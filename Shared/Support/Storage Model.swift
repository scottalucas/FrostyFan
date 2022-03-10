//
//  Storage Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/10/21.
//

import Foundation
import Combine
import CoreLocation

//class Storage: ObservableObject {
//    typealias MacAddr = String
//    typealias IpAddress = String
//    typealias FanName = String
//    private var defaults: UserDefaultsProtocol
//    static let shared = Storage()
//    private var fanStorage: FanStorageValue
//    private var houseStorage: HouseStorageValue
//    static func mock(useDefaults defaults: UserDefaultsProtocol) -> Storage {
//        Storage.init(defaults: defaults)
//    }
//    
//    @Published var houseLocation: CLLocation? {
//        willSet {
//            houseStorage.fanLocation = newValue.map { HouseStorageValue.FanLocation(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) } ?? nil
//            let encoder = JSONEncoder()
//            let data = (try? encoder.encode(houseStorage)) ?? Data()
//            defaults.set(data, forKey: HouseStorageValue.Key)
//        }
//    }
//    @Published var fanNames = Dictionary<MacAddr, FanName?>() { //use .update at call site
//        willSet {
//            for (macAddr, fanName) in newValue {
//                var changedFan = fanStorage.fans[macAddr] ?? FanStorageValue.Fan()
//                changedFan.name = fanName
//                fanStorage.fans.updateValue(changedFan, forKey: macAddr)
//            }
//            let encoder = JSONEncoder()
//            let data = (try? encoder.encode(fanStorage)) ?? Data()
//            defaults.set(data, forKey: FanStorageValue.Key)
//        }
//    }
//    @Published var fanIpAddrs = Dictionary<MacAddr, IpAddress?>() {
//        willSet {
//            for (macAddr, ipAddr) in newValue {
//                var changedFan = fanStorage.fans[macAddr] ?? FanStorageValue.Fan()
//                changedFan.lastIp = ipAddr
//                fanStorage.fans.updateValue(changedFan, forKey: macAddr)
//            }
//            let encoder = JSONEncoder()
//            let data = (try? encoder.encode(fanStorage)) ?? Data()
//            defaults.set(data, forKey: FanStorageValue.Key)
//        }
//    }
//    @Published var triggeredAlarms = Alarm() {
//        willSet {
//            houseStorage.triggeredAlarms = newValue
//            let encoder = JSONEncoder()
//            let data = (try? encoder.encode(houseStorage)) ?? Data()
//            defaults.set(data, forKey: HouseStorageValue.Key)
//        }
//    }
//    @Published var configuredAlarms = Alarm() {
//        willSet {
//            newConfiguredAlarms = newValue.subtracting(configuredAlarms)
//            let encoder = JSONEncoder()
//            let data = (try? encoder.encode(houseStorage)) ?? Data()
//            houseStorage.configuredAlarms = newValue
//            defaults.set(data, forKey: HouseStorageValue.Key)
//        }
//    }
//    @Published private (set) var newConfiguredAlarms = Alarm ()
//    
//    @Published var lowTempLimitSet: Double? {
//        willSet {
//            houseStorage.lowTempLimitSet = newValue
//            let encoder = JSONEncoder()
//            let data = (try? encoder.encode(houseStorage)) ?? Data()
//            defaults.set(data, forKey: HouseStorageValue.Key)
//        }
//    }
//    @Published var highTempLimitSet: Double? {
//        willSet {
//            houseStorage.highTempLimitSet = newValue
//            let encoder = JSONEncoder()
//            let data = (try? encoder.encode(houseStorage)) ?? Data()
//            defaults.set(data, forKey: HouseStorageValue.Key)
//        }
//    }
//    @Published var weatherStorageValue: WeatherStorageValue? {
//        willSet {
//            let encoder = JSONEncoder()
//            let data = (try? encoder.encode(newValue)) ?? Data()
//            defaults.set(data, forKey: WeatherStorageValue.Key)
//        }
//    }
//    
//    private init (defaults: UserDefaultsProtocol = UserDefaults.standard) {
//        self.defaults = defaults
//        let decoder = JSONDecoder()
//        fanStorage = {
//            guard
//                let data = defaults.data(forKey: FanStorageValue.Key),
//                let retValue = try? decoder.decode(FanStorageValue.self, from: data)
//            else { return FanStorageValue(fans: [:]) }
//           return retValue
//        }()
//        houseStorage = {
//            guard
//                let data = defaults.data(forKey: HouseStorageValue.Key),
//                let decodeVal = try? decoder.decode(HouseStorageValue.self, from: data)
//            else { return HouseStorageValue() }
//            return decodeVal
//        }()
//        weatherStorageValue = {
//            if let data = defaults.data(forKey: WeatherStorageValue.Key) {
//                return try? decoder.decode(WeatherStorageValue.self, from: data)
//            } else { return nil }
//        }()
//        
//        fanNames = fanStorage.fans.compactMapValues({ $0.name })
//        fanIpAddrs = fanStorage.fans.compactMapValues({ $0.lastIp })
//        houseLocation = houseStorage.fanCLLocation
////        triggeredAlarms = houseStorage.triggeredAlarms
////        configuredAlarms = houseStorage.configuredAlarms
//        lowTempLimitSet = houseStorage.lowTempLimitSet
//        highTempLimitSet = houseStorage.highTempLimitSet
//    }
//}
//
//extension Storage {
//    struct FanStorageValue: Codable {
//        static var Key = "fanStorage"
//        var fans: Dictionary<MacAddr, Fan>
//        struct Fan: Codable {
//            var configuredAlarms = Alarm.Fan.alwaysConfigured
//            var triggeredAlarms = Alarm.Fan()
//            var lastIp: String?
//            var name: String?
//        }
//    }
//    struct HouseStorageValue: Codable {
//        static var Key = "houseStorage"
//        var fanLocation: FanLocation?
//        var fanCLLocation: CLLocation? {
//            return fanLocation.map {CLLocation(latitude: $0.lat, longitude: $0.lon) } ?? nil
//        }
//        var configuredAlarms = Alarm.House.alwaysConfigured
//        var triggeredAlarms = Alarm.House()
//        var highTempLimitSet: Double?
//        var lowTempLimitSet: Double?
//        struct FanLocation: Codable {
//            var lat: Double
//            var lon: Double
//        }
//        init (fromLoc loc: CLLocation? = nil) {
//            fanLocation = loc.map { FanLocation(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) } ?? nil
//        }
//    }
//    struct WeatherStorageValue: Codable {
//        static var Key = "weatherStorage"
//        var lastUpdate: Date?
////        var nextUpdate: Date?
//        var rawForecast: WeatherObject?
//    }
//}

