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
    @AppStorage var name: String?
    @State private var angle: Angle = .zero
    @State private var activeSheet: Sheet?
//    @State private var hoursToAdd: Int = 0

//    private var maxKeypresses: Int {
//        13 - (Int(fanViewModel.timer/60) + (fanViewModel.timer%60 != 0 ? 1 : 0)) + 1
//    }
    
    enum Sheet: Identifiable {
        var id: Int {
            hashValue
        }
        case fanName
        case timer
        case detail
        func view(view: FanView) -> AnyView {
            switch self {
            case .fanName:
                return NameSheet(viewModel: view.fanViewModel).eraseToAnyView()
            case .timer:
                return TimerSheet(fanViewModel: view.fanViewModel) .eraseToAnyView()
            case .detail:
                return DetailSheet(fanViewModel: view.fanViewModel).eraseToAnyView()
            }
        }
    }
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                Button(
                    action: {
                        fanViewModel.model.setFan()
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
//                                    .foregroundColor(.main)
                            }
                        }
                        .padding(.bottom, 15)
                    })
                SpeedController(viewModel: fanViewModel)
                    .padding([.leading, .trailing], 20)
            }
            VStack() {
                Image.fanLarge
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .rotationEffect(angle)
//                    .foregroundColor(Color(fanViewModel.displayedLamps.isDisjoint(with: .useAlarmColor) ? .main : .alarm))
                    .opacity(/*@START_MENU_TOKEN@*/0.8/*@END_MENU_TOKEN@*/)
                    .blur(radius: 10.0)
                    .scaleEffect(1.5)
                    .allowsHitTesting(false)
                    .overlay(
                        Button(action: {
                            fanViewModel.model.setFan()
                            activeSheet = .detail
                        }, label: {
                            let labels = fanViewModel.displayedLamps.labels
                            if labels.isEmpty {
                                    AnyView(Color.clear)
                                }
                                else {
                                    ForEach (labels, id: \.self) { item in
                                        AnyView(Text(item)
//                                                    .foregroundColor(fanViewModel.displayedLamps.isDisjoint(with: .useAlarmColor) ? .main : .alarm)
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
            VStack (alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: 0) {
                HStack (alignment: .firstTextBaseline) {
                    Text(name ?? fanViewModel.model.fanCharacteristics.airspaceFanModel).font(.largeTitle)
//                        .foregroundColor(.main)
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
        .foregroundColor(fanViewModel.displayedLamps.isDisjoint(with: .useAlarmColor) ? .main : .alarm)
        .sheet(item: $activeSheet) { $0.view(view: self) }
        .onReceive(fanViewModel.$fanRotationDuration) { val in
            self.angle = .zero
            withAnimation(Animation.linear(duration: val)) {
                self.angle = .degrees(179.99)
            }
        }

//        .onChange(of: scenePhase, perform: { scene in
//            switch scene {
//            case .background, .inactive:
//                break
//            case .active:
//                fanViewModel.model.setFan()
//            @unknown default:
//                break
//            }
//        })
    }
    
    init (addr: String, chars: FanCharacteristics, house: House, weather: Weather) {
        _name = AppStorage<String?>(StorageKey.fanName(chars.macAddr).key)
        _fanViewModel = StateObject(wrappedValue: FanViewModel(atAddr: addr, usingChars: chars, inHouse: house, weather: weather))
    }
}

struct SpeedController: View {
    @ObservedObject var viewModel: FanViewModel
    
    var body: some View {
        Picker (selection: $viewModel.displayedSegmentNumber, label: Text("Picker")) {
            ForEach (0..<viewModel.controllerSegments.count, id: \.self) { segmentIndex in
                Text(viewModel.controllerSegments[segmentIndex]).tag(segmentIndex)
                }
            }
        .pickerStyle(SegmentedPickerStyle())
        .foregroundColor(.blue)
            .modifier(PhysicalSpeedIndicator(viewModel: viewModel))
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
    }
}

