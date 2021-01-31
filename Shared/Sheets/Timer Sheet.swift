//
//  Timer Sheet.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/1/21.
//

import SwiftUI

struct TimerSheet: View {
    @Binding var hoursToAdd: Int
    var fanViewModel: FanViewModel
    var maxKeypresses: Int {
        13 - (Int(fanViewModel.timer/60) + (fanViewModel.timer%60 != 0 ? 1 : 0)) + 1
    }
    var offTimeMinutes: Int {
        fanViewModel.timer
    }
    var offDateText: String {
        fanViewModel.offDateTxt
    }
    
    var body: some View {
        ZStack {
            TimerSheetBackground(timeText: offDateText)
            VStack {
                if (maxKeypresses == 0) {
                    Color.background
                        .overlay(Text("Timer at maximum").font(.largeTitle).foregroundColor(Color.main))
                        .frame(width: nil, height: 60)
                } else if maxKeypresses == 1 {
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
        .onDisappear(perform: {
            if hoursToAdd != 0 {
                fanViewModel.model.setFan(addHours: hoursToAdd)
            }
        })
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
    var timeText: String
    var body: some View {
        ZStack {
            Color.main
                .ignoresSafeArea()
            VStack (alignment: .center, spacing: 0) {
                HStack (alignment: .firstTextBaseline) {
                    Text("Timer").font(.largeTitle)
                        .foregroundColor(Color.background)
                    Spacer()
                    Text (timeText).foregroundColor(Color.background)
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
//            TimerSheet(fanViewModel: FanViewModel())
            TimerSheetBackground(timeText: "10:03 PM")
        }
    }
}
