package BangBangRoboticSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent :> Real {
        range = "0..100";
        unit = "%";
    }

    attribute def Volt :> Real {
        unit = "V";
    }

    attribute def Ampere :> Real {
        unit = "A";
    }

    attribute def NewtonMeter :> Real {
        unit = "N*m";
    }

    attribute def MeterPerSecond :> Real {
        unit = "m/s";
    }

    attribute def RadianPerSecond :> Real {
        unit = "rad/s";
    }

    attribute def Second :> Real {
        unit = "s";
    }

    attribute def Meter :> Real {
        unit = "m";
    }

    attribute def Kilogram :> Real {
        unit = "kg";
    }

    attribute def Celsius :> Real {
        unit = "degC";
    }

    attribute def BooleanSignal :> Boolean;

    attribute def RobotMode :> String;
    attribute def FaultCode :> String;

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute enabled : Boolean;
    }

    item def MotorCommand {
        attribute leftDriveEnable : Boolean;
        attribute rightDriveEnable : Boolean;
        attribute leftDrivePolarity : Integer;
        attribute rightDrivePolarity : Integer;
        attribute liftEnable : Boolean;
        attribute liftPolarity : Integer;
    }

    item def MotorTelemetry {
        attribute leftAngularSpeed : RadianPerSecond;
        attribute rightAngularSpeed : RadianPerSecond;
        attribute liftAngularSpeed : RadianPerSecond;
        attribute leftCurrent : Ampere;
        attribute rightCurrent : Ampere;
        attribute liftCurrent : Ampere;
        attribute leftTemperature : Celsius;
        attribute rightTemperature : Celsius;
        attribute liftTemperature : Celsius;
    }

    item def PoseEstimate {
        attribute x : Meter;
        attribute y : Meter;
        attribute heading : Real;
        attribute linearSpeed : MeterPerSecond;
        attribute angularSpeed : RadianPerSecond;
    }

    item def RangeScan {
        attribute frontDistance : Meter;
        attribute leftDistance : Meter;
        attribute rightDistance : Meter;
        attribute rearDistance : Meter;
        attribute valid : Boolean;
    }

    item def PayloadStatus {
        attribute present : Boolean;
        attribute mass : Kilogram;
        attribute gripped : Boolean;
        attribute liftHeight : Meter;
    }

    item def TaskCommand {
        attribute taskId : String;
        attribute pickupX : Meter;
        attribute pickupY : Meter;
        attribute dropoffX : Meter;
        attribute dropoffY : Meter;
        attribute payloadMassLimit : Kilogram;
        attribute startRequested : Boolean;
        attribute cancelRequested : Boolean;
    }

    item def TaskReport {
        attribute taskId : String;
        attribute mode : RobotMode;
        attribute percentComplete : Percent;
        attribute success : Boolean;
        attribute faulted : Boolean;
        attribute faultCode : FaultCode;
        attribute elapsedTime : Second;
    }

    port def PowerPort {
        in item powerIn : ElectricalPower;
    }

    port def ControlPort {
        in item command : MotorCommand;
        out item telemetry : MotorTelemetry;
    }

    port def SensorPort {
        out item pose : PoseEstimate;
        out item ranges : RangeScan;
        out item payload : PayloadStatus;
    }

    port def MissionPort {
        in item taskCommand : TaskCommand;
        out item taskReport : TaskReport;
    }

    port def SafetyPort {
        in item emergencyStop : BooleanSignal;
        out item safeToOperate : BooleanSignal;
    }

    part def BatteryPack {
        attribute nominalVoltage : Volt = 24.0;
        attribute capacityAh : Real = 18.0;
        attribute stateOfCharge : Percent;
        attribute maxContinuousCurrent : Ampere = 45.0;
        attribute lowChargeThreshold : Percent = 15.0;

        port output : PowerPort;

        action providePower {
            in enabled : Boolean;
            out suppliedPower : ElectricalPower;
            constraint {
                suppliedPower.voltage == nominalVoltage;
                suppliedPower.enabled == enabled and stateOfCharge > lowChargeThreshold;
            }
        }
    }

    part def BangBangController {
        attribute positionTolerance : Meter = 0.05;
        attribute headingTolerance : Real = 0.035;
        attribute obstacleStopDistance : Meter = 0.35;
        attribute gripperCloseDistance : Meter = 0.02;
        attribute liftLowSetpoint : Meter = 0.05;
        attribute liftCarrySetpoint : Meter = 0.35;
        attribute driveDutyCycle : Percent = 100.0;
        attribute creepDutyCycle : Percent = 40.0;
        attribute controlPeriod : Second = 0.02;

        port mission : MissionPort;
        port sensors : SensorPort;
        port driveControl : ControlPort;
        port safety : SafetyPort;

        action computeBangBangDriveCommand {
            in task : TaskCommand;
            in pose : PoseEstimate;
            in ranges : RangeScan;
            in payload : PayloadStatus;
            out command : MotorCommand;
            out safe : BooleanSignal;

            attribute targetX : Meter;
            attribute targetY : Meter;
            attribute distanceError : Meter;
            attribute headingError : Real;

            constraint {
                safe == ranges.valid and ranges.frontDistance > obstacleStopDistance;
            }
        }

        action stopAllActuators {
            out command : MotorCommand;
            constraint {
                command.leftDriveEnable == false;
                command.rightDriveEnable == false;
                command.liftEnable == false;
            }
        }

        state def BangBangMissionState {
            entry action stopAllActuators;

            state idle;
            state validateTask;
            state navigateToPickup;
            state alignForPickup;
            state closeGripper;
            state liftPayload;
            state navigateToDropoff;
            state lowerPayload;
            state releasePayload;
            state returnToIdle;
            state faultStop;

            initial then idle;

            transition idle_to_validate
                first idle
                accept mission.taskCommand
                if mission.taskCommand.startRequested
                then validateTask;

            transition validate_to_pickup
                first validateTask
                if mission.taskCommand.payloadMassLimit <= 8.0
                then navigateToPickup;

            transition validate_to_fault
                first validateTask
                if mission.taskCommand.payloadMassLimit > 8.0
                then faultStop;

            transition pickup_to_align
                first navigateToPickup
                if abs(sensors.pose.x - mission.taskCommand.pickupX) <= positionTolerance and
                   abs(sensors.pose.y - mission.taskCommand.pickupY) <= positionTolerance
                then alignForPickup;

            transition align_to_grip
                first alignForPickup
                if abs(sensors.pose.angularSpeed) <= headingTolerance
                then closeGripper;

            transition grip_to_lift
                first closeGripper
                if sensors.payload.gripped
                then liftPayload;

            transition lift_to_dropoff
                first liftPayload
                if sensors.payload.liftHeight >= liftCarrySetpoint
                then navigateToDropoff;

            transition dropoff_to_lower
                first navigateToDropoff
                if abs(sensors.pose.x - mission.taskCommand.dropoffX) <= positionTolerance and
                   abs(sensors.pose.y - mission.taskCommand.dropoffY) <= positionTolerance
                then lowerPayload;

            transition lower_to_release
                first lowerPayload
                if sensors.payload.liftHeight <= liftLowSetpoint
                then releasePayload;

            transition release_to_return
                first releasePayload
                if not sensors.payload.gripped
                then returnToIdle;

            transition return_to_idle
                first returnToIdle
                then idle;

            transition any_to_fault_by_estop
                first idle
                accept safety.emergencyStop
                if safety.emergencyStop
                then faultStop;

            transition fault_to_idle
                first faultStop
                accept mission.taskCommand
                if mission.taskCommand.cancelRequested
                then idle;
        }
    }

    part def DifferentialDriveBase {
        attribute wheelRadius : Meter = 0.075;
        attribute trackWidth : Meter = 0.42;
        attribute maxSpeed : MeterPerSecond = 1.20;
        attribute maxTorquePerWheel : NewtonMeter = 9.0;
        attribute bangBangDutyCycle : Percent = 100.0;

        port power : PowerPort;
        port control : ControlPort;

        part leftMotor {
            attribute enabled : Boolean;
            attribute polarity : Integer;
            attribute angularSpeed : RadianPerSecond;
            attribute torque : NewtonMeter;
        }

        part rightMotor {
            attribute enabled : Boolean;
            attribute polarity : Integer;
            attribute angularSpeed : RadianPerSecond;
            attribute torque : NewtonMeter;
        }

        action applyDriveCommand {
            in command : MotorCommand;
            out telemetry : MotorTelemetry;
            constraint {
                leftMotor.enabled == command.leftDriveEnable;
                rightMotor.enabled == command.rightDriveEnable;
                leftMotor.polarity == command.leftDrivePolarity;
                rightMotor.polarity == command.rightDrivePolarity;
            }
        }
    }

    part def LiftAndGripper {
        attribute maxPayloadMass : Kilogram = 8.0;
        attribute gripForce : Real = 120.0;
        attribute liftTravel : Meter = 0.45;
        attribute liftSpeed : MeterPerSecond = 0.08;

        port power : PowerPort;
        port control : ControlPort;
        port payloadSensor : SensorPort;

        part liftMotor {
            attribute enabled : Boolean;
            attribute polarity : Integer;
            attribute angularSpeed : RadianPerSecond;
        }

        part gripper {
            attribute closed : Boolean;
            attribute objectDetected : Boolean;
        }

        action bangBangLiftControl {
            in targetHeight : Meter;
            in currentHeight : Meter;
            out command : MotorCommand;
            constraint {
                command.liftEnable == abs(targetHeight - currentHeight) > 0.01;
            }
        }
    }

    part def PerceptionSuite {
        attribute rangeUpdatePeriod : Second = 0.05;
        attribute odometryUpdatePeriod : Second = 0.02;
        attribute minimumReliableRange : Meter = 0.04;
        attribute maximumReliableRange : Meter = 4.00;

        port power : PowerPort;
        port sensors : SensorPort;

        part wheelEncoders {
            attribute leftTicks : Integer;
            attribute rightTicks : Integer;
            attribute ticksPerRevolution : Integer = 2048;
        }

        part rangeArray {
            attribute frontDistance : Meter;
            attribute leftDistance : Meter;
            attribute rightDistance : Meter;
            attribute rearDistance : Meter;
        }

        part payloadDetector {
            attribute beamBroken : Boolean;
            attribute loadCellMass : Kilogram;
        }

        action estimatePose {
            out pose : PoseEstimate;
        }

        action scanObstacles {
            out ranges : RangeScan;
            constraint {
                ranges.valid == ranges.frontDistance >= minimumReliableRange and
                                ranges.frontDistance <= maximumReliableRange;
            }
        }
    }

    part def SafetySupervisor {
        attribute motorCurrentLimit : Ampere = 30.0;
        attribute motorTemperatureLimit : Celsius = 80.0;
        attribute batteryMinimumVoltage : Volt = 20.0;
        attribute watchdogTimeout : Second = 0.10;

        port powerMonitor : PowerPort;
        port driveMonitor : ControlPort;
        port liftMonitor : ControlPort;
        port safety : SafetyPort;

        action evaluateSafety {
            in power : ElectricalPower;
            in driveTelemetry : MotorTelemetry;
            in liftTelemetry : MotorTelemetry;
            in emergencyStop : BooleanSignal;
            out safeToOperate : BooleanSignal;
            constraint {
                safeToOperate == not emergencyStop and
                                 power.voltage >= batteryMinimumVoltage and
                                 driveTelemetry.leftCurrent <= motorCurrentLimit and
                                 driveTelemetry.rightCurrent <= motorCurrentLimit and
                                 liftTelemetry.liftCurrent <= motorCurrentLimit and
                                 driveTelemetry.leftTemperature <= motorTemperatureLimit and
                                 driveTelemetry.rightTemperature <= motorTemperatureLimit and
                                 liftTelemetry.liftTemperature <= motorTemperatureLimit;
            }
        }

        state def SafetyState {
            state safe;
            state inhibited;
            state emergencyStopped;

            initial then inhibited;

            transition inhibited_to_safe
                first inhibited
                if safety.safeToOperate
                then safe;

            transition safe_to_inhibited
                first safe
                if not safety.safeToOperate
                then inhibited;

            transition any_to_estop
                first safe
                accept safety.emergencyStop
                if safety.emergencyStop
                then emergencyStopped;
        }
    }

    part def TaskInterface {
        port mission : MissionPort;

        action receiveTask {
            out task : TaskCommand;
        }

        action publishReport {
            in report : TaskReport;
        }
    }

    part def BangBangRobot {
        attribute name : String = "BangBangMaterialTransferRobot";
        attribute dryMass : Kilogram = 42.0;
        attribute ratedPayload : Kilogram = 8.0;
        attribute primaryTask : String = "Transport payload from pickup location to dropoff location using bang-bang actuation";

        port mission : MissionPort;
        port emergency : SafetyPort;

        part battery : BatteryPack;
        part controller : BangBangController;
        part driveBase : DifferentialDriveBase;
        part manipulator : LiftAndGripper;
        part perception : PerceptionSuite;
        part safetySupervisor : SafetySupervisor;
        part taskInterface : TaskInterface;

        connect battery.output to driveBase.power;
        connect battery.output to manipulator.power;
        connect battery.output to perception.power;
        connect battery.output to safetySupervisor.powerMonitor;

        connect controller.driveControl to driveBase.control;
        connect controller.driveControl to manipulator.control;
        connect controller.sensors to perception.sensors;
        connect controller.safety to safetySupervisor.safety;
        connect controller.mission to taskInterface.mission;
        connect mission to taskInterface.mission;
        connect emergency to safetySupervisor.safety;

        perform action completePrimaryTask {
            in command : TaskCommand;
            out report : TaskReport;

            first start;
            then acceptTask;
            then navigateToPickup;
            then acquirePayload;
            then navigateToDropoff;
            then releasePayload;
            then reportCompletion;

            action start;
            action acceptTask;
            action navigateToPickup;
            action acquirePayload;
            action navigateToDropoff;
            action releasePayload;
            action reportCompletion;
        }
    }

    part def OperatingCell {
        attribute length : Meter = 12.0;
        attribute width : Meter = 8.0;
        attribute floorFrictionCoefficient : Real = 0.72;

        part robot : BangBangRobot;

        part pickupStation {
            attribute x : Meter = 1.50;
            attribute y : Meter = 2.00;
            attribute payloadMass : Kilogram = 5.00;
        }

        part dropoffStation {
            attribute x : Meter = 9.50;
            attribute y : Meter = 6.00;
        }

        part chargingDock {
            attribute x : Meter = 0.50;
            attribute y : Meter = 0.50;
        }
    }

    requirement def PrimaryTaskRequirement {
        subject robot : BangBangRobot;
        attribute maximumPayloadMass : Kilogram = 8.0;
        attribute maximumTaskTime : Second = 180.0;

        require constraint {
            robot.ratedPayload >= maximumPayloadMass;
        }
    }

    requirement def BangBangControlRequirement {
        subject controller : BangBangController;

        require constraint {
            controller.driveDutyCycle == 100.0 and
            controller.positionTolerance <= 0.05 and
            controller.controlPeriod <= 0.02;
        }
    }

    requirement def ObstacleSafetyRequirement {
        subject controller : BangBangController;

        require constraint {
            controller.obstacleStopDistance >= 0.35;
        }
    }

    requirement def PayloadRequirement {
        subject manipulator : LiftAndGripper;
        attribute requiredPayloadMass : Kilogram = 8.0;
        attribute requiredLiftHeight : Meter = 0.35;

        require constraint {
            manipulator.maxPayloadMass >= requiredPayloadMass and
            manipulator.liftTravel >= requiredLiftHeight;
        }
    }

    requirement def PowerRequirement {
        subject battery : BatteryPack;
        attribute minimumNominalVoltage : Volt = 24.0;
        attribute minimumContinuousCurrent : Ampere = 40.0;

        require constraint {
            battery.nominalVoltage >= minimumNominalVoltage and
            battery.maxContinuousCurrent >= minimumContinuousCurrent;
        }
    }

    requirement def SafeStopRequirement {
        subject safetySupervisor : SafetySupervisor;
        attribute maximumWatchdogTimeout : Second = 0.10;

        require constraint {
            safetySupervisor.watchdogTimeout <= maximumWatchdogTimeout;
        }
    }

    satisfy PrimaryTaskRequirement by BangBangRobot;
    satisfy BangBangControlRequirement by BangBangController;
    satisfy ObstacleSafetyRequirement by BangBangController;
    satisfy PayloadRequirement by LiftAndGripper;
    satisfy PowerRequirement by BatteryPack;
    satisfy SafeStopRequirement by SafetySupervisor;

    part operatingCell : OperatingCell;

}