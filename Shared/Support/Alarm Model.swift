//
//  Alarm Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/10/21.
//

import Foundation
import SwiftUI

//final class HouseStatus: OptionSet, RawRepresentable {
//    var rawValue: Int
//    
////    static var scanning = HouseStatus(rawValue: 1)
//    static var tooHot = HouseStatus(rawValue: 1 << 1)
//    static var tooCold = HouseStatus(rawValue: 1 << 2)
//    static var noFansAvailable = HouseStatus(rawValue: 1 << 3)
//    static var temperatureAvailable = HouseStatus(rawValue: 1 << 4)
//    static var temperatureAlarmsEnabled = HouseStatus(rawValue: 1 << 5)
//
//    var description: [String] {
//        var retVal = Array<String>()
//        if self.contains(.tooHot) { retVal.append("Too hot") }
//        if self.contains(.tooCold) { retVal.append("Too cold") }
////        if self.contains(.scanning) { retVal.append("Scanning") }
//        if self.contains(.noFansAvailable) { retVal.append("No fans") }
//        if self.contains(.temperatureAvailable) { retVal.append("Temp reading available") }
//        if self.contains(.temperatureAlarmsEnabled) { retVal.append("Temp alarms configured") }
//        return retVal
//    }
//    
//    internal init (rawValue: Int) {
//        self.rawValue = rawValue
//    }
//}

//final class HouseLamps: OptionSet, RawRepresentable, Equatable {
//    var rawValue: Int
//    static let shared = HouseLamps()
//    
//    static var showTemperatureWarning = HouseLamps(rawValue: 1 << 1)
//    static var showScanningSpinner = HouseLamps(rawValue: 1 << 2)
//    static var useAlarmColor = HouseLamps(rawValue: 1 << 3)
//    static var showTemperatureText = HouseLamps(rawValue: 1 << 4)
//    static var showNoFanWarning = HouseLamps(rawValue: 1 << 5)
//
//    var description: [String] {
//        var retVal = Array<String>()
//        if self.contains(.showTemperatureWarning) { retVal.append("Temperature indicator") }
//        if self.contains(.showScanningSpinner) { retVal.append("Scanning spinner") }
//        if self.contains(.showTemperatureText) { retVal.append("Show temp text") }
//        if self.contains(.useAlarmColor) { retVal.append("App: use alarm color") }
//        if self.contains(.showNoFanWarning) { retVal.append("Show no fan warning") }
//        return retVal
//    }
//    
//    var diplayedLabels: [String] {
//        var labelArr = Array<String>()
//        if self.contains(.showTemperatureWarning) { labelArr.append("Outside temperature warning") }
//        if self.contains(.showScanningSpinner) { labelArr.append("Looking for fans") }
//        if self.contains(.showNoFanWarning) { labelArr.append("No fans found") }
//        return labelArr
//    }
//    
//    internal init (rawValue: Int) {
//        self.rawValue = rawValue
//    }
//}


