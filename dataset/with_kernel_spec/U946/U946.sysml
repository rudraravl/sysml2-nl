package WheatstoneBridge {
    private import ISQ::*;
    private import ISQBase::*;
    private import NumericalFunctions::*;

    item def ElectricCurrent;

    port def ElectricalPort {
        attribute voltage : Voltage;
        in item current : ElectricCurrent;
    }

    part def DCVoltageSource {
        attribute nominalVoltage : Voltage;
        port positiveTerminal : ElectricalPort;
        port negativeTerminal : ElectricalPort;
    }

    part def Resistor {
        attribute resistance : Resistance;
        port terminalA : ElectricalPort;
        port terminalB : ElectricalPort;
    }

    part def VariableResistor :> Resistor {
        attribute minResistance : Resistance;
        attribute maxResistance : Resistance;
        attribute currentResistance : Resistance;
    }

    part def UnknownResistor :> Resistor {
        attribute measuredResistance : Resistance;
    }

    part def Galvanometer {
        attribute reading : Voltage;
        port terminalA : ElectricalPort;
        port terminalB : ElectricalPort;
    }

    calc def BalanceCalculation {
        in r1 : Resistance;
        in r2 : Resistance;
        in r3 : Resistance;
        return rx : Resistance = r2 * r3 / r1;
    }

    action def AdjustVariableResistor {
        in galvanometerReading : Voltage;
        in currentSetting : Resistance;
        out newSetting : Resistance;
    }

    part def WheatstoneBridgeSystem {
        part voltageSource : DCVoltageSource;
        part knownResistor1 : Resistor;
        part knownResistor2 : Resistor;
        part variableResistor : VariableResistor;
        part unknownResistor : UnknownResistor;
        part galvanometer : Galvanometer;

        connect voltageSource.positiveTerminal to knownResistor1.terminalA;
        connect voltageSource.positiveTerminal to variableResistor.terminalA;
        connect knownResistor1.terminalB to knownResistor2.terminalA;
        connect variableResistor.terminalB to unknownResistor.terminalA;
        connect knownResistor2.terminalB to voltageSource.negativeTerminal;
        connect unknownResistor.terminalB to voltageSource.negativeTerminal;
        connect knownResistor1.terminalB to galvanometer.terminalA;
        connect variableResistor.terminalB to galvanometer.terminalB;

        calc balanceCalc : BalanceCalculation {
            in r1 = knownResistor1.resistance;
            in r2 = knownResistor2.resistance;
            in r3 = variableResistor.currentResistance;
            return rx;
        }

        attribute unknownResistance : Resistance = balanceCalc.rx;

        state machine bridgeOperation {
            state Unbalanced;
            state Balancing;
            state Balanced;

            transition from Unbalanced to Balancing when galvanometer.reading != 0 [V];
            transition from Balancing to Balanced when galvanometer.reading == 0 [V];
            transition from Balanced to Unbalanced when galvanometer.reading != 0 [V];
        }
    }

    requirement def BalanceRequirement {
        text "When the bridge is balanced, the galvanometer reading shall be zero volts.";
        attribute galvanometerReading : Voltage;
        require galvanometerReading == 0 [V];
    }

    requirement def PrecisionRequirement {
        text "The unknown resistance shall be calculated with a tolerance of 0.001 Ohm or better.";
        attribute tolerance : Resistance;
        require tolerance <= 0.001 [Ohm];
    }

    part bridgeSystem : WheatstoneBridgeSystem {
        part voltageSource : DCVoltageSource {
            attribute nominalVoltage = 12 [V];
        }
        part knownResistor1 : Resistor {
            attribute resistance = 100 [Ohm];
        }
        part knownResistor2 : Resistor {
            attribute resistance = 100 [Ohm];
        }
        part variableResistor : VariableResistor {
            attribute minResistance = 0 [Ohm];
            attribute maxResistance = 1000 [Ohm];
            attribute currentResistance = 100 [Ohm];
        }
    }
}
