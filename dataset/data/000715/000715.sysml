package OphthalmoscopySystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RetinaRegion;
	attribute def VesselPattern;
	
	item def LightBeam {
		attribute wavelength : ISQ::LengthValue;
		attribute intensity : ISQ::LuminousIntensityValue;
		attribute beamDiameter : ISQ::LengthValue;
	}
	
	item def RetinaImage {
		attribute clarity : Real;
		attribute magnification : Real;
		attribute region : RetinaRegion;
		attribute vesselVisibility : Real;
	}
	
	item def DiagnosticFindings {
		attribute normalRetina : Boolean;
		attribute abnormalitiesDetected : Boolean;
		attribute vesselCondition : String;
		attribute opticDiscAppearance : String;
	}
	
	attribute def IlluminationIntensity :> ISQ::LuminousIntensityValue;
	attribute def FocalLength :> ISQ::LengthValue;
	attribute def PupilDiameter :> ISQ::LengthValue;
	
	port def OpticalInputPort {
		in item incomingLight : LightBeam;
	}
	
	port def OpticalOutputPort {
		out item outgoingLight : LightBeam;
	}
	
	port def ImageOutputPort {
		out item visualImage : RetinaImage;
	}
	
	port def PowerInputPort {
		in voltage : ISQ::ElectricPotentialValue;
		in current : ISQ::ElectricCurrentValue;
	}
	
	part def IlluminationSource {
		attribute nominalIntensity : IlluminationIntensity;
		attribute operatingVoltage : ISQ::ElectricPotentialValue;
		port powerIn : PowerInputPort;
		port lightOut : OpticalOutputPort;
		
		action def GenerateIllumination {
			in powerLevel : ISQ::ElectricPotentialValue;
			out beam : LightBeam;
		}
	}
	
	part def CondensingLens {
		attribute focalLength : FocalLength;
		port opticalIn : OpticalInputPort;
		port opticalOut : OpticalOutputPort;
		
		action def CondenseLight {
			in inputBeam : LightBeam;
			out condensedBeam : LightBeam;
		}
	}
	
	part def ReflectingMirror {
		attribute reflectivity : Real;
		attribute apertureDiameter : ISQ::LengthValue;
		port opticalIn : OpticalInputPort;
		port opticalOut : OpticalOutputPort;
		
		action def ReflectBeam {
			in incidentBeam : LightBeam;
			out reflectedBeam : LightBeam;
		}
	}
	
	part def ObjectiveLens {
		attribute magnificationPower : Real;
		attribute workingDistance : ISQ::LengthValue;
		port opticalIn : OpticalInputPort;
		port opticalOut : OpticalOutputPort;
		
		action def FocusOnRetina {
			in lightBeam : LightBeam;
			in focusAdjustment : FocalLength;
			out focusedBeam : LightBeam;
		}
	}
	
	part def ViewingOptics {
		attribute eyepieceMagnification : Real;
		port opticalIn : OpticalInputPort;
		port imageOut : ImageOutputPort;
		
		action def FormImage {
			in reflectedLight : LightBeam;
			out retinaImage : RetinaImage;
		}
	}
	
	part def PatientEye {
		attribute pupilDiameter : PupilDiameter;
		attribute retinaCondition : String;
		port pupilInterface : OpticalInputPort;
		port reflectionOutput : OpticalOutputPort;
		
		action def ReflectFromRetina {
			in illuminatingBeam : LightBeam;
			out reflectedBeam : LightBeam;
		}
	}
	
	part def PowerSupply {
		attribute batteryCapacity : ISQ::ElectricChargeValue;
		attribute outputVoltage : ISQ::ElectricPotentialValue;
		port powerOut : PowerInputPort;
	}
	
	part def OphthalmoscopeDevice {
		part powerSupply : PowerSupply {
			attribute batteryCapacity = 2500.0 [SI::mA];
			attribute outputVoltage = 3.6 [SI::V];
		}
		part illumination : IlluminationSource {
			attribute nominalIntensity = 120.0 [SI::cd];
			attribute operatingVoltage = 3.6 [SI::V];
		}
		part condenser : CondensingLens {
			attribute focalLength = 25.0 [SI::mm];
		}
		part mirror : ReflectingMirror {
			attribute reflectivity = 0.95;
			attribute apertureDiameter = 12.0 [SI::mm];
		}
		part objectiveLens : ObjectiveLens {
			attribute magnificationPower = 15.0;
			attribute workingDistance = 25.0 [SI::mm];
		}
		part viewing : ViewingOptics {
			attribute eyepieceMagnification = 10.0;
		}
		
		connection powerConnection connect powerSupply.powerOut to illumination.powerIn;
		connection illuminationPath connect illumination.lightOut to condenser.opticalIn;
		connection condensedPath connect condenser.opticalOut to mirror.opticalIn;
		connection reflectedPath connect mirror.opticalOut to objectiveLens.opticalIn;
		
		perform action conductExamination[*] ordered;
	}
	
	action def PrepareExamination {
		in pupilDilated : Boolean;
		in roomDarkened : Boolean;
		out examinationReady : Boolean;
	}
	
	action def ActivateIllumination {
		in intensityLevel : IlluminationIntensity;
		out illuminationActive : Boolean;
	}
	
	action def DirectLightToRetina {
		in lightBeam : LightBeam;
		in alignmentAngle : Real;
		out retinaIlluminated : Boolean;
	}
	
	action def AdjustFocus {
		in currentClarity : Real;
		in focusDirection : Real;
		out optimalFocus : FocalLength;
	}
	
	action def ObserveRetinaStructures {
		in retinaImage : RetinaImage;
		out observations : DiagnosticFindings;
	}
	
	action def DocumentFindings {
		in diagnosticData : DiagnosticFindings;
		out clinicalRecord : String;
	}
	
	action def OphthalmoscopyProcedure {
		first start;
		then action prepare : PrepareExamination {
			in pupilDilated = true;
			in roomDarkened = true;
			out examinationReady;
		}
		then action activate : ActivateIllumination {
			in intensityLevel = 100.0 [SI::cd];
			out illuminationActive;
		}
		then merge continuousViewing;
		then action direct : DirectLightToRetina {
			in lightBeam;
			in alignmentAngle = 0.0;
			out retinaIlluminated;
		}
		then action focus : AdjustFocus {
			in currentClarity;
			in focusDirection;
			out optimalFocus;
		}
		then action observe : ObserveRetinaStructures {
			in retinaImage;
			out observations;
		}
		then decide;
			if observe.observations.normalRetina then document;
			if not observe.observations.normalRetina then continuousViewing;
		action document : DocumentFindings {
			in diagnosticData = observe.observations;
			out clinicalRecord;
		}
		then done;
	}
	
	state def OphthalmoscopeStates {
		entry; then off;
		
		state off {
			entry assign devicePowered = false;
		}
		
		transition powerOn
			first off
			accept PowerOnEvent
			then standby;
		
		state standby {
			entry assign devicePowered = true;
			entry assign illuminationOn = false;
		}
		
		transition beginExam
			first standby
			accept StartExaminationEvent
			then examining;
		
		state examining {
			entry assign illuminationOn = true;
			
			state aligning {
				entry assign alignmentComplete = false;
			}
			
			state focusing {
				do action adjustFocusAction : AdjustFocus;
			}
			
			state observing {
				do action observeAction : ObserveRetinaStructures;
			}
			
			transition align_to_focus
				first aligning
				if alignmentComplete
				then focusing;
			
			transition focus_to_observe
				first focusing
				if focusAchieved
				then observing;
		}
		
		transition endExam
			first examining
			accept ExaminationCompleteEvent
			then standby;
		
		transition powerOff
			first standby
			accept PowerOffEvent
			then off;
	}
	
	part ophthalmoscopeSystem : OphthalmoscopeDevice {
		attribute devicePowered : Boolean;
		attribute illuminationOn : Boolean;
		attribute alignmentComplete : Boolean;
		attribute focusAchieved : Boolean;
		
		exhibit state operatingStates : OphthalmoscopeStates;
		
		perform action conductExamination : OphthalmoscopyProcedure;
	}
	
	requirement def <'REQ-OPHT-001'> PrimaryFunctionRequirement {
		doc /* The ophthalmoscopy system shall enable direct visualization of 
		       the interior structures of the eye, including the retina, optic 
		       disc, macula, and retinal blood vessels, by projecting a focused 
		       beam of light through the pupil and collecting the reflected light 
		       for observation by a clinician. */
		
		subject ophthalmoscopeSystem : OphthalmoscopeDevice;
		
		require constraint {
			ophthalmoscopeSystem.illumination.nominalIntensity >= 80.0 [SI::cd] and
			ophthalmoscopeSystem.illumination.nominalIntensity <= 150.0 [SI::cd]
		}
	}
	
	requirement def <'REQ-OPHT-002'> OpticalPerformanceRequirement {
		doc /* The optical system shall provide sufficient magnification and 
		       clarity to resolve retinal blood vessels and detect pathological 
		       changes in retinal structures. */
		
		require constraint {
			ophthalmoscopeSystem.objectiveLens.magnificationPower >= 10.0 and
			ophthalmoscopeSystem.viewing.eyepieceMagnification >= 5.0
		}
	}
	
	requirement def <'REQ-OPHT-003'> IlluminationSafetyRequirement {
		doc /* The illumination intensity shall not exceed safe exposure limits 
		       for ocular tissue to prevent photochemical or thermal damage to 
		       the patient's retina during examination. */
		
		require constraint {
			ophthalmoscopeSystem.illumination.nominalIntensity <= 150.0 [SI::cd]
		}
	}
	
	requirement def <'REQ-OPHT-004'> WorkingDistanceRequirement {
		doc /* The objective lens shall maintain an appropriate working distance 
		       to allow comfortable examination while providing adequate 
		       illumination and image quality. */
		
		require constraint {
			ophthalmoscopeSystem.objectiveLens.workingDistance >= 20.0 [SI::mm] and
			ophthalmoscopeSystem.objectiveLens.workingDistance <= 30.0 [SI::mm]
		}
	}
	
	requirement <'REQ-OPHT-005'> clinicalDiagnosticCapability : PrimaryFunctionRequirement {
		assume constraint patientPreparation {
			doc /* Patient pupil is adequately dilated and examination room 
			       lighting is appropriately dimmed. */
		}
		
		require opticalPerformance : OpticalPerformanceRequirement;
		require illuminationSafety : IlluminationSafetyRequirement;
		require workingDistance : WorkingDistanceRequirement;
	}
}
