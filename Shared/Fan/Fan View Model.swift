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
    @Published var fanLamps = FanLamps()
    @Published var fanRotationDuration: Double = 0.0
    @Published var displayedSegmentNumber: Int = -1
    @Published var airspaceFanModel: String?
    @Published var controllerSegments: [String] = ["Off", "On"]
    @Published var timer = 0
    @Published var offDateTxt = ""
    @Published var physicalFanSpeed: Int?
    @Published var displayedLamps = ApplicationLamps()
    @Published var timeToAdd: Int?
    @Published var updatedName: String?

    private var displayedMotorSpeed: Int?
    private var displayMotor = PassthroughSubject<AnyPublisher<Double, Never>, Never>()
    
    private var bag = Set<AnyCancellable>()
    
    init (atAddr addr: String, usingChars chars: FanCharacteristics, inHouse house: House, weather: Weather) {
        print("view model init")
        self.house = house
        self.weather = weather
        self.model = FanModel(forAddress: addr, usingChars: chars)
        startSubscribers()
    }
    
    convenience init () {
        let house = House()
        let weather = Weather(house: house)
        let chars = FanCharacteristics()
        let addr = "Test"
        self.init(atAddr: addr, usingChars: chars, inHouse: house, weather: weather)
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
    func startSubscribers () {
        
        $displayedSegmentNumber
            .receive(on: DispatchQueue.main)
            .filter { [weak self] dSpeed in
                guard let self = self, let pSpeed = self.physicalFanSpeed else { return false }
                return dSpeed != pSpeed
            }
            .sink(receiveValue: { [weak self] newSpeed in
                guard let self = self else { return }
                self.model.setFan(toSpeed: newSpeed)
            })
            .store(in: &bag)
        
        model.$fanCharacteristics
            .compactMap { $0?.timer }
            .receive(on: DispatchQueue.main)
            .map { [weak self] timeTillOff in
                guard timeTillOff > 0 else {
                    self?.fanLamps.remove(.nonZeroTimeRemaining)
                    return "" }
                self?.fanLamps.insert(.nonZeroTimeRemaining)
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return "Off at \(formatter.string(from: Date(timeIntervalSinceNow: TimeInterval(timeTillOff * 60))))"
            }
            .assign(to: &$offDateTxt)

        model.$fanCharacteristics
            .compactMap { $0?.timer }
            .receive(on: DispatchQueue.main)
            .assign(to: &$timer)

        model.$fanCharacteristics
            .receive(on: DispatchQueue.main)
            .compactMap { $0?.speed }
            .print("in view model")
            .sink(receiveValue: { [weak self] actualSpeed in
                guard let self = self else { return }
                if self.physicalFanSpeed == nil { self.displayedSegmentNumber = actualSpeed } //should only happen first time through
                self.physicalFanSpeed = actualSpeed
                self.setDisplayMotor(toSpeed: actualSpeed)
            })
            .store(in: &bag)
        
        displayMotor
            .receive(on: DispatchQueue.main)
            .switchToLatest()
            .assign(to: &$fanRotationDuration)
        
        model.$fanCharacteristics
            .compactMap { $0?.airspaceFanModel }
            .receive(on: DispatchQueue.main)
            .map {
                FanViewModel.speedTable[String($0.prefix(4))] ?? 1 }
            .map { count -> [String] in Range(0...count).map { String($0) } }
            .map {
                var newArr = $0
                newArr[$0.startIndex] = "Off"
                newArr[$0.endIndex - 1] = $0.count <= 2 ? "On" : "Max"
                return newArr
            }
            .assign(to: &$controllerSegments)
        
        model.$fanCharacteristics
            .compactMap { $0 }
            .map { ($0.interlock1 || $0.interlock2) }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] alarm in
                if alarm {
                    self?.fanLamps.insert(.interlockActive)
                } else {
                    self?.fanLamps.remove(.interlockActive)
                }
            })
            .store(in: &bag)
        
        model.$commError
            .receive(on: DispatchQueue.main)
            .filter { $0 != nil }
            .sink(receiveValue: { [weak self] err in
                print("Comm error: \(err.debugDescription)")
                if let house = self?.house, let chars = self?.model.fanCharacteristics {
                    house.fans.remove(chars)
                }
            })
            .store(in: &bag)
//        
//        model.$timerBusy
//            .receive(on: DispatchQueue.main)
//            .sink (receiveValue: { [weak self] flags in
//                if flags.contains(.damperOperating) {
//                    self?.displayedLamps.insert(.damperOpening)
//                } else {
//                    self?.displayedLamps.remove(.damperOpening)
//                }
//                
//                if flags.contains(.speedAdjusting) {
//                    self?.displayedLamps.insert(.speedAdjusting)
//                } else {
//                    self?.displayedLamps.remove(.speedAdjusting)
//                }
//                
//                if flags.contains(.timerAdjusting) {
//                    self?.displayedLamps.insert(.timerActive)
//                } else {
//                    self?.displayedLamps.remove(.timerActive)
//                }
//                
//                if flags.contains(.fanOff) {
//                    self?.displayedLamps.insert(.fanOff)
//                } else {
//                    self?.displayedLamps.remove(.fanOff)
//                }
//                
//            })
//            .store(in: &bag)
        
        weather.$currentTempStr
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                guard let self = self else { return }
                if self.weather.tooCold { self.displayedLamps.insert(.tooCold) } else { self.displayedLamps.remove(.tooCold) }
                if self.weather.tooHot { self.displayedLamps.insert(.tooHot) } else { self.displayedLamps.remove(.tooHot) }
            })
            .store(in: &bag)
        }
    }

extension FanViewModel {
    private func setDisplayMotor(toSpeed: Int) {
        guard displayedMotorSpeed != toSpeed else { return }
        let scaleFactor = 3.5
        displayedMotorSpeed = toSpeed
        guard toSpeed != 0 else { displayMotor.send(Just(0.0).eraseToAnyPublisher()); return }
        let s = Double(toSpeed)
        displayMotor.send(
            Timer.publish(every: scaleFactor * 1/s, on: .main, in: .common)
                .autoconnect()
            .map { _ in scaleFactor * 1/s }
            .eraseToAnyPublisher())
    }
}