//protocol UserDefaultsProtocol {
//    func data(forKey: String) -> Data?
//    func set(_:Any?, forKey: String)
//}
//
//extension UserDefaults: UserDefaultsProtocol {}
enum StorageKey: Equatable {
    case interlockAlarmEnabled, //bool
         temperatureAlarmEnabled, //bool
         lowTempLimit, //double
         highTempLimit, //double
         //         locationAvailable,
         forecast, //data, decode to WeatherResult
         lastForecastUpdate, //Date
         coordinate, //data, decode to Coordinate
         fanName (String) //string
    var key: String {
        switch self {
            case .interlockAlarmEnabled:
                return "interlock"
            case .temperatureAlarmEnabled:
                return "tempAlarm"
            case .lowTempLimit:
                return "lowTempLimit"
            case .highTempLimit:
                return "highTempLimit"
                //        case .locationAvailable:
                //            return "locAvailable"
            case .forecast:
                return "forecast"
            case .lastForecastUpdate:
                return "lastForecastUpdate"
                //        case .locLat:
                //            return "locLat"
                //        case .locLon:
                //            return "locLon"
            case .coordinate:
                return "coordinate"
            case .fanName(let macAddr):
                return "name\(macAddr)"
        }
    }
}

struct Storage {
    static var interlockAlarmEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: StorageKey.interlockAlarmEnabled.key) == nil ? false : UserDefaults.standard.bool(forKey: StorageKey.interlockAlarmEnabled.key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: StorageKey.interlockAlarmEnabled.key)
        }
    }
    static var temperatureAlarmEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: StorageKey.temperatureAlarmEnabled.key) == nil ? false : UserDefaults.standard.bool(forKey: StorageKey.temperatureAlarmEnabled.key)
        }
        set {
             UserDefaults.standard.set(newValue, forKey: StorageKey.temperatureAlarmEnabled.key)
        }
    }
    
    static var lowTempLimit: Double? {
        get {
            UserDefaults.standard.object(forKey: StorageKey.lowTempLimit.key) == nil ? nil : UserDefaults.standard.double(forKey: StorageKey.lowTempLimit.key)
        }
        set {
             UserDefaults.standard.set(newValue, forKey: StorageKey.lowTempLimit.key)
        }
    }
    
    static var highTempLimit: Double? {
        get {
            UserDefaults.standard.object(forKey: StorageKey.highTempLimit.key) == nil ? nil : UserDefaults.standard.double(forKey: StorageKey.highTempLimit.key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: StorageKey.highTempLimit.key)
        }
    }

    static var storedWeather: Weather.WeatherResult? {
        get {
            UserDefaults.standard.object(forKey: StorageKey.forecast.key) == nil ? nil : UserDefaults.standard.data(forKey: StorageKey.forecast.key)?.decodeWeatherResult
        }
        set {
            guard let val = newValue else {
                UserDefaults.standard.set(nil, forKey: StorageKey.forecast.key)
                return
            }
            let obj = Weather.WeatherObject(fromResult: val).data
            UserDefaults.standard.set(obj, forKey: StorageKey.forecast.key)
        }
    }
    
    static var lastForecastUpdate: Date {
        get {
            UserDefaults.standard.data(forKey: StorageKey.lastForecastUpdate.key)?.decodeDate ?? .distantPast
        } set {
            UserDefaults.standard.set(newValue.data, forKey: StorageKey.lastForecastUpdate.key)
        }
    }
    
    static var coordinate: Coordinate? {
        get {
            UserDefaults.standard.data(forKey: StorageKey.coordinate.key)?.decodeCoordinate
        } set {
            UserDefaults.standard.set(newValue?.data, forKey: StorageKey.coordinate.key)
        }
    }
    
    static func setName(forAddr addr: String, toName name: String) {
        let key = StorageKey.fanName(addr).key
        UserDefaults.standard.set(name, forKey: key)
    }
    
    static func getName(forAddr addr: String) -> String {
        let key = StorageKey.fanName(addr).key
        return UserDefaults.standard.object(forKey: key) == nil ? "Fan \(addr)" : UserDefaults.standard.string(forKey: key) ?? "Fan \(addr)"
    }

