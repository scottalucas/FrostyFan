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
    private (set) var progress = PassthroughSubject<Double?, Never>()
    var scan: () async -> Void {
        return {
            await self.scanForFans()
        }
    }
    
    private func scanForFans () async {
        var hosts = NetworkAddress.hosts
        hosts.append("192.168.1.67:8080")
        let totalHosts = Double(hosts.count)
        var checkedHosts = Double.zero
        guard totalHosts > 0 else { return }
        fanSetPub.send([])
        let config = URLSession.shared.configuration
        config.timeoutIntervalForRequest = 5
        let session = URLSession.init(configuration: config)
        progress.send(0.0)
        await withTaskGroup(of: (IPAddr, Data?).self) { group in
            for ip in hosts {
                guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(FanModel.Action.refresh.rawValue)") else { continue }
                group.addTask {
                    let d = try? await session.data(from: url).0
                    return (ip, d)
                }
            }
            for await (ipAddr, optData) in group {
                checkedHosts += 1
                progress.send ( checkedHosts / totalHosts )
                if let newData = optData, var chars = FanCharacteristics(data: newData) {
                    chars.ipAddr = ipAddr
                    fanSetPub.value.update(with: chars)
                }
            }
            progress.send(nil)
        }
    }
    
    func remove(_ chars: FanCharacteristics) {
        fanSetPub.value.remove(chars)
    }
}

extension House: HouseDataSource { }

protocol HouseDataSource {
    var fanSetPub: CurrentValueSubject<Set<FanCharacteristics>, Never> { get }
    var progress: PassthroughSubject<Double?, Never> { get }
    var scan: () async -> Void { get }
    func remove(_: FanCharacteristics) -> Void
}
