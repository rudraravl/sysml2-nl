package 'Touchless Urinal System' {
	private import ScalarValues::*;
	private import ISQ::*;

	item def PersonDetected;
	item def PersonLeft;
	item def UserPresenceSignal;
	item def UserDepartureSignal;
	item def ValveOpenCommand;
	item def ValveCloseCommand;
	item def Water;
	item def Wastewater;

	part def InfraredSensor {
		port signalPort {
			out userPresence : UserPresenceSignal;
			out userDeparture : UserDepartureSignal;
		}
		exhibit state sensorStates {
			entry; then idle;
			state idle;
			accept PersonDetected
				do send new UserPresenceSignal() to signalPort
				then occupied;
			state occupied;
			accept PersonLeft
				do send new UserDepartureSignal() to signalPort
				then idle;
		}
	}

	part def FlushController {
		port sensorInputPort {
			in userPresence : UserPresenceSignal;
			in userDeparture : UserDepartureSignal;
		}
		port valveCommandPort {
			out valveOpen : ValveOpenCommand;
			out valveClose : ValveCloseCommand;
		}
		attribute flushDelay : DurationValue = 3 [s];
		attribute flushDuration : DurationValue = 5 [s];

		exhibit state controllerStates {
			entry; then idle;
			state idle;
			accept UserPresenceSignal via sensorInputPort
				then occupied;
			state occupied;
			accept UserDepartureSignal via sensorInputPort
				then delay;
			state delay;
			accept after flushDelay
				do send new ValveOpenCommand() to valveCommandPort
				then flushing;
			state flushing;
			accept after flushDuration
				do send new ValveCloseCommand() to valveCommandPort
				then idle;
		}
	}

	part def SolenoidValve {
		port valveCommandPort {
			in valveOpen : ValveOpenCommand;
			in valveClose : ValveCloseCommand;
		}
		port waterOutPort {
			out waterFlow : Water;
		}
		exhibit state valveStates {
			entry; then closed;
			state closed;
			accept ValveOpenCommand via valveCommandPort
				then open;
			state open;
			accept ValveCloseCommand via valveCommandPort
				then closed;
		}
	}

	part def CeramicBowl {
		port waterInPort {
			in waterFlow : Water;
		}
		port wasteOutPort {
			out wastewaterFlow : Wastewater;
		}
	}

	part def PTrap {
		port wasteInPort {
			in wastewaterFlow : Wastewater;
		}
		port wasteOutPort {
			out sealedWastewaterFlow : Wastewater;
		}
	}

	part def DrainPipe {
		port wasteInPort {
			in wastewaterFlow : Wastewater;
		}
	}

	part def TouchlessUrinal {
		part infraredSensor : InfraredSensor;
		part controller : FlushController;
		part solenoidValve : SolenoidValve;
		part bowl : CeramicBowl;
		part pTrap : PTrap;
		part drainPipe : DrainPipe;

		flow userPresenceFlow of UserPresenceSignal
			from infraredSensor.signalPort.userPresence to controller.sensorInputPort.userPresence;
		flow userDepartureFlow of UserDepartureSignal
			from infraredSensor.signalPort.userDeparture to controller.sensorInputPort.userDeparture;
		flow valveOpenFlow of ValveOpenCommand
			from controller.valveCommandPort.valveOpen to solenoidValve.valveCommandPort.valveOpen;
		flow valveCloseFlow of ValveCloseCommand
			from controller.valveCommandPort.valveClose to solenoidValve.valveCommandPort.valveClose;
		flow waterFlow of Water
			from solenoidValve.waterOutPort.waterFlow to bowl.waterInPort.waterFlow;
		flow wastewaterFlow of Wastewater
			from bowl.wasteOutPort.wastewaterFlow to pTrap.wasteInPort.wastewaterFlow;
		flow sealedWastewaterFlow of Wastewater
			from pTrap.wasteOutPort.sealedWastewaterFlow to drainPipe.wasteInPort.wastewaterFlow;
	}

	requirement def HygienicOperation {
		subject urinalSystem : TouchlessUrinal;
		doc /* Provide hands-free operation to improve sanitation. */
	}

	requirement def WaterConservation {
		subject urinalSystem : TouchlessUrinal;
		doc /* Conserve water by using a controlled, automated flush cycle. */
	}

	requirement def SewerGasPrevention {
		subject trap : PTrap;
		doc /* Prevent unpleasant sewer gases from backing up into the restroom. */
	}
}
