//
//  Logging.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 4/15/22.
//

import Foundation
import os

struct Log {
    static var app = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "app")
    static var house = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "house")
    static var fan = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "fan")
    static var config = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "config")
    static var weather = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "weather")
    static var location = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "location")
    static var ui = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ui")
    static var background = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "background")
    static var alert = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "alert")
    static var settings = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "settings")
    static var network = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network")

    static func custom(category: String) -> Logger { Logger(subsystem: Bundle.main.bundleIdentifier!, category: category)}
}
