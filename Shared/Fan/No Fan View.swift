//
//  No Fan View.swift
//  Fan with SwiftUI
//
//  Created by Scott Lucas on 11/5/21.
//
/*
A simple view that displays when there are no fans in the House.
 */

import SwiftUI

struct NoFanView: View {
    @StateObject var viewModel: NoFanViewModel
    var body: some View {
        Rectangle ()
            .foregroundColor(Color(.clear))
            .overlay (alignment: .center) {
                if viewModel.scanUntil > .now {
                    RefreshIndicator(scanUntil: $viewModel.scanUntil)
                        .tint(.main)
                } else {
                    Text(viewModel.houseMessage ?? "No fans found")
                }
            }
            .padding([.top, .bottom], 50)
    }
    init () {
        _viewModel = StateObject(wrappedValue: NoFanViewModel())
    }
}

struct No_Fan_View_Previews: PreviewProvider {

    static var previews: some View {
        NoFanView()
            .preferredColorScheme(.dark)
    }
}
