package 'Evolutionary Robotics System' {
	private import ISQ::*;
	private import ScalarValues::*;
	private import SequenceFunctions::*;

	attribute def FitnessScore :> Real;
	attribute def Weight :> Real;
	attribute def Bias :> Real;
	attribute def SensorValue :> Real;
	attribute def MotorCommand :> Real;

	attribute def Position2D {
		attribute x : Real;
		attribute y : Real;
	}

	attribute def TrialMetrics {
		attribute distanceTraveled : Real;
		attribute finalDistanceToTarget : Real;
		attribute collisionCount : Integer;
		attribute energyConsumed : Real;
		attribute elapsedTime : Real;
	}

	attribute def Genome {
		attribute weights : Weight[*];
		attribute biases : Bias[*];
		attribute layerSizes : Integer[*];
	}

	part def ProximitySensor {
		out reading : SensorValue;
	}

	part def LightSensor {
		out reading : SensorValue;
	}

	part def GroundSensor {
		out reading : SensorValue;
	}

	part def DCMotor {
		in command : MotorCommand;
	}

	part def NeuralNetworkController {
		attribute genome : Genome;
		in proxInputs : SensorValue[8];
		in lightInputs : SensorValue[4];
		in groundInputs : SensorValue[2];
		out leftCommand : MotorCommand;
		out rightCommand : MotorCommand;
	}

	part def MobileRobot {
		attribute mass : Real;
		attribute wheelRadius : Real;
		attribute wheelBase : Real;
		part proximitySensors : ProximitySensor[8];
		part lightSensors : LightSensor[4];
		part groundSensors : GroundSensor[2];
		part leftMotor : DCMotor;
		part rightMotor : DCMotor;
		part controller : NeuralNetworkController;

		connect proximitySensors.reading to controller.proxInputs;
		connect lightSensors.reading to controller.lightInputs;
		connect groundSensors.reading to controller.groundInputs;
		connect controller.leftCommand to leftMotor.command;
		connect controller.rightCommand to rightMotor.command;
	}

	part def Obstacle {
		attribute position : Position2D;
		attribute radius : Real;
	}

	part def Target {
		attribute position : Position2D;
		attribute radius : Real;
	}

	part def SimulationEnvironment {
		attribute arenaWidth : Real;
		attribute arenaHeight : Real;
		attribute robotStartPosition : Position2D;
		part obstacles : Obstacle[*];
		part target : Target[1];
		part robot : MobileRobot[1];
	}

	calc def Distance2D {
		in a : Position2D;
		in b : Position2D;
		return dist : Real;
	}

	calc def FitnessFunction {
		in metrics : TrialMetrics;
		return score : FitnessScore =
			1000.0 / (1.0 + metrics.finalDistanceToTarget) +
			500.0 / (1.0 + metrics.collisionCount) +
			300.0 / (1.0 + metrics.energyConsumed);
	}

	action def SimulationTrial {
		in controller : NeuralNetworkController;
		in environment : SimulationEnvironment;
		in duration : Real;
		out metrics : TrialMetrics;
	}

	action def FitnessEvaluation {
		in metrics : TrialMetrics;
		out score : FitnessScore;
	}

	action def Selection {
		in population : NeuralNetworkController[*];
		in scores : FitnessScore[*];
		in eliteCount : Integer;
		out parents : NeuralNetworkController[*];
		out elites : NeuralNetworkController[*];
	}

	action def Crossover {
		in parent1 : NeuralNetworkController;
		in parent2 : NeuralNetworkController;
		out offspring : NeuralNetworkController;
	}

	action def Mutation {
		in individual : NeuralNetworkController;
		in mutationRate : Real;
		out mutated : NeuralNetworkController;
	}

	action def BreedGeneration {
		in parents : NeuralNetworkController[*];
		in populationSize : Integer;
		in mutationRate : Real;
		in elites : NeuralNetworkController[*];
		out offspring : NeuralNetworkController[*];
	}

	action def SelectBestController {
		in population : NeuralNetworkController[*];
		in scores : FitnessScore[*];
		out best : NeuralNetworkController;
		out bestScore : FitnessScore;
	}

	action def EvaluatePopulation {
		in population : NeuralNetworkController[*];
		in environment : SimulationEnvironment;
		in duration : Real;
		out scores : FitnessScore[*];

		attribute scoreList : FitnessScore[*] := ();
		for i in 1..population->size() {
			perform action trial : SimulationTrial {
				in controller = population#(i);
				in environment = environment;
				in duration = duration;
			}
			then perform action evaluation : FitnessEvaluation {
				in metrics = trial.metrics;
			}
			then assign scoreList := scoreList->including(evaluation.score);
		}
		assign scores := scoreList;
	}

	action def EvolveGeneration {
		in population : NeuralNetworkController[*];
		in environment : SimulationEnvironment;
		in duration : Real;
		in mutationRate : Real;
		in eliteCount : Integer;
		out nextPopulation : NeuralNetworkController[*];

		attribute scores : FitnessScore[*] := ();

		perform action evaluate : EvaluatePopulation {
			in population = population;
			in environment = environment;
			in duration = duration;
		}
		then assign scores := evaluate.scores;

		perform action select : Selection {
			in population = population;
			in scores = scores;
			in eliteCount = eliteCount;
		}

		perform action breed : BreedGeneration {
			in parents = select.parents;
			in populationSize = population->size();
			in mutationRate = mutationRate;
			in elites = select.elites;
		}
		then assign nextPopulation := breed.offspring;
	}

	state machine def EvolutionaryCycle {
		in maxGenerations : Integer;
		in generationCount : Integer;

		state Initialization;
		state Simulation;
		state Evaluation;
		state Selection;
		state Reproduction;
		state Termination;

		transition initial to Initialization;
		transition from Initialization to Simulation;
		transition from Simulation to Evaluation;
		transition from Evaluation to Selection;
		transition from Selection to Reproduction;
		transition from Reproduction to Simulation when generationCount < maxGenerations;
		transition from Reproduction to Termination when generationCount >= maxGenerations;
	}

	analysis def EvolutionaryOptimization {
		subject robot : MobileRobot;
		subject environment : SimulationEnvironment;

		in initialPopulation : NeuralNetworkController[*];
		in maxGenerations : Integer;
		in trialDuration : Real;
		in mutationRate : Real;
		in eliteCount : Integer;

		attribute bestFitnessScore : FitnessScore;

		objective evolveObjective {
			require constraint {
				bestFitnessScore > 0.85
			}
		}

		private attribute population : NeuralNetworkController[*] := initialPopulation;

		for gen in 1..maxGenerations {
			perform action evolution : EvolveGeneration {
				in population = population;
				in environment = environment;
				in duration = trialDuration;
				in mutationRate = mutationRate;
				in eliteCount = eliteCount;
			}
			then assign population := evolution.nextPopulation;
		}

		attribute finalScores : FitnessScore[*] := ();
		for i in 1..population->size() {
			perform action trial : SimulationTrial {
				in controller = population#(i);
				in environment = environment;
				in duration = trialDuration;
			}
			then perform action evaluation : FitnessEvaluation {
				in metrics = trial.metrics;
			}
			then assign finalScores := finalScores->including(evaluation.score);
		}

		perform action selectBest : SelectBestController {
			in population = population;
			in scores = finalScores;
		}

		assign bestFitnessScore := selectBest.bestScore;

		return bestController : NeuralNetworkController = selectBest.best;
	}

	requirement def ConvergenceRequirement {
		subject analysis : EvolutionaryOptimization;
		require constraint { analysis.bestFitnessScore > 0.85 }
	}

	requirement def SensorConfigurationRequirement {
		subject robot : MobileRobot;
		require constraint {
			robot.proximitySensors->size() == 8 &
			robot.lightSensors->size() == 4 &
			robot.groundSensors->size() == 2
		}
	}

	requirement def TrialDurationRequirement {
		subject trial : SimulationTrial;
		require constraint { trial.duration <= 60.0 }
	}

	requirement def PopulationSizeRequirement {
		subject analysis : EvolutionaryOptimization;
		require constraint { analysis.initialPopulation->size() >= 100 }
	}

	requirement def GenerationCountRequirement {
		subject analysis : EvolutionaryOptimization;
		require constraint { analysis.maxGenerations >= 100 }
	}

	requirement def ElitePreservationRequirement {
		subject analysis : EvolutionaryOptimization;
		require constraint { analysis.eliteCount >= 2 }
	}

	requirement def MotorControlRequirement {
		subject robot : MobileRobot;
		require constraint {
			robot.leftMotor.command <> robot.rightMotor.command
		}
	}
}
