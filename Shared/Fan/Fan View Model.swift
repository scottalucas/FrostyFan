//
//  Fan Model View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

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
    @Published var currentMotorSpeed: Int?
    
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

    var chars: FanCharacteristics {
        model.fanCharacteristics.value
    }
    private var fanMonitor: FanMonitor?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var bag = Set<AnyCancellable>()
    
    init (chars: FanCharacteristics, id: FanView.ID) {
//        currentMotorSpeed = chars.speed
        self.model = FanModel(usingChars: chars)
        self.id = id
        self.houseStatus = HouseStatus.shared
        HouseStatus.shared.updateStatus(forFan: id, isOperating: chars.speed > 0)
//        fanMonitor = FanMonitor (id: model.id, model.refresh)
        startSubscribers(initialChars: chars)
        Log.fan.info("view model init \(self.id2) \(id)")
    }
    
    deinit {
        Log.fan.info("view model deinit")
        //        print("Deinit fan view model \(model.fanCharacteristics.value.macAddr)")
        fanMonitor?.stop()
    }
    
    convenience init () {
        let chars = FanCharacteristics()
        self.init(chars: chars, id: UUID.init().uuidString)
    }
    
    func setTimer (addHours hours: Int) {
        Task {
            registerBackgroundTask("set timer")
            await model.setFan(addHours: hours)
            endBackgroundTask()
        }
    }
    
    func setSpeed (to spd: Int?) {
        guard let spd = spd else { return }
        Task {
            registerBackgroundTask("set speed")
            await model.setFan(toSpeed: spd)
            endBackgroundTask()
        }
    }
    //
    //    func transition (foreground: Bool) {
    //        if (focus && foreground) {
    //            model.refresh ()
    //            fanMonitor.start ()
    //        } else {
    //            fanMonitor.stop()
    //        }
    //    }
    
    private func registerBackgroundTask(_ name: String) {
        Log.background.debug("Registered background task for \(name)")
        backgroundTask = UIApplication.shared.beginBackgroundTask (withName: name) { [weak self] in
            Log.background.debug("Timeout background task for \(name)")

            self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }
    
    private func endBackgroundTask() {
        Log.background.debug("Ending background task for \(String(describing: self.backgroundTask))")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    private func startSubscribers(initialChars chars: FanCharacteristics) {
        
        houseStatus.$houseMessage
//            .prepend("Nothing yet")
            .assign(to: &$houseMessage)
        
        houseStatus.$scanUntil
            .assign(to: &$scanUntil)
        
        houseStatus.$houseTempAlarm
            .assign(to: &$houseTempAlarm)

        houseStatus.$displayedFanID
            .map ({ $0 == self.id })
            .prepend(false)
            .combineLatest($appInForeground
                .prepend(false))
            .throttle(for: 1.0, scheduler: DispatchQueue.main, latest: true)
            .sink(receiveValue: { [weak self] (fanPresented, appInForeground) in
                if (fanPresented && appInForeground) {
                    guard let self = self else { return }
                    self.model.refresh ()
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
            .prepend(chars)
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .map {
                $0.damper == .operating
            }
            .assign(to: &$showDamperWarning)
        
        model.fanCharacteristics
            .prepend(chars)
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .map {
                $0.interlock2 || $0.interlock1
            }
            .assign(to: &$showInterlockWarning)
        
        Publishers.CombineLatest3 (
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
            .compactMap { chars -> (speed: Int, levels: Int)? in
                guard
                    let levels = FanViewModel.speedTable[String(chars.airspaceFanModel.prefix(4))] else { return nil }
                return (chars.speed, levels) }
            .removeDuplicates(by: { ($0.0 == $1.0) && ($0.1 == $1.1) })
            .map {
                60.0 * (Double($0.speed) / max( 1.0, Double($0.levels - 1) ) )
            }
//            .print("\r\rrpm pub")
            .assign(to: &$displayedRPM)
//            .sink(receiveValue: { [weak self] val in
//                self?.displayedRPM.send(val)
//            })
//            .store(in: &bag)
//
//        Publishers
//            .CombineLatest3 (
//                model.fanCharacteristics
//                    .prepend(chars)
//                    .map { $0.speed }
//                    .map { $0 > 0 },
//                WeatherMonitor.shared.$tooCold
//                    .prepend (false),
//                WeatherMonitor.shared.$tooHot
//                    .prepend (false)
//            )
//            .receive(on: DispatchQueue.main)
//            .map { $0 && ( $1 || $2) }
//            .assign(to: &$showTemperatureWarning)
        
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
        
        model.fanCharacteristics
            .prepend(chars)
            .receive(on: DispatchQueue.main)
            .map { $0.airspaceFanModel }
            .map { String($0.prefix(4)) }
            .map { FanViewModel.speedTable[$0] ?? 1 }
            .map { $0 + 1 }
            .assign(to: &$selectorSegments)
    }
}

@MainActor
class NoFanViewModel: ObservableObject {
    @Published var scanUntil: Date = .distantPast //from Notification
    @Published var houseMessage: String? //from Notification
    private var houseStatus: HouseStatus
    
    init ( ) {
        Log.fan.info("no fan view model init")
        houseStatus = HouseStatus.shared
        houseStatus.$houseMessage
            .assign(to: &$houseMessage)
        
        houseStatus.$scanUntil
            .assign(to: &$scanUntil)
    }
}

class FanMonitor {
    private var id: String
    private var task: Task<(), Never>?
    private var refresh: () async throws -> ()
    
    deinit {
        task?.cancel()
        task = nil
        Log.fan.debug("fan monitor deinit")
    }
    
    init (id: String, _ refresher: @escaping () async throws -> () ) {
        Log.fan.info("fan monitor init")
        self.id = id
        refresh = refresher
    }
    
    fileprivate func start () {
        let interval = TimeInterval( 5 * 60 ) //5 minute loop interval
        if let t = task, !t.isCancelled { return }
        stop()
        //        print("Monitor started \(id)")
        Log.fan.info("fan monitor loop start")
        task = Task {
            while true {
                do {
                    Log.fan.info("fan monitor loop")
                    try await Task.sleep(interval: interval) //run the loop every 5 minutes to respond as conditions change
                    guard let t = task, !t.isCancelled else { throw BackgroundTaskError.taskCancelled }
                    try await refresh ()
                } catch {
                    break
                }
            }
            stop()
        }
    }
    
    fileprivate func stop () {
        Log.fan.info("fan monitor loop kill")
        task?.cancel()
        task = nil
        //        print ("Monitor suspended \(id)")
    }
}

class TestFanViewModel: ObservableObject {
    var model: FanModel
    var fanCharacteristics: FanCharacteristics
    
    init (chars: FanCharacteristics) {
        self.model = FanModel(usingChars: chars)
        self.fanCharacteristics = chars
        //        startSubscribers(initialChars: chars)
        //        fanMonitor()
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
