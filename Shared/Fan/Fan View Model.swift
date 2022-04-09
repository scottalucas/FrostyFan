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

class FanViewModel: ObservableObject {
    private var model: FanModel
    private var houseStatus = HouseStatus.shared
    var id: FanView.ID
    @Published var selectorSegments: Int = 2
    @Published var currentMotorSpeed: Int?
    
    @Published var scanUntil: Date = .distantPast //from HouseStatus.shared
    @Published var houseMessage: String? //from HouseStatus.shared
    @Published var houseTempAlarm: Bool = false //from HouseStatus.shared
    
    @Published var appInForeground = false
    @Published var indicatedAlarm: IndicatorOpacity.IndicatorBlink?
    @Published var offDateText: String?
    @Published var showTimerIcon = true
    @Published var showDamperWarning = false
    @Published var showInterlockWarning = false
    @Published var displayedRPM: Int = 0
    var chars: FanCharacteristics {
        model.fanCharacteristics.value
    }
    private var fanMonitor: FanMonitor?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var bag = Set<AnyCancellable>()
    
    init (chars: FanCharacteristics, id: FanView.ID) {
        self.model = FanModel(usingChars: chars)
        self.id = id
        HouseStatus.shared.updateStatus(forFan: id, isOperating: chars.speed > 0)
//        fanMonitor = FanMonitor (id: model.id, model.refresh)
        startSubscribers(initialChars: chars)
    }
    
    deinit {
        //        print("Deinit fan view model \(model.fanCharacteristics.value.macAddr)")
        fanMonitor?.stop()
    }
    
    convenience init () {
        let chars = FanCharacteristics()
        self.init(chars: chars, id: UUID.init().uuidString)
    }
    
    func setTimer (addHours hours: Int) {
        Task {
            registerBackgroundTask()
            await model.setFan(addHours: hours)
            endBackgroundTask()
        }
    }
    
    func setSpeed (to spd: Int?) {
        guard let spd = spd else { return }
        Task {
            registerBackgroundTask()
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
    
    private func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }
    
    private func endBackgroundTask() {
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
        
        model.motorContext
            .prepend(.standby)
            .receive(on: DispatchQueue.main)
            .map {
                $0 != .adjusting
            }
            .combineLatest(
                model.timerContext
                    .prepend(.standby)
                    .map {
                        $0 != .adjusting
                    }
            )
            .map { $0 && $1 }
            .assign(to: &$showTimerIcon)
        
        model.fanCharacteristics
            .prepend(chars)
            .receive(on: DispatchQueue.main)
            .map { $0.speed }
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
            .map {
                Int( 80.0 * (Double($0.speed) / max( 1.0, Double($0.levels - 1) ) ) )
            }
            .assign(to: &$displayedRPM)
        
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

class NoFanViewModel: ObservableObject {
    @Published var scanUntil: Date = .distantPast //from Notification
    @Published var houseMessage: String? //from Notification
    private var houseStatus = HouseStatus.shared
    
    init ( ) {
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
        print("fan monitor deinit")
    }
    
    init (id: String, _ refresher: @escaping () async throws -> () ) {
        self.id = id
        refresh = refresher
    }
    
    fileprivate func start () {
        let interval = TimeInterval( 5 * 60 ) //5 minute loop interval
        if let t = task, !t.isCancelled { return }
        stop()
        //        print("Monitor started \(id)")
        task = Task {
            while true {
                do {
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
