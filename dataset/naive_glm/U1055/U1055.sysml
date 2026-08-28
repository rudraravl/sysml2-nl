package ExploratoryEngineeringPlatform {
    import ScalarValues::*;
    import ISQ::*;
    
    value def Mass :> Real { unit "kg"; }
    value def Power :> Real { unit "W"; }
    value def Efficiency :> Real { unit "%"; }
    value def Complexity :> Real { unit "unitless"; }
    value def Maturity :> Integer { unit "level"; }
    value def Score :> Real { unit "pts"; }
    
    item def DesignConcept {
        attribute mass : Mass;
        attribute power : Power;
        attribute efficiency : Efficiency;
        attribute complexity : Complexity;
        attribute maturity : Maturity;
        attribute score : Score;
    }
    
    item def SeedDesign :> DesignConcept;
    
    item def FeasibilityReport {
        attribute concept : DesignConcept;
        attribute viabilityScore : Score;
        attribute isFeasible : Boolean;
    }
    
    item def TradeStudyResult {
        attribute rankedConcepts : DesignConcept[0..*];
        attribute bestConcept : DesignConcept;
    }
    
    item def ValidationReport {
        attribute concept : DesignConcept;
        attribute meetsRequirements : Boolean;
        attribute finalScore : Score;
    }
    
    requirement def SystemRequirements {
        attribute maxMass : Mass = 1000;
        attribute minEfficiency : Efficiency = 80;
        subject concept : DesignConcept;
        constraint { concept.mass <= maxMass }
        constraint { concept.efficiency >= minEfficiency }
    }
    
    port def ConceptOut { out item concept : DesignConcept; }
    port def ConceptIn { in item concept : DesignConcept; }
    port def ConceptListOut { out item concepts : DesignConcept[0..*]; }
    port def ConceptListIn { in item concepts : DesignConcept[0..*]; }
    port def ValidationOut { out item report : ValidationReport; }
    port def ValidationIn { in item report : ValidationReport; }
    
    part def ConceptGenerator {
        port seedIn : ConceptIn;
        port conceptsOut : ConceptListOut;
        
        action def GenerateVariations {
            in seed : DesignConcept;
            out variations : DesignConcept[0..*];
        }
        
        exhibit state def GenerationBehavior {
            entry; then Generating;
            state Generating;
            transition Generating -> Generating
                when seedIn.concept isReceived
                do action GenerateVariations(in seed = seedIn.concept, out variations = conceptsOut.concepts);
        }
    }
    
    part def FeasibilityAnalyzer {
        port conceptsIn : ConceptListIn;
        port feasibleOut : ConceptListOut;
        
        action def FilterFeasible {
            in concepts : DesignConcept[0..*];
            out feasibleConcepts : DesignConcept[0..*];
        }
        
        exhibit state def AnalysisBehavior {
            entry; then Analyzing;
            state Analyzing;
            transition Analyzing -> Analyzing
                when conceptsIn.concepts isReceived
                do action FilterFeasible(in concepts = conceptsIn.concepts, out feasibleConcepts = feasibleOut.concepts);
        }
    }
    
    part def TradeStudyEngine {
        port conceptsIn : ConceptListIn;
        port bestOut : ConceptOut;
        
        action def RankConcepts {
            in concepts : DesignConcept[0..*];
            out best : DesignConcept;
        }
        
        exhibit state def TradeStudyBehavior {
            entry; then Evaluating;
            state Evaluating;
            transition Evaluating -> Evaluating
                when conceptsIn.concepts isReceived
                do action RankConcepts(in concepts = conceptsIn.concepts, out best = bestOut.concept);
        }
    }
    
    part def OptimizationEngine {
        port conceptIn : ConceptIn;
        port optimizedOut : ConceptOut;
        
        action def OptimizeParameters {
            in concept : DesignConcept;
            out optimized : DesignConcept;
        }
        
        exhibit state def OptimizationBehavior {
            entry; then Optimizing;
            state Optimizing;
            transition Optimizing -> Optimizing
                when conceptIn.concept isReceived
                do action OptimizeParameters(in concept = conceptIn.concept, out optimized = optimizedOut.concept);
        }
    }
    
    part def PerformanceValidator {
        port conceptIn : ConceptIn;
        port reportOut : ValidationOut;
        
        action def ValidatePerformance {
            in concept : DesignConcept;
            out report : ValidationReport;
        }
        
        exhibit state def ValidationBehavior {
            entry; then Validating;
            state Validating;
            transition Validating -> Validating
                when conceptIn.concept isReceived
                do action ValidatePerformance(in concept = conceptIn.concept, out report = reportOut.report);
        }
    }
    
    part def KnowledgeRepository {
        port conceptIn : ConceptIn;
        port reportIn : ValidationIn;
        
        attribute storedConcepts : DesignConcept[0..*];
        attribute storedReports : ValidationReport[0..*];
        
        action def StoreConcept {
            in concept : DesignConcept;
            in out storedConcepts : DesignConcept[0..*];
        }
        action def StoreReport {
            in report : ValidationReport;
            in out storedReports : ValidationReport[0..*];
        }
        
        exhibit state def StorageBehavior {
            entry; then Storing;
            state Storing;
            transition Storing -> Storing
                when conceptIn.concept isReceived
                do action StoreConcept(in concept = conceptIn.concept, in out storedConcepts = storedConcepts);
            transition Storing -> Storing
                when reportIn.report isReceived
                do action StoreReport(in report = reportIn.report, in out storedReports = storedReports);
        }
    }
    
    part def PlatformController {
        port reportIn : ValidationIn;
        port seedOut : ConceptOut;
        
        attribute currentBest : DesignConcept;
        
        action def EvaluateReport {
            in report : ValidationReport;
            out seed : DesignConcept;
        }
        
        exhibit state def ControlBehavior {
            entry; then Idle;
            state Idle;
            transition Idle -> Idle
                when reportIn.report isReceived
                do action EvaluateReport(in report = reportIn.report, out seed = seedOut.concept);
        }
    }
    
    part def ExploratoryEngineeringPlatform {
        part generator : ConceptGenerator;
        part analyzer : FeasibilityAnalyzer;
        part tradeStudy : TradeStudyEngine;
        part optimizer : OptimizationEngine;
        part validator : PerformanceValidator;
        part repository : KnowledgeRepository;
        part controller : PlatformController;
        
        connection generator.conceptsOut to analyzer.conceptsIn;
        connection analyzer.feasibleOut to tradeStudy.conceptsIn;
        connection tradeStudy.bestOut to optimizer.conceptIn;
        connection optimizer.optimizedOut to validator.conceptIn;
        
        connection generator.conceptsOut to repository.conceptIn;
        connection validator.reportOut to repository.reportIn;
        
        connection validator.reportOut to controller.reportIn;
        connection controller.seedOut to generator.seedIn;
    }
}
