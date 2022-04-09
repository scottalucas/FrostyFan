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
    
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) var scenePhase
    
    let location = Location()
    let weather = WeatherMonitor.shared
    let houseView = HouseView()
    
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
                print("foreground in modifier")
                BGTaskScheduler.shared.cancelAllTaskRequests()
                WeatherMonitor.shared.monitor ()
            }
            .onScenePhaseChange(phase: .background) {
                print("background in modifier")
                WeatherBackgroundTaskManager.scheduleBackgroundTempCheckTask (forId: BackgroundTaskIdentifier.tempertureOutOfRange, waitUntil: WeatherMonitor.shared.weatherServiceNextCheckDate())
                WeatherMonitor.shared.suspendMonitor ()
            }
        }
//        .onChange(of: scenePhase, perform: { newPhase in
//            switch newPhase {
//                case .active:
//                    print("foreground in app view")
////                    BGTaskScheduler.shared.cancelAllTaskRequests()
////                    WeatherMonitor.shared.monitor()
//                case .background:
//                    print("background in app view")
////                    WeatherBackgroundTaskManager.scheduleBackgroundTempCheckTask (forId: BackgroundTaskIdentifier.tempertureOutOfRange, waitUntil: WeatherMonitor.shared.weatherServiceNextCheckDate())
////                    WeatherMonitor.shared.suspendMonitor()
//                case .inactive:
//                    break
//                @unknown default:
//                    break
//            }
//        })
    }
    
    init () {
        UITableView.appearance().backgroundColor = .clear
        UITableView.appearance().separatorColor = .main
        UIPageControl.appearance().currentPageIndicatorTintColor = .main
        UIPageControl.appearance().pageIndicatorTintColor = .main.withAlphaComponent(0.25)
        UISegmentedControl.appearance().selectedSegmentTintColor = .main
        UIPickerView.appearance().backgroundColor = .main
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
        
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        if BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskIdentifier.tempertureOutOfRange, using: nil, launchHandler: { task in
            print("Background task called")
            guard let task = task as? BGRefreshTask else { return }
            Task {
                await WeatherBackgroundTaskManager.handleTempCheckTask(task: task)
            }
        }) {
            print("Task registration succeeded")
        } else {
            print("Task registration failed")
        }
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            
            if error != nil || !granted {
                print("Error requesting notification authorization, \(error?.localizedDescription ?? "not permitted by user.")")
                BGTaskScheduler.shared.cancelAllTaskRequests()
                print("Background tasks cancelled.")
            }
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
