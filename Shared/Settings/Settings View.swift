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
            SettingsWeatherErrorSection ( viewModel: viewModel )
        }
        .foregroundColor(.pageBackground)
        .listStyle(GroupedListStyle())
        .alert(
            "Not Available",
            isPresented: $showAlert,
            actions: {
                Button(viewModel.settingsError?.recoverySuggestion ?? "") {
                    Task { await viewModel.settingsError?.resolve() }
                }
            },
            message: {
                Text(viewModel.settingsError?.failureReason ?? "")
            })
        
        Spacer()
        
            .background(Color.pageBackground)
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
            .onAppear(perform: {
                viewModel.appeared()
            })
            .onChange(of: viewModel.settingsError) { newValue in
                showAlert = newValue != nil
            }
    }
}

struct SettingsLocationSection: View {
    var viewModel: SettingViewModel
    
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
                    Spacer()
                    Button(action: {
                        viewModel.clearLocation()
                    }, label: {
                        Text("Erase Location")
                            .settingsAppearance(.buttonLabel)
                    })
                }
            case .unknown:
                HStack {
                    Text("Location unknown")
                    Spacer()
                    Button(action: {
                        Task { await viewModel.updateLocation() }
                    }, label: {
                        Text("Set Location")
                            .settingsAppearance(.buttonLabel)
                    })
                }
            case .unavailable:
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
            @unknown default:
                EmptyView()
            }
        }
    }
}

struct SettingsSwitchesSection: View {
    var viewModel: SettingViewModel
    @AppStorage(StorageKey.interlockAlarmEnabled.rawValue) var interlockAlertsEnabled: Bool = false
    @AppStorage(StorageKey.temperatureAlarmEnabled.rawValue) var temperatureAlertsEnabled: Bool = false
    
    var body: some View {
        VStack {
            Toggle("Interlock", isOn: $interlockAlertsEnabled)
            Toggle("Temperature", isOn: $temperatureAlertsEnabled)
        }
        .toggleStyle(ColoredToggleStyle(onColor: .main, offColor: .gray, thumbColor: .pageBackground))
        
        .onChange(of: interlockAlertsEnabled) { newValue in
            if newValue {
                viewModel.validateInterlockAlert()
            }
        }
        .onChange(of: temperatureAlertsEnabled) { newValue in
            if newValue {
                viewModel.validateTempAlert()
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
    private var viewModel: SettingViewModel
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
