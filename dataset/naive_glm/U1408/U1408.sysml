package EvolutionSimulation {
    import ScalarValues::*;
    
    // ===========================================
    // Value Types with Units
    // ===========================================
    
    value type BodyMassKg :> Real {
        doc "Body mass in kilograms";
        unit kg;
    }
    
    value type MetabolicRateValue :> Real {
        doc "Metabolic rate in kilojoules per day";
        unit kJ_per_day;
    }
    
    value type ReproductiveRateValue :> Real {
        doc "Reproductive rate per generation";
        unit per_generation;
    }
    
    value type SurvivalProbabilityValue :> Real {
        doc "Probability of survival, range 0.0 to 1.0";
        unit ratio;
    }
    
    value type FitnessScoreValue :> Real {
        doc "Fitness score, range 0.0 to 1.0";
        unit ratio;
    }
    
    value type TemperatureValue :> Real {
        doc "Temperature in Kelvin";
        unit K;
    }
    
    value type ResourceDensityValue :> Real {
        doc "Resource density in kilograms per square meter";
        unit kg_per_sq_m;
    }
    
    value type MutationRateValue :> Real {
        doc "Mutation rate per generation";
        unit per_generation;
    }
    
    value type RecombinationRateValue :> Real {
        doc "Recombination rate, range 0.0 to 1.0";
        unit ratio;
    }
    
    value type SeedValue :> Integer {
        doc "Random number generator seed";
    }
    
    // ===========================================
    // Item Definitions
    // ===========================================
    
    item def Allele {
        doc "A variant of a gene";
        attribute geneId: String;
        attribute alleleValue: Real;
        attribute dominant: Boolean default false;
    }
    
    item def Gene {
        doc "A unit of heredity";
        attribute geneId: String;
        item dominantAllele: Allele;
        item recessiveAllele: Allele;
    }
    
    item def Chromosome {
        doc "A collection of genes";
        item genes: Gene[0..*];
    }
    
    item def Genotype {
        doc "The genetic makeup of an individual";
        item chromosomes: Chromosome[0..*];
        attribute genomeId: String;
    }
    
    // ===========================================
    // Value Type Definitions (Data Structures)
    // ===========================================
    
    value type Phenotype {
        doc "Observable physical and behavioral traits";
        attribute bodyMass: BodyMassKg default 1.0;
        attribute metabolicRate: MetabolicRateValue default 100.0;
        attribute reproductiveRate: ReproductiveRateValue default 2.0;
        attribute survivalProbability: SurvivalProbabilityValue default 0.5;
    }
    
    value type EnvironmentalFactors {
        doc "Current state of the environment";
        attribute temperature: TemperatureValue default 293.15;
        attribute resourceDensity: ResourceDensityValue default 5.0;
        attribute predatorCount: Integer default 3;
        attribute carryingCapacity: Integer default 100;
    }
    
    value type IndividualRecord {
        doc "Serializable data for a single individual";
        attribute individualId: String;
        attribute bodyMass: BodyMassKg;
        attribute metabolicRate: MetabolicRateValue;
        attribute reproductiveRate: ReproductiveRateValue;
        attribute survivalProbability: SurvivalProbabilityValue;
        attribute fitness: FitnessScoreValue;
        attribute age: Integer;
        attribute isAlive: Boolean;
    }
    
    value type PopulationSnapshot {
        doc "Snapshot of population state at a point in time";
        attribute generationNumber: Integer;
        attribute populationSize: Integer;
        attribute averageFitness: FitnessScoreValue;
        attribute averageBodyMass: BodyMassKg;
        attribute averageMetabolicRate: MetabolicRateValue;
        attribute averageReproductiveRate: ReproductiveRateValue;
        attribute averageSurvivalProbability: SurvivalProbabilityValue;
    }
    
    value type SimulationConfig {
        doc "Configuration parameters for the simulation";
        attribute initialPopulationSize: Integer default 50;
        attribute maxGenerations: Integer default 500;
        attribute mutationRate: MutationRateValue default 0.02;
        attribute recombinationRate: RecombinationRateValue default 0.5;
        attribute mutationMagnitude: Real default 0.1;
        attribute selectionPressure: Real default 0.3;
        attribute survivalThreshold: FitnessScoreValue default 0.3;
        attribute temperatureChangeRate: TemperatureValue default 2.0;
        attribute resourceChangeRate: ResourceDensityValue default 0.5;
        attribute predatorChangeProbability: Real default 0.3;
        attribute randomSeed: SeedValue default 42;
        attribute initialCarryingCapacity: Integer default 100;
        attribute initialTemperature: TemperatureValue default 293.15;
        attribute initialResourceDensity: ResourceDensityValue default 5.0;
        attribute initialPredatorCount: Integer default 3;
        attribute numChromosomes: Integer default 5;
        attribute numGenesPerChromosome: Integer default 4;
    }
    
    value type SimulationResult {
        doc "Result of a completed simulation run";
        attribute totalGenerations: Integer;
        attribute finalPopulationSize: Integer;
        attribute isExtinct: Boolean;
        attribute finalAverageFitness: FitnessScoreValue;
        attribute finalAverageBodyMass: BodyMassKg;
        attribute generationsSurvived: Integer;
    }
    
    // ===========================================
    // Port Definitions
    // ===========================================
    
    port def EnvironmentalDataPort {
        doc "Port for transmitting environmental data";
        out environment: EnvironmentalFactors;
    }
    
    port def FitnessDataPort {
        doc "Port for transmitting fitness scores";
        out fitnessScores: FitnessScoreValue[0..*];
    }
    
    port def PopulationDataPort {
        doc "Port for transmitting population data";
        out snapshot: PopulationSnapshot;
        out records: IndividualRecord[0..*];
    }
    
    port def GenerationEventPort {
        doc "Port for generation cycle events";
        out generationNumber: Integer;
        out isComplete: Boolean;
        out populationSize: Integer;
        out isExtinct: Boolean;
    }
    
    port def SimulationControlPort {
        doc "Port for simulation control commands";
        in startSimulation: Boolean;
        in stopSimulation: Boolean;
        in config: SimulationConfig;
    }
    
    // ===========================================
    // Connection Definitions
    // ===========================================
    
    connection def EnvironmentalFlow {
        doc "Connection carrying environmental data";
        end source: EnvironmentalDataPort;
        end target: EnvironmentalDataPort;
    }
    
    connection def FitnessFlow {
        doc "Connection carrying fitness scores";
        end source: FitnessDataPort;
        end target: FitnessDataPort;
    }
    
    connection def PopulationFlow {
        doc "Connection carrying population data";
        end source: PopulationDataPort;
        end target: PopulationDataPort;
    }
    
    // ===========================================
    // Utility Action Definitions
    // ===========================================
    
    action def rand {
        doc "Generate a pseudo-random value in [0, 1)";
        in out state: Integer;
        out value: Real;
        perform {
            state = (state * 1103515245 + 12345) % 2147483647;
            if state < 0 {
                state = -state;
            }
            value = state / 2147483647.0;
        }
    }
    
    action def randInt {
        doc "Generate a pseudo-random integer in [min, max]";
        in minVal: Integer;
        in maxVal: Integer;
        in out state: Integer;
        out value: Integer;
        perform {
            var r: Real;
            call rand(state, r);
            value = minVal + (r * (maxVal - minVal + 1)) as Integer;
        }
    }
    
    action def clamp {
        doc "Clamp a value to a range";
        in val: Real;
        in minVal: Real;
        in maxVal: Real;
        out result: Real;
        perform {
            result = val;
            if result < minVal {
                result = minVal;
            }
            if result > maxVal {
                result = maxVal;
            }
        }
    }
    
    // ===========================================
    // Part: Individual
    // ===========================================
    
    part def Individual {
        doc "A single organism in the population";
        
        attribute individualId: String;
        attribute age: Integer default 0;
        item genotype: Genotype;
        attribute phenotype: Phenotype;
        attribute fitness: FitnessScoreValue default 0.0;
        attribute isAlive: Boolean default true;
        attribute generationBorn: Integer default 0;
        
        port envInput: EnvironmentalDataPort;
        port fitnessOutput: FitnessDataPort;
        
        state machine lifecycle {
            doc "Life cycle of an individual organism";
            
            entry {
                age = 0;
                isAlive = true;
            }
            
            state Born {
                doc "Newly created individual";
            }
            state Growing {
                doc "Juvenile stage, not yet reproductive";
            }
            state Mature {
                doc "Adult, capable of reproduction";
            }
            state Reproducing {
                doc "Actively producing offspring";
            }
            state Senescent {
                doc "Post-reproductive decline";
            }
            state Dead {
                doc "No longer alive";
                entry {
                    isAlive = false;
                }
            }
            
            transition bornToGrowing {
                from Born;
                to Growing;
            }
            
            transition growingToMature {
                from Growing;
                to Mature;
                when age >= 5;
            }
            
            transition matureToReproducing {
                from Mature;
                to Reproducing;
            }
            
            transition reproducingToSenescent {
                from Reproducing;
                to Senescent;
                when age >= 15;
            }
            
            transition senescentToDead {
                from Senescent;
                to Dead;
                when age >= 20;
            }
            
            transition earlyDeathByEnvironment {
                from Growing;
                to Dead;
                when phenotype.survivalProbability < 0.1;
            }
            
            transition matureDeathByEnvironment {
                from Mature;
                to Dead;
                when phenotype.survivalProbability < 0.05;
            }
            
            transition reproducingDeathByEnvironment {
                from Reproducing;
                to Dead;
                when phenotype.survivalProbability < 0.05;
            }
        }
        
        action def incrementAge {
            perform {
                age = age + 1;
            }
        }
        
        action def toRecord {
            out record: IndividualRecord;
            perform {
                record.individualId = individualId;
                record.bodyMass = phenotype.bodyMass;
                record.metabolicRate = phenotype.metabolicRate;
                record.reproductiveRate = phenotype.reproductiveRate;
                record.survivalProbability = phenotype.survivalProbability;
                record.fitness = fitness;
                record.age = age;
                record.isAlive = isAlive;
            }
        }
    }
    
    // ===========================================
    // Part: Population
    // ===========================================
    
    part def Population {
        doc "A population of individuals existing in a habitat";
        
        attribute populationId: String;
        attribute populationSize: Integer default 0;
        attribute generationCount: Integer default 0;
        attribute averageFitness: FitnessScoreValue default 0.0;
        attribute averageBodyMass: BodyMassKg default 1.0;
        attribute averageMetabolicRate: MetabolicRateValue default 100.0;
        attribute averageReproductiveRate: ReproductiveRateValue default 2.0;
        attribute averageSurvivalProbability: SurvivalProbabilityValue default 0.5;
        
        part individuals: Individual[0..*];
        
        port popOutput: PopulationDataPort;
        port envInput: EnvironmentalDataPort;
        
        state machine populationDynamics {
            doc "Population dynamics state machine";
            
            state Founded {
                doc "Initial population established";
            }
            state Growing {
                doc "Population increasing toward capacity";
            }
            state Stable {
                doc "Population near carrying capacity";
            }
            state Declining {
                doc "Population decreasing";
            }
            state Extinct {
                doc "No living individuals remain";
                entry {
                    populationSize = 0;
                }
            }
            
            transition foundedToGrowing {
                from Founded;
                to Growing;
                when populationSize > 0;
            }
            
            transition growingToStable {
                from Growing;
                to Stable;
                when populationSize >= 50;
            }
            
            transition stableToDeclining {
                from Stable;
                to Declining;
                when populationSize < 50;
            }
            
            transition growingToDeclining {
                from Growing;
                to Declining;
                when populationSize < 20 && generationCount > 5;
            }
            
            transition decliningToExtinct {
                from Declining;
                to Extinct;
                when populationSize == 0;
            }
            
            transition decliningToStable {
                from Declining;
                to Stable;
                when populationSize >= 50;
            }
            
            transition decliningToGrowing {
                from Declining;
                to Growing;
                when populationSize >= 20 && populationSize < 50;
            }
        }
        
        action def computeAverages {
            doc "Compute average trait values across living individuals";
            perform {
                var count: Integer = 0;
                var totalFitness: FitnessScoreValue = 0.0;
                var totalBodyMass: BodyMassKg = 0.0;
                var totalMetabolicRate: MetabolicRateValue = 0.0;
                var totalReproductiveRate: ReproductiveRateValue = 0.0;
                var totalSurvivalProb: SurvivalProbabilityValue = 0.0;
                
                for indiv in individuals {
                    if indiv.isAlive {
                        count = count + 1;
                        totalFitness = totalFitness + indiv.fitness;
                        totalBodyMass = totalBodyMass + indiv.phenotype.bodyMass;
                        totalMetabolicRate = totalMetabolicRate + indiv.phenotype.metabolicRate;
                        totalReproductiveRate = totalReproductiveRate + indiv.phenotype.reproductiveRate;
                        totalSurvivalProb = totalSurvivalProb + indiv.phenotype.survivalProbability;
                    }
                }
                
                populationSize = count;
                if count > 0 {
                    averageFitness = totalFitness / count;
                    averageBodyMass = totalBodyMass / count;
                    averageMetabolicRate = totalMetabolicRate / count;
                    averageReproductiveRate = totalReproductiveRate / count;
                    averageSurvivalProbability = totalSurvivalProb / count;
                }
                else {
                    averageFitness = 0.0;
                    averageBodyMass = 0.0;
                    averageMetabolicRate = 0.0;
                    averageReproductiveRate = 0.0;
                    averageSurvivalProbability = 0.0;
                }
            }
        }
        
        action def takeSnapshot {
            out snapshot: PopulationSnapshot;
            perform {
                call computeAverages();
                snapshot.generationNumber = generationCount;
                snapshot.populationSize = populationSize;
                snapshot.averageFitness = averageFitness;
                snapshot.averageBodyMass = averageBodyMass;
                snapshot.averageMetabolicRate = averageMetabolicRate;
                snapshot.averageReproductiveRate = averageReproductiveRate;
                snapshot.averageSurvivalProbability = averageSurvivalProbability;
            }
        }
        
        action def addIndividual {
            in indiv: Individual;
            perform {
                individuals = individuals + {indiv};
                populationSize = populationSize + 1;
            }
        }
        
        action def removeDeadIndividuals {
            perform {
                var living: Individual[0..*] = {};
                for indiv in individuals {
                    if indiv.isAlive {
                        living = living + {indiv};
                    }
                }
                individuals = living;
                populationSize = individuals.size;
            }
        }
    }
    
    // ===========================================
    // Part: Habitat
    // ===========================================
    
    part def Habitat {
        doc "The environment in which the population exists";
        
        attribute habitatId: String;
        attribute factors: EnvironmentalFactors;
        attribute temperatureVariability: TemperatureValue default 5.0;
        attribute resourceFluctuation: ResourceDensityValue default 1.0;
        attribute predatorFluctuationProbability: Real default 0.3;
        attribute rngState: SeedValue default 42;
        
        port envOutput: EnvironmentalDataPort;
        
        state machine environmentalDynamics {
            doc "Environmental state transitions";
            
            state Stable {
                doc "Environment within normal parameters";
            }
            state Warming {
                doc "Above-optimal temperature regime";
            }
            state Cooling {
                doc "Below-optimal temperature regime";
            }
            state ResourceDepletion {
                doc "Low resource availability";
            }
            state ResourceAbundance {
                doc "High resource availability";
            }
            state PredatorPressure {
                doc "Elevated predator population";
            }
            state Harsh {
                doc "Multiple adverse conditions";
            }
            
            transition stableToWarming {
                from Stable;
                to Warming;
                when factors.temperature > 298.15;
            }
            
            transition warmingToStable {
                from Warming;
                to Stable;
                when factors.temperature <= 298.15 && factors.temperature >= 288.15;
            }
            
            transition stableToCooling {
                from Stable;
                to Cooling;
                when factors.temperature < 288.15;
            }
            
            transition coolingToStable {
                from Cooling;
                to Stable;
                when factors.temperature >= 288.15 && factors.temperature <= 298.15;
            }
            
            transition stableToDepletion {
                from Stable;
                to ResourceDepletion;
                when factors.resourceDensity < 2.0;
            }
            
            transition depletionToStable {
                from ResourceDepletion;
                to Stable;
                when factors.resourceDensity >= 2.0;
            }
            
            transition stableToAbundance {
                from Stable;
                to ResourceAbundance;
                when factors.resourceDensity > 10.0;
            }
            
            transition abundanceToStable {
                from ResourceAbundance;
                to Stable;
                when factors.resourceDensity <= 10.0;
            }
            
            transition stableToPredator {
                from Stable;
                to PredatorPressure;
                when factors.predatorCount > 10;
            }
            
            transition predatorToStable {
                from PredatorPressure;
                to Stable;
                when factors.predatorCount <= 10;
            }
            
            transition warmingToHarsh {
                from Warming;
                to Harsh;
                when factors.resourceDensity < 2.0;
            }
            
            transition coolingToHarsh {
                from Cooling;
                to Harsh;
                when factors.predatorCount > 10;
            }
            
            transition harshToStable {
                from Harsh;
                to Stable;
                when factors.temperature >= 288.15 && factors.temperature <= 298.15 && factors.resourceDensity >= 2.0 && factors.predatorCount <= 10;
            }
        }
        
        action def applyEnvironmentalChange {
            in temperatureDelta: TemperatureValue;
            in resourceDelta: ResourceDensityValue;
            in predatorDelta: Integer;
            perform {
                var r: Real;
                call clamp(factors.temperature + temperatureDelta, 250.0, 320.0, r);
                factors.temperature = r;
                
                call clamp(factors.resourceDensity + resourceDelta, 0.0, 20.0, r);
                factors.resourceDensity = r;
                
                factors.predatorCount = factors.predatorCount + predatorDelta;
                if factors.predatorCount < 0 {
                    factors.predatorCount = 0;
                }
            }
        }
    }
    
    // ===========================================
    // Part: FitnessEvaluator
    // ===========================================
    
    part def FitnessEvaluator {
        doc "Evaluates individual fitness against environmental conditions";
        
        attribute optimalTemperature: TemperatureValue default 293.15;
        attribute temperatureTolerance: TemperatureValue default 10.0;
        attribute resourceEfficiencyCoefficient: Real default 20.0;
        attribute predatorRiskCoefficient: Real default 0.05;
        
        port envInput: EnvironmentalDataPort;
        port popInput: PopulationDataPort;
        port fitnessOutput: FitnessDataPort;
        
        action def evaluateIndividual {
            doc "Calculate a fitness score for a single individual";
            in env: EnvironmentalFactors;
            in individual: Individual;
            out fitness: FitnessScoreValue;
            
            perform {
                var baseScore: FitnessScoreValue = individual.phenotype.survivalProbability;
                
                // Temperature suitability
                var tempScore: FitnessScoreValue = 1.0;
                if env.temperature > optimalTemperature + temperatureTolerance {
                    tempScore = 0.5;
                }
                if env.temperature < optimalTemperature - temperatureTolerance {
                    tempScore = 0.5;
                }
                
                // Resource availability relative to body mass
                var resourceScore: FitnessScoreValue = 1.0;
                var requiredResource: Real = individual.phenotype.bodyMass * 2.0;
                if env.resourceDensity < requiredResource {
                    resourceScore = 0.6;
                }
                
                // Predator pressure — larger bodies are slightly more vulnerable
                var predatorScore: FitnessScoreValue = 1.0;
                if env.predatorCount > 5 {
                    var bodyMassRisk: Real = individual.phenotype.bodyMass * predatorRiskCoefficient;
                    if bodyMassRisk < 1.0 {
                        predatorScore = 1.0 - bodyMassRisk;
                    }
                    else {
                        predatorScore = 0.0;
                    }
                }
                
                // Metabolic efficiency relative to resources
                var metabolicScore: FitnessScoreValue = 1.0;
                if individual.phenotype.metabolicRate > env.resourceDensity * resourceEfficiencyCoefficient {
                    metabolicScore = 0.7;
                }
                
                // Reproductive rate penalty — high reproduction costs energy
                var reproductionScore: FitnessScoreValue = 1.0;
                if individual.phenotype.reproductiveRate > 4.0 {
                    reproductionScore = 0.8;
                }
                
                // Combined fitness
                fitness = baseScore * tempScore * resourceScore * predatorScore * metabolicScore * reproductionScore;
                
                var clamped: Real;
                call clamp(fitness, 0.0, 1.0, clamped);
                fitness = clamped;
            }
        }
        
        action def evaluatePopulation {
            doc "Evaluate fitness for all individuals in a population";
            in env: EnvironmentalFactors;
            in population: Population;
            out fitnessScores: FitnessScoreValue[0..*];
            
            perform {
                fitnessScores = {};
                for indiv in population.individuals {
                    if indiv.isAlive {
                        var score: FitnessScoreValue;
                        call evaluateIndividual(env, indiv, score);
                        indiv.fitness = score;
                        fitnessScores = fitnessScores + {score};
                    }
                }
            }
        }
    }
    
    // ===========================================
    // Part: SelectionMechanism
    // ===========================================
    
    part def SelectionMechanism {
        doc "Performs natural selection on the population";
        
        attribute survivalThreshold: FitnessScoreValue default 0.3;
        attribute selectionPressure: Real default 0.3;
        
        port fitnessInput: FitnessDataPort;
        port popInput: PopulationDataPort;
        port popOutput: PopulationDataPort;
        
        action def selectSurvivors {
            doc "Select individuals that survive to reproduce";
            in population: Population;
            in carryingCapacity: Integer;
            in out rngState: SeedValue;
            out survivors: Individual[0..*];
            out populationData: PopulationSnapshot;
            
            perform {
                var candidates: Individual[0..*] = {};
                var livingCount: Integer = 0;
                
                for indiv in population.individuals {
                    if indiv.isAlive && indiv.fitness >= survivalThreshold {
                        candidates = candidates + {indiv};
                        livingCount = livingCount + 1;
                    }
                }
                
                // Sort candidates by fitness descending (selection sort)
                var sorted: Individual[0..*] = {};
                var remaining: Individual[0..*] = candidates;
                
                while remaining.size > 0 {
                    var bestIdx: Integer = 0;
                    var bestFit: FitnessScoreValue = remaining[0].fitness;
                    var i: Integer = 1;
                    while i < remaining.size {
                        if remaining[i].fitness > bestFit {
                            bestFit = remaining[i].fitness;
                            bestIdx = i;
                        }
                        i = i + 1;
                    }
                    sorted = sorted + {remaining[bestIdx]};
                    // Remove the selected element
                    var newRemaining: Individual[0..*] = {};
                    var j: Integer = 0;
                    while j < remaining.size {
                        if j != bestIdx {
                            newRemaining = newRemaining + {remaining[j]};
                        }
                        j = j + 1;
                    }
                    remaining = newRemaining;
                }
                
                // Select up to carrying capacity, with some stochastic selection
                var numSurvivors: Integer = carryingCapacity;
                if sorted.size < numSurvivors {
                    numSurvivors = sorted.size;
                }
                
                survivors = {};
                var k: Integer = 0;
                while k < numSurvivors {
                    survivors = survivors + {sorted[k]};
                    k = k + 1;
                }
                
                // Compute population snapshot for survivors
                populationData.generationNumber = population.generationCount;
                populationData.populationSize = survivors.size;
                var totalFit: FitnessScoreValue = 0.0;
                var totalMass: BodyMassKg = 0.0;
                for s in survivors {
                    totalFit = totalFit + s.fitness;
                    totalMass = totalMass + s.phenotype.bodyMass;
                }
                if survivors.size > 0 {
                    populationData.averageFitness = totalFit / survivors.size;
                    populationData.averageBodyMass = totalMass / survivors.size;
                }
                else {
                    populationData.averageFitness = 0.0;
                    populationData.averageBodyMass = 0.0;
                }
            }
        }
    }
    
    // ===========================================
    // Part: MutationMechanism
    // ===========================================
    
    part def MutationMechanism {
        doc "Introduces random mutations into genotypes";
        
        attribute mutationRate: MutationRateValue default 0.02;
        attribute mutationMagnitude: Real default 0.1;
        
        action def mutate {
            doc "Apply random mutations to a genotype";
            in genotype: Genotype;
            in out rngState: SeedValue;
            out mutated: Genotype;
            
            perform {
                mutated = genotype;
                
                for chrom in mutated.chromosomes {
                    for gene in chrom.genes {
                        var randVal: Real;
                        call rand(rngState, randVal);
                        if randVal < mutationRate {
                            call rand(rngState, randVal);
                            var delta: Real = (randVal - 0.5) * mutationMagnitude;
                            var newVal: Real = gene.dominantAllele.alleleValue + delta;
                            var clamped: Real;
                            call clamp(newVal, 0.0, 1.0, clamped);
                            gene.dominantAllele.alleleValue = clamped;
                        }
                        
                        call rand(rngState, randVal);
                        if randVal < mutationRate {
                            call rand(rngState, randVal);
                            var delta2: Real = (randVal - 0.5) * mutationMagnitude;
                            var newVal2: Real = gene.recessiveAllele.alleleValue + delta2;
                            var clamped2: Real;
                            call clamp(newVal2, 0.0, 1.0, clamped2);
                            gene.recessiveAllele.alleleValue = clamped2;
                        }
                    }
                }
            }
        }
    }
    
    // ===========================================
    // Part: RecombinationMechanism
    // ===========================================
    
    part def RecombinationMechanism {
        doc "Shuffles genes during sexual reproduction";
        
        attribute recombinationRate: RecombinationRateValue default 0.5;
        
        action def recombine {
            doc "Recombine two parent genotypes into an offspring genotype";
            in parent1: Genotype;
            in parent2: Genotype;
            in out rngState: SeedValue;
            out offspringGenotype: Genotype;
            
            perform {
                offspringGenotype = Genotype();
                offspringGenotype.genomeId = "offspring_genome";
                
                var minChroms: Integer = parent1.chromosomes.size;
                if parent2.chromosomes.size < minChroms {
                    minChroms = parent2.chromosomes.size;
                }
                
                var i: Integer = 0;
                while i < minChroms {
                    var newChrom: Chromosome = Chromosome();
                    var p1Chrom: Chromosome = parent1.chromosomes[i];
                    var p2Chrom: Chromosome = parent2.chromosomes[i];
                    
                    var minGenes: Integer = p1Chrom.genes.size;
                    if p2Chrom.genes.size < minGenes {
                        minGenes = p2Chrom.genes.size;
                    }
                    
                    var j: Integer = 0;
                    while j < minGenes {
                        var randVal: Real;
                        call rand(rngState, randVal);
                        if randVal < recombinationRate {
                            newChrom.genes = newChrom.genes + {p1Chrom.genes[j]};
                        }
                        else {
                            newChrom.genes = newChrom.genes + {p2Chrom.genes[j]};
                        }
                        j = j + 1;
                    }
                    
                    offspringGenotype.chromosomes = offspringGenotype.chromosomes + {newChrom};
                    i = i + 1;
                }
            }
        }
    }
    
    // ===========================================
    // Part: ReproductionMechanism
    // ===========================================
    
    part def ReproductionMechanism {
        doc "Manages reproduction of the population";
        
        port popInput: PopulationDataPort;
        port envInput: EnvironmentalDataPort;
        port popOutput: PopulationDataPort;
        
        part mutator: MutationMechanism;
        part recombiner: RecombinationMechanism;
        
        action def produceOffspring {
            doc "Generate offspring from surviving individuals";
            in survivors: Individual[0..*];
            in env: EnvironmentalFactors;
            in nextGenNumber: Integer;
            in out rngState: SeedValue;
            out offspring: Individual[0..*];
            
            perform {
                offspring = {};
                
                if survivors.size < 2 {
                    // Not enough parents for sexual reproduction
                    return;
                }
                
                var pairCount: Integer = survivors.size / 2;
                var i: Integer = 0;
                
                while i < pairCount {
                    var parent1: Individual = survivors[i * 2];
                    var parent2: Individual = survivors[i * 2 + 1];
                    
                    // Determine number of offspring from average reproductive rate
                    var avgReproRate: ReproductiveRateValue = 
                        (parent1.phenotype.reproductiveRate + parent2.phenotype.reproductiveRate) / 2.0;
                    var numOffspring: Integer = avgReproRate as Integer;
                    if numOffspring < 1 {
                        numOffspring = 1;
                    }
                    
                    var k: Integer = 0;
                    while k < numOffspring {
                        // Recombine parent genotypes
                        var childGenotype: Genotype;
                        call recombiner.recombine(
                            parent1.genotype,
                            parent2.genotype,
                            rngState,
                            childGenotype);
                        
                        // Apply mutation
                        var mutatedGenotype: Genotype;
                        call mutator.mutate(childGenotype, rngState, mutatedGenotype);
                        
                        // Create new individual
                        var child: Individual = Individual();
                        child.individualId = "gen_" + nextGenNumber as String + "_ind_" + k as String;
                        child.genotype = mutatedGenotype;
                        child.phenotype = derivePhenotype(mutatedGenotype);
                        child.age = 0;
                        child.isAlive = true;
                        child.generationBorn = nextGenNumber;
                        
                        offspring = offspring + {child};
                        k = k + 1;
                    }
                    i = i + 1;
                }
            }
        }
        
        action def derivePhenotype {
            doc "Derive phenotype from genotype by mapping allele values to traits";
            in genotype: Genotype;
            out phenotype: Phenotype;
            
            perform {
                phenotype = Phenotype();
                
                var totalAlleleValue: Real = 0.0;
                var geneCount: Integer = 0;
                
                for chrom in genotype.chromosomes {
                    for gene in chrom.genes {
                        totalAlleleValue = totalAlleleValue + gene.dominantAllele.alleleValue;
                        geneCount = geneCount + 1;
                    }
                }
                
                if geneCount > 0 {
                    var avgValue: Real = totalAlleleValue / geneCount;
                    
                    var bodyMass: Real = 0.5 + avgValue * 2.0;
                    var clampedBody: Real;
                    call clamp(bodyMass, 0.1, 10.0, clampedBody);
                    phenotype.bodyMass = clampedBody;
                    
                    var metabolic: Real = 50.0 + avgValue * 100.0;
                    var clampedMet: Real;
                    call clamp(metabolic, 10.0, 500.0, clampedMet);
                    phenotype.metabolicRate = clampedMet;
                    
                    var repro: Real = 1.0 + avgValue * 3.0;
                    var clampedRepro: Real;
                    call clamp(repro, 0.5, 6.0, clampedRepro);
                    phenotype.reproductiveRate = clampedRepro;
                    
                    var survival: Real = 0.3 + avgValue * 0.4;
                    var clampedSurv: Real;
                    call clamp(survival, 0.1, 1.0, clampedSurv);
                    phenotype.survivalProbability = clampedSurv;
                }
            }
        }
    }
    
    // ===========================================
    // Part: EnvironmentalDynamics
    // ===========================================
    
    part def EnvironmentalDynamics {
        doc "Manages changes to the environment between generations";
        
        port envInput: EnvironmentalDataPort;
        port envOutput: EnvironmentalDataPort;
        
        attribute temperatureChangeRate: TemperatureValue default 2.0;
        attribute resourceChangeRate: ResourceDensityValue default 0.5;
        attribute predatorChangeProbability: Real default 0.3;
        attribute resourceRecoveryRate: ResourceDensityValue default 0.2;
        attribute carryingCapacityMin: Integer default 10;
        attribute carryingCapacityMax: Integer default 200;
        
        action def updateEnvironment {
            doc "Update environmental factors for the next generation";
            in current: EnvironmentalFactors;
            in generationNumber: Integer;
            in out rngState: SeedValue;
            out updated: EnvironmentalFactors;
            
            perform {
                updated = EnvironmentalFactors();
                updated.carryingCapacity = current.carryingCapacity;
                
                // Temperature drift
                var randVal: Real;
                call rand(rngState, randVal);
                var tempDelta: TemperatureValue = (randVal - 0.5) * temperatureChangeRate;
                var newTemp: Real = current.temperature + tempDelta;
                var clampedTemp: Real;
                call clamp(newTemp, 250.0, 320.0, clampedTemp);
                updated.temperature = clampedTemp;
                
                // Resource density change
                call rand(rngState, randVal);
                var resourceDelta: ResourceDensityValue = (randVal - 0.5) * resourceChangeRate;
                var newResource: Real = current.resourceDensity + resourceDelta;
                var clampedResource: Real;
                call clamp(newResource, 0.0, 20.0, clampedResource);
                updated.resourceDensity = clampedResource;
                
                // Predator count — stochastic increase or decrease
                updated.predatorCount = current.predatorCount;
                call rand(rngState, randVal);
                if randVal < predatorChangeProbability {
                    call rand(rngState, randVal);
                    if randVal > 0.5 {
                        updated.predatorCount = current.predatorCount + 1;
                    }
                    else {
                        if current.predatorCount > 0 {
                            updated.predatorCount = current.predatorCount - 1;
                        }
                    }
                }
                
                // Carrying capacity responds to resource density
                if updated.resourceDensity > 8.0 {
                    updated.carryingCapacity = current.carryingCapacity + 5;
                }
                if updated.resourceDensity < 3.0 {
                    updated.carryingCapacity = current.carryingCapacity - 5;
                }
                if updated.carryingCapacity < carryingCapacityMin {
                    updated.carryingCapacity = carryingCapacityMin;
                }
                if updated.carryingCapacity > carryingCapacityMax {
                    updated.carryingCapacity = carryingCapacityMax;
                }
            }
        }
        
        action def resetEnvironment {
            in config: SimulationConfig;
            out env: EnvironmentalFactors;
            perform {
                env = EnvironmentalFactors();
                env.temperature = config.initialTemperature;
                env.resourceDensity = config.initialResourceDensity;
                env.predatorCount = config.initialPredatorCount;
                env.carryingCapacity = config.initialCarryingCapacity;
            }
        }
    }
    
    // ===========================================
    // Part: SimulationController
    // ===========================================
    
    part def SimulationController {
        doc "Controls the evolution simulation lifecycle";
        
        attribute config: SimulationConfig;
        attribute currentGeneration: Integer default 0;
        attribute isRunning: Boolean default false;
        attribute isComplete: Boolean default false;
        attribute isExtinct: Boolean default false;
        attribute rngState: SeedValue default 42;
        attribute generationsSurvived: Integer default 0;
        attribute finalResult: SimulationResult;
        
        part habitat: Habitat;
        part population: Population;
        part fitnessEvaluator: FitnessEvaluator;
        part selection: SelectionMechanism;
        part reproduction: ReproductionMechanism;
        part environmentalDynamics: EnvironmentalDynamics;
        
        port envPort: EnvironmentalDataPort;
        port popPort: PopulationDataPort;
        port generationPort: GenerationEventPort;
        port controlPort: SimulationControlPort;
        
        // Internal connections
        bind habitat.envOutput to population.envInput;
        bind habitat.envOutput to fitnessEvaluator.envInput;
        bind population.popOutput to fitnessEvaluator.popInput;
        bind population.popOutput to selection.popInput;
        bind fitnessEvaluator.fitnessOutput to selection.fitnessInput;
        bind selection.popOutput to reproduction.popInput;
        bind habitat.envOutput to reproduction.envInput;
        bind habitat.envOutput to environmentalDynamics.envInput;
        bind reproduction.popOutput to population.popOutput;
        
        state machine simulationStateMachine {
            doc "Main simulation control state machine";
            
            state Idle {
                doc "Simulation not yet started";
            }
            state Initializing {
                doc "Setting up initial population and environment";
            }
            state Running {
                doc "Active simulation in progress";
            }
            state EvaluatingFitness {
                doc "Computing fitness scores for all individuals";
            }
            state Selecting {
                doc "Performing natural selection";
            }
            state Reproducing {
                doc "Generating offspring for next generation";
            }
            state UpdatingEnvironment {
                doc "Applying environmental changes";
            }
            state Completed {
                doc "Simulation finished normally";
            }
            state ExtinctState {
                doc "Population went extinct";
            }
            state Stopped {
                doc "Simulation stopped by user";
            }
            
            transition idleToInitializing {
                from Idle;
                to Initializing;
                when isRunning == true;
            }
            
            transition initializingToRunning {
                from Initializing;
                to Running;
            }
            
            transition runningToEvaluating {
                from Running;
                to EvaluatingFitness;
            }
            
            transition evaluatingToSelecting {
                from EvaluatingFitness;
                to Selecting;
            }
            
            transition selectingToReproducing {
                from Selecting;
                to Reproducing;
            }
            
            transition reproducingToEnvUpdate {
                from Reproducing;
                to UpdatingEnvironment;
            }
            
            transition envUpdateToEvaluating {
                from UpdatingEnvironment;
                to EvaluatingFitness;
                when currentGeneration < config.maxGenerations && population.populationSize > 0;
            }
            
            transition envUpdateToCompleted {
                from UpdatingEnvironment;
                to Completed;
                when currentGeneration >= config.maxGenerations;
            }
            
            transition envUpdateToExtinct {
                from UpdatingEnvironment;
                to ExtinctState;
                when population.populationSize == 0;
            }
            
            transition completedToIdle {
                from Completed;
                to Idle;
                when isRunning == false;
            }
            
            transition extinctToIdle {
                from ExtinctState;
                to Idle;
                when isRunning == false;
            }
            
            transition runningToStopped {
                from Running;
                to Stopped;
                when isRunning == false;
            }
            
            transition stoppedToIdle {
                from Stopped;
                to Idle;
            }
        }
        
        action def initializeSimulation {
            doc "Initialize the simulation with starting parameters";
            in simConfig: SimulationConfig;
            
            perform {
                config = simConfig;
                currentGeneration = 0;
                isRunning = true;
                isComplete = false;
                isExtinct = false;
                generationsSurvived = 0;
                rngState = config.randomSeed;
                
                // Initialize environment
                var initEnv: EnvironmentalFactors;
                call environmentalDynamics.resetEnvironment(config, initEnv);
                habitat.factors = initEnv;
                
                // Initialize population
                population.populationSize = config.initialPopulationSize;
                population.generationCount = 0;
                population.individuals = {};
                
                var i: Integer = 0;
                while i < config.initialPopulationSize {
                    var indiv: Individual = Individual();
                    indiv.individualId = "founder_" + i as String;
                    indiv.age = 0;
                    indiv.isAlive = true;
                    indiv.generationBorn = 0;
                    
                    var gt: Genotype;
                    call generateRandomGenotype(config, rngState, gt);
                    indiv.genotype = gt;
                    
                    var pt: Phenotype;
                    call derivePhenotypeFromGenotype(gt, pt);
                    indiv.phenotype = pt;
                    
                    population.individuals = population.individuals + {indiv};
                    i = i + 1;
                }
            }
        }
        
        action def runGeneration {
            doc "Execute a single generation cycle";
            perform {
                var env: EnvironmentalFactors = habitat.factors;
                
                // Step 1: Fitness Evaluation
                var fitnessScores: FitnessScoreValue[0..*];
                call fitnessEvaluator.evaluatePopulation(env, population, fitnessScores);
                
                // Update population averages
                call population.computeAverages();
                
                // Step 2: Natural Selection
                var survivors: Individual[0..*];
                var popData: PopulationSnapshot;
                call selection.selectSurvivors(
                    population, env.carryingCapacity, rngState, survivors, popData);
                
                if survivors.size == 0 {
                    population.populationSize = 0;
                    isExtinct = true;
                    isComplete = true;
                    generationsSurvived = currentGeneration;
                }
                else {
                    // Step 3: Reproduction
                    var offspring: Individual[0..*];
                    call reproduction.produceOffspring(
                        survivors, env, currentGeneration + 1, rngState, offspring);
                    
                    // Replace population with offspring
                    population.individuals = offspring;
                    population.populationSize = offspring.size;
                    population.generationCount = population.generationCount + 1;
                    
                    // Step 4: Environmental Change
                    var newEnv: EnvironmentalFactors;
                    call environmentalDynamics.updateEnvironment(
                        env, currentGeneration, rngState, newEnv);
                    habitat.factors = newEnv;
                    
                    generationsSurvived = currentGeneration + 1;
                }
                
                currentGeneration = currentGeneration + 1;
                
                if currentGeneration >= config.maxGenerations {
                    isComplete = true;
                }
            }
        }
        
        action def generateRandomGenotype {
            doc "Generate a random genotype for the initial population";
            in config: SimulationConfig;
            in out rngState: SeedValue;
            out genotype: Genotype;
            
            perform {
                genotype = Genotype();
                genotype.genomeId = "genome_initial";
                
                var c: Integer = 0;
                while c < config.numChromosomes {
                    var chrom: Chromosome = Chromosome();
                    
                    var g: Integer = 0;
                    while g < config.numGenesPerChromosome {
                        var gene: Gene = Gene();
                        gene.geneId = "gene_" + c as String + "_" + g as String;
                        
                        var domAllele: Allele = Allele();
                        domAllele.geneId = gene.geneId;
                        var domVal: Real;
                        call rand(rngState, domVal);
                        domAllele.alleleValue = domVal;
                        domAllele.dominant = true;
                        
                        var recAllele: Allele = Allele();
                        recAllele.geneId = gene.geneId;
                        var recVal: Real;
                        call rand(rngState, recVal);
                        recAllele.alleleValue = recVal;
                        recAllele.dominant = false;
                        
                        gene.dominantAllele = domAllele;
                        gene.recessiveAllele = recAllele;
                        
                        chrom.genes = chrom.genes + {gene};
                        g = g + 1;
                    }
                    
                    genotype.chromosomes = genotype.chromosomes + {chrom};
                    c = c + 1;
                }
            }
        }
        
        action def derivePhenotypeFromGenotype {
            doc "Derive phenotype from a genotype";
            in genotype: Genotype;
            out phenotype: Phenotype;
            
            perform {
                phenotype = Phenotype();
                
                var totalAlleleValue: Real = 0.0;
                var geneCount: Integer = 0;
                
                for chrom in genotype.chromosomes {
                    for gene in chrom.genes {
                        totalAlleleValue = totalAlleleValue + gene.dominantAllele.alleleValue;
                        geneCount = geneCount + 1;
                    }
                }
                
                if geneCount > 0 {
                    var avgValue: Real = totalAlleleValue / geneCount;
                    
                    var bodyMass: Real = 0.5 + avgValue * 2.0;
                    var clampedBody: Real;
                    call clamp(bodyMass, 0.1, 10.0, clampedBody);
                    phenotype.bodyMass = clampedBody;
                    
                    var metabolic: Real = 50.0 + avgValue * 100.0;
                    var clampedMet: Real;
                    call clamp(metabolic, 10.0, 500.0, clampedMet);
                    phenotype.metabolicRate = clampedMet;
                    
                    var repro: Real = 1.0 + avgValue * 3.0;
                    var clampedRepro: Real;
                    call clamp(repro, 0.5, 6.0, clampedRepro);
                    phenotype.reproductiveRate = clampedRepro;
                    
                    var survival: Real = 0.3 + avgValue * 0.4;
                    var clampedSurv: Real;
                    call clamp(survival, 0.1, 1.0, clampedSurv);
                    phenotype.survivalProbability = clampedSurv;
                }
            }
        }
        
        action def getSimulationResult {
            out result: SimulationResult;
            perform {
                result = SimulationResult();
                result.totalGenerations = currentGeneration;
                result.finalPopulationSize = population.populationSize;
                result.isExtinct = isExtinct;
                result.generationsSurvived = generationsSurvived;
                result.finalAverageFitness = population.averageFitness;
                result.finalAverageBodyMass = population.averageBodyMass;
            }
        }
        
        action def stopSimulation {
            perform {
                isRunning = false;
            }
        }
    }
    
    // ===========================================
    // Top-Level System
    // ===========================================
    
    part def EvolutionSimulationSystem {
        doc "Top-level system for simulating biological evolution through natural selection";
        
        attribute systemName: String default "EvolutionSimulationSystem";
        attribute systemVersion: String default "1.0";
        attribute description: String default 
            "Simulates biological evolution within a population of organisms over many generations";
        
        part controller: SimulationController;
        
        port envPort: EnvironmentalDataPort;
        port genPort: GenerationEventPort;
        port controlPort: SimulationControlPort;
        port resultPort: PopulationDataPort;
        
        bind envPort to controller.envPort;
        bind genPort to controller.generationPort;
        bind controlPort to controller.controlPort;
        bind resultPort to controller.popPort;
    }
    
    // ===========================================
    // Requirements
    // ===========================================
    
    requirement def EvolutionSimulationRequirements {
        doc "Top-level requirements for the biological evolution simulation system";
        
        requirement populationModelingReq {
            doc "The system shall model a population of unique individuals";
            subject: EvolutionSimulationSystem;
            require populationSize: Integer >= 0;
            require controller.population.individuals[*].individualId: String;
        }
        
        requirement genotypeModelingReq {
            doc "Each individual shall have a distinct genetic makeup (genotype)";
            subject: Individual;
            require genotype: Genotype;
            require genotype.chromosomes[*].genes[*].dominantAllele: Allele;
            require genotype.chromosomes[*].genes[*].recessiveAllele: Allele;
        }
        
        requirement phenotypeModelingReq {
            doc "Each individual shall have a phenotype derived from its genotype";
            subject: Individual;
            require phenotype: Phenotype;
            require phenotype.bodyMass: BodyMassKg;
            require phenotype.metabolicRate: MetabolicRateValue;
            require phenotype.reproductiveRate: ReproductiveRateValue;
            require phenotype.survivalProbability: SurvivalProbabilityValue;
        }
        
        requirement habitatModelingReq {
            doc "The system shall include a dynamic habitat with environmental factors";
            subject: Habitat;
            require factors.temperature: TemperatureValue;
            require factors.resourceDensity: ResourceDensityValue;
            require factors.predatorCount: Integer >= 0;
            require factors.carryingCapacity: Integer >= 1;
        }
        
        requirement carryingCapacityReq {
            doc "The habitat shall have a limited carrying capacity";
            subject: Habitat;
            require factors.carryingCapacity: Integer >= 1;
            assume factors.carryingCapacity: Integer <= 200;
        }
        
        requirement fitnessEvaluationReq {
            doc "The system shall evaluate each individual fitness against environmental conditions";
            subject: FitnessEvaluator;
            require fitnessScores: FitnessScoreValue[0..*];
            require fitnessScores[*] >= 0.0;
            require fitnessScores[*] <= 1.0;
        }
        
        requirement naturalSelectionReq {
            doc "The system shall perform natural selection favoring individuals with higher fitness";
            subject: SelectionMechanism;
            require survivalThreshold: FitnessScoreValue >= 0.0;
            require selectionPressure: Real >= 0.0;
        }
        
        requirement reproductionReq {
            doc "The system shall reproduce through mutation and recombination of genetic material";
            subject: ReproductionMechanism;
            require mutator.mutationRate: MutationRateValue >= 0.0;
            require recombiner.recombinationRate: RecombinationRateValue >= 0.0;
            require recombiner.recombinationRate: RecombinationRateValue <= 1.0;
        }
        
        requirement mutationReq {
            doc "Mutation shall introduce genetic diversity by altering allele values";
            subject: MutationMechanism;
            require mutationRate: MutationRateValue >= 0.0;
            require mutationMagnitude: Real > 0.0;
        }
        
        requirement recombinationReq {
            doc "Recombination shall shuffle genes from both parents during reproduction";
            subject: RecombinationMechanism;
            require recombinationRate: RecombinationRateValue >= 0.0;
            require recombinationRate: RecombinationRateValue <= 1.0;
        }
        
        requirement environmentalDynamicsReq {
            doc "The environment shall change between generations, creating new selection pressures";
            subject: EnvironmentalDynamics;
            require temperatureChangeRate: TemperatureValue;
            require resourceChangeRate: ResourceDensityValue;
            require predatorChangeProbability: Real >= 0.0;
        }
        
        requirement environmentalChangeRangeReq {
            doc "Environmental changes shall be bounded to realistic ranges";
            subject: EnvironmentalDynamics;
            require temperatureChangeRate: TemperatureValue <= 10.0;
            require resourceChangeRate: ResourceDensityValue <= 5.0;
        }
        
        requirement extinctionHandlingReq {
            doc "The system shall detect and handle population extinction";
            subject: SimulationController;
            require isExtinct: Boolean;
            require generationsSurvived: Integer >= 0;
        }
        
        requirement multiGenerationReq {
            doc "The simulation shall run for hundreds or thousands of generations";
            subject: SimulationController;
            require config.maxGenerations: Integer >= 100;
            require currentGeneration: Integer >= 0;
            require currentGeneration: Integer <= config.maxGenerations;
        }
        
        requirement adaptationTrackingReq {
            doc "The system shall track population-level adaptation over time";
            subject: Population;
            require averageFitness: FitnessScoreValue;
            require averageBodyMass: BodyMassKg;
            require averageMetabolicRate: MetabolicRateValue;
            require averageReproductiveRate: ReproductiveRateValue;
            require averageSurvivalProbability: SurvivalProbabilityValue;
        }
        
        requirement lifecycleModelingReq {
            doc "The system shall model the complete lifecycle of individuals";
            subject: Individual;
            require age: Integer >= 0;
            require isAlive: Boolean;
        }
        
        requirement populationDynamicsReq {
            doc "The population shall transition through growth, stability, decline, and potential extinction";
            subject: Population;
            require populationSize: Integer >= 0;
            require generationCount: Integer >= 0;
        }
        
        requirement simulationResultReq {
            doc "The system shall produce a result summarizing the simulation outcome";
            subject: SimulationController;
            require finalResult.totalGenerations: Integer;
            require finalResult.finalPopulationSize: Integer >= 0;
            require finalResult.isExtinct: Boolean;
            require finalResult.generationsSurvived: Integer >= 0;
        }
    }
}
