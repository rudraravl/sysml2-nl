package UncrewedVehicleSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    item def Command {
        attribute commandId : String;
        attribute issuedAt : TimeValue;
        attribute priority : PriorityLevel;
        attribute modeRequest : MissionMode;
    }

    item def MissionPlan {
        attribute missionId : String;
        attribute route : Waypoint[1..*];
        attribute cruiseSpeed : SpeedValue;
        attribute nominalAltitude : LengthValue;
        attribute returnHomeOnFault : Boolean;
    }

    item def Waypoint {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
        attribute loiterTime : TimeValue;
    }

    item def Telemetry {
        attribute vehicleId : String;
        attribute position : GeoPosition;
        attribute velocity : SpeedValue;
        attribute heading : PlaneAngleValue;
        attribute batteryStateOfCharge : PercentValue;
        attribute healthStatus : HealthState;
        attribute activeMode : MissionMode;
    }

    item def SensorData {
        attribute timestamp : TimeValue;
        attribute position : GeoPosition;
        attribute obstacleRange : LengthValue;
        attribute obstacleBearing : PlaneAngleValue;
        attribute confidence : PercentValue;
    }

    item def GeoPosition {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
    }

    item def PropulsionCommand {
        attribute thrustRequest : PercentValue;
        attribute steeringAngle : PlaneAngleValue;
        attribute brakeRequest : PercentValue;
    }

    item def PowerFlow {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute power : PowerValue;
    }

    item def PayloadData {
        attribute timestamp : TimeValue;
        attribute geoTag : GeoPosition;
        attribute classification : String;
        attribute quality : PercentValue;
    }

    enum def MissionMode {
        enum idle;
        enum preflight;
        enum autonomousTransit;
        enum obstacleAvoidance;
        enum payloadOperation;
        enum returnToBase;
        enum emergencyStop;
        enum shutdown;
    }

    enum def HealthState {
        enum nominal;
        enum degraded;
        enum critical;
        enum failed;
    }

    enum def PriorityLevel {
        enum routine;
        enum urgent;
        enum emergency;
    }

    value def PercentValue :> Real {
        unit = "%";
    }

    value def TimeValue :> Real {
        unit = "s";
    }

    value def LengthValue :> Real {
        unit = "m";
    }

    value def SpeedValue :> Real {
        unit = "m/s";
    }

    value def MassValue :> Real {
        unit = "kg";
    }

    value def PowerValue :> Real {
        unit = "W";
    }

    value def EnergyValue :> Real {
        unit = "Wh";
    }

    value def ElectricPotentialValue :> Real {
        unit = "V";
    }

    value def ElectricCurrentValue :> Real {
        unit = "A";
    }

    value def PlaneAngleValue :> Real {
        unit = "deg";
    }

    port def CommandPort {
        in item command : Command;
        in item missionPlan : MissionPlan;
    }

    port def TelemetryPort {
        out item telemetry : Telemetry;
    }

    port def SensorPort {
        out item sensorData : SensorData;
    }

    port def PropulsionControlPort {
        out item propulsionCommand : PropulsionCommand;
    }

    port def PowerPort {
        out item powerFlow : PowerFlow;
    }

    port def PayloadPort {
        out item payloadData : PayloadData;
        in item command : Command;
    }

    port def DataBusPort {
        inout item command : Command;
        inout item telemetry : Telemetry;
        inout item sensorData : SensorData;
        inout item payloadData : PayloadData;
    }

    part def UncrewedVehicle {
        attribute vehicleId : String;
        attribute maximumSpeed : SpeedValue = 22.0;
        attribute cruiseSpeed : SpeedValue = 12.0;
        attribute maximumEndurance : TimeValue = 7200.0;
        attribute maximumPayloadMass : MassValue = 8.0;
        attribute operationalRange : LengthValue = 35000.0;
        attribute currentMode : MissionMode = MissionMode::idle;
        attribute health : HealthState = HealthState::nominal;

        port commandPort : CommandPort;
        port telemetryPort : TelemetryPort;

        part autonomyController : AutonomyController;
        part navigationSystem : NavigationSystem;
        part perceptionSystem : PerceptionSystem;
        part propulsionSystem : PropulsionSystem;
        part energySystem : EnergySystem;
        part communicationsSystem : CommunicationsSystem;
        part payloadSystem : PayloadSystem;
        part vehicleFrame : VehicleFrame;

        connect commandPort to communicationsSystem.externalCommandPort;
        connect communicationsSystem.vehicleDataBus to autonomyController.commandBus;
        connect autonomyController.navigationBus to navigationSystem.controlBus;
        connect perceptionSystem.sensorBus to autonomyController.perceptionBus;
        connect autonomyController.propulsionControlPort to propulsionSystem.controlPort;
        connect energySystem.powerOutput to propulsionSystem.powerInput;
        connect energySystem.powerOutput to autonomyController.powerInput;
        connect energySystem.powerOutput to navigationSystem.powerInput;
        connect energySystem.powerOutput to perceptionSystem.powerInput;
        connect energySystem.powerOutput to communicationsSystem.powerInput;
        connect autonomyController.payloadCommandPort to payloadSystem.commandPort;
        connect payloadSystem.payloadDataPort to communicationsSystem.payloadBus;
        connect communicationsSystem.telemetryPort to telemetryPort;
        connect navigationSystem.navigationDataPort to communicationsSystem.navigationBus;
        connect energySystem.energyTelemetryPort to communicationsSystem.energyBus;
    }

    part def AutonomyController {
        attribute processorLoad : PercentValue;
        attribute selectedMode : MissionMode = MissionMode::idle;
        attribute faultToleranceLevel : PriorityLevel = PriorityLevel::routine;

        port commandBus : DataBusPort;
        port perceptionBus : DataBusPort;
        port navigationBus : DataBusPort;
        port propulsionControlPort : PropulsionControlPort;
        port payloadCommandPort : PayloadPort;
        port powerInput : PowerPort;

        action selectMissionMode {
            in item command : Command;
            in item telemetry : Telemetry;
            out attribute mode : MissionMode;
        }

        action computeTrajectory {
            in item missionPlan : MissionPlan;
            in item sensorData : SensorData;
            in item telemetry : Telemetry;
            out item propulsionCommand : PropulsionCommand;
        }

        action monitorVehicleHealth {
            in item telemetry : Telemetry;
            in attribute batteryStateOfCharge : PercentValue;
            out attribute health : HealthState;
        }

        state behavior autonomyBehavior {
            entry action initializeController;

            state Idle;
            state PreflightCheck;
            state AutonomousTransit;
            state AvoidObstacle;
            state OperatePayload;
            state ReturnToBase;
            state EmergencyStop;
            state Shutdown;

            transition first Idle;

            transition Idle_to_Preflight
                first Idle
                then PreflightCheck
                accept Command
                if command.modeRequest == MissionMode::preflight;

            transition Preflight_to_Transit
                first PreflightCheck
                then AutonomousTransit
                if health == HealthState::nominal;

            transition Transit_to_Avoid
                first AutonomousTransit
                then AvoidObstacle
                accept SensorData
                if sensorData.obstacleRange < 25.0;

            transition Avoid_to_Transit
                first AvoidObstacle
                then AutonomousTransit
                if sensorData.obstacleRange >= 25.0;

            transition Transit_to_Payload
                first AutonomousTransit
                then OperatePayload
                if selectedMode == MissionMode::payloadOperation;

            transition Payload_to_Transit
                first OperatePayload
                then AutonomousTransit
                if selectedMode == MissionMode::autonomousTransit;

            transition Any_to_Return
                first AutonomousTransit
                then ReturnToBase
                if batteryStateOfCharge < 25.0;

            transition Return_to_Shutdown
                first ReturnToBase
                then Shutdown
                if selectedMode == MissionMode::shutdown;

            transition Any_to_Emergency
                first AutonomousTransit
                then EmergencyStop
                accept Command
                if command.priority == PriorityLevel::emergency;

            transition Emergency_to_Shutdown
                first EmergencyStop
                then Shutdown;
        }
    }

    part def NavigationSystem {
        attribute estimatedPosition : GeoPosition;
        attribute positionAccuracy : LengthValue = 1.5;
        attribute headingAccuracy : PlaneAngleValue = 2.0;

        port controlBus : DataBusPort;
        port navigationDataPort : DataBusPort;
        port powerInput : PowerPort;

        part gnssReceiver : GNSSReceiver;
        part inertialMeasurementUnit : InertialMeasurementUnit;
        part navigationComputer : NavigationComputer;

        connect gnssReceiver.positionPort to navigationComputer.gnssPort;
        connect inertialMeasurementUnit.motionPort to navigationComputer.imuPort;
        connect navigationComputer.navigationDataPort to navigationDataPort;
    }

    part def GNSSReceiver {
        attribute updateRate : Real = 10.0;
        attribute horizontalAccuracy : LengthValue = 1.2;
        port positionPort : SensorPort;
    }

    part def InertialMeasurementUnit {
        attribute accelerationRange : Real = 16.0;
        attribute angularRateRange : Real = 2000.0;
        port motionPort : SensorPort;
    }

    part def NavigationComputer {
        port gnssPort : SensorPort;
        port imuPort : SensorPort;
        port navigationDataPort : DataBusPort;

        action estimateState {
            in item gnssData : SensorData;
            in item imuData : SensorData;
            out item telemetry : Telemetry;
        }
    }

    part def PerceptionSystem {
        attribute detectionRange : LengthValue = 120.0;
        attribute minimumAvoidanceRange : LengthValue = 25.0;

        port sensorBus : DataBusPort;
        port powerInput : PowerPort;

        part forwardLidar : LidarSensor;
        part opticalCamera : CameraSensor;
        part perceptionComputer : PerceptionComputer;

        connect forwardLidar.obstaclePort to perceptionComputer.lidarInput;
        connect opticalCamera.imageFeaturePort to perceptionComputer.cameraInput;
        connect perceptionComputer.perceptionOutput to sensorBus;
    }

    part def LidarSensor {
        attribute range : LengthValue = 120.0;
        attribute fieldOfView : PlaneAngleValue = 120.0;
        port obstaclePort : SensorPort;
    }

    part def CameraSensor {
        attribute resolutionHorizontal : Real = 1920.0;
        attribute resolutionVertical : Real = 1080.0;
        attribute frameRate : Real = 30.0;
        port imageFeaturePort : SensorPort;
    }

    part def PerceptionComputer {
        port lidarInput : SensorPort;
        port cameraInput : SensorPort;
        port perceptionOutput : DataBusPort;

        action fuseSensorObservations {
            in item lidarData : SensorData;
            in item cameraData : SensorData;
            out item fusedData : SensorData;
        }
    }

    part def PropulsionSystem {
        attribute maximumThrust : Real = 100.0;
        attribute commandedThrust : PercentValue = 0.0;
        attribute commandedSteering : PlaneAngleValue = 0.0;

        port controlPort : PropulsionControlPort;
        port powerInput : PowerPort;

        part motorController : MotorController;
        part leftDriveMotor : ElectricMotor;
        part rightDriveMotor : ElectricMotor;
        part steeringActuator : SteeringActuator;
        part brakingActuator : BrakingActuator;

        connect controlPort to motorController.commandInput;
        connect motorController.leftMotorOutput to leftDriveMotor.controlInput;
        connect motorController.rightMotorOutput to rightDriveMotor.controlInput;
        connect motorController.steeringOutput to steeringActuator.controlInput;
        connect motorController.brakeOutput to brakingActuator.controlInput;
    }

    part def MotorController {
        port commandInput : PropulsionControlPort;
        port leftMotorOutput : PropulsionControlPort;
        port rightMotorOutput : PropulsionControlPort;
        port steeringOutput : PropulsionControlPort;
        port brakeOutput : PropulsionControlPort;

        action allocatePropulsion {
            in item propulsionCommand : PropulsionCommand;
            out item leftCommand : PropulsionCommand;
            out item rightCommand : PropulsionCommand;
        }
    }

    part def ElectricMotor {
        attribute ratedPower : PowerValue = 1800.0;
        attribute efficiency : PercentValue = 88.0;
        port controlInput : PropulsionControlPort;
    }

    part def SteeringActuator {
        attribute maximumAngle : PlaneAngleValue = 35.0;
        attribute responseTime : TimeValue = 0.2;
        port controlInput : PropulsionControlPort;
    }

    part def BrakingActuator {
        attribute maximumBrakeForce : Real = 2500.0;
        attribute responseTime : TimeValue = 0.15;
        port controlInput : PropulsionControlPort;
    }

    part def EnergySystem {
        attribute batteryCapacity : EnergyValue = 5200.0;
        attribute nominalVoltage : ElectricPotentialValue = 48.0;
        attribute stateOfCharge : PercentValue = 100.0;
        attribute reserveThreshold : PercentValue = 25.0;

        port powerOutput : PowerPort;
        port energyTelemetryPort : DataBusPort;

        part batteryPack : BatteryPack;
        part powerDistributionUnit : PowerDistributionUnit;
        part chargerInterface : ChargerInterface;

        connect batteryPack.powerPort to powerDistributionUnit.inputPower;
        connect powerDistributionUnit.outputPower to powerOutput;
        connect chargerInterface.chargePowerPort to batteryPack.powerPort;
    }

    part def BatteryPack {
        attribute capacity : EnergyValue = 5200.0;
        attribute nominalVoltage : ElectricPotentialValue = 48.0;
        attribute maximumCurrent : ElectricCurrentValue = 160.0;
        attribute stateOfCharge : PercentValue = 100.0;
        port powerPort : PowerPort;
    }

    part def PowerDistributionUnit {
        attribute conversionEfficiency : PercentValue = 94.0;
        port inputPower : PowerPort;
        port outputPower : PowerPort;
    }

    part def ChargerInterface {
        attribute maximumChargePower : PowerValue = 1500.0;
        port chargePowerPort : PowerPort;
    }

    part def CommunicationsSystem {
        attribute commandLinkRange : LengthValue = 10000.0;
        attribute telemetryRate : Real = 5.0;

        port externalCommandPort : CommandPort;
        port telemetryPort : TelemetryPort;
        port vehicleDataBus : DataBusPort;
        port payloadBus : PayloadPort;
        port navigationBus : DataBusPort;
        port energyBus : DataBusPort;
        port powerInput : PowerPort;

        part radioModem : RadioModem;
        part messageRouter : MessageRouter;

        connect externalCommandPort to radioModem.commandPort;
        connect radioModem.dataBus to messageRouter.externalBus;
        connect messageRouter.vehicleBus to vehicleDataBus;
        connect messageRouter.telemetryPort to telemetryPort;
    }

    part def RadioModem {
        attribute frequency : Real = 915.0;
        attribute transmitPower : PowerValue = 2.0;
        port commandPort : CommandPort;
        port dataBus : DataBusPort;
    }

    part def MessageRouter {
        port externalBus : DataBusPort;
        port vehicleBus : DataBusPort;
        port telemetryPort : TelemetryPort;

        action buildTelemetryMessage {
            in item navigationTelemetry : Telemetry;
            in item energyTelemetry : Telemetry;
            out item vehicleTelemetry : Telemetry;
        }
    }

    part def PayloadSystem {
        attribute payloadMass : MassValue = 5.0;
        attribute payloadPowerDemand : PowerValue = 120.0;

        port commandPort : PayloadPort;
        port payloadDataPort : PayloadPort;

        part surveySensor : SurveySensor;
        part payloadProcessor : PayloadProcessor;

        connect commandPort to payloadProcessor.commandInput;
        connect surveySensor.payloadOutput to payloadProcessor.sensorInput;
        connect payloadProcessor.payloadOutput to payloadDataPort;
    }

    part def SurveySensor {
        attribute swathWidth : LengthValue = 30.0;
        attribute sampleRate : Real = 2.0;
        port payloadOutput : PayloadPort;
    }

    part def PayloadProcessor {
        port commandInput : PayloadPort;
        port sensorInput : PayloadPort;
        port payloadOutput : PayloadPort;

        action processPayloadObservation {
            in item rawPayloadData : PayloadData;
            out item processedPayloadData : PayloadData;
        }
    }

    part def VehicleFrame {
        attribute structuralMass : MassValue = 42.0;
        attribute maximumGrossMass : MassValue = 68.0;
        attribute ingressProtectionRating : String = "IP54";
    }

    action def ExecuteAutonomousMission {
        in item missionPlan : MissionPlan;
        in item command : Command;
        out item missionTelemetry : Telemetry;

        action validateMissionPlan;
        action armVehicle;
        action navigateRoute;
        action avoidDetectedObstacles;
        action performPayloadTask;
        action returnToBase;
        action disarmVehicle;

        flow validateMissionPlan then armVehicle;
        flow armVehicle then navigateRoute;
        flow navigateRoute then avoidDetectedObstacles;
        flow avoidDetectedObstacles then performPayloadTask;
        flow performPayloadTask then returnToBase;
        flow returnToBase then disarmVehicle;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The uncrewed vehicle shall autonomously execute a commanded mission plan by navigating through assigned waypoints, avoiding obstacles, operating its payload, transmitting telemetry, and returning to base without onboard human control. */

        subject vehicle : UncrewedVehicle;

        require constraint {
            vehicle.operationalRange >= 30000.0
        }

        require constraint {
            vehicle.maximumEndurance >= 5400.0
        }
    }

    requirement def SafetyRequirement {
        doc /* The uncrewed vehicle shall transition to emergency stop when it receives an emergency command or detects a critical health state. */

        subject controller : AutonomyController;

        require constraint {
            controller.selectedMode != MissionMode::emergencyStop implies controller.faultToleranceLevel != PriorityLevel::emergency
        }
    }

    requirement def EnergyReserveRequirement {
        doc /* The uncrewed vehicle shall reserve sufficient stored energy to return to base by initiating return-to-base behavior when battery state of charge falls below the reserve threshold. */

        subject energySystem : EnergySystem;

        require constraint {
            energySystem.reserveThreshold >= 20.0
        }
    }

    requirement def ObstacleAvoidanceRequirement {
        doc /* The uncrewed vehicle shall command an obstacle avoidance behavior whenever a detected obstacle is inside the minimum avoidance range. */

        subject perceptionSystem : PerceptionSystem;

        require constraint {
            perceptionSystem.minimumAvoidanceRange >= 20.0
        }
    }

    requirement def TelemetryRequirement {
        doc /* The uncrewed vehicle shall provide periodic telemetry containing vehicle position, active mission mode, health state, and battery state of charge. */

        subject communicationsSystem : CommunicationsSystem;

        require constraint {
            communicationsSystem.telemetryRate >= 1.0
        }
    }

    requirement def PayloadRequirement {
        doc /* The uncrewed vehicle shall collect mission payload data and associate each payload observation with a geospatial tag and timestamp. */

        subject payloadSystem : PayloadSystem;

        require constraint {
            payloadSystem.payloadMass <= 8.0
        }
    }

    satisfy PrimaryFunctionRequirement by UncrewedVehicle;
    satisfy SafetyRequirement by AutonomyController;
    satisfy EnergyReserveRequirement by EnergySystem;
    satisfy ObstacleAvoidanceRequirement by PerceptionSystem;
    satisfy TelemetryRequirement by CommunicationsSystem;
    satisfy PayloadRequirement by PayloadSystem;

    part uncrewedSurveyVehicle : UncrewedVehicle {
        vehicleId = "UV-001";
        maximumSpeed = 22.0;
        cruiseSpeed = 12.0;
        maximumEndurance = 7200.0;
        maximumPayloadMass = 8.0;
        operationalRange = 35000.0;
        currentMode = MissionMode::idle;
        health = HealthState::nominal;
    }

    action missionExecution : ExecuteAutonomousMission {
        in item missionPlan = MissionPlan {
            missionId = "SURVEY-MISSION-001";
            cruiseSpeed = 12.0;
            nominalAltitude = 0.0;
            returnHomeOnFault = true;
        }
    }
}