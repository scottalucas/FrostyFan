//
//  Detail Sheet.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/1/21.
//

import SwiftUI

struct NameSheet: View {
    @AppStorage var name: String
    var body: some View {
        ZStack {
            NameSheetBackground(name: name)
            VStack {
                Spacer()
                VStack (alignment: .leading, spacing: 8.0) {
                    HStack {
                        Spacer ()
                    }
                    TextField(name, text: $name)
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
    
    init (storageKey: StorageKey) {
        _name = AppStorage(wrappedValue: "Name", storageKey.key)
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
    static var house = HouseViewModel()
    static var myModel: FanViewModel {
//        let testModel = FanModel()
//        testModel.fanCharacteristics.labelValueDictionary = ["DIP Switch": "11110", "Model": "3.5e", "DNS": "192.168.1.254", "Damper": "Not operating", "Remote Switch": "1111", "Interlock 1": "Not active", "IP Address": "not found", "Setpoint": "0", "Attic Temp": "85˚", "Airflow": "0 cfm", "Power": "0", "MAC Address": "BE:EF:BE:EF:BE:EF", "Inside Temp": "72˚", "Software version": "2.15.1", "Interlock 2": "Not active", "Timer": "0", "Speed": "0", "Outside Temp": "-99"]
        return FanViewModel()
    }
    
    static var previews: some View {
        
        NameSheet(storageKey: .fanName("String"))

//        DetailSheetEntry(label: "Speed", value: "10")
//            .padding()
//            .background(Color.main)
    }
}
