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
                            .lineLimit(1)
                            .truncationMode(.head)
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
        c.speed = 4
    return c
    }
    static var previews: some View {
        
        DetailSheet(chars: chars)

//        DetailSheetEntry(label: "Speed", value: "10")
//            .padding()
//            .background(Color.main)
    }
}
