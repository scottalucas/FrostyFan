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
//    private var sharedHouseData = SharedHouseData.shared
    @AppStorage(StorageKey.lowTempLimit.key) var lowTempLimit: Double = 55
    @AppStorage(StorageKey.highTempLimit.key) var highTempLimit: Double = 75
//    @AppStorage var houseConfiguredAlarms: Alarm.House
    @AppStorage(StorageKey.temperatureAlarmEnabled.key) var tempAlarmSet = false
    @AppStorage(StorageKey.locationAvailable.key) var locationPermission: Location.LocationPermission = .unknown
//    @AppStorage(StorageKey.locLat.key) var latitude: Double?
//    @AppStorage(StorageKey.locLon.key) var longitude: Double?
    @AppStorage(StorageKey.coordinate.key) var coordinateData: Data? //decodes to Coordinate
    @AppStorage(StorageKey.lastForecastUpdate.key) var lastUpdateData: Data? //decodes to Date
    @AppStorage(StorageKey.forecast.key) var forecastData: Data?
    @Published private (set) var currentTemp: Measurement<UnitTemperature>?
    @Published private (set) var tooHot: Bool = false
    @Published private (set) var tooCold: Bool = false
    private var currentTempValue: Double? {
        willSet {
            guard let t = newValue else {
                currentTemp = nil
                tooHot = false
                tooCold = false
                return
            }
//            let tempFormatter = NumberFormatter()
//            tempFormatter.positiveFormat = "#0\u{00B0}"
//            tempFormatter.negativeFormat = "-#0\u{00B0}"
//            tempFormatter.roundingMode = .halfDown
            currentTemp = Measurement(value: t, unit: UnitTemperature.fahrenheit)
            tooCold = t < lowTempLimit
            tooHot = t > highTempLimit
        }
    }
//    private var checkTimer = Timer.publish(every: (15.0 * 60.0), on: .main, in: .common)
    private var forecast = Array<(Date, Double)>()
//    private var bag = Set<AnyCancellable>()
    
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
        startChecking()
//
//        Deferred { Just(Date()) }
//            .merge (with: checkTimer)
//            .sink(receiveValue: { [weak self] _ in
//                guard let self = self else { return }
//                let lastUpdate = self.lastUpdate.map { Date(timeIntervalSince1970: $0) } ?? .distantPast
////                let fansAreRunning = self.house.fans.map { $0.speed }.filter({ $0 > 0 }).count > 0
//                self.updateCurrentTemp()
//                let nextUpdate = WeatherCheckInterval.nextRecommendedDate(
//                    forTemp: self.currentTemp,
//                    fromLastUpdate: lastUpdate,
//                    highTempLimitSet: self.highTempLimit,
//                    lowTempLimitSet: self.lowTempLimit,
//                    tempAlarmSet: self.tempAlarmSet,
//                    fansRunning: true) //FIX
//                if Date() > nextUpdate {
//                    Task {
//                        await self.load()
//                    }
//                }
//            })
//            .store(in: &bag)
    }
    
    private func startChecking () {
        Task {
            while true {
                let lastUpdate = self.lastUpdateData?.decodeDate ?? .distantPast
                if true
//                    if Date () > WeatherCheckInterval.nextRecommendedDate (
//                    forTemp: self.currentTemp,
//                    fromLastUpdate: lastUpdate,
//                    highTempLimitSet: self.highTempLimit,
//                    lowTempLimitSet: self.lowTempLimit,
//                    tempAlarmSet: self.tempAlarmSet,
//                    fansRunning: true
//                )
                {
                    do {
                        try await load()
                    } catch {
                        print ("Error getting weather \(error.localizedDescription)")
                    }
                }
                await Task.sleep(15 * 60 * 1_000_000_000)
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
//        WeatherLoader(components: components)?
//            .getWeather
//            .sink(receiveCompletion: { [weak self] comp in
//                if case .failure = comp {
//                    self?.forecastData = Data()
//                }
//            }, receiveValue: { [weak self] weatherObj in
//                guard let self = self else { return }
//                var newForcast = self.convertToDateArray(byHour: weatherObj.hourly ?? [])
//                weatherObj.current?.temp.map { newForcast.append((Date(), $0)) }
//                newForcast.sort(by: { $0.0 < $1.0 })
//                self.forecast = newForcast
//                self.forecastData = weatherObj.data()
//                self.lastUpdate = Date().timeIntervalSince1970
//                self.updateCurrentTemp()
//            })
//            .store(in: &bag)
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
    case rarely = 43200 //12 hours
    
    static func nextRecommendedDate (forTemp temp: Double?, fromLastUpdate lastUpdate: Date, highTempLimitSet: Double?, lowTempLimitSet: Double?, tempAlarmSet: Bool, fansRunning: Bool) -> Date {
        guard let temp = temp else {
            return .distantPast
        }
        let highTempLimitRange = highTempLimitSet.map { Range<Int>((Int($0 * 10) - 30) ... (Int($0 * 10) + 30)) }
        let lowTempLimitRange = lowTempLimitSet.map { Range<Int>((Int($0 * 10) - 30) ... (Int($0 * 10) + 30)) }
        let tempInProximity = highTempLimitRange.map { $0 ~= Int(temp * 10) } ?? false || lowTempLimitRange.map { $0 ~= Int(temp * 10) } ?? false
        
        switch (fansRunning, tempAlarmSet, tempInProximity) {
        case (false, _, _):
            let interval = TimeInterval(self.rarely.rawValue)
            return Date(timeInterval: interval, since: lastUpdate)
        case (true, true, true):
            let interval = TimeInterval(self.frequent.rawValue)
            return Date(timeInterval: interval, since: lastUpdate)
        case (true, false, _):
            let interval = TimeInterval(self.occasional.rawValue)
            return Date(timeInterval: interval, since: lastUpdate)
        default:
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
