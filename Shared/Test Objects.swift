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
class TestWeather {
//    static var roomTempWeatherData: Data {
//        let forecast: [(Date, Measurement<UnitTemperature>)] = Range<Int>.init((1...8)).map( { (Date(timeIntervalSinceNow: Double($0) * 3600), Measurement<UnitTemperature>.init(value: 72, unit: .fahrenheit)) } )
//        let res = Weather.WeatherResult.init(currentTemp: Measurement<UnitTemperature>.init(value: 72, unit: .fahrenheit), forecast: forecast)
//        return Weather.WeatherObject.init(fromResult: res).data
//    }
//
//    static var coldTempWeatherData: Data {
//        let forecast: [(Date, Measurement<UnitTemperature>)] = Range<Int>.init((1...8)).map( { (Date(timeIntervalSinceNow: Double($0) * 3600), Measurement<UnitTemperature>.init(value: 10, unit: .fahrenheit)) } )
//        let res = Weather.WeatherResult.init(currentTemp: Measurement<UnitTemperature>.init(value: 10, unit: .fahrenheit), forecast: forecast)
//        return Weather.WeatherObject.init(fromResult: res).data
//    }
//
//    static var hotTempWeatherData: Data {
//        let forecast: [(Date, Measurement<UnitTemperature>)] = Range<Int>.init((1...8)).map( { (Date(timeIntervalSinceNow: Double($0) * 3600), Measurement<UnitTemperature>.init(value: 100, unit: .fahrenheit)) } )
//        let res = Weather.WeatherResult.init(currentTemp: Measurement<UnitTemperature>.init(value: 100, unit: .fahrenheit), forecast: forecast)
//        return Weather.WeatherObject.init(fromResult: res).data
//    }
    
    static var testCoordinate: Coordinate {
        //40.584422, -105.070148
        Coordinate(lat: 40.584422, lon: -105.070148)
    }
    
    static func weatherResult (currentTemp: Double, start: Date = .now, inRange: Bool = true) -> Weather.WeatherResult {
        let lowTempLim = Storage.lowTempLimit ?? 55.0
        let highTempLim = Storage.highTempLimit ?? 75.0
        let tempArray: [Measurement<UnitTemperature>] = (1...8).map({ _ in
            let tVal =
            inRange ? Double.random(in: (lowTempLim...highTempLim)) : Bool.random() ? Double.random(in: (0.0...lowTempLim)) : Double.random(in: (highTempLim...100))
            return Measurement<UnitTemperature>.init(value: tVal, unit: .fahrenheit)
        })
        let dateArray = (1...8).map({ c in
            start.addingTimeInterval(Double(c) * 3600.0) })
        let forecast: [(Date, Measurement<UnitTemperature>)] = zip(dateArray, tempArray).map ({ ($0, $1) })
        return Weather.WeatherResult.init(currentTemp: Measurement<UnitTemperature>.init(value: currentTemp, unit: .fahrenheit), forecast: forecast)
//        return Weather.WeatherObject.init(fromResult: res).data
    }
}

extension CLAuthorizationStatus {
    var description: String {
        switch self.rawValue {
            case 0:
                return "notDetermined"
            case 1:
                return "restricted"
            case 2:
                return  "denied"
            case 3:
                return "authorizedAlways"
            case 4:
                return "authorizedWhenInUse"
            default:
                return "INVALID"
        }
    }
}
//class MockUserDefaults: UserDefaultsProtocol {
//    let encoder = JSONEncoder()
//    let decoder = JSONDecoder()
//    var fanStorage: Storage.FanStorageValue
//    var houseStorage: Storage.HouseStorageValue
//    var weatherStorage: Storage.WeatherStorageValue
//    
//    init (fan: Storage.FanStorageValue, house: Storage.HouseStorageValue, weather: Storage.WeatherStorageValue) {
//        fanStorage = fan
//        houseStorage = house
//        weatherStorage = weather
//    }
//    
//    func data(forKey: String) -> Data? {
//        switch forKey {
//        case Storage.FanStorageValue.Key:
//            print("Fan settings retrieved")
//            return (try? encoder.encode(fanStorage)) ?? Data()
//        case Storage.HouseStorageValue.Key:
//            print("House settings retrieved")
//            return (try? encoder.encode(houseStorage)) ?? Data()
//        case Storage.WeatherStorageValue.Key:
//            print("Weather settings retrieved")
//            return (try? encoder.encode(weatherStorage)) ?? Data()
//        default:
//            return Data()
//        }
//    }
//    
//    func set(_ data: Any?, forKey: String) {
//        guard let data = data as? Data else {
//            print("Failed to set for key \(forKey)")
//            return
//        }
//        switch forKey {
//        case Storage.FanStorageValue.Key:
//            print("Fan settings stored")
//            fanStorage = (try? decoder.decode(Storage.FanStorageValue.self, from: data)) ?? Storage.FanStorageValue(fans: [:])
//        case Storage.HouseStorageValue.Key:
//            print("House settings stored")
//            houseStorage = (try? decoder.decode(Storage.HouseStorageValue.self, from: data)) ?? Storage.HouseStorageValue()
//        case Storage.WeatherStorageValue.Key:
//            print("Weather settings stored")
//            weatherStorage = (try? decoder.decode(Storage.WeatherStorageValue.self, from: data)) ?? Storage.WeatherStorageValue()
//        default:
//            return
//        }
//    }
//}

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
