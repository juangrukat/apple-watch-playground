import Foundation

// Two in-flight snapshots at most. A slow response never builds a sensor backlog.
final class HTTPTransport {
    let monitor=LinkMonitor()
    private let worker=DispatchQueue(label:"Playground local HTTP",qos:.userInitiated)
    private let store:SampleStore,url:URL,code:String,onCommand:(UInt8,UInt32?)->Void
    private let session:URLSession
    private var timer:DispatchSourceTimer?
    private var stopped=false,pairing=false,token=""
    private var retry=RetrySchedule(),retryAt=0.0
    private var active=0,sequence=0,lastSource=0.0,lastSent=0.0,lastContact=0.0
    private var cadence=CadenceWindow()
    private var submitted:UInt64=0
    private let resources=ResourceSampler()
    private var diagnostics:[String:Double]=[:],lastDiagnostics=0.0
    init(store:SampleStore,url:URL,code:String,onCommand:@escaping(UInt8,UInt32?)->Void) {
        self.store=store;self.url=url;self.code=code;self.onCommand=onCommand
        let config=URLSessionConfiguration.ephemeral;config.waitsForConnectivity=false;config.timeoutIntervalForRequest=2;config.timeoutIntervalForResource=4;config.httpMaximumConnectionsPerHost=2
        session=URLSession(configuration:config)
        worker.async { [self] in
            let timer=DispatchSource.makeTimerSource(queue:worker);timer.schedule(deadline:.now(),repeating:.milliseconds(20),leeway:.milliseconds(2));timer.setEventHandler{[weak self] in self?.tick()};self.timer=timer;timer.resume()
        }
    }
    func stop() { worker.async { [self] in stopped=true;timer?.cancel();timer=nil;session.invalidateAndCancel();monitor.update{$0.phase="Idle";$0.live=false;$0.detail="Session stopped"} } }
    private func tick() {
        guard !stopped else { return }
        let now=ProcessInfo.processInfo.systemUptime
        monitor.update{$0.submitHz=cadence.rate(now:now);$0.submitted=submitted;$0.contactAge=lastContact>0 ? now-lastContact:.infinity}
        guard now>=retryAt else { return }
        if token.isEmpty {
            guard !pairing else { return };pairing=true;monitor.update{$0.phase="Authenticating";$0.detail="Connecting to Mac over local HTTP"}
            request(["pair":code]) { [weak self] object,status in
                guard let self else { return };self.pairing=false
                if let token=object?["session"] as? String,object?["paired"] as? Bool==true { self.token=token;self.retry.reset();self.lastContact=ProcessInfo.processInfo.systemUptime;self.monitor.update{$0.phase="Live";$0.live=true;$0.detail="Local HTTP to Mac"} }
                else if status==403 || status==401 { self.retryAt = .infinity;self.monitor.update{$0.phase="Needs attention";$0.detail="Check Mac pairing code";$0.live=false} }
                else { self.failed("Mac pairing unavailable") }
            };return
        }
        guard active<2 else { return }
        let snapshot=store.read(now:now)
        let source=snapshot.motion?.nativeTime ?? 0
        guard source != lastSource || now-lastSent>=0.2 else { return }
        lastSource=source;lastSent=now;sequence += 1
        if now-lastDiagnostics>=1 {
            lastDiagnostics=now;let r=resources.sample(now:now)
            diagnostics=["captureHz":snapshot.captureHz,"captureGap":snapshot.captureGap,"capturedTotal":Double(snapshot.captured),"submittedTotal":Double(submitted),"submitHz":cadence.rate(now:now),"cpu":r.cpuPercent ?? -1,"memory":r.residentMB ?? -1,"thermal":Double(r.thermal),"active":snapshot.active ? 1:0,"dimmed":snapshot.dimmed ? 1:0,"lowPower":r.lowPower ? 1:0]
        }
        var values:[String:[Double]]=[:],dates:[String:Double]=[:],statuses:[String:String]=[:]
        for (id,reading) in snapshot.readings {
            if reading.state==0,!reading.values.isEmpty { values[id]=reading.values;dates[id]=reading.sourceTime }
            if reading.state != 0 { statuses[id]=reading.detail } else { statuses[id]="" }
        }
        if let motion=snapshot.motion { values["quaternion"]=motion.quaternion }
        active += 1;submitted &+= 1;cadence.record(now)
        request(["session":token,"sequence":sequence,"values":values,"dates":dates,"status":statuses,"diagnostics":diagnostics]) { [weak self] object,status in
            guard let self else { return };self.active=max(0,self.active-1)
            guard let object,status==200,object["error"]==nil else { if status==403 || status==401 { self.token="" };self.failed("Mac response interrupted");return }
            self.lastContact=ProcessInfo.processInfo.systemUptime;self.retry.reset();self.retryAt=0
            self.monitor.update{$0.live=true;$0.phase="Live";$0.detail="Local HTTP to Mac"}
            let ids:[String:UInt8]=["haptic":1,"mint":2,"violet":3,"reset":4,"audit-all":5]
            for command in object["commands"] as? [String] ?? [] { if let id=ids[command] { self.onCommand(id,nil) } }
        }
    }
    private func failed(_ reason:String) {
        retryAt=ProcessInfo.processInfo.systemUptime+retry.nextDelay()
        monitor.update{$0.phase="Retrying";$0.detail=reason;$0.lastError=reason;$0.reconnects += 1;$0.live=false}
    }
    private func request(_ object:[String:Any],completion:@escaping([String:Any]?,Int)->Void) {
        guard let body=try? JSONSerialization.data(withJSONObject:object) else { completion(nil,0);return }
        var req=URLRequest(url:url);req.httpMethod="POST";req.httpBody=body;req.setValue("application/json",forHTTPHeaderField:"Content-Type")
        session.dataTask(with:req) { [weak self] data,response,_ in
            guard let self else { return }
            self.worker.async { [weak self] in
                guard let self,!self.stopped else { return }
                let obj=data.flatMap{try? JSONSerialization.jsonObject(with:$0)} as? [String:Any]
                completion(obj,(response as? HTTPURLResponse)?.statusCode ?? 0)
            }
        }.resume()
    }
}
