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
    @AppStorage(Setting.fans) private var fanSettings = FanSettings()
    
    enum Sheet: Identifiable {
        var id: Int {
            hashValue
        }
        
        case fanName
        case timer
        case detail
        
        func view(viewModel: FanViewModel) -> AnyView {
            switch self {
            case .fanName:
                return NameSheet(fanViewModel: viewModel).eraseToAnyView()
            case .timer:
                return TimerSheet(fanViewModel: viewModel).eraseToAnyView()
            case .detail:
                return DetailSheet(fanViewModel: viewModel).eraseToAnyView()
            }
        }
    }
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                Text( fanViewModel.testText ?? "No text" )
                Button(
                    action: {
                        activeSheet = .timer
                }, label: {
                Image.timer
                    .resizable()
                    .foregroundColor(.main)
                    .scaledToFit()
                    .frame(width: nil, height: 40)
                    .padding(.bottom, 15)
                })
                SpeedController(viewModel: fanViewModel)
                    .padding([.leading, .trailing], 20)
            }
            .zIndex(/*@START_MENU_TOKEN@*/1.0/*@END_MENU_TOKEN@*/)
            VStack {
                Image.fanLarge
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .rotationEffect(angle)
                    .foregroundColor(Color.main)
                    .opacity(/*@START_MENU_TOKEN@*/0.8/*@END_MENU_TOKEN@*/)
                    .blur(radius: 10.0)
                    .scaleEffect(1.5)
                    .onTapGesture {
                        activeSheet = .detail
                    }
                    .overlay(
                        VStack (alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: 0) {
                            HStack {
                                Text(fanViewModel.name).font(.largeTitle)
                                    .onLongPressGesture {
                                        activeSheet = .fanName
                                    }
                                Spacer()
                            }
                            Divider().frame(width: nil, height: 1, alignment: .center).background(Color.main)
                            Spacer()
                        }
                        .padding()
                    )
                Spacer()
            }
            .zIndex(2)
        }
//        .sheet(item: $activeSheet, content: { $0.view(viewModel: fanViewModel) })
        .sheet(item: $activeSheet, onDismiss: { indicator = true }, content: { $0.view(viewModel: fanViewModel) })
        .onReceive(fanViewModel.$fanRotationDuration) { val in
            self.angle = .zero
            withAnimation(Animation.linear(duration: val)) {
                self.angle = .degrees(179.99)
            }
        }
    }
    
    init(fanViewModel: FanViewModel) {
        self.fanViewModel = fanViewModel
    }
}

struct SpeedController: View {
    @ObservedObject private var viewModel: FanViewModel
    @State private var userSelected: Bool = true
    @State private var pickerSelection: Int = -1
    
    var body: some View {
        VStack {
            Picker (selection: $viewModel.displayedSegmentNumber, label: Text("Picker")) {
                ForEach ((0..<viewModel.controllerSegments.count), id: \.self) { segmentIndex in
                    Text(viewModel.controllerSegments[segmentIndex]).tag(segmentIndex)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    init(viewModel: FanViewModel) {
        self.viewModel = viewModel
    }
}

struct FanView_Previews: PreviewProvider {
    static var previews: some View {
        FanView(fanViewModel: FanViewModel())
    }
}
