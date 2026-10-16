import Foundation
import Darwin

struct RuntimeResources {
    var cpuPercent:Double?
    var residentMB:Double?
    var thermal:Int
    var lowPower:Bool
}
final class ResourceSampler {
    private var previousCPU:Double?
    private var previousTime:Double?
    private func cpuTime()->Double? {
        var usage=rusage()
        guard getrusage(RUSAGE_SELF,&usage)==0 else { return nil }
        return Double(usage.ru_utime.tv_sec+usage.ru_stime.tv_sec)+Double(usage.ru_utime.tv_usec+usage.ru_stime.tv_usec)/1_000_000
    }
    func sample(now:Double=ProcessInfo.processInfo.systemUptime)->RuntimeResources {
        let cpu=cpuTime(); var percent:Double?
        if let cpu,let previousCPU,let previousTime,now>previousTime { percent=max(0,(cpu-previousCPU)/(now-previousTime)*100) }
        previousCPU=cpu; previousTime=now
        var info=mach_task_basic_info_data_t()
        var count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size/MemoryLayout<integer_t>.size)
        let result=withUnsafeMutablePointer(to:&info) { ptr in
            ptr.withMemoryRebound(to:integer_t.self,capacity:Int(count)) { task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count) }
        }
        return RuntimeResources(cpuPercent:percent,residentMB:result==KERN_SUCCESS ? Double(info.resident_size)/1_048_576:nil,thermal:ProcessInfo.processInfo.thermalState.rawValue,lowPower:ProcessInfo.processInfo.isLowPowerModeEnabled)
    }
}
struct CadenceWindow {
    private(set) var times:[Double]=[]
    mutating func record(_ now:Double=ProcessInfo.processInfo.systemUptime,allowDuplicate:Bool=true) {
        guard now.isFinite else { return }
        if let last=times.last,(now<last || (!allowDuplicate && now==last)) { return }
        times.append(now); times=Array(times.suffix(600)); times.removeAll{now-$0>3}
    }
    func rate(now:Double=ProcessInfo.processInfo.systemUptime)->Double {
        let recent=times.filter{now-$0<=1 && now >= $0}
        return Double(recent.count)
    }
    func gap(now:Double=ProcessInfo.processInfo.systemUptime)->Double {
        let recent=times.filter{now-$0<=2 && now >= $0}
        let differences=zip(recent,recent.dropFirst()).map{$1-$0}
        let silence=times.last.map{max(0,now-$0)} ?? 0
        return max(differences.max() ?? 0,silence)*1000
    }
}
