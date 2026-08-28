package PostWorkSociety {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;

	attribute def DemandSurge;
	attribute def DemandStabilized;
	attribute def MaintenanceSchedule;
	attribute def MaintenanceDone;

	item def Goods {
		attribute kind : String;
		attribute quantity : Real;
		attribute unit : String;
	}

	item def HousingUnit {
		attribute unitId : String;
		attribute capacity : Integer;
		attribute location : String;
	}

	item def HealthcareService {
		attribute serviceType : String;
		attribute priority : Integer;
	}

	item def NutritionPackage {
		attribute calories : Real;
		attribute dietaryInfo : String;
	}

	item def EducationalResource {
		attribute resourceId : String;
		attribute field : String;
	}

	item def CreativeProject {
		attribute projectId : String;
		attribute domain : String;
		attribute participantCount : Integer;
	}

	item def CulturalEvent {
		attribute eventId : String;
		attribute venue : String;
		attribute attendeeCount : Integer;
	}

	attribute def WellbeingMetric {
		attribute physical : Real;
		attribute mental : Real;
		attribute social : Real;
		attribute creative : Real;
	}

	attribute def DemandForecast {
		attribute forecastLevel : Real;
		attribute timeHorizon : DurationValue;
	}

	port def GoodsPort {
		out goods : Goods;
	}

	port def ServicePort {
		in housingRequest : HousingUnit;
		out housingAssignment : HousingUnit;
		in healthcareRequest : HealthcareService;
		out healthcareProvision : HealthcareService;
		in nutritionRequest : NutritionPackage;
		out nutritionProvision : NutritionPackage;
		in educationRequest : EducationalResource;
		out educationProvision : EducationalResource;
	}

	port def MetricsPort {
		out metrics : WellbeingMetric;
	}

	port def AllocationPort {
		in metrics : WellbeingMetric;
		in utilization : Real;
		out goods : Goods;
		out forecast : DemandForecast;
		out directive : String;
	}

	port def CommunityPort {
		in goods : Goods;
		in collaborationRequest : CreativeProject;
		out creativeProject : CreativeProject;
		out culturalEvent : CulturalEvent;
		out metrics : WellbeingMetric;
	}

	part def AutomatedProductionSystem {
		part roboticManufacturing;
		part logisticsAutomation;
		part optimizer;
		port goodsOut : GoodsPort;
		port allocationIn : ~AllocationPort;
		attribute efficiency : Real = 0.95;
		attribute sustainabilityIndex : Real = 0.90;
		action produceGoods;
		action optimizeProduction;
	}

	part def UniversalBasicServicesSystem {
		part housing;
		part healthcare;
		part nutrition;
		part education;
		port goodsIn : ~GoodsPort;
		port servicePort : ServicePort;
		port metricsOut : MetricsPort;
		attribute serviceCapacity : Integer;
		action allocateHousing;
		action provideHealthcare;
		action distributeNutrition;
		action deliverEducation;
	}

	part def ResourceAllocationAI {
		port goodsIn : ~GoodsPort;
		port goodsOut : GoodsPort;
		port metricsIn : ~MetricsPort;
		port communityMetricsIn : ~MetricsPort;
		port allocationOut : AllocationPort;
		attribute populationWellbeing : WellbeingMetric;
		attribute resourceUtilization : Real;
		attribute demandForecast : DemandForecast;
		attribute demandThreshold : Real = 0.75;
		action monitorWellbeing;
		action forecastDemand;
		action calculateAllocation;
	}

	part def CommunityEngagementSystem {
		part creativeWorkspaces;
		part culturalVenues;
		part digitalNetworks;
		port goodsIn : ~GoodsPort;
		port communityPort : CommunityPort;
		port metricsOut : MetricsPort;
		attribute activeProjects : Integer;
		attribute culturalEventsScheduled : Integer;
		action facilitateCreativeWork;
		action hostCulturalEvent;
	}

	part def postWorkSociety {
		part production : AutomatedProductionSystem;
		part services : UniversalBasicServicesSystem;
		part allocationAI : ResourceAllocationAI;
		part community : CommunityEngagementSystem;

		connect production.goodsOut to allocationAI.goodsIn;
		connect allocationAI.goodsOut to services.goodsIn;
		connect allocationAI.goodsOut to community.goodsIn;
		connect services.metricsOut to allocationAI.metricsIn;
		connect community.metricsOut to allocationAI.communityMetricsIn;
		connect allocationAI.allocationOut to production.allocationIn;

		attribute maintenanceInterval : DurationValue = 720 [h];
		attribute scheduledMaintenanceTime : TimeInstantValue;

		action normalOperation {
			action monitorWellbeing;
			action forecastDemand;
			action optimizeProduction;
			action allocateHousing;
			action facilitateCreativeWork;
		}

		action adaptiveScalingOperation {
			action produceGoods;
			action calculateAllocation;
			action optimizeProduction;
		}

		action maintenanceOperation {
			action optimizeProduction;
			action monitorWellbeing;
		}

		state SocietyStates {
			entry; then normal;

			state normal {
				do normalOperation;
				accept DemandSurge then adaptiveScaling;
				accept MaintenanceSchedule then maintenance;
			}

			state adaptiveScaling {
				do adaptiveScalingOperation;
				accept DemandStabilized then normal;
			}

			state maintenance {
				do maintenanceOperation;
				accept MaintenanceDone then normal;
				accept after 48 [h] then normal;
			}
		}
	}

	requirement def SustainableOperation {
		subject society : postWorkSociety;
		constraint { society.allocationAI.resourceUtilization <= 1.0 }
	}

	requirement def MaxWellbeing {
		subject society : postWorkSociety;
		constraint { society.allocationAI.populationWellbeing.physical >= 0.8 }
		constraint { society.allocationAI.populationWellbeing.mental >= 0.8 }
		constraint { society.allocationAI.populationWellbeing.social >= 0.8 }
		constraint { society.allocationAI.populationWellbeing.creative >= 0.8 }
	}

	requirement def EfficientProduction {
		subject society : postWorkSociety;
		constraint { society.production.efficiency >= 0.9 }
	}

	requirement def UniversalAccess {
		subject society : postWorkSociety;
		constraint { society.services.serviceCapacity >= 1000 }
	}

	requirement def CommunityFulfillment {
		subject society : postWorkSociety;
		constraint { society.community.activeProjects >= 100 }
	}
}
