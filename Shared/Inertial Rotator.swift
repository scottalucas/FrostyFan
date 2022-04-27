//
//  Inertial Rotator.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/29/21.
//

import Foundation
import SwiftUI
import Combine
import os.log

struct Rotator<Content: View>: View {
    private let framePeriod: Double
    private let content: Content
    var rpm: Int
    var body: some View {
        TimelineView (.periodic(from: .now, by: ( framePeriod * 1 ) )) { timeline in
                RotatedView(rpm: rpm, driver: timeline.date, framePeriod: framePeriod) {
                    content
                }
            }
    }
    init(rpm: Int, frameRate: Double = 10.0, content: @escaping () -> Content) {
        self.content = content ()
        self.rpm = rpm
        framePeriod = 1.0 / Double(frameRate)
    }
}

struct RotatedView<Content: View>: View {
    @StateObject var viewModel: RotatingViewModel
    private var driver: Date = .now
    private var rpm: Int = .zero
    private var content: Content
    var body: some View {
        content
            .rotationEffect(viewModel.deg)
            .animation(viewModel.animation, value: viewModel.deg)
            .onChange(of: driver) { newValue in
                viewModel.updateRpm(to: rpm)
                viewModel.getNextDegree()
            }
    }
    
    init(rpm: Int, driver: Date, framePeriod: Double, content: () -> Content) {
        self.rpm = rpm
        self.content = content ()
        _viewModel = StateObject(wrappedValue: RotatingViewModel(rpm: rpm, framePeriod: framePeriod))
    }
}

class RotatingViewModel: ObservableObject {

    var deg: Angle = .zero
    var animation: Animation
    private var baseFramePeriod: TimeInterval
    private var animationIndex: Int = .zero
    private var accum: Array<Angle> = [.zero]
    private let anglePerTransitionFrame: Angle = .init(degrees: 2)
    private var targetRpm: Int = .zero
    private var currentRpm: Double = .zero
    private var frameMark = Date.now
    
    struct FrameTimer {
        private var entries = Dictionary<String, Date>()
        
        func diff(_ name: String) -> TimeInterval? {
            guard let start = entries[name] else { return nil }
            return start.timeIntervalSinceNow
        }
        mutating func mark(_ name: String) {
            entries[name] = .now
        }
    }
                           
    init(rpm: Int, framePeriod period: TimeInterval = 1.0 / 5.0) {
        baseFramePeriod = period
        animation = Animation.linear ( duration: period )
        self.targetRpm = rpm
    }
    
    func updateRpm (to newRpm: Int) {
        guard newRpm != targetRpm else { return }
        targetRpm = newRpm
        animationIndex = .zero
        let startDeg = degPerFrame(forRpm: currentRpm)
        let deltaDeg = degPerFrame(forRpm: targetRpm).degrees - startDeg.degrees
        let frames = max(5, Int ( ( abs ( deltaDeg ) / anglePerTransitionFrame.degrees ).rounded ( ) ) )
        let increments = Array<Angle>.init(repeating: (Angle(degrees: deltaDeg)), count: frames)
        let normalizedCurvePoints =
        (1...frames)
            .map ({ idx -> Double in
                let sIdx = Double(idx) / Double(frames)
                return pow(sIdx, 2) / ( 2.0 * ( pow(sIdx, 2) - sIdx ) + 1.0 )
            })
        accum = zip(increments, normalizedCurvePoints).map({ ( $0 * $1 ) + startDeg })
    }
    
    func getNextDegree () {
        var nextAngle: Angle = .zero
        defer {
            frameMark = .now
            deg = nextAngle
            animationIndex = min ( animationIndex + 1, accum.count - 1)
        }
        let dT = frameMark.timeIntervalSinceNow
        animation = .linear(duration: dT)
        let adj = Double ( abs ( dT / baseFramePeriod ) )
        nextAngle = ( deg + accum [ animationIndex ] * adj )
        currentRpm = rpmFromDeg(accum [ animationIndex ])
        let degPerT = (nextAngle.degrees - deg.degrees) / ( dT == 0 ? .infinity : dT )
        let rotPerS = degPerT / 360.0
        let rotPerM = rotPerS * 60.0
        Log.ui.debug("\(adj) \(String(describing: rotPerM)) \(dT)")
        deg = nextAngle
    }
    
    
    private func degPerFrame (forRpm rpm: Double) -> Angle {
        return .degrees( 6.0 * rpm * baseFramePeriod )
    }
    
    private func degPerFrame (forRpm rpm: Int) -> Angle {
        return .degrees( 6.0 * Double ( rpm ) * baseFramePeriod )
    }
    
    private func rpmFromDeg (_ deg: Angle) -> Double {
        return deg.degrees / ( 6.0 * baseFramePeriod )
    }
}

struct RotateTest: View {
//    var rpm = CurrentValueSubject<Int, Never>(10)
    @State var toggle: Bool = true
    @State var rpm: Int = 10
    
    var body: some View {
        Rotator (rpm: rpm) {
            IdentifiableImage.fanLarge.image
                .resizable()
                .aspectRatio(1.0, contentMode: .fit)
                .scaleEffect(1.75)
                .task {
                    while true {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        rpm = (toggle ? 0 : 60)
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
