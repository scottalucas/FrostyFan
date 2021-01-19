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
    static var main = #colorLiteral(red: 0.2745098174, green: 0.4862745106, blue: 0.1411764771, alpha: 1)
    static var alarm = #colorLiteral(red: 0.6840745905, green: 0.0425841135, blue: 0.1318473293, alpha: 0.7751843718)
    static var background = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
}

extension Color {
    static var main = Color(UIColor.main)
    static var alarm = Color(UIColor.alarm)
    static var background = Color(UIColor.background)
}

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}


struct RefreshableScrollView<Content: View>: View {
    @State private var previousScrollOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var frozen: Bool = false
    @State private var rotation: Angle = .degrees(0)
    
    var threshold: CGFloat = 80
    @Binding var refreshing: Bool
    let content: Content

    init(height: CGFloat = 80, refreshing: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.threshold = height
        self._refreshing = refreshing
        self.content = content()

    }
    
    var body: some View {
        return VStack {
            ScrollView {
                ZStack(alignment: .top) {
                    MovingView()
                    
                    VStack { self.content }.alignmentGuide(.top, computeValue: { d in (self.refreshing && self.frozen) ? -self.threshold : 0.0 })
                    
                    SymbolView(height: self.threshold, loading: self.refreshing, frozen: self.frozen, rotation: self.rotation)
                }
            }
            .background(FixedView())
            .onPreferenceChange(RefreshableKeyTypes.PrefKey.self) { values in
                self.refreshLogic(values: values)
            }
        }
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
                    }.frame(height: height).fixedSize()
                        .offset(y: -height + (self.loading && self.frozen ? height : 0.0))
                } else {
                    Image(systemName: "arrow.down") // If not loading, show the arrow
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: height * 0.25, height: height * 0.25).fixedSize()
                        .padding(height * 0.375)
                        .rotationEffect(rotation)
                        .offset(y: -height + (loading && frozen ? +height : 0.0))
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

struct RangeSliderHandle: View {
    @Binding var handleSize: CGSize
    @State var fill: Color
    @State var strokeColor: Color
    @State var strokeLineWidth: CGFloat
    
    var body: some View {
        Circle ()
            .size(handleSize)
            .fill(fill)
            .overlay(Circle().size(handleSize).stroke(lineWidth: strokeLineWidth).foregroundColor(strokeColor))
            .frame(width: handleSize.width, height: handleSize.height, alignment: .center)
    }
}

struct RangeSlider: View {
    @State var lowSelected: CGFloat = 0
    @State var highSelected: CGFloat = 1
    @State var handleSize: CGSize = CGSize(width: 20.0, height: 20.0)
    @State var barHeight: CGFloat = 9.0
    var minTemp = 40
    var maxTemp = 85
    
    var body: some View {
        GeometryReader { geo in
            ZStack (alignment: Alignment(horizontal: .leading, vertical: .center)) {
                Group {
                    Rectangle()
                        .size(width: geo.size.width, height: barHeight)
                        .fill(Color.gray)
                    Rectangle ()
                        .size(width: geo.size.width * (highSelected - lowSelected), height: barHeight)
                        .fill(Color.main)
                        .offset(x: geo.size.width * lowSelected, y: 0)
                }
                .frame(width: nil, height: barHeight, alignment: .center)
                HStack (alignment: .center, spacing: geo.size.width * (highSelected - lowSelected) - handleSize.width)
                {
                    RangeSliderHandle(handleSize: $handleSize, fill: .clear, strokeColor: .blue, strokeLineWidth: 1.0)
                        .gesture(
                            DragGesture (minimumDistance: 0.0, coordinateSpace: .global)
                                .onChanged { drag in
                                    let width = geo.frame(in: .local).width
                                    self.lowSelected = max(0, min(drag.location.x / width, 0.85))
                                    if self.highSelected < (lowSelected + 0.15) { self.highSelected = drag.location.x / width + 0.15 }
                                })
                    RangeSliderHandle(handleSize: $handleSize, fill: .clear, strokeColor: .red, strokeLineWidth: 1.0)
                        .gesture (
                            DragGesture (minimumDistance: 0.0, coordinateSpace: .global)
                                .onChanged { drag in
                                    let width = geo.frame(in: .local).width
                                    self.highSelected = min(max(drag.location.x / width, 0.15), 1)
                                    if self.lowSelected > (highSelected - 0.15) { lowSelected = drag.location.x / width - 0.15}
                                })
                }
                .frame(width: geo.size.width * (highSelected - lowSelected) + handleSize.height, height: nil, alignment: .center)
                .offset(x: geo.size.width * lowSelected - handleSize.width / 2, y: 0)
            }
            .frame(width: nil, height: handleSize.width)
            Text("\(lowSelected)")
                .offset(x: 0, y: 60)
        }
        .padding([.leading, .trailing], handleSize.width / 2)
    }
}

struct Utilities_Previews: PreviewProvider {
//        @ObservedObject var slider = CustomSlider(start: 10, end: 100)

    
    static var previews: some View {
        HStack {
            Spacer()
            VStack {
                Image.fanLarge
                RangeSlider()
                Spacer()
                Spacer()
                Image.fanIcon
                Image.interlock
                Image.leaf
                Image.network
                Image.question
                Image.bell
//                Image.flame
            }
            Spacer ()
            VStack {
                Spacer ()
                Image.settings
                Image.speed
                Image.thermometer
                Image.timer
                Image.rainDrops
                Color.main
                    .frame(width: 25, height: 25, alignment: .center)
            }
            Spacer()
        }
    }
}
