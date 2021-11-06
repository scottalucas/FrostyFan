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
//    @EnvironmentObject var house: House
//    @GestureState private var dragSize = CGSize.zero
//    @State var verticalOffset: Double = .zero
    
    var body: some View {
        Rectangle ()
            .foregroundColor(Color(uiColor: .systemBackground))
            .overlay {
                VStack (alignment: .center, spacing: 20)
                {
//                if house.isRefreshing {
//                    ProgressView ()
//                }
                VStack {
                    Text("No fans found")
//                    Text("\(dragSize.debugDescription)")
//                    Text(house.isRefreshing ? "Refreshing" : "Not refreshing")
                }
                }
//                .offset(y: verticalOffset)
            }
            .padding([.top, .bottom], 50)
//            .pulldownRefresh()
//            .gesture(DragGesture().updating($dragSize) { value, state, _ in
//                print(house.isRefreshing)
//                guard !house.isRefreshing else { return }
//                state = CGSize(width: .zero, height: max(0, min(75, value.translation.height)))
//                verticalOffset = 75 * (state.height)/(state.height + 75)
//                if state.height >= 75 {
//                    let thump = UIImpactFeedbackGenerator(style: .rigid)
//                    thump.impactOccurred()
//                    house.scan()
//                    withAnimation {
//                        verticalOffset = .zero
//                    }
//                }
//            })
    }
}

struct No_Fan_View_Previews: PreviewProvider {
    static var previews: some View {
        NoFanView()
            .environmentObject(House())
            .preferredColorScheme(.dark)
    }
}
