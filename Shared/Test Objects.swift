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
