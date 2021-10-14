//
//  Utilities.swift
//  whf001
//
//  Created by Scott Lucas on 12/10/20.
//

import Foundation
import SwiftUI
import Combine

extension Image {
    static var fanLarge = Image("fanLarge")
    static var fanIcon = Image("fanIcon")
    static var flame = Image(systemName: "flame.fill")
    static var interlock = Image(systemName: "wind")
    static var leaf = Image(systemName: "leaf.arrow.circlepath")
    static var network = Image(systemName: "link")
    static var question = Image(systemName: "questionmark")
    static var settings = Image(systemName: "gear")
    static var speed = Image(systemName: "speedometer")
    static var thermometer = Image(systemName: "thermometer")
    static var timer = Image(systemName: "timer")
    static var rainDrops =  Image(systemName: "cloud.sun")
    static var bell = Image(systemName: "bell")
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

struct RefreshableScrollView<Content: View>: View {
    @State private var previousScrollOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var frozen: Bool = true
    @State private var rotation: Angle = .degrees(0)
    @Binding var refreshing: Bool
    
    var threshold: CGFloat
    let content: Content

    init(height: CGFloat = 50, refreshing: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.threshold = height
        self._refreshing = refreshing
        self.content = content()

    }
    
    var body: some View {
        return
//            VStack {
            GeometryReader { geo in
                ScrollView {
                    ZStack(alignment: .top) {
                        MovingView()
                        self.content
                            .frame(minHeight: geo.frame(in: .global).height)
                            .alignmentGuide(.top, computeValue: { d in (self.refreshing && self.frozen) ? -self.threshold : 0.0 })
                            .ignoresSafeArea()
                        SymbolView(scrollOffset: $scrollOffset, height: self.threshold, loading: self.refreshing, frozen: self.frozen, rotation: self.rotation)
                    }
                }
                .background(FixedView())
                .onPreferenceChange(RefreshableKeyTypes.PrefKey.self) { values in
                    self.refreshLogic(values: values)
                }
                
            }
//        }
    }
    
    func refreshLogic(values: [RefreshableKeyTypes.PrefData]) {
        DispatchQueue.main.async {
            // Calculate scroll offset
            let movingBounds = values.first { $0.vType == .movingView }?.bounds ?? .zero
            let fixedBounds = values.first { $0.vType == .fixedView }?.bounds ?? .zero
            
            self.scrollOffset  = movingBounds.minY - fixedBounds.minY
            
            self.rotation = self.symbolRotation(self.scrollOffset)
            
            // Crossing the threshold on the way down, we start the refresh process
            if !self.refreshing && (self.scrollOffset > self.threshold && self.previousScrollOffset <= self.threshold) {
                self.refreshing = true
            }
            
            if self.refreshing {
                // Crossing the threshold on the way up, we add a space at the top of the scrollview
                if self.previousScrollOffset > self.threshold && self.scrollOffset <= self.threshold {
                    self.frozen = true

                }
            } else {
                // remove the sapce at the top of the scroll view
                self.frozen = false
            }
            
            // Update last scroll offset
            self.previousScrollOffset = self.scrollOffset
        }
    }
    
    func symbolRotation(_ scrollOffset: CGFloat) -> Angle {
        
        // We will begin rotation, only after we have passed
        // 60% of the way of reaching the threshold.
        if scrollOffset < self.threshold * 0.60 {
            return .degrees(0)
        } else {
            // Calculate rotation, based on the amount of scroll offset
            let h = Double(self.threshold)
            let d = Double(scrollOffset)
            let v = max(min(d - (h * 0.6), h * 0.4), 0)
            return .degrees(180 * v / (h * 0.4))
        }
    }
    
    struct SymbolView: View {
        @Binding var scrollOffset: CGFloat
        var height: CGFloat
        var loading: Bool
        var frozen: Bool
        var rotation: Angle
        
        
        var body: some View {
            Group {
                if self.loading { // If loading, show the activity control
                    VStack {
                        Spacer()
                        ActivityRep()
                        Spacer()
                    }
                    .frame(height: height)
                    .fixedSize()
                    .offset(y: (self.loading && self.frozen) ? 0.0 : height)
//                    .offset(y: height - (self.loading && self.frozen) ? height : 0.0)
                } else {
                    Image(systemName: "arrow.down") // If not loading, show the arrow
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: scrollOffset > 0 ? height * 0.5 : 0, height: scrollOffset > 0 ? height * 0.5 : 0)
                        .fixedSize()
                        .padding(height * 0.375)
                        .rotationEffect(rotation)
                        .offset(y: -height + (loading && frozen ? height : 0.0))
                        .foregroundColor(.main)
                }
            }
        }
    }
    
