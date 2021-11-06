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
    deinit { NotificationCenter.default.removeObserver(self, name: .removeFan, object: nil) }
//    static let shared = HouseViewModel()
    private var house: House
    private var status = HouseStatus() {
        willSet {
            indicators = setHouseLamps(status: newValue)
        }
    }
    
    @Published var fanViews = Set<FanView>()
    @Published var progress: Double?
    @Published var indicators = HouseLamps()
    @Published var scanning = false
    @Published var pullDownOffset: CGFloat = .zero
//    @Published var refreshing = false
    
    private var bag = Set<AnyCancellable>()
    
    init () {
        house = House()
        NotificationCenter.default.addObserver(forName: .removeFan, object: nil, queue: nil) { [weak self] noti in
            guard let fan = noti.userInfo?.keys.first as? FanView else { return }
            self?.fanViews.remove(fan)
        }
        house.$fans
            .map { charSet in
                Set (
                    charSet
                        .map { FanView(initialCharacteristics: $0) }
                )
            }
            .assign(to: &$fanViews)
        
        house.$progress
            .assign(to: &$progress)
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
        
    }
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
    
    func asyncScan () async {
        fanViews.removeAll()
        Task {
//            await house.scannerAsync()
            if fanViews.count == 0 {
                status.update(with: .noFansAvailable)
            } else {
                status.remove(.noFansAvailable)
            }
        }
//        let taskGroup = await house.scannerAsync()
//        for await (addr, optChars) in taskGroup {
//            if var chars = optChars {
//                print("Addr: \(addr), chars: \(chars)")
//                chars.ipAddr = addr
//                let newFanView = await FanView(addr: addr, chars: chars, houseViewModel: self)
//                fanViews.update(with: newFanView)
//            }
//        }
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
