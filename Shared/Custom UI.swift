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

//SliderValue to restrict double range: 0.0 to 1.0
@propertyWrapper
struct SliderValue {
    var value: Double
    
    init(wrappedValue: Double) {
        self.value = wrappedValue
    }
    
    var wrappedValue: Double {
        get { value }
        set { value = min(max(0.0, newValue), 1.0) }
    }
}

class SliderHandle: ObservableObject {
    
    //Slider Size
    let sliderWidth: CGFloat
    let sliderHeight: CGFloat
    
    //Slider Range
    let sliderValueStart: Double
    let sliderValueRange: Double
    
    //Slider Handle
    var diameter: CGFloat = 30
    var startLocation: CGPoint
    
    //Current Value
    @Published var currentPercentage: SliderValue
    
    //Slider Button Location
    @Published var onDrag: Bool
    @Published var currentLocation: CGPoint
        
    init(sliderWidth: CGFloat, sliderHeight: CGFloat, sliderValueStart: Double, sliderValueEnd: Double, startPercentage: SliderValue) {
        self.sliderWidth = sliderWidth
        self.sliderHeight = sliderHeight
        
        self.sliderValueStart = sliderValueStart
        self.sliderValueRange = sliderValueEnd - sliderValueStart
        
        let startLocation = CGPoint(x: (CGFloat(startPercentage.wrappedValue)/1.0)*sliderWidth, y: sliderHeight/2)
        
        self.startLocation = startLocation
        self.currentLocation = startLocation
        self.currentPercentage = startPercentage
        
        self.onDrag = false
    }
    
    lazy var sliderDragGesture: _EndedGesture<_ChangedGesture<DragGesture>>  = DragGesture()
        .onChanged { value in
            self.onDrag = true
            
            let dragLocation = value.location
            
            //Restrict possible drag area
            self.restrictSliderBtnLocation(dragLocation)
            
            //Get current value
            self.currentPercentage.wrappedValue = Double(self.currentLocation.x / self.sliderWidth)
            
        }.onEnded { _ in
            self.onDrag = false
        }
    
    private func restrictSliderBtnLocation(_ dragLocation: CGPoint) {
        //On Slider Width
        if dragLocation.x > CGPoint.zero.x && dragLocation.x < sliderWidth {
            calcSliderBtnLocation(dragLocation)
        }
    }
    
    private func calcSliderBtnLocation(_ dragLocation: CGPoint) {
        if dragLocation.y != sliderHeight/2 {
            currentLocation = CGPoint(x: dragLocation.x, y: sliderHeight/2)
        } else {
            currentLocation = dragLocation
        }
    }
    
    //Current Value
    var currentValue: Double {
        return sliderValueStart + currentPercentage.wrappedValue * sliderValueRange
    }
}

class CustomSlider: ObservableObject {
    
    //Slider Size
    final let width: CGFloat = 300
    final let lineWidth: CGFloat = 8
    
    //Slider value range from valueStart to valueEnd
    final let valueStart: Double
    final let valueEnd: Double
    
    //Slider Handle
    @Published var highHandle: SliderHandle
    @Published var lowHandle: SliderHandle
    
    //Handle start percentage (also for starting point)
    @SliderValue var highHandleStartPercentage = 1.0
    @SliderValue var lowHandleStartPercentage = 0.0

    final var anyCancellableHigh: AnyCancellable?
    final var anyCancellableLow: AnyCancellable?
    private var bag = Set<AnyCancellable>()
    
