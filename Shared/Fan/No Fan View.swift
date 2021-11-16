//
//  No Fan View.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/5/21.
//

import SwiftUI

struct NoFanView: View {
    typealias IPAddr = String
    @EnvironmentObject private var sharedHouseData: SharedHouseData
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Rectangle ()
            .foregroundColor(Color(.clear))
            .overlay (alignment: .center) {
                    if sharedHouseData.updateProgress != nil {
                            RefreshIndicator()
                    } else {
                        Text("No fans found")
                    }
            }
            .padding([.top, .bottom], 50)
    }
}

struct No_Fan_View_Previews: PreviewProvider {
    struct InjectedIndicators {
        static var indicators: SharedHouseData {
            let retVal = SharedHouseData.shared
            retVal.updateProgress = 0.2
            return retVal
        }
    }
    static var previews: some View {
        NoFanView()
            .preferredColorScheme(.dark)
            .environmentObject(InjectedIndicators.indicators)
        
    }
}
