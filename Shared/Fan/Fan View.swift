//
//  Fan View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct FanView: View {
    typealias IPAddr = String
    @StateObject var fanViewModel: FanViewModel
//    @AppStorage("test") var name: String = ""
    @AppStorage var name: String?
    @State private var angle: Angle = .zero
    @State private var indicator: Bool = false
    @State private var activeSheet: Sheet?
    @State private var hoursToAdd: Int = 0
    @Binding var fanAddrs: Set<FanCharacteristics>
    @Binding var runningFans: Set<FanCharacteristics>
    private var maxKeypresses: Int {
        13 - (Int(fanViewModel.timer/60) + (fanViewModel.timer%60 != 0 ? 1 : 0)) + 1
    }
    
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
                return TimerSheet(hoursToAdd: view.$hoursToAdd, fanViewModel: view.fanViewModel) .eraseToAnyView()
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
                        fanViewModel.refresh()
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
                                    .foregroundColor(.main)
                            }
                        }
                        .padding(.bottom, 15)
                    })
                SpeedController(displayedSegmentNumber: $fanViewModel.displayedSegmentNumber, controllerSegments: $fanViewModel.controllerSegments, showPhysicalSpeedIndicator: $fanViewModel.showPhysicalSpeedIndicator, bladeColor: $fanViewModel.bladeColor, physicalFanSpeed: $fanViewModel.physicalFanSpeed)
                    .padding([.leading, .trailing], 20)
            }
            VStack() {
                Image.fanLarge
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .rotationEffect(angle)
                    .foregroundColor(Color(fanViewModel.bladeColor))
                    .opacity(/*@START_MENU_TOKEN@*/0.8/*@END_MENU_TOKEN@*/)
                    .blur(radius: 10.0)
                    .scaleEffect(1.5)
                    .overlay(
                        Button(action: {
                            fanViewModel.refresh()
                            activeSheet = .detail
                        }, label: {
                                if fanViewModel.displayedAlarms.isEmpty {
                                    AnyView(Color.clear)
                                }
                                else {
                                    ForEach (Alarm.labels(forOptions: fanViewModel.displayedAlarms), id: \.self) { item in
                                        AnyView(Text(item).foregroundColor(.alarm))
                                    }
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
                    Text(name ?? fanViewModel.model.fanCharacteristics.airspaceFanModel).font(.largeTitle).foregroundColor(.main)
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
        .sheet(item: $activeSheet, onDismiss: { indicator = true }, content: { $0.view(view: self) })
        .onReceive(fanViewModel.$fanRotationDuration) { val in
            self.angle = .zero
            withAnimation(Animation.linear(duration: val)) {
                self.angle = .degrees(179.99)
            }
        }
        .onReceive(fanViewModel.$commError) { err in
            if err {
                fanAddrs.remove(fanViewModel.model.fanCharacteristics)
            }
        }
        .onReceive(fanViewModel.$physicalFanSpeed) { spd in
            spd.map {
                if $0 > 0 {
                    runningFans.update(with: fanViewModel.model.fanCharacteristics)
                } else {
                    runningFans.remove(fanViewModel.model.fanCharacteristics)
                }
            }
        }
        .onAppear(perform: {
            fanViewModel.refresh()
        })
    }
    
    init (addr: String, chars: FanCharacteristics, allFans fans: Binding<Set<FanCharacteristics>>, runningFans running: Binding<Set<FanCharacteristics>>) {
        _fanAddrs = fans
        _runningFans = running
        let mod = FanModel(forAddress: addr, usingChars: chars)
        _fanViewModel = StateObject(wrappedValue: FanViewModel(forModel: mod))
        _name = AppStorage<String?>(chars.macAddr)
    }
}

struct SpeedController: View {
    @Binding var displayedSegmentNumber: Int
    @Binding var controllerSegments: [String]
    @Binding var showPhysicalSpeedIndicator: Bool
    @Binding var bladeColor: UIColor
    @Binding var physicalFanSpeed: Int?
    
    var body: some View {
            Picker (selection: $displayedSegmentNumber, label: Text("Picker")) {
                ForEach (0..<controllerSegments.count, id: \.self) { segmentIndex in
                    Text(controllerSegments[segmentIndex]).tag(segmentIndex)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .modifier(PhysicalSpeedIndicator(showPhysicalSpeedIndicator: $showPhysicalSpeedIndicator, bladeColor: $bladeColor, controllerSegments: $controllerSegments, physicalFanSpeed: $physicalFanSpeed))
    }
}

struct PhysicalSpeedIndicator: ViewModifier {
    @Binding var showPhysicalSpeedIndicator: Bool
    @Binding var bladeColor: UIColor
    @Binding var controllerSegments: [String]
    @Binding var physicalFanSpeed: Int?
    
    func body(content: Content) -> some View {
        content
            .overlay (
                showPhysicalSpeedIndicator ?
                GeometryReader { geo2 in
                    Image(systemName: "arrowtriangle.up.fill")
                        .resizable()
                        .foregroundColor(Color(bladeColor))
                        .alignmentGuide(.top, computeValue: { dimension in
                            -geo2.size.height + dimension.height/CGFloat(2)
                        })
                        .alignmentGuide(HorizontalAlignment.center, computeValue: { dimension in
                            let oneSegW = geo2.size.width/CGFloat(controllerSegments.count)
                            let offs = oneSegW/2.0 + (oneSegW * CGFloat(physicalFanSpeed ?? 0)) - dimension.width
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
    static var previews: some View {
        FanView(addr: "0.0.0.0:8181", chars: chars, allFans: $fans, runningFans: $runningFans)
    }
}
