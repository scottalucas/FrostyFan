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
    @Published var fanRotationDuration: Double = 0.0
    @Published var displayedSegmentNumber: Int = -1
    @Published var opening: String = "No"
    @Published var airspaceFanModel: String?
    @Published var macAddr: String = "BEEF"
    @Published var name = "Whole House Fan"
    @Published var controllerSegments: [String] = ["Off", "On"]
    @Published var interlocked: Bool = false
    @Published var timer: Int = 0
    @Published var testText: String?
    @AppStorage(Setting.fans) private var fanSettings = FanSettings()
    private var physicalFanSpeed: Int?
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
        fanSettings.fans[macAddr]?.name = name
    }
    
    func setFan(addTimerHours hoursToAdd: Int) {
        model.setFan(addHours: hoursToAdd)
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
            .map { ($0.macAddr, $0.airspaceFanModel) }
            .map { [weak self] (retrievedMacAddr, retrievedModelNumber) -> String in
                self?.fanSettings.fans[retrievedMacAddr]?.name ?? retrievedModelNumber }
            .receive(on: DispatchQueue.main)
            .assign(to: &$name)
        
        model.$fanCharacteristics
            .map { $0.macAddr }
            .receive(on: DispatchQueue.main)
            .assign(to: &$macAddr)
        
        model.$fanCharacteristics
            .map { $0.timer }
            .receive(on: DispatchQueue.main)
            .assign(to: &$timer)

        model.$fanCharacteristics
            .map { $0.speed }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] actualSpeed in
                if self?.physicalFanSpeed == nil { self?.displayedSegmentNumber = actualSpeed } //should only happen first time through
                self?.physicalFanSpeed = actualSpeed
                self?.setDisplayMotor(toSpeed: actualSpeed)
            })
            .store(in: &bag)
        
        displayMotor
            .switchToLatest()
            .assign(to: &$fanRotationDuration)
        
        model.$fanCharacteristics
            .map { $0.airspaceFanModel }
            .map { FanViewModel.speedTable[String($0.prefix(4))] ?? 1 }
            .map { count -> [String] in Range(0...count).map { String($0) } }
            .map {
                var newArr = $0
                newArr[$0.startIndex] = "Off"
                newArr[$0.endIndex - 1] = $0.count <= 2 ? "On" : "Max"
                return newArr
            }
            .assign(to: &$controllerSegments)
        
        model.$fanCharacteristics
            .map { ($0.interlock1, $0.interlock2) }
            .map { $0.0 || $0.1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$interlocked)
    }
}

extension FanViewModel {
    private func setDisplayMotor(toSpeed: Int) {
//        defer {print("out of scope")}
        guard displayedMotorSpeed != toSpeed else { return }
        let scaleFactor = 3.0
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
