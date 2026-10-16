import Foundation

@main struct WatchRewriteCheck {
    static func main() {
        let store=SampleStore();store.start()
        store.put("microphone",[-20],at:100);store.put("microphone",[-50],at:99)
        precondition(store.read().readings["microphone"]?.values==[-20],"Late samples cannot replace newer data")
        store.status("microphone",6,"Paused");precondition(store.read().readings["microphone"]?.values.isEmpty==true)
        store.put("microphone",[-21],at:101);precondition(store.read().readings["microphone"]?.state==0)
        for i in 0..<10000 { store.put("crown",[Double(i)],at:Double(i+1000));store.put("unknown\(i)",[1]) }
        precondition(store.read().readings.count==2,"Storage cannot grow with unknown channels")
        store.put("location",[-1,10,20],at:1000);store.status("location",10,"Waiting for fix")
        precondition(store.read().readings["location"]?.values==[-1,10,20],"Temporary GPS errors retain last fix")
        store.put("location",[2,10,20],at:1001);precondition(store.read().readings["location"]?.state==0,"New fix recovers automatically")
        store.put("heading",[359],at:1000);store.status("heading",11,"Unreliable")
        precondition(store.read().readings["heading"]?.values==[359])
        store.status("location",2,"Denied");precondition(store.read().readings["location"]?.values.isEmpty==true,"Denied permission clears retained fix")
        store.stop();store.put("touch",[99]);precondition(store.read().readings["touch"]==nil,"Stopped capture rejects readings")
        store.start();precondition(store.read().readings.isEmpty)
        var retry=RetrySchedule();let delays=(0..<8).map{_ in retry.nextDelay()}
        precondition(delays==[0.5,1,2,4,8,8,8,8]);retry.reset();precondition(retry.nextDelay()==0.5)
        var ledger=CommandLedger();precondition(ledger.accept(42));precondition(!ledger.accept(42));precondition(ledger.accept(43))
        var pending=PendingWatchCommands();precondition(pending.add(code:2,name:"mint"))
        let first=pending.due(now:0);precondition(first.count==1);precondition(pending.due(now:1).isEmpty)
        let parsed=CommandWire.decodeRequest(first[0])!;precondition(parsed.0==2)
        precondition(pending.due(now:1.5)==first,"Retry retains the same command ID")
        let ack=CommandWire.acknowledgement(id:parsed.1,accepted:true);precondition(CommandWire.decodeAcknowledgement(ack)?.0==parsed.1)
        precondition(pending.acknowledge(parsed.1)=="mint");precondition(pending.due(now:9).isEmpty)
        precondition(CommandWire.decodeRequest(Data([0xC1,2]))==nil)
        precondition(CommandWire.decodeAcknowledgement(Data([0xCC,0,0,0,0,9]))==nil)
        precondition(pending.add(code:1,name:"haptic"));_=pending.due(now:10);_=pending.due(now:12);_=pending.due(now:14);precondition(pending.expire(now:16)==["haptic"])
        for _ in 0..<16 { precondition(pending.add(code:1,name:"haptic")) };precondition(!pending.add(code:1,name:"overflow"))
        var scheduler=PacketScheduler()
        let now=ProcessInfo.processInfo.systemUptime
        for i in 0..<500 {
            store.motion(MotionFrame(nativeTime:now+Double(i)/50,sourceTime:1000+Double(i)/50,quaternion:[0,0,0,1],orientation:[0,0,0],rotation:[0,0,0],gravity:[0,0,-1],acceleration:[0,0,-1],energy:0))
        }
        precondition(store.read(now:now+10).captured==500)
        let expected=store.read().motion!.nativeTime
        for def in FeedDefinition.all where def.channel>2 { store.put(def.id,[Double(def.channel)],at:5000) }
        let snapshot=store.read();scheduler.prepare(snapshot,now:now)
        var delivered=Set<UInt8>(),poses=0,stamps=Set<UInt8>()
        for _ in 0..<150 {
            guard let (data,pose)=scheduler.next(snapshot,limit:20) else { break }
            precondition(data.count<=20)
            if pose { poses += 1;let decoded=BLEWire.decodePoseController(data)!;precondition(decoded.3==UInt16(truncatingIfNeeded:UInt64(expected*1000))) }
            for frame in BLEWire.unpack(data) { if let id=frame.first,id<128 { delivered.insert(id) };if frame.first==0xE0 { stamps.insert(frame[1]) } }
        }
        precondition(poses==1,"No stale pose replay")
        precondition(Set(FeedDefinition.all.filter{$0.channel>2}.map(\.channel)).isSubset(of:delivered),"Every secondary gets a turn at minimum MTU")
        precondition(delivered.isSubset(of:stamps),"Every secondary preserves its actual source timestamp")
        print("PASS: bounded sample storage, stale/stop handling, capped retry, command correlation/deduplication/expiry, latest pose and fair timestamped minimum-MTU feeds")
    }
}
