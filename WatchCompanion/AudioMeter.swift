import Foundation
import AVFoundation

// Only the latest scalar level crosses the audio callback; audio buffers are not retained.
final class AudioLevelMailbox {
    private let lock=NSLock()
    private var latest:(Double,Double)?
    func capture(_ buffer:AVAudioPCMBuffer) {
        guard let samples=buffer.floatChannelData,buffer.frameLength>0 else { return }
        let count=Int(buffer.frameLength),channels=Int(buffer.format.channelCount)
        guard channels>0 else { return }
        var sum=0.0
        for channel in 0..<channels {
            for index in 0..<count { let value=Double(samples[channel][index]);sum += value*value }
        }
        let rms=sqrt(sum/Double(count*channels))
        let level=max(-160,min(0,20*log10(max(1e-8,rms))))
        lock.lock();latest=(level,ProcessInfo.processInfo.systemUptime);lock.unlock()
    }
    func reading()->(Double,Double)? { lock.lock();defer{lock.unlock()};return latest }
}
