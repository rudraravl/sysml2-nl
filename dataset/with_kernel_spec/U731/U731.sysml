package 'Infrared Thermometer' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	attribute def TriggerPulled;
	attribute def TriggerReleased;
	attribute def ModeSelect;
	attribute def PowerOn;
	attribute def PowerOff;
	attribute def InactivityTimeout;
	attribute def LowBatteryAlert;

	item def InfraredEnergy;
	item def ElectricalVoltage;
	item def DigitalValue;
	item def TemperatureReading;
	item def LaserDot;

	enum def MeasurementMode {
		singlePoint;
		continuousScan;
		maximum;
		minimum;
		average;
	}

	attribute def EmissivityValue {
		attribute value : Real = 0.95;
	}

	part def OpticalLens {
		out item irEnergy : InfraredEnergy;
	}

	part def ThermopileSensor {
		in item irEnergy : InfraredEnergy;
		out item rawVoltage : ElectricalVoltage;
	}

	part def SignalAmplifier {
		in item rawVoltage : ElectricalVoltage;
		out item amplifiedVoltage : ElectricalVoltage;
	}

	part def AnalogToDigitalConverter {
		in item amplifiedVoltage : ElectricalVoltage;
		out item digitalValue : DigitalValue;
	}

	part def AmbientTemperatureSensor {
		out ambientTemp : TemperatureValue;
	}

	part def Microcontroller {
		in item digitalValue : DigitalValue;
		in ambientTemp : TemperatureValue;
		in emissivity : EmissivityValue;
		in mode : MeasurementMode;
		out item reading : TemperatureReading;
	}

	part def LCDDisplay {
		in item reading : TemperatureReading;
	}

	part def LaserPointer {
		out item dot : LaserDot;
	}

	part def PowerSupply {
		out item regulatedVoltage : ElectricalVoltage;
		attribute batteryLevel : Real;
	}

	part def TriggerButton {
		out triggerSignal : TriggerPulled;
		out releaseSignal : TriggerReleased;
	}

	part def ModeSelector {
		out modeSignal : ModeSelect;
	}

	action def GatherIR {
		out item irEnergy : InfraredEnergy;
	}

	action def SenseIR {
		in item irEnergy : InfraredEnergy;
		out item rawVoltage : ElectricalVoltage;
	}

	action def AmplifyVoltage {
		in item rawVoltage : ElectricalVoltage;
		out item amplifiedVoltage : ElectricalVoltage;
	}

	action def DigitizeVoltage {
		in item amplifiedVoltage : ElectricalVoltage;
		out item digitalValue : DigitalValue;
	}

	action def ComputeTemperature {
		in item digitalValue : DigitalValue;
		in ambientTemp : TemperatureValue;
		in emissivity : EmissivityValue;
		out item reading : TemperatureReading;
	}

	action def MeasureTemperature {
		in item irEnergy : InfraredEnergy;
		in ambientTemp : TemperatureValue;
		in emissivity : EmissivityValue;
		out item reading : TemperatureReading;
		action gather : GatherIR {
			out item irEnergy;
		}
		flow gather.irEnergy to sense.irEnergy;
		action sense : SenseIR {
			in item irEnergy;
			out item rawVoltage;
		}
		flow sense.rawVoltage to amplify.rawVoltage;
		action amplify : AmplifyVoltage {
			in item rawVoltage;
			out item amplifiedVoltage;
		}
		flow amplify.amplifiedVoltage to convert.amplifiedVoltage;
		action convert : DigitizeVoltage {
			in item amplifiedVoltage;
			out item digitalValue;
		}
		flow convert.digitalValue to compute.digitalValue;
		action compute : ComputeTemperature {
			in item digitalValue;
			in ambientTemp;
			in emissivity;
			out item reading;
		}
	}

	state def PowerStates {
		in powerSupply : PowerSupply;
		in ambientSensor : AmbientTemperatureSensor;
		in lcdDisplay : LCDDisplay;
		in emissivityValue : EmissivityValue;
		entry; then off;
		state off;
		accept triggerSignal : TriggerPulled
			then standby;
		state standby;
		accept triggerSignal : TriggerPulled
			then measuring;
		accept when powerSupply.batteryLevel < 0.15
			then sleep;
		state measuring {
			entry action measure : MeasureTemperature {
				in ambientTemp = ambientSensor.ambientTemp;
				in emissivity = emissivityValue;
			}
			flow measure.reading to lcdDisplay.reading;
		}
		accept triggerReleased : TriggerReleased
			then displaying;
		state displaying;
		accept after 10 [s]
			then standby;
		accept InactivityTimeout
			then sleep;
		state sleep;
		accept triggerSignal : TriggerPulled
			then standby;
		accept PowerOff
			then off;
	}

	part def InfraredThermometer {
		part opticalLens : OpticalLens;
		part thermopileSensor : ThermopileSensor;
		part signalAmplifier : SignalAmplifier;
		part adc : AnalogToDigitalConverter;
		part ambientSensor : AmbientTemperatureSensor;
		part microcontroller : Microcontroller;
		part lcdDisplay : LCDDisplay;
		part laserPointer : LaserPointer;
		part powerSupply : PowerSupply;
		part triggerButton : TriggerButton;
		part modeSelector : ModeSelector;

		attribute emissivity : EmissivityValue;
		attribute currentMode : MeasurementMode = MeasurementMode::singlePoint;

		flow opticalLens.irEnergy to thermopileSensor.irEnergy;
		flow thermopileSensor.rawVoltage to signalAmplifier.rawVoltage;
		flow signalAmplifier.amplifiedVoltage to adc.amplifiedVoltage;
		flow adc.digitalValue to microcontroller.digitalValue;
		flow ambientSensor.ambientTemp to microcontroller.ambientTemp;
		flow microcontroller.reading to lcdDisplay.reading;

		state powerState : PowerStates {
			in powerSupply = self.powerSupply;
			in ambientSensor = self.ambientSensor;
			in lcdDisplay = self.lcdDisplay;
			in emissivityValue = self.emissivity;
		}
	}

	requirement def TemperatureAccuracyRequirement {
		subject thermometer : InfraredThermometer;
		in targetTemp : TemperatureValue;
		in measuredTemp : TemperatureValue;
		constraint accuracyConstraint {
			(targetTemp - measuredTemp) <= 2.0 [K] and
			(measuredTemp - targetTemp) <= 2.0 [K]
		}
	}

	requirement def MeasurementRangeRequirement {
		subject thermometer : InfraredThermometer;
		in reading : TemperatureValue;
		constraint rangeConstraint {
			reading >= 223.15 [K] and
			reading <= 653.15 [K]
		}
	}

	requirement def BatteryLifeRequirement {
		subject thermometer : InfraredThermometer;
		in batteryLevel : Real;
		constraint batteryConstraint {
			batteryLevel >= 0.10
		}
	}
}
