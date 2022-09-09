//
//  Inertial Rotator.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/29/21.
//
/*
 This is a view modifier designed to apply an adjustable, continuously rotating effect to a view. Available rotation animation options can't easily change speed mid-rotation without jerkiness. This animation also adds inertial changes and a "judder" that simulates an electric motor stopping.
 
 This is used in the Fan View/Rotator Render view.
 */

import Foundation
import SwiftUI
import Combine
import os.log

struct Rotator<Content: View>: View { //this is what's called in the view. RPM does not need to trigger state redraws since the TimelineView updates continuously. In fact, using a State variable has unintended side effects if/when it triggers a rebuild (i.e. child view properties being reinitialized and causing animation stutters).
    @State var pauseRotation = false
    var rpm: Double
    var content: Content
    
    var body: some View {
        VStack {
        TimelineView(.animation(paused: pauseRotation)) { timeline in
                RotatedView(rpm: rpm, pacer: timeline.date, pause: $pauseRotation) {
                    content
                }
            }
        }
    }
    
    init (rpm: Double, content: () -> Content) {
        self.rpm = rpm
        self.content = content ()
    }
}

fileprivate struct RotatedView<Content: View>: View { //this struct rotates the underlying View.
    @StateObject var viewModel = RotatingViewModel ()
    @Binding var pauseRotation: Bool
    private var content: Content
    private var pacer: Date
    private var rpm: Double

    var body: some View {
        content
            .rotationEffect(viewModel.getDeg(for: pacer))
            .onChange(of: rpm, perform: { newValue in
                viewModel.setRpm(to: newValue)
            })
            .onReceive(viewModel.pauseRotation) { pause in
                pauseRotation = pause
            }
    }
    
    init (rpm: Double, pacer: Date, pause: Binding<Bool>, _ content: () -> Content) {
        self.content = content ()
        self.pacer = pacer
        self.rpm = rpm
        _pauseRotation = pause
    }
}

fileprivate class RotatingViewModel: ObservableObject { //do all the math here
    var pauseRotation = CurrentValueSubject<Bool, Never>(false)
    private var startTransition: Bool = false
    private var startSpring: Bool = true
    private var lastDate: Date = .now
    private var lastAngle: Angle = .zero
    private var rpmStart: Double = .zero
    private var rpmEnd: Double = .zero
    private var currentRpm: Double?
    private var transitionRange: Range<Date>?
    private var springRange: Range<Date>?
    private var springDecaySlope: Double = 1.0
    private var springDecayIntercept: Double = .zero
    private var accel: Double = 45 // Degrees/s/s

    @MainActor func getDeg(for nextDate: Date) -> Angle { //this is a continuous animation. This function calculates the next rotational degree based on time delta from the last time it was set.
        var nextAngle: Angle = .zero
        var instantaneousRpm: Double = .zero
        defer { //clean up to prepare for next call of the function.
            lastDate = nextDate
            lastAngle = nextAngle
            currentRpm = instantaneousRpm
            if instantaneousRpm == rpmEnd, instantaneousRpm == 0, !startTransition { // fan animation has stopped, pause animation. Not sure if this has to be done, but the .animation TimelineScheduler keeps firing if you don't.
                pauseRotation.send(true)
                springRange = nil
                transitionRange = nil
            }
        }
        
        if startTransition { //this handles calculations for inertial speed changes.
            let timeToTransition = abs ( 6.0 * ( rpmEnd - rpmStart ) / accel ) //seconds
            transitionRange = Range<Date>.init(uncheckedBounds: (lower: nextDate, upper: nextDate.addingTimeInterval(timeToTransition)))
            startTransition = false
        }
        
        instantaneousRpm = instantRpm(currentTime: nextDate)
        
        if ( instantaneousRpm < 3 && rpmEnd == 0 ) { // add "judder" to simulate a stopping electric motor.
            if springRange == nil, let upperB = transitionRange?.upperBound, upperB > nextDate
            {
                springRange = Range<Date>( uncheckedBounds: ( lower: nextDate, upper: nextDate.addingTimeInterval(0.75) ) )
                springDecaySlope = instantaneousRpm * 2.0
                springDecayIntercept = instantaneousRpm
            }
            if let springRange = springRange {
                let progress = springRange.upperBound.timeIntervalSince(nextDate) / springRange.upperBound.timeIntervalSince(springRange.lowerBound)
                let damper = progress * springDecayIntercept
                instantaneousRpm = progress <= 0.0 ? 0.0 : progress * springDecayIntercept * wobbleMultiply(forRpm: damper, at: nextDate)
            }
        }

        let deltaTime = nextDate.timeIntervalSinceReferenceDate - lastDate.timeIntervalSinceReferenceDate
        let deltaDeg: Angle = .degrees ( 6.0 * instantaneousRpm * deltaTime )
        nextAngle = deltaDeg + lastAngle
        return nextAngle
    }
    
    func setRpm (to rpm: Double) {
        guard rpm != rpmEnd else { return }
        rpmStart = currentRpm ?? rpmEnd
        rpmEnd = rpm
        startTransition = true
        pauseRotation.send(false)
    }
    
    private func wobbleMultiply (forRpm rpm: Double, at time: Date) -> Double { //function to create the modifier for ending judder.
        guard let range = springRange, range.upperBound > time else {
            return .zero
        }
        let progress = range.lowerBound.timeIntervalSince(time) / ( range.upperBound.timeIntervalSinceReferenceDate - range.lowerBound.timeIntervalSinceReferenceDate )
        return cos(progress * 5.0 * .pi) * 2.0
    }
    
    private func instantRpm (currentTime: Date) -> Double { //calculate the instantaneous rpm. If the fan's rotating at a steady state, this returns the same value for each animation. If it's making an inertial change, this returns an appropriate value for the current inertial progress.
        guard let upperB = transitionRange?.upperBound, currentTime <= upperB else {
            return Double ( rpmEnd )
        }
        guard let lowerB = transitionRange?.lowerBound, currentTime >= lowerB else {
            return Double ( rpmStart )
        }
        let progress: Double = lowerB.timeIntervalSince(currentTime) / lowerB.timeIntervalSince(upperB)

        return ( Double ( rpmEnd - rpmStart ) ) * ( pow ( progress, 2 ) / ( 2.0 * ( pow ( progress, 2 ) - progress ) + 1.0 ) ) + Double ( rpmStart )
    }

}

struct RotateTest: View {
//    var rpm = CurrentValueSubject<Int, Never>(10)
    @State var toggle: Bool = true
    @State var rpm: Double = 15
    
    var body: some View {
        VStack {
            Rotator (rpm: $rpm.wrappedValue) {
                IdentifiableImage.fanLarge.image
                    .resizable()
                    .aspectRatio(1.0, contentMode: .fit)
                    .scaleEffect(1.75)
                    .task {
                        while true {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            toggle.toggle()
                            rpm = toggle ? 0 : 20
                        }
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
