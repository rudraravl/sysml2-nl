package DigitalPHSensingSystem {
	private import ScalarValues::Real;
	private import ScalarValues::Integer;
	private import ISQ::*;
	private import SI::*;

	item def Solution;
	item def Voltage;
	item def Current;
	item def Temperature;
	attribute def DigitalValue :> Integer;
	attribute def PHValue :> Real;

	port def SolutionPort {
		out item solution : Solution;
	}
	port def VoltagePort {
		out item voltage : Voltage;
	}
	port def CurrentPort {
		out item current : Current;
	}
	port def DigitalPort {
		out item digitalValue : DigitalValue;
	}
	port def PHPort {
		out item phValue : PHValue;
	}
	port def TemperaturePort {
		out item temperature : Temperature;
	}

	part def IonSensitiveMembrane {
		port solutionPort : ~SolutionPort;
		port voltageOutPort : VoltagePort;
	}
	
	part def FETTransistor {
		port gateVoltageInPort : ~VoltagePort;
		port sourceVoltageInPort : ~VoltagePort;
		port currentOutPort : CurrentPort;
	}
	
	part def ReferenceElectrode {
		port voltageOutPort : VoltagePort;
	}
	
	part def TransimpedanceAmplifier {
		port currentInPort : ~CurrentPort;
		port voltageOutPort : VoltagePort;
	}
	
	part def ADC {
		port voltageInPort : ~VoltagePort;
		port digitalOutPort : DigitalPort;
	}
	
	part def Microcontroller {
		port digitalInPort : ~DigitalPort;
		port temperatureInPort : ~TemperaturePort;
		port phOutPort : PHPort;
		
		action processPH {
			in item digitalValue : DigitalValue = digitalInPort.digitalValue;
			in item temp : Temperature = temperatureInPort.temperature;
			out item phValue : PHValue = phOutPort.phValue;
		}
	}
	
	part def ISFETSensor {
		port solutionPort : SolutionPort;
		port currentOutPort : CurrentPort;
		
		part membrane : IonSensitiveMembrane;
		part fet : FETTransistor;
		part reference : ReferenceElectrode;
		
		flow of solution : Solution
			from solutionPort.solution to membrane.solutionPort.solution;
		flow of voltage : Voltage
			from membrane.voltageOutPort.voltage to fet.gateVoltageInPort.voltage;
		flow of voltage : Voltage
			from reference.voltageOutPort.voltage to fet.sourceVoltageInPort.voltage;
		flow of current : Current
			from fet.currentOutPort.current to currentOutPort.current;
	}
	
	part def DigitalPHSensorSystem {
		port solutionPort : SolutionPort;
		port temperatureInPort : ~TemperaturePort;
		port phOutPort : PHPort;
		
		part isfet : ISFETSensor;
		part amplifier : TransimpedanceAmplifier;
		part adc : ADC;
		part microcontroller : Microcontroller;
		
		flow of solution : Solution
			from solutionPort.solution to isfet.solutionPort.solution;
		flow of temperature : Temperature
			from temperatureInPort.temperature to microcontroller.temperatureInPort.temperature;
		flow of current : Current
			from isfet.currentOutPort.current to amplifier.currentInPort.current;
		flow of voltage : Voltage
			from amplifier.voltageOutPort.voltage to adc.voltageInPort.voltage;
		flow of digitalValue : DigitalValue
			from adc.digitalOutPort.digitalValue to microcontroller.digitalInPort.digitalValue;
		flow of phValue : PHValue
			from microcontroller.phOutPort.phValue to phOutPort.phValue;
	}

	requirement def MeasurementRangeRequirement {
		doc /* The system shall measure pH in the range of 0 to 14. */
		attribute minPH : Real = 0;
		attribute maxPH : Real = 14;
		attribute phValue : Real;
		require constraint { phValue >= minPH and phValue <= maxPH }
	}

	requirement def AccuracyRequirement {
		doc /* The system shall have an accuracy of ±0.02 pH units. */
		attribute maxError : Real = 0.02;
		attribute error : Real;
		require constraint { error <= maxError }
	}

	requirement def ResponseTimeRequirement {
		doc /* The system shall have a response time of under 10 seconds. */
		attribute maxResponseTime : Real = 10;
		attribute responseTime : Real;
		require constraint { responseTime < maxResponseTime }
	}

	requirement def OperatingTemperatureRequirement {
		doc /* The system shall operate in temperatures from 0°C to 100°C. */
		attribute minTemp : Real = 0;
		attribute maxTemp : Real = 100;
		attribute temperature : Real;
		require constraint { temperature >= minTemp and temperature <= maxTemp }
	}

	part phSensorSystem : DigitalPHSensorSystem {
		requirement measurementRangeReq : MeasurementRangeRequirement {
			subject phValue : Real;
		}
		requirement accuracyReq : AccuracyRequirement {
			subject error : Real;
		}
		requirement responseTimeReq : ResponseTimeRequirement {
			subject responseTime : Real;
		}
		requirement operatingTempReq : OperatingTemperatureRequirement {
			subject temperature : Real;
		}
	}
}
