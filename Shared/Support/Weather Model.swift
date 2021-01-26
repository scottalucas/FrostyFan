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
    static let shared = WeatherManager()
    @ObservedObject private var settings = Settings.shared
    @Published var currentTemp: Double?
    
    private var checkTimer = Timer.publish(every: (15.0 * 60.0), on: .main, in: .common)
    private var lastUpdate: Date
    private var nextUpdate: Date
    private var lat: Double? {
        settings.houseLocation?.coordinate.latitude
    }
    private var lon: Double? {
        settings.houseLocation?.coordinate.longitude
    }
    private var forecast = Array<(Date, Double)>()
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
    
    private init () {
        self.lastUpdate = Settings.shared.weatherStorageValue?.lastUpdate ?? .distantPast
        self.nextUpdate = Settings.shared.weatherStorageValue?.nextUpdate ?? WeatherCheckInterval.nextRecommendedDate(forTemp: nil)
       
        settings.$newConfiguredAlarms
            .sink(receiveValue: { [weak self] alarms in
                guard !alarms.isDisjoint(with: Alarm.weatherRequired) else {
                    return
                }
                self?.load()
            })
            .store(in: &bag)
        
        Deferred { Just(Date()) }
            .merge (with: checkTimer)
            .sink(receiveValue: { [weak self] _ in
                guard let self = self else { return }
                guard Date() > self.nextUpdate else {
                    //add update to current temp based on forecast if time since last update > 30 min
                    //add update to nextUpdate if forecast temp ~any temp limit settings
                    return
                }
                self.load()
            })
            .store(in: &bag)
    }

    private func load () {
        guard let qE = queryElements else { return }
        var components = URLComponents()
        components.host = "api.openweathermap.org"
        components.scheme = "http"
        components.path = "/data/2.5/onecall"
        components.queryItems = qE
        WeatherLoader(components: components)?
            .loadResults
            .sink(receiveCompletion: { [weak self] comp in
                if case .failure = comp {
                    self?.settings.weatherStorageValue = nil
                }
            }, receiveValue: { [weak self] weatherObj in
                guard let self = self else { return }
                defer {
                    Settings.shared.weatherStorageValue = Settings.WeatherStorageValue.init(lastUpdate: Date(), nextUpdate: self.nextUpdate, rawForecast: weatherObj)
                    self.lastUpdate = Date()
                }
                var newForcast = self.convertToDateArray(byHour: weatherObj.hourly ?? [])
                weatherObj.current?.temp.map { newForcast.append((Date(), $0)) }
                newForcast.sort(by: { $0.0 < $1.0 })
                self.currentTemp = self.getBestTemp(fromArray: newForcast)
                self.nextUpdate = WeatherCheckInterval.nextRecommendedDate(forTemp: self.currentTemp)
            })
            .store(in: &bag)
        return
    }
    
    private func convertToDateArray (byHour: [WeatherObject.Hourly]) -> Array<(Date, Double)> {
        return byHour.compactMap({ hourly in
            guard
                let intDate = hourly.dt,
                let doubleTemp = hourly.temp
            else { return nil }
            return (Date.init(timeIntervalSince1970: TimeInterval(intDate)), doubleTemp)
            })
    }
    
    private func getBestTemp (fromArray arr: Array<(Date, Double)>) -> Double {
        return arr.reduce((.distantPast, 0.0)) { (last, next) in
            return (abs(Date().timeIntervalSince(last.0)) > abs(Date().timeIntervalSince(next.0))) ? next : last
        }.1
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

enum WeatherCheckInterval: Int {
    case frequent = 900 //15 minutes
    case occasional = 3600 //1 hour
    case rarely = 43200 //12 hours
    
    static func nextRecommendedDate (forTemp temp: Double?) -> Date {
        guard let temp = temp else {
            return Date(timeIntervalSinceNow: TimeInterval(self.occasional.rawValue))
        }
        let fanOn = House.shared.runningFans.count > 0 ? true : false
        let weatherAlertsRequested = !Settings.shared.configuredAlarms.isDisjoint(with: Alarm.weatherRequired)
        let highTempLimitRange = Settings.shared.highTempLimitSet.map { Range<Int>((Int($0 * 10) - 3) ... (Int($0 * 10) + 3)) }
        let lowTempLimitRange = Settings.shared.lowTempLimitSet.map { Range<Int>((Int($0 * 10) - 3) ... (Int($0 * 10) + 3)) }
        let tempInProximity = highTempLimitRange.map { $0 ~= Int(temp * 10) } ?? false || lowTempLimitRange.map { $0 ~= Int(temp * 10) } ?? false
        
        switch (fanOn, weatherAlertsRequested, tempInProximity) {
        case (false, _, _):
            let interval = TimeInterval(self.rarely.rawValue)
            return Date(timeIntervalSinceNow:interval)
        case (true, true, true):
            let interval = TimeInterval(self.frequent.rawValue)
            return Date(timeIntervalSinceNow:interval)
        case (true, false, _):
            let interval = TimeInterval(self.occasional.rawValue)
            return Date(timeIntervalSinceNow:interval)
        default:
            let interval = TimeInterval(self.rarely.rawValue)
            return Date(timeIntervalSinceNow:interval)
        }
    }
}

