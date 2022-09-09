//
//  Custom Errors.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 12/24/20.
//
/*
 Collect all custom errors here.
 */
import Foundation
import Combine
import SwiftUI

enum AdjustmentError: Error { //errors related to making adjustments to the fan
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

enum ConnectionError: Error { //errors related to network resource connection errors. Used to explain connectivity issues with the fan.
    case badUrl
    case timeout
    case networkError (String)
    case serverError (String)
    case decodeError (String)
    case other (String)
    case upstream (Error)

    static func cast(_ error: Error) -> ConnectionError {
        return .upstream(error)
    }
}

enum WeatherRetrievalError: Error { //used with the weather API. Note the throttle error, which is designed to help manage API queries so the app makes the miniumum number of calls needed for operation
    case noLocation
    case badUrl
    case decodeError
    case tooManyTries
    case cancelled
    case throttle (lastUpdate: String)
    case serverError (Int?)
    case unknownError (String)
}

enum BackgroundTaskError: Error { //background task code throws errors under certain conditions, including when the fan isn't operating or when the user has turned off notifications.
    case notAuthorized
    case fanNotOperating
    case noFans
    case tempAlarmNotSet
    case interlockAlarmNotSet
    case noCurrentTemp
    case taskCancelled
}

enum NotificationError: Error { //helps manage background notifications
    case tooSoon, notificationsDisabled, dataNotAvailable
}

enum SettingsError: LocalizedError { //used in the settings page. Experimenting with LocalizedError to see if the standardized failureReason, recoverySuggestion, etc. were useful.
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
