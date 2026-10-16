import Foundation
import AVFoundation
@main struct AudioMeterCheck {
    static func main() {
        let format=AVAudioFormat(standardFormatWithSampleRate:48000,channels:1)!
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:1024)!
        buffer.frameLength=1024
        let meter=AudioLevelMailbox()
        precondition(meter.reading()==nil,"No buffer means no measurement")
        for (amplitude,expected) in [(Float(1),0.0),(Float(0.1),-20.0),(Float(0),-160.0)] {
            for index in 0..<1024 { buffer.floatChannelData![0][index]=amplitude }
            meter.capture(buffer)
            let reading=meter.reading()!
            precondition(abs(reading.0-expected)<0.001,"RMS level must be in dBFS")
            precondition(abs(ProcessInfo.processInfo.systemUptime-reading.1)<1,"Timestamp must identify a fresh captured buffer")
        }
        print("PASS: no invented initial level; full-scale, -20 dBFS and silence RMS; fresh-buffer timestamp")
    }
}
