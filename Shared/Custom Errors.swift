//
//  Custom Errors.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 12/24/20.
//

import Foundation
import Combine

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
                return "Upstream \(err.localizedDescription)"
        }
    }
}
