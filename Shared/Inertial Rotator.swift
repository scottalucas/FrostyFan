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
//    private var rpm = CurrentValueSubject<Int, Never>(0)
//    @StateObject var viewModel: RotatingViewModel

    let frameRate: Double
//    let content: Content
    @StateObject var rotatedView: RotatingViewModel<Content>
    private var bag = Set<AnyCancellable>()
    var body: some View {
//        ZStack {
            TimelineView (.periodic(from: .now, by: 1.0 / Double(frameRate))) { timeline in
                rotatedView.rotate()
            }
//            Text("\(rpm)")
//        }
//        .onChange(of: rpm) { newRpm in
//            var transaction = Transaction(animation: nil)
//            transaction.disablesAnimations = true
//            withTransaction(transaction) {
//                rotatedView.updateRpm(to: newRpm)
//            }
//        }
//        .onAppear() {
//            rotatedView.updateRpm(to: rpm)
//        }
    }
    init(rpm: CurrentValueSubject<Int, Never>, frameRate: Double = 5.0, content: Content) {
        print("INIT view")
//        let newId = UUID().uuidString
        self.frameRate = frameRate
//        let c = content ()
//        rpm.sink(receiveValue: { self.rpm = $0 }).store(in: &bag)
        _rotatedView = StateObject(wrappedValue: RotatingViewModel(rpm: rpm, frameRate: frameRate, content: content))
    }
}

class RotatingViewModel<Content: View>: ObservableObject {

    private var logger: Logger!
    private var id2: String = UUID().uuidString
    private var baseFrameRate: Double
    private var animation: Animation
    private var animationIndex: Int = .zero
    private var accum: Array<Angle> = [.zero]
    private let anglePerTransitionFrame: Angle = .init(degrees: 5)
    private var deg: Angle = .zero
    private var rpm: Int = .zero
    { didSet {
        print("\(id2) rpm: \(rpm)")
    }}
    private var content: Content
    private var bag = Set<AnyCancellable>()
    
    deinit { Log.ui.debug( "deinit \(self.id2)" ) }
                           
    init(rpm: CurrentValueSubject<Int, Never>, frameRate rate: Double = 5.0, content: Content) {
        Log.ui.debug("rotator view model initialized")
        baseFrameRate = rate
        animation = Animation.linear ( duration: 1.0 / Double ( rate ) )
        self.content = content
        rpm
//            .print("\(id) \(id2)")
            .sink(receiveValue: { [weak self] newValue in self?.updateRpm(to: newValue) }).store(in: &bag)
    }
    
    func rotate () -> AnyView {
        let lastDeg = deg
        deg = getNextDegree()
//        print("rotate \(deg.degFormat) rpm \(rpm) delta \((lastDeg - deg).degFormat)")
        return ZStack {
            Text("\(deg.degrees)")
            content
            .rotationEffect(deg)
            .animation(animation, value: deg)
        }
        .eraseToAnyView()
    }

    func updateRpm (to newRpm: Int) {
        defer {
//            rpm = newRpm
//            print ("\(rpm)")
        }

        animationIndex = .zero
        let startDeg = degPerFrame(forRpm: rpm)
        let deltaDeg = degPerFrame(forRpm: newRpm).degrees - startDeg.degrees
        let frames = max(5, Int ( ( abs ( deltaDeg ) / anglePerTransitionFrame.degrees ).rounded ( ) ) )
        let increments = Array<Angle>.init(repeating: (Angle(degrees: deltaDeg)), count: frames)
        let normalizedCurvePoints =
        (1...frames)
            .map ({ idx -> Double in
                let sIdx = Double(idx) / Double(frames)
                return pow(sIdx, 2) / ( 2.0 * ( pow(sIdx, 2) - sIdx ) + 1.0 )
            })
        let zippedStr = zip(increments, normalizedCurvePoints).map({ $0 * $1 + startDeg }).reduce("") { last, next in last.appending("\r\(next)") }
        //        Log.ui.debug("Old rpm: \(oldRpm) new rpm: \(newRpm)")
        //        Log.ui.debug("Delta deg: \(deltaDeg)")
        //        Log.ui.debug("\(zippedStr)")
        accum = zip(increments, normalizedCurvePoints).map({ ( $0 * $1 ) + startDeg })
        print(String(describing: accum.map{ rpmFromDeg($0) }))
    }
    
    private func getNextDegree () -> Angle {
//        guard accum.count > 0 else { return angle }
        let nextIndex = min(accum.count - 1, animationIndex + 1)
        let nextAngle = deg + accum [ animationIndex ]
        if nextIndex != accum.count - 1 {
//            Log.ui.debug("animation i \(self.animationIndex) accum count \(self.accum.count) accum last i \(self.accum.endIndex)  next index: \(nextIndex) last angle \(Int(angle.degrees)%360) next angle \(Int(nextAngle.degrees)%360)")
//            Log.ui.debug("last angle \(Int(angle.degrees)%360) next angle \(Int(nextAngle.degrees)%360) delta: \(Int(angle.degrees - nextAngle.degrees))")
      }
        defer {
            rpm = Int(rpmFromDeg(accum [ animationIndex ]))
            animationIndex = nextIndex }
        print ("calc rpm: \(rpmFromDeg(accum [animationIndex]))")
        return nextAngle
    }
    
    
    private func degPerFrame (forRpm rpm: Int) -> Angle {
        return .degrees( 6.0 * Double ( rpm ) / Double ( baseFrameRate ) )
    }
    
    private func rpmFromDeg (_ deg: Angle) -> Double {
        return deg.degrees * Double (baseFrameRate) / 6.0
    }
}

struct RotateTest: View {
    var rpm = CurrentValueSubject<Int, Never>(10)
    @State var toggle: Bool = true
    
    var body: some View {
        Rotator (rpm: rpm, content:
            IdentifiableImage.fanLarge.image
                .resizable()
                .aspectRatio(1.0, contentMode: .fit)
                .scaleEffect(1.75)
                .task {
                    while true {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        rpm.send(toggle ? 0 : 80)
                        toggle.toggle()
                    }
                }
        )
    }
}

struct Rotater_Previews: PreviewProvider {
    static var previews: some View {
            RotateTest()
    }
}
