//
//  whf001App.swift
//  Shared
//
//  Created by Scott Lucas on 12/9/20.
//
/*
 This is the main App. At a top level, the app is constructed with a single House that can contain multiple Fans. There are activities, events, and alarms that happen at the House level, such as:
        * house location (used to retrieve current outdoor temperatures
        * temperature alarms that notify users if they should consider turning their fan on or off
 
 There are other activities, events, and alarms that happen at the Fan level, such as:
        * fan speed displays and adjustments
        * fan timer displays and adjustments
        * fan safety interlock notifications
        * fan user-friendly names
 
 Handle scene phase changes here. Specifically, there are two possible alerts that may be presented to the user when the app is in background, and check routines for those alerts are initiated here. One process queries the fan to see if the fan itself is in an alarm state, the other process queries the weather to see if the user needs to be notified of outside temperatures that may require user attention to change the fan's operation.
 */

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
    
    let location = Location.shared
    let weather: WeatherMonitor
    let houseView: HouseView
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                houseView
                    .background(Color.pageBackground)
                    .foregroundColor(.main)
                    .ignoresSafeArea()
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
                InterlockBackgroundTaskManager.scheduleInterlockCheckTask (forId: BackgroundTaskIdentifier.interlockActive, waitUntil: .now.addingTimeInterval(10.0 * 60.0))
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
            Log.background.info("Background task for temp check called")
            guard let task = task as? BGProcessingTask else { return }
            task.expirationHandler = {
                Log.background.error("Background handler for temperature check expired")
                task.setTaskCompleted(success: false)
            }
            Task {
                if await WeatherBackgroundTaskManager.handleTempCheckTask() {
                    task.setTaskCompleted(success: true)
                    Log.background.info("Background temp check task handle success.")
                } else {
                    task.setTaskCompleted(success: false)
                    Log.background.info("Background temp check task handle failed.")
                }
            }
        })
        {
            Log.background.info("Background task registered for tempOutOfRange event.")
        } else {
            Log.background.error("Background task failed to register for tempOutOfRange event.")
        }
        
        if BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskIdentifier.interlockActive, using: nil, launchHandler: { task in
            Log.background.info("Background task for interlock called")
            task.expirationHandler = {
                Log.background.error("Background handler for interlock check expired")
                task.setTaskCompleted(success: false)
            }
            guard let task = task as? BGProcessingTask else { return }
            Task {
                if await InterlockBackgroundTaskManager.handleInterlockCheckTask () {
                    task.setTaskCompleted(success: true)
                    Log.background.info("Background interlock check task handle success.")
                } else {
                    task.setTaskCompleted(success: false)
                    Log.background.info("Background interlock check task handle fail.")
                }
            }
        })
        {
            Log.background.info("Background task registered for interlock active event.")
        } else {
            Log.background.error("Background task failed to register for interlock active event.")
        }
        return true
    }
}
