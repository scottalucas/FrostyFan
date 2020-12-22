//
//  Utilities.swift
//  whf001
//
//  Created by Scott Lucas on 12/10/20.
//

import Foundation
import SwiftUI
import Combine

extension Image {
    static var fanLarge = Image("fanLarge")
    static var fanIcon = Image("fanIcon")
    static var flame = Image(systemName: "flame.fill")
    static var interlock = Image(systemName: "wind")
    static var leaf = Image(systemName: "leaf.arrow.circlepath")
    static var network = Image(systemName: "link")
    static var question = Image(systemName: "questionmark")
    static var settings = Image(systemName: "gear")
    static var speed = Image(systemName: "speedometer")
    static var thermometer = Image(systemName: "thermometer")
    static var timer = Image(systemName: "timer")
    static var rainDrops =  Image(systemName: "cloud.sun")
    static var bell = Image(systemName: "bell")
}

extension UIColor {
    static var main = #colorLiteral(red: 0.2745098174, green: 0.4862745106, blue: 0.1411764771, alpha: 1)
    static var alarm = #colorLiteral(red: 0.5725490451, green: 0, blue: 0.2313725501, alpha: 1)
    static var background = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
}

extension Color {
    static var main = Color(UIColor.main)
    static var alarm = Color(UIColor.alarm)
    static var background = Color(UIColor.background)
}

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

struct UserSettings {
    private let defaults = UserDefaults.standard
    var names = [String:String]()
    init () {
        guard let n = defaults.object(forKey: "names"), let names = n as? [String:String] else { return }
        self.names = names
    }
    
    mutating func setName(forMacAddr addr: String, toName name: String) {
        names[addr] = name
        defaults.setValue(names, forKey: "names")
    }
}

struct Utilities_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            VStack {
                Image.fanLarge
                Spacer()
                Image.fanIcon
                Image.interlock
                Image.leaf
                Image.network
                Image.question
                Image.bell
                Image.flame
            }
            Spacer ()
            VStack {
                Spacer ()
                Image.settings
                Image.speed
                Image.thermometer
                Image.timer
                Image.rainDrops
                Color.main
                    .frame(width: 25, height: 25, alignment: .center)
            }
            Spacer()
        }
    }
}
