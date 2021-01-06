//
//  Custom Operators.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 12/24/20.
//

import Foundation
import Combine
//
//extension Publisher where Output == FanModel.Action, Failure == Never {
//    
//    func adjustPhysicalFan(atNetworkAddr ip: String, retry: Bool = false) -> AnyPublisher<Dictionary<String,String?>, AdjustmentError> {
//        typealias Output = Dictionary<String,String?>
//        typealias Failure = AdjustmentError
//        
//        return self
//            .setFailureType(to: Failure.self)
//            .flatMap { action -> AnyPublisher<Output, Failure> in
//                guard let baseUrl = URL(string: "http://\(ip)"),
//                      let urlStr = baseUrl.appendingPathComponent("/fanspd.cgi?dir=\(action.rawValue)").absoluteString.removingPercentEncoding,
//                      let finalURL = URL(string: urlStr)
//                else { return AdjustmentError.upstream(ConnectionError.badUrl).publisher(valueType: Output.self) }
//                
//                return URLSession.shared.dataTaskPublisher(for: finalURL)
//                    .tryMap { (data, resp) -> Output in
//                        guard let resp = resp as? HTTPURLResponse else {
//                            throw Failure.upstream(ConnectionError.networkError("Bad response from fan."))
//                        }
//                        guard (200..<300).contains(resp.statusCode) else {
//                            throw Failure.upstream(ConnectionError.networkError("Bad status code: \(resp.statusCode)"))
//                        }
//                        guard let decodedData = String(data: data, encoding: .ascii) else {
//                            throw Failure.upstream(ConnectionError.decodeError("Failed to convert data to text, data length: \(data.count)"))
//                        }
//                        let tupleArray = decodedData
//                            .filter({ !$0.isWhitespace })
//                            .split(separator: "<")
//                            .filter({ !$0.contains("/") && $0.contains(">") })
//                            .map ({ $0.split(separator: ">", maxSplits: 1) })
//                            .map ({ arr -> (String, String?) in
//                                let newTuple = (String(arr[0]), arr.count == 2 ? String(arr[1]) : nil)
//                                return newTuple
//                            })
//                        
//                        let newDict = Dictionary(tupleArray, uniquingKeysWith: { (first, _) in first })
//
//                        guard FanModel.FanKey.requiredKeys.isSubset(of: Set( newDict.keys.map({ String($0) }) )) else {
//                            throw Failure.missingKeys
//                        }
//
//                        return newDict
//                    }
//                    .retry(retry ? 3 : 0)
//                    .mapError { $0 as? Failure ?? Failure.cast($0) }
//                    .eraseToAnyPublisher()
//            }
//            .eraseToAnyPublisher()
//    }
//}
