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
    var model: FanModel
    @Published var fanCharacteristics: FanCharacteristics
    @Published var selectorSegments: Int = 2
    @Published var currentMotorSpeed: Int?
    @Published var indicatedAlarm: IndicatorOpacity.IndicatorBlink?
    @Published var showTimerIcon = true
    @Published var timerWheelPosition: Int = .zero
    @Published var offDateText: String?
    @Published var showDamperWarning = false
    @Published var showInterlockWarning = false
    @Published var showTemperatureWarning = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

//    @Published var chars: FanCharacteristics
//    @Published var targetedSpeed: Int?
//    @Published var fanStatusText: String?
//    @Published var fanStatusIcons = Array<Image>()
//    @Published var fanRotationDuration: Double = 0.0
//    @Published var useAlarmColor = false
//    @Published var fatalFault = false
//    @Published var displayFanRpm = Int.zero
//    private var displayedMotorSpeed: Int?
//    private var displayMotor = PassthroughSubject<AnyPublisher<Double, Never>, Never>()
    
//    private var bag = Set<AnyCancellable>()
    
    init (chars: FanCharacteristics) {
        self.model = FanModel(usingChars: chars)
        self.fanCharacteristics = chars
        startSubscribers(initialChars: chars)
        fanMonitor()
    }
    
    deinit {
        print("Deinit fan view model \(fanCharacteristics.macAddr)")
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

    func refreshFan () {
        Task { try? await model.refresh() }
    }
    
    private func fanMonitor () {
        let interval = TimeInterval( 5 * 60 ) //5 minute loop interval
        Task {
            while true {
                do {
                    print("Fan monitor loop @ \(Date.now.formatted()), last update \(Storage.lastForecastUpdate.formatted())")
                    try await Task.sleep(interval: interval) //run the loop every 5 minutes to respond as conditions change
                    refreshFan()
                } catch {
                    let e = error as? BackgroundTaskError ?? error
                    print("exited fan monitor loop @ \(Date.now.formatted()), error: \(e.localizedDescription)")
                    break
                }
            }
        }
    }
    
    private func registerBackgroundTask() {
        //        print("BG task started")
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            //            print("BG task expired")
            self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }
    
    private func endBackgroundTask() {
        //        print("Background task ended.")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
//
//    private func updateOffDate(minutesLeft: Int) -> String {
//        guard minutesLeft > 0 else {
//            return ""
//        }
//        let formatter = DateFormatter()
//        formatter.dateFormat = "h:mm a"
//        return "Off at \(formatter.string(from: Date(timeIntervalSinceNow: TimeInterval(minutesLeft * 60))))"
//    }

//
//    private func setFanLamps(from status: FanStatus) -> (FanLamps, IndicatorOpacity.IndicatorBlink?) {
//        var retLamps = FanLamps()
//        var retBlink = Optional<IndicatorOpacity.IndicatorBlink>.none
//        if !status.isDisjoint(with: [.damperOperating, .interlockActive]) {
//            retLamps.insert(.showMinorFaultIndicator)
//            retBlink = .slowBlink
//        }
//        if status.contains(.damperOperating) {
//            retLamps.insert(.showDamperIndicator)
//        }
//        if status.contains(.interlockActive) {
//            retLamps.insert(.showInterlockIndicator)
//        }
//        if status.contains(.speedAdjusting) {
//            retLamps.insert(.showPhysicalSpeedIndicator)
//        }
//
//        if !status.contains(.timerAdjusting) {
//            self.fanLamps.insert([.showTimeLeft, .showTimerIcon])
//        }
//
//        if status.contains(.noFanCharacteristics) {
//            self.fanLamps.insert(.showNoCharsIndicator)
//        }
//        return (retLamps, retBlink)
//    }
    
    private func startSubscribers(initialChars chars: FanCharacteristics) {
        
        model.fanCharacteristics
            .assign(to: &$fanCharacteristics)
        
        $fanCharacteristics
            .prepend(chars)
            .compactMap { $0 }
            .map {
                $0.damper == .operating
            }
            .assign(to: &$showDamperWarning)
        
        $fanCharacteristics
            .prepend(chars)
            .compactMap { $0 }
            .map {
                $0.interlock2 || $0.interlock1
            }
            .assign(to: &$showInterlockWarning)
        
        //should all be done in house tint
//        model.$fanCharacteristics
//            .map { $0 == nil }
//            .combineLatest(self.sharedHouseData.$useAlarmColor)
//            .map { $0 || $1 }
//            .assign(to: &$useAlarmColor)
//
//        model.$fanCharacteristics
//            .map { $0 == nil }
//            .assign(to: &$fatalFault)

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

//        $targetedSpeed
//            .compactMap { $0 }
//            .sink(receiveValue: { [weak self] segmentSelected in
//                guard let self = self else { return }
//                Task { await self.model.setFan(toSpeed: segmentSelected) }
//            })
//            .store(in: &longTermBag)
        
//        model.$fanStatus
//            .sink(receiveValue: { status in
////                print(status.description)
////                guard !status.contains(.fanNotResponsive) else {
////                    NotificationCenter.default.post(name: .removeFan, object: nil, userInfo: [self.model.ipAddr : ""])
////                    return
////                }
//            })
//            
//            .store(in: &longTermBag)
        
//        model.$fanCharacteristics
//            .compactMap { $0 }
//            .assign(to: &$chars)
        
//        model.$fanCharacteristics
//            .prepend(chars)
//            .compactMap { optChars -> (String, Int)? in
//                guard
//                    let chars = optChars,
//                    let levels = FanViewModel.speedTable[String(chars.airspaceFanModel.prefix(4))]
//                else {
//                    print("Model: \(optChars?.airspaceFanModel ?? "Not found"), speed: \(optChars.map ({ FanViewModel.speedTable[$0.airspaceFanModel].debugDescription }) ?? "Not found")")
//                    return nil
//                }
//                return (addr: chars.macAddr, rpm: Int ( Double ( chars.speed ) * 50.0 / Double ( levels ) ))
//            }
//            .sink(receiveValue: { (addr, rpm) in
//                HouseMonitor.shared.updateOperationalStatus(forMacAddr: addr, to: rpm)
//            })
//            .store(in: &bag)
        //
        //        $displayFanRpm
        //            .handleEvents(receiveOutput: { rpm in
        //                print("rpm \(rpm) in \(self.mark)")
        //            })
//            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
//            .store(in: &bag)
        
//            .compactMap { $0?.speed }
//            .assign(to: &$displayFanRpm)
        
        $fanCharacteristics
            .prepend(chars)
            .map { $0.speed }
            .assign(to: &$currentMotorSpeed)
        
        Publishers
            .CombineLatest3 (
                $fanCharacteristics
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

        $fanCharacteristics
            .prepend (chars)
            .map { $0.timer }
            .map { timeTillOff -> Date? in
                guard timeTillOff > 0 else { return nil }
                return Date(timeIntervalSinceNow: Double(timeTillOff) * 60.0)
            }
            .map {
                guard let offDate = $0 else { return nil }
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return "Off at \(formatter.string(from: offDate))"
            }
            .assign(to: &$offDateText)
        
        $fanCharacteristics
            .prepend(chars)
            .map { $0.airspaceFanModel }
            .map { String($0.prefix(4)) }
            .map { FanViewModel.speedTable[$0] ?? 1 }
            .map { $0 + 1 }
            .assign(to: &$selectorSegments)

//
//
//        $currentMotorSpeed
//            .compactMap { $0 }
//            .sink(receiveValue: { [weak self] spd in
//                guard let self = self else { return }
//                guard spd != 0 else {
//                    self.displayMotor.send(Just(0.0).eraseToAnyPublisher())
//                    return
//                }
//                let scaleFactor = 3.5
//                let s = Double (spd)
//                self.displayMotor.send (
//                    Timer.publish(every: scaleFactor * 1/s, on: .main, in: .common)
//                        .autoconnect()
//                        .map { _ in scaleFactor * 1/s }
//                        .eraseToAnyPublisher())
//            })
//            .store(in: &bag)
//
//        displayMotor
//            .switchToLatest()
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$fanRotationDuration)
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
