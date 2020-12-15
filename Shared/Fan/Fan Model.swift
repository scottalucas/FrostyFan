//
//  Fan Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import Combine
import SwiftUI

class FanModel: ObservableObject {
    @ObservedObject var connection = FanConnection()
    private var characteristics = Dictionary<String, String>()
    @State private var ipAddr: String?
    @Published var speed: Int?
    @Published var model: String?
    @Published var swVersion: String?
    @Published var availableLevels: Int?
    @Published var opening: Bool?
    @Published var timerRemaining: Int?
    @Published var macAddr: String?
    @Published var interlock1: Bool?
    @Published var interlock2: Bool?
    @Published var cfm: Int?
    @Published var power: Int?
    @Published var houseTemp: Int?
    @Published var atticTemp: Int?
    @Published var serverResponse: String?
    @Published var dipSwitches: String?
    @Published var remoteSwitch: String?
    @Published var setpoint: Int?
    
    init(forAddress address: String) {
        connection = FanConnection(address: address)
        ipAddr = address
        
        connection.characteristicsPublisher
            .map({ dict in
                dict["macaddr"] ?? nil
            })
            .receive(on: DispatchQueue.main)
            .assign(to: &$macAddr)
        
        connection.characteristicsPublisher
            .map({ dict in
                guard let s = dict["fanspd"], let s2 = s, let spd = Int(s2) else { return nil }
                return spd
            })
            .receive(on: DispatchQueue.main)
            .assign(to: &$speed)
        


        connection.characteristicsPublisher
            .map({ dict in
                dict["model"] ?? nil
            })
            .receive(on: DispatchQueue.main)
            .assign(to: &$model)
        
        connection.characteristicsPublisher
            .map({ dict in
                guard let inProcess = dict["doorinprocess"] else { return nil }
                return inProcess == "1" ? true : false
            })
            .receive(on: DispatchQueue.main)
            .assign(to: &$opening)
    }
    
    func update(_ msg: Int? = nil) {
            connection.update(action: msg)
    }
    
    func getView () -> some View {
        FanViewModel(forModel: self).getView()
    }
}

extension FanModel {
    convenience init () {
        self.init(forAddress: "0.0.0.0:8181")
    }
}
