//
//  Custom Errors.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 12/24/20.
//

import Foundation
import Combine
import SwiftUI

enum AdjustmentError: Error {
    typealias E = Self
    
    case notReady (String?)
    case notNeeded
    case retrievalError(ConnectionError)
    case parentOutOfScope
    case speedDidNotChange
    case timerDidNotChange
    case fanNotResponsive
    case missingKeys
    case notFound
    case notAtTarget
    case upstream (Error)
    
    static func cast(_ error: Error) -> AdjustmentError {
        .upstream(error)
    }
}

enum ConnectionError: Error {
    static func cast(_ error: Error) -> ConnectionError {
        return .upstream(error)
    }
    case badUrl
    case timeout
    case networkError (String)
    case serverError (String)
    case decodeError (String)
    case upstream (Error)

}

enum WeatherRetrievalError: Error {
    case noLocation
    case badUrl
    case decodeError
    case tooManyTries
    case cancelled
    case throttle (lastUpdate: String)
    case serverError (Int?)
    case unknownError (String)
}

enum BackgroundTaskError: Error {
    case notAuthorized
    case fanNotOperating
    case tempAlarmNotSet
    case noCurrentTemp
    case taskCancelled
}

enum NotificationError: Error {
    case tooSoon, notificationsDisabled, dataNotAvailable
}

enum SettingsError: LocalizedError {
    case noTemp, alertsDisabled, locationDisabledForApp, locationDisabledForDevice, noLocation
    
    var errorDescription: String? {
        switch self {
        case .alertsDisabled:
            return "Notifications disabled"
        case .locationDisabledForApp:
            return "Location disabled for this app"
        case .locationDisabledForDevice:
            return "Location disabled for this device"
        case .noTemp:
            return "Outside temperature not available"
        case .noLocation:
            return "Location could not be retrieved"
        default:
            return nil
        }
    }
     
    var failureReason: String? {
        switch self {
        case .alertsDisabled:
            return "Notifications are turned off for this app"
        case .locationDisabledForApp:
            return "Can't get location, app is not authorized"
        case .locationDisabledForDevice:
            return "Location disabled for this device"
        case .noTemp:
            return "Unable to retrieve temperature"
        case .noLocation:
            return "Error when requesting location"
        default:
            return nil
        }
    }
     
    var recoverySuggestion: String? {
        switch self {
        case .alertsDisabled:
            return "Enable notifications?"
        case .locationDisabledForApp, .locationDisabledForDevice:
            return "Enable location?"
        case .noLocation:
            return "Get location?"
        case .noTemp:
            return "Try getting weather again?"
        default:
            return nil
        }
    }
    
    func resolve (using vm: SettingViewModel) async throws {
        switch self {
        case .alertsDisabled, .locationDisabledForApp, .locationDisabledForDevice:
            guard
                let url = await URL(string: UIApplication.openSettingsURLString),
                await UIApplication.shared.canOpenURL(url)
            else { return }
            await UIApplication.shared.open(url)
        case .noTemp:
            try? await WeatherMonitor.shared.updateWeatherConditions()
        case .noLocation:
            await vm.updateLocation()
        default:
            return
        }
    }
}
/*
guard await UNUserNotificationCenter.current().getStatus() == .authorized else {
    print("Notifications not authorized.")
    task.setTaskCompleted(success: true)
    return
}
guard house.fansOperating, monitor.tempAlarmSet else {
    print("Background task not required, fan operating: \(house.fansOperating), alarm set: \(monitor.tempAlarmSet)")
    task.setTaskCompleted(success: true)
    return
}

await monitor.updateWeatherAlarmStatus()

guard let currentTemp = monitor.currentTemp else {
    print("Valid current temp not available.")
    task.setTaskCompleted(success: false)
    return
}
*/
