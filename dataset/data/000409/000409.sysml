package 'March of the Machines System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MachineIdentifier :> String;
	attribute def FormationPattern :> String;
	attribute def MachineState :> String;
	attribute def BatteryLevel :> Real;
	
	attribute def Position {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute heading : Real;
	}
	
	attribute def Velocity {
		attribute speed : SpeedValue;
		attribute direction : Real;
	}
	
	item def MarchCommand {
		attribute commandType : String;
		attribute targetFormation : FormationPattern;
		attribute marchSpeed : SpeedValue;
		attribute destinationX : LengthValue;
		attribute destinationY : LengthValue;
	}
	
	item def StatusUpdate {
		attribute machineId : MachineIdentifier;
		attribute posX : LengthValue;
		attribute posY : LengthValue;
		attribute velSpeed : SpeedValue;
		attribute batteryLevel : BatteryLevel;
		attribute operationalState : MachineState;
	}
	
	item def FormationData {
		attribute pattern : FormationPattern;
		attribute spacing : LengthValue;
		attribute positionCount : Integer;
	}
	
	port def CommandInterface {
		in item commandReceived : MarchCommand;
		out item statusSent : StatusUpdate;
	}
	
	port def CoordinationInterface {
		in item neighborData : StatusUpdate;
		out item ownData : StatusUpdate;
	}
	
	port def ControlInterface {
		out item commandIssued : MarchCommand;
		in item statusReceived : StatusUpdate;
	}
	
	part def AutonomousMachine {
		attribute machineId : MachineIdentifier;
		attribute batteryCapacity : EnergyValue;
		attribute currentBattery : BatteryLevel := 100.0;
		attribute assignedPosX : LengthValue;
		attribute assignedPosY : LengthValue;
		attribute currentPosX : LengthValue;
		attribute currentPosY : LengthValue;
		attribute currentSpeed : SpeedValue;
		attribute currentDirection : Real;
		attribute positionDeviation : LengthValue;
		attribute formationTolerance : LengthValue := 2.0 [m];
		
		port commandPort : CommandInterface;
		port coordinationPort : CoordinationInterface[*];
		
		perform action executeOperation : MachineOperation;
	}
	
	part def FormationCoordinator {
		attribute activeFormation : FormationPattern;
		attribute formationTolerance : LengthValue;
		attribute machineCount : Integer;
		
		port controlPort : ControlInterface[*];
		
		perform action manageFormation : FormationManagement;
	}
	
	part def MissionController {
		attribute missionObjective : String;
		attribute totalMachines : Integer;
		attribute missionProgress : Real;
		
		port masterControl : ControlInterface;
		
		perform action orchestrateMission : MissionOrchestration;
	}
	
	state def MachineLifecycle {
		entry; then standby;
		
		state standby {
			doc /* Machine is powered and awaiting commands */
		}
		
		transition standby_to_marching
			first standby
			accept cmd : MarchCommand
			then marching;
		
		state marching {
			entry; then maintaining;
			
			state maintaining {
				doc /* Machine maintains position in formation */
			}
			
			state correcting {
				doc /* Machine adjusts trajectory to correct deviation */
			}
			
			transition maintaining_to_correcting
				first maintaining
				then correcting;
			
			transition correcting_to_maintaining
				first correcting
				then maintaining;
		}
		
		transition marching_to_recharging
			first marching
			then recharging;
		
		state recharging {
			doc /* Machine returns to charging station */
		}
		
		transition recharging_to_standby
			first recharging
			then standby;
		
		transition marching_to_halted
			first marching
			accept haltCmd : MarchCommand
			then halted;
		
		state halted {
			doc /* Machine stopped and holding position */
		}
		
		transition halted_to_standby
			first halted
			accept resetCmd : MarchCommand
			then standby;
	}
	
	action def CalculatePositionError {
		in currentPosX : LengthValue;
		in currentPosY : LengthValue;
		in targetPosX : LengthValue;
		in targetPosY : LengthValue;
		out positionError : LengthValue;
		out deviationAngle : Real;
	}
	
	action def ComputeCorrection {
		in positionError : LengthValue;
		in deviationAngle : Real;
		in currentSpeed : SpeedValue;
		out correctionSpeed : SpeedValue;
		out correctionHeading : Real;
	}
	
	action def UpdatePosition {
		in velSpeed : SpeedValue;
		in velDirection : Real;
		in deltaTime : TimeValue;
		inout posX : LengthValue;
		inout posY : LengthValue;
	}
	
	action def BroadcastStatus {
		in machineId : MachineIdentifier;
		in posX : LengthValue;
		in posY : LengthValue;
		in velSpeed : SpeedValue;
		in battery : BatteryLevel;
		in state : MachineState;
		out status : StatusUpdate;
	}
	
	action def MachineOperation {
		in command : MarchCommand;
		inout currentPosX : LengthValue;
		inout currentPosY : LengthValue;
		inout currentSpeed : SpeedValue;
		inout currentDirection : Real;
		inout battery : BatteryLevel;
		in assignedPosX : LengthValue;
		in assignedPosY : LengthValue;
		in formationTolerance : LengthValue;
		in machineId : MachineIdentifier;
		out status : StatusUpdate;
		
		first start;
		then merge operationLoop;
		
		then action calculateError : CalculatePositionError {
			in currentPosX;
			in currentPosY;
			in targetPosX = assignedPosX;
			in targetPosY = assignedPosY;
			out positionError;
			out deviationAngle;
		}
		
		then decide;
			if calculateError.positionError > formationTolerance then correct;
			if calculateError.positionError <= formationTolerance then maintain;
		
		action correct : ComputeCorrection {
			in positionError = calculateError.positionError;
			in deviationAngle = calculateError.deviationAngle;
			in currentSpeed;
			out correctionSpeed;
			out correctionHeading;
		}
		then assign currentSpeed := correct.correctionSpeed;
		then assign currentDirection := correct.correctionHeading;
		then updatePos;
		
		action maintain {
			then assign currentSpeed := command.marchSpeed;
		}
		then updatePos;
		
		action updatePos : UpdatePosition {
			in velSpeed = currentSpeed;
			in velDirection = currentDirection;
			in deltaTime = 0.1 [s];
			inout posX = currentPosX;
			inout posY = currentPosY;
		}
		
		then assign battery := battery - 0.1;
		
		then action broadcast : BroadcastStatus {
			in machineId;
			in posX = currentPosX;
			in posY = currentPosY;
			in velSpeed = currentSpeed;
			in battery;
			in state = "marching";
			out status;
		}
		
		then decide;
			if battery > 20.0 then operationLoop;
			if battery <= 20.0 then done;
	}
	
	action def GenerateFormation {
		in pattern : FormationPattern;
		in machineCount : Integer;
		in spacing : LengthValue;
		out formationData : FormationData;
	}
	
	action def AssessFormationQuality {
		in statusCount : Integer;
		in targetPattern : FormationPattern;
		out formationQuality : Real;
		out requiresCorrection : Boolean;
	}
	
	action def IssueCommands {
		in pattern : FormationPattern;
		in marchSpeed : SpeedValue;
		in destX : LengthValue;
		in destY : LengthValue;
		out commandCount : Integer;
	}
	
	action def FormationManagement {
		in statusCount : Integer;
		in activeFormation : FormationPattern;
		in machineCount : Integer;
		in formationTolerance : LengthValue;
		out commandCount : Integer;
		
		first start;
		then merge formationControl;
		
		then action generateForm : GenerateFormation {
			in pattern = activeFormation;
			in machineCount;
			in spacing = formationTolerance;
			out formationData;
		}
		
		then action assessQuality : AssessFormationQuality {
			in statusCount;
			in targetPattern = generateForm.formationData.pattern;
			out formationQuality;
			out requiresCorrection;
		}
		
		then decide;
			if assessQuality.requiresCorrection then issueCorrections;
			if not assessQuality.requiresCorrection then formationControl;
		
		action issueCorrections : IssueCommands {
			in pattern = generateForm.formationData.pattern;
			in marchSpeed = 5.0 [m/s];
			in destX = 1000.0 [m];
			in destY = 1000.0 [m];
			out commandCount;
		}
		
		then formationControl;
	}
	
	action def PlanMissionPhases {
		in objective : String;
		out formationCount : Integer;
		out speedCount : Integer;
		out waypointCount : Integer;
	}
	
	action def MonitorProgress {
		in statusCount : Integer;
		in waypointCount : Integer;
		out progress : Real;
		out currentPhase : Integer;
	}
	
	action def MissionOrchestration {
		in objective : String;
		in totalMachines : Integer;
		out commandCount : Integer;
		
		first start;
		
		then action planPhases : PlanMissionPhases {
			in objective;
			out formationCount;
			out speedCount;
			out waypointCount;
		}
		
		then merge executeMission;
		
		then action monitorMission : MonitorProgress {
			in statusCount = totalMachines;
			in waypointCount = planPhases.waypointCount;
			out progress;
			out currentPhase;
		}
		
		then decide;
			if monitorMission.progress < 100.0 then continuePhase;
			if monitorMission.progress >= 100.0 then completeMission;
		
		action continuePhase {
			then assign commandCount := planPhases.formationCount;
		}
		then executeMission;
		
		action completeMission {
			then assign commandCount := 0;
		}
		then done;
	}
	
	part marchOfMachinesSystem {
		attribute systemObjective : String = "Execute coordinated autonomous march across terrain";
		attribute fleetSize : Integer = 100;
		attribute defaultFormation : FormationPattern = "wedge";
		attribute operationalRange : LengthValue = 50.0 [km];
		
		part missionController : MissionController {
			attribute :>> missionObjective = systemObjective;
			attribute :>> totalMachines = fleetSize;
			attribute :>> missionProgress = 0.0;
			
			perform action orchestrateMission;
		}
		
		part formationCoordinator : FormationCoordinator {
			attribute :>> activeFormation = defaultFormation;
			attribute :>> formationTolerance = 2.0 [m];
			attribute :>> machineCount = fleetSize;
			
			perform action manageFormation;
		}
		
		part machineFleet : AutonomousMachine[100] {
			attribute :>> batteryCapacity = 500.0 [kW*h];
			attribute :>> currentBattery = 100.0;
			
			perform action executeOperation;
		}
		
		connect missionController.masterControl to formationCoordinator.controlPort;
		connect formationCoordinator.controlPort to machineFleet.commandPort;
		connect machineFleet.coordinationPort to machineFleet.coordinationPort;
	}
	
	requirement def PrimaryMissionRequirement {
		doc /* The system shall coordinate autonomous machines to march in formation across designated terrain. */
		subject system : MarchOfMachinesSystem;
	}
	
	requirement def FormationPrecisionRequirement {
		doc /* Machines shall maintain formation positions within 2 meters of assigned coordinates. */
		require constraint {
			positionError : LengthValue;
			positionError <= 2.0 [m]
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* Machines shall respond to formation commands within 1 second. */
		require constraint {
			responseTime : TimeValue;
			responseTime <= 1.0 [s]
		}
	}
	
	requirement def EnduranceRequirement {
		doc /* Machines shall operate continuously for at least 8 hours on full battery. */
		require constraint {
			operationTime : TimeValue;
			batteryLevel : BatteryLevel;
			operationTime >= 8.0 [h] or batteryLevel > 20.0
		}
	}
	
	requirement def CoordinationRequirement {
		doc /* All machines shall maintain communication with neighbors within 100 meters. */
		require constraint {
			communicationRange : LengthValue;
			communicationRange >= 100.0 [m]
		}
	}
	
	requirement <'SYS-MARCH-001'> systemMissionRequirement : PrimaryMissionRequirement {
		subject marchOfMachinesSystem;
		
		require formationPrecision : FormationPrecisionRequirement;
		require commandResponse : ResponseTimeRequirement;
		require operationalEndurance : EnduranceRequirement;
		require machineCoordination : CoordinationRequirement;
	}
	
	part def MarchOfMachinesSystem :> marchOfMachinesSystem;
}