    struct MovingView: View {
        var body: some View {
            GeometryReader { proxy in
                Color.clear.preference(key: RefreshableKeyTypes.PrefKey.self, value: [RefreshableKeyTypes.PrefData(vType: .movingView, bounds: proxy.frame(in: .global))])
            }.frame(height: 0)
        }
    }
    
    struct FixedView: View {
        var body: some View {
            GeometryReader { proxy in
                Color.clear.preference(key: RefreshableKeyTypes.PrefKey.self, value: [RefreshableKeyTypes.PrefData(vType: .fixedView, bounds: proxy.frame(in: .global))])
            }
        }
    }
}

struct RefreshableKeyTypes {
    enum ViewType: Int {
        case movingView
        case fixedView
    }

    struct PrefData: Equatable {
        let vType: ViewType
        let bounds: CGRect
    }

    struct PrefKey: PreferenceKey {
        static var defaultValue: [PrefData] = []

        static func reduce(value: inout [PrefData], nextValue: () -> [PrefData]) {
            value.append(contentsOf: nextValue())
        }

        typealias Value = [PrefData]
    }
}

struct ActivityRep: UIViewRepresentable {
    func makeUIView(context: UIViewRepresentableContext<ActivityRep>) -> UIActivityIndicatorView {
        return UIActivityIndicatorView()
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityRep>) {
        uiView.startAnimating()
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

struct TargetSegmentedPicker: View {
    @Binding var segments: Int
    @Binding var highlightedSegment: Int
    @Binding var targetedSegment: Int
    @Binding var indicatorPulse: TargetAlarmIndicator?
    @State private var targetedSegmentIndicatorOn: Bool = false
    @State private var targetSegmentOffset: CGFloat = 0
//    @State private var indicatorCase: String = "init"
    
    enum TargetAlarmIndicator {
        case fastBlink, slowBlink
        var description: String {
            switch self {
                case .fastBlink:
                    return "fast"
                case .slowBlink:
                    return "slow"
            }
        }
    }
    
    struct IndicatorOn: View {
        @State private var opacity: CGFloat = 0.0
        var body: some View {
            Image(systemName: "triangle.fill")
                .resizable()
                .opacity(opacity)
                .onAppear(perform: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        opacity = 1.0
                    }
                })
        }
    }
    
