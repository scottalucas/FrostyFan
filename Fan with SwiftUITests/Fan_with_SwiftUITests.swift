//
//  Fan_with_SwiftUITests.swift
//  Fan with SwiftUITests
//
//  Created by Scott Lucas on 1/31/22.
//

import XCTest
import SwiftUI
import BackgroundTasks

@testable import Fan_with_SwiftUI
class Fan_with_SwiftUITests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }
}
// In order to get access to our code, without having to make all
// of our types and functions public, we can use the @testable
// keyword to also import all internal symbols from our app target.

class WeatherCheckIntervalTestsWithFanRunning: XCTestCase {
//    @AppStorage(StorageKey.forecast.key) var Storage.storedWeather: Data = Data()
//    @AppStorage(StorageKey.lowTempLimit.key) var Storage.lowTempLimit: Double = 55 //default set in App
//    @AppStorage(StorageKey.highTempLimit.key) var Storage.highTempLimit: Double = 75 //default set in App
//    @AppStorage(StorageKey.temperatureAlarmEnabled.key) var Storage.temperatureAlarmEnabled = false //default set in App
//    @AppStorage(StorageKey.lastForecastUpdate.key) var Storage.lastForecastUpdate: Date? //decodes to Date
    var dtNow = Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded())
    let timeIntervals = Array(-2 ... 5).map { TimeInterval($0 * 3600) }
    
    @MainActor override func setUp() { //load forecast with 8 entries @ 72degF, load current temp == 72degF, load one fan "ON", set temperature limits
        dtNow = Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded())
        Storage.clear(.forecast)
        Storage.clear(.highTempLimit)
        Storage.clear(.lowTempLimit)
        Storage.clear(.temperatureAlarmEnabled)
        HouseStatus.shared.updateStatus(forFan: "test", isOperating: true) //turn on a fan
        WeatherMonitor.shared.currentTemp = Measurement<UnitTemperature>.init(value: 72, unit: .fahrenheit)
    }
    
    func inRangeTemp () -> Double { Double(Int.random(in: Int(Storage.lowTempLimit ?? 55) ... Int(Storage.highTempLimit ?? 75))) }
    
    func outOfRangeTemp () -> Double {
        Double(Int.random(in: (1 ... 2))%2 == 0 ? Int.random(in: (0 ... Int(Storage.lowTempLimit ?? 55) - 1)) : Int.random(in: (Int(Storage.highTempLimit ?? 75) + 1 ... 100)))
    }
    
    @MainActor func testTempAlwaysInRange() {
        //check with a fan ON, default setup == temp never out of range
        Storage.highTempLimit = 72.0
        Storage.lowTempLimit = 55.0
        let testW = TestWeather.weatherResult(currentTemp: 72.0, start: dtNow)
        Storage.storedWeather = testW
        Storage.lastForecastUpdate = dtNow
        Storage.temperatureAlarmEnabled = true
        var checkDate = WeatherMonitor.shared.weatherServiceNextCheckDate()
        assert(checkDate.formatted() == testW.forecast.map({ $0.date }).max()?.formatted() ) //last available forecast entry
        
        //check with no fans on
        Storage.lastForecastUpdate = dtNow
        HouseStatus.shared.clearFans()
        checkDate = WeatherMonitor.shared.weatherServiceNextCheckDate()
        assert(checkDate >= dtNow.addingTimeInterval( 12 * 3600 ) ) //12 hours
    }
    
    @MainActor func testNoWeatherData() {
        //check with fan on
        Storage.clear(.forecast)
        Storage.lastForecastUpdate = dtNow
        Storage.temperatureAlarmEnabled = true
        Storage.highTempLimit = 75
        Storage.lowTempLimit = 55
        var nextDate = WeatherMonitor.shared.weatherServiceNextCheckDate()
        
        assert(nextDate.formatted() == dtNow.addingTimeInterval(15 * 60).formatted())
        
        //check with temp alarm disabled
        Storage.temperatureAlarmEnabled = false
        nextDate = WeatherMonitor.shared.weatherServiceNextCheckDate()
        assert(nextDate.formatted() == dtNow.addingTimeInterval(12 * 3600).formatted())
        
        //check with no high temp limit
        Storage.temperatureAlarmEnabled = true
        Storage.clear(.highTempLimit)
        nextDate = WeatherMonitor.shared.weatherServiceNextCheckDate()
        assert(nextDate.formatted() == dtNow.addingTimeInterval(12 * 3600).formatted())
        
        //check with no low temp limit
        Storage.highTempLimit = 75
        Storage.clear(.lowTempLimit)
        HouseStatus.shared.clearFans()
        nextDate = WeatherMonitor.shared.weatherServiceNextCheckDate()
        assert(nextDate.formatted() == dtNow.addingTimeInterval(12 * 3600).formatted())
        
        //check with fans off
        Storage.lowTempLimit = 55
        HouseStatus.shared.clearFans()
        nextDate = WeatherMonitor.shared.weatherServiceNextCheckDate()
        assert(nextDate.formatted() == dtNow.addingTimeInterval(12 * 3600).formatted())
    }
    
    @MainActor func testCurrentTempOutOfRangeNeverBackIn() {
//        var weatherObj = Weather.WeatherObject()
//        WeatherMonitor.shared.currentTemp = Measurement<UnitTemperature>.init(value: 50, unit: .fahrenheit)
//        let testForecast: [Weather.WeatherObject.Hourly] = timeIntervals.map {
//            let nextDt = Int(Date(timeInterval: $0, since: dtNow).timeIntervalSince1970)
//            return Weather.WeatherObject.Hourly(dt: nextDt, temp: outOfRangeTemp())
//        }
//        weatherObj.current = Weather.WeatherObject.Current(temp: 40.0)
//        weatherObj.hourly = testForecast
        HouseStatus.shared.updateStatus(forFan: "test", isOperating: true)
        Storage.storedWeather = nil
        Storage.storedWeather = TestWeather.weatherResult(currentTemp: 100, start: dtNow, inRange: false)
        Storage.temperatureAlarmEnabled = true
        Storage.highTempLimit = 75
        Storage.lowTempLimit = 55
        Storage.lastForecastUpdate = dtNow
        var nextDate = WeatherMonitor.shared.weatherServiceNextCheckDate()
        assert(HouseStatus.shared.fansOperating)
        assert(nextDate.formatted() == Storage.storedWeather!.forecast.map({ $0.date }).max()?.formatted() ) //last available forecast entry
        
        HouseStatus.shared.clearFans()
        nextDate = WeatherMonitor.shared.weatherServiceNextCheckDate()
        
        assert(nextDate.formatted() == Storage.lastForecastUpdate.addingTimeInterval(12 * 3600).formatted() ) //12 hours
    }
    
    @MainActor func testCurrentTempInRangeNeverOut() {
        HouseStatus.shared.updateStatus(forFan: "test", isOperating: true)
        Storage.storedWeather = nil
        Storage.storedWeather = TestWeather.weatherResult(currentTemp: 72, start: dtNow, inRange: true)
        Storage.temperatureAlarmEnabled = true
        Storage.highTempLimit = 75
        Storage.lowTempLimit = 55
        Storage.lastForecastUpdate = dtNow
        
        let checkDate = WeatherMonitor.shared.weatherServiceNextCheckDate()
        
        assert(checkDate == Storage.storedWeather!.forecast.last!.date) //longest date in forecast
        
        HouseStatus.shared.clearFans()
        let checkInterval = WeatherMonitor.shared.weatherServiceNextCheckDate().timeIntervalSince(dtNow)
        
        assert(checkInterval >= 12 * 3600) //12 hours
    }
    
    @MainActor func testCurrentTempRangeTransition() {
        HouseStatus.shared.updateStatus(forFan: "test", isOperating: true)
        Storage.storedWeather = nil
//        Storage.storedWeather = TestWeather.weatherResult(currentTemp: 72, start: dtNow, inRange: true)
        Storage.temperatureAlarmEnabled = true
        Storage.highTempLimit = 75
        Storage.lowTempLimit = 55
        Storage.lastForecastUpdate = dtNow
        
        var inRange = TestWeather.weatherResult(currentTemp: 72, start: dtNow, inRange: true).forecast
        var outOfRange = TestWeather.weatherResult(currentTemp: 72, start: inRange.last!.date, inRange: false).forecast
        var forecast = inRange + outOfRange
        Storage.storedWeather = Weather.WeatherResult.init(currentTemp: .init(value: 72.0, unit: .fahrenheit), forecast: forecast)
        var checkDate = WeatherMonitor.shared.weatherServiceNextCheckDate()
        var indexOf = Storage.storedWeather?.forecast.firstIndex(where: { $0.date == checkDate })
        guard let idx1 = indexOf else {
            assert(false)
            return
        }
        assert(idx1 == 7)
        
        outOfRange = TestWeather.weatherResult(currentTemp: 100, start: dtNow, inRange: false).forecast
        inRange = TestWeather.weatherResult(currentTemp: 100, start: inRange.last!.date, inRange: true).forecast
        
        forecast = outOfRange + inRange
        Storage.storedWeather = Weather.WeatherResult.init(currentTemp: .init(value: 100, unit: .fahrenheit), forecast: forecast)
        checkDate = WeatherMonitor.shared.weatherServiceNextCheckDate()
        indexOf = Storage.storedWeather?.forecast.firstIndex(where: { $0.date == checkDate })
        guard let idx2 = indexOf else {
            assert(false)
            return
        }
        assert(idx2 == 7)
        
        HouseStatus.shared.clearFans()
        let nextInterval = WeatherMonitor.shared.weatherServiceNextCheckDate().timeIntervalSince(dtNow)
        
        assert(nextInterval >= 12 * 3600) //12 hours
    }
}

