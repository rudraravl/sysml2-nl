package RedoxElectrodeSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ElectricPotential {
        attribute value : Real;
        attribute unit : String = "V";
    }

    attribute def ElectricCurrent {
        attribute value : Real;
        attribute unit : String = "A";
    }

    attribute def Concentration {
        attribute value : Real;
        attribute unit : String = "mol/m^3";
    }

    attribute def Temperature {
        attribute value : Real;
        attribute unit : String = "K";
    }

    attribute def Area {
        attribute value : Real;
        attribute unit : String = "m^2";
    }

    attribute def ChargeTransferRate {
        attribute value : Real;
        attribute unit : String = "mol/(m^2*s)";
    }

    attribute def Resistance {
        attribute value : Real;
        attribute unit : String = "ohm";
    }

    attribute def TimeDuration {
        attribute value : Real;
        attribute unit : String = "s";
    }

    item def Electron {
        attribute charge : Real = -1.602176634e-19;
        attribute chargeUnit : String = "C";
    }

    item def Ion {
        attribute chargeNumber : Integer;
        attribute concentration : Concentration;
    }

    item def OxidizedSpecies :> Ion {
        attribute chargeNumber : Integer = 3;
    }

    item def ReducedSpecies :> Ion {
        attribute chargeNumber : Integer = 2;
    }

    item def ElectrolyteSolution {
        attribute oxidizedConcentration : Concentration;
        attribute reducedConcentration : Concentration;
        attribute ionicStrength : Concentration;
        attribute temperature : Temperature;
        attribute pH : Real;
    }

    item def ElectricalSignal {
        attribute potential : ElectricPotential;
        attribute current : ElectricCurrent;
    }

    port def ElectronConductorPort {
        out item electrons : Electron;
        in item signal : ElectricalSignal;
    }

    port def IonicInterfacePort {
        inout item solution : ElectrolyteSolution;
        in item oxidizedSpecies : OxidizedSpecies;
        out item reducedSpecies : ReducedSpecies;
    }

    port def MeasurementPort {
        out item measuredSignal : ElectricalSignal;
    }

    port def FluidPort {
        inout item solution : ElectrolyteSolution;
    }

    action def ExchangeElectrons {
        in item oxidized : OxidizedSpecies;
        out item reduced : ReducedSpecies;
        out item electronFlow : Electron;
        attribute rate : ChargeTransferRate;
    }

    action def EstablishInterfacialPotential {
        in item solution : ElectrolyteSolution;
        out item signal : ElectricalSignal;
        attribute formalPotential : ElectricPotential;
        attribute nernstPotential : ElectricPotential;
    }

    action def MeasureElectrodePotential {
        in item electrodeSignal : ElectricalSignal;
        out item measuredSignal : ElectricalSignal;
        attribute measurementInterval : TimeDuration;
    }

    action def StabilizeSurfaceChemistry {
        inout item solution : ElectrolyteSolution;
        attribute equilibrationTime : TimeDuration;
    }

    state def RedoxElectrodeOperatingState {
        entry action StabilizeSurfaceChemistry;

        state Initializing;
        state Equilibrating;
        state Sensing;
        state Polarized;
        state Faulted;

        transition first Initializing then Equilibrating
            accept after 5.0;

        transition Equilibrating then Sensing
            accept when oxidizedReducedRatioStable;

        transition Sensing then Polarized
            accept when absoluteCurrentAboveLimit;

        transition Polarized then Sensing
            accept when currentReturnedWithinLimit;

        transition Sensing then Faulted
            accept when referenceOpenCircuitDetected;

        transition Polarized then Faulted
            accept when surfacePassivationDetected;
    }

    part def ConductiveSubstrate {
        attribute material : String = "platinum";
        attribute exposedArea : Area;
        attribute ohmicResistance : Resistance;
        port electrical : ElectronConductorPort;
    }

    part def RedoxActiveSurface {
        attribute formalPotential : ElectricPotential;
        attribute exchangeCurrentDensity : Real;
        attribute exchangeCurrentDensityUnit : String = "A/m^2";
        attribute surfaceCoverage : Real;
        port ionic : IonicInterfacePort;
        port electronic : ElectronConductorPort;

        perform action electronExchange : ExchangeElectrons;
        perform action potentialFormation : EstablishInterfacialPotential;
    }

    part def ElectrolyteBoundaryLayer {
        attribute thickness : Real;
        attribute thicknessUnit : String = "m";
        attribute diffusionCoefficientOx : Real;
        attribute diffusionCoefficientRed : Real;
        attribute diffusionCoefficientUnit : String = "m^2/s";
        item solution : ElectrolyteSolution;
        port bulkFluid : FluidPort;
        port surfaceInterface : IonicInterfacePort;
    }

    part def ReferenceMeasurementCircuit {
        attribute inputImpedance : Resistance;
        attribute samplingPeriod : TimeDuration;
        port input : MeasurementPort;
        port output : MeasurementPort;

        perform action measurePotential : MeasureElectrodePotential;
    }

    part def RedoxElectrode {
        attribute nominalFormalPotential : ElectricPotential;
        attribute operatingTemperature : Temperature;
        attribute maximumSafeCurrent : ElectricCurrent;
        attribute responseTime : TimeDuration;

        part substrate : ConductiveSubstrate {
            attribute material = "glassy carbon";
            attribute exposedArea {
                value = 7.85e-5;
                unit = "m^2";
            }
            attribute ohmicResistance {
                value = 0.2;
                unit = "ohm";
            }
        }

        part activeSurface : RedoxActiveSurface {
            attribute formalPotential {
                value = 0.771;
                unit = "V";
            }
            attribute exchangeCurrentDensity = 1.5;
            attribute surfaceCoverage = 0.92;
        }

        part boundaryLayer : ElectrolyteBoundaryLayer {
            attribute thickness = 1.0e-4;
            attribute diffusionCoefficientOx = 7.2e-10;
            attribute diffusionCoefficientRed = 6.8e-10;
        }

        port electricalTerminal : ElectronConductorPort;
        port solutionInterface : FluidPort;
        port measuredPotential : MeasurementPort;

        connect substrate.electrical to activeSurface.electronic;
        connect activeSurface.ionic to boundaryLayer.surfaceInterface;
        connect boundaryLayer.bulkFluid to solutionInterface;
        connect substrate.electrical to electricalTerminal;

        exhibit state operatingState : RedoxElectrodeOperatingState;

        perform action primaryFunction : EstablishInterfacialPotential;
    }

    part def RedoxElectrodeMeasurementSystem {
        attribute systemPurpose : String = "Convert the oxidation-reduction state of an electrolyte into a stable measurable electrical potential.";

        part electrode : RedoxElectrode {
            attribute nominalFormalPotential {
                value = 0.771;
                unit = "V";
            }
            attribute operatingTemperature {
                value = 298.15;
                unit = "K";
            }
            attribute maximumSafeCurrent {
                value = 1.0e-3;
                unit = "A";
            }
            attribute responseTime {
                value = 2.0;
                unit = "s";
            }
        }

        part measurementCircuit : ReferenceMeasurementCircuit {
            attribute inputImpedance {
                value = 1.0e9;
                unit = "ohm";
            }
            attribute samplingPeriod {
                value = 0.1;
                unit = "s";
            }
        }

        item sampleElectrolyte : ElectrolyteSolution {
            attribute oxidizedConcentration {
                value = 10.0;
                unit = "mol/m^3";
            }
            attribute reducedConcentration {
                value = 5.0;
                unit = "mol/m^3";
            }
            attribute ionicStrength {
                value = 100.0;
                unit = "mol/m^3";
            }
            attribute temperature {
                value = 298.15;
                unit = "K";
            }
            attribute pH = 7.0;
        }

        port processFluidConnection : FluidPort;
        port electricalReadout : MeasurementPort;

        connect processFluidConnection to electrode.solutionInterface;
        connect electrode.measuredPotential to measurementCircuit.input;
        connect measurementCircuit.output to electricalReadout;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : RedoxElectrodeMeasurementSystem;

        doc /* The system shall use a redox electrode to establish an interfacial electrical potential that represents the ratio of oxidized and reduced chemical species in the contacting electrolyte. */

        require constraint {
            system.electrode.responseTime.value <= 5.0
        }

        require constraint {
            system.electrode.maximumSafeCurrent.value <= 1.0e-3
        }
    }

    requirement def HighImpedanceMeasurementRequirement {
        subject circuit : ReferenceMeasurementCircuit;

        doc /* The measurement circuit shall sense electrode potential with sufficiently high input impedance so that the redox equilibrium is not significantly disturbed. */

        require constraint {
            circuit.inputImpedance.value >= 1.0e8
        }
    }

    requirement def StableElectrodeInterfaceRequirement {
        subject electrode : RedoxElectrode;

        doc /* The active surface shall maintain a reproducible redox-active interface in contact with the electrolyte during sensing operation. */

        require constraint {
            electrode.activeSurface.surfaceCoverage >= 0.85
        }
    }

    requirement def OperatingTemperatureRequirement {
        subject electrode : RedoxElectrode;

        doc /* The electrode shall operate at normal laboratory temperature for aqueous redox measurements. */

        require constraint {
            electrode.operatingTemperature.value >= 293.15 and electrode.operatingTemperature.value <= 303.15
        }
    }

    part redoxElectrodeSystem : RedoxElectrodeMeasurementSystem;

    satisfy PrimaryFunctionRequirement by redoxElectrodeSystem;
    satisfy HighImpedanceMeasurementRequirement by redoxElectrodeSystem.measurementCircuit;
    satisfy StableElectrodeInterfaceRequirement by redoxElectrodeSystem.electrode;
    satisfy OperatingTemperatureRequirement by redoxElectrodeSystem.electrode;
}