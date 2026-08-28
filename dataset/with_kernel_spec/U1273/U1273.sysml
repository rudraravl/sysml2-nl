package 'Belkin Wemo Smart Plug' {
	private import ISQ::*;
	private import ScalarValues::*;
	private import SI::*;

	item def TurnOnCommand;
	item def TurnOffCommand;
	item def ScheduleCommand {
		attribute startTime : TimeValue;
		attribute duration : TimeValue;
	}
	item def StatusReport {
		attribute instantaneousPower : PowerValue;
		attribute totalEnergy : EnergyValue;
		attribute isPowered : Boolean;
	}
	item def PowerMeasurement {
		attribute voltage : ElectricPotentialDifferenceValue;
		attribute current : ElectricCurrentValue;
	}
	item def RelayControlSignal {
		attribute closeCircuit : Boolean;
	}
	item def LEDStateSignal {
		attribute ledState : String;
	}

	attribute def WiFiConnectedSignal;
	attribute def WiFiDisconnectedSignal;

	port def WiFiCommandPort {
		in turnOn : TurnOnCommand;
		in turnOff : TurnOffCommand;
		in schedule : ScheduleCommand;
		out status : StatusReport;
	}
	port def RelayControlPort {
		out relaySignal : RelayControlSignal;
	}
	port def PowerMeasurementPort {
		out measurement : PowerMeasurement;
	}
	port def LEDControlPort {
		out ledSignal : LEDStateSignal;
	}
	port def ACPowerPort {
		inout acPower : PowerValue;
	}

	action def MeasurePower {
		in voltageIn : ElectricPotentialDifferenceValue;
		in currentIn : ElectricCurrentValue;
		in timeInterval : TimeValue;
		out powerOut : PowerValue;
		out energyDelta : EnergyValue;
	}
	action def GenerateStatusReport {
		in power : PowerValue;
		in energy : EnergyValue;
		in isPowered : Boolean;
		out report : StatusReport;
	}

	state def SmartPlugStates;
	state def NetworkStates;
	state def PowerStates;

	part def ControlProcessor {
		port wifiPort : WiFiCommandPort;
		port relayPort : RelayControlPort;
		port measurementPort : ~PowerMeasurementPort;
		port ledPort : LEDControlPort;

		attribute totalEnergy : EnergyValue = 0 [J];
		attribute currentPower : PowerValue = 0 [W];
		attribute isPowered : Boolean = false;
	}

	part def WiFiModule {
		attribute isConnected : Boolean = false;
		port commandPort : WiFiCommandPort;
	}

	part def RelaySwitch {
		port relayControlPort : ~RelayControlPort;
		port acIn : ACPowerPort;
		port acOut : ACPowerPort;
		attribute circuitClosed : Boolean = false;
	}

	part def PowerMeter {
		port acIn : ACPowerPort;
		port measurementPort : PowerMeasurementPort;
	}

	part def LEDIndicator {
		port ledControlPort : ~LEDControlPort;
		attribute currentState : String = "off";
	}

	part def SmartPlug {
		port wallInlet : ACPowerPort;
		port applianceOutlet : ACPowerPort;
		port userPort : WiFiCommandPort;

		part controlProcessor : ControlProcessor;
		part wifiModule : WiFiModule;
		part relaySwitch : RelaySwitch;
		part powerMeter : PowerMeter;
		part ledIndicator : LEDIndicator;

		flow acPowerToRelay of PowerValue
			from wallInlet.acPower to relaySwitch.acIn.acPower;
		flow acPowerToMeter of PowerValue
			from wallInlet.acPower to powerMeter.acIn.acPower;
		flow acPowerToOutlet of PowerValue
			from relaySwitch.acOut.acPower to applianceOutlet.acPower;

		flow turnOnFlow of TurnOnCommand
			from wifiModule.commandPort.turnOn to controlProcessor.wifiPort.turnOn;
		flow turnOffFlow of TurnOffCommand
			from wifiModule.commandPort.turnOff to controlProcessor.wifiPort.turnOff;
		flow scheduleFlow of ScheduleCommand
			from wifiModule.commandPort.schedule to controlProcessor.wifiPort.schedule;
		flow statusFlow of StatusReport
			from controlProcessor.wifiPort.status to wifiModule.commandPort.status;

		flow relayControlFlow of RelayControlSignal
			from controlProcessor.relayPort.relaySignal to relaySwitch.relayControlPort.relaySignal;
		flow measurementFlow of PowerMeasurement
			from powerMeter.measurementPort.measurement to controlProcessor.measurementPort.measurement;
		flow ledControlFlow of LEDStateSignal
			from controlProcessor.ledPort.ledSignal to ledIndicator.ledControlPort.ledSignal;

		bind userPort = wifiModule.commandPort;

		exhibit state smartPlugStates : SmartPlugStates parallel {
			state networkStates : NetworkStates {
				entry; then disconnected;
				state disconnected;
				accept WiFiConnectedSignal
					then connected;
				state connected;
				accept WiFiDisconnectedSignal
					then disconnected;
			}
			state powerStates : PowerStates {
				entry; then off;
				state off;
				accept TurnOnCommand
					then on;
				state on;
				accept TurnOffCommand
					then off;
			}
		}
	}

	requirement def SmartPlugRequirements {
		subject plug : SmartPlug;
		requirement ControlRequirement {
			subject cp : ControlProcessor;
			doc /* The control processor shall process TurnOn, TurnOff, and Schedule commands received via WiFi. */
		}
		requirement RelaySwitchingRequirement {
			subject rs : RelaySwitch;
			doc /* The relay shall open or close the AC circuit based on the control signal. */
		}
		requirement PowerMonitoringRequirement {
			subject pm : PowerMeter;
			doc /* The power meter shall measure voltage and current to calculate power and energy usage. */
		}
		requirement StatusReportingRequirement {
			subject cp : ControlProcessor;
			doc /* The processor shall send status reports back over WiFi. */
		}
		requirement LEDIndicationRequirement {
			subject led : LEDIndicator;
			doc /* The LED shall indicate the plug state: on, off, or connecting. */
		}
	}

	requirement smartPlugReqs : SmartPlugRequirements;
	part smartPlug : SmartPlug;
	satisfy smartPlugReqs by smartPlug;
}
