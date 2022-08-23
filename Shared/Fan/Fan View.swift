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
    @StateObject var viewModel: FanViewModel
    var id: MACAddr
    @AppStorage var name: String
    @State private var activeSheet: OverlaySheet?
    
    var body: some View {
        Group {
            if id == "No fan" {
                NoFanView ()
            } else {
                ZStack {
                    NavigationLink(
                        tag: OverlaySheet.fanName,
                        selection: $activeSheet,
                        destination: {
                            NameSheet(
                                sheet: $activeSheet,
                                storageKey: StorageKey.fanName(id)) },
                        label: {})
                    
                    NavigationLink(
                        tag: OverlaySheet.timer,
                        selection: $activeSheet,
                        destination: {
                            TimerSheet(
                                activeSheet: $activeSheet,
                                viewModel: viewModel,
                                timeOnTimer: viewModel.chars.timer)},
                        label: {})
                    
                    NavigationLink(
                        tag: OverlaySheet.detail,
                        selection: $activeSheet,
                        destination: {
                            DetailSheet(
                                activeSheet: $activeSheet,
                                chars: viewModel.chars )},
                        label: {})
                    
                    NavigationLink(
                        tag: OverlaySheet.fatalFault,
                        selection: $activeSheet,
                        destination: {
                            FatalFaultSheet()},
                        label: {})
                    
                    NavigationLink(
                        tag: OverlaySheet.settings,
                        selection: $activeSheet,
                        destination: {
                            SettingsView(activeSheet: $activeSheet)},
                        label: {})
                    
                    RotatorRender ( rpm: viewModel.displayedRPM ) {
                        IdentifiableImage.fanIcon.image
                            .resizable ( )
                            .aspectRatio ( 1.0, contentMode: .fit )
                            .scaleEffect ( 1.75 )
                            .blur ( radius: 30 )
                            .foregroundColor ( viewModel.houseTempAlarm ? .alarm : .main )
                            .ignoresSafeArea ( )
                    }
                    
                    FanInfoAreaRender (
                        viewModel: viewModel,
                        activeSheet: $activeSheet)
                    ControllerRender (
                        viewModel: viewModel,
                        activeSheet: $activeSheet
                    )
                }
                
                .toolbar(content: {
                    ToolbarItem(placement: .principal) {
                        FanNameRender(
                            viewModel: viewModel,
                            activeSheet: $activeSheet, name: $name)
                        .padding(.bottom, 35)
                    }
                })
                .onAppear() {
                    Log.fan(id).info("view appeared")
                    let _ = task { await viewModel.refresh() }
                }
                .onDisappear() {
                    Log.fan(id).info("view disappeared")
                }
                .onScenePhaseChange(phase: .active) {
                    viewModel.appInForeground = true
                }
                .onScenePhaseChange(phase: .background) {
                    viewModel.appInForeground = false
                }
            }
        }
    }
    
    init (initialCharacteristics chars: FanCharacteristics?) {
        id = chars?.macAddr ?? UUID.init().uuidString
        _name = chars == nil ? AppStorage(wrappedValue: "No fan found", StorageKey.fanName("No fan").rawValue) : AppStorage(wrappedValue: "\(chars!.airspaceFanModel)", StorageKey.fanName(chars!.macAddr).rawValue)
        _viewModel = StateObject.init(wrappedValue: FanViewModel(chars: chars ?? FanCharacteristics(), id: chars?.macAddr ?? "No fan"))
        Log.fan(id).info("view init")
    }
}

struct RotatorRender<Content: View>: View {
    var rpm: Double
    var content: Content
    
    var body: some View {
        Rotator(rpm: rpm) { content }
    }
    
    init (rpm: Double, content: @escaping () -> Content) {
        self.rpm = rpm
        self.content = content ()
    }
}

struct ControllerRender: View {
    @ObservedObject var viewModel: FanViewModel
    @State var requestedSpeed: Int?
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
                                if let offDateText = viewModel.offDateText {
                                    Text(offDateText)
                                        .font(.subheadline)
                                }
                            }
                            .padding(.bottom, 15)
                        })
                }
            }
            SegmentedSpeedPicker (
                segments: $viewModel.selectorSegments,
                highlightedSegment: $viewModel.currentMotorSpeed,
                highlightedAlarm: $viewModel.showInterlockWarning,
                indicatedSegment: $requestedSpeed,
                indicatorBlink: $viewModel.indicatedAlarm,
                minMaxLabels: .useStrings(["Off", "Max"]))
            .frame(height: 40)
            .frame(maxWidth: 500)
            .padding([.leading, .trailing, .bottom])
            .onAppear() {
                requestedSpeed = viewModel.currentMotorSpeed
            }
            .onChange(of: requestedSpeed) { speed in
                Log.fan(viewModel.chars.ipAddr).info("selected speed \(String(describing: speed))")
                viewModel.setSpeed(to: speed)
            }
        }
        .foregroundColor(viewModel.houseTempAlarm ? .alarm : .main)
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
    @ObservedObject var viewModel: FanViewModel
    @Binding var activeSheet: OverlaySheet?
    
    var body: some View {
        VStack (alignment: .center, spacing: 5) {
            Spacer()
            Button(action: {
                activeSheet = .detail
            }, label: {
                IdentifiableImage.info.image
                    .resizable()
                    .frame(width: 35, height: 35)
                    .aspectRatio(1.0, contentMode: .fill)
                    .foregroundColor(viewModel.showDamperWarning || viewModel.showInterlockWarning ? .alarm : .main)
            })
            if (viewModel.scanUntil > .now) {
                RefreshIndicator(scanUntil: $viewModel.scanUntil)
                    .padding(.top, 40)
            } else {
                if let temp = WeatherMonitor.shared.currentTemp {
                    Text(temp.formatted(Measurement<UnitTemperature>.FormatStyle.truncatedTemp))
                        .bold()
                        .font(.largeTitle)
                        .padding([.bottom,.top], 20)
                }
                if let msg = viewModel.houseMessage {
                    Text(msg)
                }
            }
            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
        .buttonStyle(BorderlessButtonStyle())
        .padding()
        .background(.ultraThinMaterial)
    }
}

