package UnmannedAerialVehicleSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    alias kg for SI::kilogram;
    alias m for SI::metre;
    alias s for SI::second;
    alias rad for SI::radian;
    alias deg for SI::degree;
    alias N for SI::newton;
    alias W for SI::watt;
    alias V for SI::volt;
    alias A for SI::ampere;
    alias Hz for SI::hertz;
    alias Pa for SI::pascal;

    enum def FlightMode {
        enum idle;
        enum preFlight;
        enum takeoff;
        enum climb;
        enum cruise;
        enum missionExecution;
        enum returnToLaunch;
        enum landing;
        enum emergency;
        enum shutdown;
    }

    enum def NavigationFixQuality {
        enum noFix;
        enum deadReckoning;
        enum twoDimensionalFix;
        enum threeDimensionalFix;
        enum rtkFloat;
        enum rtkFixed;
    }

    enum def CommandKind {
        enum arm;
        enum disarm;
        enum uploadMission;
        enum startMission;
        enum pauseMission;
        enum resumeMission;
        enum returnHome;
        enum landNow;
        enum emergencyStop;
    }

    item def ElectricalPower {
        attribute voltage :> ISQ::voltage;
        attribute current :> ISQ::electricCurrent;
        attribute power :> ISQ::power;
    }

    item def ControlCommand {
        attribute kind : CommandKind;
        attribute sequenceNumber : Integer;
        attribute issuedTime :> ISQ::time;
        attribute validUntil :> ISQ::time;
    }

    item def Telemetry {
        attribute timeStamp :> ISQ::time;
        attribute latitudeDeg : Real;
        attribute longitudeDeg : Real;
        attribute altitudeM :> ISQ::length;
        attribute groundSpeed :> ISQ::speed;
        attribute verticalSpeed :> ISQ::speed;
        attribute batteryStateOfCharge : Real;
        attribute flightMode : FlightMode;
        attribute fixQuality : NavigationFixQuality;
    }

    item def NavigationEstimate {
        attribute latitudeDeg : Real;
        attribute longitudeDeg : Real;
        attribute altitudeM :> ISQ::length;
        attribute roll :> ISQ::planeAngle;
        attribute pitch :> ISQ::planeAngle;
        attribute yaw :> ISQ::planeAngle;
        attribute horizontalAccuracy :> ISQ::length;
        attribute verticalAccuracy :> ISQ::length;
        attribute fixQuality : NavigationFixQuality;
    }

    item def MissionPlan {
        attribute missionId : String;
        attribute waypointCount : Integer;
        attribute cruiseAltitude :> ISQ::length;
        attribute cruiseSpeed :> ISQ::speed;
        attribute loiterTimeAtTarget :> ISQ::time;
        attribute returnHomeOnCompletion : Boolean;
    }

    item def RotorThrustCommand {
        attribute frontLeftThrust :> ISQ::force;
        attribute frontRightThrust :> ISQ::force;
        attribute rearLeftThrust :> ISQ::force;
        attribute rearRightThrust :> ISQ::force;
    }

    item def SensorData {
        attribute accelerationX :> ISQ::acceleration;
        attribute accelerationY :> ISQ::acceleration;
        attribute accelerationZ :> ISQ::acceleration;
        attribute angularRateRoll : Real;
        attribute angularRatePitch : Real;
        attribute angularRateYaw : Real;
        attribute barometricPressure :> ISQ::pressure;
        attribute gnssLatitudeDeg : Real;
        attribute gnssLongitudeDeg : Real;
        attribute gnssAltitudeM :> ISQ::length;
        attribute fixQuality : NavigationFixQuality;
    }

    item def PayloadData {
        attribute collectionTime :> ISQ::time;
        attribute targetLatitudeDeg : Real;
        attribute targetLongitudeDeg : Real;
        attribute imageFrameCount : Integer;
        attribute storageUsedMB : Real;
    }

    port def PowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def PowerOutputPort {
        out item powerOut : ElectricalPower;
    }

    port def CommandInputPort {
        in item command : ControlCommand;
        in item mission : MissionPlan;
    }

    port def TelemetryOutputPort {
        out item telemetry : Telemetry;
    }

    port def SensorOutputPort {
        out item sensorData : SensorData;
    }

    port def NavigationOutputPort {
        out item navigationEstimate : NavigationEstimate;
    }

    port def RotorCommandInputPort {
        in item thrustCommand : RotorThrustCommand;
    }

    port def PayloadOutputPort {
        out item payloadData : PayloadData;
    }

    port def PayloadControlPort {
        in item command : ControlCommand;
        out item payloadData : PayloadData;
    }

    requirement def PrimaryFunctionRequirement {
        subject uav : UAVSystem;
        require constraint {
            uav.canExecuteMission == true
        }
        doc /* The unmanned aerial vehicle shall autonomously fly a planned mission route, collect payload data, transmit telemetry, and return safely without onboard human crew. */
    }

    requirement def EnduranceRequirement {
        subject uav : UAVSystem;
        require constraint {
            uav.maxFlightTime >= 1800 [s]
        }
        doc /* The UAV shall provide at least 30 minutes of powered flight under nominal mission payload. */
    }

    requirement def TelemetryRequirement {
        subject radio : CommunicationsSubsystem;
        require constraint {
            radio.telemetryUpdateRate >= 2 [Hz]
        }
        doc /* The UAV shall transmit navigation, health, and mission status telemetry at no less than 2 Hz during flight. */
    }

    requirement def NavigationAccuracyRequirement {
        subject navigation : NavigationSubsystem;
        require constraint {
            navigation.nominalHorizontalAccuracy <= 2.5 [m]
        }
        doc /* The UAV navigation subsystem shall estimate horizontal position with nominal accuracy of 2.5 meters or better. */
    }

    requirement def SafeReturnRequirement {
        subject controller : FlightControlComputer;
        require constraint {
            controller.returnHomeEnabled == true
        }
        doc /* The UAV shall initiate return-to-launch when battery energy is insufficient to complete the active mission with reserve. */
    }

    part def BatteryPack {
        attribute nominalVoltage :> ISQ::voltage = 22.2 [V];
        attribute capacityAh : Real = 12.0;
        attribute storedEnergy :> ISQ::energy = 958000 [J];
        attribute stateOfCharge : Real = 1.0;
        attribute minimumReserveStateOfCharge : Real = 0.20;
        port powerOut : PowerOutputPort;
    }

    part def PowerDistributionUnit {
        attribute maxContinuousCurrent :> ISQ::electricCurrent = 80 [A];
        attribute regulatedBusVoltage :> ISQ::voltage = 12 [V];
        port mainPowerIn : PowerInputPort;
        port avionicsPowerOut : PowerOutputPort;
        port propulsionPowerOut : PowerOutputPort;
        port payloadPowerOut : PowerOutputPort;
    }

    part def MotorController {
        attribute maxPhaseCurrent :> ISQ::electricCurrent = 35 [A];
        port powerIn : PowerInputPort;
        port commandIn : RotorCommandInputPort;
    }

    part def RotorAssembly {
        attribute rotorDiameter :> ISQ::length = 0.38 [m];
        attribute maxStaticThrust :> ISQ::force = 18 [N];
        attribute nominalSpeed : Real = 5200;
        port powerIn : PowerInputPort;
        port commandIn : RotorCommandInputPort;
    }

    part def PropulsionSubsystem {
        attribute totalMaxThrust :> ISQ::force = 72 [N];
        attribute hoverPower :> ISQ::power = 460 [W];

        port powerIn : PowerInputPort;
        port rotorCommandIn : RotorCommandInputPort;

        part frontLeftMotorController : MotorController;
        part frontRightMotorController : MotorController;
        part rearLeftMotorController : MotorController;
        part rearRightMotorController : MotorController;

        part frontLeftRotor : RotorAssembly;
        part frontRightRotor : RotorAssembly;
        part rearLeftRotor : RotorAssembly;
        part rearRightRotor : RotorAssembly;

        connect powerIn to frontLeftMotorController.powerIn;
        connect powerIn to frontRightMotorController.powerIn;
        connect powerIn to rearLeftMotorController.powerIn;
        connect powerIn to rearRightMotorController.powerIn;

        connect rotorCommandIn to frontLeftMotorController.commandIn;
        connect rotorCommandIn to frontRightMotorController.commandIn;
        connect rotorCommandIn to rearLeftMotorController.commandIn;
        connect rotorCommandIn to rearRightMotorController.commandIn;

        connect frontLeftMotorController.commandIn to frontLeftRotor.commandIn;
        connect frontRightMotorController.commandIn to frontRightRotor.commandIn;
        connect rearLeftMotorController.commandIn to rearLeftRotor.commandIn;
        connect rearRightMotorController.commandIn to rearRightRotor.commandIn;
    }

    part def InertialMeasurementUnit {
        attribute sampleRate :> ISQ::frequency = 200 [Hz];
        attribute gyroBiasStability : Real = 4.0;
        port sensorOut : SensorOutputPort;
        port powerIn : PowerInputPort;
    }

    part def GNSSReceiver {
        attribute updateRate :> ISQ::frequency = 10 [Hz];
        attribute coldStartTime :> ISQ::time = 35 [s];
        attribute fixQuality : NavigationFixQuality = NavigationFixQuality::noFix;
        port sensorOut : SensorOutputPort;
        port powerIn : PowerInputPort;
    }

    part def BarometricAltimeter {
        attribute pressureResolution :> ISQ::pressure = 1 [Pa];
        attribute altitudeResolution :> ISQ::length = 0.1 [m];
        port sensorOut : SensorOutputPort;
        port powerIn : PowerInputPort;
    }

    part def NavigationSubsystem {
        attribute nominalHorizontalAccuracy :> ISQ::length = 2.0 [m];
        attribute nominalVerticalAccuracy :> ISQ::length = 3.0 [m];
        port imuIn : SensorOutputPort;
        port gnssIn : SensorOutputPort;
        port barometerIn : SensorOutputPort;
        port navigationOut : NavigationOutputPort;
        port powerIn : PowerInputPort;
    }

    part def CommunicationsSubsystem {
        attribute commandLinkRange :> ISQ::length = 5000 [m];
        attribute telemetryUpdateRate :> ISQ::frequency = 5 [Hz];
        attribute linkAvailable : Boolean = true;
        port commandIn : CommandInputPort;
        port telemetryOut : TelemetryOutputPort;
        port powerIn : PowerInputPort;
    }

    part def PayloadSubsystem {
        attribute sensorMass :> ISQ::mass = 0.45 [kg];
        attribute imageResolutionMegapixels : Real = 20.0;
        attribute storageCapacityGB : Real = 128.0;
        attribute activePower :> ISQ::power = 14 [W];
        port payloadControl : PayloadControlPort;
        port payloadDataOut : PayloadOutputPort;
        port powerIn : PowerInputPort;
    }

    part def Airframe {
        attribute emptyMass :> ISQ::mass = 3.2 [kg];
        attribute maximumTakeoffMass :> ISQ::mass = 5.5 [kg];
        attribute armSpan :> ISQ::length = 0.72 [m];
        attribute payloadBayVolumeLiters : Real = 2.4;
    }

    part def FlightControlComputer {
        attribute processorFrequency :> ISQ::frequency = 1.4e9 [Hz];
        attribute controlLoopRate :> ISQ::frequency = 400 [Hz];
        attribute returnHomeEnabled : Boolean = true;
        attribute activeMode : FlightMode = FlightMode::idle;
        attribute commandedAltitude :> ISQ::length = 0 [m];
        attribute commandedSpeed :> ISQ::speed = 0 [m/s];
        attribute lowBatteryThreshold : Real = 0.25;

        port powerIn : PowerInputPort;
        port commandIn : CommandInputPort;
        port navigationIn : NavigationOutputPort;
        port rotorCommandOut : RotorCommandInputPort;
        port telemetryOut : TelemetryOutputPort;
        port payloadControl : PayloadControlPort;

        action def ComputeRotorCommands {
            in nav : NavigationEstimate;
            in mission : MissionPlan;
            out command : RotorThrustCommand;
        }

        action def GenerateTelemetry {
            in nav : NavigationEstimate;
            in mode : FlightMode;
            out telemetry : Telemetry;
        }

        state def FlightStateMachine {
            state idle;
            state preFlight;
            state takeoff;
            state climb;
            state cruise;
            state missionExecution;
            state returnToLaunch;
            state landing;
            state emergency;
            state shutdown;

            transition idle_to_preFlight
                first idle
                then preFlight
                accept ControlCommand
                if command.kind == CommandKind::arm;

            transition preFlight_to_takeoff
                first preFlight
                then takeoff
                accept ControlCommand
                if command.kind == CommandKind::startMission;

            transition takeoff_to_climb
                first takeoff
                then climb
                if commandedAltitude > 2 [m];

            transition climb_to_cruise
                first climb
                then cruise
                if commandedAltitude >= 30 [m];

            transition cruise_to_missionExecution
                first cruise
                then missionExecution
                if command.kind == CommandKind::resumeMission;

            transition missionExecution_to_returnToLaunch
                first missionExecution
                then returnToLaunch
                if command.kind == CommandKind::returnHome;

            transition missionExecution_to_returnToLaunch_lowBattery
                first missionExecution
                then returnToLaunch
                if lowBatteryThreshold >= 0.25;

            transition returnToLaunch_to_landing
                first returnToLaunch
                then landing
                if commandedAltitude <= 10 [m];

            transition landing_to_shutdown
                first landing
                then shutdown
                if commandedAltitude == 0 [m];

            transition any_to_emergency
                first idle
                then emergency
                accept ControlCommand
                if command.kind == CommandKind::emergencyStop;

            transition emergency_to_shutdown
                first emergency
                then shutdown
                accept ControlCommand
                if command.kind == CommandKind::disarm;
        }
    }

    part def UAVSystem {
        attribute systemName : String = "Autonomous Survey UAV";
        attribute canExecuteMission : Boolean = true;
        attribute maximumTakeoffMass :> ISQ::mass = 5.5 [kg];
        attribute maxFlightTime :> ISQ::time = 2100 [s];
        attribute maximumCruiseSpeed :> ISQ::speed = 16 [m/s];
        attribute nominalCruiseSpeed :> ISQ::speed = 10 [m/s];
        attribute operationalCeiling :> ISQ::length = 120 [m];
        attribute primaryFunction : String = "Autonomously navigate a planned route, collect aerial payload data, transmit telemetry, and return safely to launch.";

        port operatorCommandIn : CommandInputPort;
        port groundTelemetryOut : TelemetryOutputPort;

        part airframe : Airframe;
        part battery : BatteryPack;
        part powerDistribution : PowerDistributionUnit;
        part propulsion : PropulsionSubsystem;
        part flightComputer : FlightControlComputer;
        part imu : InertialMeasurementUnit;
        part gnss : GNSSReceiver;
        part barometer : BarometricAltimeter;
        part navigation : NavigationSubsystem;
        part communications : CommunicationsSubsystem;
        part payload : PayloadSubsystem;

        connect battery.powerOut to powerDistribution.mainPowerIn;
        connect powerDistribution.propulsionPowerOut to propulsion.powerIn;
        connect powerDistribution.avionicsPowerOut to flightComputer.powerIn;
        connect powerDistribution.avionicsPowerOut to imu.powerIn;
        connect powerDistribution.avionicsPowerOut to gnss.powerIn;
        connect powerDistribution.avionicsPowerOut to barometer.powerIn;
        connect powerDistribution.avionicsPowerOut to navigation.powerIn;
        connect powerDistribution.avionicsPowerOut to communications.powerIn;
        connect powerDistribution.payloadPowerOut to payload.powerIn;

        connect operatorCommandIn to communications.commandIn;
        connect communications.commandIn to flightComputer.commandIn;

        connect imu.sensorOut to navigation.imuIn;
        connect gnss.sensorOut to navigation.gnssIn;
        connect barometer.sensorOut to navigation.barometerIn;
        connect navigation.navigationOut to flightComputer.navigationIn;

        connect flightComputer.rotorCommandOut to propulsion.rotorCommandIn;
        connect flightComputer.payloadControl to payload.payloadControl;

        connect flightComputer.telemetryOut to communications.telemetryOut;
        connect communications.telemetryOut to groundTelemetryOut;

        satisfy PrimaryFunctionRequirement by UAVSystem;
        satisfy EnduranceRequirement by UAVSystem;
        satisfy TelemetryRequirement by communications;
        satisfy NavigationAccuracyRequirement by navigation;
        satisfy SafeReturnRequirement by flightComputer;
    }

    action def ExecuteAerialMission {
        in mission : MissionPlan;
        in command : ControlCommand;
        out telemetry : Telemetry;
        out collectedData : PayloadData;

        first start;
        then validateMission;
        then armVehicle;
        then takeOff;
        then navigateWaypoints;
        then collectPayloadData;
        then transmitTelemetry;
        then returnToLaunch;
        then land;
        then disarm;
        then done;

        action validateMission;
        action armVehicle;
        action takeOff;
        action navigateWaypoints;
        action collectPayloadData;
        action transmitTelemetry;
        action returnToLaunch;
        action land;
        action disarm;
    }

    requirement primarySystemCapability : PrimaryFunctionRequirement {
        subject uav = system;
    }

    requirement enduranceCapability : EnduranceRequirement {
        subject uav = system;
    }

    requirement telemetryCapability : TelemetryRequirement {
        subject radio = system.communications;
    }

    requirement navigationCapability : NavigationAccuracyRequirement {
        subject navigation = system.navigation;
    }

    requirement safeReturnCapability : SafeReturnRequirement {
        subject controller = system.flightComputer;
    }

    part system : UAVSystem;

    action missionBehavior : ExecuteAerialMission {
        in mission = MissionPlan {
            missionId = "SURVEY-ALPHA";
            waypointCount = 12;
            cruiseAltitude = 60 [m];
            cruiseSpeed = 10 [m/s];
            loiterTimeAtTarget = 30 [s];
            returnHomeOnCompletion = true;
        }
    }
}