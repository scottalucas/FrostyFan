//
//  House View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct HouseView: View {
    typealias IPAddr = String
    @Environment(\.refresh) private var refreshAction
    @EnvironmentObject var weather: Weather
    @ObservedObject var viewModel = HouseViewModel.shared
    @StateObject private var actionPerformer = RefreshActionPerformer()
    
    @State private var currentTab: Int = 0
    @State private var info: String = ""
    @State private var fanLabel: String = "Fan"
    @State private var refreshing: Bool = false
    @State var viewOffset = CGSize.zero
    
    var body: some View {
        ZStack {
            TabView (selection: $currentTab) {
                FanViewPageContainer(viewModel: viewModel, weather: weather, viewOffset: $viewOffset)
                    .ignoresSafeArea(.container, edges: [.top])
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
            if refreshing {
                VStack {
                    ProgressView ()
                    Spacer()
                }
            }
        }
        .offset(viewOffset)
        .accentColor(.main)
        .onChange(of: viewModel.indicators) { indicators in
            if !indicators.contains(.showScanningSpinner) {
                //                refresh = false
            }
        }
        .gesture(DragGesture()
                    .onChanged { value in
            let y = max(value.translation.height, 0)
            viewOffset = CGSize(width: 0, height: y)
        }
                    .onEnded { value in
            withAnimation(.easeIn(duration: 0.1)) { viewOffset = .zero }
            guard !refreshing else { return }
            Task {
                refreshing = true
                await viewModel.asyncScan()
                refreshing = false
            }
        })
    }
}

struct FanViewPageContainer: View {
    typealias IPAddr = String
    @ObservedObject var viewModel: HouseViewModel
    @ObservedObject var weather: Weather
    @State private var selectedFan: Int = 0
    @Binding var viewOffset: CGSize
    
    var body: some View {
        if viewModel.fans.count == 0 {
                Text("No fans connected")
        } else if viewModel.fans.count == 1 {
            FanView(addr: viewModel.fans.first!.ipAddr ?? "not found", chars: viewModel.fans.first!)
                .padding(.bottom, 35)
                .offset(viewOffset)
        } else {
            TabView (selection: $selectedFan) {
                ForEach (Array(viewModel.fans), id: \.self) { fanAddr in
                    FanView(addr: fanAddr.ipAddr ?? "not found", chars: fanAddr)
                        .padding(.bottom, 75)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .offset(viewOffset)
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
