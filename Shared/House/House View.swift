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
        
        TabView (selection: $currentTab) {
            ZStack {
                VStack {
                    RefreshableScrollView(height: 40, refreshing: $viewModel.scanning) {}
                        .frame(width: nil, height: 75, alignment: .top)
                    Spacer()
                }
                VStack {
                    FanViewPageContainer(viewModel: viewModel)
                        .ignoresSafeArea(.container, edges: .top)
                    Spacer()
                }
            }
//            .fixedSize(horizontal: false, vertical: true)
            .tabItem {
                Image.fanIcon
                Text(viewModel.scanning ? "Scanning" : "Fan")
            }
            .tag(1)
//            .accentColor(Color.main)
            
            Text("")
                .tabItem {
                    Image.bell
                    Text("Alarms")
                }
                .tag(2)
//                .accentColor(Color.main)
        }
        .accentColor(.main)
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
        } else if viewModel.fanModels.count == 1 {
            viewModel.fanModels.first!
                .getView()
                .padding(.bottom, 35)
        } else {
            TabView (selection: $selectedFan) {
                ForEach (viewModel.fanModels) { fanModel in
                    fanModel
                        .getView()
                        .padding(.bottom, 100)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
    }
}

struct HouseViewPreviews: PreviewProvider {
    static var previews: some View {
        HouseView(viewModel: TestHouseViewModel(testFans: [FanModel()]))
    }
}
