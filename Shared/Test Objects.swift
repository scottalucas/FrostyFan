//
//  Test Objects.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 12/24/20.
//

import Foundation

struct TestItems {
//    static var fans: [String] = ["0.0.0.0:8181"]
        static var fans: [String] = []
}

class TestViewModel: ObservableObject {
    @Published var segmentState: Int = 0
    @Published var userSelection: Int?
    
    var userSelectedSpeed: Int?
    
    init () {
        Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
            self.segmentState = 4
        }
    }
}
