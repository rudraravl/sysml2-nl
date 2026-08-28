package 'RoboticCompetitionSystem' {
    private import ScalarValues::*;
    private import SequenceFunctions::*;

    unit def meter { symbol "m"; }
    unit def second { symbol "s"; }
    unit def newton { symbol "N"; }
    unit def joule { symbol "J"; }
    unit def radian { symbol "rad"; }
    unit def meter_per_second { symbol "m/s"; }

    attribute def LengthValue :> Real { unit meter; }
    attribute def SpeedValue :> Real { unit meter_per_second; }
    attribute def ForceValue :> Real { unit newton; }
    attribute def EnergyValue :> Real { unit joule; }
    attribute def TimeValue :> Real { unit second; }
    attribute def AngleValue :> Real { unit radian; }

    attribute def Position {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute heading : AngleValue;
    }

    item def GameStart;
    item def TimerExpired;
    item def Reset;
    item def PieceDetected;
    item def TargetReached;
    item def PieceAcquired;
    item def ZoneReached;
    item def PieceDeposited;
    item def LowBattery;

    item def GamePiece {
        attribute id : Integer;
    }

    part def Wheel;

    part def Zone {
        attribute zoneType : String;
    }

    port def DriveCommandPort {
        in attribute targetSpeed : SpeedValue;
        in attribute targetHeading : AngleValue;
    }

    port def VisionDataPort {
        out item detectedPieces : GamePiece[*];
        out attribute robotPosition : Position;
    }

    port def ManipCommandPort {
        in attribute command : String;
    }

    port def BatteryMonitorPort {
        out attribute currentLevel : EnergyValue;
        out attribute maxCapacity : EnergyValue;
    }

    port def PowerPort {
        out attribute voltage : Real;
    }

    part def DriveSystem {
        attribute maxSpeed : SpeedValue = 3.5 [m/s];
        part wheels : Wheel[4];
        port driveCommand : DriveCommandPort;
        port powerIn : ~PowerPort;
    }

    part def VisionSystem {
        attribute detectionRange : LengthValue = 5 [m];
        port visionOut : VisionDataPort;
        port powerIn : ~PowerPort;
    }

    part def Manipulator {
        attribute maxGripForce : ForceValue = 50 [N];
        port manipCommand : ManipCommandPort;
        port powerIn : ~PowerPort;
    }

    part def Battery {
        attribute maxCapacity : EnergyValue = 200000 [J];
        attribute currentLevel : EnergyValue := 200000 [J];
        port powerOut : PowerPort;
        port monitorOut : BatteryMonitorPort;
    }

    action def ScanFieldAction {
        in detectionRange : LengthValue;
        out detectedPieces : GamePiece[*];
    }

    action def NavigateAction {
        in target : Position;
        in current : Position;
        out speedCommand : SpeedValue;
        out headingCommand : AngleValue;
    }

    action def AcquireAction {
        in piece : GamePiece;
        out gripperCommand : String;
    }

    action def DepositAction {
        in piece : GamePiece;
        out gripperCommand : String;
    }

    action def CalculateScore {
        in attribute redPieces : GamePiece[*];
        in attribute bluePieces : GamePiece[*];
        out attribute redScore : Integer;
        out attribute blueScore : Integer;
        assign redScore := redPieces->size();
        assign blueScore := bluePieces->size();
    }

    part def AutonomousController {
        port visionIn : ~VisionDataPort;
        port driveCmdOut : ~DriveCommandPort;
        port manipCmdOut : ~ManipCommandPort;
        port batteryMonitorIn : ~BatteryMonitorPort;

        state robotBehavior {
            entry; then Scanning;
            state Scanning;
            transition t_scan_nav
                first Scanning
                accept PieceDetected
                then Navigating;
            state Navigating;
            transition t_nav_acq
                first Navigating
                accept TargetReached
                then Acquiring;
            state Acquiring;
            transition t_acq_trans
                first Acquiring
                accept PieceAcquired
                then Transporting;
            state Transporting;
            transition t_trans_dep
                first Transporting
                accept ZoneReached
                then Depositing;
            state Depositing;
            transition t_dep_scan
                first Depositing
                accept PieceDeposited
                then Scanning;
            state Faulted;
            transition t_low_scan
                first Scanning
                accept LowBattery
                then Faulted;
            transition t_low_nav
                first Navigating
                accept LowBattery
                then Faulted;
            transition t_low_acq
                first Acquiring
                accept LowBattery
                then Faulted;
            transition t_low_trans
                first Transporting
                accept LowBattery
                then Faulted;
            transition t_low_dep
                first Depositing
                accept LowBattery
                then Faulted;
            transition t_reset
                first Faulted
                accept Reset
                then Scanning;
        }
    }

    part def CompetitionRobot {
        attribute teamColor : String;
        part driveSystem : DriveSystem;
        part visionSystem : VisionSystem;
        part manipulator : Manipulator;
        part battery : Battery;
        part controller : AutonomousController;
        connect visionSystem.visionOut to controller.visionIn;
        connect controller.driveCmdOut to driveSystem.driveCommand;
        connect controller.manipCmdOut to manipulator.manipCommand;
        connect battery.monitorOut to controller.batteryMonitorIn;
        connect battery.powerOut to driveSystem.powerIn;
        connect battery.powerOut to visionSystem.powerIn;
        connect battery.powerOut to manipulator.powerIn;
    }

    part def CompetitionField {
        attribute length : LengthValue = 15 [m];
        attribute width : LengthValue = 8 [m];
        part redScoringZone : Zone {
            attribute :>> zoneType := "Red";
        }
        part blueScoringZone : Zone {
            attribute :>> zoneType := "Blue";
        }
        part loadingStation : Zone {
            attribute :>> zoneType := "Loading";
        }
        item fieldPieces : GamePiece[20];
    }

    part def CompetitionManager {
        attribute matchTime : TimeValue = 150 [s];
        attribute autonomousTime : TimeValue = 15 [s];
        attribute teleopTime : TimeValue = 135 [s];
        attribute redScore : Integer = 0;
        attribute blueScore : Integer = 0;
        attribute currentPhase : String;

        state matchBehavior {
            entry; then Setup;
            state Setup;
            transition t_start
                first Setup
                accept GameStart
                then Autonomous;
            state Autonomous;
            transition t_end_auto
                first Autonomous
                accept TimerExpired
                then Teleop;
            state Teleop;
            transition t_end_teleop
                first Teleop
                accept TimerExpired
                then GameOver;
            state GameOver;
            transition t_reset_match
                first GameOver
                accept Reset
                then Setup;
        }

        action scoreCalculator : CalculateScore;
    }

    part def CompetitionSystem {
        part field : CompetitionField;
        part manager : CompetitionManager;
        part redRobot : CompetitionRobot {
            attribute :>> teamColor := "Red";
        }
        part blueRobot : CompetitionRobot {
            attribute :>> teamColor := "Blue";
        }
    }

    requirement def RobotSpeedLimit {
        doc /* The drive system shall provide mobility at speeds up to 3.5 meters per second. */
        subject robot : CompetitionRobot;
        constraint { robot.driveSystem.maxSpeed <= 3.5 [m/s] }
    }

    requirement def VisionDetectionRange {
        doc /* The vision system shall detect game pieces within a 5-meter range and provide localization. */
        subject robot : CompetitionRobot;
        constraint { robot.visionSystem.detectionRange >= 5 [m] }
    }

    requirement def ManipulatorGripForce {
        doc /* The manipulator shall grasp game pieces with at least 50 N of force. */
        subject robot : CompetitionRobot;
        constraint { robot.manipulator.maxGripForce >= 50 [N] }
    }

    requirement def BatteryCapacityReq {
        doc /* The battery shall provide sufficient energy for a complete 150-second match. */
        subject robot : CompetitionRobot;
        constraint { robot.battery.maxCapacity >= 200000 [J] }
    }

    requirement def FieldPieceCountReq {
        doc /* The competition field shall contain exactly twenty scorable game pieces. */
        subject field : CompetitionField;
        constraint { field.fieldPieces->size() == 20 }
    }

    requirement def MatchDurationReq {
        doc /* The competition manager shall run matches of 150 seconds total duration. */
        subject manager : CompetitionManager;
        constraint { manager.matchTime == 150 [s] }
    }

    requirement def RobotTaskLoopReq {
        doc /* Each robot shall cycle through scanning, navigating, acquiring, transporting, and depositing during the autonomous phase. */
        subject robot : CompetitionRobot;
    }
}
