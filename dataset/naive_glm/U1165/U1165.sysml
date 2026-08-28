package PostWorkSociety {

    package ValueTypes {
        value type PopulationCount > Real { unit "person"; }
        value type WellbeingIndex > Real { unit "score"; }
        value type ResourceUtilizationRate > Real { unit "percent"; }
        value type DemandForecast > Real { unit "units"; }
        value type ProductionRate > Real { unit "units per day"; }
        value type EnergyConsumption > Real { unit "kilowatt hour"; }
        value type SustainabilityIndex > Real { unit "score"; }
        value type HousingUnitCount > Real { unit "housing unit"; }
        value type NutritionSupply > Real { unit "kilocalorie per day"; }
        value type HealthcareCapacity > Real { unit "patient per day"; }
        value type CreativeEngagementLevel > Real { unit "score"; }
        value type RequestRate > Real { unit "request per day"; }
    }

    package Items {
        item def RawMaterial;
        item def ManufacturedGood;
        item def BasicResource;
        item def HousingAssignment;
        item def HealthcareService;
        item def NutritionPackage;
        item def EducationalResource;
        item def CulturalEvent;
        item def CollaborativeProject;
        item def WellbeingMetric;
        item def DemandSignal;
        item def AllocationDirective;
        item def ProductionOrder;
    }

    package Ports {
        port def ProductionOut {
            out goods : ManufacturedGood;
            out resources : BasicResource;
        }
        port def ProductionIn {
            in order : ProductionOrder;
            in rawMaterial : RawMaterial;
        }
        port def ServiceOut {
            out housing : HousingAssignment;
            out healthcare : HealthcareService;
            out nutrition : NutritionPackage;
            out education : EducationalResource;
        }
        port def ServiceIn {
            in goods : ManufacturedGood;
            in directive : AllocationDirective;
        }
        port def CommunityOut {
            out events : CulturalEvent;
            out projects : CollaborativeProject;
        }
        port def CommunityIn {
            in resources : BasicResource;
            in directive : AllocationDirective;
        }
        port def ControlOut {
            out directive : AllocationDirective;
            out order : ProductionOrder;
        }
        port def ControlIn {
            in metrics : WellbeingMetric;
            in demand : DemandSignal;
            in utilization : ResourceUtilizationRate;
        }
        port def CitizenServicePort {
            in housingRequest;
            in healthcareRequest;
            in nutritionRequest;
            in educationRequest;
            in creativeRequest;
            in eventRequest;
            out metrics : WellbeingMetric;
            out demand : DemandSignal;
        }
    }

    package Subsystems {

        part def AutomatedProductionSystem {
            port prodIn : ProductionIn;
            port prodOut : ProductionOut;

            attribute productionRate : ProductionRate := 1000 [units per day];
            attribute energyUse : EnergyConsumption := 5000 [kilowatt hour];
            attribute sustainability : SustainabilityIndex := 0.85 [score];
            attribute rawMaterialStock : RawMaterial;

            part manufacturingFacilities {
                attribute capacity : ProductionRate := 1500 [units per day];
                perform produceGoods;
            }
            part logisticsAutomation {
                attribute throughput : ProductionRate := 1200 [units per day];
                perform distributeGoods;
            }
            part aiOptimizer {
                attribute efficiencyTarget : ResourceUtilizationRate := 90 [percent];
                perform optimizeThroughput;
            }

            action produceGoods {
                in raw : RawMaterial;
                out goods : ManufacturedGood;
                out resources : BasicResource;
            }
            action distributeGoods {
                in goods : ManufacturedGood;
            }
            action optimizeThroughput {
                in currentRate : ProductionRate;
                out adjustedRate : ProductionRate;
            }

            state productionBehavior {
                entry; then Operating;
                state Operating {
                    do { produceGoods(); }
                }
                transition from Operating to ScalingUp
                    when prodIn.order.quantity > productionRate;
                state ScalingUp {
                    entry { productionRate := manufacturingFacilities.capacity; }
                    do { produceGoods(); }
                }
                transition from ScalingUp to Operating
                    when prodIn.order.quantity <= productionRate;
                transition from Operating to Maintenance
                    when sustainability < 0.6 [score];
                state Maintenance {
                    entry { productionRate := 0 [units per day]; }
                    do { performMaintenance(); }
                }
                transition from Maintenance to Operating
                    when sustainability >= 0.8 [score];
            }

            action performMaintenance {
                out restoredSustainability : SustainabilityIndex;
            }
        }

        part def UniversalBasicServicesSystem {
            port svcIn : ServiceIn;
            port svcOut : ServiceOut;
            port citizen : CitizenServicePort;

            attribute housingUnits : HousingUnitCount := 10000 [housing unit];
            attribute nutritionSupply : NutritionSupply := 2000000 [kilocalorie per day];
            attribute healthcareCapacity : HealthcareCapacity := 500 [patient per day];
            attribute requestRate : RequestRate := 100 [request per day];

            part housingManager {
                attribute availableUnits : HousingUnitCount := 1000 [housing unit];
                perform assignHousing;
            }
            part healthcareProvider {
                attribute capacity : HealthcareCapacity := 500 [patient per day];
                perform provideHealthcare;
            }
            part nutritionDistributor {
                attribute supply : NutritionSupply := 2000000 [kilocalorie per day];
                perform distributeNutrition;
            }
            part educationAccess {
                attribute enrolledLearners : PopulationCount := 5000 [person];
                perform provideEducation;
            }

            action assignHousing {
                in request;
                out assignment : HousingAssignment;
            }
            action provideHealthcare {
                in need;
                out service : HealthcareService;
            }
            action distributeNutrition {
                out package : NutritionPackage;
            }
            action provideEducation {
                out resource : EducationalResource;
            }
            action requestAdditionalGoods {
                out signal : DemandSignal;
            }

            state serviceBehavior {
                entry; then NormalService;
                state NormalService {
                    do { assignHousing(); provideHealthcare(); distributeNutrition(); provideEducation(); }
                }
                transition from NormalService to HighDemand
                    when requestRate > housingUnits * 0.1 [request per day];
                state HighDemand {
                    entry { requestAdditionalGoods(); }
                    do { assignHousing(); provideHealthcare(); distributeNutrition(); }
                }
                transition from HighDemand to NormalService
                    when requestRate <= housingUnits * 0.05 [request per day];
            }
        }

        part def ResourceAllocationAI {
            port ctrlIn : ControlIn;
            port ctrlOut : ControlOut;

            attribute populationWellbeing : WellbeingIndex := 0.8 [score];
            attribute utilizationRate : ResourceUtilizationRate := 75 [percent];
            attribute demandForecast : DemandForecast := 800 [units];
            attribute metricsUpdated : Boolean := false;
            attribute forecastComputed : Boolean := false;
            attribute directiveSent : Boolean := false;

            part monitoringEngine {
                perform monitorMetrics;
            }
            part forecastingEngine {
                perform forecastDemand;
            }
            part allocationEngine {
                perform allocateResources;
            }

            action monitorMetrics {
                in rawMetrics : WellbeingMetric;
                out metrics : WellbeingMetric;
            }
            action forecastDemand {
                in metrics : WellbeingMetric;
                in demand : DemandSignal;
                out forecast : DemandForecast;
            }
            action allocateResources {
                in forecast : DemandForecast;
                in utilization : ResourceUtilizationRate;
                out directive : AllocationDirective;
                out order : ProductionOrder;
            }

            state aiBehavior {
                entry; then Monitoring;
                state Monitoring {
                    do { monitorMetrics(); }
                }
                transition from Monitoring to Forecasting
                    when metricsUpdated;
                state Forecasting {
                    do { forecastDemand(); }
                }
                transition from Forecasting to Allocating
                    when forecastComputed;
                state Allocating {
                    do { allocateResources(); }
                }
                transition from Allocating to Monitoring
                    when directiveSent;
            }
        }

        part def CommunityEngagementSystem {
            port commIn : CommunityIn;
            port commOut : CommunityOut;
            port citizen : CitizenServicePort;

            attribute creativeEngagement : CreativeEngagementLevel := 0.75 [score];
            attribute eventSurge : Boolean := false;
            attribute activeParticipants : PopulationCount := 8000 [person];

            part creativeWorkspaces {
                attribute availableSpaces : PopulationCount := 2000 [person];
                perform hostCreativeWork;
            }
            part culturalVenues {
                attribute venueCount : Integer := 50;
                perform hostEvents;
            }
            part digitalNetwork {
                attribute activeConnections : PopulationCount := 15000 [person];
                perform enableCollaboration;
            }

            action hostCreativeWork {
                out project : CollaborativeProject;
            }
            action hostEvents {
                out event : CulturalEvent;
            }
            action enableCollaboration {
                out project : CollaborativeProject;
            }

            state communityBehavior {
                entry; then Active;
                state Active {
                    do { enableCollaboration(); hostCreativeWork(); }
                }
                transition from Active to Festival
                    when eventSurge;
                state Festival {
                    entry { hostEvents(); }
                    do { hostCreativeWork(); enableCollaboration(); }
                }
                transition from Festival to Active
                    when !eventSurge;
            }
        }
    }

    package Society {

        part def PostWorkSocietySystem {
            part production : Subsystems::AutomatedProductionSystem;
            part services : Subsystems::UniversalBasicServicesSystem;
            part ai : Subsystems::ResourceAllocationAI;
            part community : Subsystems::CommunityEngagementSystem;

            attribute population : PopulationCount := 100000 [person];
            attribute overallWellbeing : WellbeingIndex := 0.82 [score];
            attribute demandSurgeDetected : Boolean := false;
            attribute maintenanceNeeded : Boolean := false;

            connection aiToServicesDirective connect ai.ctrlOut.directive to services.svcIn.directive;
            connection aiToCommunityDirective connect ai.ctrlOut.directive to community.commIn.directive;
            connection aiToProductionOrder connect ai.ctrlOut.order to production.prodIn.order;
            connection productionToServicesGoods connect production.prodOut.goods to services.svcIn.goods;
            connection productionToCommunityResources connect production.prodOut.resources to community.commIn.resources;
            connection servicesToAiMetrics connect services.citizen.metrics to ai.ctrlIn.metrics;
            connection communityToAiMetrics connect community.citizen.metrics to ai.ctrlIn.metrics;
            connection servicesToAiDemand connect services.citizen.demand to ai.ctrlIn.demand;
            connection communityToAiDemand connect community.citizen.demand to ai.ctrlIn.demand;

            state societyOperation {
                entry; then NormalOperation;
                state NormalOperation {
                    do { ai.monitorMetrics(); production.produceGoods(); services.assignHousing(); community.enableCollaboration(); }
                }
                transition from NormalOperation to AdaptiveScaling
                    when ai.demandForecast > production.productionRate;
                state AdaptiveScaling {
                    entry { production.productionRate := production.manufacturingFacilities.capacity; }
                    do { production.produceGoods(); ai.allocateResources(); }
                }
                transition from AdaptiveScaling to NormalOperation
                    when ai.demandForecast <= production.productionRate;
                transition from NormalOperation to MaintenanceMode
                    when production.sustainability < 0.6 [score];
                state MaintenanceMode {
                    entry { production.productionRate := 0 [units per day]; }
                    do { production.performMaintenance(); }
                }
                transition from MaintenanceMode to NormalOperation
                    when production.sustainability >= 0.8 [score];
            }
        }
    }

    package Requirements {

        requirement def SocietyRequirement {
            doc "The post-work society must autonomously manage all essential production and services, freeing humans from traditional labor.";
            attribute populationServed : PopulationCount;
        }

        requirement def ProductionRequirement {
            doc "Automated production must sustainably supply all necessary goods and basic resources for the entire population.";
            attribute minSustainability : SustainabilityIndex = 0.7 [score];
            attribute minProductionRate : ProductionRate = 1000 [units per day];
            attribute maxEnergyUse : EnergyConsumption = 10000 [kilowatt hour];
        }

        requirement def ServicesRequirement {
            doc "Universal basic services must meet the fundamental needs of every citizen without direct cost.";
            attribute housingCoverage : ResourceUtilizationRate = 100 [percent];
            attribute healthcareAvailability : HealthcareCapacity;
            attribute nutritionCoverage : ResourceUtilizationRate = 100 [percent];
            attribute educationAccess : ResourceUtilizationRate = 100 [percent];
        }

        requirement def AllocationRequirement {
            doc "The resource allocation AI must monitor wellbeing and intelligently allocate goods to maximize human welfare.";
            attribute targetWellbeing : WellbeingIndex = 0.9 [score];
            attribute maxUtilization : ResourceUtilizationRate = 95 [percent];
        }

        requirement def CommunityRequirement {
            doc "The community engagement system must provide infrastructure for creative, cultural, and collaborative fulfillment.";
            attribute minEngagement : CreativeEngagementLevel = 0.7 [score];
            attribute minWorkspaceCapacity : PopulationCount = 2000 [person];
        }

        requirement def AdaptationRequirement {
            doc "The society must dynamically adapt to demand surges via adaptive scaling and enter maintenance mode when sustainability drops.";
            attribute scalingFactor : Real = 1.5;
            attribute maintenanceThreshold : SustainabilityIndex = 0.6 [score];
        }

        requirement societyReq : SocietyRequirement {
            subject s : Society::PostWorkSocietySystem;
            attribute :>> populationServed = s.population;
        }

        requirement productionReq : ProductionRequirement {
            subject p : Subsystems::AutomatedProductionSystem;
            attribute :>> minProductionRate = p.productionRate;
        }

        requirement servicesReq : ServicesRequirement {
            subject sv : Subsystems::UniversalBasicServicesSystem;
            attribute :>> healthcareAvailability = sv.healthcareCapacity;
        }

        requirement allocationReq : AllocationRequirement {
            subject a : Subsystems::ResourceAllocationAI;
            attribute :>> targetWellbeing = a.populationWellbeing;
        }

        requirement communityReq : CommunityRequirement {
            subject c : Subsystems::CommunityEngagementSystem;
            attribute :>> minEngagement = c.creativeEngagement;
        }

        requirement adaptationReq : AdaptationRequirement {
            subject s : Society::PostWorkSocietySystem;
        }
    }
}