//    func get() -> Any? {
//        switch self {
//            case .interlockAlarmEnabled, .temperatureAlarmEnabled:
//                return UserDefaults.standard.bool(forKey: self.key)
//            case .lowTempLimit, .highTempLimit:
//                return UserDefaults.standard.double(forKey: self.key)
//            case .forecast:
//                return UserDefaults.standard.data(forKey: self.key)?.decodeWeatherResult
//            case .lastForecastUpdate:
//                return UserDefaults.standard.data(forKey: self.key)?.decodeDate
//            case .coordinate:
//                return UserDefaults.standard.data(forKey: self.key)?.decodeCoordinate
//            case .fanName:
//                return UserDefaults.standard.string(forKey: self.key)
//        }
//    }
//
//    static var interlockAlarmEnabled: Bool {
//        UserDefaults.standard.bool(forKey: StorageKey.interlockAlarmEnabled.key)
//    }
//
//    var temperatureAlarmEnabled: Bool {
//        UserDefaults.standard.bool(forKey: StorageKey.temperatureAlarmEnabled.key)
//    }
//
//    var highTempLimit: Double {
//        UserDefaults.standard.double(forKey: StorageKey.highTempLimit.key)
//    }
//
//    var lowTempLimit: Double {
//        UserDefaults.standard.double(forKey: StorageKey.lowTempLimit.key)
//    }
//
//    var storedWeather: Weather.WeatherResult? {
//        UserDefaults.standard.data(forKey: StorageKey.forecast.key)?.decodeWeatherResult
//    }
//
//    var lastUpdate: Date {
//        UserDefaults.standard.data(forKey: StorageKey.lastForecastUpdate.key)?.decodeDate ?? .distantPast
//    }
//
//    var fanCoordinates: Coordinate? {
//        UserDefaults.standard.data(forKey: StorageKey.coordinate.key)?.decodeCoordinate
//    }
    
    static func clear (_ key: StorageKey) {
        UserDefaults.standard.set(nil, forKey: key.key)
    }
//
//    func set(to value: Any) throws {
//        switch self {
//            case .interlockAlarmEnabled, .temperatureAlarmEnabled:
//                guard let val = value as? Bool else { throw StorageError.typeMismatch }
//                UserDefaults.standard.set(val, forKey: self.key)
//            case .lowTempLimit, .highTempLimit:
//                switch value.self {
//                    case is Int:
//                        UserDefaults.standard.set(Double(value as! Int), forKey: self.key)
//                    case is Double:
//                        UserDefaults.standard.set(value as! Double, forKey: self.key)
//                    default:
//                        throw StorageError.typeMismatch
//                }
//            case .forecast:
//                guard let val = value as? Data else { throw StorageError.typeMismatch }
//                UserDefaults.standard.set(val, forKey: self.key)
//            case .lastForecastUpdate:
//                guard let val = value as? Date else { throw StorageError.typeMismatch }
//                UserDefaults.standard.set(val, forKey: self.key)
//            case .coordinate:
//                guard let val = value as? Coordinate else { throw StorageError.typeMismatch }
//                UserDefaults.standard.set(val.data, forKey: self.key)
//            case .fanName:
//                guard let val = value as? String else { throw StorageError.typeMismatch }
//                UserDefaults.standard.set(val, forKey: self.key)
//        }
//    }
//
//    enum StorageError: Error {
//        case typeMismatch, notFound
//    }
}

struct ENV {
    private static let pListFilePath = Bundle.main.path(forResource: "Server", ofType: "plist")
    private static let pList = NSDictionary(contentsOfFile: pListFilePath!)!
    static let WEATHER_API_KEY: String = (pList["WeatherAPIKey"] as? String) ?? "not found"
}
