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
    case settings
    case fatalFault
}

struct FanView: View {
    typealias MACAddr = String
    let id: MACAddr
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var sharedHouseData: HouseMonitor
    @StateObject var viewModel: FanViewModel
    @AppStorage var name: String
    @GestureState var viewOffset = CGSize.zero
    
    @State var pullDownOffset = CGFloat.zero
    @State private var angle = Angle.zero
    @State private var activeSheet: OverlaySheet?
    
    var body: some View {
//        NavigationView {
            ZStack {
                NavigationLink(tag: OverlaySheet.fanName, selection: $activeSheet, destination: { NameSheet(sheet: $activeSheet, storageKey: StorageKey.fanName(id)) }, label: {})
                NavigationLink(tag: OverlaySheet.timer, selection: $activeSheet, destination: { TimerSheet(activeSheet: $activeSheet, timeOnTimer: viewModel.chars.timer, fanViewModel: viewModel) }, label: {})
                NavigationLink(tag: OverlaySheet.detail, selection: $activeSheet, destination: { DetailSheet(chars: viewModel.chars, activeSheet: $activeSheet) }, label: {})
                NavigationLink(tag: OverlaySheet.fatalFault, selection: $activeSheet, destination: { FatalFaultSheet() }, label: {})
                NavigationLink(tag: OverlaySheet.settings, selection: $activeSheet, destination: { SettingsView(activeSheet: $activeSheet) }, label: {})
                
                FanInfoAreaRender(activeSheet: $activeSheet, viewModel: viewModel)
//                    .ignoresSafeArea()
                ControllerRender(viewModel: viewModel, activeSheet: $activeSheet)
//                    .padding(.bottom, 45)
                .toolbar(content: {
                    ToolbarItem(placement: .principal) {
                        FanNameRender(activeSheet: $activeSheet, name: $name, showDamperWarning: $viewModel.showDamperWarning, showInterlockWarning: $viewModel.showInterlockWarning)
                            .padding(.bottom, 35)
                    }
                })
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
        _name = AppStorage(wrappedValue: "\(chars.airspaceFanModel)", StorageKey.fanName(chars.macAddr).rawValue)
        _viewModel = StateObject.init(wrappedValue: FanViewModel(chars: chars))
        print("init fan view model \(chars.airspaceFanModel) selector segments \(viewModel.selectorSegments)")
        
    }
}

struct SpeedController: View {
    @ObservedObject var viewModel: FanViewModel
    @State var requestedSpeed: Int?
    var body: some View {
        SegmentedSpeedPicker (
            segments: $viewModel.selectorSegments,
            highlightedSegment: $viewModel.currentMotorSpeed,
            indicatedSegment: $requestedSpeed,
            indicatorBlink: $viewModel.indicatedAlarm,
            minMaxLabels: .useStrings(["Off", "Max"]))
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

struct BaseFanImage: View {
    var body: some View {
        IdentifiableImage.fanIcon.image
            .resizable()
            .scaleEffect(1.75)
            .aspectRatio(1.0, contentMode: .fit)
    }
}

struct FanInfoAreaRender: View {
    @EnvironmentObject var sharedHouseData: HouseMonitor
    @EnvironmentObject var weather: WeatherMonitor
    @Binding var activeSheet: OverlaySheet?
    @State private var fanFrame: CGRect = .zero
    @ObservedObject var viewModel: FanViewModel
//    private var tempFormatter: MeasurementFormatter {
//        let m = MeasurementFormatter()
//        m.numberFormatter.maximumFractionDigits = 0
//        return m
//    }
    
    var body: some View {
                VStack (alignment: .center, spacing: 5)
                {
                    Spacer()
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
                    if let temp = weather.currentTemp, !sharedHouseData.scanning {
                        Text(CustomFormatter.temperture.string(from: temp))
                            .padding(.top, 20)
                        if weather.tooHot || weather.tooCold {
                            Text ("It's \(weather.tooHot ? "hot" : "cold") outside. Turn the fan off?")
                        }
                    }
                    Spacer()
                }
                .fixedSize(horizontal: false, vertical: true)
                .buttonStyle(BorderlessButtonStyle())
    }
}

struct FanNameRender: View {
    @EnvironmentObject var sharedHouseData: HouseMonitor
    @EnvironmentObject var weatherMonitor: WeatherMonitor
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
                    if weatherMonitor.tooCold || weatherMonitor.tooCold {
                        IdentifiableImage.thermometer.image
                    }
                    if showDamperWarning {
                        IdentifiableImage.damper.image
                    }
                    if showInterlockWarning {
                        IdentifiableImage.interlock.image
                    }
                    Button(action: { activeSheet = .settings }, label: { Image(systemName: "bell") })
                }
            }
            .padding([.leading, .trailing], 20.0)
            .padding(.top, 40.0)
            Divider()
                .frame(width: nil, height: 1, alignment: .center)
                .background(Color.main)
                .ignoresSafeArea(.all, edges: [.leading, .trailing])
            Spacer()
        }
    }
}

//struct FanImageOffsetKey: PreferenceKey {
//    static var defaultValue: CGRect = .zero
//
//    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
//        value = nextValue()
//    }
//}

//struct FanImageOffsetReader: ViewModifier {
//    private var offsetView: some View {
//        GeometryReader { geometry in
//            let inset = geometry.safeAreaInsets.top
//            Color.clear
//                .preference(key: FanImageOffsetKey.self, value: geometry.frame(in: .global))
//        }
//    }
//
//    func body(content: Content) -> some View {
//        content.background(offsetView)
//    }
//}
//
//extension View {
//    func readFanOffset () -> some View {
//        modifier(FanImageOffsetReader())
//    }
//}


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
            a.speed = 1
            chars = a
        }
    }
    struct InjectedIndicators {
        static var indicators: HouseMonitor {
            let retVal = HouseMonitor.shared
            retVal.scanning = true
            return retVal
        }
    }
    static var chars = FanMock().chars
    static var previews: some View {
        let fan = FanMock().chars
//        let vm = FanViewModel(chars: fan)
        return Group {
            FanView(initialCharacteristics: fan)
            //                .environmentObject(SharedHouseData.shared)
            //                .environmentObject(Weather())
                .preferredColorScheme(.light)
//                .foregroundColor(.main)
//                .tint(.main)
//                .accentColor(.main)
            FanNameRender(activeSheet: .constant(nil), name: .constant("Test"), showDamperWarning: .constant(true), showInterlockWarning: .constant(true))
//            FanImageRender(activeSheet: .constant(nil), viewModel: vm)
//            VStack {
//                BaseFanImage()
//                Spacer()
//            }
        }
        .environmentObject(HouseMonitor.shared)
        .environmentObject(WeatherMonitor.shared)
        .foregroundColor(.main)
    }
}
