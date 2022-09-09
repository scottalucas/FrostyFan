//
//  Weather Model.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/9/21.
//
/*
 API interface for openweathermap.org. Throttling code helps prevent swamping the API. To minimize transactions on the API, I store weather forecasts and return forecasted temperatures when available. If weather API calls were inexpensive this code could be simpler.
 
 There are two uses for retrieved temperature data. First, we check to see if tempertures are outside the user-set bounds for a notification. Second, we provide the temperature value for display to the user.
 */

import Foundation
import CoreLocation
import Combine
import SwiftUI
import BackgroundTasks

struct Weather {
    typealias TempMeasurement = Measurement<UnitTemperature>
    typealias Forecast = Array<(Date, TempMeasurement)>
    typealias WeatherLoader = () async -> TempMeasurement
    private static func url(atCoord coord: Coordinate) -> URL? {
        var accumElements:[URLQueryItem] = []
        accumElements.append(URLQueryItem(name: "lat", value: String(format: "%f", coord.lat)))
        accumElements.append(URLQueryItem(name: "lon", value: String(format: "%f", coord.lon)))
        accumElements.append(URLQueryItem(name: "units", value: "imperial"))
        accumElements.append(URLQueryItem(name: "APPID", value: ENV.WEATHER_API_KEY))
        var components = URLComponents()
        components.host = "api.openweathermap.org"
        components.scheme = "http"
        components.path = "/data/2.5/onecall"
        components.queryItems = accumElements
        return components.url
    }
    
    static fileprivate func loadCurrentTemp() async throws -> TempMeasurement {
        let result: WeatherResult
        do {
            guard abs(Storage.lastForecastUpdate.timeIntervalSinceNow) > 15 * 60 else {
                    throw WeatherRetrievalError.throttle(lastUpdate: Storage.lastForecastUpdate.formatted())
            } //return something from the stored forecast is it's available and not stale.
            
            guard let coord = Storage.coordinate else {
                    throw WeatherRetrievalError.noLocation
            }
            
            guard let url = url(atCoord: coord) else {
                throw WeatherRetrievalError.badUrl
            }
            
            Log.weather.info("contacting weather service on url \(url.description, privacy: .private)")
            
            let (weatherData, response) = try await Task.retrying(operation: {
                try await URLSession.shared.data(from: url)
            }).value
            

            guard let response = response as? HTTPURLResponse else {
                throw WeatherRetrievalError.decodeError
            }

            guard (200..<300) ~= response.statusCode else {
                throw WeatherRetrievalError.serverError(response.statusCode)
            }
            
            guard let r = weatherData.decodeWeatherResult else {
                throw WeatherRetrievalError.decodeError
            }
            
            result = r

            Storage.lastForecastUpdate = Date.now
            
            Storage.storedWeather = result
            
            Log.weather.info("Weather successfully retrieved from weather service.")
            Log.weather.info("last forecast update \(Storage.lastForecastUpdate.formatted())")
            
        } catch {
            guard
                let r = Storage.storedWeather,
                Date.now.timeIntervalSince(Storage.lastForecastUpdate) < ( 3600 * 24 )
            else {
                Log.weather.error("Weather retrieve failed, no stored weather available, error \(error.localizedDescription)")
                throw error }
            result = r
            Log.weather.error ("Weather retrieve returned stored weather,\r\tthrottle: \(abs(Storage.lastForecastUpdate.timeIntervalSinceNow) <= 15 * 60)\r\tCoordinate available: \(UserDefaults.standard.object(forKey: StorageKey.coordinate.rawValue) != nil)\r\tURL valid: \(Storage.coordinate.map ({ url(atCoord: $0) }) != nil)")
//            return weather
        }
        
        var forecast = result.forecast
        
        let currentConditions = (forecast[0].date.addingTimeInterval(-3600), result.currentTemp)
        
        forecast.insert(currentConditions, at: 0)
        
        //            go through forecast array to find entry closest to current time
        let currentTemp = forecast.reduce(result.currentTemp) { abs($1.date.timeIntervalSinceNow) < ( 30 * 60 ) ? $1.temp : $0 }
        Log.weather.info("current temp update successful, temp is \(currentTemp.formatted())")
        return currentTemp
    }
    
    struct WeatherObject: Codable {
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
        
