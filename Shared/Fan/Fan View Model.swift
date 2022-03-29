//
//  Fan Model View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

class FanViewModel: ObservableObject {
    //    private var sharedHouseData: SharedHouseData
    private var model: FanModel
//    @Published var fanCharacteristics: FanCharacteristics
    @Published var selectorSegments: Int = 2
    @Published var currentMotorSpeed: Int?
    @Published var indicatedAlarm: IndicatorOpacity.IndicatorBlink?
    @Published var offDateText: String?
    @Published var showTimerIcon = true
    @Published var showDamperWarning = false
    @Published var showInterlockWarning = false
    @Published var showTemperatureWarning = false
//    @Published var visible: Bool?
//    @Published var foreground: Bool?
    var chars: FanCharacteristics {
        model.fanCharacteristics.value
    }
    private var fanMonitor: FanMonitor!
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
//    private var bag = Set<AnyCancellable>()

    init (chars: FanCharacteristics) {
        self.model = FanModel(usingChars: chars)
        startSubscribers(initialChars: chars)
        fanMonitor = FanMonitor (id: model.id, model.refresh)
//        fanMonitor?.start()
    }
    
    deinit {
//        print("Deinit fan view model \(model.fanCharacteristics.value.macAddr)")
        fanMonitor?.stop()
    }
    
    convenience init () {
        let chars = FanCharacteristics()
        self.init(chars: chars)
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
    
    func transition (visible: Bool, foreground: Bool) {
        if (visible && foreground) {
            model.refresh ()
            fanMonitor.start ()
        } else {
            fanMonitor.stop()
        }
    }
    
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
        
        model.fanCharacteristics
            .prepend(chars)
            .compactMap { $0 }
            .map {
                $0.damper == .operating
            }
            .assign(to: &$showDamperWarning)
        
        model.fanCharacteristics
            .prepend(chars)
            .compactMap { $0 }
            .map {
                $0.interlock2 || $0.interlock1
            }
            .assign(to: &$showInterlockWarning)
        
        model.motorContext
            .prepend(.standby)
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
            .map { $0.speed }
            .assign(to: &$currentMotorSpeed)
        
        Publishers
            .CombineLatest3 (
                model.fanCharacteristics
                    .prepend(chars)
                    .map { $0.speed }
                    .map { $0 > 0 },
                WeatherMonitor.shared.$tooCold
                    .prepend (false),
                WeatherMonitor.shared.$tooHot
                    .prepend (false)
            )
            .map { $0 && ( $1 || $2) }
            .assign(to: &$showTemperatureWarning)
        
        model.fanCharacteristics
            .prepend (chars)
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
            .map { $0.airspaceFanModel }
            .map { String($0.prefix(4)) }
            .map { FanViewModel.speedTable[$0] ?? 1 }
            .map { $0 + 1 }
            .assign(to: &$selectorSegments)
    }
}

class FanMonitor {
    private var id: String
    private var task: Task<(), Never>?
    private var refresh: () async throws -> ()
    
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
