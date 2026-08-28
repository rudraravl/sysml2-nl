package 'EGT Gauge System' {
	private import ISQ::*;
	private import ScalarValues::*;

	package Definitions {
		alias TemperatureValue for ISQ::TemperatureValue;
		alias VoltageValue for ISQ::ElectricPotentialValue;

		item def RawSignal {
			attribute voltage : VoltageValue;
		}
		item def ConditionedSignal {
			attribute voltage : VoltageValue;
		}
		item def DigitalTempData {
			attribute temperature : TemperatureValue;
		}
		item def WarningCommand {
			attribute activate : Boolean;
		}
		item def Power12V {
			attribute voltage : VoltageValue = 12;
		}
		item def Power5V {
			attribute voltage : VoltageValue = 5;
		}

		port def RawSignalOutPort {
			out rawSignal : RawSignal;
		}
		port def RawSignalInPort {
			in rawSignal : RawSignal;
		}
		port def ConditionedSignalOutPort {
			out conditionedSignal : ConditionedSignal;
		}
		port def ConditionedSignalInPort {
			in conditionedSignal : ConditionedSignal;
		}
		port def TempDataOutPort {
			out tempData : DigitalTempData;
		}
		port def TempDataInPort {
			in tempData : DigitalTempData;
		}
		port def WarningOutPort {
			out warningCmd : WarningCommand;
		}
		port def WarningInPort {
			in warningCmd : WarningCommand;
		}
		port def Power12VInPort {
			in power : Power12V;
		}
		port def Power5VOutPort {
			out power : Power5V;
		}
		port def Power5VInPort {
			in power : Power5V;
		}

		action def MeasureTemperature {
			out rawSignal : RawSignal;
		}
		action def ConditionSignal {
			in rawSignal : RawSignal;
			out conditionedSignal : ConditionedSignal;
		}
		action def ProcessTemperature {
			in conditionedSignal : ConditionedSignal;
			out tempData : DigitalTempData;
			out warningCmd : WarningCommand;
		}
		action def DisplayTemperature {
			in tempData : DigitalTempData;
		}
		action def ActivateWarning {
			in warningCmd : WarningCommand;
		}
		action def BlinkWarning;
		action def ConvertPower {
			in inputPower : Power12V;
			out outputPower : Power5V;
		}

		state def SystemStates;

		part def ThermocoupleSensor {
			attribute sensorType = "K";
			port signalOut : RawSignalOutPort;
			port powerIn : Power5VInPort;
			perform action measure : MeasureTemperature;
		}

		part def SignalConditioner {
			port signalIn : RawSignalInPort;
			port signalOut : ConditionedSignalOutPort;
			port powerIn : Power5VInPort;
			perform action condition : ConditionSignal;
		}

		part def Microcontroller {
			port signalIn : ConditionedSignalInPort;
			port tempOut : TempDataOutPort;
			port warningOut : WarningOutPort;
			port powerIn : Power5VInPort;
			attribute safetyLimit : TemperatureValue = 900;
			attribute currentTemp : TemperatureValue;
			perform action process : ProcessTemperature;
		}

		part def LCDDisplay {
			port tempIn : TempDataInPort;
			port powerIn : Power5VInPort;
			perform action display : DisplayTemperature;
		}

		part def WarningIndicator {
			port warningIn : WarningInPort;
			port powerIn : Power5VInPort;
			perform action alert : ActivateWarning;
			perform action blink : BlinkWarning;
		}

		part def PowerSupply {
			port powerIn : Power12VInPort;
			port powerOut : Power5VOutPort;
			perform action convert : ConvertPower;
		}

		part def EGTGaugeAssembly {
			port powerInput : Power12VInPort;
			part thermocouple : ThermocoupleSensor;
			part conditioner : SignalConditioner;
			part microcontroller : Microcontroller;
			part lcdDisplay : LCDDisplay;
			part warningIndicator : WarningIndicator;
			part powerSupply : PowerSupply;

			flow from thermocouple.signalOut to conditioner.signalIn;
			flow from conditioner.signalOut to microcontroller.signalIn;
			flow from microcontroller.tempOut to lcdDisplay.tempIn;
			flow from microcontroller.warningOut to warningIndicator.warningIn;
			flow from powerSupply.powerOut to thermocouple.powerIn;
			flow from powerSupply.powerOut to conditioner.powerIn;
			flow from powerSupply.powerOut to microcontroller.powerIn;
			flow from powerSupply.powerOut to lcdDisplay.powerIn;
			flow from powerSupply.powerOut to warningIndicator.powerIn;
			flow from powerInput to powerSupply.powerIn;

			exhibit state 'system states' : SystemStates;
		}

		requirement def MeasureExhaustGasTemp {
			subject thermocouple : ThermocoupleSensor;
			doc /* The system shall continuously measure exhaust gas temperature using a Type K thermocouple placed directly in the exhaust stream. */
		}
		requirement def ConditionRawSignal {
			subject conditioner : SignalConditioner;
			doc /* The signal conditioner shall filter and amplify the raw thermocouple signal to produce a stable conditioned signal. */
		}
		requirement def DisplayTempReading {
			subject lcdDisplay : LCDDisplay;
			doc /* The system shall display the measured temperature on a backlit LCD digital display. */
		}
		requirement def WarnOverTemp {
			subject microcontroller : Microcontroller;
			doc /* The system shall activate a blinking red warning indicator if the exhaust gas temperature exceeds 900 degC. */
		}
		requirement def ProvidePower {
			subject powerSupply : PowerSupply;
			doc /* The power supply shall convert 12V DC input to 5V DC for all internal electronics. */
		}
	}

	package Usages {
		private import Definitions::*;

		part egtGauge : EGTGaugeAssembly {
			action 'measure temperature' : MeasureTemperature;
			action 'condition signal' : ConditionSignal;
			action 'process temperature' : ProcessTemperature;
			action 'display temperature' : DisplayTemperature;
			action 'activate warning' : ActivateWarning;
			action 'blink warning' : BlinkWarning;

			satisfy MeasureExhaustGasTemp by thermocouple;
			satisfy ConditionRawSignal by conditioner;
			satisfy DisplayTempReading by lcdDisplay;
			satisfy WarnOverTemp by microcontroller;
			satisfy ProvidePower by powerSupply;

			state 'system states' : SystemStates {
				entry; then normal;
				state normal {
					do 'measure temperature';
					do 'condition signal';
					do 'process temperature';
					do 'display temperature';
				}
				accept when microcontroller.currentTemp > microcontroller.safetyLimit
					then warning;
				state warning {
					entry 'activate warning';
					do 'blink warning';
				}
				accept when microcontroller.currentTemp <= microcontroller.safetyLimit
					then normal;
			}
		}
	}
}
