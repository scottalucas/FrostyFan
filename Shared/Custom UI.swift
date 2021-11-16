//
//  Utilities.swift
//  whf001
//
//  Created by Scott Lucas on 12/10/20.
//

import Foundation
import SwiftUI
import Combine

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

extension View {
    func overlaySheet(dataSource source: FanViewModel, activeSheet: Binding<OverlaySheet?>) -> some View {
        modifier(OverlaySheetRender(dataSource: source, activeSheet: activeSheet))
    }
}

struct OverlaySheetRender: ViewModifier {
    @Binding var activeSheet: OverlaySheet?
    @ObservedObject var data: FanViewModel
    
    func body (content: Content) -> some View {
        content
            .sheet(item: $activeSheet, onDismiss: {
                defer { Task { await data.setTimerWheel(to: 0) } }
                if data.timerWheelPosition > 0 {
                    data.setTimer(addHours: data.timerWheelPosition)
                }
            }) {
                switch $0 {
                    case .detail:
                        DetailSheet(chars: data.chars)
                    case .fanName:
                        NameSheet(storageKey: StorageKey.fanName(data.chars.macAddr))
                    case .timer:
                        TimerSheet(wheelPosition: $data.timerWheelPosition, timeOnTimer: data.chars.timer)
                    case .fatalFault:
                        FatalFaultSheet()
                }
            }
    }
    init (dataSource: FanViewModel, activeSheet: Binding<OverlaySheet?>) {
        self._activeSheet = activeSheet
        self.data = dataSource
    }
}

struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct WidthReader: ViewModifier {
    private var sizeView: some View {
        GeometryReader { geometry in
            Color.clear.preference(key: WidthPreferenceKey.self, value: geometry.size.width)
        }
    }

    func body(content: Content) -> some View {
        content.background(sizeView)
    }
}

struct RangeSliderHandle: View {
    @Binding var value: Double
    var style = RangeSlider.HandleStyle()
    private var handleLabel: HandleLabel?

    struct HandleLabel: View {
        @Binding var value: Double
        var style: RangeSlider.LabelStyle
        var body: some View {
            Text(style.numberFormat.string(from: NSNumber(value: value)) ?? "")
                .font(style.isItalic ? style.labelFont.italic() : style.labelFont)
                .fontWeight(style.labelWeight)
                .foregroundColor(style.color)
                .background(style.background)
        }
    }
    
    var body: some View {
        ZStack {
            style.handleShape
                .size(style.size)
                .fill(style.fill)
                .overlay(style.handleShape
                            .size(style.size)
                            .stroke(lineWidth: style.strokeWeight)
                            .foregroundColor(style.strokeColor))
                .overlay(style.handleBackground ?? Color.clear.eraseToAnyView())
                .shadow(color: style.shadowColor, radius: style.shadowRadius, x: style.shadowOffset.width, y: style.shadowOffset.height)
                .frame(width: style.size.width, height: style.size.height, alignment: .center)
            if let label = handleLabel {
                label
                    .offset(style.labelOffset ?? CGSize(width: 0, height: -style.size.height * 1.3))
            }
        }
    }
    
    init(_ value: Binding<Double>? = nil, handleFormatter: (inout RangeSlider.HandleStyle) -> () = { _ in }) {
        _value = value ?? .constant(0.0)
        handleFormatter(&style)
        if let val = value, let style = style.labelStyle {
            handleLabel = HandleLabel(value: val, style: style)
        }
    }
}

struct RangeSlider: View {
    //unit = base value
    @Binding var lowValue: Double
    {
        willSet {
            offsetLow = maxWidth * CGFloat((newValue - minValue) / (maxValue - minValue))
        }
    }
    @Binding var highValue: Double
    {
        willSet {
            offsetHigh = maxWidth * CGFloat((newValue - minValue) / (maxValue - minValue))
        }
    }
    
    private var minValue: Double
    private var maxValue: Double

    private var barStyle = BarStyle()
    private var leftHandle: RangeSliderHandle
    private var rightHandle: RangeSliderHandle
    
    //unit = pixel
    @State private var offsetLowBookmark: CGFloat = .zero
    @State private var offsetHighBookmark: CGFloat = .infinity
    @State private var offsetLow: CGFloat = .zero
    @State private var offsetHigh: CGFloat = .infinity
    @State private var maxWidth: CGFloat = .infinity
    
    //unit = percent
    private var lowerHandleUpperBound: Double {
        Double(offsetHigh / maxWidth) - barStyle.minHandleSeparation
    }
    private var upperHandleLowerBound: Double {
        Double(offsetLow / maxWidth) + barStyle.minHandleSeparation
    }
    
