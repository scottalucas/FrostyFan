//
//  Detail Sheet.swift
//  Fan with SwiftUI (iOS)
//
//  Created by Scott Lucas on 1/1/21.
//

import SwiftUI

struct DetailSheet: View {
    @ObservedObject var fanViewModel: FanViewModel
    
    var body: some View {
        Text("Detail sheet")
    }
}

struct DetailSheet_Previews: PreviewProvider {
    static var previews: some View {
        DetailSheet(fanViewModel: FanViewModel())
    }
}
