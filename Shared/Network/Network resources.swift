//
//  Network resources.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import Combine

class FanConnection: ObservableObject {
    private var ipAddress: String
    private var characteristics = CurrentValueSubject<Dictionary<String, String?>, Never>([:])
    @Published var characteristicsPublisher: AnyPublisher<Dictionary<String, String?>, Never>
    private var bag = Set<AnyCancellable>()
    static var requiredKeys: Set<String> = ["fanspd", "doorinprocess", "timeremaining", "macaddr", "ipaddr", "model", "softver", "interlock1", "interlock2", "cfm", "power" , "house_temp", "attic_temp", "DIPS", "switch2"]
    
    init (address ipAddress: String = "192.168.1.122") {
        self.ipAddress = ipAddress
        characteristicsPublisher = characteristics.eraseToAnyPublisher()
    }
}
