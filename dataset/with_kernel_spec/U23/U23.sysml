package FleetCommandAndControl {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	attribute def Position {
		attribute x : LengthValue;
		attribute y : LengthValue;
	}

	item def MissionDirective {
		attribute destination : Position;
		attribute phase : String;
		attribute goal : String;
	}

	item def MarchingOrder {
		attribute assignedPosition : Position;
		attribute targetSpeed : SpeedValue;
		attribute destination : Position;
	}

	item def StatusUpdate {
		attribute currentPosition : Position;
		attribute currentSpeed : SpeedValue;
		attribute batteryLevel : Real;
	}

	item def CorrectionCommand {
		attribute deltaHeading : PlaneAngleValue;
		attribute deltaSpeed : SpeedValue;
	}

	item def NeighborStatus {
		attribute currentPosition : Position;
		attribute currentSpeed : SpeedValue;
		attribute batteryLevel : Real;
	}

	enum def FormationPattern {
		wedge;
		line;
		column;
	}

	port def DirectiveOutPort {
		out directive : MissionDirective;
	}

	port def DirectiveInPort {
		in directive : MissionDirective;
	}

	port def CommandOutPort {
		out order : MarchingOrder;
		out correction : CorrectionCommand;
	}

	port def CommandInPort {
		in order : MarchingOrder;
		in correction : CorrectionCommand;
	}

	port def StatusOutPort {
		out status : StatusUpdate;
	}

	port def StatusInPort {
		in status : StatusUpdate;
	}

	port def NeighborCommPort {
		out ownStatus : NeighborStatus;
		in neighborStatus : NeighborStatus;
	}

	part def MissionController {
		port directivePort : DirectiveOutPort;
		port reportPort : StatusInPort;
		attribute missionDestination : Position;
		attribute currentPhase : String;
		attribute missionGoal : String;

		action defineGoal { out goal : String; }
		action planPhases { out phases : String; }
		action monitorProgress { out progress : String; }

		exhibit state missionStates {
			entry; then planning;
			state planning {
				entry defineGoal;
				do planPhases;
			}
			accept after 10 [s] then monitoring;
			state monitoring {
				do monitorProgress;
			}
			accept when monitorProgress.progress == "COMPLETE" then complete;
			state complete;
		}
	}

	part def FormationCoordinator {
		port directiveIn : DirectiveInPort;
		port commandOut : CommandOutPort;
		port statusIn : StatusInPort;
		attribute activePattern : FormationPattern = FormationPattern::wedge;
		attribute tolerance : LengthValue = 2.0 [m];
		attribute fleetDestination : Position;

		action assessPositions { out deviation : LengthValue; }
		action calculateIdealPositions { out idealPositions : Position; }
		action issueCorrections { out correction : CorrectionCommand; }
		action generateOrders { out order : MarchingOrder; }

		exhibit state coordinationStates {
			entry; then assessing;
			do assessPositions;
			state assessing {
				do calculateIdealPositions;
			}
			accept when assessPositions.deviation > tolerance
				do issueCorrections
				then correcting;
			state correcting {
				entry issueCorrections;
				do generateOrders;
			}
			accept when assessPositions.deviation <= tolerance
				then assessing;
		}
	}

	part def AutonomousMachine {
		port commandIn : CommandInPort;
		port statusOut : StatusOutPort;
		port neighborPort : NeighborCommPort;
		attribute id : Integer;
		attribute currentPosition : Position;
		attribute currentSpeed : SpeedValue;
		attribute batteryLevel : Real = 100.0;
		attribute maxDeviation : LengthValue = 2.0 [m];
		attribute assignedPosition : Position;
		attribute assignedSpeed : SpeedValue;
		attribute destination : Position;
		attribute basePosition : Position;

		action sensePosition { out position : Position; }
		action senseBattery { out level : Real; }
		action broadcastStatus { out status : StatusUpdate; }
		action calculateDeviation { out dev : LengthValue; }
		action calculateCorrection;
		action applyCorrection;
		action navigate;
		action chargeBattery { out level : Real; }

		action senseStatus {
			first start;
			then sensePosition;
			then senseBattery;
			then calculateDeviation;
			then done;
		}

		exhibit state machineStates {
			entry; then standby;
			do senseStatus;
			state standby;
			accept MarchingOrder
				then marching;
			state marching {
				entry broadcastStatus;
				do navigate;
			}
			accept when calculateDeviation.dev > maxDeviation
				then correcting;
			accept when senseBattery.level < 20.0
				then recharging;
			state correcting {
				entry calculateCorrection;
				do applyCorrection;
			}
			accept when calculateDeviation.dev <= maxDeviation
				then marching;
			accept when senseBattery.level < 20.0
				then recharging;
			state recharging {
				do chargeBattery;
			}
			accept when chargeBattery.level >= 100.0
				then standby;
		}
	}

	requirement def FormationToleranceRequirement {
		doc /* The fleet shall maintain formation such that no machine deviates from its assigned position by more than 2 meters. */
		attribute maxDeviation : LengthValue = 2.0 [m];
	}

	requirement def EnduranceRequirement {
		doc /* Each machine shall be capable of operating for at least 8 hours before needing to recharge. */
		attribute minOperatingTime : DurationValue = 8 [h];
	}

	requirement def FleetSizeRequirement {
		doc /* The system shall manage a fleet of exactly 100 autonomous machines. */
		attribute fleetSize : Integer = 100;
	}

	part fleetSystem {
		part missionController : MissionController;
		part formationCoordinator : FormationCoordinator;
		part machines : AutonomousMachine[100];

		flow directiveFlow of MissionDirective
			from missionController.directivePort.directive
			to formationCoordinator.directiveIn.directive;
		flow orderFlow of MarchingOrder
			from formationCoordinator.commandOut.order
			to machines.commandIn.order;
		flow correctionFlow of CorrectionCommand
			from formationCoordinator.commandOut.correction
			to machines.commandIn.correction;
		flow statusFlow of StatusUpdate
			from machines.statusOut.status
			to formationCoordinator.statusIn.status;
		flow neighborFlow of NeighborStatus
			from machines.neighborPort.ownStatus
			to machines.neighborPort.neighborStatus;

		requirement formationTolerance : FormationToleranceRequirement;
		requirement endurance : EnduranceRequirement;
		requirement fleetSize : FleetSizeRequirement;

		satisfy formationTolerance by formationCoordinator;
		satisfy endurance by machines;
		satisfy fleetSize by machines;
	}
}
