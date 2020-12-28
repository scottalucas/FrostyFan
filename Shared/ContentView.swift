//
//  ContentView.swift
//  Shared
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        House.shared.getView()
    }
    
    init () {
        let app = UISegmentedControl.appearance()
        app.backgroundColor = .background
        app.selectedSegmentTintColor = .main
        app.setTitleTextAttributes([.foregroundColor: UIColor.main], for: .normal)
        app.setTitleTextAttributes([.foregroundColor: UIColor.background], for: .selected)
        House.shared.fansAt.insert("0.0.0.0:8181")
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
