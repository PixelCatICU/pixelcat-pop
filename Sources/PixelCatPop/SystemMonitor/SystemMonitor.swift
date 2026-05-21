import Darwin
import Foundation
import MachO

struct SystemSnapshot: Equatable {
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double
    let networkDownloadRate: UInt64
    let networkUploadRate: UInt64
}

final class SystemMonitor {
    private var previousCPU: CPUTicks?
    private var previousNetwork: NetworkCounters?
    private var previousNetworkDate: Date?

    func sample() -> SystemSnapshot {
        let now = Date()
        let cpu = sampleCPU()
        let memory = sampleMemory()
        let disk = sampleDisk()
        let network = sampleNetwork(now: now)
        return SystemSnapshot(
            cpuUsage: cpu,
            memoryUsage: memory,
            diskUsage: disk,
            networkDownloadRate: network.downloadRate,
            networkUploadRate: network.uploadRate
        )
    }

    private func sampleCPU() -> Double {
        guard let current = CPUTicks.current() else { return 0 }
        defer { previousCPU = current }
        guard let previousCPU else { return 0 }

        let user = current.user - previousCPU.user
        let system = current.system - previousCPU.system
        let idle = current.idle - previousCPU.idle
        let nice = current.nice - previousCPU.nice
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(user + system + nice) / Double(total)))
    }

    private func sampleMemory() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        var totalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0) == 0, totalMemory > 0 else {
            return 0
        }

        var hostPageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &hostPageSize) == KERN_SUCCESS else {
            return 0
        }
        let pageSize = UInt64(hostPageSize)
        let usedPages = UInt64(stats.active_count)
            + UInt64(stats.inactive_count)
            + UInt64(stats.wire_count)
            + UInt64(stats.compressor_page_count)
        return min(1, max(0, Double(usedPages * pageSize) / Double(totalMemory)))
    }

    private func sampleDisk() -> Double {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ]),
            let total = values.volumeTotalCapacity,
            total > 0
        else {
            return 0
        }

        let available = values.volumeAvailableCapacityForImportantUsage ?? Int64(total)
        return min(1, max(0, 1 - Double(available) / Double(total)))
    }

    private func sampleNetwork(now: Date) -> (downloadRate: UInt64, uploadRate: UInt64) {
        guard let current = NetworkCounters.current() else {
            return (0, 0)
        }
        defer {
            previousNetwork = current
            previousNetworkDate = now
        }

        guard let previousNetwork,
              let previousNetworkDate
        else {
            return (0, 0)
        }

        let interval = max(0.1, now.timeIntervalSince(previousNetworkDate))
        let inputDelta = current.inputBytes >= previousNetwork.inputBytes ? current.inputBytes - previousNetwork.inputBytes : 0
        let outputDelta = current.outputBytes >= previousNetwork.outputBytes ? current.outputBytes - previousNetwork.outputBytes : 0
        return (
            UInt64(Double(inputDelta) / interval),
            UInt64(Double(outputDelta) / interval)
        )
    }
}

private struct CPUTicks {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64

    static func current() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }
}

private struct NetworkCounters {
    let inputBytes: UInt64
    let outputBytes: UInt64

    static func current() -> NetworkCounters? {
        var addressPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressPointer) == 0, let firstAddress = addressPointer else {
            return nil
        }
        defer { freeifaddrs(addressPointer) }

        var inputBytes: UInt64 = 0
        var outputBytes: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            let flags = Int32(current.pointee.ifa_flags)
            guard flags & IFF_UP != 0,
                  flags & IFF_LOOPBACK == 0,
                  let data = current.pointee.ifa_data
            else {
                continue
            }

            let interfaceData = data.assumingMemoryBound(to: if_data.self).pointee
            inputBytes += UInt64(interfaceData.ifi_ibytes)
            outputBytes += UInt64(interfaceData.ifi_obytes)
        }

        return NetworkCounters(inputBytes: inputBytes, outputBytes: outputBytes)
    }
}
