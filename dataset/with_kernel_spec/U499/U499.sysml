package 'Automated Liquid Level Control System' {
	private import ScalarValues::*;

	item def Liquid;
	item def SwitchSignal {
		attribute closed : Boolean;
	}

	port def LiquidPort {
		out item liquid : Liquid;
	}
	port def SignalPort {
		out item switchSignal : SwitchSignal;
	}

	part def LiquidSource {
		port liquidOutPort : LiquidPort;
	}

	part def LiquidTank {
		port liquidInPort : ~LiquidPort;
		port liquidOutPort : LiquidPort;
		attribute capacity : Real = 3.0;
		attribute currentLevel : Real;
		item storedLiquid : Liquid;
	}

	part def FloatMechanism {
		attribute floatPosition : Real;
	}

	part def ElectricalContact {
		port signalOutPort : SignalPort;
		attribute isClosed : Boolean;
	}

	part def FloatSwitch {
		part floatMechanism : FloatMechanism;
		part electricalContact : ElectricalContact;
		attribute activationLevel : Real = 2.5;
		attribute deactivationLevel : Real = 0.5;
	}

	action def PumpLiquid {
		in liquidIn : Liquid;
		in switchSignal : SwitchSignal;
		out liquidOut : Liquid;
	}

	part def Pump {
		port liquidInPort : ~LiquidPort;
		port liquidOutPort : LiquidPort;
		port signalInPort : ~SignalPort;
		attribute isActive : Boolean;
		attribute flowRate : Real;

		perform action pumpLiquid : PumpLiquid {
			in liquidIn = liquidInPort.liquid;
			in switchSignal = signalInPort.switchSignal;
			out liquidOut = liquidOutPort.liquid;
		}
	}

	part def Drain {
		port liquidInPort : ~LiquidPort;
	}

	requirement def PreventOverflow {
		subject tank : LiquidTank;
		objective {
			doc /* The system shall prevent the tank from overflowing by activating the pump when the liquid level reaches the activation level. */
			constraint { tank.currentLevel <= tank.capacity }
		}
	}

	requirement def HysteresisControl {
		subject floatSwitch : FloatSwitch;
		objective {
			doc /* The difference between activation and deactivation levels shall be sufficient to prevent rapid pump cycling. */
			constraint { floatSwitch.activationLevel > floatSwitch.deactivationLevel }
		}
	}

	part context {
		part source : LiquidSource;
		part tank : LiquidTank;
		part floatSwitch : FloatSwitch;
		part pump : Pump;
		part drain : Drain;

		flow of liquid : Liquid
			from source.liquidOutPort.liquid to tank.liquidInPort.liquid;
		flow of liquid : Liquid
			from tank.liquidOutPort.liquid to pump.liquidInPort.liquid;
		flow of liquid : Liquid
			from pump.liquidOutPort.liquid to drain.liquidInPort.liquid;
		flow of switchSignal : SwitchSignal
			from floatSwitch.electricalContact.signalOutPort.switchSignal to pump.signalInPort.switchSignal;

		constraint floatTracksLevel {
			floatSwitch.floatMechanism.floatPosition == tank.currentLevel;
		}

		state machine controlSystemBehavior {
			initial state idle;
			state pumping;

			transition first idle
				if tank.currentLevel >= floatSwitch.activationLevel
				then pumping;

			transition first pumping
				if tank.currentLevel <= floatSwitch.deactivationLevel
				then idle;
		}

		satisfy PreventOverflow by controlSystemBehavior;
		satisfy HysteresisControl by floatSwitch;
	}
}
