package PhaseUnwrappingSystem {
	private import ScalarValues::*;
	
	attribute def PhaseAngle :> Real {
		doc
		/*
		 * Phase angle in degrees, typically between -180 and 180 for wrapped measurements.
		 */
	}
	
	attribute def QualityValue :> Real {
		doc
		/*
		 * Reliability value between 0.0 and 1.0 indicating pixel coherence.
		 */
		constraint { self >= 0.0 and self <= 1.0 }
	}
	
	item def WrappedPhaseMap {
		attribute width : Integer;
		attribute height : Integer;
		attribute pixels : PhaseAngle[0..*];
	}
	
	item def QualityMap {
		attribute width : Integer;
		attribute height : Integer;
		attribute reliability : QualityValue[0..*];
	}
	
	item def UnwrappedPhaseMap {
		attribute width : Integer;
		attribute height : Integer;
		attribute pixels : PhaseAngle[0..*];
	}
	
	item def ValidationResult {
		attribute meanResidualError : Real;
		attribute maxResidualError : Real;
		attribute isValid : Boolean;
	}
	
	part def PhaseAcquisitionModule {
		in port sensorInput : WrappedPhaseMap;
		out port wrappedPhaseOut : WrappedPhaseMap;
	}
	
	part def QualityAssessmentModule {
		in port wrappedPhaseIn : WrappedPhaseMap;
		out port qualityMapOut : QualityMap;
	}
	
	part def UnwrappingProcessorModule {
		in port wrappedPhaseIn : WrappedPhaseMap;
		in port qualityMapIn : QualityMap;
		out port unwrappedPhaseOut : UnwrappedPhaseMap;
	}
	
	part def ValidationModule {
		in port wrappedPhaseIn : WrappedPhaseMap;
		in port unwrappedPhaseIn : UnwrappedPhaseMap;
		out port validationResultOut : ValidationResult;
	}
	
	part def PhaseUnwrappingSystem {
		in port systemInput : WrappedPhaseMap;
		out port systemOutput : ValidationResult;
		
		part acquisition : PhaseAcquisitionModule {
			in port sensorInput = PhaseUnwrappingSystem::systemInput;
		}
		
		part assessment : QualityAssessmentModule;
		part processor : UnwrappingProcessorModule;
		
		part validation : ValidationModule {
			out port validationResultOut = PhaseUnwrappingSystem::systemOutput;
		}
		
		flow from acquisition.wrappedPhaseOut to assessment.wrappedPhaseIn;
		flow from acquisition.wrappedPhaseOut to processor.wrappedPhaseIn;
		flow from assessment.qualityMapOut to processor.qualityMapIn;
		flow from processor.unwrappedPhaseOut to validation.unwrappedPhaseIn;
		flow from acquisition.wrappedPhaseOut to validation.wrappedPhaseIn;
	}
	
	action def AcquirePhase {
		in sensorData : WrappedPhaseMap;
		out wrappedPhase : WrappedPhaseMap;
	}
	
	action def AssessQuality {
		in wrappedPhase : WrappedPhaseMap;
		out qualityMap : QualityMap;
	}
	
	action def UnwrapPhase {
		in wrappedPhase : WrappedPhaseMap;
		in qualityMap : QualityMap;
		out unwrappedPhase : UnwrappedPhaseMap;
	}
	
	action def ValidateResult {
		in wrappedPhase : WrappedPhaseMap;
		in unwrappedPhase : UnwrappedPhaseMap;
		out validationResult : ValidationResult;
	}
	
	action def ProcessPhaseData {
		in sensorData : WrappedPhaseMap;
		out validationResult : ValidationResult;
		
		action acquire : AcquirePhase {
			in sensorData = ProcessPhaseData::sensorData;
			out wrappedPhase;
		}
		action assess : AssessQuality {
			in wrappedPhase;
			out qualityMap;
		}
		action unwrap : UnwrapPhase {
			in wrappedPhase;
			in qualityMap;
			out unwrappedPhase;
		}
		action validate : ValidateResult {
			in wrappedPhase;
			in unwrappedPhase;
			out validationResult = ProcessPhaseData::validationResult;
		}
		
		flow from acquire.wrappedPhase to assess.wrappedPhase;
		flow from acquire.wrappedPhase to unwrap.wrappedPhase;
		flow from acquire.wrappedPhase to validate.wrappedPhase;
		flow from assess.qualityMap to unwrap.qualityMap;
		flow from unwrap.unwrappedPhase to validate.unwrappedPhase;
		
		first start;
		then acquire;
		then assess;
		then unwrap;
		then validate;
		then done;
	}
	
	attribute def StartProcessing;
	attribute def AcquireComplete;
	attribute def AssessComplete;
	attribute def UnwrapComplete;
	attribute def ValidateComplete;
	attribute def ValidationFailed;
	attribute def Reset;
	
	state def PhaseUnwrappingState {
		state idle;
		state acquiring;
		state assessing;
		state unwrapping;
		state validating;
		state complete;
		state faultState;
		
		transition from idle to acquiring accept StartProcessing;
		transition from acquiring to assessing accept AcquireComplete;
		transition from assessing to unwrapping accept AssessComplete;
		transition from unwrapping to validating accept UnwrapComplete;
		transition from validating to complete accept ValidateComplete;
		transition from validating to faultState accept ValidationFailed;
		transition from faultState to idle accept Reset;
	}
	
	requirement def PhaseUnwrappingRequirement {
		doc
		/*
		 * The system shall reconstruct continuous phase data from inherently cyclical or wrapped measurements.
		 */
	}
	
	requirement def QualityGuidedRequirement :> PhaseUnwrappingRequirement {
		doc
		/*
		 * The unwrapping processor shall use a quality map to guide the phase unwrapping process,
		 * starting from the most reliable seed points and propagating outwards.
		 */
	}
	
	requirement def ValidationRequirement :> PhaseUnwrappingRequirement {
		doc
		/*
		 * The validation module shall compare the unwrapped phase map against the original wrapped phase map
		 * and calculate a residual error.
		 */
	}
	
	part system : PhaseUnwrappingSystem {
		action processPhaseData : ProcessPhaseData;
		behavior pipelineState : PhaseUnwrappingState;
	}
	
	requirement phaseUnwrappingReq : PhaseUnwrappingRequirement;
	requirement qualityGuidedReq : QualityGuidedRequirement;
	requirement validationReq : ValidationRequirement;
	
	satisfy phaseUnwrappingReq by system;
	satisfy qualityGuidedReq by system.processor;
	satisfy validationReq by system.validation;
}
