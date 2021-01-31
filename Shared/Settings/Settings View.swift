//
//  Settings View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var weather: Weather
    @EnvironmentObject var location: Location
    @AppStorage(StorageKey.temperatureAlert.key) var temperatureAlertsEnabled: Bool = false
    @AppStorage(StorageKey.interlockAlert.key) var interlockAlertsEnabled: Bool = false
    @Environment(\.scenePhase) var scenePhase
    private var coordinatesAvailable: Bool {
        return (location.latStr == nil || location.lonStr == nil) ? false : true
    }

    var body: some View {
        ZStack {
            Color.main
                .ignoresSafeArea()
            VStack {
                SettingsBackgound()
                List {
                    if location.status == .deviceProhibited {
                        Section(header: Text("Location")) {
                            HStack {
                                Text("Location off for this device")
                                    .foregroundColor(.main)
                                Spacer()
                                Button(action: {
                                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                                }, label: {
                                    Text("Change Settings")
                                        .padding(5)
                                        .background(Color.main)
                                        .clipShape(RoundedRectangle(cornerRadius: 5.0))
                                })
                            }
                        }
                    }
                    else if location.status == .appProhibited {
                        Section(header: Text("Location")) {
                            HStack {
                                Text("Location disabled for Toasty")
                                    .foregroundColor(.main)
                                Spacer()
                                Button(action: {
                                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                                }, label: {
                                    Text("Change Settings")
                                        .padding(5)
                                        .background(Color.main)
                                        .clipShape(RoundedRectangle(cornerRadius: 5.0))
                                })
                            }
                        }
                    }
                    else if location.status == .appAllowed, !coordinatesAvailable {
                        Section(header: Text("Location")) {
                            HStack {
                                Text("Status: not set")
                                    .foregroundColor(.main)
                                Spacer()
                                Button(action: {
                                    location.updateLocation()
                                }, label: {
                                    Text("Set Location")
                                        .padding(5)
                                        .background(Color.main)
                                        .clipShape(RoundedRectangle(cornerRadius: 5.0))
                                })
                            }
                        }
                    }
                    else if location.status == .appAllowed, coordinatesAvailable {
                        Section(header: Text("Location")) {
                            HStack {
                                Text("Status: available")
                                    .foregroundColor(.main)
                                Spacer()
                                Button(action: {
                                    location.clearLocation()
                                }, label: {
                                    Text("Erase Location")
                                        .padding(5)
                                        .background(Color.main)
                                        .clipShape(RoundedRectangle(cornerRadius: 5.0))
                                })
                            }
                        }
                    }
                    else {
                        Section(header: Text("Location")) {
                            HStack {
                                Text("Location status unknown")
                                    .foregroundColor(.main)
                                Spacer()
                                Button(action: {
                                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                                }, label: {
                                    Text("Change Settings")
                                        .padding(5)
                                        .background(Color.main)
                                        .clipShape(RoundedRectangle(cornerRadius: 5.0))
                                })
                            }
                        }
                    }
                    Section(header: Text("Alerts")) {
                        VStack {
                            if
                                location.status == .appAllowed, coordinatesAvailable {
                                HStack {
                                    Text("Temperature")
                                        .foregroundColor(.main)
                                    Toggle("Enable", isOn: $temperatureAlertsEnabled)
                                }
                            }
                            HStack {
                                Text("Interlock")
                                    .foregroundColor(.main)
                                Toggle("Interlock", isOn: $interlockAlertsEnabled)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .main))
                    }
                    if
                        location.status == .appAllowed, coordinatesAvailable, temperatureAlertsEnabled {
                        Section(header: Text("temperature alert range")) {
                            VStack {
                                TemperatureSelector()
                                    .padding(.top, 25)
                                    .padding(.bottom, 10)
                            }
                        }
                    }                }
                    .background(Color.main)
                    .foregroundColor(.white)
                Spacer()
                HStack {
                    VStack (alignment: .leading) {
                        if let tempStr = weather.currentTempStr {
                            Text("Outside temperature: \(tempStr)")
                                .foregroundColor(.white)
                                .italic()
                        }
                        if location.status == .appAllowed, coordinatesAvailable
                        {
                            Text("Location: \(location.latStr!), \(location.lonStr!)")
                                .foregroundColor(.white)
                                .italic()
                        }
                    }
                    .font(.body)
                    Spacer()
                }
                .padding()
            }
        }
        .listStyle(GroupedListStyle())
        .onAppear {
            location.getLocationStatus()
        }
        .onChange(of: scenePhase, perform: { scene in
            switch scene {
            case .background, .inactive:
                break
            case .active:
                location.getLocationStatus()
            @unknown default:
                break
            }
        })
    }
}

struct TemperatureSelector: View {
    @AppStorage(StorageKey.lowTempLimit.key) var lowTemp: Double = 55
    @AppStorage(StorageKey.highTempLimit.key) var highTemp: Double = 75
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

struct Settings_View_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(Weather())
            .environmentObject(Location())
    }
}
