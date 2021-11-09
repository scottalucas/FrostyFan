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
                defer { data.timerWheelPosition = 0 }
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

struct SegmentedSpeedPicker: View {
    @Binding var segments: Int
    @Binding var highlightedSegment: Int?
    @Binding var indicatedSegment: Int?
    @Binding var indicatorBlink: IndicatorOpacity.IndicatorBlink?
    @State private var indicatorOn: Bool = false
    @State private var indicatorOffset: CGFloat = 0
    @State private var highlightOffset: CGFloat = 0
    var minMaxLabels: PickerLabel.Appearance
    var middleLabels: PickerLabel.Appearance

    struct PickerLabel: View, Identifiable {
        var id: Int
        var labelView: AnyView
        var highlighted: Bool
        var visibleSeparator: Bool
        var cells: Int
        var separatorPaddingFactor: CGFloat
        var body: some View {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: geo.size.height * 0.3)
                    .inset(by: 3.0)
                    .foregroundColor( Color(UIColor.clear) )
                    .overlay(
                        VerticalLine()
                            .stroke(visibleSeparator ? Color.gray.opacity(0.5) : Color.clear)
                            .padding([.bottom, .top], geo.size.height * separatorPaddingFactor)
                    )
                    .overlay(
                        labelView
                            .font(.system(size: geo.size.height * 0.4))
                            .foregroundColor(.segmentControllerText)
                    )
                    .frame(width: geo.size.width/CGFloat(cells))
            }
        }
        enum Appearance {
            case useStrings(Array<String>), useImages(Array<Image>), fillIntegerSequence
        }
    }
    
    private var labelArray: Array<PickerLabel> {
        guard segments > 1 else { return [] }
        var labelViews = Array<AnyView>()
        
        switch minMaxLabels {
            case .useImages(let i):
                let image = i.first ?? Image(uiImage: UIImage(systemName: "circle")!)
                labelViews = [image.eraseToAnyView()]
            case .useStrings(let s):
                let string = s.first ?? "Min"
                labelViews = [Text(string).eraseToAnyView()]
            case .fillIntegerSequence:
                labelViews = [Text("0").eraseToAnyView()]
        }
        
        switch middleLabels {
            case .fillIntegerSequence:
                labelViews.append(contentsOf: (1..<segments - 1).map { Text(String($0)).eraseToAnyView() })
            case .useImages(let i):
                let finalMiddleLabels: Array<AnyView> = Array<AnyView>.init(repeating: Image(uiImage: UIImage(systemName: "circle")!).eraseToAnyView(), count: segments - 2)
                    .enumerated()
                    .map { (index, view) in
                        guard i.indices.contains(index) else { return view }
                        return i[index].eraseToAnyView()
                    }
                labelViews.append(contentsOf: finalMiddleLabels)
            case .useStrings(let s):
                let finalMiddleLabels: Array<AnyView> = Array<AnyView>.init(repeating: Text("•").eraseToAnyView(), count: segments - 2)
                    .enumerated()
                    .map { (index, view) in
                        guard s.indices.contains(index) else { return view }
                        return Text(s[index]).eraseToAnyView()
                    }
                labelViews.append(contentsOf: finalMiddleLabels)
                break
        }
        
        switch minMaxLabels {
            case .useImages(let i):
                labelViews.append((i.last ?? Image(uiImage: UIImage(systemName: "circle")!)).eraseToAnyView())
            case .useStrings(let s):
                labelViews.append(Text(s.last ?? "Max").eraseToAnyView())
            case .fillIntegerSequence:
                labelViews.append(Text(String(segments - 1)).eraseToAnyView())
        }
        
        var retVal = Array<PickerLabel>()

        labelViews.enumerated().forEach { (i, val) in
            let highlighted: Bool
            let separator: Bool
            switch (i, highlightedSegment) {
                case (0, nil):
                    highlighted = false
                    separator = false
                case (0,0):
                    highlighted = true
                    separator = false
                case (let i, .some(let h)) where i == h:
                    highlighted = true //t
                    separator = false
                case (let i, .some(let h)) where i == h + 1:
                    highlighted = false
                    separator = false
                case (let i, _) where i == 0:
                    highlighted = false
                    separator = false
                default:
                    highlighted = false
                    separator = true
            }
            retVal.append(PickerLabel(id: i, labelView: labelViews[i], highlighted: highlighted, visibleSeparator: separator, cells: segments, separatorPaddingFactor: 0.1))
        }
        return retVal
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let cornerRadius = geo.size.height * 0.3
            let cellWidth = width / CGFloat(segments)
            RoundedRectangle(cornerRadius: cornerRadius)
                .foregroundColor(.segmentControllerBackground)
                .overlay (
                    VStack {
                        if highlightedSegment == nil {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .foregroundColor(Color.clear)
                        } else {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .inset(by: 3.0)
                                .frame(width: cellWidth)
                                .foregroundColor( Color(UIColor.systemBackground) )
                                .shadow(color: .black, radius: 0.75, x: 0.5, y: 0.5)
                                .offset(x: highlightOffset, y: 0)
                        }
                    }
                    , alignment: .leading
                )
                .overlay (
                    ForEach ( labelArray ) { label in
                        label
                            .onTapGesture(perform: {
                                indicatedSegment = label.id
                            })
                            .offset(x: cellWidth * CGFloat(label.id), y: 0)
                    }
                )
                .overlay (
                    Image(systemName: "triangle.fill")
                        .resizable()
                        .modifier(IndicatorOpacity(on: $indicatorOn, blink: $indicatorBlink))
                        .aspectRatio(1.0, contentMode: .fit)
                        .scaleEffect(x: 0.5, y: 0.5, anchor: .center)
                        .offset(x: indicatorOffset)
                        .foregroundColor(.controlsTint)
                        .alignmentGuide(HorizontalAlignment.leading) { boxDim in
                            (boxDim.width - cellWidth)/2
                        }
                        .alignmentGuide(VerticalAlignment.top) { boxDim in
                            -(boxDim.height/2)
                        }
                    , alignment: .topLeading)
                .onChange(of: indicatedSegment) { newTarget in
                    guard let newTarget = newTarget else {
                        indicatorOn = false
                        return
                    }
                    indicatorOn = indicatedSegment != highlightedSegment
                    withAnimation(.easeInOut(duration: 0.5)) {
                        indicatorOffset = cellWidth * CGFloat (newTarget)
                    }
                }
                .onChange(of: highlightedSegment) { newHighlight in
                    guard let newHighlight = newHighlight else {
                        indicatorOn = false
                        return
                    }
                    indicatorOn = indicatedSegment != highlightedSegment
                    withAnimation(.easeInOut(duration: 0.5)) {
                        highlightOffset = cellWidth * CGFloat (newHighlight)
                    }
                }
                .onAppear() {
                    highlightOffset = cellWidth * CGFloat (highlightedSegment ?? 0)
                    indicatorOffset = cellWidth * CGFloat (indicatedSegment ?? 0)
                    if let h = highlightedSegment, let t = indicatedSegment {
                        indicatorOn.toggle()
                        indicatorOn = t == h ? false : true
                    }
                }
        }
        .frame(minWidth: 125, idealWidth: 300, maxWidth: 325, minHeight: 20, idealHeight: 30, maxHeight: 40)
    }
    
    init (
        segments: Binding<Int>,
        highlightedSegment: Binding<Int?>,
        indicatedSegment: Binding<Int?>,
        indicatorBlink: Binding<IndicatorOpacity.IndicatorBlink?>,
        minMaxLabels: PickerLabel.Appearance = .useStrings(["Min", "Max"]),
        middleLabels: PickerLabel.Appearance = .fillIntegerSequence) {
            self._segments = segments
            self._highlightedSegment = highlightedSegment
            self._indicatedSegment = indicatedSegment
            self._indicatorBlink = indicatorBlink
            self.minMaxLabels = minMaxLabels
            self.middleLabels = middleLabels
        }
}

