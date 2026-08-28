package WheatstoneBridge {
    import ScalarValues::*;
    import ISQ::*;
    import ISQElectromagnetism::*;

    // ---- Value types with units ----
    value def VoltageValue :> Real { unit "V"; }
    value def ResistanceValue :> Real { unit "Ω"; }
    value def CurrentValue :> Real { unit "A"; }
    value def RatioValue :> Real { unit "1"; }

    // ---- Item types ----
    item def ElectricalSignal {
        attribute potential : VoltageValue;
        attribute current : CurrentValue;
    }

    // ---- Port definitions ----
    port def ElectricalPort {
        attribute potential : VoltageValue;
        in item inflow : ElectricalSignal;
        out item outflow : ElectricalSignal;
    }

    // ---- Component definitions ----
    part def DCVoltageSource {
        attribute nominalVoltage : VoltageValue;
        attribute maxCurrent : CurrentValue;
        port positiveTerminal : ElectricalPort;
        port negativeTerminal : ElectricalPort;

        action supplyPower {
            out positiveTerminal.outflow : ElectricalSignal;
            out negativeTerminal.outflow : ElectricalSignal;
        }
    }

    part def Resistor {
        attribute resistance : ResistanceValue;
        attribute tolerance : ResistanceValue;
        port terminalA : ElectricalPort;
        port terminalB : ElectricalPort;

        action conduct {
            in terminalA.inflow : ElectricalSignal;
            in terminalB.inflow : ElectricalSignal;
            out terminalA.outflow : ElectricalSignal;
            out terminalB.outflow : ElectricalSignal;
        }
    }

    part def VariableResistor {
        attribute resistance : ResistanceValue;
        attribute minResistance : ResistanceValue;
        attribute maxResistance : ResistanceValue;
        attribute stepResolution : ResistanceValue;
        port terminalA : ElectricalPort;
        port terminalB : ElectricalPort;

        action adjust {
            in targetResistance : ResistanceValue;
            then if (targetResistance >= minResistance && targetResistance <= maxResistance) {
                assign resistance := targetResistance;
            }
        }

        action increment {
            then assign resistance := resistance + stepResolution;
        }

        action decrement {
            then assign resistance := resistance - stepResolution;
        }
    }

    part def Galvanometer {
        attribute reading : VoltageValue;
        attribute sensitivity : VoltageValue;
        attribute zeroThreshold : VoltageValue = 0.001 [V];
        port terminalA : ElectricalPort;
        port terminalB : ElectricalPort;

        action measure {
            in terminalA.inflow : ElectricalSignal;
            in terminalB.inflow : ElectricalSignal;
            then assign reading := terminalA.potential - terminalB.potential;
        }

        action indicateZero {
            when reading >= -zeroThreshold && reading <= zeroThreshold
            then assign reading := 0.0 [V];
        }
    }

    // ---- The Wheatstone Bridge System ----
    part def WheatstoneBridgeSystem {
        attribute supplyVoltage : VoltageValue = 5.0 [V];
        attribute calculatedUnknownResistance : ResistanceValue;
        attribute balanceRatio : RatioValue;

        port positiveRail : ElectricalPort;
        port negativeRail : ElectricalPort;

        part voltageSource : DCVoltageSource {
            attribute nominalVoltage = 5.0 [V];
            attribute maxCurrent = 0.5 [A];
        }

        part referenceResistorR1 : Resistor {
            attribute resistance = 100.0 [Ω];
            attribute tolerance = 0.1 [Ω];
        }

        part referenceResistorR2 : Resistor {
            attribute resistance = 1000.0 [Ω];
            attribute tolerance = 1.0 [Ω];
        }

        part variableResistorR3 : VariableResistor {
            attribute minResistance = 0.0 [Ω];
            attribute maxResistance = 5000.0 [Ω];
            attribute stepResolution = 0.1 [Ω];
            attribute resistance = 1000.0 [Ω];
        }

        part unknownResistorRx : Resistor {
            attribute resistance : ResistanceValue;
            attribute tolerance : ResistanceValue;
        }

        part galvanometer : Galvanometer {
            attribute sensitivity = 0.0001 [V];
            attribute zeroThreshold = 0.001 [V];
            attribute reading : VoltageValue;
        }

        // ---- Connections forming the diamond/bridge topology ----
        connection voltageSource.positiveTerminal to positiveRail;
        connection voltageSource.negativeTerminal to negativeRail;

        // Branch 1: R1 (top) and R2 (bottom) in series from positive to negative rail
        connection positiveRail to referenceResistorR1.terminalA;
        connection referenceResistorR1.terminalB to referenceResistorR2.terminalA;
        connection referenceResistorR2.terminalB to negativeRail;

        // Branch 2: R3 (top) and Rx (bottom) in series from positive to negative rail
        connection positiveRail to variableResistorR3.terminalA;
        connection variableResistorR3.terminalB to unknownResistorRx.terminalA;
        connection unknownResistorRx.terminalB to negativeRail;

        // Galvanometer connected between the two branch midpoints
        connection referenceResistorR1.terminalB to galvanometer.terminalA;
        connection variableResistorR3.terminalB to galvanometer.terminalB;

        // ---- Behaviors ----
        action balanceBridge {
            // Adjust R3 until galvanometer reads zero
            while galvanometer.reading > galvanometer.zeroThreshold {
                perform variableResistorR3.increment;
                perform galvanometer.measure;
            }
            while galvanometer.reading < -galvanometer.zeroThreshold {
                perform variableResistorR3.decrement;
                perform galvanometer.measure;
            }
            perform galvanometer.indicateZero;
        }

        action calculateUnknown {
            // When balanced: Rx = R2 * R3 / R1
            assign balanceRatio := referenceResistorR2.resistance / referenceResistorR1.resistance;
            assign calculatedUnknownResistance := balanceRatio * variableResistorR3.resistance;
            assign unknownResistorRx.resistance := calculatedUnknownResistance;
        }

        action performMeasurement {
            perform voltageSource.supplyPower;
            perform galvanometer.measure;
            perform balanceBridge;
            perform calculateUnknown;
        }

        // ---- State machine ----
        state def BridgeOperatingStates {
            entry; then Initializing;

            state Initializing {
                entry assign galvanometer.reading := supplyVoltage;
                then Unbalanced;
            }

            state Unbalanced {
                entry perform galvanometer.measure;
                do perform voltageSource.supplyPower;
            }

            state Balancing {
                entry perform balanceBridge;
            }

            state Balanced {
                entry perform calculateUnknown;
            }

            state MeasurementComplete;

            transition Unbalanced to Balancing
                when galvanometer.reading != 0.0 [V];

            transition Balancing to Balanced
                when galvanometer.reading == 0.0 [V];

            transition Balancing to Unbalanced
                when variableResistorR3.resistance > variableResistorR3.maxResistance
                or variableResistorR3.resistance < variableResistorR3.minResistance;

            transition Balanced to MeasurementComplete
                when unknownResistorRx.resistance == calculatedUnknownResistance;

            transition MeasurementComplete to Unbalanced
                when galvanometer.reading != 0.0 [V];
        }

        exhibit state BridgeOperatingStates;
    }

    // ---- Requirements ----
    requirement def PrecisionMeasurementRequirement {
        doc "The Wheatstone bridge shall measure an unknown resistance with high precision using a ratio of three known resistances.";
        attribute measurementAccuracy : ResistanceValue = 0.1 [Ω];
        attribute maxMeasurementRange : ResistanceValue = 50000.0 [Ω];
        subject bridge : WheatstoneBridgeSystem;
        require bridge.calculatedUnknownResistance == bridge.unknownResistorRx.resistance
            when bridge.galvanometer.reading == 0.0 [V];
    }

    requirement def BalancedBridgeRequirement {
        doc "The system shall achieve a balanced bridge state when the galvanometer indicates zero voltage difference between the branch midpoints.";
        subject bridge : WheatstoneBridgeSystem;
        require bridge.galvanometer.reading == 0.0 [V];
    }

    requirement def AdjustableRangeRequirement {
        doc "The variable resistor shall be adjustable over a range sufficient to balance the bridge for unknown resistances within the measurement range.";
        subject variableResistor : VariableResistor;
        require variableResistor.maxResistance >= 5000.0 [Ω];
        require variableResistor.minResistance <= 0.0 [Ω];
    }

    requirement def GalvanometerSensitivityRequirement {
        doc "The galvanometer shall be sufficiently sensitive to detect voltage differences smaller than the balance threshold.";
        subject galvanometer : Galvanometer;
        require galvanometer.sensitivity <= 0.0001 [V];
        require galvanometer.zeroThreshold <= 0.001 [V];
    }

    requirement def PowerSupplyRequirement {
        doc "The DC voltage source shall provide a stable voltage to power both branches of the bridge.";
        subject source : DCVoltageSource;
        require source.nominalVoltage >= 1.0 [V];
        require source.nominalVoltage <= 12.0 [V];
    }

    // ---- Verification actions ----
    verification def VerifyBalanceCondition {
        subject bridge : WheatstoneBridgeSystem;
        objective {
            doc "Confirm that when the galvanometer reads zero, the unknown resistance equals the calculated value.";
        }
        action {
            perform bridge.performMeasurement;
            then assert bridge.galvanometer.reading == 0.0 [V];
            then assert bridge.unknownResistorRx.resistance == bridge.calculatedUnknownResistance;
        }
    }

    verification def VerifyMeasurementAccuracy {
        subject bridge : WheatstoneBridgeSystem;
        objective {
            doc "Confirm that the calculated unknown resistance is within the specified accuracy tolerance.";
        }
        action {
            perform bridge.performMeasurement;
            then assert (bridge.unknownResistorRx.resistance - bridge.calculatedUnknownResistance) <= 0.1 [Ω];
        }
    }
}
