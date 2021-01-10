//
//  Fan View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct FanView: View {
    @ObservedObject var fanViewModel: FanViewModel
    @State private var angle: Angle = .zero
    @State private var indicator: Bool = false
    @State private var activeSheet: Sheet?
    @State private var hoursToAdd: Int = 0
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
                SpeedController(viewModel: fanViewModel)
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
                        Button(
                            action: {
                            fanViewModel.refresh()
                            activeSheet = .detail
                        },
                            label: {
                            if fanViewModel.alarmCondition.isEmpty {
                                Color.clear.eraseToAnyView()
                            } else {
                                ForEach (Alarm.labels(forOptions: fanViewModel.alarmCondition), id: \.self) { item in
                                    Text(item).foregroundColor(.alarm)
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
                    Text(fanViewModel.name).font(.largeTitle).foregroundColor(.main)
                        .onLongPressGesture {
                            activeSheet = .fanName
                        }
                    Spacer()
                }
                Divider().frame(width: nil, height: 1, alignment: .center).background(Color.main)
                Spacer()
            }
            .padding([.leading, .trailing], 20.0)
        }
        .sheet(item: $activeSheet, onDismiss: { indicator = true }, content: { $0.view(view: self) })
        .onReceive(fanViewModel.$fanRotationDuration) { val in
            self.angle = .zero
            withAnimation(Animation.linear(duration: val)) {
                self.angle = .degrees(179.99)
            }
        }
//        .onAppear(perform: {
//            fanViewModel.refresh()
//        })
    }
    
    init(fanViewModel: FanViewModel) {
        self.fanViewModel = fanViewModel
    }
}

struct SpeedController: View {
    @ObservedObject private var viewModel: FanViewModel
    
    var body: some View {
            Picker (selection: $viewModel.displayedSegmentNumber, label: Text("Picker")) {
                ForEach (0..<viewModel.controllerSegments.count) { segmentIndex in
                    Text(viewModel.controllerSegments[segmentIndex]).tag(segmentIndex)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .modifier(PhysicalSpeedIndicator(viewModel: viewModel))
    }
    
    init(viewModel: FanViewModel) {
        self.viewModel = viewModel
    }
}

struct Title: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.largeTitle)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct PhysicalSpeedIndicator: ViewModifier {
    
    @ObservedObject var viewModel: FanViewModel
    
    func body(content: Content) -> some View {
        content
            .overlay (
                viewModel.showPhysicalSpeedIndicator ?
                GeometryReader { geo2 in
                    Image(systemName: "arrowtriangle.up.fill")
                        .resizable()
                        .foregroundColor(Color(viewModel.bladeColor))
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
    static var previews: some View {
        FanView(fanViewModel: FanViewModel())
    }
}
