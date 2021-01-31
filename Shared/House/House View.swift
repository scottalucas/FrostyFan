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
    @StateObject var house: House = House()
    @State private var runningFans = Set<FanCharacteristics>() {
        didSet {
            weather.fansRunning = runningFans.count > 0 ? true : false
        }
    }
    @State private var currentTab: Int = 0
    @State private var info: String = ""
    @State private var tap: Bool = false
    @State private var fanLabel: String?
    
    var body: some View {
        
        TabView (selection: $currentTab) {
            ZStack {
                VStack {
                    RefreshableScrollView(height: 40, refreshing: $house.scanning) {}
                        .frame(width: nil, height: 75, alignment: .top)
                    Spacer()
                }
                VStack {
                    FanViewPageContainer(fanChars: $house.fans, fanCharsRunning: $runningFans)
                        .ignoresSafeArea(.container, edges: .top)
                    Spacer()
                }
            }
            .tabItem {
                Image.fanIcon
                Text(house.scanning ? "Scanning" : "Fan")
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
    }
}

struct FanViewPageContainer: View {
    typealias IPAddr = String
    @Binding var fanChars: Set<FanCharacteristics>
    @Binding var fanCharsRunning: Set<FanCharacteristics>
    @State private var selectedFan: Int = 0
    
    var body: some View {
        if fanChars.count == 0 {
            Text("No fans connected")
        } else if fanChars.count == 1 {
            FanView(addr: fanChars.first!.ipAddr ?? "not found", chars: fanChars.first!, allFans: $fanChars, runningFans: $fanCharsRunning)
                .padding(.bottom, 35)
        } else {
            TabView (selection: $selectedFan) {
                ForEach (Array(fanChars), id: \.self) { fanAddr in
                    FanView(addr: fanAddr.ipAddr ?? "not found", chars: fanAddr, allFans: $fanChars, runningFans: $fanCharsRunning)
                        .padding(.bottom, 100)
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
    }
}