    var body: some View {
        ZStack (alignment: Alignment(horizontal: .leading, vertical: .center)) {
            Group {
                RoundedRectangle(cornerRadius: barStyle.barHeight / 2)
                    .fill(barStyle.barOutsideFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: barStyle.barHeight / 2)
                            .stroke(lineWidth: barStyle.barOutsideStrokeWeight)
                            .foregroundColor(barStyle.barOutsideStrokeColor)
                    )
                    
                    .padding([.leading, .trailing], 5)
                    .modifier(WidthReader())
                    .onPreferenceChange(WidthPreferenceKey.self) { width in
                        maxWidth = width - (leftHandle.style.size.width + rightHandle.style.size.width) * 0.5
                        offsetHigh = CGFloat( ( highValue - minValue) / (maxValue - minValue) ) * (maxWidth)
                        offsetLow = CGFloat( ( lowValue - minValue) / (maxValue - minValue) ) * (maxWidth)
                        offsetHighBookmark = offsetHigh
                        offsetLowBookmark = offsetLow
                    }
                Rectangle ()
                    .size(width: (offsetHigh - offsetLow), height: barStyle.barHeight)
                    .fill(barStyle.barInsideFill)
                    .overlay(
                        Rectangle()
                            .size(width: (offsetHigh - offsetLow), height: barStyle.barHeight)
                            .stroke(lineWidth: barStyle.barInsideStrokeWeight)
                            .foregroundColor(barStyle.barInsideStrokeColor)
                    )
                    .offset(x: offsetLow + (leftHandle.style.size.width + rightHandle.style.size.width) * 0.25, y: 0)
            }
            .frame(width: nil, height: barStyle.barHeight, alignment: .center)
            leftHandle
                .gesture(
                    DragGesture (minimumDistance: 0.0, coordinateSpace: .global)
                        .onChanged { drag in
                            let positionPercent = Double((offsetLowBookmark + drag.translation.width) / maxWidth).clamped(to: .zero...lowerHandleUpperBound)
                            lowValue = positionPercent * (maxValue - minValue) + minValue
                        }
                        .onEnded({ drag in
                            offsetLowBookmark = offsetLow
                        }))
                .offset(x: offsetLow, y: 0)
            rightHandle
                .gesture (
                    DragGesture (minimumDistance: 0.0, coordinateSpace: .global)
                        .onChanged { drag in
                            let positionPercent = Double((offsetHighBookmark + drag.translation.width) / maxWidth).clamped(to: upperHandleLowerBound...1.0)
                            highValue = positionPercent * (maxValue - minValue) + minValue
                        }
                        .onEnded({ drag in
                            offsetHighBookmark = min (maxWidth, offsetHigh)
                        }))
                .offset(x: offsetHigh, y: 0)
        }
    }
    
    init (
        selectedLow low: Binding<Double>,
        selectedHigh high: Binding<Double>,
        minimum min: Double,
        maximum max: Double,
        barFormatter: (inout BarStyle) -> () = { _ in },
        rightHandleFormatter: (inout HandleStyle) -> () = { _ in },
        leftHandleFormatter: (inout HandleStyle) -> () = { _ in })
    {
        _lowValue = low
        _highValue = high
        minValue = min
        maxValue = max
        barFormatter(&barStyle)
        rightHandle = RangeSliderHandle (
            high,
            handleFormatter: rightHandleFormatter
        )
        leftHandle = RangeSliderHandle (
            low,
            handleFormatter: leftHandleFormatter
        )
    }
}

extension RangeSlider {
    struct BarStyle {
        var barHeight: CGFloat = 4.0
        var barOutsideFill = Color.black.opacity(0.15)
        var barOutsideStrokeColor: Color = .clear
        var barOutsideStrokeWeight: CGFloat = 0.0
        var barInsideFill: Color = Color(UIColor.systemBlue)
        var barInsideStrokeColor = Color(UIColor.clear)
        var barInsideStrokeWeight: CGFloat = 0.0
        var minHandleSeparation: Double { //percent
            set {
                if newValue < 0.01 { _minHandleSeparation = 0.01
                } else if newValue > 0.99 {
                    _minHandleSeparation = 0.99
                } else {
                    _minHandleSeparation = newValue
                }
                
            }
            get {
                return _minHandleSeparation
            }
        }
        private var _minHandleSeparation: Double = 0.2
    }
    struct HandleStyle {
        private (set) var handleShape: AnyShape = Circle().eraseToAnyShape()
        private (set) var handleBackground: AnyView?
        var labelStyle: LabelStyle?
        var labelOffset: CGSize?
        var size: CGSize = CGSize(width: 30, height: 30)
        var shadowColor: Color = Color.black.opacity(0.15)
        var shadowRadius: CGFloat = 2.5
        var shadowOffset: CGSize = CGSize(width: 1.5, height: 1.5)
        var fill: Color = .white
        var strokeColor: Color = .clear
        var strokeWeight: CGFloat = 1.0
        mutating func setShape<S: Shape>(to shape: S) {
            handleShape = shape.eraseToAnyShape()
        }
        mutating func setBackground<V: View> (to view: V) {
            handleBackground = view.eraseToAnyView()
        }
    }
    
    struct LabelStyle {
        var color: Color = .black
        var background: Color = .clear
        var numberFormat = NumberFormatter()
        var labelFont: Font = .body
        var labelWeight: Font.Weight = .regular
        var isItalic: Bool = false
        var isBold: Bool = false
    }
}


struct Utilities_Previews: PreviewProvider {
    struct GlobalIndicatorHolder {
        static var sharedHouseData: SharedHouseData {
            let retVal = SharedHouseData.shared
            retVal.updateProgress = 0.5
            return retVal
        }
    }
    
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
            .environmentObject(GlobalIndicatorHolder.sharedHouseData)
    }
}

extension Binding {
    static func mock(_ value: Value) -> Self {
        var value = value
        return Binding(get: { value }, set: { value = $0 })
    }
}
