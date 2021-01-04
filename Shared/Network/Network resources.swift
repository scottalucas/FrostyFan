//
//  Network resources.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import Combine

struct NetworkAddress {
    static var hosts: [String] {
//        (firstHost...lastHost)
//            .map ({ hostIpInt in
//                    [3, 2, 1, 0].map({ index in (UInt8(hostIpInt >> (index * 8) & UInt32(0xFF))) }) })
//            .compactMap ({ hostIpArr in
//                            guard
//                                hostIpArr.count == 4,
//                                (0...255).contains(hostIpArr[0]),
//                                (0...255).contains(hostIpArr[1]),
//                                (0...255).contains(hostIpArr[2]),
//                                (0...255).contains(hostIpArr[3]) else { return nil }
//                            return "\(hostIpArr[0]).\(hostIpArr[1]).\(hostIpArr[2]).\(hostIpArr[3])" })
            ["0.0.0.0:8181"] //testing only
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
        let arr = addresses[0].ip.split(separator: ".").compactMap({ UInt8.init($0) })
        guard
            arr.count == 4,
            (0..<255).contains(arr[0]),
            (0..<255).contains(arr[1]),
            (0..<255).contains(arr[2]),
            (0..<255).contains(arr[3]) else { return nil }
        let finalAddr = UInt32(arr.reduce(0) { $0 << 8 | Int($1) })
        
        let m = addresses[0].netmask.split(separator: ".").compactMap({ UInt8.init($0) })
        guard
            m.count == 4,
            (0...255).contains(m[0]),
            (0...255).contains(m[1]),
            (0...255).contains(m[2]),
            (0...255).contains(m[3]) else { return nil }
        let finalMask = UInt32(m.reduce(0) { $0 << 8 | Int($1) })
        
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

