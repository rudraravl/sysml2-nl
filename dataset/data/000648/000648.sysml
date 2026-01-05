package 'Medical Laboratory Instrument System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def SampleIdentifier;
	attribute def TestType;
	attribute def CalibrationStatus;

	attribute def ConcentrationValue {
		attribute numericValue : Real;
		attribute unitString : String;
	}

	attribute def AbsorbanceValue {
		attribute value : Real;
	}

	item def BiologicalSample {
		attribute sampleID : SampleIdentifier;
		attribute volume : VolumeValue;
		attribute collectionTimestamp : String;
		attribute patientID : String;
	}

	item def ChemicalReagent {
		attribute reagentName : String;
		attribute lotNumber : String;
		attribute concentration : ConcentrationValue;
		attribute expiryDate : String;
	}

	item def TestResult {
		attribute sampleID : SampleIdentifier;
		attribute testType : TestType;
		attribute measuredValue : Real;
		attribute unit : String;
		attribute referenceRangeLow : Real;
		attribute referenceRangeHigh : Real;
		attribute isAbnormal : Boolean;
		attribute timestamp : String;
	}

	item def DiagnosticReport {
		attribute sampleID : SampleIdentifier;
		attribute results : TestResult[1..*];
		attribute reportGeneratedTime : String;
		attribute validationStatus : String;
	}

	port def SampleIntakePort {
		in item sample : BiologicalSample;
	}

	port def ReagentSupplyPort {
		in item reagent : ChemicalReagent;
	}

	port def ResultDeliveryPort {
		out item report : DiagnosticReport;
	}

	port def ControlCommandPort {
		in attribute command : String;
		out attribute statusResponse : String;
	}

	port def DataTransferPort {
		in item data;
		out item processedData;
	}

	action def InitializeSystem {
		out systemReady : Boolean;
		first start;
		then assign systemReady := true;
		then done;
	}

	action def LoadBiologicalSample {
		in sample : BiologicalSample;
		out sampleLoaded : Boolean;
		out loadedSampleID : SampleIdentifier;
		first start;
		then assign loadedSampleID := sample.sampleID;
		then assign sampleLoaded := true;
		then done;
	}

	action def PrepareSample {
		in rawSample : BiologicalSample;
		out preparedSample : BiologicalSample;
		first start;
		then assign preparedSample := rawSample;
		then done;
	}

	action def DispenseReagent {
		in reagent : ChemicalReagent;
		in targetVolume : VolumeValue;
		out dispensed : Boolean;
		first start;
		then assign dispensed := true;
		then done;
	}

	action def MixSampleWithReagent {
		in preparedSample : BiologicalSample;
		in reagent : ChemicalReagent;
		out reactionMixture;
		first start;
		then done;
	}

	action def IncubateMixture {
		in mixture;
		in temperature : TemperatureValue;
		in duration : TimeValue;
		out incubatedMixture;
		first start;
		then done;
	}

	action def MeasureAbsorbance {
		in mixture;
		in wavelength : LengthValue;
		out absorbance : AbsorbanceValue;
		first start;
		then done;
	}

	action def CalculateConcentration {
		in absorbance : AbsorbanceValue;
		in calibrationCurve;
		out concentration : ConcentrationValue;
		first start;
		then done;
	}

	action def ValidateResult {
		in result : TestResult;
		out isValid : Boolean;
		first start;
		then assign isValid := true;
		then done;
	}

	action def GenerateDiagnosticReport {
		in results : TestResult[1..*];
		in sampleID : SampleIdentifier;
		out report : DiagnosticReport;
		first start;
		then assign report.sampleID := sampleID;
		then assign report.results := results;
		then assign report.validationStatus := "Validated";
		then done;
	}

	action def PerformQualityControl {
		in controlSample : BiologicalSample;
		out qcPassed : Boolean;
		first start;
		then assign qcPassed := true;
		then done;
	}

	action def CalibrateInstrument {
		in calibrationStandards[1..*];
		out calibrationComplete : Boolean;
		first start;
		then assign calibrationComplete := true;
		then done;
	}

	action def CleanFluidics {
		out cleaningComplete : Boolean;
		first start;
		then assign cleaningComplete := true;
		then done;
	}

	action def PerformCompleteAnalysis {
		in inputSample : BiologicalSample;
		in reagent : ChemicalReagent;
		out finalResult : TestResult;

		first start;
		then action prepare : PrepareSample {
			in rawSample = inputSample;
			out preparedSample;
		}
		then action dispense : DispenseReagent {
			in reagent = reagent;
			in targetVolume;
			out dispensed;
		}
		then action mix : MixSampleWithReagent {
			in preparedSample = prepare.preparedSample;
			in reagent = reagent;
			out reactionMixture;
		}
		then action incubate : IncubateMixture {
			in mixture = mix.reactionMixture;
			in temperature;
			in duration;
			out incubatedMixture;
		}
		then action measure : MeasureAbsorbance {
			in mixture = incubate.incubatedMixture;
			in wavelength;
			out absorbance;
		}
		then action calculate : CalculateConcentration {
			in absorbance = measure.absorbance;
			in calibrationCurve;
			out concentration;
		}
		then action validate : ValidateResult {
			in result = finalResult;
			out isValid;
		}
		then assign finalResult.sampleID := inputSample.sampleID;
		then assign finalResult.measuredValue := calculate.concentration.numericValue;
		then done;
	}

	part def SampleHandlingModule {
		port sampleIn : SampleIntakePort;
		port sampleOut : DataTransferPort;

		attribute handlingStatus : String;
		attribute currentSampleID : SampleIdentifier;

		perform action handleSample : LoadBiologicalSample;
		perform action prepareSample : PrepareSample;
	}

	part def ReagentManagementModule {
		port reagentIn : ReagentSupplyPort;
		port reagentOut : DataTransferPort;

		attribute reagentInventory : ChemicalReagent[*];
		attribute dispensingStatus : String;

		perform action dispenseReagent : DispenseReagent;
	}

	part def OpticalDetectionModule {
		port dataIn : DataTransferPort;
		port dataOut : DataTransferPort;

		attribute wavelengthRange : LengthValue;
		attribute detectorTemperature : TemperatureValue;
		attribute measurementPrecision : Real;

		perform action measureAbsorbance : MeasureAbsorbance;
	}

	part def DataProcessingModule {
		port rawDataIn : DataTransferPort;
		port reportOut : ResultDeliveryPort;

		attribute processingAlgorithm : String;
		attribute calibrationData;

		perform action calculateConcentration : CalculateConcentration;
		perform action validateResult : ValidateResult;
		perform action generateReport : GenerateDiagnosticReport;
	}

	part def QualityControlModule {
		port controlIn : ControlCommandPort;

		attribute lastCalibrationDate : String;
		attribute calibrationStatus : CalibrationStatus;
		attribute qcFrequency : TimeValue;

		perform action performQC : PerformQualityControl;
		perform action calibrate : CalibrateInstrument;
	}

	part def FluidicsModule {
		port fluidIn;
		port fluidOut;
		port wasteOut;

		attribute pumpStatus : String;
		attribute valvePositions : String[*];
		attribute flowRate : VolumeFlowRateValue;

		perform action mixReagents : MixSampleWithReagent;
		perform action incubate : IncubateMixture;
		perform action cleanSystem : CleanFluidics;
	}

	part def ClinicalChemistryAnalyzer {
		attribute instrumentID : String;
		attribute modelNumber : String;
		attribute serialNumber : String;
		attribute operationalState : String;
		attribute throughputCapacity : Real;

		part sampleHandler : SampleHandlingModule;
		part reagentManager : ReagentManagementModule;
		part fluidics : FluidicsModule;
		part opticalDetector : OpticalDetectionModule;
		part dataProcessor : DataProcessingModule;
		part qualityControl : QualityControlModule;

		port sampleInput : SampleIntakePort;
		port reagentInput : ReagentSupplyPort;
		port reportOutput : ResultDeliveryPort;
		port controlInterface : ControlCommandPort;

		connection sampleInputConnection
			connect sampleInput to sampleHandler.sampleIn;

		connection sampleToFluidicsConnection
			connect sampleHandler.sampleOut to fluidics.fluidIn;

		connection reagentInputConnection
			connect reagentInput to reagentManager.reagentIn;

		connection reagentToFluidicsConnection
			connect reagentManager.reagentOut to fluidics.fluidIn;

		connection fluidicsToDetectorConnection
			connect fluidics.fluidOut to opticalDetector.dataIn;

		connection detectorToProcessorConnection
			connect opticalDetector.dataOut to dataProcessor.rawDataIn;

		connection processorToOutputConnection
			connect dataProcessor.reportOut to reportOutput;

		connection controlToQCConnection
			connect controlInterface to qualityControl.controlIn;

		perform action operateAnalyzer {
			first start;
			then action initialize : InitializeSystem {
				out systemReady;
			}
			then merge awaitSample;

			action loadSample : LoadBiologicalSample {
				in sample;
				out sampleLoaded;
				out loadedSampleID;
			}
			then action performAnalysis : PerformCompleteAnalysis {
				in inputSample;
				in reagent;
				out finalResult;
			}
			then action createReport : GenerateDiagnosticReport {
				in results;
				in sampleID = loadSample.loadedSampleID;
				out report;
			}
			then action cleanFluidics : CleanFluidics {
				out cleaningComplete;
			}
			then decide;
				if cleanFluidics.cleaningComplete then awaitSample;
			then done;
		}
	}

	part def LaboratoryInformationSystem {
		attribute systemID : String;
		attribute databaseConnection : String;

		perform action manageWorkflow {
			in sampleBatch : BiologicalSample[*];
			out completedReports : DiagnosticReport[*];
		}

		perform action archiveResults {
			in reports : DiagnosticReport[*];
			out archiveComplete : Boolean;
		}
	}

	requirement def MeasurementAccuracyRequirement {
		doc /* The analyzer shall measure analyte concentrations with coefficient of variation ≤3% within the analytical measurement range. */

		subject analyzer : ClinicalChemistryAnalyzer;

		attribute maxCoefficientOfVariation : Real = 3.0;

		require constraint {
			doc /* Measurement precision must meet clinical laboratory standards. */
		}
	}

	requirement def ThroughputRequirement {
		doc /* The analyzer shall process a minimum of 200 tests per hour in continuous operation mode. */

		subject analyzer : ClinicalChemistryAnalyzer;

		attribute minimumTestsPerHour : Real = 200.0;

		require constraint {
			analyzer.throughputCapacity >= minimumTestsPerHour
		}
	}

	requirement def SampleVolumeRequirement {
		doc /* The analyzer shall perform complete analysis using sample volumes not exceeding 10 microliters. */

		subject analyzer : ClinicalChemistryAnalyzer;

		attribute maximumSampleVolume : VolumeValue;

		require constraint {
			doc /* Minimal sample volume enables pediatric and critical care testing. */
		}
	}

	requirement def CalibrationStabilityRequirement {
		doc /* The analyzer shall maintain calibration stability for at least 30 days under normal operating conditions. */

		subject qc : QualityControlModule;

		attribute minimumCalibrationPeriod : TimeValue;

		require constraint {
			doc /* Extended calibration stability reduces operational overhead. */
		}
	}

	requirement def BiosafetyRequirement {
		doc /* The analyzer shall contain all biological samples within sealed compartments to prevent operator exposure. */

		subject analyzer : ClinicalChemistryAnalyzer;

		require constraint {
			doc /* Closed system design ensures biosafety compliance. */
		}
	}

	requirement def DataIntegrityRequirement {
		doc /* The analyzer shall maintain complete audit trail of all test results with timestamp and operator identification. */

		subject dataProcessor : DataProcessingModule;

		require constraint {
			doc /* Data integrity supports regulatory compliance and quality assurance. */
		}
	}

	part clinicalLaboratorySystem {
		part chemistryAnalyzer : ClinicalChemistryAnalyzer {
			:>> instrumentID = "CCA-2024-001";
			:>> modelNumber = "ChemAnalyzer-Pro-3000";
			:>> serialNumber = "SN-20240515-0042";
			:>> throughputCapacity = 250.0;
		}

		part lis : LaboratoryInformationSystem {
			:>> systemID = "LIS-MAIN-CENTRAL";
			:>> databaseConnection = "secure-db.hospital.local";
		}

		satisfy accuracyReq : MeasurementAccuracyRequirement by chemistryAnalyzer;
		satisfy throughputReq : ThroughputRequirement by chemistryAnalyzer;
		satisfy sampleVolumeReq : SampleVolumeRequirement by chemistryAnalyzer;
		satisfy calibrationReq : CalibrationStabilityRequirement by chemistryAnalyzer.qualityControl;
		satisfy biosafetyReq : BiosafetyRequirement by chemistryAnalyzer;
		satisfy dataIntegrityReq : DataIntegrityRequirement by chemistryAnalyzer.dataProcessor;
	}

	action def ProcessDailyTestBatch {
		in testBatch : BiologicalSample[*];
		out batchReports : DiagnosticReport[*] := ( );

		private attribute currentReport : DiagnosticReport;

		for sample in testBatch {
			perform action analyzeSample : PerformCompleteAnalysis {
				in inputSample = sample;
				in reagent;
				out finalResult;
			}
			then action createReport : GenerateDiagnosticReport {
				in results := (analyzeSample.finalResult);
				in sampleID = sample.sampleID;
				out report;
			}
			then assign currentReport := createReport.report;
			then assign batchReports := batchReports->including(currentReport);
		}
	}
}
