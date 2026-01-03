package SelsynAngleTransmissionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def RotationalAngle :> ISQ::PlaneAngleValue {
        doc /* Angular position measured in degrees or radians */
    }

    attribute def ACVoltage :> ISQ::VoltageValue {
        doc /* Alternating current voltage for rotor excitation */
    }

    attribute def StatorSignal :> ISQ::VoltageValue {
        doc /* Voltage induced in stator windings */
    }

    attribute def CorrectiveTorque :> ISQ::TorqueValue {
        doc /* Torque applied to align receiver with transmitter */
    }

    port def MechanicalShaftPort {
        attribute shaftAngle : RotationalAngle;
        attribute appliedTorque : ISQ::TorqueValue;
    }

    port def ElectricalExcitationPort {
        in attribute excitationVoltage : ACVoltage;
        in attribute frequency : ISQ::FrequencyValue;
    }

    port def StatorWindingPort {
        attribute windingVoltage : StatorSignal;
    }

    part def SelsynTransmitterUnit {
        doc /* Converts mechanical shaft rotation into three-phase electrical signals */

        port mechanicalInput : MechanicalShaftPort {
            in attribute shaftAngle : RotationalAngle;
        }

        port rotorExcitation : ElectricalExcitationPort;

        port statorPhaseA : StatorWindingPort {
            out attribute windingVoltage : StatorSignal;
        }

        port statorPhaseB : StatorWindingPort {
            out attribute windingVoltage : StatorSignal;
        }

        port statorPhaseC : StatorWindingPort {
            out attribute windingVoltage : StatorSignal;
        }

        attribute currentRotorAngle : RotationalAngle;
    }

    part def SelsynReceiverUnit {
        doc /* Converts three-phase electrical signals back into mechanical shaft rotation */

        port rotorExcitation : ElectricalExcitationPort;

        port statorPhaseA : StatorWindingPort {
            in attribute windingVoltage : StatorSignal;
        }

        port statorPhaseB : StatorWindingPort {
            in attribute windingVoltage : StatorSignal;
        }

        port statorPhaseC : StatorWindingPort {
            in attribute windingVoltage : StatorSignal;
        }

        port mechanicalOutput : MechanicalShaftPort {
            out attribute shaftAngle : RotationalAngle;
            out attribute appliedTorque : CorrectiveTorque;
        }

        attribute currentRotorAngle : RotationalAngle;
    }

    part def ACPowerSource {
        doc /* Provides AC excitation voltage to both transmitter and receiver rotors */

        port transmitterSupply : ElectricalExcitationPort {
            out attribute excitationVoltage : ACVoltage;
            out attribute frequency : ISQ::FrequencyValue;
        }

        port receiverSupply : ElectricalExcitationPort {
            out attribute excitationVoltage : ACVoltage;
            out attribute frequency : ISQ::FrequencyValue;
        }

        attribute supplyVoltage : ACVoltage;
        attribute supplyFrequency : ISQ::FrequencyValue;
    }

    part def InputShaft {
        doc /* Mechanical input shaft providing angular position to be transmitted */

        port output : MechanicalShaftPort {
            out attribute shaftAngle : RotationalAngle;
        }

        attribute inputAngle : RotationalAngle;
    }

    part def OutputShaft {
        doc /* Mechanical output shaft that follows the input shaft position remotely */

        port input : MechanicalShaftPort {
            in attribute shaftAngle : RotationalAngle;
            in attribute appliedTorque : CorrectiveTorque;
        }

        attribute outputAngle : RotationalAngle;
    }

    action def SenseInputAngle {
        in mechanicalAngle : RotationalAngle;
        out sensedAngle : RotationalAngle;
    }

    action def EncodeToStatorSignals {
        in rotorAngle : RotationalAngle;
        in excitationVoltage : ACVoltage;
        out phaseASignal : StatorSignal;
        out phaseBSignal : StatorSignal;
        out phaseCSignal : StatorSignal;
    }

    action def TransmitElectricalSignals {
        in txPhaseA : StatorSignal;
        in txPhaseB : StatorSignal;
        in txPhaseC : StatorSignal;
        out rxPhaseA : StatorSignal;
        out rxPhaseB : StatorSignal;
        out rxPhaseC : StatorSignal;
    }

    action def DecodeStatorSignals {
        in phaseASignal : StatorSignal;
        in phaseBSignal : StatorSignal;
        in phaseCSignal : StatorSignal;
        in currentReceiverAngle : RotationalAngle;
        out angleError : RotationalAngle;
    }

    action def GenerateCorrectionTorque {
        in angleError : RotationalAngle;
        out torque : CorrectiveTorque;
    }

    action def AdjustReceiverPosition {
        in torque : CorrectiveTorque;
        in currentAngle : RotationalAngle;
        out updatedAngle : RotationalAngle;
    }

    action def TransmitAngularPosition {
        doc /* Primary system function: transmit angular position from input to output shaft */

        in inputShaftAngle : RotationalAngle;
        out outputShaftAngle : RotationalAngle;

        first start;

        then action sense : SenseInputAngle {
            in mechanicalAngle = inputShaftAngle;
            out sensedAngle;
        }

        then action encode : EncodeToStatorSignals {
            in rotorAngle = sense.sensedAngle;
            in excitationVoltage;
            out phaseASignal;
            out phaseBSignal;
            out phaseCSignal;
        }

        then action transmit : TransmitElectricalSignals {
            in txPhaseA = encode.phaseASignal;
            in txPhaseB = encode.phaseBSignal;
            in txPhaseC = encode.phaseCSignal;
            out rxPhaseA;
            out rxPhaseB;
            out rxPhaseC;
        }

        then merge synchronizationLoop;

        then action decode : DecodeStatorSignals {
            in phaseASignal = transmit.rxPhaseA;
            in phaseBSignal = transmit.rxPhaseB;
            in phaseCSignal = transmit.rxPhaseC;
            in currentReceiverAngle;
            out angleError;
        }

        then decide;
            if decode.angleError > 0.1 then applyCorrection;
            if decode.angleError <= 0.1 then synchronized;

        action applyCorrection : GenerateCorrectionTorque {
            in angleError = decode.angleError;
            out torque;
        }

        then action adjust : AdjustReceiverPosition {
            in torque = applyCorrection.torque;
            in currentAngle;
            out updatedAngle;
        }

        then synchronizationLoop;

        action synchronized {
            out finalAngle = decode.currentReceiverAngle;
        }

        then assign outputShaftAngle := synchronized.finalAngle;

        then done;
    }

    part selsynSystem {
        doc /* Complete selsyn system for remote angular position transmission and synchronization */

        part inputShaft : InputShaft;

        part transmitter : SelsynTransmitterUnit;

        part receiver : SelsynReceiverUnit;

        part outputShaft : OutputShaft;

        part powerSource : ACPowerSource {
            attribute supplyVoltage = 115.0;
            attribute supplyFrequency = 60.0;
        }

        connect inputShaft.output to transmitter.mechanicalInput;

        connect powerSource.transmitterSupply to transmitter.rotorExcitation;
        connect powerSource.receiverSupply to receiver.rotorExcitation;

        connect transmitter.statorPhaseA to receiver.statorPhaseA;
        connect transmitter.statorPhaseB to receiver.statorPhaseB;
        connect transmitter.statorPhaseC to receiver.statorPhaseC;

        connect receiver.mechanicalOutput to outputShaft.input;

        perform action transmitPosition : TransmitAngularPosition;
    }

    requirement def PositionSynchronizationRequirement {
        doc /* The selsyn system shall maintain angular synchronization between input and output shafts */

        subject system : selsynSystem;

        require constraint accuracyConstraint {
            doc /* Angular error between input and output shall not exceed 1 degree under steady-state conditions */
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The selsyn system shall achieve position synchronization within acceptable time */

        subject system : selsynSystem;

        require constraint responseConstraint {
            doc /* Output shaft shall reach 95 percent of commanded position within 250 milliseconds */
        }
    }

    requirement <'SELSYN-SYS-001'> primaryFunctionRequirement {
        doc /* The selsyn system shall transmit angular position from an input shaft to a remote output shaft 
             through electromagnetic coupling, maintaining continuous synchronization between the two shafts 
             without mechanical connection */

        subject system : selsynSystem;

        require positionSynchronization : PositionSynchronizationRequirement;
        require responseTimePerformance : ResponseTimeRequirement;
    }
}
