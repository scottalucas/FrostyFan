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
    static let shared = House.init()
    @Published var fansAt = Set<String>() //IP addresses
    @Published private ( set ) var scanning: Bool = false
    private var bag = Set<AnyCancellable>()
    
    private init () {
//        startSubs()
        scanForFans()
    }
    
    func scanForFans () {
        scanning = true
        scanner
            .sink(receiveCompletion: { [weak self] comp in
                self?.scanning = false
                if case .finished = comp {
                    print ("complete")
                }
                if case .failure (let err) = comp {
                    print ("error: \(err)")
                }
            }, receiveValue: { addr in
                print ("Got address: \(addr)")
            })
            .store(in: &bag)
    }
    
    func getView (usingHouse house: House? = nil) -> some View {
        HouseViewModel().getView()
    }
    
    func lostFan(atIp ip: String) {
        fansAt.remove(ip)
    }
}

extension House {
    var scanner: AnyPublisher<String, Never> {
        return
            NetworkAddress.hosts.publisher
            .eraseToAnyPublisher()
            .flatMap ({ host -> AnyPublisher<String, Never> in
                return Just (FanModel.Action.refresh)
                    .adjustFan(at: host)
                    .tryMap { dict in
                        let addr = FanModel.FanKey.getValue(forKey: .ipAddress, fromTable: dict)
                        guard let a = addr else { throw AdjustmentError.notFound }
                        return a }
                    .replaceError(with: "Not found")
                    .filter({ $0 != "Not found" })
                    .timeout(.seconds(10), scheduler: DispatchQueue.main)
                    .eraseToAnyPublisher()
            })
            .eraseToAnyPublisher()
    }
}


struct DummyFanModel {
    var models = [String]()
    
    init () {
        models = ["One", "Two"]
    }
    
    func getView() -> some View {
        Group {
            ForEach ((0..<models.count)) { idx in
                return Text(models[idx])
            }
        }
    }
}

//class TestHouse: House {
//    override init() {
//        super.init()
//        fansAt.update(with: "0.0.0.0:8181")
//    }
//}
