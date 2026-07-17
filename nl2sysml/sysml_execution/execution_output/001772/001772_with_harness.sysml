package EnergyIndustrySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        attribute def ElectricalPowerValue :> ISQ::PowerValue;
        attribute def VoltageValue :> Real;
        attribute def CurrentValue :> ISQ::ElectricCurrentValue;
        attribute def FrequencyValue :> ISQ::FrequencyValue;
        attribute def EnergyValue :> ISQ::EnergyValue;
        attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
        attribute def PressureValue :> ISQ::PressureValue;
        attribute def MassFlowRateValue :> ISQ::MassFlowRateValue;
        attribute def EfficiencyValue :> Real;
        
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def LoadDemandSignal;
        attribute def EmergencyShutdown;
        attribute def TurbineAtSpeed;
        attribute def GridSynchronized;
        attribute def DemandChange;
        attribute def LoadStable;
        attribute def SystemStopped;
        
        item def Fuel {
            attribute energyContent : EnergyValue;
            attribute flowRate : MassFlowRateValue;
        }
        
        item def Steam {
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute massFlowRate : MassFlowRateValue;
        }
        
        item def ElectricalPower {
            attribute voltage : VoltageValue;
            attribute current : CurrentValue;
            attribute activePower : ElectricalPowerValue;
            attribute frequency : FrequencyValue;
        }
        
        port def FuelPort {
            in fuel : Fuel;
        }
        
        port def SteamPort {
            out steam : Steam;
        }
        
        port def MechanicalPort {
            out torque : ISQ::TorqueValue;
            out rotationalSpeed : ISQ::AngularVelocityValue;
        }
        
        port def ElectricalPort {
            out power : ElectricalPower;
        }
        
        port def ControlPort {
            in demandSignal : LoadDemandSignal;
            out statusFeedback : Real;
        }
        
        part def Boiler {
            port fuelInput : FuelPort;
            port steamOutput : SteamPort;
            attribute efficiency : EfficiencyValue;
            attribute maxSteamPressure : PressureValue;
        }
        
        part def SteamTurbine {
            port steamInput;
            port mechanicalOutput : MechanicalPort;
            attribute stages : Integer;
            attribute efficiency : EfficiencyValue;
        }
        
        part def ElectricalGenerator {
            port mechanicalInput : MechanicalPort;
            port electricalOutput : ElectricalPort;
            attribute ratedPower : ElectricalPowerValue;
            attribute ratedVoltage : VoltageValue;
            attribute efficiency : EfficiencyValue;
        }
        
        part def StepUpTransformer {
            port lowVoltageInput : ElectricalPort;
            port highVoltageOutput : ElectricalPort;
            attribute primaryVoltage : VoltageValue;
            attribute secondaryVoltage : VoltageValue;
            attribute turnsRatio : Real;
        }
        
        part def TransmissionLine {
            port transmissionInput : ElectricalPort;
            port transmissionOutput : ElectricalPort;
            attribute length : ISQ::LengthValue;
            attribute resistance : Real;
            attribute powerLoss : ElectricalPowerValue;
        }
        
        part def StepDownTransformer {
            port highVoltageInput : ElectricalPort;
            port mediumVoltageOutput : ElectricalPort;
            attribute primaryVoltage : VoltageValue;
            attribute secondaryVoltage : VoltageValue;
        }
        
        part def DistributionSubstation {
            port substationInput : ElectricalPort;
            port distributionOutput : ElectricalPort;
            attribute numberOfFeeders : Integer;
            attribute distributionVoltage : VoltageValue;
        }
        
        part def ControlSystem {
            port monitoringPort : ControlPort;
            attribute setPoint : ElectricalPowerValue;
            attribute currentOutput : ElectricalPowerValue;
        }
        
        part def PowerGenerationPlant {
            attribute overallEfficiency : EfficiencyValue;
            attribute ratedCapacity : ElectricalPowerValue;
            part generator : ElectricalGenerator;
        }
        
        action def CombustFuel {
            in fuel : Fuel;
            out thermalEnergy : EnergyValue;
        }
        
        action def GenerateSteam {
            in thermalEnergy : EnergyValue;
            out steam : Steam;
        }
        
        action def DriveTurbine {
            in steam : Steam;
            out mechanicalPower : ISQ::PowerValue;
        }
        
        action def GenerateElectricity {
            in mechanicalPower : ISQ::PowerValue;
            out electricalPower : ElectricalPower;
        }
        
        action def StepUpVoltage {
            in lowVoltage : ElectricalPower;
            out highVoltage : ElectricalPower;
        }
        
        action def TransmitPower {
            in highVoltage : ElectricalPower;
            out transmittedPower : ElectricalPower;
        }
        
        action def StepDownVoltage {
            in highVoltage : ElectricalPower;
            out mediumVoltage : ElectricalPower;
        }
        
        action def DistributePower {
            in mediumVoltage : ElectricalPower;
            out consumerPower : ElectricalPower;
        }
        
        action def MonitorLoad {
            out currentDemand : ElectricalPowerValue;
            out currentSupply : ElectricalPowerValue;
        }
        
        action def AdjustGeneration {
            in demand : ElectricalPowerValue;
            in supply : ElectricalPowerValue;
            out adjustment : Real;
        }
        
        action def SupplyElectricalPower {
            in loadDemand : LoadDemandSignal;
            out deliveredPower : ElectricalPower;
        }
    }
    
    package Requirements {
        requirement <'REQ-ENERGY-001'> primaryFunction {
            doc /* The electrical power generation and distribution system shall 
                 * convert primary fuel energy into electrical energy and deliver 
                 * it to consumers through a transmission and distribution network.
                 */
            subject system : Definitions::PowerGenerationPlant;
        }
        
        requirement <'REQ-ENERGY-002'> generationCapacity {
            doc /* The power generation plant shall have a minimum capacity 
                 * of 600 MW to meet regional demand requirements.
                 */
            subject plant : Definitions::PowerGenerationPlant;
            assert constraint {
                plant.generator.ratedPower >= 600.0
            }
        }
        
        requirement <'REQ-ENERGY-003'> transmissionVoltage {
            doc /* The transmission system shall operate at 345 kV with 
                 * voltage variation not exceeding ±5% under normal load.
                 */
            subject transformer : Definitions::StepUpTransformer;
            assert constraint {
                transformer.secondaryVoltage >= 327.75 and
                transformer.secondaryVoltage <= 362.25
            }
        }
        
        requirement <'REQ-ENERGY-004'> frequencyStability {
            doc /* The electrical grid shall maintain frequency at 60 Hz 
                 * with deviation not exceeding ±0.2 Hz during operation.
                 */
            subject generator : Definitions::ElectricalGenerator;
            assert constraint {
                generator.electricalOutput.power.frequency >= 59.8 and
                generator.electricalOutput.power.frequency <= 60.2
            }
        }
        
        requirement <'REQ-ENERGY-005'> systemEfficiency {
            doc /* The overall system efficiency from fuel input to electrical 
                 * output shall be at least 38% under rated conditions.
                 */
            subject plant : Definitions::PowerGenerationPlant;
            assert constraint {
                plant.overallEfficiency >= 0.38
            }
        }
    }
    
    package SystemArchitecture {
        part powerGenerationSystem : Definitions::PowerGenerationPlant {
            attribute overallEfficiency : Definitions::EfficiencyValue = 0.40;
            attribute ratedCapacity : Definitions::ElectricalPowerValue = 650.0;
            
            part boiler : Definitions::Boiler {
                attribute efficiency = 0.89;
                attribute maxSteamPressure = 17.5;
                port fuelInput : Definitions::FuelPort;
                port steamOutput : Definitions::SteamPort {
                    out steam : Definitions::Steam {
                        attribute temperature = 565.0;
                        attribute pressure = 16.8;
                        attribute massFlowRate = 520.0;
                    }
                }
                perform action combustFuel : Definitions::CombustFuel;
                perform action generateSteam : Definitions::GenerateSteam;
            }
            
            part turbine : Definitions::SteamTurbine {
                attribute stages = 4;
                attribute efficiency = 0.92;
                port steamInput;
                port mechanicalOutput : Definitions::MechanicalPort {
                    out torque : ISQ::TorqueValue;
                    out rotationalSpeed : ISQ::AngularVelocityValue = 3600.0;
                }
                perform action driveTurbine : Definitions::DriveTurbine;
            }
            
            part generator : Definitions::ElectricalGenerator {
                attribute ratedPower = 650.0;
                attribute ratedVoltage = 22.0;
                attribute efficiency = 0.985;
                port mechanicalInput : Definitions::MechanicalPort;
                port electricalOutput : Definitions::ElectricalPort {
                    out power : Definitions::ElectricalPower {
                        attribute voltage = 22.0;
                        attribute frequency = 60.0;
                        attribute activePower = 640.0;
                    }
                }
                perform action generateElectricity : Definitions::GenerateElectricity;
            }
            
            part stepUpTransformer : Definitions::StepUpTransformer {
                attribute primaryVoltage = 22.0;
                attribute secondaryVoltage = 345.0;
                attribute turnsRatio = 15.68;
                port lowVoltageInput : Definitions::ElectricalPort;
                port highVoltageOutput : Definitions::ElectricalPort {
                    out power : Definitions::ElectricalPower {
                        attribute voltage = 345.0;
                        attribute frequency = 60.0;
                    }
                }
                perform action stepUpVoltage : Definitions::StepUpVoltage;
            }
            
            part transmissionLine : Definitions::TransmissionLine {
                attribute length = 180.0;
                attribute resistance = 0.025;
                attribute powerLoss = 12.0;
                port transmissionInput : Definitions::ElectricalPort;
                port transmissionOutput : Definitions::ElectricalPort;
                perform action transmitPower : Definitions::TransmitPower;
            }
            
            part stepDownTransformer : Definitions::StepDownTransformer {
                attribute primaryVoltage = 345.0;
                attribute secondaryVoltage = 69.0;
                port highVoltageInput : Definitions::ElectricalPort;
                port mediumVoltageOutput : Definitions::ElectricalPort {
                    out power : Definitions::ElectricalPower {
                        attribute voltage = 69.0;
                        attribute frequency = 60.0;
                    }
                }
                perform action stepDownVoltage : Definitions::StepDownVoltage;
            }
            
            part distributionSubstation : Definitions::DistributionSubstation {
                attribute numberOfFeeders = 12;
                attribute distributionVoltage = 13.8;
                port substationInput : Definitions::ElectricalPort;
                port distributionOutput : Definitions::ElectricalPort {
                    out power : Definitions::ElectricalPower {
                        attribute voltage = 13.8;
                        attribute frequency = 60.0;
                    }
                }
                perform action distributePower : Definitions::DistributePower;
            }
            
            part controlSystem : Definitions::ControlSystem {
                attribute setPoint = 640.0;
                attribute currentOutput = 640.0;
                port monitoringPort : Definitions::ControlPort;
                perform action monitorLoad : Definitions::MonitorLoad;
                perform action adjustGeneration : Definitions::AdjustGeneration;
            }
            
            connect boiler.steamOutput to turbine.steamInput;
            connect turbine.mechanicalOutput to generator.mechanicalInput;
            connect generator.electricalOutput to stepUpTransformer.lowVoltageInput;
            connect stepUpTransformer.highVoltageOutput to transmissionLine.transmissionInput;
            connect transmissionLine.transmissionOutput to stepDownTransformer.highVoltageInput;
            connect stepDownTransformer.mediumVoltageOutput to distributionSubstation.substationInput;
        }
        
        satisfy Requirements::primaryFunction by powerGenerationSystem;
        satisfy Requirements::generationCapacity by powerGenerationSystem;
        satisfy Requirements::transmissionVoltage by powerGenerationSystem.stepUpTransformer;
        satisfy Requirements::frequencyStability by powerGenerationSystem.generator;
        satisfy Requirements::systemEfficiency by powerGenerationSystem;
    }
    
    package Behavior {
        action supplyElectricalPower : Definitions::SupplyElectricalPower {
            in loadDemand : Definitions::LoadDemandSignal;
            out deliveredPower : Definitions::ElectricalPower;
            
            first start;
            then accept startCommand : Definitions::StartCommand;
            then merge operationLoop;
            
            action operationLoop {
                action powerGeneration {
                    action combustFuel : Definitions::CombustFuel {
                        in fuel : Definitions::Fuel {
                            attribute energyContent = 42000.0;
                            attribute flowRate = 35.0;
                        }
                        out thermalEnergy : Definitions::EnergyValue;
                    }
                    flow combustFuel.thermalEnergy to generateSteam.thermalEnergy;
                    
                    action generateSteam : Definitions::GenerateSteam {
                        in thermalEnergy : Definitions::EnergyValue;
                        out steam : Definitions::Steam;
                    }
                    flow generateSteam.steam to driveTurbine.steam;
                    
                    action driveTurbine : Definitions::DriveTurbine {
                        in steam : Definitions::Steam;
                        out mechanicalPower : ISQ::PowerValue;
                    }
                    flow driveTurbine.mechanicalPower to generateElectricity.mechanicalPower;
                    
                    action generateElectricity : Definitions::GenerateElectricity {
                        in mechanicalPower : ISQ::PowerValue;
                        out electricalPower : Definitions::ElectricalPower;
                    }
                    flow generateElectricity.electricalPower to stepUpVoltage.lowVoltage;
                    
                    action stepUpVoltage : Definitions::StepUpVoltage {
                        in lowVoltage : Definitions::ElectricalPower;
                        out highVoltage : Definitions::ElectricalPower;
                    }
                    flow stepUpVoltage.highVoltage to transmitPower.highVoltage;
                    
                    action transmitPower : Definitions::TransmitPower {
                        in highVoltage : Definitions::ElectricalPower;
                        out transmittedPower : Definitions::ElectricalPower;
                    }
                    flow transmitPower.transmittedPower to stepDownVoltage.highVoltage;
                    
                    action stepDownVoltage : Definitions::StepDownVoltage {
                        in highVoltage : Definitions::ElectricalPower;
                        out mediumVoltage : Definitions::ElectricalPower;
                    }
                    flow stepDownVoltage.mediumVoltage to distributePower.mediumVoltage;
                    
                    action distributePower : Definitions::DistributePower {
                        in mediumVoltage : Definitions::ElectricalPower;
                        out consumerPower : Definitions::ElectricalPower;
                    }
                }
                
                then action loadControl {
                    action monitorLoad : Definitions::MonitorLoad {
                        out currentDemand : Definitions::ElectricalPowerValue;
                        out currentSupply : Definitions::ElectricalPowerValue;
                    }
                    
                    then decide;
                        if monitorLoad.currentDemand > monitorLoad.currentSupply then increaseGeneration;
                        if monitorLoad.currentDemand < monitorLoad.currentSupply then decreaseGeneration;
                        if monitorLoad.currentDemand == monitorLoad.currentSupply then maintainGeneration;
                    
                    action increaseGeneration : Definitions::AdjustGeneration {
                        in demand = monitorLoad.currentDemand;
                        in supply = monitorLoad.currentSupply;
                        out adjustment : Real;
                    }
                    
                    action decreaseGeneration : Definitions::AdjustGeneration {
                        in demand = monitorLoad.currentDemand;
                        in supply = monitorLoad.currentSupply;
                        out adjustment : Real;
                    }
                    
                    action maintainGeneration : Definitions::AdjustGeneration {
                        in demand = monitorLoad.currentDemand;
                        in supply = monitorLoad.currentSupply;
                        out adjustment : Real;
                    }
                }
            }
            
            then operationLoop;
            then accept stopCommand : Definitions::StopCommand;
            then done;
        }
        
        state def OperationalState {
            entry; then idle;
            
            state idle;
            state startup;
            state synchronizing;
            state generating;
            state loadFollowing;
            state shutdown;
            
            accept start : Definitions::StartCommand
                then startup;
            
            accept turbineAtSpeed : Definitions::TurbineAtSpeed
                first startup
                then synchronizing;
            
            accept gridSynchronized : Definitions::GridSynchronized
                first synchronizing
                then generating;
            
            accept demandChange : Definitions::DemandChange
                first generating
                then loadFollowing;
            
            accept loadStable : Definitions::LoadStable
                first loadFollowing
                then generating;
            
            accept stop : Definitions::StopCommand
                first generating
                then shutdown;
            
            accept systemStopped : Definitions::SystemStopped
                first shutdown
                then idle;
        }
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import EnergyIndustrySystem::*;

    part testSubject : Boiler {
        exhibit state sm : OperationalState;
    }

    action orchestrator {
        attribute testLoadDemand : Definitions::LoadDemandSignal;
        // TODO(human): unsupported trigger payload type for Definitions
        // TODO(human): unsupported trigger payload type for Definitions
        action supplyElectricalPowerProbe : Definitions {
            in loadDemand = testLoadDemand;
        }
        first supplyElectricalPowerProbe;
    }
}
