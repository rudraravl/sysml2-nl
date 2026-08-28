package 'CHT Gauge System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	attribute def VoltageValue : Real;

	package Definitions {
		port def TempPort {
			out temp : TemperatureValue;
		}
		
		port def VoltagePort {
			out voltage : VoltageValue;
		}
		
		part def CylinderHead {
			attribute temp : TemperatureValue;
			port tempOut : TempPort;
			bind temp = tempOut.temp;
		}
		
		part def TemperatureSensor {
			port tempIn : TempPort;
			port voltageOut : VoltagePort;
		}
		
		part def IndicatorGauge {
			port voltageIn : VoltagePort;
			attribute cautionThreshold : TemperatureValue = 200 [degC];
			attribute overheatThreshold : TemperatureValue = 250 [degC];
		}
		
		part def WarningLight {
			port voltageIn : VoltagePort;
			attribute overheatThreshold : TemperatureValue = 250 [degC];
		}
		
		action def ConvertTempToVoltage {
			in temp : TemperatureValue;
			out voltage : VoltageValue;
		}
		
		action def InterpretVoltage {
			in voltage : VoltageValue;
			out temp : TemperatureValue;
		}
		
		action def MoveNeedle {
			in temp : TemperatureValue;
		}
		
		action def Illuminate;
		action def Extinguish;
		
		state def GaugeStates {
			in temp : TemperatureValue;
			in cautionThreshold : TemperatureValue;
			in overheatThreshold : TemperatureValue;
			entry; then NORMAL;
			state NORMAL;
			accept when temp > cautionThreshold
				then CAUTION;
			state CAUTION;
			accept when temp > overheatThreshold
				then OVERHEAT;
			accept when temp <= cautionThreshold
				then NORMAL;
			state OVERHEAT;
			accept when temp <= overheatThreshold
				then CAUTION;
		}
		
		state def LightStates {
			in temp : TemperatureValue;
			in overheatThreshold : TemperatureValue;
			entry; then OFF;
			state OFF;
			accept when temp > overheatThreshold
				then ON;
			state ON;
			accept when temp <= overheatThreshold
				then OFF;
		}
		
		part def CHTSystem {
			part cylinderHead : CylinderHead;
			part sensor : TemperatureSensor;
			part gauge : IndicatorGauge;
			part warningLight : WarningLight;
			
			connect cylinderHead.tempOut to sensor.tempIn;
			connect sensor.voltageOut to gauge.voltageIn;
			connect sensor.voltageOut to warningLight.voltageIn;
			
			action 'sensor convert': ConvertTempToVoltage {
				in temp = sensor.tempIn.temp;
				out voltage = sensor.voltageOut.voltage;
			}
			
			action 'gauge interpret': InterpretVoltage {
				in voltage = gauge.voltageIn.voltage;
				out temp;
			}
			
			action 'gauge display': MoveNeedle {
				in temp = 'gauge interpret'.temp;
			}
			
			action 'light interpret': InterpretVoltage {
				in voltage = warningLight.voltageIn.voltage;
				out temp;
			}
			
			exhibit state 'gauge states': GaugeStates {
				in temp = 'gauge interpret'.temp;
				in cautionThreshold = gauge.cautionThreshold;
				in overheatThreshold = gauge.overheatThreshold;
			}
			
			exhibit state 'light states': LightStates {
				in temp = 'light interpret'.temp;
				in overheatThreshold = warningLight.overheatThreshold;
			}
		}
	}
}
