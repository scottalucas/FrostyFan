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
    static func mock (usingMgr mgr: LocationManagerProtocol, usingSettings settings: Settings) -> LocationManager {
        LocationManager(locManager: mgr, settings: settings)
    }
    private var settings: Settings
    private var mgr: LocationManagerProtocol
    @Published private (set) var authorized: Bool?
    
    private init (locManager manager: LocationManagerProtocol = CLLocationManager(), settings: Settings = Settings.shared ) {
        mgr = manager
        self.settings = settings
        super.init()
        mgr.delegate = self
        changedAuthorization(mgr)
        print("Location services are enabled: \(CLLocationManager.locationServicesEnabled())")
    }
    
    func update () {
        mgr.requestWhenInUseAuthorization()
        mgr.startUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        updatedLocations(manager, locations: locations)
    }
    
    func updatedLocations (_ manager: LocationManagerProtocol, locations: [CLLocation]) {
        print(locations.last.debugDescription)
        settings.houseLocation = locations.last.map { $0 }
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("location manager failed with error \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        changedAuthorization(manager)
    }
    
    func changedAuthorization(_ manager: LocationManagerProtocol) {
        switch manager.authorizationStatus {
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

protocol LocationManagerProtocol {
    var delegate: CLLocationManagerDelegate? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization () -> Void
    func startUpdatingLocation () -> Void
    func stopUpdatingLocation () -> Void
    static func locationServicesEnabled () -> Bool
}

extension CLLocationManager: LocationManagerProtocol { }
