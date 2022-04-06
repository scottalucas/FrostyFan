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
    @Environment(\.scenePhase) var scenePhase
    @StateObject var viewModel: FanViewModel = FanViewModel()
    var id: MACAddr {
        viewModel.id
    }
    @AppStorage var name: String
    @State private var activeSheet: OverlaySheet?
    
    var body: some View {
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
                            setter: viewModel.setTimer(addHours:),
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
                
                FanInfoAreaRender (
                    viewModel: viewModel,
                    activeSheet: $activeSheet)
                //                    .ignoresSafeArea()
                ControllerRender (
                    viewModel: viewModel,
                    activeSheet: $activeSheet,
                    setSpeed: viewModel.setSpeed(to:) )
                //                    .padding(.bottom, 45)
            }
            .background (
                IdentifiableImage.fanIcon.image
                    .resizable()
                    .aspectRatio(1.0, contentMode: .fit)
                    .scaleEffect(1.75)
                    .rotate(rpm: $viewModel.displayedRPM)
                //                    .padding(.bottom, viewModel.fanSet.count > 1 ? 30 : 0)
                    .blur(radius: 30)
                    .foregroundColor (viewModel.houseTempAlarm ? .alarm : .main)
                    .edgesIgnoringSafeArea(.all)
            )
            .toolbar(content: {
                ToolbarItem(placement: .principal) {
                    FanNameRender(
                        viewModel: viewModel,
                        activeSheet: $activeSheet, name: $name)
                    .padding(.bottom, 35)
                }
            })
            .onAppear() {
                viewModel.appInForeground = scenePhase == .active
            }
            
            .onDisappear() {
                viewModel.appInForeground = scenePhase == .active
            }
            
            .onChange(of: scenePhase, perform: { phase in
                viewModel.appInForeground = scenePhase == .active
            })
        }
    }
    
    init (initialCharacteristics chars: FanCharacteristics?) {
        _name = chars == nil ? AppStorage(wrappedValue: "No fan found", StorageKey.fanName("No fan").rawValue) : AppStorage(wrappedValue: "\(chars!.airspaceFanModel)", StorageKey.fanName(chars!.macAddr).rawValue)
        _viewModel = StateObject.init(wrappedValue: FanViewModel(chars: chars ?? FanCharacteristics(), id: chars?.macAddr ?? "No fan"))
        //        houseViewModel = houseVM
        //        print("init fan view model \(chars?.airspaceFanModel) selector segments \(viewModel.selectorSegments)")
        
    }
}


struct SpeedController: View {
    @ObservedObject var viewModel: FanViewModel
    @Binding var requestedSpeed: Int?
    var setSpeed: (Int?) -> ()
    var body: some View {
        SegmentedSpeedPicker (
            segments: $viewModel.selectorSegments,
            highlightedSegment: $viewModel.currentMotorSpeed,
            highlightedAlarm: $viewModel.showInterlockWarning,
            indicatedSegment: $requestedSpeed,
            indicatorBlink: $viewModel.indicatedAlarm,
            minMaxLabels: .useStrings(["Off", "Max"]))
        .onChange(of: requestedSpeed) { speed in
            setSpeed(speed)
        }
    }
}

struct ControllerRender: View {
    @ObservedObject var viewModel: FanViewModel
    @State var requestedSpeed: Int?
    @Binding var activeSheet: OverlaySheet?
    var setSpeed: (Int?) -> ()
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
            
            .onChange(of: requestedSpeed) { speed in
                setSpeed(speed)
            }
            .padding([.leading, .trailing], 20)
        }
        .foregroundColor(HouseStatus.shared.houseTempAlarm ? .alarm : .main)
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
    //    @ObservedObject var houseViewModel: HouseViewModel
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
//                        .multilineTextAlignment(.center)
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
    //    @Binding var showTemperatureWarning: Bool
    //    @Binding var showDamperWarning: Bool
    //    @Binding var showInterlockWarning: Bool
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
        //                .environmentObject(SharedHouseData.shared)
        //                .environmentObject(Weather())
            .preferredColorScheme(.light)
        //                .foregroundColor(.main)
        //                .tint(.main)
        //                .accentColor(.main)
        
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
        FanViewPreviewContainer()
            .task {
                try? await Task.sleep(interval: 2.0)
                URLSessionMgr.shared.networkAvailable.send(true)
                WeatherMonitor.shared.currentTemp = .init(value: 10, unit: .fahrenheit)
                WeatherMonitor.shared.tooCold = true
                WeatherMonitor.shared.tooHot = false
                HouseStatus.shared.houseTempAlarm = true
//                HouseStatus.shared.houseMessage = "test"
//                HouseStatus.shared.scanUntil = .now.addingTimeInterval(2.0)
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
