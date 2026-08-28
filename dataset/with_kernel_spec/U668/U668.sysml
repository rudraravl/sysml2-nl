package 'Engine Coolant Temperature Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		value type TemperatureValue :> ScalarValues::Real;
		value type ResistanceValue :> ScalarValues::Real;
		value type VoltageValue :> ScalarValues::Real;

		item def Coolant;
		item def 'Coolant Flow';

		attribute def 'Start Signal';
		attribute def 'Stop Signal';
		attribute def 'Reset Signal';
		attribute def 'Fault Code';
		attribute def 'Open Circuit Detected';
		attribute def 'Short Circuit Detected';
		attribute def 'Out of Range Detected';
		attribute def 'Overheat Alert';
		attribute def 'Fan Activate';
		attribute def 'Fan Deactivate';
		attribute def 'Warning On';
		attribute def 'Warning Off';
		attribute def 'Fuel Mixture Cold';
		attribute def 'Fuel Mixture Warm';

		action def 'Measure Temperature' {
			out temp : TemperatureValue;
		}

		action def 'Condition Signal' {
			in resistance : ResistanceValue;
			out voltage : VoltageValue;
		}

		action def 'Report to ECM' {
			in voltage : VoltageValue;
		}

		action def 'Detect Fault' {
			out fault : 'Fault Code';
		}

		action def 'Control Fuel Injection' {
			in temp : TemperatureValue;
		}

		action def 'Activate Cooling Fan' {
			in temp : TemperatureValue;
		}

		action def 'Trigger Warning Light' {
			in temp : TemperatureValue;
		}

		state def 'Sensor States';
		state def 'ECM States';

		port def 'Coolant Interface Port' {
			out coolant : Coolant;
		}
		port def 'Sensor Output Port' {
			out signalVoltage : VoltageValue;
		}
		port def 'ECM Sensor Input Port' {
			in temperatureVoltage : VoltageValue;
		}
		port def 'Fan Control Port' {
			out fanCommand : 'Fan Activate';
		}
		port def 'Warning Light Port' {
			out warningCommand : 'Warning On';
		}
		port def 'Fuel Injector Port' {
			out fuelCommand : 'Fuel Mixture Cold';
		}
		port def 'Fan Input Port' {
			in fanCommand : 'Fan Activate';
		}
		port def 'Warning Input Port' {
			in warningCommand : 'Warning On';
		}
		port def 'Fuel Input Port' {
			in fuelCommand : 'Fuel Mixture Cold';
		}

		part def Thermistor {
			attribute nominalResistance : ResistanceValue;
			attribute currentResistance : ResistanceValue;
			attribute betaCoefficient : ScalarValues::Real;
		}

		part def 'Signal Conditioning Circuit' {
			attribute supplyVoltage : VoltageValue;
			attribute calibrationOffset : VoltageValue;
		}

		part def 'Weatherproof Connector' {
			attribute pinCount : ScalarValues::Integer = 2;
			attribute rating : ScalarValues::String = "IP67";
		}

		part def 'Engine Coolant Temperature Sensor' {
			attribute casingMaterial : ScalarValues::String = "brass";
			attribute threadSpec : ScalarValues::String = "M12x1.5";
			attribute minOperatingTemp : TemperatureValue;
			attribute maxOperatingTemp : TemperatureValue;

			part thermistor : Thermistor;
			part signalConditioningCircuit : 'Signal Conditioning Circuit';
			part connector : 'Weatherproof Connector';

			port coolantInterface : 'Coolant Interface Port';
			port electricalOutput : 'Sensor Output Port';

			exhibit state sensorStates : 'Sensor States';
			perform action measureTemperature : 'Measure Temperature';
			perform action conditionSignal : 'Condition Signal';
			perform action reportToEcm : 'Report to ECM';
			perform action detectFault : 'Detect Fault';
		}

		part def 'Engine Control Module' {
			port sensorInput : 'ECM Sensor Input Port';
			port fanOutput : 'Fan Control Port';
			port warningOutput : 'Warning Light Port';
			port fuelOutput : 'Fuel Injector Port';

			exhibit state ecmStates : 'ECM States';
			perform action controlFuelInjection : 'Control Fuel Injection';
			perform action activateCoolingFan : 'Activate Cooling Fan';
			perform action triggerWarningLight : 'Trigger Warning Light';
		}

		part def Engine {
			part coolantCircuit : 'Coolant Circuit';
		}

		part def 'Coolant Circuit' {
			port coolantPort : 'Coolant Interface Port';
		}

		part def 'Radiator Cooling Fan' {
			port fanInput : 'Fan Input Port';
		}

		part def 'Warning Light' {
			port warningInput : 'Warning Input Port';
		}

		part def 'Fuel Injector' {
			port fuelInput : 'Fuel Input Port';
		}

		interface def 'Coolant Flow Interface' {
			end coolantSource : 'Coolant Interface Port';
			end coolantSink : 'Coolant Interface Port';
		}

		interface def 'Sensor Signal Interface' {
			end signalSource : 'Sensor Output Port';
			end signalSink : 'ECM Sensor Input Port';
		}

		interface def 'Fan Control Interface' {
			end fanSource : 'Fan Control Port';
			end fanSink : 'Fan Input Port';
		}

		interface def 'Warning Interface' {
			end warningSource : 'Warning Light Port';
			end warningSink : 'Warning Input Port';
		}

		interface def 'Fuel Control Interface' {
			end fuelSource : 'Fuel Injector Port';
			end fuelSink : 'Fuel Input Port';
		}

		requirement def 'Temperature Accuracy Requirement' {
			subject sensor : 'Engine Coolant Temperature Sensor';
			attribute maxError : TemperatureValue;
			constraint { maxError <= 2 }
		}

		requirement def 'Operational Range Requirement' {
			subject sensor : 'Engine Coolant Temperature Sensor';
			attribute minTemp : TemperatureValue;
			attribute maxTemp : TemperatureValue;
			constraint { minTemp <= -40 }
			constraint { maxTemp >= 150 }
		}

		requirement def 'Fault Detection Requirement' {
			subject sensor : 'Engine Coolant Temperature Sensor';
			doc
			/*
			 * The sensor shall detect open circuit, short circuit,
			 * and out-of-range temperature conditions, and report
			 * a fault code to the Engine Control Module.
			 */
		}

		requirement def 'Response Time Requirement' {
			subject sensor : 'Engine Coolant Temperature Sensor';
			attribute maxResponseTimeMs : ScalarValues::Real;
			constraint { maxResponseTimeMs <= 100 }
		}
	}

	package Usages {
		private import Definitions::*;

		action measureTemperature : 'Measure Temperature';
		action conditionSignal : 'Condition Signal';
		action reportToEcm : 'Report to ECM';
		action detectFault : 'Detect Fault';
		action controlFuelInjection : 'Control Fuel Injection';
		action activateCoolingFan : 'Activate Cooling Fan';
		action triggerWarningLight : 'Trigger Warning Light';

		part engineAssembly : Engine {
			part coolantCircuit : 'Coolant Circuit';
		}

		part coolantTempSensor : 'Engine Coolant Temperature Sensor' {
			part thermistor : Thermistor {
				attribute nominalResistance = 2400;
				attribute betaCoefficient = 3950;
			}
			part signalConditioningCircuit : 'Signal Conditioning Circuit' {
				attribute supplyVoltage = 5;
				attribute calibrationOffset = 0;
			}
			part connector : 'Weatherproof Connector';

			attribute minOperatingTemp = -40;
			attribute maxOperatingTemp = 150;

			exhibit state sensorStates : 'Sensor States' parallel {
				state operationalStates {
					entry action initial { }
					transition initial then idle;

					state idle;

					transition idleToMeasuring
						first idle
						accept 'Start Signal'
						then measuring;

					state measuring {
						do measureTemperature;
						do conditionSignal;
						do reportToEcm;
					}

					transition measuringToIdle
						first measuring
						accept 'Stop Signal'
						then idle;
				}

				state faultMonitoring {
					entry action initial { }
					transition initial then noFault;

					state noFault;

					transition detectOpenCircuit
						first noFault
						accept 'Open Circuit Detected'
						do send new 'Fault Code'() to engineControlModule
						then faultState;

					transition detectShortCircuit
						first noFault
						accept 'Short Circuit Detected'
						do send new 'Fault Code'() to engineControlModule
						then faultState;

					transition detectOutOfRange
						first noFault
						accept 'Out of Range Detected'
						do send new 'Fault Code'() to engineControlModule
						then faultState;

					state faultState;

					transition faultRecovery
						first faultState
						accept 'Reset Signal'
						then noFault;
				}
			}
		}

		part engineControlModule : 'Engine Control Module' {
			exhibit state ecmStates : 'ECM States' {
				entry action initial { }
				transition initial then monitoring;

				state monitoring {
					do controlFuelInjection;
					do activateCoolingFan;
					do triggerWarningLight;
				}
			}
		}

		part radiatorFan : 'Radiator Cooling Fan';
		part warningLight : 'Warning Light';
		part fuelInjector : 'Fuel Injector';

		flow coolantFlow of Coolant
			from engineAssembly.coolantCircuit.coolantPort.coolant
			to coolantTempSensor.coolantInterface.coolant;

		flow tempSignalFlow of VoltageValue
			from coolantTempSensor.electricalOutput.signalVoltage
			to engineControlModule.sensorInput.temperatureVoltage;

		flow fanCmdFlow of 'Fan Activate'
			from engineControlModule.fanOutput.fanCommand
			to radiatorFan.fanInput.fanCommand;

		flow warnCmdFlow of 'Warning On'
			from engineControlModule.warningOutput.warningCommand
			to warningLight.warningInput.warningCommand;

		flow fuelCmdFlow of 'Fuel Mixture Cold'
			from engineControlModule.fuelOutput.fuelCommand
			to fuelInjector.fuelInput.fuelCommand;

		requirement tempAccuracyReq : 'Temperature Accuracy Requirement' {
			attribute maxError = 2;
		}

		requirement operationalRangeReq : 'Operational Range Requirement' {
			attribute minTemp = -40;
			attribute maxTemp = 150;
		}

		requirement faultDetectionReq : 'Fault Detection Requirement';

		requirement responseTimeReq : 'Response Time Requirement' {
			attribute maxResponseTimeMs = 100;
		}

		satisfy tempAccuracyReq by coolantTempSensor;
		satisfy operationalRangeReq by coolantTempSensor;
		satisfy faultDetectionReq by coolantTempSensor;
		satisfy responseTimeReq by coolantTempSensor;
	}
}
