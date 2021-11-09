//
//  House View Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

//@MainActor
class HouseViewModel: ObservableObject {
    deinit { NotificationCenter.default.removeObserver(self, name: .removeFan, object: nil) }
    private var house: HouseDataSource
    private var status = HouseStatus() {
        willSet {
            indicators = setHouseLamps(status: newValue)
        }
    }
    @Published var fanViews = Set<FanView>()
    @Published var indicators = HouseLamps()
    @Published var pullDownOffset: CGFloat = .zero
    @Published var isRefreshing = false
    
    private var bag = Set<AnyCancellable>()
    
    init (dataSource: HouseDataSource = House()) {
        house = dataSource
        house
            .fanSetPub
            .map {
                $0
                    .map { chars in
                        FanView(initialCharacteristics: chars)
                    }
            }
            .map { Set($0) }
            .assign(to: &$fanViews)
        }
        
//        house.$isRefreshing
//            .assign(to: &$isRefreshing)
//
//        house.$fans
//            .map { charSet in
//                Set (
//                    charSet
//                        .map { FanView(initialCharacteristics: $0) }
//                )
//            }
//            .assign(to: &$fanViews)
//
//        house.$progress
//            .assign(to: &$progress)
        //        $status
//            .sink(receiveValue: { status in
//                if status.contains(.scanning) {
//                    self.indicators.insert(.showScanningSpinner)
//                } else {
//                    self.indicators.remove(.showScanningSpinner)
//                }
//
//                if status.contains(.temperatureAlarmsEnabled) && !status.isDisjoint(with: [.tooHot, .tooCold]) {
//                    self.indicators.insert(.showTemperatureWarning)
//                    self.indicators.insert(.useAlarmColor)
//                } else {
//                    self.indicators.remove(.showTemperatureWarning)
//                    self.indicators.remove(.useAlarmColor)
//                }
//
//                if status.contains(.noFansAvailable) {
//                    self.indicators.insert(.showNoFanWarning)
//                } else {
//                    self.indicators.remove(.showNoFanWarning)
//                }
//
//                if status.contains(.temperatureAvailable) {
//                    self.indicators.insert(.showTemperatureText)
//                } else {
//                    self.indicators.remove(.showTemperatureText)
//                }
//            })
//            .store(in: &bag)
//
//        house.$fans
//            .assign(to: &$fans)
        
//    }
//    func scan () {
//        house.scanForFans()
//    }
    
    private func setHouseLamps(status: HouseStatus) -> HouseLamps {
        var retVal = HouseLamps()
//        if status.contains(.scanning) {
//            retVal.insert(.showScanningSpinner)
//        }
        
        if status.contains(.temperatureAlarmsEnabled) && !status.isDisjoint(with: [.tooHot, .tooCold]) {
            retVal.insert(.showTemperatureWarning)
            retVal.insert(.useAlarmColor)
        }
        
        if status.contains(.noFansAvailable) {
            retVal.insert(.showNoFanWarning)
        }
        
        if status.contains(.temperatureAvailable) {
            retVal.insert(.showTemperatureText)
        }
        return retVal
    }
    
    func scan () async {
        await house.scan()
    }
}

extension HouseViewModel: HouseViewDataSource { }

protocol HouseViewDataSource: ObservableObject {
    var indicators: HouseLamps { get }
    var pullDownOffset: CGFloat { get }
    var isRefreshing: Bool { get }
}
