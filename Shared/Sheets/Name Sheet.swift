//
//  Detail Sheet.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/1/21.
//

import SwiftUI

struct NameSheet: View {
    @AppStorage var name: String
    @Binding var activeSheet: OverlaySheet?
    @State private var newName = "new name"
    var body: some View {
        ZStack {
            Color.pageBackground.ignoresSafeArea()
            VStack {
                Spacer()
                TextField("", text: $newName)
                    .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                    .padding(.horizontal, 20)
                    .padding(/*@START_MENU_TOKEN@*/.vertical/*@END_MENU_TOKEN@*/, 5)
                    .background(Color.main)
                    .foregroundColor(.pageBackground)
                    .clipShape(Capsule())
                    .shadow(radius: 10)
//                    .padding(.horizontal, 20)
                Text("Current name is \" \(name)\"").font(.italic(.body)())
                    .padding(.top, 4)
                    .foregroundColor(.main)
                Spacer()
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(alignment: .center, spacing: 0) {
                    HStack (alignment: .firstTextBaseline) {
                        Button("Cancel") {
                            activeSheet = nil
                        }
                        Spacer()
                        Text("Update Name")
                            .font(.largeTitle)
                            .foregroundColor(.main)
                        Spacer()
                        Button("Confirm") {
                            name = newName
                            activeSheet = nil
                        }
                    }
                    Divider()
                        .ignoresSafeArea(.all, edges: [.leading, .trailing])
                        .background(Color.main)
                    Spacer()
                }
                .foregroundColor(.main)
            }
        }
            .navigationBarBackButtonHidden(true)
        
     }
    
    init (sheet: Binding<OverlaySheet?>, storageKey: StorageKey) {
        _activeSheet = sheet
        _name = AppStorage(wrappedValue: "Name", storageKey.rawValue)
    }
}

struct NameSheet_Previews: PreviewProvider {
    static var house = HouseViewModel(initialFans: [])
    static var myModel: FanViewModel {
//        let testModel = FanModel()
//        testModel.fanCharacteristics.labelValueDictionary = ["DIP Switch": "11110", "Model": "3.5e", "DNS": "192.168.1.254", "Damper": "Not operating", "Remote Switch": "1111", "Interlock 1": "Not active", "IP Address": "not found", "Setpoint": "0", "Attic Temp": "85˚", "Airflow": "0 cfm", "Power": "0", "MAC Address": "BE:EF:BE:EF:BE:EF", "Inside Temp": "72˚", "Software version": "2.15.1", "Interlock 2": "Not active", "Timer": "0", "Speed": "0", "Outside Temp": "-99"]
        return FanViewModel()
    }
    
    static var previews: some View {
        NavigationView {
            NameSheet(sheet: .constant(.fanName), storageKey: .fanName("String"))
                .preferredColorScheme(.dark)
            
        }

//        DetailSheetEntry(label: "Speed", value: "10")
//            .padding()
//            .background(Color.main)
    }
}
