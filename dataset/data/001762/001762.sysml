package 'Comilla District System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PopulationCount :> Real;
    attribute def AreaMeasure :> AreaValue;
    attribute def BudgetAmount :> Real;
    attribute def ServiceCoveragePercent :> Real;
    attribute def EfficiencyRating :> Real;
    
    attribute def UpazilaName :> String;
    attribute def ServiceCategory :> String;
    attribute def ResourceType :> String;
    
    item def Citizen {
        attribute citizenID : String;
        attribute age : Real;
        attribute location : UpazilaName;
    }
    
    item def PublicService {
        attribute serviceType : ServiceCategory;
        attribute deliveryDate : String;
        attribute beneficiaryCount : PopulationCount;
    }
    
    item def Resource {
        attribute resourceType : ResourceType;
        attribute quantity : Real;
        attribute allocatedTo : UpazilaName;
    }
    
    item def InfrastructureProject {
        attribute projectID : String;
        attribute budget : BudgetAmount;
        attribute completionPercent : Real;
    }
    
    port def ServiceDeliveryPort {
        in item serviceRequests : PublicService[*];
        out item deliveredServices : PublicService[*];
    }
    
    port def ResourceAllocationPort {
        in item resourceRequests : Resource[*];
        out item allocatedResources : Resource[*];
    }
    
    port def CoordinationPort {
        inout item coordinationData[*];
        inout item performanceMetrics[*];
    }
    
    part def Upazila {
        attribute name : UpazilaName;
        attribute population : PopulationCount;
        attribute area : AreaMeasure;
        attribute localBudget : BudgetAmount;
        
        port servicePort : ServiceDeliveryPort;
        port resourcePort : ResourceAllocationPort;
        
        part localAdministration {
            attribute staffCount : Real;
        }
        
        part serviceCenter {
            perform action deliverLocalServices;
        }
    }
    
    part def DistrictAdministration {
        attribute totalBudget : BudgetAmount;
        attribute allocatedBudget : BudgetAmount;
        attribute operationalEfficiency : EfficiencyRating;
        
        port coordination : CoordinationPort;
        
        action def PlanResourceAllocation {
            in totalAvailable : BudgetAmount;
            in upazilaNeeds : BudgetAmount[*];
            out allocationPlan : BudgetAmount[*];
        }
        
        action def MonitorPerformance {
            in serviceMetrics[*];
            out performanceReport : EfficiencyRating;
        }
        
        action def CoordinateUpazilas {
            in upazilaReports[*];
            out directives[*];
        }
    }
    
    part def HealthcareSystem {
        attribute hospitalCount : Real;
        attribute healthCenterCount : Real;
        attribute medicalStaff : PopulationCount;
        attribute patientCapacity : PopulationCount;
        
        port healthServices : ServiceDeliveryPort;
        
        action def ProvideHealthcare {
            in patientDemand : PopulationCount;
            in availableStaff : PopulationCount;
            in medicalSupplies : Real;
            out patientsTreated : PopulationCount;
            out serviceCoverage : ServiceCoveragePercent;
        }
    }
    
    part def EducationSystem {
        attribute primarySchools : Real;
        attribute secondarySchools : Real;
        attribute colleges : Real;
        attribute teachers : PopulationCount;
        attribute studentCapacity : PopulationCount;
        
        port educationServices : ServiceDeliveryPort;
        
        action def ProvideEducation {
            in eligibleStudents : PopulationCount;
            in availableTeachers : PopulationCount;
            in infrastructure : Real;
            out enrolledStudents : PopulationCount;
            out literacyRate : Real;
        }
    }
    
    part def TransportationNetwork {
        attribute roadLength : LengthValue;
        attribute bridgeCount : Real;
        attribute railwayStations : Real;
        attribute busTerminals : Real;
        
        port transportServices : ServiceDeliveryPort;
        
        action def FacilitateTransport {
            in dailyCommuters : PopulationCount;
            in vehicleCapacity : Real;
            in roadCondition : EfficiencyRating;
            out mobilityIndex : Real;
            out accessibilityScore : Real;
        }
    }
    
    part def AgriculturalSector {
        attribute cultivableLand : AreaMeasure;
        attribute farmers : PopulationCount;
        attribute irrigationCoverage : AreaMeasure;
        attribute annualProduction : MassValue;
        
        port agriculturalServices : ServiceDeliveryPort;
        
        action def SupportAgriculture {
            in farmingPopulation : PopulationCount;
            in irrigatedArea : AreaMeasure;
            in subsidyAmount : BudgetAmount;
            out cropYield : MassValue;
            out farmerIncome : BudgetAmount;
        }
    }
    
    part def EconomicDevelopmentOffice {
        attribute industrialZones : Real;
        attribute registeredBusinesses : Real;
        attribute employmentRate : Real;
        
        port economicServices : ServiceDeliveryPort;
        
        action def PromoteEconomicGrowth {
            in investmentFunds : BudgetAmount;
            in businessIncentives : Real;
            out jobsCreated : PopulationCount;
            out gdpGrowth : Real;
        }
    }
    
    action def ManageDistrictOperations {
        in districtPopulation : PopulationCount;
        in annualBudget : BudgetAmount;
        in upazilaCount : Real;
        out overallWelfare : EfficiencyRating;
        out developmentIndex : Real;
        
        first start;
        then merge operationCycle;
        
        action assessDistrictNeeds {
            in population : PopulationCount;
            in upazilas : Real;
            out healthNeeds : PopulationCount;
            out educationNeeds : PopulationCount;
            out infrastructureNeeds : Real;
            out economicNeeds : BudgetAmount;
        }
        
        then action planAllocation : DistrictAdministration::PlanResourceAllocation {
            in totalAvailable = annualBudget;
            out allocationPlan;
        }
        
        then decide;
            if planAllocation.allocationPlan->notEmpty() then distributeResources;
        
        action distributeResources {
            action allocateHealthBudget {
                in healthAllocation : BudgetAmount;
                out healthFunding : BudgetAmount;
            }
            action allocateEducationBudget {
                in educationAllocation : BudgetAmount;
                out educationFunding : BudgetAmount;
            }
            action allocateInfrastructureBudget {
                in infrastructureAllocation : BudgetAmount;
                out infrastructureFunding : BudgetAmount;
            }
            action allocateEconomicBudget {
                in economicAllocation : BudgetAmount;
                out economicFunding : BudgetAmount;
            }
        }
        
        then merge deliverServices;
        
        action deliverServices {
            action provideHealthServices : HealthcareSystem::ProvideHealthcare;
            action provideEducationServices : EducationSystem::ProvideEducation;
            action maintainTransportation : TransportationNetwork::FacilitateTransport;
            action supportFarming : AgriculturalSector::SupportAgriculture;
            action developEconomy : EconomicDevelopmentOffice::PromoteEconomicGrowth;
        }
        
        then action monitorAndEvaluate : DistrictAdministration::MonitorPerformance {
            out performanceReport;
        }
        
        then decide;
            if monitorAndEvaluate.performanceReport < 0.7 then adjustStrategies;
            if monitorAndEvaluate.performanceReport >= 0.7 then operationCycle;
        
        action adjustStrategies {
            in currentPerformance : EfficiencyRating;
            out revisedPlan[*];
        }
        
        then operationCycle;
    }
    
    part comillaDistrict {
        doc /* 
            Comilla District is an administrative region in Bangladesh that coordinates 
            governance, public services, and development across 17 upazilas. The system 
            manages healthcare, education, transportation, agriculture, and economic 
            development to ensure citizen welfare and sustainable regional growth.
        */
        
        attribute districtName : String = "Comilla";
        attribute totalPopulation : PopulationCount = 6029000.0;
        attribute totalArea : AreaMeasure = 3146.0 [km^2];
        attribute annualBudget : BudgetAmount = 500000000.0;
        
        port districtCoordination : CoordinationPort;
        
        part administration : DistrictAdministration {
            totalBudget = comillaDistrict.annualBudget;
            perform comillaDistrict::operations.planAllocation;
            perform comillaDistrict::operations.monitorAndEvaluate;
        }
        
        part baruraUpazila : Upazila {
            name = "Barura";
            population = 280000.0;
            area = 168.0 [km^2];
        }
        
        part brahmanparaUpazila : Upazila {
            name = "Brahmanpara";
            population = 190000.0;
            area = 182.0 [km^2];
        }
        
        part burichongUpazila : Upazila {
            name = "Burichong";
            population = 310000.0;
            area = 251.0 [km^2];
        }
        
        part chandinaUpazila : Upazila {
            name = "Chandina";
            population = 380000.0;
            area = 257.0 [km^2];
        }
        
        part chauddagramUpazila : Upazila {
            name = "Chauddagram";
            population = 420000.0;
            area = 254.0 [km^2];
        }
        
        part daudkandiUpazila : Upazila {
            name = "Daudkandi";
            population = 290000.0;
            area = 222.0 [km^2];
        }
        
        part debidwarUpazila : Upazila {
            name = "Debidwar";
            population = 360000.0;
            area = 334.0 [km^2];
        }
        
        part homnaUpazila : Upazila {
            name = "Homna";
            population = 340000.0;
            area = 239.0 [km^2];
        }
        
        part lakshamUpazila : Upazila {
            name = "Laksham";
            population = 270000.0;
            area = 141.0 [km^2];
        }
        
        part muradnagarUpazila : Upazila {
            name = "Muradnagar";
            population = 410000.0;
            area = 315.0 [km^2];
        }
        
        part nangalkotUpazila : Upazila {
            name = "Nangalkot";
            population = 320000.0;
            area = 207.0 [km^2];
        }
        
        part comillaSadarUpazila : Upazila {
            name = "Comilla Sadar";
            population = 580000.0;
            area = 177.0 [km^2];
        }
        
        part meghnaUpazila : Upazila {
            name = "Meghna";
            population = 240000.0;
            area = 112.0 [km^2];
        }
        
        part monoharganjUpazila : Upazila {
            name = "Monoharganj";
            population = 260000.0;
            area = 157.0 [km^2];
        }
        
        part sadarDakshinUpazila : Upazila {
            name = "Sadar Dakshin";
            population = 350000.0;
            area = 165.0 [km^2];
        }
        
        part titumirupazila : Upazila {
            name = "Titumir";
            population = 230000.0;
            area = 142.0 [km^2];
        }
        
        part lalmaiUpazila : Upazila {
            name = "Lalmai";
            population = 309000.0;
            area = 123.0 [km^2];
        }
        
        part healthcare : HealthcareSystem {
            hospitalCount = 12.0;
            healthCenterCount = 85.0;
            medicalStaff = 3500.0;
            patientCapacity = 8000.0;
            perform comillaDistrict::operations.deliverServices.provideHealthServices;
        }
        
        part education : EducationSystem {
            primarySchools = 1850.0;
            secondarySchools = 420.0;
            colleges = 65.0;
            teachers = 28000.0;
            studentCapacity = 1200000.0;
            perform comillaDistrict::operations.deliverServices.provideEducationServices;
        }
        
        part transportation : TransportationNetwork {
            roadLength = 2800.0 [km];
            bridgeCount = 145.0;
            railwayStations = 8.0;
            busTerminals = 17.0;
            perform comillaDistrict::operations.deliverServices.maintainTransportation;
        }
        
        part agriculture : AgriculturalSector {
            cultivableLand = 2450.0 [km^2];
            farmers = 1800000.0;
            irrigationCoverage = 1650.0 [km^2];
            annualProduction = 2500000.0 [tonne];
            perform comillaDistrict::operations.deliverServices.supportFarming;
        }
        
        part economicDevelopment : EconomicDevelopmentOffice {
            industrialZones = 5.0;
            registeredBusinesses = 12500.0;
            employmentRate = 0.68;
            perform comillaDistrict::operations.deliverServices.developEconomy;
        }
        
        action operations : ManageDistrictOperations {
            in districtPopulation = comillaDistrict.totalPopulation;
            in annualBudget = comillaDistrict.annualBudget;
            in upazilaCount = 17.0;
            out overallWelfare;
            out developmentIndex;
        }
        
        connection adminToHealth connect administration.coordination to healthcare.healthServices;
        connection adminToEducation connect administration.coordination to education.educationServices;
        connection adminToTransport connect administration.coordination to transportation.transportServices;
        connection adminToAgriculture connect administration.coordination to agriculture.agriculturalServices;
        connection adminToEconomic connect administration.coordination to economicDevelopment.economicServices;
    }
    
    requirement districtGovernanceRequirement {
        doc /* 
            The Comilla District system shall effectively coordinate administrative 
            functions, deliver essential public services, and promote sustainable 
            development across all 17 upazilas to ensure citizen welfare and 
            regional prosperity.
        */
        
        subject comillaDistrict;
        
        require serviceDeliveryRequirement;
        require resourceManagementRequirement;
        require developmentRequirement;
    }
    
    requirement serviceDeliveryRequirement {
        doc /* 
            All essential public services including healthcare, education, 
            transportation, and agricultural support shall be delivered 
            effectively to citizens across all upazilas.
        */
    }
    
    requirement resourceManagementRequirement {
        doc /* 
            District resources shall be allocated efficiently and equitably 
            across all sectors and upazilas based on population needs and 
            development priorities.
        */
    }
    
    requirement developmentRequirement {
        doc /* 
            The district shall achieve measurable progress in economic development, 
            infrastructure improvement, and quality of life indicators.
        */
    }
}
