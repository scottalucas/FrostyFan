//
//  Settings View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI
import CoreLocation
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var location: Location
    @EnvironmentObject var weather: WeatherMonitor
    @Environment(\.scenePhase) var scenePhase
    @AppStorage(StorageKey.temperatureAlarmEnabled.rawValue) var temperatureAlertsEnabled: Bool = false
    @AppStorage(StorageKey.interlockAlarmEnabled.rawValue) var interlockAlertsEnabled: Bool = false
//    @AppStorage(StorageKey.locationAvailable.key) var locationPermission: Location.LocationPermission = .unknown
    @AppStorage(StorageKey.coordinate.rawValue) var coordinateData: Data?
//    @AppStorage (StorageKey.lowTempLimit.rawValue) var lowTempLimit: Double?
//    @AppStorage (StorageKey.highTempLimit.rawValue) var highTempLimit: Double?

    @State private var initTempAlertsEnabled = false
    @State private var initInterlockAlertsEnabled = false
    @State private var initCoord: Data?
    @State private var initLowTempLimit: Double?
    @State private var initHighTempLimit: Double?
    @State private var weatherError: Error?
    @Binding var activeSheet: OverlaySheet?
    
    var body: some View {
        ZStack {
            Color.main
                .ignoresSafeArea(.all, edges: .top)
            VStack {
                List {
                    Section(header: Text("Location").foregroundColor(.background)) {
                        if coordinateData != nil {
                            HStack {
                                VStack {
                                    Text("Location saved")
                                        .settingsAppearance(.lineLabel)
                                    Text("\(Storage.coordinate?.lat.latitudeStr ?? "")   \(Storage.coordinate?.lon.longitudeStr ?? "")")
                                            .font(.caption2.italic())
                                }
                                Spacer()
                                Button(action: {
                                    location.clearLocation()
                                }, label: {
                                    Text("Erase Location")
                                        .settingsAppearance(.buttonLabel)
                                })
                            }
                        } else if !CLLocationManager.locationServicesEnabled() {
                            HStack {
                                Text("Location off for this device")
                                    .settingsAppearance(.lineLabel)
                                Spacer()
                                Button(action: {
                                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                                }, label: {
                                    Text("Enable Location")
                                        .settingsAppearance(.buttonLabel)
                                })
                            }
                        } else {
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
                        }
//                        switch (locationPermission, coordinatesAvailable) {
//                            case (.appProhibited, _):
//                                HStack {
//                                    Text("Location disabled for Toasty")
//                                        .settingsAppearance(.lineLabel)
//                                    Spacer()
//                                    Button(action: {
//                                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
//                                    }, label: {
//                                        Text("Change Settings")
//                                            .settingsAppearance(.buttonLabel)
//                                    })
//                                }
//                            case (.deviceProhibited, _):
//                            case (.appAllowed, false), (.unknown, false):
//                            case (_, true):
//                        }
                    }
                    Section(header: Text("Alerts").settingsAppearance(.header)) {
                            if coordinateData != nil {
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
                    if (coordinateData != nil && temperatureAlertsEnabled) {
                        Section(header: Text("temperature alert range").settingsAppearance(.header)) {
                            TemperatureSelector()
                                .padding(.top, 25)
                                .padding(.bottom, 10)
                        }
                    }
                    if weatherError != nil, coordinateData != nil, temperatureAlertsEnabled {
                        Section(header: Text("Weather Error").settingsAppearance(.header)) {
                            VStack (alignment: .leading)
                            {
                                HStack {
                                    Text("Could not get outside temperature")
                                    Spacer()
                                    Button(action: {
                                        Task {
                                            do {
                                               try await WeatherMonitor.shared.updateWeatherConditions()
                                                self.weatherError = nil
                                            } catch {
                                                self.weatherError = error
                                            }
                                        }
                                    }, label: {
                                        Text("Try Again")
                                            .settingsAppearance(.buttonLabel)
                                    })
                                }
                            Text ( (weatherError! as? ConnectionError).map { $0.description } ?? weatherError!.localizedDescription )
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
                                    coordinateData = initCoord
                                    Storage.highTempLimit = initHighTempLimit
                                    Storage.lowTempLimit = initLowTempLimit
                                    activeSheet = nil
                                }
                                Spacer()
                                Text("Settings").font(.largeTitle)
                                Spacer()
                                Button("Update") {
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
            initCoord = coordinateData
            initLowTempLimit = Storage.highTempLimit
            initHighTempLimit = Storage.lowTempLimit
        })
        .onChange(of: interlockAlertsEnabled, perform: { enabled in
            UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in
                if settings.authorizationStatus != .authorized {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge], completionHandler: { (approved, _) in
                        if !approved {
                            interlockAlertsEnabled = false
                            temperatureAlertsEnabled = false
                        }
                    })
                }
            })
        })
        .onChange(of: temperatureAlertsEnabled, perform: { enabled in
            UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in
                if settings.authorizationStatus != .authorized {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge], completionHandler: { (approved, _) in
                        if !approved {
                            interlockAlertsEnabled = false
                            temperatureAlertsEnabled = false
                        }
                    })
                }
            })
        })
    }
}

struct TemperatureSelector: View {
    @AppStorage(StorageKey.lowTempLimit.rawValue) var lowTempLimit: Double?
    @AppStorage(StorageKey.highTempLimit.rawValue) var highTempLimit: Double?
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
                var labelStyle = RangeSlider.LabelStyle()
                labelStyle.formatter = { val in
                    let formatter = MeasurementFormatter()
                    let nFormatter = NumberFormatter()
                    nFormatter.maximumFractionDigits = 0
                    formatter.unitOptions = .temperatureWithoutUnit
                    formatter.numberFormatter = nFormatter
                    let val = Measurement(value: val, unit: UnitTemperature.fahrenheit)
                    return formatter.string(from: val)
                }
                labelStyle.color = .main
                style.labelStyle = labelStyle
            },
            leftHandleFormatter: { style in
                style.size = CGSize(width: 30, height: 30)
                style.strokeColor = .blue
                style.strokeWeight = 2.0
                style.labelOffset = CGSize(width: 0, height: -30)
                var labelStyle = RangeSlider.LabelStyle()
                labelStyle.formatter = { val in
                    let formatter = MeasurementFormatter()
                    let nFormatter = NumberFormatter()
                    nFormatter.maximumFractionDigits = 0
                    formatter.unitOptions = .temperatureWithoutUnit
                    formatter.numberFormatter = nFormatter
                    let val = Measurement(value: val, unit: UnitTemperature.fahrenheit)
                    return formatter.string(from: val)
                }
                labelStyle.color = .main
                style.labelStyle = labelStyle
            })
            .onChange(of: lowTemp) { newLowTemp in
                lowTempLimit = Measurement(value: newLowTemp, unit: UnitTemperature.fahrenheit).value
            }
            .onChange(of: highTemp) { newHighTemp in
                highTempLimit = Measurement(value: newHighTemp, unit: UnitTemperature.fahrenheit).value
            }
            .onAppear(perform: {
                lowTempLimit = lowTemp
                highTempLimit = highTemp
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
        @AppStorage(StorageKey.coordinate.rawValue) var coordData: Data?
        coordData = CLLocation(latitude: 38, longitude: -122).data
        return Location()
    }
    static var previews: some View {
        NavigationView {
            SettingsView(activeSheet: .constant(nil))
        }
                    .preferredColorScheme(.dark)
                    .environmentObject(WeatherMonitor.shared)
                    .environmentObject(loc)
                    .environment(\.locale, .init(identifier: "de"))

    }
}
