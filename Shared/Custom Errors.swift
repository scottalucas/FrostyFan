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
}
