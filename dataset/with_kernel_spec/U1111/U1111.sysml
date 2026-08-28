package JoblessRecoveryModel {
    private import ScalarValues::Real;
    private import ScalarValues::String;
    private import ScalarValues::Boolean;
    private import ScalarValues::Integer;

    doc /* This model represents a modern economic system designed to analyze and understand the phenomenon of a "jobless recovery." */

    // ===== Value Type Definitions =====

    attribute def Money :> Real {
        doc /* Monetary value in billions of currency units */
    }
    attribute def GDP :> Money {
        doc /* Gross Domestic Product */
    }
    attribute def GDPRate :> Real {
        doc /* GDP growth rate as a percentage */
    }
    attribute def UnemploymentRate :> Real {
        doc /* Unemployment rate as a percentage */
    }
    attribute def ProductivityIndex :> Real {
        doc /* Labor productivity index, baseline 100 */
    }
    attribute def LaborCost :> Money {
        doc /* Cost per worker per period */
    }
    attribute def TechnologyCost :> Money {
        doc /* Cost per unit of automation per period */
    }
    attribute def DemandLevel :> Money {
        doc /* Level of aggregate demand */
    }
    attribute def OutputLevel :> Money {
        doc /* Level of economic output */
    }
    attribute def ProfitLevel :> Money {
        doc /* Corporate profit level */
    }
    attribute def WorkerCount :> Real {
        doc /* Number of workers in thousands */
    }
    attribute def HiresCount :> Real {
        doc /* Number of new hires in thousands */
    }
    attribute def AutomationInvestment :> Money {
        doc /* Investment in automation technology */
    }
    attribute def RetrainingBudget :> Money {
        doc /* Budget for workforce retraining */
    }

    // ===== Item Definitions =====

    item def EconomicData {
        doc /* Snapshot of key economic indicators */
        attribute gdpLevel : GDP;
        attribute gdpGrowthRate : GDPRate;
        attribute unemploymentRate : UnemploymentRate;
        attribute productivityIndex : ProductivityIndex;
    }

    item def DemandSignal {
        doc /* Signal indicating level and trend of demand */
        attribute level : DemandLevel;
        attribute trend : Real;
    }

    item def HiringDecision {
        doc /* Decision on how many workers to hire */
        attribute newHires : HiresCount;
        attribute justification : String;
    }

    item def AutomationDecision {
        doc /* Decision on how much to invest in automation */
        attribute investment : AutomationInvestment;
        attribute justification : String;
    }

    item def PolicyAction {
        doc /* Government policy intervention action */
        attribute fiscalStimulus : Money;
        attribute infrastructureInvestment : Money;
        attribute retrainingFunding : RetrainingBudget;
        attribute description : String;
    }

    item def ProductivityReport {
        doc /* Report on productivity levels */
        attribute index : ProductivityIndex;
        attribute trend : Real;
    }

    item def LaborMarketStatus {
        doc /* Status of the labor market */
        attribute employed : WorkerCount;
        attribute unemployed : WorkerCount;
        attribute unemploymentRate : UnemploymentRate;
    }

    item def TechnologyProduct {
        doc /* Automation product offered by the Technology Sector */
        attribute name : String;
        attribute productivityGain : ProductivityIndex;
        attribute price : TechnologyCost;
    }

    // ===== Port Definitions =====

    port def EconomicDataOut {
        out data : EconomicData;
    }
    port def EconomicDataIn {
        in data : EconomicData;
    }
    port def DemandOut {
        out demand : DemandSignal;
    }
    port def DemandIn {
        in demand : DemandSignal;
    }
    port def HiringOut {
        out decision : HiringDecision;
    }
    port def HiringIn {
        in decision : HiringDecision;
    }
    port def AutomationOut {
        out decision : AutomationDecision;
    }
    port def AutomationIn {
        in decision : AutomationDecision;
    }
    port def PolicyOut {
        out action : PolicyAction;
    }
    port def PolicyIn {
        in action : PolicyAction;
    }
    port def ProductivityOut {
        out report : ProductivityReport;
    }
    port def ProductivityIn {
        in report : ProductivityReport;
    }
    port def LaborStatusOut {
        out status : LaborMarketStatus;
    }
    port def LaborStatusIn {
        in status : LaborMarketStatus;
    }
    port def TechnologyProductOut {
        out product : TechnologyProduct;
    }
    port def TechnologyProductIn {
        in product : TechnologyProduct;
    }

    // ===== Calculation Definitions =====

    calc def EffectiveTechCost {
        doc /* Effective cost of technology per unit of output, adjusted for productivity gains */
        in techCostPerUnit : TechnologyCost;
        in productivityIndex : ProductivityIndex;
        return : TechnologyCost = techCostPerUnit / (1.0 + productivityIndex / 100.0);
    }

    calc def RequiredWorkers {
        doc /* Number of workers required to meet a given demand level at current output per worker */
        in demandLevel : DemandLevel;
        in baselineOutputPerWorker : OutputLevel;
        return : HiresCount = demandLevel / baselineOutputPerWorker;
    }

    calc def TotalLaborCost {
        doc /* Total cost of hiring workers to meet demand */
        in demandLevel : DemandLevel;
        in laborCostPerWorker : LaborCost;
        in baselineOutputPerWorker : OutputLevel;
        return : Money = RequiredWorkers(demandLevel, baselineOutputPerWorker) * laborCostPerWorker;
    }

    calc def TotalTechCost {
        doc /* Total cost of automation to meet demand, accounting for productivity gains */
        in demandLevel : DemandLevel;
        in techCostPerUnit : TechnologyCost;
        in productivityIndex : ProductivityIndex;
        in baselineOutputPerWorker : OutputLevel;
        return : Money = EffectiveTechCost(techCostPerUnit, productivityIndex) * (demandLevel / baselineOutputPerWorker);
    }

    // ===== Action Definitions =====

    action def CollectEconomicData {
        doc /* Collect economic data from all sectors */
        out data : EconomicData;
    }

    action def DistributeData {
        doc /* Distribute economic data to all sectors */
        in data : EconomicData;
    }

    action def AssessDemand {
        doc /* Assess incoming demand signal and produce assessed demand level */
        in demand : DemandSignal;
        out assessedLevel : DemandLevel;
    }

    action def CompareCosts {
        doc /* Compare effective cost of technology vs labor for meeting demand */
        in demandLevel : DemandLevel;
        in productivity : ProductivityReport;
        in techCostPerUnit : TechnologyCost;
        in laborCostPerWorker : LaborCost;
        in baselineOutputPerWorker : OutputLevel;
        out totalTechCost : Money;
        out totalLaborCost : Money;
        out requiredWorkers : HiresCount;
    }

    action def ChooseAutomation {
        doc /* Invest in automation instead of hiring */
        in demandLevel : DemandLevel;
        in techCostPerUnit : TechnologyCost;
        out automation : AutomationDecision;
    }

    action def ChooseHiring {
        doc /* Hire new workers instead of automating */
        in demandLevel : DemandLevel;
        in requiredWorkers : HiresCount;
        out hiring : HiringDecision;
    }

    action def DetectJoblessRecovery {
        doc /* Detect if GDP is growing but unemployment remains high */
        in data : EconomicData;
        in threshold : UnemploymentRate;
        out isJobless : Boolean;
    }

    action def DesignIntervention {
        doc /* Design policy intervention for jobless recovery */
        out action : PolicyAction;
    }

    action def MonitorEconomy {
        doc /* Continue monitoring, no intervention needed */
        out action : PolicyAction;
    }

    action def UpdateEmployment {
        doc /* Update employment status based on hiring decisions and policy actions */
        in newHires : HiresCount;
        in policyAction : PolicyAction;
        in currentEmployed : WorkerCount;
        in totalWorkforce : WorkerCount;
        out status : LaborMarketStatus;
    }

    action def DevelopAutomation {
        doc /* Develop automation technology based on demand */
        in demand : AutomationDecision;
        out product : TechnologyProduct;
        out report : ProductivityReport;
    }

    // ===== Composite Action Definitions =====

    action def CorporateDecisionCycle {
        doc /* Main corporate decision cycle: assess demand, compare costs, choose automation or hiring */
        in data : EconomicData;
        in demand : DemandSignal;
        in productivity : ProductivityReport;
        in techCostPerUnit : TechnologyCost;
        in laborCostPerWorker : LaborCost;
        in baselineOutputPerWorker : OutputLevel;
        out hiring : HiringDecision;
        out automation : AutomationDecision;

        first start;
        then action assess : AssessDemand {
            in demand = demand;
            out assessedLevel;
        }
        then action compare : CompareCosts {
            in demandLevel = assess.assessedLevel;
            in productivity = productivity;
            in techCostPerUnit = techCostPerUnit;
            in laborCostPerWorker = laborCostPerWorker;
            in baselineOutputPerWorker = baselineOutputPerWorker;
            out totalTechCost;
            out totalLaborCost;
            out requiredWorkers;
        }
        then if compare.totalTechCost < compare.totalLaborCost {
            action automate : ChooseAutomation {
                in demandLevel = assess.assessedLevel;
                in techCostPerUnit = techCostPerUnit;
                out automation;
            }
        } else {
            action hire : ChooseHiring {
                in demandLevel = assess.assessedLevel;
                in requiredWorkers = compare.requiredWorkers;
                out hiring;
            }
        }
        then done;
    }

    action def PolicyResponseCycle {
        doc /* Policy authority response cycle: detect jobless recovery, design intervention or monitor */
        in data : EconomicData;
        in threshold : UnemploymentRate;
        out action : PolicyAction;

        first start;
        then action detect : DetectJoblessRecovery {
            in data = data;
            in threshold = threshold;
            out isJobless;
        }
        then if detect.isJobless {
            action design : DesignIntervention {
                out action;
            }
        } else {
            action monitor : MonitorEconomy {
                out action;
            }
        }
        then done;
    }

    // ===== State Machine Definitions =====

    state def CorporateState {
        doc /* State machine for corporate decision-making during recovery */
        state idle {
            doc /* Waiting for demand signals */
        }
        state responding {
            doc /* Responding to recovery demand */
        }
        state evaluating {
            doc /* Evaluating hiring vs automation options */
        }
        state deciding {
            doc /* Making the final decision */
        }
        transition from idle to responding;
        transition from responding to evaluating;
        transition from evaluating to deciding;
        transition from deciding to idle;
    }

    state def LaborMarketState {
        doc /* State machine for labor market health */
        state healthy {
            doc /* Labor market healthy with low unemployment */
        }
        state stressed {
            doc /* Labor market under stress from high unemployment */
        }
        state recovering {
            doc /* Labor market recovering through policy interventions */
        }
        transition from healthy to stressed;
        transition from stressed to recovering;
        transition from recovering to healthy;
    }

    state def PolicyState {
        doc /* State machine for policy authority */
        state monitoring {
            doc /* Monitoring economic conditions */
        }
        state intervening {
            doc /* Policy authority actively intervening in economy */
        }
        transition from monitoring to intervening;
        transition from intervening to monitoring;
    }

    state def EconomyState {
        doc /* State machine for the overall economy */
        state recession {
            doc /* Economy in recession */
        }
        state recovery {
            doc /* GDP growth resumes after recession */
        }
        state joblessRecovery {
            doc /* GDP growing but unemployment remains high */
        }
        state policyResponse {
            doc /* Policy authority intervenes to address jobless recovery */
        }
        transition from recession to recovery;
        transition from recovery to joblessRecovery;
        transition from joblessRecovery to policyResponse;
        transition from policyResponse to recovery;
    }

    state def TechnologyDevelopmentState {
        doc /* State machine for technology sector development */
        state developing {
            doc /* Developing new automation technology */
        }
        state mature {
            doc /* Technology is mature and ready for deployment */
        }
        transition from developing to mature;
        transition from mature to developing;
    }

    // ===== Part Definitions =====

    part def EconomicMonitor {
        doc /* Impartial observer that collects and distributes economic data to all sectors */
        attribute observedGDP : GDP;
        attribute observedGDPRate : GDPRate;
        attribute observedUnemployment : UnemploymentRate;
        attribute observedProductivity : ProductivityIndex;

        port dataOut : EconomicDataOut;
        port laborStatusIn : LaborStatusIn;
        port productivityIn : ProductivityIn;

        action monitorCycle {
            doc /* Continuous monitoring cycle: collect data then distribute */
            first start;
            then action collect : CollectEconomicData {
                out data : EconomicData;
            }
            then action distribute : DistributeData {
                in data = collect.data;
            }
            then done;
        }
    }

    part def CorporateSector {
        doc /* Businesses that drive economic output and decide between hiring and automation */
        attribute currentOutput : OutputLevel;
        attribute currentProfit : ProfitLevel;
        attribute laborCostPerWorker : LaborCost = 50.0;
        attribute techCostPerUnit : TechnologyCost = 80.0;
        attribute baselineOutputPerWorker : OutputLevel = 10.0;

        port economicDataIn : EconomicDataIn;
        port demandIn : DemandIn;
        port productivityIn : ProductivityIn;
        port hiringOut : HiringOut;
        port automationOut : AutomationOut;
        port policyIn : PolicyIn;
        port laborStatusIn : LaborStatusIn;
        port technologyIn : TechnologyProductIn;

        action corporateCycle : CorporateDecisionCycle;
        state corporateState : CorporateState;
    }

    part def LaborMarket {
        doc /* The workforce including both employed and unemployed individuals */
        attribute totalWorkforce : WorkerCount = 50000.0;
        attribute employedWorkers : WorkerCount = 45000.0;
        attribute unemployedWorkers : WorkerCount = 5000.0;
        attribute currentUnemploymentRate : UnemploymentRate = 10.0;

        port hiringIn : HiringIn;
        port policyIn : PolicyIn;
        port statusOut : LaborStatusOut;

        action update : UpdateEmployment;
        state laborState : LaborMarketState;
    }

    part def TechnologySector {
        doc /* Develops and supplies automation and productivity-enhancing tools */
        attribute productPrice : TechnologyCost = 80.0;
        attribute productivityGain : ProductivityIndex = 15.0;

        port automationIn : AutomationIn;
        port productivityOut : ProductivityOut;
        port technologyOut : TechnologyProductOut;

        action develop : DevelopAutomation;
        state techState : TechnologyDevelopmentState;
    }

    part def PolicyAuthority {
        doc /* Government or central bank that monitors the economy and intervenes */
        attribute interventionThreshold : UnemploymentRate = 7.0;

        port economicDataIn : EconomicDataIn;
        port laborStatusIn : LaborStatusIn;
        port policyOut : PolicyOut;

        action responseCycle : PolicyResponseCycle;
        state policyState : PolicyState;
    }

    // ===== The Economy System =====

    part def Economy {
        doc /* The complete economic system simulating jobless recovery dynamics */

        part monitor : EconomicMonitor;
        part corporate : CorporateSector;
        part labor : LaborMarket;
        part technology : TechnologySector;
        part policy : PolicyAuthority;

        connect monitor.dataOut to corporate.economicDataIn;
        connect monitor.dataOut to policy.economicDataIn;
        connect corporate.hiringOut to labor.hiringIn;
        connect corporate.automationOut to technology.automationIn;
        connect technology.technologyOut to corporate.technologyIn;
        connect technology.productivityOut to corporate.productivityIn;
        connect technology.productivityOut to monitor.productivityIn;
        connect labor.statusOut to monitor.laborStatusIn;
        connect labor.statusOut to policy.laborStatusIn;
        connect policy.policyOut to labor.policyIn;
        connect policy.policyOut to corporate.policyIn;

        state economyState : EconomyState;
    }

    // ===== Requirements =====

    requirement def EconomicSimulationRequirement {
        doc /* Top-level requirement for the jobless recovery simulation */
        subject economy : Economy;
        objective {
            doc /* The system shall accurately simulate the conditions and dynamics of a jobless recovery,
                 * where GDP growth resumes but unemployment remains high due to productivity-driven growth
                 * from technology and automation rather than employment gains. */
        }
    }

    requirement def DataDistributionRequirement {
        doc /* The Economic Monitor shall distribute accurate economic data to all sectors */
        subject monitor : EconomicMonitor;
        objective {
            doc /* All sectors shall receive accurate GDP, unemployment, and productivity data
                 * to enable informed decision-making. */
        }
    }

    requirement def AutomationDecisionRequirement {
        doc /* The Corporate Sector shall compare effective technology cost against labor cost */
        subject corporate : CorporateSector;
        objective {
            doc /* When the effective cost of technology, adjusted for productivity benefits,
                 * is lower than the cost of hiring new workers, the corporate sector shall
                 * invest in automation rather than increasing employment. */
        }
    }

    requirement def JoblessRecoveryDetectionRequirement {
        doc /* The Policy Authority shall detect jobless recovery conditions */
        subject policy : PolicyAuthority;
        objective {
            doc /* When GDP growth is positive while unemployment remains above the
                 * intervention threshold, the authority shall detect a jobless recovery
                 * condition and trigger an appropriate policy response. */
        }
    }

    requirement def PolicyInterventionRequirement {
        doc /* The Policy Authority shall provide appropriate interventions for jobless recovery */
        subject policy : PolicyAuthority;
        objective {
            doc /* Interventions shall include fiscal stimulus to boost demand,
                 * infrastructure investment to create direct employment,
                 * and workforce retraining funding to re-skill workers for
                 * a more automated economy. */
        }
    }

    requirement def LaborMarketResponsivenessRequirement {
        doc /* The Labor Market shall reflect the impact of hiring decisions and policy interventions */
        subject labor : LaborMarket;
        objective {
            doc /* The labor market unemployment rate shall decrease in response to
                 * effective hiring from the corporate sector and retraining programs
                 * funded by policy interventions. */
        }
    }

    // ===== Requirement Usages =====

    requirement economicSimReq : EconomicSimulationRequirement {
        subject economy : Economy;
    }
    requirement dataDistReq : DataDistributionRequirement {
        subject monitor : EconomicMonitor;
    }
    requirement autoDecisionReq : AutomationDecisionRequirement {
        subject corporate : CorporateSector;
    }
    requirement detectionReq : JoblessRecoveryDetectionRequirement {
        subject policy : PolicyAuthority;
    }
    requirement interventionReq : PolicyInterventionRequirement {
        subject policy : PolicyAuthority;
    }
    requirement laborRespReq : LaborMarketResponsivenessRequirement {
        subject labor : LaborMarket;
    }

    // ===== Satisfaction =====

    satisfy economicSimReq by Economy;
    satisfy dataDistReq by EconomicMonitor;
    satisfy autoDecisionReq by CorporateSector;
    satisfy detectionReq by PolicyAuthority;
    satisfy interventionReq by PolicyAuthority;
    satisfy laborRespReq by LaborMarket;

    // ===== Constraints =====

    assert constraint joblessRecoveryDefinition {
        doc /* A jobless recovery is defined as positive GDP growth (gdpGrowthRate > 0)
             * with unemployment remaining above the pre-recession level.
             * Growth is driven by productivity gains from technology and automation
             * rather than by employment gains. */
    }

    assert constraint productivityDrivenGrowth {
        doc /* In a jobless recovery, GDP growth is driven by productivity gains
             * from technology and automation rather than by employment gains.
             * The corporate sector chooses automation when effective technology cost
             * is lower than effective labor cost. */
    }
}
