//
//  Settings View Model.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 4/16/22.
//

import Foundation
import SwiftUI
import CoreLocation
import UserNotifications
import BackgroundTasks

class SettingViewModel: ObservableObject {
    @EnvironmentObject var location: Location
    @Environment(\.scenePhase) var scenePhase
    @AppStorage(StorageKey.temperatureAlarmEnabled.rawValue) var temperatureAlertsEnabled: Bool = false
    @AppStorage(StorageKey.interlockAlarmEnabled.rawValue) var interlockAlertsEnabled: Bool = false
    @AppStorage(StorageKey.coordinate.rawValue) var coordinateData: Data?
    @AppStorage (StorageKey.lowTempLimit.rawValue) var lowTempLimit: Double?
    @AppStorage (StorageKey.highTempLimit.rawValue) var highTempLimit: Double?
    private var initTempAlertsEnabled: Bool?
    private var initInterlockAlertsEnabled: Bool?
    private var initCoord: Data?
    private var initHighTempLimit: Double?
    private var initLowTempLimit: Double?
    @Published var showLocation: LocationSectionStatus = .unknown
    @Published var showTempSwitch: Bool = true
//    @Published var showNoNotisAlert: Bool = false
//    @Published var showNoLocationAlert: Bool = false
//    @Published var showCouldNotGetLocationAlert: Bool = false
    @Published var settingsError: SettingsError?
    
    enum LocationSectionStatus { case known ( String ), unknown, unavailable }
    
    init() {
        appeared()
    }
    
    func validateTempAlert () {
        Task {
            do {
                guard await notificationsAuthorized() else {
                    throw SettingsError.alertsDisabled
                }
                if coordinateData != nil {
                    self.settingsError = nil
                    return
                }
                guard
                    let d = try? await location.updateLocation(),
                    let dat = d.data,
                    dat.decodeCoordinate != nil
                else {
                    showLocation = .unknown
                    throw SettingsError.locationDisabled
                }
                self.settingsError = nil
                coordinateData = dat
            } catch {
                self.settingsError = error as? SettingsError
                temperatureAlertsEnabled = false
                Log.settings.info("Unsupported temperture alert \(self.settingsError?.errorDescription ?? "")")
            }
        }
    }
    
    func validateInterlockAlert () {
        Task {
            do {
                guard await notificationsAuthorized() else {
                    throw SettingsError.alertsDisabled
                }
                settingsError = nil
            } catch {
                settingsError = error as? SettingsError
                interlockAlertsEnabled = false
                Log.settings.info("Unsupported interlock alert \(self.settingsError?.errorDescription ?? "")")
            }
        }
    }
    
    func retryTemperature () async {
        do {
            try await WeatherMonitor.shared.updateWeatherConditions()
            guard WeatherMonitor.shared.currentTemp != nil else {
                throw SettingsError.noTemp
            }
        } catch {
            settingsError = .noTemp
        }
    }
    
    func updateLocation () async {
        do {
            let newCoord = try await location.updateLocation()
            coordinateData = newCoord.data
            showLocation = .known("\(newCoord.lat.latitudeStr) \(newCoord.lon.longitudeStr)")
        } catch {
            Log.settings.error("Failed to update location \(error.localizedDescription)")
            settingsError = .noLocation
            showLocation = .unknown
        }
    }
    
    func clearLocation () {
        location.clearLocation()
    }
    
    func appeared () {
        initCoord = coordinateData
        initHighTempLimit = highTempLimit
        initLowTempLimit = lowTempLimit
        initTempAlertsEnabled = temperatureAlertsEnabled
        initInterlockAlertsEnabled = interlockAlertsEnabled
        if let cData = coordinateData, let coord = cData.decodeCoordinate {
            showLocation = .known("\(coord.lat.latitudeStr) \(coord.lon.longitudeStr)")
        } else if CLLocationManager.locationServicesEnabled() {
            showLocation = .unknown
        } else {
            showLocation = .unavailable
        }
    }
    
    func commit () {
        Task { try? await WeatherMonitor.shared.updateWeatherConditions() }
    }
    
    func cancel () {
        coordinateData = initCoord
        highTempLimit = initHighTempLimit
        lowTempLimit = initLowTempLimit
        temperatureAlertsEnabled = initTempAlertsEnabled ?? false
        interlockAlertsEnabled = initInterlockAlertsEnabled ?? false
    }
    
    private func notificationsAuthorized () async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let permitted = try await center.requestAuthorization(options: [.alert, .sound])
            if !permitted {
                BGTaskScheduler.shared.cancelAllTaskRequests()
                Log.alert.info("Background tasks cancelled.")
                Log.alert.info("Notifications not permitted")
            }
            return permitted
        } catch {
            Log.alert.error("Error requesting notification authorization, \(error.localizedDescription)")
            Log.alert.info("Background tasks cancelled.")
            BGTaskScheduler.shared.cancelAllTaskRequests()
            return false
        }
    }
    //
    //    private func updateErrors () {
    //        settingsError.rawValue = .zero
    //        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert]) { [weak self] granted, _ in
    //            if !granted {
    //                self?.settingsError.insert(.alertsDisabled)
    //            }
    //        }
    //        let locSvcsEnabled = CLLocationManager.locationServicesEnabled()
    //        let locSvcsAuthorized = CLLocationManager().authorizationStatus
    //        if !locSvcsEnabled || !( locSvcsAuthorized == .authorizedWhenInUse || locSvcsAuthorized == .authorizedWhenInUse ) {
    //            settingsError.insert(.locationDisabled)
    //        }
    //        if WeatherMonitor.shared.currentTemp == nil {
    //            settingsError.insert(.noTemp)
    //        }
    //    }
}
