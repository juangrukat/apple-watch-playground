import Foundation
import CoreBluetooth

// Watch is the central; Mac advertises this private service as a peripheral.
// Frames stay below the baseline 20-byte ATT payload. No sensor backlog is kept.
@MainActor final class BluetoothLink:NSObject,@preconcurrency CBPeripheralManagerDelegate {
    static let serviceID=CBUUID(string:"65CC1700-A8BE-4F0A-99D1-4A073E7B2901")
    static let inputID=CBUUID(string:"65CC1701-A8BE-4F0A-99D1-4A073E7B2901")
    static let authID=CBUUID(string:"65CC1703-A8BE-4F0A-99D1-4A073E7B2901")
    static let outputID=CBUUID(string:"65CC1702-A8BE-4F0A-99D1-4A073E7B2901")
    weak var studio:Studio?
    private var manager:CBPeripheralManager!
    let ingress=BluetoothIngress()
    private var input:CBMutableCharacteristic!
    private var output:CBMutableCharacteristic!
    private var auth:CBMutableCharacteristic!
    private var sourceDates:[String:Date]=[:]
    private var peer:CBCentral?
    private var authorized:Set<UUID>=[]
    private var pingTimer:Timer?
    private var pingSequence:UInt32=0
    private var pendingPings:[UInt32:Double]=[:]
    private var recentRTT:[Double]=[]
    private var lastSample=Date.distantPast
    private var count=0
    private var uniqueCount=0
    private var lastSource:Date?
    private var lastArrival:Double?
    private var gaps:[Double]=[]
    private var benchmarkStart:Double?
    private var requestedRate=50
    private var confirmedRate=0
    private var lastControllerSequence:UInt16?
    private var lastNativeTicks:UInt16?
    private var lastControllerArrival:Double?
    private var watchActive=true
    private var watchDimmed=false
    private var sweepDone=false
    private var window=Date()
    private var pendingOutput:[Data]=[]
    private var commands=PendingWatchCommands()
    private let channels:[UInt8:String]=[1:"orientation",2:"acceleration",3:"rotation",4:"gravity",5:"intensity",6:"stillness",7:"crown",8:"touch",9:"battery",10:"microphone",11:"altitude",12:"pressure",13:"heading",14:"steps",15:"heart",16:"hrv",17:"oxygen",18:"temperature",19:"rhythm",20:"location",21:"lastOutput",22:"locationQuality",23:"headingQuality"]
    init(studio:Studio) {
        self.studio=studio; super.init()
        requestedRate=ProcessInfo.processInfo.arguments.contains("--sweep") ? 50:studio.controllerRate
        ingress.owner=self
        manager=CBPeripheralManager(delegate:ingress,queue:DispatchQueue(label:"WatchPlayground.BluetoothIngress",qos:.userInteractive))
    }
    func stop() { pingTimer?.invalidate(); pingTimer=nil; manager.stopAdvertising(); manager.removeAllServices(); authorized=[]; pendingPings=[:]; pendingOutput=[];commands=PendingWatchCommands();peer=nil }
    func peripheralManagerDidUpdateState(_ peripheral:CBPeripheralManager) {
        guard let s=studio else { return }
        switch peripheral.state {
        case .poweredOn:
            input=CBMutableCharacteristic(type:Self.inputID,properties:[.writeWithoutResponse],value:nil,permissions:[.writeable])
            output=CBMutableCharacteristic(type:Self.outputID,properties:[.notify],value:nil,permissions:[])
            auth=CBMutableCharacteristic(type:Self.authID,properties:[.write],value:nil,permissions:[.writeable])
            let service=CBMutableService(type:Self.serviceID,primary:true); service.characteristics=[input,output,auth]; peripheral.add(service)
        case .unauthorized:s.message="Allow Bluetooth for Watch Playground in System Settings → Privacy & Security → Bluetooth"
        case .poweredOff:s.message="Turn Bluetooth on to connect your Watch directly"
        default:s.message="Bluetooth initializing…"
        }
    }
    func peripheralManager(_ peripheral:CBPeripheralManager,didAdd service:CBService,error:Error?) {
        if let error { studio?.message="Bluetooth service: \(error.localizedDescription)"; return }
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey:[Self.serviceID],CBAdvertisementDataLocalNameKey:"Watch Playground"])
        studio?.message="Bluetooth ready • choose Direct Bluetooth on Watch and enter this Mac's pairing code"
    }
    func peripheralManagerDidStartAdvertising(_ peripheral:CBPeripheralManager,error:Error?) { if let error { studio?.message="Bluetooth advertising: \(error.localizedDescription)" } }
    func peripheralManager(_ peripheral:CBPeripheralManager,central:CBCentral,didSubscribeTo characteristic:CBCharacteristic) {
        peer=central; peripheral.setDesiredConnectionLatency(.low,for:central)
        pingTimer?.invalidate()
        pingTimer=Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in Task { @MainActor in self?.ping() } }
    }
    func peripheralManager(_ peripheral:CBPeripheralManager,central:CBCentral,didUnsubscribeFrom characteristic:CBCharacteristic) {
        authorized.remove(central.identifier); peer=nil;pendingOutput=[];commands=PendingWatchCommands(); studio?.connected=false; studio?.message="Bluetooth disconnected • keep Playground active on Watch"
    }
    func peripheralManager(_ peripheral:CBPeripheralManager,didReceiveWrite requests:[CBATTRequest]) {
        for request in requests {
            guard let data=request.value,let type=data.first else { peripheral.respond(to:request,withResult:.invalidAttributeValueLength); continue }
            if type==0xA0 && request.characteristic.uuid==Self.authID {
                let code=String(data:data.dropFirst(),encoding:.utf8)
                if code==studio?.pairingCode {
                    authorized.insert(request.central.identifier); peer=request.central
                    sourceDates=[:]; lastNativeTicks=nil; lastControllerArrival=nil; studio?.sequenceGaps=0; lastControllerSequence=nil; confirmedRate=0; lastSource=nil; lastArrival=nil; gaps=[]; count=0; uniqueCount=0; window=Date()
                    benchmarkStart=ProcessInfo.processInfo.systemUptime
                    studio?.setDemo(false); studio?.statuses=[:];studio?.connected=true; studio?.message="Direct Bluetooth • authenticated Watch"
                    notify(Data([0xA1,1])); peripheral.respond(to:request,withResult:.success)
                } else { notify(Data([0xA1,0])); peripheral.respond(to:request,withResult:.insufficientAuthentication) }
                continue
            }
            guard authorized.contains(request.central.identifier) else { continue }
            var frames:[Data]=[]
            for frame in BLEWire.unpack(data) {
                if frame.first==0xEA,frame.count==3,let key=channels[frame[1]] {
                    studio?.statuses[key]=BLEWire.availabilityMessage(frame[2]);if frame[2] != 0 && frame[2] != 10 && frame[2] != 11 { studio?.samples.removeValue(forKey:key) };continue
                }
                if frame.first==0xED && frame.count==17 { var reference=frame;reference.append(contentsOf:[0,0]);reference[0]=0xEB
                    if let (_,values,gravity,_)=BLEWire.decodePoseController(reference),let q=PoseQuaternion(values) {
                        let g=Vector3(x:gravity[0],y:gravity[1],z:gravity[2]);studio?.referenceDownZ=q.rotate(g).z;studio?.referenceInverseDownZ=q.inverse.rotate(g).z
                    };continue
                }
                if let (id,accepted)=CommandWire.decodeAcknowledgement(frame) {
                    if let name=commands.acknowledge(id) { studio?.recordCommandResult(name,accepted:accepted) };continue
                }
                if let diagnostics=BLEWire.decodeDiagnostics(frame) { studio?.updateWatchDiagnostics(diagnostics);continue }
                if let (sequence,quaternion,acceleration,ticks)=BLEWire.decodePoseController(frame),let q=PoseQuaternion(quaternion) {
                    guard sequence != lastControllerSequence else { continue }
                    if let previous=lastControllerSequence { let delta=sequence &- previous;if delta>1 && delta<32768 { studio?.sequenceGaps += Int(delta)-1 } }
                    let arrival=ProcessInfo.processInfo.systemUptime
                    if let lastNativeTicks,let lastControllerArrival {
                        let sourceDelta=Double(ticks &- lastNativeTicks)
                        if sourceDelta<10000 && arrival-lastControllerArrival<10 { studio?.transportSpacingError=(arrival-lastControllerArrival)*1000-sourceDelta }
                    }
                    lastNativeTicks=ticks;lastControllerArrival=arrival;lastControllerSequence=sequence;sourceDates["orientation"]=Date()
                    if !(studio?.paused ?? true) && !(studio?.demo ?? true) { studio?.ingest("quaternion",quaternion) }
                    for (id,values) in [(UInt8(1),q.euler),(UInt8(2),acceleration)] {
                        var expanded=Data([id]);for value in values { var bits=Float(value).bitPattern.littleEndian;withUnsafeBytes(of:&bits){expanded.append(contentsOf:$0)} };frames.append(expanded)
                    }
                } else if let (sequence,orientation,acceleration)=BLEWire.decodeController(frame) {
                    guard sequence != lastControllerSequence else { continue }
                    lastControllerSequence=sequence; sourceDates["orientation"]=Date()
                    for (id,values) in [(UInt8(1),orientation),(UInt8(2),acceleration)] {
                        var expanded=Data([id])
                        for value in values { var bits=Float(value).bitPattern.littleEndian; withUnsafeBytes(of:&bits){expanded.append(contentsOf:$0)} }
                        frames.append(expanded)
                    }
                } else { frames.append(frame) }
            }
            for data in frames {
                guard let type=data.first else { continue }
            if type==0xD1,data.count==3 {
                confirmedRate=Int(data[1]) | (Int(data[2]) << 8)
                print("BLE RATE ACK \(confirmedRate)"); fflush(stdout)
            } else if type==0xE2,data.count==3 {
                let resumed=(!watchActive || watchDimmed) && data[1]==1 && data[2]==0
                watchActive=data[1]==1; watchDimmed=data[2]==1
                if resumed { peripheral.setDesiredConnectionLatency(.low,for:request.central) }
            } else if type==0xE0,data.count==10,let key=channels[data[1]] {
                let bits=data.subdata(in:2..<10).withUnsafeBytes{$0.loadUnaligned(as:UInt64.self).littleEndian}
                let timestamp=Double(bitPattern:bits)
                if timestamp.isFinite { sourceDates[key]=Date(timeIntervalSince1970:timestamp) }
            } else if type==0xF1,data.count==5 {
                let seq=data.dropFirst().withUnsafeBytes{$0.loadUnaligned(as:UInt32.self).littleEndian}
                if let start=pendingPings.removeValue(forKey:seq) {
                    let rtt=(ProcessInfo.processInfo.systemUptime-start)*1000
                    recentRTT.append(rtt); recentRTT=Array(recentRTT.suffix(60))
                    let sorted=recentRTT.sorted(); studio?.bluetoothRTT=String(format:"RTT %.0f ms · p95 %.0f ms",rtt,sorted[min(sorted.count-1,Int(Double(sorted.count)*0.95))])
                    if ProcessInfo.processInfo.arguments.contains("--benchmark") { print("BLE RTT \(rtt) ms; p95 \(sorted[min(sorted.count-1,Int(Double(sorted.count)*0.95))]) ms; motion \(studio?.bluetoothRate ?? 0) Hz"); fflush(stdout) }
                }
            } else if let key=channels[type],data.count>=5,(data.count-1)%4==0 {
                var values:[Double]=[]
                for offset in stride(from:1,to:data.count,by:4) { let bits=data.subdata(in:offset..<offset+4).withUnsafeBytes{$0.loadUnaligned(as:UInt32.self).littleEndian}; values.append(Double(Float(bitPattern:bits))) }
                if !(studio?.paused ?? true) && !(studio?.demo ?? true) && studio?.statuses[key]==nil { studio?.ingest(key,values,source:sourceDates[key]) }
                studio?.touchBluetoothPacket()
                if key=="orientation" {
                    count += 1
                    if let source=sourceDates[key],source != lastSource { uniqueCount += 1; lastSource=source }
                    let now=ProcessInfo.processInfo.systemUptime
                    if let lastArrival { gaps.append((now-lastArrival)*1000) }
                    lastArrival=now
                }
                let dt=Date().timeIntervalSince(window)
                if dt>=1 {
                    studio?.bluetoothRate=Double(count)/dt
                    if ProcessInfo.processInfo.arguments.contains("--benchmark") {
                        let sorted=gaps.sorted()
                        print("BLE WINDOW target=\(requestedRate) confirmed=\(confirmedRate) active=\(watchActive) dimmed=\(watchDimmed) arrivals=\(Double(count)/dt) unique=\(Double(uniqueCount)/dt) gapP95=\(sorted.isEmpty ? 0:sorted[min(sorted.count-1,Int(Double(sorted.count)*0.95))]) gapMax=\(sorted.last ?? 0)")
                        fflush(stdout)
                    }
                    count=0; uniqueCount=0; gaps=[]; window=Date()
                }
            }
            }
            if request.characteristic.properties.contains(.write) { peripheral.respond(to:request,withResult:.success) }
        }
    }
    func ping() {
        guard let peer,authorized.contains(peer.identifier) else { return }
        serviceCommands()
        if ProcessInfo.processInfo.arguments.contains("--sweep"),let benchmarkStart,!sweepDone {
            let elapsed=ProcessInfo.processInfo.systemUptime-benchmarkStart
            let target=elapsed<10 ? 50:elapsed<30 ? 100:elapsed<50 ? 200:100
            if target != requestedRate {
                requestedRate=target; notify(Data([0xD0,UInt8(target & 255),UInt8(target >> 8)]))
                print("BLE TARGET \(target) Hz at \(elapsed)s"); fflush(stdout)
            }
            if elapsed>=50 { sweepDone=true; print("BLE SWEEP COMPLETE"); fflush(stdout) }
        }
        if confirmedRate != requestedRate { notify(Data([0xD0,UInt8(requestedRate & 255),UInt8(requestedRate >> 8)])) }
        pendingPings=pendingPings.filter{ProcessInfo.processInfo.systemUptime-$0.value<5}
        pingSequence &+= 1; var seq=pingSequence.littleEndian
        var frame=Data([0xF0]); withUnsafeBytes(of:&seq){frame.append(contentsOf:$0)}
        pendingPings[pingSequence]=ProcessInfo.processInfo.systemUptime
        if !manager.updateValue(frame,for:output,onSubscribedCentrals:[peer]) { pendingPings.removeValue(forKey:pingSequence) }
    }
    func setRate(_ rate:Int) {
        sweepDone=true; requestedRate=max(25,min(100,rate))
        notify(Data([0xD0,UInt8(requestedRate & 255),UInt8(requestedRate >> 8)]))
    }
    func command(_ name:String) {
        let ids:[String:UInt8]=["haptic":1,"mint":2,"violet":3,"reset":4,"audit-all":5]
        if let id=ids[name] {
            guard commands.add(code:id,name:name) else { studio?.note="Watch command queue is full; wait for acknowledgements.";return };serviceCommands()
        }
    }
    private func serviceCommands() {
        let now=ProcessInfo.processInfo.systemUptime
        for name in commands.expire(now:now) { studio?.recordCommandResult(name,accepted:false,detail:"No Watch acknowledgement for \(name).") }
        for frame in commands.due(now:now) { notify(frame) }
    }
    private func notify(_ data:Data) {
        guard let peer else { return }
        if !manager.updateValue(data,for:output,onSubscribedCentrals:[peer]) {
            // Pings and rate requests are refreshed on the next timer tick.
            if data.first==0xF0 || data.first==0xD0 { return }
            if pendingOutput.count<32,!pendingOutput.contains(data) { pendingOutput.append(data) }
        }
    }
    func peripheralManagerIsReady(toUpdateSubscribers peripheral:CBPeripheralManager) {
        guard let peer else { return }
        while let data=pendingOutput.first {
            guard manager.updateValue(data,for:output,onSubscribedCentrals:[peer]) else { return }
            pendingOutput.removeFirst()
        }
    }
}

