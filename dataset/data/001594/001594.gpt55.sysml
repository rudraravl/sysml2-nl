package TechnologicalEvolutionMobilityModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Kilowatt :> Real {
        attribute unit : String = "kW";
    }

    attribute def KilowattHour :> Real {
        attribute unit : String = "kW*h";
    }

    attribute def VoltDC :> Real {
        attribute unit : String = "V dc";
    }

    attribute def Ampere :> Real {
        attribute unit : String = "A";
    }

    attribute def Kilometer :> Real {
        attribute unit : String = "km";
    }

    attribute def KilometerPerHour :> Real {
        attribute unit : String = "km/h";
    }

    attribute def Meter :> Real {
        attribute unit : String = "m";
    }

    attribute def Second :> Real {
        attribute unit : String = "s";
    }

    attribute def Celsius :> Real {
        attribute unit : String = "degC";
    }

    attribute def Percent :> Real {
        attribute unit : String = "%";
    }

    attribute def PassengerCount :> Integer {
        attribute unit : String = "passenger";
    }

    attribute def DataRateMbps :> Real {
        attribute unit : String = "Mbit/s";
    }

    attribute def ComputingRateTOPS :> Real {
        attribute unit : String = "TOPS";
    }

    attribute def CO2GramPerKilometer :> Real {
        attribute unit : "gCO2/km";
    }

    enum def EvolutionStageKind {
        enum horseDrawnMobility;
        enum internalCombustionMassTransit;
        enum batteryElectricTransit;
        enum connectedAutonomousElectricMobility;
    }

    enum def OperationalModeKind {
        enum poweredOff;
        enum charging;
        enum standby;
        enum boarding;
        enum autonomousDriving;
        enum remoteAssistedDriving;
        enum minimalRiskStop;
        enum maintenance;
    }

    enum def SafetyIntegrityKind {
        enum nominal;
        enum degraded;
        enum failOperational;
        enum failSafe;
    }

    enum def PassengerAccessKind {
        enum closed;
        enum opening;
        enum open;
        enum closing;
        enum locked;
    }

    enum def EnergyFlowKind {
        enum gridToBattery;
        enum batteryToTraction;
        enum regenerativeToBattery;
        enum batteryToAuxiliary;
        enum thermalDissipation;
    }

    item def Passenger {
        attribute passengerIdentifier : String;
        attribute mobilityNeedDescription : String;
        attribute accessibilityAssistanceRequired : Boolean;
    }

    item def MobilityRequest {
        attribute requestIdentifier : String;
        attribute originName : String;
        attribute destinationName : String;
        attribute requestedPassengerCount : PassengerCount;
        attribute maximumWaitTime : Second;
        attribute wheelchairSpaceRequired : Boolean;
    }

    item def RoutePlan {
        attribute planIdentifier : String;
        attribute plannedDistance : Kilometer;
        attribute plannedDuration : Second;
        attribute maximumAllowedSpeed : KilometerPerHour;
        attribute energyEstimate : KilowattHour;
        attribute includesProtectedStops : Boolean;
    }

    item def MotionTrajectory {
        attribute horizon : Second;
        attribute targetSpeed : KilometerPerHour;
        attribute stoppingDistance : Meter;
        attribute curvatureLimit : Real;
    }

    item def SensorFrame {
        attribute frameIdentifier : String;
        attribute timeStamp : Second;
        attribute detectionRange : Meter;
        attribute confidence : Percent;
    }

    item def ObjectList {
        attribute objectCount : Integer;
        attribute nearestObstacleDistance : Meter;
        attribute vulnerableRoadUserPresent : Boolean;
        attribute confidence : Percent;
    }

    item def VehicleCommand {
        attribute requestedSpeed : KilometerPerHour;
        attribute requestedSteeringAngle : Real;
        attribute requestedBrakePercent : Percent;
        attribute emergencyStop : Boolean;
    }

    item def HealthStatus {
        attribute healthIdentifier : String;
        attribute safetyIntegrity : SafetyIntegrityKind;
        attribute batteryStateOfCharge : Percent;
        attribute propulsionAvailable : Boolean;
        attribute autonomousControlAvailable : Boolean;
        attribute faultDescription : String;
    }

    item def PassengerServiceStatus {
        attribute seatedPassengerCount : PassengerCount;
        attribute doorState : PassengerAccessKind;
        attribute cabinReady : Boolean;
        attribute tripComplete : Boolean;
    }

    item def ElectricalEnergy {
        attribute energyAmount : KilowattHour;
        attribute voltage : VoltDC;
        attribute current : Ampere;
        attribute flowKind : EnergyFlowKind;
    }

    item def ElectricalPower {
        attribute power : Kilowatt;
        attribute voltage : VoltDC;
        attribute current : Ampere;
        attribute flowKind : EnergyFlowKind;
    }

    item def MechanicalTorque {
        attribute torqueNewtonMeter : Real;
        attribute rotationalSpeedRpm : Real;
    }

    item def ThermalEnergy {
        attribute temperature : Celsius;
        attribute rejectedPower : Kilowatt;
    }

    item def DigitalMessage {
        attribute messageIdentifier : String;
        attribute payloadSizeByte : Integer;
        attribute authenticated : Boolean;
        attribute latency : Second;
    }

    item def EvolutionRecord {
        attribute stage : EvolutionStageKind;
        attribute dominantEnergySource : String;
        attribute primaryControlMethod : String;
        attribute societalCapabilityAdded : String;
        attribute tailpipeEmission : CO2GramPerKilometer;
    }

    port def PassengerInterfacePort {
        in item request : MobilityRequest;
        in item passenger : Passenger;
        out item serviceStatus : PassengerServiceStatus;
        out item tripPlan : RoutePlan;
    }

    port def ChargingPort {
        in item gridPower : ElectricalPower;
        out item chargeStatus : HealthStatus;
    }

    port def DCPowerPort {
        inout item dcPower : ElectricalPower;
    }

    port def MechanicalDrivePort {
        out item driveTorque : MechanicalTorque;
    }

    port def WheelTorquePort {
        in item appliedTorque : MechanicalTorque;
    }

    port def ThermalPort {
        inout item heat : ThermalEnergy;
    }

    port def SensorDataPort {
        out item rawFrame : SensorFrame;
    }

    port def PerceptionPort {
        in item rawFrame : SensorFrame;
        out item perceivedObjects : ObjectList;
    }

    port def PlanningPort {
        in item request : MobilityRequest;
        in item objects : ObjectList;
        in item health : HealthStatus;
        out item route : RoutePlan;
        out item trajectory : MotionTrajectory;
    }

    port def ControlPort {
        in item trajectory : MotionTrajectory;
        in item health : HealthStatus;
        out item command : VehicleCommand;
    }

    port def ActuatorCommandPort {
        in item command : VehicleCommand;
    }

    port def VehicleNetworkPort {
        inout item message : DigitalMessage;
    }

    port def HealthPort {
        out item health : HealthStatus;
    }

    port def V2XPort {
        inout item v2xMessage : DigitalMessage;
    }

    part def TechnologicalEvolutionLineage {
        attribute currentStage : EvolutionStageKind = EvolutionStageKind::connectedAutonomousElectricMobility;

        part horseDrawnStage {
            attribute record : EvolutionRecord {
                :>> stage = EvolutionStageKind::horseDrawnMobility;
                :>> dominantEnergySource = "animal metabolic energy";
                :>> primaryControlMethod = "human driver with reins";
                :>> societalCapabilityAdded = "personal and local goods mobility beyond walking distance";
                :>> tailpipeEmission = 0.0;
            }
        }

        part combustionTransitStage {
            attribute record : EvolutionRecord {
                :>> stage = EvolutionStageKind::internalCombustionMassTransit;
                :>> dominantEnergySource = "liquid hydrocarbon fuel";
                :>> primaryControlMethod = "human driver with mechanical controls";
                :>> societalCapabilityAdded = "high capacity scheduled urban transportation";
                :>> tailpipeEmission = 980.0;
            }
        }

        part electricTransitStage {
            attribute record : EvolutionRecord {
                :>> stage = EvolutionStageKind::batteryElectricTransit;
                :>> dominantEnergySource = "grid-charged electrochemical battery";
                :>> primaryControlMethod = "human driver with electronic powertrain control";
                :>> societalCapabilityAdded = "low noise zero-tailpipe-emission city mobility";
                :>> tailpipeEmission = 0.0;
            }
        }

        part autonomousConnectedStage {
            attribute record : EvolutionRecord {
                :>> stage = EvolutionStageKind::connectedAutonomousElectricMobility;
                :>> dominantEnergySource = "renewable grid electricity stored in solid-state battery";
                :>> primaryControlMethod = "software-defined autonomous driving with remote supervision";
                :>> societalCapabilityAdded = "on-demand shared mobility with continuous safety monitoring";
                :>> tailpipeEmission = 0.0;
            }
        }
    }

    part def SolidStateBatteryPack {
        attribute nominalCapacity : KilowattHour = 320.0;
        attribute usableCapacity : KilowattHour = 288.0;
        attribute nominalVoltage : VoltDC = 800.0;
        attribute maximumDischargePower : Kilowatt = 420.0;
        attribute maximumChargePower : Kilowatt = 250.0;
        attribute stateOfCharge : Percent = 80.0;
        attribute minimumOperatingTemperature : Celsius = -20.0;
        attribute maximumOperatingTemperature : Celsius = 55.0;

        port dcPort : DCPowerPort;
        port thermalPort : ThermalPort;
        port healthPort : HealthPort;
    }

    part def BatteryManagementSystem {
        attribute cellVoltageSamplingPeriod : Second = 0.05;
        attribute balancingCurrent : Ampere = 2.0;
        attribute minimumAllowedStateOfCharge : Percent = 10.0;
        attribute maximumAllowedStateOfCharge : Percent = 95.0;

        port batteryHealthOut : HealthPort;
        port networkPort : VehicleNetworkPort;
    }

    part def BidirectionalCharger {
        attribute maximumInputPower : Kilowatt = 250.0;
        attribute dcOutputVoltage : VoltDC = 800.0;
        attribute gridFrequencyHertz : Real = 50.0;
        port externalChargingPort : ChargingPort;
        port dcPort : DCPowerPort;
        port networkPort : VehicleNetworkPort;
    }

    part def TractionInverter {
        attribute continuousPower : Kilowatt = 260.0;
        attribute peakPower : Kilowatt = 420.0;
        attribute switchingFrequencyHertz : Real = 12000.0;
        port dcPort : DCPowerPort;
        port mechanicalCommandIn : ActuatorCommandPort;
        port leftMotorPort : MechanicalDrivePort;
        port rightMotorPort : MechanicalDrivePort;
        port thermalPort : ThermalPort;
        port networkPort : VehicleNetworkPort;
    }

    part def ElectricDriveMotor {
        attribute peakPower : Kilowatt = 210.0;
        attribute continuousPower : Kilowatt = 130.0;
        attribute maximumTorqueNewtonMeter : Real = 1650.0;
        attribute regenerativeBrakingAvailable : Boolean = true;

        port driveInput : WheelTorquePort;
        port wheelOutput : MechanicalDrivePort;
        port thermalPort : ThermalPort;
    }

    part def WheelModule {
        attribute tireRadius : Meter = 0.38;
        attribute maximumWheelSpeed : KilometerPerHour = 110.0;
        attribute brakeEnergyRecoveryLimit : Kilowatt = 90.0;

        port torqueInput : WheelTorquePort;
        port commandInput : ActuatorCommandPort;
        port healthPort : HealthPort;
    }

    part def SteeringBrakeActuator {
        attribute steeringResponseTime : Second = 0.20;
        attribute brakeResponseTime : Second = 0.12;
        attribute maximumServiceBrakePercent : Percent = 100.0;

        port commandPort : ActuatorCommandPort;
        port networkPort : VehicleNetworkPort;
        port healthPort : HealthPort;
    }

    part def ThermalManagementSystem {
        attribute coolantTargetTemperature : Celsius = 32.0;
        attribute maximumHeatRejection : Kilowatt = 55.0;
        attribute cabinHeatingPower : Kilowatt = 18.0;
        attribute cabinCoolingPower : Kilowatt = 20.0;

        port batteryThermalPort : ThermalPort;
        port inverterThermalPort : ThermalPort;
        port motorThermalPort : ThermalPort;
        port cabinThermalPort : ThermalPort;
        port healthPort : HealthPort;
    }

    part def LidarSensor {
        attribute horizontalFieldOfViewDegree : Real = 360.0;
        attribute detectionRange : Meter = 220.0;
        attribute updatePeriod : Second = 0.10;
        port dataOut : SensorDataPort;
        port networkPort : VehicleNetworkPort;
    }

    part def RadarSensor {
        attribute detectionRange : Meter = 250.0;
        attribute velocityAccuracyMeterPerSecond : Real = 0.15;
        attribute updatePeriod : Second = 0.05;
        port dataOut : SensorDataPort;
        port networkPort : VehicleNetworkPort;
    }

    part def CameraArray {
        attribute cameraCount : Integer = 12;
        attribute detectionRange : Meter = 120.0;
        attribute frameRateHertz : Real = 30.0;
        port dataOut : SensorDataPort;
        port networkPort : VehicleNetworkPort;
    }

    part def GnssImuUnit {
        attribute positionAccuracy : Meter = 0.15;
        attribute yawRateAccuracyDegreePerSecond : Real = 0.05;
        attribute updatePeriod : Second = 0.01;
        port dataOut : SensorDataPort;
        port networkPort : VehicleNetworkPort;
    }

    part def PerceptionComputer {
        attribute processingCapacity : ComputingRateTOPS = 900.0;
        attribute maximumSensorLatency : Second = 0.08;
        attribute objectConfidenceThreshold : Percent = 92.0;

        port lidarIn : PerceptionPort;
        port radarIn : PerceptionPort;
        port cameraIn : PerceptionPort;
        port localizationIn : PerceptionPort;
        port objectOut : PlanningPort;
        port networkPort : VehicleNetworkPort;
        port healthPort : HealthPort;
    }

    part def MotionPlanningComputer {
        attribute planningCycleTime : Second = 0.10;
        attribute maximumRouteDistance : Kilometer = 120.0;
        attribute comfortAccelerationLimitMeterPerSecondSquared : Real = 1.8;

        port planningPort : PlanningPort;
        port networkPort : VehicleNetworkPort;
        port healthPort : HealthPort;
    }

    part def VehicleControlComputer {
        attribute controlLoopPeriod : Second = 0.01;
        attribute maximumCommandLatency : Second = 0.03;
        attribute minimalRiskStopDecelerationMeterPerSecondSquared : Real = 3.0;

        port controlPort : ControlPort;
        port actuatorOut : ActuatorCommandPort;
        port networkPort : VehicleNetworkPort;
        port healthPort : HealthPort;
    }

    part def SafetySupervisor {
        attribute hazardMonitoringPeriod : Second = 0.02;
        attribute minimumObstacleClearance : Meter = 1.50;
        attribute maximumAllowedFaultReactionTime : Second = 0.50;
        attribute requiredSafetyIntegrity : SafetyIntegrityKind = SafetyIntegrityKind::failOperational;

        port healthInputs : HealthPort;
        port controlOverride : ActuatorCommandPort;
        port networkPort : VehicleNetworkPort;
        port supervisorHealth : HealthPort;
    }

    part def ConnectedMobilityGateway {
        attribute cellularDataRate : DataRateMbps = 300.0;
        attribute v2xDataRate : DataRateMbps = 27.0;
        attribute cloudLatencyBudget : Second = 0.25;
        attribute cybersecurityAuthenticationRequired : Boolean = true;

        port passengerServicePort : PassengerInterfacePort;
        port v2xPort : V2XPort;
        port vehicleNetworkPort : VehicleNetworkPort;
        port healthPort : HealthPort;
    }

    part def PassengerCabin {
        attribute seatedCapacity : PassengerCount = 12;
        attribute standingCapacity : PassengerCount = 0;
        attribute wheelchairSpaces : PassengerCount = 2;
        attribute cabinNoiseLimitDecibelA : Real = 62.0;
        attribute interiorTemperatureSetpoint : Celsius = 22.0;

        port passengerPort : PassengerInterfacePort;
        port thermalPort : ThermalPort;
        port healthPort : HealthPort;
    }

    part def AccessDoorSystem {
        attribute doorWidth : Meter = 1.20;
        attribute openingTime : Second = 2.50;
        attribute obstructionDetectionRange : Meter = 0.20;
        attribute state : PassengerAccessKind = PassengerAccessKind::closed;

        port passengerPort : PassengerInterfacePort;
        port commandPort : ActuatorCommandPort;
        port healthPort : HealthPort;
    }

    part def LowFloorChassis {
        attribute vehicleLength : Meter = 6.20;
        attribute vehicleWidth : Meter = 2.10;
        attribute vehicleHeight : Meter = 2.65;
        attribute curbMassKilogram : Real = 4200.0;
        attribute grossVehicleMassKilogram : Real = 6200.0;
        attribute turningRadius : Meter = 7.50;

        port frontLeftWheel : WheelTorquePort;
        port frontRightWheel : WheelTorquePort;
        port rearLeftWheel : WheelTorquePort;
        port rearRightWheel : WheelTorquePort;
        port healthPort : HealthPort;
    }

    part def AutonomousElectricMobilityPod {
        attribute productName : String = "Connected Autonomous Electric Mobility Pod";
        attribute primaryFunctionDescription : String =
            "Provide safe, on-demand, zero-tailpipe-emission passenger transportation by combining the technological evolution from mechanized transit, electrified propulsion, network connectivity, and autonomous driving.";
        attribute currentEvolutionStage : EvolutionStageKind = EvolutionStageKind::connectedAutonomousElectricMobility;
        attribute operationalMode : OperationalModeKind = OperationalModeKind::standby;
        attribute maximumOperatingSpeed : KilometerPerHour = 65.0;
        attribute nominalRange : Kilometer = 240.0;
        attribute tailpipeEmission : CO2GramPerKilometer = 0.0;
        attribute minimumSafeStateOfCharge : Percent = 15.0;

        port passengerService : PassengerInterfacePort;
        port chargeInterface : ChargingPort;
        port v2xInterface : V2XPort;

        part lineage : TechnologicalEvolutionLineage;
        part battery : SolidStateBatteryPack;
        part bms : BatteryManagementSystem;
        part charger : BidirectionalCharger;
        part inverter : TractionInverter;
        part leftMotor : ElectricDriveMotor;
        part rightMotor : ElectricDriveMotor;
        part frontLeftWheel : WheelModule;
        part frontRightWheel : WheelModule;
        part rearLeftWheel : WheelModule;
        part rearRightWheel : WheelModule;
        part steeringBrakeActuator : SteeringBrakeActuator;
        part thermalSystem : ThermalManagementSystem;
        part lidar : LidarSensor;
        part radar : RadarSensor;
        part cameras : CameraArray;
        part gnssImu : GnssImuUnit;
        part perception : PerceptionComputer;
        part planner : MotionPlanningComputer;
        part controller : VehicleControlComputer;
        part safetySupervisor : SafetySupervisor;
        part gateway : ConnectedMobilityGateway;
        part cabin : PassengerCabin;
        part doors : AccessDoorSystem;
        part chassis : LowFloorChassis;

        connect externalCharging to charger.externalChargingPort from chargeInterface;
        connect chargerDcToBattery to battery.dcPort from charger.dcPort;
        connect batteryDcToInverter to inverter.dcPort from battery.dcPort;

        connect inverterToLeftMotor to leftMotor.driveInput from inverter.leftMotorPort;
        connect inverterToRightMotor to rightMotor.driveInput from inverter.rightMotorPort;
        connect leftMotorToRearLeftWheel to rearLeftWheel.torqueInput from leftMotor.wheelOutput;
        connect rightMotorToRearRightWheel to rearRightWheel.torqueInput from rightMotor.wheelOutput;

        connect rearLeftWheelToChassis to chassis.rearLeftWheel from rearLeftWheel.torqueInput;
        connect rearRightWheelToChassis to chassis.rearRightWheel from rearRightWheel.torqueInput;
        connect frontLeftWheelToChassis to chassis.frontLeftWheel from frontLeftWheel.torqueInput;
        connect frontRightWheelToChassis to chassis.frontRightWheel from frontRightWheel.torqueInput;

        connect controllerToInverter to inverter.mechanicalCommandIn from controller.actuatorOut;
        connect controllerToSteeringBrake to steeringBrakeActuator.commandPort from controller.actuatorOut;
        connect supervisorOverrideToActuator to steeringBrakeActuator.commandPort from safetySupervisor.controlOverride;
        connect steeringBrakeToFrontLeft to frontLeftWheel.commandInput from steeringBrakeActuator.commandPort;
        connect steeringBrakeToFrontRight to frontRightWheel.commandInput from steeringBrakeActuator.commandPort;
        connect steeringBrakeToRearLeft to rearLeftWheel.commandInput from steeringBrakeActuator.commandPort;
        connect steeringBrakeToRearRight to rearRightWheel.commandInput from steeringBrakeActuator.commandPort;

        connect lidarToPerception to perception.lidarIn from lidar.dataOut;
        connect radarToPerception to perception.radarIn from radar.dataOut;
        connect camerasToPerception to perception.cameraIn from cameras.dataOut;
        connect localizationToPerception to perception.localizationIn from gnssImu.dataOut;
        connect perceptionToPlanner to planner.planningPort from perception.objectOut;
        connect plannerToController to controller.controlPort from planner.planningPort;

        connect passengerInterfaceToGateway to gateway.passengerServicePort from passengerService;
        connect passengerInterfaceToCabin to cabin.passengerPort from passengerService;
        connect passengerInterfaceToDoors to doors.passengerPort from passengerService;
        connect gatewayToV2X to gateway.v2xPort from v2xInterface;

        connect cabinThermalLoop to thermalSystem.cabinThermalPort from cabin.thermalPort;
        connect batteryThermalLoop to thermalSystem.batteryThermalPort from battery.thermalPort;
        connect inverterThermalLoop to thermalSystem.inverterThermalPort from inverter.thermalPort;
        connect leftMotorThermalLoop to thermalSystem.motorThermalPort from leftMotor.thermalPort;
        connect rightMotorThermalLoop to thermalSystem.motorThermalPort from rightMotor.thermalPort;

        connect bmsHealthToSupervisor to safetySupervisor.healthInputs from bms.batteryHealthOut;
        connect batteryHealthToSupervisor to safetySupervisor.healthInputs from battery.healthPort;
        connect controllerHealthToSupervisor to safetySupervisor.healthInputs from controller.healthPort;
        connect perceptionHealthToSupervisor to safetySupervisor.healthInputs from perception.healthPort;
        connect plannerHealthToSupervisor to safetySupervisor.healthInputs from planner.healthPort;
        connect chassisHealthToSupervisor to safetySupervisor.healthInputs from chassis.healthPort;

        connect bmsNetwork to gateway.vehicleNetworkPort from bms.networkPort;
        connect chargerNetwork to gateway.vehicleNetworkPort from charger.networkPort;
        connect inverterNetwork to gateway.vehicleNetworkPort from inverter.networkPort;
        connect sensorNetworkLidar to gateway.vehicleNetworkPort from lidar.networkPort;
        connect sensorNetworkRadar to gateway.vehicleNetworkPort from radar.networkPort;
        connect sensorNetworkCamera to gateway.vehicleNetworkPort from cameras.networkPort;
        connect sensorNetworkGnss to gateway.vehicleNetworkPort from gnssImu.networkPort;
        connect autonomyNetworkPerception to gateway.vehicleNetworkPort from perception.networkPort;
        connect autonomyNetworkPlanner to gateway.vehicleNetworkPort from planner.networkPort;
        connect autonomyNetworkController to gateway.vehicleNetworkPort from controller.networkPort;
        connect safetyNetwork to gateway.vehicleNetworkPort from safetySupervisor.networkPort;

        action provideAutonomousSharedMobility : ProvideAutonomousSharedMobility;
        state operatingLifecycle : AutonomousPodOperatingLifecycle;
    }

    action def ReceiveMobilityRequest {
        in item request : MobilityRequest;
        out item acceptedRequest : MobilityRequest;
    }

    action def ValidateEnergyAndHealth {
        in item request : MobilityRequest;
        in item health : HealthStatus;
        out item dispatchApproved : Boolean;
    }

    action def PlanAutonomousRoute {
        in item acceptedRequest : MobilityRequest;
        in item perceivedObjects : ObjectList;
        out item route : RoutePlan;
        out item trajectory : MotionTrajectory;
    }

    action def BoardPassengers {
        in item passenger : Passenger;
        in item route : RoutePlan;
        out item serviceStatus : PassengerServiceStatus;
    }

    action def ExecuteAutonomousDrive {
        in item route : RoutePlan;
        in item trajectory : MotionTrajectory;
        in item objects : ObjectList;
        out item command : VehicleCommand;
        out item health : HealthStatus;
    }

    action def ManageRegenerativeEnergy {
        in item command : VehicleCommand;
        inout item batteryEnergy : ElectricalEnergy;
        out item recoveredEnergy : ElectricalEnergy;
    }

    action def CompleteTripAndReport {
        in item route : RoutePlan;
        in item serviceStatus : PassengerServiceStatus;
        out item tripReport : DigitalMessage;
    }

    action def EnterMinimalRiskCondition {
        in item health : HealthStatus;
        out item stopCommand : VehicleCommand;
    }

    action def ProvideAutonomousSharedMobility {
        in item tripRequest : MobilityRequest;
        in item boardingPassenger : Passenger;
        in item sensorObjects : ObjectList;
        in item systemHealth : HealthStatus;
        out item serviceStatus : PassengerServiceStatus;
        out item tripReport : DigitalMessage;

        action receiveRequest : ReceiveMobilityRequest {
            in item request = tripRequest;
        }

        action validateReadiness : ValidateEnergyAndHealth {
            in item request = receiveRequest.acceptedRequest;
            in item health = systemHealth;
        }

        action planRoute : PlanAutonomousRoute {
            in item acceptedRequest = receiveRequest.acceptedRequest;
            in item perceivedObjects = sensorObjects;
        }

        action board : BoardPassengers {
            in item passenger = boardingPassenger;
            in item route = planRoute.route;
        }

        action drive : ExecuteAutonomousDrive {
            in item route = planRoute.route;
            in item trajectory = planRoute.trajectory;
            in item objects = sensorObjects;
        }

        action recoverEnergy : ManageRegenerativeEnergy {
            in item command = drive.command;
        }

        action report : CompleteTripAndReport {
            in item route = planRoute.route;
            in item serviceStatus = board.serviceStatus;
        }

        action minimalRisk : EnterMinimalRiskCondition {
            in item health = drive.health;
        }

        first start;
        then receiveRequest;
        then validateReadiness;

        if validateReadiness.dispatchApproved then planRoute;
        then board;
        then drive;
        then recoverEnergy;
        then report;
        then done;

        if not validateReadiness.dispatchApproved then minimalRisk;
        then done;

        bind serviceStatus = board.serviceStatus;
        bind tripReport = report.tripReport;
    }

    state def AutonomousPodOperatingLifecycle {
        in item requestedService : MobilityRequest;
        in item health : HealthStatus;
        out item activeMode : OperationalModeKind;

        state PoweredOff {
            entry action setModeOff {
                out item activeMode : OperationalModeKind = OperationalModeKind::poweredOff;
            }
        }

        state Charging {
            entry action enableCharger;
            do action replenishBattery;
            exit action lockChargingConnector;
        }

        state Standby {
            entry action runSelfTest;
            do action awaitMobilityRequest;
        }

        state Boarding {
            entry action openDoors;
            do action verifyPassengerCount;
            exit action closeAndLockDoors;
        }

        state AutonomousDriving {
            entry action engageAutonomousControl;
            do action followPlannedTrajectory;
            exit action storeTripTelemetry;
        }

        state RemoteAssistedDriving {
            entry action requestRemoteSupervisor;
            do action followApprovedRemoteGuidance;
        }

        state MinimalRiskStop {
            entry action commandControlledStop;
            do action activateHazardSignals;
            exit action notifyOperationsCenter;
        }

        state Maintenance {
            entry action isolateHighVoltage;
            do action diagnoseAndRepair;
        }

        transition initialToOff first PoweredOff;

        transition powerOn from PoweredOff to Standby
            accept DigitalMessage
            if health.autonomousControlAvailable and health.propulsionAvailable;

        transition requestCharge from Standby to Charging
            accept ElectricalPower
            if health.batteryStateOfCharge < 40.0;

        transition chargeComplete from Charging to Standby
            accept HealthStatus
            if health.batteryStateOfCharge >= 90.0;

        transition serviceAccepted from Standby to Boarding
            accept MobilityRequest
            if health.safetyIntegrity == SafetyIntegrityKind::nominal;

        transition boardingComplete from Boarding to AutonomousDriving
            accept PassengerServiceStatus
            if health.batteryStateOfCharge >= 15.0;

        transition remoteAssistanceNeeded from AutonomousDriving to RemoteAssistedDriving
            accept HealthStatus
            if health.safetyIntegrity == SafetyIntegrityKind::degraded;

        transition remoteResolved from RemoteAssistedDriving to AutonomousDriving
            accept HealthStatus
            if health.safetyIntegrity == SafetyIntegrityKind::nominal;

        transition hazardDetected from AutonomousDriving to MinimalRiskStop
            accept ObjectList
            if health.safetyIntegrity == SafetyIntegrityKind::failSafe;

        transition severeFault from RemoteAssistedDriving to MinimalRiskStop
            accept HealthStatus
            if not health.propulsionAvailable or not health.autonomousControlAvailable;

        transition tripFinished from AutonomousDriving to Standby
            accept PassengerServiceStatus;

        transition maintenanceRequested from Standby to Maintenance
            accept DigitalMessage;

        transition maintenanceComplete from Maintenance to PoweredOff
            accept HealthStatus;
    }

    requirement def PrimaryFunctionRequirement {
        subject pod : AutonomousElectricMobilityPod;

        doc /* The mobility pod shall provide high-level passenger transportation as its primary function by autonomously conveying passengers from a requested origin to a requested destination using electrified propulsion and connected digital coordination. */

        require constraint {
            pod.tailpipeEmission == 0.0 and
            pod.maximumOperatingSpeed >= 50.0 and
            pod.nominalRange >= 200.0
        }
    }

    requirement def TechnologicalEvolutionRequirement {
        subject pod : AutonomousElectricMobilityPod;

        doc /* The system shall embody technological evolution from human-directed mechanical mobility to software-defined, connected, autonomous, battery-electric mobility. */

        require constraint {
            pod.currentEvolutionStage == EvolutionStageKind::connectedAutonomousElectricMobility
        }
    }

    requirement def PassengerCapacityRequirement {
        subject pod : AutonomousElectricMobilityPod;

        doc /* The system shall transport a shared passenger group suitable for low-density urban service while supporting inclusive access. */

        require constraint {
            pod.cabin.seatedCapacity >= 10 and
            pod.cabin.wheelchairSpaces >= 1
        }
    }

    requirement def EnergyStorageRequirement {
        subject pod : AutonomousElectricMobilityPod;

        doc /* The battery system shall store sufficient usable energy to support urban service without tailpipe emissions. */

        require constraint {
            pod.battery.usableCapacity >= 250.0 and
            pod.battery.nominalVoltage >= 700.0 and
            pod.battery.maximumChargePower >= 200.0
        }
    }

    requirement def AutonomousSafetyRequirement {
        subject pod : AutonomousElectricMobilityPod;

        doc /* The autonomous control system shall maintain fail-operational supervision and command a minimal risk stop when safety integrity degrades below operational limits. */

        require constraint {
            pod.safetySupervisor.maximumAllowedFaultReactionTime <= 0.50 and
            pod.safetySupervisor.minimumObstacleClearance >= 1.0 and
            pod.controller.maximumCommandLatency <= 0.05
        }
    }

    requirement def ConnectivityRequirement {
        subject pod : AutonomousElectricMobilityPod;

        doc /* The system shall exchange authenticated mobility service, vehicle-to-everything, telemetry, and remote supervision messages over a connected gateway. */

        require constraint {
            pod.gateway.cybersecurityAuthenticationRequired == true and
            pod.gateway.cloudLatencyBudget <= 0.30 and
            pod.gateway.cellularDataRate >= 100.0
        }
    }

    requirement def ThermalRequirement {
        subject pod : AutonomousElectricMobilityPod;

        doc /* The thermal system shall regulate battery, inverter, motor, and cabin heat to maintain safety, efficiency, and passenger comfort. */

        require constraint {
            pod.thermalSystem.maximumHeatRejection >= 50.0 and
            pod.thermalSystem.coolantTargetTemperature <= 40.0 and
            pod.cabin.interiorTemperatureSetpoint >= 18.0 and
            pod.cabin.interiorTemperatureSetpoint <= 25.0
        }
    }

    requirement def SensorCoverageRequirement {
        subject pod : AutonomousElectricMobilityPod;

        doc /* The sensor suite shall provide complementary long-range, full-surround, camera, radar, lidar, and localization perception for autonomous urban operation. */

        require constraint {
            pod.lidar.detectionRange >= 200.0 and
            pod.radar.detectionRange >= 200.0 and
            pod.cameras.cameraCount >= 8 and
            pod.gnssImu.positionAccuracy <= 0.25
        }
    }

    satisfy PrimaryFunctionRequirement by AutonomousElectricMobilityPod;
    satisfy TechnologicalEvolutionRequirement by AutonomousElectricMobilityPod::lineage;
    satisfy PassengerCapacityRequirement by AutonomousElectricMobilityPod::cabin;
    satisfy EnergyStorageRequirement by AutonomousElectricMobilityPod::battery;
    satisfy AutonomousSafetyRequirement by AutonomousElectricMobilityPod::safetySupervisor;
    satisfy ConnectivityRequirement by AutonomousElectricMobilityPod::gateway;
    satisfy ThermalRequirement by AutonomousElectricMobilityPod::thermalSystem;
    satisfy SensorCoverageRequirement by AutonomousElectricMobilityPod::lidar;
    satisfy SensorCoverageRequirement by AutonomousElectricMobilityPod::radar;
    satisfy SensorCoverageRequirement by AutonomousElectricMobilityPod::cameras;
    satisfy SensorCoverageRequirement by AutonomousElectricMobilityPod::gnssImu;

    part urbanMobilityPod : AutonomousElectricMobilityPod {
        :>> productName = "EvoTransit-A1 Autonomous Electric Mobility Pod";
        :>> operationalMode = OperationalModeKind::standby;
        :>> maximumOperatingSpeed = 65.0;
        :>> nominalRange = 240.0;
        :>> tailpipeEmission = 0.0;
    }
}
