//
//  Storage Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/10/21.
//

import Foundation
import Combine
import CoreLocation

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
            guard let dat = (try? encoder.encode(newValue)) else { Storage.clear(.knownFans); return }
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
            guard let newValue = newValue else { Storage.clear(.lowTempLimit); return }
             UserDefaults.standard.set(newValue, forKey: StorageKey.lowTempLimit.rawValue)
        }
    }
    
    static var highTempLimit: Double? {
        get {
            UserDefaults.standard.object(forKey: StorageKey.highTempLimit.rawValue) == nil ? nil : UserDefaults.standard.double(forKey: StorageKey.highTempLimit.rawValue)
        }
        set {
            guard let newValue = newValue else { Storage.clear(.highTempLimit); return }
            UserDefaults.standard.set(newValue, forKey: StorageKey.highTempLimit.rawValue)
        }
    }

    static var storedWeather: Weather.WeatherResult? {
        get {
            UserDefaults.standard.object(forKey: StorageKey.forecast.rawValue) == nil ? nil : UserDefaults.standard.data(forKey: StorageKey.forecast.rawValue)?.decodeWeatherResult
        }
        set {
            guard let val = newValue else {
                UserDefaults.standard.removeObject(forKey: StorageKey.forecast.rawValue)
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
            guard let newValue = newValue else { Storage.clear(.coordinate); return }
            UserDefaults.standard.set(newValue.data, forKey: StorageKey.coordinate.rawValue)
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
    
    static func clear (_ key: StorageKey? = nil) {
        if let k = key?.rawValue {
            UserDefaults.standard.removeObject(forKey: k)
        } else {
            StorageKey.allCases.forEach({
                UserDefaults.standard.removeObject(forKey: $0.rawValue)
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
