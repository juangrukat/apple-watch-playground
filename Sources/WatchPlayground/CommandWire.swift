import Foundation

enum CommandWire {
    static func request(code:UInt8,id:UInt32)->Data { var id=id.littleEndian;var data=Data([0xC1,code]);withUnsafeBytes(of:&id){data.append(contentsOf:$0)};return data }
    static func acknowledgement(id:UInt32,accepted:Bool)->Data { var id=id.littleEndian;var data=Data([0xCC]);withUnsafeBytes(of:&id){data.append(contentsOf:$0)};data.append(accepted ? 1:0);return data }
    static func decodeRequest(_ data:Data)->(UInt8,UInt32)? {
        guard data.count==6,data.first==0xC1 else { return nil }
        return (data[1],data.subdata(in:2..<6).withUnsafeBytes{$0.loadUnaligned(as:UInt32.self).littleEndian})
    }
    static func decodeAcknowledgement(_ data:Data)->(UInt32,Bool)? {
        guard data.count==6,data.first==0xCC,data[5]<=1 else { return nil }
        return (data.subdata(in:1..<5).withUnsafeBytes{$0.loadUnaligned(as:UInt32.self).littleEndian},data[5]==1)
    }
}
struct PendingWatchCommands {
    struct Entry { let id:UInt32;let code:UInt8;let name:String;var sent=0;var lastSent = -Double.infinity }
    private(set) var entries:[Entry]=[]
    private var nextID=UInt32.random(in:1...UInt32.max-1000)
    mutating func add(code:UInt8,name:String)->Bool {
        guard entries.count<16 else { return false };nextID &+= 1;entries.append(Entry(id:nextID,code:code,name:name));return true
    }
    mutating func due(now:Double)->[Data] {
        var result:[Data]=[]
        for index in entries.indices where entries[index].sent<3 && now-entries[index].lastSent>=1.5 {
            entries[index].sent += 1;entries[index].lastSent=now
            result.append(CommandWire.request(code:entries[index].code,id:entries[index].id))
        }
        return result
    }
    mutating func expire(now:Double)->[String] {
        let expired=entries.filter{$0.sent>=3 && now-$0.lastSent>=2}
        entries.removeAll{$0.sent>=3 && now-$0.lastSent>=2};return expired.map(\.name)
    }
    mutating func acknowledge(_ id:UInt32)->String? {
        guard let index=entries.firstIndex(where:{$0.id==id}) else { return nil };return entries.remove(at:index).name
    }
}
