package 'Engine Knock Control System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	attribute def KnockIntensity :> Real;
	attribute def IgnitionAdvance :> Real;
	attribute def FuelOctaneRating :> Real;
	
	enum def KnockSeverity {
		none;
		light;
		moderate;
		severe;
	}
	
	enum def EngineState {
		idle;
		normal;
		knockDetected;
		mitigating;
		protected;
	}
	
	item def KnockSensorData {
		attribute frequency : FrequencyValue;
		attribute amplitude : Real;
		attribute timestamp : TimeInstantValue;
	}
	
	item def IgnitionCommand {
		attribute timingAdjustment : Real;
		attribute cylinderID : Integer;
	}
	
	item def FuelCommand {
		attribute enrichmentFactor : Real;
	}
	
	item def KnockReducedSignal;
	item def SevereKnockSignal;
	item def KnockClearedSignal;
	
	port def KnockSensorPort {
		out knockData : KnockSensorData;
	}
	
	port def IgnitionControlPort {
		in ignitionCmd : IgnitionCommand;
	}
	
	port def FuelControlPort {
		in fuelCmd : FuelCommand;
	}
	
	part def KnockSensor {
		attribute sensitivity : Real;
		attribute detectionThreshold : Real;
		port sensorOutput : KnockSensorPort;
	}
	
	part def IgnitionSystem {
		attribute baseTimingAdvance : Real;
		attribute currentTiming : Real;
		port ignitionInput : IgnitionControlPort;
	}
	
	part def FuelInjectionSystem {
		attribute baseFuelRate : Real;
		attribute currentFuelRate : Real;
		port fuelInput : FuelControlPort;
	}
	
	part def CombustionChamber {
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
		attribute compressionRatio : Real;
	}
	
	part def EngineControlUnit {
		attribute knockThreshold : Real;
		attribute maxTimingRetard : Real;
		attribute timingRetardStep : Real;
		attribute currentKnockIntensity : Real;
		attribute knockDetected : Boolean;
		
		port knockDataInput : ~KnockSensorPort;
		port ignitionOutput : ~IgnitionControlPort;
		port fuelOutput : ~FuelControlPort;
	}
	
	action def DetectKnock {
		in sensorData : KnockSensorData;
		in threshold : Real;
		out knockDetected : Boolean;
		out knockIntensity : KnockIntensity;
		out severity : KnockSeverity;
	}
	
	action def CalculateTimingAdjustment {
		in knockSeverity : KnockSeverity;
		in currentTiming : Real;
		in maxRetard : Real;
		out timingAdjustment : Real;
	}
	
	action def CalculateFuelAdjustment {
		in knockSeverity : KnockSeverity;
		out fuelEnrichment : Real;
	}
	
	action def ApplyIgnitionRetard {
		in timingAdjustment : Real;
		out ignitionCmd : IgnitionCommand;
	}
	
	action def ApplyFuelEnrichment {
		in enrichmentFactor : Real;
		out fuelCmd : FuelCommand;
	}
	
	action def MonitorCombustion {
		in chamberPressure : PressureValue;
		in chamberTemperature : TemperatureValue;
		out abnormalCombustion : Boolean;
	}
	
	action def MonitorSensors;
	action def EvaluateSeverity;
	action def RetardTiming;
	action def VerifyReduction;
	action def MonitorKnockLevel;
	action def MaximumRetard;
	action def EnrichFuel;
	
	action def KnockControlLoop {
		first start;
		then merge continuousMonitoring;
		
		then action detectKnock : DetectKnock {
			in sensorData : KnockSensorData;
			in threshold : Real;
			out knockDetected : Boolean;
			out knockIntensity : KnockIntensity;
			out severity : KnockSeverity;
		}
		
		then decide;
			if detectKnock.severity == KnockSeverity::none then continuousMonitoring;
			if detectKnock.severity == KnockSeverity::light then applyLightMitigation;
			if detectKnock.severity == KnockSeverity::moderate then applyModerateMitigation;
			if detectKnock.severity == KnockSeverity::severe then applySevereMitigation;
		
		action applyLightMitigation {
			action calcTiming : CalculateTimingAdjustment {
				in knockSeverity = KnockSeverity::light;
				in currentTiming : Real;
				in maxRetard : Real;
				out timingAdjustment : Real;
			}
			then action applyIgnition : ApplyIgnitionRetard {
				in timingAdjustment = calcTiming.timingAdjustment;
				out ignitionCmd : IgnitionCommand;
			}
		}
		then continuousMonitoring;
		
		action applyModerateMitigation {
			action calcTiming : CalculateTimingAdjustment {
				in knockSeverity = KnockSeverity::moderate;
				in currentTiming : Real;
				in maxRetard : Real;
				out timingAdjustment : Real;
			}
			then action applyIgnition : ApplyIgnitionRetard {
				in timingAdjustment = calcTiming.timingAdjustment;
				out ignitionCmd : IgnitionCommand;
			}
			then action calcFuel : CalculateFuelAdjustment {
				in knockSeverity = KnockSeverity::moderate;
				out fuelEnrichment : Real;
			}
			then action applyFuel : ApplyFuelEnrichment {
				in enrichmentFactor = calcFuel.fuelEnrichment;
				out fuelCmd : FuelCommand;
			}
		}
		then continuousMonitoring;
		
		action applySevereMitigation {
			action calcTiming : CalculateTimingAdjustment {
				in knockSeverity = KnockSeverity::severe;
				in currentTiming : Real;
				in maxRetard : Real;
				out timingAdjustment : Real;
			}
			then action applyIgnition : ApplyIgnitionRetard {
				in timingAdjustment = calcTiming.timingAdjustment;
				out ignitionCmd : IgnitionCommand;
			}
			then action calcFuel : CalculateFuelAdjustment {
				in knockSeverity = KnockSeverity::severe;
				out fuelEnrichment : Real;
			}
			then action applyFuel : ApplyFuelEnrichment {
				in enrichmentFactor = calcFuel.fuelEnrichment;
				out fuelCmd : FuelCommand;
			}
		}
		then continuousMonitoring;
	}
	
	state def KnockControlStateMachine {
		in currentKnockIntensity : Real;
		
		entry; then normalOperation;
		
		state normalOperation {
			entry action monitorSensors : MonitorSensors;
		}
		
		accept knockEvent : KnockSensorData
		if knockEvent.amplitude > 0.5
		then knockDetectedState;
		
		state knockDetectedState {
			entry action evaluateSeverity : EvaluateSeverity;
			do action retardTiming : RetardTiming;
		}
		
		accept timingAdjusted : IgnitionCommand
		then mitigatingState;
		
		state mitigatingState {
			entry action verifyReduction : VerifyReduction;
			do action monitorKnockLevel : MonitorKnockLevel;
		}
		
		accept knockReduced : KnockReducedSignal
		if currentKnockIntensity < 0.2
		then normalOperation;
		
		accept severeKnock : SevereKnockSignal
		if currentKnockIntensity > 0.9
		then protectionMode;
		
		state protectionMode {
			entry action maximumRetard : MaximumRetard;
			do action enrichFuel : EnrichFuel;
		}
		
		accept knockCleared : KnockClearedSignal
		then normalOperation;
	}
	
	connection def KnockSensorConnection {
		end sensorEnd : KnockSensorPort;
		end ecuEnd : ~KnockSensorPort;
	}
	
	connection def IgnitionConnection {
		end ecuEnd : ~IgnitionControlPort;
		end ignitionEnd : IgnitionControlPort;
	}
	
	connection def FuelConnection {
		end ecuEnd : ~FuelControlPort;
		end fuelEnd : FuelControlPort;
	}
	
	requirement def PrimaryFunction {
		doc /*
			The Engine Knock Control System shall detect abnormal combustion events 
			(engine knock) and automatically adjust ignition timing and fuel delivery 
			to eliminate knocking, thereby preventing engine damage while maintaining 
			optimal performance and fuel efficiency.
		*/
	}
	
	requirement def KnockDetectionRequirement {
		doc /*
			The system shall continuously monitor combustion chamber vibrations 
			and detect engine knock within 10 milliseconds of occurrence.
		*/
		
		attribute maxDetectionTime : DurationValue = 0.010 [SI::s];
		
		require constraint {
			maxDetectionTime <= 0.010 [SI::s]
		}
	}
	
	requirement def TimingResponseRequirement {
		doc /*
			The system shall adjust ignition timing within 50 milliseconds 
			of knock detection to mitigate abnormal combustion.
		*/
		
		attribute maxResponseTime : DurationValue = 0.050 [SI::s];
		
		require constraint {
			maxResponseTime <= 0.050 [SI::s]
		}
	}
	
	requirement def ProtectionRequirement {
		doc /*
			The system shall limit maximum ignition timing retard to prevent 
			excessive performance degradation while ensuring engine protection.
		*/
		
		attribute maxTimingRetard : Real = 15.0;
		
		require constraint {
			maxTimingRetard <= 15.0
		}
	}
	
	requirement knockControlSystemRequirements {
		doc /* Top-level requirements for the Engine Knock Control System. */
		
		require requirement primaryFunction : PrimaryFunction;
		require requirement knockDetection : KnockDetectionRequirement;
		require requirement timingResponse : TimingResponseRequirement;
		require requirement protection : ProtectionRequirement;
	}
	
	part def EngineKnockControlSystem {
		doc /*
			The Engine Knock Control System is an automotive safety and performance 
			system that protects the engine from destructive abnormal combustion events. 
			
			Its primary function is to continuously monitor combustion chamber conditions 
			using piezoelectric knock sensors that detect the characteristic high-frequency 
			vibrations of engine knock (pre-ignition or detonation). When knock is detected, 
			the system immediately calculates the severity and automatically adjusts ignition 
			timing by retarding spark advance, and in severe cases, enriches the fuel mixture 
			to lower combustion temperatures. This closed-loop control prevents mechanical 
			damage to pistons, rings, and cylinder heads while allowing the engine to operate 
			at optimal efficiency under varying fuel quality and load conditions.
		*/
	}
	
	part engineKnockControlSystem : EngineKnockControlSystem {
		satisfy knockControlSystemRequirements;
		
		part knockSensor1 : KnockSensor {
			attribute :>> sensitivity = 0.85;
			attribute :>> detectionThreshold = 0.5;
			port :>> sensorOutput;
		}
		
		part knockSensor2 : KnockSensor {
			attribute :>> sensitivity = 0.82;
			attribute :>> detectionThreshold = 0.5;
			port :>> sensorOutput;
		}
		
		part ecu : EngineControlUnit {
			attribute :>> knockThreshold = 0.6;
			attribute :>> maxTimingRetard = 12.0;
			attribute :>> timingRetardStep = 2.0;
			attribute :>> currentKnockIntensity = 0.0;
			attribute :>> knockDetected = false;
			
			port :>> knockDataInput;
			port :>> ignitionOutput;
			port :>> fuelOutput;
			
			action knockControl : KnockControlLoop;
			state knockBehavior : KnockControlStateMachine {
				in :>> currentKnockIntensity = ecu.currentKnockIntensity;
			}
		}
		
		part ignitionSystem : IgnitionSystem {
			attribute :>> baseTimingAdvance = 15.0;
			attribute :>> currentTiming = 15.0;
			port :>> ignitionInput;
		}
		
		part fuelSystem : FuelInjectionSystem {
			attribute :>> baseFuelRate = 10.5;
			attribute :>> currentFuelRate = 10.5;
			port :>> fuelInput;
		}
		
		part cylinder1 : CombustionChamber {
			attribute :>> temperature = 800 [SI::K];
			attribute :>> pressure = 2000000 [SI::Pa];
			attribute :>> compressionRatio = 10.5;
		}
		
		part cylinder2 : CombustionChamber {
			attribute :>> temperature = 800 [SI::K];
			attribute :>> pressure = 2000000 [SI::Pa];
			attribute :>> compressionRatio = 10.5;
		}
		
		part cylinder3 : CombustionChamber {
			attribute :>> temperature = 800 [SI::K];
			attribute :>> pressure = 2000000 [SI::Pa];
			attribute :>> compressionRatio = 10.5;
		}
		
		part cylinder4 : CombustionChamber {
			attribute :>> temperature = 800 [SI::K];
			attribute :>> pressure = 2000000 [SI::Pa];
			attribute :>> compressionRatio = 10.5;
		}
		
		connection sensor1Connection : KnockSensorConnection
			connect knockSensor1.sensorOutput to ecu.knockDataInput;
		
		connection sensor2Connection : KnockSensorConnection
			connect knockSensor2.sensorOutput to ecu.knockDataInput;
		
		connection ignitionConnection : IgnitionConnection
			connect ecu.ignitionOutput to ignitionSystem.ignitionInput;
		
		connection fuelConnection : FuelConnection
			connect ecu.fuelOutput to fuelSystem.fuelInput;
		
		assert constraint sensorReliability {
			knockSensor1.sensitivity > 0.8 and knockSensor2.sensitivity > 0.8
		}
		
		assert constraint timingRetardLimit {
			ecu.maxTimingRetard <= 15.0
		}
	}
}
