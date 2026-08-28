package 'Comilla District Governance System' {
	private import ScalarValues::*;

	package Definitions {
		attribute def PopulationCount :> Integer;
		attribute def BudgetAmount :> Real;
		attribute def PerformanceScore :> Real;
		attribute def EmploymentRatePct :> Real;
		attribute def FoodProductionTons :> Real;
		attribute def StudentCount :> Integer;
		attribute def PatientCount :> Integer;
		attribute def RoadLengthKm :> Real;
		attribute def LandAreaHectares :> Real;

		item def NeedsAssessment;
		item def BudgetAllocation;
		item def PerformanceReport;
		item def PolicyDirective;
		item def ServiceRequest;
		item def ServiceResponse;

		port def CoordinationPort {
			in budgetAllocation : BudgetAllocation;
			in policyDirective : PolicyDirective;
			out needsAssessment : NeedsAssessment;
			out performanceReport : PerformanceReport;
		}

		port def CitizenPort {
			in serviceRequest : ServiceRequest;
			out serviceResponse : ServiceResponse;
		}

		part def DistrictAdministration {
			attribute districtName : String;
			attribute totalPopulation : PopulationCount;
			attribute annualBudget : BudgetAmount;
			port coordinationPort : ~CoordinationPort;
		}

		part def LocalAdministration {
			attribute upazilaName : String;
			port citizenPort : ~CitizenPort;
		}

		part def ServiceCenter {
			port citizenPort : ~CitizenPort;
		}

		part def Upazila {
			attribute upazilaName : String;
			attribute upazilaPopulation : PopulationCount;
			part localAdministration : LocalAdministration;
			part serviceCenter : ServiceCenter;
			port citizenPort : ~CitizenPort;
		}

		part def Hospital {
			attribute capacity : PatientCount;
			port citizenPort : CitizenPort;
		}

		part def HealthCenter {
			attribute capacity : PatientCount;
			port citizenPort : CitizenPort;
		}

		part def MedicalStaff {
			attribute staffCount : Integer;
		}

		part def HealthcareSystem {
			attribute totalPatients : PatientCount;
			part hospitals : Hospital[*];
			part healthCenters : HealthCenter[*];
			part medicalStaff : MedicalStaff[*];
			port coordinationPort : CoordinationPort;
			port citizenPort : CitizenPort;
		}

		part def PrimarySchool {
			attribute enrollment : StudentCount;
			port citizenPort : CitizenPort;
		}

		part def SecondarySchool {
			attribute enrollment : StudentCount;
			port citizenPort : CitizenPort;
		}

		part def College {
			attribute enrollment : StudentCount;
			port citizenPort : CitizenPort;
		}

		part def Teacher {
			attribute teacherCount : Integer;
		}

		part def EducationSystem {
			attribute totalStudents : StudentCount;
			part primarySchools : PrimarySchool[*];
			part secondarySchools : SecondarySchool[*];
			part colleges : College[*];
			part teachers : Teacher[*];
			port coordinationPort : CoordinationPort;
			port citizenPort : CitizenPort;
		}

		part def Road {
			attribute length : RoadLengthKm;
		}

		part def Bridge {
			attribute length : RoadLengthKm;
		}

		part def RailwayStation;
		part def BusTerminal;

		part def TransportationNetwork {
			attribute totalRoadLength : RoadLengthKm;
			part roads : Road[*];
			part bridges : Bridge[*];
			part railwayStations : RailwayStation[*];
			part busTerminals : BusTerminal[*];
			port coordinationPort : CoordinationPort;
		}

		part def AgriculturalSector {
			attribute cultivableLand : LandAreaHectares;
			attribute farmingPopulation : PopulationCount;
			attribute annualFoodProduction : FoodProductionTons;
			port coordinationPort : CoordinationPort;
			port citizenPort : CitizenPort;
		}

		part def IndustrialZone {
			attribute zoneArea : LandAreaHectares;
		}

		part def EconomicDevelopmentOffice {
			attribute targetEmploymentRate : EmploymentRatePct;
			attribute currentEmploymentRate : EmploymentRatePct;
			part industrialZones : IndustrialZone[*];
			port coordinationPort : CoordinationPort;
		}

		part def ComillaDistrict {
			attribute districtName : String;
			attribute totalPopulation : PopulationCount;
			attribute upazilaCount : Integer;
			part districtAdministration : DistrictAdministration;
			part healthcareSystem : HealthcareSystem;
			part educationSystem : EducationSystem;
			part transportationNetwork : TransportationNetwork;
			part agriculturalSector : AgriculturalSector;
			part economicDevelopmentOffice : EconomicDevelopmentOffice;
			part upazilas : Upazila[*];
		}
	}

	package Behaviors {
		private import Definitions::*;

		action def AssessNeeds {
			out needsAssessment : NeedsAssessment;
		}

		action def PlanAndAllocate {
			in needsAssessment : NeedsAssessment;
			out budgetAllocation : BudgetAllocation;
			out policyDirective : PolicyDirective;
		}

		action def DeliverServices {
			in budgetAllocation : BudgetAllocation;
			in policyDirective : PolicyDirective;
			out performanceReport : PerformanceReport;
		}

		action def MonitorPerformance {
			in performanceReport : PerformanceReport;
			out performanceScore : PerformanceScore;
			out adjustedStrategy : PolicyDirective;
		}

		action def AdjustStrategy {
			in adjustedStrategy : PolicyDirective;
		}

		action def GovernanceCycle {
			first start;
			then merge continueCycle;
			then action assess : AssessNeeds {
				out needsAssessmentOut : NeedsAssessment;
			}
			then action plan : PlanAndAllocate {
				in needsAssessment = assess.needsAssessmentOut;
				out budgetAllocationOut : BudgetAllocation;
				out policyDirectiveOut : PolicyDirective;
			}
			then action deliver : DeliverServices {
				in budgetAllocation = plan.budgetAllocationOut;
				in policyDirective = plan.policyDirectiveOut;
				out performanceReportOut : PerformanceReport;
			}
			then action monitor : MonitorPerformance {
				in performanceReport = deliver.performanceReportOut;
				out performanceScoreOut : PerformanceScore;
				out adjustedStrategyOut : PolicyDirective;
			}
			then decide;
				if monitor.performanceScoreOut < 100 then adjustStrategy;
				if monitor.performanceScoreOut >= 100 then continueCycle;
			action adjustStrategy : AdjustStrategy {
				in adjustedStrategy = monitor.adjustedStrategyOut;
			}
			then continueCycle;
		}

		state def GovernanceStates {
			in district : ComillaDistrict;
			entry; then assessing;
			state assessing;
			accept NeedsAssessment then planning;
			state planning;
			accept BudgetAllocation then delivering;
			state delivering;
			accept PerformanceReport then monitoring;
			state monitoring;
			accept PolicyDirective then assessing;
		}
	}

	package Requirements {
		private import Definitions::*;

		requirement def DistrictGovernanceRequirement {
			doc
			/*
			 * The system shall manage public services for Comilla District
			 * with a population exceeding 6 million people.
			 */
		}

		requirement def BudgetAllocationRequirement :> DistrictGovernanceRequirement {
			doc
			/*
			 * The District Administration shall allocate its annual budget
			 * across all public service sectors.
			 */
		}

		requirement def ServiceDeliveryRequirement :> DistrictGovernanceRequirement {
			doc
			/*
			 * Each sector shall deliver services to citizens across all
			 * 17 Upazilas of the district.
			 */
		}

		requirement def PerformanceMonitoringRequirement :> DistrictGovernanceRequirement {
			doc
			/*
			 * The District Administration shall monitor sector performance
			 * and adjust strategies when targets are not met.
			 */
		}

		requirement def HealthcareServiceRequirement :> ServiceDeliveryRequirement {
			doc
			/*
			 * The Healthcare System shall provide medical services through
			 * hospitals and health centers to the entire district population.
			 */
		}

		requirement def EducationServiceRequirement :> ServiceDeliveryRequirement {
			doc
			/*
			 * The Education System shall provide educational services through
			 * primary schools, secondary schools, and colleges.
			 */
		}

		requirement def TransportationServiceRequirement :> ServiceDeliveryRequirement {
			doc
			/*
			 * The Transportation Network shall ensure mobility of people
			 * and goods via roads, bridges, railway stations, and bus terminals.
			 */
		}

		requirement def AgriculturalSupportRequirement :> ServiceDeliveryRequirement {
			doc
			/*
			 * The Agricultural Sector shall support the farming population
			 * through irrigation and subsidies, and manage annual food production.
			 */
		}

		requirement def EconomicDevelopmentRequirement :> ServiceDeliveryRequirement {
			doc
			/*
			 * The Economic Development Office shall foster growth by managing
			 * industrial zones and working to improve the employment rate.
			 */
		}
	}

	package Usages {
		private import Definitions::*;
		private import Behaviors::*;
		private import Requirements::*;

		part comillaDistrict : ComillaDistrict {
			attribute districtName = "Comilla";
			attribute totalPopulation = 6000000;
			attribute upazilaCount = 17;

			part districtAdministration : DistrictAdministration {
				attribute districtName = "Comilla";
				attribute totalPopulation = 6000000;
				attribute annualBudget = 5000000000.0;
				port coordinationPort : ~CoordinationPort;
			}

			part healthcareSystem : HealthcareSystem {
				attribute totalPatients = 6000000;
				port coordinationPort : CoordinationPort;
				port citizenPort : CitizenPort;
			}

			part educationSystem : EducationSystem {
				attribute totalStudents = 1500000;
				port coordinationPort : CoordinationPort;
				port citizenPort : CitizenPort;
			}

			part transportationNetwork : TransportationNetwork {
				attribute totalRoadLength = 5000.0;
				port coordinationPort : CoordinationPort;
			}

			part agriculturalSector : AgriculturalSector {
				attribute cultivableLand = 250000.0;
				attribute farmingPopulation = 2000000;
				attribute annualFoodProduction = 3000000.0;
				port coordinationPort : CoordinationPort;
				port citizenPort : CitizenPort;
			}

			part economicDevelopmentOffice : EconomicDevelopmentOffice {
				attribute targetEmploymentRate = 95.0;
				attribute currentEmploymentRate = 75.0;
				port coordinationPort : CoordinationPort;
			}

			connect districtAdministration.coordinationPort to healthcareSystem.coordinationPort;
			connect districtAdministration.coordinationPort to educationSystem.coordinationPort;
			connect districtAdministration.coordinationPort to transportationNetwork.coordinationPort;
			connect districtAdministration.coordinationPort to agriculturalSector.coordinationPort;
			connect districtAdministration.coordinationPort to economicDevelopmentOffice.coordinationPort;

			part upazila_barura : Upazila {
				attribute upazilaName = "Barura";
				attribute upazilaPopulation = 350000;
				part localAdministration : LocalAdministration {
					attribute upazilaName = "Barura";
				}
				part serviceCenter : ServiceCenter;
			}

			part upazila_chandina : Upazila {
				attribute upazilaName = "Chandina";
				attribute upazilaPopulation = 400000;
				part localAdministration : LocalAdministration {
					attribute upazilaName = "Chandina";
				}
				part serviceCenter : ServiceCenter;
			}

			part upazila_daudkandi : Upazila {
				attribute upazilaName = "Daudkandi";
				attribute upazilaPopulation = 500000;
				part localAdministration : LocalAdministration {
					attribute upazilaName = "Daudkandi";
				}
				part serviceCenter : ServiceCenter;
			}

			perform governanceCycle : GovernanceCycle;
		}

		requirement districtGovernanceReq : DistrictGovernanceRequirement;
		requirement budgetAllocationReq : BudgetAllocationRequirement;
		requirement serviceDeliveryReq : ServiceDeliveryRequirement;
		requirement performanceMonitoringReq : PerformanceMonitoringRequirement;
		requirement healthcareReq : HealthcareServiceRequirement;
		requirement educationReq : EducationServiceRequirement;
		requirement transportationReq : TransportationServiceRequirement;
		requirement agricultureReq : AgriculturalSupportRequirement;
		requirement econDevReq : EconomicDevelopmentRequirement;

		satisfy districtGovernanceReq by comillaDistrict;
		satisfy budgetAllocationReq by comillaDistrict.districtAdministration;
		satisfy performanceMonitoringReq by comillaDistrict.districtAdministration;
		satisfy healthcareReq by comillaDistrict.healthcareSystem;
		satisfy educationReq by comillaDistrict.educationSystem;
		satisfy transportationReq by comillaDistrict.transportationNetwork;
		satisfy agricultureReq by comillaDistrict.agriculturalSector;
		satisfy econDevReq by comillaDistrict.economicDevelopmentOffice;
	}

	public import Definitions::*;
	public import Behaviors::*;
}