class WeatherBGTestLaunchChecker: XCTestCase {
    let dtNow = Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded())
    let timeIntervals = Array(-2 ... 5).map { TimeInterval($0 * 3600) }
    var forecast = Array<Weather.WeatherObject.Hourly>()
    var weatherObject = Weather.WeatherObject()
//    var testRefreshTask = BGProcessingTask()
    
//    class TestRefreshTask: BGProcessingTask {
//        var taskCompleted: Bool?
//
////        identifier: String = "Test"
////
////        expirationHandler: (() -> Void)?
//
//        override func setTaskCompleted(success: Bool) {
//            taskCompleted = success
//        }
//
//        init (id: String, handler: (() -> Void)?) {
//            identifier = id
//            expirationHandler = handler
//        }
//    }
//
    @MainActor override func setUp() { //prepare environment to successfully handle task
        print("set up")
//        testRefreshTask = TestRefreshTask()
        BGTaskScheduler.shared.cancelAllTaskRequests()
        Storage.lowTempLimit = 55
        Storage.highTempLimit = 75
        Storage.temperatureAlarmEnabled = false
        Storage.storedWeather = TestWeather.weatherResult(currentTemp: 72.0)
        Storage.coordinate = TestWeather.testCoordinate
        HouseStatus.shared.updateStatus(forFan: "test", isOperating: true) //turn on a fan
        WeatherMonitor.shared.currentTemp = Measurement<UnitTemperature>.init(value: 72.0, unit: .fahrenheit)
        Storage.temperatureAlarmEnabled = true
        Task {
            let tasks = await BGTaskScheduler.shared.pendingTaskRequests()
            assert(!tasks.contains(where: { $0.identifier == BackgroundTaskIdentifier.tempertureOutOfRange }))
        }
    }
    
    func testTaskCompleteWithAndWithoutFans() async {
        await HouseStatus.shared.updateStatus(forFan: "test", isOperating: true)
        var taskCompleteSuccess = await WeatherBackgroundTaskManager.handleTempCheckTask()
        assert(taskCompleteSuccess == true)
        await HouseStatus.shared.clearFans()
        taskCompleteSuccess = await WeatherBackgroundTaskManager.handleTempCheckTask()
        assert(taskCompleteSuccess == false)
    }
    
    func testTaskCompleteWithAndWithoutAlarm() async {
        Storage.temperatureAlarmEnabled = true
        var taskCompleteSuccess = await WeatherBackgroundTaskManager.handleTempCheckTask()
        assert(taskCompleteSuccess == true)
        Storage.temperatureAlarmEnabled = false
        taskCompleteSuccess = await WeatherBackgroundTaskManager.handleTempCheckTask ()
        assert(taskCompleteSuccess == false)
    }
    
