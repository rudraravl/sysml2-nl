package EvolutionaryBiologySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    
    attribute def GenerationNumber :> Integer;
    attribute def FitnessValue :> Real;
    attribute def MutationProbability :> Real;
    attribute def SelectionCoefficient :> Real;
    attribute def AlleleFrequency :> Real;
    
    attribute def GeneticSequence {
        attribute nucleotides : String;
        attribute length : Integer;
    }
    
    attribute def Phenotype {
        attribute bodySize : LengthValue;
        attribute metabolicRate : PowerValue;
        attribute reproductiveRate : Real;
        attribute survivalProbability : Real;
    }
    
    attribute def EnvironmentalFactors {
        attribute temperature : TemperatureValue;
        attribute resourceDensity : Real;
        attribute predatorDensity : Real;
        attribute climaticStress : Real;
    }
    
    item def Genotype {
        attribute sequence : GeneticSequence;
        attribute alleles : String[*];
        attribute mutationRate : MutationProbability;
    }
    
    item def Individual {
        attribute genotype : Genotype;
        attribute phenotype : Phenotype;
        attribute fitness : FitnessValue;
        attribute age : DurationValue;
        attribute isAlive : Boolean;
    }
    
    item def PopulationData {
        attribute individuals : Individual[1..*];
        attribute size : Integer;
        attribute meanFitness : FitnessValue;
        attribute geneticVariance : Real;
        attribute alleleFrequencies : AlleleFrequency[*];
    }
    
    part def HabitatEnvironment {
        attribute conditions : EnvironmentalFactors;
        attribute carryingCapacity : Integer;
        attribute seasonalCycle : DurationValue;
        
        port environmentOutput {
            out envConditions : EnvironmentalFactors;
            out capacity : Integer;
        }
    }
    
    part def GeneticVariationEngine {
        attribute baseMutationRate : MutationProbability;
        attribute recombinationRate : Real;
        
        port variationInput {
            in parentGenotypes : Genotype[2];
        }
        
        port variationOutput {
            out offspringGenotype : Genotype;
        }
    }
    
    part def SelectionMechanism {
        attribute selectionIntensity : SelectionCoefficient;
        attribute selectionType : String;
        
        port selectionInput {
            in population : PopulationData;
            in environment : EnvironmentalFactors;
        }
        
        port selectionOutput {
            out selectedIndividuals : Individual[*];
            out eliminatedIndividuals : Individual[*];
        }
    }
    
    part def ReproductionSystem {
        attribute offspringPerMating : Integer;
        attribute sexualReproduction : Boolean;
        
        port reproductionInput {
            in parents : Individual[*];
            in mutationEngine : GeneticVariationEngine;
        }
        
        port reproductionOutput {
            out offspring : Individual[*];
        }
    }
    
    part def FitnessCalculator {
        port fitnessInput {
            in individual : Individual;
            in environment : EnvironmentalFactors;
        }
        
        port fitnessOutput {
            out fitnessScore : FitnessValue;
        }
    }
    
    action def CalculateFitness {
        in individual : Individual;
        in environment : EnvironmentalFactors;
        out fitness : FitnessValue;
    }
    
    action def ApplyMutation {
        in parentGenotype : Genotype;
        in mutationRate : MutationProbability;
        out mutatedGenotype : Genotype;
    }
    
    action def PerformRecombination {
        in parent1Genotype : Genotype;
        in parent2Genotype : Genotype;
        out recombinedGenotype : Genotype;
    }
    
    action def SelectForReproduction {
        in population : PopulationData;
        in environment : EnvironmentalFactors;
        in selectionCoefficient : SelectionCoefficient;
        out survivors : Individual[*];
        out deceased : Individual[*];
    }
    
    action def ProduceOffspring {
        in parent1 : Individual;
        in parent2 : Individual;
        in mutationRate : MutationProbability;
        out newIndividual : Individual;
    }
    
    action def UpdateEnvironment {
        in currentConditions : EnvironmentalFactors;
        in generation : GenerationNumber;
        in populationSize : Integer;
        out updatedConditions : EnvironmentalFactors;
    }
    
    action def EvolutionaryProcess {
        in foundingPopulation : PopulationData;
        in habitat : EnvironmentalFactors;
        in generationLimit : GenerationNumber;
        in mutationRate : MutationProbability;
        in selectionStrength : SelectionCoefficient;
        out evolvedPopulation : PopulationData;
        out generationalData : PopulationData[*];
        
        private attribute currentPopulation : PopulationData := foundingPopulation;
        private attribute currentEnvironment : EnvironmentalFactors := habitat;
        private attribute populationHistory : PopulationData[*] := (foundingPopulation);
        private attribute generationCount : GenerationNumber := 0;
        
        first start;
        then merge generationCycle;
        
        action generationLoop {
            first action evaluateFitness {
                private attribute evalIndex : Integer := 1;
                private attribute popSize : Integer := currentPopulation.size;
                
                first action evalStart;
                then merge evalNext;
                
                action evalStep {
                    private attribute currentIndividual : Individual := currentPopulation.individuals->at(evalIndex);
                    
                    action calcFit : CalculateFitness {
                        in individual = currentIndividual;
                        in environment = currentEnvironment;
                        out fitness;
                    }
                    
                    then assign currentIndividual.fitness := calcFit.fitness;
                    then assign evalIndex := evalIndex + 1;
                }
                
                then decide;
                    if evalIndex <= popSize then evalNext;
                    if evalIndex > popSize then evalDone;
                
                action evalDone;
            }
            
            then action naturalSelection : SelectForReproduction {
                in population = currentPopulation;
                in environment = currentEnvironment;
                in selectionCoefficient = selectionStrength;
                out survivors;
                out deceased;
            }
            
            then action reproduction {
                private attribute newGeneration : Individual[*] := ();
                private attribute pairIndex : Integer := 1;
                private attribute targetSize : Integer := currentPopulation.size;
                
                first action reproStart;
                then merge reproNext;
                
                action reproStep {
                    private attribute parent1 : Individual := naturalSelection.survivors->at(pairIndex);
                    private attribute parent2 : Individual := naturalSelection.survivors->at(pairIndex + 1);
                    
                    action mate : ProduceOffspring {
                        in parent1 = parent1;
                        in parent2 = parent2;
                        in mutationRate = mutationRate;
                        out newIndividual;
                    }
                    
                    then assign newGeneration := newGeneration->including(mate.newIndividual);
                    then assign pairIndex := pairIndex + 2;
                }
                
                then decide;
                    if newGeneration->size() < targetSize then reproNext;
                    if newGeneration->size() >= targetSize then reproDone;
                
                action reproDone {
                    then assign currentPopulation.individuals := newGeneration;
                }
            }
            
            then action environmentUpdate : UpdateEnvironment {
                in currentConditions = currentEnvironment;
                in generation = generationCount;
                in populationSize = currentPopulation.size;
                out updatedConditions;
            }
            
            then assign currentEnvironment := environmentUpdate.updatedConditions;
            then assign generationCount := generationCount + 1;
            
            then action recordPopulation {
                private attribute snapshot : PopulationData {
                    :>> individuals = currentPopulation.individuals;
                    :>> size = currentPopulation.size;
                    :>> meanFitness = currentPopulation.meanFitness;
                }
                then assign populationHistory := populationHistory->including(snapshot);
            }
        }
        
        then decide;
            if generationCount < generationLimit then generationCycle;
            if generationCount >= generationLimit then finalize;
        
        action finalize {
            then assign evolvedPopulation := currentPopulation;
            then assign generationalData := populationHistory;
        }
        
        then done;
    }
    
    state def PopulationLifecycle {
        entry; then founding;
        
        state founding {
            entry action initializePopulation;
        }
        
        transition founding_to_growth
            first founding
            accept when populationSize > 0
            then growth;
        
        state growth {
            do action reproduce;
            do action mutate;
        }
        
        transition growth_to_selection
            first growth
            accept when resourceLimited
            then selection;
        
        state selection {
            do action evaluateFitness;
            do action eliminateUnfit;
        }
        
        transition selection_to_adaptation
            first selection
            accept when environmentalPressure
            then adaptation;
        
        state adaptation {
            state divergence {
                do action speciationProcess;
            }
            state convergence {
                do action optimizeFitness;
            }
        }
        
        transition adaptation_to_equilibrium
            first adaptation
            accept when fitnessStabilized
            then equilibrium;
        
        state equilibrium {
            do action maintainDiversity;
        }
        
        transition equilibrium_to_extinction
            first equilibrium
            accept when catastrophicEvent or populationSize == 0
            then extinction;
        
        state extinction;
        
        transition extinction_to_exit
            first extinction
            then done;
    }
    
    part evolutionaryBiologySystem {
        doc /* 
        This system models the fundamental mechanisms of biological evolution in natural populations.
        
        The primary function is to simulate evolutionary change across generations through the 
        interplay of genetic variation, natural selection, and environmental pressures. The system 
        demonstrates how populations adapt to their environments over time through differential 
        survival and reproduction of individuals with varying genetic traits.
        
        The simulation operates through discrete generational cycles. Each cycle begins with fitness 
        evaluation, where every individual's phenotypic traits are assessed against current 
        environmental conditions to determine survival probability. Natural selection then acts on 
        this variation, favoring individuals whose traits confer higher fitness. Survivors reproduce, 
        passing genetic material to offspring with occasional mutations and genetic recombination 
        introducing new variation. Environmental conditions may fluctuate between generations, 
        creating dynamic selection pressures. This iterative process continues across many generations, 
        producing evolutionary trajectories that reveal adaptation, genetic drift, and the emergence 
        of complex biological diversity patterns observed in nature.
        */
        
        attribute systemMutationRate : MutationProbability = 0.001;
        attribute systemSelectionStrength : SelectionCoefficient = 0.25;
        attribute maximumGenerations : GenerationNumber = 500;
        attribute initialPopulationSize : Integer = 200;
        
        part habitat : HabitatEnvironment {
            attribute :>> conditions = EnvironmentalFactors {
                :>> temperature = 293.15 [SI::K];
                :>> resourceDensity = 0.65;
                :>> predatorDensity = 0.15;
                :>> climaticStress = 0.3;
            }
            attribute :>> carryingCapacity = 1000;
            attribute :>> seasonalCycle = 365.0 [SI::d];
        }
        
        part variationEngine : GeneticVariationEngine {
            attribute :>> baseMutationRate = evolutionaryBiologySystem.systemMutationRate;
            attribute :>> recombinationRate = 0.5;
        }
        
        part selectionMechanism : SelectionMechanism {
            attribute :>> selectionIntensity = evolutionaryBiologySystem.systemSelectionStrength;
            attribute :>> selectionType = "stabilizing";
        }
        
        part reproductionSystem : ReproductionSystem {
            attribute :>> offspringPerMating = 2;
            attribute :>> sexualReproduction = true;
        }
        
        part fitnessCalculator : FitnessCalculator;
        
        connection habitatToSelection
            connect habitat.environmentOutput.envConditions to selectionMechanism.selectionInput.environment;
        
        connection selectionToReproduction
            connect selectionMechanism.selectionOutput.selectedIndividuals to reproductionSystem.reproductionInput.parents;
        
        connection variationToReproduction
            connect variationEngine to reproductionSystem.reproductionInput.mutationEngine;
        
        perform action runEvolution : EvolutionaryProcess {
            in foundingPopulation = PopulationData {
                :>> size = evolutionaryBiologySystem.initialPopulationSize;
                :>> geneticVariance = 0.75;
            }
            in habitat = habitat.conditions;
            in generationLimit = evolutionaryBiologySystem.maximumGenerations;
            in mutationRate = evolutionaryBiologySystem.systemMutationRate;
            in selectionStrength = evolutionaryBiologySystem.systemSelectionStrength;
            out evolvedPopulation;
            out generationalData;
        }
    }
    
    requirement def EvolutionarySystemRequirements {
        doc /* The evolutionary biology system shall accurately simulate natural selection and adaptation. */
        
        requirement geneticVariationMaintenance {
            id = "REQ-001";
            doc /* The system shall maintain genetic variation through mutation and recombination mechanisms. */
            
            require constraint {
                variationEngine.baseMutationRate > 0.0 and 
                variationEngine.baseMutationRate < 0.1 and
                variationEngine.recombinationRate >= 0.0 and
                variationEngine.recombinationRate <= 1.0
            }
        }
        
        requirement selectionPressureApplication {
            id = "REQ-002";
            doc /* The system shall apply selection pressure proportional to fitness differences. */
            
            require constraint {
                selectionMechanism.selectionIntensity >= 0.0 and
                selectionMechanism.selectionIntensity <= 1.0
            }
        }
        
        requirement populationViability {
            id = "REQ-003";
            doc /* The system shall maintain population sizes within ecological carrying capacity. */
            
            require constraint {
                evolutionaryBiologySystem.runEvolution.evolvedPopulation.size > 0 and
                evolutionaryBiologySystem.runEvolution.evolvedPopulation.size <= habitat.carryingCapacity
            }
        }
        
        requirement adaptiveEvolution {
            id = "REQ-004";
            doc /* The system shall demonstrate fitness optimization over successive generations. */
            
            require constraint {
                evolutionaryBiologySystem.runEvolution.evolvedPopulation.meanFitness >= 
                evolutionaryBiologySystem.runEvolution.foundingPopulation.meanFitness
            }
        }
        
        requirement environmentalResponsiveness {
            id = "REQ-005";
            doc /* The system shall adjust selection dynamics in response to environmental changes. */
            
            require constraint {
                habitat.conditions.temperature >= 273.15 [SI::K] and
                habitat.conditions.temperature <= 323.15 [SI::K] and
                habitat.conditions.resourceDensity >= 0.0 and
                habitat.conditions.resourceDensity <= 1.0
            }
        }
    }
    
    requirement systemRequirements : EvolutionarySystemRequirements {
        subject evolutionaryBiologySystem;
        
        assume constraint initialConditions {
            doc /* Initial population must be viable and environment must support life. */
            evolutionaryBiologySystem.initialPopulationSize > 10 and
            habitat.conditions.resourceDensity > 0.1 and
            habitat.conditions.temperature > 273.15 [SI::K]
        }
        
        require geneticVariationMaintenance;
        require selectionPressureApplication;
        require populationViability;
        require adaptiveEvolution;
        require environmentalResponsiveness;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    private import EvolutionaryBiologySystem::*;

    part testSubject : HabitatEnvironment {
        exhibit state sm : PopulationLifecycle;
    }

    action orchestrator {
        attribute testEnvironment : EnvironmentalFactors {
            attribute temperature : TemperatureValue;
            attribute resourceDensity = 0.0;
            attribute predatorDensity = 0.0;
            attribute climaticStress = 0.0;
        }
        action calcFitProbe : CalculateFitness {
            // TODO(human): unsupported input type for individual: Individual (unsupported structured payload members: genotype)
            in environment = testEnvironment;
        }
        first calcFitProbe;
    }
}
