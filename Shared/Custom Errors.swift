//
//  Custom Errors.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 12/24/20.
//

import Foundation
import Combine

enum AdjustmentError: Error, FallbackSafe {
    
    typealias E = Self
    
    case notReady (String?)
    case notNeeded
    case retrievalError(ConnectionError)
    case parentOutOfScope
    case speedDidNotChange
    case missingKeys
    case notFound
    case upstream (Error)
    
    static func cast(_ error: Error) -> AdjustmentError {
        .upstream(error)
    }
    
    func publisher<V> (valueType value: V.Type) -> AnyPublisher<V, E> {
        return Fail.init(outputType: value, failure: self).eraseToAnyPublisher()
    }
}

enum ConnectionError: Error, FallbackSafe {
    typealias E = Self
    static func cast(_ error: Error) -> ConnectionError {
        return .upstream(error)
    }
    
    func publisher<V> (valueType value: V.Type) -> AnyPublisher<V, E> {
        return Fail.init(outputType: value, failure: self).eraseToAnyPublisher()
    }
    
    case badUrl
    case timeout
    case networkError (String)
    case serverError (String)
    case decodeError (String)
    case upstream (Error)
    
    static func publisher<T> (ofType type: T.Type, withError error: Error) -> AnyPublisher<T, ConnectionError> {
        let err: ConnectionError = error as? ConnectionError ?? .upstream(error)
        return Fail<T, ConnectionError>.init(error: err).eraseToAnyPublisher()
    }
}

protocol FallbackSafe {
    associatedtype E: Error
    static func cast (_ error: Error) -> E
    func publisher<V> (valueType value: V.Type) -> AnyPublisher<V, E>
}
