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
    @Published var actualSpeed: Int = -1
    @Published var opening: String = "No"
    @Published var airspaceFanModel: String = "Model number"
    @Published var macAddr: String?
    @Published var name = "Fan"
    @Published var controllerSegments: [String] = ["Off", "On"]
    @Published var interlocked: Bool = false
    private var speedAdjustmentPublisher: AnyCancellable?
    var speedIsAdjusting: Bool = false {
        didSet {
            print ("Set speed is adjusting to \(speedIsAdjusting)")
        }
    }
    private var userSpeedTarget: Int? = nil //nil before an adjustment has been requested
    private var bag = Set<AnyCancellable>()
    
    init (forModel model: FanModel) {
        self.model = model
        startSubscribers()
    }
    
    func setSpeed (to: Int) {
        guard to != actualSpeed else { return }
        let slowTimer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .eraseToAnyPublisher()
        let fastTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .eraseToAnyPublisher()
        let timerSource = PassthroughSubject<AnyPublisher<Date, Never>, Never>()
        
        speedAdjustmentPublisher = adjust(toSpeed: to, usingTimerSource: timerSource.eraseToAnyPublisher())
            .print("Adjust publisher")
            .sink(receiveCompletion: { [weak self] comp in
                guard let self = self else { return }
                switch comp {
                case .failure(let err):
                    print("Failed to adjust, error: \(err.localizedDescription)")
                case .finished:
                    print("successful adjust, requested speed: \(to) actual speed: \(self.actualSpeed.description)")
                }
            }, receiveValue: { [weak self] lastSpeed in
                guard let self = self else { return }
                if lastSpeed == to { self.speedAdjustmentPublisher?.cancel(); return }
                if lastSpeed > 0 { timerSource.send(fastTimer) }
            })
        if actualSpeed == 0 { timerSource.send(slowTimer) } else { timerSource.send(fastTimer) }
    }
    
    func getView () -> some View {
        FanView(fanViewModel: self)
    }
    
    private func adjust (toSpeed target: Int, usingTimerSource timerSource: AnyPublisher<AnyPublisher<Date, Never>, Never>) -> AnyPublisher <Int, FanViewModel.AdjustmentError> {
        typealias err = FanViewModel.AdjustmentError
        
        func fail(withError: Error) -> AnyPublisher<Int, FanViewModel.AdjustmentError> {
            let err: FanViewModel.AdjustmentError = withError as? FanViewModel.AdjustmentError ?? .unknownError(withError.localizedDescription)
            return Fail<Int, FanViewModel.AdjustmentError>.init(error: err).eraseToAnyPublisher()
        }
//
//        func getAction (actualSpeed aSpd: Int, targetSpeed tSpd: Int) -> throws FanModel.Action {
//
//            switch (actualSpeed, target) {
//            case (_, 0):
//                command = .off
//            case let (a, _) where a == -1:
//                command = .refresh
//            case let (a, t) where a < t:
//                command = .faster
//            case let (a, t) where a > t:
//                command = .slower
//            case let (a, t) where a == t:
//                return throw AdjustmentError.notNeeded
//            default:
//                return throw AdjustmentError.notReady("Actual: \(actualSpeed.description) target: \(userSpeedTarget?.description ?? "Nil")"))
//            }
//        }
        
        return timerSource
            .prepend ( Just(Date()).eraseToAnyPublisher() )
            .switchToLatest()
//            .filter { [weak self] _ in self?.actualSpeed != target }
            .flatMap { [weak self] _ -> AnyPublisher<Int, FanViewModel.AdjustmentError> in
                guard let self = self else { return fail(withError: err.parentOutOfScope) }
                let oldSpeed = self.actualSpeed
                return self.model.adjustFan(action: .refresh)
                    .retry(3)
                    .mapError { e in
                        err.retrievalError(e)
                    }
                    .receive(on: DispatchQueue.main)
                    .tryMap {
                        self.model.chars = $0
                        guard let nSpd = FanValue.getValue(forKey: .speed, fromTable: $0), let newSpeed = Int(nSpd) else { throw err.retrievalError(.unknown("Bad values returned.")) }
//                        guard newSpeed != oldSpeed else { throw err.speedDidNotChange }
                        if newSpeed == oldSpeed { print ("Warning, speed did not change.") }
                        return newSpeed
                    }
                    .catch { e in fail(withError: e) }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
   
    private func test () -> AnyPublisher<Dictionary<String, String?>, FanModel.ConnectionError> {
        return model.adjustFan(action: .faster).eraseToAnyPublisher()
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
    enum AdjustmentError: Error {
        case notReady (String)
        case notNeeded
        case retrievalError(FanModel.ConnectionError)
        case parentOutOfScope
        case speedDidNotChange
        case unknownError (String)
    }
}

extension FanViewModel {
    func startSubscribers () {
        model.$chars
            .map { FanValue.getValue(forKey: .macAddr, fromTable: $0) ?? "Not found" }
            .map { UserSettings().names[$0] ?? "Fan" }
            .receive(on: DispatchQueue.main)
            .assign(to: &$name)
        
        model.$chars
            .map { FanValue.getValue(forKey: .macAddr, fromTable: $0) ?? "Not found" }
            .receive(on: DispatchQueue.main)
            .assign(to: &$macAddr)
        
        model.$chars
            .map { (FanValue.getValue(forKey: .speed, fromTable: $0) ?? "-1") }
            .map { Int($0) ?? -1 }
            .print("Char publisher")
            .receive(on: DispatchQueue.main)
            .assign(to: &$actualSpeed)
        
        model.$chars
            .map { (FanValue.getValue(forKey: .speed, fromTable: $0) ?? "0.0") }
            .map { Double($0) ?? 0.0 }
            .map { $0 == 0.0 ? 0.0 : 1.0/$0 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$fanRotationDuration)
        
        model.$chars
            .map { (FanValue.getValue(forKey: .model, fromTable: $0) ?? "") }
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
            .map { ((FanValue.getValue(forKey: .interlock1, fromTable: $0) ?? "0", FanValue.getValue(forKey: .interlock2, fromTable: $0) ?? "0")) }
            .map { (Int($0) ?? 0) == 1 || (Int($1) ?? 0) == 1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$interlocked)

//        slowTimer
//            .setFailureType(to: URLError.self)
//            Just(true)
//                .flatMap { sw in
//                    .delay(1.0)
//                }
//            .map { _ in
//                URL(string: "http://0.0.0.0:8181")!            }
//            .flatMap { url in
//                URLSession.shared.dataTaskPublisher(for: url)
//            }
////            .print()
//            .sink(receiveCompletion: { comp in
//                print ("Completion: \(comp)")
//            }, receiveValue: { val in
//                print("val: \(val)")
//            })
//            
//            .store(in: &bag)
        
        //        model.$speed //speed adjustment subscriber.
        //            .filter { [weak self] _ in
        //                guard let self = self else { return false }
        //                return self.speedIsAdjusting == true
        //            } //abandon if speedIsAdjusting == false or the object's been deallocated
        //            .compactMap { [weak self] optAct -> (Int, Int)? in
        //                guard let self = self else { return nil }
        //                guard let act = optAct, let req = self.requestedSpeed else {
        //                    self.speedIsAdjusting = false
        //                    return nil
        //                } // turn off speedIsAdjusting flag and abandon if we are already at the requested speed
        //                return (act, req)
        //            }
        //            .map { (act, req) -> FanModel.Action in
        //                switch (act, req) {
        //                case let (a, r) where a == r:
        //                    self.speedIsAdjusting = false
        //                    return .refresh
        //                case (_, 0):
        //                    return .off
        //                case let (a, r) where a > r:
        //                    return .slower
        //                case let (a, r) where a < r:
        //                    return .faster
        //                default:
        //                    self.speedIsAdjusting = false
        //                    return .refresh
        //                }
        //            }
        //            .throttle(for: .seconds(throttleInterval), scheduler: DispatchQueue.main, latest: true)
        //            .sink { [weak self] action in
        //                self?.model.update(action)
        //                }
        //            .store(in: &bag)
        
        
    }
}
