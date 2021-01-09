//
//  whf001App.swift
//  Shared
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

@main
struct AirspaceFanApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct FanSettings: Codable {
    static var Key = "fans"
    var fans = [String: Fan]()
    struct Fan: Codable {
        var lastIp = String()
        var name = String()
    }
    static func store (sets: FanSettings) {
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(sets)) ?? Data()
        UserDefaults.standard.setValue(data, forKey: FanSettings.Key)
    }
    
    static func retreive () -> FanSettings {
        let decoder = JSONDecoder()
        guard
            let data = UserDefaults.standard.data(forKey: FanSettings.Key),
            let retValue = try? decoder.decode(FanSettings.self, from: data)
        else { return FanSettings() }
        return retValue
    }
}

extension Array where Element == (String, String?) {
    var jsonData: Data? {
        let newDict = Dictionary(self, uniquingKeysWith: { (first, _) in first })
        guard let data = try? JSONSerialization.data(withJSONObject: newDict) else {
            return nil
        }
        return data
    }
}
