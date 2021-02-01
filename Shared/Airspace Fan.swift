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
    let house = House()
    let location = Location()
    let weather: Weather
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(weather)
                .environmentObject(location)
                .environmentObject(house)
        }
    }
    
    init () {
        weather = Weather(house: house)
        UITableView.appearance().backgroundColor = .main
        UITableView.appearance().separatorColor = .main
    }
}