// CoreBluetooth callbacks arrive independently of SwiftUI's main thread.
final class BluetoothIngress:NSObject,CBPeripheralManagerDelegate {
    weak var owner:BluetoothLink?
    private let lock=NSLock()
    private var cadence=CadenceWindow()
    func snapshot()->(Double,Double) { lock.lock();defer{lock.unlock()};return (cadence.rate(),cadence.gap()) }
    func peripheralManagerDidUpdateState(_ manager:CBPeripheralManager) { DispatchQueue.main.async { [weak owner] in owner?.peripheralManagerDidUpdateState(manager) } }
    func peripheralManager(_ manager:CBPeripheralManager,didAdd service:CBService,error:Error?) { DispatchQueue.main.async { [weak owner] in owner?.peripheralManager(manager,didAdd:service,error:error) } }
    func peripheralManagerDidStartAdvertising(_ manager:CBPeripheralManager,error:Error?) { DispatchQueue.main.async { [weak owner] in owner?.peripheralManagerDidStartAdvertising(manager,error:error) } }
    func peripheralManager(_ manager:CBPeripheralManager,central:CBCentral,didSubscribeTo characteristic:CBCharacteristic) { DispatchQueue.main.async { [weak owner] in owner?.peripheralManager(manager,central:central,didSubscribeTo:characteristic) } }
    func peripheralManager(_ manager:CBPeripheralManager,central:CBCentral,didUnsubscribeFrom characteristic:CBCharacteristic) { DispatchQueue.main.async { [weak owner] in owner?.peripheralManager(manager,central:central,didUnsubscribeFrom:characteristic) } }
    func peripheralManager(_ manager:CBPeripheralManager,didReceiveWrite requests:[CBATTRequest]) {
        let arrival=ProcessInfo.processInfo.systemUptime
        lock.lock()
        for request in requests {
            for frame in BLEWire.unpack(request.value ?? Data()) where frame.first==0xEB || frame.first==0xE4 { cadence.record(arrival) }
        }
        lock.unlock()
        DispatchQueue.main.async { [weak owner] in
            owner?.studio?.recordTransportLag((ProcessInfo.processInfo.systemUptime-arrival)*1000)
            owner?.peripheralManager(manager,didReceiveWrite:requests)
        }
    }
    func peripheralManagerIsReady(toUpdateSubscribers manager:CBPeripheralManager) { DispatchQueue.main.async { [weak owner] in owner?.peripheralManagerIsReady(toUpdateSubscribers:manager) } }
}
