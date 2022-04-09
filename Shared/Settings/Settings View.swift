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
            Color.pageBackground
                .ignoresSafeArea(.all, edges: .top)
            VStack {
                List {
                    Section(header: Text("Location").settingsAppearance(.header)) {
                        Group {
                            if coordinateData != nil {
                                HStack {
                                    VStack {
                                        Text("Location saved")
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
                            }
                            else if !CLLocationManager.locationServicesEnabled() {
                                HStack {
                                    Text("Location off for this device")
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
                                    Spacer()
                                    Button(action: {
                                        location.updateLocation()
                                    }, label: {
                                        Text("Set Location")
                                            .settingsAppearance(.buttonLabel)
                                    })
                                }
                            }
                        }
                        .settingsAppearance(.lineLabel)
                        
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
                        Group {
                            VStack {
                                Toggle("Interlock", isOn: $interlockAlertsEnabled)
                                if coordinateData != nil {
                                    Toggle("Temperature", isOn: $temperatureAlertsEnabled)
                                }
                            }
                            .toggleStyle(ColoredToggleStyle(onColor: .main, offColor: .gray, thumbColor: .pageBackground))
                            //                                .tint(.main)
                            //                            else {
                            //                                Toggle("Interlock", isOn: $interlockAlertsEnabled)
                            //                                    .toggleStyle(SwitchToggleStyle(tint: .main))
                            //                            }
                        }
                    }
                    .settingsAppearance(.lineLabel)
                    
                    if (coordinateData != nil && temperatureAlertsEnabled) {
                        Section(header: Text("temperature alert range").settingsAppearance(.header)) {
                            TemperatureSelector(tempAlertsEnabled: $temperatureAlertsEnabled)
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
                                            try await WeatherMonitor.shared.updateWeatherConditions ()
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
                    //                        }
                    //                    }
                }
                .foregroundColor(.pageBackground)
                .listStyle(GroupedListStyle())
            }
        }
            //            Spacer()
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
                                Task {
                                    try? await WeatherMonitor.shared.updateWeatherConditions()
                                }
                                activeSheet = nil
                            }
                        }
                        Divider()
                            .ignoresSafeArea(.all, edges: [.leading, .trailing])
                            .background(Color.main)
                        Spacer()
                    }
                    .foregroundColor(.main)
                }
            }
        .navigationBarBackButtonHidden(true)
        .onAppear(perform: {
            initTempAlertsEnabled = temperatureAlertsEnabled
            initInterlockAlertsEnabled = interlockAlertsEnabled
            initCoord = coordinateData
            initLowTempLimit = Storage.lowTempLimit
            initHighTempLimit = Storage.highTempLimit
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
        @Binding var tempAlertsEnabled: Bool
        @State private var lowTemp: Double = 55
        @State private var highTemp: Double = 80
        private var minTempScale: Double {
            return UnitTemperature.current == UnitTemperature.fahrenheit ? 40.0 : Measurement(value: 5.0, unit: UnitTemperature.celsius).converted(to: .fahrenheit).value
        }
        private var maxTempScale: Double {
            return UnitTemperature.current == UnitTemperature.fahrenheit ? 85.0 : Measurement(value: 30.0, unit: UnitTemperature.celsius).converted(to: .fahrenheit).value
        }
        
        private func initHiLowTemps () {
            let cLow = Measurement(value: 13.0, unit: UnitTemperature.celsius).converted(to: .fahrenheit).value
            let cHigh = Measurement(value: 27.0, unit: UnitTemperature.celsius).converted(to: .fahrenheit).value
            let lowDef = UnitTemperature.current == .fahrenheit ? 55.0 : cLow
            let highDef = UnitTemperature.current == .fahrenheit ? 80.0 : cHigh
            let candidateLowTemp = lowTempLimit ?? lowDef
            let candidateHighTemp = highTempLimit ?? highDef
            lowTemp = candidateLowTemp.clamped(to: (minTempScale...Swift.min(candidateHighTemp, highDef)))
            highTemp = candidateHighTemp.clamped(to: (Swift.max(lowDef, candidateLowTemp)...maxTempScale))
            lowTempLimit = lowTemp
            highTempLimit = highTemp
        }
        
        var body: some View {
            RangeSlider(
                selectedLow: $lowTemp,
                selectedHigh: $highTemp,
                minimum: minTempScale,
                maximum: maxTempScale,
                barFormatter: { style in
                    style.barInsideFill = .main
                    style.barOutsideFill = .pageBackground
                    style.barOutsideStrokeColor = .main
                    style.barOutsideStrokeWeight = 0.75
                    style.barHeight = 7.0
                },
                rightHandleFormatter: { style in
                    style.fill = .pageBackground
                    style.size = CGSize(width: 30, height: 30)
                    style.strokeColor = .red
                    style.strokeWeight = 2.0
                    style.labelOffset = CGSize(width: 0, height: -30)
                    var labelStyle = RangeSlider.LabelStyle()
                    labelStyle.formatter = { val in
                        let formatter = MeasurementFormatter()
                        let nFormatter = NumberFormatter()
                        nFormatter.maximumFractionDigits = UnitTemperature.current == .fahrenheit ? 0 : 1
                        formatter.unitOptions = .temperatureWithoutUnit
                        formatter.numberFormatter = nFormatter
                        let val = Measurement(value: val, unit: UnitTemperature.fahrenheit)
                        return formatter.string(from: val)
                    }
                    labelStyle.color = .main
                    style.labelStyle = labelStyle
                },
                leftHandleFormatter: { style in
                    style.fill = .pageBackground
                    style.size = CGSize(width: 30, height: 30)
                    style.strokeColor = .blue
                    style.strokeWeight = 2.0
                    style.labelOffset = CGSize(width: 0, height: -30)
                    var labelStyle = RangeSlider.LabelStyle()
                    labelStyle.formatter = { val in
                        let formatter = MeasurementFormatter()
                        let nFormatter = NumberFormatter()
                        nFormatter.maximumFractionDigits = UnitTemperature.current == .fahrenheit ? 0 : 1
                        formatter.unitOptions = .temperatureWithoutUnit
                        formatter.numberFormatter = nFormatter
                        let val = Measurement(value: val, unit: UnitTemperature.fahrenheit)
                        return formatter.string(from: val)
                    }
                    labelStyle.color = .main
                    style.labelStyle = labelStyle
                })
            .onChange(of: lowTemp) { newLowTemp in
                let nlt = (newLowTemp * 10).rounded() / 10
                lowTempLimit = Measurement(value: nlt, unit: UnitTemperature.fahrenheit).value
            }
            .onChange(of: highTemp) { newHighTemp in
                let nht = (newHighTemp * 10).rounded() / 10
                highTempLimit = Measurement(value: nht, unit: UnitTemperature.fahrenheit).value
            }
            .onChange(of: tempAlertsEnabled) { enabled in
                if enabled { initHiLowTemps() }
            }
            .onAppear(perform: {
                initHiLowTemps()
            })
        }
    }
    
    struct SettingsAppearance: ViewModifier {
        enum Position { case header, lineLabel, buttonLabel }
        var position: Position
        func body(content: Content) -> some View {
            switch position {
                case .lineLabel:
                    content
                        .foregroundColor(.main)
                        .background(Color.clear)
                case .buttonLabel:
                    content
                        .padding(5)
                        .background(Color.main)
                        .clipShape(RoundedRectangle(cornerRadius: 5.0))
                        .foregroundColor(Color.pageBackground)
                case .header:
                    content
                        .foregroundColor(Color.main)
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
