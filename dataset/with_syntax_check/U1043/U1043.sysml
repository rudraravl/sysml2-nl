package ElectricPowerDistributionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VoltageLevel :> ISQ::ElectricPotentialDifferenceValue;
    attribute def CurrentLevel :> ISQ::ElectricCurrentValue;
    attribute def PowerLevel :> ISQ::PowerValue;
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def ResistanceValue :> ISQ::ResistanceValue;
    
    attribute def GridState {
        attribute voltage : VoltageLevel;
        attribute frequency : FrequencyValue;
        attribute totalLoad : PowerLevel;
        attribute isStable : Boolean;
    }
    
    attribute def FaultCondition {
        attribute faultType : String;
        attribute location : String;
        attribute severity : Real;
    }
    
    port def PowerPort {
        attribute voltage : VoltageLevel;
        attribute current : CurrentLevel;
        attribute frequency : FrequencyValue;
        attribute activePower : PowerLevel;
    }
    
    part def PowerGenerator {
        attribute ratedPower : PowerLevel;
        attribute ratedVoltage : VoltageLevel;
        attribute ratedFrequency : FrequencyValue;
        port generatorOutput : PowerPort;
    }
    
    part def StepUpTransformer {
        attribute primaryVoltage : VoltageLevel;
        attribute secondaryVoltage : VoltageLevel;
        attribute transformerRatio : Real;
        attribute efficiency : Real;
        attribute ratedPower : PowerLevel;
        port primarySide : PowerPort;
        port secondarySide : PowerPort;
    }
    
    part def TransmissionLine {
        attribute lineVoltage : VoltageLevel;
        attribute resistance : ResistanceValue;
        attribute length : ISQ::LengthValue;
        attribute maxCurrent : CurrentLevel;
        port lineInput : PowerPort;
        port lineOutput : PowerPort;
    }
    
    part def StepDownTransformer {
        attribute primaryVoltage : VoltageLevel;
        attribute secondaryVoltage : VoltageLevel;
        attribute transformerRatio : Real;
        attribute efficiency : Real;
        attribute ratedPower : PowerLevel;
        port primarySide : PowerPort;
        port secondarySide : PowerPort;
    }
    
    part def DistributionSubstation {
        attribute substationVoltage : VoltageLevel;
        attribute maxCapacity : PowerLevel;
        port hvInput : PowerPort;
        port mvOutput1 : PowerPort;
        port mvOutput2 : PowerPort;
        port mvOutput3 : PowerPort;
    }
    
    part def DistributionFeeder {
        attribute feederVoltage : VoltageLevel;
        attribute resistance : ResistanceValue;
        attribute maxCurrent : CurrentLevel;
        port feederInput : PowerPort;
        port feederOutput : PowerPort;
    }
    
    part def ServiceTransformer {
        attribute primaryVoltage : VoltageLevel;
        attribute secondaryVoltage : VoltageLevel;
        attribute transformerRatio : Real;
        attribute efficiency : Real;
        port primarySide : PowerPort;
        port secondarySide : PowerPort;
    }
    
    part def LoadCenter {
        attribute connectedLoad : PowerLevel;
        attribute demandFactor : Real;
        attribute actualDemand : PowerLevel;
        attribute serviceVoltage : VoltageLevel;
        port powerInput : PowerPort;
    }
    
    part def CircuitBreaker {
        attribute ratedCurrent : CurrentLevel;
        attribute tripThreshold : CurrentLevel;
        attribute isOpen : Boolean;
        port breakerInput : PowerPort;
        port breakerOutput : PowerPort;
    }
    
    part def VoltageRegulator {
        attribute nominalVoltage : VoltageLevel;
        attribute regulationRange : VoltageLevel;
        attribute tapPosition : Integer;
        port regulatorInput : PowerPort;
        port regulatorOutput : PowerPort;
    }
    
    part def ProtectionRelay {
        attribute overcurrentThreshold : CurrentLevel;
        attribute undervoltageThreshold : VoltageLevel;
        attribute overvoltageThreshold : VoltageLevel;
        attribute operatingTime : ISQ::TimeValue;
    }
    
    action def MonitorGridConditions {
        in gridVoltage : VoltageLevel;
        in gridCurrent : CurrentLevel;
        in gridFrequency : FrequencyValue;
        out gridState : GridState;
    }
    
    action def CalculateTotalLoad {
        in loadDemands : PowerLevel[*];
        in demandFactors : Real[*];
        out totalDemand : PowerLevel;
    }
    
    action def RegulateVoltage {
        in measuredVoltage : VoltageLevel;
        in targetVoltage : VoltageLevel;
        in regulationRange : VoltageLevel;
        out tapAdjustment : Integer;
    }
    
    action def DetectFault {
        in measuredCurrent : CurrentLevel;
        in measuredVoltage : VoltageLevel;
        in normalCurrent : CurrentLevel;
        in normalVoltage : VoltageLevel;
        out faultDetected : Boolean;
        out faultCondition : FaultCondition;
    }
    
    action def IsolateFaultedSection {
        in faultLocation : String;
        in faultSeverity : Real;
        out breakersToTrip : String[*];
    }
    
    action def ReconfigureNetwork {
        in isolatedSections : String[*];
        in availableRoutes : String[*];
        out switchingSequence : String[*];
        out restoredLoads : String[*];
    }
    
    action def BalanceLoad {
        in feederLoads : PowerLevel[*];
        in feederCapacities : PowerLevel[*];
        out transferCommands : String[*];
    }
    
    action def DistributeElectricalPower {
        in generatedPower : PowerLevel;
        in transmissionVoltage : VoltageLevel;
        in distributionVoltage : VoltageLevel;
        in serviceVoltage : VoltageLevel;
        in loadDemands : PowerLevel[*];
        out systemState : GridState;
        
        first start;
        then merge monitoringCycle;
        
        then action monitorGrid : MonitorGridConditions {
            in gridVoltage = transmissionVoltage;
            in gridCurrent;
            in gridFrequency;
            out gridState;
        }
        
        then action calculateLoad : CalculateTotalLoad {
            in loadDemands = loadDemands;
            in demandFactors;
            out totalDemand;
        }
        
        then decide;
            if monitorGrid.gridState.isStable then normalOperation;
            if !monitorGrid.gridState.isStable then faultHandling;
        
        action normalOperation {
            action regulateVoltage : RegulateVoltage {
                in measuredVoltage = monitorGrid.gridState.voltage;
                in targetVoltage = distributionVoltage;
                in regulationRange;
                out tapAdjustment;
            }
            then action balanceLoad : BalanceLoad {
                in feederLoads;
                in feederCapacities;
                out transferCommands;
            }
            then assign systemState := monitorGrid.gridState;
        }
        then monitoringCycle;
        
        action faultHandling {
            action detectFault : DetectFault {
                in measuredCurrent;
                in measuredVoltage = monitorGrid.gridState.voltage;
                in normalCurrent;
                in normalVoltage;
                out faultDetected;
                out faultCondition;
            }
            then if detectFault.faultDetected {
                action isolate : IsolateFaultedSection {
                    in faultLocation = detectFault.faultCondition.location;
                    in faultSeverity = detectFault.faultCondition.severity;
                    out breakersToTrip;
                }
                then action reconfigure : ReconfigureNetwork {
                    in isolatedSections;
                    in availableRoutes;
                    out switchingSequence;
                    out restoredLoads;
                }
            }
        }
        then monitoringCycle;
    }
    
    part powerDistributionGrid {
        part generator : PowerGenerator {
            attribute :>> ratedPower = 150.0e6;
            attribute :>> ratedVoltage = 13800.0;
            attribute :>> ratedFrequency = 60.0;
        }
        
        part stepUpTransformer : StepUpTransformer {
            attribute :>> primaryVoltage = 13800.0;
            attribute :>> secondaryVoltage = 138000.0;
            attribute :>> transformerRatio = 10.0;
            attribute :>> efficiency = 0.985;
            attribute :>> ratedPower = 150.0e6;
        }
        
        part transmissionBreaker : CircuitBreaker {
            attribute :>> ratedCurrent = 1200.0;
            attribute :>> tripThreshold = 1320.0;
            attribute :>> isOpen = false;
        }
        
        part transmissionLine : TransmissionLine {
            attribute :>> lineVoltage = 138000.0;
            attribute :>> resistance = 0.08;
            attribute :>> length = 50000.0;
            attribute :>> maxCurrent = 1200.0;
        }
        
        part stepDownTransformer : StepDownTransformer {
            attribute :>> primaryVoltage = 138000.0;
            attribute :>> secondaryVoltage = 13800.0;
            attribute :>> transformerRatio = 10.0;
            attribute :>> efficiency = 0.985;
            attribute :>> ratedPower = 140.0e6;
        }
        
        part substation : DistributionSubstation {
            attribute :>> substationVoltage = 13800.0;
            attribute :>> maxCapacity = 130.0e6;
        }
        
        part substationBreaker : CircuitBreaker {
            attribute :>> ratedCurrent = 6000.0;
            attribute :>> tripThreshold = 6600.0;
            attribute :>> isOpen = false;
        }
        
        part voltageRegulator : VoltageRegulator {
            attribute :>> nominalVoltage = 13800.0;
            attribute :>> regulationRange = 1380.0;
            attribute :>> tapPosition = 0;
        }
        
        part feeder1 : DistributionFeeder {
            attribute :>> feederVoltage = 13800.0;
            attribute :>> resistance = 0.15;
            attribute :>> maxCurrent = 2000.0;
        }
        
        part feeder2 : DistributionFeeder {
            attribute :>> feederVoltage = 13800.0;
            attribute :>> resistance = 0.15;
            attribute :>> maxCurrent = 2000.0;
        }
        
        part feeder3 : DistributionFeeder {
            attribute :>> feederVoltage = 13800.0;
            attribute :>> resistance = 0.15;
            attribute :>> maxCurrent = 2000.0;
        }
        
        part feederBreaker1 : CircuitBreaker {
            attribute :>> ratedCurrent = 2000.0;
            attribute :>> tripThreshold = 2200.0;
            attribute :>> isOpen = false;
        }
        
        part feederBreaker2 : CircuitBreaker {
            attribute :>> ratedCurrent = 2000.0;
            attribute :>> tripThreshold = 2200.0;
            attribute :>> isOpen = false;
        }
        
        part feederBreaker3 : CircuitBreaker {
            attribute :>> ratedCurrent = 2000.0;
            attribute :>> tripThreshold = 2200.0;
            attribute :>> isOpen = false;
        }
        
        part serviceTransformer1 : ServiceTransformer {
            attribute :>> primaryVoltage = 13800.0;
            attribute :>> secondaryVoltage = 480.0;
            attribute :>> transformerRatio = 28.75;
            attribute :>> efficiency = 0.97;
        }
        
        part serviceTransformer2 : ServiceTransformer {
            attribute :>> primaryVoltage = 13800.0;
            attribute :>> secondaryVoltage = 240.0;
            attribute :>> transformerRatio = 57.5;
            attribute :>> efficiency = 0.96;
        }
        
        part serviceTransformer3 : ServiceTransformer {
            attribute :>> primaryVoltage = 13800.0;
            attribute :>> secondaryVoltage = 480.0;
            attribute :>> transformerRatio = 28.75;
            attribute :>> efficiency = 0.97;
        }
        
        part industrialLoad : LoadCenter {
            attribute :>> connectedLoad = 25.0e6;
            attribute :>> demandFactor = 0.85;
            attribute :>> actualDemand = 21.25e6;
            attribute :>> serviceVoltage = 480.0;
        }
        
        part residentialLoad : LoadCenter {
            attribute :>> connectedLoad = 15.0e6;
            attribute :>> demandFactor = 0.70;
            attribute :>> actualDemand = 10.5e6;
            attribute :>> serviceVoltage = 240.0;
        }
        
        part commercialLoad : LoadCenter {
            attribute :>> connectedLoad = 20.0e6;
            attribute :>> demandFactor = 0.80;
            attribute :>> actualDemand = 16.0e6;
            attribute :>> serviceVoltage = 480.0;
        }
        
        part protectionRelay : ProtectionRelay {
            attribute :>> overcurrentThreshold = 6600.0;
            attribute :>> undervoltageThreshold = 12420.0;
            attribute :>> overvoltageThreshold = 15180.0;
            attribute :>> operatingTime = 0.1;
        }
        
        connection generatorToStepUp connect 
            generator.generatorOutput to stepUpTransformer.primarySide;
        
        connection stepUpToTransmissionBreaker connect 
            stepUpTransformer.secondarySide to transmissionBreaker.breakerInput;
        
        connection transmissionBreakerToLine connect 
            transmissionBreaker.breakerOutput to transmissionLine.lineInput;
        
        connection transmissionLineToStepDown connect 
            transmissionLine.lineOutput to stepDownTransformer.primarySide;
        
        connection stepDownToSubstationBreaker connect 
            stepDownTransformer.secondarySide to substationBreaker.breakerInput;
        
        connection substationBreakerToSubstation connect 
            substationBreaker.breakerOutput to substation.hvInput;
        
        connection substationToRegulator connect 
            substation.mvOutput1 to voltageRegulator.regulatorInput;
        
        connection regulatorToFeeder1Breaker connect 
            voltageRegulator.regulatorOutput to feederBreaker1.breakerInput;
        
        connection substationToFeeder2Breaker connect 
            substation.mvOutput2 to feederBreaker2.breakerInput;
        
        connection substationToFeeder3Breaker connect 
            substation.mvOutput3 to feederBreaker3.breakerInput;
        
        connection feeder1BreakerToFeeder1 connect 
            feederBreaker1.breakerOutput to feeder1.feederInput;
        
        connection feeder2BreakerToFeeder2 connect 
            feederBreaker2.breakerOutput to feeder2.feederInput;
        
        connection feeder3BreakerToFeeder3 connect 
            feederBreaker3.breakerOutput to feeder3.feederInput;
        
        connection feeder1ToServiceTransformer1 connect 
            feeder1.feederOutput to serviceTransformer1.primarySide;
        
        connection feeder2ToServiceTransformer2 connect 
            feeder2.feederOutput to serviceTransformer2.primarySide;
        
        connection feeder3ToServiceTransformer3 connect 
            feeder3.feederOutput to serviceTransformer3.primarySide;
        
        connection serviceTransformer1ToIndustrialLoad connect 
            serviceTransformer1.secondarySide to industrialLoad.powerInput;
        
        connection serviceTransformer2ToResidentialLoad connect 
            serviceTransformer2.secondarySide to residentialLoad.powerInput;
        
        connection serviceTransformer3ToCommercialLoad connect 
            serviceTransformer3.secondarySide to commercialLoad.powerInput;
        
        perform action distributeElectricalPower : DistributeElectricalPower {
            in generatedPower = generator.ratedPower;
            in transmissionVoltage = transmissionLine.lineVoltage;
            in distributionVoltage = substation.substationVoltage;
            in serviceVoltage = industrialLoad.serviceVoltage;
            in loadDemands = (industrialLoad.actualDemand, residentialLoad.actualDemand, commercialLoad.actualDemand);
            out systemState;
        }
    }
    
    requirement <'REQ-EPDS-001'> primaryFunction {
        doc /* The electric power distribution system shall reliably 
             * transmit electrical power from generation sources through 
             * high-voltage transmission lines, step down voltage through 
             * distribution substations, and deliver power to industrial, 
             * commercial, and residential loads at appropriate service 
             * voltage levels with continuous monitoring and fault protection.
             */
        subject system :> powerDistributionGrid;
    }
    
    requirement <'REQ-EPDS-002'> transmissionCapacity {
        doc /* The transmission system shall have sufficient capacity 
             * to transmit at least 150 MW of power at 138 kV.
             */
        subject transmission :> powerDistributionGrid.transmissionLine;
        
        assert constraint {
            transmission.lineVoltage >= 138000.0
        }
    }
    
    requirement <'REQ-EPDS-003'> voltageRegulation {
        doc /* The distribution system shall maintain voltage within 
             * ±10% of nominal voltage at all load centers.
             */
        subject regulator :> powerDistributionGrid.voltageRegulator;
        
        assert constraint {
            regulator.regulationRange <= regulator.nominalVoltage * 0.1
        }
    }
    
    requirement <'REQ-EPDS-004'> loadSupport {
        doc /* The system shall support total connected load demand 
             * with at least 20% capacity margin for peak conditions.
             */
        subject system :> powerDistributionGrid;
        
        assert constraint {
            system.generator.ratedPower >= 
                (system.industrialLoad.actualDemand + 
                 system.residentialLoad.actualDemand + 
                 system.commercialLoad.actualDemand) * 1.2
        }
    }
    
    requirement <'REQ-EPDS-005'> transformerEfficiency {
        doc /* All transformers shall operate at minimum 96% efficiency 
             * at rated load to minimize transmission losses.
             */
        subject stepUpTrans :> powerDistributionGrid.stepUpTransformer;
        subject stepDownTrans :> powerDistributionGrid.stepDownTransformer;
        
        assert constraint {
            stepUpTrans.efficiency >= 0.96 and stepDownTrans.efficiency >= 0.96
        }
    }
    
    requirement <'REQ-EPDS-006'> faultProtection {
        doc /* The protection system shall detect and isolate faults 
             * within 100 milliseconds to prevent cascading failures.
             */
        subject relay :> powerDistributionGrid.protectionRelay;
        
        assert constraint {
            relay.operatingTime <= 0.1
        }
    }
    
    satisfy primaryFunction by powerDistributionGrid;
}
