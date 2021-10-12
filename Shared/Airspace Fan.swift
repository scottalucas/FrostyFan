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
    let house = House.shared
    let location = Location()
//    let appStatus = ApplicationStatus.shared
    let weather: Weather
    
    var body: some Scene {
        WindowGroup {
            ContentView()
//                .environmentObject(appStatus)
                .environmentObject(weather)
                .environmentObject(location)
                .environmentObject(house)
        }
    }
    
    init () {
        weather = Weather()
        UITableView.appearance().backgroundColor = .main
        UITableView.appearance().separatorColor = .main
    }
}


