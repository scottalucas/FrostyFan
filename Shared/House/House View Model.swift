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
    @Published var indicators = HouseLamps()
    @Published var displayedFanID: FanView.MACAddr = "not set"
    @Published var displayedRPM: Int = 0
//    var fanSpeedPublishers = [ FanView.MACAddr : AnyPublisher<Int, Never> ]()
    
    init (dataSource: House = House(), initialFans: Set<FanCharacteristics> = []) {
//        let views = Set(initialFans.map { FanView(initialCharacteristics: $0) })
//        let spds = Dictionary.init( uniqueKeysWithValues: views.map { ($0.id, $0.viewModel.$displayFanRpm.eraseToAnyPublisher()) } )
//
        fanViews = Set( initialFans.map { FanView( initialCharacteristics: $0 ) } )
//        fanSpeedPublishers = spds
        self.dataSource = dataSource
        
        $displayedFanID
            .print()
            .compactMap { displayedID in self.fanViews.first(where: { $0.id == displayedID }) }
            .flatMap { fanView in
                fanView.viewModel.$displayFanRpm
            }
            .assign(to: &$displayedRPM)
        
    }

    func scan () async throws {
        fanViews.removeAll()
//        fanSpeedPublishers.removeAll()
        for try await item in dataSource.scan() {
            let fView = FanView(initialCharacteristics: item)
            fanViews.update(with: fView)
            displayedFanID = item.macAddr
//            fanSpeedPublishers.updateValue(fView.viewModel.$displayFanRpm.eraseToAnyPublisher(), forKey: fView.id)
        }
    }
}
