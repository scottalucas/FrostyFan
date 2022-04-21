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
enum StorageKey: Equatable, RawRepresentable, CaseIterable {
    static var allCases: [StorageKey] {
        return [.knownFans, .interlockAlarmEnabled, .temperatureAlarmEnabled, .lowTempLimit, .highTempLimit, .forecast, .lastForecastUpdate, .lastNotificationShown, .coordinate, .fanName("")]
    }
    
    init?(rawValue: String) {
        if rawValue.prefix(4) == "name" {
            let addr = String(rawValue.dropFirst(4))
            self = .fanName(addr)
        } else if let val = StorageKey.init(rawValue: rawValue) {
            self = val
        } else {
            return nil
        }
    }
        
    typealias RawValue = String
    
    case knownFans, //data, decode to [String]
         interlockAlarmEnabled, //bool
         temperatureAlarmEnabled, //bool
         lowTempLimit, //double
         highTempLimit, //double
         forecast, //data, decode to WeatherResult
         lastForecastUpdate, //Date
         lastNotificationShown, //Date
         coordinate, //data, decode to Coordinate
         fanName (String) //string
    
    var rawValue: String {
        switch self {
        case .knownFans:
            return "knownFans"
            case .interlockAlarmEnabled:
                return "interlock"
            case .temperatureAlarmEnabled:
                return "tempAlarm"
            case .lowTempLimit:
                return "lowTempLimit"
            case .highTempLimit:
                return "highTempLimit"
            case .forecast:
                return "forecast"
            case .lastForecastUpdate:
                return "lastForecastUpdate"
            case .lastNotificationShown:
                return "lastNotificationShown"
            case .coordinate:
                return "coordinate"
            case .fanName(let macAddr):
                return "name\(macAddr)"
        }
    }
}

struct Storage {
    static var knownFans: Set<String> {
        get {
            UserDefaults.standard.object(forKey: StorageKey.knownFans.rawValue) == nil ? [] : UserDefaults.standard.data(forKey: StorageKey.knownFans.rawValue)?.decodeFans ?? []
        }
        set {
            let encoder = JSONEncoder()
            let dat = (try? encoder.encode(newValue)) ?? Data()
            UserDefaults.standard.set(dat, forKey: StorageKey.knownFans.rawValue)
        }
    }
    
    static var interlockAlarmEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: StorageKey.interlockAlarmEnabled.rawValue) == nil ? false : UserDefaults.standard.bool(forKey: StorageKey.interlockAlarmEnabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: StorageKey.interlockAlarmEnabled.rawValue)
        }
    }
    static var temperatureAlarmEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: StorageKey.temperatureAlarmEnabled.rawValue) == nil ? false : UserDefaults.standard.bool(forKey: StorageKey.temperatureAlarmEnabled.rawValue)
        }
        set {
             UserDefaults.standard.set(newValue, forKey: StorageKey.temperatureAlarmEnabled.rawValue)
        }
    }
    
    static var lowTempLimit: Double? {
        get {
            UserDefaults.standard.object(forKey: StorageKey.lowTempLimit.rawValue) == nil ? nil : UserDefaults.standard.double(forKey: StorageKey.lowTempLimit.rawValue)
        }
        set {
             UserDefaults.standard.set(newValue, forKey: StorageKey.lowTempLimit.rawValue)
        }
    }
    
    static var highTempLimit: Double? {
        get {
            UserDefaults.standard.object(forKey: StorageKey.highTempLimit.rawValue) == nil ? nil : UserDefaults.standard.double(forKey: StorageKey.highTempLimit.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: StorageKey.highTempLimit.rawValue)
        }
    }

    static var storedWeather: Weather.WeatherResult? {
        get {
            UserDefaults.standard.object(forKey: StorageKey.forecast.rawValue) == nil ? nil : UserDefaults.standard.data(forKey: StorageKey.forecast.rawValue)?.decodeWeatherResult
        }
        set {
            guard let val = newValue else {
                UserDefaults.standard.set(nil, forKey: StorageKey.forecast.rawValue)
                return
            }
            let obj = Weather.WeatherObject(fromResult: val).data
            UserDefaults.standard.set(obj, forKey: StorageKey.forecast.rawValue)
        }
    }
    
    static var lastForecastUpdate: Date {
        get {
            UserDefaults.standard.data(forKey: StorageKey.lastForecastUpdate.rawValue)?.decodeDate ?? .distantPast
        } set {
            UserDefaults.standard.set(newValue.data, forKey: StorageKey.lastForecastUpdate.rawValue)
        }
    }
    
    static var lastNotificationShown: Date {
        get {
            UserDefaults.standard.data(forKey: StorageKey.lastNotificationShown.rawValue)?.decodeDate ?? .distantPast
        } set {
            UserDefaults.standard.set(newValue.data, forKey: StorageKey.lastNotificationShown.rawValue)
        }
    }
    
    static var coordinate: Coordinate? {
        get {
            UserDefaults.standard.data(forKey: StorageKey.coordinate.rawValue)?.decodeCoordinate
        } set {
            UserDefaults.standard.set(newValue?.data, forKey: StorageKey.coordinate.rawValue)
        }
    }
    
    static func setName(forAddr addr: String, toName name: String) {
        let key = StorageKey.fanName(addr).rawValue
        UserDefaults.standard.set(name, forKey: key)
    }
    
    static func getName(forAddr addr: String) -> String {
        let key = StorageKey.fanName(addr).rawValue
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
    
    static func clear (_ key: StorageKey? = nil) {
        if let k = key?.rawValue {
            UserDefaults.standard.set(nil, forKey: k)
        } else {
            StorageKey.allCases.forEach({
                UserDefaults.standard.set(nil, forKey: $0.rawValue)
            })
        }
    }
    
    static func printAll(forAddr macAddr: String? = nil) {
        StorageKey.allCases.forEach ({ key in
            if key == .fanName("") {
                print ("Key: fanName for addr \(macAddr ?? "nil"), Value: \(getName(forAddr: macAddr ?? ""))")
            } else {
                switch key {
                    case .temperatureAlarmEnabled:
                        print (key.rawValue, UserDefaults.standard.object(forKey: StorageKey.temperatureAlarmEnabled.rawValue) == nil ? "not set" : temperatureAlarmEnabled)
                    case .interlockAlarmEnabled:
                        print (key.rawValue, UserDefaults.standard.object(forKey: StorageKey.interlockAlarmEnabled.rawValue) == nil ? "not set" : interlockAlarmEnabled)
                    case .coordinate:
                        print (key.rawValue, coordinate == nil ? "not set": coordinate!)
                    case .lastForecastUpdate:
                        print (key.rawValue, UserDefaults.standard.object(forKey: StorageKey.lastForecastUpdate.rawValue) == nil ? "not set" : lastForecastUpdate == .distantPast ? "distant past" : lastForecastUpdate.formatted())
                    case .lastNotificationShown:
                        print (key.rawValue, UserDefaults.standard.object(forKey: StorageKey.lastNotificationShown.rawValue) == nil ? "not set" : lastNotificationShown == .distantPast ? "distant past" : lastNotificationShown.formatted())
                    case .forecast:
                        print (key.rawValue, storedWeather ?? "not set")
                    case .highTempLimit:
                        print (key.rawValue, highTempLimit?.debugDescription ?? "not set")
                    case .lowTempLimit:
                        print (key.rawValue, lowTempLimit?.debugDescription ?? "not set")
                    default:
                        break
                }
            }
        })
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
