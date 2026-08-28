package IncubatorSystem {
	private import ScalarValues::*;

	attribute def Temperature :> Real { unit 'degC'; }
	attribute def Humidity :> Real { unit 'percentRH'; }
	attribute def CO2Concentration :> Real { unit 'percent'; }

	item def TemperatureReading { attribute value : Temperature; }
	item def HumidityReading { attribute value : Humidity; }
	item def CO2Reading { attribute value : CO2Concentration; }
	item def DoorStatus { attribute isOpen : Boolean; }
	item def SetPoints {
		attribute targetTemp : Temperature;
		attribute targetHumidity : Humidity;
		attribute targetCO2 : CO2Concentration;
	}
	item def ControlCommand { attribute activate : Boolean; }
	item def AlarmTrigger { attribute alarmText : String; }

	item def PowerOnSignal;
	item def StableSignal;
	item def DoorOpenSignal;
	item def DoorClosedSignal;
	item def DeviationSignal;
	item def RestoredSignal;

	part def Chamber;

	part def HeatingElement {
		port commandPort { in command : ControlCommand; }
	}
	part def HumidificationSystem {
		port commandPort { in command : ControlCommand; }
	}
	part def CO2InjectionSystem {
		port commandPort { in command : ControlCommand; }
	}

	part def TemperatureSensor {
		port readingPort { out reading : TemperatureReading; }
	}
	part def HumiditySensor {
		port readingPort { out reading : HumidityReading; }
	}
	part def CO2Sensor {
		port readingPort { out reading : CO2Reading; }
	}
	part def DoorSensor {
		port statusPort { out status : DoorStatus; }
	}

	part def UserInterface {
		port setPointsPort { out setPoints : SetPoints; }
	}

	part def AlarmSystem {
		port triggerPort { in trigger : AlarmTrigger; }
	}

	part def ControlUnit {
		port setPointsPort { in setPoints : SetPoints; }
		port tempReadingPort { in reading : TemperatureReading; }
		port humidityReadingPort { in reading : HumidityReading; }
		port co2ReadingPort { in reading : CO2Reading; }
		port doorStatusPort { in status : DoorStatus; }
		port heaterCommandPort { out command : ControlCommand; }
		port humidifierCommandPort { out command : ControlCommand; }
		port co2InjectorCommandPort { out command : ControlCommand; }
		port alarmTriggerPort { out trigger : AlarmTrigger; }

		attribute targetTemp : Temperature;
		attribute targetHumidity : Humidity;
		attribute targetCO2 : CO2Concentration;

		state def ControlStates {
			entry; then off;

			state off;
			accept PowerOnSignal then startup;

			state startup {
				entry action activateSystems {
					language "Alf"
					/*
					 * send new ControlCommand{ activate = true; } via heaterCommandPort;
					 * send new ControlCommand{ activate = true; } via humidifierCommandPort;
					 * send new ControlCommand{ activate = true; } via co2InjectorCommandPort;
					 */
				}
			}
			accept StableSignal then maintaining;
			accept DoorOpenSignal then doorOpen;

			state maintaining {
				do action regulate {
					language "Alf"
					/*
					 * if (tempReadingPort.reading.value < targetTemp) {
					 *     send new ControlCommand{ activate = true; } via heaterCommandPort;
					 * } else {
					 *     send new ControlCommand{ activate = false; } via heaterCommandPort;
					 * }
					 * if (humidityReadingPort.reading.value < targetHumidity) {
					 *     send new ControlCommand{ activate = true; } via humidifierCommandPort;
					 * } else {
					 *     send new ControlCommand{ activate = false; } via humidifierCommandPort;
					 * }
					 * if (co2ReadingPort.reading.value < targetCO2) {
					 *     send new ControlCommand{ activate = true; } via co2InjectorCommandPort;
					 * } else {
					 *     send new ControlCommand{ activate = false; } via co2InjectorCommandPort;
					 * }
					 */
				}
			}
			accept DoorOpenSignal then doorOpen;
			accept DeviationSignal then alarm;

			state doorOpen {
				entry action deactivateSystems {
					language "Alf"
					/*
					 * send new ControlCommand{ activate = false; } via heaterCommandPort;
					 * send new ControlCommand{ activate = false; } via humidifierCommandPort;
					 * send new ControlCommand{ activate = false; } via co2InjectorCommandPort;
					 */
				}
			}
			accept DoorClosedSignal then startup;

			state alarm {
				entry action soundAlarm {
					language "Alf"
					/*
					 * send new AlarmTrigger{ alarmText = "Environmental deviation detected!"; } via alarmTriggerPort;
					 */
				}
			}
			accept RestoredSignal then maintaining;
			accept DoorOpenSignal then doorOpen;
		}

		state controlStates : ControlStates;
	}

	part def Incubator {
		part chamber : Chamber;
		part heatingElement : HeatingElement;
		part humidificationSystem : HumidificationSystem;
		part co2InjectionSystem : CO2InjectionSystem;
		part temperatureSensor : TemperatureSensor;
		part humiditySensor : HumiditySensor;
		part co2Sensor : CO2Sensor;
		part doorSensor : DoorSensor;
		part userInterface : UserInterface;
		part alarmSystem : AlarmSystem;
		part controlUnit : ControlUnit;

		flow tempFlow of TemperatureReading
			from temperatureSensor.readingPort.reading to controlUnit.tempReadingPort.reading;
		flow humidityFlow of HumidityReading
			from humiditySensor.readingPort.reading to controlUnit.humidityReadingPort.reading;
		flow co2Flow of CO2Reading
			from co2Sensor.readingPort.reading to controlUnit.co2ReadingPort.reading;
		flow doorFlow of DoorStatus
			from doorSensor.statusPort.status to controlUnit.doorStatusPort.status;
		flow setPointsFlow of SetPoints
			from userInterface.setPointsPort.setPoints to controlUnit.setPointsPort.setPoints;
		flow heaterCmdFlow of ControlCommand
			from controlUnit.heaterCommandPort.command to heatingElement.commandPort.command;
		flow humidifierCmdFlow of ControlCommand
			from controlUnit.humidifierCommandPort.command to humidificationSystem.commandPort.command;
		flow co2CmdFlow of ControlCommand
			from controlUnit.co2InjectorCommandPort.command to co2InjectionSystem.commandPort.command;
		flow alarmFlow of AlarmTrigger
			from controlUnit.alarmTriggerPort.trigger to alarmSystem.triggerPort.trigger;
	}

	requirement def EnvironmentalControl {
		subject incubator : Incubator;
		objective "The incubator shall maintain temperature, humidity, and CO2 concentration within specified tolerances during the Maintaining state.";
	}

	requirement def DoorSafetyInterlock {
		subject incubator : Incubator;
		objective "The heating, humidification, and CO2 injection systems shall be disabled whenever the chamber door is open.";
	}

	requirement def AlarmNotification {
		subject incubator : Incubator;
		objective "The alarm system shall activate when any environmental parameter deviates beyond acceptable thresholds from the set points.";
	}

	requirement def StartupSequence {
		subject incubator : Incubator;
		objective "The incubator shall enter Startup mode upon power-on and transition to Maintaining when all environmental parameters reach their target values.";
	}
}
