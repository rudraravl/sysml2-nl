package ElectromagneticTransducer {

    import ISQ::*;
    import ScalarValues::*;
    import Time::*;

    // ---- Units ----
    item def ElectricCurrentUnit :> Unit;
    item def VoltageUnit :> Unit;
    item def ForceUnit :> Unit;
    item def MagneticFluxDensityUnit :> Unit;
    item def DisplacementUnit :> Unit;
    item def SoundPressureLevelUnit :> Unit;
    item def FrequencyUnit :> Unit;
    item def PowerUnit :> Unit;
    item def ResistanceUnit :> Unit;
    item def InductanceUnit :> Unit;
    item def MassUnit :> Unit;
    item def StiffnessUnit :> Unit;
    item def DampingUnit :> Unit;
    item def AreaUnit :> Unit;
    item def EfficiencyUnit :> Unit;
    item def PercentUnit :> Unit;

    // ---- Value types ----
    value def ElectricCurrent :> Real { unit ElectricCurrentUnit; }
    value def Voltage :> Real { unit VoltageUnit; }
    value def Force :> Real { unit ForceUnit; }
    value def MagneticFluxDensity :> Real { unit MagneticFluxDensityUnit; }
    value def Displacement :> Real { unit DisplacementUnit; }
    value def SoundPressureLevel :> Real { unit SoundPressureLevelUnit; }
    value def Frequency :> Real { unit FrequencyUnit; }
    value def Power :> Real { unit PowerUnit; }
    value def Resistance :> Real { unit ResistanceUnit; }
    value def Inductance :> Real { unit InductanceUnit; }
    value def Mass :> Real { unit MassUnit; }
    value def Stiffness :> Real { unit StiffnessUnit; }
    value def DampingCoefficient :> Real { unit DampingUnit; }
    value def Area :> Real { unit AreaUnit; }
    value def Efficiency :> Real { unit EfficiencyUnit; }
    value def Percent :> Real { unit PercentUnit; }

    // ---- Item types ----
    item def AudioSignal {
        attribute voltage : Voltage;
        attribute current : ElectricCurrent;
        attribute frequency : Frequency;
    }
    item def SoundWave {
        attribute pressureLevel : SoundPressureLevel;
        attribute frequency : Frequency;
    }
    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensity;
    }

    // ---- Port definitions ----
    port def ElectricalInputPort {
        attribute voltage : Voltage;
        attribute current : ElectricCurrent;
        in item signal : AudioSignal;
    }
    port def AcousticOutputPort {
        attribute pressureLevel : SoundPressureLevel;
        out item wave : SoundWave;
    }
    port def MechanicalInterfacePort {
        attribute displacement : Displacement;
        attribute force : Force;
    }

    // ---- Requirements ----
    requirement def FrequencyResponseRequirement {
        attribute lowerCutoff : Frequency = 20.0;
        attribute upperCutoff : Frequency = 20000.0;
        attribute maxDeviation : Real = 3.0;
        doc /*
         * The transducer shall reproduce audio frequencies within the
         * specified band with deviation not exceeding maxDeviation dB.
         */
        require constraint { (lowerCutoff <= signal.frequency) and (signal.frequency <= upperCutoff) }
    }

    requirement def PowerHandlingRequirement {
        attribute nominalPower : Power = 50.0;
        attribute peakPower : Power = 200.0;
        doc /*
         * The transducer shall handle nominal and peak electrical
         * power without permanent damage or excessive distortion.
         */
    }

    requirement def DistortionRequirement {
        attribute maxTHD : Percent = 1.0;
        doc /*
         * Total harmonic distortion shall not exceed maxTHD percent
         * at rated power within the operating band.
         */
    }

    requirement def SensitivityRequirement {
        attribute minSensitivity : SoundPressureLevel = 87.0;
        attribute referencePower : Power = 1.0;
        doc /*
         * The transducer shall produce at least minSensitivity dB SPL
         * at 1 m on-axis for referencePower W input.
         */
    }

    requirement def TransducerRequirements {
        require freq : FrequencyResponseRequirement;
        require power : PowerHandlingRequirement;
        require distortion : DistortionRequirement;
        require sensitivity : SensitivityRequirement;
    }

    // ---- Part definitions ----
    part def PermanentMagnet {
        attribute remanentFluxDensity : MagneticFluxDensity = 1.2;
        out port fieldPort : MagneticField;
    }

    part def MagneticCircuit {
        attribute topPlateThickness : Displacement;
        attribute polePieceDiameter : Displacement;
        attribute gapFluxDensity : MagneticFluxDensity = 1.0;
        in port fieldInput : MagneticField;
        out port gapField : MagneticField;
    }

    part def VoiceCoil {
        attribute dcResistance : Resistance = 6.5;
        attribute inductance : Inductance = 0.8e-3;
        attribute wireTurns : Integer = 80;
        attribute movingMass : Mass = 0.5e-3;
        in port electricalInput : ElectricalInputPort;
        in port gapFieldInput : MagneticField;
        out port mechanicalOutput : MechanicalInterfacePort;
        action def GenerateForce {
            in signal : AudioSignal;
            in field : MagneticField;
            out force : Force;
        }
        perform generateForce : GenerateForce;
    }

    part def Diaphragm {
        attribute effectiveArea : Area = 0.008;
        attribute movingMass : Mass = 2.0e-3;
        in port mechanicalInput : MechanicalInterfacePort;
        out port acousticOutput : AcousticOutputPort;
        action def RadiateSound {
            in displacement : Displacement;
            out wave : SoundWave;
        }
        perform radiateSound : RadiateSound;
    }

    part def Suspension {
        attribute stiffness : Stiffness = 1000.0;
        attribute damping : DampingCoefficient = 0.5;
        in port mechanicalInterface : MechanicalInterfacePort;
        action def RestorePosition {
            in displacement : Displacement;
            out restoringForce : Force;
        }
        perform restorePosition : RestorePosition;
    }

    part def Housing {
        attribute material : String = "Aluminum";
        attribute structuralRigidity : Real = 1.0;
    }

    part def MotorAssembly {
        part magnet : PermanentMagnet;
        part magneticCircuit : MagneticCircuit;
        part voiceCoil : VoiceCoil;
        connect magnet.fieldPort to magneticCircuit.fieldInput;
        connect magneticCircuit.gapField to voiceCoil.gapFieldInput;
    }

    part def ElectromagneticTransducer {
        requirement transducerRequirements : TransducerRequirements;

        part housing : Housing;
        part motor : MotorAssembly;
        part diaphragm : Diaphragm;
        part suspension : Suspension;

        in port electricalInput : ElectricalInputPort;
        out port acousticOutput : AcousticOutputPort;

        connect electricalInput to motor.voiceCoil.electricalInput;
        connect motor.voiceCoil.mechanicalOutput to diaphragm.mechanicalInput;
        connect motor.voiceCoil.mechanicalOutput to suspension.mechanicalInterface;
        connect diaphragm.acousticOutput to acousticOutput;

        attribute nominalImpedance : Resistance = 8.0;
        attribute resonantFrequency : Frequency = 55.0;
        attribute efficiency : Efficiency = 0.02;

        // ---- State machine ----
        state def TransducerLifecycle {
            entry action { /* initialize */ }
            state off {
                entry action { /* unpowered */ }
            }
            state idle {
                entry action { /* powered, no signal */ }
            }
            state active {
                entry action { /* begin transduction */ }
                do action TranslateSignal {
                    in signal : AudioSignal;
                    out wave : SoundWave;
                }
            }
            transition off to idle when electricalInput.voltage > 0.0;
            transition idle to active when electricalInput.current != 0.0;
            transition active to idle when electricalInput.current == 0.0;
            transition idle to off when electricalInput.voltage == 0.0;
        }

        exhibit lifecycle : TransducerLifecycle;
    }
}
