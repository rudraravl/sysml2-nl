package MedicalHeadMirror {
    private import ISQ::*;
    private import ScalarValues::*;

    part def Headband {
        attribute material : String = "elastic fabric";
        attribute isAdjustable : Boolean = true;
        attribute weight :> mass;
    }

    part def MountingFrame {
        attribute weight :> mass;
        attribute isRigid : Boolean = true;
    }

    part def ConcaveMirror {
        attribute focalDistance :> length = 25 [cm];
        attribute diameter :> length;
        attribute weight :> mass;
    }

    part def PivotJoint {
        attribute verticalAngle :> planeAngle;
        attribute horizontalAngle :> planeAngle;
        attribute adjustmentForce :> force;
        attribute weight :> mass;
    }

    connection def HeadbandToFrame {
        end headband : Headband;
        end mountingFrame : MountingFrame;
    }

    connection def FrameToJoint {
        end mountingFrame : MountingFrame;
        end joint : PivotJoint;
    }

    connection def JointToMirror {
        end joint : PivotJoint;
        end mirror : ConcaveMirror;
    }

    item def MountSignal;
    item def PositionSignal;
    item def OperateSignal;
    item def StoreSignal;

    state def HeadMirrorStates {
        entry; then stored;
        state stored;
        state mounted;
        state positioning;
        state operating;

        transition stored_to_mounted
            first stored
            accept MountSignal
            then mounted;

        transition mounted_to_positioning
            first mounted
            accept PositionSignal
            then positioning;

        transition positioning_to_operating
            first positioning
            accept OperateSignal
            then operating;

        transition operating_to_stored
            first operating
            accept StoreSignal
            then stored;
    }

    part def HeadMirrorSystem {
        part headband : Headband;
        part mountingFrame : MountingFrame;
        part joint : PivotJoint;
        part mirror : ConcaveMirror;

        attribute totalWeight :> mass = headband.weight + mountingFrame.weight + joint.weight + mirror.weight;

        connection hbToFrame : HeadbandToFrame
            connect headband to mountingFrame;
        connection frameToJoint : FrameToJoint
            connect mountingFrame to joint;
        connection jointToMirror : JointToMirror
            connect joint to mirror;

        exhibit headMirrorStates : HeadMirrorStates;
    }

    requirement def ErgonomicRequirements {
        subject device : HeadMirrorSystem;
        requirement weightReq {
            doc /* The device must be lightweight. */
            constraint { device.totalWeight < 200 [g] }
        }
        requirement comfortReq {
            doc /* The device must be comfortable for extended use. */
        }
        requirement adjustabilityReq {
            doc /* The device must be easy to adjust during a procedure. */
            constraint { device.joint.adjustmentForce < 10 [N] }
        }
    }

    requirement ergoReq : ErgonomicRequirements {
        subject :>> device : HeadMirrorSystem;
    }

    part medicalHeadMirror : HeadMirrorSystem {
        satisfy ergoReq;
    }
}
