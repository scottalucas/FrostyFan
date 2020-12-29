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
    
    var body: some View {
        TabView (selection: $currentTab)
        {
            ZStack {
                VStack {
                    RefreshableScrollView(refreshing: $viewModel.scanning) {}
                        .frame(width: nil, height: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, alignment: .top)
                    Spacer()
                }
                .zIndex(2)
                FanViewPageContainer(viewModel: viewModel)
                    .zIndex(/*@START_MENU_TOKEN@*/1.0/*@END_MENU_TOKEN@*/)
            }
            .tabItem {
                Image.fanIcon
                Text("Fan")
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
        .accentColor(Color.main)
    }
    
    init (viewModel: HouseViewModel) {
        self.viewModel = viewModel
        //        viewModel.fanModels.forEach({ $0.update() })
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
        //        FanViewPageContainer(viewModel: TestHouseViewModel(withHouse: TestHouse()))
        HouseView(viewModel: TestHouseViewModel())
    }
}
