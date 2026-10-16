import Foundation
@main struct DiagnosticsCheck {
    static func near(_ a:Double,_ b:Double,_ tolerance:Double=1e-6) { precondition(abs(a-b)<tolerance,"\(a) != \(b)") }
    static func main() {
        let q=PoseQuaternion.euler(0.3,-0.4,1.2)
        for (actual,expected) in zip(q.euler,[0.3,-0.4,1.2]) { near(actual,expected) }
        let p=Vector3(x:0.3,y:0.7,z:-0.2)
        let back=q.inverse.rotate(q.rotate(p));near(back.x,p.x);near(back.y,p.y);near(back.z,p.z)
        let calibrated=q.inverse*q;near(calibrated.w,1);near(calibrated.rotate(p).x,p.x)
        let quarter=PoseQuaternion.euler(0,0,Double.pi/2).rotate(Vector3(x:1,y:0,z:0));near(quarter.x,0);near(quarter.y,1)
        near(Vector3(x:0,y:0,z:-1).faceUpTiltDegrees,0)
        near(Vector3(x:1,y:0,z:0).faceUpTiltDegrees,90)
        near(Vector3(x:0,y:0,z:1).faceUpTiltDegrees,180)
        let frame=BLEWire.poseController(sequence:65535,quaternion:[q.x,q.y,q.z,q.w],acceleration:[-1.234,0.456,12.345],nativeMillis:65530)!
        precondition(frame.count==19 && frame.count<=20)
        var reference=Data(frame.prefix(17));reference[0]=0xED
        let referencePackets=BLEWire.pack([reference],limit:20)
        precondition(referencePackets.count==1 && BLEWire.unpack(referencePackets[0])==[reference])
        let decoded=BLEWire.decodePoseController(frame)!
        precondition(decoded.0==65535 && decoded.3==65530)
        let restored=PoseQuaternion(decoded.1)!.rotate(p);let expected=q.rotate(p)
        near(restored.x,expected.x,0.0001);near(restored.y,expected.y,0.0001);near(decoded.2[0],-1.234,0.0001)
        let combined=BLEWire.pack([frame,Data([0xE2,1,0]),Data([4])+Data(repeating:0,count:12)],limit:64)
        precondition(combined.count==1 && combined[0].count<=64)
        precondition(BLEWire.unpack(combined[0])==[frame,Data([0xE2,1,0]),Data([4])+Data(repeating:0,count:12)],"Multiplexing must preserve native pose and secondary values")
        precondition(BLEWire.decodePoseController(Data(frame.prefix(18)))==nil)
        precondition(BLEWire.poseController(sequence:0,quaternion:[0,0,0,0],acceleration:[0,0,0],nativeMillis:0)==nil)
        let snapshot:[String:Double]=["cpu":17.5,"memory":24.25,"captureHz":100,"submitHz":50,"captureGap":10,"watchLag":4,"capturedTotal":1000,"submittedTotal":700,"replacedTotal":299,"session":1234,"active":1,"dimmed":0,"lowPower":1,"crownLeft":1,"wristRight":1,"thermal":2,"captureHandoff":12.5,"captureCoalesced":7,"bleBlocked":1.25,"bleReady":42]
        let packets=BLEWire.pack(BLEWire.diagnostics(snapshot),limit:20)
        precondition(packets.allSatisfy{$0.count<=20})
        var reconstructed:[String:Double]=[:]
        for part in packets.flatMap({BLEWire.unpack($0)}) { reconstructed.merge(BLEWire.decodeDiagnostics(part)!){_,new in new} }
        for (key,value) in snapshot { near(reconstructed[key]!,value,0.001) }
        precondition(BLEWire.decodeDiagnostics(Data([0xE6,1]))==nil)
        precondition(BLEWire.availabilityCode("Enable location on Watch")==1)
        precondition(BLEWire.availabilityCode("Location permission denied")==2)
        precondition(BLEWire.availabilityCode("Not available on this Watch")==3)
        precondition(BLEWire.availabilityCode("No authorized record available")==4)
        precondition(BLEWire.availabilityMessage(0)==nil)
        var cadence=CadenceWindow()
        for i in 0..<100 { cadence.record(Double(i)/100) }
        near(cadence.rate(now:0.999),100);precondition(cadence.gap(now:1.5)>500)
        cadence.record(0.2);precondition(cadence.times.count==100,"Reject out-of-order sample clocks")
        let resources=ResourceSampler();_=resources.sample();let reading=resources.sample()
        precondition(reading.residentMB.map{$0>0} == true)
        precondition(reading.cpuPercent.map{$0.isFinite && $0>=0} == true)
        print("PASS: quaternion/neutral/quarter-turn math, gravity tilt, 19-byte native pose and timestamp, compact diagnostics/flags/Crown metadata, cadence gaps, own-process CPU and resident memory")
    }
}
