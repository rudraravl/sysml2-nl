package 'Oil Platform System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OilFlowRate :> VolumeFlowRateValue;
    attribute def GasFlowRate :> VolumeFlowRateValue;
    attribute def WaterFlowRate :> VolumeFlowRateValue;
    attribute def StorageLevel :> VolumeValue;
    attribute def WellPressure :> PressureValue;
    attribute def ProcessTemperature :> ThermodynamicTemperatureValue;
    
    attribute def StartProduction;
    attribute def StopProduction;
    attribute def EmergencyShutdown;
    attribute def HazardDetected;
    attribute def CriticalHazard;
    attribute def HazardCleared;
    attribute def SystemReset;
    
    item def CrudeOil {
        attribute flowRate : OilFlowRate;
        attribute temperature : ProcessTemperature;
        attribute pressure : WellPressure;
        attribute apiGravity : Real;
    }
    
    item def NaturalGas {
        attribute flowRate : GasFlowRate;
        attribute pressure : WellPressure;
        attribute temperature : ProcessTemperature;
    }
    
    item def ProducedWater {
        attribute flowRate : WaterFlowRate;
        attribute salinity : Real;
    }
    
    item def WellFluid {
        attribute totalFlowRate : VolumeFlowRateValue;
        attribute oilCut : Real;
        attribute gasCut : Real;
        attribute waterCut : Real;
    }
    
    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : PowerValue;
    }
    
    port def FluidInputPort {
        in item fluid : WellFluid;
    }
    
    port def OilOutputPort {
        out item oil : CrudeOil;
    }
    
    port def GasOutputPort {
        out item gas : NaturalGas;
    }
    
    port def WaterOutputPort {
        out item water : ProducedWater;
    }
    
    port def PowerInputPort {
        in item power : ElectricalPower;
    }
    
    part def SubseaWellSystem {
        doc /* Subsea wells that extract hydrocarbons from reservoir */
        
        port wellOutput : FluidInputPort;
        
        attribute wellheadPressure : WellPressure;
        attribute reservoirPressure : WellPressure;
        attribute productionRate : VolumeFlowRateValue;
        
        perform action extractFromReservoir {
            out wellFluid : WellFluid;
        }
    }
    
    part def RiserSystem {
        doc /* Transports well fluids from seabed to platform */
        
        in port riserInput : FluidInputPort;
        out port riserOutput : FluidInputPort;
        
        attribute riserPressure : WellPressure;
        attribute riserTemperature : ProcessTemperature;
        
        perform action transportFluid {
            in incomingFluid : WellFluid;
            out deliveredFluid : WellFluid;
        }
    }
    
    part def ManifoldSystem {
        doc /* Collects and distributes flow from multiple wells */
        
        in port wellInputs[*] : FluidInputPort;
        out port manifoldOutput : FluidInputPort;
        
        attribute numberOfWells : Integer;
        
        perform action combineFlows {
            in wellFluids : WellFluid[*];
            out combinedFluid : WellFluid;
        }
    }
    
    part def SeparationSystem {
        doc /* Separates oil, gas, and water phases */
        
        in port separatorInput : FluidInputPort;
        port oilOutput : OilOutputPort;
        port gasOutput : GasOutputPort;
        port waterOutput : WaterOutputPort;
        port powerInput : PowerInputPort;
        
        attribute separationEfficiency : Real;
        attribute operatingPressure : WellPressure;
        attribute operatingTemperature : ProcessTemperature;
        
        perform action separatePhases {
            in mixedFluid : WellFluid;
            out separatedOil : CrudeOil;
            out separatedGas : NaturalGas;
            out separatedWater : ProducedWater;
        }
        
        state separatorStates {
            entry; then idle;
            
            state idle;
            state operating;
            state shutdown;
            
            transition idle_to_operating
                first idle
                accept startCmd : StartProduction
                then operating;
            
            transition operating_to_shutdown
                first operating
                accept stopCmd : StopProduction
                then shutdown;
            
            transition shutdown_to_idle
                first shutdown
                then idle;
        }
    }
    
    part def OilTreatmentSystem {
        doc /* Treats and stabilizes crude oil for export */
        
        in port rawOilInput : OilOutputPort;
        out port treatedOilOutput : OilOutputPort;
        port powerInput : PowerInputPort;
        
        attribute treatmentTemperature : ProcessTemperature;
        attribute treatmentPressure : WellPressure;
        
        perform action treatOil {
            in rawOil : CrudeOil;
            out stabilizedOil : CrudeOil;
        }
    }
    
    part def GasCompressionSystem {
        doc /* Compresses gas for export or fuel gas system */
        
        in port gasInput : GasOutputPort;
        out port compressedGasOutput : GasOutputPort;
        port powerInput : PowerInputPort;
        
        attribute compressionRatio : Real;
        attribute dischargePressure : WellPressure;
        
        perform action compressGas {
            in inletGas : NaturalGas;
            out compressedGas : NaturalGas;
        }
    }
    
    part def StorageSystem {
        doc /* Stores processed crude oil before export */
        
        in port storageInput : OilOutputPort;
        out port storageOutput : OilOutputPort;
        
        attribute storageCapacity : VolumeValue;
        attribute currentLevel : StorageLevel;
        attribute maxFillRate : OilFlowRate;
        
        perform action manageInventory {
            in incomingOil : CrudeOil;
            out exportOil : CrudeOil;
        }
    }
    
    part def ExportSystem {
        doc /* Exports oil via pipeline or tanker loading */
        
        in port exportInput : OilOutputPort;
        port powerInput : PowerInputPort;
        
        attribute exportRate : OilFlowRate;
        attribute exportPressure : WellPressure;
        
        perform action exportOil {
            in oilToExport : CrudeOil;
        }
    }
    
    part def PowerGenerationSystem {
        doc /* Generates electrical power for platform operations */
        
        in port fuelGasInput : GasOutputPort;
        port powerOutput[*] : PowerInputPort;
        
        attribute generatedPower : PowerValue;
        attribute fuelConsumption : GasFlowRate;
        attribute numberOfGenerators : Integer;
        
        perform action generatePower {
            in fuelGas : NaturalGas;
            out electricalPower : ElectricalPower;
        }
    }
    
    part def WaterTreatmentSystem {
        doc /* Treats produced water for disposal or reinjection */
        
        in port waterInput : WaterOutputPort;
        out port treatedWaterOutput : WaterOutputPort;
        port powerInput : PowerInputPort;
        
        attribute treatmentEfficiency : Real;
        
        perform action treatWater {
            in producedWater : ProducedWater;
            out treatedWater : ProducedWater;
        }
    }
    
    part def SafetySystem {
        doc /* Monitors and controls platform safety */
        
        port powerInput : PowerInputPort;
        
        attribute fireDetected : Boolean;
        attribute gasLeakDetected : Boolean;
        attribute emergencyShutdownActive : Boolean;
        
        perform action monitorSafety {
            out safetyStatus : Boolean;
        }
        
        state safetyStateMachine {
            entry; then normal;
            
            state normal {
                entry assign emergencyShutdownActive := false;
            }
            
            state warning;
            
            state emergency {
                entry assign emergencyShutdownActive := true;
            }
            
            transition normal_to_warning
                first normal
                accept hazardDetected : HazardDetected
                then warning;
            
            transition warning_to_emergency
                first warning
                accept criticalHazard : CriticalHazard
                then emergency;
            
            transition warning_to_normal
                first warning
                accept hazardCleared : HazardCleared
                then normal;
            
            transition emergency_to_normal
                first emergency
                accept systemReset : SystemReset
                then normal;
        }
    }
    
    part def ControlSystem {
        doc /* Distributed control system for platform automation */
        
        port powerInput : PowerInputPort;
        
        attribute productionSetpoint : OilFlowRate;
        attribute operatingMode : String;
        
        perform action controlProduction {
            in setpoint : OilFlowRate;
            out controlSignals;
        }
    }
    
    part def OilPlatform {
        doc /* Offshore oil production platform */
        
        part wells : SubseaWellSystem[6];
        part manifold : ManifoldSystem;
        part risers : RiserSystem[2];
        part separator : SeparationSystem;
        part oilTreatment : OilTreatmentSystem;
        part gasCompression : GasCompressionSystem;
        part storage : StorageSystem;
        part export : ExportSystem;
        part powerGen : PowerGenerationSystem;
        part waterTreatment : WaterTreatmentSystem;
        part safety : SafetySystem;
        part control : ControlSystem;
        
        flow wells[1].wellOutput.fluid to manifold.wellInputs[1].fluid;
        flow wells[2].wellOutput.fluid to manifold.wellInputs[2].fluid;
        flow wells[3].wellOutput.fluid to manifold.wellInputs[3].fluid;
        flow wells[4].wellOutput.fluid to manifold.wellInputs[4].fluid;
        flow wells[5].wellOutput.fluid to manifold.wellInputs[5].fluid;
        flow wells[6].wellOutput.fluid to manifold.wellInputs[6].fluid;
        
        flow manifold.manifoldOutput.fluid to risers[1].riserInput.fluid;
        flow risers[1].riserOutput.fluid to separator.separatorInput.fluid;
        
        flow separator.oilOutput.oil to oilTreatment.rawOilInput.oil;
        flow separator.gasOutput.gas to gasCompression.gasInput.gas;
        flow separator.waterOutput.water to waterTreatment.waterInput.water;
        
        flow oilTreatment.treatedOilOutput.oil to storage.storageInput.oil;
        flow storage.storageOutput.oil to export.exportInput.oil;
        
        flow gasCompression.compressedGasOutput.gas to powerGen.fuelGasInput.gas;
        
        flow powerGen.powerOutput[1].power to separator.powerInput.power;
        flow powerGen.powerOutput[2].power to oilTreatment.powerInput.power;
        flow powerGen.powerOutput[3].power to gasCompression.powerInput.power;
        flow powerGen.powerOutput[4].power to export.powerInput.power;
        flow powerGen.powerOutput[5].power to waterTreatment.powerInput.power;
        flow powerGen.powerOutput[6].power to safety.powerInput.power;
        flow powerGen.powerOutput[7].power to control.powerInput.power;
        
        perform action produceHydrocarbons {
            doc /* Primary platform function: extract, process, store, and export crude oil and natural gas */
            
            in productionTarget : OilFlowRate;
            out totalOilProduced : VolumeValue;
            out totalGasProduced : VolumeValue;
            
            first start;
            then merge continueProduction;
            
            then action initializeProduction {
                perform control.controlProduction {
                    in setpoint = productionTarget;
                }
            }
            
            then action checkSafety {
                perform safety.monitorSafety {
                    out safetyStatus;
                }
            }
            
            then decide;
                if checkSafety.safetyStatus == true then extractWellFluids;
                if checkSafety.safetyStatus == false then emergencyStop;
            
            action extractWellFluids {
                perform wells[1].extractFromReservoir {
                    out wellFluid;
                }
            }
            then combineWellStreams;
            
            action combineWellStreams {
                perform manifold.combineFlows {
                    out combinedFluid;
                }
            }
            then transportToTopside;
            
            action transportToTopside {
                perform risers[1].transportFluid {
                    in incomingFluid = combineWellStreams.combinedFluid;
                    out deliveredFluid;
                }
            }
            then separateFluidPhases;
            
            action separateFluidPhases {
                perform separator.separatePhases {
                    in mixedFluid = transportToTopside.deliveredFluid;
                    out separatedOil;
                    out separatedGas;
                    out separatedWater;
                }
            }
            then processOilAndGas;
            
            action processOilAndGas {
                first action treatCrudeOil {
                    perform oilTreatment.treatOil {
                        in rawOil = separateFluidPhases.separatedOil;
                        out stabilizedOil;
                    }
                }
                then action compressNaturalGas {
                    perform gasCompression.compressGas {
                        in inletGas = separateFluidPhases.separatedGas;
                        out compressedGas;
                    }
                }
                then action handleProducedWater {
                    perform waterTreatment.treatWater {
                        in producedWater = separateFluidPhases.separatedWater;
                        out treatedWater;
                    }
                }
            }
            then storeAndExportOil;
            
            action storeAndExportOil {
                first action manageOilStorage {
                    perform storage.manageInventory {
                        in incomingOil = processOilAndGas.treatCrudeOil.stabilizedOil;
                        out exportOil;
                    }
                }
                then action exportProcessedOil {
                    perform export.exportOil {
                        in oilToExport = manageOilStorage.exportOil;
                    }
                }
            }
            then generatePlatformPower;
            
            action generatePlatformPower {
                perform powerGen.generatePower {
                    in fuelGas = processOilAndGas.compressNaturalGas.compressedGas;
                    out electricalPower;
                }
            }
            then continueProduction;
            
            action emergencyStop {
                doc /* Execute emergency shutdown procedures */
            }
            then done;
        }
    }
    
    part platform : OilPlatform;
    
    requirement def PrimaryFunctionRequirement {
        doc /* The oil platform shall extract crude oil and natural gas from subsea reservoirs,
               separate and process the hydrocarbons, store the oil, and export it to shore
               while maintaining safe and environmentally compliant operations. */
        
        subject platformSystem : OilPlatform;
    }
    
    requirement def ProductionCapacityRequirement {
        doc /* The platform shall maintain minimum daily oil production capacity */
        
        subject platformSystem : OilPlatform;
        
        require constraint {
            platformSystem.wells[1].productionRate >= 5000.0
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The platform shall operate within safe parameters and execute emergency shutdown when hazards detected */
        
        subject platformSystem : OilPlatform;
        
        require constraint {
            platformSystem.safety.emergencyShutdownActive == false or
            platformSystem.separator.operatingPressure == 0.0
        }
    }
    
    requirement def StorageRequirement {
        doc /* The platform shall provide adequate storage capacity for continuous operations */
        
        subject platformSystem : OilPlatform;
        
        require constraint {
            platformSystem.storage.storageCapacity >= 100000.0
        }
    }
    
    requirement def EnvironmentalRequirement {
        doc /* The platform shall treat produced water to meet environmental discharge standards */
        
        subject platformSystem : OilPlatform;
        
        require constraint {
            platformSystem.waterTreatment.treatmentEfficiency >= 0.95
        }
    }
    
    requirement platformOperationalRequirements {
        doc /* Top-level requirements for offshore oil platform operations */
        
        subject platform : OilPlatform;
        
        require primaryFunction : PrimaryFunctionRequirement;
        require productionCapacity : ProductionCapacityRequirement;
        require safetyCompliance : SafetyRequirement;
        require storageCapacity : StorageRequirement;
        require environmentalCompliance : EnvironmentalRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Oil Platform System'::*;
    part testSubject : SubseaWellSystem;
    // TODO(human): define boundary input values for: flowRate, temperature, pressure, apiGravity, flowRate, pressure, temperature, flowRate
    // TODO(human): constraints found but no boolean expression to assert
}
