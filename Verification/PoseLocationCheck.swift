import Foundation
@main struct PoseLocationCheck {
    @MainActor static func main() {
        func near(_ a:Double,_ b:Double) {precondition(abs(a-b)<0.0001,"\(a) != \(b)")}
        let model=Studio(startNetworking:false);model.setDemo(false)
        let flat=PoseQuaternion.euler(0,0,1.2)
        model.ingest("quaternion",[flat.x,flat.y,flat.z,flat.w])
        let up=model.physicalDisplayPose.rotate(Vector3(x:0,y:0,z:1));near(up.z,1);near(up.x,0)
        let tilted=PoseQuaternion.euler(0.5,0.3,1.2)
        model.ingest("quaternion",[tilted.x,tilted.y,tilted.z,tilted.w]);let before=model.physicalDisplayPose
        model.setNeutralPose();precondition(model.physicalDisplayPose==before,"Signal zero must not change the physical picture")
        model.alignPoseView();near(model.physicalDisplayPose.rotate(Vector3(x:0,y:0,z:1)).z,tilted.rotate(Vector3(x:0,y:0,z:1)).z)
        let bodyGravity=tilted.inverse.rotate(Vector3(x:0,y:0,z:-1))
        near(model.physicalDisplayPose.rotate(bodyGravity).z,-1)
        model.ingest("heading",[359],source:Date(timeIntervalSince1970:100));model.ingest("heading",[1],source:Date(timeIntervalSince1970:100.2))
        let heading=model.displayHeading!;precondition(heading>350 || heading<10,"North crossing must take the short arc")
        print("PASS: desk-flat pose, physical tilt preserved through numeric neutral and view alignment, gravity world down, circular compass smoothing")
    }
}
