//
//  House View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct HouseView: View {
    @ObservedObject var viewModel: HouseViewModel
    @State var currentTab: Int = 0
    @State var info: String = ""
    @State private var tap: Bool = false
    @State private var fanLabel: String?
    
    var body: some View {

        ZStack {
            VStack {
                RefreshableScrollView(height: 40, refreshing: $viewModel.scanning) {}
                    .frame(width: nil, height: 75, alignment: .top)
                Spacer()
            }
            .ignoresSafeArea(.container, edges: .top)
            .zIndex(3)
            TabView (selection: $currentTab)
            {
                FanViewPageContainer(viewModel: viewModel)
                    .tabItem {
                        Image.fanIcon
                        Text(viewModel.scanning ? "Scanning" : "Fan")
                    }
                    .tag(1)
                Text("")
                    .tabItem {
                        Image.timer
                        Text("Timer")
                    }
                    .tag(2)
                Text("")
                    .tabItem {
                        Image.bell
                        Text("Alarms")
                    }
                    .tag(3)
            }
            .zIndex(2)
        }
        .accentColor(Color.main)
    }
    
    init (viewModel: HouseViewModel) {
        self.viewModel = viewModel
    }
}

struct FanViewPageContainer: View {
    @ObservedObject var viewModel: HouseViewModel
    @State private var selectedFan: Int = 0
    
    var body: some View {
        if viewModel.fanModels.count == 0 {
            Text("No fans connected")
        } else {
            TabView (selection: $selectedFan) {
                ForEach (0..<viewModel.fanModels.count, id: \.self) { fanModelIndex in
                    viewModel.fanModels[fanModelIndex]
                        .getView()
                        .padding(.bottom, viewModel.fanModels.count > 1 ? 100 : 65)
                        .tag(fanModelIndex)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .ignoresSafeArea(.container, edges: [.top])
        }
    }
}

struct HouseViewPreviews: PreviewProvider {
    static var previews: some View {
        HouseView(viewModel: TestHouseViewModel(testFans: ["0.0.0.0:8181"]))
    }
}
