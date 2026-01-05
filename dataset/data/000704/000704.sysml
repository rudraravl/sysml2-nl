package 'Gastric Intubation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PatientID;
	attribute def TubeSize;
	attribute def PlacementDepth;
	attribute def VerificationMethod;
	
	alias Pressure for ISQ::PressureValue;
	alias FlowRate for ISQ::VolumeFlowRateValue;
	alias Length for ISQ::LengthValue;
	alias Volume for ISQ::VolumeValue;
	alias Temperature for ISQ::ThermodynamicTemperatureValue;
	
	item def NasogastricTube {
		attribute outerDiameter : Length;
		attribute innerDiameter : Length;
		attribute totalLength : Length;
		attribute material : String;
		attribute frenchSize : TubeSize;
		port proximalEnd;
		port distalEnd;
		port sidePort;
	}
	
	item def SuctionApparatus {
		attribute maxSuctionPressure : Pressure;
		attribute currentPressure : Pressure;
		attribute intermittentMode : Boolean;
		port suctionConnection;
		port drainageCollection;
	}
	
	item def FeedingPump {
		attribute maxFlowRate : FlowRate;
		attribute currentFlowRate : FlowRate;
		attribute totalVolumeDelivered : Volume;
		port feedingReservoir;
		port tubeConnection;
	}
	
	item def GastricContents {
		attribute volume : Volume;
		attribute pH : Real;
		attribute appearance : String;
	}
	
	item def EnteralFormula {
		attribute volume : Volume;
		attribute temperature : Temperature;
		attribute caloricDensity : Real;
		attribute osmolality : Real;
	}
	
	item def VerificationEquipment {
		attribute method : VerificationMethod;
		attribute accuracy : Real;
		port measurementInterface;
	}
	
	part def Patient {
		attribute patientID : PatientID;
		attribute consciousnessLevel : String;
		attribute gagReflexPresent : Boolean;
		attribute nasalPatency : String;
		port nasalPassage;
		port esophagus;
		port stomach;
	}
	
	part def Clinician {
		attribute qualification : String;
		attribute experienceYears : Real;
	}
	
	action def AssessPatient {
		in patient : Patient;
		out assessmentComplete : Boolean;
		out contraindications : Boolean;
	}
	
	action def SelectAppropriateSize {
		in patient : Patient;
		out selectedTube : NasogastricTube;
		out tubeSize : TubeSize;
	}
	
	action def MeasureInsertionLength {
		in patient : Patient;
		in tube : NasogastricTube;
		out targetDepth : Length;
	}
	
	action def PrepareTube {
		in tube : NasogastricTube;
		out preparedTube : NasogastricTube;
		out lubricationApplied : Boolean;
	}
	
	action def PositionPatient {
		in patient : Patient;
		out patientPositioned : Boolean;
		out headPosition : String;
	}
	
	action def InsertThroughNares {
		in tube : NasogastricTube;
		in patient : Patient;
		in targetDepth : Length;
		out currentDepth : Length;
		out insertionComplete : Boolean;
	}
	
	action def VerifyTubePlacement {
		in tube : NasogastricTube;
		in patient : Patient;
		in verificationEquipment : VerificationEquipment;
		out placementVerified : Boolean;
		out tubeLocation : String;
	}
	
	action def SecureTubeExternally {
		in tube : NasogastricTube;
		in patient : Patient;
		out tubeSecured : Boolean;
		out secureDepth : Length;
	}
	
	action def DecompressStomach {
		in tube : NasogastricTube;
		in suctionApparatus : SuctionApparatus;
		in targetPressure : Pressure;
		out drainedVolume : Volume;
		out gastricContents : GastricContents;
	}
	
	action def AdministerEnteralFeeding {
		in tube : NasogastricTube;
		in feedingPump : FeedingPump;
		in formula : EnteralFormula;
		in prescribedRate : FlowRate;
		out volumeDelivered : Volume;
		out feedingComplete : Boolean;
	}
	
	action def AdministerMedication {
		in tube : NasogastricTube;
		in medicationVolume : Volume;
		out administrationComplete : Boolean;
	}
	
	action def MonitorTubePatency {
		in tube : NasogastricTube;
		out patencyStatus : Boolean;
		out requiresFlushing : Boolean;
	}
	
	action def FlushTube {
		in tube : NasogastricTube;
		in flushVolume : Volume;
		out flushComplete : Boolean;
	}
	
	action def RemoveTube {
		in tube : NasogastricTube;
		in patient : Patient;
		out removalComplete : Boolean;
	}
	
	action def PerformGastricIntubation {
		in patient : Patient;
		in clinician : Clinician;
		in purpose : String;
		out intubationSuccess : Boolean;
		out finalDepth : Length;
		
		first start;
		then action assess : AssessPatient {
			in patient = PerformGastricIntubation::patient;
			out assessmentComplete;
			out contraindications;
		}
		then decide;
			if assess.contraindications then abort;
		action selectSize : SelectAppropriateSize {
			in patient = PerformGastricIntubation::patient;
			out selectedTube;
			out tubeSize;
		}
		then action measureLength : MeasureInsertionLength {
			in patient = PerformGastricIntubation::patient;
			in tube = selectSize.selectedTube;
			out targetDepth;
		}
		then action prepareTubeAction : PrepareTube {
			in tube = selectSize.selectedTube;
			out preparedTube;
			out lubricationApplied;
		}
		then action position : PositionPatient {
			in patient = PerformGastricIntubation::patient;
			out patientPositioned;
			out headPosition;
		}
		then merge insertionLoop;
		then action insert : InsertThroughNares {
			in tube = prepareTubeAction.preparedTube;
			in patient = PerformGastricIntubation::patient;
			in targetDepth = measureLength.targetDepth;
			out currentDepth;
			out insertionComplete;
		}
		then action verify : VerifyTubePlacement {
			in tube = prepareTubeAction.preparedTube;
			in patient = PerformGastricIntubation::patient;
			out placementVerified;
			out tubeLocation;
		}
		then decide;
			if verify.placementVerified then securePosition;
			if not verify.placementVerified then repositionTube;
		action repositionTube : InsertThroughNares {
			in tube = prepareTubeAction.preparedTube;
			in patient = PerformGastricIntubation::patient;
			in targetDepth = measureLength.targetDepth;
			out currentDepth;
			out insertionComplete;
		}
		then insertionLoop;
		action securePosition : SecureTubeExternally {
			in tube = prepareTubeAction.preparedTube;
			in patient = PerformGastricIntubation::patient;
			out tubeSecured;
			out secureDepth;
		}
		then assign intubationSuccess := true;
		then assign finalDepth := securePosition.secureDepth;
		then done;
		action abort;
		then assign intubationSuccess := false;
		then done;
	}
	
	action def ProvideGastricAccess {
		in patient : Patient;
		in clinician : Clinician;
		in accessPurpose : String;
		out accessMaintained : Boolean;
		
		action intubate : PerformGastricIntubation {
			in patient = ProvideGastricAccess::patient;
			in clinician = ProvideGastricAccess::clinician;
			in purpose = ProvideGastricAccess::accessPurpose;
			out intubationSuccess;
			out finalDepth;
		}
		
		loop {
			action monitor : MonitorTubePatency {
				out patencyStatus;
				out requiresFlushing;
			}
			then decide;
				if accessPurpose == "decompression" then performDecompression;
				if accessPurpose == "feeding" then performFeeding;
				if accessPurpose == "medication" then performMedication;
				if monitor.requiresFlushing then performFlush;
			
			action performDecompression : DecompressStomach {
				out drainedVolume;
				out gastricContents;
			}
			then monitor;
			
			action performFeeding : AdministerEnteralFeeding {
				out volumeDelivered;
				out feedingComplete;
			}
			then monitor;
			
			action performMedication : AdministerMedication {
				out administrationComplete;
			}
			then monitor;
			
			action performFlush : FlushTube {
				in flushVolume = 30.0 [mL];
				out flushComplete;
			}
			then monitor;
		}
	}
	
	state machine def TubeStatusStateMachine {
		state Unplaced {
			entry action prepareForInsertion;
		}
		state Inserting {
			entry action beginInsertion;
			do action advanceTube;
		}
		state VerifyingPlacement {
			entry action initiateVerification;
			do action checkPosition;
		}
		state Secured {
			entry action applySecurement;
			do action maintainPosition;
		}
		state InUse {
			entry action beginTherapy;
			do action deliverTherapy;
		}
		state Occluded {
			entry action detectOcclusion;
			do action attemptClearance;
		}
		state Removed {
			entry action completeRemoval;
		}
		
		transition initialPlacement from Unplaced to Inserting;
		transition advanceToVerify from Inserting to VerifyingPlacement;
		transition verificationSuccess from VerifyingPlacement to Secured;
		transition verificationFailure from VerifyingPlacement to Inserting;
		transition readyForUse from Secured to InUse;
		transition detectBlockage from InUse to Occluded;
		transition clearanceSuccess from Occluded to InUse;
		transition clearanceFailure from Occluded to Removed;
		transition completeProcedure from InUse to Removed;
	}
	
	part gastricIntubationSystem {
		attribute systemIdentifier : String;
		
		part nasogastricTube : NasogastricTube {
			attribute outerDiameter = 4.7 [mm];
			attribute innerDiameter = 3.2 [mm];
			attribute totalLength = 120.0 [cm];
			attribute material = "medical grade polyvinyl chloride";
			attribute frenchSize = 14;
		}
		
		part suctionApparatus : SuctionApparatus {
			attribute maxSuctionPressure = 150.0 [mmHg];
			attribute currentPressure = 0.0 [mmHg];
			attribute intermittentMode = true;
		}
		
		part feedingPump : FeedingPump {
			attribute maxFlowRate = 400.0 [mL/h];
			attribute currentFlowRate = 0.0 [mL/h];
			attribute totalVolumeDelivered = 0.0 [mL];
		}
		
		part verificationEquipment : VerificationEquipment {
			attribute method = "pH testing and auscultation";
			attribute accuracy = 0.95;
		}
		
		part patient : Patient {
			attribute consciousnessLevel = "sedated";
			attribute gagReflexPresent = false;
			attribute nasalPatency = "patent";
		}
		
		part clinician : Clinician {
			attribute qualification = "registered nurse";
			attribute experienceYears = 8.0;
		}
		
		connect nasogastricTube.proximalEnd to suctionApparatus.suctionConnection;
		connect nasogastricTube.proximalEnd to feedingPump.tubeConnection;
		connect nasogastricTube.distalEnd to patient.stomach;
		connect verificationEquipment.measurementInterface to nasogastricTube.proximalEnd;
		
		perform action provideAccess : ProvideGastricAccess {
			in patient = gastricIntubationSystem::patient;
			in clinician = gastricIntubationSystem::clinician;
			in accessPurpose = "decompression";
			out accessMaintained;
		}
		
		exhibit state tubeStatus : TubeStatusStateMachine;
	}
	
	requirement <'GI-REQ-001'> primaryFunctionRequirement {
		doc /* The gastric intubation system shall provide safe and effective access 
		        to the gastric cavity for the purposes of decompression, enteral nutrition 
		        delivery, medication administration, and gastric content sampling. */
		
		require tubePlacementRequirement;
		require verificationRequirement;
		require therapeuticFunctionRequirement;
		require safetyRequirement;
	}
	
	requirement <'GI-REQ-002'> tubePlacementRequirement {
		doc /* The nasogastric tube shall be placed with the distal tip positioned 
		        in the gastric body, verified by at least two independent methods. */
		
		subject tube : NasogastricTube;
		
		require constraint placementDepthConstraint {
			doc /* Tube insertion depth shall be between 55 cm and 65 cm for average adult. */
		}
	}
	
	requirement <'GI-REQ-003'> verificationRequirement {
		doc /* Tube placement shall be verified using pH testing (pH < 5.5) and 
		        auscultation or radiographic confirmation before therapeutic use. */
		
		subject verification : VerificationEquipment;
		
		require constraint pHVerificationConstraint {
			doc /* Aspirated gastric contents shall have pH less than 5.5. */
		}
	}
	
	requirement <'GI-REQ-004'> therapeuticFunctionRequirement {
		doc /* The system shall support gastric decompression at controlled suction 
		        pressures and enteral feeding at prescribed flow rates. */
		
		require decompressionCapability;
		require feedingCapability;
	}
	
	requirement <'GI-REQ-005'> decompressionCapability {
		doc /* The suction apparatus shall provide intermittent or continuous suction 
		        at pressures not exceeding 150 mmHg. */
		
		subject suction : SuctionApparatus;
		
		require constraint suctionPressureLimit {
			doc /* Suction pressure shall not exceed maximum safe limit. */
			suction.currentPressure <= suction.maxSuctionPressure
		}
	}
	
	requirement <'GI-REQ-006'> feedingCapability {
		doc /* The feeding pump shall deliver enteral formula at controlled rates 
		        between 10 mL/h and 400 mL/h with accuracy of ±5%. */
		
		subject pump : FeedingPump;
		
		require constraint flowRateLimit {
			doc /* Feeding flow rate shall not exceed maximum safe rate. */
			pump.currentFlowRate <= pump.maxFlowRate
		}
	}
	
	requirement <'GI-REQ-007'> safetyRequirement {
		doc /* The system shall minimize risks of aspiration, tube misplacement, 
		        mucosal injury, and patient discomfort throughout the duration of use. */
		
		assume constraint patientSuitability {
			doc /* Patient has no absolute contraindications to nasogastric intubation. */
		}
		
		require constraint patencyMaintenance {
			doc /* Tube patency shall be monitored and maintained through regular flushing. */
		}
		
		require constraint secureFixation {
			doc /* Tube shall be secured externally to prevent migration or dislodgement. */
		}
	}
	
	requirement <'GI-REQ-008'> clinicalWorkflowRequirement {
		doc /* The intubation procedure shall follow established clinical protocols 
		        including patient assessment, tube selection, insertion technique, 
		        placement verification, and ongoing monitoring. */
		
		satisfy by PerformGastricIntubation;
		satisfy by ProvideGastricAccess;
	}
}
