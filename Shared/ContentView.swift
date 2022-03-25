//
//  ContentView.swift
//  Shared
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct ContentView: View {
    let houseView = HouseView()

    var body: some View {
        houseView
            .background(Color.background)
            .foregroundColor(.main)
    }
    
    init () {
        UISegmentedControl.appearance().selectedSegmentTintColor = .main
//        houseView = HouseView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
