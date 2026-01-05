package 'Palatal Obturator System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	enum def MaterialGrade {
		enum medical_grade;
		enum biocompatible;
		enum standard_grade;
	}
	
	enum def DefectType {
		enum congenital_cleft;
		enum acquired_surgical;
		enum traumatic;
	}
	
	attribute def DefectGeometry {
		attribute length : ISQ::LengthValue;
		attribute width : ISQ::LengthValue;
		attribute depth : ISQ::LengthValue;
		attribute location : ScalarValues::String;
	}
	
	attribute def SealPerformance {
		attribute leakageRate : ISQ::VolumeFlowRateValue;
		attribute contactPressure : ISQ::PressureValue;
		attribute effectiveness : ScalarValues::Real;
	}
	
	item def Air;
	item def Food;
	item def Liquid;
	
	port def OralPort {
		attribute contactArea : ISQ::AreaValue;
		in airflow : ISQ::VolumeFlowRateValue;
		out pressure : ISQ::PressureValue;
	}
	
	port def NasalPort {
		attribute contactArea : ISQ::AreaValue;
		out airflow : ISQ::VolumeFlowRateValue;
		in pressure : ISQ::PressureValue;
	}
	
	port def DefectPort {
		attribute geometry : DefectGeometry;
		in obturatorContact : ScalarValues::Boolean;
		out closureStatus : ScalarValues::Boolean;
	}
	
	port def RetentionPort {
		attribute retentionForce : ISQ::ForceValue;
		in anchorContact : ScalarValues::Boolean;
	}
	
	part def PalatalDefect {
		doc /* Represents a congenital or acquired opening in the hard or soft palate 
		     that creates abnormal communication between oral and nasal cavities. */
		attribute defectType : MaterialGrade;
		attribute geometry : DefectGeometry;
		attribute severity : ScalarValues::Real;
		port defectOpening : DefectPort;
	}
	
	part def ObturatorBody {
		doc /* The main structural component that fills the palatal defect. */
		attribute material : MaterialGrade;
		attribute volume : ISQ::VolumeValue;
		attribute mass : ISQ::MassValue;
		port defectInterface : DefectPort;
	}
	
	part def ObturatorBulb {
		doc /* The hollow or solid extension that projects into the defect space 
		     to provide sealing and separation. */
		attribute material : MaterialGrade;
		attribute compressibility : ScalarValues::Real;
		attribute surfaceArea : ISQ::AreaValue;
		port sealingSurface : OralPort;
	}
	
	part def RetentionClasps {
		doc /* Mechanical retention elements that engage remaining teeth or tissue. */
		attribute claspCount : ScalarValues::Integer;
		attribute retentionForce : ISQ::ForceValue;
		port anchorPoints : RetentionPort[2..*];
	}
	
	part def OralCavity {
		doc /* The patient's oral cavity requiring separation from nasal cavity. */
		attribute intraOralPressure : ISQ::PressureValue;
		port palatalSurface : OralPort;
		port dentalAnchors : RetentionPort[*];
	}
	
	part def NasalCavity {
		doc /* The patient's nasal cavity that must be isolated from oral cavity. */
		attribute nasalAirflow : ISQ::VolumeFlowRateValue;
		port nasalSurface : NasalPort;
	}
	
	part def PalatalObturator {
		doc /* A maxillofacial prosthetic device designed to close congenital or acquired 
		     defects of the hard and soft palate, restoring the physical barrier between 
		     oral and nasal cavities to enable proper speech, swallowing, and mastication. */
		
		attribute totalMass : ISQ::MassValue;
		attribute materialGrade : MaterialGrade;
		attribute fitQuality : ScalarValues::Real;
		
		part body : ObturatorBody {
			attribute :>> material = MaterialGrade::medical_grade;
		}
		
		part bulb : ObturatorBulb {
			attribute :>> compressibility = 0.7;
		}
		
		part retention : RetentionClasps {
			attribute :>> claspCount = 4;
			attribute :>> retentionForce = 8.0 [SI::N];
		}
		
		port oralInterface : OralPort;
		port defectClosure : DefectPort;
		port retentionInterface : RetentionPort[*];
		
		connect body.defectInterface to defectClosure;
		connect bulb.sealingSurface to oralInterface;
		connect retention.anchorPoints to retentionInterface;
	}
	
	action def AssessDefect {
		in defect : PalatalDefect;
		out defectCharacteristics : DefectGeometry;
		out treatmentPlan : ScalarValues::String;
	}
	
	action def FabricateDevice {
		in defectData : DefectGeometry;
		in materialSpec : MaterialGrade;
		out fabricatedObturator : PalatalObturator;
	}
	
	action def InsertDevice {
		in obturator : PalatalObturator;
		in oral : OralCavity;
		out insertionComplete : ScalarValues::Boolean;
		out initialSeal : SealPerformance;
	}
	
	action def EvaluateSeal {
		in obturator : PalatalObturator;
		in defect : PalatalDefect;
		out sealQuality : SealPerformance;
		out speechQuality : ScalarValues::Real;
		out swallowingFunction : ScalarValues::Real;
	}
	
	action def AdjustFit {
		in currentObturator : PalatalObturator;
		in sealAssessment : SealPerformance;
		out adjustedObturator : PalatalObturator;
	}
	
	action def RestoreOronasalSeparation {
		doc /* Primary high-level function: Close the palatal defect to restore complete 
		     separation between oral and nasal cavities, enabling normal speech articulation, 
		     preventing nasal regurgitation during swallowing, and restoring adequate 
		     intraoral pressure for mastication and deglutition. */
		
		in palatalDefect : PalatalDefect;
		out speechRestoration : ScalarValues::Real;
		out swallowingRestoration : ScalarValues::Real;
		out masticationRestoration : ScalarValues::Real;
		out sealIntegrity : ScalarValues::Real;
		
		first start;
		
		then action assess : AssessDefect {
			in defect = palatalDefect;
			out defectCharacteristics;
			out treatmentPlan;
		}
		
		then action fabricate : FabricateDevice {
			in defectData = assess.defectCharacteristics;
			in materialSpec = MaterialGrade::medical_grade;
			out fabricatedObturator;
		}
		
		then action insert : InsertDevice {
			in obturator = fabricate.fabricatedObturator;
			out insertionComplete;
			out initialSeal;
		}
		
		then merge evaluationLoop;
		
		then action evaluate : EvaluateSeal {
			in obturator = fabricate.fabricatedObturator;
			in defect = palatalDefect;
			out sealQuality;
			out speechQuality;
			out swallowingFunction;
		}
		
		then decide;
			if evaluate.sealQuality.effectiveness < 0.85 then adjust;
			if evaluate.sealQuality.effectiveness >= 0.85 then maintainFunction;
		
		action adjust : AdjustFit {
			in currentObturator = fabricate.fabricatedObturator;
			in sealAssessment = evaluate.sealQuality;
			out adjustedObturator;
		}
		then evaluationLoop;
		
		action maintainFunction {
			doc /* Device maintains effective seal and enables oral functions. */
		}
		then assign speechRestoration := evaluate.speechQuality;
		then assign swallowingRestoration := evaluate.swallowingFunction;
		then assign masticationRestoration := 0.80;
		then assign sealIntegrity := evaluate.sealQuality.effectiveness;
		then done;
	}
	
	state def ObturatorLifecycle {
		entry; then Fabrication;
		
		state Fabrication;
		accept at Fabrication
			then FabricationComplete
			then Fitting;
		
		state Fitting;
		accept at Fitting
			then SealVerified
			then Functional;
		
		state Functional;
		accept at Functional
			then SealDegraded
			then Adjustment;
		accept at Functional
			then RoutineCheckDue
			then Maintenance;
		
		state Adjustment;
		accept at Adjustment
			then AdjustmentComplete
			then Functional;
		
		state Maintenance;
		accept at Maintenance
			then MaintenanceComplete
			then Functional;
	}
	
	part palatalObturatorSystem {
		doc /* Complete system integrating patient anatomy with prosthetic device. */
		
		part patient {
			part defect : PalatalDefect {
				attribute :>> defectType = MaterialGrade::medical_grade;
				attribute :>> geometry {
					attribute :>> length = 28.0 [SI::mm];
					attribute :>> width = 18.0 [SI::mm];
					attribute :>> depth = 10.0 [SI::mm];
					attribute :>> location = "hard palate posterior";
				}
				attribute :>> severity = 0.75;
			}
			
			part oral : OralCavity {
				attribute :>> intraOralPressure = 1.5 [SI::kPa];
			}
			
			part nasal : NasalCavity {
				attribute :>> nasalAirflow = 0.00025 [SI::'m^3/s'];
			}
		}
		
		part prosthesis : PalatalObturator {
			attribute :>> totalMass = 35.0 [SI::g];
			attribute :>> materialGrade = MaterialGrade::medical_grade;
			attribute :>> fitQuality = 0.90;
		}
		
		connect prosthesis.defectClosure to patient.defect.defectOpening;
		connect prosthesis.oralInterface to patient.oral.palatalSurface;
		connect prosthesis.retentionInterface to patient.oral.dentalAnchors;
		
		perform action treatment : RestoreOronasalSeparation {
			in palatalDefect = patient.defect;
			out speechRestoration;
			out swallowingRestoration;
			out masticationRestoration;
			out sealIntegrity;
		}
	}
	
	requirement def FunctionalRequirement {
		doc /* Base requirement for obturator functional performance. */
		subject device : PalatalObturator;
	}
	
	requirement def SealingRequirement :> FunctionalRequirement {
		doc /* The obturator shall provide effective seal between oral and nasal cavities 
		     with leakage rate not exceeding 5% during normal function. */
		require constraint {
			doc /* Seal effectiveness must be at least 95% */
		}
	}
	
	requirement def RetentionRequirement :> FunctionalRequirement {
		doc /* The obturator shall remain securely retained during speech, swallowing, 
		     and mastication with minimum retention force of 5 Newtons. */
		require constraint {
			doc /* Retention force must be at least 5 N */
		}
	}
	
	requirement def BiocompatibilityRequirement :> FunctionalRequirement {
		doc /* All obturator materials in contact with tissue shall be medical-grade 
		     biocompatible materials meeting ISO 10993 standards. */
		require constraint {
			doc /* Material must be medical grade */
		}
	}
	
	requirement def SpeechRestorationRequirement :> FunctionalRequirement {
		doc /* The obturator shall restore speech intelligibility to at least 85% 
		     of normal articulation capability. */
		require constraint {
			doc /* Speech quality must be at least 85% */
		}
	}
	
	requirement def MassConstraint :> FunctionalRequirement {
		doc /* The obturator total mass shall not exceed 50 grams to ensure patient 
		     comfort and adequate retention. */
		require constraint {
			doc /* Device mass must not exceed 50 grams */
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for palatal obturator system performance. */
		
		subject system : PalatalObturator;
		
		require sealingReq : SealingRequirement;
		require retentionReq : RetentionRequirement;
		require biocompatReq : BiocompatibilityRequirement;
		require speechReq : SpeechRestorationRequirement;
		require massReq : MassConstraint;
	}
}
