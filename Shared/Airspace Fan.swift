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
    let location = Location()
    let weather = Weather()
    let sharedHouseData = SharedHouseData.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sharedHouseData)
                .environmentObject(weather)
                .environmentObject(location)
        }
    }
    
    init () {
        UITableView.appearance().backgroundColor = .main
        UITableView.appearance().separatorColor = .main
        UIPageControl.appearance().currentPageIndicatorTintColor = .main
        UIPageControl.appearance().pageIndicatorTintColor = .main.withAlphaComponent(0.25)

    }
}

private struct ProgressKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    var updateProgress: Double? {
        get { self[ProgressKey.self] }
        set { self[ProgressKey.self] = newValue }
    }
}

extension View {
    func scanProgress(_ progress: Double?) -> some View {
        environment(\.updateProgress, progress)
    }
}




