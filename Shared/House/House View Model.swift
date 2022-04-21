//
//  House View Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine
import os

@MainActor
class HouseViewModel: ObservableObject {
    @Published var fanSet: Set<FanView>

    private var bag = Set<AnyCancellable>()
    init (initialFans: Set<FanCharacteristics>) {
        fanSet = []
        Log.house.info("view model init")
        Task {
            Log.house.debug("Scanning in houseviewmodel init")
            Log.house.debug("\(Storage.knownFans)")
            await scan ( Set<String>.init(["192.168.1.179:8080", "192.168.1.180:8080"]), timeout: URLSessionMgr.shared.networkAvailable.value ? House.scanDuration : 1.0 )
//            await scan ( Storage.knownFans, timeout: URLSessionMgr.shared.networkAvailable.value ? House.scanDuration : 1.0 )
        }

        WeatherMonitor.shared.$tooHot.prepend(false)
            .combineLatest(WeatherMonitor.shared.$tooCold.prepend(false))
            .receive(on: DispatchQueue.main)
            .map { (tooHot, tooCold) in
                if !(tooHot || tooCold) { return false }
                else { return HouseStatus.shared.fansRunning }
            }
            .assign(to: &HouseStatus.shared.$houseTempAlarm)
        
//        URLSessionMgr.shared.networkAvailable
//            .receive(on: DispatchQueue.main)
//            .sink(receiveValue: { networkAvailable in
//                if networkAvailable && self.fanSet.count == 0 {
//                    Task {
//                        Log.house.debug("scanning in network available change")
//                        await self.scan(Storage.knownFans) }
//                } else if (!networkAvailable) {
//                    self.fanSet.removeAll()
//                }
//            })
//            .store(in: &bag)
        
        Publishers
            .CombineLatest4 (
                WeatherMonitor.shared.$tooHot
                    .prepend(false),
                WeatherMonitor.shared.$tooCold
                    .prepend(false),
                WeatherMonitor.shared.$currentTemp
                    .prepend(nil),
                URLSessionMgr.shared.networkAvailable
                    .prepend(true)
            )
            .receive(on: DispatchQueue.main)
            .map { (tooHot, tooCold, temp, networkAvailable) in
                if !networkAvailable {
                    return "Network unavailable"
                }
                guard temp != nil, HouseStatus.shared.fansRunning else { return nil }
                if tooHot {
                    return "It's hot outside.\rTurn off fan?"
                } else if tooCold {
                    return "It's cold outside.\rTurn off fan?"
                } else {
                    return nil
                }
            }
            .prepend ("Checking for known fans, \rplease wait...")
            .assign(to: &HouseStatus.shared.$houseMessage)
    }
    
    func scan (_ hostList: Set<String>, timeout: TimeInterval = House.scanDuration) async {
//        print("scan started")
//        if !URLSessionMgr.shared.networkAvailable.value { print("network not available"); return }
        
        let allHosts = NetworkAddress
            .hosts
            .appending("192.168.1.179:8080")
            .appending("192.168.1.180:8080")
        
        let hosts = hostList.count == 0 ? Set(allHosts) : hostList
        
        let sess = URLSessionMgr.shared.session
        Log.house.info ("scanning \(hosts.count) hosts")
        fanSet.removeAll()
        HouseStatus.shared.clearFans()
        Storage.knownFans = []
        HouseStatus.shared.scanUntil(.now.addingTimeInterval(timeout))
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
                            fanSet.update(with: FanView(initialCharacteristics: chars))
                            Storage.knownFans.update(with: ipAddr)
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
        HouseStatus.shared.scanUntil(.distantPast)
//        print("scan finished")
    }
}

@MainActor
class HouseStatus: ObservableObject {
    static var shared = HouseStatus()
    @Published var displayedFanID: FanView.ID = ""
    @Published var fansOperating: Bool = false
    @Published var houseTempAlarm: Bool = false
    @Published var houseMessage: String?
    @Published var scanUntil: Date = .distantPast
    private var _fansRunning: [FanView.ID : Bool] = [:]
    var fansRunning: Bool {
        _fansRunning.values.contains(where: { $0 })
    }
    func updateStatus ( forFan fan: FanView.ID, isOperating operating: Bool) {
        _fansRunning[fan] = operating
    }
    func scanUntil(_ date: Date) {
            scanUntil = date
    }
    func clearFans () { _fansRunning.removeAll() }
    private init () {
        Log.house.info("house status init")
    }
}
