import SwiftUI

@main struct WatchPlaygroundCompanion:App {
    @StateObject private var session=WatchSession()
    var body:some Scene { WindowGroup { WatchRoot().environmentObject(session) } }
}
struct WatchRoot:View {
    @EnvironmentObject private var session:WatchSession
    @Environment(\.scenePhase) private var phase
    @Environment(\.isLuminanceReduced) private var dimmed
    @State private var setup=false
    var body:some View {
        NavigationStack {
            TabView(selection:$session.page) {
                Group { if session.page==0 { SessionScreen(setup:$setup) } else { Color.clear } }.tag(0)
                Group { if session.page==1 { PlayScreen() } else { Color.clear } }.tag(1)
                Group { if session.page==2 { FeedsScreen() } else { Color.clear } }.tag(2)
                Group { if session.page==3 { DiagnosticsScreen() } else { Color.clear } }.tag(3)
            }.tabViewStyle(.page(indexDisplayMode:.automatic))
                .navigationTitle(["Session","Play","Feeds","Diagnostics"][min(3,max(0,session.page))])
                .navigationBarTitleDisplayMode(.inline)
        }.tint(.mint).background(.black)
            .overlay { OutputCurtain() }
            .sheet(isPresented:$setup) { SetupScreen().environmentObject(session).overlay { OutputCurtain() } }
            .onAppear { session.runtime(active:phase == .active,dimmed:dimmed) }
            .onChange(of:phase) { _,value in session.runtime(active:value == .active,dimmed:dimmed) }
            .onChange(of:dimmed) { _,value in session.runtime(active:phase == .active,dimmed:value) }
    }
}
struct SessionScreen:View {
    @EnvironmentObject private var session:WatchSession
    @Binding var setup:Bool
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:12) {
                HStack(spacing:7) {
                    Circle().fill(session.link.live ? Color.mint:Color.orange).frame(width:9,height:9)
                        .opacity(session.link.live ? max(0.12,exp(-session.link.contactAge/2)):0.5)
                    Text(session.link.phase.uppercased()).font(.system(size:11,weight:.bold,design:.rounded)).tracking(1.4)
                    Spacer()
                    Image(systemName:"applewatch.radiowaves.left.and.right").foregroundStyle(.mint)
                }
                Text(session.running ? "Your wrist.\nLive possibilities.":"Make something\nwith movement.")
                    .font(.system(size:24,weight:.semibold,design:.rounded)).fixedSize(horizontal:false,vertical:true)
                HStack(spacing:8) {
                    MetricCard(title:"CAPTURE",value:String(format:"%.0f",session.snapshot.captureHz),unit:"Hz")
                    MetricCard(title:"SENDING",value:String(format:"%.0f",session.link.submitHz),unit:"Hz")
                }
                Text(session.running ? (session.link.phase=="Idle" ? "Local capture · connect when ready":session.link.detail):session.notice)
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                if session.running {
                    Button("Open controls",systemImage:"hand.tap") { session.page=1 }.tint(.mint)
                    Button(session.link.phase=="Idle" ? "Connect to Mac":"Connection setup",systemImage:"antenna.radiowaves.left.and.right") { setup=true }
                    Button("Stop session",role:.destructive) { session.stop() }.font(.caption)
                } else {
                    Button("Start exploring",systemImage:"play.fill") { session.start() }.tint(.mint)
                    Button("Connect to Mac") { setup=true }.font(.caption)
                }
                Text(session.runtimeLabel+" · Mac reply "+age(session.link.contactAge))
                    .font(.system(size:10)).foregroundStyle(.secondary)
            }.padding(.horizontal,4).padding(.bottom,18)
        }
    }
    private func age(_ seconds:Double)->String { seconds.isFinite ? String(format:"%.1fs ago",seconds):"not received" }
}
struct MetricCard:View {
    let title:String,value:String,unit:String
    var body:some View {
        VStack(alignment:.leading,spacing:4) {
            Text(title).font(.system(size:9,weight:.semibold)).foregroundStyle(.secondary)
            HStack(alignment:.firstTextBaseline,spacing:3) { Text(value).font(.system(size:27,weight:.medium,design:.rounded)).monospacedDigit();Text(unit).font(.caption2).foregroundStyle(.secondary) }
        }.frame(maxWidth:.infinity,alignment:.leading).padding(9).background(.white.opacity(0.065),in:RoundedRectangle(cornerRadius:14))
    }
}
struct PlayScreen:View {
    @EnvironmentObject private var session:WatchSession
    @FocusState private var focused:Bool
    var body:some View {
        VStack(spacing:7) {
            Button { session.touch() } label: {
                VStack(spacing:3) {
                    Image(systemName:"hand.tap.fill").font(.title2)
                    Text("TAP · \(session.taps)").font(.system(size:16,weight:.bold,design:.rounded)).monospacedDigit()
                }.frame(maxWidth:.infinity,maxHeight:.infinity).contentShape(Rectangle())
            }.buttonStyle(.plain).background(Color.pink.opacity(0.28),in:RoundedRectangle(cornerRadius:20))
                .modifier(PrimaryGesture()).accessibilityLabel("Touch pad, \(session.taps) taps")
            HStack {
                Image(systemName:"digitalcrown.horizontal.arrow.counterclockwise")
                Text(session.crown,format:.number.precision(.fractionLength(2))).monospacedDigit()
                Spacer()
                Circle().fill(focused ? Color.mint:Color.gray).frame(width:5,height:5)
            }.font(.headline).padding(10)
                .background(Color.mint.opacity(focused ? 0.18:0.06),in:RoundedRectangle(cornerRadius:13))
                .focusable().focused($focused)
                .digitalCrownRotation(Binding(get:{session.crown},set:{session.turn($0)}),from:-1000,through:1000,by:0.01,sensitivity:.medium,isContinuous:true,isHapticFeedbackEnabled:false)
                .onTapGesture { focused=true }
                .accessibilityLabel("Crown control, \(session.crown)")
            HStack { Text(focused ? "Crown ready":"Tap value to focus").foregroundStyle(.secondary);Spacer();Button("Zero") { session.resetCrown();focused=true }.buttonStyle(.plain).foregroundStyle(.mint) }.font(.system(size:10))
        }.padding(.horizontal,5).padding(.bottom,20)
            .onAppear { session.start();focused=true }
    }
}
struct PrimaryGesture:ViewModifier {
    @ViewBuilder func body(content:Content)->some View { if #available(watchOS 11,*) { content.handGestureShortcut(.primaryAction) } else { content } }
}
struct SetupScreen:View {
    @EnvironmentObject private var session:WatchSession
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pairCode") private var code=""
    @AppStorage("macHost") private var host=""
    var body:some View {
        NavigationStack {
            Form {
                Section("Pair with your Mac") {
                    TextField("Six-digit code",text:$code).textContentType(.oneTimeCode)
                    Button("Direct Bluetooth") { session.connectBluetooth();dismiss() }.tint(.mint)
                    Text("Open Connect Watch on the Mac to find its pairing code.").font(.caption2).foregroundStyle(.secondary)
                }
                Section("Local network alternative") {
                    TextField("Mac IP address",text:$host).textContentType(.URL)
                    Button("Connect over Wi-Fi") { session.connectHTTP();dismiss() }
                    Text("Uses local HTTP. WatchOS chooses the network path; this button cannot force the Wi-Fi radio.").font(.caption2)
                }
                if session.link.phase != "Idle" { Button("Disconnect Mac") { session.disconnect();dismiss() } }
            }.navigationTitle("Connection").toolbar { ToolbarItem(placement:.cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
struct FeedsScreen:View {
    @EnvironmentObject private var session:WatchSession
    var body:some View {
        ScrollView {
            LazyVStack(alignment:.leading,spacing:9) {
                Text("20 FEED ROUTES").font(.system(size:10,weight:.bold)).tracking(1).foregroundStyle(.mint)
                Toggle("Microphone level",isOn:Binding(get:{session.microphoneOn},set:{session.microphone($0)}))
                Toggle("Location / compass",isOn:Binding(get:{session.locationOn},set:{session.location($0)}))
                Button("Read saved Health data",systemImage:"heart") { session.savedHealth() }.font(.caption)
                Button("Start all available feeds") { session.allFeeds() }.font(.caption)
                ForEach(FeedDefinition.all) { definition in
                    FeedRow(definition:definition,reading:session.snapshot.readings[definition.id])
                }
                Text("ALSO IN THE MAC LIBRARY").font(.system(size:10,weight:.bold)).foregroundStyle(.mint).padding(.top,5)
                Text("Diagnostics and connection report app state. Sound, haptics and display are outputs. Double tap invokes the Touch action; it is not a separate raw feed.").font(.caption2).foregroundStyle(.secondary)
                Text("12 reference entries").font(.caption).bold()
                Text("Action button (not on Series 10), sleep, ECG, workouts, water sensors, high-rate motion, accessory Bluetooth, UWB, raw PPG, ambient light, NFC and raw radios. These are not live feeds in this build.").font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal,4).padding(.bottom,20)
        }
    }
}
struct FeedRow:View {
    let definition:FeedDefinition,reading:FeedReading?
    var body:some View {
        VStack(alignment:.leading,spacing:4) {
            HStack(spacing:5) {
                Circle().fill(reading?.state==0 && !(reading?.values.isEmpty ?? true) ? Color.mint:Color.orange).frame(width:5,height:5)
                Text(definition.name).font(.system(size:12,weight:.medium))
            }
            if let reading,reading.state==0,!reading.values.isEmpty {
                Text(reading.values.prefix(definition.id=="location" ? 1:3).map{String(format:"%.2f",$0)}.joined(separator:"  ")+" "+definition.unit).font(.system(size:13,design:.monospaced))
                Text(definition.saved ? "Saved record · \(Date(timeIntervalSince1970:reading.sourceTime).formatted(date:.abbreviated,time:.shortened))":"Source \(max(0,Date().timeIntervalSince1970-reading.sourceTime),specifier:"%.1f")s ago").font(.system(size:9)).foregroundStyle(.secondary)
            } else { Text(reading?.detail ?? "Waiting for a reading").font(.system(size:10)).foregroundStyle(.secondary) }
        }.frame(maxWidth:.infinity,alignment:.leading).padding(9).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
    }
}
struct DiagnosticsScreen:View {
    @EnvironmentObject private var session:WatchSession
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:10) {
                Text("WATCH APP").font(.system(size:10,weight:.bold)).tracking(1).foregroundStyle(.mint)
                HStack { MetricCard(title:"CPU",value:String(format:"%.0f",session.cpu),unit:"%");MetricCard(title:"MEMORY",value:String(format:"%.0f",session.memory),unit:"MB") }
                Text("CPU uses one-core equivalent. This is app usage, not whole-device load.").font(.system(size:9)).foregroundStyle(.secondary)
                diagnostic("Runtime",session.runtimeLabel)
                diagnostic("Thermal",session.thermal)
                diagnostic("Capture gap",String(format:"%.0f ms",session.snapshot.captureGap))
                diagnostic("UI scheduling lag",String(format:"%.0f ms",session.uiLag))
                diagnostic("Captured",String(session.snapshot.captured))
                diagnostic("Submitted",String(session.link.submitted))
                diagnostic("Reconnect attempts",String(session.link.reconnects))
                diagnostic("ATT payload",String(session.link.mtu)+" B")
                diagnostic("BLE blocked",String(format:"%.1f s",session.link.blockedSeconds))
                if !session.link.lastError.isEmpty { Text(session.link.lastError).font(.caption2).foregroundStyle(.orange) }
                Text("LOCAL OUTPUT TESTS").font(.system(size:10,weight:.bold)).foregroundStyle(.mint).padding(.top,5)
                Button("Feel a notification") { session.execute(1) }
                Button("Hear Watch tone") { session.sound() }
                HStack { Button("Mint") { session.execute(2) };Button("Violet") { session.execute(3) } }
                Text(session.outputMessage).font(.caption2).foregroundStyle(.secondary)
                Text("These tests run on the Watch without a Mac. Acknowledgement means the app invoked the output; confirm the physical result yourself.").font(.system(size:10)).foregroundStyle(.secondary)
                Text("Bluetooth background support does not grant continuous sensor runtime. Wrist-down behavior is measured separately.").font(.system(size:10)).foregroundStyle(.secondary)
            }.padding(.horizontal,4).padding(.bottom,20)
        }
    }
    private func diagnostic(_ name:String,_ value:String)->some View { HStack(alignment:.top) { Text(name).foregroundStyle(.secondary);Spacer();Text(value).multilineTextAlignment(.trailing).monospacedDigit() }.font(.system(size:11)) }
}
struct OutputCurtain:View {
    @EnvironmentObject private var session:WatchSession
    var body:some View {
        if let color=session.outputColor {
            ZStack {
                color.ignoresSafeArea()
                VStack(spacing:14) {
                    Image(systemName:"checkmark.circle.fill").font(.largeTitle)
                    Text(session.outputMessage).font(.headline).multilineTextAlignment(.center)
                    Button("Clear display") { session.execute(4) }.tint(.black)
                }.foregroundStyle(.black).padding()
            }.accessibilityIdentifier("output-test-overlay")
        }
    }
}
