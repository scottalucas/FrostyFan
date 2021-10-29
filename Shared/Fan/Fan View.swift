//
//  Fan View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct FanView: View {
    typealias IPAddr = String
    @Environment(\.scenePhase) var scenePhase
//    private var applicationLamps: HouseLamps
    @StateObject var viewModel: FanViewModel
    @AppStorage var name: String
    @State private var angle: Angle = .zero
    @State private var timerWheelPosition: Int = .zero
    @State private var activeSheet: Sheet?
    enum Sheet: Identifiable {
        var id: Int { hashValue }
        case fanName
        case timer
        case detail
    }
    
    var body: some View {
        ZStack {
            ControllerRender(viewModel: viewModel, activeSheet: $activeSheet)
            FanImageRender(angle: $angle, activeSheet: $activeSheet, viewModel: viewModel)
            FanNameRender(activeSheet: $activeSheet, name: $name, fanViewModel: viewModel)
        }
        .foregroundColor(viewModel.fanLamps.contains(.useAlarmColor) || HouseViewModel.shared.indicators.contains(.useAlarmColor) ? .alarm : .main)
        .modifier(OverlaySheetRender(viewModel: viewModel, activeSheet: $activeSheet))
        .onReceive(viewModel.$fanRotationDuration) { val in
            self.angle = .zero
            withAnimation(Animation.linear(duration: val)) {
                self.angle = .degrees(179.99)
            }
        }
        .onAppear {
            viewModel.refreshFan()
        }
    }
    
    init (addr: IPAddr, chars: FanCharacteristics) {
        _name = AppStorage(wrappedValue: "\(chars.airspaceFanModel)", StorageKey.fanName(chars.macAddr).key)
        _viewModel = StateObject(wrappedValue: FanViewModel(atAddr: addr, usingChars: chars))
    }
}

struct SpeedController: View {
    @ObservedObject var viewModel: FanViewModel
    
    var body: some View {
        SegmentedSpeedPicker(
            segments: $viewModel.selectorSegments,
            highlightedSegment: $viewModel.currentMotorSpeed,
            targetedSegment: $viewModel.targetedSpeed,
            indicatorPulse: $viewModel.indicatedAlarm)
    }
}

struct ControllerRender: View {
    var viewModel: FanViewModel
    @Binding var activeSheet: FanView.Sheet?
    
    var body: some View {
        VStack {
            Spacer()
            if viewModel.fanLamps.contains(.showTimerIcon) {
                VStack {
                    Button(
                        action: {
                            activeSheet = .timer
                        }, label: {
                            VStack {
                                Image.timer
                                    .resizable()
                                    .foregroundColor(.main)
                                    .scaledToFit()
                                    .frame(width: nil, height: 40)
                                if viewModel.fanLamps.contains(.showTimeLeft) {
                                    Text(viewModel.offDateTxt)
                                        .font(.subheadline)
                                }
                            }
                            .padding(.bottom, 15)
                        })
                    ForEach (viewModel.fanLamps.diplayedLabels, id: \.self) { element in
                     Text(element)
                    }
                }
            } else {
                ForEach (HouseViewModel.shared.indicators.diplayedLabels, id: \.self) { element in
                 Text(element)
                }
            }
            SpeedController(viewModel: viewModel)
                .padding([.leading, .trailing], 20)
        }
    }
}


struct FanImageRender: View {
    @Binding var angle: Angle
    @Binding var activeSheet: FanView.Sheet?
    var viewModel: FanViewModel
    
