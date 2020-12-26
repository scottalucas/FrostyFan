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
                    Spacer()
                    Text("Speed: \(fanViewModel.fanRotationDuration)")
                    Text("Mac: \(fanViewModel.macAddr ?? "Not found")")
                    Text("Name: \(fanViewModel.name)")
                    Text("Level: \(fanViewModel.actualSpeed.description)")
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
                    Spacer()
                }
            }
        }
//        .onChange(of: displayedSpeed) { item in
////            fanViewModel.displayedSpeedChange(to: self.displayedSpeed)
//            print ("Displayed: \(self.displayedSpeed) Item: \(item)")
//        }
        .onReceive(fanViewModel.$fanRotationDuration) { val in
            withAnimation(.linear(duration: 0)) { self.angle = .zero } //needed to stop previous animation
            withAnimation(Animation.linear(duration: val).repeatForever(autoreverses: false)) {
                self.angle += .degrees(360.0/6.0)
            }
        }
//        .onReceive(fanViewModel.$actualSpeed) { spd in
//            if !fanViewModel.speedIsAdjusting { displayedSpeed = spd ?? displayedSpeed}
//        }
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
            Picker (selection: $pickerSelection, label: Text("Picker")) {
                ForEach ((0..<viewModel.controllerSegments.count), id: \.self) { segmentIndex in
                    Text(viewModel.controllerSegments[segmentIndex])
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: pickerSelection) { value in
//                print("On change \(value)")
                if userSelected {
                    print("Setting speed to \(value)")
                    viewModel.setFan(toSpeed: value)                }
            }
            .onReceive(viewModel.$actualSpeed) { newSpd in
//                print("On receive new \(newSpd.description), current \(pickerSelection)")
                userSelected = false
                pickerSelection = newSpd
                Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
                    userSelected = true
                }
            }
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
