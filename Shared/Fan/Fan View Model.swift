//
//  Fan Model View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//
/*
 The FanViewModel recieves fan updates and translates them into published characteristics used by the fan view.
 
 This makes heavy use of Combine publishers to process received updates from the fan model and the house model.
 
 Since fan speed or timer adjustments can take as long as 30 seconds, this class creates background tasks for potentially long-running steps that need to continue when the user navigates out of the app.
 */

import Foundation
import SwiftUI
import Combine
import Network

@MainActor
class FanViewModel: ObservableObject {
    private var model: FanModel
    private var houseStatus: HouseStatus
    var id: FanView.ID
    var id2 = UUID().uuidString
    @Published var selectorSegments: Int = 2
    @Published var currentMotorSpeed: Int? //as reported by the fan.
    
    @Published var scanUntil: Date = .distantPast //from HouseStatus.shared
    @Published var houseMessage: String? //from HouseStatus.shared
    @Published var houseTempAlarm: Bool = false //from HouseStatus.shared
    @Published var appInForeground = false
    @Published var indicatedAlarm: IndicatorOpacity.IndicatorBlink?
    @Published var offDateText: String?
    @Published var showTimerIcon = false
    @Published var showDamperWarning = false
    @Published var showInterlockWarning = false
    @Published var displayedRPM: Double = .zero
    var chars: FanCharacteristics
    private var fanMonitor: FanMonitor? //periodically checks fan status if the fan is in the foreground of the app.
//    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var bag = Set<AnyCancellable>()
    
    init (chars: FanCharacteristics, id: FanView.ID) {
        self.model = FanModel(usingChars: chars)
        self.id = id
        self.houseStatus = HouseStatus.shared
        self.chars = chars
        HouseStatus.shared.updateStatus(forFan: id, isOperating: chars.speed > 0)
        startSubscribers(initialChars: chars)
        Log.fan(chars.ipAddr).info("view model init \(self.id2) \(id)")
    }
    
    deinit {
        Log.fan(chars.ipAddr).info("view model deinit")
        fanMonitor?.stop()
    }
    
    convenience init () {
        let chars = FanCharacteristics()
        self.init(chars: chars, id: UUID.init().uuidString)
    }
    
    func setTimer (addHours hours: Int) {
        Task {
            let task = registerBackgroundTask("set timer")
            await model.setFan(addHours: hours)
            endBackgroundTask(task)
        }
    }
    
    func setSpeed (to spd: Int?) {
        guard let spd = spd else { return } //if the spd property isn't provided then exit
        Task {
            let task = registerBackgroundTask("set speed")
            await model.setFan(toSpeed: spd)
            endBackgroundTask(task)
        }
        
    }
    
    func refresh () async {
        await model.refresh()
    }

    private func registerBackgroundTask(_ name: String) -> UIBackgroundTaskIdentifier {
        Log.background.debug("Registered background task for \(name)")
        let backgroundTask = UIApplication.shared.beginBackgroundTask (withName: name)
        return backgroundTask
    }
    
    private func endBackgroundTask(_ id: UIBackgroundTaskIdentifier) {
        Log.background.debug("Ending background task for \(String(describing: id))")
        UIApplication.shared.endBackgroundTask(id)
    }
    
    private func startSubscribers(initialChars chars: FanCharacteristics) {
        
        houseStatus.$houseMessage
            .assign(to: &$houseMessage)
        
        houseStatus.$scanUntil
            .assign(to: &$scanUntil)
        
        houseStatus.$houseTempAlarm
            .assign(to: &$houseTempAlarm)

        houseStatus.$displayedFanID //this changes as the user flips between fans in a multi-fan house
            .map ({ $0 == self.id })
            .prepend(false)
            .combineLatest($appInForeground
                .prepend(false))
            .throttle(for: 1.0, scheduler: DispatchQueue.main, latest: true)
            .sink(receiveValue: { [weak self] (fanPresented, appInForeground) in
                if (fanPresented && appInForeground) {
                    guard let self = self else { return }
                    Task { await self.model.refresh () }
                    self.fanMonitor = nil
                    self.fanMonitor = .init(id: self.id, self.model.refresh)
                    self.fanMonitor?.start ()
                } else {
                    self?.fanMonitor?.stop ()
                    self?.fanMonitor = nil
                }
            })
            .store(in: &bag)
        
        model.fanCharacteristics
            .sink(receiveValue: { chars in
                self.chars = chars
            })
            .store(in: &bag)
        
        model.fanCharacteristics
            .prepend(chars)
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .map {
                $0.damper == .operating
            }
            .assign(to: &$showDamperWarning)
        
        Publishers.CombineLatest3 ( //handles the factors that govern whether a timer notification appears. Suppress the timer icon (which also prevents the user from making timer adjustments) whenever we can't handle a timer adjustment.
            model.motorContext
                .prepend( .standby )
                .map { $0 != .adjusting },
            model.timerContext
                .prepend ( .standby )
                .map { $0 != .adjusting },
            model.fanCharacteristics
                .prepend(chars)
                .map { $0.speed > 0 }
        )
        .map { $0 && $1 && $2 }
        .removeDuplicates()
        .receive(on: DispatchQueue.main)
        .assign(to: &$showTimerIcon)
        
        model.fanCharacteristics
            .prepend(chars)
            .map { $0.speed }
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentMotorSpeed)
        
