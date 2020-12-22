//
//  ContentView.swift
//  Shared
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TestHouse().getView()
    }
    
    init () {
        let app = UISegmentedControl.appearance()
        app.backgroundColor = .background
        app.selectedSegmentTintColor = .main
        app.setTitleTextAttributes([.foregroundColor: UIColor.main], for: .normal)
        app.setTitleTextAttributes([.foregroundColor: UIColor.background], for: .selected)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
