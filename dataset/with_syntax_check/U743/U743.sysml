package 'Laser Rangefinder System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TriggerSignal;
	attribute def LaserPulseSignal;
	attribute def ReflectionSignal;
	attribute def DistanceReading;
	
	item def LaserPulse {
		attribute wavelength : ISQ::LengthValue;
		attribute energy : ISQ::EnergyValue;
		attribute emissionTime : ISQ::TimeValue;
	}
	
	item def ReflectedPulse {
		attribute wavelength : ISQ::LengthValue;
		attribute returnEnergy : ISQ::EnergyValue;
		attribute detectionTime : ISQ::TimeValue;
	}
	
	port def LaserEmissionPort {
		out emittedPulse : LaserPulse;
	}
	
	port def LaserReceptionPort {
		in receivedPulse : ReflectedPulse;
	}
	
	port def ControlPort {
		in triggerCmd : TriggerSignal;
		out distanceOutput : DistanceReading;
	}
	
	port def PowerPort {
		in powerSupply : ISQ::PowerValue;
	}
	
	part def LaserEmitter {
		port emissionPort : LaserEmissionPort;
		port powerIn : PowerPort;
		attribute wavelength : ISQ::LengthValue = 905[SI::nm];
		attribute peakPower : ISQ::PowerValue = 75[SI::W];
		attribute pulseWidth : ISQ::TimeValue = 10[SI::ns];
	}
	
	part def OpticalReceiver {
		port receptionPort : LaserReceptionPort;
		port powerIn : PowerPort;
		attribute sensitivity : ISQ::PowerValue = 5.0e-10[SI::W];
		attribute apertureDiameter : ISQ::LengthValue = 50[SI::mm];
	}
	
	part def TimingCircuit {
		port powerIn : PowerPort;
		attribute clockFrequency : Real = 1.0e9;
		attribute resolution : ISQ::TimeValue = 1[SI::ns];
	}
	
	part def ProcessingUnit {
		port controlInterface : ControlPort;
		port powerIn : PowerPort;
		attribute speedOfLight : ISQ::SpeedValue = 299792458[SI::'m/s'];
		attribute processingRate : Real = 1000.0;
	}
	
	part def DisplayModule {
		port powerIn : PowerPort;
		attribute updateRate : Real = 10.0;
	}
	
	part def PowerSupply {
		attribute outputVoltage : ISQ::ElectricPotentialDifferenceValue = 12[SI::V];
		attribute outputCurrent : ISQ::ElectricCurrentValue = 2[SI::A];
	}
	
	action def EmitPulse {
		in trigger : TriggerSignal;
		in wavelength : ISQ::LengthValue;
		in energy : ISQ::EnergyValue;
		out pulse : LaserPulse;
		out emissionTime : ISQ::TimeValue;
	}
	
	action def PropagateToTarget {
		in emittedPulse : LaserPulse;
		in targetDistance : ISQ::LengthValue;
		out reflectedPulse : ReflectedPulse;
	}
	
	action def DetectReturn {
		in reflectedPulse : ReflectedPulse;
		out detectionTime : ISQ::TimeValue;
		out signalStrength : ISQ::PowerValue;
	}
	
	action def CalculateTimeOfFlight {
		in emissionTime : ISQ::TimeValue;
		in detectionTime : ISQ::TimeValue;
		out timeOfFlight : ISQ::TimeValue;
	}
	
	action def ComputeDistance {
		in timeOfFlight : ISQ::TimeValue;
		in speedOfLight : ISQ::SpeedValue;
		out distance : ISQ::LengthValue;
	}
	
	action def ValidateRange {
		in measuredDistance : ISQ::LengthValue;
		in minRange : ISQ::LengthValue;
		in maxRange : ISQ::LengthValue;
		out isValid : Boolean;
	}
	
	action def DisplayDistance {
		in distance : ISQ::LengthValue;
		out reading : DistanceReading;
	}
	
	action def PerformRangeMeasurement {
		in trigger : TriggerSignal;
		in minRange : ISQ::LengthValue;
		in maxRange : ISQ::LengthValue;
		in speedOfLight : ISQ::SpeedValue;
		out distanceReading : DistanceReading;
		
		first start;
		
		then action emit : EmitPulse {
			in trigger = PerformRangeMeasurement::trigger;
			in wavelength = 905[SI::nm];
			in energy = 7.5e-7[SI::J];
			out pulse : LaserPulse;
			out emissionTime : ISQ::TimeValue;
		}
		
		then action propagate : PropagateToTarget {
			in emittedPulse = emit.pulse;
			in targetDistance : ISQ::LengthValue;
			out reflectedPulse : ReflectedPulse;
		}
		
		then action detect : DetectReturn {
			in reflectedPulse = propagate.reflectedPulse;
			out detectionTime : ISQ::TimeValue;
			out signalStrength : ISQ::PowerValue;
		}
		
		then action calculateTOF : CalculateTimeOfFlight {
			in emissionTime = emit.emissionTime;
			in detectionTime = detect.detectionTime;
			out timeOfFlight : ISQ::TimeValue;
		}
		
		then action computeDist : ComputeDistance {
			in timeOfFlight = calculateTOF.timeOfFlight;
			in speedOfLight = PerformRangeMeasurement::speedOfLight;
			out distance : ISQ::LengthValue;
		}
		
		then action validate : ValidateRange {
			in measuredDistance = computeDist.distance;
			in minRange = PerformRangeMeasurement::minRange;
			in maxRange = PerformRangeMeasurement::maxRange;
			out isValid : Boolean;
		}
		
		then decide;
			if validate.isValid then displayResult;
			if !validate.isValid then handleError;
		
		action displayResult : DisplayDistance {
			in distance = computeDist.distance;
			out reading : DistanceReading;
		}
		then done;
		
		action handleError {
			attribute errorCode : Integer = -1;
		}
		then done;
	}
	
	part def LaserRangefinder {
		port opticalAperture : LaserEmissionPort;
		port opticalDetector : LaserReceptionPort;
		port userInterface : ControlPort;
		
		part emitter : LaserEmitter {
			connect opticalAperture to emissionPort;
		}
		
		part receiver : OpticalReceiver {
			connect opticalDetector to receptionPort;
		}
		
		part timer : TimingCircuit;
		
		part processor : ProcessingUnit {
			connect userInterface to controlInterface;
		}
		
		part display : DisplayModule;
		
		part power : PowerSupply;
		
		connect power to emitter.powerIn;
		connect power to receiver.powerIn;
		connect power to timer.powerIn;
		connect power to processor.powerIn;
		connect power to display.powerIn;
		
		attribute minMeasurementRange : ISQ::LengthValue = 0.2[SI::m];
		attribute maxMeasurementRange : ISQ::LengthValue = 250[SI::m];
		attribute measurementAccuracy : ISQ::LengthValue = 0.01[SI::m];
		attribute measurementFrequency : Real = 100.0;
		attribute operatingTemperatureMin : ISQ::ThermodynamicTemperatureValue = 253[SI::K];
		attribute operatingTemperatureMax : ISQ::ThermodynamicTemperatureValue = 323[SI::K];
		
		perform action rangeMeasurement[*] ordered references PerformRangeMeasurement {
			in trigger;
			in minRange = minMeasurementRange;
			in maxRange = maxMeasurementRange;
			in speedOfLight = 299792458[SI::'m/s'];
			out distanceReading;
		}
	}
	
	part rangefinderSystem : LaserRangefinder;
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The rangefinder shall measure distance with accuracy better than specified tolerance. */
		
		subject system : LaserRangefinder;
		
		require constraint {
			system.measurementAccuracy <= 0.02[SI::m]
		}
	}
	
	requirement def OperationalRangeRequirement {
		doc /* The rangefinder shall operate within specified minimum and maximum distance range. */
		
		subject system : LaserRangefinder;
		
		require constraint {
			system.minMeasurementRange >= 0.1[SI::m] and
			system.maxMeasurementRange >= 200[SI::m]
		}
	}
	
	requirement def MeasurementRateRequirement {
		doc /* The rangefinder shall provide distance measurements at minimum specified frequency. */
		
		subject system : LaserRangefinder;
		
		require constraint {
			system.measurementFrequency >= 50.0
		}
	}
	
	requirement def EnvironmentalRequirement {
		doc /* The rangefinder shall operate within specified temperature range. */
		
		subject system : LaserRangefinder;
		
		require constraint {
			system.operatingTemperatureMin <= 243[SI::K] and
			system.operatingTemperatureMax >= 333[SI::K]
		}
	}
	
	requirement def EyeSafetyRequirement {
		doc /* The laser emitter shall comply with eye safety standards for Class 1 laser products. */
		
		subject emitter : LaserEmitter;
		
		require constraint {
			emitter.peakPower <= 100[SI::W] and
			emitter.pulseWidth <= 20[SI::ns]
		}
	}
	
	requirement <'LRNG-SYS-001'> laserRangefinderSystemRequirement {
		doc /* The laser rangefinder system shall accurately measure distance to target surfaces 
		       by emitting laser pulses, detecting reflected signals, and calculating distance 
		       based on time-of-flight measurement. The system shall provide reliable measurements 
		       within specified range and accuracy while ensuring eye safety compliance. */
		
		subject system : LaserRangefinder;
		
		require MeasurementAccuracyRequirement;
		require OperationalRangeRequirement;
		require MeasurementRateRequirement;
		require EnvironmentalRequirement;
		require EyeSafetyRequirement;
	}
	
	action def ContinuousRangefinding {
		in operatingMode : Boolean;
		in measurementInterval : ISQ::TimeValue;
		out measurements : DistanceReading[*];
		
		loop {
			accept trigger : TriggerSignal;
			then action measure : PerformRangeMeasurement {
				in trigger;
				in minRange = 0.2[SI::m];
				in maxRange = 250[SI::m];
				in speedOfLight = 299792458[SI::'m/s'];
				out distanceReading;
			}
			then assign measurements := measurements->including(measure.distanceReading);
		}
	}
}
