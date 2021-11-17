//
//  Settings View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct SettingsView: View {
    //    @EnvironmentObject var weather: Weather
    @EnvironmentObject var location: Location
    @Environment(\.scenePhase) var scenePhase
    @AppStorage(StorageKey.temperatureAlarmEnabled.key) var temperatureAlertsEnabled: Bool = false
    @AppStorage(StorageKey.interlockAlarmEnabled.key) var interlockAlertsEnabled: Bool = false
    @AppStorage(StorageKey.locationAvailable.key) var locationPermission: Location.LocationPermission = .unknown
    @AppStorage(StorageKey.locLat.key) var latStr: String?
    @AppStorage(StorageKey.locLon.key) var lonStr: String?
    @State var test = true
    
    private var coordinatesAvailable: Bool {
        latStr != nil && lonStr != nil
    }
    
    var body: some View {
        ZStack {
            Color.main
                .ignoresSafeArea(.all, edges: .top)
            VStack {
                SettingsBackgound()
                List {
                    Section(header: Text("Location").foregroundColor(.background)) {
                        switch (locationPermission, coordinatesAvailable) {
                            case (.appProhibited, _):
                                HStack {
                                    Text("Location disabled for Toasty")
                                        .settingsAppearance(.lineLabel)
                                    Spacer()
                                    Button(action: {
                                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                                    }, label: {
                                        Text("Change Settings")
                                            .settingsAppearance(.buttonLabel)
                                    })
                                }
                            case (.deviceProhibited, _):
                                HStack {
                                    Text("Location off for this device")
                                        .settingsAppearance(.lineLabel)
                                    Spacer()
                                    Button(action: {
                                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                                    }, label: {
                                        Text("Change Settings")
                                            .settingsAppearance(.buttonLabel)
                                    })
                                }
                            case (.appAllowed, false), (.unknown, false):
                                HStack {
                                    Text("Location unknown")
                                        .settingsAppearance(.lineLabel)
                                    Spacer()
                                    Button(action: {
                                        location.updateLocation()
                                    }, label: {
                                        Text("Set Location")
                                            .settingsAppearance(.buttonLabel)
                                    })
                                }
                            case (_, true):
                                HStack {
                                    Text("Location saved")
                                        .settingsAppearance(.lineLabel)
                                    Spacer()
                                    Button(action: {
                                        location.clearLocation()
                                    }, label: {
                                        Text("Erase Location")
                                            .settingsAppearance(.buttonLabel)
                                    })
                                }
                        }
                    }
                    Section(header: Text("Alerts").settingsAppearance(.header)) {
                        if coordinatesAvailable {
                            VStack {
                                Toggle("Interlock", isOn: $interlockAlertsEnabled)
                                Toggle("Temperature", isOn: $temperatureAlertsEnabled)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .main))
                            .settingsAppearance(.lineLabel)
                        } else {
                            Toggle("Interlock", isOn: $interlockAlertsEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .main))
                                .settingsAppearance(.lineLabel)
                        }
                    }
                    if (coordinatesAvailable && temperatureAlertsEnabled) {
                        Section(header: Text("temperature alert range").settingsAppearance(.header)) {
                            TemperatureSelector()
                                .padding(.top, 25)
                                .padding(.bottom, 10)
                        }
                    }
                    //                    }
                    //                                                .background(Color.main)
                }
                .foregroundColor(.main)
                //                        HStack {
                //                            VStack (alignment: .leading) {
                //                        if let tempStr = weather.currentTempStr {
                //                            Text("Outside temperature: \(tempStr)")
                //                                .foregroundColor(.white)
                //                                .italic()
                //                        } //FIX
                //                        if (locationPermission == .appAllowed || locationPermission == .unknown), coordinatesAvailable
                //                        {
                //                            Text("Location: \(latStr!), \(lonStr!)")
                //                                .foregroundColor(.white)
                //                                .italic()
                //                        }
                //                    }
                //                                .font(.body)
                //                                Spacer()
            }
            .listStyle(GroupedListStyle())
            Spacer()
        }
    }
}

struct TemperatureSelector: View {
    @AppStorage(StorageKey.lowTempLimit.key) var lowTemp: Double = 55
    @AppStorage(StorageKey.highTempLimit.key) var highTemp: Double = 80
    private let min = 40.0
    private let max = 85.0
    
    var body: some View {
        RangeSlider(
            selectedLow: $lowTemp,
            selectedHigh: $highTemp,
            minimum: min,
            maximum: max,
            barFormatter: { style in
                style.barInsideFill = .main
                style.barOutsideStrokeColor = .white
                style.barOutsideStrokeWeight = 0.75
                style.barHeight = 7.0
            },
            rightHandleFormatter: { style in
                style.size = CGSize(width: 30, height: 30)
                style.strokeColor = .red
                style.strokeWeight = 2.0
                style.labelOffset = CGSize(width: 0, height: -30)
                style.labelStyle = RangeSlider.LabelStyle()
                style.labelStyle?
                    .numberFormat
                    .positiveFormat = "##\u{00B0}"
                style.labelStyle?.color = .main
            },
            leftHandleFormatter: { style in
                style.size = CGSize(width: 30, height: 30)
                style.strokeColor = .blue
                style.strokeWeight = 2.0
                style.labelOffset = CGSize(width: 0, height: -30)
                style.labelStyle = RangeSlider.LabelStyle()
                style.labelStyle?
                    .numberFormat
                    .positiveFormat = "##\u{00B0}"
                style.labelStyle?.color = .main
            })
    }
}

struct SettingsBackgound: View {
    var body: some View {
        ZStack {
            VStack (alignment: .center, spacing: 0) {
                HStack (alignment: .firstTextBaseline) {
                    Text("Settings").font(.largeTitle)
                        .foregroundColor(Color.background)
                    Spacer()
                }
                Divider()
                    .frame(width: nil, height: 1, alignment: .center)
                    .background(Color.background)
            }
            .padding()
        }
    }
}

struct SettingsAppearance: ViewModifier {
    enum Position { case header, lineLabel, buttonLabel }
    var position: Position
    func body(content: Content) -> some View {
        switch position {
            case .lineLabel:
                content
                    .foregroundColor(Color.main)
                    .background(Color.clear)
            case .buttonLabel:
                content
                    .padding(5)
                    .background(Color.main)
                    .clipShape(RoundedRectangle(cornerRadius: 5.0))
                    .foregroundColor(Color.background)
            case .header:
                content
                    .foregroundColor(Color.background)
                    .background(Color.clear)
        }
    }
}


extension View {
    func settingsAppearance (_ position: SettingsAppearance.Position) -> some View {
        modifier(SettingsAppearance(position: position))
    }
}

struct Settings_View_Previews: PreviewProvider {
    //    static var house = House.shared
    static var previews: some View {
        SettingsView()
//            .preferredColorScheme(.dark)
        //            .environmentObject(Weather())
        //            .environmentObject(Location())
    }
}
