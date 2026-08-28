package DigitalSunSensorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	attribute def VoltageValue :> ScalarValues::Real;
	attribute def AngleValue :> ScalarValues::Real;
	attribute def QualityScore :> ScalarValues::Real;
	
	item def RawVoltage {
		attribute v : VoltageValue;
	}
	item def CleanedVoltage {
		attribute v : VoltageValue;
	}
	item def SunAngles {
		attribute azimuth : AngleValue;
		attribute elevation : AngleValue;
	}
	item def ValidatedSunMeasurement {
		attribute azimuth : AngleValue;
		attribute elevation : AngleValue;
		attribute timestamp : Time::Iso8601DateTime;
		attribute quality : QualityScore;
	}
	
	attribute def PowerOn;
	attribute def FaultSignal;
	attribute def Reset;
	
	part def Photodiode {
		out raw : RawVoltage;
		action def GenerateVoltage {
			out outRaw : RawVoltage;
		}
		action generateVoltage : GenerateVoltage {
			out outRaw = raw;
		}
	}
	
	part def SensorHead {
		part diodes : Photodiode[4] ordered;
		out rawSignals : RawVoltage[4] ordered;
		action def Sense {
			out outRawSignals : RawVoltage[4];
		}
		action sense : Sense {
			out outRawSignals = rawSignals;
		}
	}
	
	part def SignalProcessor {
		in rawIn : RawVoltage[4] ordered;
		out cleanOut : CleanedVoltage[4] ordered;
		attribute amplificationGain : ScalarValues::Real = 100.0;
		action def Amplify {
			in inRaw : RawVoltage[4];
			out outAmp : CleanedVoltage[4];
		}
		action amplify : Amplify;
		action def FilterNoise {
			in inAmp : CleanedVoltage[4];
			out outClean : CleanedVoltage[4];
		}
		action filterNoise : FilterNoise;
		action def ProcessSignals {
			in inRaw : RawVoltage[4];
			out outClean : CleanedVoltage[4];
		}
		action processSignals : ProcessSignals {
			in inRaw = rawIn;
			out outClean = cleanOut;
		}
	}
	
	part def AngleCalculator {
		in cleanIn : CleanedVoltage[4] ordered;
		out anglesOut : SunAngles;
		attribute coeff0 : ScalarValues::Real = 1.0;
		attribute coeff1 : ScalarValues::Real = 1.0;
		attribute coeff2 : ScalarValues::Real = 1.0;
		attribute coeff3 : ScalarValues::Real = 1.0;
		attribute diffX : VoltageValue;
		attribute diffY : VoltageValue;
		action def Calculate {
			in inClean : CleanedVoltage[4];
			out outAngles : SunAngles;
		}
		action calculate : Calculate {
			in inClean = cleanIn;
			out outAngles = anglesOut;
		}
	}
	
	part def MeasurementValidator {
		in anglesIn : SunAngles;
		out measurementOut : ValidatedSunMeasurement;
		attribute minElevation : AngleValue = -90.0;
		attribute maxElevation : AngleValue = 90.0;
		attribute minAzimuth : AngleValue = 0.0;
		attribute maxAzimuth : AngleValue = 360.0;
		action def Validate {
			in inAngles : SunAngles;
			out outMeasurement : ValidatedSunMeasurement;
		}
		action validate : Validate {
			in inAngles = anglesIn;
			out outMeasurement = measurementOut;
		}
	}
	
	part def DigitalSunSensor {
		part head : SensorHead;
		part proc : SignalProcessor;
		part angleCalc : AngleCalculator;
		part val : MeasurementValidator;
		
		out data : ValidatedSunMeasurement;
		
		flow head.rawSignals to proc.rawIn;
		flow proc.cleanOut to angleCalc.cleanIn;
		flow angleCalc.anglesOut to val.anglesIn;
		flow val.measurementOut to data;
		
		action def TakeMeasurements;
		action takeMeasurements : TakeMeasurements;
		
		action def Initialize;
		action initialize : Initialize;
		
		action def Calibrate;
		action calibrate : Calibrate;
		
		exhibit state lifecycle {
			entry; then Off;
			state Off;
			accept PowerOn then Init;
			state Init;
			then Calibration;
			state Calibration;
			then Operational;
			state Operational {
				do takeMeasurements;
			}
			accept FaultSignal then Fault;
			state Fault;
			accept Reset then Init;
		}
	}
	
	requirement def SunAngleAccuracy {
		doc /* The computed azimuth and elevation angles shall be accurate within 0.1 degrees. */
		attribute accuracy : AngleValue = 0.1;
	}
	
	requirement def MeasurementRate {
		doc /* The sensor shall provide measurements at a rate of at least 10 Hz. */
		attribute rate : ScalarValues::Real = 10.0;
	}
	
	requirement def FaultHandling {
		doc /* The sensor shall detect invalid measurements and transition to a fault state. */
	}
	
	part sensor : DigitalSunSensor {
		satisfy SunAngleAccuracy;
		satisfy MeasurementRate;
		satisfy FaultHandling;
	}
}
