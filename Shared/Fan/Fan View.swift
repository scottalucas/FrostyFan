//
//  Fan View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct FanView: View {
    @ObservedObject var fanViewModel: FanViewModel
    @State private var displayedSpeed: Int = 0
    @State private var angle: Angle = .zero
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack {
                    Spacer()
                    Text("Speed: \(fanViewModel.fanRotationDuration)")
                    Text("Mac: \(fanViewModel.macAddr ?? "Not found")")
                    Text("Name: \(fanViewModel.name)")
                    Picker(selection: $displayedSpeed, label: Text("Speed")) {
                        ForEach (0..<(fanViewModel.speedLevels + 1), id: \.self) {spd in
                            if spd == 0 { Text("off") }
                            else if spd == fanViewModel.speedLevels { Text("full") }
                            else { Text ("\(spd)") }
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding([.leading, .trailing], 20)
                }
                .zIndex(/*@START_MENU_TOKEN@*/1.0/*@END_MENU_TOKEN@*/)
                VStack {
                    ViewPrimitive.Icon.fanLarge
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .rotationEffect(angle)
                        .foregroundColor(ViewPrimitive.AppColor.Main.view)
                        .opacity(/*@START_MENU_TOKEN@*/0.8/*@END_MENU_TOKEN@*/)
                        .blur(radius: 10.0)
                        .scaleEffect(1.5)
                    Spacer()
                }
            }
        }
        .onChange(of: displayedSpeed) { item in
            fanViewModel.displayedSpeedChange(to: self.displayedSpeed)
//            print ("Displayed: \(self.displayedSpeed) Item: \(item)")
        }
        .onReceive(fanViewModel.$fanRotationDuration) { val in
            withAnimation(.linear(duration: 0)) { self.angle = .zero } //needed to stop previous animation
            withAnimation(Animation.linear(duration: val).repeatForever(autoreverses: false)) {
                self.angle += .degrees(360.0/6.0)
            }
        }
        .onReceive(fanViewModel.$actualSpeed) { spd in
            if !fanViewModel.speedIsAdjusting { displayedSpeed = spd ?? displayedSpeed}
        }
    }
    
    init(fanViewModel: FanViewModel) {
        self.fanViewModel = fanViewModel
    }
}

struct FanView_Previews: PreviewProvider {
    static var previews: some View {
        FanView(fanViewModel: FanViewModel())
    }
}
