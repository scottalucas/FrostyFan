//
//  Detail Sheet.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/1/21.
//

import SwiftUI

struct DetailSheet: View {
    var data = [DetailSheetEntry]()
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            DetailSheetBackground()
            VStack {
                Spacer()
                LazyVGrid(columns: columns, alignment: .leading, spacing: 20, pinnedViews: []) {
                    ForEach(data, id: \.self) { item in
                            item
                                .foregroundColor(.background)
                        }
                    }
                    .padding(.horizontal)
                Spacer()
            }
        }
     }
    init (chars: FanCharacteristics) {
        data = chars.labelValueDictionary
            .sorted(by: { $0.0 < $1.0 })
            .map { (key, value) in DetailSheetEntry(label: key, value: value) }
    }
}

struct DetailSheetBackground: View {
    var body: some View {
        ZStack {
            Color.main
                .ignoresSafeArea()
            VStack (alignment: .center, spacing: 0) {
                HStack (alignment: .firstTextBaseline) {
                    Text("Fan Details").font(.largeTitle)
                        .foregroundColor(Color.background)
                    Spacer()
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

struct DetailSheetEntry: View, Hashable, Identifiable {
    var label: String
    var value: String
    var id: String { label }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(label)
    }
    
    var body: some View {
        VStack (alignment: .leading, spacing: 3.0) {
            Text(label)
                .font(/*@START_MENU_TOKEN@*/.title3/*@END_MENU_TOKEN@*/)
                .fontWeight(.bold)
                .shadow(radius: 10)
            Text(value).font(.body).fontWeight(.light).padding(.leading, 7.0)
        }
        .foregroundColor(.background)
    }
}

struct DetailSheet_Previews: PreviewProvider {
    static var chars: FanCharacteristics {
    var c = FanCharacteristics()
        c.labelValueDictionary = ["DIP Switch": "11110", "Model": "3.5e", "DNS": "192.168.1.254", "Damper": "Not operating", "Remote Switch": "1111", "Interlock 1": "Not active", "IP Address": "not found", "Setpoint": "0", "Attic Temp": "85˚", "Airflow": "0 cfm", "Power": "0", "MAC Address": "BE:EF:BE:EF:BE:EF", "Inside Temp": "72˚", "Software version": "2.15.1", "Interlock 2": "Not active", "Timer": "0", "Speed": "0", "Outside Temp": "-99"]
    return c
    }
    static var myModel: FanViewModel {
        let house = House()
        let weather = Weather(house: house)
        let testModel = FanModel()
        testModel.fanCharacteristics!.labelValueDictionary = ["DIP Switch": "11110", "Model": "3.5e", "DNS": "192.168.1.254", "Damper": "Not operating", "Remote Switch": "1111", "Interlock 1": "Not active", "IP Address": "not found", "Setpoint": "0", "Attic Temp": "85˚", "Airflow": "0 cfm", "Power": "0", "MAC Address": "BE:EF:BE:EF:BE:EF", "Inside Temp": "72˚", "Software version": "2.15.1", "Interlock 2": "Not active", "Timer": "0", "Speed": "0", "Outside Temp": "-99"]
        return FanViewModel(atAddr: "0.0.0.0:8181", usingChars: FanCharacteristics(), inHouse: house, weather: weather)
    }
    
    static var previews: some View {
        
        DetailSheet(chars: chars)

//        DetailSheetEntry(label: "Speed", value: "10")
//            .padding()
//            .background(Color.main)
    }
}
