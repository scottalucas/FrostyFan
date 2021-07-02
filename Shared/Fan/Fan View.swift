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
    @StateObject var fanViewModel: FanViewModel
    @AppStorage var name: String
    @State private var angle: Angle = .zero
    @State private var activeSheet: Sheet?
    @State private var requestedKeypresses: Int = 0
    enum Sheet: Identifiable {
        var id: Int { hashValue }
        case fanName
        case timer
        case detail
        
        func view (for viewModel: FanViewModel) -> AnyView {
            Text("test").eraseToAnyView()
//            switch self {
//            case .fanName:
//                guard let addr = viewModel.model.fanCharacteristics?.macAddr else {
//                    return EmptyView().allowsHitTesting(false).eraseToAnyView()
//                }
//                return NameSheet(storageKey: StorageKey.fanName(addr)).eraseToAnyView()
//            case .timer:
//                break
//                //                return TimerSheet(fanViewModel: viewModel).eraseToAnyView()
////                return TimerSheet(hoursToAdd: $newTime).eraseToAnyView()
//            case .detail:
//                guard let chars = viewModel.model.fanCharacteristics else {
//                    return EmptyView().allowsHitTesting(false).eraseToAnyView()
//                }
//                return DetailSheet(chars: chars).eraseToAnyView()
//            }
        }
    }
    
    var body: some View {
        ZStack {
            ControllerRender(fanViewModel: fanViewModel, speed: $fanViewModel.model.currentSpeed, activeSheet: $activeSheet)
            FanImageRender(angle: $angle, activeSheet: $activeSheet, fanViewModel: fanViewModel)
            FanNameRender(activeSheet: $activeSheet, name: $name, fanViewModel: fanViewModel)
            OverlaySheetRender(fanViewModel: fanViewModel, activeSheet: $activeSheet, requestedKeypresses: $requestedKeypresses)
        }
        .foregroundColor(fanViewModel.displayedLamps.isDisjoint(with: .useAlarmColor) ? .main : .alarm)
        .onReceive(fanViewModel.$fanRotationDuration) { val in
            self.angle = .zero
            withAnimation(Animation.linear(duration: val)) {
                self.angle = .degrees(179.99)
            }
        }
        .onAppear {
            fanViewModel.model.refreshFan()
        }
    }
    
    init (addr: String, chars: FanCharacteristics, house: House, weather: Weather) {
        _name = AppStorage(wrappedValue: "\(chars.airspaceFanModel)", StorageKey.fanName(chars.macAddr).key)
        _fanViewModel = StateObject(wrappedValue: FanViewModel(atAddr: addr, usingChars: chars, inHouse: house, weather: weather))
    }
}

struct SpeedController: View {
    @ObservedObject var viewModel: FanViewModel
    
    var body: some View {
        Picker (selection: $viewModel.displayedSegmentNumber, label: Text("Picker")) {
            ForEach (0..<viewModel.controllerSegments.count, id: \.self) { segmentIndex in
                Text(viewModel.controllerSegments[segmentIndex])
                    .tag(segmentIndex)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .modifier(PhysicalSpeedIndicator(viewModel: viewModel))
    }
}

struct ControllerRender: View {
    var fanViewModel: FanViewModel
    @Binding var speed: Int?
    @Binding var activeSheet: FanView.Sheet?
    
    var body: some View {
        VStack {
            Spacer()
            if fanViewModel.displayedLamps.intersection([.damperOpening, .speedAdjusting, .fanOff]).isEmpty {
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
                                if fanViewModel.offDateTxt.count > 0 {
                                    Text(fanViewModel.offDateTxt)
                                        .font(.subheadline)
                                }
                            }
                            .padding(.bottom, 15)
                        })
                    ForEach (fanViewModel.displayedLamps.labels, id: \.self) { element in
                     Text(element)
                    }
                }
            } else {
                ForEach (fanViewModel.displayedLamps.labels, id: \.self) { element in
                 Text(element)
                }
            }
            SpeedController(viewModel: fanViewModel)
                .padding([.leading, .trailing], 20)
        }
    }
}


struct FanImageRender: View {
    @Binding var angle: Angle
    @Binding var activeSheet: FanView.Sheet?
    var fanViewModel: FanViewModel
    
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
                        let labels = fanViewModel.displayedLamps.labels
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

struct OverlaySheetRender: View {
    var fanViewModel: FanViewModel
    @Binding var activeSheet: FanView.Sheet?
    @Binding var requestedKeypresses: Int
    @State private var wheelPosition: Int = 0
    var body: some View {
        Color.clear
            .sheet(item: $activeSheet, onDismiss: {
                defer { wheelPosition = 0 }
                if wheelPosition > 0 {
                    fanViewModel.model.setFan(addHours: wheelPosition)
                }
            }) {
                switch $0 {
                case .detail:
                    Text("detail sheet")
                case .fanName:
                    Text("name sheet")
                case .timer:
                    TimerSheet(wheelPosition: $wheelPosition, timeOnTimer: fanViewModel.model.fanCharacteristics?.timer ?? 0).eraseToAnyView()
                }
            }
    }
}

struct PhysicalSpeedIndicator: ViewModifier {
    @ObservedObject var viewModel: FanViewModel
    
    func body(content: Content) -> some View {
        content
            .overlay (
                !viewModel.displayedLamps.isDisjoint(with: .showPhysicalSpeed) ?
                    GeometryReader { geo2 in
                        Image(systemName: "arrowtriangle.up.fill")
                            .resizable()
                            .foregroundColor(Color(viewModel.displayedLamps.isDisjoint(with: .useAlarmColor) ? .main : .alarm))
                            .alignmentGuide(.top, computeValue: { dimension in
                                -geo2.size.height + dimension.height/CGFloat(2)
                            })
                            .alignmentGuide(HorizontalAlignment.center, computeValue: { dimension in
                                let oneSegW = geo2.size.width/CGFloat(viewModel.controllerSegments.count)
                                let offs = oneSegW/2.0 + (oneSegW * CGFloat(viewModel.physicalFanSpeed ?? 0)) - dimension.width
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
    @State static var fans: Set<FanCharacteristics> = [FanCharacteristics()]
    @State static var runningFans = Set<FanCharacteristics>()
    static var chars = FanCharacteristics()
    static var house = House()
    static var previews: some View {
        FanView(addr: "0.0.0.0:8181", chars: chars, house: house, weather: Weather(house: house))
            .preferredColorScheme(.light)
    }
}

