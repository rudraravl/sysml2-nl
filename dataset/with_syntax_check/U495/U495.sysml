package EnergyManufacturingCoInc {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        alias Power for ISQ::PowerValue;
        alias Energy for ISQ::EnergyValue;
        alias Temperature for ISQ::ThermodynamicTemperatureValue;
        alias Pressure for ISQ::PressureValue;
        alias MassFlow for ISQ::MassFlowRateValue;
        alias Voltage for ISQ::ElectricPotentialValue;
        alias Current for ISQ::ElectricCurrentValue;
        
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def EmergencyShutdown;
        attribute def PowerSetpoint :> Power;
        attribute def LoadDemand :> Power;
        
        item def NaturalGas;
        item def CombustionAir;
        item def ExhaustGas;
        item def CoolingWater;
        item def ElectricalPower;
        
        port def FuelPort {
            in fuel : NaturalGas;
            attribute flowRate : MassFlow;
        }
        
        port def AirPort {
            in air : CombustionAir;
            attribute flowRate : MassFlow;
        }
        
        port def ExhaustPort {
            out exhaust : ExhaustGas;
            attribute temperature : Temperature;
        }
        
        port def CoolingPort {
            in coolant : CoolingWater;
            out heated : CoolingWater;
        }
        
        port def ElectricalPort {
            out power : ElectricalPower;
            attribute voltage : Voltage;
            attribute current : Current;
            attribute outputPower : Power;
        }
        
        port def ControlPort {
            in command;
            out status;
        }
        
        part def GasTurbine {
            doc /* Converts chemical energy from natural gas into mechanical shaft power 
                 * through combustion and expansion processes.
                 */
            
            attribute ratedPower : Power;
            attribute thermalEfficiency : Real;
            attribute operatingTemp : Temperature;
            attribute operatingPressure : Pressure;
            
            port fuelInput : FuelPort;
            port airIntake : AirPort;
            port exhaustOutput : ExhaustPort;
            port shaftOutput {
                out mechanicalPower : Power;
            }
            port control : ControlPort;
        }
        
        part def ElectricalGenerator {
            doc /* Converts mechanical shaft power into three-phase electrical power 
                 * for grid distribution.
                 */
            
            attribute ratedCapacity : Power;
            attribute efficiency : Real;
            attribute outputVoltage : Voltage;
            attribute frequency : Real;
            
            port mechanicalInput {
                in shaftPower : Power;
            }
            port electricalOutput : ElectricalPort;
            port cooling : CoolingPort;
            port control : ControlPort;
        }
        
        part def HeatRecoverySystem {
            doc /* Captures waste heat from turbine exhaust to improve overall 
                 * system efficiency through cogeneration.
                 */
            
            attribute recoveredPower : Power;
            attribute heatExchangerEfficiency : Real;
            
            port exhaustInput : ExhaustPort;
            port steamOutput {
                out thermalPower : Power;
            }
            port waterInput : CoolingPort;
        }
        
        part def PowerConditioningUnit {
            doc /* Conditions and regulates electrical output to meet grid requirements 
                 * for voltage, frequency, and power quality.
                 */
            
            attribute voltageRegulation : Real;
            attribute harmonicDistortion : Real;
            
            port generatorInput : ElectricalPort;
            port gridOutput : ElectricalPort;
            port control : ControlPort;
        }
        
        part def ControlSystem {
            doc /* Monitors and controls all plant operations including startup, 
                 * load following, and shutdown sequences.
                 */
            
            attribute setpoint : Power;
            attribute currentOutput : Power;
            
            port turbineControl : ControlPort;
            port generatorControl : ControlPort;
            port pcuControl : ControlPort;
            port operatorInterface {
                in commands;
                out telemetry;
            }
        }
        
        part def EnergyStorageSystem {
            doc /* Provides short-term energy buffering for load balancing and 
                 * grid stabilization.
                 */
            
            attribute capacity : Energy;
            attribute stateOfCharge : Real;
            attribute maxChargePower : Power;
            attribute maxDischargePower : Power;
            
            port dcInterface : ElectricalPort;
            port control : ControlPort;
        }
        
        action def StartupSequence {
            in startCmd : StartCommand;
            out turbineReady : Boolean;
            out generatorSynced : Boolean;
        }
        
        action def ShutdownSequence {
            in stopCmd : StopCommand;
            out turbineStopped : Boolean;
            out generatorOffline : Boolean;
        }
        
        action def CombustFuel {
            in fuel : NaturalGas;
            in air : CombustionAir;
            out mechanicalPower : Power;
            out exhaust : ExhaustGas;
        }
        
        action def GenerateElectricity {
            in mechanicalPower : Power;
            out electricalPower : Power;
        }
        
        action def RecoverHeat {
            in exhaust : ExhaustGas;
            out thermalPower : Power;
        }
        
        action def ConditionPower {
            in rawPower : Power;
            out gridPower : Power;
        }
        
        action def ManageLoad {
            in demand : LoadDemand;
            in currentOutput : Power;
            out fuelCommand : MassFlow;
        }
        
        action def ProduceElectricalPower {
            in fuelSupply : NaturalGas;
            in loadDemand : LoadDemand;
            out deliveredPower : Power;
        }
    }
    
    package Requirements {
        requirement def PrimaryFunctionRequirement {
            doc /* The energy manufacturing system shall convert natural gas fuel 
                 * into electrical power for delivery to the electrical grid.
                 */
            subject plant : EnergyManufacturingPlant;
        }
        
        requirement <'EMC-REQ-001'> powerGenerationCapacity {
            doc /* The plant shall generate a minimum of 250 MW of electrical power 
                 * at rated conditions.
                 */
            subject plant : EnergyManufacturingPlant;
            
            assert constraint {
                plant.ratedOutputPower.num >= 250.0
            }
        }
        
        requirement <'EMC-REQ-002'> overallEfficiency {
            doc /* The combined cycle plant shall achieve a minimum overall efficiency 
                 * of 55% (LHV basis) at rated load.
                 */
            subject plant : EnergyManufacturingPlant;
            
            assert constraint {
                plant.plantEfficiency >= 55.0
            }
        }
        
        requirement <'EMC-REQ-003'> gridCompliance {
            doc /* Electrical output shall comply with grid interconnection standards 
                 * for voltage regulation and power quality.
                 */
            subject pcu : Definitions::PowerConditioningUnit;
            
            assert constraint {
                pcu.voltageRegulation <= 2.0 and
                pcu.harmonicDistortion <= 5.0
            }
        }
        
        requirement <'EMC-REQ-004'> startupTime {
            doc /* The plant shall achieve full rated output within 30 minutes 
                 * from cold start command.
                 */
            subject plant : EnergyManufacturingPlant;
        }
        
        requirement <'EMC-REQ-005'> loadFollowing {
            doc /* The plant shall be capable of ramping output at a rate of 
                 * 10 MW per minute to follow grid demand.
                 */
            subject plant : EnergyManufacturingPlant;
        }
        
        requirement <'EMC-REQ-006'> availability {
            doc /* The plant shall maintain a minimum availability factor of 92% 
                 * over a calendar year.
                 */
            subject plant : EnergyManufacturingPlant;
        }
    }
    
    package SystemArchitecture {
        part def EnergyManufacturingPlant {
            doc /* Energy Manufacturing Co. Inc operates an advanced combined-cycle 
                 * power generation facility that converts natural gas into electrical 
                 * power for the regional grid.
                 * 
                 * Primary Function: The plant combusts natural gas in a gas turbine 
                 * to generate mechanical power, which drives an electrical generator 
                 * to produce electricity. Waste heat from the turbine exhaust is 
                 * recovered through a heat recovery system to improve overall efficiency. 
                 * The electrical output is conditioned and synchronized with the grid 
                 * to deliver reliable, high-quality power that meets utility standards. 
                 * An integrated control system manages all operations from startup 
                 * through load following to shutdown, while an energy storage system 
                 * provides grid stabilization services.
                 */
            
            attribute ratedOutputPower : Power;
            attribute plantEfficiency : Real;
            attribute operatingHours : Real;
            
            part gasTurbine : Definitions::GasTurbine;
            part generator : Definitions::ElectricalGenerator;
            part heatRecovery : Definitions::HeatRecoverySystem;
            part powerConditioning : Definitions::PowerConditioningUnit;
            part controlSystem : Definitions::ControlSystem;
            part energyStorage : Definitions::EnergyStorageSystem;
        }
        
        part energyManufacturingPlant : EnergyManufacturingPlant {
            attribute ratedOutputPower.num = 250.0;
            attribute plantEfficiency = 58.5;
            attribute operatingHours = 0.0;
            
            part gasTurbine {
                attribute ratedPower.num = 180.0;
                attribute thermalEfficiency = 38.5;
                attribute operatingTemp.num = 1350.0;
                attribute operatingPressure.num = 18.0;
            }
            
            part generator {
                attribute ratedCapacity.num = 200.0;
                attribute efficiency = 98.5;
                attribute outputVoltage.num = 13800.0;
                attribute frequency = 60.0;
            }
            
            part heatRecovery {
                attribute recoveredPower.num = 75.0;
                attribute heatExchangerEfficiency = 85.0;
            }
            
            part powerConditioning {
                attribute voltageRegulation = 1.5;
                attribute harmonicDistortion = 3.2;
            }
            
            part controlSystem {
                attribute setpoint.num = 250.0;
                attribute currentOutput.num = 0.0;
            }
            
            part energyStorage {
                attribute capacity.num = 50.0;
                attribute stateOfCharge = 0.75;
                attribute maxChargePower.num = 25.0;
                attribute maxDischargePower.num = 25.0;
            }
            
            connection turbineToGenerator : ItemFlow
                connect gasTurbine.shaftOutput to generator.mechanicalInput;
            
            connection turbineToHeatRecovery : ItemFlow
                connect gasTurbine.exhaustOutput to heatRecovery.exhaustInput;
            
            connection generatorToPCU : ItemFlow
                connect generator.electricalOutput to powerConditioning.generatorInput;
            
            connection controlToTurbine : ItemFlow
                connect controlSystem.turbineControl to gasTurbine.control;
            
            connection controlToGenerator : ItemFlow
                connect controlSystem.generatorControl to generator.control;
            
            connection controlToPCU : ItemFlow
                connect controlSystem.pcuControl to powerConditioning.control;
            
            perform action producePower : Definitions::ProduceElectricalPower {
                in fuelSupply : Definitions::NaturalGas;
                in loadDemand : Definitions::LoadDemand;
                out deliveredPower : Power;
                
                first start;
                
                then action combust : Definitions::CombustFuel {
                    in fuel = producePower.fuelSupply;
                    in air : Definitions::CombustionAir;
                    out mechanicalPower : Power;
                    out exhaust : Definitions::ExhaustGas;
                }
                
                flow combust.mechanicalPower to generate.mechanicalPower;
                
                then action generate : Definitions::GenerateElectricity {
                    in mechanicalPower : Power;
                    out electricalPower : Power;
                }
                
                flow combust.exhaust to recover.exhaust;
                
                action recover : Definitions::RecoverHeat {
                    in exhaust : Definitions::ExhaustGas;
                    out thermalPower : Power;
                }
                
                flow generate.electricalPower to condition.rawPower;
                
                then action condition : Definitions::ConditionPower {
                    in rawPower : Power;
                    out gridPower = producePower.deliveredPower;
                }
                
                then action manage : Definitions::ManageLoad {
                    in demand = producePower.loadDemand;
                    in currentOutput = condition.gridPower;
                    out fuelCommand : MassFlow;
                }
                
                then done;
            }
        }
        
        satisfy Requirements::powerGenerationCapacity by energyManufacturingPlant;
        satisfy Requirements::overallEfficiency by energyManufacturingPlant;
        satisfy Requirements::gridCompliance by energyManufacturingPlant.powerConditioning;
    }
}
