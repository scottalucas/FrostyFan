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
    private typealias LocationCheckedThrowingContinuation = CheckedContinuation<Coordinate, Error>
    private var mgr: CLLocationManager
    private var locationCheckedThrowingContinuation: LocationCheckedThrowingContinuation?
    
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
        Log.location.info("Location services are enabled: \(CLLocationManager.locationServicesEnabled())")
        Log.location.info("Device location enabled: \(self.mgr.authorizationStatus.description)")
        Log.location.info("Location stored: \(Storage.coordinate == nil ? "false" : "true")")
    }

    func updateLocation () async throws -> Coordinate {
        return try await withCheckedThrowingContinuation({ [weak self] continuation in
            guard let self = self else { return }
            let authorized = ( mgr.authorizationStatus == .authorizedWhenInUse || mgr.authorizationStatus == .authorizedAlways )
            self.locationCheckedThrowingContinuation = continuation
            if authorized {
                mgr.startUpdatingLocation()
            } else {
                self.mgr.requestWhenInUseAuthorization()
            }
        })
    }
    
    func clearLocation () {
        Log.location.info("location cleared")
        Storage.coordinate = nil
    }
}

extension Location: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            let newCoord = Coordinate(coord: loc)
            locationCheckedThrowingContinuation?.resume(returning: newCoord)
            locationCheckedThrowingContinuation = nil
            if newCoord != Storage.coordinate {
                Storage.coordinate = newCoord
                Log.location.info("Got new coordinates \(Storage.coordinate.map { "\($0.lat.latitudeStr), \($0.lon.longitudeStr)" } ?? "Location update failed")")
            }
        }
        manager.stopUpdatingLocation()
    }
        
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationCheckedThrowingContinuation?.resume(throwing: error)
        locationCheckedThrowingContinuation = nil
        Log.location.error("location manager failed with error \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Log.location.error("location auth changed to \(manager.authorizationStatus.description)")

        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            mgr.startUpdatingLocation()
        }
    }
}

public typealias Location2 = CLLocationCoordinate2D

final class LocationManager: NSObject {
  private typealias LocationCheckedThrowingContinuation = CheckedContinuation<Location2, Error>

  fileprivate lazy var locationManager = CLLocationManager()

  private var locationCheckedThrowingContinuation: LocationCheckedThrowingContinuation?

  func updateLocation() async throws -> Location2 {
    return try await withCheckedThrowingContinuation({ [weak self] (continuation: LocationCheckedThrowingContinuation) in
      guard let self = self else {
        return
      }

      self.locationCheckedThrowingContinuation = continuation

      self.locationManager.delegate = self
      self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
      self.locationManager.requestWhenInUseAuthorization()
      self.locationManager.startUpdatingLocation()
    })
  }
}

extension LocationManager: CLLocationManagerDelegate {
  func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let locationObj = locations.last {
      let coord = locationObj.coordinate
      let location = Location2(latitude: coord.latitude, longitude: coord.longitude)
      locationCheckedThrowingContinuation?.resume(returning: location)
      locationCheckedThrowingContinuation = nil

    }
  }

  func locationManager(_: CLLocationManager, didFailWithError error: Error) {
    locationCheckedThrowingContinuation?.resume(throwing: error)
    locationCheckedThrowingContinuation = nil
  }
}
