//
//  House View Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//
/*
 The HouseViewModel manages discovered fans, scanning activities, and status events that are house-wide.
 */

import Foundation
import SwiftUI
import Combine
import BackgroundTasks
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
            await scan ( Storage.knownFans )
        }
    }
    
    func scan (_ hostList: Set<String>) async { //scanning uses async task groups to publish discovered fans while scanning is still happening (rather than presenting all discovered fans at once, after the scan completes). The function stores discovered fans for quick initialization when the app opens or is moved to the foreground.
        Log.house.info("Scanning for fans")
        let allHosts = NetworkAddress
            .hosts
            .appending("192.168.1.219:8080")
        //            .appending("192.168.1.180:8080")
        
        let hosts = hostList.count == 0 ? Set(allHosts) : hostList
        let timeout = hosts.count > 5 ? 30.0 : 5.0
        let sess = URLSessionMgr.shared.session
        Log.house.info ("scanning \(hosts.count) hosts from \(hostList.count > 0 ? "saved hosts" : "all hosts")")
        fanSet.removeAll()
        Storage.clear(.suppressInterlockForFans)
        Storage.clear(.knownFans)
        HouseStatus.shared.clearFans()
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
                        guard !group.isCancelled else { throw ConnectionError.other("Scan task cancelled") }
                        var chars = try FanCharacteristics(data: optData)
                        chars.ipAddr = ipAddr
                        fanSet.update(with: FanView(initialCharacteristics: chars))
                        Storage.knownFans.update(with: ipAddr)
                    } catch (let err as ConnectionError) { // there will be lots of errors in this section as network device connection attempts fail. We only want to handle the timeout.
                        if case .timeout = err {
                            throw err
                        }
                    } catch { }
                }
            }
        } catch (let err as ConnectionError) {
            Log.network.error("Error during scan \(err.description)")
        } catch {
            Log.network.fault("Error during scan \(error.localizedDescription, privacy: .public)")
        }
        HouseStatus.shared.scanUntil(.distantPast)
        Log.network.info("Scan complete")
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
    private var _fansInterlocked: [FanView.ID : Bool] = [:]
    
    var fansRunning: Bool {
        _fansRunning.values.contains(where: { $0 })
    }
    var fansInterlocked: Bool {
        _fansInterlocked.values.contains(where: { $0 })
    }
    func updateStatus ( forFan fan: FanView.ID, isOperating operating: Bool) {
        _fansRunning[fan] = operating
        fansOperating = fansRunning
    }
//    func updateStatus ( forFan fan: FanView.ID, isInterlocked interlocked: Bool) {
//        _fansInterlocked[fan] = interlocked
//    }
    func scanUntil(_ date: Date) {
        scanUntil = date
    }
    func clearFans () {
        _fansRunning.removeAll()
        _fansInterlocked.removeAll()
    }
    
    static func knownFanOperating () async -> Bool {
        let hosts = Storage.knownFans
        var operating = false
        guard hosts.count > 0 else { return false }
        let sess = URLSessionMgr.shared.session
        sess.configuration.timeoutIntervalForRequest = 5.0
        sess.configuration.waitsForConnectivity = true
        sess.configuration.allowsCellularAccess = false
        sess.configuration.allowsExpensiveNetworkAccess = false
        do {
            try await withThrowingTaskGroup(of: Data?.self) { group in
                
                group.addTask {
                    try? await Task.sleep(interval: 20.0)
                    throw ConnectionError.timeout
                }
                for ip in hosts {
                    guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(FanModel.Action.refresh.rawValue)") else { continue }
                    group.addTask {
                        let d = try? await sess.data(from: url).0
                        return (d)
                    }
                }
                
                for try await (optData) in group {
                    do {
                        guard !group.isCancelled else { throw ConnectionError.other("Refresh All task cancelled") }
                        let chars = try FanCharacteristics(data: optData)
                        if chars.speed > 0 { operating = true }
                    } catch (let err as ConnectionError) { // there will be lots of errors in this section as network device connection attempts fail. We only want to handle the timeout.
                        if case .timeout = err {
                            throw err
                        }
                    } catch { }
                }
            }
        } catch (let err as ConnectionError) {
            Log.network.error("Error during scan \(err.description)")
        } catch {
            Log.network.fault("Error during scan \(error.localizedDescription, privacy: .public)")
        }
        return operating
    }
    
    private init () {
        Log.house.info("house status init")

//        WeatherMonitor.shared.$tooHot.prepend(false)
//            .combineLatest(WeatherMonitor.shared.$tooCold.prepend(false))
//
//
        Publishers
            .CombineLatest3(
                WeatherMonitor.shared.$tooHot,
                WeatherMonitor.shared.$tooCold,
                $fansOperating
            )
            .receive(on: DispatchQueue.main)
            .map { (tooHot, tooCold, operating) in
                ((tooHot || tooCold) && operating)
            }
            .assign(to: &$houseTempAlarm)
        
        
        Publishers
            .CombineLatest4 (
                WeatherMonitor.shared.$tooHot
                    .combineLatest(WeatherMonitor.shared.$tooCold)
                    .prepend((false, false)),
                WeatherMonitor.shared.$currentTemp
                    .prepend(nil),
                URLSessionMgr.shared.networkAvailable
                    .prepend(true),
                $fansOperating
                    .prepend(false)
            )
            .receive(on: DispatchQueue.main)
            .map { (tooHotTooColdTuple, temp, networkAvailable, operating) in
                let (tooHot, tooCold) = tooHotTooColdTuple
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
            .assign(to: &$houseMessage)
    }
}

