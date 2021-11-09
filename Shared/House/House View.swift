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
    @StateObject var viewModel: HouseViewModel
    @State private var currentTab: Int = 0
    @State private var info: String = ""
    @State private var fanLabel: String = "Fan"
    
    var body: some View {
        TabView (selection: $currentTab) {
            FanViewPageContainer (viewModel: viewModel)
                .ignoresSafeArea(.container, edges: [.top])
                .tabItem {
                    Image.fanIcon
                    Text("Fan")
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
    }
    
    init(viewModel: HouseViewModel? = nil) {
        if let vm = viewModel {
            _viewModel = StateObject.init(wrappedValue: vm)
        } else {
            _viewModel = StateObject.init(wrappedValue: HouseViewModel())
        }
    }
}

struct FanViewPageContainer: View {
    typealias IPAddr = String
    @StateObject var viewModel: HouseViewModel
    @State private var selectedFan: String = ""
    @State private var viewCount = Int.zero
    
    var body: some View {
        Group {
            switch viewCount {
                case 0:
                    NoFanView()
                case 1:
                    viewModel.fanViews.first!
                        .padding(.bottom, 75)
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
        .pulldownRefresh(progress: $viewModel.progress) {
            await viewModel.scan()
        }
        .offset(x: 0, y: 50.0)
        .task {
            await viewModel.scan()
        }
        .onReceive(viewModel.$fanViews) { view in
            viewCount = view.count
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
    var progress = PassthroughSubject<Double?, Never>()
    
    var scan: () async -> Void
    
    var fanSetPub = CurrentValueSubject<Set<FanCharacteristics>, Never>([])
    
    func remove(_: FanCharacteristics) {
        print("remove request")
    }
    
    init () {
        scan = { print("scan requested") }
        let fanc = FanCharacteristics()
        let fand = FanCharacteristics()
        let fane = FanCharacteristics()
        Task {
            var fanA = FanCharacteristics()
            fanA.airspaceFanModel = "3.5e"
            var fanB = FanCharacteristics()
            fanB.airspaceFanModel = "2.5e"
            await Task.sleep(500_000_000)
            fanSetPub.send([fanA])
            progress.send(0.1)
        }
    }
}
