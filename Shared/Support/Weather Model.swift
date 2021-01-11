//
//  Weather Model.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/9/21.
//

import Foundation
import CoreLocation
import Combine
import SwiftUI

class WeatherManager: ObservableObject {
    @EnvironmentObject var houseSettings: HouseSettings
    @EnvironmentObject var weatherSettings: WeatherSettings
    
    private var lat: Double? {
        houseSettings.fanLocation?.coordinate.latitude
    }
    private var lon: Double? {
        houseSettings.fanLocation?.coordinate.longitude
    }
    
    private var bag = Set<AnyCancellable>()
    
    fileprivate var queryElements:[URLQueryItem]? {
        get {
            guard let lat = lat, let lon = lon else { return nil }
            var accumElements:[URLQueryItem] = []
            accumElements.append(URLQueryItem(name: "lat", value: String(format: "%f", lat)))
            accumElements.append(URLQueryItem(name: "lon", value: String(format: "%f", lon)))
            accumElements.append(URLQueryItem(name: "units", value: "imperial"))
            accumElements.append(URLQueryItem(name: "APPID", value: ENV.WEATHER_API_KEY))
            return accumElements
        }
    }
    
    init () { }

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
                if case .failure = comp {
                    self?.weatherSettings.updatedWeather = nil
                }
            }, receiveValue: { [weak self] weatherObj in
                self?.weatherSettings.updatedWeather = (Date(), weatherObj)
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
    var current: Current?
    var hourly: Array<Hourly>?
    struct Current: Codable {
        var temp: Double?
    }
    struct Hourly: Codable {
        var dt: Int?
        var temp: Double?
    }
}
