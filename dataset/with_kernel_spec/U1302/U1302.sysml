package 'Automated Temperature Control System' {
	private import ScalarValues::*;

	package Definitions {
		attribute def TemperatureValue :> Real;
		attribute def VoltageValue :> Real;
		attribute def CurrentValue :> Real;
		attribute def TargetTemp :> TemperatureValue;

		attribute def HeaterOnSignal;
		attribute def HeaterOffSignal;
		attribute def PowerLossEvent;
		attribute def PowerRestoredEvent;
		attribute def CriticalErrorEvent;
		attribute def ErrorRecoveredEvent;

		item def AnalogSignal {
			attribute voltage : VoltageValue;
		}

		port def PowerPort {
			out voltage : VoltageValue;
			out current : CurrentValue;
		}
		port def AnalogPort {
			out signal : AnalogSignal;
		}
		port def DigitalControlPort {
			out heaterOn : HeaterOnSignal;
			out heaterOff : HeaterOffSignal;
		}

		action def ConvertAnalogToDigital {
			in analog : AnalogSignal;
			out digital : TemperatureValue;
		}
		action def ControlLoop {
			in target : TargetTemp;
			in measured1 : TemperatureValue;
			in measured2 : TemperatureValue;
			out heaterOn : HeaterOnSignal;
			out heaterOff : HeaterOffSignal;
		}
		action def EnterLowPowerMode;
		action def PerformShutdown;
		action def PerformRecovery;

		state def ControllerStates;

		part def PowerSupply {
			port powerOut : PowerPort;
		}
		part def TemperatureSensor {
			port powerIn : ~PowerPort;
			port analogOut : AnalogPort;
		}
		part def ADC {
			port analogIn : ~AnalogPort;
			port digitalOut {
				out reading : TemperatureValue;
			}
			perform action convert : ConvertAnalogToDigital;
		}
		part def Microcontroller {
			port powerIn : ~PowerPort;
			port sensorIn1 : ~AnalogPort;
			port sensorIn2 : ~AnalogPort;
			port heaterControl : DigitalControlPort;
			attribute targetTemp : TargetTemp = 25;
			attribute measuredTemp : TemperatureValue;
			part adc1 : ADC;
			part adc2 : ADC;
			bind sensorIn1 = adc1.analogIn;
			bind sensorIn2 = adc2.analogIn;
			perform action 'control loop' : ControlLoop;
			exhibit state 'controller states' : ControllerStates;
		}
		part def HeatingElement {
			port powerIn : ~PowerPort;
			port controlIn : ~DigitalControlPort;
		}

		requirement def MaintainTemperatureRequirement {
			doc "The system shall maintain ambient temperature at the target temperature (25C +/- 1C).";
			subject temp : TemperatureValue;
		}
		requirement def ReliabilityRequirement {
			doc "The microcontroller shall handle power loss and critical errors gracefully.";
		}
	}

	package Usages {
		private import Definitions::*;

		action 'control loop' : ControlLoop;
		action 'enter low power mode' : EnterLowPowerMode;
		action 'perform shutdown' : PerformShutdown;
		action 'perform recovery' : PerformRecovery;

		part tempControlSystem {
			part powerSupply : PowerSupply;
			part sensor1 : TemperatureSensor;
			part sensor2 : TemperatureSensor;
			part microcontroller : Microcontroller;
			part heater : HeatingElement;

			connect powerSupply.powerOut to sensor1.powerIn;
			connect powerSupply.powerOut to sensor2.powerIn;
			connect powerSupply.powerOut to microcontroller.powerIn;
			connect powerSupply.powerOut to heater.powerIn;
			connect sensor1.analogOut to microcontroller.sensorIn1;
			connect sensor2.analogOut to microcontroller.sensorIn2;
			connect microcontroller.heaterControl to heater.controlIn;

			requirement tempStability : MaintainTemperatureRequirement {
				subject temp = microcontroller.measuredTemp;
			}
			requirement systemReliability : ReliabilityRequirement;
		}

		state 'controller states' : ControllerStates {
			entry; then active;
			state active {
				do 'control loop';
			}
			accept PowerLossEvent
				then sleep;
			accept CriticalErrorEvent
				then shutdown;
			state sleep {
				entry 'enter low power mode';
			}
			accept PowerRestoredEvent
				then active;
			state shutdown {
				entry 'perform shutdown';
			}
			accept ErrorRecoveredEvent
				then recovery;
			state recovery {
				entry 'perform recovery';
			}
			transition recovery_to_active
				first recovery
				then active;
		}
	}
}
