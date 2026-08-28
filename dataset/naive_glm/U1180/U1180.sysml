package RoboticCompetitionSystem {

  package Units {
    unit m;
    unit s;
    unit m_per_s : m / s;
    unit N;
    unit J;
    unit W;
    unit V;
    unit A;
    unit kg;
    unit rad;
  }

  // ---- Value types ----
  value type Length > Real { unit m; }
  value type Speed > Real { unit m_per_s; }
  value type Force > Real { unit N; }
  value type Energy > Real { unit J; }
  value type Power > Real { unit W; }
  value type Voltage > Real { unit V; }
  value type Current > Real { unit A; }
  value type Time > Real { unit s; }
  value type Mass > Real { unit kg; }
  value type Angle > Real { unit rad; }
  value type ScoreValue > Integer;

  // ---- Enumerations ----
  enum TeamColor { red, blue; }
  enum GamePhase { setup, autonomous, teleoperated, complete; }
  enum PieceType { cube, cone; }
  enum RobotMode { idle, scanning, navigating, acquiring, transporting, depositing, fault; }
  enum ManipulatorAction { grasp, hold, release; }

  // ---- Item definitions ----
  item def GamePiece {
    attribute id : String;
    attribute type : PieceType;
    attribute mass : Mass := 0.5 [kg];
    attribute scored : Boolean := false;
    attribute value : ScoreValue := 1;
  }

  item def FieldCoordinate {
    attribute x : Length;
    attribute y : Length;
  }

  item def Pose {
    attribute position : FieldCoordinate;
    attribute orientation : Angle;
  }

  // ---- Port definitions ----
  port def PowerPort {
    out voltage : Voltage;
    out current : Current;
  }

  port def DriveCommandPort {
    in targetPose : Pose;
    in targetSpeed : Speed;
  }

  port def ManipulatorCommandPort {
    in action : ManipulatorAction;
    in gripForce : Force;
  }

  port def VisionDataPort {
    out pose : Pose;
    out detectedPieces : GamePiece[0..*];
  }

  port def ScoreUpdatePort {
    out team : TeamColor;
    out points : ScoreValue;
  }

  port def FieldStatePort {
    out availablePieces : GamePiece[0..*];
    out redZoneCenter : FieldCoordinate;
    out blueZoneCenter : FieldCoordinate;
  }

  // ---- Requirements ----
  requirement def CompetitionRequirements {
    subject comp : RoboticCompetitionSystem;

    requirement DriveSpeedReq {
      subject ds : DriveSystem;
      doc /* Drive system shall achieve speeds up to 3.5 m/s. */
      constraint { ds.maxSpeed <= 3.5 [m_per_s]; }
    }

    requirement VisionRangeReq {
      subject vs : VisionSystem;
      doc /* Vision system shall detect game pieces within 5 m. */
      constraint { vs.detectionRange >= 5.0 [m]; }
    }

    requirement ManipulatorForceReq {
      subject m : Manipulator;
      doc /* Manipulator shall grasp game pieces with sufficient force. */
      constraint { m.maxGripForce >= 20.0 [N]; }
    }

    requirement BatteryEnduranceReq {
      subject b : Battery;
      doc /* Battery shall provide sufficient energy for a full match. */
      constraint { b.capacity >= 50000 [J]; }
      constraint { b.criticalThreshold <= 5000 [J]; }
    }

    requirement FieldPieceCountReq {
      subject f : CompetitionField;
      doc /* Field shall contain exactly twenty scorable game pieces. */
      constraint { f.gamePieces.size == 20; }
    }

    requirement AutonomousOperationReq {
      subject r : CompetitionRobot;
      doc /* Robot shall operate without human intervention during autonomous phase. */
    }

    requirement MatchManagementReq {
      subject mgr : CompetitionManager;
      doc /* Manager shall transition through setup, autonomous, teleoperated, and complete phases. */
    }
  }

  // ---- Subsystem definitions ----
  part def Wheel {
    attribute radius : Length := 0.075 [m];
  }

  part def DriveSystem {
    attribute maxSpeed : Speed := 3.5 [m_per_s];
    attribute wheelCount : Integer := 4;
    port driveCmd : DriveCommandPort;
    port powerIn : PowerPort;
    part wheels : Wheel[4];

    action def MoveTo {
      in target : Pose;
      in speed : Speed;
      out arrived : Boolean;
    }
    action moveTo : MoveTo;
  }

  part def VisionSystem {
    attribute detectionRange : Length := 5.0 [m];
    attribute updateRate : Real := 30.0;
    port visionOut : VisionDataPort;
    port powerIn : PowerPort;

    action def Scan {
      out pose : Pose;
      out pieces : GamePiece[0..*];
    }
    action scan : Scan;
  }

  part def Manipulator {
    attribute maxGripForce : Force := 50.0 [N];
    attribute carriedPiece : GamePiece[0..1];
    port manipCmd : ManipulatorCommandPort;
    port powerIn : PowerPort;

    action def Grasp {
      in piece : GamePiece;
      out grasped : Boolean;
    }
    action def Release {
      out piece : GamePiece;
      out released : Boolean;
    }
    action grasp : Grasp;
    action release : Release;
  }

  part def Battery {
    attribute capacity : Energy := 60000 [J];
    attribute currentEnergy : Energy := 60000 [J];
    attribute nominalVoltage : Voltage := 12.0 [V];
    attribute criticalThreshold : Energy := 5000 [J];
    port powerOut : PowerPort;

    action def Discharge {
      in amount : Energy;
      out remaining : Energy;
    }
    action discharge : Discharge;

    action def IsCritical {
      out critical : Boolean;
    }
    action isCritical : IsCritical;
  }

  part def AutonomousController {
    attribute team : TeamColor;
    attribute mode : RobotMode := idle;
    port visionIn : VisionDataPort;
    port driveOut : DriveCommandPort;
    port manipOut : ManipulatorCommandPort;

    action def PlanStrategy {
      in pose : Pose;
      in pieces : GamePiece[0..*];
      in scoringZone : FieldCoordinate;
      out target : GamePiece;
      out targetPose : Pose;
      out scoringPose : Pose;
    }
    action planStrategy : PlanStrategy;

    state machine def ControllerStateMachine {
      entry idle;
      transition idle -> scanning on startScan;
      transition scanning -> navigating on pieceFound;
      transition navigating -> acquiring on arrivedAtPiece;
      transition acquiring -> transporting on pieceGrasped;
      transition transporting -> depositing on arrivedAtScoringZone;
      transition depositing -> scanning on pieceReleased;
      transition idle -> fault on batteryCritical;
      transition scanning -> fault on batteryCritical;
      transition navigating -> fault on batteryCritical;
      transition acquiring -> fault on batteryCritical;
      transition transporting -> fault on batteryCritical;
      transition depositing -> fault on batteryCritical;
      transition fault -> idle on reset;
    }
  }

  // ---- Competition Robot ----
  part def CompetitionRobot {
    attribute robotId : String;
    attribute team : TeamColor;
    port scoreOut : ScoreUpdatePort;
    port fieldIn : FieldStatePort;

    part drive : DriveSystem;
    part vision : VisionSystem;
    part manipulator : Manipulator;
    part battery : Battery;
    part controller : AutonomousController {
      attribute team = CompetitionRobot.this.team;
    }

    connect battery.powerOut to drive.powerIn;
    connect battery.powerOut to vision.powerIn;
    connect battery.powerOut to manipulator.powerIn;
    connect vision.visionOut to controller.visionIn;
    connect controller.driveOut to drive.driveCmd;
    connect controller.manipOut to manipulator.manipCmd;

    state machine def RobotBehavior {
      entry idle;
      transition idle -> scanning on matchStart;
      transition scanning -> navigating on nearestPieceFound;
      transition navigating -> acquiring on arrivedAtPiece;
      transition acquiring -> transporting on pieceGrasped;
      transition transporting -> depositing on arrivedAtScoringZone;
      transition depositing -> scanning on pieceDeposited;
      transition idle -> fault on batteryCritical;
      transition scanning -> fault on batteryCritical;
      transition navigating -> fault on batteryCritical;
      transition acquiring -> fault on batteryCritical;
      transition transporting -> fault on batteryCritical;
      transition depositing -> fault on batteryCritical;
      transition fault -> idle on matchReset;
    }

    action def TaskLoop {
      in fieldPieces : GamePiece[0..*];
      in scoringZone : FieldCoordinate;
      out scoredPiece : GamePiece;

      action scan : VisionSystem::Scan;
      action plan : AutonomousController::PlanStrategy;
      action navigate : DriveSystem::MoveTo;
      action acquire : Manipulator::Grasp;
      action transport : DriveSystem::MoveTo;
      action deposit : Manipulator::Release;

      flow scan.pieces to plan.pieces;
      flow plan.target to acquire.piece;
      flow plan.targetPose to navigate.target;
      flow navigate.arrived to acquire;
      flow acquire.grasped to transport;
      flow plan.scoringPose to transport.target;
      flow transport.arrived to deposit;
      flow deposit.piece to scoredPiece;
    }
    action taskLoop : TaskLoop;
  }

  // ---- Field components ----
  part def ScoringZone {
    attribute team : TeamColor;
    attribute center : FieldCoordinate;
    attribute radius : Length := 0.5 [m];
    attribute scoredPieces : GamePiece[0..*];
  }

  part def LoadingStation {
    attribute center : FieldCoordinate;
    attribute availablePieces : GamePiece[0..*];
  }

  part def CompetitionField {
    attribute length : Length := 12.0 [m];
    attribute width : Length := 8.0 [m];
    attribute redScoringZoneCenter : FieldCoordinate := FieldCoordinate { x = 1.0 [m]; y = 4.0 [m]; };
    attribute blueScoringZoneCenter : FieldCoordinate := FieldCoordinate { x = 11.0 [m]; y = 4.0 [m]; };
    attribute loadingStationCenter : FieldCoordinate := FieldCoordinate { x = 6.0 [m]; y = 4.0 [m]; };
    attribute gamePieces : GamePiece[20];
    port fieldStateOut : FieldStatePort;

    part redZone : ScoringZone {
      attribute team = TeamColor::red;
      attribute center = CompetitionField.this.redScoringZoneCenter;
    }
    part blueZone : ScoringZone {
      attribute team = TeamColor::blue;
      attribute center = CompetitionField.this.blueScoringZoneCenter;
    }
    part loadingStation : LoadingStation {
      attribute center = CompetitionField.this.loadingStationCenter;
    }
  }

  // ---- Competition Manager ----
  part def CompetitionManager {
    attribute matchDuration : Time := 150.0 [s];
    attribute autonomousDuration : Time := 30.0 [s];
    attribute teleoperatedDuration : Time := 120.0 [s];
    attribute currentPhase : GamePhase := setup;
    attribute redScore : ScoreValue := 0;
    attribute blueScore : ScoreValue := 0;
    attribute matchTimer : Time := 0.0 [s];

    port redScoreIn : ScoreUpdatePort;
    port blueScoreIn : ScoreUpdatePort;

    state machine def MatchStateMachine {
      entry setup;
      transition setup -> autonomous on matchStart;
      transition autonomous -> teleoperated on autonomousTimerExpired;
      transition teleoperated -> complete on matchTimerExpired;
    }

    action def RunMatch {
      in redRobot : CompetitionRobot;
      in blueRobot : CompetitionRobot;
      out redFinalScore : ScoreValue;
      out blueFinalScore : ScoreValue;

      action startMatch;
      action runAutonomous;
      action runTeleoperated;
      action calculateScores;
      flow calculateScores.redTotal to redFinalScore;
      flow calculateScores.blueTotal to blueFinalScore;
    }
    action runMatch : RunMatch;

    action def CalculateScores {
      in redUpdates : ScoreUpdatePort;
      in blueUpdates : ScoreUpdatePort;
      out redTotal : ScoreValue;
      out blueTotal : ScoreValue;
    }
    action calculateScores : CalculateScores;

    action def DetermineWinner {
      in redTotal : ScoreValue;
      in blueTotal : ScoreValue;
      out winner : TeamColor;
    }
    action determineWinner : DetermineWinner;
  }

  // ---- Top-level system ----
  part def RoboticCompetitionSystem {
    attribute eventName : String := "Regional Championship";
    attribute matchNumber : Integer := 1;

    part field : CompetitionField;
    part redRobot : CompetitionRobot {
      attribute robotId = "R-RED-01";
      attribute team = TeamColor::red;
    }
    part blueRobot : CompetitionRobot {
      attribute robotId = "R-BLUE-01";
      attribute team = TeamColor::blue;
    }
    part manager : CompetitionManager;

    connect redRobot.scoreOut to manager.redScoreIn;
    connect blueRobot.scoreOut to manager.blueScoreIn;
    connect field.fieldStateOut to redRobot.fieldIn;
    connect field.fieldStateOut to blueRobot.fieldIn;

    flow field.gamePieces to redRobot.taskLoop.fieldPieces;
    flow field.redScoringZoneCenter to redRobot.taskLoop.scoringZone;
    flow field.gamePieces to blueRobot.taskLoop.fieldPieces;
    flow field.blueScoringZoneCenter to blueRobot.taskLoop.scoringZone;

    requirement compReqs : CompetitionRequirements {
      subject = this;
    }
  }

  part competitionSystem : RoboticCompetitionSystem;

}
