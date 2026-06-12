package RobotCompetitionSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Score;
    attribute def MatchTime;
    attribute def AllianceColor;
    attribute def GamePieceState;
    attribute def RobotMode;
    attribute def BatteryState;

    enum def AllianceColorEnum {
        enum red;
        enum blue;
    }

    enum def RobotModeEnum {
        enum disabled;
        enum autonomous;
        enum teleoperated;
        enum endgame;
        enum fault;
    }

    enum def GamePieceStateEnum {
        enum none;
        enum detected;
        enum acquired;
        enum secured;
        enum scored;
        enum released;
    }

    value def Volt :> ISQ::VoltageUnit;
    value def Ampere :> ISQ::ElectricCurrentUnit;
    value def Watt :> ISQ::PowerUnit;
    value def Newton :> ISQ::ForceUnit;
    value def Meter :> ISQ::LengthUnit;
    value def MeterPerSecond :> ISQ::SpeedUnit;
    value def Degree :> ISQ::PlaneAngleUnit;
    value def Kilogram :> ISQ::MassUnit;
    value def Second :> ISQ::TimeUnit;

    item def GamePiece {
        attribute mass : Kilogram;
        attribute diameter : Meter;
        attribute state : GamePieceStateEnum;
    }

    item def CompetitionCommand {
        attribute requestedMode : RobotModeEnum;
        attribute enableDrive : Boolean;
        attribute enableScoring : Boolean;
        attribute emergencyStop : Boolean;
    }

    item def DriverInput {
        attribute forwardDemand : Real;
        attribute strafeDemand : Real;
        attribute rotateDemand : Real;
        attribute intakeCommand : Boolean;
        attribute scoreCommand : Boolean;
        attribute climbCommand : Boolean;
    }

    item def RobotTelemetry {
        attribute mode : RobotModeEnum;
        attribute batteryVoltage : Volt;
        attribute totalCurrent : Ampere;
        attribute poseX : Meter;
        attribute poseY : Meter;
        attribute heading : Degree;
        attribute heldPiece : Boolean;
        attribute estimatedScore : Score;
        attribute faultActive : Boolean;
    }

    port def CommandPort {
        in item command : CompetitionCommand;
    }

    port def DriverInputPort {
        in item input : DriverInput;
    }

    port def TelemetryPort {
        out item telemetry : RobotTelemetry;
    }

    port def GamePiecePort {
        inout item piece : GamePiece;
    }

    port def PowerPort {
        out attribute voltage : Volt;
        out attribute currentLimit : Ampere;
    }

    port def MotorPowerPort {
        in attribute voltage : Volt;
        in attribute currentLimit : Ampere;
    }

    port def SensorDataPort {
        out attribute valid : Boolean;
        out attribute distance : Meter;
        out attribute angle : Degree;
    }

    port def ActuatorCommandPort {
        in attribute demand : Real;
        in attribute enabled : Boolean;
    }

    part def CompetitionField {
        attribute length : Meter = 16.54 [m];
        attribute width : Meter = 8.21 [m];

        part scoringZone {
            attribute centerX : Meter = 14.5 [m];
            attribute centerY : Meter = 4.105 [m];
            attribute radius : Meter = 0.75 [m];
            attribute lowGoalPoints : Score = 2;
            attribute highGoalPoints : Score = 5;
        }

        part loadingZone {
            attribute centerX : Meter = 1.1 [m];
            attribute centerY : Meter = 4.105 [m];
            attribute radius : Meter = 0.9 [m];
        }

        part endgamePlatform {
            attribute height : Meter = 0.55 [m];
            attribute climbPoints : Score = 10;
        }
    }

    part def BatteryPack {
        attribute nominalVoltage : Volt = 12.6 [V];
        attribute minimumOperatingVoltage : Volt = 9.0 [V];
        attribute capacity : Ampere = 18 [A];
        attribute state : BatteryState;
        attribute outputVoltage : Volt;
        attribute currentLimit : Ampere = 120 [A];

        port powerOut : PowerPort;

        action providePower {
            out attribute deliveredVoltage : Volt;
            out attribute availableCurrent : Ampere;

            bind deliveredVoltage = outputVoltage;
            bind availableCurrent = currentLimit;
        }
    }

    part def SwerveDriveModule {
        attribute wheelDiameter : Meter = 0.1016 [m];
        attribute maxWheelSpeed : MeterPerSecond = 5.2 [m/s];
        attribute steeringAngle : Degree;
        attribute driveDemand : Real;
        attribute steerDemand : Real;

        port motorPower : MotorPowerPort;
        port driveCommand : ActuatorCommandPort;
        port steerCommand : ActuatorCommandPort;

        action setWheelVector {
            in attribute targetSpeed : MeterPerSecond;
            in attribute targetAngle : Degree;
            out attribute achievedSpeed : MeterPerSecond;
            out attribute achievedAngle : Degree;

            bind achievedAngle = targetAngle;
        }
    }

    part def Drivetrain {
        attribute maxLinearSpeed : MeterPerSecond = 4.8 [m/s];
        attribute maxAngularRate : Degree = 540 [deg];
        attribute poseX : Meter;
        attribute poseY : Meter;
        attribute heading : Degree;
        attribute enabled : Boolean;

        port powerIn : MotorPowerPort;
        port commandIn : ActuatorCommandPort;

        part frontLeft : SwerveDriveModule;
        part frontRight : SwerveDriveModule;
        part rearLeft : SwerveDriveModule;
        part rearRight : SwerveDriveModule;

        connect powerIn to frontLeft.motorPower;
        connect powerIn to frontRight.motorPower;
        connect powerIn to rearLeft.motorPower;
        connect powerIn to rearRight.motorPower;

        action driveToPose {
            in attribute targetX : Meter;
            in attribute targetY : Meter;
            in attribute targetHeading : Degree;
            out attribute reached : Boolean;

            first startMotion;
            then monitorPosition;
            then stopAtTarget;

            action startMotion;
            action monitorPosition;
            action stopAtTarget;
        }

        action holdPosition {
            out attribute stationary : Boolean;
        }
    }

    part def Intake {
        attribute captureWidth : Meter = 0.46 [m];
        attribute rollerSpeedDemand : Real;
        attribute possessionConfirmed : Boolean;

        port powerIn : MotorPowerPort;
        port commandIn : ActuatorCommandPort;
        port gamePieceInterface : GamePiecePort;

        action acquireGamePiece {
            inout item targetPiece : GamePiece;
            out attribute acquired : Boolean;

            first spinRollers;
            then centerPiece;
            then confirmPossession;

            action spinRollers;
            action centerPiece;
            action confirmPossession;
        }

        action releaseGamePiece {
            inout item heldPiece : GamePiece;
            out attribute released : Boolean;
        }
    }

    part def ScoringMechanism {
        attribute armAngle : Degree;
        attribute shooterVelocityDemand : Real;
        attribute launchForce : Newton = 38 [N];
        attribute readyToScore : Boolean;

        port powerIn : MotorPowerPort;
        port commandIn : ActuatorCommandPort;
        port gamePieceInterface : GamePiecePort;

        action aimAtGoal {
            in attribute targetDistance : Meter;
            in attribute targetAngle : Degree;
            out attribute aimed : Boolean;
        }

        action scoreHighGoal {
            inout item heldPiece : GamePiece;
            out attribute pointsAwarded : Score;

            first spinShooter;
            then positionArm;
            then feedPiece;
            then verifyRelease;

            action spinShooter;
            action positionArm;
            action feedPiece;
            action verifyRelease;
        }

        action scoreLowGoal {
            inout item heldPiece : GamePiece;
            out attribute pointsAwarded : Score;
        }
    }

    part def EndgameClimber {
        attribute deployedHeight : Meter = 0.72 [m];
        attribute hookLoadCapacity : Newton = 980 [N];
        attribute climbComplete : Boolean;

        port powerIn : MotorPowerPort;
        port commandIn : ActuatorCommandPort;

        action climbPlatform {
            out attribute climbed : Boolean;

            first deployHooks;
            then latchPlatform;
            then liftRobot;
            then lockPosition;

            action deployHooks;
            action latchPlatform;
            action liftRobot;
            action lockPosition;
        }
    }

    part def VisionSensor {
        attribute horizontalFov : Degree = 70 [deg];
        attribute detectionRange : Meter = 6.0 [m];
        attribute targetVisible : Boolean;
        attribute targetDistance : Meter;
        attribute targetAngle : Degree;

        port sensorOut : SensorDataPort;

        action detectGoal {
            out attribute visible : Boolean;
            out attribute distance : Meter;
            out attribute angle : Degree;
        }
    }

    part def ProximitySensor {
        attribute sensingRange : Meter = 0.35 [m];
        attribute pieceDetected : Boolean;
        attribute distanceToPiece : Meter;

        port sensorOut : SensorDataPort;

        action detectGamePiece {
            out attribute detected : Boolean;
            out attribute distance : Meter;
        }
    }

    part def InertialMeasurementUnit {
        attribute yaw : Degree;
        attribute pitch : Degree;
        attribute roll : Degree;
        attribute angularRate : Degree;

        port sensorOut : SensorDataPort;

        action estimateHeading {
            out attribute heading : Degree;
        }
    }

    part def RobotController {
        attribute mode : RobotModeEnum = RobotModeEnum::disabled;
        attribute alliance : AllianceColorEnum;
        attribute matchClock : Second;
        attribute scoreEstimate : Score = 0;
        attribute faultActive : Boolean = false;
        attribute heldPiece : Boolean = false;

        port commandIn : CommandPort;
        port driverInputIn : DriverInputPort;
        port telemetryOut : TelemetryPort;
        port driveCommandOut : ActuatorCommandPort;
        port intakeCommandOut : ActuatorCommandPort;
        port scoringCommandOut : ActuatorCommandPort;
        port climberCommandOut : ActuatorCommandPort;

        state def RobotCompetitionStateMachine {
            entry action initializeRobot;

            state Disabled;
            state Autonomous;
            state Teleoperated;
            state Endgame;
            state Fault;

            transition initial then Disabled;

            transition Disabled_to_Autonomous
                first Disabled
                accept CompetitionCommand
                if command.requestedMode == RobotModeEnum::autonomous and command.emergencyStop == false
                then Autonomous;

            transition Disabled_to_Teleoperated
                first Disabled
                accept CompetitionCommand
                if command.requestedMode == RobotModeEnum::teleoperated and command.emergencyStop == false
                then Teleoperated;

            transition Autonomous_to_Teleoperated
                first Autonomous
                accept CompetitionCommand
                if command.requestedMode == RobotModeEnum::teleoperated
                then Teleoperated;

            transition Teleoperated_to_Endgame
                first Teleoperated
                accept CompetitionCommand
                if command.requestedMode == RobotModeEnum::endgame
                then Endgame;

            transition Any_to_Fault
                first Disabled, Autonomous, Teleoperated, Endgame
                accept CompetitionCommand
                if command.emergencyStop == true
                then Fault;

            transition Fault_to_Disabled
                first Fault
                accept CompetitionCommand
                if command.requestedMode == RobotModeEnum::disabled and command.emergencyStop == false
                then Disabled;
        }

        action executeAutonomousRoutine {
            out attribute autonomousScore : Score;

            first leaveStartingArea;
            then locateGamePiece;
            then acquireAutonomousPiece;
            then navigateToScoringZone;
            then scoreAutonomousPiece;

            action leaveStartingArea;
            action locateGamePiece;
            action acquireAutonomousPiece;
            action navigateToScoringZone;
            action scoreAutonomousPiece;
        }

        action executeTeleoperatedControl {
            in item driverInput : DriverInput;
            out attribute commandsIssued : Boolean;
        }

        action executeEndgame {
            out attribute endgamePoints : Score;
        }

        action publishTelemetry {
            out item telemetry : RobotTelemetry;
        }
    }

    part def CompetitionRobot {
        attribute robotMass : Kilogram = 49.8 [kg];
        attribute frameLength : Meter = 0.83 [m];
        attribute frameWidth : Meter = 0.72 [m];
        attribute primaryTaskScoreTarget : Score = 45;
        attribute currentMode : RobotModeEnum;
        attribute totalScore : Score = 0;

        port fieldGamePiecePort : GamePiecePort;
        port competitionCommandPort : CommandPort;
        port driverInputPort : DriverInputPort;
        port telemetryPort : TelemetryPort;

        part battery : BatteryPack;
        part drivetrain : Drivetrain;
        part intake : Intake;
        part scoringMechanism : ScoringMechanism;
        part climber : EndgameClimber;
        part vision : VisionSensor;
        part pieceSensor : ProximitySensor;
        part imu : InertialMeasurementUnit;
        part controller : RobotController;

        connect battery.powerOut to drivetrain.powerIn;
        connect battery.powerOut to intake.powerIn;
        connect battery.powerOut to scoringMechanism.powerIn;
        connect battery.powerOut to climber.powerIn;

        connect competitionCommandPort to controller.commandIn;
        connect driverInputPort to controller.driverInputIn;
        connect controller.telemetryOut to telemetryPort;

        connect controller.driveCommandOut to drivetrain.commandIn;
        connect controller.intakeCommandOut to intake.commandIn;
        connect controller.scoringCommandOut to scoringMechanism.commandIn;
        connect controller.climberCommandOut to climber.commandIn;

        connect fieldGamePiecePort to intake.gamePieceInterface;
        connect intake.gamePieceInterface to scoringMechanism.gamePieceInterface;

        action performPrimaryCompetitionTask {
            inout item gamePiece : GamePiece;
            out attribute pointsScored : Score;

            first detectOrReceiveGamePiece;
            then acquireAndSecureGamePiece;
            then navigateToScoringLocation;
            then aimScoringMechanism;
            then scoreGamePiece;
            then updateScoreEstimate;

            action detectOrReceiveGamePiece {
                out attribute detected : Boolean;
            }

            action acquireAndSecureGamePiece {
                inout item gamePiece : GamePiece;
                out attribute secured : Boolean;
            }

            action navigateToScoringLocation {
                out attribute atScoringLocation : Boolean;
            }

            action aimScoringMechanism {
                out attribute ready : Boolean;
            }

            action scoreGamePiece {
                inout item gamePiece : GamePiece;
                out attribute scoreValue : Score;
            }

            action updateScoreEstimate {
                in attribute scoreValue : Score;
                out attribute newTotal : Score;
            }
        }
    }

    part def RobotCompetition {
        attribute matchDuration : Second = 150 [s];
        attribute autonomousDuration : Second = 15 [s];
        attribute teleoperatedDuration : Second = 105 [s];
        attribute endgameDuration : Second = 30 [s];
        attribute winningScoreThreshold : Score = 80;

        part field : CompetitionField;
        part robot : CompetitionRobot;

        item gamePiece1 : GamePiece {
            attribute mass = 0.35 [kg];
            attribute diameter = 0.18 [m];
            attribute state = GamePieceStateEnum::none;
        }

        item gamePiece2 : GamePiece {
            attribute mass = 0.35 [kg];
            attribute diameter = 0.18 [m];
            attribute state = GamePieceStateEnum::none;
        }

        connect robot.fieldGamePiecePort to gamePiece1;
        connect robot.fieldGamePiecePort to gamePiece2;

        action runMatch {
            out attribute finalScore : Score;

            first initializeMatch;
            then runAutonomousPeriod;
            then runTeleoperatedPeriod;
            then runEndgamePeriod;
            then finalizeScore;

            action initializeMatch {
                out attribute ready : Boolean;
            }

            action runAutonomousPeriod {
                out attribute autonomousScore : Score;
            }

            action runTeleoperatedPeriod {
                out attribute teleopScore : Score;
            }

            action runEndgamePeriod {
                out attribute endgameScore : Score;
            }

            action finalizeScore {
                out attribute finalScore : Score;
            }
        }
    }

    requirement def CompetitionPrimaryTaskRequirement {
        subject robot : CompetitionRobot;

        doc /* The robotic system shall perform its primary competition task by acquiring a game piece, navigating to a scoring zone, and scoring the game piece during an enabled competition mode. */

        require constraint {
            robot.primaryTaskScoreTarget >= 45
        }
    }

    requirement def SafeCompetitionOperationRequirement {
        subject robot : CompetitionRobot;

        doc /* The robot shall enter fault mode and disable actuators when an emergency stop command is received. */

        require constraint {
            robot.controller.faultActive == true implies
            robot.drivetrain.enabled == false
        }
    }

    requirement def BatteryVoltageRequirement {
        subject robot : CompetitionRobot;

        doc /* The robot shall operate scoring and driving mechanisms only when battery voltage remains above the minimum operating voltage. */

        require constraint {
            robot.battery.outputVoltage >= robot.battery.minimumOperatingVoltage
        }
    }

    requirement def AutonomousScoringRequirement {
        subject robot : CompetitionRobot;

        doc /* During the autonomous period, the robot shall be capable of scoring at least one game piece without driver input. */

        require constraint {
            robot.controller.mode == RobotModeEnum::autonomous implies
            robot.totalScore >= 5
        }
    }

    requirement def EndgameClimbRequirement {
        subject robot : CompetitionRobot;

        doc /* During endgame mode, the robot shall deploy the climber, latch to the platform, and reach a locked climbed state before match end. */

        require constraint {
            robot.controller.mode == RobotModeEnum::endgame implies
            robot.climber.climbComplete == true
        }
    }

    requirement def TelemetryRequirement {
        subject robot : CompetitionRobot;

        doc /* The robot shall publish telemetry containing mode, battery voltage, pose, possession status, score estimate, and fault status throughout the match. */

        require constraint {
            robot.telemetryPort.telemetry.batteryVoltage >= 0 [V]
        }
    }

    satisfy CompetitionPrimaryTaskRequirement by CompetitionRobot::performPrimaryCompetitionTask;
    satisfy SafeCompetitionOperationRequirement by RobotController::RobotCompetitionStateMachine;
    satisfy BatteryVoltageRequirement by BatteryPack::providePower;
    satisfy AutonomousScoringRequirement by RobotController::executeAutonomousRoutine;
    satisfy EndgameClimbRequirement by EndgameClimber::climbPlatform;
    satisfy TelemetryRequirement by RobotController::publishTelemetry;
}