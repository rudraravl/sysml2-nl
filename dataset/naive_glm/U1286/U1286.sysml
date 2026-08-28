package GermanyNationalSystem {
    import ISQ::*;
    import ScalarValues::*;
    import Time::*;

    // ---- Value types with units ----
    value def Population :> Real { unit "person"; }
    value def Power :> Real { unit "MW"; }
    value def Energy :> Real { unit "GWh"; }
    value def Currency :> Real { unit "EUR"; }
    value def Percentage :> Real { unit "%"; }
    value def Length :> Real { unit "km"; }
    value def Speed :> Real { unit "km/h"; }
    value def DataRate :> Real { unit "Gbit/s"; }
    value def Volume :> Real { unit "m3"; }
    value def Area :> Real { unit "km2"; }

    // ---- Enumerations ----
    enum GovBranch { legislative, executive, judicial }
    enum EnergySource { naturalGas, coal, windOnshore, windOffshore, solar, hydro, biomass }
    enum CrisisType { economicDownturn, energyShortage, publicHealthEmergency, naturalDisaster }
    enum TransportMode { road, rail, air, sea }

    // ---- Item definitions ----
    item def Legislation;
    item def Policy;
    item def Goods;
    item def Services;
    item def Electricity;
    item def NaturalGas;
    item def Coal;
    item def TaxRevenue;
    item def LaborForce;
    item def Capital;
    item def ExportGoods;
    item def ImportGoods;
    item def Pension;
    item def UnemploymentBenefit;
    item def HealthcareService;
    item def EducationService;
    item def WaterSupply;
    item def Waste;
    item def Data;
    item def Passenger;
    item def Freight;

    // ---- Port definitions ----
    port def GovPolicyPort {
        out policy : Policy;
        out legislation : Legislation;
        in taxRevenue : TaxRevenue;
    }

    port def EconomyPort {
        in labor : LaborForce;
        in capital : Capital;
        out goods : Goods;
        out services : Services;
        out exportGoods : ExportGoods;
        in importGoods : ImportGoods;
    }

    port def EnergyPort {
        out electricity : Electricity;
        in demand : Power;
    }

    port def InfrastructurePort {
        out passenger : Passenger;
        out freight : Freight;
        out data : Data;
        out water : WaterSupply;
        in waste : Waste;
    }

    port def SocialPort {
        in funding : TaxRevenue;
        out healthcare : HealthcareService;
        out education : EducationService;
        out pension : Pension;
        out unemploymentBenefit : UnemploymentBenefit;
    }

    // ---- Federal Government ----
    part def FederalGovernment {
        port govPort : GovPolicyPort;
        attribute population : Population = 83000000;
        attribute gdp : Currency = 3.8e12;
        attribute branch : GovBranch;

        part bundestag : Bundestag;
        part bundesrat : Bundesrat;
        part chancellor : Chancellor;
        part constitutionalCourt : ConstitutionalCourt;

        flow taxRevenue from govPort.taxRevenue to govPort.policy;

        action enactLegislation {
            in bill : Legislation;
            out law : Legislation;
        }
    }

    part def Bundestag {
        attribute seats : Integer = 736;
        attribute branch : GovBranch = GovBranch::legislative;
        action debate {
            in bill : Legislation;
        }
        action vote {
            in bill : Legislation;
            out passed : Legislation;
        }
    }

    part def Bundesrat {
        attribute seats : Integer = 69;
        attribute branch : GovBranch = GovBranch::legislative;
        action review {
            in bill : Legislation;
            out approved : Legislation;
        }
    }

    part def Chancellor {
        attribute termYears : Integer = 4;
        attribute branch : GovBranch = GovBranch::executive;
        action leadExecutive;
        action proposeLegislation {
            out bill : Legislation;
        }
    }

    part def ConstitutionalCourt {
        attribute judges : Integer = 16;
        attribute branch : GovBranch = GovBranch::judicial;
        action reviewConstitutionality {
            in law : Legislation;
            out ruling : Legislation;
        }
    }

    // ---- Economic System ----
    part def EconomicSystem {
        port econPort : EconomyPort;
        attribute laborForce : Population = 45000000;
        attribute capitalStock : Currency = 1.5e13;
        attribute exportVolume : Currency = 1.4e12;
        attribute importVolume : Currency = 1.2e12;

        part manufacturing : ManufacturingSector;
        part service : ServiceSector;

        flow labor from econPort.labor to manufacturing;
        flow capital from econPort.capital to manufacturing;
        flow goods from manufacturing to econPort.goods;
        flow services from service to econPort.services;
        flow exportGoods from manufacturing to econPort.exportGoods;
        flow importGoods from econPort.importGoods to manufacturing;

        action produceGoodsAndServices {
            in labor : LaborForce;
            in capital : Capital;
            out goods : Goods;
            out services : Services;
        }
    }

    part def ManufacturingSector {
        port in labor : LaborForce;
        port in capital : Capital;
        port out goods : Goods;
        port out exportGoods : ExportGoods;

        part automotive : AutomotiveIndustry;
        part machinery : MachineryIndustry;
        part chemical : ChemicalIndustry;

        action produceGoods {
            in labor : LaborForce;
            in capital : Capital;
            out goods : Goods;
        }
    }

    part def AutomotiveIndustry {
        attribute annualOutput : Integer = 4600000;
        attribute exportShare : Percentage = 0.75;
    }

    part def MachineryIndustry {
        attribute exportShare : Percentage = 0.70;
        attribute employees : Population = 1000000;
    }

    part def ChemicalIndustry {
        attribute revenue : Currency = 2.0e11;
        attribute employees : Population = 450000;
    }

    part def ServiceSector {
        port in labor : LaborForce;
        port in capital : Capital;
        port out services : Services;

        part finance : FinanceIndustry;
        part healthcare : HealthcareIndustry;
        part education : EducationIndustry;

        action provideServices {
            in labor : LaborForce;
            in capital : Capital;
            out services : Services;
        }
    }

    part def FinanceIndustry {
        attribute assets : Currency = 8.0e12;
        attribute employees : Population = 800000;
    }

    part def HealthcareIndustry {
        attribute hospitals : Integer = 1900;
        attribute employees : Population = 1300000;
    }

    part def EducationIndustry {
        attribute universities : Integer = 400;
        attribute employees : Population = 1100000;
    }

    // ---- Energy System ----
    part def EnergySystem {
        port energyPort : EnergyPort;
        attribute totalCapacity : Power = 230000;
        attribute renewableShare : Percentage = 0.52;
        attribute targetRenewableShare : Percentage = 0.80;
        attribute targetYear : Integer = 2030;

        part conventional : ConventionalGeneration;
        part renewable : RenewableGeneration;
        part transmissionGrid : TransmissionGrid;

        flow electricity from conventional.electricity to transmissionGrid.electricity;
        flow electricity from renewable.electricity to transmissionGrid.electricity;
        flow distributed from transmissionGrid.distributed to energyPort.electricity;
        flow demand from energyPort.demand to transmissionGrid.demand;

        action balanceSupply {
            in supply : Power;
            in demand : Power;
            out balanced : Power;
        }
    }

    part def ConventionalGeneration {
        port out electricity : Electricity;
        part naturalGasPlant : NaturalGasPlant;
        part coalPlant : CoalPlant;
        attribute phaseOutYear : Integer = 2038;
    }

    part def NaturalGasPlant {
        attribute capacity : Power = 30000;
        attribute fuel : NaturalGas;
        attribute status : String = "operational";
    }

    part def CoalPlant {
        attribute capacity : Power = 40000;
        attribute fuel : Coal;
        attribute status : String = "phasingOut";
    }

    part def RenewableGeneration {
        port out electricity : Electricity;
        part windOnshore : WindOnshore;
        part windOffshore : WindOffshore;
        part solar : SolarGeneration;
        part hydro : HydroGeneration;
        part biomass : BiomassGeneration;
    }

    part def WindOnshore {
        attribute capacity : Power = 60000;
        attribute turbineCount : Integer = 30000;
        attribute source : EnergySource = EnergySource::windOnshore;
    }

    part def WindOffshore {
        attribute capacity : Power = 8000;
        attribute turbineCount : Integer = 1500;
        attribute source : EnergySource = EnergySource::windOffshore;
    }

    part def SolarGeneration {
        attribute capacity : Power = 70000;
        attribute panelArea : Area = 5.0e6;
        attribute source : EnergySource = EnergySource::solar;
    }

    part def HydroGeneration {
        attribute capacity : Power = 5000;
        attribute source : EnergySource = EnergySource::hydro;
    }

    part def BiomassGeneration {
        attribute capacity : Power = 9000;
        attribute source : EnergySource = EnergySource::biomass;
    }

    part def TransmissionGrid {
        port in electricity : Electricity;
        port in demand : Power;
        port out distributed : Electricity;
        attribute gridLength : Length = 35000;
        attribute voltage : Integer = 380;
        action transmit {
            in electricity : Electricity;
            out distributed : Electricity;
        }
    }

    // ---- Infrastructure System ----
    part def InfrastructureSystem {
        port infraPort : InfrastructurePort;

        part transport : TransportNetwork;
        part digital : DigitalInfrastructure;
        part utilities : PublicUtilities;

        flow passenger from transport.passenger to infraPort.passenger;
        flow freight from transport.freight to infraPort.freight;
        flow data from digital.data to infraPort.data;
        flow water from utilities.water to infraPort.water;
        flow waste from infraPort.waste to utilities.waste;
    }

    part def TransportNetwork {
        port out passenger : Passenger;
        port out freight : Freight;

        part autobahn : AutobahnNetwork;
        part rail : RailSystem;
        part airports : AirportSystem;
        part seaports : SeaportSystem;
    }

    part def AutobahnNetwork {
        attribute totalLength : Length = 13000;
        attribute maxSpeed : Speed = 130;
        attribute mode : TransportMode = TransportMode::road;
    }

    part def RailSystem {
        attribute networkLength : Length = 33000;
        attribute operator : String = "Deutsche Bahn";
        attribute mode : TransportMode = TransportMode::rail;
    }

    part def AirportSystem {
        attribute majorAirports : Integer = 15;
        attribute mode : TransportMode = TransportMode::air;
    }

    part def SeaportSystem {
        attribute majorPorts : Integer = 10;
        attribute mode : TransportMode = TransportMode::sea;
    }

    part def DigitalInfrastructure {
        port out data : Data;
        attribute fiberLength : Length = 1.5e6;
        attribute avgSpeed : DataRate = 1.0;
    }

    part def PublicUtilities {
        port out water : WaterSupply;
        port in waste : Waste;
        attribute waterSupplyCapacity : Volume = 1.0e7;
    }

    // ---- Social System ----
    part def SocialSystem {
        port socialPort : SocialPort;
        attribute population : Population = 83000000;

        part healthcare : UniversalHealthcare;
        part education : PublicEducation;
        part socialSecurity : SocialSecurity;

        flow funding from socialPort.funding to healthcare.funding;
        flow funding from socialPort.funding to education.funding;
        flow funding from socialPort.funding to socialSecurity.funding;
        flow service from healthcare.service to socialPort.healthcare;
        flow service from education.service to socialPort.education;
        flow pension from socialSecurity.pension to socialPort.pension;
        flow unemploymentBenefit from socialSecurity.unemploymentBenefit to socialPort.unemploymentBenefit;
    }

    part def UniversalHealthcare {
        port in funding : TaxRevenue;
        port out service : HealthcareService;
        attribute insuredPopulation : Population = 73000000;
        attribute statutoryInsurance : Boolean = true;
        attribute hospitals : Integer = 1900;
    }

    part def PublicEducation {
        port in funding : TaxRevenue;
        port out service : EducationService;
        attribute tuitionFree : Boolean = true;
        attribute dualApprenticeship : Boolean = true;
        attribute universities : Integer = 400;
    }

    part def SocialSecurity {
        port in funding : TaxRevenue;
        port out pension : Pension;
        port out unemploymentBenefit : UnemploymentBenefit;
        attribute pensioners : Population = 21000000;
        attribute unemploymentRate : Percentage = 0.05;
    }

    // ---- State machine for national operation ----
    action def regularGovernance {
        out legislation : Legislation;
    }

    action def regularEconomy {
        in labor : LaborForce;
        in capital : Capital;
        out goods : Goods;
        out services : Services;
    }

    action def activateProtocols {
        in crisis : CrisisType;
        out measures : Policy;
    }

    state def NationalStates {
        attribute crisisResolved : Boolean = false;

        state NormalOperation {
            entry action enterNormal;
            do regularGovernance;
            do regularEconomy;
        }

        state EmergencyOperation {
            entry action enterEmergency;
            do activateProtocols;
        }

        transition normalToEmergency
            first NormalOperation
            accept crisis : CrisisType
            guard crisis == CrisisType::economicDownturn
                or crisis == CrisisType::energyShortage
                or crisis == CrisisType::publicHealthEmergency
                or crisis == CrisisType::naturalDisaster
            then EmergencyOperation;

        transition emergencyToNormal
            first EmergencyOperation
            accept resolved
            guard crisisResolved == true
            then NormalOperation;
    }

    // ---- Top-level national system ----
    part def FederalRepublicOfGermany {
        attribute population : Population = 83000000;
        attribute area : Area = 357000;
        attribute capital : String = "Berlin";
        attribute crisisResolved : Boolean = false;
        attribute climateNeutralityTargetYear : Integer = 2045;

        port govPort : GovPolicyPort;
        port econPort : EconomyPort;
        port energyPort : EnergyPort;
        port infraPort : InfrastructurePort;
        port socialPort : SocialPort;

        part federalGovernment : FederalGovernment;
        part economicSystem : EconomicSystem;
        part energySystem : EnergySystem;
        part infrastructureSystem : InfrastructureSystem;
        part socialSystem : SocialSystem;

        // Inter-subsystem connections
        connection policyToEconomy
            connect federalGovernment.govPort.policy to economicSystem.econPort;
        connection legislationToSocial
            connect federalGovernment.govPort.legislation to socialSystem.socialPort;
        connection goodsToInfrastructure
            connect economicSystem.econPort.goods to infrastructureSystem.infraPort;
        connection electricityToEconomy
            connect energySystem.energyPort.electricity to economicSystem.econPort;
        connection electricityToInfrastructure
            connect energySystem.energyPort.electricity to infrastructureSystem.infraPort;
        connection dataToEconomy
            connect infrastructureSystem.infraPort.data to economicSystem.econPort;
        connection healthcareToGov
            connect socialSystem.socialPort.healthcare to federalGovernment.govPort;
        connection exportToGov
            connect economicSystem.econPort.exportGoods to federalGovernment.govPort;
        connection taxRevenueToSocial
            connect federalGovernment.govPort.taxRevenue to socialSystem.socialPort;

        exhibit NationalStates;
    }

    // ---- Requirements ----
    requirement def DemocraticGovernanceReq {
        doc "The system shall provide democratic governance through elected representatives in a federal parliamentary republic."
        subject federalGovernment : FederalGovernment;
        constraint { federalGovernment.bundestag.seats > 0 }
        constraint { federalGovernment.bundesrat.seats > 0 }
        constraint { federalGovernment.constitutionalCourt.judges > 0 }
    }

    requirement def SocialMarketEconomyReq {
        doc "The system shall maintain a social market economy balancing free enterprise with social welfare."
        subject economicSystem : EconomicSystem;
        constraint { economicSystem.laborForce > 0 }
        constraint { economicSystem.capitalStock > 0 }
        constraint { economicSystem.exportVolume > 0 }
    }

    requirement def RenewableTransitionReq {
        doc "The system shall lead the Energiewende transition to renewable energy and achieve climate neutrality."
        subject energySystem : EnergySystem;
        constraint { energySystem.renewableShare >= 0.52 }
        constraint { energySystem.targetRenewableShare >= 0.80 }
    }

    requirement def SocialWelfareReq {
        doc "The system shall provide comprehensive social welfare including universal healthcare, public education, and social security."
        subject socialSystem : SocialSystem;
        constraint { socialSystem.healthcare.insuredPopulation >= 0.8 * socialSystem.population }
        constraint { socialSystem.education.tuitionFree == true }
        constraint { socialSystem.socialSecurity.pensioners > 0 }
    }

    requirement def EmergencyResponseReq {
        doc "The system shall shift into an emergency state in response to major crises and activate special protocols."
        subject nation : FederalRepublicOfGermany;
        constraint { nation.crisisResolved == true implies true }
    }

    requirement def EuropeanIntegrationReq {
        doc "The system shall commit to European integration as a core principle."
        subject nation : FederalRepublicOfGermany;
    }

    requirement def ClimateNeutralityReq {
        doc "The system shall achieve climate neutrality through the Energiewende policy."
        subject nation : FederalRepublicOfGermany;
        constraint { nation.climateNeutralityTargetYear <= 2045 }
    }

    requirement nationalRequirements {
        subject nation : FederalRepublicOfGermany;
        satisfy DemocraticGovernanceReq by nation.federalGovernment;
        satisfy SocialMarketEconomyReq by nation.economicSystem;
        satisfy RenewableTransitionReq by nation.energySystem;
        satisfy SocialWelfareReq by nation.socialSystem;
        satisfy EmergencyResponseReq by nation;
        satisfy EuropeanIntegrationReq by nation;
        satisfy ClimateNeutralityReq by nation;
    }
}
