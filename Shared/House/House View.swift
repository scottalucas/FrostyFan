//
//  House View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//
/*
 The HouseView is fairly simple. A TabView displays discovered fans, and a pulldownRefresh view modifier creates a way for users to re-scan for fans.
 
 The FanView communicates the currently-active fan via the selectedTab state. Individual fans receive that state to manage how often (or if) they check a fan's current status.
 */

import SwiftUI
import Combine

@MainActor
struct HouseView: View {
    @StateObject var viewModel: HouseViewModel
    @Environment(\.scenePhase) var scenePhase
    @State var selectedTab: FanView.ID = ""

    var body: some View {
        Group {
            if viewModel.fanSet.count == 0 {
                NoFanView ( )
            } else {
                TabView (selection: $selectedTab) {
                    ForEach (Array(viewModel.fanSet)) { fanView in
                        fanView
                            .tag(fanView.id)
                            .padding(.bottom, 50)
                            .ignoresSafeArea(.all)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .automatic))
            }
        }
        .pulldownRefresh {
            await viewModel.scan([])
        }

        .onChange(of: selectedTab) { newId in
            HouseStatus.shared.displayedFanID = newId
        }
    }
    
    init(viewModel: HouseViewModel? = nil) {
        Log.house.info("view init")
        _viewModel = StateObject(wrappedValue: viewModel ?? HouseViewModel(initialFans: []))
    }
}

class ViewModelMock: HouseViewModel {
    var fanB = FanCharacteristics()
    var fanC = FanCharacteristics()
    
    init () {
        fanB.airspaceFanModel = "2.5e"
        fanB.interlock1 = true
        fanB.damper = .operating
        fanB.macAddr = UUID.init().uuidString
        fanB.speed = 2
        fanC.airspaceFanModel = "4300"
        fanC.macAddr = UUID.init().uuidString
        super.init(initialFans: [fanB, fanC])
        HouseStatus.shared.scanUntil = .distantPast
    }
}

struct HouseViewPreviews: PreviewProvider {
    
    static var previews: some View {
        let vm = ViewModelMock()
        return NavigationView {
            HouseView(viewModel: vm)
                .preferredColorScheme(.dark)
                .environmentObject(WeatherMonitor.shared)
                .background(Color.pageBackground)
                .foregroundColor(.main)
                .ignoresSafeArea()
                .onAppear {
                    WeatherMonitor.shared.tooHot = true
                    WeatherMonitor.shared.tooCold = false
                    HouseStatus.shared.scanUntil = .distantPast
                }
            
        }
    }
}
