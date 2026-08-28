package SpeedSensingUnitModel {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		package ItemDefinitions {
			attribute def Voltage :> ISQ::voltage;
			attribute def Frequency :> ISQ::frequency;
			attribute def Speed :> ISQ::speed;
			attribute def TimeValue :> ISQ::time;

			attribute def RawSignal {
				voltage : Voltage;
				frequency : Frequency;
			}
			attribute def ConditionedSignal {
				voltage : Voltage;
				frequency : Frequency;
			}
			attribute def SpeedMeasurement {
				speed : Speed;
				timestamp : TimeValue;
				valid : Boolean;
			}
			attribute def DiagnosticInfo {
				status : String;
				errorCode : Integer;
			}
			attribute def SelfTestResult {
				passed : Boolean;
			}
			attribute def PowerOnSignal;
			attribute def StartCommand;
			attribute def ResetCommand;
			attribute def PowerOffSignal;
		}

		package PortDefinitions {
			private import ItemDefinitions::*;
			port def PowerPort {
				in power : PowerOnSignal;
			}
			port def RawSignalPort {
				out raw : RawSignal;
			}
			port def ConditionedSignalPort {
				out cond : ConditionedSignal;
			}
			port def DataOutputPort {
				out measurement : SpeedMeasurement;
			}
			port def DiagnosticPort {
				out diagnostic : DiagnosticInfo;
			}
		}

		package ActionDefinitions {
			private import ItemDefinitions::*;
			action def AcquireData {
				out raw : RawSignal;
			}
			action def FilterAndAmplify {
				in raw : RawSignal;
				out cond : ConditionedSignal;
			}
			action def ConvertToSpeed {
				in cond : ConditionedSignal;
				out speed : Speed;
			}
			action def ValidateMeasurement {
				in speed : Speed;
				out valid : Boolean;
			}
			action def PackageMeasurement {
				in speed : Speed;
				in valid : Boolean;
				out measurement : SpeedMeasurement;
			}
			action def PerformSelfTest {
				out result : SelfTestResult;
			}
			action def ReportDiagnostics {
				out diagnostic : DiagnosticInfo;
			}
			action def MeasureCycle {
				out measurement : SpeedMeasurement;
				out valid : Boolean;
				language "Alf"
				/*
				 * Acquire raw data from sensor
				 * Filter and amplify signal
				 * Convert to calibrated speed
				 * Validate measurement (0 to 200 m/s)
				 * Package with timestamp and validity
				 * Store in data logger buffer
				 */
			}
		}

		package PartDefinitions {
			private import PortDefinitions::*;
			private import ActionDefinitions::*;

			part def SpeedSensor {
				port rawOut : RawSignalPort;
			}

			part def SignalConditioner {
				port rawIn : ~RawSignalPort;
				port condOut : ConditionedSignalPort;
			}

			part def DataLogger {
				attribute buffer : SpeedMeasurement[0..*] ordered;
			}

			part def SpeedSensingUnit {
				attribute powerVoltage : Voltage = 5[V];
				attribute measurementRate : Frequency = 10[Hz];
				attribute accuracy : Real = 0.01;

				port powerPort : PowerPort;
				port dataOutputPort : DataOutputPort;
				port diagnosticPort : DiagnosticPort;

				part speedSensor : SpeedSensor;
				part signalConditioner : SignalConditioner;
				part dataLogger : DataLogger;

				connection rawConnection from speedSensor.rawOut to signalConditioner.rawIn;

				perform action performSelfTest : PerformSelfTest;
				perform action reportDiagnostics : ReportDiagnostics;
				perform action measureCycle : MeasureCycle;

				exhibit state unitStates {
					entry; then off;
					state off;
					transition off_to_initializing
						first off
						accept PowerOnSignal via powerPort
						then initializing;
					state initializing {
						entry action performSelfTest { out result; }
						transition init_to_ready
							first initializing
							if performSelfTest.result.passed
							then ready;
						transition init_to_fault
							first initializing
							if not performSelfTest.result.passed
							then fault;
					}
					state ready;
					transition ready_to_measuring
						first ready
						accept StartCommand
						then measuring;
					transition ready_to_off
						first ready
						accept PowerOffSignal
						then off;
					state measuring {
						do measureCycle;
						transition measure_loop
							first measuring
							after 0.1[s]
							then measuring;
						transition measuring_to_fault
							first measuring
							if measureCycle.valid == false
							then fault;
						transition measuring_to_ready
							first measuring
							accept PowerOffSignal
							then ready;
					}
					state fault {
						do reportDiagnostics;
						transition fault_to_ready
							first fault
							accept ResetCommand
							then ready;
						transition fault_to_off
							first fault
							accept PowerOffSignal
							then off;
					}
				}
			}
		}

		package RequirementDefinitions {
			private import PartDefinitions::*;
			requirement def PowerSupplyRequirement {
				doc /* The unit shall operate on a 5V DC power supply. */
				subject unit : SpeedSensingUnit;
				requirement { unit.powerVoltage == 5[V] }
			}
			requirement def MeasurementRateRequirement {
				doc /* The unit shall provide measurements at a rate of at least 10 Hz. */
				subject unit : SpeedSensingUnit;
				requirement { unit.measurementRate >= 10[Hz] }
			}
			requirement def AccuracyRequirement {
				doc /* The unit shall maintain an accuracy of better than 1%. */
				subject unit : SpeedSensingUnit;
				requirement { unit.accuracy <= 0.01 }
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part speedSensingUnit : SpeedSensingUnit;

		requirement powerSupplyReq : PowerSupplyRequirement {
			subject unit = speedSensingUnit;
		}
		requirement measurementRateReq : MeasurementRateRequirement {
			subject unit = speedSensingUnit;
		}
		requirement accuracyReq : AccuracyRequirement {
			subject unit = speedSensingUnit;
		}

		satisfy powerSupplyReq by speedSensingUnit.powerPort;
		satisfy measurementRateReq by speedSensingUnit;
		satisfy accuracyReq by speedSensingUnit;
	}
}
