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
    @Published var fanSet = Set<FanCharacteristics>()
    @Published var displayedFanID: FanView.MACAddr = "not set"
    @Published var displayedRPM: Int = 0
    @Published var houseAlarm: Bool = false
    @Published var houseMessage: String?
    @Published var temperature: String?
    @Published var fansRunning = false
    @Published var scanUntil: Date = .distantPast
    private var bag = Set<AnyCancellable>()
//    static var scanDuration: TimeInterval = 15.0
    
    init () {
        Task {
            scanUntil = .now.addingTimeInterval( URLSessionMgr.shared.networkAvailable.value ? House.scanDuration : 1.0 )
            await scan( timeout: URLSessionMgr.shared.networkAvailable.value ? House.scanDuration : 1.0 )
            scanUntil = .distantPast
        }

        $fanSet
            .combineLatest($displayedFanID)
            .compactMap { (fanChars, id) in
                guard let chars = fanChars.first(where: { char in char.macAddr == id }), let levels = FanViewModel.speedTable[chars.airspaceFanModel] else { return nil }
                let speed = chars.speed
                return Int( 80.0  * (Double(speed) / Double(levels - 1) ) )
            }
            .assign(to: &$displayedRPM)
        
        $fanSet
            .map { $0.map({ $0.speed }).reduce(0, +) > 0 }
            .assign(to: &$fansRunning)
        
        Publishers
            .CombineLatest3 (
                WeatherMonitor.shared
                    .$tooHot
                    .prepend(false),
                WeatherMonitor.shared
                    .$tooCold
                    .prepend(false),
            $fansRunning
                    .prepend(false)
            )
            .map { (tooHot, tooCold, running) in
                if !(tooHot || tooCold) { return false }
                else if running { return true }
                else { return false }
            }
            .assign(to: &$houseAlarm)
        
        WeatherMonitor.shared.$currentTemp
            .compactMap {
                $0?.formatted(Measurement.FormatStyle.truncatedTemp)
            }
            .assign(to: &$temperature)
        
        URLSessionMgr.shared.networkAvailable
            .sink(receiveValue: {networkAvailable in
                if networkAvailable && self.fanSet.count == 0 {
                    Task { await self.scan() }
                } else if (!networkAvailable) {
                    self.fanSet.removeAll()
                }
            })
            .store(in: &bag)
        
        Publishers
            .CombineLatest4 (
                WeatherMonitor.shared.$tooHot
                    .prepend(false),
                WeatherMonitor.shared.$tooCold
                    .prepend(false),
                WeatherMonitor.shared.$currentTemp
                    .prepend(nil),
                URLSessionMgr.shared.networkAvailable
            )
            .map { (tooHot, tooCold, temp, networkAvailable) in
                if !networkAvailable {
                    return "Network unavailable"
                }
                guard let temp = temp else { return nil }
                if tooHot {
                    return "It's hot outside (\(temp.formatted(Measurement.FormatStyle.truncatedTemp))).\rTurn off fan?"
                } else if tooCold {
                    return "It's cold outside (\(temp.formatted(Measurement.FormatStyle.truncatedTemp))).\rTurn off fan?"
                } else {
                    return nil
                }
            }
            .assign(to: &$houseMessage)
    }
    
    func scan (timeout: TimeInterval = House.scanDuration) async {
//        print("scan started")
//        if !URLSessionMgr.shared.networkAvailable.value { print("network not available"); return }
        let hosts = NetworkAddress
            .hosts
            .appending("192.168.1.179:8080")
        guard hosts.count > 0 else { return }
        let sess = URLSessionMgr.shared.session
//        print("hosts count \(hosts.count)")
        fanSet.removeAll()
        scanUntil = .now.addingTimeInterval(timeout)
            do {
                try await withThrowingTaskGroup(of: (IPAddr, Data?).self) { group in
                    
                    group.addTask {
                        try? await Task.sleep(interval: timeout)
                        throw ConnectionError.timeout
                    }
                    for ip in hosts {
                        guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(FanModel.Action.refresh.rawValue)") else { continue }
                        group.addTask {
                            let d = try? await sess.data(from: url).0
                            return (ip, d)
                        }
                    }
                    
                    for try await (ipAddr, optData) in group {
                        do {
                            guard !group.isCancelled else { print("group cancelled"); return }
                            var chars = try FanCharacteristics(data: optData)
                            chars.ipAddr = ipAddr
                            fanSet.update(with: chars)
                        } catch {
                            if let err = error as? ConnectionError, case .timeout = err {
                                throw err
                            }
                        }
                    }
                }
            } catch {
//                print("Exited scan with error \((error as? ConnectionError)?.description ?? error.localizedDescription)")
            }
        scanUntil = .distantPast
//        print("scan finished")
    }
}

