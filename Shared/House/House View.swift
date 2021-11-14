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
    @EnvironmentObject private var globalIndicators: GlobalIndicators
    @State private var currentTab: Int = 0
    @State private var info: String = ""
    @State private var fanLabel: String = "Fan"
    
    var body: some View {
        TabView (selection: $currentTab) {
            FanViewPageContainer (viewModel: viewModel)
                .ignoresSafeArea(.all, edges: [.top])
                .tabItem {
                    Image.fanIcon
                    Text(globalIndicators.updateProgress == nil ? "Fan" : "Scanning")
                }
                .tag(1)
            SettingsView()
                .tabItem {
                    Image.bell
                    Text("Alarms")
                }
                .tag(2)
            Text("test")
                .tabItem {
                    Image.fanIcon
                    Text("\(viewModel.fanViews.count)")
                }
        }
        .foregroundColor(.main)
        .tint(.main)
        .accentColor(.main)
        .onAppear {
            Task {
               try? await viewModel.scan()
            }
        }
    }
    
    init(viewModel: HouseViewModel? = nil) {
//        _viewModel = StateObject.init(wrappedValue: HouseViewModel(dataSource: HouseViewDataMock()))
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
    @State private var revealControlOffset = CGFloat.zero
//    @State private var viewCount = Int.zero
    
    var body: some View {
        Group {
            switch viewModel.fanViews.count {
                case 0:
                    NoFanView()
                case 1:
                    viewModel.fanViews.first!
                        .padding(.bottom, 75)
                default:
                    TabView (selection: $selectedFan) {
                        ForEach (Array(viewModel.fanViews)) { view in
                            view
                                .padding(.bottom, 50)
                                .tag(view.id)
                        }
                    }
//                    .overlay {
//                        ZStack {
//                            GeometryReader {
//                                geo in
//                                Color.red
////                                revealControlOffset = 25.0
//                            }
//
//                        }
//                    }
//                    .frame(width: .infinity, height: 600)
                    .offset(x: 0, y: revealControlOffset)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 60) }
        .pulldownRefresh {
            try? await viewModel.scan()
        }
        
        .offset(x: 0, y: 50.0)
//        .onReceive(viewModel.$fanViews) { view in
//            viewCount = view.count
//        }
    }
}

struct HouseViewPreviews: PreviewProvider {

    static var previews: some View {
        HouseView(viewModel: HouseViewModel(dataSource: HouseViewDataMock(), initialFans: Set([FanCharacteristics(), FanCharacteristics()])))
            .preferredColorScheme(.dark)
            .environmentObject(GlobalIndicators.shared)
    }
}

class HouseViewDataMock: House {
    
    var timeToFinish: Date?
    
    var finishTimer: Timer?
    
    var indicators = GlobalIndicators.shared

    var percentHostsChecked: Double?
    
    override func scan () -> AsyncThrowingStream<FanCharacteristics, Error> {
        return AsyncThrowingStream <FanCharacteristics, Error> { continuation in
            Task {
                let totalHosts = 10.0
                var checkedHosts = Double.zero
                
                GlobalIndicators.shared.updateProgress = 0.0
                
                timeToFinish = Date() + 5.0
                
                DispatchQueue.main.async {
                    self.finishTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self, ttf = self.timeToFinish, dur = 5.0] _ in
                        guard let self = self else { return }
                        guard let ttf = ttf else {
                            self.indicators.updateProgress = nil
                            return
                        }
                        let percentTimeLeft = (ttf.timeIntervalSinceReferenceDate - Date().timeIntervalSinceReferenceDate) / dur
                        guard (0...1) ~= percentTimeLeft else {
                            self.indicators.updateProgress = nil
                            return
                        }
                        self.indicators.updateProgress = max(self.percentHostsChecked ?? 0.0, 1 - percentTimeLeft)
                    }
                }

                await Task.sleep(1_000_000_000)
                var fanA = FanCharacteristics()
                fanA.airspaceFanModel = "3.5e"
                fanA.macAddr = UUID.init().uuidString
                continuation.yield(fanA)
                checkedHosts += 1
                percentHostsChecked = checkedHosts / totalHosts
//                print("a \(fanSet.count)")
                var fanB = FanCharacteristics()
                fanB.airspaceFanModel = "2.5e"
                fanB.macAddr = UUID.init().uuidString
                await Task.sleep(1_500_000_000)
                continuation.yield(fanB)
                checkedHosts += 1
                percentHostsChecked = checkedHosts / totalHosts
                //                print("b \(fanSet.count)")
                await Task.sleep(500_000_000)
                var fanC = FanCharacteristics()
                fanC.airspaceFanModel = "4300"
                fanC.macAddr = UUID.init().uuidString
                continuation.yield(fanC)
                checkedHosts += 1
                percentHostsChecked = checkedHosts / totalHosts
                //                print("c \(fanSet.count)")
                await Task.sleep(1_000_000_000)
                indicators.updateProgress = nil
                continuation.finish(throwing: nil)
                finishTimer?.invalidate()
                finishTimer = nil
            }
            
        }
    }
}
