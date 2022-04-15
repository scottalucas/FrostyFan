//
//  House Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine
import os.log

class House {
    let logger = Logger()
    static var scanDuration: TimeInterval = 5.0
    var fanSet = Set<FanCharacteristics>() {
        didSet {
            fansRunning = fanSet.map({ $0.speed }).reduce(0, +) > 0
        }
    }
    var fansRunning = false
    init () {
        logger.log("House model init")
        print("house model init")
    }
}
