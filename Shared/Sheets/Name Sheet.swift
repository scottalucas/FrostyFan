//
//  Detail Sheet.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/1/21.
//

import SwiftUI

struct NameSheet: View {
    @ObservedObject var fanViewModel: FanViewModel
//    @State var newName: String
    @AppStorage var newName: String
    var body: some View {
        ZStack {
            NameSheetBackground(name: newName)
            VStack {
                Spacer()
                VStack (alignment: .leading, spacing: 8.0) {
                    HStack {
                        Spacer ()
                    }
                    TextField(newName, text: $newName)
                        .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                        .padding(.horizontal, 20)
                        .padding(/*@START_MENU_TOKEN@*/.vertical/*@END_MENU_TOKEN@*/, 5)
                        .background(Color.background)
                        .foregroundColor(.main)
                        .clipShape(RoundedRectangle(cornerRadius: /*@START_MENU_TOKEN@*/25.0/*@END_MENU_TOKEN@*/))
                        .shadow(radius: 10)
                        .padding(.horizontal, 20)
                }
                Spacer()
            }
        }
     }
    
    init (viewModel: FanViewModel) {
        fanViewModel = viewModel
        _newName = AppStorage(wrappedValue: viewModel.model.fanCharacteristics.airspaceFanModel, StorageKey.fanName(viewModel.model.fanCharacteristics.macAddr).key)
    }
}

struct NameSheetBackground: View {
    var name: String
    var body: some View {
        ZStack {
            Color.main
                .ignoresSafeArea()
            VStack (alignment: .center, spacing: 0) {
                HStack (alignment: .firstTextBaseline) {
                    Text("Fan Name").font(.largeTitle)
                    Spacer()
                    Text(name)
                }
                .foregroundColor(Color.background)
                Divider()
                    .frame(width: nil, height: 1, alignment: .center)
                    .background(Color.background)
                Spacer()
            }
            .padding()
        }
    }
}


struct NameSheet_Previews: PreviewProvider {
    static var house = House()
    static var myModel: FanViewModel {
//        let testModel = FanModel()
//        testModel.fanCharacteristics.labelValueDictionary = ["DIP Switch": "11110", "Model": "3.5e", "DNS": "192.168.1.254", "Damper": "Not operating", "Remote Switch": "1111", "Interlock 1": "Not active", "IP Address": "not found", "Setpoint": "0", "Attic Temp": "85˚", "Airflow": "0 cfm", "Power": "0", "MAC Address": "BE:EF:BE:EF:BE:EF", "Inside Temp": "72˚", "Software version": "2.15.1", "Interlock 2": "Not active", "Timer": "0", "Speed": "0", "Outside Temp": "-99"]
        return FanViewModel(atAddr: "0.0.0.0:8181", usingChars: FanCharacteristics(), inHouse: house, weather: Weather(house: house))
    }
    
    static var previews: some View {
        
        NameSheet(viewModel: myModel)
//        DetailSheetEntry(label: "Speed", value: "10")
//            .padding()
//            .background(Color.main)
    }
}
