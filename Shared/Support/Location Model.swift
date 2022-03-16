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
//    @AppStorage(StorageKey.coordinate.rawValue) var coordinate: Data? //use a CLLocation type
    
    enum LocationPermission: String, Codable {
        case deviceProhibited, appProhibited, appAllowed, unknown
        var data: Data? {
            let encoder = JSONEncoder()
            return try? encoder.encode(self)
        }
    }
    
    override init () {
        mgr = CLLocationManager()
        super.init()
        mgr.delegate = self
        print("Location services are enabled: \(CLLocationManager.locationServicesEnabled())")
        print("Device location enabled: \(mgr.authorizationStatus.description)")
        print ("Location stored: \(Storage.coordinate == nil ? "false" : "true")")
    }

    func updateLocation () {
        if mgr.authorizationStatus == .authorizedAlways || mgr.authorizationStatus == .authorizedWhenInUse {
            mgr.startUpdatingLocation()
        } else {
            mgr.requestWhenInUseAuthorization()
        }
    }
    
    func clearLocation () {
        Storage.coordinate = nil
    }
}

extension Location: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            let newCoord = Coordinate(coord: loc)
            if newCoord != Storage.coordinate {
                Storage.coordinate = newCoord
                print("Saved new coordinates \(Storage.coordinate.map { "\($0.lat.latitudeStr), \($0.lon.longitudeStr)" } ?? "failed")")
            }
        }
        manager.stopUpdatingLocation()
    }
        
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("location manager failed with error \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            mgr.startUpdatingLocation()
        }
    }
    
//    func getLocationPermission() {
//        switch (CLLocationManager.locationServicesEnabled(), mgr.authorizationStatus) {
//        case (false, _):
////                lat = nil
////                lon = nil
//                coordinate = nil
////                locationPermission = .deviceProhibited
//        case (_, .authorizedAlways), (_, .authorizedWhenInUse):
////            locationPermission = .appAllowed
//        case (_, .notDetermined):
////            locationPermission = .unknown
//        default:
////                lat = nil
////                lon = nil
//                coordinate = nil
////                locationPermission = .appProhibited
//        }
//    }
}

extension Double {
    var latitudeStr: String {
        let formatter = NumberFormatter()
        formatter.positiveFormat = "##0.00\u{00B0} N"
        formatter.negativeFormat = "##0.00\u{00B0} S"
        return formatter.string(from: NSNumber(value: self)) ?? "nil"
    }
    var longitudeStr: String {
        let formatter = NumberFormatter()
        formatter.positiveFormat = "##0.00\u{00B0} E"
        formatter.negativeFormat = "##0.00\u{00B0} W"
        return formatter.string(from: NSNumber(value: self)) ?? "nil"
    }
}
