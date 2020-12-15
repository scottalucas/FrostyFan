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
    @State private var visBase: Bool = false
    private var vis: Bool { get {
        return visBase
    } set {
        guard newValue != visBase else {return}
        visBase = newValue
        print("Set new value")
    }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack {
                    Spacer()
                    Button("Hit me", action: {
                        fanViewModel.update(msg: 1)
                    })
                    Text("Speed: \(fanViewModel.fanRotationDuration)")
                    Text("Mac: \(fanViewModel.model.macAddr ?? "Not found")")
                    Text("Name \(fanViewModel.name)")
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
            .frame(width: nil, height: (geo.size.height - 50) < 0 ? 0 : geo.size.height - 50, alignment: .bottom)
        }
        .onReceive(fanViewModel.$fanRotationDuration, perform: { val in
            withAnimation(.linear(duration: 0)) { self.angle = .zero }
            withAnimation(Animation.linear(duration: val).repeatForever(autoreverses: false)) {
                self.angle += .degrees(360.0/6.0)
            }
        })
    }
    init(fanViewModel: FanViewModel) {
        self.fanViewModel = fanViewModel
//        fanViewModel.update()
    }
}

struct FanView_Previews: PreviewProvider {
    static var previews: some View {
            FanView(fanViewModel: FanViewModel())
    }
}
