package PhotomultiplierSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Energy :> Real { unit 'eV'; }
    value type Wavelength :> Real { unit 'nm'; }
    value type ElectronCount :> Integer;
    value type Gain :> Real;
    value type PulseAmplitude :> Real { unit 'mV'; }
    value type PulseWidth :> Real { unit 'ns'; }
    value type Pressure :> Real { unit 'mPa'; }
    value type Temperature :> Real { unit 'K'; }
    value type CountRate :> Real { unit 'cps'; }

    // ===== Item Definitions =====
    item def Photon {
        attribute wavelength : Wavelength;
        attribute energy : Energy;
    }

    item def Electron {
        attribute charge : Real = -1.602e-19 [unit 'C'];
    }

    item def Photoelectron :> Electron;

    item def SecondaryElectron :> Electron;

    item def ElectronBurst {
        attribute electronCount : ElectronCount;
    }

    item def ElectricalPulse {
        attribute amplitude : PulseAmplitude;
        attribute width : PulseWidth;
        attribute isValid : Boolean;
    }

    item def PhotonEvent {
        attribute timestamp : Real;
        attribute photon : Photon;
        attribute pulse : ElectricalPulse;
    }

    // ===== Port Definitions =====
    port def PhotonInputPort {
        attribute acceptedWavelengthRange : Wavelength[0..1];
        in item photons : Photon[*];
    }

    port def ElectronFlowPort {
        in item electrons : Electron[*];
        out item emittedElectrons : Electron[*];
    }

    port def HVPort {
        out voltage : Voltage;
        out current : Current;
    }

    port def HVInputPort {
        in voltage : Voltage;
    }

    port def SignalPort {
        out pulse : ElectricalPulse;
    }

    port def SignalInputPort {
        in pulse : ElectricalPulse;
    }

    port def LogicOutputPort {
        out event : PhotonEvent;
    }

    // ===== Requirements =====
    requirement def PhotomultiplierSystemRequirements {
        requirement SinglePhotonSensitivity {
            doc /* The system shall be capable of detecting a single photon incident on the photocathode. */
            constraint { gain >= 1.0e6 }
        }
        requirement HVStability {
            doc /* The high voltage supply shall provide a stable 1200 V output. */
            constraint { hvOutput == 1200 [unit 'V'] }
            attribute hvOutput : Voltage;
        }
        requirement DynodeChainCount {
            doc /* The PMT shall contain exactly eight dynodes in the multiplication chain. */
            constraint { dynodeCount == 8 }
            attribute dynodeCount : Integer;
        }
        requirement VacuumIntegrity {
            doc /* The vacuum envelope shall maintain pressure below 1 mPa. */
            constraint { internalPressure < 1.0 [unit 'mPa'] }
            attribute internalPressure : Pressure;
        }
        requirement NoiseRejection {
            doc /* The discriminator shall reject pulses below a threshold amplitude representing noise. */
            constraint { thresholdAmplitude >= 5.0 [unit 'mV'] }
            attribute thresholdAmplitude : PulseAmplitude;
        }
        requirement SpectralResponse {
            doc /* The photocathode shall respond to photons in the 300-650 nm range. */
            constraint { minWavelength >= 300 [unit 'nm'] and maxWavelength <= 650 [unit 'nm'] }
            attribute minWavelength : Wavelength;
            attribute maxWavelength : Wavelength;
        }
    }

    // ===== Photocathode =====
    part def Photocathode {
        attribute material : String = "Bialkali";
        attribute quantumEfficiency : Real = 0.25;
        port electronOut : ElectronFlowPort;
        port hvBias : HVInputPort;

        action def ConvertPhoton :> Action {
            in photon : Photon;
            out photoelectron : Photoelectron[0..1];
            perform {
                if photon.energy >= 2.0 [unit 'eV'] {
                    photoelectron = Photoelectron();
                } else {
                    photoelectron = ();
                }
            }
        }

        perform action convert : ConvertPhoton;
    }

    // ===== Dynode =====
    part def Dynode {
        attribute stageIndex : Integer;
        attribute secondaryEmissionCoefficient : Real = 4.0;
        port electronIn : ElectronFlowPort;
        port electronOut : ElectronFlowPort;
        port hvBias : HVInputPort;

        action def Multiply :> Action {
            in incoming : Electron[*];
            out outgoing : SecondaryElectron[*];
            perform {
                outgoing = SecondaryElectron[incoming.size * secondaryEmissionCoefficient];
            }
        }

        perform action multiply : Multiply;
    }

    // ===== Anode =====
    part def Anode {
        attribute collectionEfficiency : Real = 0.95;
        port electronIn : ElectronFlowPort;
        port signalOut : SignalPort;

        action def CollectElectrons :> Action {
            in burst : ElectronBurst;
            out pulse : ElectricalPulse;
            perform {
                pulse = ElectricalPulse(
                    amplitude = burst.electronCount * 1.0e-6 [unit 'mV'],
                    width = 10.0 [unit 'ns'],
                    isValid = true
                );
            }
        }

        perform action collect : CollectElectrons;
    }

    // ===== Vacuum Envelope =====
    part def VacuumEnvelope {
        attribute material : String = "Borosilicate Glass";
        attribute internalPressure : Pressure = 0.1 [unit 'mPa'];
        attribute operatingTemperature : Temperature = 300.0 [unit 'K'];
    }

    // ===== Window =====
    part def OpticalWindow {
        attribute material : String = "Borosilicate Glass";
        attribute transmittance : Real = 0.92;
        attribute thickness : Real = 2.0 [unit 'mm'];
        port photonIn : PhotonInputPort;
        port photonOut : PhotonInputPort;
    }

    // ===== Photomultiplier Tube =====
    part def PhotomultiplierTube {
        attribute overallGain : Gain = 6.5e6;
        attribute dynodeCount : Integer = 8;

        port photonPort : PhotonInputPort {
            attribute acceptedWavelengthRange = (300.0 [unit 'nm'], 650.0 [unit 'nm']);
        }
        port hvPort : HVInputPort;
        port signalPort : SignalPort;

        part envelope : VacuumEnvelope;
        part window : OpticalWindow {
            port photonIn : PhotonInputPort;
            port photonOut : PhotonInputPort;
        }
        part photocathode : Photocathode;
        part dynodes : Dynode[8] {
            attribute stageIndex = index + 1;
        }
        part anode : Anode;

        connection def ElectronCascade :> Connection {
            end source : ElectronFlowPort;
            end target : ElectronFlowPort;
        }

        connection photonEntry : PhotonInputPort connect window.photonIn to photonPort;
        connection photonToCathode : PhotonInputPort connect window.photonOut to photocathode.electronOut;
        connection cathodeToDynode1 : ElectronCascade connect photocathode.electronOut to dynodes[1].electronIn;
        connection dynodeChain : ElectronCascade connect dynodes[1].electronOut to dynodes[2].electronIn;
        connection dynodeChain2 : ElectronCascade connect dynodes[2].electronOut to dynodes[3].electronIn;
        connection dynodeChain3 : ElectronCascade connect dynodes[3].electronOut to dynodes[4].electronIn;
        connection dynodeChain4 : ElectronCascade connect dynodes[4].electronOut to dynodes[5].electronIn;
        connection dynodeChain5 : ElectronCascade connect dynodes[5].electronOut to dynodes[6].electronIn;
        connection dynodeChain6 : ElectronCascade connect dynodes[6].electronOut to dynodes[7].electronIn;
        connection dynodeChain7 : ElectronCascade connect dynodes[7].electronOut to dynodes[8].electronIn;
        connection dynodeToAnode : ElectronCascade connect dynodes[8].electronOut to anode.electronIn;
        connection anodeSignal : SignalPort connect anode.signalOut to signalPort;

        // HV distribution to internal components
        connection hvToCathode : HVInputPort connect hvPort to photocathode.hvBias;
        connection hvToDynodes : HVInputPort connect hvPort to dynodes.hvBias;
        connection hvToAnode : HVInputPort connect hvPort to anode.electronIn;

        // State machine for PMT operation
        state def PMTOperationState;
        state machine PMTOperation : PMTOperationState {
            state Idle;
            state PhotonDetected;
            state Cascading;
            state SignalOutput;
            state Reset;

            transition init to Idle;
            transition Idle to PhotonDetected when photonPort.photons->notEmpty();
            transition PhotonDetected to Cascading when photocathode.convert.photoelectron->notEmpty();
            transition Cascading to SignalOutput when anode.collect.pulse.isValid;
            transition SignalOutput to Reset;
            transition Reset to Idle;
        }

        perform state machine operation : PMTOperation;
    }

    // ===== High Voltage Supply =====
    part def HighVoltageSupply {
        attribute outputVoltage : Voltage = 1200.0 [unit 'V'];
        attribute outputCurrent : Current = 5.0e-3 [unit 'A'];
        attribute ripple : Real = 5.0e-4 [unit 'V'];
        attribute stability : Real = 0.01;
        port hvOutput : HVPort;

        state def HVState;
        state machine HVOperation : HVState {
            state Off;
            state Ramping;
            state Stable;
            state Fault;

            transition init to Off;
            transition Off to Ramping when enabled;
            transition Ramping to Stable when hvOutput.voltage >= 1200.0 [unit 'V'];
            transition Stable to Fault when outputCurrent > 10.0e-3 [unit 'A'];
            transition Fault to Off when reset;
        }

        perform state machine hvStateMachine : HVOperation;
    }

    // ===== Voltage Divider Network =====
    part def VoltageDividerNetwork {
        attribute totalResistance : Real = 10.0e6 [unit 'ohm'];
        attribute resistorCount : Integer = 10;
        attribute stageVoltages : Voltage[9];
        port hvInput : HVInputPort;
        port dynodeOutputs : HVInputPort[8];
        port cathodeOutput : HVInputPort;
        port anodeOutput : HVInputPort;

        action def DistributeVoltage :> Action {
            in inputVoltage : Voltage;
            out stageVoltageOut : Voltage[8];
            perform {
                var step : Voltage = inputVoltage / 9.0;
                for i in 1..8 {
                    stageVoltageOut[i] = step * i;
                }
            }
        }

        perform action distribute : DistributeVoltage;
    }

    // ===== Pre-Amplifier =====
    part def PreAmplifier {
        attribute gain : Gain = 100.0;
        attribute bandwidth : Real = 500.0e6 [unit 'Hz'];
        attribute noiseFigure : Real = 1.5;
        port signalIn : SignalInputPort;
        port signalOut : SignalPort;

        action def Amplify :> Action {
            in inputPulse : ElectricalPulse;
            out outputPulse : ElectricalPulse;
            perform {
                outputPulse = ElectricalPulse(
                    amplitude = inputPulse.amplitude * gain,
                    width = inputPulse.width,
                    isValid = inputPulse.isValid
                );
            }
        }

        perform action amplify : Amplify;
    }

    // ===== Discriminator =====
    part def Discriminator {
        attribute threshold : PulseAmplitude = 10.0 [unit 'mV'];
        attribute deadTime : Real = 20.0 [unit 'ns'];
        port signalIn : SignalInputPort;
        port logicOut : LogicOutputPort;

        action def Discriminate :> Action {
            in inputPulse : ElectricalPulse;
            out event : PhotonEvent[0..1];
            perform {
                if inputPulse.amplitude >= threshold {
                    event = PhotonEvent(
                        timestamp = 0.0,
                        photon = Photon(wavelength = 400.0 [unit 'nm'], energy = 3.1 [unit 'eV']),
                        pulse = inputPulse
                    );
                } else {
                    event = ();
                }
            }
        }

        perform action discriminate : Discriminate;

        state def DiscriminatorState;
        state machine DiscriminatorOperation : DiscriminatorState {
            state Ready;
            state Processing;
            state DeadTime;

            transition init to Ready;
            transition Ready to Processing when signalIn.pulse->notEmpty();
            transition Processing to DeadTime when discriminate.event->notEmpty();
            transition DeadTime to Ready after 20.0 [unit 'ns'];
        }

        perform state machine discStateMachine : DiscriminatorOperation;
    }

    // ===== Top-level Photomultiplier System =====
    part def PhotomultiplierSystem {
        requirement ref systemReqs : PhotomultiplierSystemRequirements {
            attribute hvOutput = 1200.0 [unit 'V'];
            attribute dynodeCount = 8;
            attribute internalPressure = 0.1 [unit 'mPa'];
            attribute thresholdAmplitude = 10.0 [unit 'mV'];
            attribute minWavelength = 300.0 [unit 'nm'];
            attribute maxWavelength = 650.0 [unit 'nm'];
        }

        attribute systemGain : Gain = 6.5e8;
        attribute detectionEfficiency : Real = 0.23;

        port lightInput : PhotonInputPort;
        port eventOutput : LogicOutputPort;

        part hvSupply : HighVoltageSupply;
        part voltageDivider : VoltageDividerNetwork;
        part pmt : PhotomultiplierTube;
        part preamp : PreAmplifier;
        part discriminator : Discriminator;

        // Connections
        connection lightToPMT : PhotonInputPort connect lightInput to pmt.photonPort;
        connection hvToDivider : HVPort connect hvSupply.hvOutput to voltageDivider.hvInput;
        connection dividerToCathode : HVInputPort connect voltageDivider.cathodeOutput to pmt.hvPort;
        connection dividerToDynodes : HVInputPort connect voltageDivider.dynodeOutputs to pmt.hvPort;
        connection pmtToPreamp : SignalPort connect pmt.signalPort to preamp.signalIn;
        connection preampToDisc : SignalPort connect preamp.signalOut to discriminator.signalIn;
        connection discToOutput : LogicOutputPort connect discriminator.logicOut to eventOutput;

        // System-level state machine
        state def SystemState;
        state machine SystemOperation : SystemState {
            state PoweredOff;
            state Initializing;
            state Operational;
            state Calibrating;
            state ErrorState;

            transition init to PoweredOff;
            transition PoweredOff to Initializing when powerOn;
            transition Initializing to Operational when hvSupply.hvOutput.voltage >= 1200.0 [unit 'V'];
            transition Operational to Calibrating when calibrateRequested;
            transition Calibrating to Operational when calibrationComplete;
            transition Operational to ErrorState when hvSupply.hvOutput.voltage < 1100.0 [unit 'V'];
            transition ErrorState to PoweredOff when shutdown;
        }

        perform state machine systemStateMachine : SystemOperation;

        // System-level action for full detection cycle
        action def FullDetectionCycle :> Action {
            in incomingPhoton : Photon;
            out detectedEvent : PhotonEvent[0..1];
            perform {
                var pe : Photoelectron[0..1] = pmt.photocathode.convert(incomingPhoton);
                if pe->isEmpty() { detectedEvent = (); return; }
                var burst : ElectronBurst = ElectronBurst(electronCount = 1);
                for i in 1..8 {
                    burst = ElectronBurst(electronCount = burst.electronCount * 4);
                }
                var rawPulse : ElectricalPulse = pmt.anode.collect(burst);
                var amplifiedPulse : ElectricalPulse = preamp.amplify(rawPulse);
                detectedEvent = discriminator.discriminate(amplifiedPulse);
            }
        }

        perform action detectionCycle : FullDetectionCycle;
    }
}
