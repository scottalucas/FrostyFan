//
//  House Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

class House {
    static var scanDuration: TimeInterval = 5.0
    var fanSet = Set<FanCharacteristics>() {
        didSet {
            fansRunning = fanSet.map({ $0.speed }).reduce(0, +) > 0
        }
    }
//    var scanning = false
    var fansRunning = false
    
//    func lowLevelScan ()
//    //    -> AsyncThrowingStream<FanCharacteristics, Error>
//    {
//    //        return AsyncThrowingStream<FanCharacteristics, Error> { continuation in
//    let hosts = NetworkAddress
//        .hosts
//        .appending("192.168.1.180:8080")
//    guard hosts.count > 0 else {
//        //                continuation.finish(throwing: ConnectionError.serverError("No hosts"))
//        return
//    }
//    let config = URLSession.shared.configuration
//    config.timeoutIntervalForRequest = House.scanDuration
//    scanning = true
//    fanSet.removeAll()
//    let session = URLSession.init(configuration: config)
//    Task {
//        do {
//            try await withThrowingTaskGroup(of: (IPAddr, Data?).self) { group in
//
//                group.addTask {
//                    try? await Task.sleep(interval: House.scanDuration + 2.0)
//                    throw ConnectionError.timeout
//                }
//
//                for ip in hosts {
//                    guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(FanModel.Action.refresh.rawValue)") else { continue }
//                    group.addTask {
//                        let d = try? await session.data(from: url).0
//                        return (ip, d)
//                    }
//                }
//
//                for try await (ipAddr, optData) in group {
//                    if let newData = optData, var chars = FanCharacteristics(data: newData) {
//                        guard !group.isCancelled else { print("group cancelled"); return }
//                        chars.ipAddr = ipAddr
//                        fanSet.update(with: chars)
//                        //                                continuation.yield(chars)
//                    }
//                }
//            }
//        } catch {
//            let e = (error as? ConnectionError) ?? ConnectionError.cast(error)
//            print ("Error in throwing task group \(e.description)")
//        }
//        scanning = false
//        //                continuation.finish()
//    }
//    //        }
//    }
}
//
//class HouseMonitor: ObservableObject {
//    static var shared = HouseMonitor()
//    @Published var scanning: Bool?
//    @Published var fansRunning = false
//    @Published var fanRPMs = Dictionary<String, Int>()
////    var scanDuration: Double = 15.0
//    //    var fansOperating: Bool {
//    //        return fanRPMs.values.reduce(false, { (last, next) in
//    //            if next != 0 { return true } else { return last }
//    //        })
//    //    }
//    private init () {}
//    
//    func updateOperationalStatus(forMacAddr macAddr: String, to: Int) {
//        //        fanRPMs.updateValue(to, forKey: macAddr)
//        //        fansRunning = fanRPMs.values.reduce(.zero, +) > 0
//        //        Task {
//        //            try? await WeatherMonitor.shared.updateWeatherConditions(loader: Weather.load)
//        //        }
//    }
//}
