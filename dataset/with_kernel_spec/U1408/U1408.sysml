package 'Biological Evolution Simulation' {
	private import ScalarValues::*;
	private import SI::*;
	private import SequenceFunctions::*;

	package 'Value Types' {
		attribute def FitnessScore :> Real {
			assert constraint { that >= 0.0 }
		}
		attribute def SurvivalProbability :> Real {
			assert constraint { that >= 0.0 and that <= 1.0 }
		}
		attribute def BodySize :> Real;
		attribute def MetabolicRate :> Real;
		attribute def ReproductiveRate :> Real;
		attribute def Temperature :> Real;
		attribute def ResourceDensity :> Real {
			assert constraint { that >= 0.0 }
		}
		attribute def PredatorCount :> Integer;
		attribute def CarryingCapacity :> Integer;
		attribute def GenerationCount :> Integer;

		item def Gene {
			attribute value : Real;
		}

		item def Genotype {
			attribute genes : Gene[1..*];
		}
	}

	package 'Part Definitions' {
		private import 'Value Types'::*;

		part def Individual {
			attribute id : Natural;
			attribute genotype : Genotype;
			attribute bodySize : BodySize;
			attribute metabolicRate : MetabolicRate;
			attribute reproductiveRate : ReproductiveRate;
			attribute survivalProbability : SurvivalProbability;
			attribute fitnessScore : FitnessScore;
			attribute generationNumber : Natural;

			exhibit state LifeCycle {
				entry; then Born;
				state Born;
				then Alive;
				state Alive;
				then Reproducing;
				state Reproducing;
				then Dead;
				state Dead;
			}
		}

		port def EnvironmentPort {
			attribute temperature : Temperature;
			attribute resourceDensity : ResourceDensity;
			attribute predatorCount : PredatorCount;
		}

		part def Habitat {
			attribute temperature : Temperature;
			attribute resourceDensity : ResourceDensity;
			attribute predatorCount : PredatorCount;
			attribute carryingCapacity : CarryingCapacity;
			port env : EnvironmentPort;
		}

		part def Population {
			part individuals : Individual[0..*];
			attribute generation : GenerationCount;
			attribute size : Natural;
			port habitatPort : EnvironmentPort;

			exhibit state lifecycle {
				entry; then founding;
				state founding;
				then growth;
				state growth;
				then adaptation;
				state adaptation;
				then stability;
				state stability;
				then declining;
				state declining;
				then extinct;
				state extinct;
			}
		}

		part def EvolutionSimulation {
			part habitat : Habitat;
			part population : Population;
			attribute maxGenerations : GenerationCount;
			attribute mutationRate : Real;
			attribute initialPopulationSize : Natural;

			connect population.habitatPort to habitat.env;
		}
	}

	package 'Calculations' {
		private import 'Value Types'::*;
		private import 'Part Definitions'::*;

		calc def FitnessCalculation {
			in bodySize : BodySize;
			in metabolicRate : MetabolicRate;
			in temp : Temperature;
			in resource : ResourceDensity;
			in predators : PredatorCount;
			return : FitnessScore = (bodySize * resource) - (metabolicRate * temp) - (predators * 0.1);
		}

		calc def SurvivalCalculation {
			in bodySize : BodySize;
			in metabolicRate : MetabolicRate;
			in resource : ResourceDensity;
			in predators : PredatorCount;
			return : SurvivalProbability = 1.0 / (1.0 + (predators * 0.1) / (resource + 0.1) + 0.01 * bodySize);
		}

		calc def RecombineGenome {
			in g1 : Genotype;
			in g2 : Genotype;
			return : Genotype = new Genotype(genes = g1.genes->concatenate(g2.genes));
		}

		calc def MutateGenome {
			in original : Genotype;
			in rate : Real;
			return : Genotype = new Genotype(genes = original.genes->collect(g | new Gene(value = g.value + rate)));
		}

		calc def MakeOffspring {
			in parent1 : Individual;
			in parent2 : Individual;
			in mutationRate : Real;
			in generation : GenerationCount;
			return : Individual = new Individual(
				id = parent1.id * 1000 + parent2.id + generation,
				genotype = MutateGenome(RecombineGenome(parent1.genotype, parent2.genotype), mutationRate),
				bodySize = (parent1.bodySize + parent2.bodySize) / 2.0,
				metabolicRate = (parent1.metabolicRate + parent2.metabolicRate) / 2.0,
				reproductiveRate = (parent1.reproductiveRate + parent2.reproductiveRate) / 2.0,
				generationNumber = generation
			);
		}
	}

	package 'Behaviors' {
		private import 'Part Definitions'::*;
		private import 'Calculations'::*;

		action def ChangeEnvironment {
			in habitat : Habitat;
			in generation : GenerationCount;
			out newTemp : Temperature = habitat.temperature + 0.1;
			out newResource : ResourceDensity = habitat.resourceDensity * 0.98;
			out newPredators : PredatorCount = habitat.predatorCount + 1;
		}

		analysis def EvolutionSimulationAnalysis {
			subject habitat : Habitat;
			subject population : Population;
			in attribute maxGenerations : GenerationCount;
			in attribute mutationRate : Real;
			return attribute finalGeneration : GenerationCount;
			out finalPopulationSize : Natural;

			private attribute evaluated : Individual[0..*] := ();
			private attribute survivors : Individual[0..*] := ();
			private attribute offspring : Individual[0..*] := ();

			for gen in 1..maxGenerations {
				assign evaluated := population.individuals->collect(ind |
					new Individual(
						id = ind.id,
						genotype = ind.genotype,
						bodySize = ind.bodySize,
						metabolicRate = ind.metabolicRate,
						reproductiveRate = ind.reproductiveRate,
						survivalProbability = SurvivalCalculation(ind.bodySize, ind.metabolicRate, habitat.resourceDensity, habitat.predatorCount),
						fitnessScore = FitnessCalculation(ind.bodySize, ind.metabolicRate, habitat.temperature, habitat.resourceDensity, habitat.predatorCount),
						generationNumber = ind.generationNumber
					)
				);
				then assign survivors := evaluated->select(f | f.fitnessScore > 0.0);
				then assign offspring := survivors->collect(s |
					MakeOffspring(s, s, mutationRate, population.generation + 1)
				);
				then assign population.individuals := offspring;
				then assign population.generation := population.generation + 1;
				then perform action envChange : ChangeEnvironment {
					in habitat = habitat;
					in generation = population.generation;
				}
				then assign habitat.temperature := envChange.newTemp;
				then assign habitat.resourceDensity := envChange.newResource;
				then assign habitat.predatorCount := envChange.newPredators;
			}
			assign finalGeneration := population.generation;
			then assign finalPopulationSize := population.individuals->size();
		}
	}

	package 'Requirements' {
		private import 'Part Definitions'::*;
		private import 'Value Types'::*;

		requirement def 'Simulate Evolution' {
			doc /* The system shall simulate the biological evolution of a population over multiple generations. */
			subject simulation : EvolutionSimulation;
			attribute minGenerations : GenerationCount = 100;
			constraint { simulation.maxGenerations >= minGenerations }
		}

		requirement def 'Calculate Fitness' {
			doc /* The system shall calculate a fitness score for each individual based on environmental conditions. */
			subject simulation : EvolutionSimulation;
		}

		requirement def 'Natural Selection' {
			doc /* The system shall eliminate less fit individuals based on their fitness score. */
			subject simulation : EvolutionSimulation;
		}

		requirement def 'Reproduction' {
			doc /* The system shall generate offspring from surviving individuals with genetic mutation and recombination. */
			subject simulation : EvolutionSimulation;
			attribute maxMutationRate : Real = 0.1;
			constraint { simulation.mutationRate <= maxMutationRate }
		}

		requirement def 'Environmental Change' {
			doc /* The environment shall change between generations to introduce new selection pressures. */
			subject simulation : EvolutionSimulation;
		}

		requirement def 'Carrying Capacity' {
			doc /* The population shall not exceed the carrying capacity of the habitat. */
			subject simulation : EvolutionSimulation;
			constraint { simulation.population.size <= simulation.habitat.carryingCapacity }
		}

		requirement def 'Adaptation' {
			doc /* Over many generations, the population shall become better adapted to its environment, reflected by increasing or stabilizing mean fitness. */
			subject simulation : EvolutionSimulation;
		}

		requirement def 'Extinction' {
			doc /* The simulation shall model potential extinction if the population fails to adapt to severe environmental changes. */
			subject simulation : EvolutionSimulation;
		}
	}

	package 'Instances' {
		private import 'Part Definitions'::*;
		private import 'Behaviors'::*;

		part sim : EvolutionSimulation {
			attribute :>> maxGenerations = 1000;
			attribute :>> mutationRate = 0.01;
			attribute :>> initialPopulationSize = 100;

			part :>> habitat {
				attribute :>> temperature = 20.0;
				attribute :>> resourceDensity = 1.0;
				attribute :>> predatorCount = 5;
				attribute :>> carryingCapacity = 200;
			}

			part :>> population {
				attribute :>> generation = 0;
				attribute :>> size = 100;
			}
		}
	}
}
