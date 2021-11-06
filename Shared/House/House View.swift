//
//  House View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct HouseView: View {
    typealias IPAddr = String
//    @EnvironmentObject var weather: Weather
    @StateObject var viewModel = HouseViewModel()
    @EnvironmentObject private var house: House
    @State private var currentTab: Int = 0
    @State private var info: String = ""
    @State private var fanLabel: String = "Fan"
    
    var body: some View {
        TabView (selection: $currentTab) {
            FanViewPageContainer(viewModel: viewModel, weather: Weather())
                .ignoresSafeArea(.container, edges: [.top])
                .padding(.top, house.isRefreshing ? 10 : 0)
                .pulldownRefresh()
                .tabItem {
                    Image.fanIcon
                    Text(viewModel.indicators.contains(.showScanningSpinner) ? "Scanning" : "Fan")
                }
                .tag(1)
            SettingsView()
                .tabItem {
                    Image.bell
                    Text("Alarms")
                }
                .tag(2)
        }
        .accentColor(.main)
        .onAppear {
//            house.scan()
        }
    }
}

struct FanViewPageContainer: View {
    typealias IPAddr = String
    @ObservedObject var viewModel: HouseViewModel
    @ObservedObject var weather: Weather
//    @Binding var refreshing: Bool
//    var pullDownSize: CGSize
    @State private var selectedFan: Int = 0
    
    var body: some View {
        if viewModel.fanViews.count == 0 {
                NoFanView()
        } else if viewModel.fanViews.count == 1 {
            viewModel.fanViews.first!
                .padding(.bottom, 35)
        } else {
            TabView (selection: $selectedFan) {
                ForEach (Array(viewModel.fanViews)) { view in
                    view
                        .padding(.bottom, 75)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
    }
}

struct HouseViewPreviews: PreviewProvider {
    static var previews: some View {
        HouseView()
            .preferredColorScheme(.dark)
            .environmentObject(House())
//            .environmentObject(Weather())
        
    }
}
