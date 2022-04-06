//
//  Pulldown Refresh.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/12/21.
//

import Foundation
import SwiftUI

struct RefreshIndicator: View {
    @Binding var scanUntil: Date
    @State private var progress: Double = 0.0
    @State private var progressTimer: Timer?
//    private var scanUntil: Date = .distantPast
    var body: some View {
            VStack (alignment: .center) {
                Color.clear
                    .overlay (
                        GeometryReader { geo in
                            HStack {
                                Spacer ()
                                VStack {
                                    Spacer()
                                    ProgressView (value: progress.clamped(to: 0.0...1.0))
                                    Text("Scanning...")
                                    Spacer()
                                }
                                .frame(
                                    maxWidth: min(200, geo.size.width * 0.8),
                                    maxHeight: geo.size.height)
                                Spacer ()
                            }
                            .accentColor(.main)
                        }
                    )
                Spacer ()
            }
            .onAppear () {
                if scanUntil > .now {
                    startCountdown()
                } else {
                    progress = 1.0
                }
            }
            .onChange(of: scanUntil) { until in
                if until > .now {
                    startCountdown()
                } else {
                    progress = 1.0
                }
            }
    }
    
    init(scanUntil: Binding<Date>) {
        _scanUntil = scanUntil
    }

    private func startCountdown () {
        progressTimer?.invalidate()
        progressTimer = nil
        let timeToRun = scanUntil.timeIntervalSinceNow
        guard timeToRun > 0 else { return }
        progressTimer = Timer.scheduledTimer(withTimeInterval: timeToRun/100.0, repeats: true) { _ in
            guard scanUntil > .now else {
                progress = 1.0
                progressTimer?.invalidate()
                progressTimer = nil
                return
            }
            progress = 1 - (scanUntil.timeIntervalSinceNow/timeToRun)
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

struct RefreshIndicatorPreviewContainer: View {
    @State private var start: Date?
    
    var body: some View {
        RefreshIndicator(scanUntil: .constant(.distantFuture))
            .task {
                try? await Task.sleep(interval: 1.0)
                start = .now.addingTimeInterval(5)
                try? await Task.sleep(interval: 2)
                start = .now.addingTimeInterval(1)
            }
    }
}

struct RefreshIndicator_Previews: PreviewProvider {
    static var previews: some View {
        RefreshIndicatorPreviewContainer ()
    }
}
