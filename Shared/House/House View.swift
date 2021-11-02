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
    @StateObject private var actionPerformer = RefreshActionPerformer()
    
    @State private var currentTab: Int = 0
    @State private var info: String = ""
    @State private var fanLabel: String = "Fan"
    @State private var refreshing: Bool = false
    @GestureState var viewOffset = CGSize.zero
    private var pullDownSize: CGSize = .zero
    
    var body: some View {
            TabView (selection: $currentTab) {
                FanViewPageContainer(viewModel: viewModel, weather: weather, refreshing: $refreshing, pullDownSize: viewOffset)
                    .ignoresSafeArea(.container, edges: [.top])
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
            .overlay {
                if refreshing {
                    VStack {
                        ProgressView ()
                        Spacer()
                    }
                }
            }
        .accentColor(.main)
        .gesture(DragGesture().updating($viewOffset) { value, state, _ in
            guard !refreshing else { return }
            let pullH = max(value.translation.height, 0)
            state = CGSize(width: 0, height: pullH)
            if pullH > 75 {
                let thump = UIImpactFeedbackGenerator(style: .rigid)
                thump.impactOccurred()
                refreshing = true
                Task {
                    await viewModel.asyncScan()
                    refreshing = false
                }
            }
        })
    }
}

struct FanViewPageContainer: View {
    typealias IPAddr = String
    @ObservedObject var viewModel: HouseViewModel
    @ObservedObject var weather: Weather
    @Binding var refreshing: Bool
    var pullDownSize: CGSize
    @State private var selectedFan: Int = 0
    
    var body: some View {
        if viewModel.fans.count == 0 {
                Text("No fans connected")
        } else if viewModel.fans.count == 1 {
            FanView(addr: viewModel.fans.first!.ipAddr ?? "not found", chars: viewModel.fans.first!, refreshing: _refreshing, pullDownOffset: pullDownSize)
                .padding(.bottom, 35)
        } else {
            TabView (selection: $selectedFan) {
                ForEach (Array(viewModel.fans), id: \.self) { fanAddr in
                    FanView(addr: fanAddr.ipAddr ?? "not found", chars: fanAddr, refreshing: _refreshing, pullDownOffset: pullDownSize)
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
