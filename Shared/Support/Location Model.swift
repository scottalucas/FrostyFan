//
//  Location Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/10/21.
//
/*
 Routines to get the user location. Unlike other apps, we only need to get the location once, when the user is near their fan. We're not interested in user location, we're interested in fan location (which will not change over time).
 
 Built using continuations to translate the delegate-based CoreLocation APIs into async functions. Probably didn't need to do this but it was a great way to learn about how to bridge older APIs to async.
 */

import Foundation
import CoreLocation
import Combine
import SwiftUI

class Location: NSObject, ObservableObject {
    static var shared: Location { Location () }
    private var mgr: CLLocationManager
    private typealias LocationCheckedThrowingContinuation = CheckedContinuation<Coordinate, Error>
    private typealias AuthorizationCheckedContinuation = CheckedContinuation<LocationPermission, Never>
    private var locationCheckedThrowingContinuation: LocationCheckedThrowingContinuation?
    private var authorizationCheckedContinuation: AuthorizationCheckedContinuation?
    
    enum LocationPermission: String, Codable {
        case deviceProhibited, appProhibited, appAllowed, unknown
        var data: Data? {
            let encoder = JSONEncoder()
            return try? encoder.encode(self)
        }
    }
    
    private override init () {
        mgr = CLLocationManager()
        super.init()
        mgr.delegate = self
        Log.location.info("Location services are enabled: \(CLLocationManager.locationServicesEnabled())")
        Log.location.info("Device location enabled: \(self.mgr.authorizationStatus.description)")
        Log.location.info("Location stored: \(Storage.coordinate == nil ? "false" : "true")")
    }
    
    private func checkAuthorization () async -> LocationPermission {
        return await withCheckedContinuation({ [weak self] continuation in
            self?.authorizationCheckedContinuation = continuation
            guard self != nil else {
                authorizationCheckedContinuation?.resume(returning: .unknown)
                authorizationCheckedContinuation = nil
                return }
            guard CLLocationManager.locationServicesEnabled() else {
                authorizationCheckedContinuation?.resume(returning: .deviceProhibited)
                authorizationCheckedContinuation = nil
                Log.location.error("Device location services are off.")
                return
            }
            switch mgr.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                authorizationCheckedContinuation?.resume(returning: .appAllowed)
                Log.location.info("App location services authorized")
            case .denied, .restricted:
                authorizationCheckedContinuation?.resume(returning: .appProhibited)
                Log.location.info("Location service denied for app.")
            case .notDetermined:
                mgr.requestWhenInUseAuthorization()
                return
            default:
                authorizationCheckedContinuation?.resume(returning: .unknown)
                Log.location.fault("Location service location not found, this is unexpected.")
            }
            authorizationCheckedContinuation = nil
        })
    }

    func updateLocation () async throws -> Coordinate {
        return try await withCheckedThrowingContinuation ({ [weak self] continuation in
            self?.locationCheckedThrowingContinuation = continuation
            guard self != nil else {
                locationCheckedThrowingContinuation?.resume(throwing: SettingsError.noLocation)
                locationCheckedThrowingContinuation = nil
                return }
            Task {
                let auth = await checkAuthorization()
                if Task.isCancelled {
                    locationCheckedThrowingContinuation?.resume(throwing: SettingsError.noLocation)
                    locationCheckedThrowingContinuation = nil
                }
                switch auth {
                case .deviceProhibited:
                    locationCheckedThrowingContinuation?.resume(throwing: SettingsError.locationDisabledForDevice)
                    locationCheckedThrowingContinuation = nil
                case .appProhibited:
                    locationCheckedThrowingContinuation?.resume(throwing: SettingsError.locationDisabledForApp)
                    locationCheckedThrowingContinuation = nil
                case .appAllowed:
                    mgr.startUpdatingLocation()
                case .unknown:
                    locationCheckedThrowingContinuation?.resume(throwing: SettingsError.noLocation)
                    locationCheckedThrowingContinuation = nil
                }
            }
        })
    }
}
    
//    func clearLocation () {
//        Log.location.info("location cleared")
//        Storage.coordinate = nil
//    }

extension Location: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        defer { locationCheckedThrowingContinuation = nil }
        if let loc = locations.last {
            let newCoord = Coordinate(coord: loc)
            Log.location.info("Got new coordinates \(Storage.coordinate.map { "\($0.lat.latitudeStr), \($0.lon.longitudeStr)" } ?? "Location update failed")")
            manager.stopUpdatingLocation()
            locationCheckedThrowingContinuation?.resume(returning: newCoord)
        } else {
            locationCheckedThrowingContinuation?.resume(throwing: SettingsError.noLocation)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        defer { locationCheckedThrowingContinuation = nil }
        Log.location.error("location manager failed with error \(error.localizedDescription)")
        locationCheckedThrowingContinuation?.resume(throwing: SettingsError.noLocation)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        defer {
            Log.location.info("Finished handling manager did change authorization. Resume called: \(self.authorizationCheckedContinuation != nil)")
            authorizationCheckedContinuation = nil
        }
        Log.location.info("location auth changed to \(manager.authorizationStatus.description)")
        
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            authorizationCheckedContinuation?.resume(returning: .appAllowed)
        } else {
            authorizationCheckedContinuation?.resume(returning: .appProhibited)
        }
    }
}
//
//public typealias Location2 = CLLocationCoordinate2D
//
//final class LocationManager: NSObject {
//  private typealias LocationCheckedThrowingContinuation = CheckedContinuation<Location2, Error>
//
//  fileprivate lazy var locationManager = CLLocationManager()
//
//  private var locationCheckedThrowingContinuation: LocationCheckedThrowingContinuation?
//
//  func updateLocation() async throws -> Location2 {
//    return try await withCheckedThrowingContinuation({ [weak self] (continuation: LocationCheckedThrowingContinuation) in
//      guard let self = self else {
//        return
//      }
//
//      self.locationCheckedThrowingContinuation = continuation
//
//      self.locationManager.delegate = self
//      self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
//      self.locationManager.requestWhenInUseAuthorization()
//      self.locationManager.startUpdatingLocation()
//    })
//  }
//}
//
//extension LocationManager: CLLocationManagerDelegate {
//  func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//    if let locationObj = locations.last {
//      let coord = locationObj.coordinate
//      let location = Location2(latitude: coord.latitude, longitude: coord.longitude)
//      locationCheckedThrowingContinuation?.resume(returning: location)
//      locationCheckedThrowingContinuation = nil
//
//    }
//  }
//
//  func locationManager(_: CLLocationManager, didFailWithError error: Error) {
//    locationCheckedThrowingContinuation?.resume(throwing: error)
//    locationCheckedThrowingContinuation = nil
//  }
//}
