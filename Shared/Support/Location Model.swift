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
//    static let shared = LocationManager()
//    static func mock (usingMgr mgr: LocationManagerProtocol) -> LocationManager {
//        LocationManager(locManager: mgr)
//    }
    private var mgr: CLLocationManager
    
    @Published var latStr: String?
    @Published var lonStr: String?
    @Published var status: LocationStatus = .unknown
    
    @AppStorage(StorageKey.locationAvailable.key()) private var locationStatus: LocationStatus = .unknown {
        didSet {
            status = locationStatus
        }
    }
    @AppStorage(StorageKey.locLat.key()) private var latitude: Double? {
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
    @AppStorage(StorageKey.locLon.key()) private var longitude: Double? {
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
    
    enum LocationStatus: String {
        case deviceProhibited, appProhibited, appAllowed, unknown
    }
    
    override init () {
        mgr = CLLocationManager()
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
        getLocationStatus()
    }
    
    func getLocationStatus() {
        switch (CLLocationManager.locationServicesEnabled(), mgr.authorizationStatus) {
        case (false, _):
            longitude = nil
            latitude = nil
            locationStatus = .deviceProhibited
        case (_, .authorizedAlways), (_, .authorizedWhenInUse):
            locationStatus = .appAllowed
        case (_, .notDetermined):
            mgr.requestWhenInUseAuthorization()
            locationStatus = .unknown
        default:
            longitude = nil
            latitude = nil
            locationStatus = .appProhibited
        }
    }
}

//extension Location: LocationProtocol {
//    var latStrPublished: Published<String?> { _latStr }
//    var latStrPublisher: Published<String?>.Publisher { $latStr }
//
//    var lonStrPublished: Published<String?> { _lonStr }
//    var lonStrPublisher: Published<String?>.Publisher { $lonStr }
//    
//    var statusPublished: Published<Location.LocationStatus> { _status }
//    var statusPublisher: Published<Location.LocationStatus>.Publisher { $status }
//}
//
//protocol LocationProtocol: ObservableObject {
//    var latStr: String? { get }
//    var latStrPublished: Published<String?> { get }
//    var latStrPublisher: Published<String?>.Publisher { get }
//
//    var lonStr: String? { get }
//    var lonStrPublished: Published<String?> { get }
//    var lonStrPublisher: Published<String?>.Publisher { get }
//
//    var status: Location.LocationStatus { get }
//    var statusPublished: Published<Location.LocationStatus> { get }
//    var statusPublisher: Published<Location.LocationStatus>.Publisher { get }
//    
//    func updateLocation ()
//    func clearLocation()
//}
//
//protocol LocationManagerProtocol {
//    var delegate: CLLocationManagerDelegate? { get set }
//    var authorizationStatus: CLAuthorizationStatus { get }
//    func requestWhenInUseAuthorization () -> Void
//    func startUpdatingLocation () -> Void
//    func stopUpdatingLocation () -> Void
//    static func locationServicesEnabled () -> Bool
//}
//
//extension CLLocationManager: LocationManagerProtocol { }
