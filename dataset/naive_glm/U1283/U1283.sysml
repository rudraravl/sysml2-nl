package ControlledEmberSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Temperature :> Real { unit 'K'; }
    value def MassFlowRate :> Real { unit 'kg/s'; }
    value def HeatFlux :> Real { unit 'W'; }
    value def Mass :> Real { unit 'kg'; }
    value def VolumeFlowRate :> Real { unit 'm3/s'; }
    value def Percentage :> Real { unit '%'; }

    // ===== Item Types =====
    item def SolidFuel {
        attribute carbonContent : Percentage;
        attribute energyDensity : Real; // J/kg
        attribute mass : Mass;
    }
    item def Oxygen {
        attribute purity : Percentage;
        attribute flowRate : MassFlowRate;
    }
    item def ExhaustGas {
        attribute temperature : Temperature;
        attribute flowRate : MassFlowRate;
    }
    item def RadiantHeat {
        attribute flux : HeatFlux;
        attribute surfaceTemperature : Temperature;
    }

    // ===== Port Definitions =====
    port def FuelPort {
        out fuel : SolidFuel;
    }
    port def AirPort {
        out oxygen : Oxygen;
    }
    port def HeatPort {
        out heat : RadiantHeat;
    }
    port def ExhaustPort {
        out exhaust : ExhaustGas;
    }
    port def ControlPort {
        in temperature : Temperature;
        out airflowCommand : VolumeFlowRate;
    }

    // ===== Requirements =====
    requirement def StableHeatOutput {
        doc "The system shall produce continuous radiant heat at a stable output level.";
        attribute targetHeatFlux : HeatFlux = 500.0;
        attribute tolerance : HeatFlux = 50.0;
        subject emberSystem : EmberSystem;
        require emberSystem.radiator.heat.flux in (targetHeatFlux - tolerance .. targetHeatFlux + tolerance)
            when emberSystem.currentState == 'glowing';
    }

    requirement def FlamelessOperation {
        doc "Combustion shall occur as a flameless, glowing reaction.";
        subject core : CombustionCore;
        require core.flamePresent == false;
    }

    requirement def SelfRegulation {
        doc "The system shall self-regulate airflow to maintain stable temperature.";
        subject airSupply : AirSupplySystem;
        require airSupply.regulatedFlow == true;
    }

    requirement def LongDurationHeat {
        doc "The system shall sustain heat output for extended durations.";
        attribute minDuration : Real = 36000.0; // seconds
        subject emberSystem : EmberSystem;
        require emberSystem.operatingDuration >= minDuration;
    }

    // ===== Part Definitions =====
    part def FuelBed {
        port fuelOut : FuelPort;
        attribute fuelMass : Mass;
        attribute maxCapacity : Mass = 5.0;
        attribute lowFuelThreshold : Mass = 0.5;
        
        action def SupplyFuel {
            in requestedAmount : Mass;
            out deliveredFuel : SolidFuel;
        }
        
        perform action supplyFuel : SupplyFuel;
    }

    part def CombustionCore {
        port fuelIn : FuelPort;
        port airIn : AirPort;
        port heatOut : HeatPort;
        port exhaustOut : ExhaustPort;
        port control : ControlPort;
        
        attribute coreTemperature : Temperature;
        attribute targetTemperature : Temperature = 1073.0; // ~800°C
        attribute reactionRate : Real;
        attribute flamePresent : Boolean = false;
        attribute fuelRemaining : Mass;
        
        action def Combust {
            in fuel : SolidFuel;
            in oxygen : Oxygen;
            out heat : RadiantHeat;
            out exhaust : ExhaustGas;
        }
        
        perform action combust : Combust;
    }

    part def AirSupplySystem {
        port airOut : AirPort;
        port control : ControlPort;
        
        attribute currentFlowRate : VolumeFlowRate;
        attribute maxFlowRate : VolumeFlowRate = 0.01;
        attribute minFlowRate : VolumeFlowRate = 0.001;
        attribute regulatedFlow : Boolean = true;
        
        action def RegulateAirflow {
            in temperature : Temperature;
            out airflow : VolumeFlowRate;
        }
        
        perform action regulateAirflow : RegulateAirflow;
    }

    part def ThermalRadiator {
        port heatIn : HeatPort;
        port heatEmit : HeatPort;
        
        attribute surfaceTemperature : Temperature;
        attribute emissivity : Real = 0.9;
        attribute radiatingArea : Real = 0.25; // m2
        
        action def RadiateHeat {
            in heat : RadiantHeat;
            out emittedHeat : RadiantHeat;
        }
        
        perform action radiateHeat : RadiateHeat;
    }

    // ===== Top-Level Ember System =====
    part def EmberSystem {
        port externalHeat : HeatPort;
        
        attribute currentState : String;
        attribute operatingDuration : Real;
        
        part fuelBed : FuelBed {
            attribute fuelMass : Mass = 4.0;
        }
        part combustionCore : CombustionCore {
            attribute coreTemperature : Temperature = 293.15;
        }
        part airSupply : AirSupplySystem {
            attribute currentFlowRate : VolumeFlowRate = 0.003;
        }
        part radiator : ThermalRadiator {
            attribute surfaceTemperature : Temperature = 293.15;
        }
        
        connect fuelBed.fuelOut to combustionCore.fuelIn;
        connect airSupply.airOut to combustionCore.airIn;
        connect combustionCore.heatOut to radiator.heatIn;
        connect radiator.heatEmit to externalHeat;
        connect combustionCore.exhaustOut to self;
        connect combustionCore.control to airSupply.control;
        
        satisfy StableHeatOutput;
        satisfy FlamelessOperation;
        satisfy SelfRegulation;
        satisfy LongDurationHeat;
        
        state def EmberLifecycle {
            entry action { EmberSystem.currentState = 'dormant'; }
            
            state dormant {
                entry action { 
                    EmberSystem.currentState = 'dormant';
                    airSupply.currentFlowRate = 0.0;
                }
                transition to glowing
                    when (combustionCore.coreTemperature > 773.15)
                    do action { airSupply.currentFlowRate = 0.003; };
            }
            
            state glowing {
                entry action {
                    EmberSystem.currentState = 'glowing';
                    airSupply.regulatedFlow = true;
                }
                do action {
                    if (combustionCore.coreTemperature < combustionCore.targetTemperature - 50.0) {
                        airSupply.currentFlowRate = airSupply.currentFlowRate + 0.0005;
                    }
                    if (combustionCore.coreTemperature > combustionCore.targetTemperature + 50.0) {
                        airSupply.currentFlowRate = airSupply.currentFlowRate - 0.0005;
                    }
                    if (airSupply.currentFlowRate > airSupply.maxFlowRate) {
                        airSupply.currentFlowRate = airSupply.maxFlowRate;
                    }
                    if (airSupply.currentFlowRate < airSupply.minFlowRate) {
                        airSupply.currentFlowRate = airSupply.minFlowRate;
                    }
                }
                transition to fading
                    when (fuelBed.fuelMass < fuelBed.lowFuelThreshold 
                          or airSupply.currentFlowRate <= airSupply.minFlowRate);
            }
            
            state fading {
                entry action {
                    EmberSystem.currentState = 'fading';
                    airSupply.currentFlowRate = airSupply.maxFlowRate;
                }
                do action {
                    EmberSystem.operatingDuration = EmberSystem.operatingDuration + 1.0;
                }
                transition to glowing
                    when (combustionCore.coreTemperature > 873.15 
                          and fuelBed.fuelMass > fuelBed.lowFuelThreshold)
                    do action { airSupply.currentFlowRate = 0.003; };
                transition to extinguished
                    when (fuelBed.fuelMass <= 0.05 
                          or combustionCore.coreTemperature < 423.15);
            }
            
            state extinguished {
                entry action {
                    EmberSystem.currentState = 'extinguished';
                    airSupply.currentFlowRate = 0.0;
                }
                transition to dormant
                    when (fuelBed.fuelMass > 1.0);
            }
        }
        
        exhibit state lifecycle : EmberLifecycle;
    }
}
