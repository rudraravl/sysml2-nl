package SNSPD_System {

    // ===== Value Types =====
    value type Temperature :> Real { unit 'K'; }
    value type Current :> Real { unit 'A'; }
    value type Voltage :> Real { unit 'V'; }
    value type Resistance :> Real { unit 'ohm'; }
    value type Duration :> Real { unit 's'; }
    value type Power :> Real { unit 'W'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type Energy :> Real { unit 'J'; }
    value type Length :> Real { unit 'm'; }
    value type Gain :> Real;

    // ===== Item Types =====
    item def Photon {
        attribute wavelength : Length;
        attribute energy : Energy;
    }

    item def ElectricalPulse {
        attribute amplitude : Voltage;
        attribute duration : Duration;
    }

    item def DigitalPulse {
        attribute timestamp : Duration;
        attribute isValid : Boolean;
    }

    item def CoolingFlux {
        attribute coolingPower : Power;
        attribute targetTemperature : Temperature;
    }

    item def BiasFlow {
        attribute current : Current;
    }

    // ===== Port Definitions =====
    port def OpticalPort {
        in item : Photon;
        out item : Photon;
    }

    port def ElectricalPort {
        in item : ElectricalPulse;
        out item : ElectricalPulse;
    }

    port def DigitalPort {
        in item : DigitalPulse;
        out item : DigitalPulse;
    }

    port def ThermalPort {
        in item : CoolingFlux;
        out item : CoolingFlux;
    }

    port def BiasPort {
        in item : BiasFlow;
        out item : BiasFlow;
    }

    // ===== Requirements =====
    requirement def DetectionEfficiencyRequirement {
        doc /* The SNSPD system shall detect individual photons with high efficiency. */
        attribute minEfficiency : Real = 0.90;
        attribute targetWavelength : Length = 1550e-9 [m];
    }

    requirement def TimingAccuracyRequirement {
        doc /* The system shall record photon arrival time with accuracy of tens of picoseconds. */
        attribute maxJitter : Duration = 50e-12 [s];
    }

    requirement def CryogenicTemperatureRequirement {
        doc /* The nanowire shall be cooled to approximately 2.5 K. */
        attribute targetTemperature : Temperature = 2.5 [K];
    }

    requirement def AmplifierGainRequirement {
        doc /* The readout amplifier shall boost signal strength by a factor of 1000 or more. */
        attribute minimumGain : Gain = 1000;
    }

    requirement def DeadTimeRequirement {
        doc /* The nanowire shall recover within a brief dead time after each detection. */
        attribute maximumDeadTime : Duration = 100e-9 [s];
    }

    requirement def DiscriminatorThresholdRequirement {
        doc /* The pulse discriminator shall distinguish genuine photon events from background noise. */
        attribute thresholdVoltage : Voltage = 10e-3 [V];
    }

    // ===== Part Definitions =====

    part def CryogenicRefrigerator {
        port coolingOut : ThermalPort;
        attribute baseTemperature : Temperature = 2.5 [K];
        attribute coolingCapacity : Power = 1.0 [W];

        action def CoolDown {
            out temp : Temperature;
            action { /* Cools nanowire to base temperature */ }
        }
    }

    part def BiasCurrentSource {
        port biasOut : BiasPort;
        attribute biasCurrent : Current = 15e-6 [A];
        attribute criticalCurrent : Current = 20e-6 [A];

        constraint { biasCurrent < criticalCurrent }
    }

    part def SuperconductingNanowire {
        port opticalIn : OpticalPort;
        port biasIn : BiasPort;
        port thermalIn : ThermalPort;
        port signalOut : ElectricalPort;

        attribute superconductingResistance : Resistance = 0.0 [ohm];
        attribute normalResistance : Resistance = 1e6 [ohm];
        attribute operatingTemperature : Temperature = 2.5 [K];
        attribute deadTime : Duration = 50e-9 [s];
        attribute hotspotDuration : Duration = 5e-9 [s];
        attribute pulseAmplitude : Voltage = 1e-3 [V];
        attribute photonArrived : Boolean = false;

        state def DetectionLifecycle {
            entry; then Superconducting;

            state Superconducting {
                doc /* Nanowire is in superconducting state, ready to detect photons. */
                entry action { /* Bias current flows with zero resistance. */ }
            }

            transition Superconducting to Hotspot
                when { photonArrived }
                action { /* Photon absorbed, hotspot forms, current reroutes. */ };

            state Hotspot {
                doc /* Localized resistive region formed by photon absorption. */
                entry action { /* Nanowire segment loses superconductivity. */ }
                do action { /* Bias current reroutes through load, generating pulse. */ }
            }

            transition Hotspot to Recovery
                after 5e-9 [s]
                action { /* Hotspot begins to cool. */ };

            state Recovery {
                doc /* Nanowire cooling back to superconducting state. */
                entry action { /* Thermal energy dissipating to substrate. */ }
            }

            transition Recovery to Superconducting
                after 50e-9 [s]
                action { /* Nanowire returns to superconducting state. */ };
        }

        exhibit DetectionLifecycle;

        satisfy CryogenicTemperatureRequirement by operatingTemperature;
        satisfy DeadTimeRequirement by deadTime;
    }

    part def ReadoutAmplifier {
        port signalIn : ElectricalPort;
        port signalOut : ElectricalPort;

        attribute gain : Gain = 1000;
        attribute noiseFloor : Voltage = 1e-6 [V];
        attribute bandwidth : Frequency = 100e6 [Hz];

        action def Amplify {
            in inputPulse : ElectricalPulse;
            out outputPulse : ElectricalPulse;
            action { /* Amplifies input pulse by gain factor */ }
        }

        satisfy AmplifierGainRequirement by gain;
    }

    part def PulseDiscriminator {
        port signalIn : ElectricalPort;
        port digitalOut : DigitalPort;

        attribute threshold : Voltage = 10e-3 [V];
        attribute propagationDelay : Duration = 2e-9 [s];

        action def Discriminate {
            in inputPulse : ElectricalPulse;
            out outputPulse : DigitalPulse;
            action { /* If pulse amplitude exceeds threshold, generate digital pulse */ }
        }

        satisfy DiscriminatorThresholdRequirement by threshold;
    }

    part def TimingModule {
        port digitalIn : DigitalPort;

        attribute resolution : Duration = 10e-12 [s];
        attribute count : Integer = 0;
        attribute bufferDepth : Integer = 1024;

        action def RecordArrival {
            in inputPulse : DigitalPulse;
            out recordedTime : Duration;
            action { /* Records timestamp of valid digital pulse */ }
        }

        satisfy TimingAccuracyRequirement by resolution;
    }

    // ===== System Definition =====
    part def SNSPD {
        doc /* Superconducting Nanowire Single-Photon Detector System */

        port opticalInput : OpticalPort;
        port dataOutput : DigitalPort;

        part refrigerator : CryogenicRefrigerator;
        part biasSource : BiasCurrentSource;
        part nanowire : SuperconductingNanowire;
        part amplifier : ReadoutAmplifier;
        part discriminator : PulseDiscriminator;
        part timing : TimingModule;

        connection opticalPath connect opticalInput to nanowire.opticalIn;
        connection thermalPath connect refrigerator.coolingOut to nanowire.thermalIn;
        connection biasPath connect biasSource.biasOut to nanowire.biasIn;
        connection nanowireToAmplifier connect nanowire.signalOut to amplifier.signalIn;
        connection amplifierToDiscriminator connect amplifier.signalOut to discriminator.signalIn;
        connection discriminatorToTiming connect discriminator.digitalOut to timing.digitalIn;
        connection outputPath connect discriminator.digitalOut to dataOutput;

        satisfy DetectionEfficiencyRequirement;
    }

    // ===== Top-level Usage =====
    part snspdSystem : SNSPD;
}
