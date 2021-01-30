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
//    @EnvironmentObject var fanSettings: FanSettings
    @ObservedObject var model: FanModel
    @Published var fanRotationDuration: Double = 0.0
    @Published var displayedSegmentNumber: Int = -1
    @Published var opening: String = "No"
    @Published var airspaceFanModel: String?
    @Published var macAddr: String = "BEEF"
    @Published var name = ""
    @Published var controllerSegments: [String] = ["Off", "On"]
    @Published var interlocked: Bool = false
    @Published var timer = 0
    @Published var offDateTxt = ""
    @Published var testText: String?
    @Published var physicalFanSpeed: Int?
    @Published var showPhysicalSpeedIndicator: Bool = false
    @Published var bladeColor: UIColor = .main
    @Published var displayedAlarms = Alarm(rawValue: 0)
    private var displayedMotorSpeed: Int?
    private var displayMotor = PassthroughSubject<AnyPublisher<Double, Never>, Never>()
    
    private var bag = Set<AnyCancellable>()
    
    init (forModel model: FanModel) {
        self.model = model
        startSubscribers()
    }
    
    func setFan(toSpeed finalTarget: Int?) {
        model.setFan(toSpeed: finalTarget)
    }
    
    func setFan(name: String) {
        self.name = name
//        fanSettings.update(self)
    }
    
    func setFan(addTimerHours hoursToAdd: Int) {
        model.setFan(addHours: hoursToAdd)
    }
    
    func refresh () {
        model.setFan()
    }
    
    func raiseAlarm (forCondition condition: Alarm) {
        guard !condition.isDisjoint(with: Storage.shared.configuredAlarms) else {
            clearAlarm(forCondition: condition)
            return
        }
        displayedAlarms.update(with: condition)
        bladeColor = displayedAlarms.isDisjoint(with: Alarm.redColorAlarms) ? .main : .alarm
        showPhysicalSpeedIndicator = displayedAlarms.isDisjoint(with: Alarm.displaySpeedIndicator) ? false : true
    }

    func clearAlarm (forCondition cond: Alarm? = nil) {
        if let condition = cond {
            displayedAlarms.remove(condition)
            bladeColor = displayedAlarms.isDisjoint(with: Alarm.redColorAlarms) ? .main : .alarm
            showPhysicalSpeedIndicator = displayedAlarms.isDisjoint(with: Alarm.displaySpeedIndicator) ? false : true
        } else {
            displayedAlarms = []
            bladeColor = .main
            showPhysicalSpeedIndicator = false
        }
    }

    func getView () -> some View {
        FanView(fanViewModel: self)
    }
}

extension FanViewModel {
    convenience init () {
        self.init(forModel: FanModel())
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
            .filter { [weak self] _ in
                self?.name.count == 0
            }
            .map { $0.airspaceFanModel }
            .map { retrievedModelNumber -> String in
                return retrievedModelNumber.count == 0 ? "Whole House Fan" : retrievedModelNumber
            }
            .assign(to: &$name)
        
        model.$fanCharacteristics
            .receive(on: DispatchQueue.main)
            .map { $0.macAddr }
            .assign(to: &$macAddr)
        
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
                if self?.physicalFanSpeed == nil { self?.displayedSegmentNumber = actualSpeed } //should only happen first time through
                self?.physicalFanSpeed = actualSpeed
                self?.setDisplayMotor(toSpeed: actualSpeed)
                if actualSpeed == 0 { self?.clearAlarm() }
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
                    self?.raiseAlarm(forCondition: .interlock)
                } else {
                    self?.clearAlarm(forCondition: .interlock)
                }
            })
            .store(in: &bag)
        
        model.$targetSpeed
            .receive(on: DispatchQueue.main)
            .map { $0 == nil ? false : true }
            .sink(receiveValue: { [weak self] adjusting in
                if adjusting {
                    self?.raiseAlarm(forCondition: .adjustingSpeed)
                } else {
                    self?.clearAlarm(forCondition: .adjustingSpeed)
                }
            })
            .store(in: &bag)
        
        House.shared.$displayedAlarms
            .receive(on: DispatchQueue.main)
            .map { $0.intersection(Alarm.houseAlarms) }
            .sink(receiveValue: { [weak self] alarm in
                self?.displayedAlarms.remove(Alarm.houseAlarms)
                self?.raiseAlarm(forCondition: alarm)
            })
            .store(in: &bag)
        }
    }

extension FanViewModel {
    private func setDisplayMotor(toSpeed: Int) {
//        defer {print("out of scope")}
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
