package PostWorkSocietyModel {
	private import ScalarValues::*;

	attribute def CurrencyAmount :> Real {
		attribute unitSymbol : String = "CCr";
	}

	attribute def MonthlyCurrencyRate :> Real {
		attribute unitSymbol : String = "CCr/month";
	}

	attribute def PersonCount :> Integer {
		attribute unitSymbol : String = "persons";
	}

	attribute def HoursPerWeek :> Real {
		attribute unitSymbol : String = "h/week";
	}

	attribute def EnergyAmount :> Real {
		attribute unitSymbol : String = "MWh";
	}

	attribute def EnergyRate :> Real {
		attribute unitSymbol : String = "MWh/month";
	}

	attribute def MaterialMass :> Real {
		attribute unitSymbol : String = "tonne";
	}

	attribute def MaterialRate :> Real {
		attribute unitSymbol : String = "tonne/month";
	}

	attribute def CarbonRate :> Real {
		attribute unitSymbol : String = "tCO2e/year";
	}

	attribute def WellbeingIndex :> Real {
		attribute unitSymbol : String = "index_0_to_100";
	}

	attribute def Availability :> Real {
		attribute unitSymbol : String = "percent";
	}

	attribute def ParticipationRate :> Real {
		attribute unitSymbol : String = "percent";
	}

	attribute def AutomationCapacity :> Real {
		attribute unitSymbol : String = "human-equivalent-hours/month";
	}

	attribute def ServiceLatency :> Real {
		attribute unitSymbol : String = "days";
	}

	attribute def PrivacyRiskScore :> Real {
		attribute unitSymbol : String = "index_0_to_1";
	}

	item def BasicIncomeCredit {
		attribute amount : CurrencyAmount;
		attribute periodicRate : MonthlyCurrencyRate;
		attribute recipientCount : PersonCount;
		attribute unconditional : Boolean;
	}

	item def ServiceEntitlement {
		attribute housingCoverage : Boolean;
		attribute healthcareCoverage : Boolean;
		attribute learningCoverage : Boolean;
		attribute mobilityCoverage : Boolean;
		attribute nutritionCoverage : Boolean;
		attribute monthlyPublicValue : MonthlyCurrencyRate;
	}

	item def NeedsPortfolio {
		attribute personsRepresented : PersonCount;
		attribute essentialServiceDemand : MonthlyCurrencyRate;
		attribute careHoursDemand : HoursPerWeek;
		attribute energyDemand : EnergyRate;
		attribute materialDemand : MaterialRate;
	}

	item def WellbeingReport {
		attribute reportedPopulation : PersonCount;
		attribute livelihoodSecurity : WellbeingIndex;
		attribute autonomy : WellbeingIndex;
		attribute socialConnection : WellbeingIndex;
		attribute careSufficiency : WellbeingIndex;
		attribute ecologicalConfidence : WellbeingIndex;
		attribute privacyRisk : PrivacyRiskScore;
	}

	item def CivicContribution {
		attribute contributorCount : PersonCount;
		attribute voluntaryHours : HoursPerWeek;
		attribute careHours : HoursPerWeek;
		attribute learningHours : HoursPerWeek;
		attribute commonsStewardshipHours : HoursPerWeek;
		attribute compensated : Boolean;
	}

	item def AutomationWorkPackage {
		attribute productionCapacity : AutomationCapacity;
		attribute energyRequired : EnergyAmount;
		attribute materialRequired : MaterialMass;
		attribute expectedHumanOversight : HoursPerWeek;
		attribute essentialServicePriority : Boolean;
	}

	item def CommonsResource {
		attribute renewableEnergyAvailable : EnergyRate;
		attribute recycledMaterialAvailable : MaterialRate;
		attribute sharedHousingCapacity : PersonCount;
		attribute publicDataTrustCapacity : PersonCount;
	}

	item def PolicyProposal {
		attribute sponsorCount : PersonCount;
		attribute expectedMonthlyCost : MonthlyCurrencyRate;
		attribute expectedWellbeingGain : WellbeingIndex;
		attribute expectedCarbonImpact : CarbonRate;
	}

	item def PolicyMandate {
		attribute approved : Boolean;
		attribute participation : ParticipationRate;
		attribute effectiveMonthlyBudget : MonthlyCurrencyRate;
		attribute ecologicalLimit : CarbonRate;
		attribute guaranteedIncomeLevel : MonthlyCurrencyRate;
	}

	item def ResourceAllocation {
		attribute incomeBudget : MonthlyCurrencyRate;
		attribute careBudget : MonthlyCurrencyRate;
		attribute automationEnergyBudget : EnergyRate;
		attribute materialBudget : MaterialRate;
		attribute carbonUse : CarbonRate;
	}

	item def LivelihoodSecurityOutcome {
		attribute peopleAboveDignityFloor : PersonCount;
		attribute averageUnpaidWorkBurden : HoursPerWeek;
		attribute averageVoluntaryContribution : HoursPerWeek;
		attribute wellbeing : WellbeingIndex;
		attribute serviceAvailability : Availability;
	}

	port def NeedSubmissionPort {
		in item needs : NeedsPortfolio;
	}

	port def WellbeingPublicationPort {
		out item report : WellbeingReport;
	}

	port def WellbeingIntakePort {
		in item report : WellbeingReport;
	}

	port def IncomePaymentPort {
		out item credit : BasicIncomeCredit;
	}

	port def IncomeReceiptPort {
		in item credit : BasicIncomeCredit;
	}

	port def ServiceEntitlementPort {
		out item entitlement : ServiceEntitlement;
	}

	port def ServiceUsePort {
		in item entitlement : ServiceEntitlement;
	}

	port def ContributionOfferPort {
		out item contribution : CivicContribution;
	}

	port def ContributionIntakePort {
		in item contribution : CivicContribution;
	}

	port def AutomationTaskPort {
		out item task : AutomationWorkPackage;
	}

	port def AutomationCompletionPort {
		in item allocation : ResourceAllocation;
	}

	port def CommonsSupplyPort {
		out item resource : CommonsResource;
	}

	port def CommonsDemandPort {
		in item allocation : ResourceAllocation;
	}

	port def ProposalPort {
		in item proposal : PolicyProposal;
	}

	port def MandatePort {
		out item mandate : PolicyMandate;
	}

	port def MandateIntakePort {
		in item mandate : PolicyMandate;
	}

	part def CitizenCommunity {
		attribute residents : PersonCount = 1000000;
		attribute minimumDignifiedCost : MonthlyCurrencyRate = 1800.0;
		attribute averageVoluntaryContribution : HoursPerWeek = 8.0;
		attribute maximumAcceptableCompulsoryLabor : HoursPerWeek = 0.0;
		attribute desiredParticipation : ParticipationRate = 65.0;

		port incomeIn : IncomeReceiptPort;
		port servicesIn : ServiceUsePort;
		port needsOut : NeedSubmissionPort;
		port wellbeingOut : WellbeingPublicationPort;
		port contributionOut : ContributionOfferPort;
		port proposalIn : ProposalPort;

		perform action expressNeeds : ExpressCollectiveNeeds;
		perform action offerContribution : OfferVoluntaryContribution;
	}

	part def PublicTrustTreasury {
		attribute monthlyCommonDividendFund : MonthlyCurrencyRate = 2200000000.0;
		attribute automationRentCapture : MonthlyCurrencyRate = 900000000.0;
		attribute landValueDividend : MonthlyCurrencyRate = 500000000.0;
		attribute dataCommonsDividend : MonthlyCurrencyRate = 300000000.0;
		attribute resourceRoyaltyDividend : MonthlyCurrencyRate = 500000000.0;
		attribute reserveMonths : Real = 18.0;

		port mandateIn : MandateIntakePort;
		port paymentOut : IncomePaymentPort;

		perform action fundGuarantee : FundBasicIncome;
	}

	part def BasicIncomeService {
		attribute monthlyGrant : MonthlyCurrencyRate = 2000.0;
		attribute paymentAvailability : Availability = 99.99;
		attribute enrollmentLatency : ServiceLatency = 1.0;
		attribute meansTestingRequired : Boolean = false;

		port mandateIn : MandateIntakePort;
		port treasuryPaymentIn : IncomeReceiptPort;
		port paymentOut : IncomePaymentPort;

		perform action allocateIncome : AllocateBasicIncome;
	}

	part def UniversalServiceCommons {
		attribute housingAvailability : Availability = 97.0;
		attribute healthcareAvailability : Availability = 99.0;
		attribute nutritionAvailability : Availability = 99.5;
		attribute mobilityAvailability : Availability = 96.0;
		attribute learningAvailability : Availability = 98.0;
		attribute monthlyServiceValue : MonthlyCurrencyRate = 950.0;

		port entitlementOut : ServiceEntitlementPort;
		port needsIn : NeedSubmissionPort;
		port commonsIn : CommonsDemandPort;

		perform action provideUniversalServices : ProvideUniversalServices;
	}

	part def AutomationCommons {
		attribute totalCapacity : AutomationCapacity = 160000000.0;
		attribute essentialProductionShare : Real = 0.72;
		attribute humanOversightBurden : HoursPerWeek = 2.5;
		attribute monthlyEnergyUse : EnergyRate = 380000.0;
		attribute productiveAvailability : Availability = 99.2;

		port taskIn : AutomationTaskPort;
		port allocationOut : AutomationCompletionPort;
		port commonsResourceIn : CommonsDemandPort;

		perform action coordinateAutomation : CoordinateAutomation;
	}

	part def CivicContributionExchange {
		attribute averageMatchedHours : HoursPerWeek = 7.5;
		attribute compulsoryWorkHours : HoursPerWeek = 0.0;
		attribute carePriorityShare : Real = 0.45;
		attribute learningPriorityShare : Real = 0.20;
		attribute ecologicalStewardshipShare : Real = 0.25;

		port contributionIn : ContributionIntakePort;
		port taskOut : AutomationTaskPort;
		port wellbeingIn : WellbeingIntakePort;

		perform action matchContribution : MatchVoluntaryContribution;
	}

	part def DemocraticGovernanceAssembly {
		attribute quorumThreshold : ParticipationRate = 50.0;
		attribute deliberationParticipation : ParticipationRate = 68.0;
		attribute policyReviewIntervalDays : Integer = 30;
		attribute minorityProtectionThreshold : ParticipationRate = 15.0;

		port proposalIn : ProposalPort;
		port wellbeingIn : WellbeingIntakePort;
		port mandateOut : MandatePort;

		perform action deliberatePolicy : DeliberatePolicy;
	}

	part def WellbeingAndEquityMonitor {
		attribute targetLivelihoodSecurity : WellbeingIndex = 90.0;
		attribute targetAutonomy : WellbeingIndex = 85.0;
		attribute targetCareSufficiency : WellbeingIndex = 88.0;
		attribute maximumPrivacyRisk : PrivacyRiskScore = 0.15;
		attribute measurementPeriodDays : Integer = 14;

		port reportIn : WellbeingIntakePort;
		port reportOut : WellbeingPublicationPort;
		port proposalOut : ProposalPort;

		perform action monitorWellbeing : MonitorWellbeing;
	}

	part def RegenerativeResourceLoop {
		attribute renewableEnergySupply : EnergyRate = 450000.0;
		attribute recycledMaterialSupply : MaterialRate = 120000.0;
		attribute annualCarbonLimit : CarbonRate = 1200000.0;
		attribute currentAnnualCarbonUse : CarbonRate = 850000.0;
		attribute circularMaterialRate : Real = 0.86;

		port supplyOut : CommonsSupplyPort;
		port demandIn : CommonsDemandPort;
		port mandateIn : MandateIntakePort;

		perform action regenerateCommons : RegenerateCommons;
	}

	action def ExpressCollectiveNeeds {
		out needs : NeedsPortfolio;
	}

	action def OfferVoluntaryContribution {
		out contribution : CivicContribution;
	}

	action def FundBasicIncome {
		in mandate : PolicyMandate;
		out credit : BasicIncomeCredit;
	}

	action def AllocateBasicIncome {
		in treasuryCredit : BasicIncomeCredit;
		in mandate : PolicyMandate;
		out residentCredit : BasicIncomeCredit;
	}

	action def ProvideUniversalServices {
		in needs : NeedsPortfolio;
		in allocation : ResourceAllocation;
		out entitlement : ServiceEntitlement;
	}

	action def CoordinateAutomation {
		in task : AutomationWorkPackage;
		in resourceAllocation : ResourceAllocation;
		out completedAllocation : ResourceAllocation;
	}

	action def MatchVoluntaryContribution {
		in contribution : CivicContribution;
		in wellbeing : WellbeingReport;
		out automationTask : AutomationWorkPackage;
	}

	action def DeliberatePolicy {
		in proposal : PolicyProposal;
		in wellbeing : WellbeingReport;
		out mandate : PolicyMandate;
	}

	action def MonitorWellbeing {
		in residentReport : WellbeingReport;
		out publicReport : WellbeingReport;
		out correctiveProposal : PolicyProposal;
	}

	action def RegenerateCommons {
		in mandate : PolicyMandate;
		in demand : ResourceAllocation;
		out supply : CommonsResource;
	}

	action def OperatePostWorkSociety {
		in communityNeeds : NeedsPortfolio;
		in voluntaryContribution : CivicContribution;
		in civicProposal : PolicyProposal;
		out outcome : LivelihoodSecurityOutcome;

		action assessNeeds : ExpressCollectiveNeeds;
		action deliberate : DeliberatePolicy;
		action fund : FundBasicIncome;
		action distribute : AllocateBasicIncome;
		action match : MatchVoluntaryContribution;
		action automate : CoordinateAutomation;
		action provideServices : ProvideUniversalServices;
		action monitor : MonitorWellbeing;
		action regenerate : RegenerateCommons;
	}

	state def PostWorkSocietyLifecycle {
		attribute initializationComplete : Boolean;
		attribute dignityFloorStable : Boolean;
		attribute ecologicalStress : Boolean;
		attribute wellbeingBelowTarget : Boolean;
		attribute crisisDeclared : Boolean;
		attribute crisisResolved : Boolean;

		entry; then initializing;

		state initializing;
		state guaranteeStabilization;
		state steadyPostWorkOperation;
		state regenerativeImprovement;
		state crisisAdaptation;

		transition initializeToStabilize
			first initializing
			then guaranteeStabilization
			if initializationComplete;

		transition stabilizeToSteady
			first guaranteeStabilization
			then steadyPostWorkOperation
			if dignityFloorStable;

		transition steadyToRegenerative
			first steadyPostWorkOperation
			then regenerativeImprovement
			if not ecologicalStress and not wellbeingBelowTarget;

		transition regenerativeToSteady
			first regenerativeImprovement
			then steadyPostWorkOperation;

		transition steadyToCrisis
			first steadyPostWorkOperation
			then crisisAdaptation
			if crisisDeclared or ecologicalStress or wellbeingBelowTarget;

		transition crisisToStabilize
			first crisisAdaptation
			then guaranteeStabilization
			if crisisResolved;
	}

	part def PostWorkSocietySystem {
		attribute primaryFunction : String =
			"Guarantee dignified livelihood independent of compulsory employment by distributing common wealth, coordinating automated essential production, providing universal services, enabling voluntary civic contribution, and governing shared resources democratically within ecological limits.";

		attribute coveredPopulation : PersonCount = 1000000;
		attribute dignityFloor : MonthlyCurrencyRate = 1800.0;
		attribute guaranteedIncome : MonthlyCurrencyRate = 2000.0;
		attribute targetCompulsoryWork : HoursPerWeek = 0.0;
		attribute targetWellbeing : WellbeingIndex = 90.0;
		attribute targetServiceAvailability : Availability = 97.0;
		attribute targetParticipation : ParticipationRate = 60.0;
		attribute maximumAnnualCarbonUse : CarbonRate = 1200000.0;

		part citizenCommunity : CitizenCommunity;
		part treasury : PublicTrustTreasury;
		part basicIncomeService : BasicIncomeService;
		part universalServices : UniversalServiceCommons;
		part automationCommons : AutomationCommons;
		part contributionExchange : CivicContributionExchange;
		part governanceAssembly : DemocraticGovernanceAssembly;
		part wellbeingMonitor : WellbeingAndEquityMonitor;
		part resourceLoop : RegenerativeResourceLoop;

		connection residentNeeds
			connect citizenCommunity.needsOut to universalServices.needsIn;

		connection residentIncome
			connect basicIncomeService.paymentOut to citizenCommunity.incomeIn;

		connection treasuryToIncomeService
			connect treasury.paymentOut to basicIncomeService.treasuryPaymentIn;

		connection serviceEntitlements
			connect universalServices.entitlementOut to citizenCommunity.servicesIn;

		connection voluntaryContributionFlow
			connect citizenCommunity.contributionOut to contributionExchange.contributionIn;

		connection contributionToAutomation
			connect contributionExchange.taskOut to automationCommons.taskIn;

		connection automationAllocationToServices
			connect automationCommons.allocationOut to universalServices.commonsIn;

		connection resourceSupplyToAutomation
			connect resourceLoop.supplyOut to automationCommons.commonsResourceIn;

		connection resourceDemandFeedback
			connect universalServices.commonsIn to resourceLoop.demandIn;

		connection wellbeingFromResidents
			connect citizenCommunity.wellbeingOut to wellbeingMonitor.reportIn;

		connection wellbeingToGovernance
			connect wellbeingMonitor.reportOut to governanceAssembly.wellbeingIn;

		connection wellbeingToContributionExchange
			connect wellbeingMonitor.reportOut to contributionExchange.wellbeingIn;

		connection residentProposals
			connect citizenCommunity.proposalIn to governanceAssembly.proposalIn;

		connection correctiveProposals
			connect wellbeingMonitor.proposalOut to governanceAssembly.proposalIn;

		connection mandateToTreasury
			connect governanceAssembly.mandateOut to treasury.mandateIn;

		connection mandateToIncome
			connect governanceAssembly.mandateOut to basicIncomeService.mandateIn;

		connection mandateToResources
			connect governanceAssembly.mandateOut to resourceLoop.mandateIn;

		perform action operate : OperatePostWorkSociety;
		exhibit state lifecycle : PostWorkSocietyLifecycle;
	}

	requirement def DefinePostWorkSocietySystem {
		subject society : PostWorkSocietySystem;

		require constraint {
			society.primaryFunction != ""
		}
	}

	requirement def LivelihoodIndependentOfEmployment {
		subject society : PostWorkSocietySystem;

		require constraint {
			society.guaranteedIncome >= society.dignityFloor and
			society.targetCompulsoryWork == 0.0
		}
	}

	requirement def UniversalBasicIncomeAdequacy {
		subject society : PostWorkSocietySystem;

		require constraint {
			society.basicIncomeService.monthlyGrant >= society.citizenCommunity.minimumDignifiedCost and
			society.basicIncomeService.meansTestingRequired == false and
			society.basicIncomeService.paymentAvailability >= 99.9
		}
	}

	requirement def UniversalServiceAvailability {
		subject society : PostWorkSocietySystem;

		require constraint {
			society.universalServices.housingAvailability >= society.targetServiceAvailability and
			society.universalServices.healthcareAvailability >= society.targetServiceAvailability and
			society.universalServices.nutritionAvailability >= society.targetServiceAvailability and
			society.universalServices.learningAvailability >= society.targetServiceAvailability
		}
	}

	requirement def DemocraticResourceGovernance {
		subject society : PostWorkSocietySystem;

		require constraint {
			society.governanceAssembly.deliberationParticipation >= society.targetParticipation and
			society.governanceAssembly.quorumThreshold >= 50.0
		}
	}

	requirement def VoluntaryContributionOnly {
		subject society : PostWorkSocietySystem;

		require constraint {
			society.contributionExchange.compulsoryWorkHours == 0.0 and
			society.citizenCommunity.averageVoluntaryContribution >= 0.0
		}
	}

	requirement def AutomationForEssentialProvision {
		subject society : PostWorkSocietySystem;

		require constraint {
			society.automationCommons.essentialProductionShare >= 0.70 and
			society.automationCommons.humanOversightBurden <= 3.0 and
			society.automationCommons.productiveAvailability >= 99.0
		}
	}

	requirement def EcologicalLimitCompliance {
		subject society : PostWorkSocietySystem;

		require constraint {
			society.resourceLoop.currentAnnualCarbonUse <= society.maximumAnnualCarbonUse and
			society.automationCommons.monthlyEnergyUse <= society.resourceLoop.renewableEnergySupply and
			society.resourceLoop.circularMaterialRate >= 0.80
		}
	}

	requirement def WellbeingAndPrivacyProtection {
		subject society : PostWorkSocietySystem;

		require constraint {
			society.wellbeingMonitor.targetLivelihoodSecurity >= society.targetWellbeing and
			society.wellbeingMonitor.maximumPrivacyRisk <= 0.15
		}
	}

	requirement def PublicTrustSolvency {
		subject society : PostWorkSocietySystem;

		require constraint {
			society.treasury.reserveMonths >= 12.0 and
			society.treasury.monthlyCommonDividendFund >=
				(society.coveredPopulation * society.guaranteedIncome)
		}
	}
}
