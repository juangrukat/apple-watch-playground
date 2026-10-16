import Foundation

// One latest snapshot per channel. Replacing a snapshot preserves its turn.
struct LatestFeedQueue {
    private var order:[UInt8]=[]
    private var frames:[UInt8:[Data]]=[:]
    var count:Int { order.count }
    mutating func offer(_ id:UInt8,_ value:[Data]) {
        if frames[id]==nil { order.append(id) }
        frames[id]=value
    }
    mutating func remove(_ id:UInt8) { frames.removeValue(forKey:id);order.removeAll{$0==id} }
    mutating func pop()->[Data]? {
        guard !order.isEmpty else { return nil }
        return frames.removeValue(forKey:order.removeFirst())
    }
}
