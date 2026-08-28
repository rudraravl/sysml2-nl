package ProximitySensingSystem {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;

	item def MagneticField {
		attribute strength : Real;
	}
	item def ElectricCurrent {
		attribute magnitude : Real;
	}
	item def NickelIronAlloy;
	item def InertGas;

	item def Reed {
		item material : NickelIronAlloy;
		attribute stiffness : Real;
	}
	item def GlassTube {
		item fillGas : InertGas;
	}

	port def MagneticPort {
		out item field : MagneticField;
	}
	port def ElectricalPort {
		out item current : ElectricCurrent;
	}

	part def Magnet {
		port magneticOut : MagneticPort;
		attribute fieldStrength : Real;
	}
	part def PowerSource {
		port powerOut : ElectricalPort;
		attribute voltage : Real;
	}
	part def ElectricalLoad {
		port loadIn : ~ElectricalPort;
		attribute isEnergized : Boolean;

		state def LoadStates;
		state loadStates : LoadStates {
			entry; then off;
			state off;
			transition from off to on when loadIn.current.magnitude > 0.0;
			state on;
			transition from on to off when loadIn.current.magnitude == 0.0;
		}
	}

	part def ReedSwitch {
		part reed1 : Reed;
		part reed2 : Reed;
		part glassTube : GlassTube;

		port magneticIn : ~MagneticPort;
		port electricalIn : ~ElectricalPort;
		port electricalOut : ElectricalPort;

		attribute closeThreshold : Real;
		attribute openThreshold : Real;

		constraint hysteresis { closeThreshold > openThreshold }

		state def SwitchStates;
		state switchStates : SwitchStates {
			entry; then open;
			state open;
			transition from open to closed when magneticIn.field.strength >= closeThreshold;
			state closed;
			transition from closed to open when magneticIn.field.strength <= openThreshold;
		}

		action def ConductCurrent {
			in inputCurrent : ElectricCurrent;
			out outputCurrent : ElectricCurrent;
		}

		perform conduct : ConductCurrent {
			in inputCurrent = electricalIn.current;
			out outputCurrent = electricalOut.current;
		}
	}

	requirement def HermeticSealing {
		doc /* The reed switch contacts must be hermetically sealed within a glass tube filled with inert gas to prevent contamination. */
	}
	requirement def HysteresisRequirement {
		doc /* The system shall exhibit hysteresis such that the magnetic field strength required to close the switch is higher than the strength required to open it, preventing chatter. */
	}
	requirement def ProximityDetection {
		doc /* The system shall detect the presence of an external magnet and activate the electrical load when the magnet is within sufficient proximity. */
	}

	part proximitySystem {
		part magnet : Magnet;
		part reedSwitch : ReedSwitch {
			satisfy hermeticSealing : HermeticSealing;
			satisfy hysteresisReq : HysteresisRequirement;
		}
		part powerSource : PowerSource;
		part load : ElectricalLoad;

		satisfy detectionReq : ProximityDetection;

		flow of field : MagneticField
			from magnet.magneticOut.field to reedSwitch.magneticIn.field;

		flow of current : ElectricCurrent
			from powerSource.powerOut.current to reedSwitch.electricalIn.current;

		flow of current : ElectricCurrent
			from reedSwitch.electricalOut.current to load.loadIn.current;
	}
}
