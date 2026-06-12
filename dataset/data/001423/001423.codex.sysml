package EvolutionaryRoboticsSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;
  import Time::*;
  import Performances::*;

  attribute def FitnessScore : Real {
    doc /* Dimensionless normalized evolutionary fitness score. */
  }

  attribute def GenerationIndex : Integer;
  attribute def PopulationCount : Integer;
  attribute def MutationRate : Real;
  attribute def CrossoverRate : Real;
  attribute def SurvivalRate : Real;
  attribute def EnergyJoule : Real;
  attribute def DistanceMeter : Real;
  attribute def SpeedMeterPerSecond : Real;
  attribute def Probability : Real;
  attribute def RuntimeSecond : Real;

  item def SensorFrame {
    attribute timestamp : RuntimeSecond;
    attribute rangeMap : DistanceMeter[64];
    attribute contactDetected : Boolean;
    attribute inertialYawRate : Real;
    attribute batteryEnergy : EnergyJoule;
  }

  item def MotorCommand {
    attribute leftWheelSpeed : SpeedMeterPerSecond;
    attribute rightWheelSpeed : SpeedMeterPerSecond;
    attribute armJointTorque : Real;
    attribute validFor : RuntimeSecond;
  }

  item def Genome {
    attribute genomeId : String;
    attribute generation : GenerationIndex;
    attribute neuralWeights : Real[128];
    attribute morphologyParameters : Real[16];
    attribute mutationRate : MutationRate;
  }

  item def Phenotype {
    attribute bodyLength : DistanceMeter;
    attribute wheelRadius : DistanceMeter;
    attribute sensorFov : Real;
    attribute controllerWeights : Real[128];
  }

  item def TrialResult {
    attribute genomeId : String;
    attribute distanceCovered : DistanceMeter;
    attribute obstaclesAvoided : Integer;
    attribute collisions : Integer;
    attribute energyConsumed : EnergyJoule;
    attribute elapsedTime : RuntimeSecond;
    attribute fitness : FitnessScore;
  }

  port def SensorDataPort {
    out item frame : SensorFrame;
  }

  port def MotorControlPort {
    in item command : MotorCommand;
  }

  port def GenomePort {
    inout item genome : Genome;
  }

  port def PhenotypePort {
    out item phenotype : Phenotype;
  }

  port def TrialResultPort {
    out item result : TrialResult;
  }

  port def EvaluationPort {
    in item result : TrialResult;
  }

  action def DecodeGenome {
    in item genome : Genome;
    out item phenotype : Phenotype;
  }

  action def SenseEnvironment {
    out item frame : SensorFrame;
  }

  action def ComputeControl {
    in item frame : SensorFrame;
    in item phenotype : Phenotype;
    out item command : MotorCommand;
  }

  action def ExecuteMotion {
    in item command : MotorCommand;
    out attribute distanceIncrement : DistanceMeter;
    out attribute energyIncrement : EnergyJoule;
  }

  action def EvaluateFitness {
    in item result : TrialResult;
    out attribute fitness : FitnessScore;
  }

  action def SelectParents {
    in item evaluatedResults : TrialResult[*];
    out item parentGenomes : Genome[*];
  }

  action def RecombineAndMutate {
    in item parentGenomes : Genome[*];
    out item offspringGenomes : Genome[*];
  }

  action def ReplacePopulation {
    in item currentPopulation : Genome[*];
    in item offspringGenomes : Genome[*];
    out item nextPopulation : Genome[*];
  }

  part def MobileRobot {
    port sensorOut : SensorDataPort;
    port motorIn : MotorControlPort;
    port phenotypeOut : PhenotypePort;

    attribute availableEnergy : EnergyJoule;
    attribute mass : Real;
    attribute maximumSpeed : SpeedMeterPerSecond;
    attribute collisionCount : Integer;

    part rangeSensor {
      attribute scanRate : Real;
      attribute maximumRange : DistanceMeter;
    }

    part inertialUnit {
      attribute yawRateNoiseStdDev : Real;
    }

    part driveTrain {
      attribute wheelBase : DistanceMeter;
      attribute wheelRadius : DistanceMeter;
      attribute maximumWheelSpeed : SpeedMeterPerSecond;
    }

    part embeddedController {
      attribute controlPeriod : RuntimeSecond;
      attribute neuralLayerCount : Integer;
      attribute neuralWeightCount : Integer;
    }

    perform action sense : SenseEnvironment {
      out frame = sensorOut.frame;
    }

    perform action control : ComputeControl;

    perform action move : ExecuteMotion {
      in command = motorIn.command;
    }

    state behavior RobotOperation {
      state poweredOff;
      state booting;
      state ready;
      state navigating;
      state faulted;

      entry;
      then poweredOff;

      transition powerApplied
        first poweredOff
        then booting;

      transition initializationComplete
        first booting
        then ready;

      transition trialStarted
        first ready
        then navigating;

      transition trialCompleted
        first navigating
        then ready;

      transition severeCollision
        first navigating
        then faulted;

      transition reset
        first faulted
        then ready;
    }
  }

  part def SimulationArena {
    port resultOut : TrialResultPort;

    attribute arenaLength : DistanceMeter;
    attribute arenaWidth : DistanceMeter;
    attribute obstacleCount : Integer;
    attribute maximumTrialDuration : RuntimeSecond;
    attribute targetDistance : DistanceMeter;

    part obstacleField {
      attribute obstacleRadiusMean : DistanceMeter;
      attribute obstacleSpacingMean : DistanceMeter;
    }

    action runTrial {
      in item phenotype : Phenotype;
      out item result : TrialResult;
    }
  }

  part def EvolutionEngine {
    port genomeExchange : GenomePort;
    port evaluationIn : EvaluationPort;

    attribute populationSize : PopulationCount;
    attribute activeGeneration : GenerationIndex;
    attribute mutationRate : MutationRate;
    attribute crossoverRate : CrossoverRate;
    attribute eliteSurvivalRate : SurvivalRate;
    attribute bestFitness : FitnessScore;
    attribute terminationFitness : FitnessScore;
    attribute maximumGenerations : GenerationIndex;

    part populationArchive {
      attribute retainedGenerationCount : Integer;
      item storedGenomes : Genome[*];
      item storedResults : TrialResult[*];
    }

    perform action select : SelectParents;
    perform action reproduce : RecombineAndMutate;
    perform action replace : ReplacePopulation;

    state behavior EvolutionCycle {
      state initialized;
      state decodingPopulation;
      state evaluatingPopulation;
      state rankingPopulation;
      state generatingOffspring;
      state complete;

      entry;
      then initialized;

      transition startRun
        first initialized
        then decodingPopulation;

      transition allGenomesDecoded
        first decodingPopulation
        then evaluatingPopulation;

      transition allTrialsEvaluated
        first evaluatingPopulation
        then rankingPopulation;

      transition fitnessBelowTermination
        first rankingPopulation
        then generatingOffspring;

      transition nextGenerationReady
        first generatingOffspring
        then decodingPopulation;

      transition targetFitnessReached
        first rankingPopulation
        then complete;

      transition generationLimitReached
        first rankingPopulation
        then complete;
    }
  }

  part def GenomeDecoder {
    port genomeIn : GenomePort;
    port phenotypeOut : PhenotypePort;

    attribute minimumBodyLength : DistanceMeter;
    attribute maximumBodyLength : DistanceMeter;
    attribute minimumWheelRadius : DistanceMeter;
    attribute maximumWheelRadius : DistanceMeter;

    perform action decode : DecodeGenome {
      in genome = genomeIn.genome;
      out phenotype = phenotypeOut.phenotype;
    }
  }

  part def FitnessEvaluator {
    port trialIn : EvaluationPort;

    attribute distanceWeight : Real;
    attribute collisionPenaltyWeight : Real;
    attribute energyPenaltyWeight : Real;
    attribute timePenaltyWeight : Real;

    perform action evaluate : EvaluateFitness;
  }

  part def EvolutionaryRoboticsPlatform {
    doc /* Primary function: autonomously evolve robot body and controller designs by repeatedly generating candidate genomes, decoding them into robot phenotypes, testing them in a navigation arena, scoring their performance, and breeding improved generations. */

    attribute designPopulationSize : PopulationCount = 80;
    attribute nominalMutationRate : MutationRate = 0.035;
    attribute nominalCrossoverRate : CrossoverRate = 0.72;
    attribute maximumRunTime : RuntimeSecond = 7200.0;
    attribute requiredTargetDistance : DistanceMeter = 25.0;
    attribute requiredMinimumFitness : FitnessScore = 0.88;

    part engine : EvolutionEngine {
      attribute populationSize = 80;
      attribute mutationRate = 0.035;
      attribute crossoverRate = 0.72;
      attribute eliteSurvivalRate = 0.10;
      attribute terminationFitness = 0.88;
      attribute maximumGenerations = 150;
    }

    part decoder : GenomeDecoder {
      attribute minimumBodyLength = 0.18;
      attribute maximumBodyLength = 0.45;
      attribute minimumWheelRadius = 0.025;
      attribute maximumWheelRadius = 0.080;
    }

    part robot : MobileRobot {
      attribute availableEnergy = 18000.0;
      attribute mass = 2.4;
      attribute maximumSpeed = 1.2;
    }

    part arena : SimulationArena {
      attribute arenaLength = 30.0;
      attribute arenaWidth = 18.0;
      attribute obstacleCount = 42;
      attribute maximumTrialDuration = 180.0;
      attribute targetDistance = 25.0;
    }

    part evaluator : FitnessEvaluator {
      attribute distanceWeight = 0.55;
      attribute collisionPenaltyWeight = 0.25;
      attribute energyPenaltyWeight = 0.12;
      attribute timePenaltyWeight = 0.08;
    }

    connect engine.genomeExchange to decoder.genomeIn;
    connect decoder.phenotypeOut to robot.phenotypeOut;
    connect robot.sensorOut to robot.embeddedController;
    connect robot.motorIn to robot.driveTrain;
    connect arena.resultOut to evaluator.trialIn;
    connect arena.resultOut to engine.evaluationIn;

    state behavior PlatformMission {
      state idle;
      state preparingInitialPopulation;
      state evolutionaryOptimization;
      state validatingBestRobot;
      state reportingDesign;
      state halted;

      entry;
      then idle;

      transition missionCommanded
        first idle
        then preparingInitialPopulation;

      transition initialPopulationReady
        first preparingInitialPopulation
        then evolutionaryOptimization;

      transition optimizationComplete
        first evolutionaryOptimization
        then validatingBestRobot;

      transition validationPassed
        first validatingBestRobot
        then reportingDesign;

      transition validationFailed
        first validatingBestRobot
        then evolutionaryOptimization;

      transition reportDelivered
        first reportingDesign
        then halted;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject platform : EvolutionaryRoboticsPlatform;
    require constraint {
      platform.requiredMinimumFitness >= 0.85
    }
    doc /* The platform shall evolve robot morphology and control policies until a candidate robot achieves the minimum target fitness in the navigation arena. */
  }

  requirement def PopulationRequirement {
    subject platform : EvolutionaryRoboticsPlatform;
    require constraint {
      platform.designPopulationSize >= 50
    }
    doc /* The evolutionary engine shall maintain enough candidate genomes per generation to preserve behavioral diversity. */
  }

  requirement def NavigationPerformanceRequirement {
    subject platform : EvolutionaryRoboticsPlatform;
    require constraint {
      platform.requiredTargetDistance >= 25.0
    }
    doc /* The evolved robot shall be optimized to traverse at least the target arena distance while avoiding obstacles. */
  }

  requirement def MutationBoundRequirement {
    subject platform : EvolutionaryRoboticsPlatform;
    require constraint {
      platform.nominalMutationRate > 0.0 and platform.nominalMutationRate <= 0.10
    }
    doc /* Mutation rate shall be nonzero but bounded to prevent random search from dominating inheritance. */
  }

  requirement def RuntimeRequirement {
    subject platform : EvolutionaryRoboticsPlatform;
    require constraint {
      platform.maximumRunTime <= 7200.0
    }
    doc /* The evolutionary run shall complete within the allocated experiment time. */
  }

  satisfy PrimaryFunctionRequirement by EvolutionaryRoboticsPlatform;
  satisfy PopulationRequirement by EvolutionaryRoboticsPlatform;
  satisfy NavigationPerformanceRequirement by EvolutionaryRoboticsPlatform;
  satisfy MutationBoundRequirement by EvolutionaryRoboticsPlatform;
  satisfy RuntimeRequirement by EvolutionaryRoboticsPlatform;
}