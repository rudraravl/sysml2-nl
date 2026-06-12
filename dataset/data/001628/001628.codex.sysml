package WireBasedPowerLinkModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Voltage {
        :> scalarValues::Real;
        unit = V;
    }

    attribute def Current {
        :> scalarValues::Real;
        unit = A;
    }

    attribute def Resistance {
        :> scalarValues::Real;
        unit = Ohm;
    }

    attribute def Power {
        :> scalarValues::Real;
        unit = W;
    }

    attribute def Temperature {
        :> scalarValues::Real;
        unit = K;
    }

    attribute def Length {
        :> scalarValues::Real;
        unit = m;
    }

    item def ElectricChargeFlow {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def ThermalEnergyFlow {
        attribute conductorTemperature : Temperature;
        attribute heatDissipation : Power;
    }

    port def ElectricalPort {
        inout flow : ElectricChargeFlow;
    }

    port def ThermalPort {
        out heat : ThermalEnergyFlow;
    }

    part def Wire {
        attribute length : Length;
        attribute resistance : Resistance;
        attribute maxCurrent : Current;
        attribute ratedVoltage : Voltage;
        attribute operatingTemperature : Temperature;

        port endA : ElectricalPort;
        port endB : ElectricalPort;
        port thermalSurface : ThermalPort;

        constraint ohmicBehavior {
            in voltageDrop : Voltage;
            in currentThroughWire : Current;
            in wireResistance : Resistance;
            voltageDrop == currentThroughWire * wireResistance;
        }

        constraint jouleHeating {
            in currentThroughWire : Current;
            in wireResistance : Resistance;
            out generatedHeat : Power;
            generatedHeat == currentThroughWire * currentThroughWire * wireResistance;
        }

        perform action conductElectricity {
            in inputFlow : ElectricChargeFlow;
            out outputFlow : ElectricChargeFlow;

            outputFlow.current = inputFlow.current;
            outputFlow.voltage = inputFlow.voltage - inputFlow.current * resistance;
            outputFlow.power = outputFlow.voltage * outputFlow.current;
        }
    }

    part def PowerSource {
        attribute nominalVoltage : Voltage;
        attribute availableCurrent : Current;

        port supply : ElectricalPort;

        perform action energize {
            out suppliedFlow : ElectricChargeFlow;
            suppliedFlow.voltage = nominalVoltage;
            suppliedFlow.current <= availableCurrent;
            suppliedFlow.power = suppliedFlow.voltage * suppliedFlow.current;
        }
    }

    part def ElectricalLoad {
        attribute requiredVoltage : Voltage;
        attribute operatingCurrent : Current;
        attribute consumedPower : Power;

        port input : ElectricalPort;

        perform action consumePower {
            in receivedFlow : ElectricChargeFlow;
            consumedPower = receivedFlow.voltage * receivedFlow.current;
        }
    }

    part def Insulation {
        attribute dielectricRating : Voltage;
        attribute maxSurfaceTemperature : Temperature;

        port thermalInput : ThermalPort;
    }

    part def WireBasedSystem {
        attribute systemVoltage : Voltage = 24 [V];
        attribute systemCurrent : Current = 5 [A];
        attribute deliveredPower : Power;

        part source : PowerSource {
            attribute nominalVoltage = 24 [V];
            attribute availableCurrent = 10 [A];
        }

        part primaryWire : Wire {
            attribute length = 2.5 [m];
            attribute resistance = 0.08 [Ohm];
            attribute maxCurrent = 8 [A];
            attribute ratedVoltage = 60 [V];
            attribute operatingTemperature = 293.15 [K];
        }

        part insulation : Insulation {
            attribute dielectricRating = 300 [V];
            attribute maxSurfaceTemperature = 358.15 [K];
        }

        part load : ElectricalLoad {
            attribute requiredVoltage = 23.0 [V];
            attribute operatingCurrent = 5 [A];
        }

        connect source.supply to primaryWire.endA;
        connect primaryWire.endB to load.input;
        connect primaryWire.thermalSurface to insulation.thermalInput;

        perform action transferElectricalPower {
            first source.energize;
            then primaryWire.conductElectricity;
            then load.consumePower;
            deliveredPower = load.consumedPower;
        }

        state def OperatingStateMachine {
            state off;
            state energizing;
            state conducting;
            state overheated;
            state faultIsolated;

            entry action initialize {
                deliveredPower = 0 [W];
            }

            transition first off then energizing
                accept PowerCommand
                do transferElectricalPower;

            transition energizing then conducting
                if primaryWire.endA.flow.voltage > 0 [V];

            transition conducting then overheated
                if primaryWire.operatingTemperature > insulation.maxSurfaceTemperature;

            transition conducting then faultIsolated
                if primaryWire.endA.flow.current > primaryWire.maxCurrent;

            transition overheated then faultIsolated;

            transition faultIsolated then off
                accept ResetCommand;
        }
    }

    action def TransferPowerHighLevel {
        in sourceVoltage : Voltage;
        in loadCurrent : Current;
        out deliveredPower : Power;

        deliveredPower = sourceVoltage * loadCurrent;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : WireBasedSystem;

        doc /* The system shall use a wire as the primary physical medium to transfer electrical power from a source to a load at a high level. */

        require constraint {
            system.deliveredPower > 0 [W]
        }
    }

    requirement def ConductiveContinuityRequirement {
        subject wire : Wire;

        doc /* The wire shall provide conductive continuity between its two electrical ports. */

        require constraint {
            wire.endA.flow.current == wire.endB.flow.current
        }
    }

    requirement def VoltageRatingRequirement {
        subject wire : Wire;

        doc /* The wire shall withstand the nominal system voltage without exceeding its rated voltage. */

        require constraint {
            wire.endA.flow.voltage <= wire.ratedVoltage
        }
    }

    requirement def CurrentLimitRequirement {
        subject wire : Wire;

        doc /* The wire shall operate without exceeding its maximum current rating. */

        require constraint {
            wire.endA.flow.current <= wire.maxCurrent
        }
    }

    requirement def InsulationProtectionRequirement {
        subject insulation : Insulation;
        subject wire : Wire;

        doc /* The insulation shall electrically protect the wire while remaining below its maximum surface temperature. */

        require constraint {
            wire.operatingTemperature <= insulation.maxSurfaceTemperature
        }
    }

    satisfy PrimaryFunctionRequirement by WireBasedSystem::transferElectricalPower;
    satisfy ConductiveContinuityRequirement by Wire;
    satisfy VoltageRatingRequirement by WireBasedSystem::primaryWire;
    satisfy CurrentLimitRequirement by WireBasedSystem::primaryWire;
    satisfy InsulationProtectionRequirement by WireBasedSystem::insulation;

    part wireBasedPowerLink : WireBasedSystem;

}