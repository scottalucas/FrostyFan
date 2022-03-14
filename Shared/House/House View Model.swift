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
//    @Published var indicators = HouseLamps()
    @Published var displayedFanID: FanView.MACAddr = "not set"
    @Published var displayedRPM: Int = 0
//    @Published var currentFanViewModel: FanViewModel?
//    var fanSpeedPublishers = [ FanView.MACAddr : AnyPublisher<Int, Never> ]()
    private var bag = Array<AnyCancellable>()
    
    init (dataSource: House = House(), initialFans: Set<FanCharacteristics> = []) {
        fanViews = Set( initialFans.map { FanView( initialCharacteristics: $0 ) } )
//        fanSpeedPublishers = spds
        self.dataSource = dataSource
        
        HouseMonitor.shared.$fanRPMs
            .combineLatest($displayedFanID)
            .compactMap { (speeds, id) in speeds[id] }
//            .print("ID")
//            .handleEvents(receiveSubscription: nil, receiveOutput: { model in
//                print("House VM stored id \(model?.mark)")
//            })
            .assign(to: &$displayedRPM)

//        
//        $displayedRPM
//            .sink(receiveValue: { val in
//                print("new rpm \(val)")
//            })
//            .store(in: &bag)
        
    }

    func scan () async throws {
        guard !HouseMonitor.shared.scanning else { return }
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
