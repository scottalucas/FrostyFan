//
//  Timer Sheet.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/1/21.
//

import SwiftUI
//(initialValue: String, key: String)
struct TimerSheet: View {
    @State var wheelPosition = Int.zero
    @Binding var activeSheet: OverlaySheet?
    var viewModel: FanViewModel
    var timeOnTimer: Int
    var offText: String = ""
//    var fanViewModel: FanViewModel
    var maxKeypresses: Int {
        13 - (Int(timeOnTimer/60) + (timeOnTimer%60 != 0 ? 1 : 0))
    }
    //    var offTimeMinutes: Int {
    //        timeOnTimer
    //    }
    //    var offDateText: String {
    ////        fanViewModel.offDateTxt
    //        return "test"
    //    }
    
    var body: some View {
        ZStack {
//            Color.main.ignoresSafeArea()
            //                TimerSheetBackground(timeText: offText)
            VStack {
                if (maxKeypresses == 0) {
                    Color.pageBackground
                        .overlay(Text("Timer at maximum").font(.largeTitle).foregroundColor(Color.main))
                        .frame(width: nil, height: 60)
                } else if maxKeypresses == 1 {
                    Color.pageBackground
                        .overlay(Button(action: { wheelPosition = 1 }) {
                            Text("Set to 12 hours").font(.largeTitle).foregroundColor(Color.main)
                        })
                        .frame(width: nil, height: 60)
                } else {
                    TimerSheetSpinner(hoursToAdd: $wheelPosition, maxKeypresses: maxKeypresses)
                        .background(Color.pageBackground)
                        .pickerStyle(.wheel)
                }
            }
            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel", action: {
//                        activeSheet = nil
//                    })
//                }
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Confirm", action: {
//                        fanViewModel.setTimer(addHours: wheelPosition)
//                        activeSheet = nil
//                    })
//                }
                ToolbarItem(placement: .principal) {
                    VStack (alignment: .center, spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            Button("Cancel", action: {
                                activeSheet = nil
                            })
                            Spacer()
                            Text("Timer").font(.title)
                            Spacer()
                            Button("Confirm", action: {
                                viewModel.setTimer(addHours: wheelPosition)
                                activeSheet = nil
                            })
                        }
                        Divider()
                            .background(Color.main)
                            .ignoresSafeArea(.all, edges: [.leading, .trailing])
                        Spacer()
                    }
                    .foregroundColor(.main)
                }
            }
            .navigationBarBackButtonHidden(true)
            .background(Color.main)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding()
            .shadow(radius: /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
            
            .foregroundColor(.pageBackground)
            .onAppear(perform: {
                wheelPosition = .zero
            })
        }
    }
}

struct TimerPickerDataSource {
    struct Element: Identifiable {
        var id: Int
        var text: String
    }
    var pressRange: Range<Int>
    var elements: [Element] {
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

struct TimerSheetSpinner: View {
    @Binding var hoursToAdd: Int
    var maxKeypresses: Int
    
    var body: some View {
        Picker(selection: $hoursToAdd, label: Text("Picker")) {
            ForEach(TimerPickerDataSource(pressRange: (0..<maxKeypresses)).elements, id: \.id) { element in
                HStack {
                    Text(element.text).tag(element.id)
                        .foregroundColor(.pageBackground)
                }
            }
        }
        .foregroundColor(.green)
    }
}

struct Timer_View_Previews: PreviewProvider {
    static var previews: some View {
        //        VStack {
        //            TimerSheet(fanViewModel: FanViewModel())
        NavigationView {
            TimerSheet(activeSheet: .constant(nil), viewModel: FanViewModel(), timeOnTimer: 0)
                .preferredColorScheme(.light)
        }
    }
}
