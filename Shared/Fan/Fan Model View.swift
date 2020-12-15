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
    
    init (forModel model: FanModel) {
        self.model = model
        
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
    }

    func update(msg: Int? = nil) {
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
