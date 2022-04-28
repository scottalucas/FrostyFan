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

struct RotatedView<Content: View>: View {
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

class RotatingViewModel: ObservableObject {
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
    private var accel: Double = 45 // Degrees/s/s

    @MainActor func getDeg(for nextDate: Date) -> Angle {
        var nextAngle: Angle = .zero
        var instantaneousRpm: Double = .zero
        defer {
            lastDate = nextDate
            lastAngle = nextAngle
            currentRpm = instantaneousRpm
            if instantaneousRpm == rpmEnd, instantaneousRpm == 0, !startTransition {
                pauseRotation.send(true)
            }
        }
        
        if startTransition {
            let timeToTransition = abs ( 6.0 * ( rpmEnd - rpmStart ) / accel ) //seconds
            transitionRange = Range<Date>.init(uncheckedBounds: (lower: nextDate, upper: nextDate.addingTimeInterval(timeToTransition)))
            startTransition = false
        }
        
        instantaneousRpm = instantRpm(currentTime: nextDate)
        
        if ( instantaneousRpm < 9 && rpmEnd == 0 ) {
            if springRange == nil, let upperB = transitionRange?.upperBound, upperB > nextDate
            {
                springRange = Range<Date>( uncheckedBounds: ( lower: nextDate, upper: upperB ) )
            }
            instantaneousRpm = instantaneousRpm * wobbleMultiply(forRpm: instantaneousRpm, at: nextDate)
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
    
    private func wobbleMultiply (forRpm rpm: Double, at time: Date) -> Double {
        guard let range = springRange, range.upperBound > time else {
            springRange = nil
            return 1.0
        }
        let progress = range.lowerBound.timeIntervalSince(time) / ( range.upperBound.timeIntervalSinceReferenceDate - range.lowerBound.timeIntervalSinceReferenceDate )
        return cos(progress * 10.0 * .pi) * 2.0
    }
    
    private func instantRpm (currentTime: Date) -> Double {
        guard let upperB = transitionRange?.upperBound, currentTime <= upperB else {
            transitionRange = nil
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
    var rpm: Double = 10
    
    var body: some View {
        Rotator (rpm: rpm) {
            IdentifiableImage.fanLarge.image
                .resizable()
                .aspectRatio(1.0, contentMode: .fit)
                .scaleEffect(1.75)
                .task {
                    while true {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
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
