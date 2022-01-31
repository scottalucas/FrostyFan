//
//  Weather Model.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/9/21.
//

import Foundation
import CoreLocation
import Combine
import SwiftUI

struct Weather {
    typealias Forecast = Array<(Date, Measurement<UnitTemperature>)>
    typealias TempMeasurement = Measurement<UnitTemperature>
    @AppStorage(StorageKey.locationAvailable.key) var locationPermission: Location.LocationPermission = .unknown
    @AppStorage(StorageKey.coordinate.key) var coordinateData: Data? //decodes to Coordinate
    @AppStorage(StorageKey.forecast.key) var forecastData: Data? //decodes to WeatherObject
    @AppStorage(StorageKey.lastForecastUpdate.key) var lastUpdateData: Data? //decodes to Date

    private var url: URL? {
        get {
            guard locationPermission == .appAllowed, let lat = coordinateData?.decodeCoordinate?.lat, let lon = coordinateData?.decodeCoordinate?.lon else { return nil }
            var accumElements:[URLQueryItem] = []
            accumElements.append(URLQueryItem(name: "lat", value: String(format: "%f", lat)))
            accumElements.append(URLQueryItem(name: "lon", value: String(format: "%f", lon)))
            accumElements.append(URLQueryItem(name: "units", value: "imperial"))
            accumElements.append(URLQueryItem(name: "APPID", value: ENV.WEATHER_API_KEY))
            var components = URLComponents()
            components.host = "api.openweathermap.org"
            components.scheme = "http"
            components.path = "/data/2.5/onecall"
            components.queryItems = accumElements
            return components.url
        }
    }
    
    init () {
        lastUpdateData = Date.distantPast.data
    }
        
    func load(test: Bool = false) async throws {
        print ("Weather service hit")
        guard let lastUpdate = lastUpdateData?.decodeDate else {
            throw WeatherRetrievalError.decodeError
        }
        guard abs(lastUpdate.timeIntervalSinceNow) > 15 * 60 else {
            throw WeatherRetrievalError.throttle(lastUpdate: lastUpdate.ISO8601Format())
        }
        guard !test else {
            forecastData = TestWeatherItems.testWeatherObj
            lastUpdateData = Date.now.data
            print("updating last update, source len: \(Date.now.data?.count), stored len: \(lastUpdateData?.count)")
            return
        }
        
        let coord = Coordinate.init(lat: 40.587348, lon: -105.085076)
        let lat = coord.lat
        let lon = coord.lon
        
        let urlSession = URLSession.shared
        var accumElements:[URLQueryItem] = []
        var components = URLComponents()
        accumElements.append(URLQueryItem(name: "lat", value: String(format: "%f", lat)))
        accumElements.append(URLQueryItem(name: "lon", value: String(format: "%f", lon)))
        accumElements.append(URLQueryItem(name: "units", value: "imperial"))
        accumElements.append(URLQueryItem(name: "APPID", value: ENV.WEATHER_API_KEY))
        components.host = "api.openweathermap.org"
        components.scheme = "http"
        components.path = "/data/2.5/onecall"
        components.queryItems = accumElements
        
        guard let url = components.url else {
            throw WeatherRetrievalError.badUrl
        }
        
        let weatherData = try await urlSession.data(from: url)
        
        guard let response = weatherData.1 as? HTTPURLResponse else {
            throw WeatherRetrievalError.serverError(-1)
        }
        
        guard (200..<300) ~= response.statusCode else {
            throw WeatherRetrievalError.serverError(response.statusCode)
        }
        
        guard weatherData.0.decodeWeatherResult != nil else {
            throw WeatherRetrievalError.decodeError
        }
        
        lastUpdateData = Date.now.data
        
        forecastData = weatherData.0
        
        return
    }

    struct WeatherObject: Codable {
        var current: Current?
        var hourly: Array<Hourly>?
        struct Current: Codable {
            var temp: Double?
        }
        struct Hourly: Codable {
            var dt: Int?
            var temp: Double?
        }
        
        var data: Data {
            let encoder = JSONEncoder()
            return (try? encoder.encode(self)) ?? Data()
        }
    }

    struct WeatherResult {
        var currentTemp: Measurement<UnitTemperature>
        var forecast: Array<(date: Date, temp: Measurement<UnitTemperature>)>
    }
    
}

