import Foundation
@main struct CardRedesignCheck {
    @MainActor static func main() throws {
        func near(_ a:Double,_ b:Double) {precondition(abs(a-b)<1e-6,"\(a) != \(b)")}
        near(CardMath.wrap(1-359),2)
        near(CardMath.component([2,4,8],axis:1),4)
        near(CardMath.component([3,4,0],axis:3),5)
        let a=CardMath.smooth(0,toward:1,milliseconds:200,dt:0.1)
        near(CardMath.smooth(a,toward:1,milliseconds:200,dt:0.1),CardMath.smooth(0,toward:1,milliseconds:200,dt:0.2))
        near(CardMath.normalize(-40,lower:-60,upper:-20,curve:"Linear",inverted:false),0.5)
        near(CardMath.normalize(3,lower:4,upper:1,curve:"Linear",inverted:false),0)
        var pressure=CardSettings.defaults("pressure");pressure.reference=101.3;pressure.convertUnits(for:"pressure",to:"hPa");near(pressure.span,2);near(pressure.reference!,1013)
        var gravity=CardSettings.defaults("gravity");gravity.changeMode(for:"gravity",to:"Axis");near(gravity.lower,-1);near(gravity.upper,1)
        let old=Data(#"{"capability":"crown","id":"00000000-0000-0000-0000-000000000001","x":40,"y":70,"gain":2,"smoothing":0.25,"deadzone":0,"inverted":false,"output":"Visual","axis":0,"bias":0,"wide":false,"note":""}"#.utf8)
        let restored=try JSONDecoder().decode(Tile.self,from:old);precondition(restored.settings==nil && restored.x==40)
        let earlierSettings=try JSONDecoder().decode(CardSettings.self,from:Data(#"{"response":true,"lower":-60,"upper":-20}"#.utf8))
        precondition(earlierSettings.response && earlierSettings.lower == -60 && earlierSettings.tolerance==0.1)
        let model=Studio(startNetworking:false);model.tiles=[];model.setDemo(false);model.connected=true
        var y=Tile(capability:"acceleration",x:28,y:28,axis:1);y.settings = .defaults("acceleration");model.tiles=[y];model.ingest("acceleration",[2,4,8]);model.setCardReference(y.id);near(model.tiles[0].settings!.reference!,4);model.tiles[0].settings!.response=true;model.tick();near(model.transformed(model.tiles[0]),0.5)
        var health=Tile(capability:"heart",x:0,y:0,gain:99,inverted:true);health.settings = .defaults("heart");model.ingest("heart",[72],source:Date(timeIntervalSinceNow:-1000));near(model.measurement(health),72)
        let touch=catalog.first{$0.id=="touch"}!;model.add(touch);let tid=model.tiles.last!.id
        model.tiles[model.tiles.count-1].settings!.response=true;model.tiles[model.tiles.count-1].settings!.pulseMS=20
        model.ingest("touch",[0]);model.tick();model.ingest("touch",[1]);model.tick();near(model.transformed(model.tiles.last!),1)
        Thread.sleep(forTimeInterval:0.03);model.ingest("touch",[1]);model.tick();near(model.transformed(model.tiles.last!),0)
        let before=model.tiles.map(\.id),kit=CardKit.builtins.first{$0.id=="controls"}!
        model.addKit(kit);precondition(model.tiles.count==before.count+kit.capabilities.count)
        model.addKit(kit);precondition(model.tiles.count==before.count+kit.capabilities.count,"Do not duplicate an existing kit group")
        model.removeGroup(kit.id);precondition(model.tiles.map(\.id)==before,"Removing a group must preserve separately added cards")
        model.snap=false;model.move(tid,x:250,y:175);near(model.tiles.last!.x,250);near(model.tiles.last!.y,175)
        let encoded=try JSONEncoder().encode(Workspace(name:"Redesign",tiles:model.tiles)),decoded=try JSONDecoder().decode(Workspace.self,from:encoded)
        precondition(decoded.tiles==model.tiles)
        model.workspaceName="Fixture preset";model.save();precondition(model.readSaved()["Fixture preset"] != nil)
        model.removeSavedPreset("Fixture preset");precondition(model.readSaved()["Fixture preset"]==nil && model.archivedPresetNames.contains("Fixture preset"))
        model.restoreSavedPreset("Fixture preset");precondition(model.readSaved()["Fixture preset"] != nil)
        let history=CardHistory();history.append(TimedReading(time:1,values:[72]));history.append(TimedReading(time:1,values:[72]));precondition(history.count==1,"Repeated saved record is not new history")
        for i in 2...10000 {history.append(TimedReading(time:Double(i),values:[1]))};precondition(history.count==4096)
        print("PASS: old workspace decoding; selected-component reference; unmodified saved records; circular wrap; time-based smoothing; unit conversion; event replay; bounded timed history; additive/removable presets and recoverable custom preset storage; drag coordinates and persistence round trip")
    }
}
