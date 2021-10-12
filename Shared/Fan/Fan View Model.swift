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
//    @ObservedObject var houseViewModel: HouseViewModel
//    @ObservedObject var weather: Weather

    @Published var controllerSegments = Array<String>()
    @Published var offDateTxt = ""
    @Published var displayedSegment: Int = 0

    @Published var fanLamps = FanLamps()

    @Published var fanRotationDuration: Double = 0.0
    @Published var currentMotorSpeed: Int?
    private var displayedMotorSpeed: Int?
    private var displayMotor = PassthroughSubject<AnyPublisher<Double, Never>, Never>()
    
    private var longTermBag = Set<AnyCancellable>()
    private var monitorBag = Set<AnyCancellable>()
    
    init (atAddr addr: String, usingChars chars: FanCharacteristics) {
        print("view model init")
        self.model = FanModel(forAddress: addr, usingChars: chars)
        startSubscribers()
        controllerSegments = updateControllerSegments(forModel: chars.airspaceFanModel)
        offDateTxt = updateOffDate(minutesLeft: chars.timer)
        updatePhysicalSpeed(toNewSpeed: chars.speed)
        displayedSegment = chars.speed
    }
    
    convenience init () {
        let chars = FanCharacteristics()
        let addr = "Test"
        self.init(atAddr: addr, usingChars: chars)
    }
    
    func setTimer (addHours hours: Int) {
        model.setFan(addHours: hours)
    }
    
    func refreshFan () {
        model.refreshFan()
    }
    
    private func updateOffDate(minutesLeft: Int) -> String {
        guard minutesLeft > 0 else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Off at \(formatter.string(from: Date(timeIntervalSinceNow: TimeInterval(minutesLeft * 60))))"
    }
    
    private func updatePhysicalSpeed (toNewSpeed speed: Int) {
        defer { currentMotorSpeed = speed }
        if currentMotorSpeed == nil { displayedSegment = speed } //should only happen first time through
        self.setDisplayMotor(toSpeed: speed)
    }
    
    private func updateControllerSegments (forModel model: String) -> [String] {
        let speedLevels = FanViewModel.speedTable[String(model.prefix(4))] ?? 1
        var newArr = Range(0...speedLevels).map { String($0) }
        newArr[newArr.startIndex] = "Off"
        newArr[newArr.endIndex - 1] = newArr.count <= 2 ? "On" : "Max"
        return newArr
    }
    
    private func killAllAdjustments () {
        monitorBag.forEach { $0.cancel() }
        monitorBag.removeAll()
    }
//           let failed = self?.fanLamps.contains(.speedAdjustmentFailed) ?? true
//                return !failed
//            }
    
    private func startSubscribers() {
        
        $displayedSegment
            .sink(receiveValue: { [weak self] segmentSelected in
                guard let self = self else { return }
                self.model.setFan(toSpeed: segmentSelected)
            })
            .store(in: &longTermBag)
        
        model.$fanStatus
            .sink(receiveValue: { status in
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
        
        
//            .filter { [weak self] displayedSpeed in
//                guard let self = self, let motorSpeed = self.currentMotorSpeed else { return false }
//                return displayedSpeed != motorSpeed
//            }
//            .sink(receiveValue: { [weak self] newSpeed in
//                guard let self = self else { return }
//                self.killAllAdjustments()
//                self.fanLamps.insert(.speedAdjusting)
//                self.model.setFan(toSpeed: newSpeed)
//                    .receive(on: DispatchQueue.main)
//                    .retry(2)
//                    .handleEvents(receiveCompletion: { comp in
//                        if case .failure (_) = comp {
//                            self.fanLamps.insert(.fanNotResponsive)
//                        }
//                    })
//                    .sink(receiveCompletion: { [weak self] comp in
//                        self?.fanLamps.remove([.speedAdjusting, .fanNotResponsive])
//                        if case .failure(let err) = comp {
//                            print ("Set fan speed failed \(err)")
//                            self?.fanLamps.insert(.speedAdjustmentFailed)
//                            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
//                                DispatchQueue.main.async {
//                                    self?.fanLamps.remove(.speedAdjustmentFailed)
//                                    self?.displayedSegment = self?.currentMotorSpeed ?? -1
//                                    print("timeout failure recovered\r\tDisplayed segment: \(self.map { String($0.displayedSegment) } ?? "Nil")\r\tFlag: \(self.map { $0.fanLamps.contains(.speedAdjustmentFailed) }?.description ?? "Nil")\r\tLast speed detected: \(self.map { $0.currentMotorSpeed?.description ?? "Nil" } ?? "Nil")")
//                                }
//                            }
//                            self?.displayedSegment = self?.currentMotorSpeed ?? -1
//                        } else {
//                            print("Set fan speed completed")
//                            self?.fanLamps.remove(.speedAdjustmentFailed)
//                        }
//                    }, receiveValue: { _ in })
//                    .store(in: &self.monitorBag)
//            })
//            .store(in: &longTermBag)
        
        model.$fanCharacteristics
            .compactMap { $0?.timer }
            .receive(on: DispatchQueue.main)
            .map { [weak self] timeTillOff in
                guard let self = self else { return "" }
                return self.updateOffDate(minutesLeft: timeTillOff)
            }
            .print()
            .assign(to: &$offDateTxt)

        model.$fanCharacteristics
            .compactMap { $0?.airspaceFanModel }
            .map { [weak self] model in
                guard let self = self else { return ["Off","On"] }
                return self.updateControllerSegments(forModel: model)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$controllerSegments)

        displayMotor
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .assign(to: &$fanRotationDuration)
        
//        model.$commError
//            .compactMap { $0 }
//            .receive(on: DispatchQueue.main)
//            .sink(receiveValue: { [weak self] err in
//                print("Comm error: \(err.localizedDescription)")
//                if let house = self?.houseViewModel, let chars = self?.model.fanCharacteristics {
//                    house.fans.remove(chars)
//                }
//            })
//            .store(in: &longTermBag)
        
//        weather.$currentTempStr
//            .receive(on: DispatchQueue.main)
//            .sink(receiveValue: { [weak self] _ in
//                guard let self = self else { return }
//                if self.weather.tooCold { self.displayedAppLamps.insert(.tooCold) } else { self.displayedAppLamps.remove(.tooCold) }
//                if self.weather.tooHot { self.displayedAppLamps.insert(.tooHot) } else { self.displayedAppLamps.remove(.tooHot) }
//            })
//            .store(in: &longTermBag)
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
    private func setDisplayMotor(toSpeed: Int) {
        guard currentMotorSpeed != toSpeed else { return }
//        defer { displayedMotorSpeed = toSpeed }
        let scaleFactor = 3.5
        guard toSpeed != 0 else {
            displayMotor.send(Just(0.0).eraseToAnyPublisher())
            return
        }
        let s = Double (toSpeed)
        displayMotor.send (
            Timer.publish(every: scaleFactor * 1/s, on: .main, in: .common)
                .autoconnect()
            .map { _ in scaleFactor * 1/s }
            .eraseToAnyPublisher())
    }
}
