//
//  Weather Monitor Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/19/22.
//

import Foundation
import SwiftUI
import BackgroundTasks

class WeatherMonitor: ObservableObject {
    typealias TempOutOfRange = Bool
    static var shared = WeatherMonitor()
    @Environment(\.scenePhase) var scenePhase
    @AppStorage(StorageKey.lowTempLimit.key) var lowTempLimit: Double = 55 //default set in App
    @AppStorage(StorageKey.highTempLimit.key) var highTempLimit: Double = 75 //default set in App
    @AppStorage(StorageKey.temperatureAlarmEnabled.key) var tempAlarmSet = false //default set in App
//    @AppStorage(StorageKey.locationAvailable.key) var locationPermission: Location.LocationPermission = .unknown
//    @AppStorage(StorageKey.coordinate.key) var coordinateData: Data? //decodes to Coordinate
    @AppStorage(StorageKey.lastForecastUpdate.key) var lastUpdateData: Data? //decodes to Date
    @AppStorage(StorageKey.forecast.key) var forecastData: Data? //encodes as a WeatherObject, use decodeWeatherResult method to get a WeatherResult
    
    @Published var tooHot: Bool = false
    @Published var tooCold: Bool = false
    @Published var currentTemp: Measurement<UnitTemperature>? {
        willSet {
            guard let t = newValue?.value else {
                currentTemp = nil
                tooHot = false
                tooCold = false
                return
            }
            tooCold = t < lowTempLimit
            tooHot = t > highTempLimit
        }
    }
    private var monitorTask: Task<(), Never>?
    
    private init () { }
    
    func monitor () {
        monitorTask = Task {
            do {
            while true {
                if monitorTask?.isCancelled ?? false {
                    throw BackgroundTaskError.taskCancelled
                }
                print("monitor loop @ \(Date.now.formatted()), last update \(lastUpdateData?.decodeDate.map ({"\($0.formatted())"}) ?? "unknown")")
                if let weatherResult = forecastData?.decodeWeatherResult, !weatherResult.forecast.isEmpty {
                    // Updates current temp using the saved forecast.
                    var forecast = weatherResult.forecast
                    let firstDate = forecast[0].date.addingTimeInterval(-(60 * 60))
                    let wArrayCurrentTemp = weatherResult.currentTemp
                    forecast.insert((date: firstDate, temp: wArrayCurrentTemp), at: 0)
                    currentTemp = forecast.reduce(wArrayCurrentTemp) { (current, next) in
                        if abs(next.date.timeIntervalSinceNow) < 30 { return next.temp }
                        else {
                            return current
                        }
                    }
                }
                // end current temp update
                
                if shouldContactWeatherService() {
                    await updateWeather ()
                    if monitorTask?.isCancelled ?? false {
                        throw BackgroundTaskError.taskCancelled
                    }
                }
                try await Task.sleep(interval: 10) //run the loop every 5 minutes to respond as conditions change
            }
                
            } catch {
                monitorTask?.cancel()
                print("exited monitor loop @ \(Date.now.formatted()), error: \(error.localizedDescription)")
            }
        }
    }
    
    func suspendMonitor () {
        monitorTask?.cancel()
    }
    
    private func shouldContactWeatherService () -> Bool {
        guard let lastUpdate = lastUpdateData?.decodeDate else { return true }
        guard SharedHouseData.shared.fansOperating, tempAlarmSet else {
            print("in should contact, operating \(SharedHouseData.shared.fansOperating), temp alarm \(tempAlarmSet)")
            return false
        }
//        print("in should contact\r\tTime interval since last update is \(lastUpdate.timeIntervalSinceNow/60.0)\r\tInterval to next check is \(intervalToNextCheck()/60.0)\r\tThreshold is \(lastUpdate.addingTimeInterval(intervalToNextCheck()))\r\tThreshold true \(lastUpdate.addingTimeInterval(intervalToNextCheck()) > .now)")
        guard abs(lastUpdate.timeIntervalSinceNow) > 15 * 60 else {
            return false
        } //shouldn't need this but it'll failsafe
        return lastUpdate.addingTimeInterval(intervalToNextCheck()) > .now ? false : true
    }
    
    func updateWeather () async {
        
        do {
            try await Weather().load(test: true)
            
            guard let weatherResult = forecastData?.decodeWeatherResult else {
                throw WeatherRetrievalError.decodeError
            }
            print (weatherResult)
            
            currentTemp = weatherResult.currentTemp
            
            if currentTemp! >= Measurement<UnitTemperature>.init(value: highTempLimit, unit: .fahrenheit) {
                tooHot = true
            }
            
            if currentTemp! <= Measurement<UnitTemperature>.init(value: lowTempLimit, unit: .fahrenheit) {
                tooCold = true
            }
            
            lastUpdateData = Date().data
            
            return
        } catch {
            if let err = error as? WeatherRetrievalError {
                print("Error updating weather \(err.description)")
            } else {
                print ("Error updating weather \(error.localizedDescription)")
            }
            tooHot = false
            tooCold = false
            return
        }
    }
    
    func intervalToNextCheck () -> TimeInterval { // min 15 minutes, max 12 hours
        guard let weatherResult = forecastData?.decodeWeatherResult, !weatherResult.forecast.isEmpty else {
            print("Next check 15 minutes after last update.")
            return 15 * 60
        }
        var forecast = weatherResult.forecast
        let firstDate = forecast[0].date.addingTimeInterval(-(60 * 60))
        let wArrayCurrentTemp = weatherResult.currentTemp
        forecast.insert((date: firstDate, temp: wArrayCurrentTemp), at: 0)
        let interval = forecast
            .reduce(TimeInterval(12 * 60 * 60)) { (current, next) in
                if (Int(lowTempLimit) ... Int(highTempLimit)) ~= Int(next.temp.value) {
                    return current
                } else {
                    return max(15 * 60, min(current, next.date.timeIntervalSinceNow))
                }
            }
        print("Next check in \(interval / 60.0) minutes.")
        return interval
    }
}

class WeatherBackgroundTaskManager {
    static func handleTempCheckTask (task: BGAppRefreshTask) {
        print("Background fetch being handled")
        scheduleBackgroundTempCheckTask(forId: BackgroundTaskIdentifier.tempertureOutOfRange, waitUntil: .now.addingTimeInterval(WeatherMonitor.shared.intervalToNextCheck()))
        let monitor = WeatherMonitor.shared
        let house = SharedHouseData.shared
        let checkTask = Task {
            do {
                guard await UNUserNotificationCenter.current().getStatus() == .authorized else { throw BackgroundTaskError.notAuthorized }

                guard house.fansOperating else { throw BackgroundTaskError.fanNotOperating }

                guard monitor.tempAlarmSet else { throw BackgroundTaskError.tempAlarmNotSet }
                
                await monitor.updateWeather()
                
                guard monitor.currentTemp != nil else { throw BackgroundTaskError.noCurrentTemp }
                                
            } catch {
                task.setTaskCompleted(success: false)
                if let err = error as? BackgroundTaskError {
                    print( err.description )
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
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
            checkTask.cancel()
        }

    }
    static func scheduleBackgroundTempCheckTask (forId: String, waitUntil date: Date) {
        print("Background fetch being scheduled")
        let request = BGAppRefreshTaskRequest(identifier: forId)
        request.earliestBeginDate = date
        do {
            print("\(request.description)")
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print ("Could not schedule app refresh request, error: \(error.localizedDescription), requested date: \(date.formatted()), id: \(forId)")
        }
    }
}
