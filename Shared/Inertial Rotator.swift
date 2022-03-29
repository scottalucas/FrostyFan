//
//  Inertial Rotator.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/29/21.
//

import Foundation
import SwiftUI

struct RotatingView<V>: View where V: View {
    @Binding var rpm: Int
    @StateObject var driver: InertialRotator
    var rotationSymmetry: Angle
    var rotatedView: V
    var speeds = [10, 20, 50, 0]
    
    struct BaseView<BaseView>: View where BaseView: View {
        var pacer: Date
        var driver: InertialRotator
        var base: BaseView
        @State private var ang = Angle.zero
        
        var body: some View {
            return base
                .rotationEffect(ang, anchor: .center)
                .onChange(of: pacer, perform: { _ in
                    let spec = driver.animationSpec
                    withAnimation(spec.animation) {
                        ang += spec.angle
                    }
                })
                .onAppear(perform: {
                    let spec = driver.animationSpec
                    withAnimation(spec.animation) {
                        ang += spec.angle
                    }
                })
        }
    }
    var body: some View {
            TimelineView (
                InertialRotator.Scheduler(driver: driver)
            ) { timeline in
                BaseView(pacer: timeline.date, driver: driver, base: rotatedView)
            }
            .onChange(of: rpm) { newRpm in
                driver.nextRpm = newRpm
            }
    }
    init (rpm: Binding<Int>, baseView: V, symmetry: Angle, transition: InertialRotator.TransitionSpeed) {
        rotatedView = baseView
        rotationSymmetry = symmetry
        self._rpm = rpm
        _driver = StateObject(wrappedValue: InertialRotator(initialRpm: rpm.wrappedValue, standardRotation: symmetry, transitionSpeed: transition))
    }
}

class InertialRotator: ObservableObject {
    var nextRpm: Int
    var animationSpec: RotationSpec = RotationSpec()
    var scheduler: Scheduler!
    private var lastRpm = Int.zero
    private let transition: TransitionSpeed
    private let standardAngle: Angle
    var description: String {
        String("Fan Driver\r\tNext rpm: \(nextRpm)\r\tLast rpm: \(lastRpm)\r\tNext animation: \(animationSpec.description)\r\tTransition speed: \(transition)\r\tStandard angle: \(standardAngle.degrees)")
    }
    func advanceAnimation () {
        animationSpec = RotationSpec.get(driver: self)
        lastRpm = nextRpm
    }
    
    deinit { print ("IR deinit") }
    
    init (initialRpm: Int, standardRotation sRot: Angle, transitionSpeed: TransitionSpeed = .standard) {
        print("IR init")
        self.standardAngle = sRot
        nextRpm = initialRpm
        self.transition = transitionSpeed
        scheduler = Scheduler(driver: self)
    }
}

extension InertialRotator {
    struct Scheduler: TimelineSchedule {
        var driver: InertialRotator
        func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
            return Entries(driver: driver, last: .distantPast)
        }
        
        struct Entries: Sequence, IteratorProtocol {
            var driver: InertialRotator
            var last: Date
            
            mutating func next() -> Date? {
                if last != .distantPast { driver.advanceAnimation() } // have to do this because "next()" is called when the timeline is initialized, and that will advance the animation before the View's ready to use it.
                let dur = driver.animationSpec.duration
                last = Date().addingTimeInterval(dur)
                return last
            }
        }
    }
}

extension InertialRotator {
    struct RotationSpec {
        var animation: Animation
        var duration: TimeInterval
        var angle: Angle
        var description: String {
            String("\t\(type)\r\tDuration: \(duration)\r\tAngle: \(angle.degrees)")
        }
        private var type: AnimateType
        static var atRestDuration = TimeInterval(0.5)
        enum AnimateType { case spinUp, spinDown, atRest, atSpeed }
        static func get(driver: InertialRotator) -> RotationSpec {
            let calcRpm: Double = Double ( max ( driver.lastRpm, driver.nextRpm ) )
            guard calcRpm > 0 else { return RotationSpec(type: .atRest, duration: atRestDuration, angle: .zero) } // at rest
            let stdA = driver.standardAngle
            let stdD = 60.0 * stdA.degrees / ( 360.0 * calcRpm )
            let transA = driver.transition.angle(standardAngle: stdA)
            let transD = driver.transition.duration(standardDuration: stdD)
            switch (driver.lastRpm, driver.nextRpm) {
                case (.zero, _): // spin up
                    return RotationSpec(type: .spinUp, duration: transD, angle: transA)
                case (_, .zero): // spin down
                    return RotationSpec(type: .spinDown, duration: transD, angle: transA)
                default: //at speed
                    return RotationSpec(type: .atSpeed, duration: stdD, angle: stdA)
            }
        }
        private init (type: AnimateType, duration: TimeInterval, angle: Angle) {
            self.type = type
            self.duration = duration
            self.angle = angle
            switch type {
                case .atRest, .atSpeed:
                    animation = .linear(duration: duration)
                case .spinUp:
                    animation = .easeIn(duration: duration)
                case .spinDown:
                    animation = .easeOut(duration: duration)
            }
        }
        init () {
            self.init(type: .atRest, duration: RotationSpec.atRestDuration, angle: .zero)
        }
    }
}

extension InertialRotator {
    enum TransitionSpeed: Double {
        case slow = 2.0, standard = 1.0, fast = 0.8
        func angle(standardAngle: Angle) -> Angle {
            standardAngle * self.rawValue
        }
        func duration(standardDuration: Double) -> TimeInterval {
            1.25 * standardDuration * self.rawValue
        }
    }
    
}

struct RotatingViewModifier: ViewModifier {
    @Binding var rpm: Int
    var rotationSymmetry: Angle
    var transitionSpeed : InertialRotator.TransitionSpeed
    
    func body(content: Content) -> some View {
        RotatingView(rpm: $rpm, baseView: content, symmetry: Angle(degrees: 90.0), transition: .standard)
    }
}

extension View {
    func rotatingView(speed: Binding<Int>, symmetry: Angle, transitionSpeed: InertialRotator.TransitionSpeed = .standard) -> some View {
        modifier(RotatingViewModifier(rpm: speed, rotationSymmetry: symmetry, transitionSpeed: transitionSpeed))
    }
}
