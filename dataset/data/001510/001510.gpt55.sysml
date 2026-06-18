package NanoroboticsTherapeuticSystemModel {

	import ScalarValues::*;
	import ISQ::*;
	import SI::*;

	attribute def NanometerLength :> ISQ::length;
	attribute def MicrometerLength :> ISQ::length;
	attribute def MillimeterLength :> ISQ::length;
	attribute def MilligramMass :> ISQ::mass;
	attribute def MicrogramMass :> ISQ::mass;
	attribute def NanowattPower :> ISQ::power;
	attribute def MillivoltVoltage :> ISQ::electricPotential;
	attribute def MillisecondTime :> ISQ::time;
	attribute def SecondTime :> ISQ::time;
	attribute def MoleConcentration :> ISQ::amountOfSubstanceConcentration;
	attribute def CelsiusTemperature :> ISQ::thermodynamicTemperature;
	attribute def PercentRatio :> ScalarValues::Real;
	attribute def CountValue :> ScalarValues::Integer;
	attribute def ProbabilityValue :> ScalarValues::Real;

	enum def MissionPhase {
		enum idle;
		enum initialized;
		enum deployed;
		enum navigating;
		enum targetSearching;
		enum targetValidated;
		enum treating;
		enum verifying;
		enum returning;
		enum biodegrading;
		enum completed;
		enum aborted;
	}

	enum def RobotHealthStatus {
		enum nominal;
		enum degraded;
		enum fouledSensor;
		enum lowEnergy;
		enum blockedLocomotion;
		enum payloadEmpty;
		enum unsafeEnvironment;
		enum lostCommunication;
		enum commandedShutdown;
	}

	enum def TargetCellClass {
		enum malignantCell;
		enum infectedCell;
		enum inflamedEndothelium;
		enum healthyCell;
		enum unknownCell;
	}

	enum def PayloadReleaseMode {
		enum none;
		enum contactInjection;
		enum membranePoratingDiffusion;
		enum enzymeTriggeredRelease;
		enum magneticTriggerRelease;
	}

	item def MissionCommand {
		attribute missionIdentifier: String;
		attribute requestedPhase: MissionPhase;
		attribute targetBiomarkerName: String;
		attribute targetSiteDescription: String;
		attribute maximumAllowedDose: MicrogramMass;
		attribute treatmentTimeLimit: SecondTime;
		attribute abortRequested: Boolean;
	}

	item def OperatorAcknowledgement {
		attribute accepted: Boolean;
		attribute reason: String;
		attribute assignedMissionIdentifier: String;
	}

	item def BioMarkerSignal {
		attribute biomarkerName: String;
		attribute concentration: MoleConcentration;
		attribute confidence: ProbabilityValue;
		attribute cellClassEstimate: TargetCellClass;
		attribute sampleAge: MillisecondTime;
	}

	item def TherapeuticPayload {
		attribute compoundName: String;
		attribute doseMass: MicrogramMass;
		attribute releaseMode: PayloadReleaseMode;
		attribute cytotoxicityIndex: PercentRatio;
		attribute encapsulated: Boolean;
	}

	item def DiagnosticImagePatch {
		attribute patchIdentifier: String;
		attribute width: MicrometerLength;
		attribute height: MicrometerLength;
		attribute resolution: NanometerLength;
		attribute targetProbability: ProbabilityValue;
	}

	item def NanoTelemetry {
		attribute robotIdentifier: String;
		attribute phase: MissionPhase;
		attribute health: RobotHealthStatus;
		attribute residualEnergy: PercentRatio;
		attribute payloadRemaining: MicrogramMass;
		attribute localTemperature: CelsiusTemperature;
		attribute lastBiomarkerConfidence: ProbabilityValue;
		attribute estimatedPositionError: MicrometerLength;
	}

	item def SwarmTelemetry {
		attribute missionIdentifier: String;
		attribute activeRobotCount: CountValue;
		attribute treatingRobotCount: CountValue;
		attribute completedRobotCount: CountValue;
		attribute abortedRobotCount: CountValue;
		attribute aggregateDeliveredDose: MicrogramMass;
		attribute aggregateTargetConfidence: ProbabilityValue;
	}

	item def EnergyPacket {
		attribute availablePower: NanowattPower;
		attribute voltage: MillivoltVoltage;
		attribute duration: MillisecondTime;
	}

	item def MolecularWaste {
		attribute moleculeName: String;
		attribute mass: MicrogramMass;
		attribute biodegradable: Boolean;
	}

	port def CommandPort {
		in item command: MissionCommand;
		out item acknowledgement: OperatorAcknowledgement;
	}

	port def TelemetryPort {
		out item telemetry: SwarmTelemetry;
	}

	port def NanoCommandPort {
		in item command: MissionCommand;
	}

	port def NanoTelemetryPort {
		out item telemetry: NanoTelemetry;
	}

	port def BiomarkerSamplingPort {
		in item sensedSignal: BioMarkerSignal;
	}

	port def PayloadTransferPort {
		in item payloadLoad: TherapeuticPayload;
		out item releasedPayload: TherapeuticPayload;
	}

	port def EnergyPort {
		in item receivedEnergy: EnergyPacket;
	}

	port def WastePort {
		out item degradationWaste: MolecularWaste;
	}

	port def CapsuleExitPort {
		out item releasedRobot: NanoRobot;
	}

	port def SwarmEntryPort {
		in item admittedRobot: NanoRobot;
	}

	part def OperatorConsole {
		attribute consoleIdentifier: String;
		attribute authorizedClinician: String;
		attribute commandLatencyLimit: MillisecondTime = 250;
		port commandLink: CommandPort;
	}

	part def ClinicalMissionPlanner {
		attribute missionIdentifier: String;
		attribute targetSiteDescription: String;
		attribute targetBiomarkerName: String;
		attribute maximumAllowedDose: MicrogramMass = 250;
		attribute plannedRobotCount: CountValue = 10000;
		attribute treatmentTimeLimit: SecondTime = 3600;
		port operatorCommandPort: CommandPort;
		port controllerCommandPort: CommandPort;
	}

	part def ExternalEnergyFieldGenerator {
		attribute generatorIdentifier: String;
		attribute nominalPowerDensity: NanowattPower = 500;
		attribute pulsePeriod: MillisecondTime = 100;
		attribute fieldEnabled: Boolean;
		port energyOutput: EnergyPort;
	}

	part def SwarmController {
		attribute controllerIdentifier: String;
		attribute missionPhase: MissionPhase = MissionPhase::idle;
		attribute commandedRobotCount: CountValue = 10000;
		attribute minimumActiveFraction: PercentRatio = 80.0;
		attribute aggregateDeliveredDose: MicrogramMass;
		attribute targetConfidenceThreshold: ProbabilityValue = 0.92;
		port commandInput: CommandPort;
		port swarmCommandOutput: NanoCommandPort;
		port swarmTelemetryInput: NanoTelemetryPort;
		port aggregateTelemetryOutput: TelemetryPort;
	}

	part def DeploymentCapsule {
		attribute capsuleIdentifier: String;
		attribute storedRobotCount: CountValue = 10000;
		attribute internalDiameter: MillimeterLength = 2.0;
		attribute shellThickness: MicrometerLength = 80.0;
		attribute dissolvingShell: Boolean = true;
		attribute releaseDelay: SecondTime = 60;
		port payloadLoadPort: PayloadTransferPort;
		port capsuleExit: CapsuleExitPort;
	}

	part def MolecularSensorArray {
		attribute receptorCount: CountValue = 512;
		attribute minimumDetectableConcentration: MoleConcentration;
		attribute falsePositiveProbability: ProbabilityValue = 0.01;
		attribute samplePeriod: MillisecondTime = 50;
		port biomarkerPort: BiomarkerSamplingPort;
	}

	part def LocomotionModule {
		attribute flagellarMotorCount: CountValue = 6;
		attribute maximumSpeed: MicrometerLength = 80;
		attribute minimumCapillaryClearance: MicrometerLength = 5;
		attribute magneticSteeringEnabled: Boolean = true;
		attribute blocked: Boolean = false;
	}

	part def NavigationProcessor {
		attribute processorIdentifier: String;
		attribute positionError: MicrometerLength = 25;
		attribute targetConfidenceThreshold: ProbabilityValue = 0.92;
		attribute safeTemperatureLimit: CelsiusTemperature = 39.5;
	}

	part def PayloadInjector {
		attribute injectorIdentifier: String;
		attribute needleDiameter: NanometerLength = 80;
		attribute payloadCapacity: MicrogramMass = 0.025;
		attribute payloadRemaining: MicrogramMass = 0.025;
		attribute releaseMode: PayloadReleaseMode = PayloadReleaseMode::contactInjection;
		port payloadPort: PayloadTransferPort;
	}

	part def PowerHarvester {
		attribute storageCapacity: NanowattPower = 1200;
		attribute residualEnergy: PercentRatio = 100.0;
		attribute minimumOperatingEnergy: PercentRatio = 15.0;
		port energyInput: EnergyPort;
	}

	part def NanoCommunicationTransceiver {
		attribute carrierFrequencyDescription: String = "ultrasonic molecular-acoustic hybrid link";
		attribute maximumRange: MillimeterLength = 25;
		attribute packetPeriod: MillisecondTime = 500;
		port commandInput: NanoCommandPort;
		port telemetryOutput: NanoTelemetryPort;
	}

	part def BiodegradationModule {
		attribute enzymaticLatchEnabled: Boolean = true;
		attribute maximumPersistenceTime: SecondTime = 7200;
		attribute degradationComplete: Boolean = false;
		port wasteOutput: WastePort;
	}

	part def NanoRobot {
		attribute robotIdentifier: String;
		attribute length: MicrometerLength = 1.2;
		attribute diameter: NanometerLength = 800;
		attribute dryMass: MicrogramMass = 0.00002;
		attribute currentPhase: MissionPhase = MissionPhase::idle;
		attribute health: RobotHealthStatus = RobotHealthStatus::nominal;
		attribute targetCellClass: TargetCellClass = TargetCellClass::unknownCell;
		attribute deliveredDose: MicrogramMass = 0.0;

		part sensors: MolecularSensorArray;
		part locomotion: LocomotionModule;
		part navigation: NavigationProcessor;
		part injector: PayloadInjector;
		part harvester: PowerHarvester;
		part transceiver: NanoCommunicationTransceiver;
		part biodegradation: BiodegradationModule;

		port commandPort: NanoCommandPort;
		port telemetryPort: NanoTelemetryPort;
		port biomarkerPort: BiomarkerSamplingPort;
		port energyPort: EnergyPort;
		port payloadPort: PayloadTransferPort;
		port wastePort: WastePort;

		connect commandPort to transceiver.commandInput;
		connect transceiver.telemetryOutput to telemetryPort;
		connect biomarkerPort to sensors.biomarkerPort;
		connect energyPort to harvester.energyInput;
		connect payloadPort to injector.payloadPort;
		connect biodegradation.wasteOutput to wastePort;
	}

	part def NanoRobotSwarm {
		attribute swarmIdentifier: String;
		attribute nominalRobotCount: CountValue = 10000;
		attribute activeRobotCount: CountValue = 10000;
		attribute maximumAggregateDose: MicrogramMass = 250;
		attribute aggregateDeliveredDose: MicrogramMass = 0.0;
		attribute aggregateTargetConfidence: ProbabilityValue = 0.0;

		part robots[10000]: NanoRobot;

		port swarmCommandPort: NanoCommandPort;
		port swarmTelemetryPort: NanoTelemetryPort;
		port entryPort: SwarmEntryPort;
		port swarmEnergyPort: EnergyPort;
		port swarmWastePort: WastePort;

		connect swarmCommandPort to robots.commandPort;
		connect robots.telemetryPort to swarmTelemetryPort;
		connect swarmEnergyPort to robots.energyPort;
		connect robots.wastePort to swarmWastePort;
	}

	part def PatientTargetRegion {
		attribute regionName: String = "vascularized tumor margin";
		attribute approximateDiameter: MillimeterLength = 8.0;
		attribute targetBiomarkerName: String = "EGFRvIII";
		attribute expectedBiomarkerConcentration: MoleConcentration;
		attribute maximumSafeLocalTemperature: CelsiusTemperature = 39.5;
		port biomarkerOutput: BiomarkerSamplingPort;
		port payloadInput: PayloadTransferPort;
	}

	part def NanoroboticsTherapeuticSystem {
		attribute systemIdentifier: String = "NRTS-Targeted-Cellular-Intervention";
		attribute primaryFunction: String = "Autonomously navigate nanoscale robots through a biological environment, recognize diseased cells by molecular biomarkers, deliver a controlled therapeutic payload locally, report mission status, and safely biodegrade after treatment.";
		attribute missionPhase: MissionPhase = MissionPhase::idle;
		attribute commandedDoseLimit: MicrogramMass = 250;
		attribute minimumTargetRecognitionConfidence: ProbabilityValue = 0.92;
		attribute maximumRobotPersistenceTime: SecondTime = 7200;

		part console: OperatorConsole;
		part planner: ClinicalMissionPlanner;
		part controller: SwarmController;
		part energyField: ExternalEnergyFieldGenerator;
		part capsule: DeploymentCapsule;
		part swarm: NanoRobotSwarm;
		part targetRegion: PatientTargetRegion;

		port operatorPort: CommandPort;
		port telemetryPort: TelemetryPort;
		port energyPort: EnergyPort;
		port wastePort: WastePort;

		connect operatorPort to console.commandLink;
		connect console.commandLink to planner.operatorCommandPort;
		connect planner.controllerCommandPort to controller.commandInput;
		connect controller.swarmCommandOutput to swarm.swarmCommandPort;
		connect swarm.swarmTelemetryPort to controller.swarmTelemetryInput;
		connect controller.aggregateTelemetryOutput to telemetryPort;
		connect energyField.energyOutput to swarm.swarmEnergyPort;
		connect capsule.capsuleExit to swarm.entryPort;
		connect targetRegion.biomarkerOutput to swarm.robots.biomarkerPort;
		connect swarm.robots.payloadPort to targetRegion.payloadInput;
		connect swarm.swarmWastePort to wastePort;
	}

	action def PlanMission {
		in targetSiteDescription: String;
		in targetBiomarkerName: String;
		in requestedDoseLimit: MicrogramMass;
		out command: MissionCommand;

		assign command.missionIdentifier := "MISSION-NANO-001";
		assign command.requestedPhase := MissionPhase::initialized;
		assign command.targetBiomarkerName := targetBiomarkerName;
		assign command.targetSiteDescription := targetSiteDescription;
		assign command.maximumAllowedDose := requestedDoseLimit;
		assign command.treatmentTimeLimit := 3600;
		assign command.abortRequested := false;
	}

	action def DeployNanoRobots {
		in command: MissionCommand;
		in capsuleRobotCount: CountValue;
		out deployedRobotCount: CountValue;

		assign deployedRobotCount := capsuleRobotCount;
	}

	action def SenseBiomarkers {
		in sensedSignal: BioMarkerSignal;
		in confidenceThreshold: ProbabilityValue;
		out targetConfirmed: Boolean;
		out estimatedCellClass: TargetCellClass;

		assign estimatedCellClass := sensedSignal.cellClassEstimate;
		assign targetConfirmed := sensedSignal.confidence >= confidenceThreshold and sensedSignal.cellClassEstimate != TargetCellClass::healthyCell;
	}

	action def NavigateToTarget {
		in command: MissionCommand;
		in residualEnergy: PercentRatio;
		out continueNavigation: Boolean;

		assign continueNavigation := residualEnergy > 15.0 and command.abortRequested == false;
	}

	action def DeliverTherapeuticPayload {
		in targetConfirmed: Boolean;
		in doseLimit: MicrogramMass;
		in payloadAvailable: MicrogramMass;
		out deliveredDose: MicrogramMass;
		out releaseMode: PayloadReleaseMode;

		assign releaseMode := PayloadReleaseMode::contactInjection;
		assign deliveredDose := if targetConfirmed and payloadAvailable <= doseLimit then payloadAvailable else 0.0;
	}

	action def ReportSwarmStatus {
		in robotTelemetry: NanoTelemetry;
		out swarmTelemetry: SwarmTelemetry;

		assign swarmTelemetry.missionIdentifier := "MISSION-NANO-001";
		assign swarmTelemetry.activeRobotCount := 10000;
		assign swarmTelemetry.treatingRobotCount := if robotTelemetry.phase == MissionPhase::treating then 1 else 0;
		assign swarmTelemetry.completedRobotCount := if robotTelemetry.phase == MissionPhase::completed then 1 else 0;
		assign swarmTelemetry.abortedRobotCount := if robotTelemetry.phase == MissionPhase::aborted then 1 else 0;
		assign swarmTelemetry.aggregateDeliveredDose := robotTelemetry.payloadRemaining;
		assign swarmTelemetry.aggregateTargetConfidence := robotTelemetry.lastBiomarkerConfidence;
	}

	action def InitiateSafeBiodegradation {
		in missionComplete: Boolean;
		in persistenceTimeExceeded: Boolean;
		out waste: MolecularWaste;

		assign waste.moleculeName := "biocompatible polymer fragments and inert metallic ions";
		assign waste.mass := 0.00002;
		assign waste.biodegradable := missionComplete or persistenceTimeExceeded;
	}

	action def ExecuteTargetedCellularIntervention {
		in command: MissionCommand;
		in biomarkerSignal: BioMarkerSignal;
		in energy: EnergyPacket;
		out telemetry: SwarmTelemetry;
		out waste: MolecularWaste;

		action deploy: DeployNanoRobots {
			in command = command;
			in capsuleRobotCount = 10000;
		}

		action navigate: NavigateToTarget {
			in command = command;
			in residualEnergy = 100.0;
		}

		action sense: SenseBiomarkers {
			in sensedSignal = biomarkerSignal;
			in confidenceThreshold = 0.92;
		}

		action treat: DeliverTherapeuticPayload {
			in targetConfirmed = sense.targetConfirmed;
			in doseLimit = command.maximumAllowedDose;
			in payloadAvailable = 0.025;
		}

		action degrade: InitiateSafeBiodegradation {
			in missionComplete = treat.deliveredDose > 0.0;
			in persistenceTimeExceeded = false;
		}

		action report: ReportSwarmStatus {
			in robotTelemetry.robotIdentifier = "NANOROBOT-0001";
			in robotTelemetry.phase = if treat.deliveredDose > 0.0 then MissionPhase::completed else MissionPhase::aborted;
			in robotTelemetry.health = RobotHealthStatus::nominal;
			in robotTelemetry.residualEnergy = 75.0;
			in robotTelemetry.payloadRemaining = 0.025 - treat.deliveredDose;
			in robotTelemetry.localTemperature = 37.0;
			in robotTelemetry.lastBiomarkerConfidence = biomarkerSignal.confidence;
			in robotTelemetry.estimatedPositionError = 25;
		}

		assign telemetry := report.swarmTelemetry;
		assign waste := degrade.waste;
	}

	state def NanoRobotMissionStateMachine {
		attribute phase: MissionPhase;
		attribute health: RobotHealthStatus;
		attribute residualEnergy: PercentRatio;
		attribute payloadRemaining: MicrogramMass;
		attribute targetConfidence: ProbabilityValue;
		attribute abortRequested: Boolean;

		state idle;
		state initialized;
		state deployed;
		state navigating;
		state targetSearching;
		state targetValidated;
		state treating;
		state verifying;
		state returning;
		state biodegrading;
		state completed;
		state aborted;

		transition initial then idle;

		transition initialize
			first idle
			then initialized
			if abortRequested == false;

		transition deploy
			first initialized
			then deployed
			if residualEnergy > 15.0;

		transition beginNavigation
			first deployed
			then navigating
			if health == RobotHealthStatus::nominal;

		transition searchForTarget
			first navigating
			then targetSearching
			if residualEnergy > 15.0;

		transition validateTarget
			first targetSearching
			then targetValidated
			if targetConfidence >= 0.92;

		transition rejectHealthyCell
			first targetSearching
			then navigating
			if targetConfidence < 0.92;

		transition releasePayload
			first targetValidated
			then treating
			if payloadRemaining > 0.0;

		transition verifyTreatment
			first treating
			then verifying;

		transition returnAfterVerification
			first verifying
			then returning
			if residualEnergy > 20.0;

		transition biodegradeAfterTreatment
			first returning
			then biodegrading;

		transition finishMission
			first biodegrading
			then completed;

		transition abortForLowEnergy
			first navigating
			then aborted
			if residualEnergy <= 15.0;

		transition abortForUnsafeHealth
			first targetSearching
			then aborted
			if health == RobotHealthStatus::unsafeEnvironment or health == RobotHealthStatus::lostCommunication;

		transition commandedAbort
			first initialized
			then aborted
			if abortRequested == true;
	}

	constraint def DoseWithinLimit {
		in deliveredDose: MicrogramMass;
		in commandedDoseLimit: MicrogramMass;
		deliveredDose <= commandedDoseLimit
	}

	constraint def TargetRecognitionConfidenceAcceptable {
		in confidence: ProbabilityValue;
		in threshold: ProbabilityValue;
		confidence >= threshold
	}

	constraint def SafeThermalOperation {
		in measuredTemperature: CelsiusTemperature;
		in maximumSafeTemperature: CelsiusTemperature;
		measuredTemperature <= maximumSafeTemperature
	}

	constraint def EnergyAdequateForOperation {
		in residualEnergy: PercentRatio;
		in minimumEnergy: PercentRatio;
		residualEnergy > minimumEnergy
	}

	constraint def PersistenceTimeLimited {
		in elapsedMissionTime: SecondTime;
		in maximumPersistenceTime: SecondTime;
		elapsedMissionTime <= maximumPersistenceTime
	}

	requirement def PrimaryFunctionRequirement {
		subject system: NanoroboticsTherapeuticSystem;
		attribute id: String = "NRTS-REQ-001";
		attribute text: String = "The nanorobotics system shall perform targeted cellular intervention by navigating nanoscale robots through a biological environment, identifying diseased cells using molecular biomarker recognition, delivering a controlled therapeutic payload locally, transmitting mission telemetry, and biodegrading safely after treatment.";
	}

	requirement def TargetRecognitionRequirement {
		subject robot: NanoRobot;
		attribute id: String = "NRTS-REQ-002";
		attribute text: String = "Each nanorobot shall classify a target cell as treatable only when the biomarker recognition confidence is at least 0.92 and the estimated cell class is not healthy.";
		require constraint TargetRecognitionConfidenceAcceptable {
			in confidence = robot.sensors.falsePositiveProbability;
			in threshold = 0.92;
		}
	}

	requirement def DoseSafetyRequirement {
		subject system: NanoroboticsTherapeuticSystem;
		attribute id: String = "NRTS-REQ-003";
		attribute text: String = "The aggregate therapeutic dose delivered by the swarm shall not exceed the clinician-commanded dose limit.";
		require constraint DoseWithinLimit {
			in deliveredDose = system.swarm.aggregateDeliveredDose;
			in commandedDoseLimit = system.commandedDoseLimit;
		}
	}

	requirement def ThermalSafetyRequirement {
		subject system: NanoroboticsTherapeuticSystem;
		attribute id: String = "NRTS-REQ-004";
		attribute text: String = "The system shall maintain local tissue temperature at or below the maximum safe temperature during sensing, locomotion, communication, and payload delivery.";
		require constraint SafeThermalOperation {
			in measuredTemperature = 37.0;
			in maximumSafeTemperature = system.targetRegion.maximumSafeLocalTemperature;
		}
	}

	requirement def EnergyRequirement {
		subject robot: NanoRobot;
		attribute id: String = "NRTS-REQ-005";
		attribute text: String = "A nanorobot shall continue autonomous navigation only when residual stored energy exceeds the minimum operating energy threshold.";
		require constraint EnergyAdequateForOperation {
			in residualEnergy = robot.harvester.residualEnergy;
			in minimumEnergy = robot.harvester.minimumOperatingEnergy;
		}
	}

	requirement def BiodegradationRequirement {
		subject robot: NanoRobot;
		attribute id: String = "NRTS-REQ-006";
		attribute text: String = "Each nanorobot shall enter safe biodegradation after mission completion, commanded shutdown, or expiration of maximum persistence time.";
		require constraint PersistenceTimeLimited {
			in elapsedMissionTime = 7200;
			in maximumPersistenceTime = robot.biodegradation.maximumPersistenceTime;
		}
	}

	requirement def TelemetryRequirement {
		subject system: NanoroboticsTherapeuticSystem;
		attribute id: String = "NRTS-REQ-007";
		attribute text: String = "The system shall provide aggregate swarm telemetry including active robot count, treatment count, delivered dose, target confidence, and abort count to the operator interface.";
	}

	part therapeuticNanoroboticsSystem: NanoroboticsTherapeuticSystem {
		attribute systemIdentifier = "NRTS-001";
		attribute missionPhase = MissionPhase::idle;
		attribute commandedDoseLimit = 250;
		attribute minimumTargetRecognitionConfidence = 0.92;
		attribute maximumRobotPersistenceTime = 7200;

		part console {
			attribute consoleIdentifier = "CLINICAL-CONSOLE-01";
			attribute authorizedClinician = "authorized interventional oncologist";
			attribute commandLatencyLimit = 250;
		}

		part planner {
			attribute missionIdentifier = "MISSION-NANO-001";
			attribute targetSiteDescription = "vascularized tumor margin adjacent to abnormal EGFRvIII expression";
			attribute targetBiomarkerName = "EGFRvIII";
			attribute maximumAllowedDose = 250;
			attribute plannedRobotCount = 10000;
			attribute treatmentTimeLimit = 3600;
		}

		part controller {
			attribute controllerIdentifier = "SWARM-CONTROLLER-01";
			attribute missionPhase = MissionPhase::idle;
			attribute commandedRobotCount = 10000;
			attribute minimumActiveFraction = 80.0;
			attribute targetConfidenceThreshold = 0.92;
		}

		part energyField {
			attribute generatorIdentifier = "EXTERNAL-FIELD-01";
			attribute nominalPowerDensity = 500;
			attribute pulsePeriod = 100;
			attribute fieldEnabled = true;
		}

		part capsule {
			attribute capsuleIdentifier = "DEPLOYMENT-CAPSULE-01";
			attribute storedRobotCount = 10000;
			attribute internalDiameter = 2.0;
			attribute shellThickness = 80.0;
			attribute dissolvingShell = true;
			attribute releaseDelay = 60;
		}

		part swarm {
			attribute swarmIdentifier = "THERAPEUTIC-SWARM-01";
			attribute nominalRobotCount = 10000;
			attribute activeRobotCount = 10000;
			attribute maximumAggregateDose = 250;
			attribute aggregateDeliveredDose = 0.0;
			attribute aggregateTargetConfidence = 0.0;
		}

		part targetRegion {
			attribute regionName = "vascularized tumor margin";
			attribute approximateDiameter = 8.0;
			attribute targetBiomarkerName = "EGFRvIII";
			attribute maximumSafeLocalTemperature = 39.5;
		}
	}

	satisfy PrimaryFunctionRequirement by therapeuticNanoroboticsSystem;
	satisfy DoseSafetyRequirement by therapeuticNanoroboticsSystem;
	satisfy ThermalSafetyRequirement by therapeuticNanoroboticsSystem;
	satisfy TelemetryRequirement by therapeuticNanoroboticsSystem;
}
