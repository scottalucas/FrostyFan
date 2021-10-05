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
    @Published var displayedSegmentNumber: Int = 0
    @Published var fanLamps = FanLamps()
    @Published var fanRotationDuration: Double = 0.0
    @Published var physicalFanSpeed: Int?
    @Published var displayedAppLamps = ApplicationLamps.shared
    @Published var displayedFanLamps = FanLamps()
    private var displayedMotorSpeed: Int?
    private var displayMotor = PassthroughSubject<AnyPublisher<Double, Never>, Never>()
    
    private var bag = Set<AnyCancellable>()
    
    init (atAddr addr: String, usingChars chars: FanCharacteristics, inHouse house: House, weather: Weather) {
        print("view model init")
        self.house = house
        self.weather = weather
        self.model = FanModel(forAddress: addr, usingChars: chars)
        startSubscribers(using: model.$fanCharacteristics)
        controllerSegments = updateControllerSegments(forModel: chars.airspaceFanModel)
        offDateTxt = updateOffDate(minutesLeft: chars.timer)
        updatePhysicalSpeed(toNewSpeed: chars.speed)
        displayedSegmentNumber = chars.speed
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
        defer { physicalFanSpeed = speed }
        if physicalFanSpeed == nil { displayedSegmentNumber = speed } //should only happen first time through
        if speed != displayedSegmentNumber {
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
    
    func setTimer(addHours: Int) {
        fanLamps.insert(.timerAdjusting)
        model.setFan(addHours: addHours)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] comp in
                self?.fanLamps.remove(.timerAdjusting)
                if case .failure(let err) = comp {
                    print ("Set fan timer failed \(err)")
                    self?.fanLamps.insert(.timerAdjustmentFailed)
                } else {
                    print("Set fan timer completed")
                    self?.fanLamps.remove(.timerAdjustmentFailed)
                }
            }, receiveValue: { _ in })
            .store(in: &bag)
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
        
        $displayedSegmentNumber
            .filter { $0 != -1 }
            .filter { [weak self] dSpeed in
                guard let self = self, let pSpeed = self.physicalFanSpeed else { return false }
                return dSpeed != pSpeed
            }
            .sink(receiveValue: { [weak self] newSpeed in
                guard let self = self else { return }
                self.fanLamps.insert(.speedAdjusting)
                self.model.setFan(toSpeed: newSpeed)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { [weak self] comp in
                        self?.fanLamps.remove(.speedAdjusting)
                        if case .failure(let err) = comp {
                            print ("Set fan speed failed \(err)")
                            self?.fanLamps.insert(.speedAdjustmentFailed)
                        } else {
                            print("Set fan speed completed")
                            self?.fanLamps.remove(.speedAdjustmentFailed)
                        }
                    }, receiveValue: { _ in })
                    .store(in: &self.bag)
            })
            .store(in: &bag)
        
        chars
            .compactMap { $0?.timer }
            .receive(on: DispatchQueue.main)
            .map { [weak self] timeTillOff in
                guard let self = self else { return "" }
                return self.updateOffDate(minutesLeft: timeTillOff)
            }
            .assign(to: &$offDateTxt)

        chars
            .compactMap { $0?.speed }
            .print("in view model \(model.ipAddr)")
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] actualSpeed in
                guard let self = self else { return }
                if actualSpeed == 0 {
                    self.fanLamps.insert(.fanOff)
                } else {
                    self.fanLamps.remove(.fanOff)
                }
                self.updatePhysicalSpeed(toNewSpeed: actualSpeed)
            })
            .store(in: &bag)
        
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
            .store(in: &bag)
        
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
            .store(in: &bag)

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
            .store(in: &bag)
        
        weather.$currentTempStr
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                guard let self = self else { return }
                if self.weather.tooCold { self.displayedAppLamps.insert(.tooCold) } else { self.displayedAppLamps.remove(.tooCold) }
                if self.weather.tooHot { self.displayedAppLamps.insert(.tooHot) } else { self.displayedAppLamps.remove(.tooHot) }
            })
            .store(in: &bag)
        }
    }

extension FanViewModel {
    private func setDisplayMotor(toSpeed: Int) {
        guard physicalFanSpeed != toSpeed else { return }
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
