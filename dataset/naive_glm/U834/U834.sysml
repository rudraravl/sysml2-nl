package ProportionalCounterSystem {
    import ScalarValues::*;

    // ─── Value Types with Units ───
    value def Voltage :> Real { unit "V"; }
    value def Energy :> Real { unit "eV"; }
    value def Charge :> Real { unit "C"; }
    value def Time :> Real { unit "s"; }
    value def Count :> Real { }
    value def Pressure :> Real { unit "Pa"; }
    value def Length :> Real { unit "m"; }
    value def Temperature :> Real { unit "K"; }
    value def PulseAmplitude :> Real { unit "V"; }
    value def CountRate :> Real { unit "1/s"; }
    value def Frequency :> Real { unit "Hz"; }
    value def Gain :> Real { }
    value def Ratio :> Real { }

    // ─── Enumerations ───
    enum def ParticleType { alpha, xray, beta, gamma }
    enum def SystemMode { standby, active, calibration, fault }

    // ─── Item Definitions ───
    item def IonizingParticle {
        attribute particleType : ParticleType;
        attribute energy : Energy;
    }

    item def ElectronIonPair {
        attribute pairCount : Count;
    }

    item def ChargePacket {
        attribute totalCharge : Charge;
        attribute proportionalEnergy : Energy;
    }

    item def ElectricalPulse {
        attribute amplitude : PulseAmplitude;
        attribute duration : Time;
        attribute timestamp : Time;
    }

    item def MeasurementResult {
        attribute measuredEnergy : Energy;
        attribute pulseCount : Count;
        attribute countRate : CountRate;
        attribute timestamp : Time;
    }

    // ─── Port Definitions ───
    port def ParticleInputPort {
        in item particle : IonizingParticle;
    }

    port def ChargeOutputPort {
        out item charge : ChargePacket;
    }

    port def ChargeInputPort {
        in item charge : ChargePacket;
    }

    port def PulseOutputPort {
        out item pulse : ElectricalPulse;
    }

    port def PulseInputPort {
        in item pulse : ElectricalPulse;
    }

    port def HVOutputPort {
        out attribute voltage : Voltage;
    }

    port def HVInputPort {
        in attribute voltage : Voltage;
    }

    port def ControlCommandOutput {
        out attribute operatingVoltage : Voltage;
        out attribute amplifierGain : Gain;
    }

    port def ControlCommandInput {
        in attribute operatingVoltage : Voltage;
        in attribute amplifierGain : Gain;
    }

    port def DataOutputPort {
        out item result : MeasurementResult;
    }

    port def DataInputPort {
        in item result : MeasurementResult;
    }

    // ─── Component Part Definitions ───

    part def CounterGas {
        attribute composition : String = "P10 (90% Argon, 10% Methane)";
        attribute pressure : Pressure = 101325 [Pa];
        attribute temperature : Temperature = 293.15 [K];
        attribute ionizationEnergy : Energy = 26.4 [eV];
    }

    part def AnodeWire {
        attribute diameter : Length = 25e-6 [m];
        attribute length : Length = 0.5 [m];
        attribute material : String = "Tungsten";
    }

    part def CathodeWall {
        attribute innerDiameter : Length = 0.05 [m];
        attribute length : Length = 0.5 [m];
        attribute material : String = "Stainless Steel";
    }

    part def DetectorChamber {
        part gas : CounterGas;
        part anode : AnodeWire;
        part cathode : CathodeWall;

        port particleInput : ParticleInputPort;
        port chargeOutput : ChargeOutputPort;
        port hvInput : HVInputPort;

        attribute gasAmplification : Gain = 1000;
        attribute activeVolumeLength : Length = 0.5 [m];
        attribute detectedEnergy : Energy;

        action DetectParticle {
            in particle : IonizingParticle;
            in hv : Voltage;
            out charge : ChargePacket;

            attribute primaryPairs : Count;
            attribute avalancheCharge : Charge;
            attribute outputEnergy : Energy;
        }

        state DetectorOperation {
            entry; then Idle;

            state Idle {
                doc /* Detector is ready and waiting for an ionizing particle to enter the chamber. */
            }

            state Ionization {
                doc /* Incoming particle collides with gas atoms, creating a trail of electron-ion pairs. */
            }

            state Drift {
                doc /* Freed electrons accelerate toward the anode wire under the electric field. */
            }

            state Avalanche {
                doc /* Gas amplification avalanche occurs in the high-field region near the anode wire. */
            }

            state ChargeCollection {
                doc /* Avalanche charge is collected on the anode wire, generating an electrical pulse. */
            }

            transition Idle_to_Ionization
                first Idle
                then Ionization;

            transition Ionization_to_Drift
                first Ionization
                then Drift;

            transition Drift_to_Avalanche
                first Drift
                then Avalanche;

            transition Avalanche_to_ChargeCollection
                first Avalanche
                then ChargeCollection;

            transition ChargeCollection_to_Idle
                first ChargeCollection
                then Idle;
        }
    }

    part def HighVoltageSupply {
        attribute outputVoltage : Voltage = 1500 [V];
        attribute maxVoltage : Voltage = 3000 [V];
        attribute ripple : Voltage = 0.01 [V];
        attribute stability : Ratio = 0.001;
        attribute rampRate : Voltage = 100 [V];

        port hvOutput : HVOutputPort;
        port controlInput : ControlCommandInput;

        state HVOperation {
            entry; then Off;

            state Off {
                doc /* HV supply is powered off. */
            }

            state Ramping {
                doc /* HV is ramping up toward the configured operating voltage. */
            }

            state Stable {
                doc /* HV output is stable at the operating voltage with acceptable ripple. */
            }

            state Fault {
                doc /* HV supply has entered a fault condition due to overvoltage or hardware error. */
            }

            transition Off_to_Ramping
                first Off
                if controlInput.operatingVoltage > 0 [V]
                then Ramping;

            transition Ramping_to_Stable
                first Ramping
                if hvOutput.voltage >= controlInput.operatingVoltage
                then Stable;

            transition Stable_to_Fault
                first Stable
                if hvOutput.voltage > maxVoltage
                then Fault;

            transition Fault_to_Off
                first Fault
                then Off;
        }
    }

    part def ChargeAmplifier {
        attribute gain : Gain = 1000;
        attribute noise : Charge = 1e-15 [C];
        attribute shapingTime : Time = 1e-6 [s];
        attribute inputImpedance : Real = 50;

        port chargeInput : ChargeInputPort;
        port pulseOutput : PulseOutputPort;
        port controlInput : ControlCommandInput;

        action AmplifyCharge {
            in charge : ChargePacket;
            out pulse : ElectricalPulse;

            attribute amplifiedAmplitude : PulseAmplitude;
            attribute signalToNoise : Ratio;
        }

        state AmplifierOperation {
            entry; then Ready;

            state Ready {
                doc /* Amplifier is idle and ready to receive a charge packet. */
            }

            state Amplifying {
                doc /* Amplifier is converting and boosting the incoming charge signal. */
            }

            transition Ready_to_Amplifying
                first Ready
                then Amplifying;

            transition Amplifying_to_Ready
                first Amplifying
                then Ready;
        }
    }

    part def PulseShaper {
        attribute shapingTime : Time = 2e-6 [s];
        attribute baseline : PulseAmplitude = 0 [V];
        attribute integrationTime : Time = 1e-6 [s];
        attribute poleZeroCancel : Ratio = 1.0;

        port pulseInput : PulseInputPort;
        port shapedOutput : PulseOutputPort;

        action ShapePulse {
            in rawPulse : ElectricalPulse;
            out shapedPulse : ElectricalPulse;

            attribute shapedAmplitude : PulseAmplitude;
            attribute shapedDuration : Time;
            attribute baselineShift : PulseAmplitude;
        }

        state ShaperOperation {
            entry; then Idle;

            state Idle {
                doc /* Pulse shaper is waiting for an incoming raw pulse. */
            }

            state Shaping {
                doc /* Pulse shaper is applying CR-RC filtering to optimize pulse form. */
            }

            transition Idle_to_Shaping
                first Idle
                then Shaping;

            transition Shaping_to_Idle
                first Shaping
                then Idle;
        }
    }

    part def DataAcquisitionSystem {
        attribute samplingRate : Frequency = 100e6 [Hz];
        attribute resolutionBits : Integer = 14;
        attribute pulseCount : Count = 0;
        attribute measuredEnergy : Energy;
        attribute energyCalibration : Gain = 1e6;
        attribute maxCountRate : CountRate = 10000 [1/s];
        attribute deadTime : Time = 2e-6 [s];

        port pulseInput : PulseInputPort;
        port dataOutput : DataOutputPort;

        action AcquirePulse {
            in pulse : ElectricalPulse;
            out result : MeasurementResult;

            attribute digitizedAmplitude : PulseAmplitude;
            attribute computedEnergy : Energy;
            attribute updatedCount : Count;
            attribute computedRate : CountRate;
        }

        state DAQOperation {
            entry; then Ready;

            state Ready {
                doc /* DAQ is ready to accept and digitize incoming pulses. */
            }

            state Processing {
                doc /* DAQ is digitizing the pulse amplitude and computing energy. */
            }

            state Recording {
                doc /* DAQ is recording the measurement result and updating counters. */
            }

            state Saturated {
                doc /* DAQ dead time exceeded; pulses may be lost. */
            }

            transition Ready_to_Processing
                first Ready
                then Processing;

            transition Processing_to_Recording
                first Processing
                then Recording;

            transition Recording_to_Ready
                first Recording
                then Ready;

            transition Ready_to_Saturated
                first Ready
                if pulseCount > maxCountRate
                then Saturated;

            transition Saturated_to_Ready
                first Saturated
                then Ready;
        }
    }

    part def ControlUnit {
        attribute operatingVoltage : Voltage = 1500 [V];
        attribute amplifierGain : Gain = 1000;
        attribute runTime : Time = 3600 [s];
        attribute mode : SystemMode = SystemMode::standby;
        attribute totalPulses : Count = 0;
        attribute acquisitionStart : Time;

        port commandHV : ControlCommandOutput;
        port commandAmp : ControlCommandOutput;
        port receiveData : DataInputPort;

        action ConfigureSystem {
            out hvSetting : Voltage;
            out gainSetting : Gain;
        }

        action AnalyzeResults {
            in result : MeasurementResult;
            attribute cumulativeCount : Count;
            attribute averageEnergy : Energy;
        }

        state ControlOperation {
            entry; then Initializing;

            state Initializing {
                doc /* System is powering up and performing self-diagnostics. */
            }

            state Configured {
                doc /* Operating parameters have been set on all subsystems. */
            }

            state Running {
                doc /* Data acquisition is actively in progress. */
            }

            state Paused {
                doc /* Acquisition is temporarily paused by operator command. */
            }

            state Stopped {
                doc /* Acquisition run is complete and data is finalized. */
            }

            transition Init_to_Configured
                first Initializing
                then Configured;

            transition Configured_to_Running
                first Configured
                then Running;

            transition Running_to_Paused
                first Running
                then Paused;

            transition Paused_to_Running
                first Paused
                then Running;

            transition Running_to_Stopped
                first Running
                if receiveData.result.timestamp >= runTime
                then Stopped;
        }
    }

    // ─── Top-Level System ───
    part def ProportionalCounterSystem {
        part detector : DetectorChamber;
        part hvSupply : HighVoltageSupply;
        part chargeAmp : ChargeAmplifier;
        part pulseShaper : PulseShaper;
        part daq : DataAcquisitionSystem;
        part controller : ControlUnit;

        // HV power delivery to detector
        connection hvPowerConnection
            connect hvSupply.hvOutput to detector.hvInput;

        // Charge signal from detector to amplifier
        connection chargeSignalConnection
            connect detector.chargeOutput to chargeAmp.chargeInput;

        // Raw pulse from amplifier to shaper
        connection rawPulseConnection
            connect chargeAmp.pulseOutput to pulseShaper.pulseInput;

        // Shaped pulse from shaper to DAQ
        connection shapedPulseConnection
            connect pulseShaper.shapedOutput to daq.pulseInput;

        // Control commands from controller to HV supply
        connection hvControlConnection
            connect controller.commandHV to hvSupply.controlInput;

        // Control commands from controller to charge amplifier
        connection ampControlConnection
            connect controller.commandAmp to chargeAmp.controlInput;

        // Measurement results from DAQ to controller
        connection dataFeedbackConnection
            connect daq.dataOutput to controller.receiveData;
    }

    // ─── Requirements ───

    requirement def DetectorSensitivityRequirement {
        doc /* The detector shall detect ionizing particles with energy ranging from 1 keV to 10 MeV. */
        attribute minEnergy : Energy = 1000 [eV];
        attribute maxEnergy : Energy = 10000000 [eV];
        subject detector : DetectorChamber;
        require detector.particleInput.particle.energy >= minEnergy
            and detector.particleInput.particle.energy <= maxEnergy;
    }

    requirement def GasAmplificationRequirement {
        doc /* The gas amplification factor shall be between 100 and 10000 to ensure proportional operation without entering Geiger-Muller mode. */
        attribute minGain : Gain = 100;
        attribute maxGain : Gain = 10000;
        subject detector : DetectorChamber;
        require detector.gasAmplification >= minGain
            and detector.gasAmplification <= maxGain;
    }

    requirement def EnergyProportionalityRequirement {
        doc /* The total charge collected at the anode shall be directly proportional to the energy of the original ionizing particle within 2% tolerance. */
        attribute tolerance : Ratio = 0.02;
        subject detector : DetectorChamber;
        require detector.chargeOutput.charge.proportionalEnergy
            >= detector.particleInput.particle.energy * (1 - tolerance)
            and detector.chargeOutput.charge.proportionalEnergy
            <= detector.particleInput.particle.energy * (1 + tolerance);
    }

    requirement def EnergyResolutionRequirement {
        doc /* The system shall measure particle energy with resolution better than 10% full width at half maximum at 5.5 MeV. */
        attribute resolution : Ratio = 0.10;
        attribute referenceEnergy : Energy = 5500000 [eV];
        subject daq : DataAcquisitionSystem;
        require daq.measuredEnergy >= referenceEnergy * (1 - resolution)
            and daq.measuredEnergy <= referenceEnergy * (1 + resolution);
    }

    requirement def HVStabilityRequirement {
        doc /* The high voltage supply shall maintain output stability within 0.1% of the set operating voltage. */
        attribute stabilityFraction : Ratio = 0.001;
        subject hvSupply : HighVoltageSupply;
        require hvSupply.ripple <= hvSupply.outputVoltage * stabilityFraction;
    }

    requirement def CountRateRequirement {
        doc /* The system shall count radiation pulses at rates up to 10000 counts per second with less than 1% loss. */
        attribute maxCountRate : CountRate = 10000 [1/s];
        attribute nyquistFactor : Ratio = 2.0;
        subject daq : DataAcquisitionSystem;
        require daq.samplingRate >= maxCountRate * nyquistFactor;
    }

    requirement def SystemIntegrationRequirement {
        doc /* The proportional counter system shall integrate detector, HV supply, amplifier, shaper, DAQ, and controller into a cohesive measurement chain. */
        subject system : ProportionalCounterSystem;
        require system.detector.charOutput == system.chargeAmp.chargeInput
            and system.chargeAmp.pulseOutput == system.pulseShaper.pulseInput
            and system.pulseShaper.shapedOutput == system.daq.pulseInput;
    }
}
