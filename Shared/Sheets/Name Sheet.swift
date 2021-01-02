//
//  Name Sheet.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/1/21.
//

import SwiftUI

struct NameSheet: View {
    @ObservedObject var fanViewModel: FanViewModel

    var body: some View {
        Text("name sheet")
    }
}

struct NameSheet_Previews: PreviewProvider {
    static var previews: some View {
        NameSheet(fanViewModel: FanViewModel())
    }
}
