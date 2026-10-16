import Foundation
import CoreMotion

final class CaptureEngine {
    private let motion=CMMotionManager()
    private let queue:OperationQueue = {
        let q=OperationQueue();q.name="Playground native capture";q.maxConcurrentOperationCount=1;q.qualityOfService = .userInteractive;return q
    }()
    private let store:SampleStore
    private let lock=NSLock()
    private var generation=UUID()
    init(store:SampleStore) { self.store=store }
    func start(rate:Double) {
        stop();let epoch=UUID();lock.lock();generation=epoch;lock.unlock()
        guard motion.isDeviceMotionAvailable else {
            for id in ["orientation","acceleration","rotation","gravity","intensity","stillness"] { store.status(id,3,"Unavailable on this Watch") };return
        }
        motion.deviceMotionUpdateInterval=1/max(10,min(100,rate))
        var peak=false,lastPeak=0.0,tempo=90.0
        motion.startDeviceMotionUpdates(to:queue) { [weak self] data,error in
            guard let self else { return }
            self.lock.lock();defer { self.lock.unlock() };guard self.generation==epoch else { return }
            guard let d=data else {
                if error != nil { for id in ["orientation","acceleration","rotation","gravity","intensity","stillness"] { self.store.status(id,2,"Motion unavailable or permission denied") } };return
            }
            let q=d.attitude.quaternion,g=d.gravity,a=d.userAcceleration,r=d.rotationRate
            let energy=sqrt(a.x*a.x+a.y*a.y+a.z*a.z),wall=Date().timeIntervalSince1970
            self.store.motion(MotionFrame(nativeTime:d.timestamp,sourceTime:wall,quaternion:[q.x,q.y,q.z,q.w],orientation:[d.attitude.roll,d.attitude.pitch,d.attitude.yaw],rotation:[r.x,r.y,r.z],gravity:[g.x,g.y,g.z],acceleration:[a.x+g.x,a.y+g.y,a.z+g.z],energy:energy))
            if energy>0.22 && !peak {
                let dt=d.timestamp-lastPeak
                if dt>0.3 { if dt<2 { tempo=tempo*0.65+60/dt*0.35;self.store.put("rhythm",[tempo],at:wall) };lastPeak=d.timestamp };peak=true
            } else if energy<0.12 { peak=false }
        }
    }
    func setRate(_ rate:Double) { motion.deviceMotionUpdateInterval=1/max(10,min(100,rate)) }
    func stop() { lock.lock();generation=UUID();lock.unlock();motion.stopDeviceMotionUpdates() }
}
