package ElectricalPowerTransmissionSystem {

    import ScalarFunctions::*;
    import ISQ::*;
    import ISQElectromagnetism::*;
    import ISQThermodynamics::*;

    // ---- Value types with units ----

    value type ResistivityValue :> Real {
        attribute unit : ElectricResistivityUnit[1] { :> = 'ohm*m'; }
    }

    value type ResistanceValue :> Real {
        attribute unit : ElectricResistanceUnit[1] { :> = 'ohm'; }
    }

    value type VoltageValue :> Real {
        attribute unit : ElectricVoltageUnit[1] { :> = 'V'; }
    }

    value type CurrentValue :> Real {
        attribute unit : ElectricCurrentUnit[1] { :> = 'A'; }
    }

    value type PowerValue :> Real {
        attribute unit : PowerUnit[1] { :> = 'W'; }
    }

    value type LengthValue :> Real {
        attribute unit : LengthUnit[1] { :> = 'm'; }
    }

    value type AreaValue :> Real {
        attribute unit : AreaUnit[1] { :> = 'm^2'; }
    }

    value type TemperatureValue :> Real {
        attribute unit : ThermodynamicTemperatureUnit[1] { :> = 'K'; }
    }

    value type ThicknessValue :> Real {
        attribute unit : LengthUnit[1] { :> = 'm'; }
    }

    value type PercentValue :> Real {
        attribute unit : DimensionlessUnit[1] { :> = '%'; }
    }

    // ---- Item types ----

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute power : PowerValue = voltage * current;
    }

    // ---- Conductor ----

    part def Conductor {
        attribute length : LengthValue = 10 [m];
        attribute crossSectionalArea : AreaValue = 0.000005 [m^2];
        attribute resistivity : ResistivityValue = 1.68e-8 [ohm*m]; // copper

        attribute resistance : ResistanceValue = resistivity * length / crossSectionalArea;

        attribute maxCurrentRating : CurrentValue = 15 [A];

        port in powerIn : ElectricalPower;
        port out powerOut : ElectricalPower;

        attribute voltageDrop : VoltageValue = resistance * powerIn.current;
        attribute powerLoss : PowerValue = resistance * powerIn.current * powerIn.current;
    }

    // ---- Insulation ----

    part def Insulation {
        attribute thickness : ThicknessValue = 0.001 [m];
        attribute maxTemperature : TemperatureValue = 343.15 [K]; // 70 C
        attribute currentTemperature : TemperatureValue = 293.15 [K];
    }

    // ---- Wire ----

    part def Wire {

        part conductor : Conductor {
            attribute ambientTemperature : TemperatureValue = 293.15 [K];
        }

        part insulation : Insulation;

        attribute voltageDropPercent : PercentValue = (conductor.voltageDrop / conductor.powerIn.voltage) * 100;

        attribute currentTemperature : TemperatureValue = insulation.currentTemperature;

        attribute isOverloaded : Boolean = conductor.powerIn.current > conductor.maxCurrentRating;

        attribute isOverheating : Boolean = insulation.currentTemperature > insulation.maxTemperature;

        port in sourceSide : ElectricalPower;
        port out loadSide : ElectricalPower;

        flow from sourceSide to conductor.powerIn;
        flow from conductor.powerOut to loadSide;

        exhibit WireStateMachine;

        state def WireStateMachine {

            attribute temperature : TemperatureValue;

            state idle {
                entry { conductor.powerIn.current = 0 [A]; }
                // No current; wire at ambient temperature
            }

            state conducting {
                // Active transmission; monitor temperature and current
                do {
                    insulation.currentTemperature = conductor.ambientTemperature +
                        (conductor.powerLoss * 0.5 [K/W]);
                }
            }

            state overload {
                // Current exceeds safe rating; potential hazard
                entry { conductor.powerIn.current = 0 [A]; }
            }

            state cooling {
                // Power removed; temperature decreasing toward ambient
                do {
                    insulation.currentTemperature = insulation.currentTemperature - 0.5 [K];
                }
            }

            transition idle_to_conducting
                first idle then conducting
                when sourceSide.current > 0 [A];

            transition conducting_to_overload
                first conducting then overload
                when conductor.powerIn.current > conductor.maxCurrentRating;

            transition conducting_to_cooling
                first conducting then cooling
                when sourceSide.current == 0 [A];

            transition overload_to_cooling
                first overload then cooling
                when sourceSide.current == 0 [A];

            transition cooling_to_idle
                first cooling then idle
                when insulation.currentTemperature <= conductor.ambientTemperature;
        }
    }

    // ---- Power Source ----

    part def PowerSource {
        attribute nominalVoltage : VoltageValue = 120 [V];
        attribute suppliedCurrent : CurrentValue = 10 [A];

        port out sourceOutput : ElectricalPower;

        attribute outputPower : ElectricalPower = ElectricalPower(nominalVoltage, suppliedCurrent);

        flow from outputPower to sourceOutput;
    }

    // ---- Electrical Load ----

    part def ElectricalLoad {
        attribute ratedVoltage : VoltageValue = 120 [V];
        attribute loadResistance : ResistanceValue = 12 [ohm];

        port in loadInput : ElectricalPower;

        attribute consumedCurrent : CurrentValue = loadInput.voltage / loadResistance;
        attribute consumedPower : PowerValue = loadInput.voltage * consumedCurrent;
    }

    // ---- Top-level System ----

    part PowerTransmissionSystem {

        part source : PowerSource;

        part wire : Wire;

        part load : ElectricalLoad;

        connection sourceToWire
            from source.sourceOutput to wire.sourceSide;

        connection wireToLoad
            from wire.loadSide to load.loadInput;

        // ---- Requirements ----

        requirement VoltageDropLimit {
            subject wire;
            doc /* The voltage drop along the wire must not exceed 3% of the source voltage. */
            constraint { wire.voltageDropPercent <= 3 [%] }
        }

        requirement TemperatureSafetyLimit {
            subject wire;
            doc /* The wire temperature must remain below the insulation's maximum rating. */
            constraint { wire.insulation.currentTemperature <= wire.insulation.maxTemperature }
        }

        requirement CurrentSafetyLimit {
            subject wire;
            doc /* The current through the wire must not exceed its maximum safe rating during normal operation. */
            constraint { wire.conductor.powerIn.current <= wire.conductor.maxCurrentRating }
        }

        requirement PowerTransmissionFunction {
            subject source, wire, load;
            doc /* The system shall transmit electrical power from the source to the load. */
            constraint { source.suppliedCurrent > 0 [A] }
            constraint { load.consumedPower > 0 [W] }
        }

        satisfy VoltageDropLimit by wire;
        satisfy TemperatureSafetyLimit by wire;
        satisfy CurrentSafetyLimit by wire;
        satisfy PowerTransmissionFunction by source;
    }
}
