//
//  House View Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

//class HouseViewModel {
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
