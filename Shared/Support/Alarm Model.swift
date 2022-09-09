//
//  Alarm Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/10/21.
//
/*
 Manages the two types of alerts provided by the app. One notifies the user when the outside temperature exceeds user-defined limits. The other notifies the user if a fan's safely interlock is active. This code also schedules the background tasks that get the current information needed to evaluate the need for an alert. For interlock alerts, we need to query the fan itself. For weather alerts, we need the current temperature.
 */

import Foundation
import SwiftUI
import BackgroundTasks

class InterlockBackgroundTaskManager {
    @MainActor static func handleInterlockCheckTask () async -> Bool {
        defer {
            scheduleInterlockCheckTask(forId: BackgroundTaskIdentifier.interlockActive, waitUntil: .now.addingTimeInterval(60.0 * 10.0) //check every 10 minutes
            )
        }
        Log.background.info("Background fetch being handled for interlock")
        
        do {
            guard await UNUserNotificationCenter.current().getStatus() == .authorized else { throw BackgroundTaskError.notAuthorized }
            guard Storage.interlockAlarmEnabled else { throw BackgroundTaskError.interlockAlarmNotSet }
            let hostList = Storage.knownFans
            guard hostList.count > 0 else { throw BackgroundTaskError.noFans}
            var interlocked: Bool = false
            Log.background.debug("Interlock check starting, hosts \(hostList.count), enabled \(Storage.interlockAlarmEnabled)")
            interlocked = try await withThrowingTaskGroup(of: Bool.self, returning: Bool.self) { group in
                let sess = URLSessionMgr.shared.session
                sess.configuration.timeoutIntervalForRequest = 5.0
                for ip in hostList {
                    guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(FanModel.Action.refresh.rawValue)") else { continue }
                    group.addTask {
                        guard
                            let d = try? await sess.data(from: url).0,
                            let chars = try? FanCharacteristics(data: d),
                            !Storage.suppressInterlockWarning.contains(chars.ipAddr),
                            (chars.interlock2 || chars.interlock1)
                        else { return false }
                        Storage.suppressInterlockWarning.update(with: chars.ipAddr)
                        return true
                        
                    }
                }
                
                do {
                    return try await group.reduce(false, { (prev, next) in prev || next })
                } catch (let err as ConnectionError) {
                    if case .timeout = err {
                        throw err
                    }
                    return false
                } catch {
                    return false
                }
            }
            if interlocked {
                try await issueInterlockNotification()
                Log.background.info("Issued interlock alert")
            } else {
                Log.background.info("Did not issue interlock alert")
            }
            
        } catch {
            if let err = error as? BackgroundTaskError {
                Log.background.error ( "BG error \(err.description, privacy: .public)" )
            } else if let err = error as? WeatherRetrievalError {
                Log.background.error ( "Connection error \(err.description, privacy: .public)" )
            } else {
                Log.background.error ( "Unknwon error type \(error.localizedDescription, privacy: .public)" )
            }
            Log.background.error("Interlock alert handling failed. \(error.localizedDescription, privacy: .public)")
            return false

        }
        
        Log.background.info("Background interlock check task complete.")
        return true
    }
    
    static func scheduleInterlockCheckTask (forId: String, waitUntil date: Date) {
        if Storage.interlockAlarmEnabled {
            Log.background.info("Background interlock fetch being scheduled")
            let request = BGProcessingTaskRequest(identifier: forId)
            request.earliestBeginDate = date
            do {
                try BGTaskScheduler.shared.submit(request)
                Log.background.info("background interlock check task scheduled for date \(date.formatted())")
            } catch {
                Log.background.error ("Could not schedule app refresh request for interlock check, error: \(error.localizedDescription), requested date: \(date.formatted()), id: \(forId)")
                Task {
                    let pendingTasks = await BGTaskScheduler.shared.pendingTaskRequests()
                    Log.background.error("Pending tasks \(pendingTasks)")
                }
            }
        } else {
            Log.background.info("Interlock check background task not scheduled, interlock alerts are disabled.")
        }
    }
    
    static func issueInterlockNotification () async throws {
        guard .distantPast < .now else { throw NotificationError.tooSoon }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        //present the alert
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = "Whole House Fan Alert"
        content.subtitle = "Speed reduced"
        content.body = "Fan interlock active. Open windows or shut fan off."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
        Storage.lastNotificationShown = .now
    }
}

class WeatherBackgroundTaskManager {
    @MainActor static func handleTempCheckTask () async -> Bool {
        defer {
            scheduleBackgroundTempCheckTask(forId: BackgroundTaskIdentifier.tempertureOutOfRange, waitUntil: WeatherMonitor.shared.weatherServiceNextCheckDate()
            )
        }
        Log.background.info("Background weather check fetch being handled")
        do {
            guard await UNUserNotificationCenter.current().getStatus() == .authorized else { throw BackgroundTaskError.notAuthorized }
            
            guard await HouseStatus.knownFanOperating() else { throw BackgroundTaskError.fanNotOperating }
                        
            guard Storage.temperatureAlarmEnabled else { throw BackgroundTaskError.tempAlarmNotSet }
            
            try await WeatherMonitor.shared.updateWeatherConditions()
            
            try await issueTempNotification()
            
        } catch {
            if let err = error as? BackgroundTaskError {
                Log.background.error ( "\(err.description)" )
            } else if let err = error as? WeatherRetrievalError {
                Log.background.error ( "\(err.description)" )
            } else {
                Log.background.error ( "\(error.localizedDescription)" )
            }
            return false
        }
        
        Log.weather.info("Background task complete.")
        return true
    }
    
    static func scheduleBackgroundTempCheckTask (forId: String, waitUntil date: Date) {
        Log.background.info("Background temp check fetch being scheduled")
        let request = BGProcessingTaskRequest(identifier: forId)
        request.earliestBeginDate = date
        do {
            try BGTaskScheduler.shared.submit(request)
            Log.background.info("background weather check task scheduled for date \(date.formatted())")
        } catch {
            Log.background.info ("Could not schedule app refresh request for weather, error: \(error.localizedDescription), requested date: \(date.formatted()), id: \(forId)")
        }
    }
    
    static func issueTempNotification () async throws {
        //        guard Storage.lastNotificationShown.addingTimeInterval(3 * 3600) < .now else { throw NotificationError.tooSoon }
        guard .distantPast < .now else { throw NotificationError.tooSoon }
        let tooHot = await WeatherMonitor.shared.tooHot
        let subtitleString = tooHot ? "It's hot outside." : "It's cold outside."
        let bodySubstring = tooHot ? "too hot" : "too cold"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        //present the alert
        let content = UNMutableNotificationContent()
        content.title = "Whole House Fan Alert"
        content.subtitle = subtitleString
        content.body = "Your fan may make your house \(bodySubstring). Turn it off?"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
        Storage.lastNotificationShown = .now
    }
}

struct BackgroundTaskIdentifier {
    static var tempertureOutOfRange = "com.porchdog.whf001.WeatherMonitor.backgroundWeatherCheck"
    static var interlockActive = "com.porchdog.whf001.FanMonitor.interlockCheck"
}
