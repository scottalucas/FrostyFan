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
    private var sharedHouseData = SharedHouseData.shared
    private var timeToFinish: Date?
    private var percentHostsChecked: Double?
    private var finishTimer: Timer?
    
    func scan () -> AsyncThrowingStream<FanCharacteristics, Error> {
        return AsyncThrowingStream<FanCharacteristics, Error> { continuation in
            Task {
                var hosts = NetworkAddress.hosts
                hosts.append("192.168.1.67:8080")
                let totalHosts = Double(hosts.count)
                guard totalHosts > 0 else { continuation.finish(throwing: ConnectionError.serverError("No hosts")) ; return }
                var checkedHosts = Double.zero
                
                sharedHouseData.updateProgress = 0.0
                
                let config = URLSession.shared.configuration
                config.timeoutIntervalForRequest = 5
                let session = URLSession.init(configuration: config)
                
                timeToFinish = Date() + config.timeoutIntervalForRequest
                
                DispatchQueue.main.async {
                    self.finishTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self, ttf = self.timeToFinish, dur = session.configuration.timeoutIntervalForRequest] _ in
                        guard let self = self else { return }
                        guard let ttf = ttf else { self.sharedHouseData.updateProgress = nil; return }
                        let percentTimeLeft = (ttf.timeIntervalSinceReferenceDate - Date().timeIntervalSinceReferenceDate) / dur
                        guard (0...1) ~= percentTimeLeft else { self.sharedHouseData.updateProgress = nil; return }
                        self.sharedHouseData.updateProgress = max(self.percentHostsChecked ?? 0.0, 1.0 - percentTimeLeft)
                    }
                }
                
                await withTaskGroup(of: (IPAddr, Data?).self) { [hosts] group in
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
                finishTimer?.invalidate()
                finishTimer = nil
                sharedHouseData.updateProgress = nil
                continuation.finish()
            }
        }
    }
}

class SharedHouseData: ObservableObject {
    enum FaultLevel { case major, minor, none }
    static var shared = SharedHouseData()
    @Published var updateProgress: Double?
    @Published var fault = FaultLevel.none
    @Published var alarmLevel = FaultLevel.none
    @Published var useAlarmColor = false
    @Published var temperature: Double?
    @Published var showTempOutOfRangeWarning = false
    private init () {}
}

    
    //extension House: HouseDataSource {}
    //
    //protocol HouseDataSource: ObservableObject {
    //    var fanSet: Set<FanCharacteristics> { get }
    //    var scan: () async -> Void { get }
    //}
