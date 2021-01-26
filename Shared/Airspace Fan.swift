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
        }
    }
    
    init () {
        UITableView.appearance().backgroundColor = .main
        UITableView.appearance().separatorColor = .main
    }
}


