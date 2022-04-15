//
//  Inertial Rotator.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/29/21.
//

import Foundation
import SwiftUI
import os.log

struct Rotator<Content: View>: View {
    let logger = Logger(subsystem: "com.porchdog.whf001", category: String(describing: Self.self))
    @Binding var rpm: Int
    let frameRate: Double
    let content: Content
    var body: some View {
        TimelineView (.periodic(from: .now, by: 1.0 / Double(frameRate))) { timeline in
            RotatingView(rpm: $rpm, driver: timeline.date, baseFrameRate: frameRate) {
                content
            }
        }
    }
    init(rpm: Binding<Int>, frameRate: Double = 5.0, @ViewBuilder content: () -> Content) {
        logger.info("Initialized")
        _rpm = rpm
        self.frameRate = frameRate
        self.content = content ()
    }
}

struct RotatingView<Content: View>: View {
    @Binding var rpm: Int
    @StateObject var viewModel: RotatingViewModel
    @State private var deg: Angle = .zero
    var content: Content
    var driver: Date
    
    var body: some View {
        content
            .rotationEffect(deg)
            .onChange(of: driver) { _ in
                withAnimation ( viewModel.animation )  {
                    deg = viewModel.getNextDegree(startingFrom: deg)
                }
            }
            .onChange(of: rpm) { [rpm] newRpm in
                viewModel.updateSpeed(fromRpm: rpm, toRpm: newRpm)
            }
        
            .onAppear() {
                print("update appear")
                viewModel.updateSpeed(fromRpm: 0, toRpm: rpm)
            }
    }
    
    init (rpm: Binding<Int>, driver: Date, baseFrameRate rate: Double, @ViewBuilder content: () -> Content) {
        _rpm = rpm
        self.driver = driver
        self.content = content ()
        _viewModel = StateObject(wrappedValue: RotatingViewModel(frameRate: rate))
    }
}

//extension Rotator {
class RotatingViewModel: ObservableObject {
    var baseFrameRate: Double
    var animation: Animation
    private var animationIndex: Int = .zero
    private var accum: Array<Angle> = .init()
    private let anglePerTransitionFrame: Angle = .init(degrees: 5)
    
    init(frameRate rate: Double = 2.0) {
        baseFrameRate = rate
        animation = Animation.linear ( duration: 1.01 / Double ( rate ) )
    }
    
    func getNextDegree (startingFrom angle: Angle) -> Angle {
        defer { animationIndex = animationIndex == ( accum.endIndex - 1 ) ? animationIndex : animationIndex + 1 }
        return angle + accum [ animationIndex ]
    }
    
    func updateSpeed (fromRpm oldRpm: Int, toRpm newRpm: Int) {
        defer { animationIndex = .zero }
        let startDeg = degPerFrame(forRpm: oldRpm)
        let endDeg = degPerFrame(forRpm: newRpm)
        let frames = max(5, Int((abs(startDeg.degrees - endDeg.degrees) / anglePerTransitionFrame.degrees).rounded()))
        let increments = Array<Angle>.init(repeating: (endDeg - startDeg), count: frames)
        let normalizedCurvePoints =
        (1...frames)
            .map ({ idx -> Double in
                let sIdx = Double(idx) / Double(frames)
                return pow(sIdx, 2) / ( 2.0 * ( pow(sIdx, 2) - sIdx ) + 1.0 )
            })
        accum = zip(increments, normalizedCurvePoints).map({ ( $0 * $1 ) + startDeg })
    }
    
    private func degPerFrame (forRpm rpm: Int) -> Angle {
        return .degrees( 6.0 * Double ( rpm ) / Double ( baseFrameRate ) )
    }
}
//}

struct RotateTest: View {
    @State var rpm: Int = 10
    @State var toggle: Bool = true
    
    var body: some View {
        Rotator (rpm: $rpm) {
            IdentifiableImage.fanLarge.image
                .resizable()
                .aspectRatio(1.0, contentMode: .fit)
                .scaleEffect(1.75)
                .task {
                    while true {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        rpm = toggle ? 0 : 80
                        toggle.toggle()
                    }
                }
        }
    }
}

struct Rotater_Previews: PreviewProvider {
    static var previews: some View {
            RotateTest()
    }
}
