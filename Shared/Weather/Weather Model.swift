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
import BackgroundTasks

struct Weather {
    typealias Forecast = Array<(Date, Measurement<UnitTemperature>)>
    typealias TempMeasurement = Measurement<UnitTemperature>
//    @AppStorage(StorageKey.lastForecastUpdate.key) var lastUpdate: Date = .distantPast
//    @AppStorage(StorageKey.coordinate.key) var coord: Data?
//    @AppStorage(StorageKey.forecast.key) var forecast: Data?
    
    private func url(atCoord coord: Coordinate) -> URL? {
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
    
    init ( ) { }
    
    fileprivate func load(testWeatherServiceResult: Weather.WeatherResult? = nil) async throws {
        guard
            let coord = Storage.coordinate else { throw WeatherRetrievalError.noLocation }
        
        //        guard let updated = lastUpdate else { throw WeatherRetrievalError.decodeError }
        
        guard
            abs(Storage.lastForecastUpdate.timeIntervalSinceNow) > 15 * 60 else {
                throw WeatherRetrievalError.throttle(lastUpdate: Storage.lastForecastUpdate.ISO8601Format())
            }
        
        guard let url = url(atCoord: coord) else {
            throw WeatherRetrievalError.badUrl
        }
        
        let urlSession = URLSession.shared
        
        if let r = testWeatherServiceResult {
            Storage.lastForecastUpdate = Date.now
            Storage.storedWeather = r
            print("In load\rVariable: \(r.forecast.count)\rUser defaults: \(Storage.storedWeather.map ({ String($0.forecast.count) }) ?? "not found.")")
            return
        }
        print ("Weather service hit")
        
        let weatherData = try await urlSession.data(from: url)
        
        guard let response = weatherData.1 as? HTTPURLResponse else {
            throw WeatherRetrievalError.serverError(-1)
        }
        
        guard (200..<300) ~= response.statusCode else {
            throw WeatherRetrievalError.serverError(response.statusCode)
        }
        
        guard weatherData.0.decodeWeatherResult != nil else {
            throw WeatherRetrievalError.decodeError
        }
        
        Storage.lastForecastUpdate = Date.now
        
        Storage.storedWeather = weatherData.0.decodeWeatherResult
        
        return
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

class WeatherMonitor: ObservableObject {
    typealias TempOutOfRange = Bool
    static var shared = WeatherMonitor()
    @Environment(\.scenePhase) var scenePhase
//    @AppStorage(StorageKey.lowTempLimit.key) var lowTempLimit: Double = 55
//    @AppStorage(StorageKey.highTempLimit.key) var highTempLimit: Double = 75
//    @AppStorage(StorageKey.temperatureAlarmEnabled.key) var tempAlarmSet = false
//    @AppStorage(StorageKey.lastForecastUpdate.key) var lastUpdate: Date = .distantPast
//    @AppStorage(StorageKey.forecast.key) var storedWeatherData: Data? //encodes as a WeatherObject, use decodeWeatherResult method to get a WeatherResult
    @Published var tooHot: Bool = false
    @Published var tooCold: Bool = false
    @Published var currentTemp: Measurement<UnitTemperature>? {
        willSet {
            print("Updated current temp to \(newValue?.formatted() ?? "nil")")
            guard let ltl = Storage.lowTempLimit, let htl = Storage.highTempLimit, let newTemp = newValue?.value else {
                tooHot = false
                tooCold = false
                return
            }
            tooCold = newTemp < ltl
            tooHot = newTemp > htl
        }
    }
    private var monitorTask: Task<(), Never>?
    
    private init () { }
    
    func monitor () {
        let interval = TimeInterval( 5 * 60 ) //5 minute loop interval
        monitorTask = Task {
            while true {
                do {
                    guard let cancelled = monitorTask?.isCancelled, !cancelled else {
                        throw BackgroundTaskError.taskCancelled
                    }
                    print("monitor loop @ \(Date.now.formatted()), last update \(Storage.lastForecastUpdate.formatted())")
                    try await updateWeatherConditions()
                    try await Task.sleep(interval: interval) //run the loop every 5 minutes to respond as conditions change
                } catch {
                    monitorTask?.cancel()
                    monitorTask = nil
                    print("exited monitor loop @ \(Date.now.formatted()), error: \(error.localizedDescription)")
                    break
                }
            }
            
        }
    }
    
    func updateWeatherConditions (testStoredWeatherResult: Weather.WeatherResult? = nil, testRetrievedWeatherResult: Weather.WeatherResult? = nil, testLocationData: Coordinate? = nil) async throws {
        if let testW = testStoredWeatherResult {
            Storage.storedWeather = testW
        }
        if weatherServiceNextCheckDate() < .now {
            for loopNum in (1...3) { //try to contact service 3X with 10s delay
                print("Contact weather service loop \(loopNum)")
                do {
                    try await Weather().load(testWeatherServiceResult: testRetrievedWeatherResult)
//                    print("In update\rVariable: \(storedWeatherData?.count)\rUser defaults: \(storedWeatherData.map ({ String($0.count) }) ?? "not found.")")
                    break //successful weather retrieve, move on
                } catch {
                    print("Retrieve error: \((error as? WeatherRetrievalError)?.description ?? error.localizedDescription)")
                    if loopNum == 3 { throw error }
                    do {
                        try await Task.sleep(interval: 10)
                    } catch {
                        throw error
                    }
                }
            } // END: retriveLoop
        } // END: shouldContactWeatherService
        guard let weatherResult = Storage.storedWeather, !weatherResult.forecast.isEmpty else {
            currentTemp = nil
            tooHot = false
            tooCold = false
            throw WeatherRetrievalError.decodeError
        }
        
        //prepend current conditions to forecast array
        var forecast = weatherResult.forecast
        let currentConditions = (forecast[0].date.addingTimeInterval(-3600), weatherResult.currentTemp)
        forecast.insert(currentConditions, at: 0)
        
        //go through forecast array to find entry closest to current time
        currentTemp = weatherResult.forecast.reduce(weatherResult.currentTemp) { abs($1.date.timeIntervalSinceNow) < ( 30 * 60 ) ? $1.temp : $0 }
    }
    
    func suspendMonitor () {
        monitorTask?.cancel()
    }
    
    //    private func shouldContactWeatherService () -> Bool {
    //        guard let lastUpdate = lastUpdateData?.decodeDate else { return true }
    //        guard abs(lastUpdate.timeIntervalSinceNow) > 15 * 60 else {
    //            return false
    //        } //shouldn't need this but it'll failsafe
    //        return weatherServiceNextCheckDate() < .now
    //    }
    
    func weatherServiceNextCheckDate () -> Date { // min 15 minutes, max 12 hours
        @ClampedWeatherRetrieval var nextCheck: Date
        
        if Storage.lastForecastUpdate == .distantPast {
            nextCheck = .now
            return nextCheck
        }
        
        guard HouseMonitor.shared.fansOperating, Storage.temperatureAlarmEnabled, let highTempLimit = Storage.highTempLimit, let lowTempLimit = Storage.lowTempLimit else {
            print("Fan operating: \(HouseMonitor.shared.fansOperating)\rHigh temp limit: \(Storage.highTempLimit)\rLow temp limit: \(Storage.lowTempLimit)\rAlarm enabled: \(Storage.temperatureAlarmEnabled)")
            print ("Next check 12 hours after last update.")
            nextCheck = Storage.lastForecastUpdate.addingTimeInterval(12 * 3600)
            return nextCheck
        }
        
        guard let weather = Storage.storedWeather, !weather.forecast.isEmpty else {
            nextCheck = .now
            print("Next check 15 minutes after last update.")
            return nextCheck
        }
        

        var forecast = weather.forecast
        forecast.append((date: .now, temp: weather.currentTemp))
        forecast.sort(by: { $0.date > $1.date })
        forecast.forEach({ print("Before eval date: \($0.date.formatted(date: .abbreviated, time: .standard)) temp: \($0.temp.value)") })
        let result = forecast.reduce(forecast.first!) { current, next in
            let currentInRange = (lowTempLimit ... highTempLimit).contains(current.temp.value)
            let nextInRange = (lowTempLimit ... highTempLimit).contains(next.temp.value)
            let res = currentInRange == nextInRange ? current : next
            print ("Current candidate date: \(res.date.formatted(date: .abbreviated, time: .standard)) temp: \(res.temp.value)")
            return currentInRange == nextInRange ? current : next
        }
        print ("Result: \(result.date.formatted()) temp: \(result.temp.value)")
        nextCheck = result.date
        return nextCheck
    }
}

class WeatherBackgroundTaskManager {
    static func handleTempCheckTask (task: BGRefreshTask, existingWeatherResult: Weather.WeatherResult? = nil, retrievedWeatherResult: Weather.WeatherResult? = nil) async -> () {
        defer { scheduleBackgroundTempCheckTask(forId: BackgroundTaskIdentifier.tempertureOutOfRange, waitUntil: WeatherMonitor.shared.weatherServiceNextCheckDate() )
        }
//        @AppStorage(StorageKey.temperatureAlarmEnabled.key) var alarmEnabled: Bool = false
        print("Background fetch being handled\t")
        let monitor = WeatherMonitor.shared
        let house = HouseMonitor.shared
        task.expirationHandler = {
            print("Background handler expired")
            task.setTaskCompleted(success: false)
        }
        do {
            guard await UNUserNotificationCenter.current().getStatus() == .authorized else { throw BackgroundTaskError.notAuthorized }
            
            guard house.fansOperating else { throw BackgroundTaskError.fanNotOperating }
            
            guard Storage.temperatureAlarmEnabled else {
                throw BackgroundTaskError.tempAlarmNotSet
            }
            
            try await monitor.updateWeatherConditions(testStoredWeatherResult: existingWeatherResult, testRetrievedWeatherResult: retrievedWeatherResult, testLocationData: nil)
            
            guard monitor.currentTemp != nil else { throw BackgroundTaskError.noCurrentTemp }
            
        } catch {
            task.setTaskCompleted(success: false)
            if let err = error as? BackgroundTaskError {
                print ( err.description )
            } else if let err = error as? WeatherRetrievalError {
                print ( err.description )
            } else {
                print (error.localizedDescription)
            }
            return
        }
        
        do {
            print("Successfully got weather")
            if !monitor.tooHot && !monitor.tooCold {
                print("Temperature in range, no need for alert")
            } else {
                guard let temperatureString = monitor.currentTemp.map ({ CustomFormatter.temperture.string(from: $0) }) else {
                    throw BackgroundTaskError.noCurrentTemp
                }
                let alertString = monitor.tooHot ? "high" : "low"
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                //present the alert
                let content = UNMutableNotificationContent()
                content.title = "Airscape Fan Temperature Alert"
                content.subtitle = "Outside temperature is \(alertString) at \(temperatureString). Consider turning the fan off."
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                try await UNUserNotificationCenter.current().add(request)
            }
        } catch {
            print("Weather update failure, error \(error.localizedDescription)")
        }
        print("Background task complete.")
        task.setTaskCompleted(success: true)
        
        
        
        
    }
    static func scheduleBackgroundTempCheckTask (forId: String, waitUntil date: Date) {
        print("Background fetch being scheduled")
        let request = BGAppRefreshTaskRequest(identifier: forId)
        request.earliestBeginDate = date
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print ("Could not schedule app refresh request, error: \(error.localizedDescription), requested date: \(date.formatted()), id: \(forId)")
        }
    }
}