struct PulldownRefresh: ViewModifier {
//    @EnvironmentObject private var houseViewModel: HouseViewModel
    @Environment (\.updateProgress) var updateProgress
    @GestureState private var dragSize = CGSize.zero
    @State private var verticalOffset: Double = .zero
//    @State private var refreshing = false
    private var spinnerAlignment: Alignment
    private var complete: () -> Void
    
    func body(content: Content) -> some View {
        return VStack (alignment: .center, spacing: 0)
        {
            if let update = updateProgress {
                ProgressView(value: update)
//                    .padding()
            }
            content
            .offset(x: 0, y: verticalOffset)
            .gesture(DragGesture().onChanged { value in
                guard updateProgress == nil else { return }
                let verticalTranslation = max(0, value.location.y - value.startLocation.y)
//                verticalOffset = 75 * (verticalTranslation)/(verticalTranslation + 75)
                verticalOffset = verticalTranslation
                if verticalTranslation >= 75 {
                    complete()
                    let thump = UIImpactFeedbackGenerator(style: .rigid)
                    thump.impactOccurred()
                    withAnimation {
                        verticalOffset = .zero
                    }
                }
            })
        }
//            .overlay(alignment: spinnerAlignment) {
//            }
    }
    init(spinnerAlignment align: Alignment = .top, _ complete: @escaping () -> Void) {
        spinnerAlignment = align
        self.complete = complete
    }
}

