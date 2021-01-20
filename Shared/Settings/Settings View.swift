//
//  Settings View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct SettingsView: View {
//    @ObservedObject var slider: CustomSlider
    @State var lowVal: Double = 45
    @State var highVal: Double = 85
    var body: some View {
        VStack {
RangeSlider(lowValue: $lowVal, highValue: $highVal, minValue: 45, maxValue: 85)
    .padding()
        }
    }
    init() {
//        slider = CustomSlider(start: 0, end: 100, initHigh: 80, initLow: 10)
    }
}

struct Settings_View_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
