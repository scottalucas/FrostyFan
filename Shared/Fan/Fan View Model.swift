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
    @ObservedObject var model: FanModel
    @Published var chars: FanCharacteristics
    @Published var selectorSegments: Int = 2
    @Published var targetedSpeed: Int?
    @Published var indicatedAlarm: IndicatorOpacity.IndicatorBlink?
    @Published var offDateTxt = ""
    @Published var fanLamps = FanLamps()
    @Published var fanRotationDuration: Double = 0.0
    @Published var currentMotorSpeed: Int?
    private var displayedMotorSpeed: Int?
    private var displayMotor = PassthroughSubject<AnyPublisher<Double, Never>, Never>()
    
    private var longTermBag = Set<AnyCancellable>()
    private var monitorBag = Set<AnyCancellable>()
    
    init (atAddr addr: String, usingChars chars: FanCharacteristics) {
        print("view model init for \(addr)")
        self.model = FanModel(forAddress: addr, usingChars: chars)
        self.chars = chars
        startSubscribers()
        let m: String = String(model.fanCharacteristics?.airspaceFanModel.prefix(4) ?? "")
        selectorSegments = FanViewModel.speedTable[m] ?? 2
        offDateTxt = updateOffDate(minutesLeft: chars.timer)
        currentMotorSpeed = chars.speed
    }
    
    convenience init () {
        let chars = FanCharacteristics()
        let addr = "Test"
        self.init(atAddr: addr, usingChars: chars)
    }
    
    func setTimer (addHours hours: Int) {
        Task {
            await model.setFan(addHours: hours)
        }
    }
    
    func refreshFan () {
        Task {
//        await model.refreshFan() # FIX
        }
    }
    
    private func updateOffDate(minutesLeft: Int) -> String {
        guard minutesLeft > 0 else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Off at \(formatter.string(from: Date(timeIntervalSinceNow: TimeInterval(minutesLeft * 60))))"
    }
    
    private func killAllAdjustments () {
        monitorBag.forEach { $0.cancel() }
        monitorBag.removeAll()
    }
    
    private func startSubscribers() {
        
        $targetedSpeed
            .compactMap { $0 }
            .sink(receiveValue: { [weak self] segmentSelected in
                guard let self = self else { return }
                Task { await self.model.setFan(toSpeed: segmentSelected) }
            })
            .store(in: &longTermBag)
        
        model.$fanStatus
            .sink(receiveValue: { status in
                print(status.description)
                if !status.isDisjoint(with: [.damperOperating, .interlockActive]) {
                    self.fanLamps.insert(.showMinorFaultIndicator)
                    self.indicatedAlarm = .slowBlink
                } else {
                    self.fanLamps.remove(.showMinorFaultIndicator)
                    self.indicatedAlarm = nil
                }
                if status.contains(.damperOperating) {
                    self.fanLamps.insert(.showDamperIndicator)
                } else {
                    self.fanLamps.remove(.showDamperIndicator)
                }
                if status.contains(.interlockActive) {
                    self.fanLamps.insert(.showInterlockIndicator)
                } else {
                    self.fanLamps.remove(.showInterlockIndicator)
                }
                if status.contains(.speedAdjusting) {
                    self.fanLamps.insert(.showPhysicalSpeedIndicator)
                } else {
                    self.fanLamps.remove(.showPhysicalSpeedIndicator)
                }
                if status.contains(.timerAdjusting) {
                    self.fanLamps.remove([.showTimeLeft, .showTimerIcon])
                } else {
                    self.fanLamps.insert([.showTimeLeft, .showTimerIcon])
                }
                if status.contains(.noFanCharacteristics) {
                    self.fanLamps.insert(.showNoCharsIndicator)
                } else {
                    self.fanLamps.remove(.showNoCharsIndicator)
                }
            })
            .store(in: &longTermBag)
        
        model.$fanCharacteristics
            .compactMap { $0 }
            .assign(to: &$chars)
        
        model.$fanCharacteristics
            .map { $0?.speed }
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentMotorSpeed)

        model.$fanCharacteristics
            .compactMap { $0?.timer }
            .receive(on: DispatchQueue.main)
            .map { [weak self] timeTillOff in
                guard let self = self else { return "" }
                return self.updateOffDate(minutesLeft: timeTillOff)
            }
            .assign(to: &$offDateTxt)

        model.$fanCharacteristics
            .compactMap { $0?.airspaceFanModel }
            .map { String($0.prefix(4)) }
            .map { FanViewModel.speedTable[$0] ?? 1 }
            .map { $0 + 1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectorSegments)
        
        $currentMotorSpeed
            .compactMap { $0 }
            .sink(receiveValue: { [weak self] spd in
                guard let self = self else { return }
                guard spd != 0 else {
                    self.displayMotor.send(Just(0.0).eraseToAnyPublisher())
                    return
                }
                let scaleFactor = 3.5
                let s = Double (spd)
                self.displayMotor.send (
                    Timer.publish(every: scaleFactor * 1/s, on: .main, in: .common)
                        .autoconnect()
                        .map { _ in scaleFactor * 1/s }
                        .eraseToAnyPublisher())
            })
            .store(in: &monitorBag)

        displayMotor
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .assign(to: &$fanRotationDuration)
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
