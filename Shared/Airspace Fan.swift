//
//  whf001App.swift
//  Shared
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI
import CoreLocation
import Combine

@main
struct AirspaceFanApp: App {
    let weatherManager = WeatherManager.shared
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct Alarm: OptionSet {
    let rawValue: UInt8
    
    static let interlock = Alarm(rawValue: 1 << 0)
    static let tooCold = Alarm(rawValue: 1 << 1)
    static let tooHot = Alarm(rawValue: 1 << 2)
    static let adjustingSpeed = Alarm(rawValue: 1 << 3)
    
    static let redColorAlarms: Alarm = [.interlock, .tooCold, .tooHot]
    static let displaySpeedIndicator: Alarm = [.adjustingSpeed, .interlock]
    static let houseAlarms: Alarm = [.tooHot, .tooCold] //alarms raised by the house
    static let fanAlarms: Alarm = [.interlock, .adjustingSpeed] //alarms specific to a fan

    static func labels (forOptions options: Alarm) -> [String] {
        var retVal = Array<String>()
        if options.contains(interlock) {retVal.append("Interlock Active")}
        if options.contains(tooHot) {retVal.append("Outside Temperature High")}
        if options.contains(tooCold) {retVal.append("Outside Temperature Low")}
        return retVal
    }
    
}

struct FanSettings: Codable {
    static var Key = "fans"
    var fans = [String: Fan]()
    struct Fan: Codable {
        var lastIp = String()
        var name = String()
    }
    static func store (sets: FanSettings) {
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(sets)) ?? Data()
        UserDefaults.standard.setValue(data, forKey: FanSettings.Key)
    }
    
    static func retreive () -> FanSettings {
        let decoder = JSONDecoder()
        guard
            let data = UserDefaults.standard.data(forKey: FanSettings.Key),
            let retValue = try? decoder.decode(FanSettings.self, from: data)
        else { return FanSettings() }
        return retValue
    }
}

struct HouseSettings: Codable {
    static var Key = "house"
    private var loc: Location
    static var location = CurrentValueSubject<CLLocation?, Never>(nil)

    
    struct Location: Codable {
        var locationLat: Double = 0.0
        var locationLon: Double = 0.0
    }
    
    enum CodingKeys: String, CodingKey {
        case loc
    }
    
    static func store (sets: CLLocation) {
        location.send(sets)
        let encoder = JSONEncoder()
        let setting = HouseSettings(loc: Location(locationLat: sets.coordinate.latitude, locationLon: sets.coordinate.longitude))
        let data = (try? encoder.encode(setting)) ?? Data()
        UserDefaults.standard.setValue(data, forKey: HouseSettings.Key)
    }
    
    static func retrieve () {
        let decoder = JSONDecoder()
        guard
            let data = UserDefaults.standard.data(forKey: HouseSettings.Key),
            let decodeVal = try? decoder.decode(HouseSettings.self, from: data)
        else {
            LocationManager.shared.update()
            return
        }
        location.send(CLLocation.init(latitude: decodeVal.loc.locationLat, longitude: decodeVal.loc.locationLon))
        return
    }
}

class WeatherSettings: Codable {
    static var Key = "weather"
    var lastUpdate: TimeInterval
    var weather: WeatherObject
    private var bag = Set<AnyCancellable>()
    
    enum CodingKeys: String, CodingKey {
        case lastUpdate, weather
    }
    
    init (lastUpdate: TimeInterval, weather: WeatherObject) {
        self.lastUpdate = lastUpdate
        self.weather = weather
        WeatherManager.shared.$weather
            .sink(receiveValue: { weather in
                guard let weather = weather else { return }
                WeatherSettings.store(sets: weather)
            })
            .store(in: &bag)
    }

    static func store (sets: WeatherObject) {
        let setting = WeatherSettings(lastUpdate: Date().timeIntervalSinceReferenceDate, weather: sets)
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(setting)) ?? Data()
        UserDefaults.standard.setValue(data, forKey: WeatherSettings.Key)
    }
    
    static func retreive () -> WeatherObject? {
        let decoder = JSONDecoder()
        guard
            let data = UserDefaults.standard.data(forKey: WeatherSettings.Key),
            let decodeVal = try? decoder.decode(WeatherSettings.self, from: data)
        else { return nil }
        return decodeVal.weather
    }
}

struct ENV {
    private static let pListFilePath = Bundle.main.path(forResource: "Server", ofType: "plist")
    private static let pList = NSDictionary(contentsOfFile: pListFilePath!)!
    static let WEATHER_API_KEY: String = (pList["WeatherAPIKey"] as? String) ?? "not found"
}

extension Array where Element == (String, String?) {
    var jsonData: Data? {
        let newDict = Dictionary(self, uniquingKeysWith: { (first, _) in first })
        guard let data = try? JSONSerialization.data(withJSONObject: newDict) else {
            return nil
        }
        return data
    }
}

class LocationManager: CLLocationManager, CLLocationManagerDelegate, ObservableObject {
    static let shared = LocationManager.init()
    
    override init () {
        super.init()
        delegate = self
        print("Location services are enabled: \(CLLocationManager.locationServicesEnabled())")
    }
    
    func update () {
        requestWhenInUseAuthorization()
        startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print(locations.last.debugDescription)
        locations.last.map {
            HouseSettings.store(sets: $0)
        }
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("location manager failed with error \(error.localizedDescription)")
    }
}
