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
import os.log

@main
struct AirspaceFanApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) var scenePhase
    
    let location = Location()
    let weather: WeatherMonitor
    let houseView: HouseView
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                houseView
                    .background(Color.pageBackground)
                    .foregroundColor(.main)
            }
            .environmentObject(weather)
            .environmentObject(location)
            .onScenePhaseChange(phase: .active) {
                Log.app.info("app in foreground")
                BGTaskScheduler.shared.cancelAllTaskRequests()
                WeatherMonitor.shared.monitor ()
            }
            .onScenePhaseChange(phase: .background) {
                Log.app.info("app in background")
                WeatherBackgroundTaskManager.scheduleBackgroundTempCheckTask (forId: BackgroundTaskIdentifier.tempertureOutOfRange, waitUntil: WeatherMonitor.shared.weatherServiceNextCheckDate())
                WeatherMonitor.shared.suspendMonitor ()
            }
        }
    }
    
    init () {
        weather = WeatherMonitor.shared
        houseView = HouseView()
        UITableView.appearance().backgroundColor = .clear
        UITableView.appearance().separatorColor = .pageBackground
        UIPageControl.appearance().currentPageIndicatorTintColor = .main
        UIPageControl.appearance().pageIndicatorTintColor = .main.withAlphaComponent(0.25)
        UISegmentedControl.appearance().selectedSegmentTintColor = .main
        UIPickerView.appearance().backgroundColor = .main
        Log.app.info("App started")
    }
}



class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskIdentifier.tempertureOutOfRange, using: nil, launchHandler: { task in
            Log.background.info("Background task called")
            guard let task = task as? BGRefreshTask else { return }
            Task {
                await WeatherBackgroundTaskManager.handleTempCheckTask(task: task)
                Log.background.info("Background task handle complete.")
            }
        }) {
            Log.background.info("Background task registered for tempOutOfRange event.")
        } else {
            Log.background.error("Background task failed to register for tempOutOfRange event.")
        }
        return true
    }
    
//    func applicationDidBecomeActive(_ application: UIApplication) {
//        print("active in app delegate")
//        BGTaskScheduler.shared.cancelAllTaskRequests()
//        WeatherMonitor.shared.monitor ()
//    }
//
//    func applicationDidEnterBackground(_ application: UIApplication) {
//        print("background in app delegate")
//        WeatherBackgroundTaskManager.scheduleBackgroundTempCheckTask (forId: BackgroundTaskIdentifier.tempertureOutOfRange, waitUntil: WeatherMonitor.shared.weatherServiceNextCheckDate())
//        WeatherMonitor.shared.suspendMonitor()
//    }
}

protocol BGTaskSched {
    static var shared: BGTaskScheduler { get }
    func register(forTaskWithIdentifier identifier: String,
                  using queue: DispatchQueue?,
                  launchHandler: @escaping (BGTask) -> Void) -> Bool
    func submit(_ taskRequest: BGTaskRequest) throws
    func cancel(taskRequestWithIdentifier: String)
    func cancelAllTaskRequests()
}

extension BGTaskScheduler: BGTaskSched { }

protocol BGRefreshTask: AnyObject {
    var identifier: String { get }
    var expirationHandler: (() -> Void)? { get set }
    func setTaskCompleted(success: Bool)
}

extension BGAppRefreshTask: BGRefreshTask { }
