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
    @State var currentPageTag: Int = 0
    @Published var fanModels = Array<FanModel>()
    @Published var scanning = false
    @Published var weatherString: String?
    private var userScan = false
    private var bag = Set<AnyCancellable>()
    
    init () {
        
        $scanning
            .filter { $0 }
            .sink(receiveValue: { _ in
                    House.shared.scanForFans()
            })
            .store(in: &bag)
        
        House.shared.$fansAt
            .map { Array.init($0) }
            .assign(to: &$fanModels)
        
        House.shared.$scanning
            .filter { !$0 }
            .assign(to: &$scanning)
        

        
        print("init house view model with fans \(fanModels.map({ $0.ipAddr }))")
    }
    
    func getView (viewModel: HouseViewModel? = nil) -> some View {
        HouseView(viewModel: self)
    }
}

class TestHouseViewModel: HouseViewModel {
    var testFans: [FanModel]
    init (testFans: [FanModel]) {
        self.testFans = testFans
        super.init()
        testFans.forEach({ House.shared.fansAt.update(with: $0) })
    }
}
