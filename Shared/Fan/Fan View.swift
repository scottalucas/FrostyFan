//
//  Fan View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct FanView: View {
    @ObservedObject var fanViewModel: FanViewModel
//    @State private var displayedSpeed: Int = 0
    @State private var angle: Angle = .zero
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack {
                    Group {
                        Spacer()
                        Spacer()
                        Spacer()
                        Spacer()
                    }
                    Text("Mac: \(fanViewModel.macAddr ?? "Not found")")
                    Text("Name: \(fanViewModel.name)")
                    Text("Level: \(fanViewModel.displayedSegmentNumber.description)")
                    SpeedController(viewModel: fanViewModel)
                        .padding([.leading, .trailing], 20)
                    Spacer ()
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
                    Spacer()
                }
                .zIndex(0)
            }
        }
        .onReceive(fanViewModel.$fanRotationDuration) { val in
            self.angle = .zero
//            withAnimation(.linear(duration: 0)) { self.angle = .zero } //needed to stop previous animation
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
                    Text(viewModel.controllerSegments[segmentIndex])
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
