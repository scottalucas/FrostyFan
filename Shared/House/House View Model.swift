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
    private var status = HouseStatus() {
        willSet {
            indicators = setHouseLamps(status: newValue)
        }
    }
    private var scanModel: () async -> Void
    @Published var fanViews = Set<FanView>()
    @Published var indicators = HouseLamps()
    @Published var pullDownOffset: CGFloat = .zero
    @Published var isRefreshing = false
    @Published var progress: Double?
    
    private var bag = Set<AnyCancellable>()
    
    init (dataSource: HouseDataSource = House()) {
        scanModel = dataSource.scan

        dataSource
            .fanSetPub
            .map { $0.map
                { chars in
                    FanView(initialCharacteristics: chars)
                }
            }
            .map { Set($0) }
            .assign(to: &$fanViews)
        
        dataSource
            .progress
            .assign(to: &$progress)
    }
        
   
    private func setHouseLamps(status: HouseStatus) -> HouseLamps {
        var retVal = HouseLamps()
        
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
        fanViews.removeAll()
        await scanModel()
    }
}
