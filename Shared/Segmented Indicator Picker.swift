//
//  Segmented Indicator Picker.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/14/21.
//

import SwiftUI


struct SegmentedSpeedPicker: View {
    @Binding var segments: Int
    @Binding var highlightedSegment: Int?
    @Binding var highlightedSegmentAlarm: Bool
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
                            .font(.system(size: min(20, geo.size.width/CGFloat(cells) * 0.5)))
                            .minimumScaleFactor(0.5)
                            .padding(3)
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
                                .strokeBorder(lineWidth: 1.0)
                                .foregroundColor(
                                    highlightedSegmentAlarm ? Color(.alarm) : Color(.clear)
                                )
                                .background(RoundedRectangle(cornerRadius: cornerRadius)
                                    .inset(by: 3.0)
                                    .fill()
                                    .foregroundColor(Color(.systemBackground))
                                    .shadow(color: highlightedSegmentAlarm ? Color(.alarm) : Color(.black), radius: 0.75, x: 0.5, y: 0.5)
                                )
                                .frame(width: cellWidth)
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
                    guard let newTarget = newTarget, let highlightedSegment = highlightedSegment else {
                        indicatorOn = false
                        return
                    }
                    indicatorOn = newTarget != highlightedSegment
                    withAnimation(.easeInOut(duration: 0.5)) {
                        indicatorOffset = cellWidth * CGFloat (newTarget)
                    }
                }
                .onChange(of: highlightedSegment) { newHighlight in
                    guard let newHighlight = newHighlight, let indicatedSegment = indicatedSegment else {
                        indicatorOn = false
                        return
                    }
                    indicatorOn = indicatedSegment != newHighlight
                    withAnimation(.easeInOut(duration: 0.5)) {
                        highlightOffset = cellWidth * CGFloat (newHighlight)
                    }
                }
                .onAppear() {
                    highlightOffset = cellWidth * CGFloat (highlightedSegment ?? 0)
                    indicatorOffset = cellWidth * CGFloat (indicatedSegment ?? 0)
//                    indicatorOn.toggle()
                    guard let h = highlightedSegment, let t = indicatedSegment else {
                        indicatorOn = false
                        return
                    }
                    indicatorOn = t != h
                }
        }
        .frame(minWidth: 125, idealWidth: 300, maxWidth: 325, minHeight: 20, idealHeight: 30, maxHeight: 40)
    }
    
    init (
        segments: Binding<Int>,
        highlightedSegment: Binding<Int?>,
        highlightedAlarm: Binding<Bool> = .constant(false),
        indicatedSegment: Binding<Int?>,
        indicatorBlink: Binding<IndicatorOpacity.IndicatorBlink?>,
        minMaxLabels: PickerLabel.Appearance = .useStrings(["Min", "Max"]),
        middleLabels: PickerLabel.Appearance = .fillIntegerSequence) {
            self._segments = segments
            self._highlightedSegment = highlightedSegment
            self._highlightedSegmentAlarm = highlightedAlarm
            self._indicatedSegment = indicatedSegment
            self._indicatorBlink = indicatorBlink
            self.minMaxLabels = minMaxLabels
            self.middleLabels = middleLabels
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
            .onAppear(perform: {
                on = false
            })
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

struct Segmented_Indicator_Picker_Previews: PreviewProvider {
    static var previews: some View {
        SegmentedSpeedPicker(
            segments: .constant(5),
            highlightedSegment: .mock(1),
            highlightedAlarm: .constant(false),
            indicatedSegment: .mock(3),
            indicatorBlink: .mock(nil))
    }
}
