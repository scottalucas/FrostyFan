//
//  Storage Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/10/21.
//

import Foundation
import Combine
import CoreLocation

class Settings: ObservableObject {
    typealias MacAddr = String
    typealias IpAddress = String
    typealias FanName = String
    private var defaults: UserDefaultsProtocol
    static let shared = Settings()
    static func mock(useDefaults defaults: UserDefaultsProtocol) -> Settings {
        Settings.init(defaults: defaults)
    }
    
    @Published var houseLocation: CLLocation? {
        willSet {
            houseSettings.fanLocation = newValue.map { HouseStorageValue.FanLocation(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) } ?? nil
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(houseSettings)) ?? Data()
            defaults.set(data, forKey: HouseStorageValue.Key)
        }
    }
    @Published var fanNames = Dictionary<MacAddr, FanName?>() { //use .update at call site
        willSet {
            for (macAddr, fanName) in newValue {
                var changedFan = fanSettings.fans[macAddr] ?? FanStorageValue.Fan()
                changedFan.name = fanName
                fanSettings.fans.updateValue(changedFan, forKey: macAddr)
            }
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(fanSettings)) ?? Data()
            defaults.set(data, forKey: FanStorageValue.Key)
        }
    }
    @Published var fanIpAddrs = Dictionary<MacAddr, IpAddress?>() {
        willSet {
            for (macAddr, ipAddr) in newValue {
                var changedFan = fanSettings.fans[macAddr] ?? FanStorageValue.Fan()
                changedFan.lastIp = ipAddr
                fanSettings.fans.updateValue(changedFan, forKey: macAddr)
            }
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(fanSettings)) ?? Data()
            defaults.set(data, forKey: FanStorageValue.Key)
        }
    }
    @Published var triggeredAlarms = Alarm() {
        willSet {
            houseSettings.triggeredAlarms = newValue
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(houseSettings)) ?? Data()
            defaults.set(data, forKey: HouseStorageValue.Key)
        }
    }
    @Published var configuredAlarms = Alarm() {
        willSet {
            newConfiguredAlarms = newValue.subtracting(configuredAlarms)
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(houseSettings)) ?? Data()
            houseSettings.configuredAlarms = newValue
            defaults.set(data, forKey: HouseStorageValue.Key)
        }
    }
    @Published private (set) var newConfiguredAlarms = Alarm ()
    
    @Published var lowTempLimitSet: Double? {
        willSet {
            houseSettings.lowTempLimitSet = newValue
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(houseSettings)) ?? Data()
            defaults.set(data, forKey: HouseStorageValue.Key)
        }
    }
    @Published var highTempLimitSet: Double? {
        willSet {
            houseSettings.highTempLimitSet = newValue
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(houseSettings)) ?? Data()
            defaults.set(data, forKey: HouseStorageValue.Key)
        }
    }
    @Published var weatherStorageValue: WeatherStorageValue? {
        willSet {
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(newValue)) ?? Data()
            defaults.set(data, forKey: WeatherStorageValue.Key)
        }
    }
    
    private var fanSettings: FanStorageValue
    private var houseSettings: HouseStorageValue
    
    private init (defaults: UserDefaultsProtocol = UserDefaults.standard) {
        self.defaults = defaults
        let decoder = JSONDecoder()
        fanSettings = {
            guard
                let data = defaults.data(forKey: FanStorageValue.Key),
                let retValue = try? decoder.decode(FanStorageValue.self, from: data)
            else { return FanStorageValue(fans: [:]) }
           return retValue
        }()
        houseSettings = {
            guard
                let data = defaults.data(forKey: HouseStorageValue.Key),
                let decodeVal = try? decoder.decode(HouseStorageValue.self, from: data)
            else { return HouseStorageValue() }
            return decodeVal
        }()
        weatherStorageValue = {
            if let data = defaults.data(forKey: WeatherStorageValue.Key) {
                return try? decoder.decode(WeatherStorageValue.self, from: data)
            } else { return nil }
        }()
        fanNames = fanSettings.fans.compactMapValues({ $0.name })
        fanIpAddrs = fanSettings.fans.compactMapValues({ $0.lastIp })
        triggeredAlarms = houseSettings.triggeredAlarms
        configuredAlarms = houseSettings.configuredAlarms
        lowTempLimitSet = houseSettings.lowTempLimitSet
        highTempLimitSet = houseSettings.highTempLimitSet
    }
}

extension Settings {
    struct FanStorageValue: Codable {
        static var Key = "fanSettings"
        var fans: Dictionary<MacAddr, Fan>
        struct Fan: Codable {
            var lastIp: String?
            var name: String?
        }
    }
    struct HouseStorageValue: Codable {
        static var Key = "houseSettings"
        var fanLocation: FanLocation?
        var fanCLLocation: CLLocation? {
            return fanLocation.map {CLLocation(latitude: $0.lat, longitude: $0.lon) } ?? nil
        }
        var configuredAlarms = Alarm()
        var triggeredAlarms = Alarm()
        var highTempLimitSet: Double?
        var lowTempLimitSet: Double?
        struct FanLocation: Codable {
            var lat: Double
            var lon: Double
        }
        init (fromLoc loc: CLLocation? = nil) {
            fanLocation = loc.map { FanLocation(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) } ?? nil
        }
    }
    struct WeatherStorageValue: Codable {
        static var Key = "weatherSettings"
        var lastUpdate: Date?
        var nextUpdate: Date?
        var rawForecast: WeatherObject?
    }
}

protocol UserDefaultsProtocol {
    func data(forKey: String) -> Data?
    func set(_:Any?, forKey: String)
}

extension UserDefaults: UserDefaultsProtocol {}

struct ENV {
    private static let pListFilePath = Bundle.main.path(forResource: "Server", ofType: "plist")
    private static let pList = NSDictionary(contentsOfFile: pListFilePath!)!
    static let WEATHER_API_KEY: String = (pList["WeatherAPIKey"] as? String) ?? "not found"
}
