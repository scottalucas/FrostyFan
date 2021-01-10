//
//  Weather Model.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/9/21.
//

import Foundation
import CoreLocation
import Combine

class WeatherManager: ObservableObject {
    static let shared = WeatherManager.init()

    @Published var weather: WeatherObject?
    private var location: CLLocation?
    private var bag = Set<AnyCancellable>()
    fileprivate var queryElements:[URLQueryItem]? {
        get {
            guard let location = location else { return nil }
            var accumElements:[URLQueryItem] = []
            accumElements.append(URLQueryItem(name: "lat", value: String(format: "%f", location.coordinate.latitude)))
            accumElements.append(URLQueryItem(name: "lon", value: String(format: "%f", location.coordinate.longitude)))
            accumElements.append(URLQueryItem(name: "units", value: "imperial"))
            accumElements.append(URLQueryItem(name: "APPID", value: ENV.WEATHER_API_KEY))
            return accumElements
        }
    }
    
    init () {
        location = CLLocation()
        HouseSettings.retrieve()
        HouseSettings.location
//            .flatMap { loc in
//                Just(loc)
//            }
            .eraseToAnyPublisher()
            .sink(receiveValue: { [weak self] loc in
                guard let loc = loc else {
                    LocationManager.shared.update()
                    return
                }
                self?.location = loc
                self?.load()
            })
            .store(in: &bag)
    }

    func load () {
        var components = URLComponents()
        components.host = "api.openweathermap.org"
        components.scheme = "http"
        components.path = "/data/2.5/onecall"
        guard let qE = queryElements else {
            return
        }
        components.queryItems = qE
        WeatherLoader(components: components)?
            .loadResults
            .sink(receiveCompletion: { [weak self] comp in
                if case .failure(let err) = comp {
                    self?.weather = nil
                }
            }, receiveValue: { [weak self] weatherObj in
                self?.weather = weatherObj
            })
            .store(in: &bag)
        return
    }
    
    struct WeatherLoader {
        var urlSession = URLSession.shared
        let decoder = JSONDecoder()
        let loadResults: AnyPublisher<WeatherObject, ConnectionError>
        init? (components: URLComponents) {
            guard let url = components.url else { return nil }
            loadResults = urlSession.dataTaskPublisher(for: url)
                .map(\.data)
                .decode(type: WeatherObject.self, decoder: decoder)
                .mapError({ err in
                    ConnectionError.cast(err)
                })
                .eraseToAnyPublisher()
        }
    }
}

class WeatherObject: Codable {
    var current: Current = Current()
    var hourly = Array<Hourly>()
    struct Current: Codable {
        var temp: Double = 0.0
    }
    struct Hourly: Codable {
        var dt: Int = 0
        var temp: Double = 0
    }
}
