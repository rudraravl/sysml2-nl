package BreathalyzerSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BreathAlcoholConcentration :> Real {
		doc /* Breath alcohol concentration measured in mg/L */
	}
	
	attribute def BloodAlcoholConcentration :> Real {
		doc /* Blood alcohol concentration in mg/dL */
	}
	
	attribute def LegalLimit :> BloodAlcoholConcentration {
		doc /* Legal BAC limit threshold */
	}
	
	attribute def TestResult {
		attribute bacLevel : BloodAlcoholConcentration;
		attribute isAboveLimit : Boolean;
		attribute timestamp : ISQ::TimeValue;
	}
	
	attribute def StartTestSignal;
	attribute def CalibrationSignal;
	
	enum def TestStatus {
		idle;
		ready;
		sampling;
		analyzing;
		complete;
		error;
	}
	
	enum def AlarmLevel {
		safe;
		warning;
		violation;
	}
	
	port def SensorPort {
		out breathSample : BreathAlcoholConcentration;
	}
	
	port def AnalyzerPort {
		in breathSample : BreathAlcoholConcentration;
		out testResult : TestResult;
	}
	
	port def DisplayPort {
		in testResult : TestResult;
		in alarmSignal : AlarmLevel;
	}
	
	port def ControlPort {
		in startSignal : StartTestSignal;
		out status : TestStatus;
	}
	
	part def BreathSensor {
		port sensorOutput : SensorPort;
		
		attribute sensitivity : Real;
		attribute calibrationDate : String;
		
		action captureBreathSample {
			out sample : BreathAlcoholConcentration;
		}
	}
	
	part def AnalysisModule {
		port breathInput : ~SensorPort;
		port analysisOutput : AnalyzerPort;
		
		attribute conversionFactor : Real := 2100.0 {
			doc /* Breath to blood conversion ratio */
		}
		
		action convertToBAC {
			in breathConcentration : BreathAlcoholConcentration;
			out bloodConcentration : BloodAlcoholConcentration;
		}
		
		action analyzeAlcoholLevel {
			in breathSample : BreathAlcoholConcentration;
			in legalLimit : LegalLimit;
			out result : TestResult;
		}
	}
	
	part def DisplayUnit {
		port displayInput : ~DisplayPort;
		
		action showResult {
			in result : TestResult;
		}
		
		action activateAlarm {
			in alarmLevel : AlarmLevel;
		}
	}
	
	part def ControlUnit {
		port controlInterface : ControlPort;
		
		attribute currentStatus : TestStatus := TestStatus::idle;
		
		action def PrepareTest;
		action def CollectBreath;
		action def ProcessData;
		action def DisplayResults;
		action def HandleError;
		
		state def TestStateMachine {
			entry; then idle;
			
			state idle;
			state ready {
				entry action prepareTest : PrepareTest;
			}
			state sampling {
				entry action collectBreath : CollectBreath;
			}
			state analyzing {
				entry action processData : ProcessData;
			}
			state complete {
				entry action displayResults : DisplayResults;
			}
			state error {
				entry action handleError : HandleError;
			}
			
			transition idleToReady
				first idle
				accept startTest : StartTestSignal
				then ready;
			
			transition readyToSampling
				first ready
				then sampling;
			
			transition samplingToAnalyzing
				first sampling
				then analyzing;
			
			transition analyzingToComplete
				first analyzing
				then complete;
			
			transition completeToIdle
				first complete
				then idle;
			
			transition anyToError
				first ready
				then error;
		}
	}
	
	part def PowerSupply {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute batteryLevel : Real;
		
		action providePower {
			out power : ISQ::PowerValue;
		}
	}
	
	part breathalyzer {
		doc /* 
			A breathalyzer system that measures breath alcohol concentration
			and determines if a person exceeds the legal blood alcohol limit.
			Primary function: Analyze breath sample to determine blood alcohol
			concentration and assess legal compliance.
		*/
		
		attribute legalBACLimit : LegalLimit := 80.0 {
			doc /* Legal limit of 80 mg/dL (0.08%) */
		}
		
		part sensor : BreathSensor {
			attribute :>> sensitivity := 0.01;
			attribute :>> calibrationDate := "2024-01-15";
		}
		
		part analyzer : AnalysisModule;
		
		part display : DisplayUnit;
		
		part controller : ControlUnit;
		
		part power : PowerSupply {
			attribute :>> voltage = 9.0 [SI::V];
			attribute :>> batteryLevel := 85.0;
		}
		
		connect sensor.sensorOutput to analyzer.breathInput;
		connect analyzer.analysisOutput to display.displayInput;
		
		action performAlcoholTest {
			doc /* 
				Primary function: Analyze breath sample to determine 
				blood alcohol concentration and assess legal compliance.
			*/
			
			first start;
			
			then action initializeSystem {
				action checkPower : PowerSupply::providePower;
				action calibrateSensor;
			}
			
			then action waitForUser {
				accept userReady : StartTestSignal;
			}
			
			then action captureBreath : BreathSensor::captureBreathSample {
				out breathSample : BreathAlcoholConcentration;
			}
			
			then action convertMeasurement : AnalysisModule::convertToBAC {
				in breathConcentration = captureBreath.breathSample;
				out bloodConcentration : BloodAlcoholConcentration;
			}
			
			then action evaluateResult : AnalysisModule::analyzeAlcoholLevel {
				in breathSample = captureBreath.breathSample;
				in legalLimit = breathalyzer.legalBACLimit;
				out result : TestResult;
			}
			
			then decide;
				if evaluateResult.result.isAboveLimit then triggerViolationAlarm;
				if evaluateResult.result.bacLevel >= 50.0 and 
				   evaluateResult.result.bacLevel < breathalyzer.legalBACLimit 
				   then triggerWarningAlarm;
				if evaluateResult.result.bacLevel < 50.0 then showSafeResult;
			
			action triggerViolationAlarm : DisplayUnit::activateAlarm {
				in alarmLevel = AlarmLevel::violation;
			}
			then displayFinalResult;
			
			action triggerWarningAlarm : DisplayUnit::activateAlarm {
				in alarmLevel = AlarmLevel::warning;
			}
			then displayFinalResult;
			
			action showSafeResult : DisplayUnit::activateAlarm {
				in alarmLevel = AlarmLevel::safe;
			}
			then displayFinalResult;
			
			action displayFinalResult : DisplayUnit::showResult {
				in result = evaluateResult.result;
			}
			
			then action resetSystem;
			
			then done;
		}
		
		perform action continuousOperation {
			loop {
				perform performAlcoholTest;
			}
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The breathalyzer shall measure BAC with specified accuracy. */
		
		subject device : breathalyzer;
		
		require constraint {
			doc /* Measurement accuracy shall be within ±0.005 mg/dL */
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The breathalyzer shall complete analysis within specified time. */
		
		subject device : breathalyzer;
		
		require constraint {
			doc /* Test results shall be displayed within 10 seconds of breath sample */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The breathalyzer shall operate safely and hygienically. */
		
		subject device : breathalyzer;
		
		require constraint {
			doc /* Device shall prevent cross-contamination between users */
		}
		
		require constraint {
			doc /* Device shall alert user if calibration is expired */
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for breathalyzer system */
		
		require accuracyReq : AccuracyRequirement;
		require responseReq : ResponseTimeRequirement;
		require safetyReq : SafetyRequirement;
	}
}