struct FanNameRender: View {
    @ObservedObject var viewModel: FanViewModel
    @Binding var activeSheet: OverlaySheet?
    @Binding var name: String
    
    var body: some View {
        VStack (alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: 0) {
            HStack (alignment: .firstTextBaseline) {
                Text(name).font(.largeTitle)
                    .onLongPressGesture {
                        activeSheet = .fanName
                    }
                Spacer()
                HStack {
                    Group {
                        if ( viewModel.houseTempAlarm ) {
                            IdentifiableImage.thermometer.image
                        }
                        if viewModel.showDamperWarning {
                            IdentifiableImage.damper.image
                        }
                        if viewModel.showInterlockWarning {
                            IdentifiableImage.interlock.image
                        }
                    }
                    .foregroundColor(.alarm)
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

extension FanView: Hashable {
    static func ==(lhs: FanView, rhs: FanView) -> Bool {
        rhs.id == lhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension FanView: Identifiable {}

struct FanViewPreviewContainer: View {
    struct FanMock {
        var chars: FanCharacteristics
        init () {
            var a = FanCharacteristics()
            a.airspaceFanModel = "4300"
            a.speed = 1
            a.damper = .notOperating
            a.interlock1 = true
            a.macAddr = "Test fan"
            chars = a
//            HouseStatus.shared.houseMessage = "Test"

        }
    }
//    var houseMock = HouseViewModel(initialFans: [])
    @State private var scanUntil: Date? = .now.addingTimeInterval(3.0)
    
    var body: some View {
        
        FanView(initialCharacteristics: FanMock().chars)
            .preferredColorScheme(.light)
    }
}

struct FanView_Previews: PreviewProvider {
    //    struct InjectedIndicators {
    //        static var indicators: HouseMonitor {
    //            let retVal = HouseMonitor.shared
    //            retVal.scanning = true
    //            return retVal
    //        }
    //    }
    static var previews: some View {
        //        let vm = FanViewModel(chars: fan)
        NavigationView {
            FanViewPreviewContainer()
                .preferredColorScheme(.light)
                .task {
                    try? await Task.sleep(interval: 2.0)
                    URLSessionMgr.shared.networkAvailable.send(true)
                    WeatherMonitor.shared.currentTemp = .init(value: 10, unit: .fahrenheit)
                    WeatherMonitor.shared.tooCold = false
                    WeatherMonitor.shared.tooHot = false
                    HouseStatus.shared.houseTempAlarm = true
                    //                HouseStatus.shared.houseMessage = "test"
                    //                HouseStatus.shared.scanUntil = .now.addingTimeInterval(2.0)
                }
            FanViewPreviewContainer()
                .preferredColorScheme(.light)
                .task {
                    try? await Task.sleep(interval: 2.0)
                    URLSessionMgr.shared.networkAvailable.send(true)
                    WeatherMonitor.shared.currentTemp = .init(value: 10, unit: .fahrenheit)
                    WeatherMonitor.shared.tooCold = false
                    WeatherMonitor.shared.tooHot = false
                    HouseStatus.shared.houseTempAlarm = true
                    //                HouseStatus.shared.houseMessage = "test"
                    //                HouseStatus.shared.scanUntil = .now.addingTimeInterval(2.0)
                }
            FanViewPreviewContainer()
                .previewDevice("iPad Pro (12.9-inch) (5th generation)")
                .preferredColorScheme(.dark)
                .task {
                    try? await Task.sleep(interval: 2.0)
                    URLSessionMgr.shared.networkAvailable.send(true)
                    WeatherMonitor.shared.currentTemp = .init(value: 10, unit: .fahrenheit)
                    WeatherMonitor.shared.tooCold = false
                    WeatherMonitor.shared.tooHot = false
                    HouseStatus.shared.houseTempAlarm = true
                    //                HouseStatus.shared.houseMessage = "test"
                    //                HouseStatus.shared.scanUntil = .now.addingTimeInterval(2.0)
                }
        }
        //            FanNameRender(showTemperatureWarning: .constant(false), showDamperWarning: .constant(false), showInterlockWarning: .constant(false), activeSheet: .constant(nil), name: .constant("Test fan"))
        //            FanImageRender(activeSheet: .constant(nil), viewModel: vm)
        //            VStack {
        //                BaseFanImage()
        //                Spacer()
        //            }
        //        .environmentObject(HouseMonitor.shared)
            
    }
}

struct TestView: View {
    @StateObject var testFanViewModel: TestFanViewModel
    @AppStorage("test") var name: String = "Not found"
    
    @ObservedObject var vm: HouseViewModel
    @State private var macAddr: MACAddr
    
    var body: some View {
        Text(macAddr)
    }
    
    init (initialCharacteristics: FanCharacteristics?, houseVM: HouseViewModel) {
        vm = houseVM
        macAddr = initialCharacteristics?.macAddr ?? "Nil mac address"
        _testFanViewModel = StateObject.init(wrappedValue: TestFanViewModel(chars: initialCharacteristics ?? FanCharacteristics() ))
    }
}
