//
//  Fan Model View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

class FanViewModel: ObservableObject {
    @ObservedObject var model: FanModel
    @Published var fanRotationDuration: Double = 0.0
    @Published var speed: Int = -1
    @Published var opening: String = "No"
    @Published var airspaceFanModel: String = "Model number"
    @Published var macAddr: String?
    @Published var name = "Fan"
    @Published var controllerSegments: [String] = ["Off", "On"]
    @Published var interlocked: Bool = false
    private var userSpeedChange: Bool?
    
    private var bag = Set<AnyCancellable>()
    
    init (forModel model: FanModel) {
        self.model = model
        startSubscribers()
        print("init fan view model \(model.ipAddr)")
    }
    
    private func fanCommFailed(withError commErr: Error) -> AnyPublisher<Int, AdjustmentError> {
        let err: AdjustmentError = commErr as? AdjustmentError ?? .upstream(commErr)
        return Fail<Int, AdjustmentError>.init(error: err).eraseToAnyPublisher()
    }
    
    func setFan(toSpeed finalTarget: Int?) {
        model.setFan(toSpeed: finalTarget)
    }

    func getView () -> some View {
        FanView(fanViewModel: self)
    }
}

extension FanViewModel {
    convenience init () {
        self.init(forModel: FanModel())
    }
}

extension FanViewModel {
    static var speedTable: [String:Int]  = [
        "3.5e" : 7,
        "4.4e" : 7,
        "5.0e" : 7,
        "2.5e" : 5,
        "3200" : 10,
        "3400" : 10,
        "4300" : 10,
        "5300" : 10
    ]
}

extension FanViewModel {
    func startSubscribers () {
        
        $speed
            .filter { [weak self] _ in return self?.userSpeedChange ?? false }
            .sink(receiveValue: { [weak self] newSpeed in
                guard let self = self else { return }
                self.model.setFan(toSpeed: newSpeed)
            })
            .store(in: &bag)
        
        model.$chars
            .map { FanModel.FanKey.getValue(forKey: .macAddr, fromTable: $0) ?? "Not found" }
            .map { UserSettings().names[$0] ?? "Fan" }
            .receive(on: DispatchQueue.main)
            .assign(to: &$name)
        
        model.$chars
            .map { FanModel.FanKey.getValue(forKey: .macAddr, fromTable: $0) ?? "Not found" }
            .receive(on: DispatchQueue.main)
            .assign(to: &$macAddr)
        
        model.$chars
            .map { (FanModel.FanKey.getValue(forKey: .speed, fromTable: $0) ?? "-1") }
            .map { Int($0) ?? -1 }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] newSpeed in
                guard let self = self else { return }
                self.userSpeedChange = false
                self.speed = newSpeed
                self.userSpeedChange = true
            })
            .store(in: &bag)
        
        model.$chars
            .map { (FanModel.FanKey.getValue(forKey: .speed, fromTable: $0) ?? "0.0") }
            .map { Double($0) ?? 0.0 }
            .map { $0 == 0.0 ? 0.0 : 1.0/$0 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$fanRotationDuration)
        
        model.$chars
            .map { (FanModel.FanKey.getValue(forKey: .model, fromTable: $0) ?? "") }
            .map { FanViewModel.speedTable[String($0.prefix(4))] ?? 1 }
            .map { count -> [String] in Range(0...count).map { String($0) } }
            .map {
                var newArr = $0
                newArr[$0.startIndex] = "Off"
                newArr[$0.endIndex - 1] = $0.count <= 2 ? "On" : "Max"
                return newArr
            }
            .assign(to: &$controllerSegments)
        
        model.$chars
            .map { ((FanModel.FanKey.getValue(forKey: .interlock1, fromTable: $0) ?? "0", FanModel.FanKey.getValue(forKey: .interlock2, fromTable: $0) ?? "0")) }
            .map { (Int($0) ?? 0) == 1 || (Int($1) ?? 0) == 1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$interlocked)
    }
}
