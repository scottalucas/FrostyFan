//
//  Fan Model View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI

class FanViewModel: ObservableObject {
    @ObservedObject var model: FanModel
    @Published var fanRotationDuration: Double = 0.0
    @Published var opening: String = "No"
    @Published var airspaceFanModel: String = "Model number"
    @Published var name = "Fan"
    @Published var speedLevels = 5
    @State var displayedSpeed: Int = 0
    
    init (forModel model: FanModel) {
        self.model = model
        startSubscribers()
    }

    func update(msg: FanModel.Action? = nil) {
        model.update(msg)
    }

    func getView () -> some View {
        FanView(fanViewModel: self)
    }
}

extension FanViewModel {
    convenience init () {
        self.init(forModel: FanModel())
    }
}

extension FanViewModel {
    static var speedTable: [String:Int]  = [
        "3.5e" : 7,
        "4.4e" : 7,
        "5.0e" : 7,
        "2.5e" : 5,
        "3200" : 10,
        "3400" : 10,
        "4300" : 10,
        "5300" : 10
    ]
}

extension FanViewModel {
    func startSubscribers () {
        
        model.$macAddr
            .map { optAddr -> String in
                guard
                    let addr = optAddr,
                    let name = UserSettings().names[addr] else { return "Fan" }
                return name
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$name)

        model.$speed
            .map ({ spd in
                guard let s = spd else {return 0.0}
                return s == 0 ? Double(0) : Double(1/Double(s))
            })
            .assign(to: &$fanRotationDuration)
        
        model.$model
            .map {
                guard let modelNumber = $0 else { return 2 }
                return Self.speedTable[String(modelNumber.prefix(4))] ?? 2
            }
            .assign(to: &$speedLevels)
    }
}
