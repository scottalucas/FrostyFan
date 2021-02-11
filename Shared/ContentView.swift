//
//  ContentView.swift
//  Shared
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HouseView()
            .background(Color.background)
    }
    
    init () {
        let app = UISegmentedControl.appearance()
        app.backgroundColor = .controlsBackground
        app.selectedSegmentTintColor = .controlsTint
        app.setTitleTextAttributes([.foregroundColor: UIColor.controlsTint], for: .normal)
        app.setTitleTextAttributes([.foregroundColor: UIColor.segmentControllerBackground], for: .selected)
//        House.shared.fansAt.insert(FanModel())
//        Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
//            House.shared.lostFan(atIp: "0.0.0.0:8181")
//        }
//        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
//            House.shared.fansAt.update (with: "0.0.0.0:8181")
//        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
