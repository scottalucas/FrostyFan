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
    
    var description: String {
        switch self {
            case .notReady(let info):
                return "Not ready, \(info ?? "no further info.")"
            case .notNeeded:
                return "Not needed"
            case .retrievalError (let err):
                return "Retrieval error \(err.localizedDescription)"
            case .parentOutOfScope:
                return "Parent out of scope"
            case .speedDidNotChange:
                return "Speed did not change"
            case .timerDidNotChange:
                return "Timer did not change"
            case .fanNotResponsive:
                return "Fan not responsive"
            case .missingKeys:
                return "Missing keys"
            case .notFound:
                 return "Not found"
            case .notAtTarget:
                return "Not at target"
            case .upstream (let err):
                return "Upstream error \(err.localizedDescription)"
        }
    }
}

enum ConnectionError: Error {
    typealias E = Self
    static func cast(_ error: Error) -> ConnectionError {
        return .upstream(error)
    }
    case badUrl
    case timeout
    case networkError (String)
    case serverError (String)
    case decodeError (String)
    case upstream (Error)
    
    var description: String {
        switch self {
            case .badUrl:
                return "Bad url"
            case .timeout:
                return "timeout"
            case .networkError (let reason):
                return "Network error \(reason)"
            case .serverError (let reason):
                return "Server error \(reason)"
            case .decodeError (let reason):
                return "Decode error \(reason)"
            case .upstream (let err):
                return "Upstream type: \(err.self) description: \(err.localizedDescription)"
        }
    }
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
    
    var description: String {
        switch self {
            case .noLocation:
                return "Location not permitted or not set"
            case .badUrl:
                return "Bad URL"
            case .decodeError:
                return "Could not decode data returned from weather service"
            case .throttle (let lastUpdate):
                return "Throttled weather service, last update was \(lastUpdate)"
            case .serverError (let error):
                var errorDesc = ""
                switch error {
                    case nil:
                        errorDesc = "Unknown error"
                    case .some(let errorCode):
                        switch errorCode {
                            case 401:
                                errorDesc = "API key error or wrong subscription type request."
                            case 404:
                                errorDesc = "Wrong location or API format."
                            case 429:
                                errorDesc = "API call rate exceeded."
                            case 500, 502, 503, 504:
                                errorDesc = "API key error or wrong subscription type request."
                            default:
                                errorDesc = "Open weather map error \(errorCode)."
                        }
                }
                return "Server error \(errorDesc)."
            case .tooManyTries:
                return "Too many attempts to retrieve weather"
            case .cancelled:
                return "Task cancelled"
            case .unknownError (let errorDescription):
                return "Unknown error \(errorDescription)"
        }
    }
}

enum BackgroundTaskError: Error {
    case notAuthorized
    case fanNotOperating
    case tempAlarmNotSet
    case noCurrentTemp
    case taskCancelled
    
    var description: String {
        switch self {
            case .notAuthorized:
                return "User has disabled notifications."
            case .fanNotOperating:
                return "No fans are operating"
            case .tempAlarmNotSet:
                return "User has disabled temperature alarms"
            case .noCurrentTemp:
                return "No current temperature provided"
            case .taskCancelled:
                return "Task cancelled"
        }
    }
}

enum NotificationError: Error {
    case tooSoon, notificationsDisabled, dataNotAvailable
    
    var description: String {
        switch self {
            case .dataNotAvailable:
                return "Data not available"
            case .notificationsDisabled:
                return "Notifications disable"
            case .tooSoon:
                return "Too soon for another notification"
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
