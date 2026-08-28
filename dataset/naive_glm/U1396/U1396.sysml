package ComillaDistrictGovernance {

    // ---- Value types with units ----
    value type PopulationCount > ScalarValues::Integer {
        doc { "Number of persons." }
        unit person;
    }

    value type BudgetAmount > ScalarValues::Real {
        doc { "Monetary amount in Bangladeshi Taka." }
        unit BDT;
    }

    value type AreaMeasure > ScalarValues::Real {
        doc { "Area in square kilometers." }
        unit 'km^2';
    }

    value type PerformanceScore > ScalarValues::Real {
        doc { "Performance score as a percentage." }
        unit percent;
    }

    value type EmploymentRate > ScalarValues::Real {
        doc { "Employment rate as a percentage." }
        unit percent;
    }

    value type FoodProductionQty > ScalarValues::Real {
        doc { "Annual food production in metric tons." }
        unit 't';
    }

    value type IrrigationCoverage > ScalarValues::Real {
        doc { "Irrigated cultivable land area in hectares." }
        unit ha;
    }

    value type PatientCount > ScalarValues::Integer {
        doc { "Number of patients treated." }
        unit patient;
    }

    value type StudentCount > ScalarValues::Integer {
        doc { "Number of enrolled students." }
        unit student;
    }

    value type RoadLength > ScalarValues::Real {
        doc { "Road length in kilometers." }
        unit km;
    }

    value type TargetThreshold > ScalarValues::Real {
        doc { "Minimum acceptable performance percentage." }
        unit percent;
    }

    // ---- Item types ----
    item def Citizen {
        attribute age : ScalarValues::Integer;
        attribute upazilaOfResidence : String;
    }

    item def Patient :> Citizen {
        attribute ailment : String;
    }

    item def Student :> Citizen {
        attribute gradeLevel : String;
    }

    item def Farmer :> Citizen {
        attribute landOwned : AreaMeasure;
    }

    item def Crop {
        attribute name : String;
        attribute annualYield : FoodProductionQty;
    }

    item def Vehicle {
        attribute registrationId : String;
        attribute capacityKg : ScalarValues::Real;
    }

    item def BudgetAllocation {
        attribute fiscalYear : String;
        attribute amount : BudgetAmount;
        attribute sector : String;
    }

    item def NeedsAssessment {
        attribute fiscalYear : String;
        attribute healthcareDemand : PatientCount;
        attribute educationDemand : StudentCount;
        attribute transportDemand : RoadLength;
        attribute irrigationDemand : IrrigationCoverage;
        attribute employmentTarget : EmploymentRate;
    }

    item def PerformanceReport {
        attribute fiscalYear : String;
        attribute sector : String;
        attribute score : PerformanceScore;
        attribute targetMet : ScalarValues::Boolean;
    }

    // ---- Port definitions ----
    port def CoordinationPort {
        in item allocations : BudgetAllocation;
        out item reports : PerformanceReport;
    }

    port def NeedsPort {
        out item assessment : NeedsAssessment;
    }

    port def ServiceDeliveryPort {
        in item citizens : Citizen;
        out item servicedCitizens : Citizen;
    }

    // ---- Part definitions ----
    part def DistrictAdministration {
        attribute districtName : String = "Comilla";
        attribute totalPopulation : PopulationCount = 6000000;
        attribute annualBudget : BudgetAmount;

        port coordinationOut : CoordinationPort;
        port needsIn : NeedsPort;

        part planningTeam {
            attribute strategicPlan : String;
            attribute allocatedBudget : BudgetAmount;
        }

        part monitoringTeam {
            attribute collectedReports : PerformanceReport[*];
        }

        action assessNeeds : NeedsAssessment;
        action planAndAllocate(in needs : NeedsAssessment) : BudgetAllocation[*];
        action monitorPerformance(in reports : PerformanceReport[*]) : PerformanceScore[*];
        action adjustStrategy(in scores : PerformanceScore[*]) : String;

        exhibit state GovernanceCycle {
            entry;
            state AssessingNeeds {
                entry action { perform assessNeeds; }
            }
            state PlanningAndAllocating {
                entry action { perform planAndAllocate; }
            }
            state DeliveringServices;
            state MonitoringPerformance {
                entry action { perform monitorPerformance; }
            }
            state AdjustingStrategy {
                entry action { perform adjustStrategy; }
            }
            transition AssessingNeeds -> PlanningAndAllocating;
            transition PlanningAndAllocating -> DeliveringServices;
            transition DeliveringServices -> MonitoringPerformance;
            transition MonitoringPerformance -> AdjustingStrategy {
                guard 'targetsNotMet';
            }
            transition AdjustingStrategy -> AssessingNeeds;
            transition MonitoringPerformance -> AssessingNeeds {
                guard 'targetsMet';
            }
        }
    }

    part def Upazila {
        attribute name : String;
        attribute population : PopulationCount;
        attribute area : AreaMeasure;
        attribute localAdministration : String;

        port serviceDelivery : ServiceDeliveryPort;

        part localHealthCenter;
        part localSchoolCluster;
        part localMarket;
    }

    part def HealthcareSystem {
        attribute hospitalsCount : ScalarValues::Integer;
        attribute healthCentersCount : ScalarValues::Integer;
        attribute medicalStaffCount : PopulationCount;

        port coordination : CoordinationPort;
        port delivery : ServiceDeliveryPort;

        action provideMedicalServices(in patients : Patient[*]) : Patient[*];
        action managePatientCare(in allocation : BudgetAllocation) : PerformanceReport;

        exhibit state HealthcareOperation {
            state Operational;
            state OverCapacity {
                guard 'patientLoad > capacity';
            }
            state EmergencyResponse;
            transition Operational -> OverCapacity;
            transition OverCapacity -> EmergencyResponse;
            transition EmergencyResponse -> Operational;
        }
    }

    part def EducationSystem {
        attribute primarySchoolsCount : ScalarValues::Integer;
        attribute secondarySchoolsCount : ScalarValues::Integer;
        attribute collegesCount : ScalarValues::Integer;
        attribute teachersCount : PopulationCount;

        port coordination : CoordinationPort;
        port delivery : ServiceDeliveryPort;

        action deliverEducation(in students : Student[*]) : Student[*];
        action manageInfrastructure(in allocation : BudgetAllocation) : PerformanceReport;

        exhibit state AcademicCycle {
            state Enrollment;
            state Instruction;
            state Examination;
            transition Enrollment -> Instruction;
            transition Instruction -> Examination;
            transition Examination -> Enrollment;
        }
    }

    part def TransportationNetwork {
        attribute totalRoadLength : RoadLength;
        attribute bridgesCount : ScalarValues::Integer;
        attribute railwayStationsCount : ScalarValues::Integer;
        attribute busTerminalsCount : ScalarValues::Integer;

        port coordination : CoordinationPort;
        port delivery : ServiceDeliveryPort;

        action ensureMobility(in vehicles : Vehicle[*]) : Vehicle[*];
        action maintainInfrastructure(in allocation : BudgetAllocation) : PerformanceReport;

        exhibit state NetworkOperation {
            state NormalFlow;
            state Congested;
            state UnderMaintenance;
            transition NormalFlow -> Congested;
            transition Congested -> NormalFlow;
            transition NormalFlow -> UnderMaintenance;
            transition UnderMaintenance -> NormalFlow;
        }
    }

    part def AgriculturalSector {
        attribute cultivableLand : AreaMeasure;
        attribute farmingPopulation : PopulationCount;
        attribute irrigationCoverage : IrrigationCoverage;
        attribute annualFoodProduction : FoodProductionQty;

        port coordination : CoordinationPort;
        port delivery : ServiceDeliveryPort;

        action supportFarmers(in farmers : Farmer[*]) : Farmer[*];
        action manageIrrigationAndSubsidies(in allocation : BudgetAllocation) : PerformanceReport;
        action harvestCrops : Crop[*];

        exhibit state CropCycle {
            state Sowing;
            state Irrigating;
            state Harvesting;
            transition Sowing -> Irrigating;
            transition Irrigating -> Harvesting;
            transition Harvesting -> Sowing;
        }
    }

    part def EconomicDevelopmentOffice {
        attribute industrialZonesCount : ScalarValues::Integer;
        attribute registeredBusinessesCount : ScalarValues::Integer;
        attribute currentEmploymentRate : EmploymentRate;

        port coordination : CoordinationPort;
        port delivery : ServiceDeliveryPort;

        action fosterGrowth(in allocation : BudgetAllocation) : PerformanceReport;
        action supportBusinesses(in citizens : Citizen[*]) : Citizen[*];

        exhibit state EconomicCycle {
            state Assessing;
            state Investing;
            state Evaluating;
            transition Assessing -> Investing;
            transition Investing -> Evaluating;
            transition Evaluating -> Assessing;
        }
    }

    part def ComillaDistrict {
        attribute districtName : String = "Comilla";
        attribute totalPopulation : PopulationCount = 6000000;
        attribute numberOfUpazilas : ScalarValues::Integer = 17;

        part administration : DistrictAdministration;

        part upazilas : Upazila[*] {
            part barura : Upazila {
                attribute name = "Barura";
            }
            part chandina : Upazila {
                attribute name = "Chandina";
            }
            part daudkandi : Upazila {
                attribute name = "Daudkandi";
            }
        }

        part healthcare : HealthcareSystem;
        part education : EducationSystem;
        part transportation : TransportationNetwork;
        part agriculture : AgriculturalSector;
        part economicDevelopment : EconomicDevelopmentOffice;

        connection adminToHealthcare connect administration.coordinationOut to healthcare.coordination;
        connection adminToEducation connect administration.coordinationOut to education.coordination;
        connection adminToTransportation connect administration.coordinationOut to transportation.coordination;
        connection adminToAgriculture connect administration.coordinationOut to agriculture.coordination;
        connection adminToEconomic connect administration.coordinationOut to economicDevelopment.coordination;

        connection healthcareToUpazilas connect healthcare.delivery to upazilas.serviceDelivery;
        connection educationToUpazilas connect education.delivery to upazilas.serviceDelivery;
        connection transportationToUpazilas connect transportation.delivery to upazilas.serviceDelivery;
        connection agricultureToUpazilas connect agriculture.delivery to upazilas.serviceDelivery;
        connection economicToUpazilas connect economicDevelopment.delivery to upazilas.serviceDelivery;
    }

    // ---- Requirements ----
    requirement def GovernanceRequirement {
        subject district : ComillaDistrict;
        objective {
            doc { "The district shall ensure well-being and development of its population exceeding 6 million." }
        }
    }

    requirement DistrictPopulationGovernance : GovernanceRequirement {
        subject district : ComillaDistrict;
        requirement {
            district.totalPopulation >= 6000000;
        }
    }

    requirement UpazilaCoverage : GovernanceRequirement {
        subject district : ComillaDistrict;
        requirement {
            district.numberOfUpazilas == 17;
        }
    }

    requirement HealthcareServiceProvision : GovernanceRequirement {
        subject district : ComillaDistrict;
        requirement {
            district.healthcare.hospitalsCount > 0;
            district.healthcare.medicalStaffCount > 0;
        }
    }

    requirement EducationServiceProvision : GovernanceRequirement {
        subject district : ComillaDistrict;
        requirement {
            district.education.primarySchoolsCount > 0;
            district.education.teachersCount > 0;
        }
    }

    requirement TransportationMobility : GovernanceRequirement {
        subject district : ComillaDistrict;
        requirement {
            district.transportation.totalRoadLength > 0;
            district.transportation.bridgesCount >= 0;
        }
    }

    requirement AgriculturalSupport : GovernanceRequirement {
        subject district : ComillaDistrict;
        requirement {
            district.agriculture.cultivableLand > 0;
            district.agriculture.annualFoodProduction > 0;
        }
    }

    requirement EconomicGrowth : GovernanceRequirement {
        subject district : ComillaDistrict;
        requirement {
            district.economicDevelopment.currentEmploymentRate >= 0;
        }
    }

    requirement ContinuousImprovementLoop : GovernanceRequirement {
        subject district : ComillaDistrict;
        requirement {
            district.administration.GovernanceCycle.isActive;
        }
    }

    requirement BudgetAllocationRequirement : GovernanceRequirement {
        subject district : ComillaDistrict;
        requirement {
            district.administration.annualBudget > 0;
        }
    }

    requirement PerformanceMonitoringRequirement : GovernanceRequirement {
        subject district : ComillaDistrict;
        attribute minAcceptableScore : TargetThreshold = 70;
        requirement {
            district.administration.monitoringTeam.collectedReports.score >= minAcceptableScore;
        }
    }

    // ---- Satisfaction ----
    satisfaction DistrictPopulationGovernance satisfy by ComillaDistrict;
    satisfaction UpazilaCoverage satisfy by ComillaDistrict;
    satisfaction HealthcareServiceProvision satisfy by ComillaDistrict.healthcare;
    satisfaction EducationServiceProvision satisfy by ComillaDistrict.education;
    satisfaction TransportationMobility satisfy by ComillaDistrict.transportation;
    satisfaction AgriculturalSupport satisfy by ComillaDistrict.agriculture;
    satisfaction EconomicGrowth satisfy by ComillaDistrict.economicDevelopment;
    satisfaction ContinuousImprovementLoop satisfy by ComillaDistrict.administration;
    satisfaction BudgetAllocationRequirement satisfy by ComillaDistrict.administration;
    satisfaction PerformanceMonitoringRequirement satisfy by ComillaDistrict.administration.monitoringTeam;

}
