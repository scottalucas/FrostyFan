//
//  Alarm Model.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 1/10/21.
//

import Foundation

//protocol Option: RawRepresentable, Hashable, CaseIterable {}
//
//extension Set where Element: Option {
//   var rawValue: Int {
//        var rawValue = 0
//        for (index, element) in Element.allCases.enumerated() {
//            if self.contains(element) {
//                rawValue |= (1 << index)
//            }
//        }
//        return rawValue
//    }
//}
//
//enum Lamp: Int, Option {
//    case showTrueSpeed, useAlarmColor, interlock, tooHot, tooCold, location
//}
//
//extension Set where Element == Lamp {
//    var labels: [String] {
//        var retValue = Array<String>()
//        if self.contains(.interlock) { retValue.append("Interlock active")}
//        if self.contains(.tooHot) { retValue.append("Outside temperature too hot")}
//        if self.contains(.tooCold) { retValue.append("Outside temperature too cold")}
//        return retValue
//    }
//}
//
////typealias Lamps = Set<Lamp>
//
//enum Alert: Int, Option {
//    case interlock, temperature
//}
//
//typealias Alerts = Set<Alert>

struct Lamps: OptionSet, RawRepresentable {
    let rawValue: Int
    static var interlock = Lamps(rawValue: 1 << 0)
    static var tooHot = Lamps(rawValue: 1 << 1)
    static var tooCold = Lamps(rawValue: 1 << 2)
    static var speedAdjusting = Lamps(rawValue: 1 << 3)
    static var damperOpening = Lamps(rawValue: 1 << 4)
    static var timerActive = Lamps(rawValue: 1 << 5)
    static var fanOff = Lamps(rawValue: 1 << 6)
    
    static var useAlarmColor: Lamps = [.interlock]
    static var showPhysicalSpeed: Lamps = [.interlock, .speedAdjusting]
    
    var labels: [String] {
        var retVal = Array<String>()
        if self.contains(.interlock) { retVal.append("Interlock active") }
        if self.contains(.tooHot) { retVal.append("It's hot outside") }
        if self.contains(.tooCold) { retVal.append("It's cold outside") }
        if self.contains(.damperOpening) { retVal.append("Fan starting") }
        if self.contains(.timerActive) { retVal.append("Timer running")}
        if self.contains(.fanOff) {
            retVal.append("Fan is off")
        }
        return retVal
    }
}

//struct ConfiguredAlerts: OptionSet, RawRepresentable {
//    let rawValue: Int
//    static var interlock = ConfiguredAlerts(rawValue: 1 << 0)
//    static var temperature = ConfiguredAlerts(rawValue: 1 << 1)
//}
//struct Alarm {
//
//    struct Fan: Codable, OptionSet, RawRepresentable {
//        let rawValue: Int
//        static let showTrueSpeed = Alarm.Fan(rawValue: 1 << 0)
//        static let damperOperating = Alarm.Fan(rawValue: 1 << 1)
//
//        static let redColorAlarms: Alarm.Fan = []
//        static let displaySpeedIndicator: Alarm.Fan = [.showTrueSpeed]
//        static let alwaysConfigured: Alarm.Fan = [.damperOperating]
//        static func enabled (forAddr addr: String) -> Alarm.Fan {
//            var retVal: Alarm.Fan = []
//            if UserDefaults.standard.bool(forKey: StorageKey.fanAdjustingSpeed(addr).key) { retVal.insert(.showTrueSpeed) }
//            if UserDefaults.standard.bool(forKey: StorageKey.fanDamperOperating(addr).key) { retVal.insert(.damperOperating) }
//            return retVal
//        }
//        var labels: [String] {
//            var retVal = Array<String>()
//            if self.contains(.damperOperating) { retVal.append("Fan starting up") }
//            if self.contains(.showTrueSpeed) { retVal.append("Adjusting speed") }
//            return retVal
//        }
//    }
//
//    struct House: Codable, OptionSet, RawRepresentable {
//        let rawValue: Int
//        static let interlock = Alarm.House(rawValue: 1 << 0)
//        static let tooCold = Alarm.House(rawValue: 1 << 1)
//        static let tooHot = Alarm.House(rawValue: 1 << 2)
//
//        static let weatherRequired: Alarm.House = [.tooHot, .tooCold]
//        static let alwaysConfigured: Alarm.House = []
//        static let redColorAlarms: Alarm.House = [.interlock]
//        static func enabled () -> Alarm.House {
//            var retVal: Alarm.House = []
//            if UserDefaults.standard.bool(forKey: StorageKey.interlockAlarmEnabled.key) { retVal.insert(.interlock) }
//            if UserDefaults.standard.bool(forKey: StorageKey.temperatureAlarmEnabled.key) { retVal.insert([.tooHot, .tooCold]) }
//            return retVal
//        }
//        var labels: [String] {
//            var retVal = Array<String>()
//            if self.contains(.tooHot) {retVal.append("Outside Temperature High")}
//            if self.contains(.tooCold) {retVal.append("Outside Temperature Low")}
//            if self.contains(.interlock) {retVal.append("Interlock limiting speed")}
//            return retVal
//        }
//    }
//}
