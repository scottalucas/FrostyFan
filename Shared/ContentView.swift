//
//  ContentView.swift
//  Shared
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct ContentView: View {

    var body: some View {
        HouseView()
            .background(Color.background)
            .foregroundColor(.main)

    }
    
    init () {
        UISegmentedControl.appearance().selectedSegmentTintColor = .main
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
