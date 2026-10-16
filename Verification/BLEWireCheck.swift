import Foundation
@main struct Check {
 static func main() {
  let original=[-3.14159,0.123456,3.14159]
  let acceleration=[-16.0,0.123456,16.0]
  let controller=BLEWire.controller(sequence:65535,orientation:original,acceleration:acceleration)!
  let decoded=BLEWire.decodeController(controller)!
  precondition(controller.count==15 && decoded.0==65535)
  for (a,b) in zip(original,decoded.1) { precondition(abs(a-b)<=0.000051) }
  for (a,b) in zip(acceleration,decoded.2) { precondition(abs(a-b)<=0.000501) }
  precondition(BLEWire.decodeController(Data(controller.prefix(14)))==nil)
  precondition(BLEWire.controller(sequence:0,orientation:[.nan,0,0],acceleration:acceleration)==nil)

  let frames=[Data([1]+Array(repeating:17,count:12)),Data([2]+Array(repeating:23,count:12)),Data([0xE0,1]+Array(repeating:11,count:8)),Data([8,0,0,0,1])]
  for limit in [20,64,185,512] {
   let packets=BLEWire.pack(frames,limit:limit)
   precondition(packets.allSatisfy{$0.count<=limit})
   precondition(packets.flatMap{BLEWire.unpack($0)}==frames)
  }
  precondition(BLEWire.unpack(Data([0xB0,5,1,2])).isEmpty)
  precondition(BLEWire.unpack(Data([0xB0,0])).isEmpty)
  precondition(BLEWire.pack(frames,limit:1).isEmpty)
  print("PASS: BLE packet framing at ATT payloads 20/64/185/512, frame ordering, truncated data and invalid sizes")
 }
}
