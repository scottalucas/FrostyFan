//
//  House View Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class HouseViewModel: ObservableObject {
//    private var status = HouseStatus() {
//        willSet {
//            indicators = setHouseLamps(status: newValue)
//        }
//    }
//    private var scanModel: () async -> Void
//    private var globalIndicators = GlobalIndicators.shared
    private var dataSource: House
    @Published var fanViews = Set<FanView>()
    @Published var indicators = HouseLamps()
    //    @Published var progress: Double?
    
//    private var bag = Set<AnyCancellable>()
    
    init (dataSource: House = House(), initialFans: Set<FanCharacteristics> = []) {
        fanViews = Set(initialFans.map { FanView(initialCharacteristics: $0) })
        self.dataSource = dataSource
    }
//    
//    
//    private func setHouseLamps(status: HouseStatus) -> HouseLamps {
//        var retVal = HouseLamps()
//        
//        if status.contains(.temperatureAlarmsEnabled) && !status.isDisjoint(with: [.tooHot, .tooCold]) {
//            retVal.insert(.showTemperatureWarning)
//            retVal.insert(.useAlarmColor)
//        }
//        
//        if status.contains(.noFansAvailable) {
//            retVal.insert(.showNoFanWarning)
//        }
//        
//        if status.contains(.temperatureAvailable) {
//            retVal.insert(.showTemperatureText)
//        }
//        return retVal
//    }
    
    func scan () async throws {
        fanViews.removeAll()
//        let data = dataSource.scan()
        for try await item in dataSource.scan() {
            fanViews.update(with: FanView(initialCharacteristics: item))
        }
    }
}
