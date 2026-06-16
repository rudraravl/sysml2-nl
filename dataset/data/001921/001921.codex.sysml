package MobileServicingSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def meterPerSecond :> ISQ::speed;
    attribute def newtonMeter :> ISQ::torque;
    attribute def degree :> ISQ::planeAngle;
    attribute def wattHour :> ISQ::energy;

    item def ElectricalPower {
        attribute voltage : ISQ::electricPotential;
        attribute current : ISQ::electricCurrent;
        attribute power : ISQ::power;
    }

    item def CommandPacket {
        attribute sequenceId : Integer;
        attribute modeCommand : String;
        attribute targetPoseId : String;
        attribute emergencyStop : Boolean;
    }

    item def TelemetryPacket {
        attribute systemMode : String;
        attribute jointAngles[7] : degree;
        attribute endEffectorLoad : ISQ::mass;
        attribute powerDraw : ISQ::power;
        attribute faultCode : String;
    }

    item def VideoFrame {
        attribute frameRate : ISQ::frequency;
        attribute resolutionWidth : Integer;
        attribute resolutionHeight : Integer;
    }

    item def ForceTorqueVector {
        attribute forceX : ISQ::force;
        attribute forceY : ISQ::force;
        attribute forceZ : ISQ::force;
        attribute torqueX : newtonMeter;
        attribute torqueY : newtonMeter;
        attribute torqueZ : newtonMeter;
    }

    item def Payload {
        attribute payloadId : String;
        attribute mass : ISQ::mass;
        attribute grappleFixtureCompatible : Boolean;
        attribute maxHandlingForce : ISQ::force;
    }

    port def PowerPort {
        in item powerIn : ElectricalPower;
        out item powerStatus : TelemetryPacket;
    }

    port def DataPort {
        in item command : CommandPacket;
        out item telemetry : TelemetryPacket;
    }

    port def VideoPort {
        out item video : VideoFrame;
    }

    port def MechanicalGrapplePort {
        inout item handledPayload : Payload;
        out item contactLoads : ForceTorqueVector;
    }

    port def StructuralMountPort {
        out item reactionLoads : ForceTorqueVector;
    }

    part def RoboticJoint {
        attribute jointAngle : degree;
        attribute angularRate : ISQ::angularVelocity;
        attribute torqueOutput : newtonMeter;
        attribute locked : Boolean;

        port power : PowerPort;
        port data : DataPort;

        action def RotateToAngle {
            in targetAngle : degree;
            in maxRate : ISQ::angularVelocity;
            out achievedAngle : degree;
        }

        state def JointStateMachine {
            state off;
            state unlocked;
            state moving;
            state holding;
            state lockedState;
            state faulted;

            transition first off then unlocked;
            transition unlocked then moving
                accept CommandPacket
                if command.modeCommand == "MOVE";
            transition moving then holding
                if abs(jointAngle - targetAngle) < 0.1 [degree];
            transition holding then lockedState
                accept CommandPacket
                if command.modeCommand == "LOCK";
            transition lockedState then unlocked
                accept CommandPacket
                if command.modeCommand == "UNLOCK";
            transition unlocked then faulted
                if torqueOutput > 750 [newtonMeter];
            transition moving then faulted
                if torqueOutput > 750 [newtonMeter];
        }
    }

    part def LatchingEndEffector {
        attribute latchClosed : Boolean;
        attribute snareTension : ISQ::force;
        attribute capturedPayloadMass : ISQ::mass;

        port grapple : MechanicalGrapplePort;
        port power : PowerPort;
        port data : DataPort;
        port cameraVideo : VideoPort;

        action def CapturePayload {
            in candidatePayload : Payload;
            out captureConfirmed : Boolean;
        }

        action def ReleasePayload {
            out releaseConfirmed : Boolean;
        }

        state def LatchStateMachine {
            state open;
            state aligning;
            state capturing;
            state captured;
            state releasing;
            state safed;

            transition first open then aligning
                accept CommandPacket
                if command.modeCommand == "ALIGN_TO_GRAPPLE_FIXTURE";
            transition aligning then capturing
                if candidatePayload.grappleFixtureCompatible == true;
            transition capturing then captured
                if latchClosed == true and snareTension >= 1200 [N];
            transition captured then releasing
                accept CommandPacket
                if command.modeCommand == "RELEASE";
            transition releasing then open
                if latchClosed == false;
            transition captured then safed
                accept CommandPacket
                if command.emergencyStop == true;
        }
    }

    part def CameraAndLightingAssembly {
        attribute illuminationPower : ISQ::power;
        attribute cameraTemperature : ISQ::thermodynamicTemperature;
        attribute operational : Boolean;

        port power : PowerPort;
        port data : DataPort;
        port video : VideoPort;

        action def AcquireInspectionVideo {
            out imageStream : VideoFrame;
        }
    }

    part def MobileBaseTransporter {
        attribute railPosition : ISQ::length;
        attribute translationRate : meterPerSecond;
        attribute brakeEngaged : Boolean;

        port power : PowerPort;
        port data : DataPort;
        port structure : StructuralMountPort;

        action def TranslateAlongTruss {
            in destinationPosition : ISQ::length;
            out finalPosition : ISQ::length;
        }

        state def TransporterStateMachine {
            state parked;
            state translating;
            state braked;
            state inhibited;

            transition first parked then braked;
            transition braked then translating
                accept CommandPacket
                if command.modeCommand == "TRANSLATE";
            transition translating then braked
                if abs(railPosition - destinationPosition) < 0.02 [m];
            transition translating then inhibited
                accept CommandPacket
                if command.emergencyStop == true;
            transition inhibited then braked
                accept CommandPacket
                if command.modeCommand == "RESET";
        }
    }

    part def ControlComputer {
        attribute processorLoad : Real;
        attribute commandValid : Boolean;
        attribute autonomousSafingEnabled : Boolean;

        port crewData : DataPort;
        port groundData : DataPort;
        port armData : DataPort;
        port baseData : DataPort;
        port power : PowerPort;

        action def ValidateCommand {
            in rawCommand : CommandPacket;
            out acceptedCommand : CommandPacket;
            out valid : Boolean;
        }

        action def GenerateMotionPlan {
            in targetPoseId : String;
            in payloadMass : ISQ::mass;
            out jointTargets[7] : degree;
        }

        action def PublishTelemetry {
            out status : TelemetryPacket;
        }

        state def ControlStateMachine {
            state initialization;
            state standby;
            state planning;
            state executing;
            state monitoring;
            state safing;
            state faultRecovery;

            transition first initialization then standby;
            transition standby then planning
                accept CommandPacket
                if commandValid == true and command.modeCommand == "PLAN";
            transition planning then executing
                if commandValid == true;
            transition executing then monitoring;
            transition monitoring then standby
                if systemMode == "TASK_COMPLETE";
            transition executing then safing
                accept CommandPacket
                if command.emergencyStop == true;
            transition monitoring then safing
                if autonomousSafingEnabled == true and faultCode != "NONE";
            transition safing then faultRecovery
                accept CommandPacket
                if command.modeCommand == "RECOVER";
            transition faultRecovery then standby
                if faultCode == "NONE";
        }
    }

    part def PowerDistributionUnit {
        attribute busVoltage : ISQ::electricPotential;
        attribute availablePower : ISQ::power;
        attribute storedEnergy : wattHour;
        attribute overCurrentTrip : Boolean;

        port stationPower : PowerPort;
        port armPower : PowerPort;
        port basePower : PowerPort;
        port avionicsPower : PowerPort;
    }

    part def SpaceStationInterface {
        attribute structuralAttachPointId : String;
        attribute powerAvailable : ISQ::power;
        attribute commandLinkAvailable : Boolean;

        port powerSupply : PowerPort;
        port commandLink : DataPort;
        port structure : StructuralMountPort;
    }

    part def MobileServicingSystem {
        attribute primaryFunction : String = "Provide remotely operated and semi-autonomous mobile robotic manipulation for external spacecraft assembly, maintenance, payload handling, inspection, and berthing support.";
        attribute maximumPayloadMass : ISQ::mass = 116000 [kg];
        attribute nominalBusVoltage : ISQ::electricPotential = 120 [V];
        attribute standbyPower : ISQ::power = 1200 [W];
        attribute peakOperatingPower : ISQ::power = 6500 [W];
        attribute armReach : ISQ::length = 17.6 [m];

        port stationPower : PowerPort;
        port crewCommandData : DataPort;
        port groundCommandData : DataPort;
        port payloadInterface : MechanicalGrapplePort;
        port stationStructure : StructuralMountPort;
        port inspectionVideo : VideoPort;

        part stationInterface : SpaceStationInterface;
        part powerDistribution : PowerDistributionUnit;
        part controlComputer : ControlComputer;
        part mobileBase : MobileBaseTransporter;

        part shoulderYaw : RoboticJoint;
        part shoulderPitch : RoboticJoint;
        part elbowPitch : RoboticJoint;
        part wristPitch : RoboticJoint;
        part wristYaw : RoboticJoint;
        part wristRoll : RoboticJoint;
        part baseJoint : RoboticJoint;

        part endEffectorA : LatchingEndEffector;
        part endEffectorB : LatchingEndEffector;
        part cameraLightingA : CameraAndLightingAssembly;
        part cameraLightingB : CameraAndLightingAssembly;

        connect stationPower to stationInterface.powerSupply;
        connect crewCommandData to stationInterface.commandLink;
        connect stationStructure to stationInterface.structure;

        connect stationInterface.powerSupply to powerDistribution.stationPower;
        connect powerDistribution.avionicsPower to controlComputer.power;
        connect powerDistribution.basePower to mobileBase.power;
        connect powerDistribution.armPower to shoulderYaw.power;
        connect powerDistribution.armPower to shoulderPitch.power;
        connect powerDistribution.armPower to elbowPitch.power;
        connect powerDistribution.armPower to wristPitch.power;
        connect powerDistribution.armPower to wristYaw.power;
        connect powerDistribution.armPower to wristRoll.power;
        connect powerDistribution.armPower to baseJoint.power;
        connect powerDistribution.armPower to endEffectorA.power;
        connect powerDistribution.armPower to endEffectorB.power;
        connect powerDistribution.armPower to cameraLightingA.power;
        connect powerDistribution.armPower to cameraLightingB.power;

        connect stationInterface.commandLink to controlComputer.crewData;
        connect groundCommandData to controlComputer.groundData;
        connect controlComputer.baseData to mobileBase.data;
        connect controlComputer.armData to shoulderYaw.data;
        connect controlComputer.armData to shoulderPitch.data;
        connect controlComputer.armData to elbowPitch.data;
        connect controlComputer.armData to wristPitch.data;
        connect controlComputer.armData to wristYaw.data;
        connect controlComputer.armData to wristRoll.data;
        connect controlComputer.armData to baseJoint.data;
        connect controlComputer.armData to endEffectorA.data;
        connect controlComputer.armData to endEffectorB.data;
        connect controlComputer.armData to cameraLightingA.data;
        connect controlComputer.armData to cameraLightingB.data;

        connect mobileBase.structure to stationStructure;
        connect endEffectorA.grapple to payloadInterface;
        connect cameraLightingA.video to inspectionVideo;
        connect cameraLightingB.video to inspectionVideo;

        action def PerformServicingOperation {
            in selectedPayload : Payload;
            in serviceLocation : ISQ::length;
            out operationComplete : Boolean;

            first start;
            then validateCommand;
            then moveBase;
            then positionArm;
            then capturePayload;
            then manipulatePayload;
            then inspectWorksite;
            then releaseOrHoldPayload;
            then publishCompletion;

            action validateCommand : ControlComputer::ValidateCommand;
            action moveBase : MobileBaseTransporter::TranslateAlongTruss;
            action positionArm : ControlComputer::GenerateMotionPlan;
            action capturePayload : LatchingEndEffector::CapturePayload;
            action manipulatePayload;
            action inspectWorksite : CameraAndLightingAssembly::AcquireInspectionVideo;
            action releaseOrHoldPayload;
            action publishCompletion : ControlComputer::PublishTelemetry;

            flow selectedPayload to capturePayload.candidatePayload;
            flow serviceLocation to moveBase.destinationPosition;
            flow capturePayload.captureConfirmed to manipulatePayload;
            flow inspectWorksite.imageStream to publishCompletion;
        }

        state def SystemOperationalStateMachine {
            state unpowered;
            state initialization;
            state standby;
            state mobileRepositioning;
            state armPositioning;
            state payloadCapture;
            state payloadManipulation;
            state inspection;
            state payloadRelease;
            state safed;
            state faulted;

            transition first unpowered then initialization
                if powerDistribution.busVoltage >= 100 [V];

            transition initialization then standby
                if controlComputer.commandValid == true;

            transition standby then mobileRepositioning
                accept CommandPacket
                if command.modeCommand == "REPOSITION_BASE";

            transition mobileRepositioning then armPositioning
                if mobileBase.brakeEngaged == true;

            transition standby then armPositioning
                accept CommandPacket
                if command.modeCommand == "POSITION_ARM";

            transition armPositioning then payloadCapture
                accept CommandPacket
                if command.modeCommand == "CAPTURE_PAYLOAD";

            transition payloadCapture then payloadManipulation
                if endEffectorA.latchClosed == true or endEffectorB.latchClosed == true;

            transition payloadManipulation then inspection
                accept CommandPacket
                if command.modeCommand == "INSPECT";

            transition inspection then payloadRelease
                accept CommandPacket
                if command.modeCommand == "RELEASE_PAYLOAD";

            transition payloadRelease then standby
                if endEffectorA.latchClosed == false and endEffectorB.latchClosed == false;

            transition standby then safed
                accept CommandPacket
                if command.emergencyStop == true;

            transition mobileRepositioning then safed
                accept CommandPacket
                if command.emergencyStop == true;

            transition armPositioning then safed
                accept CommandPacket
                if command.emergencyStop == true;

            transition payloadManipulation then safed
                accept CommandPacket
                if command.emergencyStop == true;

            transition initialization then faulted
                if powerDistribution.overCurrentTrip == true;

            transition payloadManipulation then faulted
                if payloadInterface.contactLoads.forceZ > selectedPayload.maxHandlingForce;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Mobile Servicing System shall provide mobile robotic servicing capability for external space station operations, including positioning, grappling, moving, inspecting, and releasing compatible payloads under crew, ground, or supervised autonomous control. */
        subject mss : MobileServicingSystem;

        require constraint {
            mss.armReach >= 17 [m] and
            mss.maximumPayloadMass >= 100000 [kg] and
            mss.peakOperatingPower <= 7000 [W]
        }
    }

    requirement def CommandAndTelemetryRequirement {
        doc /* The Mobile Servicing System shall accept command packets from crew and ground interfaces and shall return telemetry indicating mode, joint state, load state, power state, and fault state. */
        subject mss : MobileServicingSystem;

        require constraint {
            mss.controlComputer.commandValid == true implies
            mss.stationInterface.commandLinkAvailable == true
        }
    }

    requirement def PayloadHandlingRequirement {
        doc /* The Mobile Servicing System shall capture only payloads with compatible grapple fixtures and shall limit contact loads during payload manipulation. */
        subject payload : Payload;
        subject mss : MobileServicingSystem;

        require constraint {
            payload.grappleFixtureCompatible == true and
            payload.mass <= mss.maximumPayloadMass
        }
    }

    requirement def EmergencySafingRequirement {
        doc /* The Mobile Servicing System shall transition to a safed state when an emergency stop command is received during powered operation. */
        subject command : CommandPacket;
        subject mss : MobileServicingSystem;

        require constraint {
            command.emergencyStop == true implies
            mss.controlComputer.autonomousSafingEnabled == true
        }
    }

    requirement def PowerRequirement {
        doc /* The Mobile Servicing System shall operate from the station power bus within nominal voltage limits and shall inhibit motion during over-current conditions. */
        subject mss : MobileServicingSystem;

        require constraint {
            mss.powerDistribution.busVoltage >= 100 [V] and
            mss.powerDistribution.busVoltage <= 140 [V] and
            mss.powerDistribution.overCurrentTrip == false
        }
    }

    satisfy PrimaryFunctionRequirement by MobileServicingSystem;
    satisfy CommandAndTelemetryRequirement by MobileServicingSystem::controlComputer;
    satisfy PayloadHandlingRequirement by MobileServicingSystem::endEffectorA;
    satisfy PayloadHandlingRequirement by MobileServicingSystem::endEffectorB;
    satisfy EmergencySafingRequirement by MobileServicingSystem::SystemOperationalStateMachine;
    satisfy PowerRequirement by MobileServicingSystem::powerDistribution;

    part issMobileServicingSystem : MobileServicingSystem {
        attribute primaryFunction =
            "High-level function: move along the orbital outpost structure, position a multi-joint robotic arm, grapple compatible payloads or visiting vehicles, manipulate them with controlled loads, provide visual inspection, and report command and health telemetry to crew and ground controllers.";

        attribute maximumPayloadMass = 116000 [kg];
        attribute nominalBusVoltage = 120 [V];
        attribute standbyPower = 1200 [W];
        attribute peakOperatingPower = 6500 [W];
        attribute armReach = 17.6 [m];

        part powerDistribution {
            attribute busVoltage = 120 [V];
            attribute availablePower = 7000 [W];
            attribute storedEnergy = 0 [wattHour];
            attribute overCurrentTrip = false;
        }

        part mobileBase {
            attribute railPosition = 0 [m];
            attribute translationRate = 0.025 [m/s];
            attribute brakeEngaged = true;
        }

        part endEffectorA {
            attribute latchClosed = false;
            attribute snareTension = 0 [N];
            attribute capturedPayloadMass = 0 [kg];
        }

        part endEffectorB {
            attribute latchClosed = false;
            attribute snareTension = 0 [N];
            attribute capturedPayloadMass = 0 [kg];
        }
    }
}