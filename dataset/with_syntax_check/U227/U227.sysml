package 'Flow Injection Analysis System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	
	attribute def SampleIdentifier;
	attribute def CalibrationCurve;
	
	enum def VerdictKind {
		enum pass;
		enum fail;
		enum inconclusive;
		enum error;
	}
	
	attribute def Absorbance :> Real;
	
	item def CarrierSolution {
		attribute flowRate : VolumeFlowRateValue;
		attribute composition : String;
	}
	
	item def ReagentSolution {
		attribute flowRate : VolumeFlowRateValue;
		attribute concentration : AmountOfSubstanceConcentrationValue;
	}
	
	item def SamplePlug {
		attribute volume : VolumeValue;
		attribute sampleID : SampleIdentifier;
		attribute analyteConcentration : AmountOfSubstanceConcentrationValue;
	}
	
	item def MixedStream {
		attribute flowRate : VolumeFlowRateValue;
	}
	
	item def ReactionProduct {
		attribute absorbance : Absorbance;
	}
	
	item def WasteStream {
		attribute volume : VolumeValue;
	}
	
	port def FluidInletPort {
		in item fluidIn;
		attribute inletFlowRate : VolumeFlowRateValue;
	}
	
	port def FluidOutletPort {
		out item fluidOut;
		attribute outletFlowRate : VolumeFlowRateValue;
	}
	
	port def SamplePort {
		in item sampleIn : SamplePlug;
	}
	
	port def DetectionPort {
		out attribute signal : Absorbance;
	}
	
	port def ControlPort {
		in attribute command : Real;
		out attribute status : Real;
	}
	
	part def PeristalticPump {
		attribute nominalFlowRate : VolumeFlowRateValue;
		attribute maxFlowRate : VolumeFlowRateValue;
		
		port controlIn : ControlPort;
		port fluidIn : FluidInletPort;
		port fluidOut : FluidOutletPort;
		
		perform action pumpFluid {
			in flowCommand : Real;
			out actualFlowRate : VolumeFlowRateValue;
		}
	}
	
	part def InjectionValve {
		attribute loopVolume : VolumeValue;
		attribute switchTime : TimeValue;
		
		port sampleInput : SamplePort;
		port carrierIn : FluidInletPort;
		port streamOut : FluidOutletPort;
		port valveControl : ControlPort;
		
		state def InjectionStateMachine {
			entry; then loadPosition;
			
			state loadPosition {
				do action fillSampleLoop {
					in sample : SamplePlug;
					out loopFilled : Boolean;
				}
			}
			
			transition first loadPosition
				then injectPosition
				accept injectCommand;
			
			state injectPosition {
				do action injectSamplePlug {
					in carrier : CarrierSolution;
					in samplePlug : SamplePlug;
					out injectedStream : MixedStream;
				}
			}
			
			transition first injectPosition
				then loadPosition
				accept resetCommand;
		}
	}
	
	part def MixingTee {
		attribute mixingEfficiency : Real;
		
		port stream1In : FluidInletPort;
		port stream2In : FluidInletPort;
		port mixedOut : FluidOutletPort;
		
		perform action combineStreams {
			in stream1 : CarrierSolution;
			in stream2 : ReagentSolution;
			out combinedStream : MixedStream;
		}
	}
	
	part def ReactionCoil {
		attribute coilVolume : VolumeValue;
		attribute coilLength : LengthValue;
		attribute residenceTime : TimeValue;
		
		port streamIn : FluidInletPort;
		port streamOut : FluidOutletPort;
		
		perform action induceReaction {
			in reactants : MixedStream;
			out products : ReactionProduct;
		}
	}
	
	part def FlowThroughDetector {
		attribute wavelength : LengthValue;
		attribute pathLength : LengthValue;
		attribute sensitivity : Real;
		attribute noiseLevel : Absorbance;
		
		port cellIn : FluidInletPort;
		port cellOut : FluidOutletPort;
		port signalOut : DetectionPort;
		
		perform action measureAbsorbance {
			in reactionProduct : ReactionProduct;
			out absorbanceSignal : Absorbance;
			out peakHeight : Absorbance;
		}
	}
	
	part def DataAcquisitionSystem {
		attribute samplingRate : FrequencyValue;
		attribute calibration : CalibrationCurve;
		
		port signalIn : DetectionPort;
		port dataOut;
		
		perform action processSignal {
			in rawSignal : Absorbance;
			in peakHeight : Absorbance;
			in calibrationData : CalibrationCurve;
			out analyteConcentration : AmountOfSubstanceConcentrationValue;
			out peakArea : Real;
		}
	}
	
	part def WasteReservoir {
		attribute capacity : VolumeValue;
		attribute currentVolume : VolumeValue;
		
		port wasteIn : FluidInletPort;
	}
	
	part def FIASystem {
		attribute systemFlowRate : VolumeFlowRateValue;
		attribute analysisTime : TimeValue;
		
		part carrierPump : PeristalticPump {
			attribute :>> nominalFlowRate = 1.5 [SI::mL/SI::min];
			attribute :>> maxFlowRate = 5.0 [SI::mL/SI::min];
		}
		
		part reagentPump : PeristalticPump {
			attribute :>> nominalFlowRate = 0.8 [SI::mL/SI::min];
			attribute :>> maxFlowRate = 3.0 [SI::mL/SI::min];
		}
		
		part injector : InjectionValve {
			attribute :>> loopVolume = 200.0 [SI::uL];
			attribute :>> switchTime = 0.5 [SI::s];
		}
		
		part mixingTee : MixingTee {
			attribute :>> mixingEfficiency = 0.95;
		}
		
		part reactionCoil : ReactionCoil {
			attribute :>> coilVolume = 500.0 [SI::uL];
			attribute :>> coilLength = 50.0 [SI::cm];
			attribute :>> residenceTime = 20.0 [SI::s];
		}
		
		part detector : FlowThroughDetector {
			attribute :>> wavelength = 540.0 [SI::nm];
			attribute :>> pathLength = 10.0 [SI::mm];
			attribute :>> sensitivity = 0.001;
			attribute :>> noiseLevel = 0.0005;
		}
		
		part dataSystem : DataAcquisitionSystem {
			attribute :>> samplingRate = 10.0 [SI::Hz];
		}
		
		part wasteCollector : WasteReservoir {
			attribute :>> capacity = 2000.0 [SI::mL];
			attribute :>> currentVolume = 0.0 [SI::mL];
		}
		
		flow carrierFlow of CarrierSolution 
			from carrierPump.fluidOut to injector.carrierIn;
		
		flow reagentFlow of ReagentSolution 
			from reagentPump.fluidOut to mixingTee.stream2In;
		
		flow injectedFlow of MixedStream 
			from injector.streamOut to mixingTee.stream1In;
		
		flow combinedFlow of MixedStream 
			from mixingTee.mixedOut to reactionCoil.streamIn;
		
		flow reactionFlow of ReactionProduct 
			from reactionCoil.streamOut to detector.cellIn;
		
		flow wasteFlow of WasteStream 
			from detector.cellOut to wasteCollector.wasteIn;
		
		connect detector.signalOut to dataSystem.signalIn;
	}
	
	action def PerformFIAAnalysis {
		in sampleID : SampleIdentifier;
		in samplePlug : SamplePlug;
		out measuredConcentration : AmountOfSubstanceConcentrationValue;
		out peakArea : Real;
	}
	
	action fiaAnalysisCycle : PerformFIAAnalysis {
		in sampleID : SampleIdentifier;
		in samplePlug : SamplePlug;
		out measuredConcentration : AmountOfSubstanceConcentrationValue;
		out peakArea : Real;
		
		first start;
		
		then action establishBaseline {
			out carrierFlowing : Boolean;
			out reagentFlowing : Boolean;
			out baselineStable : Boolean;
		}
		
		then action loadSampleLoop {
			in sample : SamplePlug = fiaAnalysisCycle::samplePlug;
			out loopFilled : Boolean;
		}
		
		then action injectSampleIntoCarrier {
			in loopFilled : Boolean;
			out injectionTimestamp : TimeValue;
		}
		
		then action mergeWithReagent {
			in injectionTimestamp : TimeValue;
			out mergedStream : MixedStream;
		}
		
		then action transportThroughCoil {
			in mergedStream : MixedStream;
			out reactionComplete : Boolean;
			out reactionProduct : ReactionProduct;
		}
		
		then action detectInFlowCell {
			in reactionProduct : ReactionProduct;
			out absorbanceSignal : Absorbance;
			out peakHeight : Absorbance;
			out detectionTime : TimeValue;
		}
		
		then action processDetectorSignal {
			in absorbanceSignal : Absorbance;
			in peakHeight : Absorbance;
			out concentration : AmountOfSubstanceConcentrationValue;
			out area : Real;
		}
		
		then action flushToWaste {
			in concentration : AmountOfSubstanceConcentrationValue;
			out systemReady : Boolean;
		}
		
		then done;
		
		return measuredConcentration = processDetectorSignal.concentration;
		return peakArea = processDetectorSignal.area;
	}
	
	requirement def PrimaryFunctionRequirement {
		subject system : FIASystem;
		
		doc /*
		The FIA system shall automatically inject a discrete sample plug into 
		a continuously flowing carrier stream, merge it with reagent, allow 
		controlled dispersion and chemical reaction to occur, and detect the 
		resulting product to determine analyte concentration with minimal 
		sample and reagent consumption.
		*/
		
		require constraint {
			system.injector.loopVolume <= 500.0 [SI::uL]
		}
	}
	
	requirement def AnalysisSpeedRequirement {
		subject system : FIASystem;
		
		doc /*
		The FIA system shall complete one full analysis cycle from sample 
		injection to concentration result within 60 seconds to enable high 
		sample throughput.
		*/
		
		attribute maxCycleTime : TimeValue = 60.0 [SI::s];
		
		require constraint {
			system.analysisTime <= maxCycleTime
		}
	}
	
	requirement def DetectionSensitivityRequirement {
		subject system : FIASystem;
		
		doc /*
		The optical detector shall achieve a minimum detectable absorbance 
		of 0.001 AU to enable quantification of low analyte concentrations.
		*/
		
		attribute minDetectableAbsorbance : Absorbance = 0.001;
		
		require constraint {
			system.detector.sensitivity <= minDetectableAbsorbance
		}
	}
	
	requirement def ReagentConsumptionRequirement {
		subject system : FIASystem;
		
		doc /*
		The FIA system shall minimize reagent consumption to less than 
		1.0 mL per sample analysis to reduce operating costs and waste.
		*/
		
		attribute maxReagentPerSample : VolumeValue = 1.0 [SI::mL];
		
		require constraint {
			system.reagentPump.nominalFlowRate * system.analysisTime <= maxReagentPerSample
		}
	}
	
	requirement def PrecisionRequirement {
		subject system : FIASystem;
		
		doc /*
		The FIA system shall achieve a relative standard deviation (RSD) 
		of less than 2% for replicate measurements of the same sample.
		*/
		
		attribute maxRSD : Real = 0.02;
	}
	
	verification def VerifyAnalysisSpeed {
		subject testSystem : FIASystem;
		
		objective speedObjective {
			verify AnalysisSpeedRequirement;
		}
		
		action prepareTestSample {
			in testSystem : FIASystem = VerifyAnalysisSpeed::testSystem;
			out testSample : SamplePlug;
		}
		
		action runTimedAnalysis {
			in sample : SamplePlug = prepareTestSample.testSample;
			out startTime : TimeValue;
			out endTime : TimeValue;
			out result : AmountOfSubstanceConcentrationValue;
		}
		
		action calculateCycleTime {
			in startTime : TimeValue = runTimedAnalysis.startTime;
			in endTime : TimeValue = runTimedAnalysis.endTime;
			out cycleTime : TimeValue = endTime - startTime;
		}
		
		action evaluateSpeed {
			in cycleTime : TimeValue = calculateCycleTime.cycleTime;
			in maxAllowed : TimeValue = AnalysisSpeedRequirement::maxCycleTime;
			out verdict : VerdictKind = 
				if (cycleTime <= maxAllowed) VerdictKind::pass
				else VerdictKind::fail;
		}
		
		return verdict : VerdictKind = evaluateSpeed.verdict;
	}
	
	verification def VerifyDetectionSensitivity {
		subject testSystem : FIASystem;
		
		objective sensitivityObjective {
			verify DetectionSensitivityRequirement;
		}
		
		action prepareLowConcentrationStandard {
			in testSystem : FIASystem = VerifyDetectionSensitivity::testSystem;
			out lowStandard : SamplePlug;
			out expectedAbsorbance : Absorbance;
		}
		
		action measureLowStandard {
			in sample : SamplePlug = prepareLowConcentrationStandard.lowStandard;
			out measuredAbsorbance : Absorbance;
			out signalToNoise : Real;
		}
		
		action evaluateSensitivity {
			in measured : Absorbance = measureLowStandard.measuredAbsorbance;
			in snr : Real = measureLowStandard.signalToNoise;
			in minRequired : Absorbance = DetectionSensitivityRequirement::minDetectableAbsorbance;
			out verdict : VerdictKind = 
				if (measured >= minRequired && snr >= 3.0) VerdictKind::pass
				else VerdictKind::fail;
		}
		
		return verdict : VerdictKind = evaluateSensitivity.verdict;
	}
	
	verification def VerifyPrecision {
		subject testSystem : FIASystem;
		
		objective precisionObjective {
			verify PrecisionRequirement;
		}
		
		action prepareReplicateSamples {
			in testSystem : FIASystem = VerifyPrecision::testSystem;
			out replicates : SamplePlug[10];
		}
		
		action analyzeReplicates {
			in samples : SamplePlug[10] = prepareReplicateSamples.replicates;
			out concentrations : AmountOfSubstanceConcentrationValue[10];
		}
		
		action calculateStatistics {
			in concentrations : AmountOfSubstanceConcentrationValue[10] = analyzeReplicates.concentrations;
			out meanConcentration : AmountOfSubstanceConcentrationValue;
			out standardDeviation : AmountOfSubstanceConcentrationValue;
			out rsd : Real;
		}
		
		action evaluatePrecision {
			in rsd : Real = calculateStatistics.rsd;
			in maxAllowed : Real = PrecisionRequirement::maxRSD;
			out verdict : VerdictKind = 
				if (rsd <= maxAllowed) VerdictKind::pass
				else VerdictKind::fail;
		}
		
		return verdict : VerdictKind = evaluatePrecision.verdict;
	}
}
