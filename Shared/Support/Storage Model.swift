//
//  Storage Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/10/21.
//

import Foundation
import Combine
import CoreLocation

class Storage: ObservableObject {
    typealias MacAddr = String
    typealias IpAddress = String
    typealias FanName = String
    private var defaults: UserDefaultsProtocol
    static let shared = Storage()
    static func mock(useDefaults defaults: UserDefaultsProtocol) -> Storage {
        Storage.init(defaults: defaults)
    }
    
    @Published var houseLocation: CLLocation? {
        willSet {
            houseStorage.fanLocation = newValue.map { HouseStorageValue.FanLocation(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) } ?? nil
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(houseStorage)) ?? Data()
            defaults.set(data, forKey: HouseStorageValue.Key)
        }
    }
    @Published var fanNames = Dictionary<MacAddr, FanName?>() { //use .update at call site
        willSet {
            for (macAddr, fanName) in newValue {
                var changedFan = fanStorage.fans[macAddr] ?? FanStorageValue.Fan()
                changedFan.name = fanName
                fanStorage.fans.updateValue(changedFan, forKey: macAddr)
            }
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(fanStorage)) ?? Data()
            defaults.set(data, forKey: FanStorageValue.Key)
        }
    }
    @Published var fanIpAddrs = Dictionary<MacAddr, IpAddress?>() {
        willSet {
            for (macAddr, ipAddr) in newValue {
                var changedFan = fanStorage.fans[macAddr] ?? FanStorageValue.Fan()
                changedFan.lastIp = ipAddr
                fanStorage.fans.updateValue(changedFan, forKey: macAddr)
            }
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(fanStorage)) ?? Data()
            defaults.set(data, forKey: FanStorageValue.Key)
        }
    }
    @Published var triggeredAlarms = Alarm() {
        willSet {
            houseStorage.triggeredAlarms = newValue
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(houseStorage)) ?? Data()
            defaults.set(data, forKey: HouseStorageValue.Key)
        }
    }
    @Published var configuredAlarms = Alarm() {
        willSet {
            newConfiguredAlarms = newValue.subtracting(configuredAlarms)
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(houseStorage)) ?? Data()
            houseStorage.configuredAlarms = newValue
            defaults.set(data, forKey: HouseStorageValue.Key)
        }
    }
    @Published private (set) var newConfiguredAlarms = Alarm ()
    
    @Published var lowTempLimitSet: Double? {
        willSet {
            houseStorage.lowTempLimitSet = newValue
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(houseStorage)) ?? Data()
            defaults.set(data, forKey: HouseStorageValue.Key)
        }
    }
    @Published var highTempLimitSet: Double? {
        willSet {
            houseStorage.highTempLimitSet = newValue
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(houseStorage)) ?? Data()
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
    
    private var fanStorage: FanStorageValue
    private var houseStorage: HouseStorageValue
    
    private init (defaults: UserDefaultsProtocol = UserDefaults.standard) {
        self.defaults = defaults
        let decoder = JSONDecoder()
        fanStorage = {
            guard
                let data = defaults.data(forKey: FanStorageValue.Key),
                let retValue = try? decoder.decode(FanStorageValue.self, from: data)
            else { return FanStorageValue(fans: [:]) }
           return retValue
        }()
        houseStorage = {
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
        fanNames = fanStorage.fans.compactMapValues({ $0.name })
        fanIpAddrs = fanStorage.fans.compactMapValues({ $0.lastIp })
        houseLocation = houseStorage.fanCLLocation
        triggeredAlarms = houseStorage.triggeredAlarms
        configuredAlarms = houseStorage.configuredAlarms
        lowTempLimitSet = houseStorage.lowTempLimitSet
        highTempLimitSet = houseStorage.highTempLimitSet
    }
}

extension Storage {
    struct FanStorageValue: Codable {
        static var Key = "fanStorage"
        var fans: Dictionary<MacAddr, Fan>
        struct Fan: Codable {
            var lastIp: String?
            var name: String?
        }
    }
    struct HouseStorageValue: Codable {
        static var Key = "houseStorage"
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
        static var Key = "weatherStorage"
        var lastUpdate: Date?
//        var nextUpdate: Date?
        var rawForecast: WeatherObject?
    }
}

protocol UserDefaultsProtocol {
    func data(forKey: String) -> Data?
    func set(_:Any?, forKey: String)
}

extension UserDefaults: UserDefaultsProtocol {}

enum StorageKey {
    case interlockAlert, temperatureAlert, lowTempLimit, highTempLimit, locationAvailable, forecast, lastForecastUpdate, locLat, locLon, fanName (String)
    
    var key: String {
        switch self {
        case .interlockAlert:
            return "interlockAlert"
        case .temperatureAlert:
            return "temperatureAlert"
        case .lowTempLimit:
            return "lowTempLimit"
        case .highTempLimit:
            return "highTempLimit"
        case .locationAvailable:
            return "locAvailable"
        case .forecast:
            return "forecast"
        case .lastForecastUpdate:
            return "lastForecastUpdate"
        case .locLat:
            return "locLat"
        case .locLon:
            return "locLon"
        case .fanName(let macAddr):
            return "name\(macAddr)"
        }
    }
}

struct ENV {
    private static let pListFilePath = Bundle.main.path(forResource: "Server", ofType: "plist")
    private static let pList = NSDictionary(contentsOfFile: pListFilePath!)!
    static let WEATHER_API_KEY: String = (pList["WeatherAPIKey"] as? String) ?? "not found"
}