        model.fanCharacteristics
            .prepend(chars)
            .receive(on: DispatchQueue.main)
            .map { $0.speed }
            .sink(receiveValue: { [weak self] spd in
                guard let self = self else { return }
                HouseStatus.shared.updateStatus(forFan: self.id, isOperating: spd > 0)
            })
            .store(in: &bag)
        
        model.fanCharacteristics
            .prepend(chars)
            .receive(on: DispatchQueue.main)
            .map { $0.interlock1 || $0.interlock2 }
            .sink(receiveValue: { [weak self] interlocked in
                guard let self = self else { return }
                self.showInterlockWarning = interlocked
                if !interlocked { Storage.suppressInterlockWarning.remove(self.chars.ipAddr) }
            })
            .store(in: &bag)

        model.fanCharacteristics
            .prepend(chars)
            .receive(on: DispatchQueue.main)
            .compactMap { chars -> (speed: Int, levels: Int)? in
                guard
                    let levels = FanViewModel.speedTable[String(chars.airspaceFanModel.prefix(4))] else { return nil }
                return (chars.speed, levels) }
            .removeDuplicates(by: { ($0.0 == $1.0) && ($0.1 == $1.1) })
            .map {
                60.0 * (Double($0.speed) / max( 1.0, Double($0.levels - 1) ) )
            }
            .assign(to: &$displayedRPM)
        
        model.fanCharacteristics
            .prepend (chars)
            .receive(on: DispatchQueue.main)
            .map { $0.timer }
            .map { timeTillOff in
                guard timeTillOff > 0 else { return nil }
                let offDate = Date(timeIntervalSinceNow: Double(timeTillOff) * 60.0)
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return "Off at \(formatter.string(from: offDate))"
            }
            .assign(to: &$offDateText)
        
        model.fanCharacteristics //the app supports a number of fan models that have different available speed levels. This receiver processes the fan model number and publishes the appropriate number of available speeds. Used to build the segmented controller.
            .prepend(chars)
            .receive(on: DispatchQueue.main)
            .map { $0.airspaceFanModel }
            .map { String($0.prefix(4)) }
            .map { FanViewModel.speedTable[$0] ?? 1 }
            .map { $0 + 1 }
            .assign(to: &$selectorSegments)
    }
}
/*
 The NoFanViewModel is needed when no fans are found during a scan for fans.
 */
@MainActor
class NoFanViewModel: ObservableObject {
    @Published var scanUntil: Date = .distantPast //from Notification
    @Published var houseMessage: String? //from Notification
    private var houseStatus: HouseStatus
    
    init ( ) {
        Log.fan("no fan").info("no fan view model init")
        houseStatus = HouseStatus.shared
        houseStatus.$houseMessage
            .assign(to: &$houseMessage)
        
        houseStatus.$scanUntil
            .assign(to: &$scanUntil)
    }
}

class FanMonitor { // periodically interrogates the fan to provide current status information. This class includes the ability to stop checking, which happens when the fan view is inactive.
    private var id: String
    private var task: Task<(), Never>?
    private var refresh: () async throws -> FanCharacteristics?
    
    deinit {
        task?.cancel()
        task = nil
        Log.fan(id).debug("fan monitor deinit")
    }
    
    init (id: String, _ refresher: @escaping () async throws -> FanCharacteristics? ) {
        Log.fan(id).info("fan monitor init")
        self.id = id
        refresh = refresher
    }
    
    fileprivate func start () {
        let interval = TimeInterval( 5 * 60 ) //5 minute loop interval
        if let t = task, !t.isCancelled { return }
        stop()
        Log.fan(id).info("fan monitor loop start")
        task = Task {
            while true {
                do {
                    Log.fan(id).info("fan monitor loop")
                    try await Task.sleep(interval: interval) //run the loop every 5 minutes to respond as conditions change
                    guard let t = task, !t.isCancelled else { throw BackgroundTaskError.taskCancelled }
                    let _ = try await refresh ()
                } catch {
                    break
                }
            }
            stop()
        }
    }
    
    fileprivate func stop () {
        Log.fan(id).info("fan monitor loop kill")
        task?.cancel()
        task = nil
    }
}

class TestFanViewModel: ObservableObject {
    var model: FanModel
    var fanCharacteristics: FanCharacteristics
    
    init (chars: FanCharacteristics) {
        self.model = FanModel(usingChars: chars)
        self.fanCharacteristics = chars
    }
}

extension FanViewModel {
    static var speedTable: [String:Int]  = [
        "3.5e" : 7,
        "4.4e" : 7,
        "5.0e" : 7,
        "2.5e" : 5,
        "3200" : 10,
        "3400" : 10,
        "4300" : 10,
        "5300" : 10
    ]
}

extension FanViewModel {
    struct SpeedUpdate: Hashable {
        var id: MACAddr
        var speed: Int
        var levels: Int
    }
}
