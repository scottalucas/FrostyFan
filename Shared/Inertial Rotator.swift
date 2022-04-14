//
//  Inertial Rotator.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/29/21.
//

import Foundation
import SwiftUI

class RotatingViewModel: ObservableObject {
    var baseFrameRate: Double
    var animationIndex: Int = .zero
    var animation: Animation
    var accum: Array<Angle> = .init()
    private let anglePerTransitionFrame: Angle = .init(degrees: 1.5)
    
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

struct RotatingView<BaseView>: View where BaseView: View {
    
    @Binding var rpm: Int
    @StateObject var viewModel: RotatingViewModel
    @State private var deg: Angle = .zero
    var baseView: BaseView
    var driver: Date
    
    var body: some View {
        return baseView
            .rotationEffect(deg)
            .onChange(of: driver) { _ in
                withAnimation ( viewModel.animation )  {
                    deg = viewModel.getNextDegree(startingFrom: deg)
                }
            }
            .onChange(of: rpm) { [rpm] newRpm in
                print("update change")
                viewModel.updateSpeed(fromRpm: rpm, toRpm: newRpm)
            }
            .onAppear() {
                print("update appear")
                viewModel.updateSpeed(fromRpm: 0, toRpm: rpm)
            }
    }
    
    init (rpm: Binding<Int>, driver: Date, baseFrameRate rate: Double, baseView: BaseView) {
        _rpm = rpm
        self.driver = driver
        self.baseView = baseView
        _viewModel = StateObject(wrappedValue: RotatingViewModel(frameRate: rate))
    }
}

struct Rotator: ViewModifier {
    @Binding var rpm: Int
    let frameRate: Double = 10.0
    func body (content: Content) -> some View {
        TimelineView (.periodic(from: .now, by: 1.0 / Double(frameRate))) { timeline in
            RotatingView(rpm: $rpm, driver: timeline.date, baseFrameRate: frameRate, baseView: content)
        }
        
        
    }
}

extension View {
    func rotate ( rpm: Binding<Int> ) -> some View {
        modifier(Rotator(rpm: rpm))
    }
}

struct RotateTest: View {
    @State var rpm: Int = 10
    @State var toggle: Bool = true
    
    var body: some View {
        IdentifiableImage.fanLarge.image
            .resizable()
            .aspectRatio(1.0, contentMode: .fit)
            .scaleEffect(1.75)
            .rotate(rpm: $rpm)
            .task {
                while true {
                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                    rpm = toggle ? 0 : 80
                    toggle.toggle()
                }
            }
    }
}

struct Rotater_Previews: PreviewProvider {
    static var previews: some View {
        RotateTest()
    }
}
