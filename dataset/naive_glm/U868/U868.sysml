package SelsynAngleTransmissionSystem {
    import ScalarValues::*;

    doc /* 
        Selsyn Angle Transmission System
        An electromechanical device that transmits the angular position of a 
        mechanical shaft to a remote location and replicates it precisely 
        without any direct mechanical linkage. Functions as an "electrical gearbox" 
        for remote control and position indication.
    */

    // ============ Value Types ============
    value def AngleDeg :> Real {
        doc /* Angular position in degrees. */
    }
    value def Voltage :> Real {
        doc /* Electrical potential in volts. */
    }
    value def Torque :> Real {
        doc /* Rotational force in newton-meters. */
    }
    value def Current :> Real {
        doc /* Electrical current in amperes. */
    }
    value def Frequency :> Real {
        doc /* AC frequency in hertz. */
    }
    value def AngularVelocity :> Real {
        doc /* Angular velocity in degrees per second. */
    }
    value def Power :> Real {
        doc /* Electrical power in watts. */
    }
    value def MagneticFieldStrength :> Real {
        doc /* Magnetic field strength in amperes per meter. */
    }
    value def WindingConstant :> Real {
        doc /* Electromechanical coupling constant. */
    }

    // ============ Item Types ============
    item def MechanicalRotation {
        attribute angle : AngleDeg;
        attribute angularVelocity : AngularVelocity;
    }

    item def ThreePhaseVoltage {
        attribute phaseA : Voltage;
        attribute phaseB : Voltage;
        attribute phaseC : Voltage;
        attribute frequency : Frequency;
    }

    item def ExcitationVoltage {
        attribute rms : Voltage;
        attribute frequency : Frequency;
    }

    item def TorqueSignal {
        attribute magnitude : Torque;
        attribute direction : Integer;
        doc /* direction: -1 = counterclockwise, 0 = none, +1 = clockwise */
    }

    // ============ Port Definitions ============
    port def MechanicalShaftPort {
        out item rotation : MechanicalRotation;
        in item reaction : TorqueSignal;
    }

    port def ThreePhaseSignalPort {
        inout item voltage : ThreePhaseVoltage;
    }

    port def ACExcitationPort {
        inout item excitation : ExcitationVoltage;
    }

    // ============ Requirements ============
    requirement def TransmissionAccuracyRequirement {
        doc /* The output shaft angle shall match the input shaft angle within a specified tolerance. */
        attribute maxError : AngleDeg = 1.0;
        subject inputAngle : AngleDeg;
        subject outputAngle : AngleDeg;
        constraint { (outputAngle - inputAngle <= maxError) and (inputAngle - outputAngle <= maxError) }
    }

    requirement def SelfSynchronizationRequirement {
        doc /* The system shall automatically synchronize the receiver to the transmitter without external control signals. */
        attribute maxSettlingTime : Real = 2.0;
    }

    requirement def ContinuousTrackingRequirement {
        doc /* The output shaft shall continuously track the input shaft angle during rotation. */
        attribute maxLatency : Real = 0.1;
        attribute maxInputSpeed : AngularVelocity = 360.0;
    }

    requirement def PowerSupplyRequirement {
        doc /* Both transmitter and receiver shall be energized by a common AC power source. */
        attribute nominalVoltage : Voltage = 110.0;
        attribute nominalFrequency : Frequency = 60.0;
        attribute voltageTolerance : Real = 0.05;
    }

    requirement def CorrectiveTorqueRequirement {
        doc /* The receiver shall generate corrective torque proportional to the angular error. */
        attribute minTorqueConstant : WindingConstant = 0.01;
        attribute maxStallTorque : Torque = 10.0;
    }

    // ============ Component Parts ============

    part def InputShaft {
        doc /* Mechanical shaft whose angular position is to be transmitted. */
        attribute currentAngle : AngleDeg = 0.0;
        attribute angularVelocity : AngularVelocity = 0.0;
        attribute maxInputTorque : Torque = 5.0;

        port out shaftOutput : MechanicalShaftPort;

        action def RotateTo {
            in targetAngle : AngleDeg;
            in speed : AngularVelocity;
            doc /* Mechanically rotates the input shaft to the target angle. */
        }

        action def DriveTransmitter {
            out rotation : MechanicalRotation;
            doc /* Outputs the current shaft angle and velocity to the transmitter. */
        }
    }

    part def OutputShaft {
        doc /* Mechanical shaft that replicates the remote input shaft position. */
        attribute currentAngle : AngleDeg = 0.0;
        attribute angularVelocity : AngularVelocity = 0.0;
        attribute loadTorque : Torque = 0.0;
        attribute maxLoadTorque : Torque = 3.0;

        port in shaftInput : MechanicalShaftPort;

        action def FollowInput {
            in targetAngle : AngleDeg;
            in correctiveTorque : TorqueSignal;
            doc /* Rotates under corrective torque to match the target angle. */
        }

        action def Settle {
            doc /* Damps oscillation once synchronized. */
        }
    }

    part def RotorWinding {
        doc /* Excited rotor winding that produces a magnetic field aligned with the rotor angle. */
        attribute windingResistance : Real = 10.0;
        attribute excitationRMS : Voltage = 0.0;
        attribute excitationFreq : Frequency = 0.0;
        attribute rotorAngle : AngleDeg = 0.0;
        attribute couplingConstant : WindingConstant = 1.0;

        port in acInput : ACExcitationPort;

        action def GenerateMagneticField {
            in excitation : ExcitationVoltage;
            in angle : AngleDeg;
            out fieldStrength : MagneticFieldStrength;
            doc /* Produces a magnetic field aligned with the rotor angle, proportional to excitation voltage. */
        }
    }

    part def StatorWinding {
        doc /* Three-phase stator winding with 120-degree spatial separation between phases. */
        attribute phaseAResistance : Real = 5.0;
        attribute phaseBResistance : Real = 5.0;
        attribute phaseCResistance : Real = 5.0;
        attribute phaseAVoltage : Voltage = 0.0;
        attribute phaseBVoltage : Voltage = 0.0;
        attribute phaseCVoltage : Voltage = 0.0;
        attribute turnsRatio : Real = 1.0;

        port out threePhaseOutput : ThreePhaseSignalPort;
        port in threePhaseInput : ThreePhaseSignalPort;

        action def InducePhaseVoltages {
            in rotorAngle : AngleDeg;
            in excitation : ExcitationVoltage;
            out voltage : ThreePhaseVoltage;
            doc /* 
                Induces three-phase voltages in the stator windings based on the 
                rotor angle. Each phase voltage is proportional to:
                V_phase = K * V_exc * cos(rotorAngle - phaseOffset)
                where phaseOffset is 0, 120, 240 degrees for phases A, B, C.
            */
        }

        action def ReceivePhaseVoltages {
            in voltage : ThreePhaseVoltage;
            doc /* Receives three-phase voltages from the remote transmitter stator. */
        }
    }

    part def SelsynTransmitterUnit {
        doc /* 
            Selsyn transmitter: converts the mechanical angle of the input shaft 
            into a unique set of three-phase electrical voltage signals.
        */
        attribute rotorAngle : AngleDeg = 0.0;
        attribute transmittedVoltage : ThreePhaseVoltage;
        attribute isEnergized : Boolean = false;
        attribute couplingConstant : WindingConstant = 1.0;

        port in mechanicalInput : MechanicalShaftPort;
        port in acInput : ACExcitationPort;
        port out threePhaseOutput : ThreePhaseSignalPort;

        part rotor : RotorWinding {
            port in acInput : ACExcitationPort;
        }
        part stator : StatorWinding {
            port out threePhaseOutput : ThreePhaseSignalPort;
        }

        connection acToRotor connect acInput to rotor.acInput;

        action def ConvertAngleToVoltage {
            in shaftAngle : AngleDeg;
            in excitation : ExcitationVoltage;
            out threePhase : ThreePhaseVoltage;
            doc /* 
                Converts the mechanical shaft angle into three-phase stator voltages.
                Phase A: V_A = K * V_exc * cos(shaftAngle)
                Phase B: V_B = K * V_exc * cos(shaftAngle - 120)
                Phase C: V_C = K * V_exc * cos(shaftAngle - 240)
            */
        }

        action def UpdateRotorAngle {
            in rotation : MechanicalRotation;
            doc /* Synchronizes the internal rotor angle with the input shaft angle. */
        }

        exhibit state behavior {
            initial state DeEnergized;
            state Energized;
            state Transmitting;

            transition from DeEnergized to Energized
                when acInput.excitation.rms > 0.0;
            transition from Energized to Transmitting
                when mechanicalInput.rotation.angle != rotorAngle;
            transition from Transmitting to Energized
                when mechanicalInput.rotation.angle == rotorAngle;
        }
    }

    part def SelsynReceiverUnit {
        doc /* 
            Selsyn receiver: interprets the three-phase signals from the transmitter,
            generates corrective torque when misaligned, and drives its shaft to 
            match the transmitter's angle.
        */
        attribute rotorAngle : AngleDeg = 0.0;
        attribute receivedVoltage : ThreePhaseVoltage;
        attribute correctiveTorque : Torque = 0.0;
        attribute errorAngle : AngleDeg = 0.0;
        attribute isEnergized : Boolean = false;
        attribute torqueConstant : WindingConstant = 0.05;
        attribute maxStallTorque : Torque = 10.0;

        port in threePhaseInput : ThreePhaseSignalPort;
        port in acInput : ACExcitationPort;
        port out mechanicalOutput : MechanicalShaftPort;

        part rotor : RotorWinding {
            port in acInput : ACExcitationPort;
        }
        part stator : StatorWinding {
            port in threePhaseInput : ThreePhaseSignalPort;
        }

        connection acToRotor connect acInput to rotor.acInput;

        action def ComputeErrorAngle {
            in receivedVoltage : ThreePhaseVoltage;
            in currentRotorAngle : AngleDeg;
            out errorAngle : AngleDeg;
            doc /* 
                Computes the angular error between the transmitter angle 
                (encoded in the received three-phase voltage) and the 
                receiver's current rotor angle.
            */
        }

        action def GenerateCorrectiveTorque {
            in errorAngle : AngleDeg;
            in excitation : ExcitationVoltage;
            out torque : TorqueSignal;
            doc /* 
                Generates corrective torque proportional to sin(errorAngle).
                Torque magnitude = K_t * V_exc * sin(errorAngle).
                Direction is determined by the sign of the error angle.
            */
        }

        action def AlignShaft {
            in torque : TorqueSignal;
            out rotation : MechanicalRotation;
            doc /* Rotates the receiver rotor under corrective torque until alignment is achieved. */
        }

        action def DampOscillation {
            doc /* Applies damping to prevent overshoot during synchronization. */
        }

        exhibit state behavior {
            initial state DeEnergized;
            state Energized;
            state Synchronized;
            state Correcting;
            state Damping;

            transition from DeEnergized to Energized
                when acInput.excitation.rms > 0.0;
            transition from Energized to Synchronized
                when abs(errorAngle) < 0.5;
            transition from Synchronized to Correcting
                when abs(errorAngle) >= 0.5;
            transition from Correcting to Damping
                when abs(errorAngle) < 1.0 and abs(correctiveTorque) > 0.0;
            transition from Damping to Synchronized
                when abs(errorAngle) < 0.5 and correctiveTorque == 0.0;
            transition from Damping to Correcting
                when abs(errorAngle) >= 1.0;
        }
    }

    part def ACPowerSource {
        doc /* Common AC power source that excites the rotor windings of both transmitter and receiver. */
        attribute nominalVoltage : Voltage = 110.0;
        attribute nominalFrequency : Frequency = 60.0;
        attribute maxPower : Power = 50.0;
        attribute voltageTolerance : Real = 0.05;
        attribute isOn : Boolean = false;

        port out acOutput : ACExcitationPort;

        action def SupplyExcitation {
            out excitation : ExcitationVoltage;
            doc /* Provides AC excitation voltage to energize rotor windings. */
        }

        action def PowerOn {
            doc /* Activates the AC power source. */
        }

        action def PowerOff {
            doc /* Deactivates the AC power source. */
        }

        exhibit state behavior {
            initial state Off;
            state On;

            transition from Off to On when isOn == true;
            transition from On to Off when isOn == false;
        }
    }

    // ============ Wiring Harness ============
    part def ThreePhaseWiringHarness {
        doc /* Three-conductor wiring that carries the three-phase voltage signals between transmitter and receiver. */
        attribute wireResistance : Real = 0.5;
        attribute wireLength : Real = 50.0;
        attribute conductorGauge : Integer = 14;

        port in transmitterSide : ThreePhaseSignalPort;
        port out receiverSide : ThreePhaseSignalPort;

        action def TransmitSignals {
            in voltage : ThreePhaseVoltage;
            out voltage : ThreePhaseVoltage;
            doc /* Conducts the three-phase voltage signals from transmitter to receiver with minimal loss. */
        }
    }

    // ============ Top-Level System ============
    part def SelsynAngleTransmissionSystem {
        doc /* 
            Complete Selsyn Angle Transmission System.
            Transmits angular position from an input shaft to a remote output shaft 
            without mechanical linkage, using electromagnetic principles.
        */

        requirement transmissionAccuracy : TransmissionAccuracyRequirement;
        requirement selfSynchronization : SelfSynchronizationRequirement;
        requirement continuousTracking : ContinuousTrackingRequirement;
        requirement powerSupply : PowerSupplyRequirement;
        requirement correctiveTorque : CorrectiveTorqueRequirement;

        attribute systemName : String = "Selsyn Angle Transmission System";
        attribute maxTransmissionDistance : Real = 100.0;

        part inputShaft : InputShaft;
        part transmitter : SelsynTransmitterUnit;
        part wiringHarness : ThreePhaseWiringHarness;
        part receiver : SelsynReceiverUnit;
        part outputShaft : OutputShaft;
        part powerSource : ACPowerSource;

        // ---- Connections ----
        connection inputShaftToTransmitter
            connect inputShaft.shaftOutput to transmitter.mechanicalInput;

        connection powerToTransmitter
            connect powerSource.acOutput to transmitter.acInput;

        connection powerToReceiver
            connect powerSource.acOutput to receiver.acInput;

        connection transmitterToWiring
            connect transmitter.threePhaseOutput to wiringHarness.transmitterSide;

        connection wiringToReceiver
            connect wiringHarness.receiverSide to receiver.threePhaseInput;

        connection receiverToOutput
            connect receiver.mechanicalOutput to outputShaft.shaftInput;

        // ---- System-Level Operation ----
        action def SystemOperation {
            doc /* Continuous operation of the Selsyn transmission system. */
            parallel {
                action SupplyPower {
                    out excitation : ExcitationVoltage;
                    doc /* AC power source energizes both rotor windings. */
                }
                action SenseInputAngle {
                    in rotation : MechanicalRotation;
                    out angle : AngleDeg;
                    doc /* Input shaft angle is sensed by the transmitter. */
                }
                action EncodeAngle {
                    in angle : AngleDeg;
                    in excitation : ExcitationVoltage;
                    out voltage : ThreePhaseVoltage;
                    doc /* Transmitter encodes the angle as three-phase voltages. */
                }
                action TransmitSignals {
                    in voltage : ThreePhaseVoltage;
                    out voltage : ThreePhaseVoltage;
                    doc /* Three-phase signals transmitted over wiring. */
                }
                action DecodeAngle {
                    in voltage : ThreePhaseVoltage;
                    out errorAngle : AngleDeg;
                    doc /* Receiver decodes the angle and computes error. */
                }
                action GenerateTorque {
                    in errorAngle : AngleDeg;
                    in excitation : ExcitationVoltage;
                    out torque : TorqueSignal;
                    doc /* Corrective torque generated proportional to error. */
                }
                action DriveOutput {
                    in torque : TorqueSignal;
                    out rotation : MechanicalRotation;
                    doc /* Output shaft rotates to match input angle. */
                }
            }
        }

        exhibit action behavior : SystemOperation;

        // ---- System State Machine ----
        exhibit state behavior {
            initial state PoweredOff;
            state Initializing;
            state Operating;
            state Faulted;

            transition from PoweredOff to Initializing
                when powerSource.isOn == true;
            transition from Initializing to Operating
                when powerSource.acOutput.excitation.rms > 0.0;
            transition from Operating to PoweredOff
                when powerSource.isOn == false;
            transition from Operating to Faulted
                when receiver.correctiveTorque > receiver.maxStallTorque;
            transition from Faulted to PoweredOff
                when powerSource.isOn == false;
        }
    }
}