    init(start: Double, end: Double, initHigh: Double, initLow: Double) {
        valueStart = start
        valueEnd = end
        highHandleStartPercentage = initHigh / (end - start)
        lowHandleStartPercentage = initLow / (end - start)
        
        highHandle = SliderHandle(sliderWidth: width,
                                  sliderHeight: lineWidth,
                                  sliderValueStart: valueStart,
                                  sliderValueEnd: valueEnd,
                                  startPercentage: _highHandleStartPercentage
                                )
        
        lowHandle = SliderHandle(sliderWidth: width,
                                  sliderHeight: lineWidth,
                                  sliderValueStart: valueStart,
                                  sliderValueEnd: valueEnd,
                                  startPercentage: _lowHandleStartPercentage
                                )
        
        anyCancellableHigh = highHandle.objectWillChange.sink { [lowHandle, highHandle] _ in
            guard highHandle.currentPercentage.wrappedValue - lowHandle.currentPercentage.wrappedValue > 0.15 else {
                print ("range high")
                
                return
            }
            self.objectWillChange.send()
        }
        
        anyCancellableLow = lowHandle.objectWillChange.sink { [lowHandle, highHandle] _ in
            guard highHandle.currentPercentage.wrappedValue - lowHandle.currentPercentage.wrappedValue > 0.15 else {
                print ("range low")
                return
            }
            self.objectWillChange.send()
        }
        
//        $highHandle
//            .map { $0.currentPercentage }
//            .combineLatest($lowHandle.map { $0.currentPercentage })
//            .sink(receiveValue: { [highHandle] (highP, lowP) in
//                if highP.wrappedValue < lowP.wrappedValue {
//                    highHandle.currentPercentage = SliderValue(wrappedValue: lowP.wrappedValue + 0.1)
//                }
//
//            })
//            .store(in: &bag)
        
    }
    
    //Percentages between high and low handle
    var percentagesBetween: String {
        return String(format: "%.2f", highHandle.currentPercentage.wrappedValue - lowHandle.currentPercentage.wrappedValue)
    }
    
    //Value between high and low handle
    var valueBetween: String {
        return String(format: "%.2f", highHandle.currentValue - lowHandle.currentValue)
    }
}
//
//struct ContentView: View {
//    @ObservedObject var slider = CustomSlider(start: 10, end: 100)
//
//    var body: some View {
//        VStack {
//            Text("Value: " + slider.valueBetween)
//            Text("Percentages: " + slider.percentagesBetween)
//
//            Text("High Value: \(slider.highHandle.currentValue)")
//            Text("Low Value: \(slider.lowHandle.currentValue)")
//
//            //Slider
//            SliderView(slider: slider)
//        }
//    }
//}

struct SliderView: View {
    @ObservedObject var slider: CustomSlider
    
    var body: some View {
        RoundedRectangle(cornerRadius: slider.lineWidth)
            .fill(Color.gray.opacity(0.2))
            .frame(width: slider.width, height: slider.lineWidth)
            .overlay(
                ZStack {
                    //Path between both handles
                    SliderPathBetweenView(slider: slider)
                    
                    //Low Handle
                    SliderHandleView(handle: slider.lowHandle)
                        .highPriorityGesture(slider.lowHandle.sliderDragGesture)
                    
                    //High Handle
                    SliderHandleView(handle: slider.highHandle)
                        .highPriorityGesture(slider.highHandle.sliderDragGesture)
                }
            )
    }
}

struct SliderHandleView: View {
    @ObservedObject var handle: SliderHandle
    
    var body: some View {
        Circle()
            .frame(width: handle.diameter, height: handle.diameter)
            .foregroundColor(.white)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 0)
            .scaleEffect(handle.onDrag ? 1.3 : 1)
            .contentShape(Rectangle())
            .position(x: handle.currentLocation.x, y: handle.currentLocation.y)
    }
}

struct SliderPathBetweenView: View {
    @ObservedObject var slider: CustomSlider
    
    var body: some View {
        Path { path in
            path.move(to: slider.lowHandle.currentLocation)
            path.addLine(to: slider.highHandle.currentLocation)
        }
        .stroke(Color.main, lineWidth: slider.lineWidth)
    }
}

struct Utilities_Previews: PreviewProvider {
//        @ObservedObject var slider = CustomSlider(start: 10, end: 100)

    
    static var previews: some View {
        HStack {
            Spacer()
//            SliderView(slider: slider)
            VStack {
                Image.fanLarge
                Spacer()
//                SliderView(slider: slider)
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
