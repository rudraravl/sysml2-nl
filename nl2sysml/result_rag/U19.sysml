// Define a heating system that adjusts the temperature when there is a trigger.
package 'Heating System Example' {
	import ISQ::*;
	import ScalarValues::*;

	// Define custom value types for temperature using Celsius
	attribute def CelsiusUnit :> SimpleUnit;
	attribute def Temperature :> ScalarQuantityValue {
		attribute redefines num : Real;
		attribute redefines mRef : CelsiusUnit;
	}

	// Define items for control signals
	item def ControlSignal;
	item def OnSignal :> ControlSignal;
	item def OffSignal :> ControlSignal;

	// Define ports for component interfaces
	port def SensorPort {
		out temperatureReading : Temperature;
	}

	port def ActuatorPort {
		in command : ControlSignal;
	}

	// Define the behavior of the thermostat as a state machine
	state machine def ThermostatLogic {
		in currentTemp : Temperature;
		in setpoint : Temperature;
		in tolerance : Temperature;
		out commandSignal : ControlSignal;

		entry; then Idle;

		state Idle {
			transition activate to Heating
				accept change on currentTemp
				if currentTemp < (setpoint - tolerance)
				do commandSignal = new OnSignal();
		}

		state Heating {
			transition deactivate to Idle
				accept change on currentTemp
				if currentTemp >= setpoint
				do commandSignal = new OffSignal();
		}
	}

	// Define the physical and logical components of the system
	part def TemperatureSensor {
		attribute ambientTemperature : Temperature;
		port output : SensorPort;
		bind output.temperatureReading = ambientTemperature;
	}

	part def Furnace {
		port input : ActuatorPort;
		attribute status : Enumeration { literal on, off; } = off;

		action updateStatus {
			in signal : ControlSignal;
			if signal is OnSignal {
				status = on;
			} else if signal is OffSignal {
				status = off;
			}
		}
		accept input.command as sig {
			perform updateStatus(sig);
		}
	}

	part def Thermostat {
		attribute setpoint : Temperature = 20.0; // Default setpoint in Celsius
		attribute tolerance : Temperature = 1.0;  // Tolerance band in Celsius
		port sensorPort : ~SensorPort;
		port actuatorPort : ~ActuatorPort;

		state logic : ThermostatLogic {
			bind currentTemp = sensorPort.temperatureReading;
			bind setpoint = self.setpoint;
			bind tolerance = self.tolerance;
			bind actuatorPort.command = commandSignal;
		}
	}

	// Define the top-level heating system
	part def HeatingSystem {
		attribute desiredTemperature : Temperature;

		part sensor : TemperatureSensor;
		part furnace : Furnace;
		part thermostat : Thermostat {
			bind setpoint = desiredTemperature;
		}

		connection from sensor.output to thermostat.sensorPort;
		connection from thermostat.actuatorPort to furnace.input;
	}

	// Define system requirements
	requirement def TemperatureRegulation {
		text "The system shall maintain the ambient temperature near a desired setpoint.";
	}

	requirement Activation :> TemperatureRegulation {
		subject system : HeatingSystem;
		text "The furnace shall be activated when the ambient temperature,
		      as measured by the sensor, drops below the thermostat's
		      setpoint minus a tolerance.";
	}

	requirement Deactivation :> TemperatureRegulation {
		subject system : HeatingSystem;
		text "The furnace shall be deactivated when the ambient temperature,
		      as measured by the sensor, reaches or exceeds the
		      thermostat's setpoint.";
	}

	// Verify that the design satisfies the requirements
	view 'Requirements Verification' {
		exhibit system : HeatingSystem;

		satisfy requirement Activation by system.thermostat.logic.activate;
		satisfy requirement Deactivation by system.thermostat.logic.deactivate;
	}
}
