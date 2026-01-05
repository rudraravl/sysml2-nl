package MarineChronometer {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TimeAccuracy {
		attribute deviationPerDay : DurationValue;
		attribute cumulativeError : DurationValue;
	}
	
	attribute def TemperatureCompensation {
		attribute coefficient : Real;
		attribute referenceTemperature : TemperatureValue;
	}
	
	item def Mainspring {
		attribute maxTorque : TorqueValue;
		attribute powerReserve : DurationValue;
		attribute currentEnergy : EnergyValue;
	}
	
	item def Fusee {
		attribute constantTorqueOutput : TorqueValue;
		attribute chainLength : LengthValue;
	}
	
	item def BalanceWheel {
		attribute momentOfInertia : Real;
		attribute oscillationFrequency : FrequencyValue;
		attribute amplitude : Real;
	}
	
	item def Hairspring {
		attribute springConstant : Real;
		attribute temperatureCoefficient : Real;
	}
	
	item def Escapement {
		attribute type : String;
		attribute efficiency : Real;
		attribute impulseAngle : Real;
	}
	
	item def GearTrain {
		attribute totalReduction : Real;
		attribute numberOfWheels : Integer;
	}
	
	item def BimetallicCompensator {
		attribute expansionCoefficient : Real;
		attribute activeTemperatureRange : TemperatureValue;
	}
	
	item def Dial {
		attribute hourHandPosition : Real;
		attribute minuteHandPosition : Real;
		attribute secondHandPosition : Real;
	}
	
	port def PowerPort {
		in windingTorque : TorqueValue;
		out deliveredTorque : TorqueValue;
	}
	
	port def TimingPort {
		out currentTime : DurationValue;
		out accuracy : TimeAccuracy;
	}
	
	port def EnvironmentalPort {
		in ambientTemperature : TemperatureValue;
		in shipMotion : AccelerationValue;
	}
	
	part def MarineChronometerSystem {
		doc /* A precision mechanical timepiece designed for marine navigation,
		       providing accurate timekeeping at sea despite temperature variations
		       and ship motion to enable determination of longitude. */
		
		attribute serialNumber : String;
		attribute ratedAccuracy : TimeAccuracy;
		
		port powerInterface : PowerPort;
		port timingInterface : TimingPort;
		port environmentInterface : EnvironmentalPort;
		
		part mainspring : Mainspring {
			attribute maxTorque = 0.6 [SI::N * SI::m];
			attribute powerReserve = 56.0 [SI::h];
			attribute currentEnergy = 2.5 [SI::J];
		}
		
		part fusee : Fusee {
			attribute constantTorqueOutput = 0.15 [SI::N * SI::m];
			attribute chainLength = 0.25 [SI::m];
		}
		
		part gearTrain : GearTrain {
			attribute totalReduction = 4320.0;
			attribute numberOfWheels = 7;
		}
		
		part escapement : Escapement {
			attribute type = "detent";
			attribute efficiency = 0.96;
			attribute impulseAngle = 15.0;
		}
		
		part balanceWheel : BalanceWheel {
			attribute momentOfInertia = 0.0015;
			attribute oscillationFrequency = 2.5 [SI::Hz];
			attribute amplitude = 270.0;
		}
		
		part hairspring : Hairspring {
			attribute springConstant = 0.082;
			attribute temperatureCoefficient = 0.000011;
		}
		
		part compensator : BimetallicCompensator {
			attribute expansionCoefficient = 0.000023;
			attribute activeTemperatureRange = 50.0 [SI::K];
		}
		
		part dial : Dial;
		
		part gimbalMount {
			attribute pivotAxes : Integer = 2;
			attribute maxTiltAngle : Real = 45.0;
		}
		
		connect mainspring to fusee;
		connect fusee to gearTrain;
		connect gearTrain to escapement;
		connect escapement to balanceWheel;
		connect balanceWheel to hairspring;
		connect compensator to balanceWheel;
		connect gearTrain to dial;
	}
	
	action def WindMainspring {
		in windingRotations : Real;
		in appliedTorque : TorqueValue;
		out storedEnergy : EnergyValue;
	}
	
	action def EqualizeTorque {
		in variableTorque : TorqueValue;
		out constantTorque : TorqueValue;
	}
	
	action def TransmitPower {
		in inputTorque : TorqueValue;
		in reductionRatio : Real;
		out outputTorque : TorqueValue;
		out rotationalSpeed : FrequencyValue;
	}
	
	action def RegulateEscapement {
		in driveTorque : TorqueValue;
		in balancePosition : Real;
		out impulse : ForceValue;
		out tick : Boolean;
	}
	
	action def OscillateBalance {
		in impulse : ForceValue;
		in springRestoring : ForceValue;
		in temperatureAdjustment : Real;
		out frequency : FrequencyValue;
		out position : Real;
	}
	
	action def CompensateTemperature {
		in currentTemperature : TemperatureValue;
		in referenceTemperature : TemperatureValue;
		out adjustment : Real;
	}
	
	action def UpdateDisplay {
		in oscillations : Integer;
		out timeDisplay : DurationValue;
	}
	
	action def MaintainPreciseTime {
		doc /* Primary function: Maintain accurate time measurement through
		       temperature-compensated mechanical oscillation for marine navigation. */
		
		in windingInput : TorqueValue;
		in environmentalTemperature : TemperatureValue;
		out preciseTime : DurationValue;
		out timekeepingAccuracy : TimeAccuracy;
		
		first start;
		
		then action wind : WindMainspring {
			in windingRotations = 12.0;
			in appliedTorque = windingInput;
			out storedEnergy;
		}
		
		then merge operatingCycle;
		
		then action equalize : EqualizeTorque {
			in variableTorque = windingInput;
			out constantTorque;
		}
		
		then action transmit : TransmitPower {
			in inputTorque = equalize.constantTorque;
			in reductionRatio = 4320.0;
			out outputTorque;
			out rotationalSpeed;
		}
		
		then action compensate : CompensateTemperature {
			in currentTemperature = environmentalTemperature;
			in referenceTemperature = 293.15 [SI::K];
			out adjustment;
		}
		
		then action oscillate : OscillateBalance {
			in impulse = 0.05 [SI::N];
			in springRestoring = 0.08 [SI::N];
			in temperatureAdjustment = compensate.adjustment;
			out frequency;
			out position;
		}
		
		then action regulate : RegulateEscapement {
			in driveTorque = transmit.outputTorque;
			in balancePosition = oscillate.position;
			out impulse;
			out tick;
		}
		
		then action display : UpdateDisplay {
			in oscillations = 216000;
			out timeDisplay;
		}
		
		then decide;
			if wind.storedEnergy > 0.2 [SI::J] then operatingCycle;
			if wind.storedEnergy <= 0.2 [SI::J] then requireWinding;
		
		then action requireWinding;
		
		then done;
	}
	
	state def ChronometerOperationalStates {
		entry; then idle;
		
		state idle {
			entry action prepareForWinding;
			accept windingApplied;
			then wound;
		}
		
		state wound {
			entry action initializeOscillation;
			accept startCommand;
			then running;
		}
		
		state running {
			do action keepTime : MaintainPreciseTime;
			accept when powerDepleted;
			then idle;
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The chronometer shall maintain timekeeping accuracy
		       within specified limits under operational conditions. */
		
		subject chronometer : MarineChronometerSystem;
		
		require constraint dailyRateLimit {
			chronometer.ratedAccuracy.deviationPerDay <= 1.0 [SI::s]
		}
		
		require constraint temperatureStability {
			chronometer.environmentInterface.ambientTemperature >= 268.15 [SI::K] and
			chronometer.environmentInterface.ambientTemperature <= 313.15 [SI::K]
		}
	}
	
	requirement def PowerReserveRequirement {
		doc /* The chronometer shall operate continuously for a minimum
		       duration after full winding. */
		
		subject chronometer : MarineChronometerSystem;
		
		require constraint minimumReserve {
			chronometer.mainspring.powerReserve >= 48.0 [SI::h]
		}
	}
	
	requirement def MotionIsolationRequirement {
		doc /* The chronometer shall maintain accuracy despite ship motion
		       through gimbal mounting. */
		
		subject chronometer : MarineChronometerSystem;
		
		require constraint gimbalProtection {
			chronometer.gimbalMount.maxTiltAngle >= 30.0
		}
	}
	
	requirement def MarineNavigationMission {
		doc /* Primary mission: Provide accurate time reference for determining
		       longitude at sea through celestial navigation. */
		
		subject system : MarineChronometerSystem;
		
		assume constraint marineEnvironment {
			system.environmentInterface.ambientTemperature >= 273.15 [SI::K] and
			system.environmentInterface.ambientTemperature <= 303.15 [SI::K]
		}
		
		require accuracyReq : AccuracyRequirement {
			subject chronometer = system;
		}
		
		require powerReq : PowerReserveRequirement {
			subject chronometer = system;
		}
		
		require motionReq : MotionIsolationRequirement {
			subject chronometer = system;
		}
	}
	
	part h4Chronometer : MarineChronometerSystem {
		attribute serialNumber = "H4-1759";
		attribute ratedAccuracy : TimeAccuracy {
			attribute deviationPerDay = 0.8 [SI::s];
			attribute cumulativeError = 0.0 [SI::s];
		}
		
		perform action primaryFunction : MaintainPreciseTime {
			in windingInput = h4Chronometer.powerInterface.windingTorque;
			in environmentalTemperature = h4Chronometer.environmentInterface.ambientTemperature;
			out preciseTime;
			out timekeepingAccuracy;
		}
		
		exhibit state operation : ChronometerOperationalStates;
		
		satisfy MarineNavigationMission by h4Chronometer;
	}
}
