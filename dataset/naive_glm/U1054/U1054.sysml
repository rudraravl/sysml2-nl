package EvolutionaryRobotics {

    import ScalarValues::*;
    import ScalarFunctions::*;

    package Units {
        value type m { unit 'm'; }
        value type m_per_s { unit 'm/s'; }
        value type rad { unit 'rad'; }
        value type s { unit 's'; }
        value type J { unit 'J'; }
        value type lux { unit 'lux'; }
        value type dimensionless { unit '1'; }
    }

    package ValueTypes {
        import Units::*;

        value type Distance :> Real { unit 'm'; }
        value type Speed :> Real { unit 'm/s'; }
        value type AngularSpeed :> Real { unit 'rad/s'; }
        value type Angle :> Real { unit 'rad'; }
        value type Duration :> Real { unit 's'; }
        value type Energy :> Real { unit 'J'; }
        value type Power :> Real { unit 'W'; }
        value type FitnessScore :> Real { unit '1'; }
        value type Weight :> Real { unit '1'; }
        value type Reflectance :> Real { unit '1'; }
        value type Proximity :> Real { unit 'm'; }
        value type LightIntensity :> Real { unit 'lux'; }
        value type MotorCommand :> Real { unit '1'; }
        value type CollisionCount :> Integer { unit '1'; }
        value type GenerationNumber :> Integer { unit '1'; }
        value type PopulationSize :> Integer { unit '1'; }
        value type MutationRate :> Real { unit '1'; }
        value type CrossoverRate :> Real { unit '1'; }
        value type EliteFraction :> Real { unit '1'; }
    }

    package Items {
        import ValueTypes::*;

        item def SensorData {
            attribute values : Real[0..*];
        }

        item def ProximityData :> SensorData {
            attribute values : Proximity[8];
        }

        item def LightData :> SensorData {
            attribute values : LightIntensity[4];
        }

        item def GroundData :> SensorData {
            attribute values : Reflectance[2];
        }

        item def MotorCommands {
            attribute leftCommand : MotorCommand;
            attribute rightCommand : MotorCommand;
        }

        item def TrialMetrics {
            attribute distanceTraveled : Distance;
            attribute closestApproach : Distance;
            attribute collisions : CollisionCount;
            attribute energyUsed : Energy;
            attribute timeElapsed : Duration;
            attribute reachedTarget : Boolean;
            attribute finalSpeed : Speed;
        }

        item def Genome {
            attribute weights : Weight[0..*];
            attribute biases : Weight[0..*];
            attribute numInputs : Integer;
            attribute numHidden : Integer;
            attribute numOutputs : Integer;
        }

        item def Individual {
            attribute id : String;
            attribute genome : Genome;
            attribute fitness : FitnessScore;
            attribute metrics : TrialMetrics;
            attribute isElite : Boolean;
            attribute rank : Integer;
        }

        item def Population {
            attribute individuals : Individual[0..*];
            attribute generation : GenerationNumber;
            attribute bestFitness : FitnessScore;
            attribute meanFitness : FitnessScore;
        }

        item def Obstacle {
            attribute positionX : Distance;
            attribute positionY : Distance;
            attribute radius : Distance;
        }

        item def Target {
            attribute positionX : Distance;
            attribute positionY : Distance;
            attribute radius : Distance;
        }

        item def ArenaGeometry {
            attribute width : Distance;
            attribute height : Distance;
            attribute obstacles : Obstacle[0..*];
            attribute target : Target;
        }
    }

    package Ports {
        import Items::*;

        port def SensorOutPort {
            out item data : SensorData;
        }

        port def MotorInPort {
            in item commands : MotorCommands;
        }

        port def GenomeOutPort {
            out item genome : Genome;
        }

        port def MetricsOutPort {
            out item metrics : TrialMetrics;
        }

        port def FitnessOutPort {
            out item fitness : FitnessScore;
        }

        port def PopulationOutPort {
            out item population : Population;
        }

        port def PopulationInPort {
            in item population : Population;
        }

        port def IndividualOutPort {
            out item individual : Individual;
        }

        port def IndividualInPort {
            in item individual : Individual;
        }
    }

    package RobotParts {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def ProximitySensorArray {
            attribute readings : Proximity[8];
            out port sensorOut : SensorOutPort;
            action def Sense {
                in environment : ArenaGeometry;
                out reading : Proximity[8];
            }
        }

        part def LightSensorArray {
            attribute readings : LightIntensity[4];
            out port sensorOut : SensorOutPort;
            action def Sense {
                in environment : ArenaGeometry;
                out reading : LightIntensity[4];
            }
        }

        part def GroundSensorArray {
            attribute readings : Reflectance[2];
            out port sensorOut : SensorOutPort;
            action def Sense {
                in environment : ArenaGeometry;
                out reading : Reflectance[2];
            }
        }

        part def DCMotor {
            attribute command : MotorCommand;
            attribute angularSpeed : AngularSpeed;
            attribute powerDraw : Power;
            in port commandIn : MotorInPort;
            action def Drive {
                in cmd : MotorCommand;
                out speed : AngularSpeed;
                out power : Power;
            }
        }

        part def NeuralNetworkController {
            attribute genome : Genome;
            attribute hiddenActivations : Real[0..*];
            attribute outputActivations : Real[0..*];
            in port sensorIn : SensorOutPort;
            out port motorOut : MotorInPort;

            action def ComputeOutput {
                in sensorInput : SensorData;
                in genome : Genome;
                out motorOutput : MotorCommands;
            }

            action def Activate {
                in inputs : Real[0..*];
                in weights : Weight[0..*];
                in biases : Weight[0..*];
                out activations : Real[0..*];
            }
        }

        part def MobileRobot {
            attribute positionX : Distance;
            attribute positionY : Distance;
            attribute heading : Angle;
            attribute speed : Speed;
            attribute energyConsumed : Energy;
            attribute collisionCount : CollisionCount;

            part proximitySensors : ProximitySensorArray;
            part lightSensors : LightSensorArray;
            part groundSensors : GroundSensorArray;
            part leftMotor : DCMotor;
            part rightMotor : DCMotor;
            part controller : NeuralNetworkController;

            connection proxToController connect proximitySensors.sensorOut to controller.sensorIn;
            connection lightToController connect lightSensors.sensorOut to controller.sensorIn;
            connection groundToController connect groundSensors.sensorOut to controller.sensorIn;
            connection controllerToLeftMotor connect controller.motorOut to leftMotor.commandIn;
            connection controllerToRightMotor connect controller.motorOut to rightMotor.commandIn;

            action def Step {
                in arena : ArenaGeometry;
                in dt : Duration;
                out metrics : TrialMetrics;
            }
        }
    }

    package Environment {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        import RobotParts::*;

        part def SimulationEnvironment {
            attribute geometry : ArenaGeometry;
            attribute trialDuration : Duration;
            attribute timeStep : Duration;
            attribute currentRobot : MobileRobot;
            attribute currentController : NeuralNetworkController;
            attribute metrics : TrialMetrics;

            in port individualIn : IndividualInPort;
            out port metricsOut : MetricsOutPort;

            action def RunTrial {
                in individual : Individual;
                in arena : ArenaGeometry;
                in duration : Duration;
                out metrics : TrialMetrics;
            }

            state defdef TrialState {
                entry; then Running;
                state Running;
                transition Running_to_Finished first Running if currentRobot.positionX == geometry.target.positionX then Finished;
                state Finished;
            }
        }
    }

    package Evaluation {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def FitnessEvaluationModule {
            attribute targetWeight : Real;
            attribute collisionPenalty : Real;
            attribute energyWeight : Real;
            attribute speedWeight : Real;

            in port metricsIn : MetricsOutPort;
            out port fitnessOut : FitnessOutPort;

            action def EvaluateFitness {
                in metrics : TrialMetrics;
                in arena : ArenaGeometry;
                out fitness : FitnessScore;
            }

            action def ComputeScore {
                in distanceTraveled : Distance;
                in closestApproach : Distance;
                in collisions : CollisionCount;
                in energyUsed : Energy;
                in timeElapsed : Duration;
                in reachedTarget : Boolean;
                out score : FitnessScore;
            }
        }
    }

    package Genetics {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def GeneticOperatorEngine {
            attribute mutationRate : MutationRate;
            attribute crossoverRate : CrossoverRate;
            attribute eliteFraction : EliteFraction;
            attribute populationSize : PopulationSize;
            attribute tournamentSize : Integer;

            in port populationIn : PopulationInPort;
            out port populationOut : PopulationOutPort;

            action def EvolveGeneration {
                in current : Population;
                out next : Population;
            }

            action def SelectParents {
                in population : Population;
                out parents : Individual[0..*];
            }

            action def Crossover {
                in parentA : Individual;
                in parentB : Individual;
                out offspring : Individual;
            }

            action def Mutate {
                in individual : Individual;
                in rate : MutationRate;
                out mutated : Individual;
            }

            action def PreserveElites {
                in population : Population;
                in fraction : EliteFraction;
                out elites : Individual[0..*];
            }
        }
    }

    package System {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        import RobotParts::*;
        import Environment::*;
        import Evaluation::*;
        import Genetics::*;

        part def EvolutionaryRoboticsSystem {
            attribute maxGenerations : GenerationNumber;
            attribute populationSize : PopulationSize;
            attribute trialDuration : Duration;
            attribute mutationRate : MutationRate;
            attribute crossoverRate : CrossoverRate;
            attribute eliteFraction : EliteFraction;
            attribute currentGeneration : GenerationNumber;
            attribute bestIndividual : Individual;

            part simulationEnvironment : SimulationEnvironment;
            part fitnessEvaluator : FitnessEvaluationModule;
            part geneticEngine : GeneticOperatorEngine;
            part robot : MobileRobot;

            connection individualToEnv connect geneticEngine.populationOut to simulationEnvironment.individualIn;
            connection envToEvaluator connect simulationEnvironment.metricsOut to fitnessEvaluator.metricsIn;
            connection evaluatorToGenetic connect fitnessEvaluator.fitnessOut to geneticEngine.populationIn;

            state defdef EvolutionState {
                entry; then Initializing;
                state Initializing;
                transition Init_to_Evaluating first Initializing then Evaluating;
                state Evaluating;
                transition Eval_to_Breeding first Evaluating if allTrialsComplete then Breeding;
                state Breeding;
                transition Breed_to_Evaluating first Breeding if currentGeneration < maxGenerations then Evaluating;
                transition Breed_to_Done first Breeding if currentGeneration >= maxGenerations then Done;
                state Done;
            }

            action def RunEvolution {
                out bestController : Genome;
            }

            action def InitializePopulation {
                out population : Population;
            }

            action def EvaluatePopulation {
                in population : Population;
                out evaluated : Population;
            }

            action def BreedNextGeneration {
                in evaluated : Population;
                out next : Population;
            }
        }
    }

    package Requirements {
        import ValueTypes::*;
        import Items::*;

        requirement def EvolutionaryRoboticsRequirement {
            attribute id : String;
            attribute text : String;
        }

        requirement def RobotSensorSuiteRequirement :> EvolutionaryRoboticsRequirement {
            doc « The robot shall be equipped with eight proximity sensors, four light sensors, and two ground sensors. »
            assert ::RobotParts::MobileRobot.proximitySensors.readings.size == 8;
            assert ::RobotParts::MobileRobot.lightSensors.readings.size == 4;
            assert ::RobotParts::MobileRobot.groundSensors.readings.size == 2;
        }

        requirement def RobotActuationRequirement :> EvolutionaryRoboticsRequirement {
            doc « The robot shall move using two independently controlled DC motors. »
            assert ::RobotParts::MobileRobot.leftMotor.isInstanceOf(DCMotor);
            assert ::RobotParts::MobileRobot.rightMotor.isInstanceOf(DCMotor);
        }

        requirement def NeuralControllerRequirement :> EvolutionaryRoboticsRequirement {
            doc « The robot brain shall be a neural network controller mapping sensor data to motor commands. »
            assert ::RobotParts::MobileRobot.controller.isInstanceOf(NeuralNetworkController);
        }

        requirement def SimulationTrialRequirement :> EvolutionaryRoboticsRequirement {
            doc « Each controller shall be tested in a virtual arena for a set duration, tracking distance, closest approach, collisions, and energy. »
            assert ::Environment::SimulationEnvironment.trialDuration > 0;
        }

        requirement def FitnessEvaluationRequirement :> EvolutionaryRoboticsRequirement {
            doc « The Fitness Evaluation Module shall assign a single fitness score rewarding target seeking, collision avoidance, and energy conservation. »
            assert ::Evaluation::FitnessEvaluationModule.targetWeight > 0;
            assert ::Evaluation::FitnessEvaluationModule.collisionPenalty > 0;
            assert ::Evaluation::FitnessEvaluationModule.energyWeight > 0;
        }

        requirement def GeneticOperatorRequirement :> EvolutionaryRoboticsRequirement {
            doc « The Genetic Operator Engine shall perform selection, crossover, mutation, and elitism to produce offspring. »
            assert ::Genetics::GeneticOperatorEngine.mutationRate >= 0;
            assert ::Genetics::GeneticOperatorEngine.crossoverRate >= 0;
            assert ::Genetics::GeneticOperatorEngine.eliteFraction >= 0;
        }

        requirement def ConvergenceRequirement :> EvolutionaryRoboticsRequirement {
            doc « The system shall iterate for hundreds of generations until the best controller is discovered. »
            assert ::System::EvolutionaryRoboticsSystem.maxGenerations >= 100;
        }

        requirement def DeploymentRequirement :> EvolutionaryRoboticsRequirement {
            doc « The final output shall be the most successful neural network controller, deployable on a real robot. »
            assert ::System::EvolutionaryRoboticsSystem.bestIndividual.isInstanceOf(Individual);
        }
    }
}
