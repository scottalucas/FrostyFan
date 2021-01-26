//
//  Location Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/10/21.
//

import Foundation
import CoreLocation
import Combine
import SwiftUI

class LocationManager: CLLocationManager, ObservableObject {
    static let shared = LocationManager()
    private var settings = Settings.shared
    @Published private (set) var authorized: Bool?
    
    private override init () {
        super.init()
        delegate = self
        locationManagerDidChangeAuthorization(self)
        print("Location services are enabled: \(CLLocationManager.locationServicesEnabled())")
    }
    
    func update () {
        requestWhenInUseAuthorization()
        startUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print(locations.last.debugDescription)
        settings.houseLocation = locations.last.map { $0 }
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("location manager failed with error \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            authorized = true
        case .notDetermined:
            authorized = nil
        default:
            settings.houseLocation = nil
            authorized = false
        }
    }
}

