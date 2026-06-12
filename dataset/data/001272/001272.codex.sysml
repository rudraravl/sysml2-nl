package SQUIDSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MagneticFlux {
        attribute value : Real;
        attribute unit : Unit = weber;
    }

    attribute def MagneticField {
        attribute value : Real;
        attribute unit : Unit = tesla;
    }

    attribute def ElectricCurrent {
        attribute value : Real;
        attribute unit : Unit = ampere;
    }

    attribute def ElectricVoltage {
        attribute value : Real;
        attribute unit : Unit = volt;
    }

    attribute def Temperature {
        attribute value : Real;
        attribute unit : Unit = kelvin;
    }

    attribute def Frequency {
        attribute value : Real;
        attribute unit : Unit = hertz;
    }

    attribute def FluxNoiseDensity {
        attribute value : Real;
        attribute unit : Unit = weber / sqrt(hertz);
    }

    item def MagneticFluxSignal {
        attribute flux : MagneticFlux;
        attribute bandwidth : Frequency;
    }

    item def BiasCurrentSignal {
        attribute current : ElectricCurrent;
    }

    item def VoltageSignal {
        attribute voltage : ElectricVoltage;
        attribute bandwidth : Frequency;
    }

    item def ControlCommand {
        attribute targetBias : ElectricCurrent;
        attribute resetRequested : Boolean;
    }

    port def MagneticFluxInputPort {
        in item sensedFlux : MagneticFluxSignal;
    }

    port def BiasCurrentPort {
        in item biasCurrent : BiasCurrentSignal;
    }

    port def VoltageOutputPort {
        out item measuredVoltage : VoltageSignal;
    }

    port def ControlPort {
        in item command : ControlCommand;
    }

    port def ThermalPort {
        in attribute bathTemperature : Temperature;
    }

    part def SuperconductingLoop {
        attribute loopInductance : Real = 120.0e-12;
        attribute loopInductanceUnit : Unit = henry;
        attribute criticalTemperature : Temperature = 9.2 [K];
        attribute operatingTemperature : Temperature;
        attribute enclosedFlux : MagneticFlux;
        attribute isSuperconducting : Boolean;

        port fluxInput : MagneticFluxInputPort;
        port thermalInterface : ThermalPort;
    }

    part def JosephsonJunction {
        attribute criticalCurrent : ElectricCurrent = 8.0e-6 [A];
        attribute normalResistance : Real = 12.0;
        attribute normalResistanceUnit : Unit = ohm;
        attribute capacitance : Real = 0.2e-12;
        attribute capacitanceUnit : Unit = farad;
        attribute phaseDifference : Real;
        attribute junctionVoltage : ElectricVoltage;

        port biasInput : BiasCurrentPort;
        port voltageOutput : VoltageOutputPort;
    }

    part def BiasSource {
        attribute nominalBiasCurrent : ElectricCurrent = 16.0e-6 [A];
        attribute biasStability : Real = 0.002;
        attribute enabled : Boolean;

        port controlInput : ControlPort;
        port biasOutput : BiasCurrentPort;

        action provideBias {
            in item command : ControlCommand;
            out item bias : BiasCurrentSignal;
            first start;
            then setBias;
            then done;

            action setBias {
                bias.current := command.targetBias;
            }
        }
    }

    part def CryogenicStage {
        attribute bathTemperature : Temperature = 4.2 [K];
        attribute temperatureStability : Temperature = 0.001 [K];
        attribute cooldownComplete : Boolean;

        port thermalOutput : ThermalPort;
    }

    part def FluxCouplingCoil {
        attribute mutualInductance : Real = 8.0e-9;
        attribute mutualInductanceUnit : Unit = henry;
        attribute coupledFlux : MagneticFlux;

        port externalFluxInput : MagneticFluxInputPort;
        port loopFluxOutput : MagneticFluxInputPort;
    }

    part def FluxLockedLoopElectronics {
        attribute feedbackGain : Real = 2500.0;
        attribute loopBandwidth : Frequency = 1.0e6 [Hz];
        attribute locked : Boolean;
        attribute outputVoltage : ElectricVoltage;

        port squidVoltageInput : VoltageOutputPort;
        port biasControlOutput : ControlPort;
        port linearizedVoltageOutput : VoltageOutputPort;

        action linearizeResponse {
            in item rawVoltage : VoltageSignal;
            out item linearVoltage : VoltageSignal;
            first sample;
            then compensate;
            then publish;

            action compensate {
                linearVoltage.voltage := rawVoltage.voltage;
                linearVoltage.bandwidth := rawVoltage.bandwidth;
            }
        }
    }

    part def SQUIDMagnetometer {
        attribute fluxQuantum : MagneticFlux = 2.067833848e-15 [Wb];
        attribute fluxToVoltageGain : Real = 75.0e-6;
        attribute fluxToVoltageGainUnit : Unit = volt / weber;
        attribute noiseFloor : FluxNoiseDensity = 1.0e-6 [Wb / sqrt(Hz)];
        attribute measurementBandwidth : Frequency = 500.0e3 [Hz];

        port measuredFluxInput : MagneticFluxInputPort;
        port controlInput : ControlPort;
        port voltageOutput : VoltageOutputPort;

        part cryostat : CryogenicStage;
        part inputCoil : FluxCouplingCoil;
        part loop : SuperconductingLoop;
        part junctionA : JosephsonJunction;
        part junctionB : JosephsonJunction;
        part biasSource : BiasSource;
        part readout : FluxLockedLoopElectronics;

        connect measuredFluxInput to inputCoil.externalFluxInput;
        connect inputCoil.loopFluxOutput to loop.fluxInput;
        connect cryostat.thermalOutput to loop.thermalInterface;
        connect controlInput to biasSource.controlInput;
        connect biasSource.biasOutput to junctionA.biasInput;
        connect biasSource.biasOutput to junctionB.biasInput;
        connect junctionA.voltageOutput to readout.squidVoltageInput;
        connect junctionB.voltageOutput to readout.squidVoltageInput;
        connect readout.linearizedVoltageOutput to voltageOutput;

        action detectMagneticFlux {
            in item incidentFlux : MagneticFluxSignal;
            out item sensedVoltage : VoltageSignal;

            first coupleFlux;
            then biasJunctions;
            then interfereSupercurrents;
            then convertFluxToVoltage;
            then linearizeOutput;

            action coupleFlux {
                loop.enclosedFlux := incidentFlux.flux;
            }

            action biasJunctions {
                biasSource.enabled := true;
            }

            action interfereSupercurrents {
                junctionA.phaseDifference := loop.enclosedFlux.value / fluxQuantum.value;
                junctionB.phaseDifference := -loop.enclosedFlux.value / fluxQuantum.value;
            }

            action convertFluxToVoltage {
                sensedVoltage.voltage.value := loop.enclosedFlux.value * fluxToVoltageGain;
                sensedVoltage.bandwidth := measurementBandwidth;
            }

            action linearizeOutput {
                readout.locked := true;
            }
        }

        state def OperatingState {
            state initial Off;
            state Cooling;
            state Ready;
            state Measuring;
            state Fault;

            transition first Off then Cooling
                accept ControlCommand
                if command.resetRequested == false;

            transition Cooling then Ready
                if cryostat.cooldownComplete == true and loop.operatingTemperature.value < loop.criticalTemperature.value;

            transition Ready then Measuring
                accept MagneticFluxSignal;

            transition Measuring then Ready
                if readout.locked == true;

            transition Measuring then Fault
                if loop.operatingTemperature.value >= loop.criticalTemperature.value;

            transition Fault then Cooling
                accept ControlCommand
                if command.resetRequested == true;
        }
    }

    part def SQUIDBasedMeasurementSystem {
        attribute primaryFunction : String = "Detect extremely small magnetic flux changes by converting flux-dependent quantum interference in a superconducting loop into a measurable voltage signal.";
        attribute minimumDetectableFlux : MagneticFlux = 1.0e-21 [Wb];
        attribute nominalOperatingTemperature : Temperature = 4.2 [K];
        attribute maximumInputFlux : MagneticFlux = 1.0e-12 [Wb];

        port magneticEnvironmentInput : MagneticFluxInputPort;
        port operatorControlInput : ControlPort;
        port measurementVoltageOutput : VoltageOutputPort;

        part magnetometer : SQUIDMagnetometer;

        connect magneticEnvironmentInput to magnetometer.measuredFluxInput;
        connect operatorControlInput to magnetometer.controlInput;
        connect magnetometer.voltageOutput to measurementVoltageOutput;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall use superconducting quantum interference to sense minute magnetic flux variations and provide a proportional electrical output suitable for high-sensitivity magnetometry. */
        subject system : SQUIDBasedMeasurementSystem;
        require constraint {
            system.minimumDetectableFlux.value <= 1.0e-21
        }
    }

    requirement def CryogenicOperationRequirement {
        doc /* The superconducting loop shall operate below its critical temperature during measurement. */
        subject loop : SuperconductingLoop;
        require constraint {
            loop.operatingTemperature.value < loop.criticalTemperature.value
        }
    }

    requirement def BandwidthRequirement {
        doc /* The measurement chain shall support magnetic flux sensing over at least 500 kHz of bandwidth. */
        subject squid : SQUIDMagnetometer;
        require constraint {
            squid.measurementBandwidth.value >= 500000.0
        }
    }

    requirement def FluxLockedOutputRequirement {
        doc /* The readout electronics shall maintain a flux-locked condition before reporting the linearized voltage output. */
        subject squid : SQUIDMagnetometer;
        require constraint {
            squid.readout.locked == true
        }
    }

    satisfy PrimaryFunctionRequirement by SQUIDBasedMeasurementSystem;
    satisfy CryogenicOperationRequirement by SuperconductingLoop;
    satisfy BandwidthRequirement by SQUIDMagnetometer;
    satisfy FluxLockedOutputRequirement by FluxLockedLoopElectronics;

}