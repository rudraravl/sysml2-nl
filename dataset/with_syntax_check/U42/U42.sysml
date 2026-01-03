package BlindsightSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ConfidenceLevel :> Real {
		doc /* Confidence measure for detection and response, range 0.0 to 1.0 */
	}
	
	attribute def SpatialCoordinate :> ISQ::LengthValue {
		doc /* Position coordinate in 3D space */
	}
	
	attribute def ResponseLatency :> ISQ::TimeValue {
		doc /* Time delay between stimulus and response */
	}
	
	item def VisualStimulus {
		attribute position : SpatialCoordinate[3];
		attribute luminance : ISQ::LuminousIntensityValue;
		attribute wavelength : ISQ::LengthValue;
		attribute timestamp : ISQ::TimeValue;
		attribute fieldLocation : Real;
	}
	
	item def SpatialInformation {
		attribute objectLocation : SpatialCoordinate[3];
		attribute objectSize : ISQ::LengthValue;
		attribute motionVector : ISQ::SpeedValue[3];
		attribute processingConfidence : ConfidenceLevel;
	}
	
	item def MotorCommand {
		attribute targetPosition : SpatialCoordinate[3];
		attribute movementType : MovementType;
		attribute executionConfidence : ConfidenceLevel;
		attribute urgency : Real;
	}
	
	item def ConsciousPercept {
		attribute awarenessPresent : Boolean;
		attribute reportedVisibility : Real;
		attribute subjectiveConfidence : ConfidenceLevel;
	}
	
	enum def MovementType {
		enum reach;
		enum grasp;
		enum point;
		enum avoid;
		enum track;
	}
	
	enum def PathwayState {
		enum functional;
		enum impaired;
		enum severed;
	}
	
	port def VisualInputPort {
		in item stimulus : VisualStimulus;
	}
	
	port def NeuralSignalPort {
		out item signal : VisualStimulus;
	}
	
	port def SpatialDataPort {
		out item spatialData : SpatialInformation;
	}
	
	port def MotorCommandPort {
		out item command : MotorCommand;
	}
	
	port def ConsciousOutputPort {
		out item percept : ConsciousPercept;
	}
	
	part def Retina {
		doc /* Light-sensitive neural tissue that captures visual input */
		
		port visualInput : VisualInputPort;
		port retinaOutput : NeuralSignalPort;
		
		attribute photoreceptorCount : Real;
		attribute sensitivity : ISQ::LuminousIntensityValue;
		
		perform action captureStimulus {
			in externalStimulus : VisualStimulus;
			out neuralSignal : VisualStimulus;
			
			first start;
			then action transduce {
				in lightInput : VisualStimulus = externalStimulus;
				out transducedSignal : VisualStimulus;
			}
			then assign neuralSignal := transduce.transducedSignal;
			then done;
		}
	}
	
	part def PrimaryVisualCortex {
		doc /* V1 cortex - initial cortical processing of visual information */
		
		port corticalInput : VisualInputPort;
		port ventralOutput : NeuralSignalPort;
		port dorsalOutput : NeuralSignalPort;
		
		attribute processingDelay : ResponseLatency;
		attribute corticalIntegrity : Real;
		
		perform action processVisualSignal {
			in rawSignal : VisualStimulus;
			out ventralSignal : VisualStimulus;
			out dorsalSignal : VisualStimulus;
			
			first start;
			then action analyzeFeatures {
				in signal : VisualStimulus = rawSignal;
				out analyzedSignal : VisualStimulus;
			}
			then assign ventralSignal := analyzeFeatures.analyzedSignal;
			then assign dorsalSignal := analyzeFeatures.analyzedSignal;
			then done;
		}
	}
	
	part def VentralStream {
		doc /* Conscious perception pathway - object recognition and identification */
		
		port ventralInput : VisualInputPort;
		port consciousOutput : ConsciousOutputPort;
		
		attribute pathwayStatus : PathwayState;
		attribute lesionSeverity : Real;
		
		state ventralProcessing {
			entry; then checkIntegrity;
			
			state checkIntegrity;
			
			if pathwayStatus == PathwayState::functional then normalPerception;
			if pathwayStatus == PathwayState::impaired then degradedPerception;
			if pathwayStatus == PathwayState::severed then noPerception;
			
			state normalPerception {
				doc /* Full conscious visual awareness */
				entry assign consciousOutput.percept.awarenessPresent := true;
			}
			
			state degradedPerception {
				doc /* Partial conscious awareness */
				entry assign consciousOutput.percept.awarenessPresent := true;
				entry assign consciousOutput.percept.reportedVisibility := 0.5;
			}
			
			state noPerception {
				doc /* No conscious awareness - blindsight condition */
				entry assign consciousOutput.percept.awarenessPresent := false;
				entry assign consciousOutput.percept.reportedVisibility := 0.0;
				entry assign consciousOutput.percept.subjectiveConfidence := 0.0;
			}
		}
	}
	
	part def DorsalStream {
		doc /* Unconscious visuomotor pathway - spatial processing and action guidance */
		
		port dorsalInput : VisualInputPort;
		port spatialOutput : SpatialDataPort;
		
		attribute pathwayStatus : PathwayState;
		attribute spatialAccuracy : ConfidenceLevel;
		
		perform action extractSpatialProperties {
			in visualInput : VisualStimulus;
			out spatialInfo : SpatialInformation;
			
			first start;
			then action computeLocation {
				in stimulus : VisualStimulus = visualInput;
				out location : SpatialCoordinate[3];
			}
			then action computeMotion {
				in stimulus : VisualStimulus = visualInput;
				out motion : ISQ::SpeedValue[3];
			}
			then action assembleSpatialData {
				in loc : SpatialCoordinate[3] = computeLocation.location;
				in mot : ISQ::SpeedValue[3] = computeMotion.motion;
				out data : SpatialInformation;
			}
			then assign spatialInfo := assembleSpatialData.data;
			then done;
		}
	}
	
	part def SuperiorColliculus {
		doc /* Subcortical structure for rapid visuomotor reflexes */
		
		port subcorticalInput : VisualInputPort;
		port reflexOutput : SpatialDataPort;
		
		attribute reflexLatency : ResponseLatency;
		attribute subcorticalIntegrity : Boolean;
		
		perform action generateReflexResponse {
			in stimulus : VisualStimulus;
			out reflexData : SpatialInformation;
			
			first start;
			then action detectSalient {
				in input : VisualStimulus = stimulus;
				out salientFeatures : VisualStimulus;
			}
			then action computeReflexTarget {
				in features : VisualStimulus = detectSalient.salientFeatures;
				out targetInfo : SpatialInformation;
			}
			then assign reflexData := computeReflexTarget.targetInfo;
			then done;
		}
	}
	
	part def MotorCortex {
		doc /* Motor planning and execution system */
		
		port dorsalSpatialInput : SpatialDataPort;
		port colliculusSpatialInput : SpatialDataPort;
		port motorOutput : MotorCommandPort;
		
		attribute motorReadiness : Real;
		
		perform action planMotorResponse {
			in dorsalData : SpatialInformation;
			in colliculusData : SpatialInformation;
			out motorCmd : MotorCommand;
			
			first start;
			then action integrateSpatialInputs {
				in dorsal : SpatialInformation = dorsalData;
				in colliculus : SpatialInformation = colliculusData;
				out integratedSpatial : SpatialInformation;
			}
			then action selectMovementType {
				in spatial : SpatialInformation = integrateSpatialInputs.integratedSpatial;
				out movement : MovementType;
			}
			then action generateCommand {
				in spatial : SpatialInformation = integrateSpatialInputs.integratedSpatial;
				in moveType : MovementType = selectMovementType.movement;
				out command : MotorCommand;
			}
			then assign motorCmd := generateCommand.command;
			then done;
		}
	}
	
	part def BlindsightSubject {
		doc /* Individual exhibiting blindsight phenomenon with V1 lesion */
		
		part leftRetina : Retina {
			attribute :>> photoreceptorCount = 120000000.0;
			attribute :>> sensitivity = 0.001 [cd];
		}
		
		part rightRetina : Retina {
			attribute :>> photoreceptorCount = 120000000.0;
			attribute :>> sensitivity = 0.001 [cd];
		}
		
		part v1 : PrimaryVisualCortex {
			attribute :>> processingDelay = 0.05 [s];
			attribute :>> corticalIntegrity = 0.3;
		}
		
		part ventral : VentralStream {
			attribute :>> pathwayStatus = PathwayState::severed;
			attribute :>> lesionSeverity = 0.9;
		}
		
		part dorsal : DorsalStream {
			attribute :>> pathwayStatus = PathwayState::functional;
			attribute :>> spatialAccuracy = 0.85;
		}
		
		part colliculus : SuperiorColliculus {
			attribute :>> reflexLatency = 0.03 [s];
			attribute :>> subcorticalIntegrity = true;
		}
		
		part motor : MotorCortex {
			attribute :>> motorReadiness = 0.95;
		}
		
		connection retinaToV1Left connect leftRetina.retinaOutput to v1.corticalInput;
		connection retinaToV1Right connect rightRetina.retinaOutput to v1.corticalInput;
		connection v1ToVentral connect v1.ventralOutput to ventral.ventralInput;
		connection v1ToDorsal connect v1.dorsalOutput to dorsal.dorsalInput;
		connection retinaToColliculusLeft connect leftRetina.retinaOutput to colliculus.subcorticalInput;
		connection retinaToColliculusRight connect rightRetina.retinaOutput to colliculus.subcorticalInput;
		connection dorsalToMotor connect dorsal.spatialOutput to motor.dorsalSpatialInput;
		connection colliculusToMotor connect colliculus.reflexOutput to motor.colliculusSpatialInput;
		
		perform action demonstrateBlindsight : BlindsightBehavior;
	}
	
	action def BlindsightBehavior {
		doc /* Demonstrates unconscious visual guidance without conscious awareness */
		
		in presentedStimulus : VisualStimulus;
		out motorAction : MotorCommand;
		out consciousReport : ConsciousPercept;
		
		first start;
		
		then action receiveStimulus {
			in stimulus : VisualStimulus = presentedStimulus;
			out receivedStimulus : VisualStimulus;
		}
		
		then action consciousPathway {
			doc /* Damaged ventral stream produces no conscious awareness */
			in stimulus : VisualStimulus = receiveStimulus.receivedStimulus;
			out awareness : ConsciousPercept;
			
			action processConsciously {
				in input : VisualStimulus = stimulus;
				out percept : ConsciousPercept;
			}
			then assign awareness := processConsciously.percept;
		}
		
		then action unconsciousPathway {
			doc /* Intact dorsal and subcortical pathways enable accurate motor responses */
			in stimulus : VisualStimulus = receiveStimulus.receivedStimulus;
			out visuomotorResponse : MotorCommand;
			
			first action dorsalProcessing {
				in input : VisualStimulus = stimulus;
				out dorsalSpatial : SpatialInformation;
			}
			
			then action subcorticalProcessing {
				in input : VisualStimulus = stimulus;
				out colliculusSpatial : SpatialInformation;
			}
			
			then action motorPlanning {
				in dorsalData : SpatialInformation = dorsalProcessing.dorsalSpatial;
				in colliculusData : SpatialInformation = subcorticalProcessing.colliculusSpatial;
				out plannedMotor : MotorCommand;
			}
			
			then assign visuomotorResponse := motorPlanning.plannedMotor;
		}
		
		then action produceOutput {
			in unconsciousMotor : MotorCommand = unconsciousPathway.visuomotorResponse;
			in consciousAwareness : ConsciousPercept = consciousPathway.awareness;
		}
		
		then assign motorAction := produceOutput.unconsciousMotor;
		then assign consciousReport := produceOutput.consciousAwareness;
		
		then done;
	}
	
	requirement def BlindsightSystemRequirement {
		doc /* 
			The blindsight system shall demonstrate accurate visuomotor responses 
			to visual stimuli despite complete absence of conscious visual awareness,
			revealing dissociation between conscious perception and unconscious 
			visual processing capabilities.
		*/
		
		subject system : BlindsightSubject;
		
		require constraint ventralPathwayDamaged {
			doc /* Ventral stream must be non-functional to eliminate conscious awareness */
			system.ventral.pathwayStatus == PathwayState::severed
		}
		
		require constraint dorsalPathwayIntact {
			doc /* Dorsal stream must remain functional for visuomotor guidance */
			system.dorsal.pathwayStatus == PathwayState::functional
		}
		
		require constraint subcorticalPathwayIntact {
			doc /* Subcortical pathways must remain functional for rapid responses */
			system.colliculus.subcorticalIntegrity == true
		}
		
		require constraint noConsciousAwareness {
			doc /* Subject must report no conscious visual perception */
			system.ventral.consciousOutput.percept.awarenessPresent == false and
			system.ventral.consciousOutput.percept.reportedVisibility == 0.0
		}
		
		require constraint accurateMotorResponse {
			doc /* Motor responses must demonstrate spatial accuracy above chance */
			system.dorsal.spatialAccuracy > 0.5
		}
	}
	
	requirement <'BS-REQ-1'> primaryBlindsightFunction : BlindsightSystemRequirement {
		doc /* 
			Primary Function: The blindsight system demonstrates the fundamental 
			dissociation between conscious visual perception and unconscious 
			visuomotor processing. Despite complete loss of conscious awareness 
			due to primary visual cortex damage affecting the ventral stream, 
			the system maintains accurate spatial localization and motor guidance 
			through preserved dorsal stream and subcortical pathways. This reveals 
			that visual information can guide behavior without entering conscious 
			awareness, challenging traditional models of vision as a unified 
			conscious experience and demonstrating multiple parallel visual 
			processing systems with distinct functional roles.
		*/
		
		subject blindsightSystem : BlindsightSubject;
		
		assume constraint v1Lesion {
			doc /* Primary visual cortex damage affecting conscious pathway */
			blindsightSystem.v1.corticalIntegrity < 0.5 and
			blindsightSystem.ventral.pathwayStatus == PathwayState::severed
		}
		
		assume constraint alternativePathwaysPreserved {
			doc /* Dorsal and subcortical pathways remain functional */
			blindsightSystem.dorsal.pathwayStatus == PathwayState::functional and
			blindsightSystem.colliculus.subcorticalIntegrity == true
		}
		
		require constraint functionalDissociation {
			doc /* Conscious and unconscious processing must be dissociated */
			blindsightSystem.ventral.consciousOutput.percept.awarenessPresent == false and
			blindsightSystem.dorsal.spatialAccuracy > 0.7 and
			blindsightSystem.motor.motorReadiness > 0.8
		}
		
		require constraint responseLatencyMaintained {
			doc /* Unconscious responses must occur within normal latency range */
			blindsightSystem.colliculus.reflexLatency < 0.1 [s]
		}
	}
	
	part blindsightPatient : BlindsightSubject {
		satisfy primaryBlindsightFunction by blindsightPatient;
	}
}