    var body: some View {
        VStack() {
            Image.fanLarge
                .resizable()
                .aspectRatio(contentMode: .fit)
                .rotationEffect(angle)
                .opacity(/*@START_MENU_TOKEN@*/0.8/*@END_MENU_TOKEN@*/)
                .blur(radius: 10.0)
                .scaleEffect(1.5)
                .allowsHitTesting(false)
                .overlay(
                    Button(action: {
                        if !viewModel.fanLamps.contains(.showNoCharsIndicator) {
                            activeSheet = .detail
                        }
                    }, label: {
                        let labels = HouseViewModel.shared.indicators.diplayedLabels
                        if labels.isEmpty {
                            AnyView(Color.clear)
                        }
                        else {
                            ForEach (labels, id: \.self) { item in
                                AnyView(Text(item)
                                )}
                                .frame(width: nil, height: nil, alignment: .center)
                        }
                    })
                    .buttonStyle(BorderlessButtonStyle())
                    .frame(width: nil, height: 75, alignment: .center)
                    .padding(.horizontal)
                )
                .padding(.top, 100)
                .ignoresSafeArea(.container, edges: .top)
            Spacer()
        }
    }
}

struct FanNameRender: View {
    @Binding var activeSheet: FanView.Sheet?
    @Binding var name: String
    var fanViewModel: FanViewModel
    
    var body: some View {
        VStack (alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: 0) {
            HStack (alignment: .firstTextBaseline) {
                Text(name).font(.largeTitle)
                    .onLongPressGesture {
                        activeSheet = .fanName
                    }
                Spacer()
            }
            Divider().frame(width: nil, height: 1, alignment: .center).background(Color.main)
            Spacer()
        }
        .padding([.leading, .trailing], 20.0)
        .padding(.top, 40.0)
    }
}

struct OverlaySheetRender: ViewModifier {
    @Binding var activeSheet: FanView.Sheet?
    @State var wheelPosition: Int = 0
    private var viewModel: FanViewModel
    private var chars: FanCharacteristics?
    private var timeOnTimer: Int = 0
    private var macAddr: String = ""

    func body (content: Content) -> some View {
        content
            .sheet(item: $activeSheet, onDismiss: {
                defer { wheelPosition = 0 }
                if wheelPosition > 0 {
                    viewModel.setTimer(addHours: wheelPosition)
                }
            }) {
                switch $0 {
                case .detail:
                    DetailSheet(chars: chars ?? FanCharacteristics())
                case .fanName:
                    NameSheet(storageKey: StorageKey.fanName(macAddr))
                case .timer:
                    TimerSheet(wheelPosition: $wheelPosition, timeOnTimer: timeOnTimer).eraseToAnyView()
                }
            }
    }
    init (viewModel: FanViewModel, activeSheet: Binding<FanView.Sheet?>) {
        self.viewModel = viewModel
        self._activeSheet = activeSheet
        chars = viewModel.model.fanCharacteristics
        viewModel.model.fanCharacteristics.map { c in
            self.macAddr = c.macAddr
            self.timeOnTimer = c.timer
        }
    }
}

struct TargetSpeedIndicator: ViewModifier {
    @ObservedObject var viewModel: FanViewModel
    @ObservedObject var appLamps = HouseViewModel.shared
    
    func body(content: Content) -> some View {
        content
            .overlay (
                viewModel.fanLamps.contains(.showPhysicalSpeedIndicator) ?
                    GeometryReader { geo2 in
                        Image(systemName: "arrowtriangle.up.fill")
                            .resizable()
                            .foregroundColor(Color(viewModel.fanLamps.contains(.useAlarmColor) || appLamps.indicators.contains(.useAlarmColor) ? .main : .alarm))
                            .alignmentGuide(.top, computeValue: { dimension in
                                -geo2.size.height + dimension.height/CGFloat(2)
                            })
                            .alignmentGuide(HorizontalAlignment.center, computeValue: { dimension in
                                let oneSegW = geo2.size.width/CGFloat(viewModel.selectorSegments + 1)
                                let offs = oneSegW/2.0 + (oneSegW * CGFloat(viewModel.currentMotorSpeed ?? 0)) - dimension.width
                                return -offs
                            })
                            .animation(.easeInOut)
                            .frame(width: 20, height: 10, alignment: .top)
                    }
                    .eraseToAnyView() :
                    Color.clear.eraseToAnyView()
            )
    }
}

struct FanView_Previews: PreviewProvider {
    static var chars = FanCharacteristics()
    static var previews: some View {
        FanView(addr: "0.0.0.0:8181", chars: chars)
            .preferredColorScheme(.light)
    }
}

