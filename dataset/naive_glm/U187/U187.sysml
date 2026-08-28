package MedicalCompressionTherapySystem {
	import ScalarValues::*;
	import ISQ::*;
	import ISQSpaceTime::*;
	
	// ---------- Value Types with Units ----------
	
	value def PressureValue :> Real {
		:>> unit = PressureUnit::kPa;
	}
	
	value def CircumferenceValue :> Real {
		:>> unit = LengthUnit::cm;
	}
	
	value def TensionValue :> Real {
		:>> unit = ForceUnit::N;
	}
	
	value def DurationValue :> Real {
		:>> unit = TimeUnit::h;
	}
	
	value def ElasticModulusValue :> Real {
		:>> unit = PressureUnit::kPa;
	}
	
	value def CirculationFlowValue :> Real {
		:>> unit = VolumePerTimeUnit::mL_per_min;
	}
	
	value def WearCycleCount :> Integer;
	
	value def CompressionClass :> Integer {
		:>> constraint { self >= 1 and self <= 4 }
	}
	
	// ---------- Item Types ----------
	
	item def CompressiveFabric {
		attribute elasticModulus : ElasticModulusValue;
		attribute layerCount : Integer;
		attribute breathabilityRating : Real;
	}
	
	item def ElasticYarn {
		attribute tensileStrength : TensionValue;
		attribute elasticityRatio : Real;
	}
	
	item def ReinforcementZone {
		attribute zoneLocation : String;
		attribute targetPressure : PressureValue;
	}
	
	item def MoistureWickingLiner {
		attribute moistureTransferRate : Real;
		attribute breathabilityIndex : Real;
	}
	
	item def LimbSegment {
		attribute segmentName : String;
		attribute positionFromDistal : CircumferenceValue;
		attribute circumference : CircumferenceValue;
		attribute targetPressure : PressureValue;
	}
	
	item def PatientLimb {
		attribute limbType : String; // "arm" or "leg"
		attribute segments : LimbSegment[0..*];
		attribute swellingIndex : Real;
		attribute circulationBaseline : CirculationFlowValue;
	}
	
	// ---------- Port Definitions ----------
	
	port def PressureApplicationPort {
		out appliedPressure : PressureValue;
		in measuredPressure : PressureValue;
	}
	
	port def MonitoringPort {
		out circumferenceReading : CircumferenceValue;
		out circulationReading : CirculationFlowValue;
		in monitoringCommand : String;
	}
	
	port def FitmentPort {
		out fitmentStatus : String;
		in sizeSelection : String;
		in compressionClassSelection : CompressionClass;
	}
	
	port def PatientInterfacePort {
		out deliveredPressure : PressureValue;
		in patientFeedback : String;
	}
	
	// ---------- Requirements ----------
	
	requirement def GraduatedPressureRequirement {
		doc /* The system shall apply graduated pressure strongest at the distal point and decreasing proximally. */
		subject : compressionSystem : CompressionTherapySystem;
		subject : patient : PatientLimb;
		requirementConstraint {
			// Distal pressure must be highest
			compressionSystem.garment.distalPressure > compressionSystem.garment.proximalPressure
		}
	}
	
	requirement def TherapeuticPressureRangeRequirement {
		doc /* Applied pressure shall be within therapeutic range of 2.0 to 8.0 kPa depending on compression class. */
		subject : garment : CompressionGarment;
		requirementConstraint {
			garment.appliedPressure >= 2.0 [kPa] and garment.appliedPressure <= 8.0 [kPa]
		}
	}
	
	requirement def MonitoringRequirement {
		doc /* The system shall monitor limb circumference and circulation during therapy. */
		subject : monitor : TherapyMonitor;
		requirementConstraint {
			monitor.circumferenceTracking.isActive == true and
			monitor.circulationTracking.isActive == true
		}
	}
	
	requirement def DurabilityRequirement {
		doc /* The garment shall retain compressive properties through at least 180 wear cycles. */
		subject : garment : CompressionGarment;
		requirementConstraint {
			garment.wearCycles >= 180 and garment.pressureRetentionRatio >= 0.85
		}
	}
	
	requirement def ComfortRequirement {
		doc /* The garment shall include a moisture-wicking inner liner for patient comfort and breathability. */
		subject : garment : CompressionGarment;
		requirementConstraint {
			garment.innerLiner.moistureTransferRate >= 0.7 and garment.innerLiner.breathabilityIndex >= 0.6
		}
	}
	
	requirement def AssessmentRequirement {
		doc /* The system shall assess the patient limb to measure swelling and determine garment size and compression level. */
		subject : assessor : LimbAssessor;
		requirementConstraint {
			assessor.swellingMeasurement.isComplete == true and
			assessor.sizeDetermination.isComplete == true and
			assessor.compressionLevelDetermination.isComplete == true
		}
	}
	
	requirement def TherapeuticGoalRequirement {
		doc /* Therapy shall continue until improved circulation and reduced swelling are achieved. */
		subject : therapy : CompressionTherapyProcess;
		requirementConstraint {
			therapy.circulationImprovement >= 15.0 [%] and
			therapy.swellingReduction >= 20.0 [%]
		}
	}
	
	// ---------- Parts ----------
	
	part def CompressionGarment {
		attribute garmentType : String; // "stocking" or "sleeve"
		attribute sizeDesignation : String;
		attribute compressionClass : CompressionClass;
		attribute appliedPressure : PressureValue;
		attribute distalPressure : PressureValue;
		attribute proximalPressure : PressureValue;
		attribute wearCycles : WearCycleCount;
		attribute pressureRetentionRatio : Real;
		
		part outerFabricLayer : CompressiveFabric {
			:>> elasticModulus = 120.0 [kPa];
			:>> layerCount = 3;
			:>> breathabilityRating = 0.5;
		}
		
		part middleFabricLayer : CompressiveFabric {
			:>> elasticModulus = 85.0 [kPa];
			:>> layerCount = 2;
			:>> breathabilityRating = 0.6;
		}
		
		part elasticYarnNetwork : ElasticYarn {
			:>> tensileStrength = 50.0 [N];
			:>> elasticityRatio = 0.75;
		}
		
		part reinforcementZones : ReinforcementZone[0..*] {
			:>> zoneLocation = "ankle";
			:>> targetPressure = 6.0 [kPa];
		}
		
		part innerLiner : MoistureWickingLiner {
			:>> moistureTransferRate = 0.8;
			:>> breathabilityIndex = 0.75;
		}
		
		port pressurePort : PressureApplicationPort;
		port patientPort : PatientInterfacePort;
		port fitmentPort : FitmentPort;
		
		state def GarmentOperationalStates {
			entry action { send garmentType + " initialized"; }
			
			state Unfitted {
				entry action { send "Garment awaiting fitting"; }
				transition to Fitted
					when fitmentPort.fitmentStatus == "fitted";
			}
			
			state Fitted {
				entry action { send "Garment fitted to patient limb"; }
				transition to ActiveCompression
					when fitmentPort.fitmentStatus == "active";
			}
			
			state ActiveCompression {
				entry action {
					appliedPressure := distalPressure;
					send "Applying graduated compression: distal=" + distalPressure as String + " kPa";
				}
				do action {
					// Sustain therapeutic pressure
					appliedPressure := distalPressure;
				}
				transition to Monitoring
					when pressurePort.measuredPressure != appliedPressure;
			}
			
			state Monitoring {
				entry action { send "Monitoring pressure retention"; }
				transition to ActiveCompression
					when pressurePort.measuredPressure == appliedPressure;
				transition to MaintenanceRequired
					when pressureRetentionRatio < 0.85;
			}
			
			state MaintenanceRequired {
				entry action { send "Garment requires maintenance or replacement"; }
			}
		}
		
		composition operationalStateMachine : GarmentOperationalStates;
	}
	
	part def LimbAssessor {
		attribute assessedLimbType : String;
		attribute measuredSwelling : Real;
		attribute recommendedSize : String;
		attribute recommendedCompressionClass : CompressionClass;
		
		part swellingMeasurement {
			attribute isComplete : Boolean;
			attribute circumferenceReadings : CircumferenceValue[0..*];
		}
		
		part sizeDetermination {
			attribute isComplete : Boolean;
			attribute sizeOptions : String[0..*];
		}
		
		part compressionLevelDetermination {
			attribute isComplete : Boolean;
			attribute severityLevel : String;
		}
		
		port assessmentPort : FitmentPort;
		
		action def AssessLimb {
			in limb : PatientLimb;
			out size : String;
			out compressionClass : CompressionClass;
			out swellingIndex : Real;
			
			action MeasureSwelling {
				in limbIn : PatientLimb;
				out circumferenceData : CircumferenceValue[0..*];
				out swellingLevel : Real;
			}
			
			action DetermineSize {
				in circumferenceData : CircumferenceValue[0..*];
				out selectedSize : String;
			}
			
			action DetermineCompressionLevel {
				in swellingLevel : Real;
				out selectedClass : CompressionClass;
			}
			
			flow from MeasureSwelling.circumferenceData to DetermineSize.circumferenceData;
			flow from MeasureSwelling.swellingLevel to DetermineCompressionLevel.swellingLevel;
			
			bind size = DetermineSize.selectedSize;
			bind compressionClass = DetermineCompressionLevel.selectedClass;
			bind swellingIndex = MeasureSwelling.swellingLevel;
		}
	}
	
	part def TherapyMonitor {
		attribute monitoringActive : Boolean;
		attribute sessionDuration : DurationValue;
		attribute circulationImprovement : Real;
		attribute swellingReduction : Real;
		
		part circumferenceTracking {
			attribute isActive : Boolean;
			attribute baselineCircumference : CircumferenceValue;
			attribute currentCircumference : CircumferenceValue;
			attribute deltaCircumference : CircumferenceValue;
		}
		
		part circulationTracking {
			attribute isActive : Boolean;
			attribute baselineCirculation : CirculationFlowValue;
			attribute currentCircumference : CirculationFlowValue;
			attribute deltaCirculation : CirculationFlowValue;
		}
		
		port monitorPort : MonitoringPort;
		
		action def MonitorTherapy {
			in garment : CompressionGarment;
			in limb : PatientLimb;
			out circumferenceDelta : CircumferenceValue;
			out circulationDelta : CirculationFlowValue;
			out therapyComplete : Boolean;
			
			action TrackCircumference {
				in limbIn : PatientLimb;
				out circumferenceChange : CircumferenceValue;
			}
			
			action TrackCirculation {
				in limbIn : PatientLimb;
				out circulationChange : CirculationFlowValue;
			}
			
			action EvaluateTherapeuticGoals {
				in circumferenceChange : CircumferenceValue;
				in circulationChange : CirculationFlowValue;
				out goalsMet : Boolean;
			}
			
			flow from TrackCircumference.circumferenceChange to EvaluateTherapeuticGoals.circumferenceChange;
			flow from TrackCirculation.circulationChange to EvaluateTherapeuticGoals.circulationChange;
			
			bind circumferenceDelta = TrackCircumference.circumferenceChange;
			bind circulationDelta = TrackCirculation.circulationChange;
			bind therapyComplete = EvaluateTherapeuticGoals.goalsMet;
		}
	}
	
	part def PressureRegulator {
		attribute currentDistalPressure : PressureValue;
		attribute currentProximalPressure : PressureValue;
		attribute gradientSlope : Real;
		attribute adjustmentEnabled : Boolean;
		
		port regulationPort : PressureApplicationPort;
		
		action def RegulatePressure {
			in targetDistal : PressureValue;
			in targetProximal : PressureValue;
			out regulatedDistal : PressureValue;
			out regulatedProximal : PressureValue;
			
			action CalculateGradient {
				in distal : PressureValue;
				in proximal : PressureValue;
				out slope : Real;
			}
			
			action ApplyGradient {
				in slope : Real;
				in distal : PressureValue;
				out appliedDistal : PressureValue;
				out appliedProximal : PressureValue;
			}
			
			flow from CalculateGradient.slope to ApplyGradient.slope;
			
			bind regulatedDistal = ApplyGradient.appliedDistal;
			bind regulatedProximal = ApplyGradient.appliedProximal;
		}
	}
	
	part def CompressionTherapySystem {
		attribute systemId : String;
		attribute systemStatus : String;
		attribute circulationImprovement : Real;
		attribute swellingReduction : Real;
		
		part garment : CompressionGarment {
			:>> garmentType = "stocking";
			:>> sizeDesignation = "medium";
			:>> compressionClass = 2;
			:>> distalPressure = 6.0 [kPa];
			:>> proximalPressure = 2.5 [kPa];
			:>> appliedPressure = 6.0 [kPa];
			:>> wearCycles = 0;
			:>> pressureRetentionRatio = 1.0;
		}
		
		part assessor : LimbAssessor {
			:>> assessedLimbType = "leg";
			:>> recommendedSize = "medium";
			:>> recommendedCompressionClass = 2;
		}
		
		part monitor : TherapyMonitor {
			:>> monitoringActive = false;
			:>> sessionDuration = 0.0 [h];
			:>> circulationImprovement = 0.0;
			:>> swellingReduction = 0.0;
		}
		
		part regulator : PressureRegulator {
			:>> currentDistalPressure = 6.0 [kPa];
			:>> currentProximalPressure = 2.5 [kPa];
			:>> gradientSlope = -0.35;
			:>> adjustmentEnabled = true;
		}
		
		part patientLimb : PatientLimb {
			:>> limbType = "leg";
			:>> swellingIndex = 0.45;
			:>> circulationBaseline = 35.0 [mL/min];
			
			part distalSegment : LimbSegment {
				:>> segmentName = "ankle";
				:>> positionFromDistal = 0.0 [cm];
				:>> circumference = 24.0 [cm];
				:>> targetPressure = 6.0 [kPa];
			}
			
			part midSegment : LimbSegment {
				:>> segmentName = "calf";
				:>> positionFromDistal = 20.0 [cm];
				:>> circumference = 32.0 [cm];
				:>> targetPressure = 4.5 [kPa];
			}
			
			part proximalSegment : LimbSegment {
				:>> segmentName = "thigh";
				:>> positionFromDistal = 45.0 [cm];
				:>> circumference = 48.0 [cm];
				:>> targetPressure = 2.5 [kPa];
			}
		}
		
		// Connections
		connection assessor.assessmentPort to garment.fitmentPort;
		connection garment.pressurePort to regulator.regulationPort;
		connection garment.patientPort to monitor.monitorPort;
		
		// Requirements satisfaction
		satisfy GraduatedPressureRequirement by garment;
		satisfy TherapeuticPressureRangeRequirement by garment;
		satisfy MonitoringRequirement by monitor;
		satisfy DurabilityRequirement by garment;
		satisfy ComfortRequirement by garment;
		satisfy AssessmentRequirement by assessor;
		satisfy TherapeuticGoalRequirement by self;
		
		state def SystemTherapyStates {
			entry action { send "Compression therapy system initialized"; }
			
			state Idle {
				entry action { send "System idle, awaiting patient"; }
				transition to Assessing
					when patientLimb.swellingIndex > 0.0;
			}
			
			state Assessing {
				entry action {
					send "Assessing patient limb for swelling and sizing";
					assessor.swellingMeasurement.isComplete := true;
					assessor.sizeDetermination.isComplete := true;
					assessor.compressionLevelDetermination.isComplete := true;
				}
				transition to Fitting
					when assessor.swellingMeasurement.isComplete == true;
			}
			
			state Fitting {
				entry action {
					send "Fitting garment to patient limb";
					garment.fitmentPort.fitmentStatus := "fitted";
				}
				transition to ActiveTherapy
					when garment.fitmentPort.fitmentStatus == "active";
			}
			
			state ActiveTherapy {
				entry action {
					send "Active compression therapy in progress";
					monitor.monitoringActive := true;
					monitor.circumferenceTracking.isActive := true;
					monitor.circumferenceTracking.baselineCircumference := patientLimb.distalSegment.circumference;
					monitor.circulationTracking.isActive := true;
					monitor.circulationTracking.baselineCirculation := patientLimb.circulationBaseline;
				}
				do action {
					// Continuously apply graduated pressure and monitor
					garment.appliedPressure := garment.distalPressure;
					monitor.sessionDuration := monitor.sessionDuration + 1.0 [h];
				}
				transition to Adjusting
					when monitor.circumferenceTracking.deltaCircumference > 0.5 [cm];
				transition to TherapyComplete
					when circulationImprovement >= 15.0 and swellingReduction >= 20.0;
			}
			
			state Adjusting {
				entry action {
					send "Adjusting compression based on monitoring data";
					regulator.adjustmentEnabled := true;
				}
				transition to ActiveTherapy
					when regulator.adjustmentEnabled == false;
			}
			
			state TherapyComplete {
				entry action {
					send "Therapeutic goals achieved: circulation improved, swelling reduced";
					monitor.monitoringActive := false;
				}
				transition to Idle
					when systemStatus == "reset";
			}
		}
		
		composition therapyStateMachine : SystemTherapyStates;
	}
	
	// ---------- Top-level process definition ----------
	
	action def CompressionTherapyProcess {
		in patientLimb : PatientLimb;
		out therapyOutcome : String;
		
		attribute circulationImprovement : Real;
		attribute swellingReduction : Real;
		
		action AssessPatientLimb {
			in limb : PatientLimb;
			out size : String;
			out compressionClass : CompressionClass;
			out swellingIndex : Real;
		}
		
		action FitGarment {
			in size : String;
			in compressionClass : CompressionClass;
			out fitmentConfirmed : Boolean;
		}
		
		action ApplyGraduatedCompression {
			in fitmentConfirmed : Boolean;
			in limb : PatientLimb;
			out pressureApplied : PressureValue;
		}
		
		action MonitorProgress {
			in pressureApplied : PressureValue;
			in limb : PatientLimb;
			out circumferenceDelta : CircumferenceValue;
			out circulationDelta : CirculationFlowValue;
		}
		
		action EvaluateGoals {
			in circumferenceDelta : CircumferenceValue;
			in circulationDelta : CirculationFlowValue;
			out goalsMet : Boolean;
		}
		
		action AdjustOrContinue {
			in goalsMet : Boolean;
			in circumferenceDelta : CircumferenceValue;
			out continueTherapy : Boolean;
		}
		
		flow from AssessPatientLimb.size to FitGarment.size;
		flow from AssessPatientLimb.compressionClass to FitGarment.compressionClass;
		flow from AssessPatientLimb.swellingIndex to AssessPatientLimb.swellingIndex;
		flow from FitGarment.fitmentConfirmed to ApplyGraduatedCompression.fitmentConfirmed;
		flow from ApplyGraduatedCompression.pressureApplied to MonitorProgress.pressureApplied;
		flow from MonitorProgress.circumferenceDelta to EvaluateGoals.circumferenceDelta;
		flow from MonitorProgress.circulationDelta to EvaluateGoals.circulationDelta;
		flow from EvaluateGoals.goalsMet to AdjustOrContinue.goalsMet;
		flow from MonitorProgress.circumferenceDelta to AdjustOrContinue.circumferenceDelta;
		
		// Loop back for continued therapy
		flow from AdjustOrContinue.continueTherapy to ApplyGraduatedCompression.fitmentConfirmed;
		
		bind therapyOutcome = if EvaluateGoals.goalsMet then "therapy_successful" else "therapy_ongoing";
	}
}
