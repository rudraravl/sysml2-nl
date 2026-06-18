package StandingWheelchairSystemModel {

    import ScalarValues::*;

    package ValueTypesAndItems {

        attribute def Length_m :> Real {
            doc "Length value expressed in metres (m)."
            attribute unitSymbol : String = "m";
        }

        attribute def Mass_kg :> Real {
            doc "Mass value expressed in kilograms (kg)."
            attribute unitSymbol : String = "kg";
        }

        attribute def Speed_mps :> Real {
            doc "Linear speed expressed in metres per second (m/s)."
            attribute unitSymbol : String = "m/s";
        }

        attribute def Distance_m :> Real {
            doc "Travel distance expressed in metres (m)."
            attribute unitSymbol : String = "m";
        }

        attribute def Time_s :> Real {
            doc "Time duration expressed in seconds (s)."
            attribute unitSymbol : String = "s";
        }

        attribute def Angle_deg :> Real {
            doc "Planar angle expressed in degrees (deg)."
            attribute unitSymbol : String = "deg";
        }

        attribute def Torque_Nm :> Real {
            doc "Torque expressed in newton metres (N*m)."
            attribute unitSymbol : String = "N*m";
        }

        attribute def Force_N :> Real {
            doc "Force expressed in newtons (N)."
            attribute unitSymbol : String = "N";
        }

        attribute def ElectricPotential_V :> Real {
            doc "Electric potential expressed in volts (V)."
            attribute unitSymbol : String = "V";
        }

        attribute def ElectricCurrent_A :> Real {
            doc "Electric current expressed in amperes (A)."
            attribute unitSymbol : String = "A";
        }

        attribute def ElectricCharge_Ah :> Real {
            doc "Battery capacity expressed in ampere-hours (A*h)."
            attribute unitSymbol : String = "A*h";
        }

        attribute def Power_W :> Real {
            doc "Power expressed in watts (W)."
            attribute unitSymbol : String = "W";
        }

        attribute def Energy_Wh :> Real {
            doc "Energy expressed in watt-hours (W*h)."
            attribute unitSymbol : String = "W*h";
        }

        attribute def Acceleration_mps2 :> Real {
            doc "Acceleration expressed in metres per second squared (m/s^2)."
            attribute unitSymbol : String = "m/s^2";
        }

        attribute def Pressure_kPa :> Real {
            doc "Pressure expressed in kilopascals (kPa)."
            attribute unitSymbol : String = "kPa";
        }

        attribute def Percentage :> Real {
            doc "Percentage value expressed as percent (%)."
            attribute unitSymbol : String = "%";
        }

        attribute def Temperature_degC :> Real {
            doc "Temperature expressed in degrees Celsius (degC)."
            attribute unitSymbol : String = "degC";
        }

        item def ElectricalPowerFlow {
            attribute voltage : ElectricPotential_V;
            attribute current : ElectricCurrent_A;
            attribute availablePower : Power_W;
        }

        item def ChargingPowerFlow :> ElectricalPowerFlow {
            attribute chargerLimitedCurrent : ElectricCurrent_A;
        }

        item def MotorDrivePowerFlow :> ElectricalPowerFlow {
            attribute commandedPower : Power_W;
        }

        item def HumanControlCommand {
            attribute powerOnRequested : Boolean;
            attribute powerOffRequested : Boolean;
            attribute forwardCommand : Percentage;
            attribute turnCommand : Percentage;
            attribute standCommand : Boolean;
            attribute lowerCommand : Boolean;
            attribute hornCommand : Boolean;
            attribute speedModeStandingRequested : Boolean;
        }

        item def ControllerCommand {
            attribute leftWheelPowerCommand : Percentage;
            attribute rightWheelPowerCommand : Percentage;
            attribute liftActuatorCommand : Percentage;
            attribute brakeReleaseCommand : Boolean;
            attribute standingModeEnabled : Boolean;
            attribute audibleAlertCommand : Boolean;
        }

        item def SensorPacket {
            attribute seatOccupied : Boolean;
            attribute lapBeltLatched : Boolean;
            attribute chestSupportLocked : Boolean;
            attribute kneeBlockLocked : Boolean;
            attribute footPlateLoaded : Boolean;
            attribute leftWheelSpeed : Speed_mps;
            attribute rightWheelSpeed : Speed_mps;
            attribute liftAngle : Angle_deg;
            attribute framePitch : Angle_deg;
            attribute frameRoll : Angle_deg;
            attribute batteryStateOfCharge : Percentage;
            attribute batteryTemperature : Temperature_degC;
            attribute motorControllerTemperature : Temperature_degC;
            attribute obstacleDistanceFront : Distance_m;
            attribute obstacleDistanceRear : Distance_m;
        }

        item def MobilityStatus {
            attribute powered : Boolean;
            attribute faultActive : Boolean;
            attribute seatedMode : Boolean;
            attribute standingMode : Boolean;
            attribute drivingEnabled : Boolean;
            attribute brakingApplied : Boolean;
            attribute currentSpeed : Speed_mps;
            attribute currentLiftAngle : Angle_deg;
            attribute remainingRange : Distance_m;
        }

        item def MechanicalDriveLoad {
            attribute wheelTorque : Torque_Nm;
            attribute wheelSpeed : Speed_mps;
            attribute tractionForce : Force_N;
        }

        item def LinearActuationLoad {
            attribute actuatorForce : Force_N;
            attribute actuatorExtension : Length_m;
            attribute liftAngle : Angle_deg;
        }

        item def OccupantLoad {
            attribute occupantMass : Mass_kg;
            attribute seatedVerticalLoad : Force_N;
            attribute standingVerticalLoad : Force_N;
            attribute chestSupportForce : Force_N;
            attribute kneeSupportForce : Force_N;
            attribute footPlateForce : Force_N;
        }

        item def ServiceDiagnosticData {
            attribute faultCode : Integer;
            attribute batteryCycleCount : Integer;
            attribute totalDistanceTravelled : Distance_m;
            attribute liftCycleCount : Integer;
            attribute lastMeasuredStandingAngle : Angle_deg;
            attribute lastMeasuredStateOfCharge : Percentage;
        }

        item def AudibleAlert {
            attribute alertActive : Boolean;
            attribute soundPressureLevel : Pressure_kPa;
        }
    }

    package Interfaces {

        import ValueTypesAndItems::*;

        port def ElectricalPowerOutPort {
            out item power : ElectricalPowerFlow;
        }

        port def ElectricalPowerInPort {
            in item power : ElectricalPowerFlow;
        }

        port def ChargingPowerInPort {
            in item chargingPower : ChargingPowerFlow;
        }

        port def MotorDrivePowerOutPort {
            out item motorPower : MotorDrivePowerFlow;
        }

        port def MotorDrivePowerInPort {
            in item motorPower : MotorDrivePowerFlow;
        }

        port def HumanCommandInPort {
            in item command : HumanControlCommand;
        }

        port def ControlCommandOutPort {
            out item command : ControllerCommand;
        }

        port def ControlCommandInPort {
            in item command : ControllerCommand;
        }

        port def SensorDataOutPort {
            out item sensors : SensorPacket;
        }

        port def SensorDataInPort {
            in item sensors : SensorPacket;
        }

        port def MobilityStatusOutPort {
            out item status : MobilityStatus;
        }

        port def MobilityStatusInPort {
            in item status : MobilityStatus;
        }

        port def MechanicalDriveOutPort {
            out item driveLoad : MechanicalDriveLoad;
        }

        port def MechanicalDriveInPort {
            in item driveLoad : MechanicalDriveLoad;
        }

        port def LiftMechanicalOutPort {
            out item liftLoad : LinearActuationLoad;
        }

        port def LiftMechanicalInPort {
            in item liftLoad : LinearActuationLoad;
        }

        port def OccupantSupportPort {
            inout item load : OccupantLoad;
        }

        port def DiagnosticOutPort {
            out item diagnostics : ServiceDiagnosticData;
        }

        port def AlertOutPort {
            out item alert : AudibleAlert;
        }
    }

    package Structure {

        import ValueTypesAndItems::*;
        import Interfaces::*;

        part def UserOccupant {
            attribute bodyMass : Mass_kg = 90.0;
            attribute hipToShoulderHeight : Length_m = 0.62;
            attribute seatedHipWidth : Length_m = 0.42;
            attribute lowerLegLength : Length_m = 0.46;
            port bodyInterface : OccupantSupportPort;
            port handCommandInterface : HumanCommandInPort;
        }

        part def ChassisFrame {
            attribute overallLength : Length_m = 1.12;
            attribute overallWidth : Length_m = 0.64;
            attribute groundClearance : Length_m = 0.065;
            attribute wheelBase : Length_m = 0.76;
            attribute trackWidth : Length_m = 0.57;
            attribute structuralMass : Mass_kg = 24.0;
            attribute staticTipAngleForward : Angle_deg = 15.0;
            attribute staticTipAngleSide : Angle_deg = 12.0;
            attribute ratedStructuralLoad : Mass_kg = 160.0;
            port seatMount : LiftMechanicalInPort;
            port driveReaction : MechanicalDriveInPort;
        }

        part def SeatingSystem {
            attribute seatWidth : Length_m = 0.46;
            attribute seatDepth : Length_m = 0.43;
            attribute backrestHeight : Length_m = 0.55;
            attribute seatCushionPressure : Pressure_kPa = 6.0;
            attribute seatedAngle : Angle_deg = 4.0;
            attribute maximumOccupantMass : Mass_kg = 120.0;
            port occupantPort : OccupantSupportPort;
            port liftAttachment : LiftMechanicalInPort;
        }

        part def BodySupportSystem {
            attribute lapBeltRatedForce : Force_N = 2500.0;
            attribute chestPadRatedForce : Force_N = 1200.0;
            attribute kneeBlockRatedForce : Force_N = 1500.0;
            attribute footPlateRatedForce : Force_N = 1800.0;
            attribute footPlateWidth : Length_m = 0.42;
            attribute chestSupportHeightRange : Length_m = 0.30;
            attribute kneeBlockHeightRange : Length_m = 0.18;
            attribute lockedForStanding : Boolean = false;
            port occupantPort : OccupantSupportPort;
            port sensorOutput : SensorDataOutPort;
        }

        part def LinearActuator {
            attribute peakForce : Force_N = 4500.0;
            attribute continuousForce : Force_N = 2800.0;
            attribute strokeLength : Length_m = 0.30;
            attribute maximumExtensionSpeed : Speed_mps = 0.018;
            attribute ratedVoltage : ElectricPotential_V = 24.0;
            port electricalInput : MotorDrivePowerInPort;
            port mechanicalOutput : LiftMechanicalOutPort;
        }

        part def StandingLinkage {
            attribute lowerPivotHeight : Length_m = 0.18;
            attribute upperPivotHeightSeated : Length_m = 0.48;
            attribute upperPivotHeightStanding : Length_m = 0.92;
            attribute maximumStandingAngle : Angle_deg = 87.0;
            attribute minimumSeatedAngle : Angle_deg = 4.0;
            attribute linkageMass : Mass_kg = 8.0;
            port actuatorInput : LiftMechanicalInPort;
            port seatOutput : LiftMechanicalOutPort;
            port frameReaction : LiftMechanicalOutPort;
        }

        part def StandingLiftMechanism {
            attribute currentLiftAngle : Angle_deg = 4.0;
            attribute targetStandingAngle : Angle_deg = 84.0;
            attribute targetSeatedAngle : Angle_deg = 4.0;
            attribute nominalTransitionTime : Time_s = 16.0;
            attribute maximumTransitionTime : Time_s = 22.0;
            attribute liftLocked : Boolean = true;
            part leftActuator : LinearActuator;
            part rightActuator : LinearActuator;
            part linkage : StandingLinkage;
            port electricalInput : MotorDrivePowerInPort;
            port controlInput : ControlCommandInPort;
            port sensorOutput : SensorDataOutPort;
            port seatOutput : LiftMechanicalOutPort;
            port frameReaction : LiftMechanicalOutPort;

            connection liftPowerToLeftActuator connect electricalInput to leftActuator.electricalInput;
            connection liftPowerToRightActuator connect electricalInput to rightActuator.electricalInput;
            connection leftActuatorToLinkage connect leftActuator.mechanicalOutput to linkage.actuatorInput;
            connection rightActuatorToLinkage connect rightActuator.mechanicalOutput to linkage.actuatorInput;
            connection linkageToSeat connect linkage.seatOutput to seatOutput;
            connection linkageToFrame connect linkage.frameReaction to frameReaction;
        }

        part def DriveWheel {
            attribute diameter : Length_m = 0.34;
            attribute width : Length_m = 0.065;
            attribute rollingRadius : Length_m = 0.17;
            attribute maximumTractionForce : Force_N = 420.0;
            attribute tirePressure : Pressure_kPa = 240.0;
            port axleInput : MechanicalDriveInPort;
        }

        part def CasterWheel {
            attribute diameter : Length_m = 0.15;
            attribute width : Length_m = 0.035;
            attribute swivelOffset : Length_m = 0.035;
            attribute maximumLoad : Force_N = 700.0;
            port frameLoad : MechanicalDriveInPort;
        }

        part def WheelMotor {
            attribute ratedVoltage : ElectricPotential_V = 24.0;
            attribute ratedPower : Power_W = 350.0;
            attribute peakTorque : Torque_Nm = 55.0;
            attribute continuousTorque : Torque_Nm = 18.0;
            attribute maximumWheelSpeed : Speed_mps = 1.7;
            port electricalInput : MotorDrivePowerInPort;
            port mechanicalOutput : MechanicalDriveOutPort;
        }

        part def ElectromagneticBrake {
            attribute holdingTorque : Torque_Nm = 60.0;
            attribute releaseVoltage : ElectricPotential_V = 24.0;
            attribute failSafeApplied : Boolean = true;
            port controlInput : ControlCommandInPort;
            port wheelLoad : MechanicalDriveInPort;
        }

        part def DifferentialDriveBase {
            attribute seatedMaximumSpeed : Speed_mps = 1.6;
            attribute standingMaximumSpeed : Speed_mps = 0.35;
            attribute maximumAcceleration : Acceleration_mps2 = 0.45;
            attribute maximumDeceleration : Acceleration_mps2 = 0.70;
            attribute curbClimbHeight : Length_m = 0.045;
            part leftMotor : WheelMotor;
            part rightMotor : WheelMotor;
            part leftDriveWheel : DriveWheel;
            part rightDriveWheel : DriveWheel;
            part leftBrake : ElectromagneticBrake;
            part rightBrake : ElectromagneticBrake;
            part frontLeftCaster : CasterWheel;
            part frontRightCaster : CasterWheel;
            port leftElectricalInput : MotorDrivePowerInPort;
            port rightElectricalInput : MotorDrivePowerInPort;
            port controlInput : ControlCommandInPort;
            port sensorOutput : SensorDataOutPort;
            port frameReaction : MechanicalDriveOutPort;

            connection leftPower connect leftElectricalInput to leftMotor.electricalInput;
            connection rightPower connect rightElectricalInput to rightMotor.electricalInput;
            connection leftMotorToWheel connect leftMotor.mechanicalOutput to leftDriveWheel.axleInput;
            connection rightMotorToWheel connect rightMotor.mechanicalOutput to rightDriveWheel.axleInput;
            connection leftBrakeToWheel connect leftBrake.wheelLoad to leftDriveWheel.axleInput;
            connection rightBrakeToWheel connect rightBrake.wheelLoad to rightDriveWheel.axleInput;
            connection controlToLeftBrake connect controlInput to leftBrake.controlInput;
            connection controlToRightBrake connect controlInput to rightBrake.controlInput;
        }

        part def BatteryPack {
            attribute nominalVoltage : ElectricPotential_V = 24.0;
            attribute capacity : ElectricCharge_Ah = 50.0;
            attribute storedEnergy : Energy_Wh = 1200.0;
            attribute minimumAllowedStateOfCharge : Percentage = 10.0;
            attribute currentStateOfCharge : Percentage = 100.0;
            attribute maximumDischargeCurrent : ElectricCurrent_A = 90.0;
            attribute maximumChargeCurrent : ElectricCurrent_A = 10.0;
            attribute minimumOperatingTemperature : Temperature_degC = -10.0;
            attribute maximumOperatingTemperature : Temperature_degC = 45.0;
            port dcOutput : ElectricalPowerOutPort;
            port chargeInput : ChargingPowerInPort;
            port sensorOutput : SensorDataOutPort;
        }

        part def PowerDistributionUnit {
            attribute mainFuseCurrentLimit : ElectricCurrent_A = 100.0;
            attribute controllerBranchLimit : ElectricCurrent_A = 60.0;
            attribute liftBranchLimit : ElectricCurrent_A = 50.0;
            attribute accessoryBranchLimit : ElectricCurrent_A = 10.0;
            port dcInput : ElectricalPowerInPort;
            port leftMotorOutput : MotorDrivePowerOutPort;
            port rightMotorOutput : MotorDrivePowerOutPort;
            port liftOutput : MotorDrivePowerOutPort;
            port controllerOutput : ElectricalPowerOutPort;
        }

        part def JoystickConsole {
            attribute maximumForwardDeflection : Percentage = 100.0;
            attribute maximumReverseDeflection : Percentage = -100.0;
            attribute maximumTurnDeflection : Percentage = 100.0;
            attribute emergencyStopLatched : Boolean = false;
            attribute standButtonGuarded : Boolean = true;
            port userCommandOutput : HumanCommandInPort;
            port statusInput : MobilityStatusInPort;
        }

        part def SafetySensorSuite {
            attribute pitchWarningThreshold : Angle_deg = 7.0;
            attribute pitchFaultThreshold : Angle_deg = 10.0;
            attribute rollWarningThreshold : Angle_deg = 6.0;
            attribute rollFaultThreshold : Angle_deg = 9.0;
            attribute minimumObstacleStopDistance : Distance_m = 0.35;
            port bodySupportSensorInput : SensorDataInPort;
            port liftSensorInput : SensorDataInPort;
            port batterySensorInput : SensorDataInPort;
            port driveSensorInput : SensorDataInPort;
            port sensorOutput : SensorDataOutPort;
        }

        part def ControlComputer {
            attribute controlLoopPeriod : Time_s = 0.02;
            attribute seatedSpeedLimit : Speed_mps = 1.6;
            attribute standingSpeedLimit : Speed_mps = 0.35;
            attribute requiredStandingInterlocks : Boolean = true;
            attribute faultLatched : Boolean = false;
            port powerInput : ElectricalPowerInPort;
            port userCommandInput : HumanCommandInPort;
            port sensorInput : SensorDataInPort;
            port driveCommandOutput : ControlCommandOutPort;
            port liftCommandOutput : ControlCommandOutPort;
            port statusOutput : MobilityStatusOutPort;
            port diagnosticOutput : DiagnosticOutPort;
        }

        part def AudibleVisualAlertUnit {
            attribute hornSoundPressure : Pressure_kPa = 0.35;
            attribute standingMotionBeepPeriod : Time_s = 1.0;
            attribute faultLampActive : Boolean = false;
            port commandInput : ControlCommandInPort;
            port alertOutput : AlertOutPort;
        }

        part def StandingWheelchair {
            doc "Primary high-level function: provide powered seated mobility and, when commanded and safe, raise and support the occupant in a stable standing posture for reach, health, and social interaction while preserving braking, balance, and emergency-stop protection."

            attribute ratedUserMass : Mass_kg = 120.0;
            attribute systemMassWithoutOccupant : Mass_kg = 92.0;
            attribute maximumSeatedSpeed : Speed_mps = 1.6;
            attribute maximumStandingSpeed : Speed_mps = 0.35;
            attribute minimumRangeAtRatedMass : Distance_m = 15000.0;
            attribute maximumStandingAngle : Angle_deg = 84.0;
            attribute minimumStandingAngleForUse : Angle_deg = 80.0;
            attribute seatedAngle : Angle_deg = 4.0;
            attribute maximumTransitionTime : Time_s = 22.0;
            attribute emergencyStopStoppingDistance : Distance_m = 0.8;
            attribute canSupportSeatedMobility : Boolean = true;
            attribute canSupportStandingPosture : Boolean = true;

            part frame : ChassisFrame;
            part seating : SeatingSystem;
            part supports : BodySupportSystem;
            part lift : StandingLiftMechanism;
            part driveBase : DifferentialDriveBase;
            part battery : BatteryPack;
            part powerDistribution : PowerDistributionUnit;
            part controller : ControlComputer;
            part joystick : JoystickConsole;
            part sensors : SafetySensorSuite;
            part alerts : AudibleVisualAlertUnit;

            port occupantInterface : OccupantSupportPort;
            port userCommandPort : HumanCommandInPort;
            port chargingPort : ChargingPowerInPort;
            port statusPort : MobilityStatusOutPort;
            port diagnosticPort : DiagnosticOutPort;
            port alertPort : AlertOutPort;

            connection occupantToSeat connect occupantInterface to seating.occupantPort;
            connection occupantToSupports connect occupantInterface to supports.occupantPort;
            connection seatToLift connect seating.liftAttachment to lift.seatOutput;
            connection liftToFrame connect lift.frameReaction to frame.seatMount;
            connection driveToFrame connect driveBase.frameReaction to frame.driveReaction;

            connection chargeToBattery connect chargingPort to battery.chargeInput;
            connection batteryToDistribution connect battery.dcOutput to powerDistribution.dcInput;
            connection distributionToController connect powerDistribution.controllerOutput to controller.powerInput;
            connection distributionToLeftMotor connect powerDistribution.leftMotorOutput to driveBase.leftElectricalInput;
            connection distributionToRightMotor connect powerDistribution.rightMotorOutput to driveBase.rightElectricalInput;
            connection distributionToLift connect powerDistribution.liftOutput to lift.electricalInput;

            connection externalUserCommand connect userCommandPort to controller.userCommandInput;
            connection joystickCommand connect joystick.userCommandOutput to controller.userCommandInput;
            connection controllerDriveCommand connect controller.driveCommandOutput to driveBase.controlInput;
            connection controllerLiftCommand connect controller.liftCommandOutput to lift.controlInput;
            connection controllerAlertCommand connect controller.driveCommandOutput to alerts.commandInput;

            connection supportsSensors connect supports.sensorOutput to sensors.bodySupportSensorInput;
            connection liftSensors connect lift.sensorOutput to sensors.liftSensorInput;
            connection batterySensors connect battery.sensorOutput to sensors.batterySensorInput;
            connection driveSensors connect driveBase.sensorOutput to sensors.driveSensorInput;
            connection safetySensorsToController connect sensors.sensorOutput to controller.sensorInput;

            connection controllerStatusToConsole connect controller.statusOutput to joystick.statusInput;
            connection controllerStatusToExternal connect controller.statusOutput to statusPort;
            connection controllerDiagnostics connect controller.diagnosticOutput to diagnosticPort;
            connection alertExternal connect alerts.alertOutput to alertPort;

            perform action primaryFunction : Behavior::ProvideSupportedStandingMobility;
            exhibit state operatingStates : Behavior::StandingWheelchairOperatingStates;
        }
    }

    package Behavior {

        import ValueTypesAndItems::*;
        import Structure::*;

        action def VerifyOccupantSecured {
            in item sensors : SensorPacket;
            out item verified : MobilityStatus;
            constraint occupantSecured {
                sensors.seatOccupied == true and
                sensors.lapBeltLatched == true and
                sensors.chestSupportLocked == true and
                sensors.kneeBlockLocked == true and
                sensors.footPlateLoaded == true
            }
        }

        action def ManageDifferentialDrive {
            in item command : HumanControlCommand;
            in item sensors : SensorPacket;
            out item status : MobilityStatus;
            attribute seatedSpeedLimit : Speed_mps = 1.6;
            attribute standingSpeedLimit : Speed_mps = 0.35;
            constraint standingSpeedLimited {
                sensors.liftAngle >= 80.0 implies status.currentSpeed <= standingSpeedLimit
            }
            constraint seatedSpeedLimited {
                sensors.liftAngle < 80.0 implies status.currentSpeed <= seatedSpeedLimit
            }
        }

        action def ManageStandingTransition {
            in item command : HumanControlCommand;
            in item sensors : SensorPacket;
            out item status : MobilityStatus;
            attribute targetStandingAngle : Angle_deg = 84.0;
            attribute targetSeatedAngle : Angle_deg = 4.0;
            attribute maximumTransitionTime : Time_s = 22.0;
            constraint standOnlyWhenSecured {
                command.standCommand == true implies
                sensors.lapBeltLatched == true and
                sensors.chestSupportLocked == true and
                sensors.kneeBlockLocked == true
            }
            constraint standingReached {
                status.standingMode == true implies status.currentLiftAngle >= 80.0
            }
        }

        action def MonitorSafety {
            in item sensors : SensorPacket;
            out item status : MobilityStatus;
            attribute rollFaultLimit : Angle_deg = 9.0;
            attribute pitchFaultLimit : Angle_deg = 10.0;
            attribute lowBatteryLimit : Percentage = 10.0;
            constraint faultOnUnsafeAttitude {
                abs(sensors.frameRoll) >= rollFaultLimit or abs(sensors.framePitch) >= pitchFaultLimit implies status.faultActive == true
            }
            constraint faultOnLowBattery {
                sensors.batteryStateOfCharge <= lowBatteryLimit implies status.faultActive == true
            }
        }

        action def ApplyFailSafeBraking {
            in item status : MobilityStatus;
            out item brakeStatus : MobilityStatus;
            constraint brakeOnFault {
                status.faultActive == true implies brakeStatus.brakingApplied == true
            }
            constraint brakeOnPowerLoss {
                status.powered == false implies brakeStatus.brakingApplied == true
            }
        }

        action def ReportStatus {
            in item sensors : SensorPacket;
            out item status : MobilityStatus;
            attribute nominalFullRange : Distance_m = 15000.0;
        }

        action def ProvideSupportedStandingMobility {
            doc "High-level behavior that converts user commands and sensed conditions into safe powered driving, controlled seat elevation to standing, occupant support, braking, and status reporting."

            in item userCommand : HumanControlCommand;
            in item occupantLoad : OccupantLoad;
            in item sensedCondition : SensorPacket;
            out item mobilityStatus : MobilityStatus;

            action verifyOccupant : VerifyOccupantSecured;
            action monitorSafety : MonitorSafety;
            action drive : ManageDifferentialDrive;
            action transitionStanding : ManageStandingTransition;
            action brake : ApplyFailSafeBraking;
            action report : ReportStatus;

            first verifyOccupant then monitorSafety;
            first monitorSafety then drive;
            first monitorSafety then transitionStanding;
            first drive then brake;
            first transitionStanding then brake;
            first brake then report;
        }

        action def ChargeBattery {
            in item chargingPower : ChargingPowerFlow;
            out item status : MobilityStatus;
            attribute maximumChargeCurrent : ElectricCurrent_A = 10.0;
            attribute fullChargeState : Percentage = 100.0;
        }

        action def EmergencyStop {
            in item command : HumanControlCommand;
            out item status : MobilityStatus;
            attribute maximumStoppingDistance : Distance_m = 0.8;
            constraint emergencyStopAppliesBrake {
                command.powerOffRequested == true implies status.brakingApplied == true
            }
        }

        state def StandingWheelchairOperatingStates {
            doc "Operational states for powered seated mobility, standing transition, standing mobility, charging, and fault handling."

            in item command : HumanControlCommand;
            in item sensors : SensorPacket;
            out item status : MobilityStatus;

            state poweredOff {
                entry action applyBrakes : ApplyFailSafeBraking;
            }

            state initializing {
                entry action reportInitialStatus : ReportStatus;
            }

            state seatedReady {
                entry action reportSeatedReady : ReportStatus;
            }

            state seatedDriving {
                do action manageDrive : ManageDifferentialDrive;
            }

            state preparingToStand {
                entry action verify : VerifyOccupantSecured;
            }

            state raisingToStand {
                do action liftUp : ManageStandingTransition;
            }

            state standingReady {
                entry action reportStandingReady : ReportStatus;
            }

            state standingDriving {
                do action manageStandingDrive : ManageDifferentialDrive;
            }

            state loweringToSeated {
                do action liftDown : ManageStandingTransition;
            }

            state charging {
                do action charge : ChargeBattery;
            }

            state faultSafeStop {
                entry action stop : EmergencyStop;
                do action brake : ApplyFailSafeBraking;
            }

            transition powerOn first poweredOff then initializing
                accept command.powerOnRequested;

            transition initializationComplete first initializing then seatedReady
                if sensors.seatOccupied == true;

            transition seatedDriveCommanded first seatedReady then seatedDriving
                if command.forwardCommand != 0.0 or command.turnCommand != 0.0;

            transition seatedDriveReleased first seatedDriving then seatedReady
                if command.forwardCommand == 0.0 and command.turnCommand == 0.0;

            transition standRequested first seatedReady then preparingToStand
                accept command.standCommand;

            transition interlocksVerified first preparingToStand then raisingToStand
                if sensors.lapBeltLatched == true and sensors.chestSupportLocked == true and sensors.kneeBlockLocked == true and sensors.footPlateLoaded == true;

            transition standingAngleReached first raisingToStand then standingReady
                if sensors.liftAngle >= 80.0;

            transition standingDriveCommanded first standingReady then standingDriving
                if command.forwardCommand != 0.0 or command.turnCommand != 0.0;

            transition standingDriveReleased first standingDriving then standingReady
                if command.forwardCommand == 0.0 and command.turnCommand == 0.0;

            transition lowerRequestedFromStandingReady first standingReady then loweringToSeated
                accept command.lowerCommand;

            transition lowerRequestedFromStandingDriving first standingDriving then loweringToSeated
                accept command.lowerCommand;

            transition seatedAngleReached first loweringToSeated then seatedReady
                if sensors.liftAngle <= 5.0;

            transition chargeRequested first poweredOff then charging
                if sensors.batteryStateOfCharge < 100.0;

            transition chargeComplete first charging then poweredOff
                if sensors.batteryStateOfCharge >= 100.0;

            transition emergencyFromSeatedReady first seatedReady then faultSafeStop
                accept command.powerOffRequested;

            transition emergencyFromSeatedDriving first seatedDriving then faultSafeStop
                accept command.powerOffRequested;

            transition emergencyFromRaising first raisingToStand then faultSafeStop
                accept command.powerOffRequested;

            transition emergencyFromStandingReady first standingReady then faultSafeStop
                accept command.powerOffRequested;

            transition emergencyFromStandingDriving first standingDriving then faultSafeStop
                accept command.powerOffRequested;

            transition unsafeAttitude first standingDriving then faultSafeStop
                if abs(sensors.framePitch) >= 10.0 or abs(sensors.frameRoll) >= 9.0;

            transition resetFault first faultSafeStop then poweredOff
                if command.powerOffRequested == false and command.powerOnRequested == false;
        }
    }

    package Requirements {

        import ValueTypesAndItems::*;
        import Structure::*;

        requirement def PrimaryFunctionRequirement {
            doc "The standing wheelchair shall provide powered seated mobility and shall transition a secured occupant from seated posture to supported standing posture at a high level of safety and stability."
            subject chair : StandingWheelchair;
            require constraint primaryFunctionSatisfied {
                chair.canSupportSeatedMobility == true and chair.canSupportStandingPosture == true
            }
        }

        requirement def RatedOccupantMassRequirement {
            doc "The system shall safely support an occupant mass of at least 120 kg in both seated and standing configurations."
            subject chair : StandingWheelchair;
            require constraint ratedMass {
                chair.ratedUserMass >= 120.0
            }
        }

        requirement def StandingAngleRequirement {
            doc "The system shall raise the secured occupant to a functional standing angle of at least 80 degrees from the seated reference."
            subject chair : StandingWheelchair;
            require constraint standingAngle {
                chair.maximumStandingAngle >= chair.minimumStandingAngleForUse and chair.minimumStandingAngleForUse >= 80.0
            }
        }

        requirement def TransitionTimeRequirement {
            doc "The standing transition from seated to supported standing shall complete within 22 seconds under rated occupant mass."
            subject chair : StandingWheelchair;
            require constraint transitionTime {
                chair.maximumTransitionTime <= 22.0
            }
        }

        requirement def SeatedSpeedRequirement {
            doc "The maximum seated driving speed shall not exceed 1.6 m/s."
            subject chair : StandingWheelchair;
            require constraint seatedSpeedLimit {
                chair.maximumSeatedSpeed <= 1.6
            }
        }

        requirement def StandingSpeedRequirement {
            doc "The maximum driving speed while standing shall not exceed 0.35 m/s."
            subject chair : StandingWheelchair;
            require constraint standingSpeedLimit {
                chair.maximumStandingSpeed <= 0.35
            }
        }

        requirement def RangeRequirement {
            doc "The wheelchair shall provide at least 15 km of nominal range at rated occupant mass on level indoor flooring."
            subject chair : StandingWheelchair;
            require constraint minimumRange {
                chair.minimumRangeAtRatedMass >= 15000.0
            }
        }

        requirement def EmergencyStopRequirement {
            doc "The wheelchair shall apply fail-safe braking after an emergency stop command and stop within 0.8 m from maximum seated speed on level ground."
            subject chair : StandingWheelchair;
            require constraint stoppingDistance {
                chair.emergencyStopStoppingDistance <= 0.8
            }
        }

        requirement def StandingInterlockRequirement {
            doc "Standing transition shall be inhibited unless the seat is occupied, lap belt is latched, chest support is locked, knee block is locked, and foot plate is loaded."
            subject chair : StandingWheelchair;
            require constraint interlockEnabled {
                chair.controller.requiredStandingInterlocks == true
            }
        }

        requirement def StructuralStabilityRequirement {
            doc "The chassis shall provide static tip resistance margins for indoor operation in seated and standing configurations."
            subject chair : StandingWheelchair;
            require constraint tipMargins {
                chair.frame.staticTipAngleForward >= 15.0 and chair.frame.staticTipAngleSide >= 12.0
            }
        }

        requirement def BatterySafetyRequirement {
            doc "The battery pack shall limit discharge current, charge current, and operating temperature to safe values."
            subject chair : StandingWheelchair;
            require constraint batteryLimits {
                chair.battery.maximumDischargeCurrent <= 90.0 and
                chair.battery.maximumChargeCurrent <= 10.0 and
                chair.battery.maximumOperatingTemperature <= 45.0
            }
        }

        requirement def FailSafeBrakeRequirement {
            doc "The drive brakes shall be normally applied when unpowered and released only by a valid controller command."
            subject chair : StandingWheelchair;
            require constraint failSafeBrake {
                chair.driveBase.leftBrake.failSafeApplied == true and chair.driveBase.rightBrake.failSafeApplied == true
            }
        }

        requirement def RequirementSetForStandingWheelchair {
            doc "Aggregated requirements for the standing wheelchair system."
            subject chair : StandingWheelchair;
            requirement primary : PrimaryFunctionRequirement {
                subject chair = RequirementSetForStandingWheelchair::chair;
            }
            requirement mass : RatedOccupantMassRequirement {
                subject chair = RequirementSetForStandingWheelchair::chair;
            }
            requirement angle : StandingAngleRequirement {
                subject chair = RequirementSetForStandingWheelchair::chair;
            }
            requirement time : TransitionTimeRequirement {
                subject chair = RequirementSetForStandingWheelchair::chair;
            }
            requirement seatedSpeed : SeatedSpeedRequirement {
                subject chair = RequirementSetForStandingWheelchair::chair;
            }
            requirement standingSpeed : StandingSpeedRequirement {
                subject chair = RequirementSetForStandingWheelchair::chair;
            }
            requirement range : RangeRequirement {
                subject chair = RequirementSetForStandingWheelchair::chair;
            }
            requirement emergencyStop : EmergencyStopRequirement {
                subject chair = RequirementSetForStandingWheelchair::chair;
            }
            requirement interlock : StandingInterlockRequirement {
                subject chair = RequirementSetForStandingWheelchair::chair;
            }
            requirement stability : StructuralStabilityRequirement {
                subject chair = RequirementSetForStandingWheelchair::chair;
            }
            requirement battery : BatterySafetyRequirement {
                subject chair = RequirementSetForStandingWheelchair::chair;
            }
            requirement brakes : FailSafeBrakeRequirement {
                subject chair = RequirementSetForStandingWheelchair::chair;
            }
        }
    }

    package Verification {

        import Structure::*;
        import Requirements::*;
        import ValueTypesAndItems::*;

        part standingWheelchairSystem : StandingWheelchair {
            attribute ratedUserMass = 120.0;
            attribute maximumSeatedSpeed = 1.6;
            attribute maximumStandingSpeed = 0.35;
            attribute minimumRangeAtRatedMass = 15000.0;
            attribute maximumStandingAngle = 84.0;
            attribute minimumStandingAngleForUse = 80.0;
            attribute maximumTransitionTime = 22.0;
            attribute emergencyStopStoppingDistance = 0.8;
        }

        requirement wheelchairRequirements : RequirementSetForStandingWheelchair {
            subject chair = standingWheelchairSystem;
        }

        satisfy standingWheelchairSystem by wheelchairRequirements.primary;
        satisfy standingWheelchairSystem by wheelchairRequirements.mass;
        satisfy standingWheelchairSystem by wheelchairRequirements.angle;
        satisfy standingWheelchairSystem by wheelchairRequirements.time;
        satisfy standingWheelchairSystem by wheelchairRequirements.seatedSpeed;
        satisfy standingWheelchairSystem by wheelchairRequirements.standingSpeed;
        satisfy standingWheelchairSystem by wheelchairRequirements.range;
        satisfy standingWheelchairSystem by wheelchairRequirements.emergencyStop;
        satisfy standingWheelchairSystem by wheelchairRequirements.interlock;
        satisfy standingWheelchairSystem by wheelchairRequirements.stability;
        satisfy standingWheelchairSystem by wheelchairRequirements.battery;
        satisfy standingWheelchairSystem by wheelchairRequirements.brakes;
    }
}
