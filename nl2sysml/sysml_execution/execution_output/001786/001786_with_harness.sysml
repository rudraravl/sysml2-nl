package GasTurbineSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    
    attribute def TemperatureValue :> Real;
    attribute def PressureValue :> Real;
    attribute def MassFlowRateValue :> Real;
    attribute def RotationalSpeedValue :> Real;
    attribute def TorqueValue :> Real;
    attribute def PowerValue :> Real;
    attribute def EfficiencyValue :> Real;
    attribute def VolumeFlowRateValue :> Real;
    
    item def Air {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute massFlowRate : MassFlowRateValue;
    }
    
    item def Fuel {
        attribute massFlowRate : MassFlowRateValue;
        attribute lowerHeatingValue : Real;
    }
    
    item def CombustionGas {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute massFlowRate : MassFlowRateValue;
    }
    
    item def ExhaustGas {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute massFlowRate : MassFlowRateValue;
    }
    
    port def AirPort {
        in item airFlow : Air;
    }
    
    port def FuelPort {
        in item fuelFlow : Fuel;
    }
    
    port def GasPort {
        out item gasFlow : CombustionGas;
    }
    
    port def ExhaustPort {
        out item exhaustFlow : ExhaustGas;
    }
    
    port def MechanicalPort {
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute torque : TorqueValue;
        attribute power : PowerValue;
    }
    
    part def Compressor {
        doc /* Compresses ambient air to high pressure for combustion */
        
        port airInlet : AirPort;
        port airOutlet {
            out item compressedAir : Air;
        }
        port shaftInput : MechanicalPort;
        
        attribute pressureRatio : Real;
        attribute isentropicEfficiency : EfficiencyValue;
        attribute powerConsumed : PowerValue;
        
        action def CompressAir {
            in ambientAir : Air;
            out compressedAir : Air;
            
            first start;
            then action drawAir;
            then action increaseTemperatureAndPressure {
                doc /* Adiabatic compression increases both temperature and pressure */
            }
            then action deliverCompressedAir;
            then done;
        }
    }
    
    part def CombustionChamber {
        doc /* Burns fuel with compressed air to produce high-temperature gas */
        
        port compressedAirInlet {
            in item compressedAir : Air;
        }
        port fuelInlet : FuelPort;
        port hotGasOutlet : GasPort;
        
        attribute combustionTemperature : TemperatureValue;
        attribute combustionPressure : PressureValue;
        attribute combustionEfficiency : EfficiencyValue;
        attribute fuelAirRatio : Real;
        
        action def CombustFuel {
            in compressedAir : Air;
            in fuel : Fuel;
            out hotGas : CombustionGas;
            
            first start;
            then action injectFuel;
            then action mixFuelAndAir;
            then action igniteMixture;
            then action sustainContinuousCombustion {
                doc /* Maintain stable combustion at design temperature */
            }
            then action produceHotGas;
            then done;
        }
    }
    
    part def Turbine {
        doc /* Extracts energy from hot gas to drive compressor and produce power */
        
        port hotGasInlet {
            in item hotGas : CombustionGas;
        }
        port exhaustOutlet : ExhaustPort;
        port shaftOutput : MechanicalPort;
        
        attribute expansionRatio : Real;
        attribute isentropicEfficiency : EfficiencyValue;
        attribute powerProduced : PowerValue;
        
        action def ExpandGas {
            in hotGas : CombustionGas;
            out exhaustGas : ExhaustGas;
            out mechanicalPower : PowerValue;
            
            first start;
            then action admitHotGas;
            then action expandThroughBlades {
                doc /* Hot gas expands through turbine stages, rotating blades */
            }
            then action extractMechanicalEnergy;
            then action dischargeExhaust;
            then done;
        }
    }
    
    part def Shaft {
        doc /* Mechanical coupling between turbine and compressor */
        
        port turbineEnd : MechanicalPort;
        port compressorEnd : MechanicalPort;
        port powerOutputEnd : MechanicalPort;
        
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute torque : TorqueValue;
        
        assert constraint {
            turbineEnd.rotationalSpeed == compressorEnd.rotationalSpeed and
            compressorEnd.rotationalSpeed == powerOutputEnd.rotationalSpeed
        }
    }
    
    part def FuelSystem {
        doc /* Supplies fuel at controlled rate and pressure */
        
        port fuelOutput : FuelPort;
        
        attribute fuelPressure : PressureValue;
        attribute fuelFlowRate : MassFlowRateValue;
        
        action def SupplyFuel {
            out fuel : Fuel;
            
            first start;
            then action pumpFuel;
            then action regulatePressure;
            then action meterFlow;
            then done;
        }
    }
    
    part def ControlSystem {
        doc /* Monitors and controls turbine operation */
        
        attribute targetPower : PowerValue;
        attribute targetSpeed : RotationalSpeedValue;
        attribute fuelFlowCommand : MassFlowRateValue;
        attribute startCommand : Boolean;
        attribute shutdownCommand : Boolean;
        attribute loadDemand : Boolean;
        attribute unloadCommand : Boolean;
        attribute emergencyStop : Boolean;
        
        action def MonitorAndControl {
            in currentSpeed : RotationalSpeedValue;
            in currentPower : PowerValue;
            in currentTemperature : TemperatureValue;
            out fuelCommand : MassFlowRateValue;
            
            first start;
            then merge controlLoop;
            then action measureParameters;
            then action compareToSetpoints;
            then decide;
                if currentSpeed < targetSpeed then increaseFuel;
                if currentSpeed >= targetSpeed then maintainFuel;
            action increaseFuel {
                doc /* Increase fuel flow to accelerate */
            }
            then controlLoop;
            action maintainFuel {
                doc /* Maintain steady-state fuel flow */
            }
            then controlLoop;
        }
        
        action def maintainIdleSpeed;
        action def regulatePowerOutput;
    }
    
    part def GasTurbine {
        doc /* 
         * A gas turbine system that converts chemical energy from fuel into 
         * mechanical rotational power through a continuous Brayton cycle.
         * The system compresses ambient air, mixes it with fuel and combusts 
         * the mixture, then expands the hot gases through a turbine to extract 
         * mechanical energy while driving the compressor.
         */
        
        attribute thermalEfficiency : EfficiencyValue;
        attribute netPowerOutput : PowerValue;
        attribute specificFuelConsumption : Real;
        attribute operatingTemperature : TemperatureValue;
        attribute operatingSpeed : RotationalSpeedValue;
        
        port ambientAirIntake : AirPort;
        port fuelSupply : FuelPort;
        port exhaustDischarge : ExhaustPort;
        port mechanicalPowerOutput : MechanicalPort;
        
        part compressor : Compressor {
            attribute :>> pressureRatio = 16.0;
            attribute :>> isentropicEfficiency = 0.86;
        }
        
        part combustor : CombustionChamber {
            attribute :>> combustionTemperature = 1600.0;
            attribute :>> combustionEfficiency = 0.98;
            attribute :>> fuelAirRatio = 0.015;
        }
        
        part turbine : Turbine {
            attribute :>> expansionRatio = 15.5;
            attribute :>> isentropicEfficiency = 0.89;
        }
        
        part mainShaft : Shaft {
            attribute :>> rotationalSpeed = 12000.0;
        }
        
        part fuelSystem : FuelSystem {
            attribute :>> fuelPressure = 3500.0;
        }
        
        part controlSystem : ControlSystem {
            attribute :>> targetPower = 30000.0;
            attribute :>> targetSpeed = 12000.0;
        }
        
        connection intakeToCompressor connect ambientAirIntake to compressor.airInlet;
        connection compressorToCombustor connect compressor.airOutlet to combustor.compressedAirInlet;
        connection fuelToCombustor connect fuelSupply to combustor.fuelInlet;
        connection fuelSystemToCombustor connect fuelSystem.fuelOutput to combustor.fuelInlet;
        connection combustorToTurbine connect combustor.hotGasOutlet to turbine.hotGasInlet;
        connection turbineToExhaust connect turbine.exhaustOutlet to exhaustDischarge;
        connection turbineToShaft connect turbine.shaftOutput to mainShaft.turbineEnd;
        connection shaftToCompressor connect mainShaft.compressorEnd to compressor.shaftInput;
        connection shaftToPowerOutput connect mainShaft.powerOutputEnd to mechanicalPowerOutput;
        
        assert constraint powerBalance {
            turbine.powerProduced == compressor.powerConsumed + netPowerOutput
        }
        
        assert constraint massFlowContinuity {
            compressor.airInlet.airFlow.massFlowRate + combustor.fuelInlet.fuelFlow.massFlowRate ==
            turbine.hotGasInlet.hotGas.massFlowRate
        }
        
        perform action generatePower {
            doc /* 
             * Primary function: Continuously convert chemical energy from fuel 
             * into mechanical rotational power through compression, combustion, 
             * and expansion in a thermodynamic Brayton cycle.
             */
            
            first start;
            then merge operatingCycle;
            
            then action ingestAir {
                out ambientAir : Air;
            }
            
            then action compress references compressor.CompressAir {
                in ambientAir = ingestAir.ambientAir;
                out compressedAir : Air;
            }
            
            then action supplyFuel references fuelSystem.SupplyFuel {
                out fuel : Fuel;
            }
            
            then action combust references combustor.CombustFuel {
                in compressedAir = compress.compressedAir;
                in fuel = supplyFuel.fuel;
                out hotGas : CombustionGas;
            }
            
            then action expand references turbine.ExpandGas {
                in hotGas = combust.hotGas;
                out exhaustGas : ExhaustGas;
                out mechanicalPower : PowerValue;
            }
            
            then action deliverPower {
                in mechanicalPower = expand.mechanicalPower;
            }
            
            then action control references controlSystem.MonitorAndControl {
                in currentSpeed = mainShaft.rotationalSpeed;
                in currentPower = netPowerOutput;
                in currentTemperature = combustor.combustionTemperature;
                out fuelCommand : MassFlowRateValue;
            }
            
            then operatingCycle;
        }
    }
    
    requirement def PowerOutputRequirement {
        doc /* The gas turbine shall produce minimum net mechanical power output */
        subject gasTurbine : GasTurbine;
        require constraint {
            gasTurbine.netPowerOutput >= 25000.0
        }
    }
    
    requirement def ThermalEfficiencyRequirement {
        doc /* The gas turbine shall achieve minimum thermal efficiency */
        subject gasTurbine : GasTurbine;
        require constraint {
            gasTurbine.thermalEfficiency >= 0.35
        }
    }
    
    requirement def CombustionTemperatureRequirement {
        doc /* Combustion temperature shall remain within material limits */
        subject combustor : GasTurbine::combustor;
        require constraint {
            combustor.combustionTemperature <= 1650.0
        }
    }
    
    requirement def OperationalSpeedRequirement {
        doc /* Turbine shall operate at design rotational speed */
        subject gasTurbine : GasTurbine;
        require constraint {
            gasTurbine.operatingSpeed >= 11000.0 and
            gasTurbine.operatingSpeed <= 13000.0
        }
    }
    
    requirement <'REQ-GT-001'> primaryFunction {
        doc /* 
         * The gas turbine system shall continuously convert chemical energy 
         * from fuel into mechanical rotational power by:
         * 1. Compressing ambient air to high pressure
         * 2. Mixing compressed air with fuel and combusting the mixture
         * 3. Expanding hot combustion gases through turbine stages
         * 4. Extracting mechanical energy to drive the compressor and deliver net power
         * This implements a continuous Brayton thermodynamic cycle.
         */
        subject gasTurbine : GasTurbine;
        
        require PowerOutputRequirement;
        require ThermalEfficiencyRequirement;
        require CombustionTemperatureRequirement;
        require OperationalSpeedRequirement;
    }
    
    part gasTurbineSystem : GasTurbine {
        attribute :>> thermalEfficiency = 0.38;
        attribute :>> netPowerOutput = 30000.0;
        attribute :>> specificFuelConsumption = 0.25;
        attribute :>> operatingTemperature = 1600.0;
        attribute :>> operatingSpeed = 12000.0;
    }
    
    satisfy primaryFunction by gasTurbineSystem;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import GasTurbineSystem::*;

    action orchestrator {
        item testAmbientAir : Air {
            attribute temperature : TemperatureValue = 0.0;
            attribute pressure : PressureValue = 0.0;
            attribute massFlowRate : MassFlowRateValue = 0.0;
        }
        action actionProbe : CompressAir {
            in ambientAir = testAmbientAir;
        }
        first actionProbe;
    }
}
