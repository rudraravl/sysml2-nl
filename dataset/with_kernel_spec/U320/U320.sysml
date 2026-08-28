package 'Nanoneedle Delivery System' {
	private import ScalarValues::*;

	item def TherapeuticPayload {
		attribute volume : Real;
	}
	item def Position {
		attribute x : Real;
		attribute y : Real;
		attribute z : Real;
	}
	item def SensorData {
		attribute force : Real;
		attribute impedance : Real;
	}
	item def PositionCommand {
		attribute x : Real;
		attribute y : Real;
		attribute z : Real;
	}
	item def InjectionCommand {
		attribute volume : Real;
		attribute activate : Boolean;
	}

	part def BiologicalCell {
		attribute viability : Boolean = true;
		attribute membraneIntact : Boolean = true;
	}

	part def NanoneedleTip {
		attribute diameter : Real = 50e-9;
		port sensorPort {
			out data : SensorData;
		}
		port payloadPort {
			in item payload : TherapeuticPayload;
		}
	}

	part def PiezoelectricPositioner {
		attribute accuracy : Real = 10e-9;
		port commandPort {
			in command : PositionCommand;
		}
		port positionPort {
			out position : Position;
		}
	}

	part def MicrofluidicInjector {
		attribute injectionVolume : Real = 10e-12;
		port commandPort {
			in command : InjectionCommand;
		}
		port payloadPort {
			out item payload : TherapeuticPayload;
		}
	}

	part def ImagingSystem {
		port imagePort {
			out location : Position;
		}
	}

	part def FeedbackController {
		port sensorPort {
			in data : SensorData;
		}
		port imagePort {
			in location : Position;
		}
		port positionFeedbackPort {
			in position : Position;
		}
		port positionCommandPort {
			out command : PositionCommand;
		}
		port injectCommandPort {
			out command : InjectionCommand;
		}
	}

	action def IdentifyCell {
		out location : Position;
	}
	action def ApproachCell {
		in location : Position;
		out position : Position;
	}
	action def DetectContact {
		in data : SensorData;
		out contactConfirmed : Boolean;
	}
	action def PenetrateMembrane {
		in contactConfirmed : Boolean;
		out depthReached : Boolean;
	}
	action def InjectPayload {
		in depthReached : Boolean;
		out injectionComplete : Boolean;
	}
	action def WithdrawNeedle {
		in injectionComplete : Boolean;
	}

	action def DeliveryProcess {
		action identify : IdentifyCell;
		then action approach : ApproachCell;
		then action detect : DetectContact;
		then if detect.contactConfirmed {
			action penetrate : PenetrateMembrane;
			then action inject : InjectPayload;
			then action withdraw : WithdrawNeedle;
		}
		then done;
	}

	part def NanoneedleDeliverySystem {
		part targetCell : BiologicalCell;
		part imager : ImagingSystem;
		part controller : FeedbackController;
		part positioner : PiezoelectricPositioner;
		part nanoneedle : NanoneedleTip;
		part injector : MicrofluidicInjector;

		flow of Position from imager.imagePort.location to controller.imagePort.location;
		flow of PositionCommand from controller.positionCommandPort.command to positioner.commandPort.command;
		flow of Position from positioner.positionPort.position to controller.positionFeedbackPort.position;
		flow of SensorData from nanoneedle.sensorPort.data to controller.sensorPort.data;
		flow of InjectionCommand from controller.injectCommandPort.command to injector.commandPort.command;
		flow of TherapeuticPayload from injector.payloadPort.payload to nanoneedle.payloadPort.payload;

		perform action delivery : DeliveryProcess;
	}

	requirement def MinInvasiveRequirement {
		text "The system must maintain cell viability above 95% post-injection.";
		attribute maxDamageThreshold : Real = 100e-9;
	}
	requirement def PositionAccuracyRequirement {
		text "Positioning accuracy must be better than 100 nanometers.";
		attribute maxPositionError : Real = 100e-9;
	}
	requirement def PayloadVolumeRequirement {
		text "Delivered volume must be controllable in the picoliter range.";
		attribute minVolume : Real = 1e-12;
		attribute maxVolume : Real = 100e-12;
	}

	part systemInstance : NanoneedleDeliverySystem {
		satisfy MinInvasiveRequirement;
		satisfy PositionAccuracyRequirement;
		satisfy PayloadVolumeRequirement;
	}
}
