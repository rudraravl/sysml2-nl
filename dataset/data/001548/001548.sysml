package 'Robotic Competition System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def Distance :> ISQ::lengthValue {
		attribute :>> num : Real;
		attribute :>> mRef : LengthUnit;
	}
	
	attribute def Time :> ISQ::timeValue {
		attribute :>> num : Real;
		attribute :>> mRef : TimeUnit;
	}
	
	attribute def Velocity :> ISQ::speedValue {
		attribute :>> num : Real;
		attribute :>> mRef : SpeedUnit;
	}
	
	attribute def Force :> ISQ::forceValue {
		attribute :>> num : Real;
		attribute :>> mRef : ForceUnit;
	}
	
	attribute def Voltage :> ISQ::voltageValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute def Current :> ISQ::electricCurrentValue {
		attribute :>> num : Real;
		attribute :>> mRef : ElectricCurrentUnit;
	}
	
	attribute def Energy :> ISQ::energyValue {
		attribute :>> num : Real;
		attribute :>> mRef : EnergyUnit;
	}
	
	attribute def Mass :> ISQ::massValue {
		attribute :>> num : Real;
		attribute :>> mRef : MassUnit;
	}
	
	attribute def Score :> ScalarValues::Integer;
	
	enum def CompetitionPhase {
		enum setup;
		enum autonomous;
		enum teleoperated;
		enum endgame;
		enum finished;
	}
	
	enum def RobotMode {
		enum idle;
		enum navigating;
		enum acquiring;
		enum transporting;
		enum depositing;
		enum fault;
	}
	
	attribute def Position {
		attribute x : Distance;
		attribute y : Distance;
		attribute theta : Real;
	}
	
	item def GamePiece {
		attribute pieceID : String;
		attribute mass : Mass;
		attribute position : Position;
		attribute isScored : Boolean;
	}
	
	port def PowerPort {
		in item voltage : Voltage;
		in item current : Current;
	}
	
	port def NavigationPort {
		in item targetPosition : Position;
		out item currentPosition : Position;
		out item velocity : Velocity;
	}
	
	port def ManipulatorPort {
		in item gripCommand : Boolean;
		in item targetForce : Force;
		out item graspedPiece : GamePiece;
		out item gripperState : Boolean;
	}
	
	port def SensorPort {
		out item detectedPieces : GamePiece[0..*];
		out item robotPose : Position;
		out item obstacleDistance : Distance;
	}
	
	port def ControlPort {
		in item modeCommand : RobotMode;
		in item phaseUpdate : CompetitionPhase;
		out item statusReport : String;
		out item currentScore : Score;
	}
	
	part def Battery {
		port powerOutput : PowerPort;
		attribute capacity : Energy;
		attribute currentCharge : Energy;
		attribute voltage : Voltage;
		
		action def DischargeEnergy {
			in powerDraw : Real;
			out remainingCharge : Energy;
		}
	}
	
	part def DriveSystem {
		port powerInput : PowerPort;
		port navigation : NavigationPort;
		attribute maxSpeed : Velocity;
		attribute wheelDiameter : Distance;
		
		action def NavigateToPosition {
			in target : Position;
			in current : Position;
			out commandVelocity : Velocity;
			out arrived : Boolean;
		}
		
		action def FollowPath {
			in waypoints : Position[1..*];
			out pathComplete : Boolean;
		}
	}
	
	part def VisionSystem {
		port sensorOutput : SensorPort;
		attribute fieldOfView : Real;
		attribute detectionRange : Distance;
		
		action def DetectGamePieces {
			out pieces : GamePiece[0..*];
			out confidence : Real;
		}
		
		action def LocalizeRobot {
			out estimatedPose : Position;
			out accuracy : Real;
		}
	}
	
	part def Manipulator {
		port powerInput : PowerPort;
		port manipControl : ManipulatorPort;
		attribute maxGripForce : Force;
		attribute reachDistance : Distance;
		
		action def GraspPiece {
			in targetPiece : GamePiece;
			in gripForce : Force;
			out success : Boolean;
			out heldPiece : GamePiece;
		}
		
		action def ReleasePiece {
			in piece : GamePiece;
			out released : Boolean;
		}
	}
	
	part def AutonomousController {
		ref port driveNav : NavigationPort;
		ref port manipPort : ManipulatorPort;
		ref port sensorPort : SensorPort;
		ref port controlPort : ControlPort;
		
		attribute currentObjective : String;
		attribute scoringZonePosition : Position;
		attribute loadingZonePosition : Position;
		
		action def PlanStrategy {
			in availablePieces : GamePiece[0..*];
			in currentPos : Position;
			out selectedPiece : GamePiece;
			out actionSequence : String[1..*];
		}
		
		action def ExecuteAutonomous {
			in phase : CompetitionPhase;
			out pointsScored : Score;
		}
	}
	
	action def CompetitionTask {
		in startPhase : CompetitionPhase;
		in scoringZone : Position;
		in loadingZone : Position;
		out finalScore : Score;
		
		first start;
		then merge taskLoop;
		
		then action scanField {
			out detectedPieces : GamePiece[0..*];
			out robotPosition : Position;
		}
		
		then decide;
			if scanField.detectedPieces->size() > 0 then selectTarget;
			if scanField.detectedPieces->size() == 0 then returnToLoad;
		
		action selectTarget {
			in availablePieces : GamePiece[0..*] = scanField.detectedPieces;
			out targetPiece : GamePiece;
		}
		
		then action navigateToPiece {
			in target : Position = selectTarget.targetPiece.position;
			in current : Position = scanField.robotPosition;
			out arrived : Boolean;
		}
		
		then action acquirePiece {
			in targetPiece : GamePiece = selectTarget.targetPiece;
			in gripForce : Force;
			out success : Boolean;
			out heldPiece : GamePiece;
		}
		
		then decide;
			if acquirePiece.success then navigateToGoal;
			if !acquirePiece.success then taskLoop;
		
		action navigateToGoal {
			in target : Position = scoringZone;
			in current : Position = scanField.robotPosition;
			out arrived : Boolean;
		}
		
		then action scorePiece {
			in piece : GamePiece = acquirePiece.heldPiece;
			out released : Boolean;
			out scored : Boolean;
			out points : Score;
		}
		
		then merge taskLoop;
		
		action returnToLoad {
			in target : Position = loadingZone;
			in current : Position = scanField.robotPosition;
			out arrived : Boolean;
		}
		
		then decide;
			if startPhase == CompetitionPhase::finished then endTask;
			else taskLoop;
		
		action endTask {
			assign finalScore = scorePiece.points;
		}
		
		then done;
	}
	
	part def CompetitionRobot {
		attribute robotID : String;
		attribute teamNumber : Integer;
		attribute currentMode : RobotMode;
		attribute totalScore : Score;
		attribute piecesCollected : Integer;
		
		port controlInterface : ControlPort;
		
		part battery : Battery {
			attribute :>> capacity {
				attribute :>> num = 1800.0;
				attribute :>> mRef = J;
			}
			attribute :>> currentCharge {
				attribute :>> num = 1800.0;
				attribute :>> mRef = J;
			}
			attribute :>> voltage {
				attribute :>> num = 12.0;
				attribute :>> mRef = V;
			}
		}
		
		part driveSystem : DriveSystem {
			attribute :>> maxSpeed {
				attribute :>> num = 3.5;
				attribute :>> mRef = m/s;
			}
			attribute :>> wheelDiameter {
				attribute :>> num = 0.15;
				attribute :>> mRef = m;
			}
		}
		
		part visionSystem : VisionSystem {
			attribute :>> fieldOfView = 120.0;
			attribute :>> detectionRange {
				attribute :>> num = 5.0;
				attribute :>> mRef = m;
			}
		}
		
		part manipulator : Manipulator {
			attribute :>> maxGripForce {
				attribute :>> num = 150.0;
				attribute :>> mRef = N;
			}
			attribute :>> reachDistance {
				attribute :>> num = 0.8;
				attribute :>> mRef = m;
			}
		}
		
		part controller : AutonomousController {
			ref port :>> driveNav = driveSystem.navigation;
			ref port :>> manipPort = manipulator.manipControl;
			ref port :>> sensorPort = visionSystem.sensorOutput;
			ref port :>> controlPort = controlInterface;
		}
		
		connection powerToDrive connect battery.powerOutput to driveSystem.powerInput;
		connection powerToManip connect battery.powerOutput to manipulator.powerInput;
		
		perform action competitionTask : CompetitionTask;
		
		state robotStateMachine {
			entry; then idleState;
			
			state idleState {
				entry assign currentMode = RobotMode::idle;
			}
			
			transition idleToNavigating
				first idleState
				accept at controlInterface.phaseUpdate
				if controlInterface.phaseUpdate == CompetitionPhase::autonomous
				then navigatingState;
			
			state navigatingState {
				entry assign currentMode = RobotMode::navigating;
				do action navigate {
					perform driveSystem.NavigateToPosition;
				}
			}
			
			transition navigatingToAcquiring
				first navigatingState
				accept when competitionTask.navigateToPiece.arrived
				then acquiringState;
			
			state acquiringState {
				entry assign currentMode = RobotMode::acquiring;
				do action acquire {
					perform manipulator.GraspPiece;
				}
			}
			
			transition acquiringToTransporting
				first acquiringState
				accept when competitionTask.acquirePiece.success
				then transportingState;
			
			state transportingState {
				entry assign currentMode = RobotMode::transporting;
				do action transport {
					perform driveSystem.NavigateToPosition;
				}
			}
			
			transition transportingToDepositing
				first transportingState
				accept when competitionTask.navigateToGoal.arrived
				then depositingState;
			
			state depositingState {
				entry assign currentMode = RobotMode::depositing;
				do action deposit {
					perform manipulator.ReleasePiece;
				}
			}
			
			transition depositingToNavigating
				first depositingState
				accept when competitionTask.scorePiece.scored
				then navigatingState;
			
			transition anyToIdle
				first navigatingState, acquiringState, transportingState, depositingState
				accept at controlInterface.phaseUpdate
				if controlInterface.phaseUpdate == CompetitionPhase::finished
				then idleState;
			
			transition anyToFault
				first navigatingState, acquiringState, transportingState, depositingState
				accept when battery.currentCharge.num < 180.0
				then faultState;
			
			state faultState {
				entry assign currentMode = RobotMode::fault;
			}
		}
	}
	
	part def CompetitionField {
		attribute fieldLength : Distance;
		attribute fieldWidth : Distance;
		attribute numberOfPieces : Integer;
		
		part gamePieces : GamePiece[20] {
			attribute :>> mass {
				attribute :>> num = 0.3;
				attribute :>> mRef = kg;
			}
			attribute :>> isScored = false;
		}
		
		attribute redScoringZone : Position {
			attribute :>> x {
				attribute :>> num = 8.0;
				attribute :>> mRef = m;
			}
			attribute :>> y {
				attribute :>> num = 4.0;
				attribute :>> mRef = m;
			}
			attribute :>> theta = 0.0;
		}
		
		attribute blueScoringZone : Position {
			attribute :>> x {
				attribute :>> num = 0.5;
				attribute :>> mRef = m;
			}
			attribute :>> y {
				attribute :>> num = 4.0;
				attribute :>> mRef = m;
			}
			attribute :>> theta = 3.14159;
		}
		
		attribute loadingStation : Position {
			attribute :>> x {
				attribute :>> num = 4.0;
				attribute :>> mRef = m;
			}
			attribute :>> y {
				attribute :>> num = 0.5;
				attribute :>> mRef = m;
			}
			attribute :>> theta = 1.5708;
		}
	}
	
	part def CompetitionManager {
		attribute currentPhase : CompetitionPhase;
		attribute matchTime : Time;
		attribute maxMatchDuration : Time;
		attribute redScore : Score;
		attribute blueScore : Score;
		
		action def StartMatch {
			out initialPhase : CompetitionPhase;
		}
		
		action def UpdatePhase {
			in elapsedTime : Time;
			out newPhase : CompetitionPhase;
		}
		
		action def CalculateScore {
			in scoredPieces : Integer;
			in bonusPoints : Integer;
			out totalScore : Score;
		}
		
		action def EndMatch {
			in redFinalScore : Score;
			in blueFinalScore : Score;
			out winner : String;
		}
	}
	
	requirement def CompetitionRequirements {
		doc /* The robot shall autonomously complete competition tasks within time limits. */
		
		requirement autonomousOperation {
			doc /* The robot shall operate autonomously during the autonomous phase. */
			subject robot : CompetitionRobot;
			require constraint { robot.currentMode != RobotMode::fault }
		}
		
		requirement scoringCapability {
			doc /* The robot shall score at least 3 game pieces during autonomous phase. */
			subject robot : CompetitionRobot;
			require constraint { robot.piecesCollected >= 3 }
		}
		
		requirement safetyCompliance {
			doc /* The robot shall operate within field boundaries and safety limits. */
			subject robot : CompetitionRobot;
			subject field : CompetitionField;
		}
		
		requirement powerManagement {
			doc /* The robot shall maintain sufficient battery charge throughout the match. */
			subject robot : CompetitionRobot;
			require constraint { robot.battery.currentCharge.num > 180.0 }
		}
	}
	
	part roboticCompetitionSystem {
		part field : CompetitionField {
			attribute :>> fieldLength {
				attribute :>> num = 8.5;
				attribute :>> mRef = m;
			}
			attribute :>> fieldWidth {
				attribute :>> num = 8.0;
				attribute :>> mRef = m;
			}
			attribute :>> numberOfPieces = 20;
		}
		
		part redRobot : CompetitionRobot {
			attribute :>> robotID = "RED-001";
			attribute :>> teamNumber = 1234;
			attribute :>> totalScore = 0;
			attribute :>> piecesCollected = 0;
			
			perform action :>> competitionTask {
				in :>> startPhase = manager.currentPhase;
				in :>> scoringZone = field.redScoringZone;
				in :>> loadingZone = field.loadingStation;
			}
		}
		
		part blueRobot : CompetitionRobot {
			attribute :>> robotID = "BLUE-001";
			attribute :>> teamNumber = 5678;
			attribute :>> totalScore = 0;
			attribute :>> piecesCollected = 0;
			
			perform action :>> competitionTask {
				in :>> startPhase = manager.currentPhase;
				in :>> scoringZone = field.blueScoringZone;
				in :>> loadingZone = field.loadingStation;
			}
		}
		
		part manager : CompetitionManager {
			attribute :>> currentPhase = CompetitionPhase::setup;
			attribute :>> maxMatchDuration {
				attribute :>> num = 150.0;
				attribute :>> mRef = s;
			}
			attribute :>> redScore = 0;
			attribute :>> blueScore = 0;
		}
		
		satisfy redRequirements : CompetitionRequirements {
			subject redRobot;
			subject field;
		}
		
		satisfy blueRequirements : CompetitionRequirements {
			subject blueRobot;
			subject field;
		}
	}
	
	action runCompetition {
		first start;
		
		then action initialize {
			out phase : CompetitionPhase;
		}
		
		then merge competitionLoop;
		
		then action updatePhase {
			in elapsedTime : Time = roboticCompetitionSystem.manager.matchTime;
			out newPhase : CompetitionPhase;
		}
		
		then decide;
			if updatePhase.newPhase != CompetitionPhase::finished &&
			   roboticCompetitionSystem.manager.matchTime.num < 
			   roboticCompetitionSystem.manager.maxMatchDuration.num
			then competitionLoop;
			if updatePhase.newPhase == CompetitionPhase::finished ||
			   roboticCompetitionSystem.manager.matchTime.num >= 
			   roboticCompetitionSystem.manager.maxMatchDuration.num
			then finalizeMatch;
		
		action finalizeMatch {
			in redFinalScore : Score = roboticCompetitionSystem.redRobot.totalScore;
			in blueFinalScore : Score = roboticCompetitionSystem.blueRobot.totalScore;
			out winner : String;
		}
		
		then done;
	}
	
	allocation def LogicalToPhysicalAllocation {
		end logical : CompetitionRobot;
		end physical : CompetitionRobot;
	}
	
	allocate redRobotAllocation : LogicalToPhysicalAllocation
		allocate roboticCompetitionSystem.redRobot 
		to roboticCompetitionSystem.redRobot {
		allocate roboticCompetitionSystem.redRobot.competitionTask 
			to roboticCompetitionSystem.redRobot.competitionTask;
		allocate roboticCompetitionSystem.redRobot.controller.ExecuteAutonomous
			to roboticCompetitionSystem.redRobot.controller.ExecuteAutonomous;
	}
	
	allocate blueRobotAllocation : LogicalToPhysicalAllocation
		allocate roboticCompetitionSystem.blueRobot 
		to roboticCompetitionSystem.blueRobot {
		allocate roboticCompetitionSystem.blueRobot.competitionTask 
			to roboticCompetitionSystem.blueRobot.competitionTask;
		allocate roboticCompetitionSystem.blueRobot.controller.ExecuteAutonomous
			to roboticCompetitionSystem.blueRobot.controller.ExecuteAutonomous;
	}
}
