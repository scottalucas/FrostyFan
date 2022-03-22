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
    @Published var fanViews = Set<FanView>()
    @Published var displayedFanID: FanView.MACAddr = "not set"
    @Published var displayedRPM: Int = 0
    @Published var useAlarmColor: Bool = false
    private var dataSource: House
    private var bag = Array<AnyCancellable>()
    
    init (dataSource: House = House(), initialFans: Set<FanCharacteristics> = []) {
        fanViews = Set( initialFans.map { FanView( initialCharacteristics: $0 ) } )
        self.dataSource = dataSource
        
        HouseMonitor.shared.$fanRPMs
            .combineLatest($displayedFanID)
            .compactMap { (speeds, id) in speeds[id] }
            .assign(to: &$displayedRPM)
        
        HouseMonitor.shared.$fanRPMs
            .map {
                $0.values.reduce(.zero, +) > 0 && (WeatherMonitor.shared.tooHot || WeatherMonitor.shared.tooCold)
            }
            .assign(to: &$useAlarmColor)

    }

    func scan () async throws {
        guard !(HouseMonitor.shared.scanning ?? false) else { return }
        print("Scanning...")
        fanViews.removeAll()
        do {
            for try await item in dataSource.lowLevelScan() {
                let fView = FanView(initialCharacteristics: item)
                fanViews.update(with: fView)
                displayedFanID = item.macAddr
            }
        } catch {
            print(error)
            HouseMonitor.shared.scanning = false
        }
    }
}
