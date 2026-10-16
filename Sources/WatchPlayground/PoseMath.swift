import Foundation
struct Vector3:Equatable {
    var x:Double; var y:Double; var z:Double
    static let zero=Self(x:0,y:0,z:0)
    var length:Double { sqrt(x*x+y*y+z*z) }
    var faceUpTiltDegrees:Double { guard length>1e-9 else { return 0 };return acos(max(-1,min(1,-z/length)))*180/Double.pi }
    var normalized:Self { let n=length; return n>1e-9 ? Self(x:x/n,y:y/n,z:z/n):.zero }
}
struct PoseQuaternion:Equatable {
    var x:Double; var y:Double; var z:Double; var w:Double
    static let identity=Self(x:0,y:0,z:0,w:1)
    init(x:Double,y:Double,z:Double,w:Double) { self.x=x;self.y=y;self.z=z;self.w=w }
    init?(_ values:[Double]) {
        guard values.count==4,values.allSatisfy({$0.isFinite}) else { return nil }
        let n=sqrt(values.reduce(0){$0+$1*$1}); guard n>1e-9 else { return nil }
        self.init(x:values[0]/n,y:values[1]/n,z:values[2]/n,w:values[3]/n)
    }
    var inverse:Self { Self(x:-x,y:-y,z:-z,w:w) }
    static func *(a:Self,b:Self)->Self {
        Self(x:a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,y:a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,z:a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w,w:a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z)
    }
    func rotate(_ v:Vector3)->Vector3 {
        let q=self * Self(x:v.x,y:v.y,z:v.z,w:0) * inverse
        return Vector3(x:q.x,y:q.y,z:q.z)
    }
    static func euler(_ roll:Double,_ pitch:Double,_ yaw:Double)->Self {
        let a=roll/2,b=pitch/2,c=yaw/2
        return Self(x:sin(a)*cos(b)*cos(c)-cos(a)*sin(b)*sin(c),y:cos(a)*sin(b)*cos(c)+sin(a)*cos(b)*sin(c),z:cos(a)*cos(b)*sin(c)-sin(a)*sin(b)*cos(c),w:cos(a)*cos(b)*cos(c)+sin(a)*sin(b)*sin(c))
    }
    var euler:[Double] {
        [atan2(2*(w*x+y*z),1-2*(x*x+y*y)),asin(max(-1,min(1,2*(w*y-z*x)))),atan2(2*(w*z+x*y),1-2*(y*y+z*z))]
    }
}