extension View {
    func pulldownRefresh (spinnerAlignment: Alignment = .top, complete: @escaping () -> Void) -> some View {
        modifier(PulldownRefresh(spinnerAlignment: spinnerAlignment, complete))
    }
}

struct IndicatorOpacity: ViewModifier {
    
    enum IndicatorBlink: Double {
        case fastBlink = 0.25, slowBlink = 1.25
        var animation: Animation {
            switch self {
                case .fastBlink:
                    return .linear(duration: rawValue).repeatForever(autoreverses: true)
                case .slowBlink:
                    return .linear(duration: rawValue).repeatForever(autoreverses: true)
            }
        }
        var description: String {
            switch self {
                case .fastBlink:
                    return "fast"
                case .slowBlink:
                    return "slow"
            }
        }
    }

    @Binding var on: Bool
    @Binding var blink: IndicatorBlink?
    @State private var opacity: Double = 0.0
    
    private func recalc(on: Bool, blink: IndicatorBlink?) -> (endOpacity: Double, animation: Animation) {
        switch (on, blink) {
            case (false, _):
                return (0.0, Animation.linear(duration: 0.5))
            case (_, .some(let rate)):
                return (1.0, rate.animation)
            case (_, nil):
                return (1.0, .linear(duration: 0.5))
        }
    }
    
    func body(content: Content) -> some View {
        return content
            .opacity(opacity)
            .onChange(of: blink) { newBlink in
                guard on else { return }
                let (finalOpacity, animation) = recalc(on: on, blink: newBlink)
                withAnimation(.linear(duration: 0)) {
                    opacity = 1 - finalOpacity
                }

                withAnimation(animation) {
                    opacity = finalOpacity
                }
            }
            .onChange(of: on) { newOn in
                let (finalOpacity, animation) = recalc(on: newOn, blink: blink)
                withAnimation(.linear(duration: 0)) {
                    opacity = 1 - finalOpacity
                }
                withAnimation(animation) {
                    opacity = finalOpacity
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
            .pulldownRefresh() { }
            .environmentObject(HouseViewModel())
    }
}

extension Binding {
    static func mock(_ value: Value) -> Self {
        var value = value
        return Binding(get: { value }, set: { value = $0 })
    }
}
