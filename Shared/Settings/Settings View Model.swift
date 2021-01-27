//
//  Settings View Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    private var settings: Settings
    @Published private (set) var locationAvailable: Bool?
    @Published var temperatureNotificationsRequested = false {
        willSet {
            if newValue {
                settings.configuredAlarms.insert([.tooHot, .tooCold])
            } else {
                settings.configuredAlarms.remove([.tooHot, .tooCold])
            }
        }
    }
    @Published var interlockNotificationRequested = false{
        willSet {
            if newValue {
                settings.configuredAlarms.insert([.interlock])
            } else {
                settings.configuredAlarms.remove([.interlock])
            }
        }
    }
    @Published var highTempLimit: Double? {
        willSet {
            if newValue != settings.highTempLimitSet {
                settings.highTempLimitSet = newValue
            }
        }
    }
    @Published var lowTempLimit: Double? {
        willSet {
            if newValue != settings.lowTempLimitSet {
                settings.lowTempLimitSet = newValue
            }
        }
    }
    @Published private (set) var location: (lat: String, lon: String)?
    @Published private (set) var currentTemp: String?
    
    init (settings: Settings = Settings.shared, location: LocationManager = LocationManager.shared) {
        self.settings = settings
        settings.$configuredAlarms
            .map { alarms in
                !alarms.isDisjoint(with: [.tooHot, .tooCold])
            }
            .assign(to: &$temperatureNotificationsRequested)
        
        settings.$configuredAlarms
            .map { alarms in
                !alarms.isDisjoint(with: [.interlock])
            }
            .assign(to: &$interlockNotificationRequested)
        
        settings.$highTempLimitSet
            .assign(to: &$highTempLimit)
        
        settings.$lowTempLimitSet
            .assign(to: &$lowTempLimit)
        
        settings.$houseLocation
            .map { loc in
                loc.map { (String($0.coordinate.latitude), String($0.coordinate.longitude)) } ?? nil
            }
            .assign(to: &$location)
        
        WeatherManager.shared.$currentTemp
            .map { temp in
                temp.map { String($0) } ?? nil
            }
            .assign(to: &$currentTemp)
        
        location.$authorized
            .assign(to: &$locationAvailable)
    }
    
    func getLocation() {
        LocationManager.shared.update()
    }
    
    func clearLocation () {
        settings.houseLocation = nil
    }
}

