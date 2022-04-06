//
//  Inertial Rotator.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/29/21.
//

import Foundation
import SwiftUI

class RotatingViewStore: ObservableObject {
    @Published var deg: Angle = .zero
    static var inertialFrames: Int = 15
    static var baseFrameRate: Int = 10
    private var currentInertialIndex: Int = .zero
    private var startRpm: Int = .zero
    private var currentRpm: Int = .zero
    
    private func degPerFrame (forRpm rpm: Int) -> Angle {
        return .degrees( 6.0 * Double ( rpm ) / Double ( RotatingViewStore.baseFrameRate ) )
    }
    
    func changeRpm (to newRpm: Int) {
        startRpm = currentRpm
        currentRpm = newRpm
        currentInertialIndex = 0
    }
    
    func rotate () {
        defer { currentInertialIndex += 1  }
        let deltaDeg = degPerFrame(forRpm: currentRpm) - degPerFrame(forRpm: startRpm)
        let indx = ( Double ( currentInertialIndex ) / Double ( RotatingViewStore.inertialFrames ) ).clamped(to: 0.0...1.0)
        let sqt = indx * indx
        let increment = sqt / (2.0 * ( sqt - indx ) + 1.0)
        deg += deltaDeg * increment + degPerFrame(forRpm: startRpm)
    }
    
    func diagnostic () -> String {
        "\(startRpm)\t\(currentRpm)\t\(currentInertialIndex)\t\(deg.degrees)"
    }
}

struct RotatingView: ViewModifier {
    @Binding var rpm: Int

    struct Rotater<Content>: View where Content: View {
        @Binding var rpm: Int
        @StateObject var store = RotatingViewStore()
        private var baseView: Content
        private var driver: Date

        var body: some View {
                baseView
                    .onChange(of: driver, perform: { context in
                        withAnimation ( .linear ( duration: 1.0 / Double(RotatingViewStore.baseFrameRate) ) ) {
                            store.rotate()
                        }
                    } )
                    .onChange(of: rpm ) { newRpm in
                        store.changeRpm(to: newRpm)
                    }
                    .onAppear {
                        store.changeRpm(to: rpm)
                    }
                    .rotationEffect(store.deg)
        }

        init (rpm: Binding<Int>, baseView: Content, driver: Date) {
            _rpm = rpm
            self.baseView = baseView
            self.driver = driver
        }
    }
    
    func body(content: Content) -> some View {
        TimelineView (.periodic(from: .now, by: 1.0 / Double(RotatingViewStore.baseFrameRate))) { timeline in
            Rotater(rpm: _rpm, baseView: content, driver: timeline.date)
        }
        
    }
}

extension View {
    func rotate (rpm: Binding<Int> ) -> some View {
        modifier(RotatingView(rpm: rpm))
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
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    rpm = toggle ? 0 : 20
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
