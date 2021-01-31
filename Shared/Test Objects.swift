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
    var fanStorage: Storage.FanStorageValue
    var houseStorage: Storage.HouseStorageValue
    var weatherStorage: Storage.WeatherStorageValue
    
    init (fan: Storage.FanStorageValue, house: Storage.HouseStorageValue, weather: Storage.WeatherStorageValue) {
        fanStorage = fan
        houseStorage = house
        weatherStorage = weather
    }
    
    func data(forKey: String) -> Data? {
        switch forKey {
        case Storage.FanStorageValue.Key:
            print("Fan settings retrieved")
            return (try? encoder.encode(fanStorage)) ?? Data()
        case Storage.HouseStorageValue.Key:
            print("House settings retrieved")
            return (try? encoder.encode(houseStorage)) ?? Data()
        case Storage.WeatherStorageValue.Key:
            print("Weather settings retrieved")
            return (try? encoder.encode(weatherStorage)) ?? Data()
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
        case Storage.FanStorageValue.Key:
            print("Fan settings stored")
            fanStorage = (try? decoder.decode(Storage.FanStorageValue.self, from: data)) ?? Storage.FanStorageValue(fans: [:])
        case Storage.HouseStorageValue.Key:
            print("House settings stored")
            houseStorage = (try? decoder.decode(Storage.HouseStorageValue.self, from: data)) ?? Storage.HouseStorageValue()
        case Storage.WeatherStorageValue.Key:
            print("Weather settings stored")
            weatherStorage = (try? decoder.decode(Storage.WeatherStorageValue.self, from: data)) ?? Storage.WeatherStorageValue()
        default:
            return
        }
    }
}

//class MockLocationManager: LocationManagerProtocol {
//    var delegate: CLLocationManagerDelegate?
//    
//    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
//    
//    func requestWhenInUseAuthorization() {
//        return
//    }
//    
//    func startUpdatingLocation() {
//        return
//    }
//    
//    func stopUpdatingLocation() {
//        return
//    }
//    
//    static func locationServicesEnabled() -> Bool {
//        true
//    }
//    
//    
//}
//
//struct StorageMocks {
//    var mockDefaults: MockUserDefaults
//    var mockStorage: Storage
//    var mockViewModel: SettingsViewModel
////    var mockLocationManager = MockLocationManager()
//    init () {
//        let fans = Storage.FanStorageValue(fans: [:])
//        var house = Storage.HouseStorageValue(fromLoc: CLLocation(latitude: .init(37.3230), longitude: .init(122.0575)))
//        let weather = Storage.WeatherStorageValue()
//        house.configuredAlarms = [.interlock, .tooHot, .tooCold]
////        house.fanLocation = nil
////        house.fanLocation = Storage.HouseStorageValue.FanLocation(lat: 37.3230, lon: 122.0575)
//        mockDefaults = MockUserDefaults(fan: fans, house: house, weather: weather)
//        mockStorage = Storage.mock(useDefaults: mockDefaults)
//        mockLocationManager.authorizationStatus = .authorizedWhenInUse
////        let locMgr = LocationManager.mock(usingMgr: mockLocationManager)
//        mockViewModel = SettingsViewModel(settings: mockStorage)
//        mockDefaults.houseStorage.configuredAlarms = [.interlock, .tooHot, .tooCold]
////        mockLocationManager.
//    }
//}
