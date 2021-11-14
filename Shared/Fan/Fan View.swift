//
//  Fan View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

enum OverlaySheet: Identifiable {
    var id: Int { hashValue }
    case fanName
    case timer
    case detail
    case fatalFault
}

struct FanView: View {
    typealias MACAddr = String
    var id: MACAddr
    @Environment(\.scenePhase) var scenePhase
    @StateObject var viewModel: FanViewModel
    @AppStorage var name: String
    @GestureState var viewOffset = CGSize.zero

    @State var pullDownOffset = CGFloat.zero
    @State private var angle = Angle.zero
    @State private var activeSheet: OverlaySheet?
    
    var body: some View {
        ZStack {
            ControllerRender(viewModel: viewModel, activeSheet: $activeSheet)
            FanImageRender(angle: $angle, activeSheet: $activeSheet, viewModel: viewModel)
            FanNameRender(activeSheet: $activeSheet, name: $name)
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
        print("init fan view model \(viewModel.chars.airspaceFanModel) selector segments \(viewModel.selectorSegments)")
    }
}

struct SpeedController: View {
    @ObservedObject var viewModel: FanViewModel
    
    var body: some View {
        SegmentedSpeedPicker(
            segments: $viewModel.selectorSegments,
            highlightedSegment: $viewModel.currentMotorSpeed,
            indicatedSegment: $viewModel.targetedSpeed,
            indicatorBlink: $viewModel.indicatedAlarm)
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
                                Image.timer
                                    .resizable()
                                    .foregroundColor(.main)
                                    .scaledToFit()
                                    .frame(width: nil, height: 40)
                                if viewModel.offDateText != nil {
                                    Text(viewModel.offDateText ?? "")
                                        .font(.subheadline)
                                }
                            }
                            .padding(.bottom, 15)
                        })
                    if viewModel.fanStatusText != nil {
                        Text(viewModel.fanStatusText ?? "")
                    }
                }
            }
            SpeedController(viewModel: viewModel)
                .padding([.leading, .trailing], 20)
        }
    }
}

struct FanImageRender: View {
    @Binding var angle: Angle
    @Binding var activeSheet: OverlaySheet?
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
                .overlay(
                    VStack {
                        Button(action: {
                            activeSheet = .detail
                        }, label: {
                            Image(systemName: "info.circle.fill")
                                .resizable()
                                .frame(width: 35, height: 35)
                                .aspectRatio(1.0, contentMode: .fill)
                        })
                        RefreshIndicator()
                            .padding(.top, 40)
                    }
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
            }
            Divider().frame(width: nil, height: 1, alignment: .center).background(Color.main)
            Spacer()
        }
        .padding([.leading, .trailing], 20.0)
        .padding(.top, 40.0)
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
        static var indicators: GlobalIndicators {
            let retVal = GlobalIndicators.shared
            retVal.updateProgress = 0.5
            return retVal
        }
    }
    static var chars = FanMock().chars
    static var previews: some View {
        FanView(initialCharacteristics: chars)
            .environment(\.updateProgress, nil)
            .environmentObject(InjectedIndicators.indicators)
            .preferredColorScheme(.light)
            .foregroundColor(.main)
            .tint(.main)
            .accentColor(.main)
    }
}
