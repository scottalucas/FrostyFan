//
//  Timer Sheet.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/1/21.
//

import SwiftUI

struct TimerSheet: FanSheet {
    @ObservedObject var fanViewModel: FanViewModel
    var body: some View {
        Button (action: {
            fanViewModel.timer += 10
        }, label: {
            Text("\(fanViewModel.timer)")
        })
        Text("Remaining time is \(fanViewModel.timer)")
            .onDisappear { fanViewModel.testText = "timer disappear" }
    }
}

struct Timer_View_Previews: PreviewProvider {
    static var previews: some View {
        TimerSheet(fanViewModel: FanViewModel())
    }
}
