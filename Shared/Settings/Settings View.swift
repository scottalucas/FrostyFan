//
//  Settings View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var location: Location
    @EnvironmentObject var weather: Weather
    @Environment(\.scenePhase) var scenePhase
    @AppStorage(StorageKey.temperatureAlarmEnabled.key) var temperatureAlertsEnabled: Bool = false
    @AppStorage(StorageKey.interlockAlarmEnabled.key) var interlockAlertsEnabled: Bool = false
    @AppStorage(StorageKey.locationAvailable.key) var locationPermission: Location.LocationPermission = .unknown
    @AppStorage(StorageKey.coordinate.key) var coordinateData: Data?
    @State private var initTempAlertsEnabled = false
    @State private var initInterlockAlertsEnabled = false
    @State private var initLocationPermission: Location.LocationPermission = .unknown
    @State private var initCoord: Data?
    @Binding var activeSheet: OverlaySheet?
    
    private var coordinatesAvailable: Bool {
        coordinateData != nil
    }
    
    var body: some View {
        ZStack {
            Color.main
                .ignoresSafeArea(.all, edges: .top)
            VStack {
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
                                    VStack {
                                        Text("Location saved")
                                            .settingsAppearance(.lineLabel)
                                        if let lat = coordinateData?.decodeCoordinate?.lat, let lon = coordinateData?.decodeCoordinate?.lon {
                                            Text("\(lat.latitudeStr)   \(lon.longitudeStr)")
                                                .font(.caption2.italic())
                                        }
                                    }
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
                    if let weatherError = weather.retrievalError, coordinatesAvailable, temperatureAlertsEnabled {
                        Section(header: Text("Weather Error").settingsAppearance(.header)) {
                            VStack (alignment: .leading)
                            {
                                HStack {
                                    Text("Could not get outside temperature")
                                    Spacer()
                                    Button(action: {
                                        weather.check()
                                    }, label: {
                                        Text("Try Again")
                                            .settingsAppearance(.buttonLabel)
                                    })
                                }
                            Text( ( weatherError as? ConnectionError)?.description ?? "Unknown error")
                                    .font(.caption2)
                                    .lineLimit(3)
//                                    .layoutPriority(1)
                                    .padding(.trailing)
                                    .padding(.leading, 15)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .foregroundColor(.main)
            }
            .listStyle(GroupedListStyle())
            Spacer()
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack (alignment: .center, spacing: 0) {
                            HStack (alignment: .firstTextBaseline) {
                                Button("Cancel") {
                                    temperatureAlertsEnabled = initTempAlertsEnabled
                                    interlockAlertsEnabled = initInterlockAlertsEnabled
                                    locationPermission = initLocationPermission
                                    coordinateData = initCoord
                                    activeSheet = nil
                                }
                                Spacer()
                                Text("Settings").font(.largeTitle)
                                Spacer()
                                Button("Commit") {
                                    activeSheet = nil
                                }
                            }
                            Divider()
                                .ignoresSafeArea(.all, edges: [.leading, .trailing])
                                .background(Color.background)
                            Spacer()
                        }
                        .foregroundColor(.background)
                    }
                }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear(perform: {
            initTempAlertsEnabled = temperatureAlertsEnabled
            initInterlockAlertsEnabled = interlockAlertsEnabled
            initLocationPermission = locationPermission
            initCoord = coordinateData
        })
    }
}

struct TemperatureSelector: View {
    @AppStorage(StorageKey.lowTempLimit.key) var lowTempData: Data?
    @AppStorage(StorageKey.highTempLimit.key) var highTempData: Data?
    @State private var lowTemp: Double = 55
    @State private var highTemp: Double = 80
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
                style.labelStyle?.formatter = { inputValue in Measurement(value: inputValue, unit: UnitTemperature.fahrenheit).formatted() }
                style.labelStyle?.color = .main
            },
            leftHandleFormatter: { style in
                style.size = CGSize(width: 30, height: 30)
                style.strokeColor = .blue
                style.strokeWeight = 2.0
                style.labelOffset = CGSize(width: 0, height: -30)
                style.labelStyle = RangeSlider.LabelStyle()
                style.labelStyle?.formatter = { inputValue in Measurement(value: inputValue, unit: UnitTemperature.fahrenheit).formatted() }
                style.labelStyle?.color = .main
            })
            .onChange(of: lowTemp) { newLowTemp in
                lowTempData = Measurement(value: newLowTemp, unit: UnitTemperature.fahrenheit).data
            }
            .onChange(of: highTemp) { newHighTemp in
                highTempData = Measurement(value: newHighTemp, unit: UnitTemperature.fahrenheit).data
            }
            .onAppear(perform: {
                lowTemp = lowTempData?.decodeTemperature?.value ?? 55.0
                highTemp = highTempData?.decodeTemperature?.value ?? 80.0
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
    static var loc: Location {
        @AppStorage(StorageKey.coordinate.key) var coordData: Data?
        coordData = CLLocation(latitude: 38, longitude: -122).data
        return Location()
    }
    static var previews: some View {
        NavigationView {
            SettingsView(activeSheet: .constant(nil))
        }
                    .preferredColorScheme(.dark)
                    .environmentObject(Weather())
                    .environmentObject(loc)
                    .environment(\.locale, .init(identifier: "de"))

    }
}
