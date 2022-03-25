//
//  No Fan View.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/5/21.
//

import SwiftUI

struct NoFanView: View {
    typealias IPAddr = String
    @ObservedObject var houseViewModel: HouseViewModel
    @Environment(\.scenePhase) var scenePhase
//    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Rectangle ()
            .foregroundColor(Color(.clear))
            .overlay (alignment: .center) {
                if houseViewModel.scanUntil > .now {
                    RefreshIndicator(houseViewModel: houseViewModel)
                        .tint(.main)
                } else {
                    Text("No fans found")
                }
            }
            .padding([.top, .bottom], 50)
    }
}

struct No_Fan_View_Previews: PreviewProvider {

    static var previews: some View {
        NoFanView(houseViewModel: HouseViewModel())
            .preferredColorScheme(.dark)
        
    }
}
