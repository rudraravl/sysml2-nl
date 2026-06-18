package DevelopmentalRoboticsModel {

    private import ScalarValues::*;

    doc
    /*
     * System specification for a developmental robotics platform.
     * Primary function: autonomously acquire, organize, and refine sensorimotor,
     * social, and task-oriented skills through embodied exploration, caregiver
     * interaction, imitation, reinforcement, and memory consolidation while
     * maintaining safe behavior around people and objects.
     */

    attribute def Time_s :> Real {
        doc "Elapsed time measured in seconds."
    }

    attribute def Frequency_Hz :> Real {
        doc "Frequency measured in hertz."
    }

    attribute def Distance_m :> Real {
        doc "Distance measured in meters."
    }

    attribute def Velocity_mps :> Real {
        doc "Linear velocity measured in meters per second."
    }

    attribute def AngularVelocity_radps :> Real {
        doc "Angular velocity measured in radians per second."
    }

    attribute def Mass_kg :> Real {
        doc "Mass measured in kilograms."
    }

    attribute def Energy_Wh :> Real {
        doc "Stored electrical energy measured in watt-hours."
    }

    attribute def Power_W :> Real {
        doc "Electrical or mechanical power measured in watts."
    }

    attribute def Voltage_V :> Real {
        doc "Electrical potential measured in volts."
    }

    attribute def Temperature_C :> Real {
        doc "Temperature measured in degrees Celsius."
    }

    attribute def Force_N :> Real {
        doc "Force measured in newtons."
    }

    attribute def Torque_Nm :> Real {
        doc "Torque measured in newton-meters."
    }

    attribute def Probability :> Real {
        doc "Dimensionless probability in the closed interval [0, 1]."
    }

    attribute def Percent :> Real {
        doc "Dimensionless percentage in the closed interval [0, 100]."
    }

    attribute def Confidence :> Real {
        doc "Dimensionless confidence value in the closed interval [0, 1]."
    }

    attribute def SkillLevel :> Real {
        doc "Normalized learned skill competence in the closed interval [0, 1]."
    }

    attribute def NoveltyScore :> Real {
        doc "Normalized novelty estimate in the closed interval [0, 1]."
    }

    attribute def RewardValue :> Real {
        doc "Scalar developmental reinforcement reward."
    }

    enum def DevelopmentalMode {
        enum Initializing;
        enum Calibrating;
        enum SafeExploration;
        enum SocialImitation;
        enum GuidedPractice;
        enum AutonomousPractice;
        enum SkillConsolidation;
        enum Resting;
        enum ProtectiveStop;
    }

    enum def SafetyLevel {
        enum Nominal;
        enum Caution;
        enum Restricted;
        enum EmergencyStop;
    }

    enum def GoalKind {
        enum ExploreObject;
        enum ReachAndGrasp;
        enum VocalImitation;
        enum JointAttention;
        enum NavigateToPerson;
        enum SortObjects;
        enum AskForHelp;
        enum Recharge;
    }

    enum def CueKind {
        enum Speech;
        enum Gesture;
        enum GazeDirection;
        enum FacialExpression;
        enum DemonstrationTrajectory;
        enum TouchGuidance;
        enum Approval;
        enum Disapproval;
    }

    enum def SkillKind {
        enum PerceptualCategory;
        enum MotorPrimitive;
        enum ManipulationRoutine;
        enum NavigationRoutine;
        enum SocialTurnTaking;
        enum LanguageGrounding;
        enum SafetyReflex;
    }

    item def ElectricalPower {
        attribute voltage: Voltage_V;
        attribute availablePower: Power_W;
        attribute stateOfCharge: Percent;
    }

    item def SensorFrame {
        attribute timestamp: Time_s;
        attribute visualConfidence: Confidence;
        attribute audioConfidence: Confidence;
        attribute tactileConfidence: Confidence;
        attribute proprioceptiveConfidence: Confidence;
        attribute nearestObstacleDistance: Distance_m;
        attribute detectedHumanDistance: Distance_m;
        attribute estimatedObjectCount: Integer;
    }

    item def VisionFrame {
        attribute timestamp: Time_s;
        attribute frameRate: Frequency_Hz;
        attribute horizontalFieldOfView: Real;
        attribute detectedFaces: Integer;
        attribute detectedObjects: Integer;
        attribute meanDetectionConfidence: Confidence;
    }

    item def AudioFrame {
        attribute timestamp: Time_s;
        attribute sampleRate: Frequency_Hz;
        attribute speechDetected: Boolean;
        attribute soundSourceAzimuth: Real;
        attribute speechConfidence: Confidence;
    }

    item def TactileFrame {
        attribute timestamp: Time_s;
        attribute contactCount: Integer;
        attribute maximumContactForce: Force_N;
        attribute meanContactForce: Force_N;
    }

    item def ProprioceptiveFrame {
        attribute timestamp: Time_s;
        attribute jointPositionConfidence: Confidence;
        attribute jointVelocityConfidence: Confidence;
        attribute bodyTiltRate: AngularVelocity_radps;
    }

    item def SocialCue {
        attribute timestamp: Time_s;
        attribute kind: CueKind;
        attribute sourceDistance: Distance_m;
        attribute interpretedIntentConfidence: Confidence;
        attribute positiveValence: Probability;
    }

    item def DevelopmentalGoal {
        attribute kind: GoalKind;
        attribute priority: Real;
        attribute expectedLearningGain: NoveltyScore;
        attribute expectedRisk: Probability;
        attribute timeBudget: Time_s;
    }

    item def MotorCommand {
        attribute timestamp: Time_s;
        attribute targetLinearVelocity: Velocity_mps;
        attribute targetAngularVelocity: AngularVelocity_radps;
        attribute leftArmTorqueLimit: Torque_Nm;
        attribute rightArmTorqueLimit: Torque_Nm;
        attribute gripperForceLimit: Force_N;
        attribute expressiveHeadEnabled: Boolean;
        attribute speechEnabled: Boolean;
    }

    item def SpeechCommand {
        attribute timestamp: Time_s;
        attribute utteranceConfidence: Confidence;
        attribute intendedPoliteness: Probability;
        attribute maximumSoundLevel: Real;
    }

    item def InteractionPrompt {
        attribute timestamp: Time_s;
        attribute requestsHumanHelp: Boolean;
        attribute asksForLabel: Boolean;
        attribute asksForDemonstration: Boolean;
        attribute promptUrgency: Real;
    }

    item def RewardSignal {
        attribute timestamp: Time_s;
        attribute intrinsicReward: RewardValue;
        attribute socialReward: RewardValue;
        attribute taskReward: RewardValue;
        attribute safetyPenalty: RewardValue;
    }

    item def SkillHypothesis {
        attribute timestamp: Time_s;
        attribute kind: SkillKind;
        attribute confidence: Confidence;
        attribute competence: SkillLevel;
        attribute expectedGeneralization: Probability;
    }

    item def LearningEpisode {
        attribute startTime: Time_s;
        attribute duration: Time_s;
        attribute goalKind: GoalKind;
        attribute novelty: NoveltyScore;
        attribute reward: RewardValue;
        attribute safe: Boolean;
        attribute resultedInSkillUpdate: Boolean;
    }

    item def MapBelief {
        attribute timestamp: Time_s;
        attribute occupiedCellCount: Integer;
        attribute knownObjectCount: Integer;
        attribute humanLocationConfidence: Confidence;
        attribute localizationConfidence: Confidence;
    }

    item def SafetyAlert {
        attribute timestamp: Time_s;
        attribute level: SafetyLevel;
        attribute nearestHumanDistance: Distance_m;
        attribute nearestObstacleDistance: Distance_m;
        attribute thermalMargin: Temperature_C;
        attribute requiresStop: Boolean;
    }

    port def PowerInPort {
        in item power: ElectricalPower;
    }

    port def PowerOutPort {
        out item power: ElectricalPower;
    }

    port def PerceptionOutPort {
        out item frame: SensorFrame;
    }

    port def PerceptionInPort {
        in item frame: SensorFrame;
    }

    port def VisionOutPort {
        out item frame: VisionFrame;
    }

    port def VisionInPort {
        in item frame: VisionFrame;
    }

    port def AudioOutPort {
        out item frame: AudioFrame;
    }

    port def AudioInPort {
        in item frame: AudioFrame;
    }

    port def TactileOutPort {
        out item frame: TactileFrame;
    }

    port def TactileInPort {
        in item frame: TactileFrame;
    }

    port def ProprioceptionOutPort {
        out item frame: ProprioceptiveFrame;
    }

    port def ProprioceptionInPort {
        in item frame: ProprioceptiveFrame;
    }

    port def SocialCueOutPort {
        out item cue: SocialCue;
    }

    port def SocialCueInPort {
        in item cue: SocialCue;
    }

    port def GoalOutPort {
        out item goal: DevelopmentalGoal;
    }

    port def GoalInPort {
        in item goal: DevelopmentalGoal;
    }

    port def CommandOutPort {
        out item command: MotorCommand;
    }

    port def CommandInPort {
        in item command: MotorCommand;
    }

    port def SpeechCommandOutPort {
        out item command: SpeechCommand;
    }

    port def SpeechCommandInPort {
        in item command: SpeechCommand;
    }

    port def PromptOutPort {
        out item prompt: InteractionPrompt;
    }

    port def PromptInPort {
        in item prompt: InteractionPrompt;
    }

    port def RewardOutPort {
        out item reward: RewardSignal;
    }

    port def RewardInPort {
        in item reward: RewardSignal;
    }

    port def SkillOutPort {
        out item skill: SkillHypothesis;
    }

    port def SkillInPort {
        in item skill: SkillHypothesis;
    }

    port def EpisodeOutPort {
        out item episode: LearningEpisode;
    }

    port def EpisodeInPort {
        in item episode: LearningEpisode;
    }

    port def MapOutPort {
        out item map: MapBelief;
    }

    port def MapInPort {
        in item map: MapBelief;
    }

    port def SafetyAlertOutPort {
        out item alert: SafetyAlert;
    }

    port def SafetyAlertInPort {
        in item alert: SafetyAlert;
    }

    part def StereoVisionModule {
        attribute mass: Mass_kg = 0.42;
        attribute frameRate: Frequency_Hz = 60.0;
        attribute baseline: Distance_m = 0.08;
        attribute horizontalFieldOfView: Real = 95.0;
        attribute operatingPower: Power_W = 7.5;

        port powerIn: PowerInPort;
        port videoOut: VisionOutPort;
    }

    part def MicrophoneArray {
        attribute mass: Mass_kg = 0.11;
        attribute sampleRate: Frequency_Hz = 48000.0;
        attribute microphoneCount: Integer = 6;
        attribute operatingPower: Power_W = 1.8;

        port powerIn: PowerInPort;
        port audioOut: AudioOutPort;
    }

    part def TactileSkin {
        attribute mass: Mass_kg = 1.20;
        attribute taxelCount: Integer = 2048;
        attribute updateRate: Frequency_Hz = 200.0;
        attribute maximumMeasurableForce: Force_N = 80.0;
        attribute operatingPower: Power_W = 14.0;

        port powerIn: PowerInPort;
        port tactileOut: TactileOutPort;
    }

    part def ProprioceptiveSensorNetwork {
        attribute jointEncoderCount: Integer = 34;
        attribute imuCount: Integer = 3;
        attribute updateRate: Frequency_Hz = 500.0;
        attribute operatingPower: Power_W = 8.0;

        port powerIn: PowerInPort;
        port proprioceptionOut: ProprioceptionOutPort;
    }

    part def SensorFusionComputer {
        attribute fusionRate: Frequency_Hz = 50.0;
        attribute perceptionLatency: Time_s = 0.035;
        attribute operatingPower: Power_W = 22.0;

        port powerIn: PowerInPort;
        port visionIn: VisionInPort;
        port audioIn: AudioInPort;
        port tactileIn: TactileInPort;
        port proprioceptionIn: ProprioceptionInPort;
        port perceptionOut: PerceptionOutPort;
    }

    part def SensorSuite {
        attribute mass: Mass_kg = 2.65;
        attribute nominalUpdateRate: Frequency_Hz = 50.0;

        port powerIn: PowerInPort;
        port perceptionOut: PerceptionOutPort;

        part stereoVision: StereoVisionModule;
        part microphoneArray: MicrophoneArray;
        part tactileSkin: TactileSkin;
        part proprioception: ProprioceptiveSensorNetwork;
        part fusionComputer: SensorFusionComputer;

        connect powerIn to stereoVision.powerIn;
        connect powerIn to microphoneArray.powerIn;
        connect powerIn to tactileSkin.powerIn;
        connect powerIn to proprioception.powerIn;
        connect powerIn to fusionComputer.powerIn;

        connect stereoVision.videoOut to fusionComputer.visionIn;
        connect microphoneArray.audioOut to fusionComputer.audioIn;
        connect tactileSkin.tactileOut to fusionComputer.tactileIn;
        connect proprioception.proprioceptionOut to fusionComputer.proprioceptionIn;
        connect fusionComputer.perceptionOut to perceptionOut;
    }

    part def MobileBase {
        attribute mass: Mass_kg = 11.0;
        attribute maximumLinearVelocity: Velocity_mps = 1.1;
        attribute maximumAngularVelocity: AngularVelocity_radps = 1.8;
        attribute maximumContinuousPower: Power_W = 220.0;

        port powerIn: PowerInPort;
        port commandIn: CommandInPort;
        port proprioceptionOut: ProprioceptionOutPort;
    }

    part def ManipulatorArm {
        attribute mass: Mass_kg = 3.5;
        attribute degreeOfFreedom: Integer = 7;
        attribute reach: Distance_m = 0.62;
        attribute maximumPayload: Mass_kg = 1.2;
        attribute maximumJointTorque: Torque_Nm = 18.0;
        attribute maximumGripForce: Force_N = 45.0;

        port powerIn: PowerInPort;
        port commandIn: CommandInPort;
        port proprioceptionOut: ProprioceptionOutPort;
        port tactileOut: TactileOutPort;
    }

    part def ExpressiveHead {
        attribute mass: Mass_kg = 2.1;
        attribute neckDegreesOfFreedom: Integer = 3;
        attribute displayPower: Power_W = 12.0;

        port powerIn: PowerInPort;
        port commandIn: CommandInPort;
    }

    part def SpeechSynthesizer {
        attribute mass: Mass_kg = 0.28;
        attribute maximumSoundLevel: Real = 65.0;
        attribute operatingPower: Power_W = 5.0;

        port powerIn: PowerInPort;
        port speechIn: SpeechCommandInPort;
    }

    part def ActuationSystem {
        attribute mass: Mass_kg = 20.38;
        attribute commandRate: Frequency_Hz = 100.0;

        port powerIn: PowerInPort;
        port commandIn: CommandInPort;
        port speechIn: SpeechCommandInPort;
        port proprioceptionOut: ProprioceptionOutPort;
        port tactileOut: TactileOutPort;

        part base: MobileBase;
        part leftArm: ManipulatorArm;
        part rightArm: ManipulatorArm;
        part head: ExpressiveHead;
        part speech: SpeechSynthesizer;

        connect powerIn to base.powerIn;
        connect powerIn to leftArm.powerIn;
        connect powerIn to rightArm.powerIn;
        connect powerIn to head.powerIn;
        connect powerIn to speech.powerIn;

        connect commandIn to base.commandIn;
        connect commandIn to leftArm.commandIn;
        connect commandIn to rightArm.commandIn;
        connect commandIn to head.commandIn;
        connect speechIn to speech.speechIn;

        connect base.proprioceptionOut to proprioceptionOut;
        connect leftArm.proprioceptionOut to proprioceptionOut;
        connect rightArm.proprioceptionOut to proprioceptionOut;
        connect leftArm.tactileOut to tactileOut;
        connect rightArm.tactileOut to tactileOut;
    }

    part def HumanInteractionInterface {
        attribute speechRecognitionRate: Frequency_Hz = 20.0;
        attribute socialCueInterpretationLatency: Time_s = 0.12;
        attribute maximumPromptRate: Frequency_Hz = 0.2;

        port powerIn: PowerInPort;
        port perceptionIn: PerceptionInPort;
        port socialCueOut: SocialCueOutPort;
        port promptIn: PromptInPort;
        port speechCommandIn: SpeechCommandInPort;
        port rewardOut: RewardOutPort;
    }

    part def EpisodicMemory {
        attribute retainedEpisodeCapacity: Integer = 100000;
        attribute writeLatency: Time_s = 0.020;
        attribute recallLatency: Time_s = 0.050;

        port episodeIn: EpisodeInPort;
        port perceptionIn: PerceptionInPort;
        port rewardIn: RewardInPort;
    }

    part def SemanticMemory {
        attribute conceptCapacity: Integer = 20000;
        attribute symbolGroundingConfidence: Confidence = 0.70;
        attribute updateLatency: Time_s = 0.040;

        port skillIn: SkillInPort;
        port socialCueIn: SocialCueInPort;
    }

    part def CuriosityEngine {
        attribute noveltyThreshold: NoveltyScore = 0.35;
        attribute intrinsicRewardScale: RewardValue = 1.0;
        attribute maximumRiskForExploration: Probability = 0.12;

        port perceptionIn: PerceptionInPort;
        port mapIn: MapInPort;
        port goalOut: GoalOutPort;
        port rewardOut: RewardOutPort;
    }

    part def ImitationLearner {
        attribute demonstrationAlignmentTolerance: Time_s = 0.15;
        attribute minimumCueConfidence: Confidence = 0.55;
        attribute initialImitationCompetence: SkillLevel = 0.10;

        port socialCueIn: SocialCueInPort;
        port perceptionIn: PerceptionInPort;
        port skillOut: SkillOutPort;
        port goalOut: GoalOutPort;
    }

    part def ReinforcementLearner {
        attribute policyUpdateRate: Frequency_Hz = 5.0;
        attribute discountFactor: Real = 0.96;
        attribute learningRate: Real = 0.03;
        attribute explorationRate: Probability = 0.18;

        port perceptionIn: PerceptionInPort;
        port goalIn: GoalInPort;
        port rewardIn: RewardInPort;
        port skillOut: SkillOutPort;
        port commandOut: CommandOutPort;
        port episodeOut: EpisodeOutPort;
    }

    part def SkillLibrary {
        attribute acquiredSkillCount: Integer = 0;
        attribute targetSkillCount: Integer = 50;
        attribute minimumCompetenceForUse: SkillLevel = 0.72;
        attribute averageSkillCompetence: SkillLevel = 0.0;

        port skillIn: SkillInPort;
        port goalIn: GoalInPort;
        port commandOut: CommandOutPort;
    }

    part def DevelopmentalPlanner {
        attribute planningHorizon: Time_s = 12.0;
        attribute replanningPeriod: Time_s = 0.25;
        attribute maximumGoalQueueLength: Integer = 8;

        port perceptionIn: PerceptionInPort;
        port mapIn: MapInPort;
        port goalIn: GoalInPort;
        port safetyAlertIn: SafetyAlertInPort;
        port commandOut: CommandOutPort;
        port promptOut: PromptOutPort;
    }

    part def WorldModeler {
        attribute mapUpdateRate: Frequency_Hz = 20.0;
        attribute localizationAccuracy: Distance_m = 0.04;
        attribute objectPersistenceTime: Time_s = 600.0;

        port perceptionIn: PerceptionInPort;
        port mapOut: MapOutPort;
    }

    part def SafetySupervisor {
        attribute minimumHumanDistance: Distance_m = 0.55;
        attribute minimumObstacleDistance: Distance_m = 0.12;
        attribute maximumAllowedGripForce: Force_N = 30.0;
        attribute maximumSurfaceTemperature: Temperature_C = 45.0;
        attribute stopLatency: Time_s = 0.080;

        port perceptionIn: PerceptionInPort;
        port mapIn: MapInPort;
        port commandIn: CommandInPort;
        port safetyAlertOut: SafetyAlertOutPort;
        port commandOut: CommandOutPort;
    }

    part def AffectAndMotivationRegulator {
        attribute fatigueLimit: Percent = 80.0;
        attribute socialEngagementBias: Probability = 0.55;
        attribute restThreshold: Percent = 20.0;

        port rewardIn: RewardInPort;
        port socialCueIn: SocialCueInPort;
        port goalOut: GoalOutPort;
        port promptOut: PromptOutPort;
    }

    part def CognitiveArchitecture {
        attribute controlCyclePeriod: Time_s = 0.05;
        attribute developmentalAgeHours: Time_s = 0.0;
        attribute mode: DevelopmentalMode = DevelopmentalMode::Initializing;

        port powerIn: PowerInPort;
        port perceptionIn: PerceptionInPort;
        port socialCueIn: SocialCueInPort;
        port rewardIn: RewardInPort;
        port commandOut: CommandOutPort;
        port speechCommandOut: SpeechCommandOutPort;
        port promptOut: PromptOutPort;
        port safetyAlertOut: SafetyAlertOutPort;
        port episodeOut: EpisodeOutPort;
        port skillOut: SkillOutPort;

        part worldModeler: WorldModeler;
        part episodicMemory: EpisodicMemory;
        part semanticMemory: SemanticMemory;
        part curiosityEngine: CuriosityEngine;
        part imitationLearner: ImitationLearner;
        part reinforcementLearner: ReinforcementLearner;
        part skillLibrary: SkillLibrary;
        part planner: DevelopmentalPlanner;
        part safetySupervisor: SafetySupervisor;
        part motivationRegulator: AffectAndMotivationRegulator;

        connect perceptionIn to worldModeler.perceptionIn;
        connect perceptionIn to episodicMemory.perceptionIn;
        connect perceptionIn to curiosityEngine.perceptionIn;
        connect perceptionIn to imitationLearner.perceptionIn;
        connect perceptionIn to reinforcementLearner.perceptionIn;
        connect perceptionIn to planner.perceptionIn;
        connect perceptionIn to safetySupervisor.perceptionIn;

        connect socialCueIn to imitationLearner.socialCueIn;
        connect socialCueIn to semanticMemory.socialCueIn;
        connect socialCueIn to motivationRegulator.socialCueIn;

        connect rewardIn to episodicMemory.rewardIn;
        connect rewardIn to reinforcementLearner.rewardIn;
        connect rewardIn to motivationRegulator.rewardIn;

        connect worldModeler.mapOut to curiosityEngine.mapIn;
        connect worldModeler.mapOut to planner.mapIn;
        connect worldModeler.mapOut to safetySupervisor.mapIn;

        connect curiosityEngine.goalOut to planner.goalIn;
        connect curiosityEngine.goalOut to reinforcementLearner.goalIn;
        connect curiosityEngine.rewardOut to reinforcementLearner.rewardIn;

        connect imitationLearner.goalOut to planner.goalIn;
        connect imitationLearner.skillOut to semanticMemory.skillIn;
        connect imitationLearner.skillOut to skillLibrary.skillIn;
        connect imitationLearner.skillOut to skillOut;

        connect motivationRegulator.goalOut to planner.goalIn;
        connect motivationRegulator.promptOut to promptOut;

        connect reinforcementLearner.skillOut to skillLibrary.skillIn;
        connect reinforcementLearner.skillOut to semanticMemory.skillIn;
        connect reinforcementLearner.skillOut to skillOut;
        connect reinforcementLearner.episodeOut to episodicMemory.episodeIn;
        connect reinforcementLearner.episodeOut to episodeOut;

        connect skillLibrary.commandOut to safetySupervisor.commandIn;
        connect planner.commandOut to safetySupervisor.commandIn;
        connect reinforcementLearner.commandOut to safetySupervisor.commandIn;

        connect safetySupervisor.safetyAlertOut to planner.safetyAlertIn;
        connect safetySupervisor.safetyAlertOut to safetyAlertOut;
        connect safetySupervisor.commandOut to commandOut;

        connect planner.promptOut to promptOut;
    }

    part def BatteryPack {
        attribute mass: Mass_kg = 5.4;
        attribute nominalVoltage: Voltage_V = 48.0;
        attribute capacity: Energy_Wh = 720.0;
        attribute maximumContinuousPower: Power_W = 900.0;
        attribute stateOfCharge: Percent = 100.0;

        port powerOut: PowerOutPort;
    }

    part def PowerManager {
        attribute conversionEfficiency: Percent = 92.0;
        attribute lowPowerThreshold: Percent = 18.0;
        attribute criticalPowerThreshold: Percent = 8.0;

        port batteryIn: PowerInPort;
        port regulatedPowerOut: PowerOutPort;
        port promptOut: PromptOutPort;
    }

    part def DockingCharger {
        attribute chargingPower: Power_W = 240.0;
        attribute dockingTolerance: Distance_m = 0.05;

        port powerOut: PowerOutPort;
    }

    part def PowerSystem {
        attribute totalStoredEnergy: Energy_Wh = 720.0;
        attribute nominalRuntime: Time_s = 10800.0;

        port powerOut: PowerOutPort;
        port promptOut: PromptOutPort;

        part battery: BatteryPack;
        part manager: PowerManager;
        part charger: DockingCharger;

        connect battery.powerOut to manager.batteryIn;
        connect manager.regulatedPowerOut to powerOut;
        connect manager.promptOut to promptOut;
    }

    action def SenseEmbodiedContext {
        in item rawPerception: SensorFrame;
        out item fusedPerception: SensorFrame;
    }

    action def InferSocialIntent {
        in item perception: SensorFrame;
        in item cue: SocialCue;
        out attribute intentConfidence: Confidence;
        out item interactionPrompt: InteractionPrompt;
    }

    action def EstimateNoveltyAndCuriosity {
        in item perception: SensorFrame;
        in item map: MapBelief;
        out attribute novelty: NoveltyScore;
        out item intrinsicReward: RewardSignal;
    }

    action def SelectDevelopmentalGoal {
        in attribute novelty: NoveltyScore;
        in attribute socialIntentConfidence: Confidence;
        in item safetyAlert: SafetyAlert;
        out item selectedGoal: DevelopmentalGoal;
    }

    action def GenerateExploratoryPolicy {
        in item selectedGoal: DevelopmentalGoal;
        in item perception: SensorFrame;
        out item candidateCommand: MotorCommand;
    }

    action def EvaluateSafety {
        in item perception: SensorFrame;
        in item candidateCommand: MotorCommand;
        out item safetyAlert: SafetyAlert;
        out item safeCommand: MotorCommand;
    }

    action def LearnFromOutcome {
        in item selectedGoal: DevelopmentalGoal;
        in item perception: SensorFrame;
        in item reward: RewardSignal;
        out item skill: SkillHypothesis;
        out item episode: LearningEpisode;
    }

    action def ConsolidateSkill {
        in item skill: SkillHypothesis;
        in item episode: LearningEpisode;
        out attribute updatedAverageCompetence: SkillLevel;
    }

    action def DevelopmentalLearningCycle {
        in item perception: SensorFrame;
        in item socialCue: SocialCue;
        in item map: MapBelief;
        in item caregiverReward: RewardSignal;
        out item motorCommand: MotorCommand;
        out item prompt: InteractionPrompt;
        out item learnedSkill: SkillHypothesis;
        out item loggedEpisode: LearningEpisode;

        action sense: SenseEmbodiedContext {
            in item rawPerception = perception;
        }

        action inferIntent: InferSocialIntent {
            in item perception = sense.fusedPerception;
            in item cue = socialCue;
        }

        action assessNovelty: EstimateNoveltyAndCuriosity {
            in item perception = sense.fusedPerception;
            in item map = map;
        }

        action selectGoal: SelectDevelopmentalGoal {
            in attribute novelty = assessNovelty.novelty;
            in attribute socialIntentConfidence = inferIntent.intentConfidence;
        }

        action generatePolicy: GenerateExploratoryPolicy {
            in item selectedGoal = selectGoal.selectedGoal;
            in item perception = sense.fusedPerception;
        }

        action evaluateSafety: EvaluateSafety {
            in item perception = sense.fusedPerception;
            in item candidateCommand = generatePolicy.candidateCommand;
        }

        action learn: LearnFromOutcome {
            in item selectedGoal = selectGoal.selectedGoal;
            in item perception = sense.fusedPerception;
            in item reward = caregiverReward;
        }

        action consolidate: ConsolidateSkill {
            in item skill = learn.skill;
            in item episode = learn.episode;
        }

        flow evaluateSafety.safeCommand to motorCommand;
        flow inferIntent.interactionPrompt to prompt;
        flow learn.skill to learnedSkill;
        flow learn.episode to loggedEpisode;

        succession sense then inferIntent;
        succession sense then assessNovelty;
        succession inferIntent then selectGoal;
        succession assessNovelty then selectGoal;
        succession selectGoal then generatePolicy;
        succession generatePolicy then evaluateSafety;
        succession evaluateSafety then learn;
        succession learn then consolidate;
    }

    state def DevelopmentalRobotStateMachine {
        attribute currentMode: DevelopmentalMode;

        state initializing;
        state calibrating;
        state safeExploration;
        state socialImitation;
        state guidedPractice;
        state autonomousPractice;
        state skillConsolidation;
        state resting;
        state protectiveStop;

        transition first initializing;

        transition initializeToCalibrate
            first initializing
            then calibrating;

        transition calibrateToExplore
            first calibrating
            then safeExploration;

        transition exploreToImitation
            first safeExploration
            then socialImitation;

        transition imitationToGuidedPractice
            first socialImitation
            then guidedPractice;

        transition guidedToAutonomousPractice
            first guidedPractice
            then autonomousPractice;

        transition autonomousToConsolidation
            first autonomousPractice
            then skillConsolidation;

        transition consolidationToExplore
            first skillConsolidation
            then safeExploration;

        transition exploreToRest
            first safeExploration
            then resting;

        transition restToExplore
            first resting
            then safeExploration;

        transition anyPracticeToProtectiveStopFromExplore
            first safeExploration
            then protectiveStop;

        transition anyPracticeToProtectiveStopFromImitation
            first socialImitation
            then protectiveStop;

        transition anyPracticeToProtectiveStopFromGuided
            first guidedPractice
            then protectiveStop;

        transition anyPracticeToProtectiveStopFromAutonomous
            first autonomousPractice
            then protectiveStop;

        transition protectiveStopToCalibrating
            first protectiveStop
            then calibrating;
    }

    part def DevelopmentalRobot {
        doc
        /*
         * Embodied developmental robot whose high-level primary function is to
         * learn new sensorimotor and social capabilities over time by interacting
         * safely with people, objects, and spaces.
         */

        attribute totalMass: Mass_kg = 34.0;
        attribute height: Distance_m = 1.05;
        attribute shoulderWidth: Distance_m = 0.42;
        attribute nominalControlRate: Frequency_Hz = 20.0;
        attribute maximumSafeSpeedNearHuman: Velocity_mps = 0.35;
        attribute expectedOperationalLife: Time_s = 315360000.0;
        attribute developmentalMode: DevelopmentalMode = DevelopmentalMode::Initializing;
        attribute minimumHumanSeparation: Distance_m = 0.55;

        port externalSocialCueIn: SocialCueInPort;
        port externalRewardIn: RewardInPort;
        port interactionPromptOut: PromptOutPort;
        port safetyAlertOut: SafetyAlertOutPort;
        port learnedSkillOut: SkillOutPort;
        port learningEpisodeOut: EpisodeOutPort;

        part sensors: SensorSuite;
        part actuators: ActuationSystem;
        part cognition: CognitiveArchitecture;
        part humanInterface: HumanInteractionInterface;
        part power: PowerSystem;

        perform action learningCycle: DevelopmentalLearningCycle;
        exhibit state behavior: DevelopmentalRobotStateMachine;

        connect power.powerOut to sensors.powerIn;
        connect power.powerOut to actuators.powerIn;
        connect power.powerOut to cognition.powerIn;
        connect power.powerOut to humanInterface.powerIn;

        connect sensors.perceptionOut to cognition.perceptionIn;
        connect sensors.perceptionOut to humanInterface.perceptionIn;

        connect humanInterface.socialCueOut to cognition.socialCueIn;
        connect externalSocialCueIn to cognition.socialCueIn;
        connect externalRewardIn to cognition.rewardIn;
        connect humanInterface.rewardOut to cognition.rewardIn;

        connect cognition.commandOut to actuators.commandIn;
        connect cognition.speechCommandOut to actuators.speechIn;
        connect cognition.speechCommandOut to humanInterface.speechCommandIn;

        connect cognition.promptOut to humanInterface.promptIn;
        connect cognition.promptOut to interactionPromptOut;
        connect power.promptOut to interactionPromptOut;

        connect cognition.safetyAlertOut to safetyAlertOut;
        connect cognition.skillOut to learnedSkillOut;
        connect cognition.episodeOut to learningEpisodeOut;
    }

    constraint def MaintainHumanSeparation {
        in nearestHumanDistance: Distance_m;
        in requiredSeparation: Distance_m;
        nearestHumanDistance >= requiredSeparation;
    }

    constraint def LimitGripForce {
        in commandedGripForce: Force_N;
        in maximumGripForce: Force_N;
        commandedGripForce <= maximumGripForce;
    }

    constraint def KeepControlLatencyBounded {
        in measuredLatency: Time_s;
        in maximumLatency: Time_s;
        measuredLatency <= maximumLatency;
    }

    constraint def MaintainLearningProgress {
        in acquiredSkillCount: Integer;
        in targetSkillCount: Integer;
        acquiredSkillCount >= targetSkillCount;
    }

    constraint def MaintainEnergyReserve {
        in stateOfCharge: Percent;
        in minimumReserve: Percent;
        stateOfCharge >= minimumReserve;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         * The system shall function as a developmental robotics platform that
         * autonomously improves behavior by learning from embodied exploration,
         * imitation, caregiver feedback, and task outcome evaluation.
         */
        subject robot: DevelopmentalRobot;

        require constraint {
            robot.nominalControlRate >= 20.0
        }
    }

    requirement def EmbodiedPerceptionRequirement {
        doc
        /*
         * The robot shall integrate visual, auditory, tactile, and proprioceptive
         * information into a unified perception stream for developmental learning.
         */
        subject robot: DevelopmentalRobot;

        require constraint {
            robot.sensors.nominalUpdateRate >= 50.0
        }
    }

    requirement def IncrementalSkillAcquisitionRequirement {
        doc
        /*
         * The robot shall maintain a library of learned developmental skills and
         * target at least fifty usable skills across perception, manipulation,
         * navigation, social interaction, and language grounding.
         */
        subject robot: DevelopmentalRobot;

        require constraint MaintainLearningProgress {
            in acquiredSkillCount = robot.cognition.skillLibrary.acquiredSkillCount;
            in targetSkillCount = robot.cognition.skillLibrary.targetSkillCount;
        }
    }

    requirement def SafeHumanInteractionRequirement {
        doc
        /*
         * The robot shall preserve a minimum separation from humans during
         * autonomous and guided practice unless explicitly operating under
         * supervised touch guidance.
         */
        subject robot: DevelopmentalRobot;

        require constraint MaintainHumanSeparation {
            in nearestHumanDistance = robot.cognition.safetySupervisor.minimumHumanDistance;
            in requiredSeparation = robot.minimumHumanSeparation;
        }
    }

    requirement def ManipulationSafetyRequirement {
        doc
        /*
         * The robot shall limit grasping force during learning so exploratory
         * manipulation does not exceed the safe contact force for household
         * objects or human-guided interaction.
         */
        subject robot: DevelopmentalRobot;

        require constraint LimitGripForce {
            in commandedGripForce = robot.cognition.safetySupervisor.maximumAllowedGripForce;
            in maximumGripForce = 30.0;
        }
    }

    requirement def RealTimeSafetySupervisionRequirement {
        doc
        /*
         * The safety supervisor shall be capable of issuing a protective stop
         * within eighty milliseconds after detection of an unsafe condition.
         */
        subject robot: DevelopmentalRobot;

        require constraint KeepControlLatencyBounded {
            in measuredLatency = robot.cognition.safetySupervisor.stopLatency;
            in maximumLatency = 0.080;
        }
    }

    requirement def PowerAutonomyRequirement {
        doc
        /*
         * The robot shall monitor energy reserve and request charging before
         * the battery state of charge falls below the low-power operating limit.
         */
        subject robot: DevelopmentalRobot;

        require constraint MaintainEnergyReserve {
            in stateOfCharge = robot.power.battery.stateOfCharge;
            in minimumReserve = robot.power.manager.lowPowerThreshold;
        }
    }

    requirement def SocialLearningRequirement {
        doc
        /*
         * The robot shall interpret caregiver speech, gaze, gesture, approval,
         * disapproval, and demonstrated trajectories as developmental learning
         * cues for imitation and grounded concept formation.
         */
        subject robot: DevelopmentalRobot;

        require constraint {
            robot.humanInterface.socialCueInterpretationLatency <= 0.15
        }
    }

    requirement def CuriosityDrivenExplorationRequirement {
        doc
        /*
         * The robot shall generate intrinsic reward from novelty while limiting
         * exploratory behavior to goals whose predicted risk remains within the
         * allowed developmental exploration risk.
         */
        subject robot: DevelopmentalRobot;

        require constraint {
            robot.cognition.curiosityEngine.maximumRiskForExploration <= 0.12
        }
    }

    requirement def MemoryConsolidationRequirement {
        doc
        /*
         * The robot shall store learning episodes and consolidate repeated
         * successful episodes into reusable skill hypotheses.
         */
        subject robot: DevelopmentalRobot;

        require constraint {
            robot.cognition.episodicMemory.retainedEpisodeCapacity >= 100000
        }
    }

    part developmentalRobot: DevelopmentalRobot;

    requirement primaryFunction: PrimaryFunctionRequirement {
        subject robot = developmentalRobot;
    }

    requirement embodiedPerception: EmbodiedPerceptionRequirement {
        subject robot = developmentalRobot;
    }

    requirement incrementalSkillAcquisition: IncrementalSkillAcquisitionRequirement {
        subject robot = developmentalRobot;
    }

    requirement safeHumanInteraction: SafeHumanInteractionRequirement {
        subject robot = developmentalRobot;
    }

    requirement manipulationSafety: ManipulationSafetyRequirement {
        subject robot = developmentalRobot;
    }

    requirement realTimeSafetySupervision: RealTimeSafetySupervisionRequirement {
        subject robot = developmentalRobot;
    }

    requirement powerAutonomy: PowerAutonomyRequirement {
        subject robot = developmentalRobot;
    }

    requirement socialLearning: SocialLearningRequirement {
        subject robot = developmentalRobot;
    }

    requirement curiosityDrivenExploration: CuriosityDrivenExplorationRequirement {
        subject robot = developmentalRobot;
    }

    requirement memoryConsolidation: MemoryConsolidationRequirement {
        subject robot = developmentalRobot;
    }

    satisfy primaryFunction by developmentalRobot;
    satisfy embodiedPerception by developmentalRobot.sensors;
    satisfy incrementalSkillAcquisition by developmentalRobot.cognition.skillLibrary;
    satisfy safeHumanInteraction by developmentalRobot.cognition.safetySupervisor;
    satisfy manipulationSafety by developmentalRobot.cognition.safetySupervisor;
    satisfy realTimeSafetySupervision by developmentalRobot.cognition.safetySupervisor;
    satisfy powerAutonomy by developmentalRobot.power;
    satisfy socialLearning by developmentalRobot.humanInterface;
    satisfy curiosityDrivenExploration by developmentalRobot.cognition.curiosityEngine;
    satisfy memoryConsolidation by developmentalRobot.cognition.episodicMemory;
}
