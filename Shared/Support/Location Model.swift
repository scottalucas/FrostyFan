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

class Location: NSObject, ObservableObject {
    private var mgr: CLLocationManager
    @AppStorage(StorageKey.locLat.key) var latStr: String?
    @AppStorage(StorageKey.locLon.key) var lonStr: String?
    @AppStorage(StorageKey.locationAvailable.key) private var locationPermission: LocationPermission = .unknown

    private var latitude: Double? {
        willSet {
            if let lat = newValue {
                let formatter = NumberFormatter()
                formatter.positiveFormat = "##0.00\u{00B0} N"
                formatter.negativeFormat = "##0.00\u{00B0} S"
                latStr = formatter.string(from: NSNumber(value: lat))
            } else {
                latStr = nil
            }
        }
    }
    private var longitude: Double? {
        willSet {
            if let lon = newValue {
                let formatter = NumberFormatter()
                formatter.positiveFormat = "##0.00\u{00B0} E"
                formatter.negativeFormat = "##0.00\u{00B0} W"
                lonStr = formatter.string(from: NSNumber(value: lon))
            } else {
                lonStr = nil
            }
        }
    }
    
    enum LocationPermission: String {
        case deviceProhibited, appProhibited, appAllowed, unknown
    }
    
    override init () {
        mgr = CLLocationManager()
        super.init()
        mgr.delegate = self
        if locationPermission == .unknown { getLocationPermission() }
        print("Location services are enabled: \(CLLocationManager.locationServicesEnabled())")
        print("Device location enabled: \(mgr.authorizationStatus.rawValue)")
        print("Stored \(locationPermission)")
    }

    func updateLocation () {
        mgr.requestWhenInUseAuthorization()
        mgr.startUpdatingLocation()
    }
    
    func clearLocation () {
        latitude = nil
        longitude = nil
    }
}

extension Location: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        latitude = locations.last.map { $0.coordinate.latitude }
        longitude = locations.last.map { $0.coordinate.longitude }
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("location manager failed with error \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        getLocationPermission()
    }
    
    func getLocationPermission() {
        switch (CLLocationManager.locationServicesEnabled(), mgr.authorizationStatus) {
        case (false, _):
            longitude = nil
            latitude = nil
            locationPermission = .deviceProhibited
        case (_, .authorizedAlways), (_, .authorizedWhenInUse):
            locationPermission = .appAllowed
        case (_, .notDetermined):
            locationPermission = .unknown
        default:
            longitude = nil
            latitude = nil
            locationPermission = .appProhibited
        }
    }
}
