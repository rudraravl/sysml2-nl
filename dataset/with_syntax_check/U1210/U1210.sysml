package SmartGridSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def PowerValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def EnergyValue :> Real;
    attribute def PercentageValue :> Real;

    enum def GridState {
        stable;
        overload;
        underload;
        critical;
    }

    enum def ConsumerPriority {
        critical;
        high;
        medium;
        low;
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute frequency : FrequencyValue;
        attribute activePower : PowerValue;
    }

    item def GridData {
        attribute timestamp : String;
        attribute totalDemand : PowerValue;
        attribute totalSupply : PowerValue;
        attribute gridState : GridState;
    }

    port def PowerPort {
        out powerSupply : ElectricalPower;
        in powerDemand : ElectricalPower;
    }

    port def CommunicationPort {
        out statusData : GridData;
        in controlCommand : GridData;
    }

    part def PowerGenerator {
        attribute ratedCapacity : PowerValue;
        attribute currentOutput : PowerValue;
        attribute efficiency : PercentageValue;
        port powerOut : PowerPort;
        port commPort : CommunicationPort;
        assert constraint { currentOutput <= ratedCapacity }
    }

    part def SolarArray :> PowerGenerator {
        attribute solarIrradiance : PowerValue;
        attribute panelArea : Real;
    }

    part def WindTurbine :> PowerGenerator {
        attribute windSpeed : Real;
        attribute rotorDiameter : Real;
    }

    part def NaturalGasPlant :> PowerGenerator {
        attribute fuelConsumption : Real;
    }

    part def BatteryStorage {
        attribute storageCapacity : EnergyValue;
        attribute currentCharge : EnergyValue;
        attribute maxChargeRate : PowerValue;
        attribute maxDischargeRate : PowerValue;
        port powerPort : PowerPort;
        port commPort : CommunicationPort;
        assert constraint { currentCharge <= storageCapacity }
        assert constraint { currentCharge >= 0.0 }
    }

    part def TransmissionLine {
        attribute maxCapacity : PowerValue;
        attribute currentLoad : PowerValue;
        attribute lineLength : Real;
        port inputPort : PowerPort;
        port outputPort : PowerPort;
        assert constraint { currentLoad <= maxCapacity }
    }

    part def Substation {
        attribute substationId : String;
        attribute transformerCapacity : PowerValue;
        port primaryPort : PowerPort;
        port secondaryPort : PowerPort[1..*];
        port commPort : CommunicationPort;
    }

    part def SmartMeter {
        attribute meterId : String;
        attribute instantaneousDemand : PowerValue;
        attribute cumulativeConsumption : EnergyValue;
        port measurementPort : PowerPort;
        port dataPort : CommunicationPort;
    }

    part def Consumer {
        attribute consumerId : String;
        attribute priority : ConsumerPriority;
        attribute baselineDemand : PowerValue;
        attribute currentDemand : PowerValue;
        part meter : SmartMeter;
        port powerIn : PowerPort;
    }

    part def GridControlCenter {
        attribute controlCenterId : String;
        port dataAggregation : CommunicationPort[1..*];
        port commandDispatch : CommunicationPort[1..*];
        perform action controlLoop : GridControlLoop;
    }

    action def MonitorGrid {
        in totalGeneration : PowerValue;
        in totalConsumption : PowerValue;
        in storageLevel : EnergyValue;
        out currentState : GridState;
        out imbalance : PowerValue;
    }

    action def OptimizeGeneration {
        in demandForecast : PowerValue;
        in renewableAvailability : PowerValue;
        in storageCapacity : EnergyValue;
        out generationSchedule : PowerValue[*];
    }

    action def ManageStorage {
        in gridImbalance : PowerValue;
        in currentCharge : EnergyValue;
        in storageCapacity : EnergyValue;
        out storageAction : PowerValue;
    }

    action def LoadShedding {
        in excessDemand : PowerValue;
        in consumerPriorities : ConsumerPriority[*];
        out shedSchedule : PowerValue[*];
    }

    action def GridControlLoop {
        first start;
        then merge monitoringCycle;
        
        then action monitor : MonitorGrid {
            in totalGeneration : PowerValue;
            in totalConsumption : PowerValue;
            in storageLevel : EnergyValue;
            out gridState : GridState;
            out powerImbalance : PowerValue;
        }
        
        then decide;
            if monitor.gridState == GridState::stable then maintainOperation;
            if monitor.gridState == GridState::overload then handleOverload;
            if monitor.gridState == GridState::underload then handleUnderload;
            if monitor.gridState == GridState::critical then emergencyResponse;
        
        action maintainOperation : OptimizeGeneration {
            in demandForecast = monitor.totalConsumption;
            out generationSchedule : PowerValue[*];
        }
        then monitoringCycle;
        
        action handleOverload {
            action shedLoad : LoadShedding {
                in excessDemand = monitor.powerImbalance;
                out shedSchedule : PowerValue[*];
            }
            then action dischargeStorage : ManageStorage {
                in gridImbalance = monitor.powerImbalance;
                out storageAction : PowerValue;
            }
        }
        then monitoringCycle;
        
        action handleUnderload {
            action chargeStorage : ManageStorage {
                in gridImbalance = monitor.powerImbalance;
                out storageAction : PowerValue;
            }
            then action reduceGeneration : OptimizeGeneration {
                in demandForecast = monitor.totalConsumption;
                out generationSchedule : PowerValue[*];
            }
        }
        then monitoringCycle;
        
        action emergencyResponse {
            action isolateFault;
            then action restoreService;
        }
        then monitoringCycle;
    }

    part def SmartGrid {
        attribute nominalVoltage : VoltageValue;
        attribute nominalFrequency : FrequencyValue;
        attribute totalInstalledCapacity : PowerValue;
        attribute currentTotalDemand : PowerValue;
        attribute gridEfficiency : PercentageValue;
        
        part controlCenter : GridControlCenter {
            attribute :>> controlCenterId = "CENTRAL_CTRL_01";
        }
        
        part generation {
            part solarFarms : SolarArray[5] {
                attribute :>> ratedCapacity = 100000.0;
                attribute :>> efficiency = 0.18;
            }
            
            part windFarms : WindTurbine[3] {
                attribute :>> ratedCapacity = 250000.0;
                attribute :>> efficiency = 0.35;
            }
            
            part baseloadPlant : NaturalGasPlant[1] {
                attribute :>> ratedCapacity = 1000000.0;
                attribute :>> efficiency = 0.55;
            }
        }
        
        part storage : BatteryStorage[10] {
            attribute :>> storageCapacity = 500000.0;
            attribute :>> maxChargeRate = 50000.0;
            attribute :>> maxDischargeRate = 50000.0;
        }
        
        part transmission {
            part highVoltageLines : TransmissionLine[8] {
                attribute :>> maxCapacity = 500000.0;
            }
            
            part mediumVoltageLines : TransmissionLine[20] {
                attribute :>> maxCapacity = 100000.0;
            }
        }
        
        part distribution {
            part primarySubstations : Substation[4] {
                attribute :>> transformerCapacity = 750000.0;
            }
            
            part secondarySubstations : Substation[15] {
                attribute :>> transformerCapacity = 200000.0;
            }
        }
        
        part consumers {
            part industrial : Consumer[20] {
                attribute :>> priority = ConsumerPriority::high;
                attribute :>> baselineDemand = 50000.0;
            }
            
            part commercial : Consumer[100] {
                attribute :>> priority = ConsumerPriority::medium;
                attribute :>> baselineDemand = 10000.0;
            }
            
            part residential : Consumer[1000] {
                attribute :>> priority = ConsumerPriority::low;
                attribute :>> baselineDemand = 2000.0;
            }
        }
        
        connection generationToTransmission connect 
            generation.solarFarms.powerOut to transmission.highVoltageLines.inputPort;
        
        connection windToTransmission connect 
            generation.windFarms.powerOut to transmission.highVoltageLines.inputPort;
        
        connection baseloadToTransmission connect 
            generation.baseloadPlant.powerOut to transmission.highVoltageLines.inputPort;
        
        connection storageToTransmission connect 
            storage.powerPort to transmission.highVoltageLines.inputPort;
        
        connection transmissionToDistribution connect 
            transmission.highVoltageLines.outputPort to distribution.primarySubstations.primaryPort;
        
        connection primaryToSecondary connect 
            distribution.primarySubstations.secondaryPort to distribution.secondarySubstations.primaryPort;
        
        connection distributionToConsumers connect 
            distribution.secondarySubstations.secondaryPort to consumers.industrial.powerIn;
        
        connection controlToGeneration connect 
            controlCenter.commandDispatch to generation.solarFarms.commPort;
        
        connection metersToControl connect 
            consumers.industrial.meter.dataPort to controlCenter.dataAggregation;
        
        assert constraint totalCapacity {
            totalInstalledCapacity == 
                generation.solarFarms.ratedCapacity * 5 + 
                generation.windFarms.ratedCapacity * 3 + 
                generation.baseloadPlant.ratedCapacity
        }
        
        assert constraint efficiencyRequirement {
            gridEfficiency >= 0.90
        }
    }

    requirement <'REQ-SG-PRIMARY'> intelligentGridManagement {
        doc /* The smart grid system shall autonomously balance electrical 
             * power generation, storage, transmission, and consumption in 
             * real-time to ensure reliable, efficient, and sustainable 
             * energy delivery to all connected consumers while integrating 
             * renewable energy sources and optimizing overall grid performance.
             */
        subject grid : SmartGrid;
        
        require supplyDemandBalance;
        require renewableIntegration;
        require storageUtilization;
        require reliableOperation;
    }

    requirement <'REQ-SG-001'> supplyDemandBalance {
        doc /* The system shall maintain supply-demand balance within 
             * 3% tolerance during normal operating conditions.
             */
        subject grid : SmartGrid;
        
        assert constraint {
            (grid.currentTotalDemand - grid.totalInstalledCapacity).abs() / 
            grid.totalInstalledCapacity <= 0.03
        }
    }

    requirement <'REQ-SG-002'> renewableIntegration {
        doc /* The system shall prioritize renewable energy sources 
             * when available and automatically adjust conventional 
             * generation accordingly.
             */
        subject grid : SmartGrid;
    }

    requirement <'REQ-SG-003'> storageUtilization {
        doc /* Energy storage systems shall provide at least 3 hours 
             * of average grid demand capacity for load balancing.
             */
        subject grid : SmartGrid;
        
        assert constraint {
            grid.storage.storageCapacity >= 6000000.0
        }
    }

    requirement <'REQ-SG-004'> reliableOperation {
        doc /* The grid shall maintain operational efficiency above 
             * 90% under all normal operating conditions.
             */
        subject grid : SmartGrid;
        
        assert constraint {
            grid.gridEfficiency >= 0.90
        }
    }

    requirement <'REQ-SG-005'> voltageStability {
        doc /* The system shall maintain voltage within ±5% of 
             * nominal voltage at all distribution points.
             */
        subject grid : SmartGrid;
    }

    requirement <'REQ-SG-006'> frequencyRegulation {
        doc /* The system shall maintain grid frequency within 
             * ±0.2 Hz of nominal frequency.
             */
        subject grid : SmartGrid;
    }

    satisfy intelligentGridManagement by SmartGrid.controlCenter.controlLoop;
    
    part smartGridInstance : SmartGrid {
        attribute :>> nominalVoltage = 230000.0;
        attribute :>> nominalFrequency = 60.0;
        attribute :>> gridEfficiency = 0.92;
    }
}
