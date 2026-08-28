package SoftRoboticGripper {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    value def PressureValue :> Real { unit 'Pa'; }
    value def ForceValue :> Real { unit 'N'; }
    value def ComplianceValue :> Real { unit 'N/m'; }
    value def VolumeFlowRate :> Real { unit 'm3/s'; }
    value def BendAngle :> Real { unit 'deg'; }

    // ---- Item Types ----
    item def CompressedAir;
    item def GripCommand {
        attribute desiredForce : ForceValue;
        attribute desiredCompliance : ComplianceValue;
    }
    item def ReleaseCommand;
    item def ForceFeedback {
        attribute measuredForce : ForceValue;
    }
    item def PressureCommand {
        attribute targetPressure : PressureValue;
    }

    // ---- Port Definitions ----
    port def AirPort {
        out item air : CompressedAir;
        attribute pressure : PressureValue;
    }
    port def CommandPort {
        in item gripCmd : GripCommand;
        in item releaseCmd : ReleaseCommand;
    }
    port def PressureCmdPort {
        out item cmd : PressureCommand;
    }
    port def FeedbackPort {
        in item feedback : ForceFeedback;
    }

    // ---- Requirements ----
    requirement def SafeHandlingRequirement {
        attribute maxGripForce : ForceValue = 5.0;
        doc /* The gripper shall not exceed the maximum grip force to avoid damaging delicate objects. */
    }

    requirement def IndependentFingerControlRequirement {
        doc /* Each finger shall be independently controllable in pressure and flow. */
    }

    requirement def AdaptiveComplianceRequirement {
        doc /* The system shall adjust grip force based on real-time feedback to maintain commanded compliance. */
    }

    requirement def StateOperationRequirement {
        doc /* The system shall operate in idle, grasping, and releasing states. */
    }

    // ---- Part Definitions ----

    part def AirCompressor {
        port out supply : AirPort;
        attribute maxPressure : PressureValue = 700000.0;
        attribute flowRate : VolumeFlowRate = 0.001;
        action def GenerateAir {
            out generatedAir : CompressedAir;
        }
        perform GenerateAir;
    }

    part def PressureRegulator {
        port in inlet : AirPort;
        port out outlets : AirPort[3];
        port in cmd : PressureCmdPort;
        attribute regulatedPressure : PressureValue[3];
        action def Regulate {
            in cmd : PressureCommand;
            in inletAir : CompressedAir;
            out outletAir : CompressedAir[3];
        }
        perform Regulate;
    }

    part def ForceSensor {
        port out feedback : FeedbackPort;
        attribute measuredForce : ForceValue;
        action def Sense {
            out reading : ForceFeedback;
        }
        perform Sense;
    }

    part def SoftPneumaticActuator {
        port in airIn : AirPort;
        port out sensorOut : FeedbackPort;
        attribute currentPressure : PressureValue;
        attribute bendAngle : BendAngle;
        attribute material : String = "silicone elastomer";
        part sensor : ForceSensor;
        action def Inflate {
            in air : CompressedAir;
            out feedback : ForceFeedback;
        }
        action def Deflate {
            out releasedAir : CompressedAir;
        }
        perform Inflate;
    }

    part def ControlUnit {
        port in command : CommandPort;
        port out pressureCmds : PressureCmdPort[3];
        port in feedbacks : FeedbackPort[3];
        attribute currentForce : ForceValue[3];
        attribute targetForce : ForceValue;
        attribute targetCompliance : ComplianceValue;

        state def ControlStateMachine {
            state idle;
            state grasping;
            state releasing;

            transition idle_to_grasping first idle if command.gripCmd != null then grasping;
            transition grasping_to_releasing grasping if command.releaseCmd != null then releasing;
            transition releasing_to_idle releasing if true then idle;
        }

        perform ControlStateMachine;

        action def ComputePressureCommands {
            in targetForce : ForceValue;
            in targetCompliance : ComplianceValue;
            in measuredForces : ForceValue[3];
            out commands : PressureCommand[3];
        }
    }

    part def SoftRoboticGripperSystem {
        part compressor : AirCompressor;
        part regulator : PressureRegulator;
        part controller : ControlUnit;
        part fingers : SoftPneumaticActuator[3];

        satisfy SafeHandlingRequirement;
        satisfy IndependentFingerControlRequirement;
        satisfy AdaptiveComplianceRequirement;
        satisfy StateOperationRequirement;

        connection compressor.supply to regulator.inlet;
        connection regulator.outlets to fingers.airIn;
        connection controller.pressureCmds to regulator.cmd;
        connection fingers.sensorOut to controller.feedbacks;
    }

    part gripperSystem : SoftRoboticGripperSystem;

}
