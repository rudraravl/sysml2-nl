package 'German Federal System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def PopulationCount :> Real;
    attribute def AreaMeasure :> Real;
    attribute def EconomicValue :> Real;
    
    attribute def Currency :> Real;
    
    attribute def GDP :> EconomicValue;
    
    attribute def ElectricalPower :> PowerValue;
    
    item def Citizen;
    item def Policy;
    item def EconomicOutput;
    item def ElectricalEnergy {
        attribute power: ElectricalPower;
    }
    item def PublicService;
    
    port def GovernancePort {
        out policies: Policy[*];
        in citizenFeedback: String;
    }
    
    port def EconomicPort {
        out output: EconomicOutput[*];
        in demand: Real;
    }
    
    port def EnergyPort {
        out supply: ElectricalEnergy;
        in consumption: ElectricalPower;
    }
    
    port def InfrastructurePort {
        out capacity: Real;
        in utilization: Real;
    }
    
    requirement def DemocraticGovernanceRequirement {
        doc /* The system shall provide democratic governance through federal 
               parliamentary structures ensuring representation of all citizens. */
        
        require constraint {
            doc /* Legislative processes must be transparent and participatory. */
        }
    }
    
    requirement def EconomicProsperityRequirement {
        doc /* The system shall maintain a strong social market economy 
               supporting both economic growth and social welfare. */
        
        require constraint economicStability {
            attribute gdpGrowthRate: Real;
            gdpGrowthRate >= 1.0
        }
    }
    
    requirement def EnergiewendeRequirement {
        doc /* The system shall transition to renewable energy sources 
               achieving climate neutrality by 2045. */
        
        require constraint renewableTarget {
            attribute renewablePercentage: Real;
            renewablePercentage >= 80.0
        }
    }
    
    part def FederalGovernment {
        attribute numberOfStates: Integer = 16;
        
        port governance: GovernancePort;
        
        part legislature {
            attribute bundestag: String = "Federal Parliament";
            attribute bundesrat: String = "Federal Council";
            attribute members: Integer = 736;
        }
        
        part executive {
            attribute chancellor: String;
            attribute federalMinisters: Integer = 16;
        }
        
        part judiciary {
            attribute constitutionalCourt: String = "Bundesverfassungsgericht";
        }
        
        action def LegislatePolicy {
            in proposal: String;
            out enactedPolicy: Policy;
            
            first start;
            then action debate {
                doc /* Parliamentary debate in Bundestag. */
            }
            then decide;
                if proposal != "" then enact;
                else done;
            action enact {
                doc /* Enact policy into law. */
            }
            then done;
        }
    }
    
    part def EconomicSystem {
        attribute gdp: GDP;
        attribute employmentRate: Real;
        attribute exportVolume: Currency;
        
        port economic: EconomicPort;
        
        part manufacturing {
            attribute automotive: String = "Volkswagen, BMW, Mercedes-Benz";
            attribute machinery: String = "Siemens, Bosch";
            attribute chemicals: String = "BASF, Bayer";
            attribute outputShare: Real = 0.25;
        }
        
        part services {
            attribute financial: String = "Deutsche Bank, Allianz";
            attribute healthcare: String = "Universal Coverage";
            attribute education: String = "Free Public Education";
            attribute outputShare: Real = 0.69;
        }
        
        part trade {
            attribute exports: Currency;
            attribute imports: Currency;
            attribute tradeBalance: Currency;
        }
        
        action def ProduceEconomicOutput {
            in laborForce: Real;
            in capitalInvestment: Currency;
            out gdpContribution: GDP;
            
            action manufacture {
                doc /* Produce manufactured goods for domestic and export markets. */
                out goods: EconomicOutput[*];
            }
            flow manufacture.goods to deliver.products;
            
            action provideServices {
                doc /* Deliver services to citizens and businesses. */
                out services: EconomicOutput[*];
            }
            flow provideServices.services to deliver.products;
            
            action deliver {
                in products: EconomicOutput[*];
                out totalOutput: GDP;
            }
        }
    }
    
    part def EnergySystem {
        attribute totalCapacity: ElectricalPower;
        attribute renewableShare: Real;
        
        port energy: EnergyPort;
        
        part renewableGeneration {
            part wind {
                attribute onshore: ElectricalPower = 56000.0;
                attribute offshore: ElectricalPower = 8000.0;
            }
            part solar {
                attribute capacity: ElectricalPower = 67000.0;
            }
            part hydro {
                attribute capacity: ElectricalPower = 5600.0;
            }
            part biomass {
                attribute capacity: ElectricalPower = 8900.0;
            }
        }
        
        part conventionalGeneration {
            part naturalGas {
                attribute capacity: ElectricalPower = 31000.0;
            }
            part coal {
                attribute capacity: ElectricalPower = 42000.0;
                attribute phaseOutYear: Integer = 2038;
            }
        }
        
        part transmission {
            attribute gridLength: LengthValue = 1800000.0;
            attribute voltageLevel: VoltageValue = 380000.0;
        }
        
        action def GenerateAndDistributePower {
            in demand: ElectricalPower;
            out supplied: ElectricalEnergy;
            
            action generateRenewable {
                doc /* Generate electricity from wind, solar, hydro, and biomass. */
                out renewablePower: ElectricalPower;
            }
            flow generateRenewable.renewablePower to balance.renewableInput;
            
            action generateConventional {
                doc /* Generate electricity from natural gas and coal during transition. */
                out conventionalPower: ElectricalPower;
            }
            flow generateConventional.conventionalPower to balance.conventionalInput;
            
            action balance {
                in renewableInput: ElectricalPower;
                in conventionalInput: ElectricalPower;
                out balancedPower: ElectricalPower;
            }
            flow balance.balancedPower to transmit.inputPower;
            
            action transmit {
                in inputPower: ElectricalPower;
                out distributedPower: ElectricalEnergy;
            }
        }
    }
    
    part def InfrastructureSystem {
        port infrastructure: InfrastructurePort;
        
        part transportation {
            part roadNetwork {
                attribute autobahn: LengthValue = 13200.0;
                attribute federalRoads: LengthValue = 38000.0;
                attribute stateRoads: LengthValue = 86000.0;
            }
            part railNetwork {
                attribute totalLength: LengthValue = 38400.0;
                attribute highSpeed: LengthValue = 1658.0;
                attribute operator: String = "Deutsche Bahn";
            }
            part airports {
                attribute international: Integer = 16;
                attribute major: String = "Frankfurt, Munich, Berlin";
            }
            part ports {
                attribute seaPorts: Integer = 3;
                attribute major: String = "Hamburg, Bremen, Rostock";
            }
        }
        
        part digitalInfrastructure {
            attribute fiberCoverage: Real = 0.65;
            attribute broadbandSpeed: Real = 100.0;
        }
        
        part utilities {
            attribute waterSupply: String = "Municipal Systems";
            attribute wasteManagement: String = "Recycling Rate 67%";
        }
    }
    
    part def SocialSystem {
        attribute population: PopulationCount = 83200000.0;
        
        part healthcare {
            attribute universalCoverage: Boolean = true;
            attribute hospitals: Integer = 1900;
            attribute insuranceModel: String = "Statutory Health Insurance";
        }
        
        part education {
            attribute universities: Integer = 426;
            attribute vocationalSchools: Integer = 8500;
            attribute freeTuition: Boolean = true;
            attribute dualEducation: String = "Apprenticeship System";
        }
        
        part socialSecurity {
            attribute pensionSystem: String = "Pay-as-you-go";
            attribute unemploymentInsurance: Boolean = true;
            attribute socialAssistance: Boolean = true;
        }
    }
    
    action def ManageFederalRepublic {
        in citizenNeeds: String[*];
        out governanceActions: Policy[*];
        out economicGrowth: GDP;
        out energySupplied: ElectricalEnergy;
        out publicServices: PublicService[*];
        
        action govern {
            doc /* Execute democratic governance through federal structures. */
            out policies: Policy[*];
        }
        flow govern.policies to implement.policyInput;
        
        action implement {
            in policyInput: Policy[*];
            doc /* Implement policies through federal and state administrations. */
        }
        
        action produceEconomically {
            doc /* Generate economic output through manufacturing and services. */
            out output: GDP;
        }
        
        action supplyEnergy {
            doc /* Generate and distribute electrical energy. */
            out energy: ElectricalEnergy;
        }
        
        action provideServices {
            doc /* Deliver public services including healthcare, education, and social security. */
            out services: PublicService[*];
        }
    }
    
    attribute def EmergencySignal;
    attribute def ResolutionSignal;
    
    state def FederalOperationStates {
        entry; then normalOperation;
        
        state normalOperation {
            entry action standardGovernance {
                doc /* Conduct regular democratic governance and economic activities. */
            }
        }
        
        state emergencyOperation {
            entry action activateEmergencyProtocols {
                doc /* Activate constitutional emergency provisions. */
            }
            
            state economicCrisis;
            state energyCrisis;
            state publicHealthEmergency;
            state naturalDisaster;
        }
        
        transition normalToEmergency
            first normalOperation
            accept emergencyEvent : EmergencySignal
            then emergencyOperation;
            
        transition emergencyToNormal
            first emergencyOperation
            accept resolutionEvent : ResolutionSignal
            then normalOperation;
    }
    
    part def FederalRepublicOfGermany {
        doc /* The Federal Republic of Germany is a democratic federal parliamentary 
               republic in Central Europe. Its primary function is to provide effective 
               democratic governance, maintain a strong social market economy, ensure 
               comprehensive social welfare for all citizens, and lead the transition 
               to renewable energy while serving as a key member of the European Union. */
        
        attribute officialName: String = "Bundesrepublik Deutschland";
        attribute capital: String = "Berlin";
        attribute area: AreaMeasure = 357022.0;
        attribute populationCount: PopulationCount = 83200000.0;
        attribute gdpValue: GDP = 4072.0;
        attribute foundingYear: Integer = 1949;
        
        perform action operate: ManageFederalRepublic;
        exhibit state operationalState: FederalOperationStates;
        
        part government: FederalGovernment {
            perform operate.govern;
            
            part :>> legislature {
                attribute :>> bundestag = "Deutscher Bundestag";
                attribute :>> bundesrat = "Bundesrat";
            }
            
            part :>> executive {
                attribute :>> chancellor = "Federal Chancellor";
            }
        }
        
        part economy: EconomicSystem {
            perform operate.produceEconomically;
            
            attribute :>> gdp = 4072.0;
            attribute :>> employmentRate = 76.3;
            attribute :>> exportVolume = 1576.0;
            
            part :>> manufacturing {
                attribute :>> outputShare = 0.25;
            }
            
            part :>> services {
                attribute :>> outputShare = 0.69;
            }
            
            part :>> trade {
                attribute :>> exports = 1576.0;
                attribute :>> imports = 1203.0;
                attribute :>> tradeBalance = 373.0;
            }
        }
        
        part energyInfrastructure: EnergySystem {
            perform operate.supplyEnergy;
            
            attribute :>> totalCapacity = 218500.0;
            attribute :>> renewableShare = 46.0;
            
            part :>> renewableGeneration {
                part :>> wind {
                    attribute :>> onshore = 56000.0;
                    attribute :>> offshore = 8000.0;
                }
                part :>> solar {
                    attribute :>> capacity = 67000.0;
                }
            }
        }
        
        part infrastructure: InfrastructureSystem {
            part :>> transportation {
                part :>> roadNetwork {
                    attribute :>> autobahn = 13200.0;
                }
                part :>> railNetwork {
                    attribute :>> totalLength = 38400.0;
                    attribute :>> operator = "Deutsche Bahn AG";
                }
            }
        }
        
        part society: SocialSystem {
            perform operate.provideServices;
            
            attribute :>> population = 83200000.0;
            
            part :>> healthcare {
                attribute :>> universalCoverage = true;
                attribute :>> hospitals = 1900;
            }
            
            part :>> education {
                attribute :>> universities = 426;
                attribute :>> freeTuition = true;
            }
        }
        
        connection governanceToEconomy connect 
            government.governance to economy.economic;
            
        connection economyToEnergy connect 
            economy.economic to energyInfrastructure.energy;
            
        connection energyToInfrastructure connect 
            energyInfrastructure.energy to infrastructure.infrastructure;
    }
    
    requirement federalSystemRequirements {
        doc /* Top-level requirements for the Federal Republic of Germany system. */
        
        require req1: DemocraticGovernanceRequirement;
        require req2: EconomicProsperityRequirement;
        require req3: EnergiewendeRequirement;
        
        requirement europeanIntegration {
            doc /* The system shall maintain strong integration with the European Union 
                   and support European cooperation, unity, and shared values. */
        }
        
        requirement socialMarketEconomy {
            doc /* The system shall balance free market principles with social welfare 
                   ensuring both economic competitiveness and social justice. */
        }
        
        requirement comprehensiveSocialWelfare {
            doc /* The system shall provide universal healthcare, free education, 
                   and comprehensive social security for all citizens. */
        }
    }
    
    part germany: FederalRepublicOfGermany;
}