    struct IndicatorOff: View {
        @State private var opacity: CGFloat = 1.0
        var body: some View {
            Image(systemName: "triangle.fill")
                .resizable()
                .opacity(opacity)
                .onAppear(perform: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        opacity = 0.0
                    }
                })
        }
    }
    
    struct IndicatorFastBlink: View {
        @State private var opacity: CGFloat = 0.0
        var body: some View {
            Image(systemName: "triangle.fill")
                .resizable()
                .opacity(opacity)
                .onAppear(perform: {
                    withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
                        opacity = 1.0
                    }
                })
        }
    }

    struct IndicatorSlowBlink: View {
        @State private var opacity: CGFloat = 0.0
        var body: some View {
            Image(systemName: "triangle.fill")
                .resizable()
                .opacity(opacity)
                .onAppear(perform: {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        opacity = 1.0
                    }
                })
        }
    }
    
    struct PickerLabel: View, Identifiable {
        
        var id: Int
        var labelText: String
        var highlighted: Bool
        var visibleSeparator: Bool
        var segments: Int
        var separatorPaddingFactor: CGFloat
        var body: some View {
            GeometryReader { geo in
                let h = min(geo.size.height, 40)
                RoundedRectangle(cornerRadius: h * 0.3)
                    .inset(by: 3.0)
                    .foregroundColor( highlighted ? Color(UIColor.systemBackground) : Color.clear)
                    .shadow(color: highlighted ? .black : .clear, radius: 0.75, x: 0.5, y: 0.5)
                    .overlay(
                        VerticalLine()
                            .stroke(visibleSeparator ? .gray.opacity(0.5) : .clear)
                            .padding([.bottom, .top], h * separatorPaddingFactor)
                    )
                    .overlay(
                        Text(labelText)
                            .font(.system(size: h * 0.5))
                    )
                    .frame(width: geo.size.width/CGFloat(segments), height: h)
            }
        }
    }
    
    private var labelArray: Array<PickerLabel> {
        guard segments >= 2 else { return [] }
        highlightedSegment = min(highlightedSegment, segments - 1)
        targetedSegment = min(targetedSegment, segments - 1)
        var nums = segments <= 2 ? [] : (1...(segments - 2)).map{ String($0) }
        nums.append("Max")
        nums.insert("Off", at: 0)
        return nums.enumerated().map { (index, value) in PickerLabel (id: index, labelText: value, highlighted: index == highlightedSegment, visibleSeparator: ![0, highlightedSegment, highlightedSegment + 1].contains(index), segments: segments, separatorPaddingFactor: 0.1) }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = (20...40) ~= geo.size.height ? geo.size.height : 30
            let cornerRadius = height * 0.3
            let cellWidth = width / CGFloat(segments)
            RoundedRectangle(cornerRadius: cornerRadius)
                .foregroundColor(Color(UIColor.controlsBackground))
                .overlay (
                    ForEach ( labelArray ) { label in
                        label
                            .onTapGesture(perform: {
                                targetedSegment = label.id
                            })
                            .offset(x: cellWidth * CGFloat(label.id), y: 0)
                    }
                )
                .overlay (
                    VStack {
                        if (targetedSegmentIndicatorOn && indicatorPulse == nil) {
                            IndicatorOn()
                        } else if (targetedSegmentIndicatorOn && indicatorPulse == .fastBlink) {
                            IndicatorFastBlink()
                        } else if (targetedSegmentIndicatorOn && indicatorPulse == .slowBlink) {
                            IndicatorSlowBlink()
                        } else if (!targetedSegmentIndicatorOn) {
                            IndicatorOff()
                        } else {
                            EmptyView()
                        }
                    }
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(x: 0.5, y: 0.5, anchor: .bottom)
                        .offset(x: targetSegmentOffset, y: height/3)
                        .foregroundColor(.controlsTint)
                        .alignmentGuide(HorizontalAlignment.leading) { boxDim in
                            (boxDim.width - cellWidth)/2
                        }
                       , alignment: .leading)
            
//                .overlay(
//                    Text(String("Highlighted segment: \(highlightedSegment)"))
//                        .contentShape(Rectangle())
//                        .onTapGesture(perform: {
//                            highlightedSegment = (highlightedSegment + 1)%segments
//                        })
//                        .offset(x: 0, y: 40)
//                )
//                .overlay(
//                    Text(String("Speed: \(indicatorPulse == nil ? "nil" : indicatorPulse!.description)"))
//                        .contentShape(Rectangle())
//                        .onTapGesture(perform: {
//                            let pulses: [TargetAlarmIndicator?] = [nil, .fastBlink, .slowBlink]
//                            let index: Int = ((pulses.firstIndex(where: { $0 == indicatorPulse }) ?? 0) + 1)%3
//                            indicatorPulse = pulses[index] == nil ? nil : pulses[index]!
//                        })
//                        .offset(x: 0, y: 80)
//                )
//                .overlay(
//                    Text(String("State: \(indicatorCase)"))
//                        .contentShape(Rectangle())
//                        .offset(x: 0, y: 120)
//                )
                .frame(height: min(geo.size.height, 40))
                .onChange(of: targetedSegment) { newTarget in
                    targetedSegmentIndicatorOn = targetedSegment != highlightedSegment
                    withAnimation(.easeInOut(duration: 0.5)) {
                        targetSegmentOffset = cellWidth * CGFloat (newTarget)
                    }
                }
                .onChange(of: highlightedSegment) { _ in
                    targetedSegmentIndicatorOn = targetedSegment != highlightedSegment
                }
                .onAppear() {
                    targetedSegmentIndicatorOn.toggle()
                    targetedSegmentIndicatorOn = targetedSegment != highlightedSegment
                    targetSegmentOffset = cellWidth * CGFloat (targetedSegment)
                }
        }
    }
}

struct VerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
        }
    }
}

struct Utilities_Previews: PreviewProvider {
    
    struct BindingTestHolder: View {
        @State var segments: Int = 8
        @State var highlighted: Int = 2
        @State var targeted: Int = 0
        @State var pulse: TargetSegmentedPicker.TargetAlarmIndicator? = nil
        var body: some View {
            TargetSegmentedPicker(segments: $segments, highlightedSegment: $highlighted, targetedSegment: $targeted, indicatorPulse: $pulse)
        }
    }

    static var previews: some View {
        if #available(iOS 15.0, *) {
            BindingTestHolder()
                .preferredColorScheme(.dark)
                .previewInterfaceOrientation(.landscapeLeft)
        } else {
            // Fallback on earlier versions
        }
    }
}

extension Binding {
    static func mock(_ value: Value) -> Self {
        var value = value
        return Binding(get: { value }, set: { value = $0 })
    }
}
