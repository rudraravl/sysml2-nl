package 'Bonanno Suprapubic Catheter System' {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    
    item def Urine;
    item def Saline;
    
    port def UrineInPort {
        in item urine : Urine;
    }
    port def UrineOutPort {
        out item urine : Urine;
    }
    port def SalineInPort {
        in item saline : Saline;
    }
    port def SalineOutPort {
        out item saline : Saline;
    }
    
    part def Bladder {
        port urineOut : UrineOutPort;
        port salineIn : SalineInPort;
    }
    
    part def AbdominalWall;
    
    part def Eyelet;
    
    part def CatheterTip {
        part eyelet : Eyelet[2..*];
        port urineIn : UrineInPort;
        port salineOut : SalineOutPort;
    }
    
    part def Balloon {
        attribute targetVolume : Real = 10;
        port salineIn : SalineInPort;
    }
    
    part def DrainageLumen {
        attribute isPatent : Boolean = true;
        port urineIn : UrineInPort;
        port urineOut : UrineOutPort;
    }
    
    part def IrrigationLumen {
        port salineIn : SalineInPort;
        port salineOut : SalineOutPort;
    }
    
    part def Catheter {
        port bladderUrineIn : UrineInPort;
        port bladderSalineOut : SalineOutPort;
        port bagUrineOut : UrineOutPort;
        port externalSalineIn : SalineInPort;
        port externalBalloonSalineIn : SalineInPort;
        
        part tip : CatheterTip;
        part drainageLumen : DrainageLumen;
        part irrigationLumen : IrrigationLumen;
        part balloon : Balloon;
        
        flow of urine : Urine from bladderUrineIn.urine to tip.urineIn.urine;
        flow of urine : Urine from tip.urineIn.urine to drainageLumen.urineIn.urine;
        flow of urine : Urine from drainageLumen.urineOut.urine to bagUrineOut.urine;
        
        flow of saline : Saline from externalSalineIn.saline to irrigationLumen.salineIn.saline;
        flow of saline : Saline from irrigationLumen.salineOut.saline to tip.salineOut.saline;
        flow of saline : Saline from tip.salineOut.saline to bladderSalineOut.saline;
        
        flow of saline : Saline from externalBalloonSalineIn.saline to balloon.salineIn.saline;
    }
    
    part def AntiRefluxValve {
        port urineIn : UrineInPort;
        port urineOut : UrineOutPort;
    }
    
    part def CollectionBag {
        attribute capacity : Real = 2000;
        port urineIn : UrineInPort;
        part valve : AntiRefluxValve;
        item storedUrine : Urine;
        
        flow of urine : Urine from urineIn.urine to valve.urineIn.urine;
        flow of urine : Urine from valve.urineOut.urine to storedUrine;
    }
    
    action def InflateBalloon {
        in saline : Saline;
    }
    action def IrrigateBladder {
        in saline : Saline;
        out urine : Urine;
    }
    action def DeflateBalloon {
        out saline : Saline;
    }
    
    state def CatheterLifecycle {
        entry; then Inserted;
        
        state Inserted;
        transition from Inserted to Positioning;
        
        state Positioning;
        transition from Positioning to Securing;
        
        state Securing {
            entry perform action inflate : InflateBalloon;
        }
        transition from Securing to Operational;
        
        state Operational {
            entry; then Draining;
            
            state Draining;
            transition from Draining to Blocked;
            transition from Blocked to Irrigating;
            
            state Irrigating {
                entry perform action irrigate : IrrigateBladder;
            }
            transition from Irrigating to Draining;
        }
        
        transition from Operational to Deflating;
        
        state Deflating {
            entry perform action deflate : DeflateBalloon;
        }
        transition from Deflating to Removed;
        
        state Removed;
    }
    
    requirement def ContinuousDrainageReq {
        doc /* The system shall provide continuous drainage of urine from the bladder to the collection bag. */
    }
    requirement def BalloonAnchoringReq {
        doc /* The catheter shall be anchored in the bladder by inflating the balloon with saline to a specified volume. */
    }
    requirement def IrrigationCapabilityReq {
        doc /* The system shall allow irrigation of the bladder through a dedicated lumen to clear blockages. */
    }
    requirement def AntiRefluxReq {
        doc /* The collection bag shall prevent backflow of urine toward the bladder via an anti-reflux valve. */
    }
    
    part def SuprapubicCatheterSystem {
        part bladder : Bladder;
        part abdominalWall : AbdominalWall;
        part catheter : Catheter;
        part collectionBag : CollectionBag;
        
        flow of urine : Urine from bladder.urineOut.urine to catheter.bladderUrineIn.urine;
        flow of saline : Saline from catheter.bladderSalineOut.saline to bladder.salineIn.saline;
        flow of urine : Urine from catheter.bagUrineOut.urine to collectionBag.urineIn.urine;
        
        perform action lifecycle : CatheterLifecycle;
    }
    
    part bonannoSystem : SuprapubicCatheterSystem {
        satisfy ContinuousDrainageReq;
        satisfy BalloonAnchoringReq;
        satisfy IrrigationCapabilityReq;
        satisfy AntiRefluxReq;
    }
}
