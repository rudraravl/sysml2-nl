package 'Jobless Recovery Economic System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def GDPGrowthRate :> Real;
	attribute def UnemploymentRate :> Real;
	attribute def ProductivityIndex :> Real;
	attribute def WageLevel :> Real;
	attribute def CorporateProfitMargin :> Real;
	attribute def AutomationLevel :> Real;
	
	item def EconomicIndicators {
		attribute gdpGrowth : GDPGrowthRate;
		attribute unemployment : UnemploymentRate;
		attribute productivity : ProductivityIndex;
		attribute averageWage : WageLevel;
		attribute corporateProfits : CorporateProfitMargin;
		attribute automation : AutomationLevel;
	}
	
	item def PolicyDecision {
		attribute fiscalStimulus : Real;
		attribute monetaryEasing : Real;
		attribute workforceRetraining : Real;
		attribute infrastructureInvestment : Real;
	}
	
	item def MarketSignal {
		attribute consumerDemand : Real;
		attribute investmentDemand : Real;
		attribute laborCost : Real;
		attribute technologyCost : Real;
	}
	
	port def IndicatorPort {
		out indicators : EconomicIndicators;
	}
	
	port def PolicyPort {
		in policy : PolicyDecision;
	}
	
	port def MarketPort {
		out signal : MarketSignal;
		in response : MarketSignal;
	}
	
	part def EconomicMonitor {
		port indicatorOut : IndicatorPort;
		
		attribute currentGDP : GDPGrowthRate;
		attribute currentUnemployment : UnemploymentRate;
		attribute currentProductivity : ProductivityIndex;
	}
	
	part def CorporateSector {
		port marketOut : MarketPort;
		port policyIn : PolicyPort;
		port indicatorIn : IndicatorPort;
		
		attribute profitability : CorporateProfitMargin;
		attribute automationInvestment : AutomationLevel;
		attribute workforce : Real;
	}
	
	part def LaborMarket {
		port marketOut : MarketPort;
		port indicatorIn : IndicatorPort;
		
		attribute availableWorkers : Real;
		attribute employedWorkers : Real;
		attribute skillMismatch : Real;
	}
	
	part def PolicyAuthority {
		port indicatorIn : IndicatorPort;
		port policyOut : PolicyPort;
		
		attribute interventionLevel : Real;
	}
	
	part def TechnologySector {
		port marketOut : MarketPort;
		
		attribute automationCapability : AutomationLevel;
		attribute costEfficiency : Real;
	}
	
	action def AssessEconomicConditions {
		in gdpGrowth : GDPGrowthRate;
		in unemployment : UnemploymentRate;
		in productivity : ProductivityIndex;
		out isJoblessRecovery : Boolean;
		out recoveryPhase : Real;
	}
	
	action def EvaluateInvestmentOptions {
		in laborCost : Real;
		in technologyCost : Real;
		in currentProductivity : ProductivityIndex;
		in demandLevel : Real;
		out automationDecision : Boolean;
		out hiringDecision : Real;
	}
	
	action def CalculateProductivityGain {
		in automationLevel : AutomationLevel;
		in workforce : Real;
		in baseProductivity : ProductivityIndex;
		out newProductivity : ProductivityIndex;
		out outputLevel : Real;
	}
	
	action def DetermineEmploymentNeed {
		in outputTarget : Real;
		in productivity : ProductivityIndex;
		in automationLevel : AutomationLevel;
		out employmentRequired : Real;
		out employmentGap : Real;
	}
	
	action def FormulatePolicy {
		in isJoblessRecovery : Boolean;
		in unemployment : UnemploymentRate;
		in gdpGrowth : GDPGrowthRate;
		out policyMeasures : PolicyDecision;
	}
	
	action def JoblessRecoveryDynamics {
		first start;
		then merge economicCycle;
		
		then action assess : AssessEconomicConditions {
			in gdpGrowth;
			in unemployment;
			in productivity;
			out isJoblessRecovery;
			out recoveryPhase;
		}
		
		then decide;
			if assess.isJoblessRecovery and assess.recoveryPhase > 0.0 then productivityPath;
			if not assess.isJoblessRecovery then traditionalPath;
		
		action productivityPath {
			first action evaluateInvestment : EvaluateInvestmentOptions {
				in laborCost;
				in technologyCost;
				in currentProductivity;
				in demandLevel;
				out automationDecision;
				out hiringDecision;
			}
			
			then decide;
				if evaluateInvestment.automationDecision then automateProduction;
				if not evaluateInvestment.automationDecision then increaseHiring;
			
			action automateProduction {
				first action calculateGains : CalculateProductivityGain {
					in automationLevel;
					in workforce;
					in baseProductivity;
					out newProductivity;
					out outputLevel;
				}
				
				then action determineNeeds : DetermineEmploymentNeed {
					in outputTarget = calculateGains.outputLevel;
					in productivity = calculateGains.newProductivity;
					in automationLevel;
					out employmentRequired;
					out employmentGap;
				}
			}
			
			action increaseHiring {
				action hireWorkers;
			}
			
			then action formulateResponse : FormulatePolicy {
				in isJoblessRecovery = assess.isJoblessRecovery;
				in unemployment;
				in gdpGrowth;
				out policyMeasures;
			}
		}
		then economicCycle;
		
		action traditionalPath {
			action standardRecovery;
		}
		then economicCycle;
	}
	
	state def EconomicRecoveryState {
		entry; then recession;
		
		state recession {
			entry assign gdpGrowthRate = -2.0;
			entry assign unemploymentRate = 10.0;
			entry assign productivityIndex = 1.0;
			entry assign corporateOutput = 70.0;
		}
		then stimulusPhase
			if policyIntervention > 0.5;
		
		state stimulusPhase {
			entry assign gdpGrowthRate = 0.5;
			entry assign corporateOutput = 75.0;
			entry assign demandRecovery = 1.2;
		}
		then earlyRecovery
			if gdpGrowthRate > 0.0;
		
		state earlyRecovery {
			entry assign gdpGrowthRate = 2.0;
			entry assign corporateOutput = 85.0;
			entry assign automationInvestment = 1.5;
		}
		then joblessRecovery
			if gdpGrowthRate > 1.5 and unemploymentRate > 8.0 and productivityIndex > 1.15;
		then normalRecovery
			if gdpGrowthRate > 1.5 and unemploymentRate < 7.0;
		
		state joblessRecovery {
			entry assign gdpGrowthRate = 3.0;
			entry assign unemploymentRate = 9.5;
			entry assign productivityIndex = 1.3;
			entry assign corporateOutput = 95.0;
			entry assign corporateProfits = 1.4;
			entry assign automationLevel = 1.8;
		}
		then sustainedJoblessGrowth
			if gdpGrowthRate > 2.5 and unemploymentRate > 8.0;
		then employmentRecovery
			if retrainingPrograms > 1.0 and unemploymentRate < 8.0;
		
		state sustainedJoblessGrowth {
			entry assign gdpGrowthRate = 3.5;
			entry assign unemploymentRate = 9.0;
			entry assign productivityIndex = 1.5;
			entry assign corporateOutput = 105.0;
			entry assign wageStagnation = 1.0;
		}
		then employmentRecovery
			if policyIntervention > 1.5;
		
		state normalRecovery {
			entry assign gdpGrowthRate = 2.5;
			entry assign unemploymentRate = 6.5;
			entry assign corporateOutput = 95.0;
		}
		then fullRecovery
			if gdpGrowthRate > 2.0 and unemploymentRate < 6.0;
		
		state employmentRecovery {
			entry assign gdpGrowthRate = 3.0;
			entry assign unemploymentRate = 7.0;
			entry assign productivityIndex = 1.4;
			entry assign corporateOutput = 100.0;
		}
		then fullRecovery
			if unemploymentRate < 6.0;
		
		state fullRecovery {
			entry assign gdpGrowthRate = 2.5;
			entry assign unemploymentRate = 5.0;
			entry assign corporateOutput = 110.0;
			entry assign productivityIndex = 1.6;
		}
		
		attribute gdpGrowthRate : Real;
		attribute unemploymentRate : Real;
		attribute productivityIndex : Real;
		attribute corporateOutput : Real;
		attribute corporateProfits : Real;
		attribute automationLevel : Real;
		attribute demandRecovery : Real;
		attribute automationInvestment : Real;
		attribute wageStagnation : Real;
		attribute policyIntervention : Real;
		attribute retrainingPrograms : Real;
	}
	
	part joblessRecoverySystem {
		doc /* 
		Primary Function: Model an economic system experiencing jobless recovery, where GDP growth 
		resumes after recession through productivity gains and automation rather than employment expansion.
		The system demonstrates how corporate investment in technology and automation can drive economic 
		output while unemployment remains elevated, creating a recovery that benefits capital more than labor.
		*/
		
		attribute systemState : EconomicRecoveryState;
		
		part monitor : EconomicMonitor {
			port indicatorOut;
		}
		
		part corporations : CorporateSector {
			port marketOut;
			port policyIn;
			port indicatorIn;
		}
		
		part labor : LaborMarket {
			port marketOut;
			port indicatorIn;
		}
		
		part policyMaker : PolicyAuthority {
			port indicatorIn;
			port policyOut;
		}
		
		part technology : TechnologySector {
			port marketOut;
		}
		
		connect monitor.indicatorOut to corporations.indicatorIn;
		connect monitor.indicatorOut to labor.indicatorIn;
		connect monitor.indicatorOut to policyMaker.indicatorIn;
		connect policyMaker.policyOut to corporations.policyIn;
		connect corporations.marketOut to technology.marketOut;
		connect corporations.marketOut to labor.marketOut;
		
		perform action recoveryDynamics : JoblessRecoveryDynamics;
	}
	
	requirement def JoblessRecoveryRequirement {
		doc /* 
		The system shall model economic recovery dynamics characterized by GDP growth 
		occurring simultaneously with persistently high unemployment due to productivity 
		improvements from automation and technology adoption rather than workforce expansion.
		*/
		
		require constraint productivityDrivenGrowth {
			doc /* 
			Economic output growth shall be primarily driven by productivity gains 
			(measured as output per worker) rather than employment increases during 
			the jobless recovery phase.
			*/
		}
		
		require constraint employmentLag {
			doc /* 
			Employment levels shall remain at least 3 percentage points above pre-recession 
			levels while GDP returns to or exceeds pre-recession levels during jobless recovery.
			*/
		}
		
		require constraint automationIncentive {
			doc /* 
			Corporate sector investment decisions shall favor automation when technology costs 
			adjusted for productivity gains are lower than equivalent labor costs.
			*/
		}
	}
	
	requirement def MonitoringRequirement {
		doc /* 
		The system shall continuously monitor and assess economic indicators to detect 
		and characterize jobless recovery patterns distinct from traditional recoveries.
		*/
		
		require constraint indicatorTracking {
			doc /* 
			GDP growth rate, unemployment rate, productivity index, and automation levels 
			shall be monitored and updated at regular intervals throughout the economic cycle.
			*/
		}
		
		require constraint recoveryDetection {
			doc /* 
			The system shall identify jobless recovery conditions when GDP growth exceeds 1.5% 
			while unemployment remains above 8% and productivity growth exceeds 15%.
			*/
		}
	}
	
	requirement def PolicyResponseRequirement {
		doc /* 
		The system shall generate appropriate policy interventions when jobless recovery 
		conditions persist, addressing both output sustainability and employment creation.
		*/
		
		require constraint adaptiveIntervention {
			doc /* 
			Policy measures shall include workforce retraining programs, infrastructure investment, 
			and targeted fiscal stimulus when jobless recovery conditions are detected.
			*/
		}
		
		require constraint balancedApproach {
			doc /* 
			Policy responses shall balance support for productivity-driven growth with measures 
			to reduce structural unemployment and skill mismatches.
			*/
		}
	}
	
	requirement systemRequirements {
		subject joblessRecoverySystem;
		
		require joblessRecoveryReq : JoblessRecoveryRequirement;
		require monitoringReq : MonitoringRequirement;
		require policyReq : PolicyResponseRequirement;
		
		assume constraint economicCycles {
			doc /* 
			The economy experiences cyclical patterns of recession and recovery driven by 
			demand fluctuations, investment cycles, and technological change.
			*/
		}
		
		assume constraint technologyAvailability {
			doc /* 
			Automation and productivity-enhancing technologies are available and economically 
			viable alternatives to labor expansion for meeting increased output demand.
			*/
		}
		
		assume constraint corporateRationality {
			doc /* 
			Corporate sector makes investment decisions based on cost-benefit analysis comparing 
			labor costs to technology costs adjusted for productivity impacts.
			*/
		}
	}
	
	occurrence def JoblessRecoveryInteraction {
		ref part mon :>> monitor;
		ref part corp :>> corporations;
		ref part lab :>> labor;
		ref part pol :>> policyMaker;
		ref part tech :>> technology;
		
		message indicatorsToCorporations of EconomicIndicators
			from mon.indicatorOut to corp.indicatorIn;
		then message indicatorsToLabor of EconomicIndicators
			from mon.indicatorOut to lab.indicatorIn;
		then message indicatorsToPolicy of EconomicIndicators
			from mon.indicatorOut to pol.indicatorIn;
		then message marketSignalToTech of MarketSignal
			from corp.marketOut to tech.marketOut;
		then message policyDecision of PolicyDecision
			from pol.policyOut to corp.policyIn;
	}
}
