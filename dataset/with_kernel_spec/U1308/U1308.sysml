package 'Intelligent Central Heating System' {
	private import ScalarValues::*;

	attribute def Temperature :> Real;
	attribute def PowerLevel :> Real;
	attribute def FaultCode :> Integer;

	item def SetpointCommand {
		attribute targetWaterTemp : Temperature;
		attribute roomSetpoint : Temperature;
	}

	item def BoilerStatus {
		attribute currentWaterTemp : Temperature;
		attribute modulationLevel : PowerLevel;
		attribute flameActive : Boolean;
		attribute faultCode : FaultCode;
	}

	item def AmbientReading {
		attribute measuredTemp : Temperature;
	}

	port def OpenThermMasterPort {
		out setpointCmd : SetpointCommand;
		in boilerStatus : BoilerStatus;
	}

	port def OpenThermSlavePort {
		in setpointCmd : SetpointCommand;
		out boilerStatus : BoilerStatus;
	}

	port def AmbientSensorPort {
		out ambientReading : AmbientReading;
	}

	interface def OpenThermInterface {
		end masterPort : OpenThermMasterPort;
		end slavePort : OpenThermSlavePort;
		flow setpointFlow of SetpointCommand
			from masterPort.setpointCmd to slavePort.setpointCmd;
		flow statusFlow of BoilerStatus
			from slavePort.boilerStatus to masterPort.boilerStatus;
	}

	part def RoomThermostat {
		attribute desiredTemperature : Temperature = 21.0;
		attribute ambientTemperature : Temperature = 20.0;
		attribute calculatedTargetWaterTemp : Temperature;

		port masterPort : OpenThermMasterPort;
		port sensorPort : AmbientSensorPort;

		state thermostatStates {
			entry; then idle;
			state idle;
			accept AmbientReading via sensorPort then evaluating;
			state evaluating {
				entry action calculateTarget {
					/* Calculate target water temperature based on difference between desired and ambient */
				}
				exit action sendSetpoint {
					send new SetpointCommand() to masterPort;
				}
			}
			then monitoring;
			state monitoring;
			accept BoilerStatus via masterPort then idle;
		}
	}

	part def ModulatingBoiler {
		attribute currentWaterTemp : Temperature = 20.0;
		attribute targetWaterTemp : Temperature;
		attribute modulationLevel : PowerLevel = 0;
		attribute flameActive : Boolean = false;
		attribute faultCode : FaultCode = 0;

		port slavePort : OpenThermSlavePort;

		state boilerStates {
			entry; then standby;
			state standby;
			accept SetpointCommand via slavePort then heating;
			state heating {
				entry action adjustBurner {
					/* Adjust burner intensity and modulation based on target water temperature */
				}
				do action heatWater {
					/* Heat water toward target temperature */
				}
				exit action sendStatus {
					send new BoilerStatus() to slavePort;
				}
			}
			accept SetpointCommand via slavePort then heating;
		}
	}

	part def HeatingSystem {
		part thermostat : RoomThermostat;
		part boiler : ModulatingBoiler;

		interface openthermLink : OpenThermInterface
			connect thermostat.masterPort to boiler.slavePort;
	}

	requirement def TemperatureControlRequirement {
		doc /* The system shall maintain the room temperature within +/- 0.5 degrees of the user setpoint. */
		subject heatingSystem : HeatingSystem;
		attribute tolerance : Temperature = 0.5;
	}

	requirement def ModulationRequirement {
		doc /* The boiler shall modulate its power output continuously between 0 and 100 percent. */
		subject boiler : ModulatingBoiler;
	}

	requirement def OpenThermCommunicationRequirement {
		doc /* The thermostat and boiler shall exchange setpoint commands and status updates continuously. */
		subject heatingSystem : HeatingSystem;
	}

	requirement def FaultReportingRequirement {
		doc /* The boiler shall report any fault codes in its status updates. */
		subject boiler : ModulatingBoiler;
	}

	requirement tempControl : TemperatureControlRequirement;
	requirement modulation : ModulationRequirement;
	requirement communication : OpenThermCommunicationRequirement;
	requirement faultReporting : FaultReportingRequirement;

	part heatingSystemInstance : HeatingSystem;

	satisfy tempControl by heatingSystemInstance;
	satisfy modulation by heatingSystemInstance.boiler;
	satisfy communication by heatingSystemInstance;
	satisfy faultReporting by heatingSystemInstance.boiler;
}
