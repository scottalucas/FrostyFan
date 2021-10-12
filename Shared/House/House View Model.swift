//
//  House View Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

class HouseViewModel: ObservableObject {
    static let shared = HouseViewModel()
    @ObservedObject var house = House.shared
    @Published var fans = Set<FanCharacteristics>()
    @Published var indicators = HouseLamps()
    @Published private var status = House.shared.status
    private var bag = Set<AnyCancellable>()
    
    private init () {
        $status
            .sink(receiveValue: { status in
                if status.contains(.scanning) {
                    self.indicators.insert(.showScanningSpinner)
                } else {
                    self.indicators.remove(.showScanningSpinner)
                }
                
                if status.contains(.temperatureAlarmsEnabled) && !status.isDisjoint(with: [.tooHot, .tooCold]) {
                    self.indicators.insert(.showTemperatureWarning)
                    self.indicators.insert(.useAlarmColor)
                } else {
                    self.indicators.remove(.showTemperatureWarning)
                    self.indicators.remove(.useAlarmColor)
                }
                
                if status.contains(.noFansAvailable) {
                    self.indicators.insert(.showNoFanWarning)
                } else {
                    self.indicators.remove(.showNoFanWarning)
                }
                
                if status.contains(.temperatureAvailable) {
                    self.indicators.insert(.showTemperatureText)
                } else {
                    self.indicators.remove(.showTemperatureText)
                }
            })
            .store(in: &bag)
        
        house.$fans
            .assign(to: &$fans)
        
    }
    func scan () {
        house.scanForFans()
    }
}
//    typealias IPAddr = String
//    
////    @State var currentPageTag: Int = 0
////    @Published var fanModels = Array<IPAddr>()
////    @Published var scanning = false
//    @Binding var fans: Array<String>
//    @Binding var runningFans: Array<String>
//    @Binding var scanning: Bool
////    @Published var weatherString: String?
//    private var house: House
////    private var userScan = false
////    private var bag = Set<AnyCancellable>()
//    
////    init () {
////        self.house = house
////        $scanning
////            .filter { $0 }
////            .sink(receiveValue: { [weak self] _ in
////                self?.house.scanForFans()
////            })
////            .store(in: &bag)
////
////        house.$fans
////            .map { Array.init($0) }
////            .assign(to: &$fanModels)
////
////        house.$scanning
////            .filter { !$0 }
////            .assign(to: &$scanning)
//        
//
//        
////        print("init house view model with fans \(fanModels.map({ $0 }))")
////    }
//    
////    func getView (viewModel: HouseViewModel? = nil) -> some View {
////        HouseView(viewModel: self)
////    }
//}
//
//class TestHouseViewModel: HouseViewModel {
//    var testFans: [FanModel]
//    init (testFans: [FanModel]) {
//        self.testFans = testFans
//        super.init()
//        testFans.forEach({ House.shared.fansAt.update(with: $0) })
//    }
//}
