package ResistorSystemModel {

    import ScalarValues::*;
    import SI::*;

    value def ResistanceValue :> Real {
        unit = "ohm";
    }

    value def VoltageValue :> Real {
        unit = "V";
    }

    value def CurrentValue :> Real {
        unit = "A";
    }

    value def PowerValue :> Real {
        unit = "W";
    }

    value def TemperatureValue :> Real {
        unit = "degC";
    }

    value def EnergyValue :> Real {
        unit = "J";
    }

    item def ElectricalChargeFlow {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute power : PowerValue;
    }

    item def ThermalEnergyFlow {
        attribute heatRate : PowerValue;
        attribute temperature : TemperatureValue;
    }

    port def ElectricalTerminal {
        inout item chargeFlow : ElectricalChargeFlow;
        attribute terminalVoltage : VoltageValue;
        attribute terminalCurrent : CurrentValue;
    }

    port def ThermalInterface {
        out item dissipatedHeat : ThermalEnergyFlow;
        attribute surfaceTemperature : TemperatureValue;
    }

    action def LimitCurrent {
        in voltageAcross : VoltageValue;
        in resistance : ResistanceValue;
        out resultingCurrent : CurrentValue;

        constraint ohmsLaw {
            resultingCurrent == voltageAcross / resistance;
        }
    }

    action def DissipateElectricalPower {
        in currentThrough : CurrentValue;
        in resistance : ResistanceValue;
        out dissipatedPower : PowerValue;

        constraint jouleHeating {
            dissipatedPower == currentThrough * currentThrough * resistance;
        }
    }

    action def ProvideVoltageDrop {
        in currentThrough : CurrentValue;
        in resistance : ResistanceValue;
        out voltageDrop : VoltageValue;

        constraint voltageDropLaw {
            voltageDrop == currentThrough * resistance;
        }
    }

    state def ResistorOperatingState {
        entry action initializeThermalState;

        state Off;
        state Conducting;
        state Overloaded;
        state FailedOpen;

        transition initial then Off;

        transition turnOn
            first Off
            accept ElectricalChargeFlow
            then Conducting;

        transition exceedPowerRating
            first Conducting
            if actualPower > ratedPower
            then Overloaded;

        transition coolDown
            first Overloaded
            if actualPower <= ratedPower
            then Conducting;

        transition thermalFailure
            first Overloaded
            if bodyTemperature > maximumBodyTemperature
            then FailedOpen;

        transition removeVoltage
            first Conducting
            if appliedVoltage == 0.0
            then Off;
    }

    part def Resistor {
        attribute nominalResistance : ResistanceValue = 1000.0;
        attribute tolerancePercent : Real = 5.0;
        attribute ratedPower : PowerValue = 0.25;
        attribute maximumVoltage : VoltageValue = 250.0;
        attribute maximumBodyTemperature : TemperatureValue = 155.0;
        attribute ambientTemperature : TemperatureValue = 25.0;
        attribute bodyTemperature : TemperatureValue = 25.0;
        attribute appliedVoltage : VoltageValue;
        attribute actualCurrent : CurrentValue;
        attribute actualPower : PowerValue;

        port terminalA : ElectricalTerminal;
        port terminalB : ElectricalTerminal;
        port thermalSurface : ThermalInterface;

        perform limitCurrent : LimitCurrent {
            in voltageAcross = appliedVoltage;
            in resistance = nominalResistance;
            out resultingCurrent = actualCurrent;
        }

        perform dissipatePower : DissipateElectricalPower {
            in currentThrough = actualCurrent;
            in resistance = nominalResistance;
            out dissipatedPower = actualPower;
        }

        perform provideDrop : ProvideVoltageDrop {
            in currentThrough = actualCurrent;
            in resistance = nominalResistance;
        }

        exhibit operatingState : ResistorOperatingState;

        constraint positiveResistance {
            nominalResistance > 0.0;
        }

        constraint withinVoltageRating {
            abs(appliedVoltage) <= maximumVoltage;
        }

        constraint withinPowerRating {
            actualPower <= ratedPower;
        }
    }

    part def InputVoltageSource {
        attribute sourceVoltage : VoltageValue = 5.0;
        attribute maximumCurrent : CurrentValue = 0.02;

        port positive : ElectricalTerminal;
        port negative : ElectricalTerminal;
    }

    part def LoadNode {
        attribute nodeVoltage : VoltageValue;
        attribute nodeCurrent : CurrentValue;

        port input : ElectricalTerminal;
        port return : ElectricalTerminal;
    }

    part def HeatSinkEnvironment {
        attribute ambientTemperature : TemperatureValue = 25.0;
        attribute thermalCapacity : EnergyValue = 10.0;

        port heatInput : ThermalInterface;
    }

    part def ResistorBasedCurrentLimiterSystem {
        doc
        /* The system uses a resistor as its primary functional element to oppose electrical current, create a predictable voltage drop, and convert excess electrical energy into heat. At a high level, its primary function is to passively limit current in a circuit according to Ohm's law while remaining within voltage, power, and temperature ratings. */

        attribute commandedVoltage : VoltageValue = 5.0;
        attribute limitedCurrent : CurrentValue;
        attribute resistorVoltageDrop : VoltageValue;
        attribute dissipatedPower : PowerValue;

        part source : InputVoltageSource {
            attribute sourceVoltage = commandedVoltage;
        }

        part currentLimitingResistor : Resistor {
            attribute nominalResistance = 1000.0;
            attribute ratedPower = 0.25;
            attribute maximumVoltage = 250.0;
        }

        part protectedLoadNode : LoadNode;

        part environment : HeatSinkEnvironment {
            attribute ambientTemperature = 25.0;
        }

        connect source.positive to currentLimitingResistor.terminalA;
        connect currentLimitingResistor.terminalB to protectedLoadNode.input;
        connect protectedLoadNode.return to source.negative;
        connect currentLimitingResistor.thermalSurface to environment.heatInput;

        bind limitedCurrent = currentLimitingResistor.actualCurrent;
        bind resistorVoltageDrop = currentLimitingResistor.appliedVoltage;
        bind dissipatedPower = currentLimitingResistor.actualPower;

        constraint systemOhmsLaw {
            limitedCurrent == resistorVoltageDrop / currentLimitingResistor.nominalResistance;
        }

        constraint resistorPower {
            dissipatedPower == limitedCurrent * limitedCurrent * currentLimitingResistor.nominalResistance;
        }
    }

    requirement def ReqPrimaryFunction {
        subject system : ResistorBasedCurrentLimiterSystem;

        doc
        /* The resistor-based system shall limit electrical current by providing a resistance-controlled voltage drop between the source and the protected load node. */

        require constraint {
            system.limitedCurrent == system.resistorVoltageDrop / system.currentLimitingResistor.nominalResistance;
        }
    }

    requirement def ReqPassiveOperation {
        subject resistor : Resistor;

        doc
        /* The resistor shall perform current limiting without active control, switching logic, or external power beyond the applied circuit voltage. */

        require constraint {
            resistor.nominalResistance > 0.0;
        }
    }

    requirement def ReqPowerRating {
        subject resistor : Resistor;

        doc
        /* The resistor shall dissipate electrical power without exceeding its rated power during nominal operation. */

        require constraint {
            resistor.actualPower <= resistor.ratedPower;
        }
    }

    requirement def ReqVoltageRating {
        subject resistor : Resistor;

        doc
        /* The resistor shall withstand the applied voltage across its two terminals during nominal operation. */

        require constraint {
            abs(resistor.appliedVoltage) <= resistor.maximumVoltage;
        }
    }

    requirement def ReqThermalProtection {
        subject resistor : Resistor;

        doc
        /* The resistor body temperature shall remain below the maximum specified operating temperature while dissipating heat to the environment. */

        require constraint {
            resistor.bodyTemperature <= resistor.maximumBodyTemperature;
        }
    }

    satisfy ReqPrimaryFunction by ResistorBasedCurrentLimiterSystem;
    satisfy ReqPassiveOperation by Resistor;
    satisfy ReqPowerRating by Resistor;
    satisfy ReqVoltageRating by Resistor;
    satisfy ReqThermalProtection by Resistor;

    part resistorCurrentLimiter : ResistorBasedCurrentLimiterSystem;

}