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

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    static func mock (usingMgr mgr: LocationManagerProtocol) -> LocationManager {
        LocationManager(locManager: mgr)
    }
    private var mgr: LocationManagerProtocol
    @AppStorage("locationAvailability") var locationStatus: LocationStatus = .unknown
    @AppStorage("locLat") var latitude: Double?
    @AppStorage("locLon") var longitude: Double?
    
    enum LocationStatus: String {
        case deviceProhibited, appProhibited, appAllowed, unknown
    }
    
    private init (locManager manager: LocationManagerProtocol = CLLocationManager()) {
        mgr = manager
        super.init()
        mgr.delegate = self
        getLocationStatus()
        if locationStatus != .appAllowed {
            mgr.requestWhenInUseAuthorization()
        }
        print("Location services are enabled: \(CLLocationManager.locationServicesEnabled())")
    }

    func updateLocation () {
        if locationStatus != .appAllowed {
            mgr.requestWhenInUseAuthorization()
        }
        mgr.startUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        updatedLocations(manager, locations: locations)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("location manager failed with error \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        getLocationStatus()
    }
    
    private func updatedLocations (_ manager: LocationManagerProtocol, locations: [CLLocation]) {
        latitude = locations.last.map { $0.coordinate.latitude }
        longitude = locations.last.map { $0.coordinate.longitude }
        manager.stopUpdatingLocation()
    }

    func getLocationStatus() {
        if mgr.authorizationStatus == .notDetermined {
            mgr.requestWhenInUseAuthorization()
        }
        switch (CLLocationManager.locationServicesEnabled(), mgr.authorizationStatus) {
        case (false, _):
            longitude = nil
            latitude = nil
            locationStatus = .deviceProhibited
        case (_, .authorizedAlways), (_, .authorizedWhenInUse):
            locationStatus = .appAllowed
        case (_, .notDetermined):
            locationStatus = .unknown
        default:
            longitude = nil
            latitude = nil
            locationStatus = .appProhibited
        }
    }
}

protocol LocationManagerProtocol {
    var delegate: CLLocationManagerDelegate? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization () -> Void
    func startUpdatingLocation () -> Void
    func stopUpdatingLocation () -> Void
    static func locationServicesEnabled () -> Bool
}

extension CLLocationManager: LocationManagerProtocol { }
