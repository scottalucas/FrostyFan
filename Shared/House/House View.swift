//
//  House View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI
import Combine

struct HouseView: View {
    typealias IPAddr = String
    @Environment(\.updateProgress) var updateProgress
    @StateObject var viewModel: HouseViewModel
    @State private var currentTab: Int = 0
    @State private var info: String = ""
    @State private var fanLabel: String = "Fan"
    
    var body: some View {
        TabView (selection: $currentTab) {
            FanViewPageContainer (viewModel: viewModel)
                .ignoresSafeArea(.container, edges: [.top])
                .pulldownRefresh {
                    Task {
                        await viewModel.scan()
                    }
                }
                .tabItem {
                    Image.fanIcon
                    Text(updateProgress == nil ? "Fan" : "Scanning")
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
        .task {
            await viewModel.scan()
        }
    }
}

struct FanViewPageContainer: View {
    typealias IPAddr = String
    var viewModel: HouseViewModel
    @State private var selectedFan: String = ""
    
    var body: some View {
        switch viewModel.fanViews.count {
            case 0:
                NoFanView()
            case 1:
                viewModel.fanViews.first!
                    .padding(.bottom, 35)
            default:
                TabView (selection: $selectedFan) {
                    ForEach (Array(viewModel.fanViews)) { view in
                            view
                                .padding(.bottom, 75)
                                .tag(view.id)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
    }
}

struct HouseViewPreviews: PreviewProvider {
    static var previews: some View {
        HouseView(viewModel: HouseViewModel(dataSource: HouseViewDataMock()))
            .preferredColorScheme(.dark)
            .environment(\.updateProgress, nil)
    }
}

class HouseViewDataMock: HouseDataSource {
    var fanSetPub : CurrentValueSubject<Set<FanCharacteristics>, Never>
    
    var updateProgress: Double?
    
    func scan() async {
        print("scan request")
    }
    
    func remove(_: FanCharacteristics) {
        print("remove request")
    }
    
    init () {
        let fanA = FanCharacteristics()
        let fanB = FanCharacteristics()
        let fanc = FanCharacteristics()
        let fand = FanCharacteristics()
        let fane = FanCharacteristics()
        fanSetPub = CurrentValueSubject<Set<FanCharacteristics>, Never>([fanA,fanB, fanc, fand, fane])
    }
}
