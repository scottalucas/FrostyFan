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
    @Published var fanSet = Set<FanView>()
    private var fansRunning: Bool {
        fanSet.reduce(false, { $0 || $1.viewModel.displayedRPM > 0 })
    }
    private var bag = Set<AnyCancellable>()
    
    init (initialFans: Set<FanCharacteristics>) {
        Task {
            await scan( timeout: URLSessionMgr.shared.networkAvailable.value ? House.scanDuration : 1.0 )
        }

        WeatherMonitor.shared.$tooHot.prepend(false)
            .combineLatest(WeatherMonitor.shared.$tooCold.prepend(false))
            .map { [weak self] (tooHot, tooCold) in
                if !(tooHot || tooCold) { return false }
                else { return self?.fansRunning ?? false }
            }
            .assign(to: &HouseStatus.shared.$houseTempAlarm)
        
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
                    .prepend(true)
            )
            .map { (tooHot, tooCold, temp, networkAvailable) in
                if !networkAvailable {
                    return "Network unavailable"
                }
                guard temp != nil else { return nil }
                if tooHot {
                    return "It's hot outside.\rTurn off fan?"
                } else if tooCold {
                    return "It's cold outside.\rTurn off fan?"
                } else {
                    return nil
                }
            }
            .prepend ("Publisher")
            .assign(to: &HouseStatus.shared.$houseMessage)
    }
    
    func scan (timeout: TimeInterval = House.scanDuration) async {
//        print("scan started")
//        if !URLSessionMgr.shared.networkAvailable.value { print("network not available"); return }
        let hosts = NetworkAddress
            .hosts
            .appending("192.168.1.180:8080")
        guard hosts.count > 0 else { return }
        let sess = URLSessionMgr.shared.session
//        print("hosts count \(hosts.count)")
        fanSet.removeAll()
        HouseStatus.shared.scanUntil = .now.addingTimeInterval(timeout)
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
                            let _ = DispatchQueue.main.sync { [chars] in
                                fanSet.update(with: FanView(initialCharacteristics: chars))
                            }
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
        HouseStatus.shared.scanUntil = .distantPast
//        print("scan finished")
    }
}

class HouseStatus: ObservableObject {
    @Published var displayedFanID: FanView.ID = ""
    @Published var houseTempAlarm: Bool = false
    @Published var houseMessage: String?
    @Published var scanUntil: Date = .distantPast
    static var shared = HouseStatus()
    private init () {
        houseMessage = "Init"
    }
}
