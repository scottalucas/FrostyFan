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
    @StateObject var viewModel = SettingViewModel()
    @Binding var activeSheet: OverlaySheet?
    @State private var showAlert: Bool = false
    
    var body: some View {
        List {
            SettingsLocationSection ( viewModel: viewModel )
            SettingsSwitchesSection ( viewModel: viewModel )
            if viewModel.temperatureAlertsEnabled {
                Section (header: Text("Temp Alarm Range").settingsAppearance(.header)) {
                    TemperatureSelector(tempAlertsEnabled: $viewModel.temperatureAlertsEnabled)
                        .padding(.top, 25)
                }
            }
            SettingsWeatherErrorSection ( viewModel: viewModel )
        }
        .onChange(of: viewModel.temperatureAlertsEnabled, perform: { newValue in
            Log.settings.info("Temperature alerts \(newValue ? "enabled" : "disabled")")
        })
        .foregroundColor(.pageBackground)
        .listStyle(GroupedListStyle())
        .alert (
            "Not Available",
            isPresented: $showAlert,
            actions: {
                Button ("Cancel") {
                    viewModel.settingsError = nil
                    showAlert = false
                }
                Button(viewModel.settingsError?.recoverySuggestion ?? "") {
                    Task {
                        do {
                            try await viewModel.settingsError?.resolve(using: viewModel)
                            viewModel.settingsError = nil
                        } catch (let err as SettingsError) {
                            viewModel.settingsError = err
                        } catch { }
                    }
                }
            },
            message: {
                Text(viewModel.settingsError?.failureReason ?? "")
            })
        .background(Color.pageBackground)
        .onAppear(perform: {
            viewModel.appeared()
        })
        .onChange(of: viewModel.settingsError) { newValue in
            showAlert = newValue != nil
            Log.settings.info("Error update \( newValue.map { $0.localizedDescription } ?? "error cleared, show alert \(showAlert)" )")
        }
        
        Spacer()
        
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack (alignment: .center, spacing: 0) {
                        HStack (alignment: .firstTextBaseline) {
                            Button("Cancel") {
                                viewModel.cancel()
                                activeSheet = nil
                            }
                            Spacer()
                            Text("Settings").font(.largeTitle)
                            Spacer()
                            Button("Update") {
                                viewModel.commit()
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
    }
    init (activeSheet: Binding<OverlaySheet?>) {
        _activeSheet = activeSheet
    }
}

struct SettingsLocationSection: View {
    @ObservedObject var viewModel: SettingViewModel
    @AppStorage (StorageKey.coordinate.rawValue) var coordinates: Data?
    @ViewBuilder
    var body: some View {
        Section(header: Text("Location").settingsAppearance(.header)) {
            switch viewModel.showLocation {
            case .known(let displayString):
                HStack {
                    VStack {
                        Text("Location saved")
                        Text(displayString)
                            .font(.caption2.italic())
                    }
                    .settingsAppearance(.lineLabel)
                    Spacer()
                    Button(action: {
                        viewModel.clearLocation()
                        viewModel.temperatureAlertsEnabled = false
                    }, label: {
                        Text("Erase Location")
                            .settingsAppearance(.buttonLabel)
                    })
                }
                .onAppear() {
                    Log.settings.info("Known location view shown \(displayString, privacy: .private)")
                }
            case .unknown:
                HStack {
                    Text("Location unknown")
                        .settingsAppearance(.lineLabel)
                    Spacer()
                    Button(action: {
                        Task { await viewModel.updateLocation() }
                    }, label: {
                        Text("Set Location")
                            .settingsAppearance(.buttonLabel)
                    })
                }
                .onAppear() {
                    Log.settings.info("Unknown location view shown")
                }
            case .unavailable:
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
                .onAppear() {
                    Log.settings.info("Unavailable location view shown")
                }
            @unknown default:
                EmptyView()
            }
        }
    }
}

struct SettingsSwitchesSection: View {
    @ObservedObject var viewModel: SettingViewModel
    @AppStorage(StorageKey.interlockAlarmEnabled.rawValue) var interlockAlertsEnabled: Bool = false
    @AppStorage(StorageKey.temperatureAlarmEnabled.rawValue) var temperatureAlertsEnabled: Bool = false
    
    var body: some View {
        Section(header: Text("Alerts").settingsAppearance(.header)) {
            VStack {
                Toggle("Interlock", isOn: $viewModel.interlockAlertsEnabled)
                Toggle("Temperature", isOn: $viewModel.temperatureAlertsEnabled)
            }
            .toggleStyle(ColoredToggleStyle(onColor: .main, offColor: .gray, thumbColor: .pageBackground))
            .settingsAppearance(.lineLabel)
            
            
            .onChange(of: viewModel.interlockAlertsEnabled) { newValue in
                if newValue {
                    viewModel.validateInterlockAlert()
                }
            }
            .onChange(of: viewModel.temperatureAlertsEnabled) { newValue in
                if newValue {
                    viewModel.validateTempAlert()
                }
            }
        }
    }
    
    init( viewModel: SettingViewModel) {
        self.viewModel = viewModel
    }
}

struct SettingsWeatherErrorSection: View {
    @AppStorage(StorageKey.coordinate.rawValue) var coordinateData: Data?
    @AppStorage(StorageKey.temperatureAlarmEnabled.rawValue) var temperatureAlertsEnabled: Bool = false
    @ObservedObject private var viewModel: SettingViewModel
    @ViewBuilder
    var body: some View {
        if
            WeatherMonitor.shared.currentTemp == nil,
            coordinateData != nil,
            temperatureAlertsEnabled {
            Section(header: Text("Weather Error").settingsAppearance(.header)) {
                VStack (alignment: .leading)
                {
                    HStack {
                        Text("Could not get outside temperature")
                            .settingsAppearance(.lineLabel)
                        Spacer()
                        Button(action: {
                            Task { await viewModel.retryTemperature() }
                        }, label: {
                            Text("Try Again")
                                .settingsAppearance(.buttonLabel)
                        })
                    }
                }
            }
            .onAppear() {
                Log.settings.info("Settings weather error shown")
            }
        } else {
            EmptyView()
        }
    }
    init ( viewModel: SettingViewModel) {
        self.viewModel = viewModel
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
            Log.settings.debug("Temp slider enabled: \(enabled)")
            if enabled { initHiLowTemps() }
        }
        .onAppear() {
            Log.settings.debug("Temp slider appeared")
            initHiLowTemps()
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
        return Location.shared
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
