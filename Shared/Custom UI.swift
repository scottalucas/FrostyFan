//
//  Utilities.swift
//  whf001
//
//  Created by Scott Lucas on 12/10/20.
//

import Foundation
import SwiftUI
import Combine
import Network

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

extension FanModel.Action: CustomStringConvertible {
    var description: String {
        switch self {
            case .refresh:
                return "refresh"
            case .faster:
                return "faster"
            case .timer:
                return "timer"
            case .slower:
                return "slower"
            case .off:
                return "off"
        }
    }
}

extension NWPath.Status: CustomStringConvertible {
    public var description: String {
        switch self {
        case .requiresConnection:
            return "requires connection"
        case .satisfied:
            return "satisfied"
        case .unsatisfied:
            return "unsatisfied"
        @unknown default:
            return "unknown"
        }
    }
}

extension AdjustmentError: CustomStringConvertible {
    var description: String {
        switch self {
            case .notReady(let info):
                return "Not ready, \(info ?? "no further info.")"
            case .notNeeded:
                return "Not needed"
            case .retrievalError (let err):
                return "Retrieval error \(err.localizedDescription)"
            case .parentOutOfScope:
                return "Parent out of scope"
            case .speedDidNotChange:
                return "Speed did not change"
            case .timerDidNotChange:
                return "Timer did not change"
            case .fanNotResponsive:
                return "Fan not responsive"
            case .missingKeys:
                return "Missing keys"
            case .notFound:
                 return "Not found"
            case .notAtTarget:
                return "Not at target"
            case .upstream (let err):
                return "Upstream error \(err.localizedDescription)"
        }
    }
}

extension ConnectionError: CustomStringConvertible {
    var description: String {
        switch self {
            case .badUrl:
                return "Bad url"
            case .timeout:
                return "timeout"
            case .networkError (let reason):
                return "Network error \(reason)"
            case .serverError (let reason):
                return "Server error \(reason)"
            case .decodeError (let reason):
                return "Decode error \(reason)"
            case .upstream (let err):
                return "Upstream type: \(err.self) description: \(err.localizedDescription)"
        }
    }
}

extension WeatherRetrievalError: CustomStringConvertible {
    var description: String {
        switch self {
            case .noLocation:
                return "Location not permitted or not set"
            case .badUrl:
                return "Bad URL"
            case .decodeError:
                return "Could not decode data returned from weather service"
            case .throttle (let lastUpdate):
                return "Throttled weather service, last update was \(lastUpdate)"
            case .serverError (let error):
                var errorDesc = ""
                switch error {
                    case nil:
                        errorDesc = "Unknown error"
                    case .some(let errorCode):
                        switch errorCode {
                            case 401:
                                errorDesc = "API key error or wrong subscription type request."
                            case 404:
                                errorDesc = "Wrong location or API format."
                            case 429:
                                errorDesc = "API call rate exceeded."
                            case 500, 502, 503, 504:
                                errorDesc = "API key error or wrong subscription type request."
                            default:
                                errorDesc = "Open weather map error \(errorCode)."
                        }
                }
                return "Server error \(errorDesc)."
            case .tooManyTries:
                return "Too many attempts to retrieve weather"
            case .cancelled:
                return "Task cancelled"
            case .unknownError (let errorDescription):
                return "Unknown error \(errorDescription)"
        }
    }
}

extension BackgroundTaskError: CustomStringConvertible {
    var description: String {
        switch self {
            case .notAuthorized:
                return "User has disabled notifications."
            case .fanNotOperating:
                return "No fans are operating"
            case .tempAlarmNotSet:
                return "User has disabled temperature alarms"
            case .noCurrentTemp:
                return "No current temperature provided"
            case .taskCancelled:
                return "Task cancelled"
        }
    }
}

extension NotificationError: CustomStringConvertible {
    var description: String {
        switch self {
            case .dataNotAvailable:
                return "Data not available"
            case .notificationsDisabled:
                return "Notifications disable"
            case .tooSoon:
                return "Too soon for another notification"
        }
    }
}

extension FanCharacteristics.DamperStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .operating:
            return "operating"
        case .notOperating:
            return "not operating"
        case .unknown:
            return "unknown"
        }
    }
}

extension IndicatorOpacity.IndicatorBlink: CustomStringConvertible {
    var description: String {
        switch self {
        case .fastBlink:
            return "fast"
        case .slowBlink:
            return "slow"
        }
    }
}

extension Coordinate: CustomStringConvertible {
    var description: String {
        return "\(lat.latitudeStr) \(lon.longitudeStr)"
    }
}

extension Double {
    var latitudeStr: String {
        let formatter = NumberFormatter()
        formatter.positiveFormat = "##0.00\u{00B0} N"
        formatter.negativeFormat = "##0.00\u{00B0} S"
        return formatter.string(from: NSNumber(value: self)) ?? "nil"
    }
    var longitudeStr: String {
        let formatter = NumberFormatter()
        formatter.positiveFormat = "##0.00\u{00B0} E"
        formatter.negativeFormat = "##0.00\u{00B0} W"
        return formatter.string(from: NSNumber(value: self)) ?? "nil"
    }
}

extension Angle {
    var degFormat: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        let a = NSNumber(value: self.degrees)
        return formatter.string(from: a) ?? ""
    }
}
struct SizePreferenceKey: PreferenceKey {
  static var defaultValue: CGSize = .zero

  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
  }
}

struct MeasureSizeModifier: ViewModifier {
  func body(content: Content) -> some View {
    content.background(GeometryReader { geometry in
      Color.clear.preference(key: SizePreferenceKey.self,
                             value: geometry.size)
    })
  }
}

extension View {
  func measureSize(perform action: @escaping (CGSize) -> Void) -> some View {
    self.modifier(MeasureSizeModifier())
      .onPreferenceChange(SizePreferenceKey.self, perform: action)
  }
}
