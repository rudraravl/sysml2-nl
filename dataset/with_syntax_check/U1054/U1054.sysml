package EvolutionaryRoboticsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FitnessScore :> Real;
    attribute def GenerationCount :> Integer;
    attribute def PopulationSize :> Integer;
    attribute def MutationProbability :> Real;
    
    value def NeuralGenome {
        attribute connectionWeights : Real[*];
        attribute nodeActivationThresholds : Real[*];
        attribute topologyEncoding : Integer[*];
        attribute fitnessHistory : FitnessScore[*];
    }
    
    value def EvolutionParameters {
        attribute populationSize : PopulationSize = 100;
        attribute maxGenerations : GenerationCount = 200;
        attribute mutationRate : MutationProbability = 0.15;
        attribute crossoverRate : Real = 0.75;
        attribute elitismRatio : Real = 0.10;
        attribute tournamentSize : Integer = 5;
    }
    
    item def SensorData {
        attribute proximityReadings : LengthValue[8];
        attribute lightIntensity : Real[4];
        attribute groundReflectance : Real[2];
        attribute timestamp : TimeValue;
    }
    
    item def ActuatorCommands {
        attribute leftMotorVelocity : AngularVelocityValue;
        attribute rightMotorVelocity : AngularVelocityValue;
        attribute timestamp : TimeValue;
    }
    
    item def PerformanceMetrics {
        attribute distanceTraveled : LengthValue;
        attribute targetProximity : LengthValue;
        attribute energyEfficiency : Real;
        attribute collisionCount : Integer;
        attribute taskCompletionTime : TimeValue;
        attribute behavioralComplexity : Real;
    }
    
    port def SensorInterface {
        out sensorReadings : SensorData;
    }
    
    port def ActuatorInterface {
        in motorCommands : ActuatorCommands;
    }
    
    port def GenomeInterface {
        in controllerGenome : NeuralGenome;
        out performanceData : PerformanceMetrics;
    }
    
    part def PhysicalRobot {
        attribute robotMass : MassValue = 0.5[kg];
        attribute wheelRadius : LengthValue = 0.03[m];
        attribute wheelBase : LengthValue = 0.12[m];
        attribute batteryCapacity : EnergyValue = 50.0[J];
        attribute currentEnergy : EnergyValue;
        
        port sensors : SensorInterface;
        port actuators : ActuatorInterface;
        port genomePort : GenomeInterface;
        
        part proximityArray : ProximitySensorArray[8];
        part lightSensors : LightSensor[4];
        part groundSensors : GroundSensor[2];
        part leftMotor : DCMotor;
        part rightMotor : DCMotor;
        part neuralController : NeuralNetworkController;
        
        connection sensorToController connect proximityArray.output to neuralController.sensorInput;
        connection controllerToMotor connect neuralController.motorOutput to leftMotor.commandInput;
        connection controllerToMotor2 connect neuralController.motorOutput to rightMotor.commandInput;
    }
    
    part def ProximitySensorArray {
        attribute sensorCount : Integer = 8;
        attribute maxRange : LengthValue = 0.5[m];
        port output {
            out distances : LengthValue[8];
        }
    }
    
    part def LightSensor {
        attribute sensitivity : Real = 1.0;
        port output {
            out intensity : Real;
        }
    }
    
    part def GroundSensor {
        port output {
            out reflectance : Real;
        }
    }
    
    part def DCMotor {
        attribute maxTorque : TorqueValue = 0.1[N*m];
        attribute maxSpeed : AngularVelocityValue = 10.0[rad/s];
        port commandInput {
            in targetVelocity : AngularVelocityValue;
        }
    }
    
    part def NeuralNetworkController {
        attribute genome : NeuralGenome;
        attribute inputNodes : Integer = 14;
        attribute hiddenNodes : Integer = 8;
        attribute outputNodes : Integer = 2;
        
        port sensorInput {
            in readings : SensorData;
        }
        port motorOutput {
            out commands : ActuatorCommands;
        }
    }
    
    part def SimulationEnvironment {
        attribute arenaLength : LengthValue = 5.0[m];
        attribute arenaWidth : LengthValue = 5.0[m];
        attribute obstacleCount : Integer = 10;
        attribute targetLocation : LengthValue[2];
        attribute simulationTimeStep : TimeValue = 0.01[s];
        attribute maxSimulationTime : TimeValue = 120.0[s];
        
        port environmentInterface {
            in robotPosition : LengthValue[2];
            in robotOrientation : Real;
            out obstaclePositions : LengthValue[*];
            out targetDistance : LengthValue;
        }
    }
    
    part def GeneticOperatorEngine {
        attribute mutationRate : MutationProbability;
        attribute crossoverRate : Real;
        
        port operatorInterface {
            in parentGenomes : NeuralGenome[*];
            out offspringGenomes : NeuralGenome[*];
        }
    }
    
    part def FitnessEvaluationModule {
        attribute targetReachThreshold : LengthValue = 0.2[m];
        attribute collisionPenalty : Real = 50.0;
        attribute efficiencyWeight : Real = 0.3;
        
        port evaluationInterface {
            in metrics : PerformanceMetrics;
            out fitness : FitnessScore;
        }
    }
    
    part def PopulationManager {
        attribute currentGeneration : GenerationCount = 0;
        attribute populationSize : PopulationSize;
        
        port populationInterface {
            out currentPopulation : NeuralGenome[*];
            in evaluatedPopulation : NeuralGenome[*];
            in fitnessScores : FitnessScore[*];
        }
    }
    
    action def SenseEnvironment {
        in robotPosition : LengthValue[2];
        in robotOrientation : Real;
        in obstacleMap : LengthValue[*];
        in targetPosition : LengthValue[2];
        out sensorData : SensorData;
    }
    
    action def ExecuteNeuralControl {
        in genome : NeuralGenome;
        in sensorInputs : SensorData;
        out motorOutputs : ActuatorCommands;
    }
    
    action def UpdateRobotPhysics {
        in leftWheelVelocity : AngularVelocityValue;
        in rightWheelVelocity : AngularVelocityValue;
        in currentPosition : LengthValue[2];
        in currentOrientation : Real;
        in deltaTime : TimeValue;
        in wheelRadius : LengthValue;
        in wheelBase : LengthValue;
        out newPosition : LengthValue[2];
        out newOrientation : Real;
        out distanceMoved : LengthValue;
    }
    
    action def ComputeFitness {
        in performanceMetrics : PerformanceMetrics;
        in targetReachThreshold : LengthValue;
        in collisionPenalty : Real;
        in efficiencyWeight : Real;
        out fitnessScore : FitnessScore;
    }
    
    action def SelectParents {
        in population : NeuralGenome[*];
        in fitnessScores : FitnessScore[*];
        in tournamentSize : Integer;
        in selectionCount : Integer;
        out selectedParents : NeuralGenome[*];
    }
    
    action def PerformCrossover {
        in parent1 : NeuralGenome;
        in parent2 : NeuralGenome;
        in crossoverRate : Real;
        out offspring1 : NeuralGenome;
        out offspring2 : NeuralGenome;
    }
    
    action def MutateGenome {
        in genome : NeuralGenome;
        in mutationRate : MutationProbability;
        out mutatedGenome : NeuralGenome;
    }
    
    action def SimulateRobotTrial {
        in robotGenome : NeuralGenome;
        in environmentArenaLength : LengthValue;
        in environmentArenaWidth : LengthValue;
        in environmentObstacleCount : Integer;
        in environmentTargetLocation : LengthValue[2];
        in environmentSimulationTimeStep : TimeValue;
        in environmentMaxSimulationTime : TimeValue;
        out trialMetrics : PerformanceMetrics;
        
        private attribute currentTime : TimeValue := 0.0[s];
        private attribute robotPos : LengthValue[2] := (0.0[m], 0.0[m]);
        private attribute robotAngle : Real := 0.0;
        private attribute totalDistance : LengthValue := 0.0[m];
        private attribute collisions : Integer := 0;
        
        first start;
        then merge simulationLoop;
        then decide;
            if currentTime < environmentMaxSimulationTime then continueSimulation;
            else finishSimulation;
        action continueSimulation {
            first action sense : SenseEnvironment {
                in robotPosition = robotPos;
                in robotOrientation = robotAngle;
                in obstacleMap;
                in targetPosition;
                out sensorData;
            }
            then action control : ExecuteNeuralControl {
                in genome = robotGenome;
                in sensorInputs = sense.sensorData;
                out motorOutputs;
            }
            then action physics : UpdateRobotPhysics {
                in leftWheelVelocity = control.motorOutputs.leftMotorVelocity;
                in rightWheelVelocity = control.motorOutputs.rightMotorVelocity;
                in currentPosition = robotPos;
                in currentOrientation = robotAngle;
                in deltaTime = environmentSimulationTimeStep;
                in wheelRadius = 0.03[m];
                in wheelBase = 0.12[m];
                out newPosition;
                out newOrientation;
                out distanceMoved;
            }
            then assign robotPos := physics.newPosition;
            then assign robotAngle := physics.newOrientation;
            then assign totalDistance := totalDistance + physics.distanceMoved;
            then assign currentTime := currentTime + environmentSimulationTimeStep;
        }
        then simulationLoop;
        action finishSimulation;
        then done;
    }
    
    action def EvaluateIndividual {
        in genome : NeuralGenome;
        in environmentArenaLength : LengthValue;
        in environmentArenaWidth : LengthValue;
        in environmentObstacleCount : Integer;
        in environmentTargetLocation : LengthValue[2];
        in environmentSimulationTimeStep : TimeValue;
        in environmentMaxSimulationTime : TimeValue;
        in evaluationModuleTargetReachThreshold : LengthValue;
        in evaluationModuleCollisionPenalty : Real;
        in evaluationModuleEfficiencyWeight : Real;
        out fitness : FitnessScore;
        
        first start;
        then action simulate : SimulateRobotTrial {
            in robotGenome = genome;
            in environmentArenaLength;
            in environmentArenaWidth;
            in environmentObstacleCount;
            in environmentTargetLocation;
            in environmentSimulationTimeStep;
            in environmentMaxSimulationTime;
            out trialMetrics;
        }
        then action evaluate : ComputeFitness {
            in performanceMetrics = simulate.trialMetrics;
            in targetReachThreshold = evaluationModuleTargetReachThreshold;
            in collisionPenalty = evaluationModuleCollisionPenalty;
            in efficiencyWeight = evaluationModuleEfficiencyWeight;
            out fitnessScore;
        }
        then assign fitness := evaluate.fitnessScore;
        then done;
    }
    
    action def EvolveGeneration {
        in currentPopulation : NeuralGenome[*];
        in currentFitness : FitnessScore[*];
        in evolutionParams : EvolutionParameters;
        out nextPopulation : NeuralGenome[*];
        
        private attribute eliteCount : Integer := 10;
        private attribute offspringCount : Integer := 90;
        private attribute newGenomes : NeuralGenome[*] := ();
        
        first start;
        then action preserveElites {
            for i in 1..eliteCount {
                assign newGenomes := newGenomes->including(currentPopulation->at(i));
            }
        }
        then merge breedingLoop;
        then decide;
            if newGenomes->size() < evolutionParams.populationSize then continueBreeding;
            else finalize;
        action continueBreeding {
            first action selectForBreeding : SelectParents {
                in population = currentPopulation;
                in fitnessScores = currentFitness;
                in tournamentSize = evolutionParams.tournamentSize;
                in selectionCount = 2;
                out selectedParents;
            }
            then action crossover : PerformCrossover {
                in parent1 = selectForBreeding.selectedParents->at(1);
                in parent2 = selectForBreeding.selectedParents->at(2);
                in crossoverRate = evolutionParams.crossoverRate;
                out offspring1;
                out offspring2;
            }
            then action mutate1 : MutateGenome {
                in genome = crossover.offspring1;
                in mutationRate = evolutionParams.mutationRate;
                out mutatedGenome;
            }
            then action mutate2 : MutateGenome {
                in genome = crossover.offspring2;
                in mutationRate = evolutionParams.mutationRate;
                out mutatedGenome;
            }
            then assign newGenomes := newGenomes->including(mutate1.mutatedGenome);
            then assign newGenomes := newGenomes->including(mutate2.mutatedGenome);
        }
        then breedingLoop;
        action finalize;
        then assign nextPopulation := newGenomes;
        then done;
    }
    
    action def RunEvolutionaryProcess {
        in initialPopulation : NeuralGenome[*];
        in environmentArenaLength : LengthValue;
        in environmentArenaWidth : LengthValue;
        in environmentObstacleCount : Integer;
        in environmentTargetLocation : LengthValue[2];
        in environmentSimulationTimeStep : TimeValue;
        in environmentMaxSimulationTime : TimeValue;
        in evolutionParams : EvolutionParameters;
        in evaluationModuleTargetReachThreshold : LengthValue;
        in evaluationModuleCollisionPenalty : Real;
        in evaluationModuleEfficiencyWeight : Real;
        out bestGenome : NeuralGenome;
        out bestFitness : FitnessScore;
        out convergenceHistory : FitnessScore[*];
        
        private attribute population := initialPopulation;
        private attribute generation : GenerationCount := 0;
        private attribute fitnessScores : FitnessScore[*] := ();
        private attribute maxFitness : FitnessScore := 0.0;
        private attribute history : FitnessScore[*] := ();
        
        first start;
        then merge evolutionLoop;
        then decide;
            if generation < evolutionParams.maxGenerations then continueEvolution;
            else finishEvolution;
        action continueEvolution {
            first assign fitnessScores := ();
            then action evaluatePopulation {
                for individual in population {
                    perform action eval : EvaluateIndividual {
                        in genome = individual;
                        in environmentArenaLength;
                        in environmentArenaWidth;
                        in environmentObstacleCount;
                        in environmentTargetLocation;
                        in environmentSimulationTimeStep;
                        in environmentMaxSimulationTime;
                        in evaluationModuleTargetReachThreshold;
                        in evaluationModuleCollisionPenalty;
                        in evaluationModuleEfficiencyWeight;
                        out fitness;
                    }
                    then assign fitnessScores := fitnessScores->including(eval.fitness);
                }
            }
            then action findBest {
                assign maxFitness := fitnessScores->max();
                private attribute bestIndex := fitnessScores->indexOf(maxFitness);
                assign bestGenome := population->at(bestIndex);
                assign bestFitness := maxFitness;
                assign history := history->including(maxFitness);
            }
            then action evolve : EvolveGeneration {
                in currentPopulation = population;
                in currentFitness = fitnessScores;
                in evolutionParams;
                out nextPopulation;
            }
            then assign population := evolve.nextPopulation;
            then assign generation := generation + 1;
        }
        then evolutionLoop;
        action finishEvolution;
        then assign convergenceHistory := history;
        then done;
    }
    
    part evolutionaryRoboticsSystem {
        attribute systemParams : EvolutionParameters {
            attribute populationSize = 100;
            attribute maxGenerations = 200;
            attribute mutationRate = 0.15;
            attribute crossoverRate = 0.75;
            attribute elitismRatio = 0.10;
            attribute tournamentSize = 5;
        }
        
        part simulationEnv : SimulationEnvironment {
            attribute arenaLength = 5.0[m];
            attribute arenaWidth = 5.0[m];
            attribute obstacleCount = 10;
            attribute targetLocation = (4.0[m], 4.0[m]);
            attribute simulationTimeStep = 0.01[s];
            attribute maxSimulationTime = 120.0[s];
        }
        
        part fitnessEval : FitnessEvaluationModule {
            attribute targetReachThreshold = 0.2[m];
            attribute collisionPenalty = 50.0;
            attribute efficiencyWeight = 0.3;
        }
        
        part populationMgr : PopulationManager {
            attribute currentGeneration = 0;
            attribute populationSize = systemParams.populationSize;
        }
        
        part geneticOps : GeneticOperatorEngine {
            attribute mutationRate = systemParams.mutationRate;
            attribute crossoverRate = systemParams.crossoverRate;
        }
        
        part robotPrototype : PhysicalRobot {
            attribute robotMass = 0.5[kg];
            attribute wheelRadius = 0.03[m];
            attribute wheelBase = 0.12[m];
            attribute batteryCapacity = 50.0[J];
        }
        
        connection populationToGenetic connect 
            populationMgr.populationInterface.currentPopulation to 
            geneticOps.operatorInterface.parentGenomes;
        
        connection geneticToPopulation connect 
            geneticOps.operatorInterface.offspringGenomes to 
            populationMgr.populationInterface.evaluatedPopulation;
        
        perform action mainEvolution : RunEvolutionaryProcess {
            in initialPopulation;
            in environmentArenaLength = simulationEnv.arenaLength;
            in environmentArenaWidth = simulationEnv.arenaWidth;
            in environmentObstacleCount = simulationEnv.obstacleCount;
            in environmentTargetLocation = simulationEnv.targetLocation;
            in environmentSimulationTimeStep = simulationEnv.simulationTimeStep;
            in environmentMaxSimulationTime = simulationEnv.maxSimulationTime;
            in evolutionParams = systemParams;
            in evaluationModuleTargetReachThreshold = fitnessEval.targetReachThreshold;
            in evaluationModuleCollisionPenalty = fitnessEval.collisionPenalty;
            in evaluationModuleEfficiencyWeight = fitnessEval.efficiencyWeight;
            out bestGenome;
            out bestFitness;
            out convergenceHistory;
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The Evolutionary Robotics System shall autonomously evolve neural network 
                controllers for mobile robots through simulated natural selection, enabling 
                robots to develop adaptive navigation and task-completion behaviors without 
                explicit programming of control strategies. */
    }
    
    requirement def EvolutionaryOptimizationRequirement {
        doc /* The system shall optimize robot controller performance through iterative 
                genetic algorithm cycles of evaluation, selection, crossover, and mutation. */
        
        require constraint fitnessImprovement {
            doc /* Average population fitness shall increase by at least 15% every 50 generations. */
        }
        
        require constraint convergenceStability {
            doc /* Best fitness shall stabilize within 5% variation over final 20 generations. */
        }
    }
    
    requirement def BehavioralAdaptationRequirement {
        doc /* Evolved controllers shall demonstrate emergent adaptive behaviors in navigation tasks. */
        
        require constraint targetReaching {
            doc /* Best evolved robot shall reach target location within 0.2m in at least 90% of trials. */
        }
        
        require constraint obstacleAvoidance {
            doc /* Collision rate shall be reduced to below 5% of simulation time. */
        }
        
        require constraint energyEfficiency {
            doc /* Evolved controllers shall achieve task completion with 30% less energy than baseline. */
        }
    }
    
    requirement def GeneticDiversityRequirement {
        doc /* The evolutionary process shall maintain sufficient genetic diversity to avoid premature convergence. */
        
        require constraint populationVariance {
            doc /* Genome variance across population shall remain above 20% of maximum possible variance. */
        }
        
        require constraint elitismBalance {
            doc /* Elite preservation shall not exceed 15% of population to ensure exploration. */
        }
    }
    
    requirement def SimulationFidelityRequirement {
        doc /* Physics simulation shall accurately represent real robot dynamics and sensor characteristics. */
        
        require constraint physicsAccuracy {
            doc /* Simulation time step shall be 0.01s or smaller for numerical stability. */
        }
        
        require constraint sensorRealism {
            doc /* Simulated sensors shall model noise and range limitations of physical counterparts. */
        }
    }
    
    requirement systemRequirements {
        subject evolutionaryRoboticsSystem;
        
        doc /* Top-level requirements for the Evolutionary Robotics System governing autonomous 
                controller evolution, behavioral adaptation, and simulation fidelity. */
        
        require primaryFunction : PrimaryFunctionRequirement;
        require evolutionaryOptimization : EvolutionaryOptimizationRequirement;
        require behavioralAdaptation : BehavioralAdaptationRequirement;
        require geneticDiversity : GeneticDiversityRequirement;
        require simulationFidelity : SimulationFidelityRequirement;
        
        assume constraint initialPopulationValidity {
            doc /* Initial robot genomes shall be randomly generated with valid network topologies. */
        }
        
        assume constraint computationalResources {
            doc /* Sufficient computational resources shall be available to complete 200 generations 
                    with population size 100 within 24 hours. */
        }
    }
}
