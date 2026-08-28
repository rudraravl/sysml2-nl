package LVDTPositionMeasurementSystem {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value def Voltage :> Real { unit 'V'; }
    value def Displacement :> Real { unit 'mm'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Current :> Real { unit 'A'; }
    value def Length :> Real { unit 'mm'; }
    value def Resistance :> Real { unit 'ohm'; }
    value def Inductance :> Real { unit 'mH'; }
    value def PhaseAngle :> Real { unit 'deg'; }

    // ===== Item Types =====
    item def DCVoltage {
        attribute magnitude : Voltage;
    }
    item def ACVoltage {
        attribute magnitude : Voltage;
        attribute frequency : Frequency;
        attribute phase : PhaseAngle;
    }
    item def DifferentialVoltage {
        attribute magnitude : Voltage;
        attribute phase : PhaseAngle;
    }
    item def ConditionedDCVoltage {
        attribute magnitude : Voltage;
    }
    item def PositionReading {
        attribute value : Displacement;
    }

    // ===== Port Definitions =====
    port def DCPowerPort {
        out dcVoltage : DCVoltage;
    }
    port def ACExcitationPort {
        out acVoltage : ACVoltage;
    }
    port def SecondaryOutputPort {
        out acVoltage : ACVoltage;
    }
    port def DifferentialSignalPort {
        out diffVoltage : DifferentialVoltage;
    }
    port def ConditionedDCPort {
        out dcVoltage : ConditionedDCVoltage;
    }
    port def PositionOutputPort {
        out position : PositionReading;
    }
    port def MechanicalLinkPort {
        in displacement : Displacement;
    }

    // ===== Requirements =====
    requirement def MeasurementRangeRequirement {
        doc /* The system shall measure linear displacements over a range of ±25 mm. */
        attribute minRange : Displacement = -25 [mm];
        attribute maxRange : Displacement = 25 [mm];
        constraint { measurementValue >= minRange and measurementValue <= maxRange }
        attribute measurementValue : Displacement;
    }

    requirement def ResolutionRequirement {
        doc /* The system shall achieve a position resolution of at least 0.01 mm. */
        attribute minResolution : Displacement = 0.01 [mm];
        constraint { resolution <= minResolution }
        attribute resolution : Displacement;
    }

    requirement def AccuracyRequirement {
        doc /* The displayed position shall be proportional to core displacement within 0.005 mm. */
        attribute maxError : Displacement = 0.005 [mm];
        constraint { |reading - actual| <= maxError }
        attribute reading : Displacement;
        attribute actual : Displacement;
    }

    requirement def ExcitationStabilityRequirement {
        doc /* The excitation source shall generate a stable high-frequency AC voltage to energize the primary coil. */
        attribute nominalFrequency : Frequency = 5000 [Hz];
        attribute nominalAmplitude : Voltage = 3.0 [V];
        attribute frequencyStabilityTolerance : Real = 0.01;
        constraint { |excitationFrequency - nominalFrequency| / nominalFrequency <= frequencyStabilityTolerance }
        attribute excitationFrequency : Frequency;
    }

    requirement def ZeroOutputRequirement {
        doc /* When the ferrite core is centered, the differential secondary voltage shall be zero. */
        constraint { |corePosition| == 0 [mm] implies |differentialVoltage| == 0 [V] }
        attribute corePosition : Displacement;
        attribute differentialVoltage : Voltage;
    }

    // ===== Part Definitions =====

    part def PowerSupply {
        attribute outputVoltage : Voltage = 15 [V];
        attribute maxCurrent : Current = 0.5 [A];
        attribute rippleVoltage : Voltage = 0.01 [V];
        port dcOut : DCPowerPort;

        action def SupplyPower {
            out dc : DCVoltage;
        }
    }

    part def ExcitationSource {
        attribute excitationFrequency : Frequency = 5000 [Hz];
        attribute excitationAmplitude : Voltage = 3.0 [V];
        attribute waveformType : String = "sine";
        port dcIn : DCPowerPort;
        port acOut : ACExcitationPort;

        action def GenerateAC {
            in dcInput : DCVoltage;
            out acOutput : ACVoltage;
        }
    }

    part def PrimaryCoil {
        attribute inductance : Inductance = 10 [mH];
        attribute resistance : Resistance = 50 [ohm];
        attribute turns : Integer = 500;
        port excitationIn : ACExcitationPort;
    }

    part def SecondaryCoil {
        attribute inductance : Inductance = 5 [mH];
        attribute resistance : Resistance = 30 [ohm];
        attribute turns : Integer = 250;
        port output : SecondaryOutputPort;
    }

    part def FerriteCore {
        attribute relativePermeability : Real = 2000;
        attribute length : Length = 30 [mm];
        attribute diameter : Length = 5 [mm];
        attribute currentDisplacement : Displacement = 0 [mm];
        port mechanicalLink : MechanicalLinkPort;
    }

    part def LVDTTransformer {
        doc /* Linear Variable Differential Transformer assembly with primary coil, two secondary coils, and movable ferrite core. */
        part primaryCoil : PrimaryCoil;
        part secondaryCoilA : SecondaryCoil;
        part secondaryCoilB : SecondaryCoil;
        part ferriteCore : FerriteCore;

        attribute strokeRange : Displacement = 25 [mm];
        attribute sensitivity : Real = 0.12 [V/mm];

        port excitationPort : ACExcitationPort;
        port secondaryAOut : SecondaryOutputPort;
        port secondaryBOut : SecondaryOutputPort;
        port mechanicalInput : MechanicalLinkPort;

        connection excitationConn connect excitationPort to primaryCoil.excitationIn;
        connection mechanicalConn connect mechanicalInput to ferriteCore.mechanicalLink;

        action def InduceVoltages {
            in primaryExcitation : ACVoltage;
            in corePosition : Displacement;
            out secondaryA : ACVoltage;
            out secondaryB : ACVoltage;
        }
    }

    part def SignalConditioner {
        doc /* Processes raw AC secondary outputs: calculates differential voltage, demodulates, filters, and amplifies. */
        attribute gain : Real = 100;
        attribute filterCutoff : Frequency = 100 [Hz];
        attribute inputImpedance : Resistance = 10000 [ohm];

        port secondaryAIn : SecondaryOutputPort;
        port secondaryBIn : SecondaryOutputPort;
        port diffOut : DifferentialSignalPort;
        port conditionedOut : ConditionedDCPort;

        action def CalculateDifferential {
            in secA : ACVoltage;
            in secB : ACVoltage;
            out diff : DifferentialVoltage;
        }

        action def Demodulate {
            in diff : DifferentialVoltage;
            out dc : ConditionedDCVoltage;
        }

        action def FilterAndAmplify {
            in dc : ConditionedDCVoltage;
            out conditioned : ConditionedDCVoltage;
        }

        action def ProcessSignals {
            in secA : ACVoltage;
            in secB : ACVoltage;
            out conditioned : ConditionedDCVoltage;

            action calcDiff : CalculateDifferential;
            action demod : Demodulate;
            action filtAmp : FilterAndAmplify;

            succession calcDiff to demod;
            succession demod to filtAmp;
        }
    }

    part def DisplayUnit {
        doc /* Converts conditioned DC voltage into a calibrated displacement value and presents a digital readout. */
        attribute calibrationFactor : Real = 8.33 [mm/V];
        attribute displayResolution : Displacement = 0.01 [mm];
        attribute displayType : String = "digital LCD";

        port conditionedIn : ConditionedDCPort;
        port positionOut : PositionOutputPort;

        action def ConvertToPosition {
            in dcVoltage : ConditionedDCVoltage;
            out position : PositionReading;
        }
    }

    // ===== Top-level System =====
    part def LVDTPositionMeasurementSystem {
        doc /* High-precision position measurement system based on an LVDT. Converts linear mechanical movement into a proportional electrical signal displayed as a precise position reading. */

        satisfy MeasurementRangeRequirement;
        satisfy ResolutionRequirement;
        satisfy AccuracyRequirement;
        satisfy ExcitationStabilityRequirement;
        satisfy ZeroOutputRequirement;

        part powerSupply : PowerSupply;
        part excitationSource : ExcitationSource;
        part lvdtTransformer : LVDTTransformer;
        part signalConditioner : SignalConditioner;
        part displayUnit : DisplayUnit;

        // Inter-part connections
        connection powerToExcitation connect powerSupply.dcOut to excitationSource.dcIn;
        connection excitationToPrimary connect excitationSource.acOut to lvdtTransformer.excitationPort;
        connection secondaryAToConditioner connect lvdtTransformer.secondaryAOut to signalConditioner.secondaryAIn;
        connection secondaryBToConditioner connect lvdtTransformer.secondaryBOut to signalConditioner.secondaryBIn;
        connection conditionedToDisplay connect signalConditioner.conditionedOut to displayUnit.conditionedIn;

        // System-level state machine
        state def SystemStates {
            entry; then Off;

            state Off {
                doc /* System is powered down; no excitation or measurement active. */
            }

            transition from Off to PoweringUp
                when powerSupply.outputVoltage > 0 [V];

            state PoweringUp {
                doc /* DC power applied; excitation source initializing. */
                entry; then Exciting;
            }

            transition from PoweringUp to Exciting;

            state Exciting {
                doc /* Excitation source generating stable AC voltage energizing primary coil. */
                entry; then Measuring;
            }

            transition from Exciting to Measuring;

            state Measuring {
                doc /* Ferrite core displacement is being measured; signal conditioner processing outputs; display showing position. */
            }

            transition from Measuring to Off
                when powerSupply.outputVoltage == 0 [V];
        }

        // System-level measurement action
        action def PerformMeasurement {
            in mechanicalDisplacement : Displacement;
            out positionReading : PositionReading;

            action supply : PowerSupply::SupplyPower;
            action generate : ExcitationSource::GenerateAC;
            action induce : LVDTTransformer::InduceVoltages;
            action process : SignalConditioner::ProcessSignals;
            action convert : DisplayUnit::ConvertToPosition;

            succession supply to generate;
            succession generate to induce;
            succession induce to process;
            succession process to convert;
        }
    }
}
