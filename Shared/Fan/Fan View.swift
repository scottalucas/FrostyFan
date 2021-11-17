//
//  Fan View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

enum OverlaySheet: String, Identifiable {
    var id: String { self.rawValue }
    case fanName
    case timer
    case detail
    case fatalFault
}

struct FanView: View {
    typealias MACAddr = String
    let id: MACAddr
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var sharedHouseData: SharedHouseData
    @StateObject var viewModel: FanViewModel
    @AppStorage var name: String
    @GestureState var viewOffset = CGSize.zero
    
    @State var pullDownOffset = CGFloat.zero
    @State private var angle = Angle.zero
    @State private var activeSheet: OverlaySheet?
    
    var body: some View {
        ZStack {
            FanImageRender(angle: $angle, activeSheet: $activeSheet, viewModel: viewModel)
            ControllerRender(viewModel: viewModel, activeSheet: $activeSheet)
                .padding(.bottom, 45)
            FanNameRender(activeSheet: $activeSheet, name: $name, showDamperWarning: $viewModel.showDamperWarning, showInterlockWarning: $viewModel.showInterlockWarning)
        }
        .overlaySheet(dataSource: viewModel, activeSheet: $activeSheet)
        .onReceive(viewModel.$fanRotationDuration) { val in
            self.angle = .zero
            withAnimation(Animation.linear(duration: val)) {
                self.angle = .degrees(179.99)
            }
        }
        .onChange(of: viewModel.fatalFault) { fault in
            guard fault else { return }
            activeSheet = .fatalFault
        }
        .onAppear {
            viewModel.refreshFan()
        }
    }
    
    init (initialCharacteristics chars: FanCharacteristics) {
        id = chars.macAddr
        _name = AppStorage(wrappedValue: "\(chars.airspaceFanModel)", StorageKey.fanName(chars.macAddr).key)
        _viewModel = StateObject.init(wrappedValue: FanViewModel(chars: chars))
        print("init fan view model \(chars.airspaceFanModel) selector segments \(viewModel.selectorSegments)")
    }
}

struct SpeedController: View {
    @ObservedObject var viewModel: FanViewModel
    @State var requestedSpeed: Int?
    var body: some View {
        SegmentedSpeedPicker(
            segments: $viewModel.selectorSegments,
            highlightedSegment: $viewModel.currentMotorSpeed,
            indicatedSegment: $requestedSpeed,
            indicatorBlink: $viewModel.indicatedAlarm)
            .onChange(of: requestedSpeed) { speed in
                viewModel.setSpeed(to: speed)
            }
    }
}

struct ControllerRender: View {
    var viewModel: FanViewModel
    @Binding var activeSheet: OverlaySheet?
    var body: some View {
        VStack {
            Spacer()
            if viewModel.showTimerIcon {
                VStack {
                    Button(
                        action: {
                            activeSheet = .timer
                        }, label: {
                            VStack {
                                IdentifiableImage.timer.image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: nil, height: 40)
                                if viewModel.offDateText != nil {
                                    Text(viewModel.offDateText ?? "")
                                        .font(.subheadline)
                                }
                            }
                            .padding(.bottom, 15)
                        })
                }
            }
            SpeedController(viewModel: viewModel)
                .padding([.leading, .trailing], 20)
        }
    }
}

struct FanImageRender: View {
    @EnvironmentObject var sharedHouseData: SharedHouseData
    @EnvironmentObject var weather: Weather
    @Binding var angle: Angle
    @Binding var activeSheet: OverlaySheet?
    @State private var verticalOffset = CGFloat.zero
    var viewModel: FanViewModel
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack {
                IdentifiableImage.fanIcon.image
                    .resizable()
                    .aspectRatio(1.0, contentMode: .fit)
                    .rotationEffect(angle)
                    .scaleEffect(1.5)
                    .clipped()
                    .readFanOffset()
                    .onPreferenceChange(FanImageOffsetKey.self) { midpoint in
                        verticalOffset = midpoint
                    }
                Spacer()
            }
            .offset(y: 100)
            Color.clear
                .background(.thinMaterial)
            VStack {
                Button(action: {
                    activeSheet = .detail
                }, label: {
                    IdentifiableImage.info.image
                        .resizable()
                        .frame(width: 35, height: 35)
                        .aspectRatio(1.0, contentMode: .fill)
                })
                RefreshIndicator()
                    .padding(.top, 40)
                    .tint(.main)
                if let temp = weather.currentTempStr, sharedHouseData.updateProgress == nil {
                    Text(temp)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal)
            .alignmentGuide(VerticalAlignment.top, computeValue: { dim in
                -verticalOffset + dim.height/2
            })
        }
        .ignoresSafeArea()
    }
}

struct FanNameRender: View {
    @EnvironmentObject var sharedHouseData: SharedHouseData
    @EnvironmentObject var weather: Weather
    @Binding var activeSheet: OverlaySheet?
    @Binding var name: String
    @Binding var showDamperWarning: Bool
    @Binding var showInterlockWarning: Bool
    
    var body: some View {
        VStack (alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: 0) {
            HStack (alignment: .firstTextBaseline) {
                Text(name).font(.largeTitle)
                    .onLongPressGesture {
                        activeSheet = .fanName
                    }
                Spacer()
                HStack {
                    if weather.tooCold || weather.tooCold {
                        IdentifiableImage.thermometer.image
                    }
                    if showDamperWarning {
                        IdentifiableImage.damper.image
                    }
                    if showInterlockWarning {
                        IdentifiableImage.interlock.image
                    }
                }
            }
            Divider().frame(width: nil, height: 1, alignment: .center).background(Color.main)
            Spacer()
        }
        .padding([.leading, .trailing], 20.0)
        .padding(.top, 40.0)
    }
}

struct FanImageOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct FanImageOffsetReader: ViewModifier {
    private var offsetView: some View {
        GeometryReader { geometry in
            Color.clear.preference(key: FanImageOffsetKey.self, value: geometry.frame(in: .global).midY)
        }
    }
    
    func body(content: Content) -> some View {
        content.background(offsetView)
    }
}

extension View {
    func readFanOffset () -> some View {
        modifier(FanImageOffsetReader())
    }
}


extension FanView: Hashable {
    static func ==(lhs: FanView, rhs: FanView) -> Bool {
        rhs.id == lhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension FanView: Identifiable {}


struct FanView_Previews: PreviewProvider {
    struct FanMock {
        var chars: FanCharacteristics
        init () {
            var a = FanCharacteristics()
            a.airspaceFanModel = "4300"
            chars = a
        }
    }
    struct InjectedIndicators {
        static var indicators: SharedHouseData {
            let retVal = SharedHouseData.shared
            retVal.updateProgress = 0.5
            return retVal
        }
    }
    static var chars = FanMock().chars
    static var previews: some View {
        var fan = FanCharacteristics()
        fan.timer = 0
        let vm = FanViewModel(chars: fan)
        //        vm.offDateText = "test"
        return ControllerRender(viewModel: vm, activeSheet: .mock(nil))
        //            .environmentObject(env)
        //        FanView(initialCharacteristics: chars)
        //            .environment(\.updateProgress, nil)
        //            .environmentObject(InjectedIndicators.indicators)
            .preferredColorScheme(.light)
            .foregroundColor(.main)
            .tint(.main)
            .accentColor(.main)
    }
}
