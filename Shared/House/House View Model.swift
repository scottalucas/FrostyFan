//
//  House View Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

class HouseViewModel: ObservableObject {
    //    @Published var fanChars = Set<FanCharacteristics>()
    typealias IPAddr = String
    @Published var fanSet = Set<FanCharacteristics>()
    @Published var displayedFanID: FanView.MACAddr = "not set"
    @Published var displayedRPM: Int = 0
    @Published var useAlarmColor: Bool = false
    @Published var fansRunning = false
    @Published var scanUntil: Date = .distantPast
//    static var scanDuration: TimeInterval = 15.0
    private var bag = Array<AnyCancellable>()
    
    
    init () {
        //        fanViews = Set( initialFans.map { FanView( initialCharacteristics: $0 ) } )
        //        fanChars = initialFans
        Task {
            scanUntil = .now.addingTimeInterval(House.scanDuration)
            await scan(timeout: House.scanDuration)
            scanUntil = .distantPast
        }

        $fanSet
            .combineLatest($displayedFanID)
            .map { (fanChars, id) in (fanChars.first(where: { $0.macAddr == id })?.speed) ?? 0 }
            .assign(to: &$displayedRPM)
        
        $fanSet
            .map { $0.map({ $0.speed }).reduce(0, +) > 0 }
            .assign(to: &$fansRunning)
        
        $fansRunning
            .map {
                $0 && (WeatherMonitor.shared.tooHot || WeatherMonitor.shared.tooCold)
            }
            .assign(to: &$useAlarmColor)
    }
    
    func scan (timeout: TimeInterval = House.scanDuration) async {
        print("scan started")
        let hosts = NetworkAddress
            .hosts
            .appending("192.168.1.180:8080")
        guard hosts.count > 0 else { return }
        let config = URLSession.shared.configuration
        config.timeoutIntervalForRequest = House.scanDuration
        fanSet.removeAll()
        scanUntil = .now.addingTimeInterval(timeout)
        let session = URLSession.init(configuration: config)
            do {
                try await withThrowingTaskGroup(of: (IPAddr, Data?).self) { group in
                    
                    group.addTask {
                        try? await Task.sleep(interval: timeout)
                        throw ConnectionError.timeout
                    }
                    
                    for ip in hosts {
                        guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(FanModel.Action.refresh.rawValue)") else { continue }
                        group.addTask {
                            let d = try? await session.data(from: url).0
                            return (ip, d)
                        }
                    }
                    
                    for try await (ipAddr, optData) in group {
                        if let newData = optData, var chars = FanCharacteristics(data: newData) {
                            guard !group.isCancelled else { print("group cancelled"); return }
                            chars.ipAddr = ipAddr
                            fanSet.update(with: chars)
                        }
                    }
                }
            } catch { }
        scanUntil = .distantPast
        print("scan finished")
    }
    
    //    func scan () async throws {
    //        guard !(HouseMonitor.shared.scanning ?? false) else { return }
    //        print("Scanning...")
    //        dataSource.lowLevelScan()
    ////        fanChars.removeAll()
    //        do {
    //            for try await item in dataSource.lowLevelScan() {
    ////                let fView = FanView(initialCharacteristics: item)
    //                fanChars.update(with: item)
    //                displayedFanID = item.macAddr
    //            }
    //        } catch {
    //            print(error)
    //            HouseMonitor.shared.scanning = false
    //        }
    //    }
}
