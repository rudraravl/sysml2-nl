package MHD_Sensing_Unit {

    import ScalarValues::*;
    import ISQ::*;
    import ISQBaseQuantities::*;

    // ---- Value types with units ----
    value type Voltage :> Real {
        unit volt;
    }
    value type Current :> Real {
        unit ampere;
    }
    value type MagneticFluxDensity :> Real {
        unit tesla;
    }
    value type Velocity :> Real {
        unit "m/s";
    }
    value type VolumetricFlowRate :> Real {
        unit "m^3/s";
    }
    value type Length :> Real {
        unit m;
    }
    value type Diameter :> Real {
        unit m;
    }
    value type Area :> Real {
        unit "m^2";
    }
    value type Frequency :> Real {
        unit Hz;
    }
    value type Temperature :> Real {
        unit degC;
    }
    value type Conductivity :> Real {
        unit "S/m";
    }
    value type Dimensionless :> Real;

    // ---- Item types ----
    item def ConductiveFluid {
        attribute conductivity : Conductivity;
        attribute temperature : Temperature;
        attribute density : Real;
    }

    item def RawVoltageSignal {
        attribute magnitude : Voltage;
        attribute noiseFloor : Voltage;
    }

    item def ConditionedSignal {
        attribute magnitude : Voltage;
        attribute stability : Dimensionless;
    }

    item def FlowMeasurement {
        attribute averageVelocity : Velocity;
        attribute volumetricFlowRate : VolumetricFlowRate;
        attribute timestamp : String;
        attribute quality : Dimensionless;
    }

    item def MeasurementCommand {
        attribute commandKind : String;
    }

    item def DiagnosticResult {
        attribute fieldCoilStatus : String;
        attribute electrodeStatus : String;
        attribute signalChainStatus : String;
        attribute passed : Boolean;
    }

    // ---- Port definitions ----
    port def FluidPort {
        in item fluid : ConductiveFluid;
    }

    port def ElectrodeSignalPort {
        out item rawSignal : RawVoltageSignal;
    }

    port def ConditionedSignalPort {
        out item conditioned : ConditionedSignal;
    }

    port def FieldControlPort {
        in item excitation : Current;
    }

    port def DataOutputPort {
        out item measurement : FlowMeasurement;
        out item diagnostic : DiagnosticResult;
    }

    port def CommandPort {
        in item command : MeasurementCommand;
    }

    // ---- Sub-component definitions ----

    part def PTFELiner {
        attribute material : String = "PTFE";
        attribute thickness : Length;
        attribute isNonConductive : Boolean = true;
    }

    part def MeasurementTube {
        attribute material : String = "StainlessSteel";
        attribute innerDiameter : Diameter;
        attribute length : Length;
        attribute crossSectionalArea : Area;
        part liner : PTFELiner;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def Electromagnet {
        attribute coilResistance : Real;
        attribute nominalFieldStrength : MagneticFluxDensity;
        attribute excitationFrequency : Frequency;
        port fieldControl : FieldControlPort;
        action def generateField(in current : Current; out field : MagneticFluxDensity);
    }

    part def Electrode {
        attribute material : String = "HastelloyC";
        attribute position : String;
        attribute contactDiameter : Length;
        port signalOut : ElectrodeSignalPort;
        action def senseVoltage(in field : MagneticFluxDensity; in velocity : Velocity; out signal : RawVoltageSignal);
    }

    part def SignalConditioningModule {
        attribute gain : Real;
        attribute bandwidth : Frequency;
        attribute filterType : String = "BandPass";
        port signalIn : ElectrodeSignalPort;
        port signalOut : ConditionedSignalPort;
        action def amplify(in raw : RawVoltageSignal; out amplified : RawVoltageSignal);
        action def filter(in amplified : RawVoltageSignal; out clean : ConditionedSignal);
        action def condition(in raw : RawVoltageSignal; out clean : ConditionedSignal) {
            perform amplify(raw, amplified);
            perform filter(amplified, clean);
        }
    }

    part def InternalProcessor {
        attribute clockFrequency : Frequency;
        attribute calibrationFactor : Dimensionless;
        port signalIn : ConditionedSignalPort;
        port dataOut : DataOutputPort;
        port commandIn : CommandPort;
        action def computeVelocity(in signal : ConditionedSignal; in field : MagneticFluxDensity; in diameter : Diameter; out velocity : Velocity) {
            // E = B * D * v  =>  v = E / (B * D)
        }
        action def computeFlowRate(in velocity : Velocity; in area : Area; out flowRate : VolumetricFlowRate) {
            // Q = v * A
        }
        action def assembleMeasurement(in velocity : Velocity; in flowRate : VolumetricFlowRate; out measurement : FlowMeasurement);
        action def process(in signal : ConditionedSignal; in field : MagneticFluxDensity; in diameter : Diameter; in area : Area; out measurement : FlowMeasurement) {
            perform computeVelocity(signal, field, diameter, velocity);
            perform computeFlowRate(velocity, area, flowRate);
            perform assembleMeasurement(velocity, flowRate, measurement);
        }
    }

    part def PowerSupply {
        attribute inputVoltage : Voltage;
        attribute outputVoltage : Voltage;
        attribute outputCurrent : Current;
        action def powerOn();
        action def powerOff();
    }

    // ---- Top-level MHD Sensing Unit ----
    part def MHDSensingUnit {

        attribute manufacturer : String;
        attribute modelNumber : String;
        attribute tag : String;
        attribute nominalDiameter : Diameter;
        attribute fullScaleFlowRate : VolumetricFlowRate;
        attribute accuracyClass : Dimensionless;

        port processInlet : FluidPort;
        port processOutlet : FluidPort;
        port commandInput : CommandPort;
        port dataOutput : DataOutputPort;

        part measurementTube : MeasurementTube {
            rebind innerDiameter = nominalDiameter;
        }
        part liner : PTFELiner;
        part electromagnetA : Electromagnet;
        part electromagnetB : Electromagnet;
        part electrodeA : Electrode;
        part electrodeB : Electrode;
        part signalConditioning : SignalConditioningModule;
        part processor : InternalProcessor;
        part powerSupply : PowerSupply;

        // Internal connections
        connection fluidPath connect measurementTube.fluidIn to measurementTube.fluidOut;
        connection processInletConnect connect processInlet to measurementTube.fluidIn;
        connection processOutletConnect connect measurementTube.fluidOut to processOutlet;

        connection fieldExcitationA connect powerSupply.outputCurrent to electromagnetA.fieldControl.excitation;
        connection fieldExcitationB connect powerSupply.outputCurrent to electromagnetB.fieldControl.excitation;

        connection electrodeSignalA connect electrodeA.signalOut to signalConditioning.signalIn;
        connection electrodeSignalB connect electrodeB.signalOut to signalConditioning.signalIn;

        connection conditionedSignalPath connect signalConditioning.signalOut to processor.signalIn;

        connection commandPath connect commandInput to processor.commandIn;
        connection dataPath connect processor.dataOut to dataOutput;

        // Lifecycle state machine
        state machine Lifecycle {
            entry action powerUp {
                perform powerSupply.powerOn();
            }
            exit action powerDown {
                perform powerSupply.powerOff();
            }

            state Off;
            state Initializing {
                entry action initSequence {
                    // Check magnetic field and electrodes
                }
                do action checkFieldCoils;
                do action checkElectrodes;
                do action checkSignalChain;
            }
            state Ready;
            state Measuring {
                do action measurementCycle {
                    // Generate field -> acquire voltage -> process data
                    perform electromagnetA.generateField(current, fieldA);
                    perform electromagnetB.generateField(current, fieldB);
                    perform electrodeA.senseVoltage(fieldA, velocity, rawA);
                    perform electrodeB.senseVoltage(fieldB, velocity, rawB);
                    perform signalConditioning.condition(rawA, cleanA);
                    perform processor.process(cleanA, fieldA, measurementTube.innerDiameter, measurementTube.crossSectionalArea, measurement);
                }
            }
            state Diagnostic {
                do action selfTest {
                    // Self-test routines
                }
            }
            state Fault;

            transition off_to_init transition Off to Initializing when powerOn;
            transition init_to_ready transition Initializing to Ready when initSequence.done;
            transition init_to_fault transition Initializing to Fault when initSequence.failed;
            transition ready_to_measuring transition Ready to Measuring when commandInput.command.commandKind == "start";
            transition measuring_to_ready transition Measuring to Ready when commandInput.command.commandKind == "stop";
            transition ready_to_diagnostic transition Ready to Diagnostic when commandInput.command.commandKind == "diagnose";
            transition diagnostic_to_ready transition Diagnostic to Ready when selfTest.done;
            transition any_to_off transition Ready to Off when commandInput.command.commandKind == "powerOff";
            transition fault_to_off transition Fault to Off when commandInput.command.commandKind == "powerOff";
        }

        // Requirement satisfaction
        satisfy req VelocityMeasurementRequirement by processor.computeVelocity;
        satisfy req VolumetricFlowRateRequirement by processor.computeFlowRate;
        satisfy req SignalIntegrityRequirement by signalConditioning.condition;
    }

    // ---- Requirements ----
    requirement def VelocityMeasurementRequirement {
        subject sensingUnit : MHDSensingUnit;
        requirement {
            doc /* The sensing unit shall measure the average fluid velocity with an accuracy of +/-0.5% of reading. */
        }
    }

    requirement def VolumetricFlowRateRequirement {
        subject sensingUnit : MHDSensingUnit;
        requirement {
            doc /* The sensing unit shall compute volumetric flow rate from measured velocity and known pipe geometry. */
        }
    }

    requirement def SignalIntegrityRequirement {
        subject module : SignalConditioningModule;
        requirement {
            doc /* The signal conditioning module shall amplify and filter the raw electrode voltage to produce a stable conditioned signal. */
        }
    }

    requirement def ConductiveFluidCompatibilityRequirement {
        subject sensingUnit : MHDSensingUnit;
        requirement {
            doc /* The sensing unit shall be compatible with conductive fluids having conductivity greater than 5 microSiemens per centimeter. */
        }
    }

    requirement def LifecycleRequirement {
        subject sensingUnit : MHDSensingUnit;
        requirement {
            doc /* The sensing unit shall implement Off, Initializing, Ready, Measuring, Diagnostic, and Fault lifecycle states. */
        }
    }

    requirement def MaterialRequirement {
        subject sensingUnit : MHDSensingUnit;
        requirement {
            doc /* The measurement tube shall be stainless steel with a non-conductive PTFE liner; electrodes shall be Hastelloy C. */
        }
    }

    requirement def FaradayInductionRequirement {
        subject sensingUnit : MHDSensingUnit;
        requirement {
            doc /* The sensing unit shall induce a voltage proportional to fluid velocity via a magnetic field perpendicular to flow, per Faraday's law. */
        }
    }

    requirement def DataOutputRequirement {
        subject sensingUnit : MHDSensingUnit;
        requirement {
            doc /* The sensing unit shall transmit velocity and volumetric flow rate measurements through a data output port. */
        }
    }

    requirement def DiagnosticRequirement {
        subject sensingUnit : MHDSensingUnit;
        requirement {
            doc /* The sensing unit shall provide a diagnostic mode for self-testing of field coils, electrodes, and signal chain. */
        }
    }

    // Package-level requirement group
    requirement MHDRequirements {
        requirement velocityReq : VelocityMeasurementRequirement;
        requirement flowRateReq : VolumetricFlowRateRequirement;
        requirement signalReq : SignalIntegrityRequirement;
        requirement fluidReq : ConductiveFluidCompatibilityRequirement;
        requirement lifecycleReq : LifecycleRequirement;
        requirement materialReq : MaterialRequirement;
        requirement faradayReq : FaradayInductionRequirement;
        requirement outputReq : DataOutputRequirement;
        requirement diagReq : DiagnosticRequirement;
    }

}
