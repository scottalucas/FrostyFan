//
//  No Fan View.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/5/21.
//

import SwiftUI

struct NoFanView: View {
    typealias IPAddr = String
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        Rectangle ()
            .foregroundColor(Color(uiColor: .systemBackground))
            .overlay {
                    Text("No fans found")
            }
            .padding([.top, .bottom], 50)
    }
}

struct No_Fan_View_Previews: PreviewProvider {
    static var previews: some View {
        NoFanView()
//            .environmentObject(HouseViewModel())
            .preferredColorScheme(.dark)
    }
}
