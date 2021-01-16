//
//  whf001App.swift
//  Shared
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI
import CoreLocation
import Combine

@main
struct AirspaceFanApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WeatherSettings())
                .environmentObject(HouseSettings())
                .environmentObject(FanSettings())
        }
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

