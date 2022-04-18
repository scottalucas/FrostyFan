//
//  Network resources.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import Combine
import Network

struct NetworkAddress {
    static var hosts: [String] {
        (firstHost...lastHost)
            .map ({ hostIpInt in
                [3, 2, 1, 0].map({ index in (UInt8(hostIpInt >> (index * 8) & UInt32(0xFF))) })
            })
            .compactMap ({ hostIpArr in
                guard
                    hostIpArr.count == 4,
                    (0...255).contains(hostIpArr[0]),
                    (0...255).contains(hostIpArr[1]),
                    (0...255).contains(hostIpArr[2]),
                    (0...255).contains(hostIpArr[3]) else { return nil }
                return "\(hostIpArr[0]).\(hostIpArr[1]).\(hostIpArr[2]).\(hostIpArr[3])" })
        //            ["0.0.0.0:8181"] //testing only
    }
    
    private static var netInfo: (address: UInt32, mask: UInt32)? {
        struct NetInfo {
            var ip: String
            var netmask: String
        }
        // Get list of all interfaces on the local machine:
        var addresses = [NetInfo]()
        var ifaddr : UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            
            var ptr = ifaddr;
            while ptr != nil {
                
                let flags = Int32((ptr?.pointee.ifa_flags)!)
                var addr = ptr?.pointee.ifa_addr.pointee
                let interface = ptr?.pointee
                // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
                if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    if addr?.sa_family == UInt8(AF_INET) || addr?.sa_family == UInt8(AF_INET6) {
                        var name = ""
                        if let interf = interface, let nmCStr = interf.ifa_name {
                            name = String(cString: (nmCStr))
                        }
                        if name == "en0"
                        {
                        // Convert interface address to a human readable string:
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if (getnameinfo(&addr!, socklen_t((addr?.sa_len)!), &hostname, socklen_t(hostname.count),
                                        nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                            if let address = String.init(validatingUTF8:hostname) {
                                
                                var net = ptr?.pointee.ifa_netmask.pointee
                                var netmaskName = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                                getnameinfo(&net!, socklen_t((net?.sa_len)!), &netmaskName, socklen_t(netmaskName.count),
                                            nil, socklen_t(0), NI_NUMERICHOST)// == 0
                                if let netmask = String.init(validatingUTF8:netmaskName) {
                                    addresses.append(NetInfo(ip: address, netmask: netmask))
                                }
                            }
                        }
                        }
                    }
                }
                ptr = ptr?.pointee.ifa_next
            }
            freeifaddrs(ifaddr)
        }
        //        let arr = addresses[0].ip.split(separator: ".").compactMap({ UInt8.init($0) })
        let firstIP4Addr = addresses
            .first(where: { netInfo in netInfo.ip.split(separator: ".").count == 4 })
        
        let firstIP4AddrArr =
        firstIP4Addr?
            .ip
            .split(separator: ".")
            .compactMap({ UInt8.init($0) }) ?? []
        
        let firstIP4MaskArr =
        firstIP4Addr?
            .netmask
            .split(separator: ".")
            .compactMap({ UInt8.init($0) }) ?? []
        
        guard
            firstIP4AddrArr.count == 4,
            (
                firstIP4AddrArr[0] == 10)
                || (firstIP4AddrArr[0] == 172 && (16...31).contains(firstIP4AddrArr[1]))
                || (firstIP4AddrArr[0] == 192 && firstIP4AddrArr[1] == 168
                )
                //                ,
                //            (0..<255).contains(firstIP4AddrArr[0]),
                //            (0..<255).contains(firstIP4AddrArr[1]),
                //            (0..<255).contains(firstIP4AddrArr[2]),
                //            (0..<255).contains(firstIP4AddrArr[3])
        else { return nil }
        let finalAddr = UInt32(firstIP4AddrArr.reduce(0) { $0 << 8 | Int($1) })
        
        //        let firstIP4MaskArr = addresses[0].netmask.split(separator: ".").compactMap({ UInt8.init($0) })
        guard
            firstIP4MaskArr.count == 4,
            (0...255).contains(firstIP4MaskArr[0]),
            (0...255).contains(firstIP4MaskArr[1]),
            (0...255).contains(firstIP4MaskArr[2]),
            (0...255).contains(firstIP4MaskArr[3]) else { return nil }
        let finalMask = UInt32(firstIP4MaskArr.reduce(0) { $0 << 8 | Int($1) })
        
        return (finalAddr, finalMask)
    }
    private static var netId: UInt32? {
        guard let a = netInfo?.address, let m = netInfo?.mask else { return nil }
        return a & m
    }
    private static var firstHost: UInt32 {
        guard let i = netId else { return 0 }
        return i + 1
    }
    private static var lastHost: UInt32 {
        guard let m = netInfo?.mask, let n = netId else { return 0 }
        return (~m | (n)) - 1
    }
}

class URLSessionMgr {
    static var shared: URLSessionMgr = URLSessionMgr ()
    var networkAvailable: CurrentValueSubject<Bool, Never> = .init(false)
    private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let queue = DispatchQueue(label: "Monitor")
    private var gateway: NWEndpoint?
    var session: URLSession {
        let config = URLSession.shared.configuration
        config.timeoutIntervalForRequest = House.scanDuration
        config.waitsForConnectivity = true
        config.allowsCellularAccess = false
        config.allowsExpensiveNetworkAccess = false
        return URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }
    
    private init () { start() }
    
    private func start() {
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied && !path.isExpensive && !NetworkAddress.hosts.isEmpty { //make sure path is appropriate for scanning
                self.networkAvailable.send(true)
            } else {
                Log.house.error("network unavailable, status : \(path.status), expensive: \(path.isExpensive), host count: \(NetworkAddress.hosts.count)")
                self.networkAvailable.send(false)
            }
        }
        monitor.start(queue: queue)
    }
}
