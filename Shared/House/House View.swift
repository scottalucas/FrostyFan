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
//    @State var scanUntil: Date?
    
    var body: some View {
        NavigationView {
            VStack {
                switch viewModel.fanSet.count {
                    case 0:
                        NoFanView(houseViewModel: viewModel)
                    case 1:
                        FanView(initialCharacteristics: viewModel.fanSet.first!, houseVM: viewModel)
                    default:
                        TabView (selection: $viewModel.displayedFanID) {
                            ForEach (Array(viewModel.fanSet)) { chars in
                                FanView(initialCharacteristics: chars, houseVM: viewModel)
                                    .tag(chars.id)
                                    .padding(.bottom, 50)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .automatic))
                }
            }
                .background (
                    IdentifiableImage.fanIcon.image
                        .resizable()
                        .aspectRatio(1.0, contentMode: .fit)
                        .scaleEffect(1.75)
                        .rotatingView(speed: $viewModel.displayedRPM, symmetry: .degrees(60.0))
                        .padding(.bottom, viewModel.fanSet.count > 1 ? 30 : 0)
                        .blur(radius: 30)
                        .foregroundColor(viewModel.useAlarmColor ? .alarm : .main)
                )
                .pulldownRefresh {
                    Task {
                        await viewModel.scan()
                    }
                }

    }
    }
    
    init(viewModel: HouseViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? HouseViewModel())
    }
}

//struct FanViewPageContainer: View {
//    typealias IPAddr = String
//    @Binding var fanSet: Set<FanCharacteristics>
//    @Binding var displayedFanID: FanView.ID
//    @Binding var scanEndDate: Date?
//    @Binding var houseAlarm: Bool
//    @State private var revealControlOffset = CGFloat.zero {
//        didSet {
//            print("set fan view, count: \(fanSet.count)")
//        }
//    }
//
//    var body: some View {
//        VStack {
//            switch fanSet.count {
//                case 0:
//                    NoFanView(endDate: $scanEndDate)
//                case 1:
//                    FanView(initialCharacteristics: fanSet.first!, houseAlarm: $houseAlarm, scanEndDate: $scanEndDate)
//                default:
//                    TabView (selection: $displayedFanID) {
//                        ForEach (Array(fanSet)) { chars in
//                            FanView(initialCharacteristics: chars, houseAlarm: $houseAlarm, scanEndDate: $scanEndDate)
//                                .tag(chars.id)
//                                .padding(.bottom, 50)
//                        }
//                    }
//                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
//                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .automatic))
//            }
//        }
//        //        .onAppear {
//        //            house.fanSet.removeAll()
//        //            fanViews = house.fanSet.map({ FanView(initialCharacteristics: $0) })
//        //        }
//        //        .onChange(of: house.fanSet) { chars in
//        //            fanViews.removeAll()
//        //            fanViews = house.fanSet.map({ FanView(initialCharacteristics: $0) })
//        //        }
//        //        .onDisappear {
//        //            house.fanSet.removeAll()
//        //        }
//    }
//}

class ViewModelMock: HouseViewModel {
    var fanB = FanCharacteristics()
    var fanC = FanCharacteristics()
    
    override init () {
        super.init()
        fanB.airspaceFanModel = "2.5e"
        fanB.interlock1 = true
        fanB.damper = .operating
        fanB.macAddr = UUID.init().uuidString
        fanB.speed = 2
        fanC.airspaceFanModel = "4300"
        fanC.macAddr = UUID.init().uuidString
        fanSet.update(with: fanC)
        fanSet.update(with: fanB)
    }
}

struct HouseViewPreviews: PreviewProvider {
    
    static var previews: some View {
        //        let vm = HouseViewModel()
        let vm = ViewModelMock()
        return HouseView(viewModel: vm)
            .preferredColorScheme(.dark)
            .environmentObject(WeatherMonitor.shared)
            .background(Color.background)
            .foregroundColor(.main)
            .onAppear {
                WeatherMonitor.shared.tooHot = true
                WeatherMonitor.shared.tooCold = false
            }
    }
}

//class HouseViewDataMock: House {
//    
//    
//    override func lowLevelScan () -> AsyncThrowingStream<FanCharacteristics, Error> {
//        HouseMonitor.shared.scanning = true
//        return AsyncThrowingStream <FanCharacteristics, Error> { continuation in
//            Task {
//                let totalHosts = 10.0
//                var checkedHosts = Double.zero
//                try! await Task.sleep(nanoseconds: 1_000_000_000)
//                var fanA = FanCharacteristics()
//                fanA.airspaceFanModel = "3.5e"
//                fanA.macAddr = UUID.init().uuidString
//                continuation.yield(fanA)
//                checkedHosts += 1
//                percentHostsChecked = checkedHosts / totalHosts
////                var fanB = FanCharacteristics()
////                fanB.airspaceFanModel = "2.5e"
////                fanB.interlock1 = true
////                fanB.damper = .operating
////                fanB.macAddr = UUID.init().uuidString
////                fanB.speed = 2
////                try? await Task.sleep(nanoseconds: 1_500_000_000)
////                continuation.yield(fanB)
////                checkedHosts += 1
////                percentHostsChecked = checkedHosts / totalHosts
////                await Task.sleep(500_000_000)
////                var fanC = FanCharacteristics()
////                fanC.airspaceFanModel = "4300"
////                fanC.macAddr = UUID.init().uuidString
////                continuation.yield(fanC)
////                checkedHosts += 1
//                percentHostsChecked = checkedHosts / totalHosts
//                try await Task.sleep(nanoseconds: 1_000_000_000)
////                indicators.updateProgress = nil
//                continuation.finish(throwing: nil)
//                HouseMonitor.shared.scanning = false
////                finishTimer?.invalidate()
////                finishTimer = nil
//            }
//
//        }
//    }
//    override init () {
////        SharedHouseData.shared.updateProgress = nil
//    }
//}
