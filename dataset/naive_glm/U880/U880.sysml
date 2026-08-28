package SPAD_System {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // ============================================================
    //  Value Types (with units)
    // ============================================================
    attribute def Voltage :> Real { unit "V"; }
    attribute def Current :> Real { unit "A"; }
    attribute def Temperature :> Real { unit "K"; }
    attribute def Duration :> Real { unit "s"; }
    attribute def Frequency :> Real { unit "Hz"; }
    attribute def Count :> Integer;
    attribute def Probability :> Real;
    attribute def Wavelength :> Real { unit "nm"; }
    attribute def Energy :> Real { unit "eV"; }

    // ============================================================
    //  Item Definitions
    // ============================================================
    item def Photon {
        attribute wavelength : Wavelength;
        attribute energy : Energy;
    }

    item def ElectronHolePair;

    item def BiasVoltageSignal {
        attribute magnitude : Voltage;
        attribute ripple : Voltage;
    }

    item def AvalancheCurrentPulse {
        attribute peakCurrent : Current;
        attribute riseTime : Duration;
        attribute width : Duration;
        attribute charge : Real { unit "C"; }
    }

    item def CoolingState {
        attribute temperature : Temperature;
        attribute stability : Temperature;
    }

    item def QuenchControlSignal {
        attribute quenchVoltage : Voltage;
        attribute resetVoltage : Voltage;
        attribute quenchDuration : Duration;
    }

    item def DigitalOutputPulse {
        attribute timestamp : Duration;
        attribute pulseWidth : Duration;
        attribute logicHigh : Boolean = true;
        attribute amplitude : Voltage;
    }

    // ============================================================
    //  Port Definitions
    // ============================================================
    port def PhotonInPort { in item : Photon; }
    port def BiasVoltageInPort { in item : BiasVoltageSignal; }
    port def CoolingInPort { in item : CoolingState; }
    port def QuenchControlInPort { in item : QuenchControlSignal; }
    port def AvalancheOutPort { out item : AvalancheCurrentPulse; }
    port def AvalancheInPort { in item : AvalancheCurrentPulse; }
    port def QuenchControlOutPort { out item : QuenchControlSignal; }
    port def DigitalOutPort { out item : DigitalOutputPulse; }
    port def DigitalInPort { in item : DigitalOutputPulse; }

    // ============================================================
    //  Requirements
    // ============================================================
    requirement def DetectSinglePhoton {
        doc "The SPAD system shall convert the arrival of a single photon into a measurable, macroscopic electrical signal.";
        subject detector : SPAD_System;
        attribute singlePhotonSensitivity : Boolean = true;
        require detector.singlePhotonSensitivity == true;
    }

    requirement def MaintainBiasAboveBreakdown {
        doc "The bias supply shall maintain the diode at a voltage just above its breakdown point.";
        subject supply : BiasSupply;
        attribute breakdownVoltage : Voltage = 25.0;
        attribute biasMargin : Voltage = 3.0;
        require supply.nominalBias > breakdownVoltage;
        require (supply.nominalBias - breakdownVoltage) <= biasMargin;
    }

    requirement def StabilizeTemperature {
        doc "The cooling system shall keep the diode at a low, stable temperature to reduce dark counts.";
        subject cooler : CoolingSystem;
        attribute targetTemperature : Temperature = 233.0;
        attribute tolerance : Temperature = 1.0;
        require abs(cooler.operatingTemperature - targetTemperature) <= tolerance;
    }

    requirement def LimitDarkCounts {
        doc "The system shall limit dark count rate caused by thermal noise.";
        subject detector : SPAD_System;
        attribute maxDarkCountRate : Frequency = 1000.0;
        require detector.darkCountRate <= maxDarkCountRate;
    }

    requirement def QuenchAndReset {
        doc "The passive quenching circuit shall quench the avalanche and reset the diode within the specified dead time.";
        subject quencher : PassiveQuenchingCircuit;
        attribute maxDeadTime : Duration = 50.0e-9;
        require quencher.deadTime <= maxDeadTime;
    }

    requirement def ProduceTimestampedDigitalOutput {
        doc "The discriminator shall produce a clean, standardized digital output pulse with a precise timestamp.";
        subject disc : DiscriminatorCircuit;
        attribute maxJitter : Duration = 50.0e-12;
        require disc.timingJitter <= maxJitter;
    }

    // ============================================================
    //  Part: SPAD Diode
    // ============================================================
    part def SPADDiode {
        port photonPort : PhotonInPort;
        port biasPort : BiasVoltageInPort;
        port coolingPort : CoolingInPort;
        port quenchPort : QuenchControlInPort;
        port avalanchePort : AvalancheOutPort;

        attribute breakdownVoltage : Voltage = 25.0;
        attribute operatingVoltage : Voltage = 28.0;
        attribute quenchVoltage : Voltage = 20.0;
        attribute darkCountRate : Frequency = 100.0;
        attribute quantumEfficiency : Probability = 0.40;
        attribute junctionTemperature : Temperature = 233.0;

        exhibit state DiodeStateMachine {
            entry;

            state Ready {
                doc "Diode biased above breakdown, in a highly sensitive ready state.";
                entry {
                    junctionTemperature := 233.0;
                }
            }

            state Avalanche {
                doc "Self-sustaining cascade of electrons triggered by an absorbed photon.";
                entry {
                    send AvalancheCurrentPulse(
                        peakCurrent = 5.0e-3,
                        riseTime = 0.5e-9,
                        width = 5.0e-9,
                        charge = 25.0e-12
                    ) via avalanchePort;
                }
            }

            state Quenched {
                doc "Avalanche stopped by lowering the voltage across the diode.";
                entry {
                    operatingVoltage := quenchVoltage;
                }
            }

            state DeadTime {
                doc "Detector temporarily blind while bias is restored.";
            }

            transition from Ready to Avalanche
                when photonPort::Photon is received;

            transition from Avalanche to Quenched
                when quenchPort::QuenchControlSignal is received;

            transition from Quenched to DeadTime
                after 10.0e-9;

            transition from DeadTime to Ready
                after 40.0e-9
                do {
                    operatingVoltage := 28.0;
                };
        }
    }

    // ============================================================
    //  Part: Bias Supply
    // ============================================================
    part def BiasSupply {
        port biasOut : out item BiasVoltageSignal;

        attribute nominalBias : Voltage = 28.0;
        attribute ripple : Voltage = 0.01;
        attribute stability : Voltage = 0.005;

        satisfy MaintainBiasAboveBreakdown;

        exhibit action GenerateBias {
            doc "Continuously supply a precise bias voltage just above breakdown.";
            while true {
                send BiasVoltageSignal(
                    magnitude = nominalBias,
                    ripple = ripple
                ) via biasOut;
            }
        }
    }

    // ============================================================
    //  Part: Cooling System
    // ============================================================
    part def CoolingSystem {
        port coolingOut : out item CoolingState;

        attribute operatingTemperature : Temperature = 233.0;
        attribute targetTemperature : Temperature = 233.0;
        attribute stability : Temperature = 0.5;
        attribute coolingCapacity : Real { unit "W"; } = 2.0;

        satisfy StabilizeTemperature;

        exhibit action RegulateTemperature {
            doc "Maintain the diode at a low, stable temperature to suppress dark counts.";
            while true {
                if operatingTemperature > targetTemperature {
                    operatingTemperature := operatingTemperature - 0.1;
                }
                send CoolingState(
                    temperature = operatingTemperature,
                    stability = stability
                ) via coolingOut;
            }
        }
    }

    // ============================================================
    //  Part: Passive Quenching Circuit
    // ============================================================
    part def PassiveQuenchingCircuit {
        port avalancheIn : AvalancheInPort;
        port quenchOut : QuenchControlOutPort;
        port pulseOut : out item AvalancheCurrentPulse;

        attribute quenchVoltage : Voltage = 20.0;
        attribute resetVoltage : Voltage = 28.0;
        attribute quenchDuration : Duration = 10.0e-9;
        attribute resetDuration : Duration = 40.0e-9;
        attribute deadTime : Duration = 50.0e-9;

        satisfy QuenchAndReset;

        exhibit state QuenchStateMachine {
            entry;

            state Monitoring {
                doc "Waiting for an avalanche current pulse from the diode.";
            }

            state Quenching {
                doc "Lower the voltage across the diode to stop the avalanche.";
                entry {
                    send QuenchControlSignal(
                        quenchVoltage = quenchVoltage,
                        resetVoltage = resetVoltage,
                        quenchDuration = quenchDuration
                    ) via quenchOut;
                }
            }

            state Resetting {
                doc "Restore the high bias voltage to prepare the diode for the next photon.";
                entry {
                    send QuenchControlSignal(
                        quenchVoltage = resetVoltage,
                        resetVoltage = resetVoltage,
                        quenchDuration = resetDuration
                    ) via quenchOut;
                }
            }

            transition from Monitoring to Quenching
                when avalancheIn::AvalancheCurrentPulse is received
                do {
                    send AvalancheCurrentPulse(
                        peakCurrent = 5.0e-3,
                        riseTime = 0.5e-9,
                        width = 5.0e-9,
                        charge = 25.0e-12
                    ) via pulseOut;
                };

            transition from Quenching to Resetting
                after quenchDuration;

            transition from Resetting to Monitoring
                after resetDuration;
        }
    }

    // ============================================================
    //  Part: Discriminator Circuit
    // ============================================================
    part def DiscriminatorCircuit {
        port analogIn : AvalancheInPort;
        port digitalOut : DigitalOutPort;

        attribute threshold : Current = 1.0e-3;
        attribute outputPulseWidth : Duration = 10.0e-9;
        attribute outputAmplitude : Voltage = 3.3;
        attribute timingJitter : Duration = 30.0e-12;
        attribute lastTimestamp : Duration = 0.0;

        satisfy ProduceTimestampedDigitalOutput;

        exhibit action ProcessAvalanche {
            doc "Clean the analog avalanche pulse and convert it to a timestamped digital output.";
            in pulse : AvalancheCurrentPulse;
            out result : DigitalOutputPulse;

            if pulse.peakCurrent >= threshold {
                lastTimestamp := lastTimestamp + 0.0;
                result := DigitalOutputPulse(
                    timestamp = lastTimestamp,
                    pulseWidth = outputPulseWidth,
                    logicHigh = true,
                    amplitude = outputAmplitude
                );
            }
        }

        exhibit state DiscriminatorStateMachine {
            entry;

            state Idle {
                doc "Waiting for an analog avalanche pulse.";
            }

            state Processing {
                doc "Cleaning the signal and assigning a timestamp.";
                entry {
                    perform ProcessAvalanche(
                        in pulse = analogIn::AvalancheCurrentPulse,
                        out result = digitalOut::DigitalOutputPulse
                    );
                }
            }

            transition from Idle to Processing
                when analogIn::AvalancheCurrentPulse is received;

            transition from Processing to Idle
                after 5.0e-9;
        }
    }

    // ============================================================
    //  Part: SPAD System (top-level integration)
    // ============================================================
    part def SPAD_System {
        port opticalInput : PhotonInPort;
        port digitalOutput : DigitalOutPort;

        attribute singlePhotonSensitivity : Boolean = true;
        attribute darkCountRate : Frequency = 100.0;
        attribute systemDeadTime : Duration = 50.0e-9;

        satisfy DetectSinglePhoton;
        satisfy LimitDarkCounts;

        part diode : SPADDiode;
        part biasSupply : BiasSupply;
        part coolingSystem : CoolingSystem;
        part quenchingCircuit : PassiveQuenchingCircuit;
        part discriminator : DiscriminatorCircuit;

        // Optical input to diode
        connection opticalInput to diode.photonPort;

        // Bias supply to diode
        connection biasSupply.biasOut to diode.biasPort;

        // Cooling system to diode
        connection coolingSystem.coolingOut to diode.coolingPort;

        // Diode avalanche pulse to quenching circuit
        connection diode.avalanchePort to quenchingCircuit.avalancheIn;

        // Quenching control back to diode
        connection quenchingCircuit.quenchOut to diode.quenchPort;

        // Quenching circuit forwards pulse to discriminator
        connection quenchingCircuit.pulseOut to discriminator.analogIn;

        // Discriminator digital output to system output
        connection discriminator.digitalOut to digitalOutput;
    }
}
