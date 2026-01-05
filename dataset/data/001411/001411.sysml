package EfficientEnergyManagementSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package ValueDefinitions {
        attribute def EnergyEfficiency :> Real;
        attribute def LoadFactor :> Real;
        attribute def PowerFactor :> Real;
        
        enum def SystemMode {
            enum peak;
            enum normal;
            enum economy;
            enum standby;
        }
        
        enum def SourcePriority {
            enum renewable;
            enum storage;
            enum grid;
        }
        
        item def ElectricalPower {
            attribute activePower : PowerValue;
            attribute reactivePower : PowerValue;
            attribute voltage : ElectricPotentialValue;
            attribute current : ElectricCurrentValue;
            attribute frequency : FrequencyValue;
        }
        
        item def EnergyMetrics {
            attribute consumed : EnergyValue;
            attribute generated : EnergyValue;
            attribute stored : EnergyValue;
            attribute efficiency : EnergyEfficiency;
        }
    }

    package PortDefinitions {
        port def PowerInputPort {
            in item powerSupply : ValueDefinitions::ElectricalPower;
        }
        
        port def PowerOutputPort {
            out item powerDelivery : ValueDefinitions::ElectricalPower;
        }
        
        port def BidirectionalPowerPort {
            in item powerIn : ValueDefinitions::ElectricalPower;
            out item powerOut : ValueDefinitions::ElectricalPower;
        }
        
        port def ControlPort {
            in attribute modeCommand : ValueDefinitions::SystemMode;
            in attribute priorityCommand : ValueDefinitions::SourcePriority;
            out attribute currentMode : ValueDefinitions::SystemMode;
            out attribute systemStatus : Real;
        }
        
        port def MonitoringPort {
            out attribute metrics : ValueDefinitions::EnergyMetrics;
            out attribute efficiency : Real;
            out attribute loadLevel : Real;
        }
    }

    package ComponentDefinitions {
        part def RenewableEnergySource {
            attribute maxCapacity : PowerValue;
            attribute currentOutput : PowerValue;
            attribute availability : Real;
            port powerOut : PortDefinitions::PowerOutputPort;
        }
        
        part def EnergyStorageSystem {
            attribute capacity : EnergyValue;
            attribute stateOfCharge : Real;
            attribute chargeRate : PowerValue;
            attribute dischargeRate : PowerValue;
            attribute cycleEfficiency : Real;
            port storagePort : PortDefinitions::BidirectionalPowerPort;
        }
        
        part def GridInterface {
            attribute gridVoltage : ElectricPotentialValue;
            attribute maxDrawPower : PowerValue;
            attribute maxFeedPower : PowerValue;
            attribute tariffRate : Real;
            port gridPort : PortDefinitions::BidirectionalPowerPort;
        }
        
        part def LoadController {
            attribute totalLoad : PowerValue;
            attribute criticalLoad : PowerValue;
            attribute deferrableLoad : PowerValue;
            attribute currentDemand : PowerValue;
            port loadPort : PortDefinitions::PowerInputPort;
        }
        
        part def EnergyOptimizer {
            attribute targetEfficiency : Real;
            attribute currentEfficiency : Real;
            attribute optimizationInterval : Real;
            port controlOut : PortDefinitions::ControlPort;
            port monitorIn : PortDefinitions::MonitoringPort;
        }
        
        part def PowerDistributionUnit {
            attribute inputVoltage : ElectricPotentialValue;
            attribute outputVoltage : ElectricPotentialValue;
            attribute conversionEfficiency : Real;
            attribute maxThroughput : PowerValue;
            port primaryIn : PortDefinitions::PowerInputPort;
            port renewableIn : PortDefinitions::PowerInputPort;
            port storagePort : PortDefinitions::BidirectionalPowerPort;
            port loadOut : PortDefinitions::PowerOutputPort;
        }
        
        part def EnergyMonitor {
            attribute samplingRate : FrequencyValue;
            attribute measurementAccuracy : Real;
            port sensorPort : PortDefinitions::MonitoringPort;
        }
    }

    package BehaviorDefinitions {
        action def MeasureEnergyFlow {
            in renewablePower : PowerValue;
            in storagePower : PowerValue;
            in gridPower : PowerValue;
            in loadDemand : PowerValue;
            out totalInput : PowerValue;
            out totalOutput : PowerValue;
            out instantEfficiency : Real;
        }
        
        action def OptimizeSourceAllocation {
            in availableRenewable : PowerValue;
            in storageSOC : Real;
            in gridAvailability : Real;
            in currentDemand : PowerValue;
            in currentMode : ValueDefinitions::SystemMode;
            out renewableAllocation : PowerValue;
            out storageAllocation : PowerValue;
            out gridAllocation : PowerValue;
            out targetMode : ValueDefinitions::SystemMode;
        }
        
        action def ManageStorageOperation {
            in storageSOC : Real;
            in excessPower : PowerValue;
            in deficitPower : PowerValue;
            in cycleEfficiency : Real;
            out chargeCommand : PowerValue;
            out dischargeCommand : PowerValue;
        }
        
        action def ControlLoadDistribution {
            in availablePower : PowerValue;
            in criticalLoad : PowerValue;
            in deferrableLoad : PowerValue;
            in systemMode : ValueDefinitions::SystemMode;
            out activatedLoad : PowerValue;
            out deferredLoad : PowerValue;
        }
        
        action def EvaluateSystemPerformance {
            in energyConsumed : EnergyValue;
            in energyGenerated : EnergyValue;
            in operatingTime : Real;
            out overallEfficiency : Real;
            out costSavings : Real;
            out carbonReduction : Real;
        }
        
        action def ManageEnergySystem {
            in systemDemand : PowerValue;
            in renewableAvailable : PowerValue;
            in storageState : Real;
            out systemEfficiency : Real;
            out operatingMode : ValueDefinitions::SystemMode;
            
            first start;
            then merge continuousOperation;
            
            then action measure : MeasureEnergyFlow {
                in renewablePower : PowerValue;
                in storagePower : PowerValue;
                in gridPower : PowerValue;
                in loadDemand : PowerValue;
                out totalInput : PowerValue;
                out totalOutput : PowerValue;
                out instantEfficiency : Real;
            }
            
            flow measure.instantEfficiency to optimize.gridAvailability;
            
            then action optimize : OptimizeSourceAllocation {
                in availableRenewable : PowerValue;
                in storageSOC : Real;
                in gridAvailability : Real;
                in currentDemand : PowerValue;
                in currentMode : ValueDefinitions::SystemMode;
                out renewableAllocation : PowerValue;
                out storageAllocation : PowerValue;
                out gridAllocation : PowerValue;
                out targetMode : ValueDefinitions::SystemMode;
            }
            
            then decide;
                if optimize.storageAllocation > 0.0 then chargeStorage;
                if optimize.storageAllocation < 0.0 then dischargeStorage;
                else maintainStorage;
            
            action chargeStorage : ManageStorageOperation {
                in storageSOC : Real;
                in excessPower : PowerValue;
                in deficitPower : PowerValue;
                in cycleEfficiency : Real;
                out chargeCommand : PowerValue;
                out dischargeCommand : PowerValue;
            }
            then distributeLoad;
            
            action dischargeStorage : ManageStorageOperation {
                in storageSOC : Real;
                in excessPower : PowerValue;
                in deficitPower : PowerValue;
                in cycleEfficiency : Real;
                out chargeCommand : PowerValue;
                out dischargeCommand : PowerValue;
            }
            then distributeLoad;
            
            action maintainStorage;
            then distributeLoad;
            
            action distributeLoad : ControlLoadDistribution {
                in availablePower : PowerValue;
                in criticalLoad : PowerValue;
                in deferrableLoad : PowerValue;
                in systemMode : ValueDefinitions::SystemMode;
                out activatedLoad : PowerValue;
                out deferredLoad : PowerValue;
            }
            
            flow distributeLoad.activatedLoad to evaluate.operatingTime;
            
            then action evaluate : EvaluateSystemPerformance {
                in energyConsumed : EnergyValue;
                in energyGenerated : EnergyValue;
                in operatingTime : Real;
                out overallEfficiency : Real;
                out costSavings : Real;
                out carbonReduction : Real;
            }
            
            then continuousOperation;
        }
        
        state def EnergySystemStates {
            entry; then initialization;
            
            state initialization;
            then operationalStates;
            
            state operationalStates parallel {
                state powerManagement {
                    entry; then peakMode;
                    
                    state peakMode;
                    accept at when loadFactor > 0.8;
                    do action maximizeRenewable : OptimizeSourceAllocation;
                    
                    transition peakToNormal
                        first peakMode
                        accept when loadFactor <= 0.6
                        then normalMode;
                    
                    state normalMode;
                    accept at when loadFactor > 0.4 and loadFactor <= 0.8;
                    do action balanceSources : OptimizeSourceAllocation;
                    
                    transition normalToPeak
                        first normalMode
                        accept when loadFactor > 0.8
                        then peakMode;
                    
                    transition normalToEconomy
                        first normalMode
                        accept when loadFactor <= 0.4
                        then economyMode;
                    
                    state economyMode;
                    accept at when loadFactor <= 0.4;
                    do action minimizeCost : OptimizeSourceAllocation;
                    
                    transition economyToNormal
                        first economyMode
                        accept when loadFactor > 0.4
                        then normalMode;
                    
                    transition economyToStandby
                        first economyMode
                        accept when loadFactor <= 0.1
                        then standbyMode;
                    
                    state standbyMode;
                    accept at when loadFactor <= 0.1;
                    
                    transition standbyToEconomy
                        first standbyMode
                        accept when loadFactor > 0.1
                        then economyMode;
                }
                
                state storageManagement {
                    entry; then charging;
                    
                    state charging;
                    accept at when stateOfCharge < 0.9 and excessPower > 0.0;
                    do action chargeAction : ManageStorageOperation;
                    
                    transition chargingToFull
                        first charging
                        accept when stateOfCharge >= 0.9
                        then fullCharge;
                    
                    transition chargingToDischarging
                        first charging
                        accept when deficitPower > 0.0
                        then discharging;
                    
                    state fullCharge;
                    accept at when stateOfCharge >= 0.9;
                    
                    transition fullToDischarging
                        first fullCharge
                        accept when deficitPower > 0.0
                        then discharging;
                    
                    state discharging;
                    accept at when stateOfCharge > 0.2 and deficitPower > 0.0;
                    do action dischargeAction : ManageStorageOperation;
                    
                    transition dischargingToCharging
                        first discharging
                        accept when excessPower > 0.0
                        then charging;
                    
                    transition dischargingToLow
                        first discharging
                        accept when stateOfCharge <= 0.2
                        then lowCharge;
                    
                    state lowCharge;
                    accept at when stateOfCharge <= 0.2;
                    
                    transition lowToCharging
                        first lowCharge
                        accept when excessPower > 0.0
                        then charging;
                }
            }
        }
    }

    package RequirementsDefinition {
        requirement def EnergyEfficiencyRequirement {
            doc /* The system shall maximize energy efficiency by intelligently managing
                 * multiple energy sources and optimizing power distribution based on
                 * real-time demand and availability conditions.
                 */
            subject system : EnergyManagementSystem;
        }
        
        requirement <'REQ-2001'> minimumSystemEfficiency : EnergyEfficiencyRequirement {
            doc /* The overall system energy efficiency shall be maintained at or above 92%
                 * during normal operating conditions with balanced load.
                 */
            subject system :>> energyManagementSystem;
            assert constraint {
                system.optimizer.currentEfficiency >= 92.0
            }
        }
        
        requirement <'REQ-2002'> renewablePrioritization : EnergyEfficiencyRequirement {
            doc /* The system shall prioritize renewable energy sources over grid power
                 * when renewable generation meets or exceeds current demand.
                 */
            subject system :>> energyManagementSystem;
        }
        
        requirement <'REQ-2003'> storageOptimization : EnergyEfficiencyRequirement {
            doc /* The energy storage system shall maintain state of charge between 20% and 90%
                 * to maximize battery lifespan and ensure reserve capacity availability.
                 */
            subject storage :>> energyManagementSystem.batteryStorage;
            assert constraint {
                storage.stateOfCharge >= 20.0 and storage.stateOfCharge <= 90.0
            }
        }
        
        requirement <'REQ-2004'> loadManagement : EnergyEfficiencyRequirement {
            doc /* The system shall automatically defer non-critical loads when available power
                 * falls below 80% of total demand to maintain critical operations.
                 */
            subject controller :>> energyManagementSystem.loadController;
        }
        
        requirement <'REQ-2005'> powerQuality : EnergyEfficiencyRequirement {
            doc /* The power distribution unit shall maintain voltage regulation within ±3%
                 * and power factor above 0.95 to ensure efficient energy transfer.
                 */
            subject pdu :>> energyManagementSystem.distributionUnit;
            assert constraint {
                pdu.conversionEfficiency >= 95.0
            }
        }
        
        requirement <'REQ-2006'> responseTime : EnergyEfficiencyRequirement {
            doc /* The system shall respond to load changes and optimize source allocation
                 * within 100 milliseconds to maintain stable operation.
                 */
            subject optimizer :>> energyManagementSystem.optimizer;
            assert constraint {
                optimizer.optimizationInterval <= 0.1
            }
        }
    }

    package SystemArchitecture {
        part def EnergyManagementSystem {
            attribute systemEfficiency : Real;
            attribute operatingMode : ValueDefinitions::SystemMode;
            attribute totalPowerFlow : PowerValue;
            
            port systemControl : PortDefinitions::ControlPort;
            port systemMonitor : PortDefinitions::MonitoringPort;
            
            part solarArray : ComponentDefinitions::RenewableEnergySource {
                :>> maxCapacity = 10000.0;
                :>> currentOutput = 7500.0;
                :>> availability = 0.85;
            }
            
            part windTurbine : ComponentDefinitions::RenewableEnergySource {
                :>> maxCapacity = 5000.0;
                :>> currentOutput = 3200.0;
                :>> availability = 0.72;
            }
            
            part batteryStorage : ComponentDefinitions::EnergyStorageSystem {
                :>> capacity = 50000.0;
                :>> stateOfCharge = 65.0;
                :>> chargeRate = 5000.0;
                :>> dischargeRate = 5000.0;
                :>> cycleEfficiency = 94.0;
            }
            
            part gridInterface : ComponentDefinitions::GridInterface {
                :>> gridVoltage = 240.0;
                :>> maxDrawPower = 15000.0;
                :>> maxFeedPower = 8000.0;
                :>> tariffRate = 0.12;
            }
            
            part loadController : ComponentDefinitions::LoadController {
                :>> totalLoad = 12000.0;
                :>> criticalLoad = 6000.0;
                :>> deferrableLoad = 3000.0;
                :>> currentDemand = 9500.0;
            }
            
            part optimizer : ComponentDefinitions::EnergyOptimizer {
                :>> targetEfficiency = 95.0;
                :>> currentEfficiency = 93.5;
                :>> optimizationInterval = 0.05;
            }
            
            part distributionUnit : ComponentDefinitions::PowerDistributionUnit {
                :>> inputVoltage = 240.0;
                :>> outputVoltage = 120.0;
                :>> conversionEfficiency = 96.5;
                :>> maxThroughput = 20000.0;
            }
            
            part monitor : ComponentDefinitions::EnergyMonitor {
                :>> samplingRate = 1000.0;
                :>> measurementAccuracy = 99.5;
            }
            
            connection solarToDistribution connect 
                solarArray.powerOut to distributionUnit.renewableIn;
            
            connection windToDistribution connect 
                windTurbine.powerOut to distributionUnit.renewableIn;
            
            connection storageToDistribution connect 
                batteryStorage.storagePort to distributionUnit.storagePort;
            
            connection gridToDistribution connect 
                gridInterface.gridPort to distributionUnit.primaryIn;
            
            connection distributionToLoad connect 
                distributionUnit.loadOut to loadController.loadPort;
            
            connection monitorToOptimizer connect 
                monitor.sensorPort to optimizer.monitorIn;
            
            connection optimizerToControl connect 
                optimizer.controlOut to systemControl;
            
            perform action energyManagement : BehaviorDefinitions::ManageEnergySystem;
            
            exhibit state systemBehavior : BehaviorDefinitions::EnergySystemStates;
        }
        
        part energyManagementSystem : EnergyManagementSystem {
            :>> systemEfficiency = 93.5;
            :>> operatingMode = ValueDefinitions::SystemMode::normal;
            :>> totalPowerFlow = 9500.0;
        }
        
        satisfy RequirementsDefinition::minimumSystemEfficiency by energyManagementSystem;
        satisfy RequirementsDefinition::renewablePrioritization by energyManagementSystem;
        satisfy RequirementsDefinition::storageOptimization by energyManagementSystem.batteryStorage;
        satisfy RequirementsDefinition::loadManagement by energyManagementSystem.loadController;
        satisfy RequirementsDefinition::powerQuality by energyManagementSystem.distributionUnit;
        satisfy RequirementsDefinition::responseTime by energyManagementSystem.optimizer;
    }
}
