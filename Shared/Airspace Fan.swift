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
//    let house = House.shared
//    let location = Location()
//    let appStatus = ApplicationStatus.shared
//    let weather: Weather
    let globalIndicators = GlobalIndicators.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(globalIndicators)
//                .environmentObject(weather)
//                .environmentObject(location)
//                .environmentObject(house)
        }
    }
    
    init () {
//        weather = Weather()
        UITableView.appearance().backgroundColor = .main
        UITableView.appearance().separatorColor = .main
    }
}

class GlobalIndicators: ObservableObject {
    static var shared: GlobalIndicators = GlobalIndicators()
    @Published var updateProgress: Double?
    @Published var houseAlarms = Array<HouseLamps>()
    @Published var fanAlarmDict = Dictionary<FanView.ID, FanLamps>()

    private init() {}
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




