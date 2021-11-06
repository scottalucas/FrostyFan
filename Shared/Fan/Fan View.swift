//
//  Fan View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct FanView: View {
    typealias IPAddr = String
    var id: IPAddr
    @Environment(\.scenePhase) var scenePhase

    @StateObject var viewModel: FanViewModel
//    @ObservedObject var houseViewModel: HouseViewModel
    @AppStorage var name: String
//    @Binding var refreshing: Bool
//    @Binding var applicationLamps: HouseLamps
    @GestureState var viewOffset = CGSize.zero

    @State var pullDownOffset = CGFloat.zero
    @State private var angle = Angle.zero
    @State private var activeSheet: Sheet?
    enum Sheet: Identifiable {
        var id: Int { hashValue }
        case fanName
        case timer
        case detail
        case fatalFault
    }
    
    var body: some View {
        ZStack {
            ControllerRender(viewModel: viewModel, activeSheet: $activeSheet)
            FanImageRender(angle: $angle, activeSheet: $activeSheet, viewModel: viewModel)
            FanNameRender(activeSheet: $activeSheet, name: $name, pullDownOffset: $pullDownOffset)
            VStack {
                Text("\(pullDownOffset)")
            }
        }
//        .gesture(DragGesture().updating($viewOffset) { value, state, _ in
//            guard refreshing.status == .readyForRequest else {
//                let thump = UIImpactFeedbackGenerator(style: .rigid)
//                thump.impactOccurred()
//                pullDownOffset = .zero
//                state = .zero
//                return
//            }
//            state = CGSize(width: .zero, height: max(0, min(75, value.translation.height)))
//            pullDownOffset = state.height
//            if pullDownOffset >= 75 { refreshing.status = .requestPending }
//        })
        .foregroundColor(viewModel.useAlarmColor ? .alarm : .main)
        .overlaySheet(dataSource: viewModel, activeSheet: $activeSheet)
//        .modifier(OverlaySheetRender(dataSource: viewModel, activeSheet: $activeSheet))
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
        id = chars.ipAddr
//        self.houseViewModel = houseViewModel
        _name = AppStorage(wrappedValue: "\(chars.airspaceFanModel)", StorageKey.fanName(chars.macAddr).key)
        _viewModel = StateObject(wrappedValue: FanViewModel(chars: chars))
//        _refreshing = refreshing
//        self._pullDownOffset = pullDownOffset
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
    @Binding var activeSheet: FanView.Sheet?
//    @Binding var applicationLamps: HouseLamps
    
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
//            else {
//                ForEach (applicationLamps.diplayedLabels, id: \.self) { element in
//                 Text(element)
//                }
//            }
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
                        activeSheet = .detail
                    }, label: {
                        Text("Stats")
//                        let labels = HouseViewModel.shared.indicators.diplayedLabels
//                        if labels.isEmpty {
//                            AnyView(Color.clear)
//                        }
//                        else {
//                            ForEach (labels, id: \.self) { item in
//                                AnyView(Text(item)
//                                )}
//                                .frame(width: nil, height: nil, alignment: .center)
//                        }
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
    @EnvironmentObject private var house: House
    @Binding var activeSheet: FanView.Sheet?
    @Binding var name: String
    @Binding var pullDownOffset: CGFloat
    @State private var scaleFactor = 1.0
    @State private var yOffset: CGFloat = .zero
//    var fanViewModel: FanViewModel
    
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
        .scaleEffect(scaleFactor, anchor: .topLeading)
        .padding([.leading, .trailing], 20.0)
        .padding(.top, 40.0)
        .onChange(of: house.pulldownDistance) { pullOffset in
            yOffset = pullOffset
            scaleFactor = 1 + pow(Double(pullOffset/70), 3)

//            1/(pow(Double(pullOffset), 2) == 0 ? .infinity : pow(Double(pullOffset), 2))
        }
    }
}


//struct TargetSpeedIndicator: ViewModifier {
//    @ObservedObject var viewModel: FanViewModel
////    @ObservedObject var appLamps = HouseViewModel.shared
//
//    func body(content: Content) -> some View {
//        content
//            .overlay (
//                viewModel.fanLamps.contains(.showPhysicalSpeedIndicator) ?
//                    GeometryReader { geo2 in
//                        Image(systemName: "arrowtriangle.up.fill")
//                            .resizable()
//                            .foregroundColor(Color(viewModel.fanLamps.contains(.useAlarmColor) || appLamps.indicators.contains(.useAlarmColor) ? .main : .alarm))
//                            .alignmentGuide(.top, computeValue: { dimension in
//                                -geo2.size.height + dimension.height/CGFloat(2)
//                            })
//                            .alignmentGuide(HorizontalAlignment.center, computeValue: { dimension in
//                                let oneSegW = geo2.size.width/CGFloat(viewModel.selectorSegments + 1)
//                                let offs = oneSegW/2.0 + (oneSegW * CGFloat(viewModel.currentMotorSpeed ?? 0)) - dimension.width
//                                return -offs
//                            })
//                            .animation(.easeInOut)
//                            .frame(width: 20, height: 10, alignment: .top)
//                    }
//                    .eraseToAnyView() :
//                    Color.clear.eraseToAnyView()
//            )
//    }
//}

extension FanView: Hashable {
    static func == (lhs: FanView, rhs: FanView) -> Bool {
        rhs.id == lhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension FanView: Identifiable {}


struct FanView_Previews: PreviewProvider {
    static var chars = FanCharacteristics()
    static var previews: some View {
        FanView(initialCharacteristics: chars)
            .preferredColorScheme(.light)
            .environmentObject(House())
    }
}

