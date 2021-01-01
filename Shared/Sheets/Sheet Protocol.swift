//
//  Sheet Protocol.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/1/21.
//

import Foundation
import SwiftUI

protocol FanSheet: View {
    var fanViewModel: FanViewModel { get set }
}
