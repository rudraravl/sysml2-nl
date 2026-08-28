package 'Federal Republic of Germany' {
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        public import ItemDefinitions::*;
        public import AttributeDefinitions::*;
        public import PortDefinitions::*;
        public import ActionDefinitions::*;
        public import PartDefinitions::*;
        public import RequirementDefinitions::*;

        package ItemDefinitions {
            item def Policy;
            item def Law;
            item def Goods;
            item def Services;
            item def ElectricalPower;
            item def EnergySource;
            item def NaturalGas;
            item def Coal;
            item def Wind;
            item def Solar;
            item def Hydro;
            item def Biomass;
            item def Citizen;
            item def LaborForce;
            item def Capital;
            item def TransportFlow;
            item def DataFlow;
            item def Water;
            item def Waste;
            item def HealthcareService;
            item def EducationService;
            item def Pension;
            item def UnemploymentBenefit;
            item def CrisisResolvedEvent;

            enum def CrisisType {
                economic;
                energyShortage;
                publicHealth;
                naturalDisaster;
            }

            item def CrisisEvent {
                attribute type : CrisisType;
            }
        }

        package AttributeDefinitions {
            public import ScalarValues::*;
            public import ISQ::*;

            attribute def Population :> Integer;
            attribute def GDP :> Real;
            attribute def UnemploymentRate :> Real;
            attribute def RenewableShare :> Real;
            attribute def TotalCapacity :> power;
            attribute def EnergyDemand :> power;
            attribute def CO2Emissions :> mass;
            attribute def HealthcareCoverage :> Real;
            attribute def EducationAccess :> Real;
            attribute def AutobahnLength :> length;
            attribute def RailLength :> length;
            attribute def Year :> Integer;
        }

        package PortDefinitions {
            port def PolicyPort {
                ref item policy : Policy;
                ref item law : Law;
            }
            port def EconomicPort {
                ref item goods : Goods;
                ref item services : Services;
                ref item labor : LaborForce;
                ref item capital : Capital;
            }
            port def PowerPort {
                ref item power : ElectricalPower;
            }
            port def TransportPort {
                ref item transport : TransportFlow;
                ref item data : DataFlow;
                ref item water : Water;
                ref item waste : Waste;
            }
            port def SocialPort {
                ref item healthcare : HealthcareService;
                ref item education : EducationService;
                ref item pension : Pension;
                ref item unemploymentBenefit : UnemploymentBenefit;
                ref item citizen : Citizen;
            }
            port def CrisisPort {
                ref item crisis : CrisisEvent;
                ref item resolved : CrisisResolvedEvent;
            }
        }

        package ActionDefinitions {
            action def DebateLaw;
            action def ApproveLaw;
            action def ExecutiveAction;
            action def JudicialReview;
            action def Manufacture;
            action def ProvideService;

            action def EnactPolicy {
                in draft : Policy;
                out law : Law;
            }
            action def ProduceGoodsAndServices {
                in labor : LaborForce;
                in capital : Capital;
                out goods : Goods;
                out services : Services;
            }
            action def GeneratePower {
                in source : EnergySource;
                out power : ElectricalPower;
            }
            action def BalanceGrid {
                in supply : ElectricalPower;
                in demand : ElectricalPower;
                out balanced : ElectricalPower;
            }
            action def DistributePower {
                in power : ElectricalPower;
                out distributed : ElectricalPower;
            }
            action def OperateTransport {
                in network : TransportFlow;
                out operational : TransportFlow;
            }
            action def TransmitData {
                in data : DataFlow;
                out transmitted : DataFlow;
            }
            action def SupplyWater {
                out water : Water;
            }
            action def ManageWaste {
                in waste : Waste;
            }
            action def ProvideHealthcare {
                in patient : Citizen;
                out treatment : HealthcareService;
            }
            action def ProvideEducation {
                in student : Citizen;
                out graduate : Citizen;
            }
            action def DisburseBenefits {
                out pension : Pension;
                out unemploymentBenefit : UnemploymentBenefit;
            }
            action def ActivateEmergencyProtocols;
            action def ManageCrisis;
            action def OperateNormally;
        }

        package PartDefinitions {
            part def Bundestag {
                perform action debateLaw : DebateLaw;
            }
            part def Bundesrat {
                perform action approveLaw : ApproveLaw;
            }
            part def Chancellor {
                perform action executiveAction : ExecutiveAction;
            }
            part def ConstitutionalCourt {
                perform action judicialReview : JudicialReview;
            }

            part def FederalGovernment {
                part bundestag : Bundestag;
                part bundesrat : Bundesrat;
                part chancellor : Chancellor;
                part constitutionalCourt : ConstitutionalCourt;
                port policyOut : PolicyPort;
                port powerIn : PowerPort;
                perform action enactPolicy : EnactPolicy;
            }

            part def ManufacturingSector {
                perform action manufacture : Manufacture;
            }
            part def ServiceSector {
                perform action provideService : ProvideService;
            }

            part def EconomicSystem {
                part manufacturingSector : ManufacturingSector;
                part serviceSector : ServiceSector;
                attribute gdp : GDP;
                attribute unemploymentRate : UnemploymentRate;
                port policyIn : PolicyPort;
                port econIn : EconomicPort;
                port econOut : EconomicPort;
                port powerIn : PowerPort;
                port transportIn : TransportPort;
                perform action produceGoodsAndServices : ProduceGoodsAndServices;
            }

            part def ConventionalGeneration {
                attribute coalPhaseOutYear : Year = 2038;
                perform action generateConventionalPower : GeneratePower;
            }
            part def RenewableGeneration {
                part windOnshore;
                part windOffshore;
                part solar;
                part hydro;
                part biomass;
                perform action generateRenewablePower : GeneratePower;
            }
            part def TransmissionGrid {
                perform action transmitPower : DistributePower;
            }

            part def EnergySystem {
                part conventionalGeneration : ConventionalGeneration;
                part renewableGeneration : RenewableGeneration;
                part transmissionGrid : TransmissionGrid;
                attribute totalCapacity : TotalCapacity;
                attribute renewableShare : RenewableShare;
                port energyOut : PowerPort;
                perform action generatePower : GeneratePower;
                perform action balanceGrid : BalanceGrid;
                perform action distributePower : DistributePower;
            }

            part def TransportationNetwork {
                part autobahn;
                part railSystem;
                part airports;
                part seaports;
                attribute autobahnLength : AutobahnLength;
                attribute railLength : RailLength;
                perform action operateTransport : OperateTransport;
            }
            part def DigitalNetwork {
                perform action transmitData : TransmitData;
            }
            part def PublicUtilities {
                perform action supplyWater : SupplyWater;
                perform action manageWaste : ManageWaste;
            }

            part def InfrastructureSystem {
                part transportationNetwork : TransportationNetwork;
                part digitalNetwork : DigitalNetwork;
                part publicUtilities : PublicUtilities;
                port infraOut : TransportPort;
                port powerIn : PowerPort;
                perform action operateTransport : OperateTransport;
                perform action transmitData : TransmitData;
                perform action supplyWater : SupplyWater;
                perform action manageWaste : ManageWaste;
            }

            part def HealthcareSystem {
                perform action provideHealthcare : ProvideHealthcare;
            }
            part def EducationSystem {
                perform action provideEducation : ProvideEducation;
            }
            part def SocialSecurityNetwork {
                perform action disburseBenefits : DisburseBenefits;
            }

            part def SocialSystem {
                part healthcareSystem : HealthcareSystem;
                part educationSystem : EducationSystem;
                part socialSecurityNetwork : SocialSecurityNetwork;
                attribute population : Population = 83000000;
                port policyIn : PolicyPort;
                port econIn : EconomicPort;
                port econOut : EconomicPort;
                port powerIn : PowerPort;
                port transportIn : TransportPort;
                perform action provideHealthcare : ProvideHealthcare;
                perform action provideEducation : ProvideEducation;
                perform action disburseBenefits : DisburseBenefits;
            }

            part def Nation {
                attribute population : Population = 83000000;
                attribute gdp : GDP;
                attribute energyDemand : EnergyDemand;
                attribute renewableShare : RenewableShare;
                attribute co2Emissions : CO2Emissions;

                part federalGovernment : FederalGovernment;
                part economicSystem : EconomicSystem;
                part energySystem : EnergySystem;
                part infrastructureSystem : InfrastructureSystem;
                part socialSystem : SocialSystem;

                port crisisPort : CrisisPort;

                perform action operateNormally : OperateNormally {
                    action govern : EnactPolicy;
                    action produce : ProduceGoodsAndServices;
                    action generate : GeneratePower;
                    action balance : BalanceGrid;
                    action distribute : DistributePower;
                    action transport : OperateTransport;
                    action transmit : TransmitData;
                    action water : SupplyWater;
                    action waste : ManageWaste;
                    action health : ProvideHealthcare;
                    action education : ProvideEducation;
                    action benefits : DisburseBenefits;
                }
                perform action manageCrisis : ManageCrisis;

                exhibit state nationalStates {
                    state normal {
                        do operateNormally;
                    }
                    state emergency {
                        entry action activateEmergency : ActivateEmergencyProtocols;
                        do manageCrisis;
                    }
                    transition initial then normal;
                    transition normal_to_emergency
                        first normal
                        accept crisisEvent : CrisisEvent via crisisPort
                        then emergency;
                    transition emergency_to_normal
                        first emergency
                        accept resolvedEvent : CrisisResolvedEvent via crisisPort
                        then normal;
                }
            }
        }

        package RequirementDefinitions {
            requirement def DemocraticGovernance {
                doc /* The nation shall be governed as a federal parliamentary republic with separated legislative, executive, and judicial powers. */
            }
            requirement def EconomicProsperity {
                doc /* The nation shall maintain a strong social market economy with high-volume exports. */
                attribute targetGDP : GDP;
                attribute maxUnemploymentRate : UnemploymentRate;
            }
            requirement def SocialJustice {
                doc /* The nation shall ensure comprehensive social welfare including universal healthcare, tuition-free education, and robust social security. */
                attribute minHealthcareCoverage : HealthcareCoverage;
                attribute minEducationAccess : EducationAccess;
            }
            requirement def EuropeanIntegration {
                doc /* The nation shall be an active and committed member of the European Union. */
            }
            requirement def ClimateNeutrality {
                doc /* The nation shall achieve climate neutrality through the Energiewende energy transition policy. */
                attribute targetRenewableShare : RenewableShare;
                attribute maxCO2Emissions : CO2Emissions;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part germany : Nation {
            connect federalGovernment.policyOut to economicSystem.policyIn;
            connect federalGovernment.policyOut to socialSystem.policyIn;
            connect energySystem.energyOut to economicSystem.powerIn;
            connect energySystem.energyOut to infrastructureSystem.powerIn;
            connect energySystem.energyOut to socialSystem.powerIn;
            connect energySystem.energyOut to federalGovernment.powerIn;
            connect infrastructureSystem.infraOut to economicSystem.transportIn;
            connect infrastructureSystem.infraOut to socialSystem.transportIn;
            connect economicSystem.econOut to socialSystem.econIn;
            connect socialSystem.econOut to economicSystem.econIn;
        }

        requirement democraticGovernance : DemocraticGovernance {
            subject = germany.federalGovernment;
        }
        requirement economicProsperity : EconomicProsperity {
            subject = germany.economicSystem;
        }
        requirement socialJustice : SocialJustice {
            subject = germany.socialSystem;
        }
        requirement europeanIntegration : EuropeanIntegration {
            subject = germany.federalGovernment;
        }
        requirement climateNeutrality : ClimateNeutrality {
            subject = germany.energySystem;
        }
    }
}
