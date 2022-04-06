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
    static var background = Color(.pageBackground)
    static var controlsTint = Color(.controlsTint)
    static var controlsBackground = Color(.controlsBackground)
}

struct BackgroundTaskIdentifier {
    static var tempertureOutOfRange = "com.porchdog.whf001.WeatherMonitor.backgroundWeatherCheck"
}
//
//extension Notification.Name {
//    static let houseUpdates = Notification.Name("houseUpdates")
//}
//
//enum HouseNotificationUserInfoKey: Hashable {
//    case scanUntil, houseMessage, activeFan, houseAlarm
//}

//com.porchdog.whf001.WeatherMonitor.backgroundWeatherCheck
//extension View {
//    func overlaySheet(dataSource source: FanViewModel, activeSheet: Binding<OverlaySheet?>) -> some View {
//        modifier(OverlaySheetRender(dataSource: source, activeSheet: activeSheet))
//    }
//}

//struct OverlaySheetRender: ViewModifier {
//    @Binding var activeSheet: OverlaySheet?
//    @ObservedObject var data: FanViewModel
//
//    func body (content: Content) -> some View {
//        content
//            .sheet(item: $activeSheet, onDismiss: {
//                defer { Task { await data.setTimerWheel(to: 0) } }
//                if data.timerWheelPosition > 0 {
//                    data.setTimer(addHours: data.timerWheelPosition)
//                }
//            }) {
//                switch $0 {
//                    case .detail:
//                        DetailSheet(chars: data.chars, activeSheet: $activeSheet)
//                    case .fanName:
//                        NameSheet(sheet: .constant(.fanName), storageKey: StorageKey.fanName(data.chars.macAddr))
//                    case .timer:
//                        TimerSheet(wheelPosition: $data.timerWheelPosition, activeSheet: $activeSheet, timeOnTimer: data.chars.timer)
//                    case .fatalFault:
//                        FatalFaultSheet()
//                }
//            }
//    }
//    init (dataSource: FanViewModel, activeSheet: Binding<OverlaySheet?>) {
//        self._activeSheet = activeSheet
//        self.data = dataSource
//    }
//}


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
