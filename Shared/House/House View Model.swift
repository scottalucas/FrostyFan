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
    private var dataSource: House
    @Published var fanViews = Set<FanView>()
    @Published var displayedFanID: FanView.MACAddr = "not set"
    @Published var displayedRPM: Int = 0
    private var bag = Array<AnyCancellable>()
    
    init (dataSource: House = House(), initialFans: Set<FanCharacteristics> = []) {
        fanViews = Set( initialFans.map { FanView( initialCharacteristics: $0 ) } )
        self.dataSource = dataSource
        
        HouseMonitor.shared.$fanRPMs
            .combineLatest($displayedFanID)
            .compactMap { (speeds, id) in speeds[id] }
            .assign(to: &$displayedRPM)
    }

    func scan () async throws {
        guard !HouseMonitor.shared.scanning else { return }
        fanViews.removeAll()
        for try await item in dataSource.scan() {
            let fView = FanView(initialCharacteristics: item)
            fanViews.update(with: fView)
            displayedFanID = item.macAddr
        }
    }
}
