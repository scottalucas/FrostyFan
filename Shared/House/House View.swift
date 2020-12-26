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
    
    var body: some View {
        TabView (selection: $currentTab)
        {
            VStack {
                FanViewPageContainer(viewModel: viewModel)
                Text("Weather info")
                Spacer()
                }
            .tabItem {
                Image.fanIcon
                Text("Fan")
            }
                .tag(1)
            
            Text("Connect")
                .tabItem {
                    Image.network
                    Text("Connect")
                }
                .tag(2)
            
            Text("Alarms")
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
                ForEach (0..<viewModel.fanModels.count) { fanModelIndex in
                    viewModel.fanModels[fanModelIndex]
                        .getView()
                        .padding([.bottom], viewModel.fanModels.count == 0 ? 0 : 100)
                        .tag(fanModelIndex)
                }
            }
            .onChange(of: selectedFan) { fanIndex in
                viewModel.fanModels[fanIndex].setFan() //might not need to do this if the fan model's getting reint'd every time we change pages
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .ignoresSafeArea(.all, edges: [.top])
        }
    }
}

struct HouseViewPreviews: PreviewProvider {
    static var previews: some View {
//        FanViewPageContainer(viewModel: TestHouseViewModel(withHouse: TestHouse()))
        HouseView(viewModel: TestHouseViewModel(withHouse: TestHouse()))
    }
}
