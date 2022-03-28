//
//  House Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

class House {
    static var scanDuration: TimeInterval = 5.0
    var fanSet = Set<FanCharacteristics>() {
        didSet {
            fansRunning = fanSet.map({ $0.speed }).reduce(0, +) > 0
        }
    }
    var fansRunning = false

}
