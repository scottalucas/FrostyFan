//
//  Pulldown Refresh.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/12/21.
//

import Foundation
import SwiftUI

struct RefreshIndicator: View {
    @EnvironmentObject private var globalIndicators: GlobalIndicators
    var body: some View {
        if let update = globalIndicators.updateProgress {
            GeometryReader { geo in
                HStack {
                    Spacer()
                    VStack {
                        ProgressView(value: update)
                        Text("Scanning...")
                    }
                    .frame(
                        maxWidth: min(200, geo.size.width * 0.8),
                        maxHeight: geo.size.height)
                    Spacer()
                }
            }
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
