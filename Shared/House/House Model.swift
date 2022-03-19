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
    typealias IPAddr = String
    private var sharedHouseData = HouseMonitor.shared
    private var percentHostsChecked: Double?
    private var finishTimer: Timer?
    
    func scan () -> AsyncThrowingStream<FanCharacteristics, Error> {
        return AsyncThrowingStream<FanCharacteristics, Error> { continuation in
            sharedHouseData.scanning = true
            Task {
                let hosts = NetworkAddress.hosts
                let totalHosts = Double(hosts.count)
                guard totalHosts > 0 else { continuation.finish(throwing: ConnectionError.serverError("No hosts")) ; return }
                var checkedHosts = Double.zero
                let config = URLSession.shared.configuration
                config.timeoutIntervalForRequest = sharedHouseData.scanDuration
                let session = URLSession.init(configuration: config)
                await withTaskGroup(of: (IPAddr, Data?).self) { group in
                    for ip in hosts {
                        guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(FanModel.Action.refresh.rawValue)") else { continue }
                        group.addTask {
                            let d = try? await session.data(from: url).0
                            return (ip, d)
                        }
                    }
                    for await (ipAddr, optData) in group {
                        checkedHosts += 1
                        percentHostsChecked = ( checkedHosts / totalHosts )
                        if let newData = optData, var chars = FanCharacteristics(data: newData) {
                            chars.ipAddr = ipAddr
                            continuation.yield(chars)
                        }
                    }
                }
                sharedHouseData.scanning = false
                continuation.finish()
            }
        }
    }
}

class HouseMonitor: ObservableObject {
    enum FaultLevel { case major, minor, none }
    static var shared = HouseMonitor()
    var scanDuration: Double = 5.0
    @Published var scanning = false
    @Published var fanRPMs = Dictionary<String, Int>()
    var fansOperating: Bool {
        return fanRPMs.values.reduce(false, { (last, next) in
            if next != 0 { return true } else { return last }
        })
    }
    private init () {}
    
    func updateOperationalStatus(forMacAddr macAddr: String, to: Int) {
        fanRPMs.updateValue(to, forKey: macAddr)
    }
}
