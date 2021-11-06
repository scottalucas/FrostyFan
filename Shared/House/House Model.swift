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
    //    static let shared = House()
    @Published var fans = Set<FanCharacteristics>() //IP addresses
    @Published var progress: Double?
    @Published var isRefreshing = false
    @Published var pulldownDistance = Double.zero
    
    private var addressCount: Int = 0 {
        didSet {
            progress = updateProgress()
        }
    }
    private var addressesChecked: Int = 0 {
        didSet {
            progress = updateProgress()
            print ( progress.map { String( format: "%.2f", $0 ) } ?? "fault" )
        }
    }
    
    func scan () {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
//            await scannerAsync()
            await Task.sleep(2_000_000_000)
            isRefreshing = false
        }
    }
    
    init (testFan fan: FanCharacteristics = FanCharacteristics()) {
        fans.update(with: fan)
    }
    
   func scannerAsync () async {
        defer {print("finished")}
        return await withTaskGroup(of: (String, FanCharacteristics?).self ) { group in
            var seq = NetworkAddress.hosts
            seq.append("192.168.1.67:8080")
            addressCount = seq.count
            for addr in seq {
                group.addTask {
                    let chars = try? await FanStatusLoader(addr: addr).loadResultsAsync(action: .refresh)
                    return (addr, chars)
                }
            }
            for await (addr, optChars) in group {
                guard let chars = optChars else { return }
                print("Addr: \(addr), chars: \(chars)")
                var newFan = chars
                newFan.ipAddr = addr
                fans.update(with: newFan)
            }
//        return group
        }
    }
    
    private func updateProgress () -> Double? {
        guard addressCount > 0 else { return nil }
        guard addressesChecked/addressCount < 1 else { return 1.0 }
        return Double(addressesChecked) / Double(addressCount)
    }
//    func asyncScanForFans () {
//        Task {
//            for try await (addr, fan) in scannerAsync {
//                fan.ipAddr = addr
//                fans.update(with: fan)
//            }
//        }
    }
    
//    func scanForFans () {
//        guard !status.contains(.scanning) else { return }
//        print("start scanning")
//        status.insert(.scanning)
//        status.insert(.noFansAvailable)
//        fans.removeAll()
//        scanner
//            .timeout(.seconds(15), scheduler: DispatchQueue.global())
//            .receive(on: DispatchQueue.main)
//            .sink(receiveCompletion: { [weak self] comp in
//                guard let self = self else { return }
//                self.status.remove(.scanning)
//                if case .finished = comp {
//                    print ("scan complete")
//                }
//                if case .failure (let err) = comp {
//                    print ("error: \(err)")
//                }
//            }, receiveValue: { [weak self] (ipAddr, chars) in
//                print ("Found fan addr: \(ipAddr)")
//                var modChars = chars
//                modChars.ipAddr = ipAddr
//                self?.fans.update(with: modChars)
//                self?.status.remove(.noFansAvailable)
//            })
//            .store(in: &bag)
//    }
//}

//extension House {
//    var scanner: AnyPublisher<(String, FanCharacteristics), ConnectionError> {
//        return
//        NetworkAddress.hosts.publisher
//            .prepend("192.168.1.67:8080") //testing
//            .setFailureType(to: ConnectionError.self)
//            .flatMap ({ addr -> AnyPublisher<(IPAddr, FanCharacteristics), ConnectionError> in
//                return FanStatusLoader(addr: addr).loadResults(action: .refresh)
//                    .catch({ _ in
//                        Empty.init(completeImmediately: false)
//                    })
//                            .map { [addr] chars in (addr, chars) }
//                    .eraseToAnyPublisher()
//            })
//            .eraseToAnyPublisher()
//    }
//}

//extension House {
//    var scanner: AnyPublisher<(String, FanCharacteristics), ConnectionError> {
//        return
//            Just ("192.168.1.67:8080") //testing
//                                       //        NetworkAddress.hosts.publisher
//                                       //            .prepend("192.168.1.67:8080") //testing
//            .asyncMap { addr in
//                let chars = try await FanStatusLoader(addr: addr).loadResultsAsync(action: .refresh)
//                return (addr, chars)
//            }
//            .mapError { $0 as? ConnectionError ?? ConnectionError.cast($0) }
//            .eraseToAnyPublisher()
//    }
//}

