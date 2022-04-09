//
//  Utilities.swift
//  whf001
//
//  Created by Scott Lucas on 12/10/20.
//

import Foundation
import SwiftUI
import Combine

typealias IPAddr = String

typealias MACAddr = String

struct IdentifiableImage: Identifiable, Hashable {
    static var fanLarge = IdentifiableImage(named: "fanLarge")
    static var fanIcon = IdentifiableImage(named: "fanIcon")
    static var flame = IdentifiableImage(named: "flame.fill")
    static var damper = IdentifiableImage(named: "wind")
    static var leaf = IdentifiableImage(named: "leaf.arrow.circlepath")
    static var network = IdentifiableImage(named: "link")
    static var question = IdentifiableImage(named: "questionmark")
    static var settings = IdentifiableImage(named: "gear")
    static var interlock = IdentifiableImage(named: "speedometer")
    static var thermometer = IdentifiableImage(named: "thermometer")
    static var timer = IdentifiableImage(named: "timer")
    static var rainDrops =  IdentifiableImage(named: "cloud.sun")
    static var bell = IdentifiableImage(named: "bell")
    static var info = IdentifiableImage(named: "info.circle.fill")

    var image: Image
    private var imageName: String
    var id: String {
        imageName
    }
    init (named: String) {
        let i = UIImage(systemName: named) ?? UIImage(named: named) ?? UIImage(systemName:  "xmark.octagon.fill")!
        let img = Image(uiImage: i).renderingMode(.template)
        imageName = named
        image = img
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(imageName)
    }
}
extension UIColor {
    static var main = UIColor(named: "main")!
    static var segmentControllerText = UIColor(named: "segmentControllerText")!
    static var segmentControllerBackground = UIColor(named: "segmentControllerBackground")!
    
    static var alarm = UIColor(named: "alarm")!
    static var pageBackground = UIColor(named: "pageBackground")!
    static var controlsTint = UIColor(named: "controlsTint")!
    static var controlsBackground = UIColor(named: "controlsBackground")!
}

extension Color {
    static var main = Color(.main)
    static var segmentControllerText = Color(.segmentControllerText)
    static var segmentControllerBackground = Color(.segmentControllerBackground)
    static var alarm = Color(.alarm)
    static var pageBackground = Color(.pageBackground)
    static var controlsTint = Color(.controlsTint)
    static var controlsBackground = Color(.controlsBackground)
}

struct BackgroundTaskIdentifier {
    static var tempertureOutOfRange = "com.porchdog.whf001.WeatherMonitor.backgroundWeatherCheck"
}

public struct OnScenePhaseChange: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    public let phase: ScenePhase
    public let action: () -> ()
    public func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase, perform: { newPhase in
                if newPhase == phase {
                    action ()
                }
            })
    }
}

extension View {
    func onScenePhaseChange (phase: ScenePhase, action: @escaping () -> () ) -> some View  {
        modifier ( OnScenePhaseChange ( phase: phase, action: action ) )
    }
}

struct ColoredToggleStyle: ToggleStyle {
    var onColor = Color(UIColor.green)
    var offColor = Color(UIColor.systemGray5)
    var thumbColor = Color.white
    
    func makeBody(configuration: Self.Configuration) -> some View {
        HStack {
            configuration.label // The text (or view) portion of the Toggle
            Spacer()
            RoundedRectangle(cornerRadius: 16, style: .circular)
                .fill(configuration.isOn ? onColor : offColor)
                .frame(width: 50, height: 29)
                .overlay(
                    Circle()
                        .fill(thumbColor)
                        .shadow(radius: 1, x: 0, y: 1)
                        .padding(1.5)
                        .offset(x: configuration.isOn ? 10 : -10))
                .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                .onTapGesture { configuration.isOn.toggle() }
        }
//        .padding(.horizontal)
    }
}

struct Utilities_Previews: PreviewProvider {
//    struct GlobalIndicatorHolder {
//        static var sharedHouseData: HouseMonitor {
//            let retVal = HouseMonitor.shared
//            retVal.scanning = true
//            return retVal
//        }
//    }
    
    struct BindingTestHolder: View {
        @State var segments: Int = 8
        @State var highlighted: Int? = 7
        @State var targeted: Int? = 2
        @State var pulse: IndicatorOpacity.IndicatorBlink? = .fastBlink
        var body: some View {
            SegmentedSpeedPicker(segments: $segments, highlightedSegment: $highlighted, indicatedSegment: $targeted, indicatorBlink: $pulse)
                .frame(width: 325, height: 100)
                .overlay(
                    Text("test")
                        .offset(y: 50)
                        .onTapGesture {
                            var sArr: [Int?] = Array((0..<segments))
                            sArr.append(nil)
                            highlighted = (highlighted.map{ ($0 + 1)%(segments + 1) == segments ? nil : ($0 + 1)%(segments + 1) } ?? 0)
                        }
                )
            
        }
    }

    static var previews: some View {
//            let holder = BindingTestHolder()
//            return holder
//                .preferredColorScheme(.dark)
//
//                .eraseToAnyView()
        Rectangle ()
            .foregroundColor(Color(uiColor: .systemBackground))
            .overlay {
                Text("test")
            }
            .pulldownRefresh { }
//            .environmentObject(GlobalIndicatorHolder.sharedHouseData)
    }
}

extension Binding {
    static func mock(_ value: Value) -> Self {
        var value = value
        return Binding(get: { value }, set: { value = $0 })
    }
}
