package AcidEggSystem {
    import ScalarValues::*;
    import ScalarFunctions::*;
    
    // ============================================================
    // Unit Definitions
    // ============================================================
    unit def Liter;
    unit def Bar;
    unit def LiterPerMin;
    unit def Second;
    unit def Percent1;
    
    // ============================================================
    // Value Types with Units
    // ============================================================
    value type VolumeUnit :> Real {
        unit = Liter;
    }
    value type PressureUnit :> Real {
        unit = Bar;
    }
    value type FlowRateUnit :> Real {
        unit = LiterPerMin;
    }
    value type TimeUnit :> Real {
        unit = Second;
    }
    value type PercentUnit :> Real {
        unit = Percent1;
    }
    
    // ============================================================
    // Item Definitions
    // ============================================================
    item def CorrosiveFluid;
    item def PressurizedGas;
    
    // ============================================================
    // Enumerations
    // ============================================================
    enum def ControlCommand {
        OPEN;
        CLOSE;
    }
    
    // ============================================================
    // Port Definitions
    // ============================================================
    port def FluidPort {
        attribute nominalFlowRate : FlowRateUnit;
        in liquidIn : CorrosiveFluid[0..*];
        out liquidOut : CorrosiveFluid[0..*];
    }
    
    port def GasPort {
        attribute nominalFlowRate : FlowRateUnit;
        in gasIn : PressurizedGas[0..*];
        out gasOut : PressurizedGas[0..*];
    }
    
    port def ControlPort {
        attribute command : ControlCommand;
    }
    
    port def LevelReadingPort {
        attribute volume : VolumeUnit;
    }
    
    port def PressureReadingPort {
        attribute pressure : PressureUnit;
    }
    
    // ============================================================
    // Liquid Valve
    // ============================================================
    part def LiquidValve {
        attribute maxFlowRate : FlowRateUnit;
        attribute wettedMaterial : String;
        attribute isOpen : Boolean := false;
        
        port ctrl : ControlPort;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        
        flow of CorrosiveFluid from fluidIn to fluidOut;
        
        action Open {
            isOpen := true;
        }
        action Close {
            isOpen := false;
        }
    }
    
    // ============================================================
    // Gas Valve
    // ============================================================
    part def GasValve {
        attribute maxFlowRate : FlowRateUnit;
        attribute wettedMaterial : String;
        attribute isOpen : Boolean := false;
        
        port ctrl : ControlPort;
        port gasIn : GasPort;
        port gasOut : GasPort;
        
        flow of PressurizedGas from gasIn to gasOut;
        
        action Open {
            isOpen := true;
        }
        action Close {
            isOpen := false;
        }
    }
    
    // ============================================================
    // Level Sensor
    // ============================================================
    part def LevelSensor {
        attribute maxRange : VolumeUnit;
        attribute wettedMaterial : String;
        attribute currentVolume : VolumeUnit := 0;
        
        port reading : LevelReadingPort;
        
        bind reading.volume = currentVolume;
        
        action Sample {
            currentVolume := currentVolume;
        }
    }
    
    // ============================================================
    // Pressure Sensor
    // ============================================================
    part def PressureSensor {
        attribute maxRange : PressureUnit;
        attribute wettedMaterial : String;
        attribute currentPressure : PressureUnit := 0;
        
        port reading : PressureReadingPort;
        
        bind reading.pressure = currentPressure;
        
        action Sample {
            currentPressure := currentPressure;
        }
    }
    
    // ============================================================
    // Pressure Vessel
    // ============================================================
    part def PressureVessel {
        attribute capacity : VolumeUnit;
        attribute designPressure : PressureUnit;
        attribute maxOperatingPressure : PressureUnit;
        attribute maxFillVolume : VolumeUnit;
        attribute currentVolume : VolumeUnit := 0;
        attribute currentPressure : PressureUnit := 0;
        attribute wettedMaterial : String;
        attribute safetyFactor : Real;
        
        port liquidInPort : FluidPort;
        port liquidOutPort : FluidPort;
        port gasInPort : GasPort;
        port ventPort : GasPort;
        
        flow of CorrosiveFluid from liquidInPort to liquidOutPort;
        flow of PressurizedGas from gasInPort to ventPort;
    }
    
    // ============================================================
    // Source / Destination / Gas Supply
    // ============================================================
    part def FluidSource {
        attribute supplyPressure : PressureUnit;
        attribute availableVolume : VolumeUnit;
        attribute fluidType : String;
        
        port supply : FluidPort;
    }
    
    part def FluidDestination {
        attribute headPressure : PressureUnit;
        
        port receive : FluidPort;
    }
    
    part def GasSupply {
        attribute supplyPressure : PressureUnit;
        attribute gasType : String;
        
        port supply : GasPort;
    }
    
    // ============================================================
    // Controller with State Machine
    // ============================================================
    part def AcidEggController {
        attribute targetVolume : VolumeUnit;
        attribute targetOperatingPressure : PressureUnit;
        attribute volumeTolerancePercent : PercentUnit;
        attribute fillTimeout : TimeUnit;
        attribute pressurizeTimeout : TimeUnit;
        attribute dischargeTimeout : TimeUnit;
        attribute ventTimeout : TimeUnit;
        attribute cyclesCompleted : Integer := 0;
        
        port toInlet : ControlPort;
        port toOutlet : ControlPort;
        port toGas : ControlPort;
        port toVent : ControlPort;
        port fromLevel : LevelReadingPort;
        port fromPressure : PressureReadingPort;
        
        state Cycle {
            state Filling {
                doc "Fill the pressure vessel with corrosive fluid from the source to the target volume.";
                entry {
                    toInlet.command := ControlCommand::OPEN;
                    toOutlet.command := ControlCommand::CLOSE;
                    toGas.command := ControlCommand::CLOSE;
                    toVent.command := ControlCommand::CLOSE;
                }
            }
            
            state Pressurizing {
                doc "Feed pressurized gas into the vessel until operating pressure is reached.";
                entry {
                    toInlet.command := ControlCommand::CLOSE;
                    toOutlet.command := ControlCommand::CLOSE;
                    toGas.command := ControlCommand::OPEN;
                    toVent.command := ControlCommand::CLOSE;
                }
            }
            
            state Discharging {
                doc "Open the outlet and force the fluid to destination using gas pressure.";
                entry {
                    toInlet.command := ControlCommand::CLOSE;
                    toOutlet.command := ControlCommand::OPEN;
                    toGas.command := ControlCommand::OPEN;
                    toVent.command := ControlCommand::CLOSE;
                }
            }
            
            state Venting {
                doc "Close process valves and vent the residual gas to ready the vessel for the next cycle.";
                entry {
                    toInlet.command := ControlCommand::CLOSE;
                    toOutlet.command := ControlCommand::CLOSE;
                    toGas.command := ControlCommand::CLOSE;
                    toVent.command := ControlCommand::OPEN;
                }
                exit {
                    cyclesCompleted := cyclesCompleted + 1;
                }
            }
            
            transition from Filling to Pressurizing
                when fromLevel.volume >= targetVolume;
            
            transition from Pressurizing to Discharging
                when fromPressure.pressure >= targetOperatingPressure;
            
            transition from Discharging to Venting
                when fromLevel.volume <= 0;
            
            transition from Venting to Filling
                when fromPressure.pressure <= 0;
        }
    }
    
    // ============================================================
    // Top-level Acid Egg System
    // ============================================================
    part def AcidEggSystem {
        attribute systemTag : String := "AcidEgg-1";
        attribute fluidHandled : String := "Hydrochloric Acid (32%)";
        
        part vessel : PressureVessel {
            capacity = 100;
            designPressure = 12;
            maxOperatingPressure = 6;
            maxFillVolume = 80;
            wettedMaterial = "PFA-lined carbon steel";
            safetyFactor = 2.0;
        }
        
        part inletValve : LiquidValve {
            maxFlowRate = 50;
            wettedMaterial = "PTFE-lined ductile iron";
        }
        
        part outletValve : LiquidValve {
            maxFlowRate = 50;
            wettedMaterial = "PTFE-lined ductile iron";
        }
        
        part gasValve : GasValve {
            maxFlowRate = 2000;
            wettedMaterial = "316L stainless steel";
        }
        
        part ventValve : GasValve {
            maxFlowRate = 2000;
            wettedMaterial = "316L stainless steel";
        }
        
        part levelSensor : LevelSensor {
            maxRange = 100;
            wettedMaterial = "Tantalum";
        }
        
        part pressureSensor : PressureSensor {
            maxRange = 15;
            wettedMaterial = "316L stainless steel diaphragm";
        }
        
        part source : FluidSource {
            supplyPressure = 0.5;
            availableVolume = 1000;
            fluidType = "Hydrochloric Acid (32%)";
        }
        
        part destination : FluidDestination {
            headPressure = 1;
        }
        
        part gasSupply : GasSupply {
            supplyPressure = 8;
            gasType = "Nitrogen";
        }
        
        part controller : AcidEggController {
            targetVolume = 50;
            targetOperatingPressure = 4;
            volumeTolerancePercent = 2;
            fillTimeout = 120;
            pressurizeTimeout = 60;
            dischargeTimeout = 180;
            ventTimeout = 60;
        }
        
        // === Fluid Path ===
        connection source.supply to inletValve.fluidIn;
        connection inletValve.fluidOut to vessel.liquidInPort;
        connection vessel.liquidOutPort to outletValve.fluidIn;
        connection outletValve.fluidOut to destination.receive;
        
        // === Pressurization Gas Path ===
        connection gasSupply.supply to gasValve.gasIn;
        connection gasValve.gasOut to vessel.gasInPort;
        
        // === Vent Path ===
        connection vessel.ventPort to ventValve.gasIn;
        
        // === Control Signals ===
        connection controller.toInlet to inletValve.ctrl;
        connection controller.toOutlet to outletValve.ctrl;
        connection controller.toGas to gasValve.ctrl;
        connection controller.toVent to ventValve.ctrl;
        
        // === Sensor Signal Connections ===
        connection levelSensor.reading to controller.fromLevel;
        connection pressureSensor.reading to controller.fromPressure;
        
        // === Sensing Bindings ===
        bind levelSensor.currentVolume = vessel.currentVolume;
        bind pressureSensor.currentPressure = vessel.currentPressure;
    }
    
    // ============================================================
    // Requirements
    // ============================================================
    requirement def CorrosionResistanceRequirement {
        doc "All wetted components shall be constructed from corrosion-resistant materials compatible with the handled corrosive fluid.";
        subject sys1 : AcidEggSystem;
        attribute fluidHandled : String;
        attribute inletMaterial : String;
        attribute outletMaterial : String;
        attribute vesselMaterial : String;
        attribute sensorMaterial : String;
        constraint {
            inletMaterial <> "" and
            outletMaterial <> "" and
            vesselMaterial <> "" and
            sensorMaterial <> ""
        }
    }
    
    requirement def PressureVesselSafetyMarginRequirement {
        doc "The pressure vessel design pressure shall exceed the maximum operating pressure by a safety factor of at least 2.0, providing a robust margin against over-pressure conditions.";
        subject vessel1 : PressureVessel;
        attribute designPressure : PressureUnit;
        attribute maxOperatingPressure : PressureUnit;
        attribute safetyFactor : Real := 2.0;
        constraint {
            designPressure >= safetyFactor * maxOperatingPressure
        }
    }
    
    requirement def TransferAccuracyRequirement {
        doc "The volume of corrosive fluid transferred during each batch cycle shall be within ±2% of the specified target volume.";
        subject controller1 : AcidEggController;
        attribute targetVolume : VolumeUnit;
        attribute volumeTolerancePercent : PercentUnit := 2;
        attribute transferredVolume : VolumeUnit;
        constraint {
            abs(transferredVolume - targetVolume) <= targetVolume * volumeTolerancePercent / 100
        }
    }
    
    requirement def CycleTimeRequirement {
        doc "Each stage of the four-stage operational cycle shall complete within its configured timeout.";
        subject controller2 : AcidEggController;
        attribute fillTimeout : TimeUnit;
        attribute pressurizeTimeout : TimeUnit;
        attribute dischargeTimeout : TimeUnit;
        attribute ventTimeout : TimeUnit;
        constraint {
            fillTimeout > 0 and
            pressurizeTimeout > 0 and
            dischargeTimeout > 0 and
            ventTimeout > 0
        }
    }
    
    requirement def NoMovingWettedPartsRequirement {
        doc "The system shall use no moving parts in contact with the corrosive fluid; transfer shall be achieved by gas pressure rather than mechanical pumping.";
        subject sys2 : AcidEggSystem;
    }
    
    requirement def FourStageCycleRequirement {
        doc "Operation shall proceed through Filling, Pressurizing, Discharging, and Venting in the prescribed order.";
        subject controller3 : AcidEggController;
        attribute stageCount : Integer := 4;
    }
    
    requirement AcidEggSpecifications {
        requirement corrosion1 : CorrosionResistanceRequirement;
        requirement pressure1 : PressureVesselSafetyMarginRequirement;
        requirement accuracy1 : TransferAccuracyRequirement;
        requirement cycle1 : CycleTimeRequirement;
        requirement nopumps1 : NoMovingWettedPartsRequirement;
        requirement cycle2 : FourStageCycleRequirement;
    }
    
    // ============================================================
    // Satisfaction Relationships
    // ============================================================
    satisfaction CorrosionResistanceSatisfaction {
        subject sys1 : AcidEggSystem;
        requirement corrosion1 : CorrosionResistanceRequirement;
    }
    
    satisfaction PressureVesselSafetyMarginSatisfaction {
        subject vessel1 : AcidEggSystem::vessel;
        requirement pressure1 : PressureVesselSafetyMarginRequirement;
    }
    
    satisfaction TransferAccuracySatisfaction {
        subject controller1 : AcidEggSystem::controller;
        requirement accuracy1 : TransferAccuracyRequirement;
    }
    
    satisfaction CycleTimeSatisfaction {
        subject controller2 : AcidEggSystem::controller;
        requirement cycle1 : CycleTimeRequirement;
    }
    
    satisfaction NoMovingWettedPartsSatisfaction {
        subject sys2 : AcidEggSystem;
        requirement nopumps1 : NoMovingWettedPartsRequirement;
    }
    
    satisfaction FourStageCycleSatisfaction {
        subject controller3 : AcidEggSystem::controller;
        requirement cycle2 : FourStageCycleRequirement;
    }
}
