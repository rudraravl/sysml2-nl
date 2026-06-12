package FosterMillerBasedHazardResponseRobot {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent : Real {
        unit = "%";
    }

    attribute def BatteryStateOfCharge : Percent;
    attribute def Distance : Length;
    attribute def Speed : Real {
        unit = "m/s";
    }
    attribute def MassValue : Real {
        unit = "kg";
    }
    attribute def VoltageValue : Real {
        unit = "V";
    }
    attribute def CurrentValue : Real {
        unit = "A";
    }
    attribute def TemperatureValue : Real {
        unit = "degC";
    }
    attribute def DataRate : Real {
        unit = "Mb/s";
    }
    attribute def ForceValue : Real {
        unit = "N";
    }

    item def CommandPacket {
        attribute commandId : String;
        attribute priority : Integer;
        attribute issuedTime : String;
    }

    item def TelemetryPacket {
        attribute poseX : Distance;
        attribute poseY : Distance;
        attribute speed : Speed;
        attribute batterySoc : BatteryStateOfCharge;
        attribute linkQuality : Percent;
        attribute systemMode : String;
    }

    item def VideoFrame {
        attribute resolutionWidth : Integer;
        attribute resolutionHeight : Integer;
        attribute frameRate : Real {
            unit = "frame/s";
        }
        attribute compressedRate : DataRate;
    }

    item def ManipulatedObject {
        attribute estimatedMass : MassValue;
        attribute gripForceRequired : ForceValue;
        attribute hazardClassification : String;
    }

    port def CommandPort {
        in command : CommandPacket;
    }

    port def TelemetryPort {
        out telemetry : TelemetryPacket;
    }

    port def VideoPort {
        out frame : VideoFrame;
    }

    port def PowerPort {
        out voltage : VoltageValue;
        out current : CurrentValue;
    }

    port def MobilityControlPort {
        in desiredSpeed : Speed;
        in desiredHeading : Real {
            unit = "deg";
        }
    }

    port def ManipulatorControlPort {
        in targetReach : Distance;
        in gripperForce : ForceValue;
        in objectCommand : CommandPacket;
    }

    port def ObjectInteractionPort {
        in object : ManipulatedObject;
        out appliedForce : ForceValue;
    }

    part def FosterMillerDerivedHazardResponseRobot {
        doc /* A remotely operated tracked robot inspired by Foster-Miller TALON-class unmanned ground vehicles. Its primary high-level function is to keep operators at a safe distance while inspecting, identifying, and manipulating hazardous objects in confined or dangerous environments. */

        attribute systemMass : MassValue = 55.0;
        attribute maximumSpeed : Speed = 1.8;
        attribute operationalRange : Distance = 1000.0;
        attribute nominalVoltage : VoltageValue = 28.0;
        attribute minimumBatteryReserve : BatteryStateOfCharge = 20.0;

        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;
        port videoOut : VideoPort;
        port objectInterface : ObjectInteractionPort;

        part mobilitySubsystem : TrackedMobilitySubsystem;
        part sensorMast : SensorMastSubsystem;
        part manipulatorArm : ManipulatorSubsystem;
        part powerSubsystem : PowerSubsystem;
        part communicationsSubsystem : CommunicationsSubsystem;
        part missionComputer : MissionComputer;
        part operatorControlUnit : OperatorControlUnit;

        connect operatorControlUnit.commandOut to communicationsSubsystem.operatorCommandIn;
        connect communicationsSubsystem.robotCommandOut to missionComputer.commandIn;
        connect missionComputer.mobilityCommandOut to mobilitySubsystem.controlIn;
        connect missionComputer.manipulatorCommandOut to manipulatorArm.controlIn;
        connect missionComputer.telemetryOut to communicationsSubsystem.robotTelemetryIn;
        connect communicationsSubsystem.operatorTelemetryOut to operatorControlUnit.telemetryIn;
        connect sensorMast.videoOut to communicationsSubsystem.robotVideoIn;
        connect communicationsSubsystem.operatorVideoOut to operatorControlUnit.videoIn;
        connect powerSubsystem.powerOut to mobilitySubsystem.powerIn;
        connect powerSubsystem.powerOut to sensorMast.powerIn;
        connect powerSubsystem.powerOut to manipulatorArm.powerIn;
        connect powerSubsystem.powerOut to communicationsSubsystem.powerIn;
        connect powerSubsystem.powerOut to missionComputer.powerIn;
        connect manipulatorArm.objectInterface to objectInterface;

        perform missionBehavior : HazardResponseMission;
    }

    part def TrackedMobilitySubsystem {
        attribute trackWidth : Distance = 0.42;
        attribute groundClearance : Distance = 0.10;
        attribute maximumObstacleHeight : Distance = 0.28;
        attribute commandedSpeed : Speed;
        attribute actualSpeed : Speed;

        port controlIn : MobilityControlPort;
        port powerIn : PowerPort;

        part leftTrack : TrackDrive;
        part rightTrack : TrackDrive;

        action moveToStandoffPosition {
            in targetDistance : Distance;
            out reached : Boolean;
        }
    }

    part def TrackDrive {
        attribute motorVoltage : VoltageValue = 28.0;
        attribute motorCurrentLimit : CurrentValue = 40.0;
        attribute trackSpeed : Speed;
    }

    part def SensorMastSubsystem {
        attribute mastHeight : Distance = 1.25;
        attribute panAngle : Real {
            unit = "deg";
        }
        attribute tiltAngle : Real {
            unit = "deg";
        }

        port powerIn : PowerPort;
        port videoOut : VideoPort;

        part daylightCamera : Camera;
        part infraredCamera : Camera;
        part illuminationUnit : IlluminationUnit;
    }

    part def Camera {
        attribute horizontalFieldOfView : Real {
            unit = "deg";
        } = 72.0;
        attribute verticalFieldOfView : Real {
            unit = "deg";
        } = 44.0;
        attribute minimumFocusDistance : Distance = 0.25;
    }

    part def IlluminationUnit {
        attribute luminousPower : Real {
            unit = "lm";
        } = 1200.0;
        attribute enabled : Boolean;
    }

    part def ManipulatorSubsystem {
        attribute maximumReach : Distance = 1.9;
        attribute maximumLiftMass : MassValue = 9.0;
        attribute gripperMaximumForce : ForceValue = 450.0;

        port controlIn : ManipulatorControlPort;
        port powerIn : PowerPort;
        port objectInterface : ObjectInteractionPort;

        part shoulderJoint : JointActuator;
        part elbowJoint : JointActuator;
        part wristJoint : JointActuator;
        part gripper : Gripper;

        action inspectAndManipulateObject {
            in object : ManipulatedObject;
            out objectSecured : Boolean;
        }
    }

    part def JointActuator {
        attribute angularPosition : Real {
            unit = "deg";
        }
        attribute angularVelocity : Real {
            unit = "deg/s";
        }
        attribute torqueLimit : Real {
            unit = "N*m";
        } = 85.0;
    }

    part def Gripper {
        attribute jawOpening : Distance = 0.12;
        attribute appliedGripForce : ForceValue;
    }

    part def PowerSubsystem {
        attribute batterySoc : BatteryStateOfCharge = 100.0;
        attribute batteryVoltage : VoltageValue = 28.0;
        attribute batteryCapacity : Real {
            unit = "A*h";
        } = 32.0;
        attribute electronicsTemperature : TemperatureValue;

        port powerOut : PowerPort;

        action monitorPower {
            out reserveAvailable : Boolean;
        }
    }

    part def CommunicationsSubsystem {
        attribute radioFrequency : Real {
            unit = "MHz";
        } = 2450.0;
        attribute commandLatency : Real {
            unit = "ms";
        }
        attribute videoDataRate : DataRate = 8.0;
        attribute linkQuality : Percent;

        port operatorCommandIn : CommandPort;
        port robotCommandOut : CommandPort;
        port robotTelemetryIn : TelemetryPort;
        port operatorTelemetryOut : TelemetryPort;
        port robotVideoIn : VideoPort;
        port operatorVideoOut : VideoPort;
        port powerIn : PowerPort;
    }

    part def MissionComputer {
        attribute activeMode : String;
        attribute autonomyLevel : String = "operator supervised";
        attribute faultPresent : Boolean;

        port commandIn : CommandPort;
        port mobilityCommandOut : MobilityControlPort;
        port manipulatorCommandOut : ManipulatorControlPort;
        port telemetryOut : TelemetryPort;
        port powerIn : PowerPort;

        action interpretOperatorCommand {
            in command : CommandPacket;
            out valid : Boolean;
        }

        action publishTelemetry {
            out telemetry : TelemetryPacket;
        }
    }

    part def OperatorControlUnit {
        attribute displaySize : Distance = 0.33;
        attribute operatorId : String;
        attribute controlMode : String;

        port commandOut : CommandPort;
        port telemetryIn : TelemetryPort;
        port videoIn : VideoPort;
    }

    action def HazardResponseMission {
        in command : CommandPacket;
        out missionComplete : Boolean;

        first start;
        then establishRemoteLink;
        then moveToObservationPoint;
        then acquireSensorView;
        then classifyObjectHazard;
        then manipulateIfDirected;
        then returnToSafePosition;
        then reportMissionResult;
        then done;

        action start;
        action establishRemoteLink;
        action moveToObservationPoint;
        action acquireSensorView;
        action classifyObjectHazard;
        action manipulateIfDirected;
        action returnToSafePosition;
        action reportMissionResult;
        action done;
    }

    state def RobotOperationalStates {
        entry action initializeElectronics;
        exit action storeMissionLog;

        state PoweredOff;
        state Startup;
        state Standby;
        state TeleoperatedDrive;
        state RemoteInspection;
        state ObjectManipulation;
        state ReturnToOperator;
        state FaultSafe;

        transition first PoweredOff;
        transition PoweredOff_to_Startup
            first PoweredOff
            then Startup
            accept CommandPacket
            if command.commandId == "POWER_ON";

        transition Startup_to_Standby
            first Startup
            then Standby
            if diagnosticsPassed == true;

        transition Standby_to_TeleoperatedDrive
            first Standby
            then TeleoperatedDrive
            accept CommandPacket
            if command.commandId == "DRIVE";

        transition TeleoperatedDrive_to_RemoteInspection
            first TeleoperatedDrive
            then RemoteInspection
            accept CommandPacket
            if command.commandId == "INSPECT";

        transition RemoteInspection_to_ObjectManipulation
            first RemoteInspection
            then ObjectManipulation
            accept CommandPacket
            if command.commandId == "MANIPULATE";

        transition ObjectManipulation_to_ReturnToOperator
            first ObjectManipulation
            then ReturnToOperator
            accept CommandPacket
            if command.commandId == "RETURN";

        transition ReturnToOperator_to_Standby
            first ReturnToOperator
            then Standby
            if atOperatorPosition == true;

        transition Any_to_FaultSafe
            first Standby
            then FaultSafe
            if batterySoc < 15.0 or linkQuality < 10.0 or faultPresent == true;

        attribute diagnosticsPassed : Boolean;
        attribute atOperatorPosition : Boolean;
        attribute batterySoc : BatteryStateOfCharge;
        attribute linkQuality : Percent;
        attribute faultPresent : Boolean;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide remote hazardous-object inspection and manipulation capability so that the operator can remain outside the immediate hazard area. */
        subject robot : FosterMillerDerivedHazardResponseRobot;

        require constraint {
            robot.operationalRange >= 500.0
        }
    }

    requirement def RemoteVideoRequirement {
        doc /* The system shall transmit live visual information sufficient for operator assessment of the hazardous scene. */
        subject robot : FosterMillerDerivedHazardResponseRobot;

        require constraint {
            robot.communicationsSubsystem.videoDataRate >= 4.0
        }
    }

    requirement def MobilityRequirement {
        doc /* The system shall traverse uneven indoor and outdoor terrain while carrying its sensor and manipulator payload. */
        subject robot : FosterMillerDerivedHazardResponseRobot;

        require constraint {
            robot.mobilitySubsystem.maximumObstacleHeight >= 0.20
        }
    }

    requirement def ManipulationRequirement {
        doc /* The manipulator shall reach and apply controlled gripping force to a suspicious object without requiring direct operator exposure. */
        subject robot : FosterMillerDerivedHazardResponseRobot;

        require constraint {
            robot.manipulatorArm.maximumReach >= 1.5 and
            robot.manipulatorArm.gripperMaximumForce >= 300.0
        }
    }

    requirement def PowerReserveRequirement {
        doc /* The system shall warn and enter a conservative return mode before battery reserve is exhausted. */
        subject robot : FosterMillerDerivedHazardResponseRobot;

        require constraint {
            robot.minimumBatteryReserve >= 20.0
        }
    }

    requirement def SafetyRequirement {
        doc /* The system shall enter a fault-safe state if communications quality, battery level, or internal diagnostics fall below acceptable limits. */
        subject robot : FosterMillerDerivedHazardResponseRobot;
    }

    satisfy PrimaryFunctionRequirement by FosterMillerDerivedHazardResponseRobot;
    satisfy RemoteVideoRequirement by CommunicationsSubsystem;
    satisfy MobilityRequirement by TrackedMobilitySubsystem;
    satisfy ManipulationRequirement by ManipulatorSubsystem;
    satisfy PowerReserveRequirement by PowerSubsystem;
    satisfy SafetyRequirement by RobotOperationalStates;

    part hazardResponseRobot : FosterMillerDerivedHazardResponseRobot;

}