package JoblessRecoveryEconomicSystem {

    import ScalarValues::*;

    package Units {
        value def USD :> Real;
        value def Percent :> Real;
        value def Persons :> Real;
        value def Quarters :> Real;
        value def USDPerPerson :> Real;
        value def USDPerUnit :> Real;
        value def IndexPoints :> Real;
    }

    package ValueTypes {
        value def GDP :> Units::USD;
        value def GDPGrowthRate :> Units::Percent;
        value def UnemploymentRate :> Units::Percent;
        value def EmploymentLevel :> Units::Persons;
        value def UnemploymentLevel :> Units::Persons;
        value def LaborForceSize :> Units::Persons;
        value def AverageWage :> Units::USDPerPerson;
        value def TechnologyUnitCost :> Units::USDPerUnit;
        value def ProductivityIndex :> Units::IndexPoints;
        value def CorporateProfit :> Units::USD;
        value def AggregateDemand :> Units::USD;
        value def FiscalStimulusAmount :> Units::USD;
        value def InfrastructureBudget :> Units::USD;
        value def RetrainingSlots :> Units::Persons;
        value def InterestRatePct :> Units::Percent;
        value def AutomationInvestment :> Units::USD;
        value def HiringRate :> Units::Persons;
        value def OutputLevel :> Units::USD;
        value def ProductivityGain :> Units::IndexPoints;
        value def CostRatio :> Real;
    }

    package Signals {
        item def EconomicIndicators {
            attribute gdp : GDP;
            attribute gdpGrowthRate : GDPGrowthRate;
            attribute unemploymentRate : UnemploymentRate;
            attribute productivityIndex : ProductivityIndex;
            attribute aggregateDemand : AggregateDemand;
        }

        item def HiringDirective {
            attribute newHires : HiringRate;
            attribute averageWage : AverageWage;
            attribute targetSector : String;
        }

        item def AutomationDirective {
            attribute investment : AutomationInvestment;
            attribute productivityGain : ProductivityGain;
            attribute unitsDeployed : Real;
        }

        item def PolicyPackage {
            attribute stimulus : FiscalStimulusAmount;
            attribute infrastructure : InfrastructureBudget;
            attribute retrainingSlots : RetrainingSlots;
            attribute interestRate : InterestRatePct;
            attribute justification : String;
        }

        item def LaborSupplyUpdate {
            attribute availableWorkers : UnemploymentLevel;
            attribute retrainedWorkers : Units::Persons;
            attribute laborForce : LaborForceSize;
        }

        item def TechnologyOffer {
            attribute unitCost : TechnologyUnitCost;
            attribute productivityMultiplier : ProductivityIndex;
            attribute availableUnits : Real;
        }

        item def RecessionSignal {
            attribute severity : Real;
        }

        item def RecoverySignal {
            attribute initialGrowth : GDPGrowthRate;
        }

        item def JoblessRecoveryAlarm {
            attribute unemploymentRate : UnemploymentRate;
            attribute gdpGrowthRate : GDPGrowthRate;
            attribute detectedQuarter : Integer;
        }
    }

    package Ports {
        port def EconomicDataOut {
            out indicators : Signals::EconomicIndicators;
        }
        port def EconomicDataIn {
            in indicators : Signals::EconomicIndicators;
        }
        port def HiringOut {
            out hiring : Signals::HiringDirective;
        }
        port def HiringIn {
            in hiring : Signals::HiringDirective;
        }
        port def AutomationOut {
            out automation : Signals::AutomationDirective;
        }
        port def AutomationIn {
            in automation : Signals::AutomationDirective;
        }
        port def TechSupplyOut {
            out offer : Signals::TechnologyOffer;
        }
        port def TechSupplyIn {
            in offer : Signals::TechnologyOffer;
        }
        port def PolicyOut {
            out policy : Signals::PolicyPackage;
        }
        port def PolicyIn {
            in policy : Signals::PolicyPackage;
        }
        port def LaborSupplyOut {
            out labor : Signals::LaborSupplyUpdate;
        }
        port def LaborSupplyIn {
            in labor : Signals::LaborSupplyUpdate;
        }
        port def CycleTriggerOut {
            out recession : Signals::RecessionSignal;
            out recovery : Signals::RecoverySignal;
        }
        port def CycleTriggerIn {
            in recession : Signals::RecessionSignal;
            in recovery : Signals::RecoverySignal;
        }
        port def AlarmOut {
            out alarm : Signals::JoblessRecoveryAlarm;
        }
        port def AlarmIn {
            in alarm : Signals::JoblessRecoveryAlarm;
        }
    }

    package Actions {
        action def ComputeEconomicIndicators {
            in prevGDP : GDP;
            in currentGDP : GDP;
            in employed : EmploymentLevel;
            in laborForce : LaborForceSize;
            in productivity : ProductivityIndex;
            in demand : AggregateDemand;
            out indicators : Signals::EconomicIndicators;
        }

        action def EvaluateAutomationVsHiring {
            in laborUnitCost : AverageWage;
            in techUnitCost : TechnologyUnitCost;
            in productivityBenefit : ProductivityIndex;
            in demandGrowth : GDPGrowthRate;
            out chooseAutomation : Boolean;
            out automationDirective : Signals::AutomationDirective;
            out hiringDirective : Signals::HiringDirective;
        }

        action def DetermineJoblessRecovery {
            in gdpGrowth : GDPGrowthRate;
            in unemployment : UnemploymentRate;
            in baseline : UnemploymentRate;
            out isJobless : Boolean;
            out alarm : Signals::JoblessRecoveryAlarm;
        }

        action def FormulatePolicyResponse {
            in unemployment : UnemploymentRate;
            in gdpGrowth : GDPGrowthRate;
            in availableFunds : FiscalStimulusAmount;
            in skillGap : Units::Persons;
            out policy : Signals::PolicyPackage;
        }

        action def UpdateLaborMarketState {
            in hiring : Signals::HiringDirective;
            in retrained : RetrainingSlots;
            in policy : Signals::PolicyPackage;
            in laborForce : LaborForceSize;
            out laborSupply : Signals::LaborSupplyUpdate;
            out newUnemployment : UnemploymentRate;
        }

        action def DevelopNewTechnology {
            in investment : AutomationInvestment;
            out offer : Signals::TechnologyOffer;
        }

        action def ComputeProductivityGain {
            in automation : Signals::AutomationDirective;
            out productivity : ProductivityIndex;
        }

        action def ComputeCostRatio {
            in laborUnitCost : AverageWage;
            in techUnitCost : TechnologyUnitCost;
            in productivityMultiplier : ProductivityIndex;
            out ratio : CostRatio;
        }
    }

    package Requirements {
        requirement def EconomicGrowthRequirement {
            doc The economy shall exhibit positive GDP growth following the end of a recession to demonstrate that recovery is underway.
            subject system;
            attribute minGrowthThreshold : GDPGrowthRate := 0.5;
            objective {
                doc GDP growth rate shall remain above the minimum growth threshold for two consecutive quarters following the end of a recession.
            }
        }

        requirement def JoblessRecoveryCondition {
            doc The system shall recognize a jobless recovery when GDP grows while unemployment remains elevated above the natural baseline.
            subject system;
            attribute gdpGrowthThreshold : GDPGrowthRate := 1.0;
            attribute maxAcceptableUnemployment : UnemploymentRate := 5.0;
            objective {
                doc The system shall flag a jobless recovery when GDP growth exceeds the growth threshold and the unemployment rate remains above the acceptable level for one full quarter.
            }
        }

        requirement def AutomationDecisionRequirement {
            doc The corporate sector shall choose automation over hiring whenever the productivity-adjusted cost of technology is lower than the cost of new labor.
            subject corporateSector;
            objective {
                doc Automation shall be selected when the effective per-unit labor cost exceeds the productivity-adjusted per-unit technology cost.
            }
        }

        requirement def PolicyInterventionRequirement {
            doc The policy authority shall respond to detected jobless recoveries with at least one targeted intervention.
            subject policyAuthority;
            attribute maxResponseLatency : Units::Quarters := 1.0;
            objective {
                doc At least one of fiscal stimulus, infrastructure investment, or workforce retraining shall be deployed within one quarter of detection.
            }
        }

        requirement def MonitorDataDistribution {
            doc The economic monitor shall broadcast current economic indicators to all other sectors every simulation cycle.
            subject economicMonitor;
            objective {
                doc GDP, unemployment rate, productivity index, and aggregate demand shall be distributed to corporate, labor, technology, and policy sectors each simulated quarter.
            }
        }

        requirement def ProductivityDrivenGrowth {
            doc During a jobless recovery, GDP growth shall be driven primarily by total factor productivity gains enabled by technology rather than by additional hiring.
            subject system;
            attribute productivityShareThreshold : Real := 0.6;
            objective {
                doc The contribution of productivity to GDP growth shall exceed the contribution of new hiring during any quarter classified as a jobless recovery.
            }
        }

        requirement def LaborMarketResilience {
            doc The labor market shall update its unemployment and retraining metrics promptly in response to hiring and policy signals.
            subject laborMarket;
            objective {
                doc The labor market shall refresh its unemployment rate and available worker counts each time a hiring or retraining directive is received.
            }
        }

        requirement def TechnologySectorAvailability {
            doc The technology sector shall supply productivity-enhancing tools whose cost and productivity parameters reflect current corporate demand.
            subject technologySector;
            objective {
                doc Technology offers shall be made available whenever corporate investment is non-zero, with unit costs decreasing as cumulative deployment scales.
            }
        }

        requirement economicGrowthReq : EconomicGrowthRequirement;
        requirement joblessConditionReq : JoblessRecoveryCondition;
        requirement automationRuleReq : AutomationDecisionRequirement;
        requirement policyInterventionReq : PolicyInterventionRequirement;
        requirement monitorDistributionReq : MonitorDataDistribution;
        requirement productivityGrowthReq : ProductivityDrivenGrowth;
        requirement laborResilienceReq : LaborMarketResilience;
        requirement techAvailabilityReq : TechnologySectorAvailability;
    }

    package Sectors {

        part def CorporateSector {
            port econIn : Ports::EconomicDataIn;
            port techIn : Ports::TechSupplyIn;
            port laborIn : Ports::LaborSupplyIn;
            port policyIn : Ports::PolicyIn;
            port cycleIn : Ports::CycleTriggerIn;
            port hiringOut : Ports::HiringOut;
            port automationOut : Ports::AutomationOut;
            port alarmOut : Ports::AlarmOut;

            attribute currentOutput : OutputLevel := 1000000000.0;
            attribute currentProfit : CorporateProfit := 50000000.0;
            attribute unitLaborCost : AverageWage := 60000.0;
            attribute unitTechCost : TechnologyUnitCost := 25000.0;
            attribute productivityBaseline : ProductivityIndex := 100.0;
            attribute demandElasticity : Real := 1.2;
            attribute recentIndicators : Signals::EconomicIndicators;
            attribute latestTechOffer : Signals::TechnologyOffer;
            attribute latestLabor : Signals::LaborSupplyUpdate;
            attribute latestPolicy : Signals::PolicyPackage;
            attribute alarmSignal : Signals::JoblessRecoveryAlarm;
            attribute chooseAutomation : Boolean := false;
            attribute cycleActive : Boolean := false;
            attribute effectiveLaborCost : CostRatio := 72000.0;
            attribute effectiveTechCost : CostRatio := 62500.0;

            state machine corporateDynamics {
                state Idle;
                state AssessingDemand {
                    entry / {
                        recentIndicators := econIn.indicators;
                        latestTechOffer := techIn.offer;
                        latestLabor := laborIn.labor;
                    }
                }
                state ComparingCosts {
                    entry / {
                        effectiveLaborCost := unitLaborCost * demandElasticity;
                        effectiveTechCost := unitTechCost * latestTechOffer.productivityMultiplier;
                    }
                }
                state Hiring {
                    entry / {
                        hiringOut.hiring.newHires := 50000;
                        hiringOut.hiring.averageWage := unitLaborCost;
                        hiringOut.hiring.targetSector := "production";
                        chooseAutomation := false;
                    }
                }
                state Automating {
                    entry / {
                        automationOut.automation.investment := 2500000000.0;
                        automationOut.automation.productivityGain := 8.0;
                        automationOut.automation.unitsDeployed := 1000000.0;
                        chooseAutomation := true;
                    }
                }
                state JoblessRecoveryDetected {
                    entry / {
                        alarmOut.alarm.unemploymentRate := latestLabor.availableWorkers / latestLabor.laborForce;
                        alarmOut.alarm.gdpGrowthRate := recentIndicators.gdpGrowthRate;
                        alarmOut.alarm.detectedQuarter := 1;
                    }
                }
                state PolicyAdjusted {
                    entry / {
                        latestPolicy := policyIn.policy;
                    }
                }

                transition from Idle to AssessingDemand when cycleActive == true;
                transition from AssessingDemand to ComparingCosts when latestTechOffer.availableUnits > 0;
                transition from ComparingCosts to Hiring when effectiveLaborCost < effectiveTechCost;
                transition from ComparingCosts to Automating when effectiveLaborCost >= effectiveTechCost;
                transition from Hiring to Idle when recentIndicators.unemploymentRate < 0.05;
                transition from Automating to JoblessRecoveryDetected when latestLabor.availableWorkers > latestLabor.laborForce * 0.06;
                transition from JoblessRecoveryDetected to PolicyAdjusted when latestPolicy.retrainingSlots > 0;
                transition from PolicyAdjusted to Idle when recentIndicators.unemploymentRate < 0.05;
            }

            satisfies Requirements::automationRuleReq;
        }

        part def LaborMarket {
            port econIn : Ports::EconomicDataIn;
            port hiringIn : Ports::HiringIn;
            port policyIn : Ports::PolicyIn;
            port laborOut : Ports::LaborSupplyOut;

            attribute laborForce : LaborForceSize := 160000000.0;
            attribute employed : EmploymentLevel := 152000000.0;
            attribute unemployed : UnemploymentLevel := 8000000.0;
            attribute retrained : Units::Persons := 0;
            attribute currentUnemploymentRate : UnemploymentRate := 0.05;
            attribute incomingHiring : Signals::HiringDirective;
            attribute incomingPolicy : Signals::PolicyPackage;
            attribute currentIndicators : Signals::EconomicIndicators;
            attribute hiringReceived : Boolean := false;
            attribute policyReceived : Boolean := false;

            state machine laborDynamics {
                state Idle;
                state ReceivingHiring {
                    entry / {
                        incomingHiring := hiringIn.hiring;
                        employed := employed + incomingHiring.newHires;
                        if unemployed > 0 {
                            unemployed := laborForce - employed;
                        }
                        currentUnemploymentRate := unemployed / laborForce;
                        hiringReceived := true;
                    }
                }
                state ReceivingPolicy {
                    entry / {
                        incomingPolicy := policyIn.policy;
                        retrained := retrained + incomingPolicy.retrainingSlots;
                        employed := employed + incomingPolicy.retrainingSlots * 0.5;
                        unemployed := laborForce - employed;
                        currentUnemploymentRate := unemployed / laborForce;
                        policyReceived := true;
                    }
                }
                state UpdatingSupply {
                    entry / {
                        laborOut.labor.availableWorkers := unemployed;
                        laborOut.labor.retrainedWorkers := retrained;
                        laborOut.labor.laborForce := laborForce;
                    }
                }
                state JoblessRecovery;

                transition from Idle to ReceivingHiring when hiringIn.hiring.newHires > 0;
                transition from ReceivingHiring to UpdatingSupply when hiringReceived == true;
                transition from Idle to ReceivingPolicy when policyIn.policy.retrainingSlots > 0;
                transition from ReceivingPolicy to UpdatingSupply when policyReceived == true;
                transition from UpdatingSupply to JoblessRecovery when currentUnemploymentRate > 0.07;
                transition from UpdatingSupply to Idle when currentUnemploymentRate <= 0.07;
                transition from JoblessRecovery to ReceivingPolicy when policyIn.policy.retrainingSlots > 0;
            }

            satisfies Requirements::laborResilienceReq;
        }

        part def TechnologySector {
            port econIn : Ports::EconomicDataIn;
            port automationIn : Ports::AutomationIn;
            port policyIn : Ports::PolicyIn;
            port supplyOut : Ports::TechSupplyOut;

            attribute baseUnitCost : TechnologyUnitCost := 25000.0;
            attribute productivityMultiplier : ProductivityIndex := 2.5;
            attribute productionCapacity : Real := 5000000.0;
            attribute currentOffer : Signals::TechnologyOffer;
            attribute currentIndicators : Signals::EconomicIndicators;
            attribute recentInvestment : AutomationInvestment := 0.0;
            attribute cumulativeDeployment : Real := 0.0;
            attribute innovationTriggered : Boolean := false;
            attribute productionTriggered : Boolean := false;

            state machine techDynamics {
                state Idle;
                state Researching {
                    entry / {
                        productivityMultiplier := productivityMultiplier + 0.1;
                        innovationTriggered := true;
                    }
                }
                state Producing {
                    entry / {
                        recentInvestment := automationIn.automation.investment;
                        currentOffer.unitCost := baseUnitCost;
                        currentOffer.productivityMultiplier := productivityMultiplier;
                        currentOffer.availableUnits := productionCapacity;
                        productionTriggered := true;
                    }
                }
                state ScalingUp {
                    entry / {
                        productionCapacity := productionCapacity + 1000000.0;
                        baseUnitCost := baseUnitCost * 0.95;
                        cumulativeDeployment := cumulativeDeployment + automationIn.automation.unitsDeployed;
                    }
                }
                state DistributingOffer {
                    entry / {
                        supplyOut.offer := currentOffer;
                    }
                }

                transition from Idle to Researching when econIn.indicators.gdpGrowthRate > 0;
                transition from Researching to Producing when automationIn.automation.investment > 0 & innovationTriggered == true;
                transition from Producing to ScalingUp when recentInvestment > 1000000000.0;
                transition from ScalingUp to DistributingOffer when currentOffer.availableUnits > 0;
                transition from DistributingOffer to Idle when supplyOut.offer.availableUnits > 0;
            }

            satisfies Requirements::techAvailabilityReq;
        }

        part def PolicyAuthority {
            port econIn : Ports::EconomicDataIn;
            port alarmIn : Ports::AlarmIn;
            port laborIn : Ports::LaborSupplyIn;
            port cycleIn : Ports::CycleTriggerIn;
            port policyOut : Ports::PolicyOut;

            attribute treasuryBalance : FiscalStimulusAmount := 50000000000.0;
            attribute infrastructureBudget : InfrastructureBudget := 20000000000.0;
            attribute retrainingCapacity : RetrainingSlots := 500000.0;
            attribute currentInterestRate : InterestRatePct := 2.5;
            attribute targetUnemployment : UnemploymentRate := 0.04;
            attribute incomingAlarm : Signals::JoblessRecoveryAlarm;
            attribute currentIndicators : Signals::EconomicIndicators;
            attribute activePolicy : Signals::PolicyPackage;
            attribute skillGap : Units::Persons := 0;
            attribute alarmReceived : Boolean := false;
            attribute policyDeployed : Boolean := false;

            state machine policyDynamics {
                state Monitoring;
                state Diagnosing {
                    entry / {
                        incomingAlarm := alarmIn.alarm;
                        currentIndicators := econIn.indicators;
                        skillGap := laborIn.labor.availableWorkers * 0.3;
                        alarmReceived := true;
                    }
                }
                state StimulusDeployed {
                    entry / {
                        activePolicy.stimulus := 30000000000.0;
                        activePolicy.infrastructure := 5000000000.0;
                        activePolicy.retrainingSlots := 100000.0;
                        activePolicy.interestRate := 1.5;
                        activePolicy.justification := "Stimulus to boost aggregate demand during weak recovery";
                        policyDeployed := true;
                    }
                }
                state InfrastructureDeployed {
                    entry / {
                        activePolicy.stimulus := 10000000000.0;
                        activePolicy.infrastructure := 25000000000.0;
                        activePolicy.retrainingSlots := 200000.0;
                        activePolicy.interestRate := 2.0;
                        activePolicy.justification := "Direct job creation through infrastructure investment";
                        policyDeployed := true;
                    }
                }
                state RetrainingDeployed {
                    entry / {
                        activePolicy.stimulus := 5000000000.0;
                        activePolicy.infrastructure := 5000000000.0;
                        activePolicy.retrainingSlots := 1000000.0;
                        activePolicy.interestRate := 2.5;
                        activePolicy.justification := "Workforce reskilling to fit a more automated economy";
                        policyDeployed := true;
                    }
                }
                state Resolved {
                    entry / {
                        policyOut.policy := activePolicy;
                    }
                }

                transition from Monitoring to Diagnosing when alarmIn.alarm.unemploymentRate > 0.05;
                transition from Diagnosing to StimulusDeployed when currentIndicators.gdpGrowthRate < 1.0 & alarmReceived == true;
                transition from Diagnosing to InfrastructureDeployed when currentIndicators.gdpGrowthRate >= 1.0 & laborIn.labor.retrainedWorkers < 1000000.0;
                transition from Diagnosing to RetrainingDeployed when currentIndicators.gdpGrowthRate >= 1.0 & laborIn.labor.retrainedWorkers >= 1000000.0;
                transition from StimulusDeployed to Resolved when currentIndicators.unemploymentRate < targetUnemployment & policyDeployed == true;
                transition from InfrastructureDeployed to Resolved when currentIndicators.unemploymentRate < targetUnemployment & policyDeployed == true;
                transition from RetrainingDeployed to Resolved when currentIndicators.unemploymentRate < targetUnemployment & policyDeployed == true;
                transition from Resolved to Monitoring when currentIndicators.unemploymentRate < targetUnemployment;
            }

            satisfies Requirements::policyInterventionReq;
        }

        part def EconomicMonitor {
            port cycleIn : Ports::CycleTriggerIn;
            port indicatorsOut : Ports::EconomicDataOut;

            attribute prevGDP : GDP := 19000000000000.0;
            attribute currentGDP : GDP := 19200000000000.0;
            attribute employed : EmploymentLevel := 152000000.0;
            attribute laborForce : LaborForceSize := 160000000.0;
            attribute productivityIndex : ProductivityIndex := 100.0;
            attribute demandLevel : AggregateDemand := 18000000000000.0;
            attribute publishedIndicators : Signals::EconomicIndicators;
            attribute cycleCounter : Integer := 0;
            attribute collectingDone : Boolean := false;
            attribute computingDone : Boolean := false;
            attribute distributingDone : Boolean := false;

            state machine monitorDynamics {
                state Idle;
                state Collecting {
                    entry / {
                        employed := 152000000.0;
                        laborForce := 160000000.0;
                        productivityIndex := productivityIndex + 1.5;
                        cycleCounter := cycleCounter + 1;
                        collectingDone := true;
                    }
                }
                state Computing {
                    entry / {
                        publishedIndicators.gdp := currentGDP;
                        publishedIndicators.gdpGrowthRate := (currentGDP - prevGDP) / prevGDP * 100.0;
                        publishedIndicators.unemploymentRate := (laborForce - employed) / laborForce * 100.0;
                        publishedIndicators.productivityIndex := productivityIndex;
                        publishedIndicators.aggregateDemand := demandLevel;
                        computingDone := true;
                    }
                }
                state Distributing {
                    entry / {
                        indicatorsOut.indicators := publishedIndicators;
                        prevGDP := currentGDP;
                        distributingDone := true;
                    }
                }

                transition from Idle to Collecting when cycleIn.recovery.initialGrowth > 0;
                transition from Collecting to Computing when collectingDone == true;
                transition from Computing to Distributing when computingDone == true;
                transition from Distributing to Idle when distributingDone == true;
            }

            satisfies Requirements::monitorDistributionReq;
        }

        part def RecessionEngine {
            port cycleOut : Ports::CycleTriggerOut;

            attribute recessionTriggered : Boolean := true;
            attribute recoveryTriggered : Boolean := false;
            attribute recessionDuration : Units::Quarters := 2.0;
            attribute recoveryDuration : Units::Quarters := 1.0;
            attribute activeRecession : Signals::RecessionSignal;
            attribute activeRecovery : Signals::RecoverySignal;
            attribute recessionSent : Boolean := false;
            attribute recoverySent : Boolean := false;

            state machine engineDynamics {
                state Initial;
                state RecessionActive {
                    entry / {
                        cycleOut.recession := activeRecession;
                        recessionSent := true;
                    }
                }
                state RecoveryActive {
                    entry / {
                        cycleOut.recovery := activeRecovery;
                        recoverySent := true;
                    }
                }

                transition from Initial to RecessionActive when recessionTriggered == true;
                transition from RecessionActive to RecoveryActive when recessionSent == true;
                transition from RecoveryActive to Initial when recoverySent == true;
            }
        }
    }

    part def EconomySystem {
        part corporate : Sectors::CorporateSector;
        part labor : Sectors::LaborMarket;
        part technology : Sectors::TechnologySector;
        part policy : Sectors::PolicyAuthority;
        part monitor : Sectors::EconomicMonitor;
        part engine : Sectors::RecessionEngine;

        connection monitorToCorporate connect monitor.indicatorsOut to corporate.econIn;
        connection monitorToLabor connect monitor.indicatorsOut to labor.econIn;
        connection monitorToTechnology connect monitor.indicatorsOut to technology.econIn;
        connection monitorToPolicy connect monitor.indicatorsOut to policy.econIn;

        connection corporateHiringToLabor connect corporate.hiringOut to labor.hiringIn;
        connection corporateAutomationToTechnology connect corporate.automationOut to technology.automationIn;
        connection corporateAlarmToPolicy connect corporate.alarmOut to policy.alarmIn;

        connection technologySupplyToCorporate connect technology.supplyOut to corporate.techIn;
        connection laborSupplyToCorporate connect labor.laborOut to corporate.laborIn;
        connection laborSupplyToPolicy connect labor.laborOut to policy.laborIn;
        connection policyToLabor connect policy.policyOut to labor.policyIn;
        connection policyToCorporate connect policy.policyOut to corporate.policyIn;

        connection engineToCorporate connect engine.cycleOut to corporate.cycleIn;
        connection engineToPolicy connect engine.cycleOut to policy.cycleIn;
        connection engineToMonitor connect engine.cycleOut to monitor.cycleIn;
    }

    part economy : EconomySystem {
        satisfies Requirements::economicGrowthReq;
        satisfies Requirements::joblessConditionReq;
        satisfies Requirements::productivityGrowthReq;
    }
}
