//
//  Settings View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct SettingsView: View {
    typealias LocationStatus = LocationManager.LocationStatus
    @StateObject var viewModel: SettingsViewModel
    @EnvironmentObject var weather: WeatherManager
    @AppStorage("tempAlertsEnabled") var temperatureAlertsEnabled: Bool = false
    @AppStorage("interlockAlertsEnabled") var interlockAlertsEnabled: Bool = false
    @AppStorage("locationAvailability") var locationAvailability: LocationStatus = .unknown
    @AppStorage("locLat") var latitude: Double?
    @AppStorage("locLon") var longitude: Double?
    @Environment(\.scenePhase) var scenePhase
    private var locationManager = LocationManager.shared
    private var latFormatter: NumberFormatter
    private var lonFormatter: NumberFormatter
    private var coordinatesAvailable: Bool {
        return (latitude == nil || longitude == nil) ? false : true
    }

    var body: some View {
        ZStack {
            Color.main
                .ignoresSafeArea()
            VStack {
                SettingsBackgound()
                List {
                    if locationAvailability == .deviceProhibited {
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
                    else if locationAvailability == .appProhibited {
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
                    else if locationAvailability == .appAllowed, !coordinatesAvailable {
                        Section(header: Text("Location")) {
                            HStack {
                                Text("Status: not set")
                                    .foregroundColor(.main)
                                Spacer()
                                Button(action: {
                                    locationManager.updateLocation()
                                }, label: {
                                    Text("Set Location")
                                        .padding(5)
                                        .background(Color.main)
                                        .clipShape(RoundedRectangle(cornerRadius: 5.0))
                                })
                            }
                        }
                    }
                    else if locationAvailability == .appAllowed, coordinatesAvailable {
                        Section(header: Text("Location")) {
                            HStack {
                                Text("Status: available")
                                    .foregroundColor(.main)
                                Spacer()
                                Button(action: {
                                    latitude = nil
                                    longitude = nil
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
                                Text("Location status unknown.")
                                    .foregroundColor(.main)
                            }
                        }
                    }
                    Section(header: Text("Alerts")) {
                        VStack {
                            if
                                locationAvailability == .appAllowed,
                                latitude != nil,
                                longitude != nil {
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
                        locationAvailability == .appAllowed, coordinatesAvailable, temperatureAlertsEnabled {
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
                if let tempStr = weather.currentTempStr {
                    Text("Outside temperature: \(tempStr)")
                        .foregroundColor(.white)
                }
                if locationAvailability == .appAllowed,
                   let lat = latitude,
                   let lon = longitude,
                   let latNS = NSNumber(value: lat),
                   let lonNS = NSNumber(value: lon),
                   let latStr = latFormatter.string(from: latNS),
                   let lonStr = lonFormatter.string(from: lonNS)
                {
                    Text("Location: \(latStr), \(lonStr)")
                        .foregroundColor(.white)
                }
            }
        }
        .listStyle(GroupedListStyle())
        .onAppear {
            locationManager.getLocationStatus()
        }
//        .onChange(of: scenePhase, perform: { scene in
//            switch scene {
//            case .background, .inactive:
//                break
//            case .active:
//                print("became active")
//                viewModel.requestAuthorization()
//            @unknown default:
//                break
//            }
//        })
    }
    
    init (viewModel: SettingsViewModel = SettingsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
        latFormatter = NumberFormatter()
        lonFormatter = NumberFormatter()
        latFormatter.positiveFormat = "##0.00\u{00B0} N"
        latFormatter.negativeFormat = "##0.00\u{00B0} S"
        lonFormatter.positiveFormat = "##0.00\u{00B0} E"
        lonFormatter.negativeFormat = "##0.00\u{00B0} W"
    }
}

struct TemperatureSelector: View {
    @AppStorage("lowTempLimit") var lowTemp: Double = 55
    @AppStorage("highTempLimit") var highTemp: Double = 75
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
        SettingsView(viewModel: StorageMocks().mockViewModel)
    }
}
