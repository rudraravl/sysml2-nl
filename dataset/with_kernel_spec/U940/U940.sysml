package VisualSensingUnit {
	private import ScalarValues::*;

	attribute def Illuminance :> Real;
	attribute def Area :> Real;
	attribute def Latency :> Real;
	attribute def QualityScore :> Real;

	item def SyncSignal;
	item def RawImageData;
	item def FaultAlert;

	item def ProcessedData {
		attribute illuminance : Illuminance;
		attribute coverageArea : Area;
		attribute quality : QualityScore;
	}

	item def EnvironmentalModel {
		attribute aggregatedIlluminance : Illuminance;
		attribute totalCoverageArea : Area;
		attribute overallQuality : QualityScore;
	}

	item def MeasurementReport {
		attribute model : EnvironmentalModel;
	}

	enum def OperationalMode {
		normal;
		highPrecision;
		lowPower;
	}

	part def OpticalAssembly {
		out port light : RawImageData;
		part lens;
		part opticalFilter;
	}

	part def ImageSensorArray {
		in port light : RawImageData;
		out port rawImage : RawImageData;
		flow light to rawImage;
	}

	part def VisualSensor {
		in port syncSignal : SyncSignal;
		out port rawImageOut : RawImageData;
		out port healthStatus : Boolean;

		part opticalAssembly : OpticalAssembly;
		part sensorArray : ImageSensorArray;
		part localProcessor {
			in rawImage : RawImageData;
			out processedImage : RawImageData;
		}
		connect opticalAssembly.light to sensorArray.light;
		flow sensorArray.rawImage to localProcessor.rawImage;
		flow localProcessor.processedImage to rawImageOut;
	}

	part def DataProcessor {
		in port rawImageIn : RawImageData;
		out port processedDataOut : ProcessedData;

		action enhanceImage {
			in raw : RawImageData;
			out enhanced : RawImageData;
		}
		action extractFeatures {
			in enhanced : RawImageData;
			out features : ProcessedData;
		}
		flow rawImageIn to enhanceImage.raw;
		flow enhanceImage.enhanced to extractFeatures.enhanced;
		flow extractFeatures.features to processedDataOut;
	}

	part def DataFusionUnit {
		in port processedData : ProcessedData[4];
		out port modelOut : EnvironmentalModel;

		action fuseData {
			in data : ProcessedData[4];
			out model : EnvironmentalModel;
		}
		flow processedData to fuseData.data;
		flow fuseData.model to modelOut;
	}

	part def NetworkController {
		out port syncSignals : SyncSignal[4];
		in port modeIn : OperationalMode;
		in port faultAlertIn : FaultAlert;

		attribute currentMode : OperationalMode;
		action setMode;
		action emitSync;

		state def ControllerState {
			entry; then Normal;

			state Normal {
				do action emitSync;
			}
			state HighPrecision {
				do action emitSync;
			}
			state LowPower {
				do action emitSync;
			}
			state Degraded {
				do action emitSync;
			}

			transition first Normal
				accept mode : OperationalMode via modeIn
				if mode == OperationalMode::highPrecision
				do action setMode
				then HighPrecision;
			transition first Normal
				accept mode : OperationalMode via modeIn
				if mode == OperationalMode::lowPower
				do action setMode
				then LowPower;
			transition first HighPrecision
				accept mode : OperationalMode via modeIn
				if mode == OperationalMode::normal
				do action setMode
				then Normal;
			transition first HighPrecision
				accept mode : OperationalMode via modeIn
				if mode == OperationalMode::lowPower
				do action setMode
				then LowPower;
			transition first LowPower
				accept mode : OperationalMode via modeIn
				if mode == OperationalMode::normal
				do action setMode
				then Normal;
			transition first LowPower
				accept mode : OperationalMode via modeIn
				if mode == OperationalMode::highPrecision
				do action setMode
				then HighPrecision;
			transition first Normal
				accept fault : FaultAlert via faultAlertIn
				do action setMode
				then Degraded;
			transition first HighPrecision
				accept fault : FaultAlert via faultAlertIn
				do action setMode
				then Degraded;
			transition first LowPower
				accept fault : FaultAlert via faultAlertIn
				do action setMode
				then Degraded;
			transition first Degraded
				accept mode : OperationalMode via modeIn
				if mode == OperationalMode::normal
				do action setMode
				then Normal;
		}
		exhibit ControllerState;
	}

	part def VisualSensingSystem {
		in port modeCommand : OperationalMode;
		out port reportOut : MeasurementReport;
		in port faultAlert : FaultAlert;

		part controller : NetworkController;
		part sensors : VisualSensor[4];
		part processors : DataProcessor[4];
		part fusionUnit : DataFusionUnit;

		action generateReport {
			in model : EnvironmentalModel;
			out report : MeasurementReport;
		}

		connect modeCommand to controller.modeIn;
		connect faultAlert to controller.faultAlertIn;
		connect controller.syncSignals to sensors.syncSignal;
		connect sensors.rawImageOut to processors.rawImageIn;
		connect processors.processedDataOut to fusionUnit.processedData;
		flow fusionUnit.modelOut to generateReport.model;
		flow generateReport.report to reportOut;

		requirement def SystemRequirements {
			subject system : VisualSensingSystem;

			requirement Reliability {
				subject system;
				doc /* The system shall continue operations even if one of the four sensors fails. */
			}
			requirement Performance {
				subject system;
				doc /* The entire process from data capture to final report generation shall occur in near real-time with very low latency. */
				attribute maxLatency : Latency = 10.0;
			}
			requirement Coverage {
				subject system;
				doc /* The system shall measure illuminance and spatial characteristics over a large defined area using four parallel optical sensors. */
			}
		}
	}
}
