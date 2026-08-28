package 'Soil Moisture Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def CapacitanceValue :> Real;
		attribute def TemperatureValue :> Real;
		attribute def MoisturePercentage :> Real;
		attribute def TimeValue :> Real;

		item def SoilReading {
			attribute moisturePercentage : MoisturePercentage;
			attribute temperature : TemperatureValue;
			attribute timestamp : TimeValue;
		}

		attribute def ActivateSignal;
		attribute def SleepSignal;

		port def CapacitancePort {
			out capacitance : CapacitanceValue;
		}
		port def TemperaturePort {
			out temperature : TemperatureValue;
		}
		port def MoisturePort {
			out moisturePercentage : MoisturePercentage;
			out calibratedTemperature : TemperatureValue;
		}
		port def DataPort {
			out reading : SoilReading;
		}

		part def CapacitiveSensorProbe {
			port capOut : CapacitancePort;
		}
		part def TemperatureSensor {
			port tempOut : TemperaturePort;
		}
		part def SignalProcessor {
			port capIn : ~CapacitancePort;
			port tempIn : ~TemperaturePort;
			port moistureOut : MoisturePort;
			attribute calibrationOffset : MoisturePercentage;
		}
		part def Microcontroller {
			port dataIn : ~MoisturePort;
			port dataOut : DataPort;
			attribute powerLevel : Real;
		}
		part def SoilMoistureUnit {
			port externalDataPort : DataPort;
		}

		action def CalibrateProbe {
			in probe : CapacitiveSensorProbe;
			out calibrationOffset : MoisturePercentage;
		}
		action def MeasureCapacitance {
			in probe : CapacitiveSensorProbe;
			out capacitance : CapacitanceValue;
		}
		action def MeasureTemperature {
			in tempSensor : TemperatureSensor;
			out temperature : TemperatureValue;
		}
		action def ProcessData {
			in rawCapacitance : CapacitanceValue;
			in rawTemperature : TemperatureValue;
			in calibrationOffset : MoisturePercentage;
			out moisturePercentage : MoisturePercentage;
			out calibratedTemperature : TemperatureValue;
		}
		action def PackageAndReport {
			in moisturePercentage : MoisturePercentage;
			in temperature : TemperatureValue;
			out reading : SoilReading;
		}

		state def UnitStates {
			in probe : CapacitiveSensorProbe;
			in tempSensor : TemperatureSensor;
			in processor : SignalProcessor;
			in controller : Microcontroller;
		}
	}

	package Usages {
		private import Definitions::*;

		part sensingUnit : SoilMoistureUnit {
			part capacitiveProbe : CapacitiveSensorProbe;
			part tempSensor : TemperatureSensor;
			part signalProcessor : SignalProcessor;
			part microcontroller : Microcontroller;

			connect capacitiveProbe.capOut to signalProcessor.capIn;
			connect tempSensor.tempOut to signalProcessor.tempIn;
			connect signalProcessor.moistureOut to microcontroller.dataIn;
			connect microcontroller.dataOut to externalDataPort;

			exhibit unitStates : UnitStates {
				in probe = capacitiveProbe;
				in tempSensor = tempSensor;
				in processor = signalProcessor;
				in controller = microcontroller;

				entry; then calibrating;

				state calibrating {
					entry action doCalibrate : CalibrateProbe {
						in probe = probe;
						out calibrationOffset = processor.calibrationOffset;
					}
					then measuring;
				}

				state measuring {
					entry action doMeasureCap : MeasureCapacitance {
						in probe = probe;
						out capacitance : CapacitanceValue;
					}
					entry action doMeasureTemp : MeasureTemperature {
						in tempSensor = tempSensor;
						out temperature : TemperatureValue;
					}
					then processing;
				}

				state processing {
					entry action doProcess : ProcessData {
						in rawCapacitance : CapacitanceValue;
						in rawTemperature : TemperatureValue;
						in calibrationOffset = processor.calibrationOffset;
						out moisturePercentage : MoisturePercentage;
						out calibratedTemperature : TemperatureValue;
					}
					then reporting;
				}

				state reporting {
					entry action doReport : PackageAndReport {
						in moisturePercentage : MoisturePercentage;
						in temperature : TemperatureValue;
						out reading : SoilReading;
					}
					then measuring;
				}

				accept SleepSignal then idle;
				state idle;
				accept ActivateSignal then calibrating;
			}
		}
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def ResponseTimeRequirement {
			doc /* The unit shall provide a complete reading within 2 seconds of activation. */
			attribute maxResponseTime : TimeValue = 2;
		}

		requirement def AccuracyRequirement {
			doc /* The unit shall measure soil moisture with an accuracy of +/- 3 percent. */
			attribute accuracyTolerance : MoisturePercentage = 3;
		}

		requirement def SoilRangeRequirement {
			doc /* The unit shall function across the full spectrum of soil conditions, from completely dry to fully saturated. */
			attribute minMoisture : MoisturePercentage = 0;
			attribute maxMoisture : MoisturePercentage = 100;
		}

		requirement responseTimeReq : ResponseTimeRequirement {
			subject = sensingUnit;
		}
		requirement accuracyReq : AccuracyRequirement {
			subject = sensingUnit;
		}
		requirement soilRangeReq : SoilRangeRequirement {
			subject = sensingUnit;
		}

		satisfy responseTimeReq by sensingUnit;
		satisfy accuracyReq by sensingUnit;
		satisfy soilRangeReq by sensingUnit;
	}
}
