//
//  House Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

class House: ObservableObject {
    typealias IPAddr = String
    private (set) var fanSetPub = CurrentValueSubject<Set<FanCharacteristics>, Never>([])
    var updateProgress: Double? = .zero
    
    func scan () async {
        fanSetPub.send([])
        let decoder = JSONDecoder()
        let config = URLSession.shared.configuration
        config.timeoutIntervalForRequest = 5
        let session = URLSession.init(configuration: config)
        var hosts = NetworkAddress.hosts
        hosts.append("192.168.1.67:8080")
        let totalHosts = Double(hosts.count)
        var checkedHosts = Double.zero
        return await withTaskGroup(of: FanCharacteristics?.self) { group in
            for ip in hosts {
                group.addTask {
                    guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(FanModel.Action.refresh.rawValue)") else {
                        return nil
                    }
                    print("IP: \(url.description)")
                    guard let (data, _) = try? await session.data(from: url) else {
                        return nil
                    }
                    print ("IP got \(ip)")
                    print ("Data len: \(data.count)")
                    return try? decoder.decode(FanCharacteristics.self, from:
                                                (String(data: data, encoding: .ascii) ?? "")
                                                .trimmingCharacters(in: .whitespaces)
                                                .split(separator: "<")
                                                .filter({ !$0.contains("/") && $0.contains(">") })
                                                .map ({ $0.split(separator: ">", maxSplits: 1) })
                                                .map ({ arr -> (String, String?) in
                        let newTuple = (String(arr[0]), arr.count == 2 ? String(arr[1]) : nil)
                        return newTuple
                    })
                                                .jsonData
                    )
                }
            }
            for await fanResult in group {
                checkedHosts += 1
                updateProgress = checkedHosts / totalHosts
                print ("Checked \(checkedHosts) of \(totalHosts) hosts")
                if let chars = fanResult {
                    fanSetPub.value.update(with: chars)
                }
            }
            updateProgress = nil
        }
    }
    
    func remove(_ chars: FanCharacteristics) {
        fanSetPub.value.remove(chars)
    }
}

extension House: HouseDataSource { }

protocol HouseDataSource {
    var fanSetPub: CurrentValueSubject<Set<FanCharacteristics>, Never> { get }
    var updateProgress: Double? { get }
    func scan () async -> Void
    func remove(_: FanCharacteristics) -> Void
}
