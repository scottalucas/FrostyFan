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
    @Published var visible: Bool?
    @Published var foreground: Bool?
    var chars: FanCharacteristics {
        model.fanCharacteristics.value
    }
    private var fanMonitor: FanMonitor?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var bag = Set<AnyCancellable>()

    init (chars: FanCharacteristics) {
        self.model = FanModel(usingChars: chars)
        startSubscribers(initialChars: chars)
        fanMonitor = FanMonitor (id: model.id, refresh )
//        fanMonitor?.start()
    }
    
    deinit {
        print("Deinit fan view model \(model.fanCharacteristics.value.macAddr)")
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
    
    func refresh() async throws {
        try await model.refresh()
    }
    
//    func visible (_ visible: Bool) {
//        if visible {
//            print("visible \(model.id)")
//            Task { try? await model.refresh() }
//            //            fanMonitor.start()
//        }
//    }
//    
//    func phase (_ phase: ScenePhase) {
//        print ("phase \(phase) for id \(model.id)")
//        switch phase {
//            case .background:
//                fanMonitor?.stop()
//            case .active:
//                fanMonitor?.start()
//            default:
//                break
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
        
        Publishers
            .CombineLatest (
                $visible
                    .prepend(nil),
                $foreground
                    .prepend(nil)
            )
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink(receiveValue: { [self] (optVisible, optForeground) in
//                print("Case \tvisible: \(optVisible) \tforeground \(optForeground) \tid \(self.model.id)")

                switch (optVisible, optForeground) {
                    case (true, true): //start the monitor and do a refresh when the app is in foreground and the fan is visible
//                        print("refresh true, monitor on")
                        Task {
                            do {
                                try await self.refresh ()
                            } catch {
                                self.fanMonitor?.stop()
                            }
                        }
                        self.fanMonitor?.start()
                    case (true, nil): //do a refresh if the fan is visible and the background state of the app hasn't been set
//                        print("refresh yes, monitor don't change")

                        Task {
                            do {
                                try await self.refresh ()
                            } catch {
                                self.fanMonitor?.stop()
                            }
                        }
                    case (_, false), (false, _): //stop monitor any time the app goes into background or the fan isn't visible
//                        print("refresh no, monitor stop")

                        self.fanMonitor?.stop()
                    default:
//                        print ("refresh no, monitor don't change")
                        break
                }
            })
            .store(in: &bag)
        
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
        print("Monitor started \(id)")
            task = Task {
                while true {
                    do {
                        //                    print("Fan monitor loop @ \(Date.now.formatted()), last update \(Storage.lastForecastUpdate.formatted())")
                        try await Task.sleep(interval: interval) //run the loop every 5 minutes to respond as conditions change
                        guard let t = task, !t.isCancelled else { throw BackgroundTaskError.taskCancelled }
                        try await refresh ()
                    } catch {
                        //                    let e = error as? BackgroundTaskError ?? error
                        //                    print("exited fan monitor loop @ \(Date.now.formatted()), error: \(e.localizedDescription)")
                        break
                    }
                }
                stop()
            }
        }
    
    fileprivate func stop () {
        task?.cancel()
        task = nil
        print ("Monitor suspended \(id)")
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
