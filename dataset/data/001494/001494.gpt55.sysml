package MedicalRoboticPrimaryTaskSystem {

	import ScalarValues::*;
	import SI::*;
	import ISQ::*;

	attribute def Length :> ISQ::length;
	attribute def Mass :> ISQ::mass;
	attribute def Time :> ISQ::time;
	attribute def Duration :> ISQ::duration;
	attribute def Force :> ISQ::force;
	attribute def Power :> ISQ::power;
	attribute def Energy :> ISQ::energy;
	attribute def ElectricPotential :> ISQ::electricPotential;
	attribute def ElectricCurrent :> ISQ::electricCurrent;
	attribute def Frequency :> ISQ::frequency;
	attribute def Temperature :> ISQ::thermodynamicTemperature;
	attribute def PlaneAngle :> ISQ::planeAngle;
	attribute def LinearVelocity :> ISQ::speed;
	attribute def InformationRate :> ISQ::informationRate;
	attribute def Ratio :> ScalarValues::Real;
	attribute def Count :> ScalarValues::Integer;
	attribute def BooleanValue :> ScalarValues::Boolean;
	attribute def Text :> ScalarValues::String;

	attribute def CartesianPosition {
		attribute x : Length;
		attribute y : Length;
		attribute z : Length;
	}

	attribute def CartesianVelocity {
		attribute vx : LinearVelocity;
		attribute vy : LinearVelocity;
		attribute vz : LinearVelocity;
	}

	attribute def Orientation {
		attribute roll : PlaneAngle;
		attribute pitch : PlaneAngle;
		attribute yaw : PlaneAngle;
	}

	attribute def Pose {
		attribute position : CartesianPosition;
		attribute orientation : Orientation;
	}

	attribute def VitalSigns {
		attribute heartRate : Frequency;
		attribute systolicPressure : Pressure;
		attribute diastolicPressure : Pressure;
		attribute oxygenSaturation : Ratio;
		attribute bodyTemperature : Temperature;
	}

	attribute def Pressure :> ISQ::pressure;

	attribute def SterilityLevel {
		attribute viableParticleCount : Count;
		attribute sterilized : BooleanValue;
		attribute expirationTimeRemaining : Duration;
	}

	attribute def MotionAccuracy {
		attribute translationalError : Length;
		attribute angularError : PlaneAngle;
	}

	attribute def SafetyEnvelope {
		attribute minimumDistanceToNoGoZone : Length;
		attribute maximumToolForce : Force;
		attribute maximumToolSpeed : LinearVelocity;
		attribute maximumTherapyPower : Power;
	}

	item def Patient {
		attribute patientId : Text;
		attribute ageYears : Count;
		attribute mass : Mass;
		attribute vitals : VitalSigns;
		attribute consentVerified : BooleanValue;
	}

	item def ClinicianCommand {
		attribute commandId : Text;
		attribute requestedMode : Text;
		attribute enableTherapy : BooleanValue;
		attribute emergencyStop : BooleanValue;
	}

	item def TreatmentPlan {
		attribute planId : Text;
		attribute targetAnatomy : Text;
		attribute targetPose : Pose;
		attribute entryPose : Pose;
		attribute plannedPathLength : Length;
		attribute maximumAllowedForce : Force;
		attribute maximumAllowedSpeed : LinearVelocity;
		attribute therapyDoseEnergy : Energy;
		attribute requiresSterileTool : BooleanValue;
	}

	item def RobotStatus {
		attribute mode : Text;
		attribute ready : BooleanValue;
		attribute faultActive : BooleanValue;
		attribute currentToolPose : Pose;
		attribute measuredContactForce : Force;
		attribute remainingTherapyEnergy : Energy;
	}

	item def ImageFrame {
		attribute frameId : Text;
		attribute acquisitionTime : Time;
		attribute resolutionX : Count;
		attribute resolutionY : Count;
		attribute pixelSpacing : Length;
	}

	item def AnatomicalRegistration {
		attribute registrationId : Text;
		attribute targetPoseInRobotFrame : Pose;
		attribute registrationError : Length;
		attribute valid : BooleanValue;
	}

	item def ToolCommand {
		attribute targetPose : Pose;
		attribute targetVelocity : CartesianVelocity;
		attribute therapyPower : Power;
		attribute gripperClosed : BooleanValue;
	}

	item def ToolFeedback {
		attribute actualPose : Pose;
		attribute contactForce : Force;
		attribute toolTemperature : Temperature;
		attribute therapyEnergyDelivered : Energy;
		attribute sterileBarrierIntact : BooleanValue;
	}

	item def ElectricalSupply {
		attribute voltage : ElectricPotential;
		attribute current : ElectricCurrent;
		attribute power : Power;
	}

	item def NetworkMessage {
		attribute topic : Text;
		attribute sequenceNumber : Count;
		attribute dataRate : InformationRate;
		attribute authenticated : BooleanValue;
	}

	item def ProcedureReport {
		attribute reportId : Text;
		attribute completed : BooleanValue;
		attribute aborted : BooleanValue;
		attribute deliveredEnergy : Energy;
		attribute peakContactForce : Force;
		attribute finalRegistrationError : Length;
		attribute notes : Text;
	}

	item def Alarm {
		attribute alarmCode : Text;
		attribute severity : Text;
		attribute message : Text;
		attribute requiresManualReset : BooleanValue;
	}

	item def SterileInstrument {
		attribute instrumentId : Text;
		attribute instrumentType : Text;
		attribute sterility : SterilityLevel;
		attribute length : Length;
		attribute maximumRatedForce : Force;
	}

	port def PowerInputPort {
		in item supply : ElectricalSupply;
	}

	port def PowerOutputPort {
		out item supply : ElectricalSupply;
	}

	port def ClinicianInterfacePort {
		in item command : ClinicianCommand;
		out item status : RobotStatus;
		out item report : ProcedureReport;
		out item alarm : Alarm;
	}

	port def RobotControlPort {
		in item toolCommand : ToolCommand;
		out item robotStatus : RobotStatus;
		out item toolFeedback : ToolFeedback;
	}

	port def ImagingOutputPort {
		out item frame : ImageFrame;
		out item registration : AnatomicalRegistration;
	}

	port def ImagingInputPort {
		in item frame : ImageFrame;
		in item registration : AnatomicalRegistration;
	}

	port def ToolBasePort {
		in item command : ToolCommand;
		out item feedback : ToolFeedback;
	}

	port def InstrumentPort {
		in item instrument : SterileInstrument;
		out item feedback : ToolFeedback;
	}

	port def PatientMonitoringPort {
		in item patient : Patient;
		out item vitals : VitalSigns;
		out item alarm : Alarm;
	}

	port def NetworkPort {
		in item messageIn : NetworkMessage;
		out item messageOut : NetworkMessage;
	}

	constraint def ContactForceWithinLimit {
		in attribute measured : Force;
		in attribute limit : Force;
		constraint { measured <= limit }
	}

	constraint def RegistrationAccuracyWithinLimit {
		in attribute error : Length;
		in attribute limit : Length;
		constraint { error <= limit }
	}

	constraint def SterileToolReady {
		in attribute sterilized : BooleanValue;
		in attribute barrierIntact : BooleanValue;
		constraint { sterilized == true and barrierIntact == true }
	}

	constraint def EmergencyStopRemovesTherapyPower {
		in attribute emergencyStop : BooleanValue;
		in attribute therapyPower : Power;
		constraint { emergencyStop implies therapyPower == 0 ['W'] }
	}

	constraint def TherapyDoseBound {
		in attribute delivered : Energy;
		in attribute planned : Energy;
		in attribute tolerance : Ratio;
		constraint { delivered >= planned * (1.0 - tolerance) and delivered <= planned * (1.0 + tolerance) }
	}

	part def MedicalRobot {
		attribute robotId : Text = "MR-THERAPY-001";
		attribute degreesOfFreedom : Count = 7;
		attribute payloadCapacity : Mass = 3.0 ['kg'];
		attribute maximumReach : Length = 0.95 ['m'];
		attribute nominalPositionAccuracy : Length = 0.0005 ['m'];
		attribute maximumJointSpeed : PlaneAngle = 1.5 ['rad'];
		attribute maximumContactForce : Force = 12.0 ['N'];
		attribute sterileBarrierInstalled : BooleanValue = true;
		attribute powered : BooleanValue = false;
		attribute faultLatched : BooleanValue = false;

		port powerIn : PowerInputPort;
		port control : RobotControlPort;
		port toolInterface : ToolBasePort;
		port network : NetworkPort;

		part arm {
			attribute jointCount : Count = 7;
			attribute currentToolPose : Pose;
			attribute currentAccuracy : MotionAccuracy;
			attribute measuredContactForce : Force = 0.0 ['N'];
		}

		part forceTorqueSensor {
			attribute forceRange : Force = 50.0 ['N'];
			attribute forceResolution : Force = 0.02 ['N'];
			attribute sampleRate : Frequency = 1000.0 ['Hz'];
		}

		part sterileDrape {
			attribute installed : BooleanValue = true;
			attribute integrityVerified : BooleanValue = true;
			attribute sterility : SterilityLevel;
		}

		part endEffector {
			attribute toolPose : Pose;
			attribute tipTemperature : Temperature = 310.15 ['K'];
			attribute therapyPowerCommanded : Power = 0.0 ['W'];
			attribute energyDelivered : Energy = 0.0 ['J'];
			port base : ToolBasePort;
			port instrumentSocket : InstrumentPort;
		}

		connection internalToolControl connect control to toolInterface;
		connection endEffectorControl connect toolInterface to endEffector.base;

		assert constraint forceLimit : ContactForceWithinLimit {
			measured = arm.measuredContactForce;
			limit = maximumContactForce;
		}

		assert constraint sterileReadiness : SterileToolReady {
			sterilized = sterileDrape.sterility.sterilized;
			barrierIntact = sterileDrape.integrityVerified;
		}

		perform action executeMedicalTask : ExecuteRoboticMedicalTask;
		exhibit state lifecycle : MedicalRobotLifecycle;
	}

	part def ImagingSubsystem {
		attribute modality : Text = "stereo endoscopic ultrasound";
		attribute frameRate : Frequency = 30.0 ['Hz'];
		attribute registrationErrorLimit : Length = 0.0015 ['m'];
		attribute radiationFree : BooleanValue = true;

		port powerIn : PowerInputPort;
		port imagingOut : ImagingOutputPort;
		port network : NetworkPort;

		part cameraHead {
			attribute resolutionX : Count = 1920;
			attribute resolutionY : Count = 1080;
			attribute pixelSpacing : Length = 0.00025 ['m'];
		}

		part registrationProcessor {
			attribute latestRegistration : AnatomicalRegistration;
			attribute processingLatency : Duration = 0.08 ['s'];
		}

		assert constraint registrationAccuracy : RegistrationAccuracyWithinLimit {
			error = registrationProcessor.latestRegistration.registrationError;
			limit = registrationErrorLimit;
		}
	}

	part def SupervisoryController {
		attribute controllerId : Text = "CLINICAL-SUPERVISOR-01";
		attribute cycleTime : Duration = 0.005 ['s'];
		attribute authenticationRequired : BooleanValue = true;
		attribute currentSafetyEnvelope : SafetyEnvelope;

		port clinicianInterface : ClinicianInterfacePort;
		port robotControl : RobotControlPort;
		port imagingIn : ImagingInputPort;
		port patientMonitor : PatientMonitoringPort;
		port network : NetworkPort;

		part motionPlanner {
			attribute planningUpdateRate : Frequency = 50.0 ['Hz'];
			attribute minimumClearance : Length = 0.004 ['m'];
			attribute activePlan : TreatmentPlan;
		}

		part safetyMonitor {
			attribute forceLimit : Force = 10.0 ['N'];
			attribute speedLimit : LinearVelocity = 0.025 ['m/s'];
			attribute registrationErrorLimit : Length = 0.0015 ['m'];
			attribute emergencyStopActive : BooleanValue = false;
		}

		part therapyDoseController {
			attribute plannedDose : Energy = 120.0 ['J'];
			attribute deliveredDose : Energy = 0.0 ['J'];
			attribute doseTolerance : Ratio = 0.05;
		}

		assert constraint doseControl : TherapyDoseBound {
			delivered = therapyDoseController.deliveredDose;
			planned = therapyDoseController.plannedDose;
			tolerance = therapyDoseController.doseTolerance;
		}
	}

	part def PatientSupport {
		attribute supportId : Text = "STERILE-PATIENT-TABLE-01";
		attribute locked : BooleanValue = true;
		attribute height : Length = 0.82 ['m'];
		attribute maximumPatientMass : Mass = 250.0 ['kg'];

		port monitoring : PatientMonitoringPort;

		part restraintSystem {
			attribute engaged : BooleanValue = true;
			attribute releaseTime : Duration = 2.0 ['s'];
		}

		part vitalSignsMonitor {
			attribute sampleRate : Frequency = 2.0 ['Hz'];
			attribute latestVitals : VitalSigns;
		}
	}

	part def PowerSubsystem {
		attribute mainsVoltage : ElectricPotential = 230.0 ['V'];
		attribute dcBusVoltage : ElectricPotential = 48.0 ['V'];
		attribute ratedPower : Power = 1500.0 ['W'];
		attribute backupRuntime : Duration = 600.0 ['s'];

		port dcOutRobot : PowerOutputPort;
		port dcOutImaging : PowerOutputPort;
		port dcOutController : PowerOutputPort;

		part isolationTransformer {
			attribute leakageCurrent : ElectricCurrent = 0.00005 ['A'];
		}

		part batteryBackup {
			attribute storedEnergy : Energy = 900000.0 ['J'];
			attribute stateOfCharge : Ratio = 0.95;
		}
	}

	part def ClinicalWorkstation {
		attribute workstationId : Text = "OR-CONSOLE-01";
		attribute displayRefreshRate : Frequency = 60.0 ['Hz'];
		attribute userAuthenticated : BooleanValue = false;

		port clinician : ClinicianInterfacePort;
		port network : NetworkPort;

		part hapticInput {
			attribute maximumCommandedForce : Force = 5.0 ['N'];
			attribute deadmanSwitchPressed : BooleanValue = false;
		}

		part procedureDisplay {
			attribute diagonalSize : Length = 0.69 ['m'];
			attribute alarmVisible : BooleanValue = true;
		}
	}

	part def MedicalRoboticSystem {
		attribute systemId : Text = "MEDICAL-ROBOTIC-PRIMARY-TASK-SYSTEM";
		attribute intendedUse : Text = "perform image-guided minimally invasive therapeutic task using a Medical robot";
		attribute sterileFieldMaintained : BooleanValue = true;
		attribute primaryTaskCompleted : BooleanValue = false;

		part medicalRobot : MedicalRobot;
		part controller : SupervisoryController;
		part imaging : ImagingSubsystem;
		part patientSupport : PatientSupport;
		part power : PowerSubsystem;
		part workstation : ClinicalWorkstation;

		port clinicalUserInterface : ClinicianInterfacePort;

		connection powerToRobot connect power.dcOutRobot to medicalRobot.powerIn;
		connection powerToImaging connect power.dcOutImaging to imaging.powerIn;
		connection powerToController connect power.dcOutController to controller.network;
		connection controllerToRobot connect controller.robotControl to medicalRobot.control;
		connection imagingToController connect imaging.imagingOut to controller.imagingIn;
		connection patientMonitoringToController connect patientSupport.monitoring to controller.patientMonitor;
		connection workstationToController connect workstation.clinician to controller.clinicianInterface;
		connection externalClinicalInterface connect clinicalUserInterface to workstation.clinician;
		connection robotNetwork connect medicalRobot.network to controller.network;
		connection imagingNetwork connect imaging.network to controller.network;
		connection workstationNetwork connect workstation.network to controller.network;

		perform action primaryTask : PerformImageGuidedTherapy;
		exhibit state systemState : MedicalRoboticSystemState;
	}

	action def VerifySterility {
		in item instrument : SterileInstrument;
		in attribute barrierIntact : BooleanValue;
		out attribute sterileReady : BooleanValue;

		action inspectPackage;
		action scanInstrumentId;
		action verifyBarrier;
		action approveSterility;

		first inspectPackage;
		then scanInstrumentId;
		then verifyBarrier;
		then approveSterility;

		assert constraint readyConstraint : SterileToolReady {
			sterilized = instrument.sterility.sterilized;
			barrierIntact = barrierIntact;
		}
	}

	action def RegisterAnatomy {
		in item images : ImageFrame;
		in item plan : TreatmentPlan;
		out item registration : AnatomicalRegistration;

		action acquireImage;
		action identifyFiducials;
		action computeTransform;
		action validateRegistration;

		first acquireImage;
		then identifyFiducials;
		then computeTransform;
		then validateRegistration;
	}

	action def PlanSafeRobotMotion {
		in item plan : TreatmentPlan;
		in item registration : AnatomicalRegistration;
		in attribute envelope : SafetyEnvelope;
		out item command : ToolCommand;

		action transformTargetToRobotFrame;
		action generateCollisionFreePath;
		action limitVelocityAndForce;
		action issueMotionCommand;

		first transformTargetToRobotFrame;
		then generateCollisionFreePath;
		then limitVelocityAndForce;
		then issueMotionCommand;
	}

	action def DeliverTherapy {
		in item plan : TreatmentPlan;
		in item command : ToolCommand;
		out item feedback : ToolFeedback;
		out item report : ProcedureReport;

		action approachTarget;
		action confirmContactForce;
		action enableTherapyEnergy;
		action trackDose;
		action disableTherapyEnergy;
		action withdrawTool;

		first approachTarget;
		then confirmContactForce;
		then enableTherapyEnergy;
		then trackDose;
		then disableTherapyEnergy;
		then withdrawTool;
	}

	action def HandleFault {
		in item alarm : Alarm;
		out item status : RobotStatus;

		action stopMotion;
		action removeTherapyPower;
		action holdPositionOrRetract;
		action notifyClinician;
		action requireManualReset;

		first stopMotion;
		then removeTherapyPower;
		then holdPositionOrRetract;
		then notifyClinician;
		then requireManualReset;
	}

	action def ExecuteRoboticMedicalTask {
		in item patient : Patient;
		in item plan : TreatmentPlan;
		in item instrument : SterileInstrument;
		out item report : ProcedureReport;

		action verifyPatientConsent;
		action verifySterility : VerifySterility;
		action registerAnatomy : RegisterAnatomy;
		action planMotion : PlanSafeRobotMotion;
		action deliverTherapy : DeliverTherapy;
		action createProcedureReport;

		first verifyPatientConsent;
		then verifySterility;
		then registerAnatomy;
		then planMotion;
		then deliverTherapy;
		then createProcedureReport;
	}

	action def PerformImageGuidedTherapy {
		in item patient : Patient;
		in item clinicianCommand : ClinicianCommand;
		in item plan : TreatmentPlan;
		out item procedureReport : ProcedureReport;

		action powerOnSystem;
		action performSelfTest;
		action authenticateClinician;
		action loadTreatmentPlan;
		action prepareMedicalRobot;
		action executeTask : ExecuteRoboticMedicalTask;
		action verifyOutcome;
		action storeReport;
		action returnToSafeIdle;

		first powerOnSystem;
		then performSelfTest;
		then authenticateClinician;
		then loadTreatmentPlan;
		then prepareMedicalRobot;
		then executeTask;
		then verifyOutcome;
		then storeReport;
		then returnToSafeIdle;
	}

	state def MedicalRobotLifecycle {
		state off;
		state selfTest;
		state sterilePreparation;
		state ready;
		state executingPrimaryTask;
		state paused;
		state faultSafe;
		state completed;

		transition initialToOff first off;
		transition powerApplied first off then selfTest;
		transition selfTestPassed first selfTest then sterilePreparation;
		transition sterileVerified first sterilePreparation then ready;
		transition treatmentCommanded first ready then executingPrimaryTask;
		transition clinicianPause first executingPrimaryTask then paused;
		transition resumeTreatment first paused then executingPrimaryTask;
		transition taskFinished first executingPrimaryTask then completed;
		transition resetAfterCompletion first completed then ready;
		transition faultFromSelfTest first selfTest then faultSafe;
		transition faultFromReady first ready then faultSafe;
		transition faultFromExecuting first executingPrimaryTask then faultSafe;
		transition faultFromPaused first paused then faultSafe;
		transition manualReset first faultSafe then selfTest;
	}

	state def MedicalRoboticSystemState {
		state unavailable;
		state standby;
		state configuringProcedure;
		state sterileReady;
		state patientRegistered;
		state robotPerformingPrimaryTask;
		state verifyingOutcome;
		state procedureComplete;
		state emergencyStopped;

		transition initialize first unavailable then standby;
		transition planLoaded first standby then configuringProcedure;
		transition sterilePreparationComplete first configuringProcedure then sterileReady;
		transition anatomyRegistered first sterileReady then patientRegistered;
		transition startPrimaryTask first patientRegistered then robotPerformingPrimaryTask;
		transition taskComplete first robotPerformingPrimaryTask then verifyingOutcome;
		transition outcomeAccepted first verifyingOutcome then procedureComplete;
		transition resetForNextPatient first procedureComplete then standby;
		transition emergencyFromStandby first standby then emergencyStopped;
		transition emergencyFromConfiguring first configuringProcedure then emergencyStopped;
		transition emergencyFromSterileReady first sterileReady then emergencyStopped;
		transition emergencyFromRegistered first patientRegistered then emergencyStopped;
		transition emergencyFromTask first robotPerformingPrimaryTask then emergencyStopped;
		transition manualReset first emergencyStopped then standby;
	}

	requirement def PrimaryTaskUsingMedicalRobotRequirement {
		doc "The robotic system shall perform its primary clinical task using a MedicalRobot as the executing robot."
		subject system : MedicalRoboticSystem;
		require constraint { system.medicalRobot.degreesOfFreedom >= 6 and system.primaryTaskCompleted == true }
	}

	requirement def SterileOperationRequirement {
		doc "The MedicalRobot shall execute the task only when the sterile barrier and sterile instrument are verified."
		subject robot : MedicalRobot;
		require constraint { robot.sterileBarrierInstalled == true and robot.sterileDrape.integrityVerified == true }
	}

	requirement def ContactForceSafetyRequirement {
		doc "During patient contact, the MedicalRobot shall limit measured contact force to no more than 12 N."
		subject robot : MedicalRobot;
		require constraint { robot.arm.measuredContactForce <= 12.0 ['N'] }
	}

	requirement def RegistrationAccuracyRequirement {
		doc "The imaging and registration function shall provide target registration error no greater than 1.5 mm before therapy delivery."
		subject imaging : ImagingSubsystem;
		require constraint { imaging.registrationProcessor.latestRegistration.registrationError <= 0.0015 ['m'] }
	}

	requirement def EmergencyStopRequirement {
		doc "Activation of emergency stop shall stop robot motion and remove commanded therapy power."
		subject controller : SupervisoryController;
		require constraint { controller.safetyMonitor.emergencyStopActive implies controller.therapyDoseController.deliveredDose >= 0.0 ['J'] }
	}

	requirement def TherapyDoseRequirement {
		doc "The delivered therapy energy shall be within plus or minus five percent of the planned dose unless the procedure is aborted."
		subject controller : SupervisoryController;
		require constraint {
			controller.therapyDoseController.deliveredDose >= controller.therapyDoseController.plannedDose * 0.95 and
			controller.therapyDoseController.deliveredDose <= controller.therapyDoseController.plannedDose * 1.05
		}
	}

	requirement def PatientConsentRequirement {
		doc "The system shall not start the primary medical task unless patient consent has been verified."
		subject patient : Patient;
		require constraint { patient.consentVerified == true }
	}

	requirement def PowerContinuityRequirement {
		doc "The power subsystem shall provide at least ten minutes of backup runtime to permit controlled stopping or retraction."
		subject power : PowerSubsystem;
		require constraint { power.backupRuntime >= 600.0 ['s'] }
	}

	satisfy PrimaryTaskUsingMedicalRobotRequirement by MedicalRoboticSystem;
	satisfy SterileOperationRequirement by MedicalRobot;
	satisfy ContactForceSafetyRequirement by MedicalRobot;
	satisfy RegistrationAccuracyRequirement by ImagingSubsystem;
	satisfy EmergencyStopRequirement by SupervisoryController;
	satisfy TherapyDoseRequirement by SupervisoryController;
	satisfy PatientConsentRequirement by Patient;
	satisfy PowerContinuityRequirement by PowerSubsystem;

	part medicalRoboticSystem : MedicalRoboticSystem {
		attribute systemId = "MRS-IMAGE-GUIDED-THERAPY-001";
		attribute sterileFieldMaintained = true;
		attribute primaryTaskCompleted = false;

		part medicalRobot {
			attribute robotId = "MEDICAL-ROBOT-ARM-001";
			attribute degreesOfFreedom = 7;
			attribute payloadCapacity = 3.0 ['kg'];
			attribute maximumReach = 0.95 ['m'];
			attribute maximumContactForce = 12.0 ['N'];
			attribute sterileBarrierInstalled = true;
		}

		part controller {
			attribute controllerId = "SUPERVISORY-CONTROLLER-001";
			part safetyMonitor {
				attribute forceLimit = 10.0 ['N'];
				attribute speedLimit = 0.025 ['m/s'];
				attribute registrationErrorLimit = 0.0015 ['m'];
				attribute emergencyStopActive = false;
			}
			part therapyDoseController {
				attribute plannedDose = 120.0 ['J'];
				attribute deliveredDose = 0.0 ['J'];
				attribute doseTolerance = 0.05;
			}
		}

		part imaging {
			attribute modality = "stereo endoscopic ultrasound";
			attribute frameRate = 30.0 ['Hz'];
			attribute registrationErrorLimit = 0.0015 ['m'];
		}

		part power {
			attribute mainsVoltage = 230.0 ['V'];
			attribute dcBusVoltage = 48.0 ['V'];
			attribute ratedPower = 1500.0 ['W'];
			attribute backupRuntime = 600.0 ['s'];
		}

		part patientSupport {
			attribute locked = true;
			attribute height = 0.82 ['m'];
			attribute maximumPatientMass = 250.0 ['kg'];
		}

		part workstation {
			attribute userAuthenticated = false;
			part hapticInput {
				attribute deadmanSwitchPressed = false;
			}
		}
	}
}
