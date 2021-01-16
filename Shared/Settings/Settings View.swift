//
//  Settings View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var slider: CustomSlider
    
    var body: some View {
        VStack {
            Text("Value: " + slider.valueBetween)
            Text("Percentages: " + slider.percentagesBetween)
            
            Text("High Value: \(slider.highHandle.currentValue)")
            Text("Low Value: \(slider.lowHandle.currentValue)")

            SliderView(slider: slider)
        }
    }
    init() {
        slider = CustomSlider(start: 0, end: 100, initHigh: 80, initLow: 10)
    }
}

struct Settings_View_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
