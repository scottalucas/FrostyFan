//
//  Settings View Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    private var storage: Storage
    private var locMgr: LocationManager
    @Published private (set) var locationAvailable: LocationManager.LocationStatus = .unknown
    @Published var temperatureNotificationsRequested = false {
        willSet {
            if newValue {
                storage.configuredAlarms.insert([.tooHot, .tooCold])
            } else {
                storage.configuredAlarms.remove([.tooHot, .tooCold])
            }
        }
    }
    @Published var interlockNotificationRequested = false{
        willSet {
            if newValue {
                storage.configuredAlarms.insert([.interlock])
            } else {
                storage.configuredAlarms.remove([.interlock])
            }
        }
    }
    @Published var highTempLimit: Double? {
        willSet {
            if newValue != storage.highTempLimitSet {
                storage.highTempLimitSet = newValue
            }
        }
    }
    @Published var lowTempLimit: Double? {
        willSet {
            if newValue != storage.lowTempLimitSet {
                storage.lowTempLimitSet = newValue
            }
        }
    }
//    @Published private (set) var location: (lat: String, lon: String)?
    @Published private (set) var currentTemp: String?
    
    init (settings: Storage = Storage.shared, location: LocationManager = LocationManager.shared) {
        self.storage = settings
        locMgr = location
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
//
//        settings.$houseLocation
//            .map { loc in
//                loc.map { (String($0.coordinate.latitude), String($0.coordinate.longitude)) } ?? nil
//            }
//            .assign(to: &$location)
        
//        WeatherManager.shared.$currentTemp
//            .map { temp in
//                temp.map { String($0) } ?? nil
//            }
//            .assign(to: &$currentTemp)
        
//        requestAuthorization()
//        if storage.houseLocation == nil {
//            getLocation()
//        }
    }
    
//    func getLocation() {
//        locMgr.updateLocation()
//    }
//
//    func requestAuthorization () {
//        locMgr.requestAuthorization()
//    }
    
    func clearLocation () {
        storage.houseLocation = nil
    }
}

