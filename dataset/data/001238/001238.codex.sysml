package SelsynAngularPositionTransmissionSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Angle :> ISQ::planeAngle {
        unit = SI::degree;
    }

    attribute def AngularVelocity :> ISQ::angularVelocity {
        unit = SI::degree / SI::s;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::V;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::A;
    }

    attribute def Frequency :> ISQ::frequency {
        unit = SI::Hz;
    }

    attribute def Torque :> ISQ::torque {
        unit = SI::N * SI::m;
    }

    attribute def Power :> ISQ::power {
        unit = SI::W;
    }

    enum def SelsynOperatingMode {
        enum idle;
        enum aligning;
        enum tracking;
        enum faulted;
    }

    enum def PhaseId {
        enum phaseA;
        enum phaseB;
        enum phaseC;
    }

    item def ShaftRotation {
        attribute angle : Angle;
        attribute speed : AngularVelocity;
        attribute torque : Torque;
    }

    item def SinglePhaseExcitation {
        attribute voltageRms : Voltage;
        attribute currentRms : Current;
        attribute frequency : Frequency;
    }

    item def ThreeWireStatorSignal {
        attribute phaseAtoNeutralVoltage : Voltage;
        attribute phaseBtoNeutralVoltage : Voltage;
        attribute phaseCtoNeutralVoltage : Voltage;
        attribute lineFrequency : Frequency;
        attribute encodedRotorAngle : Angle;
    }

    item def MechanicalLoad {
        attribute demandedAngle : Angle;
        attribute resistingTorque : Torque;
        attribute inertiaEquivalent : Real;
    }

    item def AlignmentError {
        attribute commandAngle : Angle;
        attribute indicatedAngle : Angle;
        attribute errorAngle : Angle;
    }

    port def MechanicalShaftPort {
        inout item rotation : ShaftRotation;
    }

    port def RotorExcitationPort {
        in item excitation : SinglePhaseExcitation;
    }

    port def StatorThreeWirePort {
        inout item statorSignal : ThreeWireStatorSignal;
    }

    port def LoadPort {
        out item loadMotion : ShaftRotation;
        in item loadDemand : MechanicalLoad;
    }

    port def DiagnosticPort {
        out item alignment : AlignmentError;
        out attribute mode : SelsynOperatingMode;
    }

    part def SelsynTransmitter {
        attribute rotorAngle : Angle = 0 [SI::degree];
        attribute rotorSpeed : AngularVelocity = 0 [SI::degree / SI::s];
        attribute excitationVoltage : Voltage = 115 [SI::V];
        attribute excitationFrequency : Frequency = 400 [SI::Hz];
        attribute electricalPowerInput : Power;
        attribute transformationRatio : Real = 0.78;

        port shaft : MechanicalShaftPort;
        port rotorPower : RotorExcitationPort;
        port statorOutput : StatorThreeWirePort;

        action encodeMechanicalAngle {
            in item commandedRotation : ShaftRotation;
            in item excitation : SinglePhaseExcitation;
            out item statorVoltages : ThreeWireStatorSignal;

            first start;
            then sampleRotorPosition;
            then computePhaseVoltages;
            then publishStatorSignal;

            action sampleRotorPosition {
                in item commandedRotation : ShaftRotation;
                out attribute sampledAngle : Angle;
                out attribute sampledSpeed : AngularVelocity;
            }

            action computePhaseVoltages {
                in attribute sampledAngle : Angle;
                in item excitation : SinglePhaseExcitation;
                out item statorVoltages : ThreeWireStatorSignal;
            }

            action publishStatorSignal {
                in item statorVoltages : ThreeWireStatorSignal;
            }
        }

        state def TransmitterState {
            entry action initializeTransmitter;
            state unexcited;
            state excited;
            state transmitting;
            state transmitterFault;

            transition first unexcited;
            transition unexcited_to_excited
                first unexcited
                then excited
                if rotorPower.excitation.voltageRms >= 90 [SI::V];

            transition excited_to_transmitting
                first excited
                then transmitting
                if rotorPower.excitation.frequency >= 360 [SI::Hz] and rotorPower.excitation.frequency <= 440 [SI::Hz];

            transition transmitting_to_fault
                first transmitting
                then transmitterFault
                if rotorPower.excitation.voltageRms < 80 [SI::V];

            transition fault_to_unexcited
                first transmitterFault
                then unexcited
                if rotorPower.excitation.voltageRms == 0 [SI::V];
        }
    }

    part def SelsynReceiver {
        attribute indicatedAngle : Angle = 0 [SI::degree];
        attribute indicatedSpeed : AngularVelocity = 0 [SI::degree / SI::s];
        attribute developedTorque : Torque;
        attribute dampingTorque : Torque;
        attribute maximumFollowUpError : Angle = 2 [SI::degree];

        port statorInput : StatorThreeWirePort;
        port rotorPower : RotorExcitationPort;
        port outputShaft : MechanicalShaftPort;
        port drivenLoad : LoadPort;

        action convertElectricalAngleToMotion {
            in item statorVoltages : ThreeWireStatorSignal;
            in item excitation : SinglePhaseExcitation;
            in item loadDemand : MechanicalLoad;
            out item receiverRotation : ShaftRotation;
            out item alignmentError : AlignmentError;

            first compareRotorWithField;
            then generateSynchronizingTorque;
            then accelerateReceiverRotor;
            then settleAtCommandedAngle;

            action compareRotorWithField {
                in item statorVoltages : ThreeWireStatorSignal;
                out item alignmentError : AlignmentError;
            }

            action generateSynchronizingTorque {
                in item alignmentError : AlignmentError;
                out attribute synchronizingTorque : Torque;
            }

            action accelerateReceiverRotor {
                in attribute synchronizingTorque : Torque;
                in item loadDemand : MechanicalLoad;
                out item receiverRotation : ShaftRotation;
            }

            action settleAtCommandedAngle {
                in item receiverRotation : ShaftRotation;
                out item finalRotation : ShaftRotation;
            }
        }

        state def ReceiverState {
            entry action initializeReceiver;
            state unpowered;
            state seekingNull;
            state synchronized;
            state receiverFault;

            transition first unpowered;
            transition unpowered_to_seeking
                first unpowered
                then seekingNull
                if rotorPower.excitation.voltageRms >= 90 [SI::V];

            transition seeking_to_synchronized
                first seekingNull
                then synchronized
                if abs(statorInput.statorSignal.encodedRotorAngle - outputShaft.rotation.angle) <= maximumFollowUpError;

            transition synchronized_to_seeking
                first synchronized
                then seekingNull
                if abs(statorInput.statorSignal.encodedRotorAngle - outputShaft.rotation.angle) > maximumFollowUpError;

            transition seeking_to_fault
                first seekingNull
                then receiverFault
                if rotorPower.excitation.voltageRms < 80 [SI::V];

            transition fault_to_unpowered
                first receiverFault
                then unpowered
                if rotorPower.excitation.voltageRms == 0 [SI::V];
        }
    }

    part def ACReferenceSupply {
        attribute nominalVoltage : Voltage = 115 [SI::V];
        attribute nominalFrequency : Frequency = 400 [SI::Hz];
        attribute maximumOutputPower : Power = 35 [SI::W];

        port transmitterRotorOutput : RotorExcitationPort;
        port receiverRotorOutput : RotorExcitationPort;

        action provideCommonReferenceExcitation {
            out item transmitterExcitation : SinglePhaseExcitation;
            out item receiverExcitation : SinglePhaseExcitation;
        }
    }

    part def ThreeWireInterconnect {
        attribute conductorCount : Integer = 3;
        attribute phaseSeparation : Angle = 120 [SI::degree];
        attribute maximumLineVoltage : Voltage = 90 [SI::V];
        attribute maximumLineCurrent : Current = 0.25 [SI::A];

        port transmitterEnd : StatorThreeWirePort;
        port receiverEnd : StatorThreeWirePort;

        action transferStatorSignal {
            in item transmittedSignal : ThreeWireStatorSignal;
            out item receivedSignal : ThreeWireStatorSignal;
        }
    }

    part def CommandInputShaft {
        attribute commandedAngle : Angle = 0 [SI::degree];
        attribute commandedSpeed : AngularVelocity = 0 [SI::degree / SI::s];
        attribute appliedTorque : Torque = 0.08 [SI::N * SI::m];

        port shaftOutput : MechanicalShaftPort;

        action imposeCommandedRotation {
            out item commandRotation : ShaftRotation;
        }
    }

    part def RemoteIndicatorLoad {
        attribute pointerAngle : Angle = 0 [SI::degree];
        attribute frictionTorque : Torque = 0.015 [SI::N * SI::m];
        attribute allowableTrackingError : Angle = 3 [SI::degree];

        port loadInput : LoadPort;
        port diagnostics : DiagnosticPort;

        action indicateRemotePosition {
            in item loadMotion : ShaftRotation;
            out attribute displayedAngle : Angle;
        }
    }

    part def SelsynSystem {
        attribute operatingMode : SelsynOperatingMode = SelsynOperatingMode::idle;
        attribute commandedAngle : Angle;
        attribute indicatedAngle : Angle;
        attribute trackingError : Angle;
        attribute nominalExcitationVoltage : Voltage = 115 [SI::V];
        attribute nominalExcitationFrequency : Frequency = 400 [SI::Hz];

        part commandInput : CommandInputShaft;
        part transmitter : SelsynTransmitter;
        part referenceSupply : ACReferenceSupply;
        part interconnect : ThreeWireInterconnect;
        part receiver : SelsynReceiver;
        part remoteIndicator : RemoteIndicatorLoad;

        port commandShaft : MechanicalShaftPort;
        port indicatorOutput : LoadPort;
        port systemDiagnostics : DiagnosticPort;

        connect commandShaft to commandInput.shaftOutput;
        connect commandInput.shaftOutput to transmitter.shaft;
        connect referenceSupply.transmitterRotorOutput to transmitter.rotorPower;
        connect referenceSupply.receiverRotorOutput to receiver.rotorPower;
        connect transmitter.statorOutput to interconnect.transmitterEnd;
        connect interconnect.receiverEnd to receiver.statorInput;
        connect receiver.outputShaft to remoteIndicator.loadInput;
        connect remoteIndicator.loadInput to indicatorOutput;
        connect remoteIndicator.diagnostics to systemDiagnostics;

        action transmitAngularPosition {
            in item commandRotation : ShaftRotation;
            out item indicatedRotation : ShaftRotation;
            out item error : AlignmentError;

            first energizeRotors;
            then encodeCommandAngle;
            then transferThreeWireSignal;
            then driveReceiverToNull;
            then updateRemoteIndication;
            then reportTrackingError;

            action energizeRotors {
                out item transmitterExcitation : SinglePhaseExcitation;
                out item receiverExcitation : SinglePhaseExcitation;
            }

            action encodeCommandAngle {
                in item commandRotation : ShaftRotation;
                in item transmitterExcitation : SinglePhaseExcitation;
                out item statorSignal : ThreeWireStatorSignal;
            }

            action transferThreeWireSignal {
                in item statorSignal : ThreeWireStatorSignal;
                out item receivedSignal : ThreeWireStatorSignal;
            }

            action driveReceiverToNull {
                in item receivedSignal : ThreeWireStatorSignal;
                in item receiverExcitation : SinglePhaseExcitation;
                out item indicatedRotation : ShaftRotation;
            }

            action updateRemoteIndication {
                in item indicatedRotation : ShaftRotation;
                out attribute displayedAngle : Angle;
            }

            action reportTrackingError {
                in item commandRotation : ShaftRotation;
                in item indicatedRotation : ShaftRotation;
                out item error : AlignmentError;
            }
        }

        state def SystemOperatingState {
            state off;
            state energizing;
            state trackingCommandAngle;
            state holdingRemoteIndication;
            state faultDetected;

            transition first off;

            transition off_to_energizing
                first off
                then energizing
                if nominalExcitationVoltage >= 90 [SI::V];

            transition energizing_to_tracking
                first energizing
                then trackingCommandAngle
                if nominalExcitationFrequency >= 360 [SI::Hz] and nominalExcitationFrequency <= 440 [SI::Hz];

            transition tracking_to_holding
                first trackingCommandAngle
                then holdingRemoteIndication
                if abs(commandedAngle - indicatedAngle) <= remoteIndicator.allowableTrackingError;

            transition holding_to_tracking
                first holdingRemoteIndication
                then trackingCommandAngle
                if abs(commandedAngle - indicatedAngle) > remoteIndicator.allowableTrackingError;

            transition any_to_fault
                first trackingCommandAngle
                then faultDetected
                if nominalExcitationVoltage < 80 [SI::V];

            transition fault_to_off
                first faultDetected
                then off
                if nominalExcitationVoltage == 0 [SI::V];
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Selsyn system shall transmit the angular position of a local command shaft to a remote indicator shaft by converting rotor angle into three-wire stator voltages and producing synchronizing torque in the receiver until the remote shaft aligns with the command shaft. */
        subject selsynSystem : SelsynSystem;
        require constraint {
            abs(selsynSystem.commandedAngle - selsynSystem.indicatedAngle) <= 3 [SI::degree]
        }
    }

    requirement def CommonExcitationRequirement {
        doc /* The transmitter and receiver rotors shall be energized by a common single-phase AC reference so that the stator signal phase relationship represents mechanical angle consistently at both ends. */
        subject selsynSystem : SelsynSystem;
        require constraint {
            selsynSystem.nominalExcitationVoltage == 115 [SI::V] and
            selsynSystem.nominalExcitationFrequency == 400 [SI::Hz]
        }
    }

    requirement def ThreeWireTransmissionRequirement {
        doc /* The interconnect shall carry three stator signals separated electrically by 120 degrees to represent the transmitter rotor angle without requiring a local electrical amplifier. */
        subject interconnect : ThreeWireInterconnect;
        require constraint {
            interconnect.conductorCount == 3 and
            interconnect.phaseSeparation == 120 [SI::degree]
        }
    }

    requirement def PassiveFollowUpRequirement {
        doc /* The receiver shall convert the transmitted electrical angle into shaft motion by developing synchronizing torque that reduces angular error toward null. */
        subject receiver : SelsynReceiver;
        require constraint {
            receiver.maximumFollowUpError <= 2 [SI::degree]
        }
    }

    requirement def FaultResponseRequirement {
        doc /* The system shall enter a faulted operating mode when excitation voltage is below the minimum level required for reliable angle transmission. */
        subject selsynSystem : SelsynSystem;
        require constraint {
            selsynSystem.nominalExcitationVoltage >= 80 [SI::V]
        }
    }

    satisfy PrimaryFunctionRequirement by SelsynSystem::transmitAngularPosition;
    satisfy CommonExcitationRequirement by ACReferenceSupply::provideCommonReferenceExcitation;
    satisfy ThreeWireTransmissionRequirement by ThreeWireInterconnect::transferStatorSignal;
    satisfy PassiveFollowUpRequirement by SelsynReceiver::convertElectricalAngleToMotion;

    part selsynAngularPositionTransmissionSystem : SelsynSystem {
        attribute commandedAngle = 45 [SI::degree];
        attribute indicatedAngle = 45 [SI::degree];
        attribute trackingError = 0 [SI::degree];
        attribute operatingMode = SelsynOperatingMode::tracking;
    }
}