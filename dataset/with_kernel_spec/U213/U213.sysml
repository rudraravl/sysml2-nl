package ElectromagneticTransducerModel {
    private import ScalarValues::*;

    attribute def VoltageValue : Real;
    attribute def CurrentValue : Real;
    attribute def PressureValue : Real;
    attribute def ForceValue : Real;
    attribute def ResistanceValue : Real;
    attribute def MagneticFluxDensityValue : Real;
    attribute def MassValue : Real;
    attribute def SpringStiffnessValue : Real;
    attribute def FrequencyValue : Real;
    attribute def PowerValue : Real;

    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def SoundWave {
        attribute pressure : PressureValue;
    }

    item def MechanicalForce {
        attribute magnitude : ForceValue;
    }

    port def ElectricalInPort {
        in signal : ElectricalSignal;
    }

    port def AcousticOutPort {
        out wave : SoundWave;
    }

    port def MechanicalPort {
        out force : MechanicalForce;
    }

    part def VoiceCoil {
        doc /* Tightly wound coil of wire that converts electrical current into a fluctuating magnetic field. */
        attribute wireGauge : Real;
        attribute impedance : ResistanceValue;
        port electricalInput : ElectricalInPort;
        port mechanicalOutput : MechanicalPort;
    }

    part def PermanentMagnet {
        doc /* Provides a static magnetic field concentrated into the gap. */
        attribute material : String;
        attribute fieldStrength : MagneticFluxDensityValue;
    }

    part def MagneticCircuit {
        doc /* Steel plates and pole piece that shape and concentrate the magnetic field into a narrow gap. */
        part topPlate;
        part bottomPlate;
        part polePiece;
        attribute material : String = "Steel";
    }

    part def MotorAssembly {
        doc /* Core motor assembly converting electrical audio signals into mechanical force. */
        part voiceCoil : VoiceCoil;
        part magnet : PermanentMagnet;
        part magneticCircuit : MagneticCircuit;
    }

    part def Diaphragm {
        doc /* Lightweight, flexible cone or dome that moves air to create sound waves. */
        attribute material : String;
        attribute mass : MassValue;
        port mechanicalInput : ~MechanicalPort;
        port acousticOutput : AcousticOutPort;
    }

    part def Suspension {
        doc /* Flexible surround that centers the diaphragm, provides restoring force, and damps oscillations. */
        attribute material : String;
        attribute stiffness : SpringStiffnessValue;
    }

    part def Housing {
        doc /* Rigid chassis providing structural support and mounting points. */
        attribute material : String;
    }

    attribute def PowerOn;
    attribute def PowerOff;
    attribute def SignalReceived;
    attribute def SignalStopped;

    state def TransducerStates {
        state off;
        state idle;
        state active;
        
        transition powerOn first off then idle accept PowerOn;
        transition powerOff first idle then off accept PowerOff;
        transition signalReceived first idle then active accept SignalReceived;
        transition signalStopped first active then idle accept SignalStopped;
    }

    action def ConvertElectricalToMechanical {
        in signal : ElectricalSignal;
        out force : MechanicalForce;
    }

    action def RadiateSound {
        in force : MechanicalForce;
        out wave : SoundWave;
    }

    action def OperateTransducer {
        in signal : ElectricalSignal;
        out wave : SoundWave;
        
        action convert : ConvertElectricalToMechanical {
            in signal = OperateTransducer::signal;
        }
        action radiate : RadiateSound {
            out wave = OperateTransducer::wave;
        }
        flow convert.force to radiate.force;
        
        first start;
        then convert;
        then radiate;
        then done;
    }

    requirement def FrequencyResponseRequirement {
        doc /* The transducer must maintain a flat frequency response within ±3 dB from 20 Hz to 20 kHz. */
        attribute minFrequency : FrequencyValue = 20;
        attribute maxFrequency : FrequencyValue = 20000;
        attribute tolerance : Real = 3.0;
    }

    requirement def PowerHandlingRequirement {
        doc /* The transducer must handle continuous input power up to 100 Watts without thermal damage. */
        attribute maxPower : PowerValue = 100;
    }

    requirement def LowDistortionRequirement {
        doc /* Total harmonic distortion must remain below 1% at rated power. */
        attribute maxTHD : Real = 0.01;
    }

    requirement def SensitivityRequirement {
        doc /* The transducer must produce a sound pressure level of 90 dB SPL at 1 meter with 1 Watt input. */
        attribute sensitivity : Real = 90.0;
    }

    part def ElectromagneticTransducer {
        port electricalInput : ElectricalInPort;
        port acousticOutput : AcousticOutPort;
        
        part motor : MotorAssembly;
        part diaphragm : Diaphragm;
        part suspension : Suspension;
        part housing : Housing;
        
        state transducerState : TransducerStates;
        action operate : OperateTransducer;
        
        connect electricalInput to motor.voiceCoil.electricalInput;
        connect motor.voiceCoil.mechanicalOutput to diaphragm.mechanicalInput;
        connect diaphragm.acousticOutput to acousticOutput;
        connect diaphragm to suspension;
        connect suspension to housing;
        connect motor to housing;
    }
    
    requirement freqResponse : FrequencyResponseRequirement;
    requirement powerHandling : PowerHandlingRequirement;
    requirement lowDistortion : LowDistortionRequirement;
    requirement sensitivity : SensitivityRequirement;
    
    part transducer : ElectromagneticTransducer {
        satisfy freqResponse;
        satisfy powerHandling;
        satisfy lowDistortion;
        satisfy sensitivity;
    }
}
