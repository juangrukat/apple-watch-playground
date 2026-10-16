import Foundation
import CoreBluetooth

final class BluetoothTransport:NSObject,CBCentralManagerDelegate,CBPeripheralDelegate {
    private static let service=CBUUID(string:"65CC1700-A8BE-4F0A-99D1-4A073E7B2901")
    private static let inputID=CBUUID(string:"65CC1701-A8BE-4F0A-99D1-4A073E7B2901")
    private static let outputID=CBUUID(string:"65CC1702-A8BE-4F0A-99D1-4A073E7B2901")
    private static let authID=CBUUID(string:"65CC1703-A8BE-4F0A-99D1-4A073E7B2901")
    let monitor=LinkMonitor()
    private let worker=DispatchQueue(label:"Playground BLE session",qos:.userInteractive)
    private let store:SampleStore
    private let code:String
    private let onCommand:(UInt8,UInt32?)->Void
    private let onRate:(Double)->Void
    private var manager:CBCentralManager!
    private var peer:CBPeripheral?
    private var input:CBCharacteristic?,output:CBCharacteristic?,auth:CBCharacteristic?
    private var timer:DispatchSourceTimer?
    private var stopped=false,live=false,authSent=false
    private var phase="Starting"
    private var deadline=0.0,retryAt=0.0,lastContact=0.0,lastTelemetry=0.0
    private var retry=RetrySchedule()
    private var scheduler=PacketScheduler()
    private var control:[Data]=[]
    private var telemetry:[Data]=[]
    private var cadence=CadenceWindow()
    private var submitted:UInt64=0
    private var reconnects=0,readyEvents=0
    private var blockedStart:Double?,blockedTotal=0.0
    private let resources=ResourceSampler()
    private let session=UInt32.random(in:1...UInt32.max)
    private let crownLeft:Bool,wristRight:Bool
    init(store:SampleStore,code:String,crownLeft:Bool,wristRight:Bool,onCommand:@escaping(UInt8,UInt32?)->Void,onRate:@escaping(Double)->Void) {
        self.store=store;self.code=code;self.crownLeft=crownLeft;self.wristRight=wristRight;self.onCommand=onCommand;self.onRate=onRate
        super.init()
        worker.async { [self] in
            manager=CBCentralManager(delegate:self,queue:worker)
            let timer=DispatchSource.makeTimerSource(queue:worker);timer.schedule(deadline:.now(),repeating:.milliseconds(10),leeway:.milliseconds(1))
            timer.setEventHandler { [weak self] in self?.tick() };self.timer=timer;timer.resume()
        }
    }
    func stop() { worker.async { [self] in
        stopped=true;live=false;timer?.cancel();timer=nil;manager.stopScan()
        if let peer { manager.cancelPeripheralConnection(peer) };resetPeer();control=[];telemetry=[]
        setPhase("Idle","Session stopped")
    } }
    func acknowledge(_ command:UInt8,id:UInt32?,accepted:Bool) { worker.async { [weak self] in
        guard let self,!self.stopped else { return }
        if let id { self.enqueue(CommandWire.acknowledgement(id:id,accepted:accepted)) }
        self.tick()
    } }
    func resume() { worker.async { [weak self] in
        guard let self,!self.stopped else { return }
        if !self.live,self.manager.state == .poweredOn,self.peer==nil { self.retryAt=0;self.scan() }
        self.tick()
    } }
    private func setPhase(_ value:String,_ detail:String) {
        phase=value;monitor.update{$0.phase=value;$0.detail=detail;$0.live=live}
    }
    private func resetPeer() { peer?.delegate=nil;peer=nil;input=nil;output=nil;auth=nil;authSent=false;live=false;scheduler=PacketScheduler();telemetry=[];control=[] }
    private func scan() {
        guard !stopped,manager.state == .poweredOn else { return }
        manager.scanForPeripherals(withServices:[Self.service],options:nil)
        deadline=ProcessInfo.processInfo.systemUptime+12;setPhase("Searching","Looking for your Mac")
    }
    private func fail(_ reason:String,blocked:Bool=false) {
        guard !stopped else { return }
        manager.stopScan();if let peer { manager.cancelPeripheralConnection(peer) };resetPeer()
        monitor.update{$0.lastError=reason}
        if blocked { retryAt = .infinity;setPhase("Needs attention",reason) }
        else { let delay=retry.nextDelay();retryAt=ProcessInfo.processInfo.systemUptime+delay;reconnects += 1;setPhase("Retrying",reason) }
    }
    private func enqueue(_ frame:Data) { if control.count>=32 { control.removeFirst() };control.append(frame) }
    private func tick() {
        guard !stopped else { return }
        let now=ProcessInfo.processInfo.systemUptime
        if phase=="Retrying",now>=retryAt { scan() }
        else if ["Searching","Connecting","Discovering","Authenticating"].contains(phase),now>deadline { fail("\(phase) timed out") }
        if live,now-lastContact>8 { fail("Mac stopped responding") }
        let snapshot=store.read(now:now)
        if live,now-lastTelemetry>=1 {
            lastTelemetry=now;let r=resources.sample(now:now)
            let diag:[String:Double]=["captureHz":snapshot.captureHz,"captureGap":snapshot.captureGap,"submitHz":cadence.rate(now:now),"capturedTotal":Double(snapshot.captured),"submittedTotal":Double(submitted),"replacedTotal":Double(snapshot.captured>submitted ? snapshot.captured-submitted:0),"cpu":r.cpuPercent ?? -1,"memory":r.residentMB ?? -1,"thermal":Double(r.thermal),"lowPower":r.lowPower ? 1:0,"active":snapshot.active ? 1:0,"dimmed":snapshot.dimmed ? 1:0,"crownLeft":crownLeft ? 1:0,"wristRight":wristRight ? 1:0,"session":Double(session),"watchLag":-1,"captureHandoff":-1,"captureCoalesced":0,"bleBlocked":blockedTotal+(blockedStart.map{now-$0} ?? 0),"bleReady":Double(readyEvents)]
            telemetry=BLEWire.diagnostics(diag)
            telemetry.append(Data([0xE2,snapshot.active ? 1:0,snapshot.dimmed ? 1:0]))
            if let motion=snapshot.motion,var ref=BLEWire.poseController(sequence:0,quaternion:motion.quaternion,acceleration:motion.gravity,nativeMillis:0) { ref[0]=0xED;telemetry.append(Data(ref.prefix(17))) }
        }
        monitor.update { $0.submitHz=cadence.rate(now:now);$0.submitted=submitted;$0.contactAge=lastContact>0 ? now-lastContact:.infinity;$0.blockedSeconds=blockedTotal+(blockedStart.map{now-$0} ?? 0);$0.readyEvents=Double(readyEvents);$0.reconnects=reconnects }
        guard live,let peer,let input else { return }
        let limit=peer.maximumWriteValueLength(for:.withoutResponse);monitor.update{$0.mtu=limit}
        scheduler.prepare(snapshot,now:now)
        for turn in 0..<4 {
            guard peer.canSendWriteWithoutResponse else { if blockedStart==nil { blockedStart=now };return }
            if let began=blockedStart { blockedTotal += now-began;blockedStart=nil }
            let frame:Data;var pose=false
            if !control.isEmpty { frame=control.removeFirst() }
            else if turn==1,!telemetry.isEmpty { frame=telemetry.removeFirst() }
            else if let next=scheduler.next(snapshot,limit:limit) { frame=next.0;pose=next.1 }
            else if !telemetry.isEmpty { frame=telemetry.removeFirst() }
            else { return }
            guard frame.count<=limit else { continue }
            peer.writeValue(frame,for:input,type:.withoutResponse)
            if pose { submitted &+= 1;cadence.record(now) }
        }
    }
    func centralManagerDidUpdateState(_ central:CBCentralManager) {
        guard !stopped else { return }
        if central.state == .poweredOn { retry.reset();scan() }
        else if central.state == .poweredOff { fail("Turn Bluetooth on",blocked:true) }
        else if central.state == .unauthorized { fail("Allow Playground Bluetooth access",blocked:true) }
        else { fail("Bluetooth is initializing") }
    }
    func centralManager(_ central:CBCentralManager,didDiscover peripheral:CBPeripheral,advertisementData:[String:Any],rssi RSSI:NSNumber) {
        guard !stopped,peer==nil,phase=="Searching" else { return }
        peer=peripheral;peripheral.delegate=self;central.stopScan();deadline=ProcessInfo.processInfo.systemUptime+10
        setPhase("Connecting",peripheral.name ?? "Mac Playground");central.connect(peripheral,options:nil)
    }
    func centralManager(_ central:CBCentralManager,didConnect peripheral:CBPeripheral) {
        guard !stopped,peripheral===peer else { return }
        deadline=ProcessInfo.processInfo.systemUptime+8;setPhase("Discovering","Checking Mac service");peripheral.discoverServices([Self.service])
    }
    func centralManager(_ central:CBCentralManager,didFailToConnect peripheral:CBPeripheral,error:Error?) { guard peripheral===peer else { return };fail(error?.localizedDescription ?? "Connection failed") }
    func centralManager(_ central:CBCentralManager,didDisconnectPeripheral peripheral:CBPeripheral,error:Error?) { guard peripheral===peer else { return };fail(error?.localizedDescription ?? "Mac disconnected") }
    func peripheral(_ peripheral:CBPeripheral,didDiscoverServices error:Error?) {
        guard !stopped,peripheral===peer else { return }
        guard error==nil,let service=peripheral.services?.first(where:{$0.uuid==Self.service}) else { fail("Mac service unavailable");return }
        peripheral.discoverCharacteristics([Self.inputID,Self.outputID,Self.authID],for:service)
    }
    func peripheral(_ peripheral:CBPeripheral,didDiscoverCharacteristicsFor service:CBService,error:Error?) {
        guard !stopped,peripheral===peer else { return }
        guard error==nil else { fail("Mac channels unavailable");return }
        input=service.characteristics?.first{$0.uuid==Self.inputID};output=service.characteristics?.first{$0.uuid==Self.outputID};auth=service.characteristics?.first{$0.uuid==Self.authID}
        guard input != nil,auth != nil,let output else { fail("Mac is missing required channels");return }
        deadline=ProcessInfo.processInfo.systemUptime+6;setPhase("Authenticating","Checking pairing code");peripheral.setNotifyValue(true,for:output)
    }
    func peripheral(_ peripheral:CBPeripheral,didUpdateNotificationStateFor characteristic:CBCharacteristic,error:Error?) {
        guard !stopped,peripheral===peer,characteristic.uuid==Self.outputID else { return }
        guard error==nil,characteristic.isNotifying,let auth else { fail("Mac notifications unavailable");return }
        guard !authSent else { return };authSent=true;var frame=Data([0xA0]);frame.append(Data(code.utf8));peripheral.writeValue(frame,for:auth,type:.withResponse)
    }
    func peripheral(_ peripheral:CBPeripheral,didWriteValueFor characteristic:CBCharacteristic,error:Error?) { guard !stopped,peripheral===peer else { return };if let error { fail(error.localizedDescription,blocked:characteristic.uuid==Self.authID) } }
    func peripheral(_ peripheral:CBPeripheral,didUpdateValueFor characteristic:CBCharacteristic,error:Error?) {
        guard !stopped,peripheral===peer,error==nil,let data=characteristic.value,let type=data.first else { return }
        let now=ProcessInfo.processInfo.systemUptime
        if type==0xA1,data.count==2 {
            guard data[1]==1 else { fail("Pairing code does not match",blocked:true);return }
            live=true;lastContact=now;retry.reset();scheduler=PacketScheduler();setPhase("Live","Direct Bluetooth to Mac");tick();return
        }
        guard live else { return };lastContact=now
        if type==0xF0,data.count==5 { var pong=data;pong[0]=0xF1;enqueue(pong) }
        else if type==0xD0,data.count==3 {
            let requested=Double(UInt16(data[1]) | UInt16(data[2])<<8),accepted=UInt16(max(10,min(100,requested)));onRate(Double(accepted));enqueue(Data([0xD1,UInt8(accepted & 255),UInt8(accepted >> 8)]))
        } else if type==0xC1,data.count==6 {
            if let (command,id)=CommandWire.decodeRequest(data) { onCommand(command,id) }
        } else if type==0xC0,data.count==2 { onCommand(data[1],nil) }
        tick()
    }
    func peripheralIsReady(toSendWriteWithoutResponse peripheral:CBPeripheral) { guard peripheral===peer,!stopped else { return };readyEvents += 1;tick() }
}
