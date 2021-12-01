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
    @EnvironmentObject private var sharedHouseData: SharedHouseData
    @StateObject var viewModel: HouseViewModel
    @State private var currentTab: Int = 0
    @State private var info: String = ""
    @State private var fanLabel: String = "Fan"
    
    var body: some View {
            FanViewPageContainer (viewModel: viewModel)
                .foregroundColor(.main)
                .tint(.background)
                .accentColor(.main)
        .onAppear {
            Task {
               try? await viewModel.scan()
            }
        }
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
    @State private var revealControlOffset = CGFloat.zero

    var body: some View {
        VStack {
            switch viewModel.fanViews.count {
                case 0:
                    NoFanView()
                case 1:
                    viewModel.fanViews.first?.eraseToAnyView() ?? NoFanView().eraseToAnyView()
                default:
                    TabView (selection: $selectedFan) {
                        ForEach (Array(viewModel.fanViews)) { view in
                            view
                                .tag(view.id)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .automatic))
            }
        }
        .pulldownRefresh {
            try? await viewModel.scan()
        }
    }
}

struct HouseViewPreviews: PreviewProvider {

    static var previews: some View {
        let vm = HouseViewModel()
        let env = SharedHouseData.shared

        return HouseView(viewModel: HouseViewModel(dataSource: HouseViewDataMock()))
            .preferredColorScheme(.dark)
            .environmentObject(SharedHouseData.shared)
            .environmentObject(Weather())
    }
}

class HouseViewDataMock: House {
    
    var timeToFinish: Date?
    
    var finishTimer: Timer?
    
    var indicators = SharedHouseData.shared

    var percentHostsChecked: Double?
    
    override func scan () -> AsyncThrowingStream<FanCharacteristics, Error> {
        return AsyncThrowingStream <FanCharacteristics, Error> { continuation in
            Task {
                let totalHosts = 10.0
                var checkedHosts = Double.zero

                SharedHouseData.shared.updateProgress = 0.0

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
//                var fanB = FanCharacteristics()
//                fanB.airspaceFanModel = "2.5e"
//                fanB.interlock1 = true
//                fanB.damper = .operating
//                fanB.macAddr = UUID.init().uuidString
//                await Task.sleep(1_500_000_000)
//                continuation.yield(fanB)
//                checkedHosts += 1
//                percentHostsChecked = checkedHosts / totalHosts
//                await Task.sleep(500_000_000)
//                var fanC = FanCharacteristics()
//                fanC.airspaceFanModel = "4300"
//                fanC.macAddr = UUID.init().uuidString
//                continuation.yield(fanC)
//                checkedHosts += 1
//                percentHostsChecked = checkedHosts / totalHosts
//                await Task.sleep(1_000_000_000)
                indicators.updateProgress = nil
                continuation.finish(throwing: nil)
                finishTimer?.invalidate()
                finishTimer = nil
            }

        }
    }
    override init () {
        SharedHouseData.shared.updateProgress = nil
    }
}
