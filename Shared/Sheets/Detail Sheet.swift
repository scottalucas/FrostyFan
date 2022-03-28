//
//  Detail Sheet.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/1/21.
//

import SwiftUI

struct DetailSheet: View {
    @Binding var activeSheet: OverlaySheet?
    var data = [DetailSheetEntry]()
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                LazyVGrid(columns: columns, alignment: .leading, spacing: 20, pinnedViews: []) {
                    ForEach(data, id: \.self) { item in
                        item
                            .lineLimit(1)
                            .truncationMode(.head)
                            .foregroundColor(.background)
                    }
                }
                .padding(.horizontal)
                Button ("Print Defaults", action: {
                    let macAddr = data.first(where: {
                        $0.label == "MAC Address"
                    })?.value
                    Storage.printAll(forAddr: macAddr)
                })
                    .foregroundColor(.background)
                Button ("Clear Defaults", action: {
                    Storage.clear()
                })
                    .foregroundColor(.background)
                Spacer()
            }
            .background (Color.main)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack (alignment: .center, spacing: 0) {
                        HStack (alignment: .firstTextBaseline) {
                            Button("Back") {
                                activeSheet = nil
                            }
                            Spacer()
                            Text("Fan Details").font(.largeTitle)
                        }
                        Divider()
                            .background(Color.background)
                            .ignoresSafeArea(.all, edges: [.leading, .trailing])
                        Spacer()
                    }
                    .foregroundColor(.background)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    init (activeSheet: Binding<OverlaySheet?>, chars: FanCharacteristics ) {
        _activeSheet = activeSheet
        data = chars.labelValueDictionary
            .sorted(by: { $0.0 < $1.0 })
            .map { (key, value) in DetailSheetEntry(label: key, value: value) }
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
        c.speed = 4
    return c
    }
    static var previews: some View {
        NavigationView {
            DetailSheet(activeSheet: .constant(.detail), chars: chars)
        }

//        DetailSheetEntry(label: "Speed", value: "10")
//            .padding()
//            .background(Color.main)
    }
}
