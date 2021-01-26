//
//  Settings View Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    @Published private (set) var locationAvailable: Bool?
    @Published var temperatureNotificationsRequested = false {
        willSet {
            if newValue {
                Settings.shared.configuredAlarms.insert([.tooHot, .tooCold])
            } else {
                Settings.shared.configuredAlarms.remove([.tooHot, .tooCold])
            }
        }
    }
    @Published var interlockNotificationRequested = false{
        willSet {
            if newValue {
                Settings.shared.configuredAlarms.insert([.interlock])
            } else {
                Settings.shared.configuredAlarms.remove([.interlock])
            }
        }
    }
    @Published var highTempLimit: Double? {
        willSet {
            if newValue != Settings.shared.highTempLimitSet {
                Settings.shared.highTempLimitSet = newValue
            }
        }
    }
    @Published var lowTempLimit: Double? {
        willSet {
            if newValue != Settings.shared.lowTempLimitSet {
                Settings.shared.lowTempLimitSet = newValue
            }
        }
    }
    @Published private (set) var location: (lat: String, lon: String)?
    @Published private (set) var currentTemp: String?
    
    init () {
        Settings.shared.$configuredAlarms
            .map { alarms in
                !alarms.isDisjoint(with: [.tooHot, .tooCold])
            }
            .assign(to: &$temperatureNotificationsRequested)
        Settings.shared.$configuredAlarms
            .map { alarms in
                !alarms.isDisjoint(with: [.interlock])
            }
            .assign(to: &$interlockNotificationRequested)
        Settings.shared.$highTempLimitSet
            .assign(to: &$highTempLimit)
        Settings.shared.$lowTempLimitSet
            .assign(to: &$lowTempLimit)
        Settings.shared.$houseLocation
            .map { loc in
                loc.map { (String($0.coordinate.latitude), String($0.coordinate.longitude)) } ?? nil
            }
            .assign(to: &$location)
        WeatherManager.shared.$currentTemp
            .map { temp in
                temp.map { String($0) } ?? nil
            }
            .assign(to: &$currentTemp)
        LocationManager.shared.$authorized
            .assign(to: &$locationAvailable)
    }
    
    func getLocation() {
        LocationManager.shared.update()
    }
}
