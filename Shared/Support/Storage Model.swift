//
//  Storage Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/10/21.
//

import Foundation
import Combine
import CoreLocation

class FanSettings: ObservableObject {
    typealias MacAddr = String
    static var Key = "fanSettings"
    @Published var fans: Dictionary<MacAddr, FanStorageValue.Fan>? {
        willSet {
            store(sets: FanStorageValue(fans: newValue))
        }
    }
    
    struct FanStorageValue: Codable {
        var fans: Dictionary<MacAddr, Fan>?
        struct Fan: Codable {
            var lastIp: String?
            var name: String?
        }
    }
    
    init () {
        retreive()
    }
    
    private func store (sets: FanStorageValue) {
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(sets)) ?? Data()
        UserDefaults.standard.setValue(data, forKey: FanSettings.Key)
    }
    
    private func retreive () {
        let decoder = JSONDecoder()
        guard
            let data = UserDefaults.standard.data(forKey: FanSettings.Key),
            let retValue = try? decoder.decode(FanStorageValue.self, from: data)
        else { fans = [:]; return }
        fans = retValue.fans
    }
}

class HouseSettings: ObservableObject {
    static var Key = "houseSettings"
    
    @Published var fanLocation: CLLocation? {
        willSet {
            storeLocation(newLocation: newValue)
        }
    }

    struct HouseStorageValue: Codable {
        var fanLocation: FanLocation?
        var fanCLLocation: CLLocation? {
            return fanLocation.map {CLLocation(latitude: $0.lat, longitude: $0.lon) } ?? nil
        }
        struct FanLocation: Codable {
            var lat: Double
            var lon: Double
        }
        init (fromLoc loc: CLLocation?) {
            fanLocation = loc.map { FanLocation(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) } ?? nil
        }
    }
    
    init () {
        retrieve()
    }
    
    private func storeLocation (newLocation loc: CLLocation?) { //send a nil to clear location
        let newLoc = HouseStorageValue(fromLoc: loc)
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(newLoc)) ?? Data()
        UserDefaults.standard.setValue(data, forKey: HouseSettings.Key)
    }
    
    private func retrieve () {
        let decoder = JSONDecoder()
        guard
            let data = UserDefaults.standard.data(forKey: HouseSettings.Key),
            let decodeVal = try? decoder.decode(HouseStorageValue.self, from: data)
        else { return }
        fanLocation = decodeVal.fanCLLocation
        return
    }
}

class WeatherSettings: ObservableObject {
    static var Key = "weatherSettings"
    @Published var updatedWeather: (Date, WeatherObject)? {
        willSet {
            newValue.map { store(date: $0.0, weather: $0.1) } ?? UserDefaults.standard.removeObject(forKey: WeatherSettings.Key)
        }
    }
    private var bag = Set<AnyCancellable>()

    struct WeatherStorageValue: Codable {
        var lastUpdate: Date?
        var weather: WeatherObject?
    }
    
    init () {
        retrieve ()
    }

    private func store (date: Date, weather: WeatherObject) {
        let storeVal = WeatherStorageValue(lastUpdate: date, weather: weather)
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(storeVal)) ?? Data()
        UserDefaults.standard.setValue(data, forKey: WeatherSettings.Key)
    }
    
    private func retrieve () {
        let decoder = JSONDecoder()
        guard
            let data = UserDefaults.standard.data(forKey: WeatherSettings.Key),
            let decodeVal = try? decoder.decode(WeatherStorageValue.self, from: data),
            let date = decodeVal.lastUpdate,
            let weather = decodeVal.weather
        else { return }
        updatedWeather = (date, weather)
    }
}

struct ENV {
    private static let pListFilePath = Bundle.main.path(forResource: "Server", ofType: "plist")
    private static let pList = NSDictionary(contentsOfFile: pListFilePath!)!
    static let WEATHER_API_KEY: String = (pList["WeatherAPIKey"] as? String) ?? "not found"
}
