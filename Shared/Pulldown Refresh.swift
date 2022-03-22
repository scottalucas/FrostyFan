//
//  Pulldown Refresh.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/12/21.
//

import Foundation
import SwiftUI

struct RefreshIndicator: View {
    @EnvironmentObject private var sharedHouseData: HouseMonitor
    @State private var start = Date.now
    var body: some View {
        Group {
            if ( (sharedHouseData.scanning ?? false) ) {
                Color.clear
                    .overlay (
                        GeometryReader { geo in
                            HStack {
                                Spacer()
                                VStack {
                                    TimelineView( .periodic( from: .now, by: 0.1 ) ) { context in
                                        ProgressView(value: (context.date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) / sharedHouseData.scanDuration)
                                    }
                                    Text("Scanning...")
                                }
                                .frame(
                                    maxWidth: min(200, geo.size.width * 0.8),
                                    maxHeight: geo.size.height)
                                Spacer()
                            }
                            .accentColor(.main)
                        }
                    )
            } else {
                EmptyView()
            }
        }
        .onAppear {
            start = .now
        }
        .onChange(of: HouseMonitor.shared.scanning) { scanning in
            print("Scanning: \(scanning.map ({ $0.description }) ?? "nil")")
            start = .now
        }
    }
}

struct PulldownRefresh: ViewModifier {
    @GestureState private var dragSize = CGSize.zero
    @State private var verticalOffset: Double = .zero
    @State private var isEnabled = true
    private var complete: () async -> Void
    
    func body(content: Content) -> some View {
        content
            .offset(x: 0, y: verticalOffset)
            .gesture(DragGesture().onChanged { value in
                guard isEnabled else { return }
                let verticalTranslation = max(0, value.location.y - value.startLocation.y)
                verticalOffset = verticalTranslation
                if verticalTranslation >= 75 {
                    isEnabled = false
                    let thump = UIImpactFeedbackGenerator(style: .rigid)
                    thump.impactOccurred()
                    withAnimation {
                        verticalOffset = .zero
                    }
                    Task {
                        await complete()
                        isEnabled = true
                    }
                }
            })
    }
    init(complete: @escaping () async -> Void) {
        self.complete = complete
    }
}


extension View {
    func pulldownRefresh (_ complete: @escaping () async -> Void) -> some View {
        modifier(PulldownRefresh(complete: complete))
    }
}
