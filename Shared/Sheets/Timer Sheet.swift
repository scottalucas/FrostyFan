//
//  Timer Sheet.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/1/21.
//

import SwiftUI

struct TimerSheet: View {
    @ObservedObject var fanViewModel: FanViewModel
    @State private var hoursToAdd: Int = 0
    private var minutes: String {
        String(format: "%02i", timeTester%60)
    }
    private var hours: String {
        Int(timeTester/60) == 0 ? String("00") : String(Int(timeTester/60))
    }
    @State var timeTester: Int = 601
    private var maxKeypresses: Int { 13 - (Int(timeTester/60) + (timeTester%60 != 0 ? 1 : 0)) + 1 }
//    private var maxTime: Int { 13 - (Int(fanViewModel.timer/60) + (fanViewModel.timer%60 != 0 ? 1 : 0)) }
    
    var body: some View {
        ZStack {
            TimerSheetBackground(timeRemaining: $timeTester)
            VStack {
                if (timeTester >= ( 12 * 60 )) {
                    Color.background
                        .overlay(Text("Timer at maximum").font(.largeTitle).foregroundColor(Color.main))
                        .frame(width: nil, height: 60)
                } else if timeTester > (11 * 60) {
                    Color.background
                        .overlay(Button(action: { hoursToAdd = 1 }) {
                            Text("Set to 12 hours").font(.largeTitle).foregroundColor(Color.main)
                        })
                        .frame(width: nil, height: 60)
                } else {
                    Picker(selection: $hoursToAdd, label: Text("Picker")) {
                        ForEach(TimerPickerDataSource(pressRange: (0..<maxKeypresses)).data, id: \.id) { element in
                            HStack {
                                Text(element.text).tag(element.id)
                            }
                        }
                    }
                    .background(Color.background)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding()
            .shadow(radius: /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
        }
    }
}

struct TimerPickerDataSource {
    struct Element: Identifiable {
        var id: Int
        var text: String
    }
    var pressRange: Range<Int>
    var data: [Element] {
        pressRange.map { idx in
            switch idx {
            case 0:
                return Element(id: idx, text: "Don't change")
            case let i where i == pressRange.max():
                return Element(id: idx, text: "Set to 12 hours")
            case 1:
                return Element(id: idx, text: "Add an hour")
            default:
                return Element(id: idx, text: "Add \(idx) hours")
            }
        }
    }
}

struct TimerSheetBackground: View {
    @Binding var timeRemaining: Int
    private var minutes: String {
        String(format: "%02i", timeRemaining%60)
    }
    private var hours: String {
        Int(timeRemaining/60) == 0 ? String("00") : String(Int(timeRemaining/60))
    }
    
    var body: some View {
        ZStack {
            Color.main
                .ignoresSafeArea()
            VStack (alignment: .center, spacing: 0) {
                HStack (alignment: .firstTextBaseline) {
                    Text("Timer").font(.largeTitle)
                        .foregroundColor(Color.background)
                    Spacer()
                    Text (timeRemaining > 0 ? "\(hours):\(minutes) remaining" : "")
                        .foregroundColor(Color.background)
                }
                Divider()
                    .frame(width: nil, height: 1, alignment: .center)
                    .background(Color.background)
                Spacer()
            }
            .padding()
        }
    }
}

struct Timer_View_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TimerSheet(fanViewModel: FanViewModel())
//            TimerSheetBackground()
        }
    }
}
