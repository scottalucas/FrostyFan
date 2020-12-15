//
//  Utilities.swift
//  whf001
//
//  Created by Scott Lucas on 12/10/20.
//

import Foundation
import SwiftUI
import Combine

struct ViewPrimitive {
    struct Icon {
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
    struct AppColor {
        struct Main {
            static var ui = #colorLiteral(red: 0.2745098174, green: 0.4862745106, blue: 0.1411764771, alpha: 1)
            static var view = Color(ui)
        }
        struct Alarm {
            static var ui = #colorLiteral(red: 0.5725490451, green: 0, blue: 0.2313725501, alpha: 1)
            static var view = Color(ui)
        }
        struct Background {
            static var ui = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            static var view = Color(ui)
        }
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
                ViewPrimitive.Icon.fanLarge
                Spacer()
                ViewPrimitive.Icon.fanIcon
                ViewPrimitive.Icon.interlock
                ViewPrimitive.Icon.leaf
                ViewPrimitive.Icon.network
                ViewPrimitive.Icon.question
                ViewPrimitive.Icon.bell
                ViewPrimitive.Icon.flame
            }
            Spacer ()
            VStack {
                Spacer ()
                ViewPrimitive.Icon.settings
                ViewPrimitive.Icon.speed
                ViewPrimitive.Icon.thermometer
                ViewPrimitive.Icon.timer
                ViewPrimitive.Icon.rainDrops
                ViewPrimitive.AppColor.Main.view
                    .frame(width: 25, height: 25, alignment: .center)
            }
            Spacer()
        }
    }
}

extension View {
    func animate(using animation: Animation = Animation.easeInOut(duration: 1), _ action: @escaping () -> Void) -> some View {
        return onAppear {
            withAnimation(animation) {
                action()
            }
        }
    }
}

extension View {
    func animateForever(using animation: Animation = Animation.easeInOut(duration: 1), autoreverses: Bool = false, _ action: @escaping () -> Void) -> some View {
        let repeated = animation.repeatForever(autoreverses: autoreverses)

        return onAppear {
            withAnimation(repeated) {
                action()
            }
        }
    }
}

extension View {
    func animatableDuration(duration: Double) -> some View {
        self.modifier(AnimatableCustomDurationModifier(duration: duration))
    }
}

struct AnimatableCustomDurationModifier: AnimatableModifier {
    var duration: Double
    @State var rotation: Angle = .zero
    
    var animatableData: Double {
        get { duration }
        set { duration = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .animation(nil)
            .rotationEffect(rotation)
            .animate(using: Animation.linear(duration: duration).repeatForever(autoreverses: false)) {
                self.rotation = .degrees(360.0/6.0)
            }
    }
}
