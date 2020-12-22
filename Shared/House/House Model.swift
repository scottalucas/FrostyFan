//
//  House Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI

class House: ObservableObject {
    @Published var fansAt = [String]() //IP addresses
    
    func getView (usingHouse house: House? = nil) -> some View {
        HouseViewModel(withHouse: house ?? self).getView()
    }
}

struct DummyFanModel {
    var models = [String]()
    
    init () {
        models = ["One", "Two"]
    }
    
    func getView() -> some View {
        Group {
            ForEach ((0..<models.count)) { idx in
                return Text(models[idx])
            }
        }
    }
}

class TestHouse: House {
    override init () {
        super.init()
//        fansAt = ["0.0.0.0:8181", "192.168.1.122"]
        fansAt = ["0.0.0.0:8181"]
    }
}
