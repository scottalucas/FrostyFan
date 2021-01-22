//
//  Settings View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct SettingsView: View {
    @State var lowVal: Double = 55
    @State var highVal: Double = 75
//    var slider: RangeSlider
    var body: some View {
        VStack {
            RangeSlider(selectedLow: $lowVal, selectedHigh: $highVal, minimum: 45, maximum: 85)
            {
                var config = RangeSlider.Style()
                config.barSelectedColor = Color.main
                config.handleShadowColor = Color.black.opacity(0.15)
                config.lowHandleStrokeColor = Color.blue
                config.highHandleStrokeColor = Color.red
                return config
            }
            .padding()
            Text(Int(lowVal).description)
            Text(Int(highVal).description)
        }
//        .frame(width: 200, height: nil, alignment: .center)
    }
}

struct Settings_View_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
