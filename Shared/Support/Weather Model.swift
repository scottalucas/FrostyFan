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

class Weather: ObservableObject {
    @AppStorage(StorageKey.lowTempLimit.key) var lowTempLimit: Double = 55
    @AppStorage(StorageKey.highTempLimit.key) var highTempLimit: Double = 75
    @AppStorage(StorageKey.temperatureAlarmEnabled.key) var tempAlarmSet = false
    @AppStorage(StorageKey.locationAvailable.key) var locationPermission: Location.LocationPermission = .unknown
    @AppStorage(StorageKey.coordinate.key) var coordinateData: Data? //decodes to Coordinate
    @AppStorage(StorageKey.lastForecastUpdate.key) var lastUpdateData: Data? //decodes to Date
    @AppStorage(StorageKey.forecast.key) var forecastData: Data?
    @Published private (set) var currentTemp: Measurement<UnitTemperature>?
    @Published private (set) var tooHot: Bool = false
    @Published private (set) var tooCold: Bool = false
    @Published private (set) var retrievalError: Error? = ConnectionError.serverError("Just would NOT work.")
    private var currentTempValue: Double? {
        willSet {
            guard let t = newValue else {
                currentTemp = nil
                tooHot = false
                tooCold = false
                return
            }
            currentTemp = Measurement(value: t, unit: UnitTemperature.fahrenheit)
            tooCold = t < lowTempLimit
            tooHot = t > highTempLimit
        }
    }
    private var forecast = Array<(Date, Double)>()
    fileprivate var queryElements:[URLQueryItem]? {
        get {
            guard let lat = coordinateData?.decodeCoordinate?.lat, let lon = coordinateData?.decodeCoordinate?.lon else { return nil }
            var accumElements:[URLQueryItem] = []
            accumElements.append(URLQueryItem(name: "lat", value: String(format: "%f", lat)))
            accumElements.append(URLQueryItem(name: "lon", value: String(format: "%f", lon)))
            accumElements.append(URLQueryItem(name: "units", value: "imperial"))
            accumElements.append(URLQueryItem(name: "APPID", value: ENV.WEATHER_API_KEY))
            return accumElements
        }
    }
    
    init () {
        let decoder = JSONDecoder()
        let forecastD = forecastData ?? Data()
        let forecastObj = (try? decoder.decode(WeatherObject.self, from: forecastD)).map { $0.hourly } ?? nil
        forecast = forecastObj.map { convertToDateArray(byHour: $0) } ?? Array<(Date, Double)>()
        check()
    }
    
    func check () {
        Task {
            while true {
                do {
                    let lastUpdate = self.lastUpdateData?.decodeDate ?? .distantPast
                    if Date () > WeatherCheckInterval.nextRecommendedDate (
                        forTemp: self.currentTemp?.value,
                        fromLastUpdate: lastUpdate,
                        highTempLimitSet: self.highTempLimit,
                        lowTempLimitSet: self.lowTempLimit,
                        tempAlarmSet: self.tempAlarmSet,
                        fansRunning: SharedHouseData.shared.fansOperating
                    ) {
                        try await load()
                    }
                    try await Task.sleep(interval: TimeInterval(WeatherCheckInterval.frequent.rawValue) * 0.1) //run the loop fast enough to respond as conditions change
                } catch {
                    retrievalError = error
                    print ("Error getting weather \(error.localizedDescription)")
                    break
                }
            }
        }
    }
    
    private func load () async throws {
        guard let qE = queryElements else { throw ConnectionError.decodeError("Could not get query elements from \(queryElements?.description ?? "elements not available")") }
        var components = URLComponents()
        components.host = "api.openweathermap.org"
        components.scheme = "http"
        components.path = "/data/2.5/onecall"
        components.queryItems = qE
        if let loader = WeatherLoader(components: components) {
            var weatherObj: WeatherObject
            weatherObj = try await loader.load()
            var newForcast = self.convertToDateArray(byHour: weatherObj.hourly ?? [])
            weatherObj.current?.temp.map { newForcast.append((Date(), $0)) }
            newForcast.sort(by: { $0.0 < $1.0 })
            self.forecast = newForcast
            self.forecastData = weatherObj.data
            self.lastUpdateData = Date().data
            self.updateCurrentTemp()
        }
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
    
    private func updateCurrentTemp () {
        guard !forecast.isEmpty else {
            currentTemp = nil
            return
        }
        let val = forecast.reduce((.distantPast, 0.0)) { (last, next) in
            return (abs(Date().timeIntervalSince(last.0)) > abs(Date().timeIntervalSince(next.0))) ? next : last
        }.1
        currentTemp = Measurement(value: val, unit: UnitTemperature.fahrenheit)
    }
    
    struct WeatherLoader {
        var urlSession = URLSession.shared
        let decoder = JSONDecoder()
        let url: URL
        init? (components: URLComponents) {
            guard let url = components.url else { return nil }
            self.url = url
        }
        func load() async throws -> WeatherObject {
            let weatherData = try await urlSession.data(from: url).0
            return try decoder.decode(WeatherObject.self, from: weatherData)
        }
    }
}



enum WeatherCheckInterval: Int {
    case frequent = 900 //15 minutes
    case occasional = 3600 //1 hour
    case rarely = 7200 //2 hours
    
    static func nextRecommendedDate (forTemp temp: Double?, fromLastUpdate lastUpdate: Date, highTempLimitSet: Double?, lowTempLimitSet: Double?, tempAlarmSet: Bool, fansRunning: Bool) -> Date {
        guard let temp = temp else {
            return .distantPast
        }
        let highTempLimitRange = highTempLimitSet.map { Range<Int>((Int($0 * 10) - 30) ... (Int($0 * 10) + 30)) } //multiplying by 10 here to work with Int ranges
        let lowTempLimitRange = lowTempLimitSet.map { Range<Int>((Int($0 * 10) - 30) ... (Int($0 * 10) + 30)) } //multiplying by 10 to work with Int ranges
        let tempInProximity = highTempLimitRange.map { $0 ~= Int(temp * 10) } ?? false || lowTempLimitRange.map { $0 ~= Int(temp * 10) } ?? false //multiplying by 10 to work with Int ranges
        
        switch (fansRunning, tempAlarmSet, tempInProximity) {
            case (false, _, _): // no fans running
                let interval = TimeInterval(self.rarely.rawValue)
                return Date(timeInterval: interval, since: lastUpdate)
            case (_, false, _): // fans running, user does not want notifications
                let interval = TimeInterval(self.occasional.rawValue)
                return Date(timeInterval: interval, since: lastUpdate)
            case (_, true, true): // fans running, users wants notifications, outside temperatures close to set limits
                let interval = TimeInterval(self.frequent.rawValue)
                return Date(timeInterval: interval, since: lastUpdate)
            case (_, true, false): // fans running, user wants notifications, outside temperture not near limits
                let interval = TimeInterval(self.rarely.rawValue)
                return Date(timeInterval: interval, since: lastUpdate)
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
    
    var data: Data {
        let encoder = JSONEncoder()
        return (try? encoder.encode(self)) ?? Data()
    }
}