//final class FanStatus: OptionSet, RawRepresentable {
//    var rawValue: Int
//
//    static var speedAdjustmentFailed = FanStatus(rawValue: 1)
//    static var speedAdjusting = FanStatus(rawValue: 1 << 1)
//    static var fanOff = FanStatus(rawValue: 1 << 2)
//
//    static var nonZeroTimeRemaining = FanStatus(rawValue: 1 << 3)
//    static var timerAdjusting = FanStatus(rawValue: 1 << 4)
//    static var timerAdjustmentFailed = FanStatus(rawValue: 1 << 5)
//
//    static var interlockActive = FanStatus(rawValue: 1 << 6)
//
//    static var damperOperating = FanStatus(rawValue: 1 << 7)
//
//    static var fanNotResponsive = FanStatus(rawValue: 1 << 8)
//
//    static var noFanCharacteristics = FanStatus(rawValue: 1 << 9)
//
//    static var updatedByFan: FanStatus = [.fanOff, .interlockActive, .damperOperating, .fanNotResponsive, .noFanCharacteristics]
//
//    var description: [String] {
//        var retVal = Array<String>()
//        if self.contains(.interlockActive) { retVal.append("Interlock active") }
//        if self.contains(.damperOperating) { retVal.append("Damper operating") }
//        if self.contains(.speedAdjusting) { retVal.append("Speed adjusting") }
//        if self.contains(.nonZeroTimeRemaining) { retVal.append("Time remaining not zero") }
//        if self.contains(.timerAdjusting) { retVal.append("Timer adjusting") }
//        if self.contains(.fanOff) { retVal.append("Zero speed") }
//        if self.contains(.speedAdjustmentFailed) { retVal.append("Speed adjustment failed")}
//        if self.contains(.timerAdjustmentFailed) { retVal.append("Timer adjustment failed")}
//        if self.contains(.fanNotResponsive) { retVal.append("Fan unresponsive")}
//        if self.contains(.noFanCharacteristics) { retVal.append("Fan unresponsive")}
//        return retVal
//    }
//
//    internal init (rawValue: Int) {
//        self.rawValue = rawValue
//    }
//}

//final class FanLamps: OptionSet, RawRepresentable {
//    var rawValue: Int
//    
//    static var useAlarmColor = FanLamps(rawValue: 1)
//    static var showTimerIcon = FanLamps(rawValue: 1 << 1) //may not need
//    static var showTimeLeft = FanLamps(rawValue: 1 << 2)
//    static var showPhysicalSpeedIndicator = FanLamps(rawValue: 1 << 3)
//    static var showDamperIndicator = FanLamps(rawValue: 1 << 4)
//    static var showInterlockIndicator = FanLamps(rawValue: 1 << 5)
//    static var showMinorFaultIndicator = FanLamps(rawValue: 1 << 6)
//    static var showMajorFaultIndicator = FanLamps(rawValue: 1 << 7)
//    static var showNoCharsIndicator = FanLamps(rawValue: 1 << 8)
//
//    var description: [String] {
//        var retVal = Array<String>()
//        if self.contains(.useAlarmColor) { retVal.append("Fan: use alarm color") }
//        if self.contains(.showTimerIcon) { retVal.append("Show timer icon") }
//        if self.contains(.showTimeLeft) { retVal.append("Show time left") }
//        if self.contains(.showPhysicalSpeedIndicator) { retVal.append("Show physical speed indicator") }
//        if self.contains(.showDamperIndicator) { retVal.append("Show damper indicator") }
//        if self.contains(.showInterlockIndicator) { retVal.append("Show interlock indicator") }
//        if self.contains(.showMinorFaultIndicator) { retVal.append("Show minor fault indicator") }
//        if self.contains(.showMajorFaultIndicator) { retVal.append("Show major fault indicator") }
//        if self.contains(.showNoCharsIndicator) { retVal.append("Show no chars indicator") }
//        return retVal
//    }
//    
//    var diplayedLabels: [String] {
//        var labelArr = Array<String>()
//        if self.contains(.showDamperIndicator) { labelArr.append("Damper operating") }
//        if self.contains(.showInterlockIndicator) { labelArr.append("Interlock active") }
//        if self.contains(.showNoCharsIndicator) { labelArr.append("Features not found") }
//        if self.contains(.showMajorFaultIndicator) { labelArr.append("Major fan fault") }
//        if self.contains(.showMinorFaultIndicator) { labelArr.append("Minor fan fault") }
//        return labelArr
//    }
////
////    var displayedIcons: [Image] {
////        var labelArr = Array<Image>()
////        if self.contains(.showDamperIndicator) { labelArr.append(.damper) }
////        if self.contains(.showInterlockIndicator) { labelArr.append(.interlock) }
////        return labelArr
////    }
////
//    internal init (rawValue: Int) {
//        self.rawValue = rawValue
//    }
//}
