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
            FanViewPageContainer(viewModel: viewModel)
                .tabItem {
                    ViewPrimitive.Icon.fanIcon
                    Text("Fan")
                }
                .tag(1)
            
            Text("Connect")
                .tabItem {
                    ViewPrimitive.Icon.network
                    Text("Connect")
                }
                .tag(2)
            
            Text("Alarms")
                .tabItem {
                    ViewPrimitive.Icon.bell
                    Text("Alarms")
                }
                .tag(3)
        }
        .accentColor(ViewPrimitive.AppColor.Main.view)
    }
    
    init (viewModel: HouseViewModel) {
        self.viewModel = viewModel
        viewModel.refreshAllFans()
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
                        .padding([.bottom], viewModel.fanModels.count == 0 ? 0 : 40)
                        .tag(fanModelIndex)
                }
            }
            .onChange(of: selectedFan) { fan in
                viewModel.refreshFan(atIndex: fan)
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .ignoresSafeArea(.all, edges: [.top])
        }
    }
}

struct HouseViewPreviews: PreviewProvider {
    static var previews: some View {
        FanViewPageContainer(viewModel: TestHouseViewModel(withHouse: TestHouse()))
//        HouseView(viewModel: TestHouseViewModel(withHouse: TestHouse()))
    }
}
