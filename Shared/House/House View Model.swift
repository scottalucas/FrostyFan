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
    private var model: House
    @State var currentPageTag: Int = 0
    @Published var fanModels = [FanModel]()
    
    init (withHouse: House) {
        self.model = withHouse
        
        model.$fansAt
            .map {
                $0.map { addr in
                    FanModel(forAddress: addr)
                }
            }
            .assign(to: &$fanModels)
        print("init house view model with fans \(fanModels.map({ $0.ipAddr }))")
    }
    
    func getView (viewModel: HouseViewModel? = nil) -> some View {
        HouseView(viewModel: self)
    }
}

class TestHouseViewModel: HouseViewModel {
    override init (withHouse: House = TestHouse()) {
        super.init(withHouse: TestHouse())
    }
}
