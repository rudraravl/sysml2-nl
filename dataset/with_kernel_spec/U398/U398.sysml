package SmartOutletSystem {
	private import ScalarValues::Boolean;
	private import ScalarValues::Real;
	private import ScalarValues::String;

	attribute def Voltage :> Real;
	attribute def Current :> Real;
	attribute def Power :> Real;

	item def ElectricalPower {
		attribute voltage : Voltage;
		attribute current : Current;
		attribute power : Power;
	}

	enum def OutletState {
		enum offline;
		enum standby;
		enum active;
		enum tripped;
	}

	enum def FaultType {
		enum none;
		enum overcurrent;
		enum groundFault;
	}

	port def ElectricalPort {
		attribute voltage : Voltage;
		attribute current : Current;
		out item power : ElectricalPower;
	}

	action def DetectOvercurrent {
		in current : Current;
		attribute threshold : Current;
		out isFault : Boolean;
	}

	action def DetectGroundFault {
		in leakageCurrent : Current;
		attribute threshold : Current;
		out isFault : Boolean;
	}

	action def RegulateVoltage {
		in inputVoltage : Voltage;
		attribute nominalVoltage : Voltage;
		attribute tolerance : Voltage;
		out outputVoltage : Voltage;
	}

	action def DeliverPower {
		in power : ElectricalPower;
		out deliveredPower : ElectricalPower;
	}

	part def CircuitBreaker {
		in port acIn : ElectricalPort;
		out port acOut : ElectricalPort;
		attribute tripCurrent : Current = 15;
		attribute isTripped : Boolean = false;
		attribute faultType : FaultType = FaultType::overcurrent;
		action detectOvercurrent : DetectOvercurrent;
		action trip;
		action reset;
	}

	part def GFCI {
		in port acIn : ElectricalPort;
		out port acOut : ElectricalPort;
		attribute faultThreshold : Current = 0.005;
		attribute isTripped : Boolean = false;
		attribute faultType : FaultType = FaultType::groundFault;
		action detectGroundFault : DetectGroundFault;
		action trip;
		action reset;
	}

	part def VoltageRegulator {
		in port acIn : ElectricalPort;
		out port acOut : ElectricalPort;
		attribute nominalVoltage : Voltage = 120;
		attribute tolerance : Voltage = 5;
		action regulate : RegulateVoltage;
	}

	part def NEMA5_15R {
		in port acIn : ElectricalPort;
		out port deviceOut : ElectricalPort;
		attribute receptacleStandard : String = "NEMA 5-15R";
		action deliverPower : DeliverPower;
	}

	part def SmartOutlet {
		port externalAC : ElectricalPort;
		port deviceAC : ElectricalPort;

		part circuitBreaker : CircuitBreaker;
		part gfci : GFCI;
		part voltageRegulator : VoltageRegulator;
		part receptacle : NEMA5_15R;

		connect externalAC to circuitBreaker.acIn;
		connect circuitBreaker.acOut to gfci.acIn;
		connect gfci.acOut to voltageRegulator.acIn;
		connect voltageRegulator.acOut to receptacle.acIn;
		connect receptacle.deviceOut to deviceAC;

		attribute isReset : Boolean = false;
		attribute currentState : OutletState = OutletState::offline;

		state OutletStateMachine {
			state Offline;
			state Standby;
			state Active;
			state Tripped;

			transition from Offline to Standby when externalAC.voltage > 0;
			transition from Standby to Active when deviceAC.current > 0;
			transition from Active to Standby when deviceAC.current == 0;
			transition from Standby to Tripped when circuitBreaker.isTripped or gfci.isTripped;
			transition from Active to Tripped when circuitBreaker.isTripped or gfci.isTripped;
			transition from Tripped to Standby when isReset;
			transition from Standby to Offline when externalAC.voltage == 0;
		}
	}

	part smartOutlet : SmartOutlet;

	requirement def SafePowerDelivery {
		text "The system shall deliver safe, stable, and regulated electrical power to any connected device.";
	}

	requirement def OvercurrentProtection {
		text "The system shall trip and cut power if the connected device draws excessive amperage.";
	}

	requirement def GroundFaultProtection {
		text "The system shall monitor for current leakage and cut power instantly if a ground fault is detected.";
	}

	requirement def VoltageRegulation {
		text "The system shall maintain output voltage within a specified tolerance.";
	}

	requirement def StateManagement {
		text "The system shall operate through Offline, Standby, Active, and Tripped states, isolating power in Tripped until reset.";
	}

	allocate SafePowerDelivery to smartOutlet;
	allocate OvercurrentProtection to smartOutlet.circuitBreaker;
	allocate GroundFaultProtection to smartOutlet.gfci;
	allocate VoltageRegulation to smartOutlet.voltageRegulator;
	allocate StateManagement to smartOutlet;
}
