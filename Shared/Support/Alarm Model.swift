//
//  Alarm Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/10/21.
//

import Foundation

final class ApplicationLamps: OptionSet, RawRepresentable {
    var rawValue: Int
    static let shared = ApplicationLamps()
    
    static var tooHot = ApplicationLamps(rawValue: 1 << 1)
    static var tooCold = ApplicationLamps(rawValue: 1 << 2)
    
    static var showTemperatureWarning: ApplicationLamps = [.tooHot, .tooCold]
    
    var useAlarmColor: Bool {
        !self.intersection([.tooHot, .tooCold]).isEmpty
    }
    
    var showTemperatureWarning: Bool {
        !self.intersection([.tooHot, .tooCold]).isEmpty
    }
    
    var labels: [String] {
        var retVal = Array<String>()
        if self.contains(.tooHot) { retVal.append("It's hot outside") }
        if self.contains(.tooCold) { retVal.append("It's cold outside") }
        return retVal
    }
    
    internal init (rawValue: Int) {
        self.rawValue = rawValue
    }
}

extension ApplicationLamps: ObservableObject {}

final class FanLamps: OptionSet, RawRepresentable {
    var rawValue: Int
    
    static var interlockActive = FanLamps(rawValue: 1)
    static var physicalSpeedMismatchToRequested = FanLamps(rawValue: 1 << 1) //may not need
    static var damperOperating = FanLamps(rawValue: 1 << 2)
    static var speedAdjusting = FanLamps(rawValue: 1 << 3)
    static var nonZeroTimeRemaining = FanLamps(rawValue: 1 << 4)
    static var timerAdjusting = FanLamps(rawValue: 1 << 5)
    static var fanOff = FanLamps(rawValue: 1 << 6)
    static var speedAdjustmentFailed = FanLamps(rawValue: 1 << 7)
    static var timerAdjustmentFailed = FanLamps(rawValue: 1 << 8)
    static var fanNotResponsive = FanLamps(rawValue: 1 << 9)

    var labels: [String] {
        var retVal = Array<String>()
        if self.contains(.interlockActive) { retVal.append("Interlock active") }
        if self.contains(.physicalSpeedMismatchToRequested) { retVal.append("Physical speed mismatch") }
        if self.contains(.damperOperating) { retVal.append("Damper operating") }
        if self.contains(.speedAdjusting) { retVal.append("Speed adjusting") }
        if self.contains(.nonZeroTimeRemaining) { retVal.append("Time remaining not zero") }
        if self.contains(.timerAdjusting) { retVal.append("Timer adjusting") }
        if self.contains(.fanOff) { retVal.append("Zero speed") }
        if self.contains(.speedAdjustmentFailed) { retVal.append("Speed adjustment failed")}
        if self.contains(.timerAdjustmentFailed) { retVal.append("Timer adjustment failed")}
        if self.contains(.fanNotResponsive) { retVal.append("Fan unresponsive")}
        return retVal
    }
    
    var showTimerIcon: Bool {
        self.isDisjoint(with: [.damperOperating, .speedAdjusting, .timerAdjusting, .fanOff])
    }
    
    var showTimeRemainingText: Bool {
        self.showTimerIcon && self.contains(.nonZeroTimeRemaining)
    }
    
    var showPhysicalSpeedIndicator: Bool {
        self.contains(.speedAdjusting) && (!self.contains(.fanOff) || self.contains(.damperOperating))
    }
    
    var useAlarmColor: Bool {
        self.contains(.interlockActive)
    }
    
    internal init (rawValue: Int) {
        self.rawValue = rawValue
    }
}

//extension FanLamps: ObservableObject {}
