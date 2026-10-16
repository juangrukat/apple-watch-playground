import Foundation
import CoreMotion
import CoreLocation
import HealthKit
import AVFoundation
import WatchKit

@MainActor final class SensorServices:NSObject,CLLocationManagerDelegate {
    private let store:SampleStore
    private let altimeter=CMAltimeter(),pedometer=CMPedometer(),location=CLLocationManager(),health=HKHealthStore()
    private var epoch=UUID()
    private var queries:[HKQuery]=[]
    private var engine:AVAudioEngine?
    private var levels=AudioLevelMailbox()
    private var micAttempt=UUID()
    private var requestedMic=false
    private(set) var microphoneOn=false
    private(set) var locationOn=false
    private var running=false
    private var interruptions:NSObjectProtocol?
    private var interrupted=false
    private var pausedForSound=false
    private var lastMicRestart=0.0
    private var startedAt=Date.distantPast
    init(store:SampleStore) {
        self.store=store;super.init();location.delegate=self
        interruptions=NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main) { [weak self] notification in
            let kind=(notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
            Task { @MainActor in
                guard let self,self.running,self.requestedMic else { return }
                if kind==AVAudioSession.InterruptionType.began.rawValue {
                    self.interrupted=true;self.store.status("microphone",6,"Microphone interrupted")
                } else if kind==AVAudioSession.InterruptionType.ended.rawValue {
                    self.interrupted=false
                    if !self.pausedForSound { self.startMicrophone() }
                }
            }
        }
    }
    func start() {
        stop();running=true;startedAt=Date();epoch=UUID();let token=epoch
        WKInterfaceDevice.current().isBatteryMonitoringEnabled=true
        for key in ["microphone","heading","location"] { store.status(key,1,"Enable on Watch") }
        for key in ["heart","hrv","oxygen","temperature"] { store.status(key,1,"Request saved Health data") }
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to:.main) { [weak self] data,error in Task { @MainActor in
                guard let self,self.running,self.epoch==token else { return }
                if let data { self.store.put("altitude",[data.relativeAltitude.doubleValue]);self.store.put("pressure",[data.pressure.doubleValue]) }
                else if error != nil { self.store.status("altitude",2,"Altitude unavailable or permission denied");self.store.status("pressure",2,"Pressure unavailable or permission denied") }
            } }
        } else { for id in ["altitude","pressure"] { store.status(id,3,"Unavailable on this Watch") } }
        if CMPedometer.isStepCountingAvailable() {
            let start=Date()
            pedometer.startUpdates(from:start) { [weak self] data,error in Task { @MainActor in self?.steps(data,error,token) } }
            Task { [weak self] in
                try? await Task.sleep(for:.seconds(2))
                guard let self,self.running,self.epoch==token else { return }
                self.pedometer.queryPedometerData(from:start,to:Date()) { [weak self] data,error in Task { @MainActor in self?.steps(data,error,token) } }
            }
        } else { store.status("steps",3,"Unavailable on this Watch") }
        tick()
    }
    private func steps(_ data:CMPedometerData?,_ error:Error?,_ token:UUID) {
        guard running,epoch==token else { return }
        if let data { store.put("steps",[data.numberOfSteps.doubleValue,data.currentCadence?.doubleValue ?? 0],at:data.endDate.timeIntervalSince1970) }
        else if error != nil { store.status("steps",2,"Pedometer unavailable or permission denied") }
    }
    func tick() {
        guard running else { return }
        let device=WKInterfaceDevice.current()
        if device.batteryLevel>=0 { store.put("battery",[Double(device.batteryLevel)*100,Double(device.batteryState.rawValue)]) }
        if microphoneOn {
            if engine?.isRunning==true,let (level,time)=levels.reading(),ProcessInfo.processInfo.systemUptime-time<0.5 {
                store.put("microphone",[level],at:Date().timeIntervalSince1970-max(0,ProcessInfo.processInfo.systemUptime-time))
            } else {
                store.status("microphone",6,"Microphone paused")
                let now=ProcessInfo.processInfo.systemUptime
                if requestedMic,!interrupted,!pausedForSound,now-lastMicRestart>3 { startMicrophone() }
            }
        }
    }
    func setMicrophone(_ enabled:Bool) {
        requestedMic=enabled;micAttempt=UUID();let attempt=micAttempt
        stopMicrophone()
        guard enabled,running else { store.status("microphone",1,"Microphone off");return }
        store.status("microphone",8,"Approve microphone permission")
        AVAudioApplication.requestRecordPermission { [weak self] allowed in Task { @MainActor in
            guard let self,self.running,self.micAttempt==attempt,self.requestedMic else { return }
            if allowed { self.startMicrophone() } else { self.requestedMic=false;self.store.status("microphone",2,"Microphone permission denied") }
        } }
    }
    private func startMicrophone() {
        guard running,requestedMic,!interrupted,!pausedForSound else { return }
        lastMicRestart=ProcessInfo.processInfo.systemUptime
        stopMicrophone()
        do {
            let session=AVAudioSession.sharedInstance();try session.setCategory(.record,mode:.measurement)
            try session.setAllowHapticsAndSystemSoundsDuringRecording(true);try session.setActive(true)
            let engine=AVAudioEngine(),mailbox=AudioLevelMailbox(),input=engine.inputNode,format=engine.inputNode.outputFormat(forBus:0)
            guard format.sampleRate>0,format.channelCount>0 else { throw NSError(domain:"Playground",code:1,userInfo:[NSLocalizedDescriptionKey:"No microphone input format"]) }
            input.installTap(onBus:0,bufferSize:1024,format:format) { buffer,_ in mailbox.capture(buffer) }
            engine.prepare();try engine.start();self.engine=engine;levels=mailbox;microphoneOn=true
            store.status("microphone",0,"Waiting for microphone buffer")
        } catch { microphoneOn=false;store.status("microphone",5,"Microphone error: \(error.localizedDescription)");try? AVAudioSession.sharedInstance().setActive(false) }
    }
    private func stopMicrophone() {
        if let engine { engine.inputNode.removeTap(onBus:0);engine.stop() }
        engine=nil;levels=AudioLevelMailbox();microphoneOn=false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    func pauseForSound()->Bool { let restore=requestedMic;pausedForSound=true;stopMicrophone();if restore { store.status("microphone",6,"Paused for sound test") };return restore }
    func restoreAfterSound(_ restore:Bool) { pausedForSound=false;if restore && requestedMic && running { startMicrophone() } }
    func setLocation(_ enabled:Bool) {
        locationOn=enabled && running
        if locationOn { location.requestWhenInUseAuthorization();updateLocation() }
        else { location.stopUpdatingLocation();location.stopUpdatingHeading();for id in ["location","heading"] { store.status(id,1,"Location off") } }
    }
    private func updateLocation() {
        guard running,locationOn else { return }
        switch location.authorizationStatus {
        case .authorizedAlways,.authorizedWhenInUse:
            location.desiredAccuracy=kCLLocationAccuracyBest;location.distanceFilter=kCLDistanceFilterNone;location.headingFilter=1;location.startUpdatingLocation()
            if CLLocationManager.headingAvailable() { location.startUpdatingHeading() } else { store.status("heading",3,"Compass unavailable") }
        case .denied,.restricted:
            locationOn=false;for id in ["location","heading"] { store.status(id,2,"Location permission denied") }
        default:for id in ["location","heading"] { store.status(id,8,"Approve location permission") }
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager:CLLocationManager) { Task { @MainActor in self.updateLocation() } }
    nonisolated func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]) {
        guard let sample=locations.last else { return }
        Task { @MainActor in
            guard self.running,self.locationOn,sample.horizontalAccuracy>=0,abs(sample.timestamp.timeIntervalSinceNow)<30 else { return }
            self.store.put("locationQuality",[sample.horizontalAccuracy,sample.speedAccuracy,0],at:sample.timestamp.timeIntervalSince1970)
            self.store.put("location",[sample.speed,sample.coordinate.latitude,sample.coordinate.longitude],at:sample.timestamp.timeIntervalSince1970)
        }
    }
    nonisolated func locationManager(_ manager:CLLocationManager,didUpdateHeading heading:CLHeading) {
        Task { @MainActor in
            guard self.running,self.locationOn,abs(heading.timestamp.timeIntervalSinceNow)<10 else { return }
            self.store.put("headingQuality",[heading.headingAccuracy],at:heading.timestamp.timeIntervalSince1970)
            guard heading.headingAccuracy>=0 else {self.store.status("heading",11,"Compass unreliable; move away from magnets");return}
            self.store.put("heading",[heading.magneticHeading],at:heading.timestamp.timeIntervalSince1970)
        }
    }
    nonisolated func locationManager(_ manager:CLLocationManager,didFailWithError error:Error) {
        Task { @MainActor in
            guard self.running,self.locationOn else { return }
            let code=(error as NSError).code
            self.store.put("locationQuality",[-1,-1,Double(code)])
            if (error as NSError).domain==kCLErrorDomain,code==CLError.locationUnknown.rawValue {
                self.store.status("location",10,"Searching for a location fix; last fix retained")
            } else {self.store.status("location",5,"Location error \(code): \(error.localizedDescription)")}
        }
    }
    func readHealth() {
        guard running else { return }
        let token=epoch
        guard HKHealthStore.isHealthDataAvailable() else { for id in ["heart","hrv","oxygen","temperature"] { store.status(id,3,"Health unavailable") };return }
        for query in queries { health.stop(query) };queries=[]
        let definitions:[(String,HKQuantityTypeIdentifier,HKUnit)]=[("heart",.heartRate,.count().unitDivided(by:.minute())),("hrv",.heartRateVariabilitySDNN,.secondUnit(with:.milli)),("oxygen",.oxygenSaturation,.percent()),("temperature",.appleSleepingWristTemperature,.degreeCelsius())]
        let list=definitions.compactMap { id,type,unit -> (String,HKQuantityType,HKUnit)? in HKQuantityType.quantityType(forIdentifier:type).map{(id,$0,unit)} }
        for (id,_,_) in list { store.status(id,8,"Approve Health request") }
        health.requestAuthorization(toShare:[],read:Set(list.map{$0.1})) { [weak self] success,_ in Task { @MainActor in
            guard let self,self.running,self.epoch==token else { return }
            guard success else { for (id,_,_) in list { self.store.status(id,2,"Health authorization unavailable") };return }
            for (id,type,unit) in list {
                self.store.status(id,9,"Reading saved records")
                let query=HKSampleQuery(sampleType:type,predicate:nil,limit:1,sortDescriptors:[NSSortDescriptor(key:HKSampleSortIdentifierEndDate,ascending:false)]) { [weak self] _,samples,error in Task { @MainActor in
                    guard let self,self.running,self.epoch==token else { return }
                    if let record=samples?.first as? HKQuantitySample {
                        self.store.put(id,[record.quantity.doubleValue(for:unit)*(id=="oxygen" ? 100:1)],at:record.endDate.timeIntervalSince1970,detail:"Saved record")
                    } else { self.store.status(id,error == nil ? 4:5,error == nil ? "No authorized saved record":"Health query error") }
                } }
                self.queries.append(query);self.health.execute(query)
            }
        } }
    }
    func stop() {
        running=false;epoch=UUID();requestedMic=false;interrupted=false;pausedForSound=false;micAttempt=UUID()
        altimeter.stopRelativeAltitudeUpdates();pedometer.stopUpdates();location.stopUpdatingLocation();location.stopUpdatingHeading();locationOn=false
        for query in queries { health.stop(query) };queries=[];stopMicrophone()
        WKInterfaceDevice.current().isBatteryMonitoringEnabled=false
    }
}
