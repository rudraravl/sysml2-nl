package MotionDetectionSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;

	enum def SeverityLevel {
		low;
		medium;
		high;
	}

	attribute def RawMotionSignal {
		magnitude : Real;
		timestamp : TimeInstantValue;
	}

	attribute def AnalyzedSignal {
		confidence : Real;
		isRealMotion : Boolean;
	}

	attribute def AlertSignal {
		timestamp : TimeInstantValue;
		confidence : Real;
		severity : SeverityLevel;
	}

	attribute def PowerOnSignal;
	attribute def PowerOffSignal;
	attribute def MotionDetectedSignal;
	attribute def AlertAcknowledgedSignal;

	port def MotionOutPort {
		out signal : RawMotionSignal;
	}

	port def SignalInPort {
		in signal : RawMotionSignal;
	}

	port def TriggerOutPort {
		out analyzed : AnalyzedSignal;
	}

	port def TriggerInPort {
		in analyzed : AnalyzedSignal;
	}

	port def AlertOutPort {
		out alert : AlertSignal;
	}

	part def PIRSensor {
		attribute range : LengthValue = 10 [m];
		attribute sensitivity : Real = 0.8;
		out port motionOut : MotionOutPort;
		perform action detectMotion {
			out signal : RawMotionSignal;
		}
	}

	part def SignalAnalyzer {
		attribute noiseThreshold : Real = 0.3;
		attribute minConfidence : Real = 0.8;
		in port signalIn : SignalInPort;
		out port alertTrigger : TriggerOutPort;
		perform action analyzeSignal {
			in raw : RawMotionSignal;
			out analyzed : AnalyzedSignal;
		}
	}

	part def AlertGenerator {
		in port triggerIn : TriggerInPort;
		out port alertOut : AlertOutPort;
		perform action generateAlert {
			in analyzed : AnalyzedSignal;
			out alert : AlertSignal;
		}
	}

	state def SystemStates {
		in pirSensor : PIRSensor;
		in analyzer : SignalAnalyzer;
		in alertGen : AlertGenerator;

		attribute currentAnalyzed : AnalyzedSignal;

		entry; then standby;

		state standby;

		transition power_on
			first standby
			accept PowerOnSignal
			then active;

		state active {
			do action monitorArea { /* continuously monitor */ }
		}

		transition motion_detected
			first active
			accept MotionDetectedSignal
			then detecting;

		transition power_off_from_active
			first active
			accept PowerOffSignal
			then standby;

		state detecting {
			entry action analyzeDetectedSignal {
				in raw : RawMotionSignal;
				out analyzed : AnalyzedSignal;
			}
		}

		transition to_alerting
			first detecting
			accept a : AnalyzedSignal
			if a.isRealMotion and a.confidence >= analyzer.minConfidence
			do send new AlertSignal() to alertGen
			then alerting;

		transition to_active_from_detecting
			first detecting
			accept a : AnalyzedSignal
			if not a.isRealMotion or a.confidence < analyzer.minConfidence
			then active;

		transition power_off_from_detecting
			first detecting
			accept PowerOffSignal
			then standby;

		state alerting {
			entry action generateAlertAction {
				in analyzed : AnalyzedSignal;
				out alert : AlertSignal;
			}
		}

		transition alert_acknowledged
			first alerting
			accept AlertAcknowledgedSignal
			then active;

		transition power_off_from_alerting
			first alerting
			accept PowerOffSignal
			then standby;
	}

	part def MotionDetectionSystem {
		part pirSensor : PIRSensor;
		part analyzer : SignalAnalyzer;
		part alertGen : AlertGenerator;
		connect pirSensor.motionOut to analyzer.signalIn;
		connect analyzer.alertTrigger to alertGen.triggerIn;
		exhibit state systemStates : SystemStates {
			in pirSensor = self.pirSensor;
			in analyzer = self.analyzer;
			in alertGen = self.alertGen;
		}
	}

	requirement def OperationalRangeRequirement {
		doc /* The system shall detect motion at a range of at least 10 meters. */
		subject system : MotionDetectionSystem;
		constraint { system.pirSensor.range >= 10 [m] }
	}

	requirement def DetectionAccuracyRequirement {
		doc /* The system shall achieve a detection confidence of at least 80% for valid alerts. */
		subject system : MotionDetectionSystem;
		constraint { system.analyzer.minConfidence >= 0.8 }
	}

	requirement def FalseAlarmAvoidanceRequirement {
		doc /* The system shall filter signals below the noise threshold to avoid false alarms. */
		subject system : MotionDetectionSystem;
		constraint { system.analyzer.noiseThreshold <= 0.3 }
	}

	requirement operationalRange : OperationalRangeRequirement {
		subject system = motionSystem;
	}

	requirement detectionAccuracy : DetectionAccuracyRequirement {
		subject system = motionSystem;
	}

	requirement falseAlarmAvoidance : FalseAlarmAvoidanceRequirement {
		subject system = motionSystem;
	}

	part motionSystem : MotionDetectionSystem {
		satisfy operationalRange;
		satisfy detectionAccuracy;
		satisfy falseAlarmAvoidance;
	}
}