        init (fromResult: WeatherResult) {
            current = WeatherObject.Current.init(temp: fromResult.currentTemp.converted(to: .fahrenheit).value)
            hourly = fromResult.forecast.map({ (date, temp) in
                let d = Int(date.timeIntervalSince1970)
                let t = temp.converted(to: .fahrenheit).value
                return WeatherObject.Hourly.init(dt: d, temp: t)
            })
        }
        
        init () {}
    }
    
    struct WeatherResult {
        var currentTemp: Measurement<UnitTemperature>
        var forecast: Array<(date: Date, temp: Measurement<UnitTemperature>)>
    }
    
}

@MainActor
class WeatherMonitor: ObservableObject { //manages interactions with the weather service on a periodic schedule. Needs to be done even when app is backgrounded if the user wants temperature alerts.
    static var shared = WeatherMonitor()
    @Published var tooHot: Bool = false
    @Published var tooCold: Bool = false
    @Published var currentTemp: Measurement<UnitTemperature>?
    @Environment(\.scenePhase) private var phase
    private let foregroundInterval = TimeInterval( 5 * 60 ) //5 minute loop interval
    private let backgroundInterval = TimeInterval( 30 * 60 ) //5 minute loop interval
    private var monitorTask: Task<(), Error> = .init(operation: {})
    
//    private var monitorTask: Task<(), Never>?
    
    private init () { }
    
    func monitor () {
        Log.weather.info("monitor started")
        monitorTask.cancel()
        monitorTask = Task {
            var retries = 3
            while true {
                do {
                    Log.weather.info("monitor loop")
                    currentTemp = try await Weather.loadCurrentTemp()
                    try await updateWeatherConditions()
                    try await Task.sleep(interval: phase == .active ? foregroundInterval : backgroundInterval)
                    try Task.checkCancellation()
                    retries = 3
                } catch {
                    Log.weather.error("\(error.localizedDescription)")
                    if Task.isCancelled {
                        Log.weather.error("Task cancelled")
                        currentTemp = nil
                        tooHot = false
                        tooCold = false
                        throw WeatherRetrievalError.cancelled
                    }
                    
                    if retries == 0 {
                        Log.weather.error("too many retries")
                        currentTemp = nil
                        tooHot = false
                        tooCold = false
                        throw WeatherRetrievalError.tooManyTries
                    }
                    
                    if let e = error as? BackgroundTaskError, e == .tempAlarmNotSet {
                        throw e
                    }
                    retries -= 1
                }
            }
        }
    }

    func suspendMonitor () {
        Log.weather.info("monitor suspended")
        monitorTask.cancel()
    }
    
    func updateWeatherConditions () async throws -> () {
        currentTemp = try await Weather.loadCurrentTemp()
        try Task.checkCancellation()
        guard let ltl = Storage.lowTempLimit, let htl = Storage.highTempLimit else {
            tooHot = false
            tooCold = false
            throw BackgroundTaskError.tempAlarmNotSet
        }
        tooCold = currentTemp.map ({ $0.value < ltl }) ?? false
        tooHot = currentTemp.map ({ $0.value > htl }) ?? false
    }
    
    
    func weatherServiceNextCheckDate () -> Date { // min 15 minutes, max 12 hours
        @ClampedWeatherRetrieval var nextCheck: Date
        
        if Storage.lastForecastUpdate == .distantPast {
            nextCheck = .now
            return nextCheck
        }
        
        guard
            Storage.temperatureAlarmEnabled,
            let highTempLimit = Storage.highTempLimit,
            let lowTempLimit = Storage.lowTempLimit
        else {
            Log.weather.info("Next check calculated, 12 hours after last update \(Storage.lastForecastUpdate.addingTimeInterval(12 * 3600).formatted())")
            nextCheck = Storage.lastForecastUpdate.addingTimeInterval(12 * 3600)
            return nextCheck
        }
        
        guard
            let weather = Storage.storedWeather,
            !weather.forecast.isEmpty
        else {
            nextCheck = .now
            Log.weather.info("Next check 15 minutes after last update.")
            return nextCheck
        }
        
        var forecast = weather.forecast
        forecast.append((date: .now, temp: weather.currentTemp))
        forecast.sort(by: { $0.date > $1.date })
        let result = forecast.reduce(forecast.first!) { current, next in
            let currentInRange = (lowTempLimit ... highTempLimit).contains(current.temp.value)
            let nextInRange = (lowTempLimit ... highTempLimit).contains(next.temp.value)
            return currentInRange == nextInRange ? current : next
        }
        nextCheck = result.date
        return nextCheck
    }
}

