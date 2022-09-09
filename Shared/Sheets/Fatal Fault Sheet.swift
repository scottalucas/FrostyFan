//
//  Fatal Fault Sheet.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 11/2/21.
//
/*
 Mostly for troubleshooting.
 */

import SwiftUI

struct FatalFaultSheet: View {
    
    var body: some View {
        Color.main
            .ignoresSafeArea()
            .overlay {
                VStack {
                    Text("Lost contact with fan")
                    Button ("Ok") {
//                        NotificationCenter.default.post(name: .removeFan, object: nil, userInfo: [view : ""])
                    }
                }
            }
    }
//
//    init (view: FanView) {
//        self.view = view
//    }
}

struct Fatal_Fault_Sheet_Previews: PreviewProvider {
    static var previews: some View {
        FatalFaultSheet()
    }
}
