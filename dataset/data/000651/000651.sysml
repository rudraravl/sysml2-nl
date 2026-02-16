package 'PathologyInstrumentSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def TissueSample {
		attribute sampleID : String;
		attribute thickness : LengthValue;
		attribute fixationType : String;
		attribute collectionDate : String;
	}

	item def HistologicalSlide {
		attribute slideID : String;
		attribute stainType : String;
		attribute sectionThickness : LengthValue;
		attribute preparationTimestamp : String;
	}

	item def DigitalPathologyImage {
		attribute imageID : String;
		attribute resolution : Real;
		attribute magnification : Real;
		attribute scanTimestamp : String;
		attribute fileFormat : String;
	}

	item def DiagnosticReport {
		attribute reportID : String;
		attribute findings : String;
		attribute cellularAbnormalities : String[*];
		attribute diagnosticConfidence : Real;
		attribute pathologistNotes : String;
	}

	item def StainingReagent {
		attribute reagentType : String;
		attribute concentration : Real;
		attribute volume : VolumeValue;
		attribute expirationDate : String;
	}

	attribute def Temperature :> ThermodynamicTemperatureValue;
	attribute def Duration :> TimeValue;
	attribute def Volume :> VolumeValue;

	port def SampleInputPort {
		in item sample : TissueSample;
	}

	port def SlideOutputPort {
		out item slide : HistologicalSlide;
	}

	port def ImageOutputPort {
		out item image : DigitalPathologyImage;
	}

	port def ReportOutputPort {
		out item report : DiagnosticReport;
	}

	port def ControlInterfacePort {
		in attribute command : String;
		out attribute status : String;
		out attribute errorCode : Integer;
	}

	port def ReagentSupplyPort {
		in item reagent : StainingReagent;
	}

	part def TissueSectioner {
		attribute bladeAngle : Real;
		attribute sectionThickness : LengthValue;
		attribute operatingTemperature : Temperature;

		port sampleInput : SampleInputPort;
		port controlInterface : ControlInterfacePort;

		perform action sectionTissue {
			in tissueSample : TissueSample;
			out sectionedSample : TissueSample;
		}
	}

	part def AutomatedStainer {
		attribute numberOfStations : Integer;
		attribute cycleTime : Duration;
		attribute temperature : Temperature;

		port sampleInput : SampleInputPort;
		port reagentSupply : ReagentSupplyPort;
		port slideOutput : SlideOutputPort;
		port controlInterface : ControlInterfacePort;

		part heatingModule {
			attribute targetTemperature : Temperature;
			attribute heatingRate : Real;
		}

		part dispensingModule {
			attribute dispensingVolume : Volume;
			attribute dispensingAccuracy : Real;
		}

		perform action stainTissue {
			in preparedSample : TissueSample;
			in reagent : StainingReagent;
			out stainedSlide : HistologicalSlide;
		}
	}

	part def DigitalPathologyScanner {
		attribute scanningSpeed : Real;
		attribute opticalResolution : LengthValue;
		attribute maximumMagnification : Real;
		attribute illuminationType : String;

		port slideInput : SlideOutputPort;
		port imageOutput : ImageOutputPort;
		port controlInterface : ControlInterfacePort;

		part objectiveLensAssembly {
			attribute magnificationLevels : Real[*];
			attribute numericalAperture : Real;
		}

		part imagingSensor {
			attribute sensorResolution : Integer;
			attribute pixelSize : LengthValue;
			attribute bitDepth : Integer;
		}

		part focusingSystem {
			attribute autofocusAccuracy : LengthValue;
			attribute focusRange : LengthValue;
		}

		perform action scanSlide {
			in slide : HistologicalSlide;
			out digitalImage : DigitalPathologyImage;
		}
	}

	part def ImageAnalysisWorkstation {
		attribute processingCapacity : Real;
		attribute analysisAlgorithms : String[*];
		attribute aiModelVersion : String;

		port imageInput : ImageOutputPort;
		port reportOutput : ReportOutputPort;
		port controlInterface : ControlInterfacePort;

		part imageProcessor {
			attribute processingThreads : Integer;
			attribute memoryCapacity : Real;
		}

		part diagnosticEngine {
			attribute detectionSensitivity : Real;
			attribute classificationAccuracy : Real;
		}

		perform action analyzeImage {
			in pathologyImage : DigitalPathologyImage;
			out diagnosticReport : DiagnosticReport;
		}
	}

	part def EnvironmentalControlUnit {
		attribute targetTemperature : Temperature;
		attribute targetHumidity : Real;
		attribute airFiltrationLevel : String;

		perform action maintainEnvironment {
			in temperatureSetpoint : Temperature;
			in humiditySetpoint : Real;
			out actualTemperature : Temperature;
			out actualHumidity : Real;
		}
	}

	action def PrepareTissueSample {
		in rawTissue : TissueSample;
		out preparedSlide : HistologicalSlide;

		first start;
		then action section {
			in tissue = rawTissue;
			out sectionedTissue : TissueSample;
		}
		then action stain {
			in tissue = section.sectionedTissue;
			in reagent : StainingReagent;
			out slide : HistologicalSlide;
		}
		then assign preparedSlide := stain.slide;
		then done;
	}

	action def PerformPathologyDiagnostics {
		in tissueSample : TissueSample;
		in stainingReagent : StainingReagent;
		out finalReport : DiagnosticReport;

		first start;
		then merge processingLoop;
		then action prepareSample : PrepareTissueSample {
			in rawTissue = tissueSample;
			out preparedSlide;
		}
		then action digitizeSlide {
			in slide = prepareSample.preparedSlide;
			out scannedImage : DigitalPathologyImage;
		}
		then action performAnalysis {
			in image = digitizeSlide.scannedImage;
			out analysis : DiagnosticReport;
		}
		then decide;
			if performAnalysis.analysis.diagnosticConfidence >= 0.90 then acceptResult;
			else requestReview;
		action acceptResult {
			in report = performAnalysis.analysis;
		}
		then assign finalReport := performAnalysis.analysis;
		then done;
		action requestReview {
			in report = performAnalysis.analysis;
		}
		then processingLoop;
	}

	state def ScannerOperationalStates {
		entry; then standby;

		state standby;
		transition standby_to_initialization
			first standby
			accept cmd : String
			if cmd == "initialize"
			then initialization;

		state initialization {
			entry action performSystemCheck;
		}
		transition initialization_to_ready
			first initialization
			then ready;

		state ready;
		transition ready_to_scanning
			first ready
			accept cmd : String
			if cmd == "scan"
			then scanning;

		state scanning {
			entry action executeScanning;
			do action continuousMonitoring;
		}
		transition scanning_to_processing
			first scanning
			then processing;

		state processing {
			entry action processImageData;
		}
		transition processing_to_ready
			first processing
			then ready;

		transition ready_to_maintenance
			first ready
			accept cmd : String
			if cmd == "maintenance"
			then maintenance;

		state maintenance;
		transition maintenance_to_standby
			first maintenance
			then standby;

		transition any_to_error
			first any
			accept errorSignal : String
			then error;

		state error;
		transition error_to_standby
			first error
			accept cmd : String
			if cmd == "reset"
			then standby;
	}

	part pathologyInstrumentSystem {
		attribute systemIdentifier : String;
		attribute operationalMode : String;
		attribute lastCalibrationDate : String;

		part sectioner : TissueSectioner {
			attribute :>> sectionThickness = 4.0 [SI::µm];
			attribute :>> operatingTemperature = 253.15 [SI::K];
		}

		part stainer : AutomatedStainer {
			attribute :>> numberOfStations = 12;
			attribute :>> cycleTime = 120.0 [SI::s];
			attribute :>> temperature = 298.15 [SI::K];
		}

		part scanner : DigitalPathologyScanner {
			attribute :>> scanningSpeed = 60.0;
			attribute :>> maximumMagnification = 40.0;
			attribute :>> illuminationType = "LED";

			exhibit state scannerStates : ScannerOperationalStates;
		}

		part analysisWorkstation : ImageAnalysisWorkstation {
			attribute :>> processingCapacity = 1000.0;
			attribute :>> aiModelVersion = "v4.1.2";
		}

		part environmentalControl : EnvironmentalControlUnit {
			attribute :>> targetTemperature = 295.15 [SI::K];
			attribute :>> targetHumidity = 50.0;
			attribute :>> airFiltrationLevel = "HEPA";
		}

		connection sectionerToStainer connect
			sectioner.sampleInput to stainer.sampleInput;

		connection stainerToScanner connect
			stainer.slideOutput to scanner.slideInput;

		connection scannerToWorkstation connect
			scanner.imageOutput to analysisWorkstation.imageInput;

		perform action systemOperation : PerformPathologyDiagnostics[*] ordered {
			in tissueSample;
			in stainingReagent;
			out finalReport;
		}
	}

	requirement def SystemFunctionalRequirements {
		doc /* The pathology instrument system shall provide comprehensive automated 
		       tissue sample processing, high-resolution digital imaging, and AI-assisted 
		       diagnostic analysis to support accurate pathological diagnosis. */

		requirement samplePreparation {
			doc /* The system shall prepare tissue samples with section thickness 
			       between 2 and 6 micrometers with accuracy of ±0.5 micrometers. */

			require sectioner : TissueSectioner;
		}

		requirement imagingQuality {
			doc /* The system shall capture digital images with minimum resolution 
			       of 0.25 micrometers per pixel at 40x magnification. */

			require scanner : DigitalPathologyScanner;
		}

		requirement diagnosticAccuracy {
			doc /* The system shall achieve minimum diagnostic confidence of 90% 
			       for automated analysis results. */

			require workstation : ImageAnalysisWorkstation;
		}

		requirement environmentalStability {
			doc /* The system shall maintain environmental temperature at 22°C ±2°C 
			       and humidity at 50% ±10% during operation. */

			require envControl : EnvironmentalControlUnit;
		}

		requirement processingThroughput {
			doc /* The system shall process minimum 30 tissue samples per 8-hour shift. */
		}
	}

	requirement systemSpecification : SystemFunctionalRequirements {
		subject pathologySystem : pathologyInstrumentSystem;

		requirement :>> samplePreparation {
			subject sectioner = pathologySystem.sectioner;
		}

		requirement :>> imagingQuality {
			subject scanner = pathologySystem.scanner;
		}

		requirement :>> diagnosticAccuracy {
			subject workstation = pathologySystem.analysisWorkstation;
		}

		requirement :>> environmentalStability {
			subject envControl = pathologySystem.environmentalControl;
		}
	}
}
