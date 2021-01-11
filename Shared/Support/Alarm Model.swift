//
//  Alarm Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/10/21.
//

import Foundation

struct Alarm: OptionSet {
    let rawValue: UInt8
    
    static let interlock = Alarm(rawValue: 1 << 0)
    static let tooCold = Alarm(rawValue: 1 << 1)
    static let tooHot = Alarm(rawValue: 1 << 2)
    static let adjustingSpeed = Alarm(rawValue: 1 << 3)
    
    static let redColorAlarms: Alarm = [.interlock, .tooCold, .tooHot]
    static let displaySpeedIndicator: Alarm = [.adjustingSpeed, .interlock]
    static let houseAlarms: Alarm = [.tooHot, .tooCold] //alarms raised by the house
    static let fanAlarms: Alarm = [.interlock, .adjustingSpeed] //alarms specific to a fan

    static func labels (forOptions options: Alarm) -> [String] {
        var retVal = Array<String>()
        if options.contains(interlock) {retVal.append("Interlock Active")}
        if options.contains(tooHot) {retVal.append("Outside Temperature High")}
        if options.contains(tooCold) {retVal.append("Outside Temperature Low")}
        return retVal
    }
    
}
