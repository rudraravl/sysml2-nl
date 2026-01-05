package AutoAnalyzerSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SampleIdentifier;
	attribute def TestType;
	attribute def CalibrationCurve;
	
	item def BiologicalSample {
		attribute sampleID : SampleIdentifier;
		attribute volume : VolumeValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute collectionTime : String;
	}
	
	item def ChemicalReagent {
		attribute reagentName : String;
		attribute concentration : Real;
		attribute batchNumber : String;
		attribute expiryDate : String;
	}
	
	item def ReactionMixture {
		attribute sampleID : SampleIdentifier;
		attribute mixedVolume : VolumeValue;
		attribute reactionTemperature : ThermodynamicTemperatureValue;
	}
	
	item def MeasurementData {
		attribute sampleID : SampleIdentifier;
		attribute absorbance : Real;
		attribute wavelength : LengthValue;
		attribute timestamp : String;
	}
	
	item def AnalyticalResult {
		attribute sampleID : SampleIdentifier;
		attribute testType : TestType;
		attribute concentration : Real;
		attribute units : String;
		attribute qualityFlag : String;
		attribute timestamp : String;
	}
	
	item def WasteFluid {
		attribute volume : VolumeValue;
	}
	
	attribute def AbsorbanceValue :> Real;
	attribute def FlowRateValue :> VolumetricFlowRateValue;
	
	port def SampleIntakePort {
		in item sample : BiologicalSample;
	}
	
	port def ReagentSupplyPort {
		in item reagent : ChemicalReagent;
	}
	
	port def FluidOutputPort {
		out item mixture : ReactionMixture;
	}
	
	port def OpticalMeasurementPort {
		in item mixture : ReactionMixture;
		out item data : MeasurementData;
	}
	
	port def DataProcessingPort {
		in item rawData : MeasurementData;
		out item result : AnalyticalResult;
	}
	
	port def WastePort {
		out item waste : WasteFluid;
	}
	
	port def ControlCommandPort {
		in attribute command : String;
		out attribute status : String;
	}
	
	part def SampleIntakeModule {
		port sampleIn : SampleIntakePort;
		port sampleOut {
			out item preparedSample : BiologicalSample;
		}
		
		attribute queueCapacity : Integer;
		attribute currentPosition : Integer;
		
		action loadSample {
			in sample : BiologicalSample;
			out preparedSample : BiologicalSample;
		}
		
		action advanceQueue {
			in currentPos : Integer;
			out nextPos : Integer;
		}
	}
	
	part def ReagentDeliveryModule {
		port reagentIn : ReagentSupplyPort;
		port reagentOut {
			out item dispensedReagent : ChemicalReagent;
		}
		
		attribute reservoirVolume : VolumeValue;
		attribute dispensingRate : FlowRateValue;
		
		action dispenseReagent {
			in reagent : ChemicalReagent;
			in targetVolume : VolumeValue;
			out dispensedReagent : ChemicalReagent;
		}
	}
	
	part def MixingChamber {
		port sampleInput {
			in item sample : BiologicalSample;
		}
		port reagentInput {
			in item reagent : ChemicalReagent;
		}
		port mixtureOutput : FluidOutputPort;
		
		attribute chamberVolume : VolumeValue;
		attribute mixingSpeed : Real;
		
		action mixFluids {
			in sample : BiologicalSample;
			in reagent : ChemicalReagent;
			out mixture : ReactionMixture;
		}
	}
	
	part def IncubationUnit {
		port mixtureIn {
			in item mixture : ReactionMixture;
		}
		port mixtureOut {
			out item incubatedMixture : ReactionMixture;
		}
		
		attribute setpointTemperature : ThermodynamicTemperatureValue;
		attribute incubationDuration : DurationValue;
		attribute temperatureTolerance : ThermodynamicTemperatureValue;
		
		action incubate {
			in mixture : ReactionMixture;
			in duration : DurationValue;
			in temperature : ThermodynamicTemperatureValue;
			out incubatedMixture : ReactionMixture;
		}
		
		state incubationStateMachine {
			entry; then idle;
			
			state idle;
			transition idle_to_heating
				first idle
				then heating;
			
			state heating {
				entry; then reachTemperature;
				action reachTemperature;
			}
			transition heating_to_maintaining
				first heating
				then maintaining;
			
			state maintaining {
				entry; then holdTemperature;
				action holdTemperature : incubate;
			}
			transition maintaining_to_complete
				first maintaining
				then complete;
			
			state complete;
			transition complete_to_idle
				first complete
				then idle;
		}
	}
	
	part def SpectrophotometerModule {
		port measurementIn {
			in item mixture : ReactionMixture;
		}
		port dataOut {
			out item measurement : MeasurementData;
		}
		
		attribute wavelengthRange : LengthValue[2];
		attribute opticalPathLength : LengthValue;
		attribute detectorSensitivity : Real;
		
		action measureAbsorbance {
			in mixture : ReactionMixture;
			in wavelength : LengthValue;
			out absorbance : AbsorbanceValue;
		}
		
		action generateMeasurementData {
			in sampleID : SampleIdentifier;
			in absorbance : AbsorbanceValue;
			in wavelength : LengthValue;
			out data : MeasurementData;
		}
	}
	
	part def DataAnalysisModule {
		port dataIn {
			in item rawData : MeasurementData;
		}
		port resultOut {
			out item result : AnalyticalResult;
		}
		
		attribute calibrationData : CalibrationCurve;
		attribute algorithmVersion : String;
		
		action applyCalibration {
			in absorbance : AbsorbanceValue;
			in calibration : CalibrationCurve;
			out concentration : Real;
		}
		
		action validateResult {
			in concentration : Real;
			in sampleID : SampleIdentifier;
			out qualityFlag : String;
		}
		
		action assembleResult {
			in sampleID : SampleIdentifier;
			in concentration : Real;
			in qualityFlag : String;
			out result : AnalyticalResult;
		}
	}
	
	part def WasteManagementModule {
		port wasteIn {
			in item usedMixture : ReactionMixture;
		}
		port wasteOut : WastePort;
		
		attribute wasteCapacity : VolumeValue;
		attribute currentWasteLevel : VolumeValue;
		
		action collectWaste {
			in usedMixture : ReactionMixture;
			out waste : WasteFluid;
		}
	}
	
	part def SystemController {
		port controlPort : ControlCommandPort;
		
		attribute systemState : String;
		attribute errorLog : String[*];
		
		action initializeSystem;
		action shutdownSystem;
		action handleError {
			in errorCode : String;
			out recoveryAction : String;
		}
	}
	
	part def AutoAnalyzer {
		doc /*
			An automated clinical chemistry analyzer that performs quantitative 
			analysis of biological samples through spectrophotometric detection.
			The system automates sample handling, reagent dispensing, mixing, 
			incubation, optical measurement, and data analysis to produce 
			accurate analytical results with minimal human intervention.
		*/
		
		port sampleInput : SampleIntakePort;
		port reagentInput : ReagentSupplyPort;
		port resultOutput {
			out item result : AnalyticalResult;
		}
		port wasteOutput : WastePort;
		port systemControl : ControlCommandPort;
		
		part sampleIntake : SampleIntakeModule;
		part reagentDelivery : ReagentDeliveryModule;
		part mixingChamber : MixingChamber;
		part incubationUnit : IncubationUnit;
		part spectrophotometer : SpectrophotometerModule;
		part dataAnalysis : DataAnalysisModule;
		part wasteManagement : WasteManagementModule;
		part controller : SystemController;
		
		connect sampleInput to sampleIntake.sampleIn;
		connect reagentInput to reagentDelivery.reagentIn;
		connect sampleIntake.sampleOut to mixingChamber.sampleInput;
		connect reagentDelivery.reagentOut to mixingChamber.reagentInput;
		connect mixingChamber.mixtureOutput to incubationUnit.mixtureIn;
		connect incubationUnit.mixtureOut to spectrophotometer.measurementIn;
		connect spectrophotometer.dataOut to dataAnalysis.dataIn;
		connect dataAnalysis.resultOut to resultOutput;
		connect incubationUnit.mixtureOut to wasteManagement.wasteIn;
		connect wasteManagement.wasteOut to wasteOutput;
		connect systemControl to controller.controlPort;
		
		perform action executeAnalysis[*] ordered references performCompleteAnalysis;
	}
	
	action def PrepareSample {
		in rawSample : BiologicalSample;
		out preparedSample : BiologicalSample;
	}
	
	action def CreateReactionMixture {
		in sample : BiologicalSample;
		in reagent : ChemicalReagent;
		out mixture : ReactionMixture;
	}
	
	action def IncubateReaction {
		in mixture : ReactionMixture;
		in duration : DurationValue;
		in temperature : ThermodynamicTemperatureValue;
		out incubatedMixture : ReactionMixture;
	}
	
	action def PerformOpticalMeasurement {
		in mixture : ReactionMixture;
		in wavelength : LengthValue;
		out measurement : MeasurementData;
	}
	
	action def AnalyzeData {
		in measurement : MeasurementData;
		in calibration : CalibrationCurve;
		out result : AnalyticalResult;
	}
	
	action def DisposeWaste {
		in usedMixture : ReactionMixture;
		out waste : WasteFluid;
	}
	
	action performCompleteAnalysis {
		doc /*
			Complete analytical workflow that accepts a biological sample,
			mixes it with appropriate reagent, incubates the reaction,
			measures optical properties, analyzes the data using calibration,
			and produces a quantitative analytical result.
		*/
		
		first start;
		
		then action acceptSample {
			in inputSample : BiologicalSample;
			out validatedSample : BiologicalSample;
		}
		
		then action prepareSample : PrepareSample {
			in rawSample = acceptSample.validatedSample;
			out preparedSample : BiologicalSample;
		}
		
		then action dispenseReagent {
			in requiredReagent : ChemicalReagent;
			in volume : VolumeValue;
			out dispensedReagent : ChemicalReagent;
		}
		
		then action createMixture : CreateReactionMixture {
			in sample = prepareSample.preparedSample;
			in reagent = dispenseReagent.dispensedReagent;
			out reactionMixture : ReactionMixture;
		}
		
		then action incubateReaction : IncubateReaction {
			in mixture = createMixture.reactionMixture;
			in duration : DurationValue;
			in temperature : ThermodynamicTemperatureValue;
			out incubatedMixture : ReactionMixture;
		}
		
		then action performMeasurement : PerformOpticalMeasurement {
			in mixture = incubateReaction.incubatedMixture;
			in wavelength : LengthValue;
			out measurementData : MeasurementData;
		}
		
		then action analyzeData : AnalyzeData {
			in measurement = performMeasurement.measurementData;
			in calibration : CalibrationCurve;
			out analyticalResult : AnalyticalResult;
		}
		
		then action disposeWaste : DisposeWaste {
			in usedMixture = incubateReaction.incubatedMixture;
			out wasteFluid : WasteFluid;
		}
		
		then action reportResult {
			in result = analyzeData.analyticalResult;
		}
		
		then done;
	}
	
	part autoAnalyzerSystem : AutoAnalyzer {
		perform action executeAnalysis[*] ordered references performCompleteAnalysis;
		
		part :>> sampleIntake {
			perform executeAnalysis.acceptSample;
			perform executeAnalysis.prepareSample;
		}
		
		part :>> reagentDelivery {
			perform executeAnalysis.dispenseReagent;
		}
		
		part :>> mixingChamber {
			perform executeAnalysis.createMixture;
		}
		
		part :>> incubationUnit {
			perform executeAnalysis.incubateReaction;
		}
		
		part :>> spectrophotometer {
			perform executeAnalysis.performMeasurement;
		}
		
		part :>> dataAnalysis {
			perform executeAnalysis.analyzeData;
			perform executeAnalysis.reportResult;
		}
		
		part :>> wasteManagement {
			perform executeAnalysis.disposeWaste;
		}
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /*
			The analyzer shall produce measurement results within 
			specified accuracy and precision limits.
		*/
		
		attribute maxSystematicError : Real;
		attribute maxRandomError : Real;
		attribute confidenceLevel : Real;
		
		require constraint accuracyLimit {
			doc /* Systematic error must not exceed maximum allowable. */
		}
		
		require constraint precisionLimit {
			doc /* Random error must not exceed maximum allowable. */
		}
	}
	
	requirement def ThroughputRequirement {
		doc /*
			The analyzer shall process a minimum number of samples 
			per unit time to meet clinical laboratory demands.
		*/
		
		attribute minSamplesPerHour : Real;
		attribute maxTurnaroundTime : DurationValue;
		
		require constraint throughputLimit {
			doc /* Sample processing rate must meet minimum throughput. */
		}
	}
	
	requirement def ReagentStabilityRequirement {
		doc /*
			The analyzer shall maintain reagent stability and 
			detect reagent degradation.
		*/
		
		attribute maxStorageTemperature : ThermodynamicTemperatureValue;
		attribute minStorageTemperature : ThermodynamicTemperatureValue;
		
		require constraint temperatureControl {
			doc /* Reagent storage temperature must remain within limits. */
		}
	}
	
	requirement def CalibrationRequirement {
		doc /*
			The analyzer shall maintain valid calibration and 
			alert when recalibration is needed.
		*/
		
		attribute calibrationInterval : DurationValue;
		attribute calibrationStandards : Integer;
		
		require constraint validCalibration {
			doc /* Calibration must be current and verified. */
		}
	}
	
	requirement def WasteManagementRequirement {
		doc /*
			The analyzer shall safely contain and manage waste fluids 
			without leakage or overflow.
		*/
		
		attribute maxWasteCapacity : VolumeValue;
		
		require constraint wasteContainment {
			doc /* Waste must be contained without leakage. */
		}
	}
	
	requirement <'AA-REQ-001'> primaryFunctionRequirement {
		doc /*
			The AutoAnalyzer shall automatically perform quantitative chemical 
			analysis of biological samples by mixing samples with reagents, 
			incubating reactions under controlled conditions, measuring optical 
			properties, and computing analyte concentrations with high accuracy 
			and throughput.
		*/
		
		subject autoAnalyzerSystem;
		
		require measurementAccuracyReq : MeasurementAccuracyRequirement {
			maxSystematicError = 2.0;
			maxRandomError = 1.5;
			confidenceLevel = 95.0;
		}
		
		require throughputReq : ThroughputRequirement {
			minSamplesPerHour = 180.0;
			maxTurnaroundTime = 300.0 [SI::s];
		}
		
		require reagentStabilityReq : ReagentStabilityRequirement {
			maxStorageTemperature = 281.0 [SI::K];
			minStorageTemperature = 275.0 [SI::K];
		}
		
		require calibrationReq : CalibrationRequirement {
			calibrationInterval = 86400.0 [SI::s];
			calibrationStandards = 5;
		}
		
		require wasteManagementReq : WasteManagementRequirement {
			maxWasteCapacity = 5.0 [SI::L];
		}
	}
	
	requirement <'AA-REQ-002'> temperatureControlRequirement {
		doc /*
			The incubation unit shall maintain reaction temperature 
			within specified tolerance during incubation.
		*/
		
		subject incubationUnit : autoAnalyzerSystem.incubationUnit;
		
		require constraint temperatureTolerance {
			doc /* Temperature deviation must not exceed ±0.5 K. */
		}
	}
	
	requirement <'AA-REQ-003'> opticalPerformanceRequirement {
		doc /*
			The spectrophotometer shall provide accurate absorbance 
			measurements across the specified wavelength range.
		*/
		
		subject spectrophotometer : autoAnalyzerSystem.spectrophotometer;
		
		require constraint wavelengthAccuracy {
			doc /* Wavelength accuracy must be within ±1 nm. */
		}
		
		require constraint photometricLinearity {
			doc /* Absorbance linearity must be maintained to 2.5 AU. */
		}
	}
}
