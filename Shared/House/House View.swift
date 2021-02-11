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
    @EnvironmentObject var house: House
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
                    FanViewPageContainer(house: house, weather: weather)
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
    @ObservedObject var house: House
    @ObservedObject var weather: Weather
    @State private var selectedFan: Int = 0
    
    var body: some View {
        if house.fans.count == 0 {
            Text("No fans connected")
        } else if house.fans.count == 1 {
            FanView(addr: house.fans.first!.ipAddr ?? "not found", chars: house.fans.first!, house: house, weather: weather)
                .padding(.bottom, 35)
        } else {
            TabView (selection: $selectedFan) {
                ForEach (Array(house.fans), id: \.self) { fanAddr in
                    FanView(addr: fanAddr.ipAddr ?? "not found", chars: fanAddr, house: house, weather: weather)
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
            .environmentObject(House())
            .environmentObject(Weather(house: House()))
        
    }
}
