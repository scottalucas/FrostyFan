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
    @Published var fanRotationDuration: Double = 0.0
    @Published var displayedSegmentNumber: Int = -1
    @Published var airspaceFanModel: String?
    @Published var controllerSegments: [String] = ["Off", "On"]
    @Published var timer = 0
    @Published var offDateTxt = ""
    @Published var physicalFanSpeed: Int?
    @Published var displayedLamps = Lamps()
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
            .receive(on: DispatchQueue.main)
            .map { $0.timer }
            .map { timeTillOff in
                guard timeTillOff > 0 else { return "" }
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return "Off at \(formatter.string(from: Date(timeIntervalSinceNow: TimeInterval(timeTillOff * 60))))"
            }
            .assign(to: &$offDateTxt)

        model.$fanCharacteristics
            .receive(on: DispatchQueue.main)
            .map { $0.timer }
            .assign(to: &$timer)

        model.$fanCharacteristics
            .receive(on: DispatchQueue.main)
            .map { $0.speed }
            .sink(receiveValue: { [weak self] actualSpeed in
                guard let self = self else { return }
                if self.physicalFanSpeed == nil { self.displayedSegmentNumber = actualSpeed } //should only happen first time through
                self.physicalFanSpeed = actualSpeed
                self.setDisplayMotor(toSpeed: actualSpeed)
                if actualSpeed == 0 && self.displayedLamps.isDisjoint(with: .showPhysicalSpeed) { self.displayedLamps = [] }
            })
            .store(in: &bag)
        
        displayMotor
            .receive(on: DispatchQueue.main)
            .switchToLatest()
            .assign(to: &$fanRotationDuration)
        
        model.$fanCharacteristics
            .receive(on: DispatchQueue.main)
            .map { $0.airspaceFanModel }
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
            .receive(on: DispatchQueue.main)
            .map { ($0.interlock1, $0.interlock2) }
            .map { $0.0 || $0.1 }
            .sink(receiveValue: { [weak self] alarm in
                if alarm {
                    self?.displayedLamps.insert(.interlock)
                } else {
                    self?.displayedLamps.remove(.interlock)
                }
            })
            .store(in: &bag)
        
        model.$fanCharacteristics
            .receive(on: DispatchQueue.main)
            .map { $0.damper }
            .sink(receiveValue: { [weak self] damper in
                if damper {
                    self?.displayedLamps.insert(.damperOpening)
                } else {
                    self?.displayedLamps.remove(.damperOpening)
                }
            })
            .store(in: &bag)
        
        model.$targetSpeed
            .receive(on: DispatchQueue.main)
            .map { $0 == nil ? false : true }
            .sink(receiveValue: { [weak self] adjusting in
                if adjusting {
                    self?.displayedLamps.insert(.speedAdjusting)
                } else {
                    self?.displayedLamps.remove(.speedAdjusting)
                }
            })
            .store(in: &bag)
        
        model.$commError
            .receive(on: DispatchQueue.main)
            .filter { $0 != nil }
            .sink(receiveValue: { [weak self] err in
                print("Comm error: \(err.debugDescription)")
                self?.house.fans.remove(self!.model.fanCharacteristics)
            })
            .store(in: &bag)
        
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
