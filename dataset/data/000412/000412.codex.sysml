package TerabotS_HighLevelModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent : Real {
        :>> range = "0..100";
    }

    attribute def BatteryStateOfCharge : Percent;
    attribute def LinearSpeed : Real;
    attribute def AngularSpeed : Real;
    attribute def Distance : Real;
    attribute def Mass : Real;
    attribute def ElectricPotential : Real;
    attribute def ElectricCurrent : Real;
    attribute def Power : Real;
    attribute def TimeDuration : Real;
    attribute def Temperature : Real;

    item def Command {
        attribute commandId : String;
        attribute issuedBy : String;
        attribute priority : Integer;
    }

    item def MissionPlan :> Command {
        attribute missionName : String;
        attribute targetAreaId : String;
        attribute requestedCoveragePercent : Percent;
        attribute maximumMissionDuration : TimeDuration;
    }

    item def MotionCommand :> Command {
        attribute targetLinearSpeed : LinearSpeed;
        attribute targetAngularSpeed : AngularSpeed;
        attribute stopRequested : Boolean;
    }

    item def NavigationFix {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : Distance;
        attribute heading : AngularSpeed;
        attribute confidence : Percent;
    }

    item def TerrainObservation {
        attribute obstacleDistance : Distance;
        attribute surfaceClass : String;
        attribute slopeAngle : Real;
        attribute traversable : Boolean;
    }

    item def SystemHealth {
        attribute batterySoc : BatteryStateOfCharge;
        attribute driveTemperature : Temperature;
        attribute controllerTemperature : Temperature;
        attribute faultActive : Boolean;
        attribute faultCode : String;
    }

    item def PayloadData {
        attribute timestamp : TimeDuration;
        attribute areaId : String;
        attribute dataQuality : Percent;
        attribute storageUsed : Percent;
    }

    port def PowerPort {
        out item electricalPower : Power;
    }

    port def CommandPort {
        in item command : Command;
    }

    port def TelemetryPort {
        out item health : SystemHealth;
        out item navigation : NavigationFix;
        out item payloadData : PayloadData;
    }

    port def DataPort {
        in item inboundCommand : Command;
        out item outboundTelemetry : SystemHealth;
        out item outboundPayload : PayloadData;
    }

    port def MotionPort {
        in item motionCommand : MotionCommand;
        out item terrainObservation : TerrainObservation;
    }

    port def NavigationPort {
        in item missionPlan : MissionPlan;
        out item navigationFix : NavigationFix;
        out item terrainObservation : TerrainObservation;
    }

    port def PayloadPort {
        in item missionPlan : MissionPlan;
        out item payloadData : PayloadData;
    }

    part def BatteryPack {
        attribute nominalVoltage : ElectricPotential = 48.0;
        attribute capacityWh : Real = 2400.0;
        attribute stateOfCharge : BatteryStateOfCharge;
        attribute minimumOperationalSoc : BatteryStateOfCharge = 20.0;

        port powerOut : PowerPort;

        action providePower {
            in requiredPower : Power;
            out deliveredPower : Power;
        }
    }

    part def PowerDistributionUnit {
        port batteryInput : PowerPort;
        port controllerPower : PowerPort;
        port drivePower : PowerPort;
        port payloadPower : PowerPort;
        port commsPower : PowerPort;

        action distributePower {
            in availablePower : Power;
            out regulatedControllerPower : Power;
            out regulatedDrivePower : Power;
            out regulatedPayloadPower : Power;
            out regulatedCommsPower : Power;
        }
    }

    part def MobilityBase {
        attribute maximumSpeed : LinearSpeed = 1.5;
        attribute minimumTurningRadius : Distance = 0.0;
        attribute groundClearance : Distance = 0.18;
        attribute payloadCapacity : Mass = 40.0;

        port powerIn : PowerPort;
        port motion : MotionPort;

        part leftDrive;
        part rightDrive;
        part suspension;
        part chassis;

        action executeMotion {
            in motionCommand : MotionCommand;
            out terrainObservation : TerrainObservation;
        }

        state def MobilityState {
            entry action initializeDrive;
            state Idle;
            state Moving;
            state AvoidingObstacle;
            state EmergencyStopped;
            state Faulted;

            transition first Idle;
            transition Idle_to_Moving
                first Idle
                then Moving
                accept MotionCommand
                if not motionCommand.stopRequested;
            transition Moving_to_AvoidingObstacle
                first Moving
                then AvoidingObstacle
                if terrainObservation.obstacleDistance < 1.0;
            transition AvoidingObstacle_to_Moving
                first AvoidingObstacle
                then Moving
                if terrainObservation.traversable;
            transition Moving_to_Idle
                first Moving
                then Idle
                accept MotionCommand
                if motionCommand.stopRequested;
            transition Any_to_EmergencyStopped
                first Idle
                then EmergencyStopped
                accept MotionCommand
                if motionCommand.stopRequested and motionCommand.priority >= 100;
            transition Any_to_Faulted
                first Moving
                then Faulted
                if systemHealth.faultActive;
        }
    }

    part def NavigationAndAutonomyComputer {
        attribute localizationConfidenceThreshold : Percent = 80.0;
        attribute obstacleAvoidanceDistance : Distance = 1.0;

        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port navigation : NavigationPort;
        port motionOut : MotionPort;
        port telemetryOut : TelemetryPort;

        part routePlanner;
        part localization;
        part obstacleAvoidance;
        part missionManager;

        action planMission {
            in missionPlan : MissionPlan;
            in currentFix : NavigationFix;
            out motionCommand : MotionCommand;
        }

        action assessTerrain {
            in terrainObservation : TerrainObservation;
            out traversable : Boolean;
        }

        state def AutonomyState {
            state Standby;
            state Planning;
            state Navigating;
            state CollectingPayloadData;
            state ReturningToBase;
            state SafeStop;
            state FaultRecovery;

            transition first Standby;
            transition Standby_to_Planning
                first Standby
                then Planning
                accept MissionPlan;
            transition Planning_to_Navigating
                first Planning
                then Navigating
                if missionPlan.requestedCoveragePercent > 0.0;
            transition Navigating_to_CollectingPayloadData
                first Navigating
                then CollectingPayloadData
                if navigationFix.confidence >= localizationConfidenceThreshold;
            transition CollectingPayloadData_to_Navigating
                first CollectingPayloadData
                then Navigating
                if payloadData.dataQuality >= 90.0;
            transition Navigating_to_ReturningToBase
                first Navigating
                then ReturningToBase
                if systemHealth.batterySoc <= 25.0;
            transition ReturningToBase_to_Standby
                first ReturningToBase
                then Standby
                if missionComplete;
            transition Navigating_to_SafeStop
                first Navigating
                then SafeStop
                if terrainObservation.obstacleDistance < obstacleAvoidanceDistance and not terrainObservation.traversable;
            transition SafeStop_to_FaultRecovery
                first SafeStop
                then FaultRecovery
                if systemHealth.faultActive;
            transition FaultRecovery_to_Standby
                first FaultRecovery
                then Standby
                if not systemHealth.faultActive;
        }
    }

    part def SensorSuite {
        attribute lidarRange : Distance = 30.0;
        attribute cameraHorizontalFov : Real = 90.0;
        attribute imuUpdateRateHz : Real = 100.0;
        attribute gnssNominalAccuracy : Distance = 0.5;

        port powerIn : PowerPort;
        port navigationOut : NavigationPort;

        part lidar;
        part stereoCamera;
        part imu;
        part gnssReceiver;
        part wheelEncoders;

        action senseEnvironment {
            out terrainObservation : TerrainObservation;
            out navigationFix : NavigationFix;
        }
    }

    part def PayloadModule {
        attribute payloadPurpose : String = "High level field inspection and data acquisition";
        attribute storageCapacityGb : Real = 512.0;
        attribute nominalPayloadPower : Power = 120.0;

        port powerIn : PowerPort;
        port payload : PayloadPort;

        part inspectionCamera;
        part environmentalSensor;
        part onboardStorage;

        action collectPayloadData {
            in missionPlan : MissionPlan;
            out payloadData : PayloadData;
        }
    }

    part def CommunicationsModule {
        attribute primaryLink : String = "5G or Wi-Fi";
        attribute backupLink : String = "900 MHz telemetry";
        attribute nominalRange : Distance = 1000.0;

        port powerIn : PowerPort;
        port externalData : DataPort;
        port internalCommand : CommandPort;
        port internalTelemetry : TelemetryPort;

        action relayCommand {
            in inboundCommand : Command;
            out command : Command;
        }

        action transmitTelemetry {
            in health : SystemHealth;
            in navigation : NavigationFix;
            in payloadData : PayloadData;
        }
    }

    part def SafetyController {
        attribute emergencyStopLatencyLimit : TimeDuration = 0.25;
        attribute minimumSafeObstacleDistance : Distance = 0.5;

        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port motionOut : MotionPort;
        port telemetryIn : TelemetryPort;

        action evaluateSafety {
            in health : SystemHealth;
            in terrainObservation : TerrainObservation;
            out safeMotionCommand : MotionCommand;
        }

        state def SafetyState {
            state Nominal;
            state Warning;
            state EmergencyStop;
            state LockedOut;

            transition first Nominal;
            transition Nominal_to_Warning
                first Nominal
                then Warning
                if health.batterySoc < 25.0;
            transition Warning_to_Nominal
                first Warning
                then Nominal
                if health.batterySoc >= 30.0 and not health.faultActive;
            transition Nominal_to_EmergencyStop
                first Nominal
                then EmergencyStop
                if terrainObservation.obstacleDistance <= minimumSafeObstacleDistance;
            transition Warning_to_EmergencyStop
                first Warning
                then EmergencyStop
                if health.faultActive;
            transition EmergencyStop_to_LockedOut
                first EmergencyStop
                then LockedOut
                if command.priority < 100;
            transition LockedOut_to_Nominal
                first LockedOut
                then Nominal
                accept Command
                if command.commandId == "RESET_SAFETY" and command.priority >= 100;
        }
    }

    part def OperatorControlStation {
        attribute operatorInterface : String = "Mission planning, supervision, and manual override";
        attribute supportedMissionUpload : Boolean = true;

        port dataLink : DataPort;

        action defineMission {
            out missionPlan : MissionPlan;
        }

        action monitorRobot {
            in health : SystemHealth;
            in navigation : NavigationFix;
            in payloadData : PayloadData;
        }
    }

    part def TerabotS_System {
        attribute systemName : String = "Terabot-S Based Autonomous Mobile Robot";
        attribute primaryFunction : String = "Autonomously traverse an assigned operating area, avoid hazards, collect inspection data, and report mission status to an operator.";
        attribute maximumOperatingSpeed : LinearSpeed = 1.5;
        attribute nominalEnduranceHours : Real = 6.0;
        attribute nominalMass : Mass = 120.0;

        port externalCommandTelemetry : DataPort;

        part battery : BatteryPack;
        part pdu : PowerDistributionUnit;
        part mobility : MobilityBase;
        part autonomy : NavigationAndAutonomyComputer;
        part sensors : SensorSuite;
        part payload : PayloadModule;
        part communications : CommunicationsModule;
        part safety : SafetyController;
        part operatorStation : OperatorControlStation;

        connect battery.powerOut to pdu.batteryInput;
        connect pdu.drivePower to mobility.powerIn;
        connect pdu.controllerPower to autonomy.powerIn;
        connect pdu.controllerPower to safety.powerIn;
        connect pdu.payloadPower to payload.powerIn;
        connect pdu.payloadPower to sensors.powerIn;
        connect pdu.commsPower to communications.powerIn;

        connect operatorStation.dataLink to communications.externalData;
        connect communications.internalCommand to autonomy.commandIn;
        connect communications.internalCommand to safety.commandIn;
        connect communications.internalTelemetry to autonomy.telemetryOut;
        connect externalCommandTelemetry to communications.externalData;

        connect sensors.navigationOut to autonomy.navigation;
        connect autonomy.motionOut to mobility.motion;
        connect safety.motionOut to mobility.motion;
        connect payload.payload to autonomy.navigation;
        connect payload.payload to communications.internalTelemetry;

        action performPrimaryMission {
            in missionPlan : MissionPlan;
            out finalHealth : SystemHealth;
            out finalPayloadData : PayloadData;

            first startSystem;
            then receiveMission;
            then planRoute;
            then traverseArea;
            then collectInspectionData;
            then transmitStatus;
            then returnToBase;
            then shutdownToStandby;
        }

        state def TerabotSOperationalState {
            state PoweredOff;
            state Booting;
            state Standby;
            state MissionReady;
            state AutonomousMission;
            state ManualOverride;
            state ReturningHome;
            state Charging;
            state Faulted;
            state EmergencyStopped;

            transition first PoweredOff;
            transition PoweredOff_to_Booting
                first PoweredOff
                then Booting
                accept Command
                if command.commandId == "POWER_ON";
            transition Booting_to_Standby
                first Booting
                then Standby
                if systemHealth.faultActive == false;
            transition Standby_to_MissionReady
                first Standby
                then MissionReady
                accept MissionPlan;
            transition MissionReady_to_AutonomousMission
                first MissionReady
                then AutonomousMission
                if battery.stateOfCharge >= battery.minimumOperationalSoc;
            transition AutonomousMission_to_ReturningHome
                first AutonomousMission
                then ReturningHome
                if systemHealth.batterySoc <= 25.0;
            transition AutonomousMission_to_ManualOverride
                first AutonomousMission
                then ManualOverride
                accept Command
                if command.commandId == "MANUAL_OVERRIDE";
            transition ManualOverride_to_AutonomousMission
                first ManualOverride
                then AutonomousMission
                accept Command
                if command.commandId == "RESUME_AUTONOMY";
            transition ReturningHome_to_Charging
                first ReturningHome
                then Charging
                if missionComplete;
            transition Charging_to_Standby
                first Charging
                then Standby
                if battery.stateOfCharge >= 95.0;
            transition AutonomousMission_to_EmergencyStopped
                first AutonomousMission
                then EmergencyStopped
                if systemHealth.faultActive or terrainObservation.obstacleDistance <= safety.minimumSafeObstacleDistance;
            transition EmergencyStopped_to_Faulted
                first EmergencyStopped
                then Faulted
                if systemHealth.faultActive;
            transition Faulted_to_Standby
                first Faulted
                then Standby
                accept Command
                if command.commandId == "CLEAR_FAULT";
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject terabot : TerabotS_System;

        doc /* The Terabot-S based system shall provide autonomous mobile inspection by navigating a defined operating area, avoiding obstacles, collecting payload data, and transmitting status and collected data to an operator. */

        require constraint {
            terabot.primaryFunction == "Autonomously traverse an assigned operating area, avoid hazards, collect inspection data, and report mission status to an operator."
        }
    }

    requirement def MobilityRequirement {
        subject mobility : MobilityBase;

        require constraint {
            mobility.maximumSpeed >= 1.0
        }

        require constraint {
            mobility.payloadCapacity >= 25.0
        }
    }

    requirement def EnduranceRequirement {
        subject terabot : TerabotS_System;

        require constraint {
            terabot.nominalEnduranceHours >= 4.0
        }
    }

    requirement def SafetyStopRequirement {
        subject safety : SafetyController;

        require constraint {
            safety.emergencyStopLatencyLimit <= 0.5
        }

        require constraint {
            safety.minimumSafeObstacleDistance >= 0.5
        }
    }

    requirement def NavigationRequirement {
        subject autonomy : NavigationAndAutonomyComputer;

        require constraint {
            autonomy.localizationConfidenceThreshold >= 75.0
        }

        require constraint {
            autonomy.obstacleAvoidanceDistance >= 1.0
        }
    }

    requirement def PayloadDataRequirement {
        subject payload : PayloadModule;

        require constraint {
            payload.storageCapacityGb >= 128.0
        }

        require constraint {
            payload.nominalPayloadPower <= 250.0
        }
    }

    satisfy PrimaryFunctionRequirement by TerabotS_System;
    satisfy MobilityRequirement by MobilityBase;
    satisfy EnduranceRequirement by TerabotS_System;
    satisfy SafetyStopRequirement by SafetyController;
    satisfy NavigationRequirement by NavigationAndAutonomyComputer;
    satisfy PayloadDataRequirement by PayloadModule;
}