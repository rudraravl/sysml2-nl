package IcePackCoolingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ThermalConductivity {
        attribute value : Real;
    }
    
    attribute def SpecificHeatCapacity {
        attribute value : Real;
    }
    
    attribute def LatentHeatOfFusion {
        attribute value : Real;
    }
    
    enum def PhaseState {
        enum frozen;
        enum melting;
        enum liquid;
    }
    
    item def CoolantGel {
        attribute mass :> ISQ::mass;
        attribute temperature :> ISQ::temperature;
        attribute phase : PhaseState;
        attribute freezingPoint :> ISQ::temperature;
        attribute latentHeat : LatentHeatOfFusion;
        attribute specificHeat : SpecificHeatCapacity;
    }
    
    item def InsulationMaterial {
        attribute thickness :> ISQ::length;
        attribute thermalConductivity : ThermalConductivity;
    }
    
    item def FlexiblePouch {
        attribute material : String;
        attribute capacity :> ISQ::volume;
    }
    
    port def ThermalInterface {
        attribute surfaceTemperature :> ISQ::temperature;
        attribute heatFlowRate :> ISQ::heatFlowRate;
    }
    
    part def IcePack {
        attribute packTemperature :> ISQ::temperature;
        attribute ambientTemperature :> ISQ::temperature;
        attribute effectiveCoolingTime :> ISQ::time;
        
        part gel : CoolantGel {
            attribute mass = 0.5 [SI::kg];
            attribute temperature :>> temperature;
            attribute phase = PhaseState::frozen;
            attribute freezingPoint = 273.15 [SI::K];
            attribute latentHeat : LatentHeatOfFusion {
                attribute value = 334000.0;
            }
            attribute specificHeat : SpecificHeatCapacity {
                attribute value = 2100.0;
            }
        }
        
        part pouch : FlexiblePouch {
            attribute material = "polyethylene";
            attribute capacity = 0.0007 [SI::m^3];
        }
        
        part insulation : InsulationMaterial {
            attribute thickness = 0.004 [SI::m];
            attribute thermalConductivity : ThermalConductivity {
                attribute value = 0.035;
            }
        }
        
        port thermalPort : ThermalInterface;
    }
    
    action def MeasureTemperature {
        in currentTemp :> ISQ::temperature;
        in ambientTemp :> ISQ::temperature;
        out temperatureGradient :> ISQ::temperature;
        out isEffective : Boolean;
    }
    
    action def AbsorbThermalEnergy {
        in heatInput :> ISQ::heatFlowRate;
        in gelMass :> ISQ::mass;
        in currentPhase : PhaseState;
        in currentTemp :> ISQ::temperature;
        out newPhase : PhaseState;
        out newTemp :> ISQ::temperature;
    }
    
    action def ConductHeat {
        in surfaceTemp :> ISQ::temperature;
        in externalTemp :> ISQ::temperature;
        in conductivity : ThermalConductivity;
        in insulationThickness :> ISQ::length;
        out heatTransfer :> ISQ::heatFlowRate;
    }
    
    action def ProvideCooling {
        in initialTemp :> ISQ::temperature;
        in targetTemp :> ISQ::temperature;
        in environmentTemp :> ISQ::temperature;
        in operatingDuration :> ISQ::time;
        out finalTemp :> ISQ::temperature;
        out coolingEfficiency : Real;
        
        first start;
        then merge coolingLoop;
        
        then action measure : MeasureTemperature {
            in currentTemp = initialTemp;
            in ambientTemp = environmentTemp;
            out temperatureGradient;
            out isEffective;
        }
        
        then decide;
            if measure.isEffective then absorb;
            if not measure.isEffective then complete;
        
        action absorb : AbsorbThermalEnergy {
            in heatInput;
            in gelMass;
            in currentPhase;
            in currentTemp;
            out newPhase;
            out newTemp;
        }
        
        then action conduct : ConductHeat {
            in surfaceTemp = absorb.newTemp;
            in externalTemp = environmentTemp;
            in conductivity;
            in insulationThickness;
            out heatTransfer;
        }
        
        then coolingLoop;
        
        action complete {
            out result = finalTemp;
        }
        
        then done;
    }
    
    state def IcePackLifecycle {
        entry; then frozenState;
        
        state frozenState;
        
        transition frozenToMelting
            first frozenState
            accept at beginMelting
            then meltingState;
        
        state meltingState;
        
        transition meltingToLiquid
            first meltingState
            accept at meltComplete
            then liquidState;
        
        state liquidState;
        
        transition liquidToWarming
            first liquidState
            accept at warmingBegins
            then warmingState;
        
        state warmingState;
    }
    
    part icePackSystem : IcePack {
        attribute packTemperature = 253.15 [SI::K];
        attribute ambientTemperature = 298.15 [SI::K];
        attribute effectiveCoolingTime = 14400.0 [SI::s];
        
        exhibit state lifecycle : IcePackLifecycle;
        
        perform action coolingOperation : ProvideCooling {
            in initialTemp = packTemperature;
            in targetTemp = 277.15 [SI::K];
            in environmentTemp = ambientTemperature;
            in operatingDuration = effectiveCoolingTime;
            out finalTemp;
            out coolingEfficiency;
        }
    }
    
    requirement def TemperatureMaintenanceRequirement {
        doc /* The ice pack shall maintain a temperature below 277.15 K for at least 3 hours. */
        
        subject pack : IcePack;
        
        require constraint lowTemperature {
            pack.packTemperature < 277.15 [SI::K]
        }
        
        require constraint minimumDuration {
            pack.effectiveCoolingTime >= 10800.0 [SI::s]
        }
    }
    
    requirement def StructuralIntegrityRequirement {
        doc /* The ice pack pouch shall remain sealed and leak-proof during operation. */
        
        subject pouch : FlexiblePouch;
        
        require constraint materialStrength {
            pouch.material == "polyethylene"
        }
        
        require constraint adequateCapacity {
            pouch.capacity >= 0.0005 [SI::m^3]
        }
    }
    
    requirement def ThermalInsulationRequirement {
        doc /* The ice pack shall minimize heat transfer from the environment. */
        
        subject insulation : InsulationMaterial;
        
        require constraint sufficientThickness {
            insulation.thickness >= 0.003 [SI::m]
        }
        
        require constraint lowConductivity {
            insulation.thermalConductivity.value <= 0.05
        }
    }
    
    requirement def CoolingCapacityRequirement {
        doc /* The ice pack shall absorb sufficient thermal energy through phase change. */
        
        subject gel : CoolantGel;
        
        require constraint adequateMass {
            gel.mass >= 0.4 [SI::kg]
        }
        
        require constraint highLatentHeat {
            gel.latentHeat.value >= 300000.0
        }
    }
    
    requirement topLevelRequirements {
        doc /* 
            The ice pack system shall provide sustained cooling by absorbing thermal energy
            from its surroundings through phase change and thermal conduction, maintaining
            reduced temperatures for medical therapy, food preservation, or temperature control.
        */
        
        require temperatureMaintenance : TemperatureMaintenanceRequirement;
        require structuralIntegrity : StructuralIntegrityRequirement;
        require thermalInsulation : ThermalInsulationRequirement;
        require coolingCapacity : CoolingCapacityRequirement;
    }
}
