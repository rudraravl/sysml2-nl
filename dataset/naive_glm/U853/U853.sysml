package ProximitySensingSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type MagneticFluxDensity :> Real {
        unit 'T';
    }
    value type Distance :> Real {
        unit 'm';
    }
    value type Voltage :> Real {
        unit 'V';
    }
    value type Current :> Real {
        unit 'A';
    }
    value type Resistance :> Real {
        unit 'ohm';
    }
    value type BooleanState :> Boolean;

    // ===== Item Types =====
    item def MagneticFlux {
        attribute fluxDensity : MagneticFluxDensity;
    }
    item def ElectricCurrent {
        attribute magnitude : Current;
    }

    // ===== Port Definitions =====
    port def MagneticPort {
        out flux : MagneticFlux;
    }
    port def ElectricalPort {
        in current : ElectricCurrent;
        out current : ElectricCurrent;
        attribute voltage : Voltage;
    }

    // ===== Magnet =====
    part def Magnet {
        attribute strength : MagneticFluxDensity = 0.05 [T];
        port magneticOut : MagneticPort;
        
        compute emitFlux {
            out flux.fluxDensity = strength;
        }
    }

    // ===== Reed Switch Components =====
    part def FerromagneticReed {
        attribute stiffness : MagneticFluxDensity = 0.008 [T];
        attribute isAttracted : Boolean = false;
    }

    part def GlassTube {
        attribute fillGas : String = "Nitrogen";
        attribute isHermeticallySealed : Boolean = true;
    }

    // ===== Reed Switch =====
    part def ReedSwitch {
        part reedA : FerromagneticReed;
        part reedB : FerromagneticReed;
        part enclosure : GlassTube;
        
        attribute pullInRange : MagneticFluxDensity = 0.012 [T];
        attribute dropOutRange : MagneticFluxDensity = 0.006 [T];
        attribute isClosed : Boolean = false;
        
        port magneticIn : MagneticPort;
        port electricalIn : ElectricalPort;
        port electricalOut : ElectricalPort;
        
        state machine ReedSwitchBehavior {
            entry then Open;
            
            state Open {
                entry { isClosed = false; }
                transition to Closed
                    when magneticIn.flux.fluxDensity >= pullInRange
                    do { reedA.isAttracted = true; reedB.isAttracted = true; isClosed = true; }
            }
            
            state Closed {
                entry { isClosed = true; }
                transition to Open
                    when magneticIn.flux.fluxDensity <= dropOutRange
                    do { reedA.isAttracted = false; reedB.isAttracted = false; isClosed = false; }
            }
        }
        
        compute conductCurrent {
            if isClosed {
                electricalOut.current = electricalIn.current;
            } else {
                electricalOut.current.magnitude = 0 [A];
            }
        }
    }

    // ===== Power Source =====
    part def PowerSource {
        attribute nominalVoltage : Voltage = 12 [V];
        attribute internalResistance : Resistance = 0.1 [ohm];
        
        port powerOut : ElectricalPort;
        
        compute supplyCurrent {
            powerOut.voltage = nominalVoltage;
            powerOut.current.magnitude = nominalVoltage / (internalResistance + 100 [ohm]);
        }
    }

    // ===== Electrical Load =====
    part def ElectricalLoad {
        attribute loadResistance : Resistance = 100 [ohm];
        attribute isEnergized : Boolean = false;
        
        port loadIn : ElectricalPort;
        
        compute energize {
            if loadIn.current.magnitude > 0 [A] {
                isEnergized = true;
            } else {
                isEnergized = false;
            }
        }
    }

    // ===== Proximity Sensing System Assembly =====
    part def ProximitySensingSystem {
        part magnet : Magnet;
        part reedSwitch : ReedSwitch;
        part powerSource : PowerSource;
        part load : ElectricalLoad;
        
        connection magneticLink connect magnet.magneticOut to reedSwitch.magneticIn;
        connection powerLink connect powerSource.powerOut to reedSwitch.electricalIn;
        connection loadLink connect reedSwitch.electricalOut to load.loadIn;
    }

    // ===== Requirements =====
    requirement def DetectMagnetPresence {
        subject : ProximitySensingSystem;
        objective {
            doc /* The system shall detect the presence of a magnet within its activation range. */
        }
        assume magnet.strength >= 0.012 [T];
    }

    requirement def ActivateLoadOnClose {
        subject : ProximitySensingSystem;
        objective {
            doc /* When the reed switch closes, the electrical load shall be energized. */
        }
        require reedSwitch.isClosed implies load.isEnergized;
    }

    requirement def DeactivateLoadOnOpen {
        subject : ProximitySensingSystem;
        objective {
            doc /* When the reed switch opens, the electrical load shall be de-energized. */
        }
        require not reedSwitch.isClosed implies not load.isEnergized;
    }

    requirement def HysteresisBehavior {
        subject : ReedSwitch;
        objective {
            doc /* The reed switch shall exhibit hysteresis such that the closing threshold exceeds the opening threshold. */
        }
        require pullInRange > dropOutRange;
    }

    requirement def HermeticSealing {
        subject : ReedSwitch;
        objective {
            doc /* The reeds shall be sealed inside a hermetically sealed glass tube filled with inert gas. */
        }
        require enclosure.isHermeticallySealed == true;
        require enclosure.fillGas == "Nitrogen";
    }

    requirement def PreventChatter {
        subject : ReedSwitch;
        objective {
            doc /* The switch shall not chatter when the magnet is held at the edge of activation range. */
        }
        require pullInRange - dropOutRange >= 0.004 [T];
    }

    // ===== Requirement Satisfaction =====
    satisfaction detectMagnetSatisfaction : DetectMagnetPresence {
        subject = ProximitySensingSystem;
    }
    satisfaction activateLoadSatisfaction : ActivateLoadOnClose {
        subject = ProximitySensingSystem;
    }
    satisfaction deactivateLoadSatisfaction : DeactivateLoadOnOpen {
        subject = ProximitySensingSystem;
    }
    satisfaction hysteresisSatisfaction : HysteresisBehavior {
        subject = reedSwitch;
    }
    satisfaction hermeticSatisfaction : HermeticSealing {
        subject = reedSwitch;
    }
    satisfaction chatterSatisfaction : PreventChatter {
        subject = reedSwitch;
    }
}
