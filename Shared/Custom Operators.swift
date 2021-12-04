//
//  Custom Operators.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 12/24/20.
//

import Foundation
import Combine
import SwiftUI
import CoreLocation

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

public struct AnyShape: Shape {
    public var make: (CGRect, inout Path) -> ()

    public init(_ make: @escaping (CGRect, inout Path) -> ()) {
        self.make = make
    }

    public init<S: Shape>(_ shape: S) {
        self.make = { rect, path in
            path = shape.path(in: rect)
        }
    }

    public func path(in rect: CGRect) -> Path {
        return Path { [make] in make(rect, &$0) }
    }
}

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

extension Shape {
    func eraseToAnyShape () -> AnyShape {
        return AnyShape(self)
    }
}

extension Array where Element == (String, String?) {
    var jsonData: Data {
        let newDict = Dictionary(self, uniquingKeysWith: { (first, _) in first })
        guard let data = try? JSONSerialization.data(withJSONObject: newDict) else {
            return Data()
        }
        return data
    }
}

extension Publisher {
    func asyncMap<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Publishers.FlatMap<Future<T, Never>, Self> {
        flatMap { value in
            Future { promise in
                Task {
                    let output = await transform(value)
                    promise(.success(output))
                }
            }
        }
    }
}

extension Publisher {
    func asyncMap<T>(
        _ transform: @escaping (Output) async throws -> T
    ) -> Publishers.FlatMap<Future<T, Error>, Self> {
        flatMap { value in
            Future { promise in
                Task {
                    do {
                        let output = try await transform(value)
                        promise(.success(output))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }
    }
}

extension Publisher {
    func asyncMap<T>(
        _ transform: @escaping (Output) async throws -> T
    ) -> Publishers.FlatMap<Future<T, Error>,
                            Publishers.SetFailureType<Self, Error>> {
                                flatMap { value in
                                    Future { promise in
                                        Task {
                                            do {
                                                let output = try await transform(value)
                                                promise(.success(output))
                                            } catch {
                                                promise(.failure(error))
                                            }
                                        }
                                    }
                                }
                            }
}

extension Task where Success == Never, Failure == Never {
    static func sleep (interval: TimeInterval) async throws {
        let nanoSeconds = UInt64 ( interval * 1_000_000_000 )
        try await Task.sleep(nanoseconds: nanoSeconds)
    }
}

extension Data {
    var decodeTemperature: Measurement<UnitTemperature>? {
        let decoder = PropertyListDecoder()
        return try? decoder.decode(Measurement.self, from: self)
    }
}

extension Data {
    var decodeCoordinate: Coordinate? {
        let decoder = PropertyListDecoder()
        return try? decoder.decode(Coordinate.self, from: self)
    }
}

extension Data {
    var decodeDate: Date? {
        let decoder = PropertyListDecoder()
        return try? decoder.decode(Date.self, from: self)
    }
}

extension Measurement {
    var data: Data? {
        let encoder = PropertyListEncoder()
        return try? encoder.encode(self)
    }
}

struct Coordinate: Codable {
    var lat: Double
    var lon: Double
}

extension CLLocation {
    var data: Data? {
        let encoder = PropertyListEncoder()
        let coord = Coordinate(lat: self.coordinate.latitude, lon: self.coordinate.longitude)
        return try? encoder.encode(coord)
    }
}

extension Date {
    var data: Data? {
        let encoder = PropertyListEncoder()
        return try? encoder.encode(self)
    }
}

//
//extension Task {
//    static func sleep(seconds: Double) async throws {
//        let duration = UInt64(seconds * 1_000_000_000)
//        try await Task.sleep(nanoseconds: duration)
//    }
//}

//
//extension Lamps: RawRepresentable {
//    public typealias RawValue = Int
//    public init(rawValue: Int) {
//        var retValue = Lamps()
//        for (index, alert) in Lamps.allCases.enumerated() {
//            let mask = 2^index
//            if mask | rawValue > 0 { retValue.insert(alert) }
//        }
//        self = retValue
//    }
//}
//
//extension View {
//    @ViewBuilder
//    func ifLet<V, Transform: View>(
//        _ value: V?,
//        transform: (Self, V) -> Transform
//    ) -> some View {
//        if let value = value {
//            transform(self, value)
//        } else {
//            self
//        }
//    }
//}

/* CALL SITE
 var body: some view {
   myView
     .ifLet(optionalColor) { $0.foregroundColor($1) }
 }
 */
 
// extension View {
//   @ViewBuilder
//   func `if`<Transform: View>(
//     _ condition: Bool,
//     transform: (Self) -> Transform
//   ) -> some View {
//     if condition {
//       transform(self)
//     } else {
//       self
//     }
//   }
// }

/* CALL SITE
 var body: some view {
   myView
     .if(X) { $0.padding(8) }
     .if(Y) { $0.background(Color.blue) }
 }
 */

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
