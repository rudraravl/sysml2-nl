package GermanyBasedNationalSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def PopulationCount :> ScalarValues::Integer;
    attribute def EuroAmount :> ScalarValues::Real {
        unit = "EUR";
    }
    attribute def EnergyAmount :> ScalarValues::Real {
        unit = "GWh";
    }
    attribute def PowerRating :> ScalarValues::Real {
        unit = "GW";
    }
    attribute def MassAmount :> ScalarValues::Real {
        unit = "Mt";
    }
    attribute def DistanceAmount :> ScalarValues::Real {
        unit = "km";
    }
    attribute def Percentage :> ScalarValues::Real {
        unit = "%";
    }
    attribute def TimeHours :> ScalarValues::Real {
        unit = "h";
    }

    item def Electricity {
        attribute quantity : EnergyAmount;
        attribute renewableShare : Percentage;
        attribute carbonIntensity {
            unit = "gCO2e/kWh";
        }
    }

    item def PassengerFlow {
        attribute passengersPerDay : PopulationCount;
        attribute averageDelay : TimeHours;
    }

    item def FreightFlow {
        attribute tonnesPerDay {
            unit = "t/day";
        }
        attribute railShare : Percentage;
    }

    item def PublicServiceRequest {
        attribute requestId : ScalarValues::String;
        attribute serviceCategory : ScalarValues::String;
        attribute priority : ScalarValues::Integer;
    }

    item def PolicyDirective {
        attribute directiveId : ScalarValues::String;
        attribute issuingAuthority : ScalarValues::String;
        attribute targetSector : ScalarValues::String;
    }

    item def BudgetAllocation {
        attribute fiscalYear : ScalarValues::Integer;
        attribute amount : EuroAmount;
        attribute targetProgram : ScalarValues::String;
    }

    item def EmergencyAlert {
        attribute regionCode : ScalarValues::String;
        attribute severity : ScalarValues::Integer;
        attribute description : ScalarValues::String;
    }

    item def EnvironmentalMetric {
        attribute annualEmissions : MassAmount;
        attribute renewableElectricityShare : Percentage;
        attribute protectedLandShare : Percentage;
    }

    port def PolicyPort {
        out item directive : PolicyDirective;
        in item serviceRequest : PublicServiceRequest;
    }

    port def BudgetPort {
        out item allocation : BudgetAllocation;
    }

    port def GridPort {
        inout item electricity : Electricity;
    }

    port def MobilityPort {
        inout item passengerFlow : PassengerFlow;
        inout item freightFlow : FreightFlow;
    }

    port def EmergencyPort {
        in item alert : EmergencyAlert;
        out item directive : PolicyDirective;
    }

    port def EnvironmentPort {
        out item metric : EnvironmentalMetric;
        in item directive : PolicyDirective;
    }

    part def FederalGovernment {
        attribute federalBudget : EuroAmount = 476300000000.0;
        attribute ministries : ScalarValues::Integer = 15;

        port policy : PolicyPort;
        port budget : BudgetPort;
        port emergency : EmergencyPort;

        action issueNationalPolicy {
            in item incomingRequest : PublicServiceRequest;
            out item directive : PolicyDirective;
        }

        action allocateBudget {
            in item directive : PolicyDirective;
            out item allocation : BudgetAllocation;
        }
    }

    part def FederalState {
        attribute name : ScalarValues::String;
        attribute population : PopulationCount;
        attribute area : DistanceAmount;
        attribute grossRegionalProduct : EuroAmount;

        port policy : PolicyPort;
        port budget : BudgetPort;
        port mobility : MobilityPort;
        port emergency : EmergencyPort;

        action implementFederalDirective {
            in item directive : PolicyDirective;
            in item allocation : BudgetAllocation;
            out item serviceRequest : PublicServiceRequest;
        }
    }

    part def EnergySystem {
        attribute installedRenewableCapacity : PowerRating = 170.0;
        attribute installedConventionalCapacity : PowerRating = 75.0;
        attribute annualElectricityDemand : EnergyAmount = 520000.0;
        attribute targetRenewableShare2030 : Percentage = 80.0;

        port federalPolicy : PolicyPort;
        port grid : GridPort;
        port environment : EnvironmentPort;

        part transmissionGrid {
            attribute circuitLength : DistanceAmount = 37000.0;
            port northSouthExchange : GridPort;
            port regionalExchange : GridPort;
        }

        part renewableGeneration {
            attribute windCapacity : PowerRating = 72.0;
            attribute solarCapacity : PowerRating = 88.0;
            attribute hydroCapacity : PowerRating = 5.6;
            port generationOutput : GridPort;
        }

        part conventionalGeneration {
            attribute gasCapacity : PowerRating = 35.0;
            attribute coalCapacity : PowerRating = 25.0;
            port generationOutput : GridPort;
        }

        action balanceElectricitySupply {
            inout item electricity : Electricity;
            out item metric : EnvironmentalMetric;
        }

        state def EnergyOperatingState {
            state normal;
            state renewableSurplus;
            state gridConstraint;
            state emergencyLoadShedding;

            transition first normal;
            transition normal_to_surplus
                first normal
                then renewableSurplus;

            transition surplus_to_normal
                first renewableSurplus
                then normal;

            transition normal_to_constraint
                first normal
                then gridConstraint;

            transition constraint_to_shedding
                first gridConstraint
                then emergencyLoadShedding;

            transition shedding_to_constraint
                first emergencyLoadShedding
                then gridConstraint;

            transition constraint_to_normal
                first gridConstraint
                then normal;
        }

        exhibit state energyState : EnergyOperatingState;
    }

    part def MobilitySystem {
        attribute federalRailLength : DistanceAmount = 33800.0;
        attribute autobahnLength : DistanceAmount = 13200.0;
        attribute inlandWaterwayLength : DistanceAmount = 7300.0;
        attribute annualPassengerTrips : PopulationCount = 11300000000;

        port federalPolicy : PolicyPort;
        port passengerAndFreight : MobilityPort;
        port energy : GridPort;
        port emergency : EmergencyPort;

        part railNetwork {
            attribute electrifiedShare : Percentage = 62.0;
            attribute highSpeedRouteLength : DistanceAmount = 1600.0;
            port flow : MobilityPort;
            port tractionPower : GridPort;
        }

        part roadNetwork {
            attribute bridgeModernizationBacklog : ScalarValues::Integer = 4000;
            port flow : MobilityPort;
        }

        part logisticsHubs {
            attribute majorPorts : ScalarValues::Integer = 6;
            attribute intermodalTerminals : ScalarValues::Integer = 150;
            port flow : MobilityPort;
        }

        action movePeopleAndGoods {
            inout item passengerFlow : PassengerFlow;
            inout item freightFlow : FreightFlow;
        }

        state def MobilityOperatingState {
            state scheduledService;
            state congestionManagement;
            state infrastructureDisruption;
            state emergencyPriorityRouting;

            transition first scheduledService;
            transition scheduled_to_congested
                first scheduledService
                then congestionManagement;

            transition congested_to_scheduled
                first congestionManagement
                then scheduledService;

            transition scheduled_to_disrupted
                first scheduledService
                then infrastructureDisruption;

            transition disrupted_to_priority
                first infrastructureDisruption
                then emergencyPriorityRouting;

            transition priority_to_scheduled
                first emergencyPriorityRouting
                then scheduledService;
        }

        exhibit state mobilityState : MobilityOperatingState;
    }

    part def PublicAdministrationSystem {
        attribute residentsServed : PopulationCount = 84400000;
        attribute municipalities : ScalarValues::Integer = 10789;
        attribute digitalServiceAvailability : Percentage = 65.0;

        port federalPolicy : PolicyPort;
        port budget : BudgetPort;
        port emergency : EmergencyPort;

        part identityAndCivilRegistry {
            attribute annualTransactions : PopulationCount = 25000000;
            port service : PolicyPort;
        }

        part taxAndSocialServices {
            attribute annualBenefitCases : PopulationCount = 19000000;
            port service : PolicyPort;
        }

        part digitalGovernmentPlatform {
            attribute onlineServiceCount : ScalarValues::Integer = 575;
            attribute serviceUptime : Percentage = 99.5;
            port service : PolicyPort;
        }

        action processPublicServiceRequest {
            in item request : PublicServiceRequest;
            out item directive : PolicyDirective;
        }

        state def AdministrationState {
            state acceptingRequests;
            state validatingEligibility;
            state deliveringService;
            state escalatedCase;
            state closed;

            transition first acceptingRequests;
            transition accept_to_validate
                first acceptingRequests
                then validatingEligibility;

            transition validate_to_deliver
                first validatingEligibility
                then deliveringService;

            transition validate_to_escalate
                first validatingEligibility
                then escalatedCase;

            transition escalate_to_deliver
                first escalatedCase
                then deliveringService;

            transition deliver_to_close
                first deliveringService
                then closed;

            transition close_to_accept
                first closed
                then acceptingRequests;
        }

        exhibit state administrationState : AdministrationState;
    }

    part def EnvironmentalStewardshipSystem {
        attribute annualGreenhouseGasEmissions : MassAmount = 673.0;
        attribute protectedLandShare : Percentage = 37.0;
        attribute climateNeutralityTargetYear : ScalarValues::Integer = 2045;

        port federalPolicy : PolicyPort;
        port environment : EnvironmentPort;
        port emergency : EmergencyPort;

        part climateMonitoring {
            attribute monitoringStations : ScalarValues::Integer = 1800;
            port metricOutput : EnvironmentPort;
        }

        part waterAndForestProtection {
            attribute majorRiverBasins : ScalarValues::Integer = 10;
            attribute forestAreaShare : Percentage = 32.0;
            port metricOutput : EnvironmentPort;
        }

        part circularEconomy {
            attribute municipalWasteRecyclingRate : Percentage = 67.0;
            port metricOutput : EnvironmentPort;
        }

        action assessEnvironmentalPerformance {
            in item directive : PolicyDirective;
            out item metric : EnvironmentalMetric;
        }

        action triggerClimateAdaptation {
            in item alert : EmergencyAlert;
            out item directive : PolicyDirective;
        }
    }

    part def CivilProtectionSystem {
        attribute federalWarningCoverage : Percentage = 98.0;
        attribute volunteerResponderCount : PopulationCount = 1700000;
        attribute averageAlertPropagationTime : TimeHours = 0.05;

        port federalCoordination : EmergencyPort;
        port stateCoordination : EmergencyPort;
        port mobilityCoordination : EmergencyPort;
        port environmentCoordination : EmergencyPort;

        part warningInfrastructure {
            attribute sirens : ScalarValues::Integer = 38000;
            attribute cellBroadcastCoverage : Percentage = 96.0;
            port alerts : EmergencyPort;
        }

        part reliefCoordination {
            attribute federalReliefWarehouses : ScalarValues::Integer = 8;
            attribute deployablePowerUnits : ScalarValues::Integer = 450;
            port alerts : EmergencyPort;
        }

        action coordinateEmergencyResponse {
            in item alert : EmergencyAlert;
            out item directive : PolicyDirective;
        }

        state def EmergencyResponseState {
            state monitoring;
            state warningIssued;
            state responseCoordinated;
            state recoveryManaged;

            transition first monitoring;
            transition monitor_to_warning
                first monitoring
                then warningIssued;

            transition warning_to_response
                first warningIssued
                then responseCoordinated;

            transition response_to_recovery
                first responseCoordinated
                then recoveryManaged;

            transition recovery_to_monitor
                first recoveryManaged
                then monitoring;
        }

        exhibit state emergencyState : EmergencyResponseState;
    }

    part def GermanyNationalCapabilitySystem {
        attribute primaryFunction : ScalarValues::String =
            "Coordinate Germany's federal institutions, states, infrastructure, energy transition, mobility, public services, environmental stewardship, and civil protection to sustain national well-being, economic activity, democratic governance, and resilient public operations.";
        attribute population : PopulationCount = 84400000;
        attribute federalStatesCount : ScalarValues::Integer = 16;
        attribute landArea : DistanceAmount = 357600.0;
        attribute nominalGDP : EuroAmount = 4120000000000.0;

        part federalGovernment : FederalGovernment;

        part badenWuerttemberg : FederalState {
            attribute name = "Baden-Wuerttemberg";
            attribute population = 11280000;
            attribute area = 35748.0;
            attribute grossRegionalProduct = 572800000000.0;
        }

        part bavaria : FederalState {
            attribute name = "Bavaria";
            attribute population = 13440000;
            attribute area = 70550.0;
            attribute grossRegionalProduct = 768500000000.0;
        }

        part berlin : FederalState {
            attribute name = "Berlin";
            attribute population = 3890000;
            attribute area = 892.0;
            attribute grossRegionalProduct = 193200000000.0;
        }

        part brandenburg : FederalState {
            attribute name = "Brandenburg";
            attribute population = 2580000;
            attribute area = 29654.0;
            attribute grossRegionalProduct = 93100000000.0;
        }

        part bremen : FederalState {
            attribute name = "Bremen";
            attribute population = 690000;
            attribute area = 419.0;
            attribute grossRegionalProduct = 38500000000.0;
        }

        part hamburg : FederalState {
            attribute name = "Hamburg";
            attribute population = 1930000;
            attribute area = 755.0;
            attribute grossRegionalProduct = 151000000000.0;
        }

        part hesse : FederalState {
            attribute name = "Hesse";
            attribute population = 6400000;
            attribute area = 21115.0;
            attribute grossRegionalProduct = 344000000000.0;
        }

        part lowerSaxony : FederalState {
            attribute name = "Lower Saxony";
            attribute population = 8140000;
            attribute area = 47614.0;
            attribute grossRegionalProduct = 339000000000.0;
        }

        part MecklenburgWesternPomerania : FederalState {
            attribute name = "Mecklenburg-Western Pomerania";
            attribute population = 1630000;
            attribute area = 23295.0;
            attribute grossRegionalProduct = 58000000000.0;
        }

        part northRhineWestphalia : FederalState {
            attribute name = "North Rhine-Westphalia";
            attribute population = 18190000;
            attribute area = 34110.0;
            attribute grossRegionalProduct = 839000000000.0;
        }

        part rhinelandPalatinate : FederalState {
            attribute name = "Rhineland-Palatinate";
            attribute population = 4160000;
            attribute area = 19854.0;
            attribute grossRegionalProduct = 171000000000.0;
        }

        part saarland : FederalState {
            attribute name = "Saarland";
            attribute population = 1000000;
            attribute area = 2571.0;
            attribute grossRegionalProduct = 39000000000.0;
        }

        part saxony : FederalState {
            attribute name = "Saxony";
            attribute population = 4090000;
            attribute area = 18450.0;
            attribute grossRegionalProduct = 155000000000.0;
        }

        part saxonyAnhalt : FederalState {
            attribute name = "Saxony-Anhalt";
            attribute population = 2180000;
            attribute area = 20452.0;
            attribute grossRegionalProduct = 76000000000.0;
        }

        part schleswigHolstein : FederalState {
            attribute name = "Schleswig-Holstein";
            attribute population = 2960000;
            attribute area = 15804.0;
            attribute grossRegionalProduct = 117000000000.0;
        }

        part thuringia : FederalState {
            attribute name = "Thuringia";
            attribute population = 2130000;
            attribute area = 16202.0;
            attribute grossRegionalProduct = 74000000000.0;
        }

        part energySystem : EnergySystem;
        part mobilitySystem : MobilitySystem;
        part publicAdministration : PublicAdministrationSystem;
        part environmentalStewardship : EnvironmentalStewardshipSystem;
        part civilProtection : CivilProtectionSystem;

        port nationalPolicy : PolicyPort;
        port nationalBudget : BudgetPort;
        port nationalGrid : GridPort;
        port nationalMobility : MobilityPort;
        port nationalEmergency : EmergencyPort;
        port nationalEnvironment : EnvironmentPort;

        connect federalGovernment.policy to nationalPolicy;
        connect federalGovernment.budget to nationalBudget;
        connect federalGovernment.emergency to nationalEmergency;

        connect federalGovernment.policy to energySystem.federalPolicy;
        connect federalGovernment.policy to mobilitySystem.federalPolicy;
        connect federalGovernment.policy to publicAdministration.federalPolicy;
        connect federalGovernment.policy to environmentalStewardship.federalPolicy;

        connect federalGovernment.budget to publicAdministration.budget;

        connect energySystem.grid to nationalGrid;
        connect energySystem.environment to nationalEnvironment;
        connect energySystem.grid to mobilitySystem.energy;

        connect mobilitySystem.passengerAndFreight to nationalMobility;
        connect mobilitySystem.emergency to civilProtection.mobilityCoordination;

        connect environmentalStewardship.environment to nationalEnvironment;
        connect environmentalStewardship.emergency to civilProtection.environmentCoordination;

        connect civilProtection.federalCoordination to federalGovernment.emergency;
        connect civilProtection.stateCoordination to nationalEmergency;

        connect badenWuerttemberg.policy to federalGovernment.policy;
        connect bavaria.policy to federalGovernment.policy;
        connect berlin.policy to federalGovernment.policy;
        connect brandenburg.policy to federalGovernment.policy;
        connect bremen.policy to federalGovernment.policy;
        connect hamburg.policy to federalGovernment.policy;
        connect hesse.policy to federalGovernment.policy;
        connect lowerSaxony.policy to federalGovernment.policy;
        connect MecklenburgWesternPomerania.policy to federalGovernment.policy;
        connect northRhineWestphalia.policy to federalGovernment.policy;
        connect rhinelandPalatinate.policy to federalGovernment.policy;
        connect saarland.policy to federalGovernment.policy;
        connect saxony.policy to federalGovernment.policy;
        connect saxonyAnhalt.policy to federalGovernment.policy;
        connect schleswigHolstein.policy to federalGovernment.policy;
        connect thuringia.policy to federalGovernment.policy;

        connect badenWuerttemberg.mobility to mobilitySystem.passengerAndFreight;
        connect bavaria.mobility to mobilitySystem.passengerAndFreight;
        connect berlin.mobility to mobilitySystem.passengerAndFreight;
        connect brandenburg.mobility to mobilitySystem.passengerAndFreight;
        connect bremen.mobility to mobilitySystem.passengerAndFreight;
        connect hamburg.mobility to mobilitySystem.passengerAndFreight;
        connect hesse.mobility to mobilitySystem.passengerAndFreight;
        connect lowerSaxony.mobility to mobilitySystem.passengerAndFreight;
        connect MecklenburgWesternPomerania.mobility to mobilitySystem.passengerAndFreight;
        connect northRhineWestphalia.mobility to mobilitySystem.passengerAndFreight;
        connect rhinelandPalatinate.mobility to mobilitySystem.passengerAndFreight;
        connect saarland.mobility to mobilitySystem.passengerAndFreight;
        connect saxony.mobility to mobilitySystem.passengerAndFreight;
        connect saxonyAnhalt.mobility to mobilitySystem.passengerAndFreight;
        connect schleswigHolstein.mobility to mobilitySystem.passengerAndFreight;
        connect thuringia.mobility to mobilitySystem.passengerAndFreight;

        action operateNationalCapability {
            in item publicRequest : PublicServiceRequest;
            in item emergencyAlert : EmergencyAlert;
            inout item electricity : Electricity;
            inout item passengers : PassengerFlow;
            inout item freight : FreightFlow;
            out item environmentalStatus : EnvironmentalMetric;

            first start;
            then issuePolicy;
            then allocateResources;
            then balanceEnergy;
            then moveFlows;
            then deliverServices;
            then monitorEnvironment;
            then coordinateEmergencyIfNeeded;
            then done;

            action issuePolicy : FederalGovernment::issueNationalPolicy;
            action allocateResources : FederalGovernment::allocateBudget;
            action balanceEnergy : EnergySystem::balanceElectricitySupply;
            action moveFlows : MobilitySystem::movePeopleAndGoods;
            action deliverServices : PublicAdministrationSystem::processPublicServiceRequest;
            action monitorEnvironment : EnvironmentalStewardshipSystem::assessEnvironmentalPerformance;
            action coordinateEmergencyIfNeeded : CivilProtectionSystem::coordinateEmergencyResponse;
        }
    }

    requirement def NationalContinuityRequirement {
        doc
        /* The Germany-based national capability system shall maintain coordinated public governance, core infrastructure service, and civil protection across all sixteen federal states. */

        subject system : GermanyNationalCapabilitySystem;

        require constraint {
            system.population >= 80000000
        }
    }

    requirement def RenewableTransitionRequirement {
        doc
        /* The energy subsystem shall support an electricity transition toward at least eighty percent renewable electricity by 2030 while maintaining grid operation. */

        subject energy : EnergySystem;

        require constraint {
            energy.targetRenewableShare2030 >= 80.0
        }
    }

    requirement def MobilityContinuityRequirement {
        doc
        /* The mobility subsystem shall move passenger and freight flows through rail, road, and logistics hubs while supporting emergency priority routing. */

        subject mobility : MobilitySystem;

        require constraint {
            mobility.federalRailLength > 30000.0 and mobility.autobahnLength > 12000.0
        }
    }

    requirement def PublicServiceRequirement {
        doc
        /* The public administration subsystem shall process resident service requests through federal, state, municipal, and digital channels. */

        subject administration : PublicAdministrationSystem;

        require constraint {
            administration.residentsServed >= 80000000 and administration.digitalServiceAvailability >= 60.0
        }
    }

    requirement def ClimateAndEnvironmentRequirement {
        doc
        /* The environmental stewardship subsystem shall monitor emissions, land protection, water, forest, and circular economy performance against national climate goals. */

        subject environment : EnvironmentalStewardshipSystem;

        require constraint {
            environment.climateNeutralityTargetYear <= 2045
        }
    }

    requirement def CivilProtectionRequirement {
        doc
        /* The civil protection subsystem shall issue warnings and coordinate relief resources for hazards affecting federal states, mobility, environment, and public services. */

        subject protection : CivilProtectionSystem;

        require constraint {
            protection.federalWarningCoverage >= 95.0 and protection.averageAlertPropagationTime <= 0.1
        }
    }

    satisfy NationalContinuityRequirement by GermanyNationalCapabilitySystem;
    satisfy RenewableTransitionRequirement by EnergySystem;
    satisfy MobilityContinuityRequirement by MobilitySystem;
    satisfy PublicServiceRequirement by PublicAdministrationSystem;
    satisfy ClimateAndEnvironmentRequirement by EnvironmentalStewardshipSystem;
    satisfy CivilProtectionRequirement by CivilProtectionSystem;
}