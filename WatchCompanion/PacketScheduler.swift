import Foundation

// Fresh poses replace old poses. Each secondary feed retains its fair turn.
struct PacketScheduler {
    private var secondary=LatestFeedQueue()
    private var packets:[Data]=[]
    private var versions:[UInt8:UInt64]=[:]
    private var availability:[UInt8:UInt8]=[:]
    private var offeredAt:[UInt8:Double]=[:]
    private var lastPose:Double?
    private var sequence:UInt16=0
    private var poseTurns=0
    mutating func prepare(_ snapshot:CaptureSnapshot,now:Double) {
        let definitions=FeedDefinition.all+[FeedDefinition(21,"lastOutput","Output command")]
        for def in definitions {
            guard let reading=snapshot.readings[def.id] else { continue }
            if availability[def.channel] != reading.state {
                secondary.offer(def.channel|0x80,[Data([0xEA,def.channel,reading.state])]);availability[def.channel]=reading.state
            }
            guard def.channel>2,reading.state==0,!reading.values.isEmpty else { secondary.remove(def.channel);continue }
            let urgent=[7,8,21].contains(def.channel)
            let interval=urgent ? 0.02:0.2
            guard now-(offeredAt[def.channel] ?? -.infinity)>=interval,
                  versions[def.channel] != reading.revision || now-(offeredAt[def.channel] ?? 0)>=1 else { continue }
            var frame=Data([def.channel])
            for value in reading.values.prefix(3) { var bits=Float(value).bitPattern.littleEndian;withUnsafeBytes(of:&bits){frame.append(contentsOf:$0)} }
            var group:[Data]=[]
            if reading.sourceTime>0 { var bits=reading.sourceTime.bitPattern.littleEndian;var stamp=Data([0xE0,def.channel]);withUnsafeBytes(of:&bits){stamp.append(contentsOf:$0)};group.append(stamp) }
            group.append(frame);secondary.offer(def.channel,group)
            versions[def.channel]=reading.revision;offeredAt[def.channel]=now
        }
    }
    mutating func next(_ snapshot:CaptureSnapshot,limit:Int)->(Data,Bool)? {
        let pose=snapshot.motion
        let hasPose=pose.map{$0.nativeTime != lastPose} ?? false
        if !hasPose || poseTurns>=4 {
            if let next=takeSecondary(limit:limit) { poseTurns=0;return (next,false) }
        }
        if let pose,hasPose,let frame=BLEWire.poseController(sequence:sequence,quaternion:pose.quaternion,acceleration:pose.acceleration,nativeMillis:UInt16(truncatingIfNeeded:UInt64(max(0,pose.nativeTime*1000)))),frame.count<=limit {
            sequence &+= 1;lastPose=pose.nativeTime;poseTurns += 1
            if limit>=64,let slow=takeSecondary(limit:limit-frame.count-3) {
                let bundled=BLEWire.pack([frame]+BLEWire.unpack(slow),limit:limit)
                if bundled.count==1 { poseTurns=0;return (bundled[0],true) }
            }
            return (frame,true)
        }
        if let next=takeSecondary(limit:limit) { poseTurns=0;return(next,false) }
        return nil
    }
    private mutating func takeSecondary(limit:Int)->Data? {
        guard limit>=3 else { return nil }
        if packets.isEmpty,let group=secondary.pop() { packets=BLEWire.pack(group,limit:limit) }
        guard let packet=packets.first,packet.count<=limit else { return nil }
        packets.removeFirst();return packet
    }
}
