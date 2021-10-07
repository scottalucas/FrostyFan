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
    @ObservedObject var house: House
    @ObservedObject var weather: Weather
//    @Published var chars: FanCharacteristics?
    @Published var controllerSegments = Array<String>()
    @Published var offDateTxt = ""
    @Published var displayedSegment: Int = 0
    @Published var fanLamps = FanLamps()
    @Published var fanRotationDuration: Double = 0.0
    @Published var currentMotorSpeed: Int?
    @Published var displayedAppLamps = ApplicationLamps.shared
    private var displayedMotorSpeed: Int?
    private var displayMotor = PassthroughSubject<AnyPublisher<Double, Never>, Never>()
    
    private var longTermBag = Set<AnyCancellable>()
    private var monitorBag = Set<AnyCancellable>()
    
    init (atAddr addr: String, usingChars chars: FanCharacteristics, inHouse house: House, weather: Weather) {
        print("view model init")
        self.house = house
        self.weather = weather
        self.model = FanModel(forAddress: addr, usingChars: chars)
        startSubscribers(using: model.$fanCharacteristics)
        controllerSegments = updateControllerSegments(forModel: chars.airspaceFanModel)
        offDateTxt = updateOffDate(minutesLeft: chars.timer)
        updatePhysicalSpeed(toNewSpeed: chars.speed)
        displayedSegment = chars.speed
    }
    
    convenience init () {
        let house = House()
        let weather = Weather(house: house)
        let chars = FanCharacteristics()
        let addr = "Test"
        self.init(atAddr: addr, usingChars: chars, inHouse: house, weather: weather)
    }
    
    private func updateOffDate(minutesLeft: Int) -> String {
        guard minutesLeft > 0 else {
            fanLamps.remove(.nonZeroTimeRemaining)
            return ""
        }
        fanLamps.insert(.nonZeroTimeRemaining)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Off at \(formatter.string(from: Date(timeIntervalSinceNow: TimeInterval(minutesLeft * 60))))"
    }
    
    private func updatePhysicalSpeed (toNewSpeed speed: Int) {
        defer { currentMotorSpeed = speed }
        if currentMotorSpeed == nil { displayedSegment = speed } //should only happen first time through
        if speed != displayedSegment {
            fanLamps.insert(.physicalSpeedMismatchToRequested)
        } else {
            fanLamps.remove(.physicalSpeedMismatchToRequested)
        }
        self.setDisplayMotor(toSpeed: speed)
    }
    
    private func updateControllerSegments (forModel model: String) -> [String] {
        let speedLevels = FanViewModel.speedTable[String(model.prefix(4))] ?? 1
        var newArr = Range(0...speedLevels).map { String($0) }
        newArr[newArr.startIndex] = "Off"
        newArr[newArr.endIndex - 1] = newArr.count <= 2 ? "On" : "Max"
        return newArr
    }
    
    private func updateInterlock (interlock1: Bool, interlock2: Bool) {
        if interlock1 || interlock2 { fanLamps.insert(.interlockActive)
        } else {
            fanLamps.remove(.interlockActive)
        }
        
    }

    private func killAllAdjustments () {
        monitorBag.forEach { $0.cancel() }
        monitorBag.removeAll()
        fanLamps.remove(.speedAdjusting)
        fanLamps.remove(.timerAdjusting)
    }
    
    func setTimer(addHours: Int) {
        killAllAdjustments()
        fanLamps.insert(.timerAdjusting)
        model.setFan(addHours: addHours)
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveCompletion: { comp in
                if case .failure (_) = comp {
                    self.fanLamps.insert(.fanNotResponsive)
                }
            })
            .print("retry before")
            .retry(2)
            .print("retry after")
            .sink(receiveCompletion: { [weak self] comp in
                self?.fanLamps.remove([.timerAdjusting, .fanNotResponsive])
                if case .failure(let err) = comp {
                    print ("Set fan timer failed \(err)")
                    self?.fanLamps.insert(.timerAdjustmentFailed)
                } else {
                    print("Set fan timer completed")
                    self?.fanLamps.remove(.timerAdjustmentFailed)
                }
            }, receiveValue: { _ in })
            .store(in: &monitorBag)
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
    func startSubscribers (using chars: Published<FanCharacteristics?>.Publisher) {
        
        $displayedSegment
            .filter { $0 != -1 }
            .filter { [weak self] _ in
                let failed = self?.fanLamps.contains(.speedAdjustmentFailed) ?? true
                return !failed
            }
            .filter { [weak self] displayedSpeed in
                guard let self = self, let motorSpeed = self.currentMotorSpeed else { return false }
                return displayedSpeed != motorSpeed
            }
            .sink(receiveValue: { [weak self] newSpeed in
                guard let self = self else { return }
                self.killAllAdjustments()
                self.fanLamps.insert(.speedAdjusting)
                self.model.setFan(toSpeed: newSpeed)
                    .receive(on: DispatchQueue.main)
                    .retry(2)
                    .handleEvents(receiveCompletion: { comp in
                        if case .failure (_) = comp {
                            self.fanLamps.insert(.fanNotResponsive)
                        }
                    })
                    .sink(receiveCompletion: { [weak self] comp in
                        self?.fanLamps.remove([.speedAdjusting, .fanNotResponsive])
                        if case .failure(let err) = comp {
                            print ("Set fan speed failed \(err)")
                            self?.fanLamps.insert(.speedAdjustmentFailed)
                            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
                                DispatchQueue.main.async {
                                    self?.fanLamps.remove(.speedAdjustmentFailed)
                                    self?.displayedSegment = self?.currentMotorSpeed ?? -1
                                    print("timeout failure recovered\r\tDisplayed segment: \(self.map { String($0.displayedSegment) } ?? "Nil")\r\tFlag: \(self.map { $0.fanLamps.contains(.speedAdjustmentFailed) }?.description ?? "Nil")\r\tLast speed detected: \(self.map { $0.currentMotorSpeed?.description ?? "Nil" } ?? "Nil")")
                                }
                            }
                            self?.displayedSegment = self?.currentMotorSpeed ?? -1
                        } else {
                            print("Set fan speed completed")
                            self?.fanLamps.remove(.speedAdjustmentFailed)
                        }
                    }, receiveValue: { _ in })
                    .store(in: &self.monitorBag)
            })
            .store(in: &longTermBag)
        
        chars
            .compactMap { $0?.timer }
            .receive(on: DispatchQueue.main)
            .map { [weak self] timeTillOff in
                guard let self = self else { return "" }
                return self.updateOffDate(minutesLeft: timeTillOff)
            }
            .print()
            .assign(to: &$offDateTxt)

        chars
            .compactMap { $0?.speed }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] actualSpeed in
                guard let self = self else { return }
                if actualSpeed == 0 {
                    self.fanLamps.insert(.fanOff)
                    self.fanLamps.remove(.nonZeroTimeRemaining)
                } else {
                    self.fanLamps.remove(.fanOff)
                }
                self.updatePhysicalSpeed(toNewSpeed: actualSpeed)
            })
            .store(in: &longTermBag)
        
        chars
            .compactMap { $0?.damper }
            .receive(on: DispatchQueue.main)
            .sink (receiveValue: { [weak self] status in
                if status == .operating {
                    self?.fanLamps.insert(.damperOperating)
                } else {
                    self?.fanLamps.remove(.damperOperating)
                }
            })
            .store(in: &longTermBag)
        
        chars
            .compactMap { $0?.airspaceFanModel }
            .map { [weak self] model in
                guard let self = self else { return ["Off","On"] }
                return self.updateControllerSegments(forModel: model)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$controllerSegments)
        
        chars
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] chars in
                guard let self = self else { return }
                self.updateInterlock(interlock1: chars.interlock1, interlock2: chars.interlock2)
            })
            .store(in: &longTermBag)

        displayMotor
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .assign(to: &$fanRotationDuration)
        
        model.$commError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] err in
                print("Comm error: \(err.localizedDescription)")
                if let house = self?.house, let chars = self?.model.fanCharacteristics {
                    house.fans.remove(chars)
                }
            })
            .store(in: &longTermBag)
        
        weather.$currentTempStr
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                guard let self = self else { return }
                if self.weather.tooCold { self.displayedAppLamps.insert(.tooCold) } else { self.displayedAppLamps.remove(.tooCold) }
                if self.weather.tooHot { self.displayedAppLamps.insert(.tooHot) } else { self.displayedAppLamps.remove(.tooHot) }
            })
            .store(in: &longTermBag)
        }
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
