package 'Glass Break Detector System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		enum def GlassType {
			plate;
			tempered;
			laminated;
			unknown;
		}

		item def RawAudioSignal {
			attribute frequency : FrequencyValue;
			attribute amplitude : SoundPressureLevelValue;
		}

		item def ConditionedAudioSignal {
			attribute frequency : FrequencyValue;
			attribute amplitude : SoundPressureLevelValue;
		}

		item def AlarmTriggerSignal {
			attribute classification : GlassType;
			attribute confidence : Real;
		}

		port def RawAudioOut { out signal : RawAudioSignal; }
		port def RawAudioIn { in signal : RawAudioSignal; }
		port def ConditionedAudioOut { out signal : ConditionedAudioSignal; }
		port def ConditionedAudioIn { in signal : ConditionedAudioSignal; }
		port def AlarmTriggerOut { out signal : AlarmTriggerSignal; }
		port def AlarmTriggerIn { in signal : AlarmTriggerSignal; }
		port def PowerOut { out voltage : ElectricPotentialValue; }
		port def PowerIn { in voltage : ElectricPotentialValue; }

		action def CaptureSound {
			out raw : RawAudioSignal;
		}
		action def ConditionSignal {
			in raw : RawAudioSignal;
			out conditioned : ConditionedAudioSignal;
		}
		action def AnalyzeGlassBreak {
			in conditioned : ConditionedAudioSignal;
			out classification : GlassType;
			out confidence : Real;
			out isBreak : Boolean;
		}
		action def ActivateSiren {
			in sirenLevel : SoundPressureLevelValue;
		}

		attribute def PowerOn;
		attribute def PotentialEvent;
		attribute def ManualReset;

		part def AcousticSensor {
			port rawAudio : RawAudioOut;
			port power : PowerIn;
			perform action captureSound : CaptureSound;
		}

		part def SignalConditioner {
			port rawAudio : RawAudioIn;
			port conditionedAudio : ConditionedAudioOut;
			port power : PowerIn;
			attribute minFrequency : FrequencyValue = 2500 [Hz];
			attribute maxFrequency : FrequencyValue = 8500 [Hz];
			perform action conditionSignal : ConditionSignal;
		}

		part def AnalysisEngine {
			port conditionedAudio : ConditionedAudioIn;
			port alarmTrigger : AlarmTriggerOut;
			port power : PowerIn;
			attribute confidenceThreshold : Real = 0.8;
			perform action analyzeGlassBreak : AnalyzeGlassBreak;
		}

		part def AlarmModule {
			port alarmTrigger : AlarmTriggerIn;
			port power : PowerIn;
			attribute sirenLevel : SoundPressureLevelValue = 105 [dB];
			perform action activateSiren : ActivateSiren;
		}

		part def BackupBattery {
			attribute capacity : DurationValue = 4 [h];
			attribute voltage : ElectricPotentialValue = 12 [V];
		}

		part def PowerManagement {
			port power : PowerOut;
			attribute mainVoltage : ElectricPotentialValue = 12 [V];
			attribute mainPowerPresent : Boolean = true;
			part backupBattery : BackupBattery;
			exhibit state powerStates : PowerStates;
		}

		part def GlassBreakDetector {
			part acousticSensor : AcousticSensor;
			part signalConditioner : SignalConditioner;
			part analysisEngine : AnalysisEngine;
			part alarmModule : AlarmModule;
			part powerManagement : PowerManagement;

			connect acousticSensor.rawAudio to signalConditioner.rawAudio;
			connect signalConditioner.conditionedAudio to analysisEngine.conditionedAudio;
			connect analysisEngine.alarmTrigger to alarmModule.alarmTrigger;
			connect powerManagement.power to acousticSensor.power;
			connect powerManagement.power to signalConditioner.power;
			connect powerManagement.power to analysisEngine.power;
			connect powerManagement.power to alarmModule.power;

			exhibit state detectorStates : DetectorStates;
		}

		state def DetectorStates {
			in system : GlassBreakDetector;
			entry; then idle;
			state idle;
			accept PowerOn then monitoring;
			state monitoring {
				do action monitor : CaptureSound;
			}
			accept PotentialEvent then analyzing;
			state analyzing {
				entry action condition : ConditionSignal {
					in raw = monitoring.monitor.raw;
				}
				then action analyze : AnalyzeGlassBreak {
					in conditioned = condition.conditioned;
				}
				accept when analyze.isBreak and analyze.confidence >= system.analysisEngine.confidenceThreshold
					do send new AlarmTriggerSignal(
						classification = analyze.classification,
						confidence = analyze.confidence
					) to system.alarmModule
					then alarming;
				accept when not analyze.isBreak or analyze.confidence < system.analysisEngine.confidenceThreshold
					then monitoring;
			}
			state alarming {
				entry action soundSiren : ActivateSiren { in sirenLevel = system.alarmModule.sirenLevel; }
			}
			accept ManualReset then monitoring;
		}

		state def PowerStates {
			in powerUnit : PowerManagement;
			entry; then primary;
			state primary;
			accept when not powerUnit.mainPowerPresent then backup;
			state backup;
			accept when powerUnit.mainPowerPresent then primary;
		}

		requirement def GlassBreakDetectionRequirement {
			subject detector : GlassBreakDetector;
			doc "The system shall detect glass break events by analyzing acoustic signatures in the 2.5 kHz to 8.5 kHz band with confidence greater than 80%.";
		}
		requirement def AlarmSoundLevelRequirement {
			subject detector : GlassBreakDetector;
			doc "The alarm module shall sound a siren at 105 dB upon confirmed glass break.";
		}
		requirement def BackupPowerRequirement {
			subject detector : GlassBreakDetector;
			doc "The system shall switch to backup battery power if main power is lost and operate for at least 4 hours.";
		}
	}

	package Usages {
		private import Definitions::*;

		part detector : GlassBreakDetector;

		state detectorStates : DetectorStates {
			in system = detector;
		}

		state powerStates : PowerStates {
			in powerUnit = detector.powerManagement;
		}
	}
}
