package CapacitorEnergyStorageSystem {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    item def ElectricalPower;

    port def PositiveTerminal {
        out item power : ElectricalPower;
        attribute voltage :> ISQ::electricPotential;
        attribute current :> ISQ::electricCurrent;
    }

    port def NegativeTerminal {
        in item power : ElectricalPower;
        attribute voltage :> ISQ::electricPotential;
        attribute current :> ISQ::electricCurrent;
    }

    attribute def ChargeCommand;
    attribute def DischargeCommand;
    attribute def StopCommand;

    action def SupplyPower {
        out power : ElectricalPower;
    }

    action def ChargeCapacitor {
        in targetVoltage :> ISQ::electricPotential;
        out charge :> ISQ::electricCharge;
    }

    action def DischargeCapacitor {
        out energy :> ISQ::energy;
    }

    part def VoltageSource {
        attribute nominalVoltage :> ISQ::electricPotential = 12 [V];
        attribute maxCurrent :> ISQ::electricCurrent = 2 [A];
        port outputPort : PositiveTerminal;
        perform action supply : SupplyPower {
            out power = outputPort.power;
        }
    }

    part def Resistor {
        attribute resistance :> ISQ::resistance;
        attribute voltageDrop :> ISQ::electricPotential;
        attribute current :> ISQ::electricCurrent;
        port inPort : NegativeTerminal;
        port outPort : PositiveTerminal;
    }

    part def ChargingResistor :> Resistor {
        attribute :>> resistance = 100 [ohm];
    }

    part def LoadResistor :> Resistor {
        attribute :>> resistance = 50 [ohm];
    }

    part def Capacitor {
        attribute capacitance :> ISQ::capacitance = 1 [F];
        attribute maxSafeVoltage :> ISQ::electricPotential = 16 [V];
        attribute currentVoltage :> ISQ::electricPotential = 0 [V];
        attribute storedCharge :> ISQ::electricCharge;
        attribute storedEnergy :> ISQ::energy;
        port chargePort : NegativeTerminal;
        port dischargePort : PositiveTerminal;
        assert constraint chargeRelation { storedCharge == capacitance * currentVoltage }
        assert constraint energyRelation { storedEnergy == 0.5 * capacitance * currentVoltage * currentVoltage }
        assert constraint safeOperatingVoltage { currentVoltage <= maxSafeVoltage }
        perform action chargeAction : ChargeCapacitor {
            in targetVoltage = maxSafeVoltage;
            out charge = storedCharge;
        }
        perform action dischargeAction : DischargeCapacitor {
            out energy = storedEnergy;
        }
    }

    state def SystemStates;

    requirement def SafeChargingRequirement {
        doc /* The capacitor voltage shall not exceed the maximum safe voltage during charging. */
        subject capacitor : Capacitor;
        require constraint { capacitor.currentVoltage <= capacitor.maxSafeVoltage }
    }

    requirement def EnergyStorageRequirement {
        doc /* The system shall store charge and energy in the capacitor based on its voltage level. */
        subject capacitor : Capacitor;
        require constraint { capacitor.storedCharge == capacitor.capacitance * capacitor.currentVoltage }
        require constraint { capacitor.storedEnergy == 0.5 * capacitor.capacitance * capacitor.currentVoltage * capacitor.currentVoltage }
    }

    requirement def DischargeCapabilityRequirement {
        doc /* The system shall release stored energy through the load resistor upon discharge command. */
        subject loadResistor : LoadResistor;
    }

    part def CapacitorEnergyStorageSystem {
        part voltageSource : VoltageSource;
        part chargingResistor : ChargingResistor;
        part capacitor : Capacitor;
        part loadResistor : LoadResistor;

        flow of power : ElectricalPower
            from voltageSource.outputPort.power
            to chargingResistor.inPort.power;
        flow of power : ElectricalPower
            from chargingResistor.outPort.power
            to capacitor.chargePort.power;
        flow of power : ElectricalPower
            from capacitor.dischargePort.power
            to loadResistor.inPort.power;

        state systemStates : SystemStates {
            entry; then idle;
            state idle;
            accept ChargeCommand then charging;
            state charging;
            accept DischargeCommand then discharging;
            accept StopCommand then idle;
            when capacitor.currentVoltage >= capacitor.maxSafeVoltage then charged;
            state charged;
            accept DischargeCommand then discharging;
            accept StopCommand then idle;
            state discharging;
            accept ChargeCommand then charging;
            accept StopCommand then idle;
            when capacitor.currentVoltage <= 0 [V] then idle;
        }

        requirement safeCharging : SafeChargingRequirement {
            subject :>> capacitor = capacitor;
        }
        requirement energyStorage : EnergyStorageRequirement {
            subject :>> capacitor = capacitor;
        }
        requirement dischargeCapability : DischargeCapabilityRequirement {
            subject :>> loadResistor = loadResistor;
        }
    }

    part context {
        part system : CapacitorEnergyStorageSystem;
    }
}
