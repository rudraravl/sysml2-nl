package 'Linkage System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def LinkageConfiguration;
    attribute def JointAngle :> ISQ::PlaneAngleValue;
    attribute def LinkLength :> ISQ::LengthValue;
    attribute def AngularVelocity :> ISQ::AngularSpeedValue;
    attribute def LinearDisplacement :> ISQ::LengthValue;
    attribute def InputCommand;
    attribute def StopCommand;

    attribute def MotionProfile {
        attribute amplitude : JointAngle;
        attribute frequency : Real;
        attribute phase : JointAngle;
    }

    item def RotaryInput {
        attribute angle : JointAngle;
        attribute velocity : AngularVelocity;
        attribute torque : ISQ::TorqueValue;
    }

    item def LinearOutput {
        attribute displacement : LinearDisplacement;
        attribute velocity : ISQ::SpeedValue;
        attribute force : ISQ::ForceValue;
    }

    port def RotaryPort {
        attribute angle : JointAngle;
        attribute torque : ISQ::TorqueValue;
    }

    port def LinearPort {
        attribute position : LinearDisplacement;
        attribute force : ISQ::ForceValue;
    }

    part def RotaryActuator {
        in command : InputCommand;
        out rotaryDrive : RotaryInput;
        attribute maxTorque : ISQ::TorqueValue;
        attribute maxSpeed : AngularVelocity;
        port outputPort : RotaryPort;
    }

    part def CrankLink {
        attribute length : LinkLength;
        attribute mass : ISQ::MassValue;
        port pivotPort : RotaryPort;
        port connectionPort : RotaryPort;
    }

    part def CouplerLink {
        attribute length : LinkLength;
        attribute mass : ISQ::MassValue;
        port crankConnection : RotaryPort;
        port rockerConnection : RotaryPort;
    }

    part def RockerLink {
        attribute length : LinkLength;
        attribute mass : ISQ::MassValue;
        port pivotPort : RotaryPort;
        port connectionPort : RotaryPort;
    }

    part def GroundFrame {
        attribute baseLength : LinkLength;
        port crankPivot : RotaryPort;
        port rockerPivot : RotaryPort;
    }

    part def OutputMechanism {
        in linearInput : LinearOutput;
        port inputPort : LinearPort;
        attribute outputDisplacement : LinearDisplacement;
    }

    action def ComputeLinkageKinematics {
        in crankAngle : JointAngle;
        in crankLength : LinkLength;
        in couplerLength : LinkLength;
        in rockerLength : LinkLength;
        in baseLength : LinkLength;
        out rockerAngle : JointAngle;
        out couplerAngle : JointAngle;
        out outputPosition : LinearDisplacement;
    }

    action def ApplyActuatorTorque {
        in commandedAngle : JointAngle;
        in currentAngle : JointAngle;
        in maxTorque : ISQ::TorqueValue;
        out appliedTorque : ISQ::TorqueValue;
    }

    action def TransmitForce {
        in inputTorque : ISQ::TorqueValue;
        in mechanicalAdvantage : Real;
        out outputForce : ISQ::ForceValue;
    }

    requirement def KinematicRequirement {
        doc /* The linkage shall convert continuous rotary motion into controlled linear reciprocating motion. */
    }

    requirement def WorkspaceRequirement {
        doc /* The linkage output shall operate within a defined linear stroke range. */
        attribute minStroke : LinearDisplacement;
        attribute maxStroke : LinearDisplacement;
        require constraint { minStroke >= 0.0 [SI::m] }
        require constraint { maxStroke <= 0.5 [SI::m] }
    }

    requirement def ForceTransmissionRequirement {
        doc /* The linkage shall transmit at least 80% of input torque as effective output force. */
        attribute minEfficiency : Real;
        require constraint { minEfficiency >= 0.80 }
    }

    requirement def SmoothOperationRequirement {
        doc /* The linkage shall operate smoothly without binding throughout its full range of motion. */
    }

    part def FourBarLinkageMechanism {
        doc /* A four-bar linkage mechanism consisting of crank, coupler, rocker, and ground links
               arranged to convert continuous rotary input motion into controlled reciprocating 
               linear output motion through geometric constraints. */

        attribute config : LinkageConfiguration;

        part actuator : RotaryActuator {
            attribute :>> maxTorque = 50.0 [SI::N * SI::m];
            attribute :>> maxSpeed = 10.0 [SI::rad / SI::s];
        }

        part ground : GroundFrame {
            attribute :>> baseLength = 0.30 [SI::m];
        }

        part crank : CrankLink {
            attribute :>> length = 0.08 [SI::m];
            attribute :>> mass = 0.5 [SI::kg];
        }

        part coupler : CouplerLink {
            attribute :>> length = 0.25 [SI::m];
            attribute :>> mass = 1.2 [SI::kg];
        }

        part rocker : RockerLink {
            attribute :>> length = 0.15 [SI::m];
            attribute :>> mass = 0.8 [SI::kg];
        }

        part output : OutputMechanism;

        connection actuatorToCrank connect 
            actuator.outputPort to crank.pivotPort;

        connection crankToGround connect 
            crank.pivotPort to ground.crankPivot;

        connection crankToCoupler connect 
            crank.connectionPort to coupler.crankConnection;

        connection couplerToRocker connect 
            coupler.rockerConnection to rocker.connectionPort;

        connection rockerToGround connect 
            rocker.pivotPort to ground.rockerPivot;

        connection rockerToOutput connect 
            rocker.connectionPort to output.inputPort;

        perform action operateLinkage : OperateLinkage;
    }

    action def OperateLinkage {
        in startCommand : InputCommand;
        in stopCommand : StopCommand;
        in attribute motionProfile : MotionProfile;
        in attribute crankLen : LinkLength;
        in attribute couplerLen : LinkLength;
        in attribute rockerLen : LinkLength;
        in attribute baseLen : LinkLength;
        out attribute outputPositions : LinearDisplacement[*] := ( );
        out attribute outputForces : ISQ::ForceValue[*] := ( );

        private attribute currentCrankAngle : JointAngle := 0.0 [SI::rad];
        private attribute angularIncrement : JointAngle := 0.1 [SI::rad];

        first start;
        then accept begin : InputCommand;
        then merge continueCycle;

        then action computeKinematics : ComputeLinkageKinematics {
            in crankAngle = currentCrankAngle;
            in crankLength = crankLen;
            in couplerLength = couplerLen;
            in rockerLength = rockerLen;
            in baseLength = baseLen;
            out rockerAngle : JointAngle;
            out couplerAngle : JointAngle;
            out outputPosition : LinearDisplacement;
        }

        then action applyTorque : ApplyActuatorTorque {
            in commandedAngle = currentCrankAngle + angularIncrement;
            in currentAngle = currentCrankAngle;
            in maxTorque = 50.0 [SI::N * SI::m];
            out appliedTorque : ISQ::TorqueValue;
        }

        then action transmitForce : TransmitForce {
            in inputTorque = applyTorque.appliedTorque;
            in mechanicalAdvantage = 2.5;
            out outputForce : ISQ::ForceValue;
        }

        then assign currentCrankAngle := currentCrankAngle + angularIncrement;
        then assign outputPositions := outputPositions#(outputPositions->size() + 1, computeKinematics.outputPosition);
        then assign outputForces := outputForces#(outputForces->size() + 1, transmitForce.outputForce);

        then decide;
            if currentCrankAngle >= 6.28 [SI::rad] then resetCycle;
            else continueCycle;

        action resetCycle {
            then assign currentCrankAngle := 0.0 [SI::rad];
        }
        then continueCycle;

        action continueCycle;
        then done;
    }

    part linkageSystem : FourBarLinkageMechanism;

    requirement linkageSystemRequirements {
        doc /* Top-level requirements for the four-bar linkage system to achieve reliable 
               motion conversion with specified performance characteristics. */

        subject linkageSystem;

        require req1 : KinematicRequirement;

        require req2 : WorkspaceRequirement {
            attribute :>> minStroke = 0.05 [SI::m];
            attribute :>> maxStroke = 0.40 [SI::m];
        }

        require req3 : ForceTransmissionRequirement {
            attribute :>> minEfficiency = 0.82;
        }

        require req4 : SmoothOperationRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Linkage System'::*;

    action orchestrator {
        attribute testCrankAngle : JointAngle;
        attribute testCrankLength : LinkLength;
        attribute testCouplerLength : LinkLength;
        attribute testRockerLength : LinkLength;
        attribute testBaseLength : LinkLength;
        action actionProbe : ComputeLinkageKinematics {
            in crankAngle = testCrankAngle;
            in crankLength = testCrankLength;
            in couplerLength = testCouplerLength;
            in rockerLength = testRockerLength;
            in baseLength = testBaseLength;
        }
        first actionProbe;
    }
}
