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
    typealias WeatherLoader = () async -> Measurement<UnitTemperature>
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
    
    static fileprivate func loadCurrentTemp() async throws -> Measurement<UnitTemperature> {
        let result: WeatherResult
        do {
            guard abs(Storage.lastForecastUpdate.timeIntervalSinceNow) > 15 * 60 else {
                    throw WeatherRetrievalError.throttle(lastUpdate: Storage.lastForecastUpdate.formatted())
            }
            
            guard let coord = Storage.coordinate else {
                    throw WeatherRetrievalError.noLocation
            }
            
            guard let url = url(atCoord: coord) else {
                throw WeatherRetrievalError.badUrl
            }
            
            print ("Weather service hit")
            
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
            
        } catch {
            guard
                let r = Storage.storedWeather,
                Date.now.timeIntervalSince(Storage.lastForecastUpdate) < ( 3600 * 24 )
            else { throw error }
            result = r
            print ("Weather retrieve returned stored weather,\r\tthrottle: \(abs(Storage.lastForecastUpdate.timeIntervalSinceNow) <= 15 * 60)\r\tCoordinate available: \(UserDefaults.standard.object(forKey: StorageKey.coordinate.rawValue) != nil)\r\tURL valid: \(Storage.coordinate.map ({ url(atCoord: $0) }) != nil)")
//            return weather
        }
        
        var forecast = result.forecast
        
        let currentConditions = (forecast[0].date.addingTimeInterval(-3600), result.currentTemp)
        
        forecast.insert(currentConditions, at: 0)
        
        //            go through forecast array to find entry closest to current time
        let currentTemp = forecast.reduce(result.currentTemp) { abs($1.date.timeIntervalSinceNow) < ( 30 * 60 ) ? $1.temp : $0 }
        
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

class WeatherMonitor: ObservableObject {
    static var shared = WeatherMonitor()
    @Published var tooHot: Bool = false
    @Published var tooCold: Bool = false
    @Published var currentTemp: Measurement<UnitTemperature>?
    @Environment(\.scenePhase) private var phase
    private let foregroundInterval = TimeInterval( 5 * 60 ) //5 minute loop interval
    private let backgroundInterval = TimeInterval( 30 * 60 ) //5 minute loop interval
    private var monitorTask: Task<(), Error> = .init(operation: {})
    private var retries: Int = 3
    
//    private var monitorTask: Task<(), Never>?
    
    private init () { }
    
    func monitor () {
        monitorTask.cancel()
        monitorTask = Task {
            while true {
                do {
                    currentTemp = try await Weather.loadCurrentTemp()
                    try await updateWeatherConditions()
                    try await Task.sleep(interval: phase == .active ? foregroundInterval : backgroundInterval)
                    try Task.checkCancellation()
                    retries = 3
                } catch {
                    print(error.localizedDescription)
                    if Task.isCancelled {
                        currentTemp = nil
                        tooHot = false
                        tooCold = false
                        throw WeatherRetrievalError.cancelled
                    }
                    
                    if retries == 0 {
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
    
    func issueTempNotification () async throws {
//        guard Storage.lastNotificationShown.addingTimeInterval(3 * 3600) < .now else { throw NotificationError.tooSoon }
        guard .distantPast < .now else { throw NotificationError.tooSoon }
        guard let temperatureString = currentTemp.map ({ $0.formatted(Measurement<UnitTemperature>.FormatStyle.truncatedTemp) }) else { throw NotificationError.dataNotAvailable }
        let subtitleString = tooHot ? "It's hot outside." : "It's cold outside."
        let bodySubstring = tooHot ? "heating up" : "cooling down"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        //present the alert
        let content = UNMutableNotificationContent()
        content.title = "Whole House Fan Alert"
        content.subtitle = subtitleString
        content.body = "Your fan is \(bodySubstring) your house. Turn it off?"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
        Storage.lastNotificationShown = .now
    }
}

class WeatherBackgroundTaskManager {
    static func handleTempCheckTask (task: BGRefreshTask) async -> () {
        defer {
            scheduleBackgroundTempCheckTask(forId: BackgroundTaskIdentifier.tempertureOutOfRange, waitUntil: WeatherMonitor.shared.weatherServiceNextCheckDate()
            )
        }
        print("Background fetch being handled")
        task.expirationHandler = {
            print("Background handler expired")
            task.setTaskCompleted(success: false)
        }
        do {
            guard await UNUserNotificationCenter.current().getStatus() == .authorized else { throw BackgroundTaskError.notAuthorized }
            
            guard HouseStatus.shared.fansRunning else { throw BackgroundTaskError.fanNotOperating }
            
            guard Storage.temperatureAlarmEnabled else { throw BackgroundTaskError.tempAlarmNotSet }
            
            try await WeatherMonitor.shared.updateWeatherConditions()
            
            try await WeatherMonitor.shared.issueTempNotification()
            
//            guard let ct = monitor.currentTemp else { throw BackgroundTaskError.noCurrentTemp }
            
        } catch {
            task.setTaskCompleted(success: false)
            if let err = error as? BackgroundTaskError {
                print ( err.description )
            } else if let err = error as? WeatherRetrievalError {
                print ( err.description )
            } else {
                print ( error.localizedDescription )
            }
            return
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
