//
//  whf001App.swift
//  Shared
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI
import CoreLocation
import Combine
import BackgroundTasks
import UserNotifications

@main
struct AirspaceFanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    @AppStorage(StorageKey.lastForecastUpdate.key) var lastUpdateData: Data? //decodes to Date
    @AppStorage(StorageKey.forecast.key) var forecastData: Data? //encodes as a WeatherObject, use decodeWeatherResult method to get a WeatherResult

    
    let location = Location()
    let weather = WeatherMonitor.shared
    let sharedHouseData = SharedHouseData.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sharedHouseData)
                .environmentObject(weather)
                .environmentObject(location)
                .onChange(of: scenePhase, perform: { newPhase in
                    switch newPhase {
                        case .active:
                            BGTaskScheduler.shared.cancelAllTaskRequests()
                            weather.monitor()
                        case .background:
                            print("background")
                            
                            let nextCheck = WeatherMonitor.shared.intervalToNextCheck()
                            print("Scheduling background task for \(Date.init(timeIntervalSinceNow: nextCheck).formatted())")
                            WeatherBackgroundTaskManager.scheduleBackgroundTempCheckTask( forId: BackgroundTaskIdentifier.tempertureOutOfRange, waitUntil: .now.addingTimeInterval(WeatherMonitor.shared.intervalToNextCheck()) )
                          weather.suspendMonitor()
                        case .inactive:
                            break
                        @unknown default:
                            break
                    }
                })
        }
    }
    
    init () {
        UITableView.appearance().backgroundColor = .main
        UITableView.appearance().separatorColor = .main
        UIPageControl.appearance().currentPageIndicatorTintColor = .main
        UIPageControl.appearance().pageIndicatorTintColor = .main.withAlphaComponent(0.25)

        UserDefaults.standard.register(defaults: [
            StorageKey.lowTempLimit.key: 55,
            StorageKey.highTempLimit.key: 75,
            StorageKey.temperatureAlarmEnabled.key: false
        ])
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            
            if let error = error {
                print("Error requesting notification authorization, \(error.localizedDescription)")
            } else {
                if BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskIdentifier.tempertureOutOfRange, using: nil, launchHandler: { task in
                    print("Background task called")
                    WeatherBackgroundTaskManager.handleTempCheckTask(task: task as! BGAppRefreshTask)
                }) {
                    print("Task registration succeeded")
                } else {
                    print("Task registration failed")
                }
            }
        }
        
        return true
    }
}

private struct ProgressKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    var updateProgress: Double? {
        get { self[ProgressKey.self] }
        set { self[ProgressKey.self] = newValue }
    }
}

extension View {
    func scanProgress(_ progress: Double?) -> some View {
        environment(\.updateProgress, progress)
    }
}

