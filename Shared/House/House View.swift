//
//  House View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct HouseView: View {
    typealias IPAddr = String
    @EnvironmentObject var weather: Weather
    @ObservedObject var viewModel = HouseViewModel.shared
    
    @State private var currentTab: Int = 0
    @State private var info: String = ""
    @State private var fanLabel: String = "Fan"
    @State private var refresh: Bool = false
    
    var body: some View {
        
        TabView (selection: $currentTab) {
            VStack {
            RefreshableScrollView(refreshing: $refresh) {
                FanViewPageContainer(viewModel: viewModel, weather: weather)
                        .ignoresSafeArea(.container, edges: .top)
                }
            }
            .onAppear {
                refresh = true
            }
            .tabItem {
                Image.fanIcon
                Text(viewModel.indicators.contains(.showScanningSpinner) ? "Scanning" : "Fan")
            }
            .tag(1)
            VStack {
                SettingsView()
            }
            .tabItem {
                Image.bell
                Text("Alarms")
            }
            .tag(2)
        }
        .accentColor(.main)
        .onChange(of: refresh) { go in
            if !viewModel.indicators.contains(.showScanningSpinner) && go {
                viewModel.scan()
            }
        }
        .onChange(of: viewModel.indicators) { indicators in
            if !indicators.contains(.showScanningSpinner) { refresh = false }
        }
    }
}

struct FanViewPageContainer: View {
    typealias IPAddr = String
    @ObservedObject var viewModel: HouseViewModel
    @ObservedObject var weather: Weather
    @State private var selectedFan: Int = 0
    
    var body: some View {
        if viewModel.fans.count == 0 {
            Text("No fans connected")
        } else if viewModel.fans.count == 1 {
            FanView(addr: viewModel.fans.first!.ipAddr ?? "not found", chars: viewModel.fans.first!)
                .padding(.bottom, 35)
        } else {
            TabView (selection: $selectedFan) {
                ForEach (Array(viewModel.fans), id: \.self) { fanAddr in
                    FanView(addr: fanAddr.ipAddr ?? "not found", chars: fanAddr)
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
            .environmentObject(House.shared)
            .environmentObject(Weather())
        
    }
}
