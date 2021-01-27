//
//  Test Objects.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 12/24/20.
//

import Foundation
import CoreLocation

struct TestItems {
//    static var fans: [String] = ["0.0.0.0:8181"]
        static var fans: [String] = []
}

class TestViewModel: ObservableObject {
    @Published var segmentState: Int = 0
    @Published var userSelection: Int?
    
    var userSelectedSpeed: Int?
    
    init () {
        Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
            self.segmentState = 4
        }
    }
}

class MockUserDefaults: UserDefaultsProtocol {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    var fanSettings: Settings.FanStorageValue
    var houseSettings: Settings.HouseStorageValue
    var weatherSettings: Settings.WeatherStorageValue
    
    init (fan: Settings.FanStorageValue, house: Settings.HouseStorageValue, weather: Settings.WeatherStorageValue) {
        fanSettings = fan
        houseSettings = house
        weatherSettings = weather
    }
    
    func data(forKey: String) -> Data? {
        switch forKey {
        case Settings.FanStorageValue.Key:
            print("Fan settings retrieved")
            return (try? encoder.encode(fanSettings)) ?? Data()
        case Settings.HouseStorageValue.Key:
            print("House settings retrieved")
            return (try? encoder.encode(houseSettings)) ?? Data()
        case Settings.WeatherStorageValue.Key:
            print("Weather settings retrieved")
            return (try? encoder.encode(weatherSettings)) ?? Data()
        default:
            return Data()
        }
    }
    
    func set(_ data: Any?, forKey: String) {
        guard let data = data as? Data else {
            print("Failed to set for key \(forKey)")
            return
        }
        switch forKey {
        case Settings.FanStorageValue.Key:
            print("Fan settings stored")
            fanSettings = (try? decoder.decode(Settings.FanStorageValue.self, from: data)) ?? Settings.FanStorageValue(fans: [:])
        case Settings.HouseStorageValue.Key:
            print("House settings stored")
            houseSettings = (try? decoder.decode(Settings.HouseStorageValue.self, from: data)) ?? Settings.HouseStorageValue()
        case Settings.WeatherStorageValue.Key:
            print("Weather settings stored")
            weatherSettings = (try? decoder.decode(Settings.WeatherStorageValue.self, from: data)) ?? Settings.WeatherStorageValue()
        default:
            return
        }
    }
}

class MockLocationManager: LocationManagerProtocol {
    var delegate: CLLocationManagerDelegate?
    
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    
    func requestWhenInUseAuthorization() {
        return
    }
    
    func startUpdatingLocation() {
        return
    }
    
    func stopUpdatingLocation() {
        return
    }
    
    static func locationServicesEnabled() -> Bool {
        true
    }
    
    
}

struct SettingsMocks {
    var mockDefaults: MockUserDefaults
    var mockSettings: Settings
    var mockViewModel: SettingsViewModel
    var mockLocationManager = MockLocationManager()
    init () {
        var fans = Settings.FanStorageValue(fans: [:])
        var house = Settings.HouseStorageValue()
        var weather = Settings.WeatherStorageValue()
        house.configuredAlarms = [.interlock, .tooHot, .tooCold]
//        house.fanLocation = nil
        house.fanLocation = Settings.HouseStorageValue.FanLocation(lat: 37.3230, lon: 122.0575)
        mockDefaults = MockUserDefaults(fan: fans, house: house, weather: weather)
        mockSettings = Settings.mock(useDefaults: mockDefaults)
        mockLocationManager.authorizationStatus = .authorizedAlways
        var locMgr = LocationManager.mock(usingMgr: mockLocationManager, usingSettings: mockSettings)
        mockViewModel = SettingsViewModel(settings: mockSettings, location: locMgr)
        mockDefaults.houseSettings.configuredAlarms = [.interlock, .tooHot, .tooCold]
//        mockLocationManager.
    }
}
