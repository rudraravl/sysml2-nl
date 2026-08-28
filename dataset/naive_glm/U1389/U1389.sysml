package CapacitorEnergyStorageSystem {
    import ISQ::*;
    import ScalarValues::*;

    item def Electricity {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    port def ElectricalPort {
        inout flow of Electricity;
    }

    part def VoltageSource {
        attribute nominalVoltage : ElectricPotentialValue;
        port positive : ElectricalPort;
        port negative : ElectricalPort;
    }

    part def Resistor {
        attribute resistance : ElectricResistanceValue;
        port terminal1 : ElectricalPort;
        port terminal2 : ElectricalPort;
    }

    part def Capacitor {
        attribute capacitance : CapacitanceValue;
        attribute maxVoltage : ElectricPotentialValue;
        attribute currentVoltage : ElectricPotentialValue;
        attribute storedCharge : ElectricChargeValue;
        attribute storedEnergy : EnergyValue;

        port positive : ElectricalPort;
        port negative : ElectricalPort;

        compute {
            storedCharge = capacitance * currentVoltage;
            storedEnergy = 0.5 * capacitance * currentVoltage * currentVoltage;
        }
    }

    requirement def EnergyStorageRequirements {
        requirement req1 : 'The system shall charge the capacitor through the charging resistor.';
        requirement req2 : 'The system shall ensure the capacitor voltage does not exceed 16 V.';
        requirement req3 : 'The system shall discharge the capacitor through the load resistor.';
        requirement req4 : 'The system shall calculate stored charge and energy.';
    }

    part def System {
        attribute maxCapVoltage : ElectricPotentialValue = 16 [V];
        attribute sourceVoltage : ElectricPotentialValue = 12 [V];
        attribute chargeResistance : ElectricResistanceValue = 100 [Ohm];
        attribute loadResistance : ElectricResistanceValue = 500 [Ohm];
        attribute capCapacitance : CapacitanceValue = 0.002 [F];
        attribute command : String = "idle";

        part source : VoltageSource {
            nominalVoltage = sourceVoltage;
        }
        part chargeResistor : Resistor {
            resistance = chargeResistance;
        }
        part capacitor : Capacitor {
            capacitance = capCapacitance;
            maxVoltage = maxCapVoltage;
            currentVoltage = 0 [V];
        }
        part loadResistor : Resistor {
            resistance = loadResistance;
        }

        connection sourceToChargeResistor from source.positive to chargeResistor.terminal1;
        connection chargeResistorToCap from chargeResistor.terminal2 to capacitor.positive;
        connection capToLoadResistor from capacitor.positive to loadResistor.terminal1;
        connection loadResistorToCapNeg from loadResistor.terminal2 to capacitor.negative;
        connection capNegToSourceNeg from capacitor.negative to source.negative;

        action updateState {
            if command == "charge" {
                if capacitor.currentVoltage < maxCapVoltage {
                    capacitor.currentVoltage = capacitor.currentVoltage + 0.1 [V];
                } else {
                    command = "idle";
                }
            } else if command == "discharge" {
                if capacitor.currentVoltage > 0 [V] {
                    capacitor.currentVoltage = capacitor.currentVoltage - 0.1 [V];
                } else {
                    command = "idle";
                }
            }
        }

        state machine SystemBehavior {
            state idle;
            state charging;
            state discharging;
            state protected;

            transition from idle to charging when command == "charge";
            transition from charging to discharging when command == "discharge";
            transition from discharging to idle when command == "idle";
            transition from charging to protected when capacitor.currentVoltage >= maxCapVoltage;
            transition from protected to idle when command == "idle";
        }
    }

    requirement energyReq : EnergyStorageRequirements;
    satisfy energyReq by System;
}
