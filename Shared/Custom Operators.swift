//
//  Custom Operators.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 12/24/20.
//

import Foundation
import Combine

extension Publisher where Output == FanModel.Action, Failure == Never {
    
    func getAdjustmentURL(for ip: String) -> AnyPublisher<URL, ConnectionError> {
        return self
            .flatMap { action -> AnyPublisher<URL, ConnectionError> in
                guard let baseUrl = URL(string: "http://\(ip)"),
                      let urlStr = baseUrl.appendingPathComponent("/fanspd.cgi?dir=\(action.rawValue)").absoluteString.removingPercentEncoding,
                      let finalURL = URL(string: urlStr)
                else { return ConnectionError.badUrl.publisher(valueType: URL.self) }
                return Just (finalURL).setFailureType(to: ConnectionError.self).eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }
}

extension Publisher where Output == URL, Failure == ConnectionError {
    
    func adjustFan() -> AnyPublisher<Dictionary<String,String?>, AdjustmentError> {
        typealias Output = Dictionary<String,String?>
        typealias Failure = AdjustmentError
        
        return self
            .mapError { Failure.upstream($0) }
            .flatMap { url -> AnyPublisher<Output, Failure> in
                return URLSession.shared.dataTaskPublisher(for: url)
                    .tryMap { (data, resp) -> Output in
                        guard let resp = resp as? HTTPURLResponse else {
                            throw Failure.upstream(ConnectionError.networkError("Bad response from fan."))
                        }
                        guard (200..<300).contains(resp.statusCode) else {
                            throw Failure.upstream(ConnectionError.networkError("Bad status code: \(resp.statusCode)"))
                        }
                        guard let decodedData = String(data: data, encoding: .ascii) else {
                            throw Failure.upstream(ConnectionError.decodeError("Failed to convert data to text, data length: \(data.count)"))
                        }
                        let tupleArray = decodedData
                            .filter({ !$0.isWhitespace })
                            .split(separator: "<")
                            .filter({ !$0.contains("/") && $0.contains(">") })
                            .map ({ $0.split(separator: ">", maxSplits: 1) })
                            .map ({ arr -> (String, String?) in
                                let newTuple = (String(arr[0]), arr.count == 2 ? String(arr[1]) : nil)
                                return newTuple
                            })
                        
                        let newDict = Dictionary(tupleArray, uniquingKeysWith: { (first, _) in first })

                        guard FanConnection.requiredKeys.isSubset(of: Set( newDict.keys.map({ String($0) }) )) else {
                            throw Failure.missingKeys
                        }

                        return newDict
                    }
                    .mapError { $0 as? Failure ?? Failure.cast($0) }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

extension Publisher where Output == String, Failure == ConnectionError {
    
    func parseFanResponse() -> AnyPublisher<Dictionary<String, String?>, AdjustmentError> {
        typealias Output = Dictionary<String, String?>
        typealias Failure = AdjustmentError
        return self
            .mapError { AdjustmentError.upstream($0) }
            .flatMap { retrievedString -> AnyPublisher<Output, Failure> in
                
                let tupleArray = retrievedString
                    .filter({ !$0.isWhitespace })
                    .split(separator: "<")
                    .filter({ !$0.contains("/") && $0.contains(">") })
                    .map ({ $0.split(separator: ">", maxSplits: 1) })
                    .map ({ arr -> (String, String?) in
                        let newTuple = (String(arr[0]), arr.count == 2 ? String(arr[1]) : nil)
                        return newTuple
                    })
                
                let newDict = Dictionary(tupleArray, uniquingKeysWith: { (first, _) in first })
                
                guard FanConnection.requiredKeys.isSubset(of: Set( newDict.keys.map({ String($0) }) )) else {
                    return Failure.missingKeys.publisher(valueType: Output.self)
                }
                return Just (newDict).setFailureType(to: Failure.self).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

extension Publisher where Output == FanModel.Action, Failure == Never {
    
    func updateFan (atIp ip: String) -> AnyPublisher<Dictionary<String,String?>, AdjustmentError> {
        typealias Output = Dictionary<String, String?>
        typealias Failure = AdjustmentError
        return self
            .getAdjustmentURL(for: ip)
            .adjustFan()
    }
}


//extension Publisher where Output == FanModel.Action, Failure == Never {
//    typealias Err = ConnectionError
//    typealias Val = Dictionary<String, String?>
//
//    func adjustFan (locatedAt baseUrl: URL) -> AnyPublisher<URLSession.DataTaskPublisher.Output, URLSession.DataTaskPublisher.Failure> {
//        return self
//            .setFailureType(to: URLError.self)
//            .flatMap { action -> AnyPublisher<URLSession.DataTaskPublisher.Output, URLSession.DataTaskPublisher.Failure> in
//                let url = baseUrl.appendingPathComponent("/fanspd.cgi?dir=\(action.rawValue)")
////                guard let urlStr = url.absoluteString.removingPercentEncoding, let finalURL = URL(string: urlStr) else { return Err.badUrl.publisher(valueType: Val.self) }
//                return URLSession.shared
//                    .dataTaskPublisher(for: URL(string: "www.yahoo.com")!)
////                    .eraseToAnyPublisher()
////                    .mapError { Err.cast(error: $0) }
////                    .setFailureType(to: Err.self)
//            }.eraseToAnyPublisher()
////            .flatMap { (data, resp) -> AnyPublisher<Any, Error> in
////                do {
////                    guard let resp = resp as? HTTPURLResponse else {
////                        throw Err.networkError("Unknown error")
////                    }
////                    guard (200..<300).contains(resp.statusCode) else {
////                        throw Err.networkError("Bad status code: \(resp.statusCode)")
////                    }
////                    guard let decodedData = String(data: data, encoding: .ascii) else {
////                        throw Err.decodeError("Failed to convert data to text, data length: \(data.count)")
////                    }
////
////                    let tupleArray = decodedData
////                        .filter({ !$0.isWhitespace })
////                        .split(separator: "<")
////                        .filter({ !$0.contains("/") && $0.contains(">") })
////                        .map ({ $0.split(separator: ">", maxSplits: 1) })
////                        .map ({ arr -> (String, String?) in
////                            let newTuple = (String(arr[0]), arr.count == 2 ? String(arr[1]) : nil)
////                            return newTuple
////                        })
////
////                    let newDict = Dictionary(tupleArray, uniquingKeysWith: { (first, _) in first })
////
////                    guard FanConnection.requiredKeys.isSubset(of: Set( newDict.keys.map({ String($0) }) )) else {
////                        throw Err.decodeError("Missing required fan parameters")
////                    }
////
////                    return Just(newDict)
////                        .setFailureType(to: Err.self)
////                        .eraseToAnyPublisher()
////
////                } catch let error as Err {
////                    return error.publisher(valueType: Val.self)
////                } catch {
////                    return Err.cast(error: error).publisher(valueType: Val.self)
////                }
////            }
////            .eraseToAnyPublisher()
//    }
//}
