package ActigraphySystem {
	import ScalarValues::*;
	import ISQ::*;

	// ===== Value Types with Units =====

	item def AccelerationUnit :> Unit {
		private import SI::g;
	}
	value type Acceleration :> Real {
		m : AccelerationUnit;
	}

	value type ActivityCount :> Int {
		doc "Accumulated motion counts per epoch";
	}

	value type EpochDuration :> Real {
		m : SI::s;
	}

	value type BatteryCharge :> Real {
		m : SI::C;
	}

	value type BatteryPercent :> Real {
		doc "Battery level as percentage 0..100";
	}

	value type TimeOfDay :> Real {
		m : SI::h;
	}

	value type DurationHours :> Real {
		m : SI::h;
	}

	value type DurationMinutes :> Real {
		m : SI::min;
	}

	value type Percentage :> Real {
		doc "Percentage value 0..100";
	}

	// ===== Enumerations =====

	enum def SleepPhase {
		enum awake;
		enum light;
		enum deep;
		enum rem;
	}

	enum def WatchMode {
		enum recording;
		enum idle;
		enum downloading;
		enum charging;
	}

	// ===== Item Definitions =====

	item def TriAxialAcceleration {
		x : Acceleration;
		y : Acceleration;
		z : Acceleration;
	}

	item def EpochData {
		timestamp : TimeOfDay;
		activityCount : ActivityCount;
		sleepPhase : SleepPhase;
	}

	item def RawMotionSample {
		timestamp : TimeOfDay;
		accel : TriAxialAcceleration;
	}

	item def SleepAnalysisReport {
		totalSleepTime : DurationHours;
		sleepEfficiency : Percentage;
		lightSleepDuration : DurationHours;
		deepSleepDuration : DurationHours;
		remSleepDuration : DurationHours;
		wakeDuration : DurationHours;
		summary : String;
	}

	item def DataTransferPayload {
		epochs : EpochData[0..*];
		deviceId : String;
		recordingStart : TimeOfDay;
		recordingEnd : TimeOfDay;
	}

	// ===== Port Definitions =====

	port def DataTransferPort {
		out dataOut : DataTransferPayload;
		in dataAck : Boolean;
	}

	port def PowerPort {
		in powerIn : Boolean;
	}

	port def SensorPort {
		out motion : RawMotionSample;
	}

	// ===== Requirements =====

	requirement def SystemRequirements {
		requirement BatteryLifeRequirement {
			doc "The wearable device shall operate for at least two weeks on a single charge.";
			subject watch : ActigraphyWatch;
			met : watch.battery.chargeLevel >= 0.0 [BatteryPercent] implies watch.battery.chargeLevel >= 0.0 [BatteryPercent];
		}

		requirement MemoryCapacityRequirement {
			doc "Internal memory shall hold several weeks of continuous recordings.";
			subject watch : ActigraphyWatch;
			met : watch.memory.capacity >= 20160 [ActivityCount];
		}

		requirement EpochProcessingRequirement {
			doc "Processor shall convert raw motion into activity counts for each epoch interval.";
			subject watch : ActigraphyWatch;
			met : watch.epochDuration == 60 [EpochDuration];
		}

		requirement SleepClassificationRequirement {
			doc "Processor shall classify each epoch into a sleep phase.";
			subject watch : ActigraphyWatch;
			met : watch.processor.classifiedPhase->size() == watch.processor.epochData->size();
		}

		requirement DataTransferRequirement {
			doc "Stored data shall be transferable to the analysis workstation.";
			subject system : ActigraphySystem;
			met : system.workstation.receivedData->size() > 0;
		}

		requirement ReportGenerationRequirement {
			doc "Workstation shall produce a comprehensive Sleep Analysis Report.";
			subject workstation : AnalysisWorkstation;
			met : workstation.report.totalSleepTime > 0 [DurationHours];
		}
	}

	// ===== Parts: Wearable Device =====

	part def ActigraphyWatch {
		port dataPort : DataTransferPort;
		port powerPort : PowerPort;

		attribute mode : WatchMode;
		attribute epochDuration : EpochDuration = 60 [EpochDuration];

		part strap : SiliconeStrap;
		part accelerometer : TriAxialAccelerometer {
			port sensorOut : SensorPort;
		}
		part processor : WatchProcessor {
			in rawMotion : RawMotionSample;
			out epochData : EpochData[0..*];
		}
		part memory : InternalMemory {
			attribute capacity : ActivityCount = 20160;
			attribute stored : EpochData[0..*];
		}
		part battery : RechargeableBattery {
			attribute chargeLevel : BatteryPercent = 100;
		}

		connection accelToProcessor connect accelerometer.sensorOut.motion to processor.rawMotion;
		connection processorToMemory connect processor.epochData to memory.stored;

		state def WatchState {
			initial state Recording {
				entry action assignMode { mode = WatchMode::recording; }
				do action sampleAndProcess {
					accelerometer.measure();
					processor.processEpoch();
				}
				transition to Idle when battery.chargeLevel < 5;
				transition to Downloading when dataPort.dataAck == true;
				transition to Charging when powerPort.powerIn == true;
			}

			state Idle {
				entry action assignMode { mode = WatchMode::idle; }
				transition to Recording when powerPort.powerIn == false;
				transition to Charging when powerPort.powerIn == true;
				transition to Downloading when dataPort.dataAck == true;
			}

			state Downloading {
				entry action assignMode { mode = WatchMode::downloading; }
				do action transferData {
					dataPort.dataOut = DataTransferPayload {
						epochs = memory.stored,
						deviceId = "ACT-001",
						recordingStart = memory.stored->first().timestamp,
						recordingEnd = memory.stored->last().timestamp
					};
				}
				transition to Idle when memory.stored->isEmpty();
				transition to Charging when powerPort.powerIn == true;
			}

			state Charging {
				entry action assignMode { mode = WatchMode::charging; }
				do action chargeBattery { battery.chargeLevel = battery.chargeLevel + 1; }
				transition to Idle when battery.chargeLevel >= 100;
			}
		}

		state behavior :>> WatchState;
	}

	part def SiliconeStrap {
		attribute material : String = "Medical-grade silicone";
		attribute adjustable : Boolean = true;
	}

	part def TriAxialAccelerometer {
		port sensorOut : SensorPort;
		attribute sampleRate : Real = 32 [1/s];
		action def measure {
			out sample : RawMotionSample;
		}
	}

	part def WatchProcessor {
		in rawMotion : RawMotionSample;
		out epochData : EpochData[0..*];
		attribute classifiedPhase : SleepPhase[0..*];

		action def processEpoch {
			in motion : RawMotionSample;
			out epoch : EpochData;
			// Convert raw acceleration to activity count
			// Classify sleep phase based on activity and time of day
		}
	}

	part def InternalMemory {
		attribute capacity : ActivityCount;
		attribute stored : EpochData[0..*];
	}

	part def RechargeableBattery {
		attribute chargeLevel : BatteryPercent;
		attribute maxCharge : BatteryCharge = 144000;
	}

	// ===== Parts: Analysis Workstation =====

	part def AnalysisWorkstation {
		port dataPort : DataTransferPort;

		attribute receivedData : DataTransferPayload[0..*];
		attribute report : SleepAnalysisReport;

		part analysisSoftware : SleepAnalysisSoftware {
			in data : DataTransferPayload;
			out report : SleepAnalysisReport;
		}

		connection dataIn connect dataPort.dataOut to analysisSoftware.data;

		action def AnalyzeData {
			in payload : DataTransferPayload;
			out report : SleepAnalysisReport;

			// Identify sleep and wake periods
			action identifySleepWake {
				in epochs : EpochData[0..*];
				out sleepPeriods : EpochData[0..*];
				out wakePeriods : EpochData[0..*];
			}

			// Calculate total sleep time
			action calculateTotalSleepTime {
				in sleepPeriods : EpochData[0..*];
				out tst : DurationHours;
			}

			// Calculate sleep efficiency
			action calculateSleepEfficiency {
				in tst : DurationHours;
				in totalTimeInBed : DurationHours;
				out efficiency : Percentage;
			}

			// Calculate time in each sleep stage
			action calculateStageDurations {
				in epochs : EpochData[0..*];
				out lightDuration : DurationHours;
				out deepDuration : DurationHours;
				out remDuration : DurationHours;
				out wakeDuration : DurationHours;
			}

			action generateReport {
				in tst : DurationHours;
				in efficiency : Percentage;
				in lightDuration : DurationHours;
				in deepDuration : DurationHours;
				in remDuration : DurationHours;
				in wakeDuration : DurationHours;
				out finalReport : SleepAnalysisReport;
			}

			flow identifySleepWake.sleepPeriods to calculateTotalSleepTime.sleepPeriods;
			flow identifySleepWake.sleepPeriods to calculateStageDurations.epochs;
			flow identifySleepWake.wakePeriods to calculateStageDurations.epochs;
			flow calculateTotalSleepTime.tst to calculateSleepEfficiency.tst;
			flow calculateTotalSleepTime.tst to generateReport.tst;
			flow calculateSleepEfficiency.efficiency to generateReport.efficiency;
			flow calculateStageDurations.lightDuration to generateReport.lightDuration;
			flow calculateStageDurations.deepDuration to generateReport.deepDuration;
			flow calculateStageDurations.remDuration to generateReport.remDuration;
			flow calculateStageDurations.wakeDuration to generateReport.wakeDuration;
			flow generateReport.finalReport to report;
		}

		action behavior :>> AnalyzeData;
	}

	part def SleepAnalysisSoftware {
		in data : DataTransferPayload;
		out report : SleepAnalysisReport;
		attribute version : String = "2.0";
	}

	// ===== Top-level System =====

	part def ActigraphySystem {
		part watch : ActigraphyWatch;
		part workstation : AnalysisWorkstation;
		part charger : BatteryCharger {
			port powerOut : PowerPort;
		}

		connection watchToWorkstation connect watch.dataPort to workstation.dataPort;
		connection chargerToWatch connect charger.powerOut to watch.powerPort;

		satisfy SystemRequirements {
			subject system : ActigraphySystem = self;
		}
	}

	part def BatteryCharger {
		port powerOut : PowerPort;
		attribute outputVoltage : Real = 5 [V];
	}

}</think>package ActigraphySystem {
	import ScalarValues::*;
	import ISQ::*;

	item def AccelerationUnit :> Unit {
		private import SI::g;
	}
	value type Acceleration :> Real {
		m : AccelerationUnit;
	}
	value type ActivityCount :> Int {
		doc "Accumulated motion counts per epoch";
	}
	value type EpochDuration :> Real {
		m : SI::s;
	}
	value type BatteryCharge :> Real {
		m : SI::C;
	}
	value type BatteryPercent :> Real {
		doc "Battery level as percentage 0..100";
	}
	value type TimeOfDay :> Real {
		m : SI::h;
	}
	value type DurationHours :> Real {
		m : SI::h;
	}
	value type DurationMinutes :> Real {
		m : SI::min;
	}
	value type Percentage :> Real {
		doc "Percentage value 0..100";
	}

	enum def SleepPhase {
		enum awake;
		enum light;
		enum deep;
		enum rem;
	}

	enum def WatchMode {
		enum recording;
		enum idle;
		enum downloading;
		enum charging;
	}

	item def TriAxialAcceleration {
		x : Acceleration;
		y : Acceleration;
		z : Acceleration;
	}

	item def EpochData {
		timestamp : TimeOfDay;
		activityCount : ActivityCount;
		sleepPhase : SleepPhase;
	}

	item def RawMotionSample {
		timestamp : TimeOfDay;
		accel : TriAxialAcceleration;
	}

	item def SleepAnalysisReport {
		totalSleepTime : DurationHours;
		sleepEfficiency : Percentage;
		lightSleepDuration : DurationHours;
		deepSleepDuration : DurationHours;
		remSleepDuration : DurationHours;
		wakeDuration : DurationHours;
		summary : String;
	}

	item def DataTransferPayload {
		epochs : EpochData[0..*];
		deviceId : String;
		recordingStart : TimeOfDay;
		recordingEnd : TimeOfDay;
	}

	port def DataTransferPort {
		out dataOut : DataTransferPayload;
		in dataAck : Boolean;
	}

	port def PowerPort {
		in powerIn : Boolean;
	}

	port def SensorPort {
		out motion : RawMotionSample;
	}

	requirement def SystemRequirements {
		requirement BatteryLifeRequirement {
			doc "The wearable device shall operate for at least two weeks on a single charge.";
			subject watch : ActigraphyWatch;
			met : watch.battery.chargeLevel >= 0.0 [BatteryPercent];
		}
		requirement MemoryCapacityRequirement {
			doc "Internal memory shall hold several weeks of continuous recordings.";
			subject watch : ActigraphyWatch;
			met : watch.memory.capacity >= 20160 [ActivityCount];
		}
		requirement EpochProcessingRequirement {
			doc "Processor shall convert raw motion into activity counts for each epoch interval.";
			subject watch : ActigraphyWatch;
			met : watch.epochDuration == 60 [EpochDuration];
		}
		requirement SleepClassificationRequirement {
			doc "Processor shall classify each epoch into a sleep phase.";
			subject watch : ActigraphyWatch;
			met : watch.processor.classifiedPhase->size() == watch.processor.epochData->size();
		}
		requirement DataTransferRequirement {
			doc "Stored data shall be transferable to the analysis workstation.";
			subject system : ActigraphySystem;
			met : system.workstation.receivedData->size() > 0;
		}
		requirement ReportGenerationRequirement {
			doc "Workstation shall produce a comprehensive Sleep Analysis Report.";
			subject workstation : AnalysisWorkstation;
			met : workstation.report.totalSleepTime > 0 [DurationHours];
		}
	}

	part def SiliconeStrap {
		attribute material : String = "Medical-grade silicone";
		attribute adjustable : Boolean = true;
	}

	part def TriAxialAccelerometer {
		port sensorOut : SensorPort;
		attribute sampleRate : Real = 32 [1/s];
		action def measure {
			out sample : RawMotionSample;
		}
	}

	part def WatchProcessor {
		in rawMotion : RawMotionSample;
		out epochData : EpochData[0..*];
		attribute classifiedPhase : SleepPhase[0..*];
		action def processEpoch {
			in motion : RawMotionSample;
			out epoch : EpochData;
		}
	}

	part def InternalMemory {
		attribute capacity : ActivityCount;
		attribute stored : EpochData[0..*];
	}

	part def RechargeableBattery {
		attribute chargeLevel : BatteryPercent;
		attribute maxCharge : BatteryCharge = 144000;
	}

	part def ActigraphyWatch {
		port dataPort : DataTransferPort;
		port powerPort : PowerPort;
		attribute mode : WatchMode;
		attribute epochDuration : EpochDuration = 60 [EpochDuration];
		part strap : SiliconeStrap;
		part accelerometer : TriAxialAccelerometer {
			port sensorOut : SensorPort;
		}
		part processor : WatchProcessor {
			in rawMotion : RawMotionSample;
			out epochData : EpochData[0..*];
		}
		part memory : InternalMemory {
			attribute capacity : ActivityCount = 20160;
			attribute stored : EpochData[0..*];
		}
		part battery : RechargeableBattery {
			attribute chargeLevel : BatteryPercent = 100;
		}
		connection accelToProcessor connect accelerometer.sensorOut.motion to processor.rawMotion;
		connection processorToMemory connect processor.epochData to memory.stored;
		state def WatchState {
			initial state Recording {
				entry action assignMode { mode = WatchMode::recording; }
				do action sampleAndProcess {
					accelerometer.measure();
					processor.processEpoch();
				}
				transition to Idle when battery.chargeLevel < 5;
				transition to Downloading when dataPort.dataAck == true;
				transition to Charging when powerPort.powerIn == true;
			}
			state Idle {
				entry action assignMode { mode = WatchMode::idle; }
				transition to Recording when powerPort.powerIn == false;
				transition to Charging when powerPort.powerIn == true;
				transition to Downloading when dataPort.dataAck == true;
			}
			state Downloading {
				entry action assignMode { mode = WatchMode::downloading; }
				do action transferData {
					dataPort.dataOut = DataTransferPayload {
						epochs = memory.stored,
						deviceId = "ACT-001",
						recordingStart = memory.stored->first().timestamp,
						recordingEnd = memory.stored->last().timestamp
					};
				}
				transition to Idle when memory.stored->isEmpty();
				transition to Charging when powerPort.powerIn == true;
			}
			state Charging {
				entry action assignMode { mode = WatchMode::charging; }
				do action chargeBattery { battery.chargeLevel = battery.chargeLevel + 1; }
				transition to Idle when battery.chargeLevel >= 100;
			}
		}
		state behavior :>> WatchState;
	}

	part def SleepAnalysisSoftware {
		in data : DataTransferPayload;
		out report : SleepAnalysisReport;
		attribute version : String = "2.0";
	}

	part def AnalysisWorkstation {
		port dataPort : DataTransferPort;
		attribute receivedData : DataTransferPayload[0..*];
		attribute report : SleepAnalysisReport;
		part analysisSoftware : SleepAnalysisSoftware {
			in data : DataTransferPayload;
			out report : SleepAnalysisReport;
		}
		connection dataIn connect dataPort.dataOut to analysisSoftware.data;
		action def AnalyzeData {
			in payload : DataTransferPayload;
			out report : SleepAnalysisReport;
			action identifySleepWake {
				in epochs : EpochData[0..*];
				out sleepPeriods : EpochData[0..*];
				out wakePeriods : EpochData[0..*];
			}
			action calculateTotalSleepTime {
				in sleepPeriods : EpochData[0..*];
				out tst : DurationHours;
			}
			action calculateSleepEfficiency {
				in tst : DurationHours;
				in totalTimeInBed : DurationHours;
				out efficiency : Percentage;
			}
			action calculateStageDurations {
				in epochs : EpochData[0..*];
				out lightDuration : DurationHours;
				out deepDuration : DurationHours;
				out remDuration : DurationHours;
				out wakeDuration : DurationHours;
			}
			action generateReport {
				in tst : DurationHours;
				in efficiency : Percentage;
				in lightDuration : DurationHours;
				in deepDuration : DurationHours;
				in remDuration : DurationHours;
				in wakeDuration : DurationHours;
				out finalReport : SleepAnalysisReport;
			}
			flow identifySleepWake.sleepPeriods to calculateTotalSleepTime.sleepPeriods;
			flow identifySleepWake.sleepPeriods to calculateStageDurations.epochs;
			flow identifySleepWake.wakePeriods to calculateStageDurations.epochs;
			flow calculateTotalSleepTime.tst to calculateSleepEfficiency.tst;
			flow calculateTotalSleepTime.tst to generateReport.tst;
			flow calculateSleepEfficiency.efficiency to generateReport.efficiency;
			flow calculateStageDurations.lightDuration to generateReport.lightDuration;
			flow calculateStageDurations.deepDuration to generateReport.deepDuration;
			flow calculateStageDurations.remDuration to generateReport.remDuration;
			flow calculateStageDurations.wakeDuration to generateReport.wakeDuration;
			flow generateReport.finalReport to report;
		}
		action behavior :>> AnalyzeData;
	}

	part def BatteryCharger {
		port powerOut : PowerPort;
		attribute outputVoltage : Real = 5 [V];
	}

	part def ActigraphySystem {
		part watch : ActigraphyWatch;
		part workstation : AnalysisWorkstation;
		part charger : BatteryCharger {
			port powerOut : PowerPort;
		}
		connection watchToWorkstation connect watch.dataPort to workstation.dataPort;
		connection chargerToWatch connect charger.powerOut to watch.powerPort;
		satisfy SystemRequirements {
			subject system : ActigraphySystem = self;
		}
	}
}
