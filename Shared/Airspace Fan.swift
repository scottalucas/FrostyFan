//
//  whf001App.swift
//  Shared
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

@main
struct AirspaceFanApp: App {

    var body: some Scene {
        WindowGroup {
            
            ContentView()
        }
    }
}

enum Setting {
    static let fans = "fans"
}

struct FanSettings {
    var fans = [String: Fan]()
    struct Fan {
        var lastIp = String()
        var name: String?
    }
}

extension FanSettings: Codable, RawRepresentable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode(FanSettings.self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
            let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

extension Array where Element == (String, String?) {
    var jsonData: Data? {
        let newDict = Dictionary(self, uniquingKeysWith: { (first, _) in first })
        guard let data = try? JSONSerialization.data(withJSONObject: newDict) else {
            return nil
        }
        return data
    }
}
