// Define a heating system that adjusts the temperature when there is a trigger.
package 'Heating System' {
	private import ScalarValues::*;

	// --- Value Type Definitions for Temperature ---
	abstract attribute def TemperatureUnit;
	attribute def Celsius :> TemperatureUnit;

	attribute def TemperatureValue :> QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : TemperatureUnit = Celsius;
	}

	// --- Enumeration for Heater Commands ---
	enumeration def HeaterCommand {
		literal On;
		literal Off;
	}

	// --- Port Definitions for System Components ---
	port def TemperatureSource {
		out attribute currentTemperature : TemperatureValue;
	}

	port def HeaterControl {
		in item command : HeaterCommand;
	}

	// --- Component Part Definitions ---
	part def TemperatureSensor {
		port source : TemperatureSource;
		attribute internalTemperature : TemperatureValue;
		bind source.currentTemperature = internalTemperature;
	}

	part def Heater {
		port control : HeaterControl;
		attribute heatingIsActive : Boolean = false;

		state machine HeaterSM {
			initial; then Off;

			state Off {
				entry assign heatingIsActive = false;
			}
			accept control.command
			if control.command == HeaterCommand::On
			then Heating;

			state Heating {
				entry assign heatingIsActive = true;
			}
			accept control.command
			if control.command == HeaterCommand::Off
			then Off;
		}
	}

	part def Thermostat {
		attribute targetTemperature : TemperatureValue;
		attribute tolerance : TemperatureValue;

		in attribute measuredTemperature : TemperatureValue;
		out item command : HeaterCommand;

		state machine ControlLogic {
			initial; then Idle;

			state Idle {
				entry assign command = HeaterCommand::Off;
			}
			when measuredTemperature.num < (targetTemperature.num - tolerance.num)
			then Active;

			state Active {
				entry assign command = HeaterCommand::On;
			}
			when measuredTemperature.num >= (targetTemperature.num + tolerance.num)
			then Idle;
		}
	}

	// --- System Assembly ---
	part def HeatingSystem {
		attribute roomTemperature : TemperatureValue = TemperatureValue { num = 18.0 };
		attribute desiredTemperature : TemperatureValue = TemperatureValue { num = 21.0 };
		attribute tempTolerance : TemperatureValue = TemperatureValue { num = 0.5 };

		part sensor : TemperatureSensor {
			bind internalTemperature = roomTemperature;
		}

		part thermostat : Thermostat {
			bind targetTemperature = desiredTemperature;
			bind tolerance = tempTolerance;
			bind measuredTemperature = sensor.source.currentTemperature;
		}

		part heater : Heater;

		connection from thermostat to heater.control;
	}

	// --- Requirements Definition ---
	requirement def MaintainTemperature {
		subject sys : HeatingSystem;
		doc "The system shall activate the heater when the room temperature falls below a lower bound
		     and deactivate it when the temperature rises above an upper bound, relative to the desired temperature.";

		require constraint HeaterActivation {
			doc "Heater must be on if temperature is below the lower threshold."
			sys.roomTemperature.num < (sys.desiredTemperature.num - sys.tempTolerance.num) implies
			sys.thermostat.command == HeaterCommand::On;
		}

		require constraint HeaterDeactivation {
			doc "Heater must be off if temperature is above the upper threshold."
			sys.roomTemperature.num >= (sys.desiredTemperature.num + sys.tempTolerance.num) implies
			sys.thermostat.command == HeaterCommand::Off;
		}
	}

	// --- Verification of Requirements ---
	part system : HeatingSystem;
	satisfy requirement MaintainTemperature by system.thermostat.ControlLogic {
		subject sys = system;
	}
}
