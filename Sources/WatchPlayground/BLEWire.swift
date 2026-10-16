import Foundation
// A bundle contains length-prefixed frames. Every bundle fits the negotiated ATT payload.
enum BLEWire {
    // Controller frame: sequence + orientation (0.0001 rad) + acceleration (0.001 g).
    // Fifteen bytes fit the minimum ATT payload without fragmentation.
    static func controller(sequence:UInt16,orientation:[Double],acceleration:[Double])->Data? {
        guard orientation.count>=3,acceleration.count>=3 else { return nil }
        let values=Array(orientation.prefix(3))+Array(acceleration.prefix(3))
        guard values.allSatisfy({$0.isFinite}) else { return nil }
        var data=Data([0xE4]); var seq=sequence.littleEndian
        withUnsafeBytes(of:&seq){data.append(contentsOf:$0)}
        for (i,value) in values.enumerated() {
            var quantized=Int16(max(-32768,min(32767,(value*(i<3 ? 10000:1000)).rounded()))).littleEndian
            withUnsafeBytes(of:&quantized){data.append(contentsOf:$0)}
        }
        return data
    }
    static func decodeController(_ data:Data)->(UInt16,[Double],[Double])? {
        guard data.count==15,data.first==0xE4 else { return nil }
        let sequence=data.subdata(in:1..<3).withUnsafeBytes{$0.loadUnaligned(as:UInt16.self).littleEndian}
        var values:[Double]=[]
        for i in 0..<6 { let offset=3+i*2; let value=data.subdata(in:offset..<offset+2).withUnsafeBytes{$0.loadUnaligned(as:Int16.self).littleEndian}; values.append(Double(value)/(i<3 ? 10000:1000)) }
        return (sequence,Array(values.prefix(3)),Array(values.suffix(3)))
    }
    static func poseController(sequence:UInt16,quaternion:[Double],acceleration:[Double],nativeMillis:UInt16)->Data? {
        guard quaternion.count==4,acceleration.count>=3,(quaternion+acceleration).allSatisfy({$0.isFinite}) else { return nil }
        let norm=sqrt(quaternion.reduce(0){$0+$1*$1}); guard norm>1e-9 else { return nil }
        var frame=Data([0xEB]); var sequence=sequence.littleEndian
        withUnsafeBytes(of:&sequence){frame.append(contentsOf:$0)}
        for value in quaternion.map({$0/norm}) { var bits=Int16(max(-32767,min(32767,(value*32767).rounded()))).littleEndian; withUnsafeBytes(of:&bits){frame.append(contentsOf:$0)} }
        for value in acceleration.prefix(3) { var bits=Int16(max(-32768,min(32767,(value*1000).rounded()))).littleEndian; withUnsafeBytes(of:&bits){frame.append(contentsOf:$0)} }
        var ticks=nativeMillis.littleEndian; withUnsafeBytes(of:&ticks){frame.append(contentsOf:$0)}
        return frame
    }
    static func decodePoseController(_ data:Data)->(UInt16,[Double],[Double],UInt16)? {
        guard data.count==19,data.first==0xEB else { return nil }
        func u16(_ offset:Int)->UInt16 { data.subdata(in:offset..<offset+2).withUnsafeBytes{$0.loadUnaligned(as:UInt16.self).littleEndian} }
        var values:[Double]=[]
        for i in 0..<7 { values.append(Double(Int16(bitPattern:u16(3+i*2)))/(i<4 ? 32767:1000)) }
        let quaternion=Array(values.prefix(4)); let norm=sqrt(quaternion.reduce(0){$0+$1*$1})
        guard norm>0.5 && norm<1.5 else { return nil }
        return (u16(1),quaternion.map{$0/norm},Array(values.suffix(3)),u16(17))
    }
    static func diagnostics(_ d:[String:Double])->[Data] {
        let flag=UInt8(d["active"]==1 ? 1:0) | UInt8(d["dimmed"]==1 ? 2:0) | UInt8(d["lowPower"]==1 ? 4:0) | UInt8(d["crownLeft"]==1 ? 8:0) | UInt8(d["wristRight"]==1 ? 16:0) | UInt8(max(0,min(3,d["thermal"] ?? 0)))<<5
        func floats(_ type:UInt8,_ names:[String],prefix:Data=Data())->Data {
            var frame=Data([type]);frame.append(prefix)
            for name in names { var bits=Float(d[name] ?? -1).bitPattern.littleEndian;withUnsafeBytes(of:&bits){frame.append(contentsOf:$0)} }
            return frame
        }
        var counts=Data([0xE8])
        for key in ["capturedTotal","submittedTotal","replacedTotal","session"] { var value=UInt32(truncatingIfNeeded:UInt64(max(0,d[key] ?? 0))).littleEndian;withUnsafeBytes(of:&value){counts.append(contentsOf:$0)} }
        return [counts,floats(0xE6,["cpu","memory","captureHz"],prefix:Data([flag])),floats(0xE7,["submitHz","captureGap","watchLag"]),floats(0xE9,["captureHandoff","captureCoalesced","bleBlocked","bleReady"])]
    }
    static func decodeDiagnostics(_ data:Data)->[String:Double]? {
        guard let type=data.first else { return nil }
        var result:[String:Double]=[:];let names:[String];let start:Int
        if type==0xE6 && data.count==14 {
            let flags=data[1];result=["active":Double(flags&1),"dimmed":Double((flags>>1)&1),"lowPower":Double((flags>>2)&1),"crownLeft":Double((flags>>3)&1),"wristRight":Double((flags>>4)&1),"thermal":Double((flags>>5)&3)]
            names=["cpu","memory","captureHz"];start=2
        } else if type==0xE7 && data.count==13 { names=["submitHz","captureGap","watchLag"];start=1 }
        else if type==0xE9 && data.count==17 { names=["captureHandoff","captureCoalesced","bleBlocked","bleReady"];start=1 }
        else if type==0xE8 && data.count==17 {
            for (i,key) in ["capturedTotal","submittedTotal","replacedTotal","session"].enumerated() { result[key]=Double(data.subdata(in:1+i*4..<5+i*4).withUnsafeBytes{$0.loadUnaligned(as:UInt32.self).littleEndian}) }
            return result
        } else { return nil }
        for (i,key) in names.enumerated() { let value=Double(Float(bitPattern:data.subdata(in:start+i*4..<start+i*4+4).withUnsafeBytes{$0.loadUnaligned(as:UInt32.self).littleEndian}));guard value.isFinite else { return nil };result[key]=value }
        return result
    }
    static func availabilityCode(_ message:String)->UInt8 {
        let text=message.lowercased()
        if text.contains("permission") && (text.contains("denied") || text.contains("unavailable")) { return 2 }
        if text.contains("not available") || text.contains("not supported") { return 3 }
        if text.contains("no authorized record") { return 4 }
        if text.contains("enable") || text.hasSuffix(" off") { return 1 }
        if text.contains("requesting health") { return 8 }
        if text.contains("reading saved") { return 9 }
        if text.contains("paused") { return 6 }
        if text.contains("could not") || text.contains("error") { return 5 }
        return 0
    }
    static func availabilityMessage(_ code:UInt8)->String? {
        switch code {
        case 0:return nil
        case 1:return "Enable on Watch"
        case 2:return "Permission unavailable or denied"
        case 3:return "Unavailable on this Watch"
        case 4:return "No authorized saved record"
        case 5:return "Watch sensor error"
        case 6:return "Sensor paused on Watch"
        case 8:return "Approve permission request on Watch"
        case 9:return "Reading saved records"
        case 10:return "Searching for a location fix · last fix retained"
        case 11:return "Compass unreliable · move away from magnetic interference"
        default:return nil
        }
    }
    static func pack(_ frames:[Data],limit:Int)->[Data] {
        guard limit>=3 else { return [] }
        var packets:[Data]=[],packet=Data([0xB0])
        for frame in frames where !frame.isEmpty && frame.count<=255 && frame.count+2<=limit {
            if packet.count+1+frame.count>limit { if packet.count>1 { packets.append(packet) }; packet=Data([0xB0]) }
            packet.append(UInt8(frame.count)); packet.append(frame)
        }
        if packet.count>1 { packets.append(packet) }
        return packets
    }
    static func unpack(_ data:Data)->[Data] {
        guard data.first==0xB0 else { return data.isEmpty ? []:[data] }
        var result:[Data]=[],index=1
        while index<data.count {
            let length=Int(data[index]); index += 1
            guard length>0,index+length<=data.count else { return [] }
            result.append(data.subdata(in:index..<index+length)); index += length
        }
        return result
    }
}