//    @MainActor func testTempInRange() async {
//        WeatherMonitor.shared.currentTemp = nil
//        WeatherMonitor.shared.tooHot = true
//        WeatherMonitor.shared.tooCold = true
//        Storage.lastNotificationShown = .distantPast
//        await WeatherBackgroundTaskManager.handleTempCheckTask(
//            task: self.testRefreshTask,
//            location: TestWeather.testCoordinate,
//            loader: { _ in TestWeather.weatherResult(currentTemp: 72, start: .now, inRange: false) } )
//        assert(testRefreshTask.taskCompleted == true)
//        assert(WeatherMonitor.shared.currentTemp?.value == 72)
//        assert(WeatherMonitor.shared.tooCold == false)
//        assert(WeatherMonitor.shared.tooHot == false)
//        assert(testRefreshTask.taskCompleted == true)
//        print("testHandleTempCheckTaskNoCurrentTemp check 1: PASSED")
//    }
//    
//    func testTempTooHot() async {
//        self.testRefreshTask = TestRefreshTask()
//        WeatherMonitor.shared.currentTemp = nil
//        WeatherMonitor.shared.tooHot = false
//        WeatherMonitor.shared.tooCold = true
//        await WeatherBackgroundTaskManager.handleTempCheckTask(
//            task: self.testRefreshTask,
//            location: TestWeather.testCoordinate,
//            loader: { _ in TestWeather.weatherResult(currentTemp: Storage.highTempLimit! + 1, start: .now, inRange: true) } )
//        assert(testRefreshTask.taskCompleted == true)
//        assert(WeatherMonitor.shared.currentTemp?.value == Storage.highTempLimit! + 1)
//        assert(WeatherMonitor.shared.tooCold == false)
//        assert(WeatherMonitor.shared.tooHot == true)
//        assert(testRefreshTask.taskCompleted == true)
//        print("testHandleTempCheckTaskNoCurrentTemp check 2: PASSED")
//    }
//    func testTempTooCold() async {
//        self.testRefreshTask = TestRefreshTask()
//        WeatherMonitor.shared.currentTemp = nil
//        WeatherMonitor.shared.tooHot = true
//        WeatherMonitor.shared.tooCold = false
//        Storage.storedWeather = TestWeather.weatherResult(currentTemp: 72, start: .distantPast, inRange: false)
//        await WeatherBackgroundTaskManager.handleTempCheckTask(
//            task: self.testRefreshTask,
//            location: TestWeather.testCoordinate,
//            loader: { _ in TestWeather.weatherResult(currentTemp: Storage.lowTempLimit! - 1, start: .now, inRange: true) } )
//        assert(testRefreshTask.taskCompleted == true)
//        assert(WeatherMonitor.shared.currentTemp?.value == Storage.lowTempLimit! - 1)
//        assert(WeatherMonitor.shared.tooCold == true)
//        assert(WeatherMonitor.shared.tooHot == false)
//        assert(testRefreshTask.taskCompleted == true)
//        print("testHandleTempCheckTaskNoCurrentTemp check 3: PASSED")
//    }
//    
//    func testWithStoredWeather() async {
//        assert (testRefreshTask.taskCompleted == nil)
//        assert (Storage.storedWeather?.forecast.isEmpty == false)
//        assert (Storage.lowTempLimit == 55)
//        assert (Storage.highTempLimit == 75)
//        assert (Storage.temperatureAlarmEnabled == true)
//        assert (HouseStatus.shared.fanRPMs.count > 0)
//        
//        print("testHandleTempCheckTaskWithStoredWeatherData start: PASSED")
//        WeatherMonitor.shared.currentTemp = nil
//        WeatherMonitor.shared.tooHot = true
//        WeatherMonitor.shared.tooCold = true
//        Storage.storedWeather = TestWeather.weatherResult(currentTemp: 72, start: .now, inRange: true)
//        await WeatherBackgroundTaskManager.handleTempCheckTask(
//            task: self.testRefreshTask,
//            location: TestWeather.testCoordinate,
//            loader: { _ in Storage.storedWeather } )
//        assert(testRefreshTask.taskCompleted == true)
//        assert (WeatherMonitor.shared.tooHot == false)
//        assert (WeatherMonitor.shared.tooHot == false)
//        assert(WeatherMonitor.shared.currentTemp!.value == 72)
//        print("testHandleTempCheckTaskWithStoredWeatherData check 1: PASSED")
//
//        Storage.storedWeather = TestWeather.weatherResult(currentTemp: Storage.highTempLimit! + 1, start: .now, inRange: false)
//        WeatherMonitor.shared.currentTemp = nil
//        WeatherMonitor.shared.tooHot = false
//        WeatherMonitor.shared.tooCold = true
//        await WeatherBackgroundTaskManager.handleTempCheckTask(
//            task: testRefreshTask,
//            location: TestWeather.testCoordinate,
//            loader: { _ in Storage.storedWeather })
//        assert(testRefreshTask.taskCompleted == true)
//        assert (WeatherMonitor.shared.tooHot == true)
//        assert (WeatherMonitor.shared.tooCold == false)
//        assert(WeatherMonitor.shared.currentTemp!.value == Storage.highTempLimit! + 1)
//
//        print("testHandleTempCheckTaskWithStoredWeatherData check 2: PASSED")
//
//        Storage.storedWeather = TestWeather.weatherResult(currentTemp: Storage.lowTempLimit! - 1, start: .now, inRange: false)
//        WeatherMonitor.shared.currentTemp = nil
//        WeatherMonitor.shared.tooHot = true
//        WeatherMonitor.shared.tooCold = false
//        await WeatherBackgroundTaskManager.handleTempCheckTask(
//            task: testRefreshTask,
//            location: TestWeather.testCoordinate,
//            loader: { _ in Storage.storedWeather })
//        assert(testRefreshTask.taskCompleted == true)
//        assert (WeatherMonitor.shared.tooHot == false)
//        assert (WeatherMonitor.shared.tooCold == true)
//        assert(WeatherMonitor.shared.currentTemp!.value == Storage.lowTempLimit! - 1)
//
//        print("testHandleTempCheckTaskWithStoredWeatherData check 3: PASSED")
//        Storage.storedWeather = TestWeather.weatherResult(currentTemp: Storage.lowTempLimit! - 1, start: .now - (Double.random(in: ((7200 - 60 * 30)...(7200 + 60 * 30)))), inRange: true)
//        WeatherMonitor.shared.currentTemp = nil
//        WeatherMonitor.shared.tooHot = true
//        WeatherMonitor.shared.tooCold = true
//        await WeatherBackgroundTaskManager.handleTempCheckTask(
//            task: testRefreshTask,
//            location: TestWeather.testCoordinate,
//            loader: { _ in Storage.storedWeather })
//        assert(testRefreshTask.taskCompleted == true)
//        assert (WeatherMonitor.shared.tooHot == false)
//        assert (WeatherMonitor.shared.tooCold == false)
//        assert(WeatherMonitor.shared.currentTemp == Storage.storedWeather!.forecast[1].temp)
//    }
}

class Utilities: XCTestCase {
    //    @AppStorage(StorageKey.forecast.key) var Storage.storedWeather: Data = Data()
    //    @AppStorage(StorageKey.lowTempLimit.key) var Storage.lowTempLimit: Double = 55 //default set in App
    //    @AppStorage(StorageKey.highTempLimit.key) var Storage.highTempLimit: Double = 75 //default set in App
    //    @AppStorage(StorageKey.temperatureAlarmEnabled.key) var Storage.temperatureAlarmEnabled = false //default set in App
    //    @AppStorage(StorageKey.lastForecastUpdate.key) var Storage.lastForecastUpdate: Date? //decodes to Date
   
    
    func testClearUserDefaults() {
        //check with a fan ON, default setup == temp never out of range
        Storage.clear()
        for key in StorageKey.allCases {
            let val = UserDefaults.standard.object(forKey: key.rawValue)
            assert (val == nil)
        }
    }
    
}
