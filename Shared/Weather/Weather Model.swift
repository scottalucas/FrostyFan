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
    typealias WeatherLoader = () async -> ()
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
    
    static func load() async {
        guard
            abs(Storage.lastForecastUpdate.timeIntervalSinceNow) > 15 * 60,
            let coord = Storage.coordinate,
            let url = url(atCoord: coord)
        else {
//            print ("Weather retrieve returned stored weather,\r\tthrottle: \(abs(Storage.lastForecastUpdate.timeIntervalSinceNow) <= 15 * 60)\r\tCoordinate available: \(UserDefaults.standard.object(forKey: StorageKey.coordinate.rawValue) != nil)\r\tURL valid: \(Storage.coordinate.map ({ url(atCoord: $0) }) != nil)")
            return
        }
        
        print ("Weather service hit")
        
        guard let (weatherData, response) = try? await Task.retrying(operation: {
            try await URLSession.shared.data(from: url)
        }).value else { return }
        
        Storage.lastForecastUpdate = Date.now
        
        guard let response = response as? HTTPURLResponse else {
            print ("Weather retrieval error, bad response")
            return
        }
        
        guard (200..<300) ~= response.statusCode else {
            print ("Weather retrieval error, code \(response.statusCode)")
            return
        }
        
        guard let result = weatherData.decodeWeatherResult else {
            print ("Weather retrieval error, could not decode")
            return
        }
        Storage.storedWeather = result
        
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
    @Published var tooHot: Bool = false
    @Published var tooCold: Bool = false
    @Published var currentTemp: Measurement<UnitTemperature>?
    
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
//                    print("Weather monitor loop @ \(Date.now.formatted()), last update \(Storage.lastForecastUpdate.formatted())")
                    try await updateWeatherConditions()
                    issueTempNotification()
                    try await Task.sleep(interval: interval) //run the loop every 5 minutes to respond as conditions change
                } catch {
//                    let e = error as? BackgroundTaskError ?? error
//                    print("exited weather monitor loop @ \(Date.now.formatted()), error: \(e.localizedDescription)")
                    break
                }
            }
            monitorTask?.cancel()
            monitorTask = nil
        }
    }

    func suspendMonitor () {
        monitorTask?.cancel()
    }
    
    func updateWeatherConditions (
//        location: Coordinate,
        loader: Weather.WeatherLoader = Weather.load
    ) async throws {
        
        await loader()
        
        guard let weatherResult = Storage.storedWeather else {
            currentTemp = nil
            tooHot = false
            tooCold = false
            throw WeatherRetrievalError.unknownError("Weather result not available")
        }
        
        var forecast = weatherResult.forecast
        let currentConditions = (forecast[0].date.addingTimeInterval(-3600), weatherResult.currentTemp)
        forecast.insert(currentConditions, at: 0)
        
        //go through forecast array to find entry closest to current time
        currentTemp = forecast.reduce(weatherResult.currentTemp) { abs($1.date.timeIntervalSinceNow) < ( 30 * 60 ) ? $1.temp : $0 }
        
        guard let t = currentTemp, let ltl = Storage.lowTempLimit, let htl = Storage.highTempLimit else {
            tooHot = false
            tooCold = false
            return
        }
        
        tooCold = t.value < ltl
        tooHot = t.value > htl
        print("Updated current temp to \(currentTemp?.formatted() ?? "nil")")
    }
    
    
    func weatherServiceNextCheckDate () -> Date { // min 15 minutes, max 12 hours
        @ClampedWeatherRetrieval var nextCheck: Date
        
        if Storage.lastForecastUpdate == .distantPast {
            nextCheck = .now
            return nextCheck
        }
        
        guard
//            HouseMonitor.shared.fansRunning,
            Storage.temperatureAlarmEnabled,
            let highTempLimit = Storage.highTempLimit,
            let lowTempLimit = Storage.lowTempLimit
        else {
//            print("Fan operating: \(HouseMonitor.shared.fansRunning)\rHigh temp limit: \(Storage.highTempLimit)\rLow temp limit: \(Storage.lowTempLimit)\rAlarm enabled: \(Storage.temperatureAlarmEnabled)")
            print ("Next check 12 hours after last update.")
            nextCheck = Storage.lastForecastUpdate.addingTimeInterval(12 * 3600)
            return nextCheck
        }
        
        guard
            let weather = Storage.storedWeather,
            !weather.forecast.isEmpty
        else {
            nextCheck = .now
            print("Next check 15 minutes after last update.")
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
    
    func issueTempNotification () {
        guard
            Storage.lastNotificationShown.addingTimeInterval(3 * 3600) < .now,
            tooHot || tooCold,
            let temperatureString = currentTemp.map ({ $0.formatted(Measurement<UnitTemperature>.FormatStyle.truncatedTemp) })
        else { return }
        let alertString = tooHot ? "high" : "low"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        //present the alert
        let content = UNMutableNotificationContent()
        content.title = "Airscape Fan Temperature Alert"
        content.subtitle = "Outside temperature is \(alertString) at \(temperatureString). Consider turning the fan off."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
                Storage.lastNotificationShown = .now
            } catch {
                print("Failed to add notification, error: \(error.localizedDescription)")
            }
        }
    }
}

class WeatherBackgroundTaskManager {
    static func handleTempCheckTask (
        task: BGRefreshTask,
//        location: Coordinate,
        loader: Weather.WeatherLoader
    )
    async -> () {
        defer {
            scheduleBackgroundTempCheckTask(forId: BackgroundTaskIdentifier.tempertureOutOfRange, waitUntil: WeatherMonitor.shared.weatherServiceNextCheckDate()
            )
        }
        print("Background fetch being handled")
        let monitor = WeatherMonitor.shared
        task.expirationHandler = {
            print("Background handler expired")
            task.setTaskCompleted(success: false)
        }
        do {
            guard await UNUserNotificationCenter.current().getStatus() == .authorized else { throw BackgroundTaskError.notAuthorized }
            
//            guard HouseMonitor.shared.fansRunning else { throw BackgroundTaskError.fanNotOperating }
            
            guard Storage.temperatureAlarmEnabled else { throw BackgroundTaskError.tempAlarmNotSet }
            
            try await monitor.updateWeatherConditions(loader: loader)
            
//            guard let ct = monitor.currentTemp else { throw BackgroundTaskError.noCurrentTemp }
            
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
        print("Successfully got weather")
        
        if
            Storage.lastNotificationShown.addingTimeInterval(3 * 3600) < .now,
            let ct = monitor.currentTemp,
            let htl = Storage.highTempLimit,
            let ltl = Storage.lowTempLimit,
            (ct.value > htl || ct.value < ltl) {
            let alertString = ct.value > htl ? "high" : "low"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            //present the alert
            let content = UNMutableNotificationContent()
            content.title = "Airscape Fan Temperature Alert"
            content.subtitle = "Outside temperature is \(alertString) at \(ct.formatted(Measurement.FormatStyle.truncatedTemp)). Consider turning the fan off."
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            Task {
                do {
                    try await UNUserNotificationCenter.current().add(request)
                    Storage.lastNotificationShown = .now
                } catch {
                    print("Failed to add notification, error: \(error.localizedDescription)")
                }
            }
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
            print("background task scheduled for date \(date.formatted())")
        } catch {
            print ("Could not schedule app refresh request, error: \(error.localizedDescription), requested date: \(date.formatted()), id: \(forId)")
        }
    }
}
