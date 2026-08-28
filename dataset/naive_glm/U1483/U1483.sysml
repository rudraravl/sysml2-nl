package SimpleResistorCircuit {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    value type Voltage {
        :>> value : Real;
        unit volt [V];
    }

    value type Current {
        :>> value : Real;
        unit ampere [A];
    }

    value type Resistance {
        :>> value : Real;
        unit ohm [Ohm];
    }

    value type Power {
        :>> value : Real;
        unit watt [W];
    }

    value type Temperature {
        :>> value : Real;
        unit kelvin [K];
    }

    item type ElectricCharge;

    port def ElectricalPort {
        out voltage : Voltage;
        in current : Current;
        item flow : ElectricCharge;
    }

    requirement def SafeOperationRequirement {
        doc /*
         * The resistor shall operate without exceeding its maximum
         * power dissipation or maximum temperature ratings.
         */
        subject resistor : Resistor;
        requirement {
            constraint { resistor.dissipatedPower <= resistor.maxPower }
        }
        requirement {
            constraint { resistor.temperature <= resistor.maxTemp }
        }
    }

    requirement def CurrentLimitingRequirement {
        doc /*
         * The resistor shall limit the current flowing through the
         * circuit according to Ohm's Law: I = V / R.
         */
        subject resistor : Resistor;
        subject source : VoltageSource;
        requirement {
            constraint { resistor.current == source.nominalVoltage / resistor.resistance }
        }
    }

    part def VoltageSource {
        attribute nominalVoltage : Voltage = 12.0 [V];
        attribute internalResistance : Resistance = 0.01 [Ohm];
        port positiveTerminal : ElectricalPort;
        port negativeTerminal : ElectricalPort;

        action def GenerateVoltage {
            out v : Voltage = nominalVoltage;
        }

        perform action generate : GenerateVoltage {
            assign positiveTerminal.voltage := generate.v;
            assign negativeTerminal.voltage := 0.0 [V];
        }
    }

    part def Ground {
        attribute referenceVoltage : Voltage = 0.0 [V];
        port groundTerminal : ElectricalPort;

        action def EstablishReference {
            out v : Voltage = referenceVoltage;
        }

        perform action establish : EstablishReference {
            assign groundTerminal.voltage := establish.v;
        }
    }

    part def Resistor {
        attribute resistance : Resistance = 100.0 [Ohm];
        attribute maxPower : Power = 0.25 [W];
        attribute maxTemp : Temperature = 350.0 [K];
        attribute ambientTemp : Temperature = 293.15 [K];
        attribute thermalCoefficient : Real = 0.005;

        attribute voltageAcross : Voltage = 0.0 [V];
        attribute current : Current = 0.0 [A];
        attribute dissipatedPower : Power = 0.0 [W];
        attribute temperature : Temperature = ambientTemp;

        port terminal1 : ElectricalPort;
        port terminal2 : ElectricalPort;

        action def ComputeElectrical {
            in v : Voltage;
            in r : Resistance;
            out i : Current;
            out p : Power;
        }

        action def UpdateThermal {
            in p : Power;
            in t0 : Temperature;
            in coeff : Real;
            out t1 : Temperature;
        }

        perform action compute : ComputeElectrical {
            in v = voltageAcross;
            in r = resistance;
            assign current := v / r;
            assign dissipatedPower := v * current;
        }

        perform action thermal : UpdateThermal {
            in p = dissipatedPower;
            in t0 = temperature;
            in coeff = thermalCoefficient;
            assign temperature := t0 + (p * coeff);
        }

        state machine def ResistorLifecycle {
            entry action initialize {
                assign temperature := ambientTemp;
                assign current := 0.0 [A];
                assign dissipatedPower := 0.0 [W];
            }

            state idle {
                entry { /* no power applied */ }
                do action monitorIdle {
                    assign voltageAcross := 0.0 [V];
                }
            }

            state conducting {
                entry { /* energized, current flows */ }
                do action applyOhmsLaw {
                    assign current := voltageAcross / resistance;
                    assign dissipatedPower := voltageAcross * current;
                }
                do action updateTemperature {
                    assign temperature := temperature + (dissipatedPower * thermalCoefficient);
                }
            }

            state heating {
                entry { /* temperature approaching limit */ }
                do action continueConduction {
                    assign current := voltageAcross / resistance;
                    assign dissipatedPower := voltageAcross * current;
                }
                do action raiseTemperature {
                    assign temperature := temperature + (dissipatedPower * thermalCoefficient);
                }
            }

            state overheated {
                entry { /* limit exceeded, potential damage */ }
                do action shutdown {
                    assign current := 0.0 [A];
                    assign dissipatedPower := 0.0 [W];
                }
            }

            transition from idle to conducting
                when voltageAcross > 0.0 [V];

            transition from conducting to heating
                when temperature >= (maxTemp - 20.0 [K]);

            transition from heating to conducting
                when temperature < (maxTemp - 20.0 [K]) and dissipatedPower <= maxPower;

            transition from heating to overheated
                when temperature > maxTemp or dissipatedPower > maxPower;

            transition from conducting to overheated
                when temperature > maxTemp or dissipatedPower > maxPower;

            transition from overheated to idle
                when voltageAcross == 0.0 [V] and temperature <= ambientTemp + 5.0 [K];
        }

        perform state machine lifecycle : ResistorLifecycle;

        satisfy SafeOperationRequirement {
            subject resistor = Resistor::this;
        }

        satisfy CurrentLimitingRequirement {
            subject resistor = Resistor::this;
        }
    }

    part circuit :> SimpleResistorCircuit {
        part source : VoltageSource {
            attribute nominalVoltage : Voltage = 9.0 [V];
        }

        part resistor : Resistor {
            attribute resistance : Resistance = 220.0 [Ohm];
            attribute maxPower : Power = 0.5 [W];
            attribute maxTemp : Temperature = 358.15 [K];
        }

        part groundRef : Ground;

        connect source.positiveTerminal to resistor.terminal1;
        connect source.negativeTerminal to groundRef.groundTerminal;
        connect resistor.terminal2 to groundRef.groundTerminal;

        flow of ElectricCharge
            from source.positiveTerminal.flow
            to resistor.terminal1.flow;

        flow of ElectricCharge
            from resistor.terminal2.flow
            to groundRef.groundTerminal.flow;

        flow of ElectricCharge
            from groundRef.groundTerminal.flow
            to source.negativeTerminal.flow;

        requirement circuitSafeOperation : SafeOperationRequirement {
            subject resistor = circuit.resistor;
        }

        requirement circuitCurrentLimiting : CurrentLimitingRequirement {
            subject resistor = circuit.resistor;
            subject source = circuit.source;
        }
    }
}
