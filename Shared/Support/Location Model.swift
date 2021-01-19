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

class LocationManager: CLLocationManager, CLLocationManagerDelegate {
    private var settings = Settings.shared
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
        settings.houseLocation = locations.last.map { $0 }
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("location manager failed with error \(error.localizedDescription)")
    }
}

