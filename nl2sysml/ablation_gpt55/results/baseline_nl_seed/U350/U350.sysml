package PedorthistCareSystemModel {
	import ScalarValues::*;
	import ISQ::*;
	import SI::*;

	attribute def LengthValue :> length;
	attribute def MassValue :> mass;
	attribute def TimeValue :> time;
	attribute def PressureValue :> pressure;
	attribute def AreaValue :> area;
	attribute def ForceValue :> force;
	attribute def AngleValue :> planeAngle;
	attribute def TemperatureValue :> thermodynamicTemperature;

	item def Referral {
		attribute referralIdentifier : String;
		attribute referringClinician : String;
		attribute reasonForReferral : String;
		attribute mobilityGoal : String;
		attribute urgencyCode : String;
	}

	item def ClientProfile {
		attribute clientIdentifier : String;
		attribute ageYears : Integer;
		attribute bodyMass : MassValue;
		attribute primaryDiagnosis : String;
		attribute activityLevel : String;
		attribute skinIntegrityRisk : String;
		attribute painLocation : String;
		attribute mobilityAidUsed : Boolean;
	}

	item def FootMeasurements {
		attribute leftFootLength : LengthValue;
		attribute rightFootLength : LengthValue;
		attribute leftBallWidth : LengthValue;
		attribute rightBallWidth : LengthValue;
		attribute leftArchHeight : LengthValue;
		attribute rightArchHeight : LengthValue;
		attribute heelWidth : LengthValue;
		attribute ankleCircumference : LengthValue;
		attribute toeBoxHeightNeed : LengthValue;
		attribute forefootVarusAngle : AngleValue;
		attribute plantarContactArea : AreaValue;
	}

	item def GaitAssessmentData {
		attribute walkingSpeed : LengthValue;
		attribute stanceTimeLeft : TimeValue;
		attribute stanceTimeRight : TimeValue;
		attribute peakPlantarPressureLeft : PressureValue;
		attribute peakPlantarPressureRight : PressureValue;
		attribute pressureAsymmetryIndex : Real;
		attribute observedInstability : Boolean;
		attribute gaitDeviationSummary : String;
	}

	item def ClinicalAssessment {
		attribute contraindicationPresent : Boolean;
		attribute ulcerationRisk : String;
		attribute edemaVariationExpected : Boolean;
		attribute accommodationPriority : String;
		attribute correctionPriority : String;
		attribute assessmentSummary : String;
	}

	item def PedorthicTreatmentPlan {
		attribute planIdentifier : String;
		attribute interventionType : String;
		attribute footwearModificationRequired : Boolean;
		attribute customOrthosisRequired : Boolean;
		attribute depthFootwearRequired : Boolean;
		attribute pressureReliefTarget : PressureValue;
		attribute reviewInterval : TimeValue;
		attribute educationTopic : String;
	}

	item def OrthoticDesignSpecification {
		attribute shellMaterial : String;
		attribute topCoverMaterial : String;
		attribute postingAngle : AngleValue;
		attribute heelCupHeight : LengthValue;
		attribute metatarsalReliefPosition : LengthValue;
		attribute archSupportHeight : LengthValue;
		attribute offloadApertureDiameter : LengthValue;
		attribute expectedServiceLife : TimeValue;
	}

	item def FootwearSpecification {
		attribute shoeSizeLabel : String;
		attribute lastWidthCategory : String;
		attribute closureType : String;
		attribute rockerSoleRequired : Boolean;
		attribute soleModificationHeight : LengthValue;
		attribute toeBoxDepth : LengthValue;
		attribute insoleDepth : LengthValue;
	}

	item def FabricationOrder {
		attribute orderIdentifier : String;
		attribute dueTime : TimeValue;
		attribute priority : String;
		attribute qualityCheckRequired : Boolean;
	}

	item def FittedPedorthicDevice {
		attribute deviceIdentifier : String;
		attribute deviceType : String;
		attribute totalMass : MassValue;
		attribute peakInterfacePressure : PressureValue;
		attribute fitGapAtHeel : LengthValue;
		attribute fitGapAtForefoot : LengthValue;
		attribute clientCanDonDoff : Boolean;
		attribute acceptedByClient : Boolean;
	}

	item def CareInstruction {
		attribute wearingSchedule : String;
		attribute skinCheckFrequency : TimeValue;
		attribute cleaningMethod : String;
		attribute warningSigns : String;
		attribute followUpDateOffset : TimeValue;
	}

	port def ClientCarePort {
		in item incomingReferral : Referral;
		in item incomingProfile : ClientProfile;
		out item fittedDevice : FittedPedorthicDevice;
		out item instruction : CareInstruction;
	}

	port def MeasurementPort {
		in item profile : ClientProfile;
		out item measurements : FootMeasurements;
		out item gaitData : GaitAssessmentData;
	}

	port def ClinicalDataPort {
		in item measurements : FootMeasurements;
		in item gaitData : GaitAssessmentData;
		out item assessment : ClinicalAssessment;
	}

	port def DesignPort {
		in item assessment : ClinicalAssessment;
		in item measurements : FootMeasurements;
		out item treatmentPlan : PedorthicTreatmentPlan;
		out item orthoticDesign : OrthoticDesignSpecification;
		out item footwearDesign : FootwearSpecification;
	}

	port def FabricationPort {
		in item orthoticDesign : OrthoticDesignSpecification;
		in item footwearDesign : FootwearSpecification;
		in item treatmentPlan : PedorthicTreatmentPlan;
		out item fabricationOrder : FabricationOrder;
		out item fabricatedDevice : FittedPedorthicDevice;
	}

	port def FittingPort {
		in item profile : ClientProfile;
		in item treatmentPlan : PedorthicTreatmentPlan;
		in item fabricatedDevice : FittedPedorthicDevice;
		out item adjustedDevice : FittedPedorthicDevice;
		out item instruction : CareInstruction;
	}

	part def Pedorthist {
		attribute certificationIdentifier : String;
		attribute yearsOfPractice : Integer;
		attribute dailyAppointmentCapacity : Integer;
		attribute primaryFunctionStatement : String = "Assess foot and lower-limb needs, design pedorthic interventions, fit therapeutic footwear or orthoses, and educate the client to improve comfort, protection, and mobility.";
		port clientCare : ClientCarePort;
		port clinicalData : ClinicalDataPort;
		port design : DesignPort;
		port fitting : FittingPort;
	}

	part def IntakeDesk {
		attribute maximumIntakeDuration : TimeValue = 1800 [s];
		port clientCare : ClientCarePort;
	}

	part def FootMeasurementStation {
		attribute lengthMeasurementResolution : LengthValue = 0.001 [m];
		attribute pressureSamplingInterval : TimeValue = 0.01 [s];
		attribute platformTemperatureLimit : TemperatureValue = 313.15 [K];
		port measurement : MeasurementPort;
	}

	part def GaitObservationWalkway {
		attribute usableWalkwayLength : LengthValue = 6.0 [m];
		attribute minimumSafeWidth : LengthValue = 1.2 [m];
		port measurement : MeasurementPort;
	}

	part def PedorthicDesignWorkstation {
		attribute designRevisionLimit : Integer = 3;
		attribute nominalDesignDuration : TimeValue = 3600 [s];
		port design : DesignPort;
	}

	part def FabricationCoordinator {
		attribute standardFabricationDuration : TimeValue = 432000 [s];
		attribute rushFabricationDuration : TimeValue = 172800 [s];
		port fabrication : FabricationPort;
	}

	part def FittingBay {
		attribute minimumClearanceAroundChair : LengthValue = 0.9 [m];
		attribute fittingAppointmentDuration : TimeValue = 2700 [s];
		attribute allowableHeelGap : LengthValue = 0.006 [m];
		port fitting : FittingPort;
	}

	part def ClientRecordSystem {
		attribute recordRetentionPeriod : TimeValue = 220752000 [s];
		port clinicalData : ClinicalDataPort;
		port design : DesignPort;
		port fitting : FittingPort;
	}

	action def CaptureClientHistory {
		in item referral : Referral;
		in item profile : ClientProfile;
		out item updatedProfile : ClientProfile;
		out item initialRiskNote : ClinicalAssessment;
	}

	action def MeasureFeetAndGait {
		in item profile : ClientProfile;
		out item measurements : FootMeasurements;
		out item gaitData : GaitAssessmentData;
	}

	action def PerformClinicalAssessment {
		in item profile : ClientProfile;
		in item measurements : FootMeasurements;
		in item gaitData : GaitAssessmentData;
		out item assessment : ClinicalAssessment;
	}

	action def CreatePedorthicPlan {
		in item assessment : ClinicalAssessment;
		in item measurements : FootMeasurements;
		out item plan : PedorthicTreatmentPlan;
		out item orthoticDesign : OrthoticDesignSpecification;
		out item footwearDesign : FootwearSpecification;
	}

	action def CoordinateFabrication {
		in item plan : PedorthicTreatmentPlan;
		in item orthoticDesign : OrthoticDesignSpecification;
		in item footwearDesign : FootwearSpecification;
		out item fabricationOrder : FabricationOrder;
		out item fabricatedDevice : FittedPedorthicDevice;
	}

	action def FitAdjustAndEducate {
		in item profile : ClientProfile;
		in item plan : PedorthicTreatmentPlan;
		in item fabricatedDevice : FittedPedorthicDevice;
		out item fittedDevice : FittedPedorthicDevice;
		out item instruction : CareInstruction;
	}

	action def ProvidePedorthicCare {
		in item referral : Referral;
		in item profile : ClientProfile;
		out item fittedDevice : FittedPedorthicDevice;
		out item instruction : CareInstruction;

		action intake : CaptureClientHistory;
		action measure : MeasureFeetAndGait;
		action assess : PerformClinicalAssessment;
		action design : CreatePedorthicPlan;
		action fabricate : CoordinateFabrication;
		action fit : FitAdjustAndEducate;

		flow referral to intake.referral;
		flow profile to intake.profile;
		flow intake.updatedProfile to measure.profile;
		flow intake.updatedProfile to assess.profile;
		flow measure.measurements to assess.measurements;
		flow measure.gaitData to assess.gaitData;
		flow assess.assessment to design.assessment;
		flow measure.measurements to design.measurements;
		flow design.plan to fabricate.plan;
		flow design.orthoticDesign to fabricate.orthoticDesign;
		flow design.footwearDesign to fabricate.footwearDesign;
		flow intake.updatedProfile to fit.profile;
		flow design.plan to fit.plan;
		flow fabricate.fabricatedDevice to fit.fabricatedDevice;
		flow fit.fittedDevice to fittedDevice;
		flow fit.instruction to instruction;

		first intake;
		then measure;
		then assess;
		then design;
		then fabricate;
		then fit;
	}

	state def PedorthicCareLifecycle {
		state AwaitingReferral;
		state IntakeScheduled;
		state AssessmentInProgress;
		state PlanCreated;
		state FabricationInProgress;
		state FittingInProgress;
		state ClientEducated;
		state FollowUpPlanned;
		state CaseClosed;

		transition startCare first AwaitingReferral then IntakeScheduled;
		transition beginAssessment first IntakeScheduled then AssessmentInProgress;
		transition approvePlan first AssessmentInProgress then PlanCreated;
		transition orderDevice first PlanCreated then FabricationInProgress;
		transition receiveDevice first FabricationInProgress then FittingInProgress;
		transition acceptFit first FittingInProgress then ClientEducated;
		transition scheduleReview first ClientEducated then FollowUpPlanned;
		transition closeAfterFollowUp first FollowUpPlanned then CaseClosed;
	}

	part def PedorthistCareSystem {
		attribute systemName : String = "Pedorthist Care System";
		attribute primaryFunction : String = "Provide client-centered pedorthic assessment, therapeutic footwear and orthotic design, fitting, adjustment, and education to reduce foot risk and improve mobility.";
		attribute nominalCareTurnaround : TimeValue = 604800 [s];
		attribute maximumAllowedPeakInterfacePressure : PressureValue = 30000 [Pa];
		attribute maximumAllowedHeelFitGap : LengthValue = 0.006 [m];

		port clientService : ClientCarePort;

		part intakeDesk : IntakeDesk;
		part pedorthist : Pedorthist;
		part measurementStation : FootMeasurementStation;
		part gaitWalkway : GaitObservationWalkway;
		part designWorkstation : PedorthicDesignWorkstation;
		part fabricationCoordinator : FabricationCoordinator;
		part fittingBay : FittingBay;
		part recordSystem : ClientRecordSystem;

		perform action careProcess : ProvidePedorthicCare;
		exhibit state careLifecycle : PedorthicCareLifecycle;

		connect clientService to intakeDesk.clientCare;
		connect intakeDesk.clientCare to pedorthist.clientCare;
		connect measurementStation.measurement to gaitWalkway.measurement;
		connect measurementStation.measurement to pedorthist.clinicalData;
		connect gaitWalkway.measurement to pedorthist.clinicalData;
		connect pedorthist.clinicalData to recordSystem.clinicalData;
		connect pedorthist.design to designWorkstation.design;
		connect designWorkstation.design to recordSystem.design;
		connect designWorkstation.design to fabricationCoordinator.fabrication;
		connect fabricationCoordinator.fabrication to fittingBay.fitting;
		connect pedorthist.fitting to fittingBay.fitting;
		connect fittingBay.fitting to recordSystem.fitting;
		connect fittingBay.fitting to clientService;
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The Pedorthist Care System shall perform the high-level function of assessing a client's foot-related needs and delivering an appropriate pedorthic device with fitting and education. */
		subject system : PedorthistCareSystem;
		require constraint {
			system.nominalCareTurnaround <= 604800 [s]
		}
	}

	requirement def MeasurementCapabilityRequirement {
		doc /* The system shall capture dimensional and pressure information needed to support pedorthic assessment and design. */
		subject station : FootMeasurementStation;
		require constraint {
			station.lengthMeasurementResolution <= 0.001 [m]
		}
	}

	requirement def FitSafetyRequirement {
		doc /* The fitted pedorthic device shall limit heel gap and peak interface pressure to support comfort and skin protection. */
		subject system : PedorthistCareSystem;
		require constraint {
			system.maximumAllowedHeelFitGap <= 0.006 [m] and system.maximumAllowedPeakInterfacePressure <= 30000 [Pa]
		}
	}

	requirement def ClientEducationRequirement {
		doc /* The system shall provide wearing schedule, skin-check guidance, cleaning method, warning signs, and follow-up timing with each accepted device. */
		subject bay : FittingBay;
		require constraint {
			bay.fittingAppointmentDuration >= 1800 [s]
		}
	}

	requirement def RecordRetentionRequirement {
		doc /* The system shall retain clinical assessment, design, fitting, and follow-up records for continuity of pedorthic care. */
		subject records : ClientRecordSystem;
		require constraint {
			records.recordRetentionPeriod >= 220752000 [s]
		}
	}

	part pedorthistCareSystem : PedorthistCareSystem;
}
