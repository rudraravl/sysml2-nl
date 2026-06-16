package DextreBasedOrbitalServicer {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MassValue :> ISQ::mass {
        unit = SI::kilogram;
    }

    attribute def LengthValue :> ISQ::length {
        unit = SI::meter;
    }

    attribute def ForceValue :> ISQ::force {
        unit = SI::newton;
    }

    attribute def TorqueValue :> ISQ::torque {
        unit = SI::newtonMeter;
    }

    attribute def PowerValue :> ISQ::power {
        unit = SI::watt;
    }

    attribute def VoltageValue :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def DataRateValue {
        unit = "megabit/s";
    }

    attribute def AngleValue :> ISQ::planeAngle {
        unit = SI::degree;
    }

    attribute def TimeValue :> ISQ::time {
        unit = SI::second;
    }

    item def CommandPacket {
        attribute commandId : Integer;
        attribute priority : Integer;
        attribute issueTime : TimeValue;
    }

    item def TelemetryPacket {
        attribute sourceId : Integer;
        attribute healthCode : Integer;
        attribute timestamp : TimeValue;
        attribute dataRate : DataRateValue;
    }

    item def VideoFrame {
        attribute frameId : Integer;
        attribute timestamp : TimeValue;
        attribute resolutionWidth : Integer;
        attribute resolutionHeight : Integer;
    }

    item def PowerFlow {
        attribute voltage : VoltageValue;
        attribute availablePower : PowerValue;
    }

    item def ToolExchangeLoad {
        attribute mass : MassValue;
        attribute requiredTorque : TorqueValue;
        attribute captureForce : ForceValue;
    }

    item def OrbitalReplacementUnit {
        attribute mass : MassValue;
        attribute envelopeLength : LengthValue;
        attribute graspFixtureDiameter : LengthValue;
        attribute safeToHandle : Boolean;
    }

    port def PowerPort {
        in item powerIn : PowerFlow;
        out item powerStatus : TelemetryPacket;
    }

    port def DataPort {
        in item command : CommandPacket;
        out item telemetry : TelemetryPacket;
    }

    port def VideoPort {
        out item video : VideoFrame;
    }

    port def ToolPort {
        inout item toolLoad : ToolExchangeLoad;
    }

    port def GrapplePort {
        inout item handledUnit : OrbitalReplacementUnit;
    }

    port def StructuralPort {
        inout item mechanicalLoad : ToolExchangeLoad;
    }

    part def RoboticArm {
        attribute length : LengthValue;
        attribute mass : MassValue;
        attribute maxTipForce : ForceValue;
        attribute maxJointTorque : TorqueValue;
        attribute shoulderYaw : AngleValue;
        attribute shoulderPitch : AngleValue;
        attribute elbowPitch : AngleValue;
        attribute wristPitch : AngleValue;
        attribute wristYaw : AngleValue;
        attribute wristRoll : AngleValue;

        port power : PowerPort;
        port data : DataPort;
        port endEffector : GrapplePort;
        port toolInterface : ToolPort;

        action moveToPregrasp {
            in targetRange : LengthValue;
            in approachAngle : AngleValue;
            out aligned : Boolean;
        }

        action captureFixture {
            in fixtureDiameter : LengthValue;
            out captured : Boolean;
        }

        action applyServiceTorque {
            in commandedTorque : TorqueValue;
            out torqueApplied : TorqueValue;
        }
    }

    part def DexterousTool {
        attribute mass : MassValue;
        attribute ratedTorque : TorqueValue;
        attribute ratedForce : ForceValue;
        attribute powerDemand : PowerValue;

        port power : PowerPort;
        port data : DataPort;
        port toolMount : ToolPort;

        action fastenBolt {
            in torqueSetpoint : TorqueValue;
            out achievedTorque : TorqueValue;
            out complete : Boolean;
        }

        action releaseConnector {
            out released : Boolean;
        }
    }

    part def VisionSensorSuite {
        attribute mass : MassValue;
        attribute powerDemand : PowerValue;
        attribute fieldOfView : AngleValue;
        attribute minimumFocusDistance : LengthValue;

        port power : PowerPort;
        port data : DataPort;
        port video : VideoPort;

        action estimatePose {
            in targetRange : LengthValue;
            out relativeBearing : AngleValue;
            out relativeDistance : LengthValue;
            out valid : Boolean;
        }
    }

    part def ForceTorqueSensor {
        attribute mass : MassValue;
        attribute forceRange : ForceValue;
        attribute torqueRange : TorqueValue;
        attribute sampleRate {
            unit = "Hz";
        }

        port power : PowerPort;
        port data : DataPort;

        action measureContactLoad {
            out sensedForce : ForceValue;
            out sensedTorque : TorqueValue;
            out overload : Boolean;
        }
    }

    part def AvionicsController {
        attribute mass : MassValue;
        attribute powerDemand : PowerValue;
        attribute commandProcessingRate {
            unit = "command/s";
        }

        port power : PowerPort;
        port groundData : DataPort;
        port armData : DataPort;
        port toolData : DataPort;
        port visionData : DataPort;
        port sensorData : DataPort;

        action validateCommand {
            in command : CommandPacket;
            out accepted : Boolean;
        }

        action planServicingMotion {
            in targetDistance : LengthValue;
            in targetBearing : AngleValue;
            out motionReady : Boolean;
        }

        action generateTelemetry {
            out telemetry : TelemetryPacket;
        }
    }

    part def PowerConditioningUnit {
        attribute mass : MassValue;
        attribute inputVoltage : VoltageValue;
        attribute regulatedVoltage : VoltageValue;
        attribute continuousPower : PowerValue;
        attribute peakPower : PowerValue;

        port stationPower : PowerPort;
        port avionicsPower : PowerPort;
        port leftArmPower : PowerPort;
        port rightArmPower : PowerPort;
        port toolPower : PowerPort;
        port visionPower : PowerPort;
        port sensorPower : PowerPort;
    }

    part def OrbitalWorksiteInterface {
        attribute mass : MassValue;
        attribute mountingStiffness {
            unit = "N/m";
        }
        attribute allowableMoment : TorqueValue;

        port structure : StructuralPort;
        port power : PowerPort;
        port data : DataPort;
    }

    part def ServicingTarget {
        attribute targetMass : MassValue;
        attribute serviceEnvelopeLength : LengthValue;
        attribute hasStandardGrappleFixture : Boolean;

        port grappleFixture : GrapplePort;
        port serviceConnector : ToolPort;
    }

    state def ServicingStateMachine {
        entry action initializeController;
        state Standby;
        state ReceiveTask;
        state InspectTarget;
        state ApproachTarget;
        state CaptureTarget;
        state ServiceTarget;
        state ReleaseTarget;
        state ReportCompletion;
        state SafeHold;

        transition first Standby;
        transition Standby_to_ReceiveTask
            first Standby then ReceiveTask
            accept CommandPacket;

        transition ReceiveTask_to_InspectTarget
            first ReceiveTask then InspectTarget;

        transition InspectTarget_to_ApproachTarget
            first InspectTarget then ApproachTarget
            if poseValid;

        transition InspectTarget_to_SafeHold
            first InspectTarget then SafeHold
            if not poseValid;

        transition ApproachTarget_to_CaptureTarget
            first ApproachTarget then CaptureTarget
            if alignmentConfirmed;

        transition CaptureTarget_to_ServiceTarget
            first CaptureTarget then ServiceTarget
            if targetCaptured;

        transition ServiceTarget_to_ReleaseTarget
            first ServiceTarget then ReleaseTarget
            if serviceComplete;

        transition ReleaseTarget_to_ReportCompletion
            first ReleaseTarget then ReportCompletion
            if targetReleased;

        transition ReportCompletion_to_Standby
            first ReportCompletion then Standby;

        transition Any_to_SafeHold
            first Standby then SafeHold
            accept faultDetected;
    }

    action def PerformOrbitalServicing {
        in taskCommand : CommandPacket;
        in serviceUnit : OrbitalReplacementUnit;
        out completionTelemetry : TelemetryPacket;

        action receiveAndValidateCommand;
        action inspectTargetPose;
        action planDualArmMotion;
        action grappleServiceUnit;
        action removeOrInstallUnit;
        action verifyMechanicalClosure;
        action releaseAndBackAway;
        action transmitCompletionStatus;

        flow receiveAndValidateCommand then inspectTargetPose;
        flow inspectTargetPose then planDualArmMotion;
        flow planDualArmMotion then grappleServiceUnit;
        flow grappleServiceUnit then removeOrInstallUnit;
        flow removeOrInstallUnit then verifyMechanicalClosure;
        flow verifyMechanicalClosure then releaseAndBackAway;
        flow releaseAndBackAway then transmitCompletionStatus;
    }

    part def DextreBasedServicingSystem {
        attribute totalMass : MassValue = 1720 [SI::kilogram];
        attribute nominalPower : PowerValue = 2100 [SI::watt];
        attribute peakPower : PowerValue = 3200 [SI::watt];
        attribute primaryFunction : String = "Perform precise teleoperated and supervised autonomous manipulation of orbital replacement units, tools, and service connectors on spacecraft exterior worksites.";

        port stationPowerInput : PowerPort;
        port stationCommandLink : DataPort;
        port stationVideoDownlink : VideoPort;
        port worksiteMount : StructuralPort;
        port targetGrappleInterface : GrapplePort;
        port targetServiceInterface : ToolPort;

        part baseInterface : OrbitalWorksiteInterface {
            attribute mass = 180 [SI::kilogram];
            attribute allowableMoment = 2400 [SI::newtonMeter];
        }

        part powerUnit : PowerConditioningUnit {
            attribute mass = 95 [SI::kilogram];
            attribute inputVoltage = 120 [SI::volt];
            attribute regulatedVoltage = 48 [SI::volt];
            attribute continuousPower = 2500 [SI::watt];
            attribute peakPower = 3500 [SI::watt];
        }

        part controller : AvionicsController {
            attribute mass = 70 [SI::kilogram];
            attribute powerDemand = 260 [SI::watt];
            attribute commandProcessingRate = 25;
        }

        part leftArm : RoboticArm {
            attribute length = 3.5 [SI::meter];
            attribute mass = 390 [SI::kilogram];
            attribute maxTipForce = 220 [SI::newton];
            attribute maxJointTorque = 680 [SI::newtonMeter];
        }

        part rightArm : RoboticArm {
            attribute length = 3.5 [SI::meter];
            attribute mass = 390 [SI::kilogram];
            attribute maxTipForce = 220 [SI::newton];
            attribute maxJointTorque = 680 [SI::newtonMeter];
        }

        part cameraSuite : VisionSensorSuite {
            attribute mass = 48 [SI::kilogram];
            attribute powerDemand = 180 [SI::watt];
            attribute fieldOfView = 70 [SI::degree];
            attribute minimumFocusDistance = 0.45 [SI::meter];
        }

        part wristLoadSensor : ForceTorqueSensor {
            attribute mass = 18 [SI::kilogram];
            attribute forceRange = 500 [SI::newton];
            attribute torqueRange = 900 [SI::newtonMeter];
            attribute sampleRate = 1000;
        }

        part orbitalTool : DexterousTool {
            attribute mass = 55 [SI::kilogram];
            attribute ratedTorque = 420 [SI::newtonMeter];
            attribute ratedForce = 300 [SI::newton];
            attribute powerDemand = 420 [SI::watt];
        }

        part serviceTarget : ServicingTarget {
            attribute targetMass = 620 [SI::kilogram];
            attribute serviceEnvelopeLength = 1.8 [SI::meter];
            attribute hasStandardGrappleFixture = true;
        }

        connect stationPowerInput to powerUnit.stationPower;
        connect stationCommandLink to controller.groundData;
        connect stationVideoDownlink to cameraSuite.video;
        connect worksiteMount to baseInterface.structure;

        connect powerUnit.avionicsPower to controller.power;
        connect powerUnit.leftArmPower to leftArm.power;
        connect powerUnit.rightArmPower to rightArm.power;
        connect powerUnit.toolPower to orbitalTool.power;
        connect powerUnit.visionPower to cameraSuite.power;
        connect powerUnit.sensorPower to wristLoadSensor.power;

        connect controller.armData to leftArm.data;
        connect controller.armData to rightArm.data;
        connect controller.toolData to orbitalTool.data;
        connect controller.visionData to cameraSuite.data;
        connect controller.sensorData to wristLoadSensor.data;

        connect leftArm.toolInterface to orbitalTool.toolMount;
        connect rightArm.endEffector to serviceTarget.grappleFixture;
        connect targetGrappleInterface to serviceTarget.grappleFixture;
        connect targetServiceInterface to serviceTarget.serviceConnector;
        connect orbitalTool.toolMount to serviceTarget.serviceConnector;

        perform action servicingMission : PerformOrbitalServicing;

        exhibit state servicingState : ServicingStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : DextreBasedServicingSystem;
        require constraint {
            system.primaryFunction == "Perform precise teleoperated and supervised autonomous manipulation of orbital replacement units, tools, and service connectors on spacecraft exterior worksites."
        }
    }

    requirement def ManipulationReachRequirement {
        subject system : DextreBasedServicingSystem;
        require constraint {
            system.leftArm.length >= 3.0 [SI::meter] and
            system.rightArm.length >= 3.0 [SI::meter]
        }
    }

    requirement def PayloadHandlingRequirement {
        subject system : DextreBasedServicingSystem;
        require constraint {
            system.leftArm.maxTipForce >= 200 [SI::newton] and
            system.rightArm.maxTipForce >= 200 [SI::newton] and
            system.serviceTarget.targetMass <= 700 [SI::kilogram]
        }
    }

    requirement def ToolTorqueRequirement {
        subject system : DextreBasedServicingSystem;
        require constraint {
            system.orbitalTool.ratedTorque >= 400 [SI::newtonMeter]
        }
    }

    requirement def PowerRequirement {
        subject system : DextreBasedServicingSystem;
        require constraint {
            system.powerUnit.continuousPower >= system.nominalPower and
            system.powerUnit.peakPower >= system.peakPower
        }
    }

    requirement def VisionRequirement {
        subject system : DextreBasedServicingSystem;
        require constraint {
            system.cameraSuite.minimumFocusDistance <= 0.5 [SI::meter] and
            system.cameraSuite.fieldOfView >= 60 [SI::degree]
        }
    }

    requirement def SafeHoldRequirement {
        subject system : DextreBasedServicingSystem;
        require constraint {
            system.wristLoadSensor.forceRange >= 2.0 * system.leftArm.maxTipForce
        }
    }

    requirement def TeleoperationRequirement {
        subject system : DextreBasedServicingSystem;
        require constraint {
            system.controller.commandProcessingRate >= 20
        }
    }

    satisfy PrimaryFunctionRequirement by DextreBasedServicingSystem;
    satisfy ManipulationReachRequirement by DextreBasedServicingSystem;
    satisfy PayloadHandlingRequirement by DextreBasedServicingSystem;
    satisfy ToolTorqueRequirement by DextreBasedServicingSystem;
    satisfy PowerRequirement by DextreBasedServicingSystem;
    satisfy VisionRequirement by DextreBasedServicingSystem;
    satisfy SafeHoldRequirement by DextreBasedServicingSystem;
    satisfy TeleoperationRequirement by DextreBasedServicingSystem;
}