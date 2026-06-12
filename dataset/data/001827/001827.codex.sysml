package PeaucellierLipkinLinkageSystem {

    import ScalarValues::*;
    import ISQ::*;

    attribute def LengthValue :> Real {
        unit = "mm";
    }

    attribute def AngleValue :> Real {
        unit = "deg";
    }

    attribute def ForceValue :> Real {
        unit = "N";
    }

    attribute def TorqueValue :> Real {
        unit = "N*m";
    }

    attribute def VelocityValue :> Real {
        unit = "mm/s";
    }

    item def MechanicalEnergy {
        attribute kineticEnergy : Real;
        attribute potentialEnergy : Real;
    }

    item def RotaryMotion {
        attribute angularPosition : AngleValue;
        attribute angularVelocity : Real;
        attribute appliedTorque : TorqueValue;
    }

    item def TranslationalMotion {
        attribute xPosition : LengthValue;
        attribute yPosition : LengthValue;
        attribute linearVelocity : VelocityValue;
        attribute transmittedForce : ForceValue;
    }

    port def RevoluteJointPort {
        inout motion : RotaryMotion;
        inout load : ForceValue;
    }

    port def PointGuidancePort {
        out motion : TranslationalMotion;
        out straightLineError : LengthValue;
    }

    port def DrivePort {
        in commandAngle : AngleValue;
        in driveTorque : TorqueValue;
        out actualAngle : AngleValue;
    }

    part def GroundFrame {
        attribute baseLength : LengthValue = 120.0;
        attribute materialStiffness : Real = 2.0e11;

        port fixedPivotA : RevoluteJointPort;
        port fixedPivotB : RevoluteJointPort;
        port driveMount : DrivePort;
    }

    part def Link {
        attribute length : LengthValue;
        attribute mass : Real;
        attribute allowableAxialForce : ForceValue;
        attribute currentAngle : AngleValue;

        port end1 : RevoluteJointPort;
        port end2 : RevoluteJointPort;
    }

    part def TracingPoint {
        attribute idealX : LengthValue;
        attribute idealY : LengthValue;
        attribute actualX : LengthValue;
        attribute actualY : LengthValue;
        attribute straightnessError : LengthValue;

        port guideOutput : PointGuidancePort;
        port jointPort : RevoluteJointPort;
    }

    part def Actuator {
        attribute maximumTorque : TorqueValue = 4.0;
        attribute maximumSpeed : Real = 60.0;
        attribute commandedAngle : AngleValue;
        attribute measuredAngle : AngleValue;

        port shaft : DrivePort;
        port outputJoint : RevoluteJointPort;
    }

    part def PeaucellierLipkinLinkage {
        attribute rhombusLinkLength : LengthValue = 80.0;
        attribute radiusLinkLength : LengthValue = 45.0;
        attribute fixedPivotSeparation : LengthValue = 90.0;
        attribute straightLineTravel : LengthValue = 70.0;
        attribute maximumStraightLineError : LengthValue = 0.25;

        part frame : GroundFrame;
        part actuator : Actuator;

        part inputCrank : Link {
            length = 45.0;
            mass = 0.08;
            allowableAxialForce = 200.0;
        }

        part radiusLinkA : Link {
            length = 45.0;
            mass = 0.08;
            allowableAxialForce = 200.0;
        }

        part rhombusLinkAB : Link {
            length = 80.0;
            mass = 0.12;
            allowableAxialForce = 250.0;
        }

        part rhombusLinkBC : Link {
            length = 80.0;
            mass = 0.12;
            allowableAxialForce = 250.0;
        }

        part rhombusLinkCD : Link {
            length = 80.0;
            mass = 0.12;
            allowableAxialForce = 250.0;
        }

        part rhombusLinkDA : Link {
            length = 80.0;
            mass = 0.12;
            allowableAxialForce = 250.0;
        }

        part couplerPoint : TracingPoint;

        port driveInput : DrivePort;
        port straightLineOutput : PointGuidancePort;

        connect driveInput to actuator.shaft;
        connect actuator.outputJoint to inputCrank.end1;
        connect inputCrank.end2 to rhombusLinkAB.end1;
        connect rhombusLinkAB.end2 to rhombusLinkBC.end1;
        connect rhombusLinkBC.end2 to couplerPoint.jointPort;
        connect couplerPoint.jointPort to rhombusLinkCD.end1;
        connect rhombusLinkCD.end2 to rhombusLinkDA.end1;
        connect rhombusLinkDA.end2 to rhombusLinkAB.end1;
        connect frame.fixedPivotA to inputCrank.end1;
        connect frame.fixedPivotB to radiusLinkA.end1;
        connect radiusLinkA.end2 to rhombusLinkCD.end2;
        connect couplerPoint.guideOutput to straightLineOutput;

        action def ConvertRotationToStraightLine {
            in inputAngle : AngleValue;
            in driveTorque : TorqueValue;
            out outputMotion : TranslationalMotion;
            out geometricError : LengthValue;

            first start;
            then solveLinkageGeometry;
            then constrainInversePoint;
            then emitStraightLineMotion;
            then done;

            action solveLinkageGeometry;
            action constrainInversePoint;
            action emitStraightLineMotion;
        }

        state def OperatingStateMachine {
            entry action initializeGeometry;

            state Idle;
            state Homing;
            state Ready;
            state Driving;
            state StraightLineTracing;
            state OverloadFault;
            state MaintenanceLockout;

            transition first Idle;
            transition Idle to Homing
                accept commandHome;

            transition Homing to Ready
                accept homeReferenceDetected;

            transition Ready to Driving
                accept driveCommand
                if actuator.maximumTorque >= 0.5;

            transition Driving to StraightLineTracing
                accept linkageClosed
                if couplerPoint.straightnessError <= maximumStraightLineError;

            transition StraightLineTracing to Ready
                accept motionComplete;

            transition Driving to OverloadFault
                accept torqueLimitExceeded;

            transition StraightLineTracing to OverloadFault
                accept straightnessErrorExceeded;

            transition OverloadFault to MaintenanceLockout
                accept faultLatched;

            transition MaintenanceLockout to Idle
                accept resetAfterInspection;
        }

        perform action ConvertRotationToStraightLine {
            inputAngle = actuator.commandedAngle;
            driveTorque = actuator.maximumTorque;
            outputMotion = straightLineOutput.motion;
            geometricError = couplerPoint.straightnessError;
        }

        exhibit state OperatingStateMachine;
    }

    part def StraightLineGeneratingMechanism {
        doc /* Primary function: transform a controlled rotary input into an approximately exact rectilinear output path using the geometric inversion property of a Peaucellier-Lipkin linkage. */

        part linkage : PeaucellierLipkinLinkage;

        port commandedDrive : DrivePort;
        port linearMotionOutput : PointGuidancePort;

        connect commandedDrive to linkage.driveInput;
        connect linkage.straightLineOutput to linearMotionOutput;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall convert rotary motion applied at the driven crank into a guided straight-line motion at the tracing point without requiring a sliding guide. */

        subject mechanism : StraightLineGeneratingMechanism;

        require constraint {
            mechanism.linkage.couplerPoint.straightnessError <= mechanism.linkage.maximumStraightLineError
        }
    }

    requirement def GeometricClosureRequirement {
        doc /* The rhombus links shall maintain equal nominal lengths so that the linkage preserves the Peaucellier inversion geometry during operation. */

        subject linkage : PeaucellierLipkinLinkage;

        require constraint {
            linkage.rhombusLinkAB.length == linkage.rhombusLinkBC.length and
            linkage.rhombusLinkBC.length == linkage.rhombusLinkCD.length and
            linkage.rhombusLinkCD.length == linkage.rhombusLinkDA.length
        }
    }

    requirement def TravelRequirement {
        doc /* The tracing point shall provide useful straight-line travel for the external guided load. */

        subject linkage : PeaucellierLipkinLinkage;

        require constraint {
            linkage.straightLineTravel >= 60.0
        }
    }

    requirement def ActuationRequirement {
        doc /* The actuator shall provide sufficient torque to move the linkage through its intended operating range under nominal load. */

        subject linkage : PeaucellierLipkinLinkage;

        require constraint {
            linkage.actuator.maximumTorque >= 2.0
        }
    }

    requirement def NoSlidingGuideRequirement {
        doc /* The straight-line output shall be generated by revolute-joint linkage geometry rather than by a prismatic sliding constraint. */

        subject mechanism : StraightLineGeneratingMechanism;
    }

    constraint def PeaucellierInversionConstraint {
        in radiusLength : LengthValue;
        in rhombusLength : LengthValue;
        in fixedPivotDistance : LengthValue;
        in outputError : LengthValue;

        radiusLength < rhombusLength and
        fixedPivotDistance > 0.0 and
        outputError <= 0.25
    }

    analysis def StraightnessAnalysis {
        subject linkage : PeaucellierLipkinLinkage;

        objective {
            minimize linkage.couplerPoint.straightnessError;
        }

        constraint PeaucellierInversionConstraint {
            radiusLength = linkage.radiusLinkLength;
            rhombusLength = linkage.rhombusLinkLength;
            fixedPivotDistance = linkage.fixedPivotSeparation;
            outputError = linkage.couplerPoint.straightnessError;
        }
    }

    part mechanism : StraightLineGeneratingMechanism;

    satisfy PrimaryFunctionRequirement by mechanism;
    satisfy GeometricClosureRequirement by mechanism.linkage;
    satisfy TravelRequirement by mechanism.linkage;
    satisfy ActuationRequirement by mechanism.linkage;
    satisfy NoSlidingGuideRequirement by mechanism;
}