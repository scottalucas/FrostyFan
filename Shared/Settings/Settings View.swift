//
//  Settings View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct SettingsView: View {
    //    @ObservedObject var slider: CustomSlider
    @State var lowVal: Double = 55
    @State var highVal: Double = 75
    var body: some View {
        VStack {
            RangeSlider(lowValue: $lowVal, highValue: $highVal, minValue: 45, maxValue: 85)
                .padding(40)
            Text(Int(lowVal).description)
            Text(Int(highVal).description)
        }
        .frame(width: 200, height: nil, alignment: .center)
    }
}

struct Settings_View_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
