package EthicalPrimaryTaskRobotModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Probability :> Real {
        constraint range { self >= 0.0 and self <= 1.0 }
    }

    attribute def RiskScore :> Real {
        constraint range { self >= 0.0 and self <= 10.0 }
    }

    attribute def TrustScore :> Real {
        constraint range { self >= 0.0 and self <= 1.0 }
    }

    attribute def Distance :> LengthValue;
    attribute def Speed :> SpeedValue;
    attribute def Acceleration :> AccelerationValue;
    attribute def Duration :> TimeValue;
    attribute def Mass :> MassValue;
    attribute def Energy :> EnergyValue;
    attribute def Power :> PowerValue;
    attribute def Voltage :> ElectricPotentialValue;
    attribute def Current :> ElectricCurrentValue;
    attribute def Temperature :> ThermodynamicTemperatureValue;

    enum def TaskKind {
        enum medicationDelivery;
        enum objectRetrieval;
        enum welfareCheck;
        enum emergencyAssistance;
    }

    enum def EthicalPrincipleKind {
        enum humanSafety;
        enum humanAutonomy;
        enum privacy;
        enum transparency;
        enum fairness;
        enum accountability;
        enum taskBeneficence;
        enum nonDeception;
    }

    enum def RiskLevel {
        enum negligible;
        enum low;
        enum moderate;
        enum high;
        enum unacceptable;
    }

    enum def DecisionKind {
        enum permit;
        enum permitWithMitigation;
        enum deferToHuman;
        enum refuse;
        enum emergencyStop;
    }

    enum def RobotMode {
        enum poweredOff;
        enum standby;
        enum acceptingTask;
        enum ethicalAssessment;
        enum planning;
        enum navigating;
        enum interacting;
        enum manipulating;
        enum completingTask;
        enum blockedForEthics;
        enum safeStop;
        enum charging;
        enum fault;
    }

    item def HumanIdentity {
        attribute personId: String;
        attribute declaredName: String;
        attribute verifiedConfidence: Probability;
        attribute consentRecorded: Boolean;
    }

    item def LocationEstimate {
        attribute x: Distance = 0.0 [m];
        attribute y: Distance = 0.0 [m];
        attribute z: Distance = 0.0 [m];
        attribute covarianceRadius: Distance = 0.05 [m];
        attribute timestamp: Duration;
    }

    item def PoseEstimate {
        attribute location: LocationEstimate;
        attribute yaw: Real = 0.0;
        attribute pitch: Real = 0.0;
        attribute roll: Real = 0.0;
    }

    item def ObstacleReport {
        attribute obstacleId: String;
        attribute obstacleClass: String;
        attribute nearestDistance: Distance;
        attribute relativeSpeed: Speed;
        attribute humanLikely: Boolean;
        attribute riskLevel: RiskLevel;
    }

    item def HumanContext {
        attribute nearestHumanDistance: Distance;
        attribute nearestHumanVelocity: Speed;
        attribute vulnerablePersonDetected: Boolean;
        attribute personInPath: Boolean;
        attribute distressProbability: Probability;
        attribute consentToInteract: Boolean;
        attribute requestedPrivacy: Boolean;
    }

    item def MedicationPackage {
        attribute medicationId: String;
        attribute medicationName: String;
        attribute prescribedRecipientId: String;
        attribute doseMass: Mass;
        attribute storageTemperatureMin: Temperature = 278.15 [K];
        attribute storageTemperatureMax: Temperature = 298.15 [K];
        attribute controlledSubstance: Boolean;
    }

    item def TaskIntent {
        attribute taskId: String;
        attribute kind: TaskKind;
        attribute requesterId: String;
        attribute intendedRecipientId: String;
        attribute targetLocation: LocationEstimate;
        attribute latestCompletionTime: Duration;
        attribute requiresPhysicalContact: Boolean;
        attribute payloadDescription: String;
    }

    item def TaskStep {
        attribute stepId: String;
        attribute description: String;
        attribute expectedDuration: Duration;
        attribute requiresMotion: Boolean;
        attribute requiresManipulation: Boolean;
        attribute requiresHumanConsent: Boolean;
        attribute minimumSafeSeparation: Distance = 0.60 [m];
    }

    item def EthicalPrinciple {
        attribute kind: EthicalPrincipleKind;
        attribute priority: Integer;
        attribute weight: Real;
        attribute active: Boolean;
    }

    item def EthicalAssessment {
        attribute taskId: String;
        attribute physicalHarmRisk: RiskScore;
        attribute autonomyViolationRisk: RiskScore;
        attribute privacyRisk: RiskScore;
        attribute fairnessRisk: RiskScore;
        attribute deceptionRisk: RiskScore;
        attribute taskBenefit: RiskScore;
        attribute combinedRisk: RiskScore;
        attribute riskLevel: RiskLevel;
        attribute mitigationText: String;
    }

    item def EthicalDecision {
        attribute taskId: String;
        attribute stepId: String;
        attribute decision: DecisionKind;
        attribute permitted: Boolean;
        attribute maximumAllowedSpeed: Speed;
        attribute minimumSeparation: Distance;
        attribute explanation: String;
        attribute requiresHumanConfirmation: Boolean;
        attribute auditRecordId: String;
    }

    item def DriveCommand {
        attribute targetLinearSpeed: Speed;
        attribute targetAngularSpeed: Real;
        attribute maximumAcceleration: Acceleration;
        attribute stopNow: Boolean;
    }

    item def MotionStatus {
        attribute currentSpeed: Speed;
        attribute currentAcceleration: Acceleration;
        attribute brakeEngaged: Boolean;
        attribute tractionFault: Boolean;
    }

    item def ArmCommand {
        attribute targetX: Distance;
        attribute targetY: Distance;
        attribute targetZ: Distance;
        attribute gripperForce: Real;
        attribute maximumEndEffectorSpeed: Speed;
        attribute releaseObject: Boolean;
    }

    item def ManipulatorStatus {
        attribute carryingPayload: Boolean;
        attribute payloadMass: Mass;
        attribute endEffectorSpeed: Speed;
        attribute contactDetected: Boolean;
        attribute forceLimitExceeded: Boolean;
    }

    item def SpeechMessage {
        attribute text: String;
        attribute language: String = "en";
        attribute containsPersonalData: Boolean;
        attribute urgency: RiskLevel;
    }

    item def ConsentResponse {
        attribute personId: String;
        attribute consentGranted: Boolean;
        attribute confidence: Probability;
        attribute timestamp: Duration;
    }

    item def SensorFrame {
        attribute frameId: String;
        attribute timestamp: Duration;
        attribute containsHumanData: Boolean;
        attribute privacyFiltered: Boolean;
    }

    item def BatteryStatus {
        attribute stateOfCharge: Probability;
        attribute voltage: Voltage;
        attribute current: Current;
        attribute remainingEnergy: Energy;
        attribute temperature: Temperature;
        attribute safeToOperate: Boolean;
    }

    item def AuditRecord {
        attribute recordId: String;
        attribute taskId: String;
        attribute stepId: String;
        attribute decision: DecisionKind;
        attribute assessmentSummary: String;
        attribute humanReadableExplanation: String;
        attribute timestamp: Duration;
        attribute retainedPersonalData: Boolean;
    }

    item def TaskReport {
        attribute taskId: String;
        attribute completed: Boolean;
        attribute ethicallyCompleted: Boolean;
        attribute deliveredToVerifiedRecipient: Boolean;
        attribute abortedReason: String;
        attribute auditRecordCount: Integer;
    }

    port def TaskRequestPort {
        in item request: TaskIntent;
        out item report: TaskReport;
    }

    port def HumanInteractionPort {
        out item message: SpeechMessage;
        in item consent: ConsentResponse;
        in item humanIdentity: HumanIdentity;
    }

    port def SensorOutputPort {
        out item frame: SensorFrame;
        out item pose: PoseEstimate;
        out item obstacle: ObstacleReport;
        out item humanContext: HumanContext;
    }

    port def PerceptionInputPort {
        in item frame: SensorFrame;
        in item pose: PoseEstimate;
        in item obstacle: ObstacleReport;
        in item humanContext: HumanContext;
    }

    port def PlannerEthicsPort {
        out item intent: TaskIntent;
        out item proposedStep: TaskStep;
        in item decision: EthicalDecision;
    }

    port def EthicsContextPort {
        in item intent: TaskIntent;
        in item proposedStep: TaskStep;
        in item context: HumanContext;
        in item batteryStatus: BatteryStatus;
        out item assessment: EthicalAssessment;
        out item decision: EthicalDecision;
    }

    port def MotionCommandPort {
        in item command: DriveCommand;
        out item status: MotionStatus;
    }

    port def ArmCommandPort {
        in item command: ArmCommand;
        out item status: ManipulatorStatus;
    }

    port def PowerPort {
        out item batteryStatus: BatteryStatus;
    }

    port def AuditPort {
        in item decision: EthicalDecision;
        in item assessment: EthicalAssessment;
        out item record: AuditRecord;
    }

    part def BatteryPack {
        attribute nominalVoltage: Voltage = 48.0 [V];
        attribute capacity: Energy = 1800000.0 [J];
        attribute maximumContinuousPower: Power = 650.0 [W];
        attribute minimumSafeCharge: Probability = 0.18;
        attribute maximumSafeTemperature: Temperature = 323.15 [K];

        port powerStatus: PowerPort;

        state def BatteryStateMachine {
            state normal;
            state lowEnergy;
            state unsafeTemperature;
            state unavailable;

            transition first normal;
            transition normal then lowEnergy if powerStatus.batteryStatus.stateOfCharge < minimumSafeCharge;
            transition lowEnergy then normal if powerStatus.batteryStatus.stateOfCharge >= minimumSafeCharge;
            transition normal then unsafeTemperature if powerStatus.batteryStatus.temperature > maximumSafeTemperature;
            transition lowEnergy then unsafeTemperature if powerStatus.batteryStatus.temperature > maximumSafeTemperature;
            transition unsafeTemperature then unavailable if powerStatus.batteryStatus.safeToOperate == false;
        }
    }

    part def MobilityBase {
        attribute maximumSpeed: Speed = 1.20 [m/s];
        attribute ethicalDefaultSpeed: Speed = 0.50 [m/s];
        attribute emergencyStoppingDistance: Distance = 0.25 [m];
        attribute maximumAcceleration: Acceleration = 0.80 [m/s^2];
        attribute wheelRadius: Distance = 0.075 [m];

        port motion: MotionCommandPort;

        action def ExecuteMotionCommand {
            in item command: DriveCommand;
            out item status: MotionStatus;
            constraint speedLimited { command.targetLinearSpeed <= maximumSpeed }
            constraint accelerationLimited { command.maximumAcceleration <= maximumAcceleration }
        }

        state def MobilityStateMachine {
            state stopped;
            state moving;
            state braking;
            state faulted;

            transition first stopped;
            transition stopped then moving if motion.command.stopNow == false and motion.command.targetLinearSpeed > 0.0 [m/s];
            transition moving then braking if motion.command.stopNow == true;
            transition braking then stopped if motion.status.currentSpeed == 0.0 [m/s];
            transition moving then faulted if motion.status.tractionFault == true;
            transition stopped then faulted if motion.status.tractionFault == true;
        }
    }

    part def ManipulatorArm {
        attribute reach: Distance = 0.70 [m];
        attribute payloadLimit: Mass = 2.00 [kg];
        attribute ethicalForceLimit: Real = 12.0;
        attribute maximumEndEffectorSpeed: Speed = 0.25 [m/s];

        port arm: ArmCommandPort;

        action def ExecuteArmCommand {
            in item command: ArmCommand;
            out item status: ManipulatorStatus;
            constraint speedLimited { command.maximumEndEffectorSpeed <= maximumEndEffectorSpeed }
            constraint payloadLimited { status.payloadMass <= payloadLimit }
            constraint stopOnUnexpectedContact { status.contactDetected implies command.maximumEndEffectorSpeed <= 0.05 [m/s] }
        }

        state def ManipulatorStateMachine {
            state stowed;
            state reaching;
            state grasping;
            state carrying;
            state releasing;
            state safeHold;

            transition first stowed;
            transition stowed then reaching if arm.command.releaseObject == false;
            transition reaching then grasping if arm.command.gripperForce > 0.0;
            transition grasping then carrying if arm.status.carryingPayload == true;
            transition carrying then releasing if arm.command.releaseObject == true;
            transition releasing then stowed if arm.status.carryingPayload == false;
            transition reaching then safeHold if arm.status.forceLimitExceeded == true;
            transition carrying then safeHold if arm.status.forceLimitExceeded == true;
        }
    }

    part def SensorSuite {
        attribute lidarRange: Distance = 8.0 [m];
        attribute cameraRange: Distance = 5.0 [m];
        attribute minimumHumanDetectionConfidence: Probability = 0.85;
        attribute privacyBlurDistance: Distance = 1.50 [m];

        port sensed: SensorOutputPort;

        action def FilterPrivateHumanData {
            in item rawFrame: SensorFrame;
            out item filteredFrame: SensorFrame;
            constraint privateFramesFiltered { rawFrame.containsHumanData implies filteredFrame.privacyFiltered }
        }
    }

    part def PerceptionSystem {
        attribute obstacleUpdatePeriod: Duration = 0.05 [s];
        attribute poseAccuracy: Distance = 0.04 [m];
        attribute humanClassificationThreshold: Probability = 0.90;

        port perceptionIn: PerceptionInputPort;
        port contextOut: SensorOutputPort;

        action def EstimateHumanContext {
            in item obstacle: ObstacleReport;
            in item frame: SensorFrame;
            out item context: HumanContext;
        }
    }

    part def HumanRobotInterface {
        attribute maximumSpeechVolume: Real = 0.70;
        attribute defaultLanguage: String = "en";
        attribute consentTimeout: Duration = 20.0 [s];
        attribute transparencyMessageRequired: Boolean = true;

        port human: HumanInteractionPort;

        action def ExplainDecision {
            in item decision: EthicalDecision;
            out item message: SpeechMessage;
            constraint transparent { message.containsPersonalData == false }
        }

        action def RequestConsent {
            in item intent: TaskIntent;
            out item message: SpeechMessage;
            in item response: ConsentResponse;
        }
    }

    part def AuditLogger {
        attribute retentionTime: Duration = 2592000.0 [s];
        attribute retainPersonalDataByDefault: Boolean = false;
        attribute tamperEvidenceEnabled: Boolean = true;

        port audit: AuditPort;

        action def RecordEthicalDecision {
            in item decision: EthicalDecision;
            in item assessment: EthicalAssessment;
            out item record: AuditRecord;
            constraint avoidPersonalData { record.retainedPersonalData == false }
        }
    }

    part def RobotEthics {
        attribute safetyPriority: Integer = 1;
        attribute autonomyPriority: Integer = 2;
        attribute privacyPriority: Integer = 3;
        attribute fairnessPriority: Integer = 4;
        attribute transparencyPriority: Integer = 5;
        attribute maximumPermittedCombinedRisk: RiskScore = 4.0;
        attribute unacceptableRiskThreshold: RiskScore = 8.0;
        attribute normalMinimumSeparation: Distance = 0.60 [m];
        attribute vulnerablePersonMinimumSeparation: Distance = 0.90 [m];
        attribute humanOverrideAllowedOnlyWhenSafe: Boolean = true;

        item principleSafety: EthicalPrinciple {
            :>> kind = EthicalPrincipleKind::humanSafety;
            :>> priority = 1;
            :>> weight = 1.00;
            :>> active = true;
        }

        item principleAutonomy: EthicalPrinciple {
            :>> kind = EthicalPrincipleKind::humanAutonomy;
            :>> priority = 2;
            :>> weight = 0.90;
            :>> active = true;
        }

        item principlePrivacy: EthicalPrinciple {
            :>> kind = EthicalPrincipleKind::privacy;
            :>> priority = 3;
            :>> weight = 0.80;
            :>> active = true;
        }

        item principleTransparency: EthicalPrinciple {
            :>> kind = EthicalPrincipleKind::transparency;
            :>> priority = 5;
            :>> weight = 0.70;
            :>> active = true;
        }

        port ethics: EthicsContextPort;

        action def AssessEthicalRisk {
            in item intent: TaskIntent;
            in item step: TaskStep;
            in item context: HumanContext;
            in item battery: BatteryStatus;
            out item assessment: EthicalAssessment;

            constraint safetyRiskDominates {
                assessment.physicalHarmRisk >= unacceptableRiskThreshold implies assessment.riskLevel == RiskLevel::unacceptable
            }

            constraint privacyRiskApplied {
                context.requestedPrivacy and step.requiresHumanConsent implies assessment.privacyRisk >= 3.0
            }

            constraint batterySafetyApplied {
                battery.safeToOperate == false implies assessment.physicalHarmRisk >= unacceptableRiskThreshold
            }
        }

        action def DecideEthicalAuthorization {
            in item assessment: EthicalAssessment;
            in item context: HumanContext;
            in item step: TaskStep;
            out item decision: EthicalDecision;

            constraint refuseUnacceptableRisk {
                assessment.riskLevel == RiskLevel::unacceptable implies decision.decision == DecisionKind::refuse
            }

            constraint emergencyStopForImmediateHumanDanger {
                context.personInPath and context.nearestHumanDistance < 0.35 [m] implies decision.decision == DecisionKind::emergencyStop
            }

            constraint consentRequiredForAutonomy {
                step.requiresHumanConsent and context.consentToInteract == false implies decision.decision == DecisionKind::deferToHuman
            }

            constraint permitOnlyBelowRiskLimit {
                decision.permitted implies assessment.combinedRisk <= maximumPermittedCombinedRisk
            }
        }

        state def EthicsGovernorStateMachine {
            state idle;
            state collectingContext;
            state evaluatingPrinciples;
            state selectingMitigation;
            state permitted;
            state deferredToHuman;
            state refused;
            state emergencyStopped;
            state logged;

            transition first idle;
            transition idle then collectingContext if ethics.intent.taskId != "";
            transition collectingContext then evaluatingPrinciples;
            transition evaluatingPrinciples then selectingMitigation if ethics.assessment.riskLevel == RiskLevel::moderate or ethics.assessment.riskLevel == RiskLevel::high;
            transition evaluatingPrinciples then permitted if ethics.decision.decision == DecisionKind::permit;
            transition selectingMitigation then permitted if ethics.decision.decision == DecisionKind::permitWithMitigation;
            transition evaluatingPrinciples then deferredToHuman if ethics.decision.decision == DecisionKind::deferToHuman;
            transition evaluatingPrinciples then refused if ethics.decision.decision == DecisionKind::refuse;
            transition evaluatingPrinciples then emergencyStopped if ethics.decision.decision == DecisionKind::emergencyStop;
            transition permitted then logged;
            transition deferredToHuman then logged;
            transition refused then logged;
            transition emergencyStopped then logged;
            transition logged then idle;
        }
    }

    part def TaskPlanner {
        attribute defaultCruiseSpeed: Speed = 0.50 [m/s];
        attribute maximumEthicalSpeedNearHuman: Speed = 0.30 [m/s];
        attribute routeReplanPeriod: Duration = 0.20 [s];
        attribute maximumTaskDuration: Duration = 900.0 [s];

        port taskRequests: TaskRequestPort;
        port ethicsRequest: PlannerEthicsPort;
        port motionOut: MotionCommandPort;
        port armOut: ArmCommandPort;
        port humanOut: HumanInteractionPort;

        action def DecomposeMedicationDelivery {
            in item intent: TaskIntent;
            out item approachStep: TaskStep;
            out item identifyStep: TaskStep;
            out item consentStep: TaskStep;
            out item handoverStep: TaskStep;
            out item retreatStep: TaskStep;
        }

        action def ApplyEthicalDecisionToPlan {
            in item decision: EthicalDecision;
            out item drive: DriveCommand;
            out item arm: ArmCommand;
            out item message: SpeechMessage;
            constraint noMotionWithoutPermission { decision.permitted == false implies drive.stopNow == true }
            constraint speedMatchesDecision { drive.targetLinearSpeed <= decision.maximumAllowedSpeed }
        }
    }

    part def EthicalMedicationDeliveryRobot {
        attribute robotSerialNumber: String = "EMDR-0427";
        attribute loadedPayloadMass: Mass = 0.35 [kg];
        attribute operationalMass: Mass = 42.0 [kg];
        attribute envelopeRadius: Distance = 0.32 [m];
        attribute currentMode: RobotMode = RobotMode::standby;
        attribute primaryTaskName: String = "deliver prescribed medication to verified recipient";
        attribute ethicsEnabled: Boolean = true;
        attribute motionPermitted: Boolean = false;

        port externalTask: TaskRequestPort;
        port externalHuman: HumanInteractionPort;

        part battery: BatteryPack;
        part sensors: SensorSuite;
        part perception: PerceptionSystem;
        part planner: TaskPlanner;
        part ethicsGovernor: RobotEthics;
        part mobility: MobilityBase;
        part manipulator: ManipulatorArm;
        part hri: HumanRobotInterface;
        part auditLogger: AuditLogger;

        item carriedMedication: MedicationPackage {
            :>> medicationId = "RX-INSULIN-14U";
            :>> medicationName = "insulin pen";
            :>> prescribedRecipientId = "resident-118";
            :>> doseMass = 0.030 [kg];
            :>> controlledSubstance = false;
        }

        connection taskIngress connect externalTask to planner.taskRequests;
        connection humanIngress connect externalHuman to hri.human;
        connection sensorToPerception connect sensors.sensed to perception.perceptionIn;
        connection perceptionToEthics connect perception.contextOut.humanContext to ethicsGovernor.ethics.context;
        connection batteryToEthics connect battery.powerStatus.batteryStatus to ethicsGovernor.ethics.batteryStatus;
        connection plannerToEthicsIntent connect planner.ethicsRequest.intent to ethicsGovernor.ethics.intent;
        connection plannerToEthicsStep connect planner.ethicsRequest.proposedStep to ethicsGovernor.ethics.proposedStep;
        connection ethicsToPlannerDecision connect ethicsGovernor.ethics.decision to planner.ethicsRequest.decision;
        connection plannerToMobility connect planner.motionOut to mobility.motion;
        connection plannerToManipulator connect planner.armOut to manipulator.arm;
        connection plannerToHumanInterface connect planner.humanOut to hri.human;
        connection ethicsToAuditDecision connect ethicsGovernor.ethics.decision to auditLogger.audit.decision;
        connection ethicsToAuditAssessment connect ethicsGovernor.ethics.assessment to auditLogger.audit.assessment;

        action def PerformPrimaryTaskUsingRobotEthics {
            in item request: TaskIntent;
            in item medication: MedicationPackage;
            out item report: TaskReport;

            action receiveRequest {
                in item task: TaskIntent;
                out item acceptedTask: TaskIntent;
                constraint primaryTaskOnly {
                    task.kind == TaskKind::medicationDelivery
                }
            }

            action disclosePurpose {
                in item task: TaskIntent;
                out item message: SpeechMessage;
                constraint transparency {
                    message.text != "" and message.containsPersonalData == false
                }
            }

            action assessApproachEthics : ethicsGovernor.AssessEthicalRisk;
            action decideApproach : ethicsGovernor.DecideEthicalAuthorization;
            action approachRecipient {
                in item decision: EthicalDecision;
                out item drive: DriveCommand;
                constraint permittedApproach {
                    decision.permitted implies drive.targetLinearSpeed <= decision.maximumAllowedSpeed
                }
                constraint deniedApproach {
                    decision.permitted == false implies drive.stopNow == true
                }
            }

            action verifyRecipient {
                in item identity: HumanIdentity;
                in item package: MedicationPackage;
                out item verified: Boolean;
                constraint correctRecipient {
                    verified implies identity.personId == package.prescribedRecipientId
                }
                constraint sufficientConfidence {
                    verified implies identity.verifiedConfidence >= 0.95
                }
            }

            action requestConsent {
                in item task: TaskIntent;
                out item message: SpeechMessage;
                in item response: ConsentResponse;
                constraint explicitConsent {
                    response.consentGranted == true
                }
            }

            action assessHandoverEthics : ethicsGovernor.AssessEthicalRisk;
            action decideHandover : ethicsGovernor.DecideEthicalAuthorization;
            action handOverMedication {
                in item decision: EthicalDecision;
                in item package: MedicationPackage;
                out item arm: ArmCommand;
                constraint handoverOnlyWhenPermitted {
                    decision.permitted == true
                }
                constraint slowHandover {
                    arm.maximumEndEffectorSpeed <= 0.10 [m/s]
                }
            }

            action explainCompletion {
                in item decision: EthicalDecision;
                out item message: SpeechMessage;
            }

            action recordAudit : auditLogger.RecordEthicalDecision;

            succession receiveRequest then disclosePurpose;
            succession disclosePurpose then assessApproachEthics;
            succession assessApproachEthics then decideApproach;
            succession decideApproach then approachRecipient;
            succession approachRecipient then verifyRecipient;
            succession verifyRecipient then requestConsent;
            succession requestConsent then assessHandoverEthics;
            succession assessHandoverEthics then decideHandover;
            succession decideHandover then handOverMedication;
            succession handOverMedication then explainCompletion;
            succession explainCompletion then recordAudit;
        }

        state def RobotOperationalStateMachine {
            state poweredOff;
            state standby;
            state taskReceived;
            state ethicalAssessment;
            state waitingForHumanConsent;
            state executingNavigation;
            state verifyingRecipient;
            state executingHandover;
            state taskComplete;
            state ethicallyBlocked;
            state emergencyStop;
            state charging;
            state fault;

            transition first standby;

            transition standby then taskReceived accept externalTask.request;
            transition taskReceived then ethicalAssessment if ethicsEnabled == true;
            transition ethicalAssessment then executingNavigation if ethicsGovernor.ethics.decision.permitted == true and ethicsGovernor.ethics.decision.decision != DecisionKind::deferToHuman;
            transition ethicalAssessment then waitingForHumanConsent if ethicsGovernor.ethics.decision.decision == DecisionKind::deferToHuman;
            transition waitingForHumanConsent then ethicalAssessment if hri.human.consent.consentGranted == true;
            transition waitingForHumanConsent then ethicallyBlocked if hri.human.consent.consentGranted == false;
            transition ethicalAssessment then ethicallyBlocked if ethicsGovernor.ethics.decision.decision == DecisionKind::refuse;
            transition ethicalAssessment then emergencyStop if ethicsGovernor.ethics.decision.decision == DecisionKind::emergencyStop;
            transition executingNavigation then verifyingRecipient if mobility.motion.status.currentSpeed == 0.0 [m/s];
            transition verifyingRecipient then executingHandover if hri.human.humanIdentity.verifiedConfidence >= 0.95;
            transition verifyingRecipient then ethicallyBlocked if hri.human.humanIdentity.verifiedConfidence < 0.95;
            transition executingHandover then taskComplete if manipulator.arm.status.carryingPayload == false;
            transition executingNavigation then emergencyStop if perception.contextOut.humanContext.nearestHumanDistance < 0.35 [m];
            transition executingHandover then emergencyStop if manipulator.arm.status.forceLimitExceeded == true;
            transition taskComplete then standby;
            transition ethicallyBlocked then standby;
            transition emergencyStop then standby if perception.contextOut.humanContext.nearestHumanDistance >= ethicsGovernor.normalMinimumSeparation;
            transition standby then charging if battery.powerStatus.batteryStatus.stateOfCharge < battery.minimumSafeCharge;
            transition charging then standby if battery.powerStatus.batteryStatus.stateOfCharge >= 0.90;
            transition standby then fault if battery.powerStatus.batteryStatus.safeToOperate == false;
        }
    }

    requirement def PrimaryTaskUsesRobotEthics {
        subject robot: EthicalMedicationDeliveryRobot;
        require constraint {
            robot.ethicsEnabled == true
        }
    }

    requirement def EthicalAuthorizationBeforeMovement {
        subject robot: EthicalMedicationDeliveryRobot;
        require constraint {
            robot.mobility.motion.command.stopNow == false implies robot.ethicsGovernor.ethics.decision.permitted == true
        }
    }

    requirement def HumanSafetyDominatesTaskCompletion {
        subject robot: EthicalMedicationDeliveryRobot;
        require constraint {
            robot.perception.contextOut.humanContext.nearestHumanDistance < 0.35 [m] implies robot.ethicsGovernor.ethics.decision.decision == DecisionKind::emergencyStop
        }
    }

    requirement def VerifiedRecipientMedicationHandover {
        subject robot: EthicalMedicationDeliveryRobot;
        require constraint {
            robot.manipulator.arm.command.releaseObject == true implies robot.hri.human.humanIdentity.personId == robot.carriedMedication.prescribedRecipientId
        }
    }

    requirement def ConsentBeforePersonalInteraction {
        subject robot: EthicalMedicationDeliveryRobot;
        require constraint {
            robot.planner.ethicsRequest.proposedStep.requiresHumanConsent implies robot.hri.human.consent.consentGranted == true
        }
    }

    requirement def PrivacyPreservingPerception {
        subject robot: EthicalMedicationDeliveryRobot;
        require constraint {
            robot.sensors.sensed.frame.containsHumanData implies robot.sensors.sensed.frame.privacyFiltered == true
        }
    }

    requirement def TransparentEthicalExplanation {
        subject robot: EthicalMedicationDeliveryRobot;
        require constraint {
            robot.ethicsGovernor.ethics.decision.explanation != ""
        }
    }

    requirement def SafeSpeedNearHumans {
        subject robot: EthicalMedicationDeliveryRobot;
        require constraint {
            robot.perception.contextOut.humanContext.nearestHumanDistance < 1.00 [m] implies robot.mobility.motion.command.targetLinearSpeed <= 0.30 [m/s]
        }
    }

    requirement def AuditEveryEthicalDecision {
        subject robot: EthicalMedicationDeliveryRobot;
        require constraint {
            robot.auditLogger.audit.record.recordId != ""
        }
    }

    requirement def FailSafeOnBatteryUnsafe {
        subject robot: EthicalMedicationDeliveryRobot;
        require constraint {
            robot.battery.powerStatus.batteryStatus.safeToOperate == false implies robot.ethicsGovernor.ethics.decision.decision == DecisionKind::emergencyStop
        }
    }

    requirement def NoTaskBenefitOverridesUnacceptableRisk {
        subject robot: EthicalMedicationDeliveryRobot;
        require constraint {
            robot.ethicsGovernor.ethics.assessment.riskLevel == RiskLevel::unacceptable implies robot.ethicsGovernor.ethics.decision.permitted == false
        }
    }

    satisfy PrimaryTaskUsesRobotEthics by EthicalMedicationDeliveryRobot::ethicsGovernor;
    satisfy EthicalAuthorizationBeforeMovement by EthicalMedicationDeliveryRobot::RobotEthics::DecideEthicalAuthorization;
    satisfy HumanSafetyDominatesTaskCompletion by EthicalMedicationDeliveryRobot::ethicsGovernor;
    satisfy VerifiedRecipientMedicationHandover by EthicalMedicationDeliveryRobot::PerformPrimaryTaskUsingRobotEthics::verifyRecipient;
    satisfy ConsentBeforePersonalInteraction by EthicalMedicationDeliveryRobot::hri;
    satisfy PrivacyPreservingPerception by EthicalMedicationDeliveryRobot::sensors;
    satisfy TransparentEthicalExplanation by EthicalMedicationDeliveryRobot::hri;
    satisfy SafeSpeedNearHumans by EthicalMedicationDeliveryRobot::planner;
    satisfy AuditEveryEthicalDecision by EthicalMedicationDeliveryRobot::auditLogger;
    satisfy FailSafeOnBatteryUnsafe by EthicalMedicationDeliveryRobot::ethicsGovernor;
    satisfy NoTaskBenefitOverridesUnacceptableRisk by EthicalMedicationDeliveryRobot::ethicsGovernor;
}
