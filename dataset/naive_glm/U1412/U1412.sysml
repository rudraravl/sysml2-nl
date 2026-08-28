package HeatEngineSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types with Units =====
    
    value def Energy :> Real { unit 'J' }
    value def Temperature :> Real { unit 'K' }
    value def Pressure :> Real { unit 'Pa' }
    value def Volume :> Real { unit 'm3' }
    value def Power :> Real { unit 'W' }
    value def HeatFlowRate :> Real { unit 'W' }
    value def WorkFlowRate :> Real { unit 'W' }
    value def Efficiency :> Real { unit '1' }
    value def Entropy :> Real { unit 'J/K' }
    
    // ===== Item Types =====
    
    item def HeatPacket {
        attribute quantity : Energy;
        attribute sourceTemp : Temperature;
    }
    
    item def WorkPacket {
        attribute quantity : Energy;
        attribute deliveredAt : Time;
    }
    
    item def WorkingSubstance {
        attribute internalEnergy : Energy;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute volume : Volume;
        attribute entropy : Entropy;
    }
    
    // ===== Port Definitions =====
    
    port def HeatOutPort {
        out item heat : HeatPacket;
        attribute maxRate : HeatFlowRate;
    }
    
    port def HeatInPort {
        in item heat : HeatPacket;
        attribute maxRate : HeatFlowRate;
    }
    
    port def WorkOutPort {
        out item work : WorkPacket;
        attribute maxRate : WorkFlowRate;
    }
    
    port def WorkInPort {
        in item work : WorkPacket;
        attribute maxRate : WorkFlowRate;
    }
    
    // ===== Requirements =====
    
    requirement def FirstLawOfThermodynamics {
        doc "The energy supplied by the hot reservoir must equal the sum of useful work and waste heat rejected to the cold reservoir.";
        
        attribute heatIn : Energy;
        attribute workOut : Energy;
        attribute heatOut : Energy;
        
        constraint { heatIn == workOut + heatOut }
    }
    
    requirement def EnergyConservation {
        doc "Total energy entering the system must equal total energy leaving the system over each complete cycle.";
        
        attribute energyIn : Energy;
        attribute energyOut : Energy;
        
        constraint { energyIn == energyOut }
    }
    
    requirement def PositiveWorkRequirement {
        doc "The engine must produce a positive net work output over each cycle.";
        
        attribute netWork : Energy;
        
        constraint { netWork > 0 }
    }
    
    requirement def CycleCompletionRequirement {
        doc "The working substance must return to its initial thermodynamic state at the end of each cycle.";
        
        attribute initialInternalEnergy : Energy;
        attribute finalInternalEnergy : Energy;
        
        constraint { initialInternalEnergy == finalInternalEnergy }
    }
    
    requirement def EfficiencyRequirement {
        doc "The engine thermal efficiency must be positive and bounded by the Carnot efficiency.";
        
        attribute efficiency : Efficiency;
        attribute hotTemp : Temperature;
        attribute coldTemp : Temperature;
        
        constraint { efficiency > 0 }
        constraint { efficiency <= (1 - coldTemp / hotTemp) }
    }
    
    // ===== Part Definitions =====
    
    part def HotReservoir {
        doc "High-temperature reservoir acting as the heat source.";
        
        attribute temperature : Temperature = 800 [K];
        attribute heatCapacity : Energy = 1000000 [J];
        attribute availableEnergy : Energy = 500000 [J];
        
        port heatOut : HeatOutPort {
            attribute maxRate = 5000 [W];
        }
        
        action def SupplyHeat :> Action {
            out suppliedHeat : HeatPacket;
        }
        
        perform action supplyHeat : SupplyHeat;
    }
    
    part def ColdReservoir {
        doc "Low-temperature reservoir acting as the heat sink.";
        
        attribute temperature : Temperature = 300 [K];
        attribute heatCapacity : Energy = 1000000 [J];
        attribute absorbedEnergy : Energy = 0 [J];
        
        port heatIn : HeatInPort {
            attribute maxRate = 5000 [W];
        }
        
        action def AbsorbHeat :> Action {
            in receivedHeat : HeatPacket;
        }
        
        perform action absorbHeat : AbsorbHeat;
    }
    
    part def MechanicalLoad {
        doc "Mechanical device consuming work produced by the engine.";
        
        attribute totalWorkReceived : Energy = 0 [J];
        attribute ratedPower : Power = 2000 [W];
        
        port workIn : WorkInPort {
            attribute maxRate = 3000 [W];
        }
        
        action def ConsumeWork :> Action {
            in receivedWork : WorkPacket;
        }
        
        perform action consumeWork : ConsumeWork;
    }
    
    part def EngineCore {
        doc "Core engine converting thermal energy into mechanical work through a thermodynamic cycle.";
        
        attribute workingSubstance : WorkingSubstance {
            attribute internalEnergy = 1000 [J];
            attribute temperature = 300 [K];
            attribute pressure = 101325 [Pa];
            attribute volume = 0.001 [m3];
            attribute entropy = 10 [J/K];
        }
        
        attribute cycleCount : Integer = 0;
        attribute totalHeatAbsorbed : Energy = 0 [J];
        attribute totalWorkProduced : Energy = 0 [J];
        attribute totalHeatRejected : Energy = 0 [J];
        attribute thermalEfficiency : Efficiency = 0;
        
        port heatIn : HeatInPort {
            attribute maxRate = 5000 [W];
        }
        
        port heatOut : HeatOutPort {
            attribute maxRate = 5000 [W];
        }
        
        port workOut : WorkOutPort {
            attribute maxRate = 3000 [W];
        }
        
        // State machine governing the thermodynamic cycle
        state machine def ThermodynamicCycle {
            doc "Cyclical process: heat absorption, expansion, heat rejection, compression.";
            
            entry; then AbsorbingHeat;
            
            state AbsorbingHeat {
                doc "Working substance absorbs heat from the hot reservoir, increasing internal energy, temperature, and pressure.";
                
                entry {
                    workingSubstance.internalEnergy += heatIn.heat.quantity;
                    workingSubstance.temperature += heatIn.heat.quantity / (workingSubstance.entropy);
                }
                
                do {
                    totalHeatAbsorbed += heatIn.heat.quantity;
                }
                
                transition to Expanding
                    when workingSubstance.temperature >= 800 [K];
            }
            
            state Expanding {
                doc "High-energy working substance expands, performing mechanical work on the load.";
                
                entry {
                    attribute workProduced : Energy = workingSubstance.internalEnergy * 0.4;
                    workOut.work.quantity := workProduced;
                    workingSubstance.volume *= 2;
                    workingSubstance.pressure /= 2;
                    workingSubstance.internalEnergy -= workProduced;
                    totalWorkProduced += workProduced;
                }
                
                transition to RejectingHeat
                    when workingSubstance.pressure <= 50662 [Pa];
            }
            
            state RejectingHeat {
                doc "Engine expels remaining waste heat to the cold reservoir.";
                
                entry {
                    attribute wasteHeat : Energy = workingSubstance.internalEnergy * 0.5;
                    heatOut.heat.quantity := wasteHeat;
                    workingSubstance.temperature -= wasteHeat / workingSubstance.entropy;
                    workingSubstance.internalEnergy -= wasteHeat;
                    totalHeatRejected += wasteHeat;
                }
                
                transition to Compressing
                    when workingSubstance.temperature <= 300 [K];
            }
            
            state Compressing {
                doc "Working substance is compressed back to its initial state, ready for the next cycle.";
                
                entry {
                    workingSubstance.volume /= 2;
                    workingSubstance.pressure *= 2;
                    workingSubstance.temperature := 300 [K];
                    workingSubstance.internalEnergy := 1000 [J];
                }
                
                do {
                    cycleCount += 1;
                    thermalEfficiency := totalWorkProduced / totalHeatAbsorbed;
                }
                
                transition to AbsorbingHeat
                    when workingSubstance.internalEnergy == 1000 [J];
            }
        }
        
        perform state machine cycle : ThermodynamicCycle;
        
        // First Law verification action
        action def VerifyFirstLaw :> Action {
            in heatInVal : Energy;
            in workOutVal : Energy;
            in heatOutVal : Energy;
            
            constraint { heatInVal == workOutVal + heatOutVal }
        }
        
        perform action verifyFirstLaw : VerifyFirstLaw {
            in heatInVal = totalHeatAbsorbed;
            in workOutVal = totalWorkProduced;
            in heatOutVal = totalHeatRejected;
        }
    }
    
    // ===== Top-level System =====
    
    part HeatEngineSystem {
        doc "Generalized heat engine system converting thermal energy into mechanical work.";
        
        part hotReservoir : HotReservoir;
        part coldReservoir : ColdReservoir;
        part engineCore : EngineCore;
        part mechanicalLoad : MechanicalLoad;
        
        // Requirements satisfaction
        satisfy firstLawReq : FirstLawOfThermodynamics {
            attribute heatIn = engineCore.totalHeatAbsorbed;
            attribute workOut = engineCore.totalWorkProduced;
            attribute heatOut = engineCore.totalHeatRejected;
        }
        
        satisfy energyConservationReq : EnergyConservation {
            attribute energyIn = engineCore.totalHeatAbsorbed;
            attribute energyOut = engineCore.totalWorkProduced + engineCore.totalHeatRejected;
        }
        
        satisfy positiveWorkReq : PositiveWorkRequirement {
            attribute netWork = engineCore.totalWorkProduced;
        }
        
        satisfy cycleCompletionReq : CycleCompletionRequirement {
            attribute initialInternalEnergy = 1000 [J];
            attribute finalInternalEnergy = engineCore.workingSubstance.internalEnergy;
        }
        
        satisfy efficiencyReq : EfficiencyRequirement {
            attribute efficiency = engineCore.thermalEfficiency;
            attribute hotTemp = hotReservoir.temperature;
            attribute coldTemp = coldReservoir.temperature;
        }
        
        // Connections
        connection hotToEngine : HeatFlowConnection connect
            hotReservoir.heatOut to engineCore.heatIn;
        
        connection engineToCold : HeatFlowConnection connect
            engineCore.heatOut to coldReservoir.heatIn;
        
        connection engineToLoad : WorkFlowConnection connect
            engineCore.workOut to mechanicalLoad.workIn;
    }
    
    // ===== Connection Definitions =====
    
    connection def HeatFlowConnection {
        end source : HeatOutPort;
        end target : HeatInPort;
        
        attribute transferredHeat : Energy;
        
        constraint { transferredHeat >= 0 [J] }
    }
    
    connection def WorkFlowConnection {
        end source : WorkOutPort;
        end target : WorkInPort;
        
        attribute transferredWork : Energy;
        
        constraint { transferredWork >= 0 [J] }
    }
}
