package 'Rain Sensing Unit' {
	public import Definitions::*;
	public import Usages::*;
	private import ScalarValues::*;
	private import ISQ::*;
	private import Time::*;

	package Definitions {
		attribute def CapacitanceValue :> Real;
		attribute def PrecipitationRate :> Real;
		attribute def RainfallDepth :> Real;
		attribute def TempValue :> Real;

		item def PowerOnCmd;
		item def PowerOffCmd;
		item def StartCmd;
		item def StopCmd;
		item def ResetCmd;
		item def CalibrateCmd;

		item def DataReport {
			attribute rate : PrecipitationRate;
			attribute totalDepth : RainfallDepth;
			attribute timestamp : String;
			attribute status : String;
		}

		action def DetectRain { out capacitance : CapacitanceValue; }
		action def ConditionSignal { in raw : CapacitanceValue; out refined : CapacitanceValue; }
		action def SenseTemperature { out temp : TempValue; }
		action def CalculateRate { in refined : CapacitanceValue; in temp : TempValue; out rate : PrecipitationRate; }
		action def AccumulateRainfall { in rate : PrecipitationRate; in dt : TimeValue; out total : RainfallDepth; }
		action def GenerateReport { in rate : PrecipitationRate; in total : RainfallDepth; out report : DataReport; }
		action def ResetTotal;
		action def RunCalibration;

		part def CapacitiveRainSensor {
			port capPort;
			perform action detect : DetectRain;
		}

		part def SignalConditioner {
			port inPort;
			port outPort;
			perform action condition : ConditionSignal;
		}

		part def TemperatureSensor {
			port tempPort;
			perform action senseTemp : SenseTemperature;
		}

		part def CalibrationProcessor {
			port inPort;
			port tempPort;
			port ratePort;
			perform action calculate : CalculateRate;
			perform action calibrate : RunCalibration;
		}

		part def DataAccumulator {
			port ratePort;
			port depthPort;
			perform action accumulate : AccumulateRainfall;
			perform action reset : ResetTotal;
		}

		part def RainSensingUnit {
			port cmdPort;
			port reportPort;

			attribute responseTime : TimeValue;
			attribute operatingTempMin : TempValue = -40;
			attribute operatingTempMax : TempValue = 85;

			part sensor : CapacitiveRainSensor;
			part conditioner : SignalConditioner;
			part tempSensor : TemperatureSensor;
			part processor : CalibrationProcessor;
			part accumulator : DataAccumulator;

			connect sensor.capPort to conditioner.inPort;
			connect conditioner.outPort to processor.inPort;
			connect tempSensor.tempPort to processor.tempPort;
			connect processor.ratePort to accumulator.ratePort;

			action measureCycle {
				action detect : DetectRain {
					out capacitance : CapacitanceValue;
				}
				flow detect.capacitance to condition.raw;
				action condition : ConditionSignal {
					in raw : CapacitanceValue;
					out refined : CapacitanceValue;
				}
				flow condition.refined to calculate.refined;
				action senseTemp : SenseTemperature {
					out temp : TempValue;
				}
				flow senseTemp.temp to calculate.temp;
				action calculate : CalculateRate {
					in refined : CapacitanceValue;
					in temp : TempValue;
					out rate : PrecipitationRate;
				}
				flow calculate.rate to accumulate.rate;
				action accumulate : AccumulateRainfall {
					in rate : PrecipitationRate;
					in dt = 1 [SI::s];
					out total : RainfallDepth;
				}
				flow accumulate.total to generate.total;
				flow calculate.rate to generate.rate;
				action generate : GenerateReport {
					in rate : PrecipitationRate;
					in total : RainfallDepth;
					out report : DataReport;
				}
				send generate.report via reportPort;
			}

			exhibit state unitStates {
				entry; then off;

				state off;
				accept PowerOnCmd via cmdPort then standby;

				state standby;
				accept StartCmd via cmdPort then measuring;
				accept CalibrateCmd via cmdPort then calibrating;
				accept ResetCmd via cmdPort do accumulator.reset then standby;
				accept PowerOffCmd via cmdPort then off;

				state measuring {
					do measureCycle;
				}
				accept StopCmd via cmdPort then standby;
				accept ResetCmd via cmdPort do accumulator.reset then measuring;
				accept CalibrateCmd via cmdPort then calibrating;
				accept PowerOffCmd via cmdPort then off;

				state calibrating {
					do processor.calibrate;
				}
				accept StartCmd via cmdPort then measuring;
				accept StopCmd via cmdPort then standby;
				accept PowerOffCmd via cmdPort then off;
			}
		}

		requirement def ResponseTimeRequirement {
			doc /* The unit shall provide accurate precipitation measurements within 10 seconds of rainfall starting. */
			subject unit : RainSensingUnit;
			constraint { unit.responseTime <= 10 [SI::s] }
		}

		requirement def OperatingTemperatureRequirement {
			doc /* The unit shall operate over a temperature range of -40 degrees Celsius to +85 degrees Celsius. */
			subject unit : RainSensingUnit;
			constraint { unit.operatingTempMin <= -40 and unit.operatingTempMax >= 85 }
		}
	}

	package Usages {
		private import Definitions::*;

		part rainSensingUnit : RainSensingUnit {
			attribute responseTime = 10 [SI::s];
		}

		requirement responseTimeReq : ResponseTimeRequirement {
			subject unit = rainSensingUnit;
		}

		requirement operatingTempReq : OperatingTemperatureRequirement {
			subject unit = rainSensingUnit;
		}
	}
}
