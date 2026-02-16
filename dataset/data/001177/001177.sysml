package 'Phase Unwrapping System' {
	private import ISQ::*;
	private import ScalarValues::*;
	
	attribute def PhaseAngle :> Real;
	attribute def WrappedPhase :> PhaseAngle;
	attribute def UnwrappedPhase :> PhaseAngle;
	attribute def QualityMetric :> Real;
	attribute def PixelCoordinate :> Integer;
	attribute def ProcessingCommand;
	attribute def CompletionStatus;
	
	item def WrappedPhaseMap {
		attribute phaseData : WrappedPhase[*] ordered;
		attribute width : Integer;
		attribute height : Integer;
		attribute qualityMap : QualityMetric[*] ordered;
	}
	
	item def UnwrappedPhaseMap {
		attribute phaseData : UnwrappedPhase[*] ordered;
		attribute width : Integer;
		attribute height : Integer;
		attribute residualError : Real;
	}
	
	port def WrappedPhaseInput {
		in wrappedMap : WrappedPhaseMap;
	}
	
	port def UnwrappedPhaseOutput {
		out unwrappedMap : UnwrappedPhaseMap;
	}
	
	port def QualityInput {
		in qualityData : QualityMetric[*] ordered;
	}
	
	action def AnalyzePhaseQuality {
		in wrappedPhase : WrappedPhase[*] ordered;
		in width : Integer;
		in height : Integer;
		out qualityMap : QualityMetric[*] ordered;
		out reliablePixels : PixelCoordinate[*] ordered;
	}
	
	action def ComputePhaseGradients {
		in wrappedPhase : WrappedPhase[*] ordered;
		in width : Integer;
		in height : Integer;
		out gradientX : PhaseAngle[*] ordered;
		out gradientY : PhaseAngle[*] ordered;
	}
	
	action def IdentifySeedPoints {
		in qualityMap : QualityMetric[*] ordered;
		in qualityThreshold : Real;
		out seedPixels : PixelCoordinate[*] ordered;
	}
	
	action def PropagatePhaseUnwrapping {
		in wrappedPhase : WrappedPhase[*] ordered;
		in seedPixels : PixelCoordinate[*] ordered;
		in width : Integer;
		in height : Integer;
		out unwrappedPhase : UnwrappedPhase[*] ordered;
	}
	
	action def CorrectPhaseJumps {
		in wrappedValue : WrappedPhase;
		in referenceValue : UnwrappedPhase;
		out correctedValue : UnwrappedPhase;
	}
	
	action def ValidateUnwrappedPhase {
		in unwrappedPhase : UnwrappedPhase[*] ordered;
		in wrappedPhase : WrappedPhase[*] ordered;
		out isValid : Boolean;
		out residualError : Real;
	}
	
	action def PerformPhaseUnwrapping {
		in inputMap : WrappedPhaseMap;
		out outputMap : UnwrappedPhaseMap;
		
		first start;
		
		then action analyzeQuality : AnalyzePhaseQuality {
			in wrappedPhase = inputMap.phaseData;
			in width = inputMap.width;
			in height = inputMap.height;
			out qualityMap;
			out reliablePixels;
		}
		
		then action computeGradients : ComputePhaseGradients {
			in wrappedPhase = inputMap.phaseData;
			in width = inputMap.width;
			in height = inputMap.height;
			out gradientX;
			out gradientY;
		}
		
		then action identifySeeds : IdentifySeedPoints {
			in qualityMap = analyzeQuality.qualityMap;
			in qualityThreshold = 0.75;
			out seedPixels;
		}
		
		then action propagate : PropagatePhaseUnwrapping {
			in wrappedPhase = inputMap.phaseData;
			in seedPixels = identifySeeds.seedPixels;
			in width = inputMap.width;
			in height = inputMap.height;
			out unwrappedPhase;
		}
		
		then action validate : ValidateUnwrappedPhase {
			in unwrappedPhase = propagate.unwrappedPhase;
			in wrappedPhase = inputMap.phaseData;
			out isValid;
			out residualError;
		}
		
		then action buildOutput {
			private attribute resultMap : UnwrappedPhaseMap {
				attribute phaseData = propagate.unwrappedPhase;
				attribute width = inputMap.width;
				attribute height = inputMap.height;
				attribute residualError = validate.residualError;
			}
		}
		
		then assign outputMap := buildOutput.resultMap;
		
		then done;
	}
	
	part def PhaseAcquisitionModule {
		out port wrappedOutput : WrappedPhaseInput;
		
		perform action acquirePhase {
			out wrappedMap : WrappedPhaseMap;
		}
	}
	
	part def QualityAssessmentModule {
		in port wrappedInput : WrappedPhaseInput;
		out port qualityOutput : QualityInput;
		
		perform action assessQuality : AnalyzePhaseQuality;
	}
	
	part def UnwrappingProcessorModule {
		in port wrappedInput : WrappedPhaseInput;
		in port qualityInput : QualityInput;
		out port unwrappedOutput : UnwrappedPhaseOutput;
		
		attribute maxIterations : Integer;
		attribute convergenceThreshold : Real;
		
		perform action processUnwrapping : PropagatePhaseUnwrapping;
	}
	
	part def ValidationModule {
		in port unwrappedInput : UnwrappedPhaseOutput;
		in port wrappedReference : WrappedPhaseInput;
		
		perform action validateResults : ValidateUnwrappedPhase;
	}
	
	part phaseUnwrappingSystem {
		doc /*
		This system performs phase unwrapping to reconstruct continuous phase 
		distributions from wrapped phase measurements. The primary function is 
		to remove 2π discontinuities inherent in interferometric or modulo 
		measurements, producing a spatially continuous phase map that represents 
		the true underlying physical quantity.
		*/
		
		part acquisitionModule : PhaseAcquisitionModule;
		
		part qualityModule : QualityAssessmentModule {
			perform phaseUnwrappingSystem.mainUnwrapping.analyzeQuality;
		}
		
		part processorModule : UnwrappingProcessorModule {
			attribute maxIterations = 500;
			attribute convergenceThreshold = 0.001;
			perform phaseUnwrappingSystem.mainUnwrapping.propagate;
		}
		
		part validationModule : ValidationModule {
			perform phaseUnwrappingSystem.mainUnwrapping.validate;
		}
		
		connect acquisitionModule.wrappedOutput to qualityModule.wrappedInput;
		connect acquisitionModule.wrappedOutput to processorModule.wrappedInput;
		connect qualityModule.qualityOutput to processorModule.qualityInput;
		connect processorModule.unwrappedOutput to validationModule.unwrappedInput;
		connect acquisitionModule.wrappedOutput to validationModule.wrappedReference;
		
		perform action mainUnwrapping : PerformPhaseUnwrapping {
			in inputMap : WrappedPhaseMap;
			out outputMap : UnwrappedPhaseMap;
		}
	}
	
	requirement def PhaseContinuityRequirement {
		doc /*
		The unwrapped phase shall be spatially continuous with no artificial 
		discontinuities exceeding π radians between adjacent pixels.
		*/
	}
	
	requirement def UnwrappingAccuracyRequirement {
		doc /*
		The residual error between rewrapped unwrapped phase and original 
		wrapped phase shall not exceed 0.05 radians RMS.
		*/
	}
	
	requirement def ProcessingPerformanceRequirement {
		doc /*
		The system shall process a 1024x1024 pixel phase map within 10 seconds 
		on standard computing hardware.
		*/
	}
	
	requirement def QualityGuidedRequirement {
		doc /*
		The unwrapping algorithm shall prioritize propagation from high-quality 
		regions to low-quality regions based on quality metrics.
		*/
	}
	
	requirement systemRequirements {
		subject phaseUnwrappingSystem;
		
		doc /*
		The phase unwrapping system shall convert wrapped phase measurements 
		into continuous unwrapped phase distributions while maintaining accuracy 
		and spatial continuity.
		*/
		
		require phaseContinuityReq : PhaseContinuityRequirement;
		require unwrappingAccuracyReq : UnwrappingAccuracyRequirement;
		require processingPerformanceReq : ProcessingPerformanceRequirement;
		require qualityGuidedReq : QualityGuidedRequirement;
		
		assume constraint validInputRange {
			doc /*
			Input wrapped phase values shall be within the range [-π, π] radians.
			*/
		}
		
		assume constraint sufficientQuality {
			doc /*
			At least 10% of pixels shall have quality metric above 0.75 to serve 
			as reliable seed points.
			*/
		}
	}
}
