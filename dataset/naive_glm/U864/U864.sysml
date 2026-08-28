package ScintillationCounter {
    import ISQ::*;
    import SI::*;

    // ---- Value types with units ----
    value type Energy :> Real { unit 'eV'; }
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Duration :> Real { unit 's'; }
    value type Wavelength :> Real { unit 'nm'; }
    value type Count :> Integer;
    value type CountRate :> Real { unit '1/s'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type Amplitude :> Real { unit 'V'; }
    value type Threshold :> Real { unit 'V'; }
    value type Gain :> Real;
    value type MeasurementTime :> Real { unit 's'; }
    value type Efficiency :> Real;
    value type PhotonFlux :> Real { unit '1/s'; }

    // ---- Item definitions ----
    item def IonizingRadiationParticle {
        attribute energy : Energy;
        attribute particleType : String; // e.g., "alpha","beta","gamma"
        attribute incident : Boolean = true;
    }

    item def LightPhoton {
        attribute wavelength : Wavelength = 420 [nm];
        attribute intensity : Real;
    }

    item def ElectricalPulse {
        attribute amplitude : Amplitude;
        attribute duration : Duration;
        attribute riseTime : Duration;
        attribute valid : Boolean = false;
        attribute timestamp : Duration;
    }

    item def CountResult {
        attribute totalCount : Count;
        attribute countRate : CountRate;
        attribute measurementTime : MeasurementTime;
    }

    // ---- Port definitions ----
    port def RadiationInPort {
        in item particle : IonizingRadiationParticle;
    }

    port def LightOutPort {
        out item photons : LightPhoton[0..*];
    }

    port def LightInPort {
        in item photons : LightPhoton[0..*];
    }

    port def PulseOutPort {
        out item pulse : ElectricalPulse;
    }

    port def PulseInPort {
        in item pulse : ElectricalPulse;
    }

    port def HVOutPort {
        out attribute voltage : Voltage;
    }

    port def HVInPort {
        in attribute voltage : Voltage;
    }

    port def CountOutPort {
        out item result : CountResult;
    }

    // ---- Requirements ----
    requirement def DetectIonizingRadiation {
        subject counter : ScintillationCounterSystem;
        doc /* The system shall detect ionizing radiation particles and convert them into countable electrical signals. */
        assume { /* The radiation source emits particles with energy above 1 keV. */ }
    }

    requirement def MeasureIntensity {
        subject counter : ScintillationCounterSystem;
        attribute minSensitivity : CountRate = 0.1 [1/s];
        attribute maxSensitivity : CountRate = 1e6 [1/s];
        doc /* The system shall measure radiation intensity as count rate within the dynamic range. */
    }

    requirement def RejectNoise {
        subject disc : Discriminator;
        attribute threshold : Threshold = 0.05 [V];
        doc /* The discriminator shall reject pulses with amplitude below threshold. */
    }

    requirement def HVStability {
        subject hv : HighVoltageSupply;
        attribute nominalVoltage : Voltage = 1000 [V];
        attribute tolerance : Real = 0.01;
        doc /* The HV supply shall maintain output within tolerance of nominalVoltage. */
    }

    requirement def PulseShapingQuality {
        subject shaper : PulseShaper;
        attribute shapingTime : Duration = 1e-6 [s];
        attribute snrImprovement : Real = 10.0;
        doc /* The shaper shall reduce noise and produce standardized pulse shape. */
    }

    requirement def ScintillationEfficiencyReq {
        subject crystal : ScintillatorCrystal;
        attribute minEfficiency : Efficiency = 0.05;
        doc /* The scintillator shall convert at least minEfficiency of incident particle energy into visible light. */
    }

    // ---- Component parts ----

    part def ScintillatorCrystal {
        port radiationIn : RadiationInPort;
        port lightOut : LightOutPort;
        attribute scintillationEfficiency : Efficiency = 0.08;
        attribute photonsPerMeV : Real = 40000.0;
        attribute decayTime : Duration = 230e-9 [s];
        attribute material : String = "NaI(Tl)";

        action def Scintillate {
            in particle : IonizingRadiationParticle;
            out photons : LightPhoton[0..*];
        }

        perform action scintillate : Scintillate;

        state crystalState {
            entry; then idle;
            state idle {
                accept radiationIn.particle then scintillating;
            }
            state scintillating {
                do scintillate;
                then idle;
            }
        }

        satisfy ScintillationEfficiencyReq by scintillationEfficiency;
    }

    part def PhotomultiplierTube {
        port lightIn : LightInPort;
        port pulseOut : PulseOutPort;
        port hvIn : HVInPort;
        attribute quantumEfficiency : Real = 0.25;
        attribute dynodeGain : Gain = 4.0;
        attribute dynodeStages : Integer = 10;
        attribute totalGain : Gain = dynodeGain ** dynodeStages;
        attribute darkCurrent : Current = 1e-9 [A];

        action def ConvertAndMultiply {
            in photons : LightPhoton[0..*];
            in hv : Voltage;
            out pulse : ElectricalPulse;
        }

        perform action convert : ConvertAndMultiply;

        state pmtState {
            entry; then ready;
            state ready {
                accept lightIn.photons then converting;
            }
            state converting {
                do convert;
                then ready;
            }
        }
    }

    part def HighVoltageSupply {
        port hvOut : HVOutPort;
        attribute outputVoltage : Voltage = 1000 [V];
        attribute ripple : Real = 0.001;
        attribute maxCurrent : Current = 5e-3 [A];

        state hvOperation {
            entry; then powering;
            state powering {
                do { hvOut.voltage = outputVoltage; }
            }
        }

        satisfy HVStability by outputVoltage;
    }

    part def PreAmplifier {
        port pulseIn : PulseInPort;
        port pulseOut : PulseOutPort;
        attribute gain : Gain = 10.0;
        attribute bandwidth : Frequency = 50e6 [Hz];
        attribute noiseFigure : Real = 1.5;

        action def Amplify {
            in pulseIn : ElectricalPulse;
            out pulseOut : ElectricalPulse;
        }

        perform action amplify : Amplify;

        state preampState {
            entry; then quiescent;
            state quiescent {
                accept pulseIn.pulse then amplifying;
            }
            state amplifying {
                do amplify;
                then quiescent;
            }
        }
    }

    part def PulseShaper {
        port pulseIn : PulseInPort;
        port pulseOut : PulseOutPort;
        attribute shapingTime : Duration = 1e-6 [s];
        attribute filterOrder : Integer = 4;
        attribute baselineRestoration : Boolean = true;

        action def Shape {
            in pulseIn : ElectricalPulse;
            out pulseOut : ElectricalPulse;
        }

        perform action shape : Shape;

        state shaperState {
            entry; then waiting;
            state waiting {
                accept pulseIn.pulse then shaping;
            }
            state shaping {
                do shape;
                then waiting;
            }
        }

        satisfy PulseShapingQuality by shapingTime;
    }

    part def Discriminator {
        port pulseIn : PulseInPort;
        port pulseOut : PulseOutPort;
        attribute threshold : Threshold = 0.05 [V];
        attribute deadTime : Duration = 50e-9 [s];

        action def Discriminate {
            in pulseIn : ElectricalPulse;
            out pulseOut : ElectricalPulse;
        }

        perform action discriminate : Discriminate;

        state discriminatorState {
            entry; then idle;
            state idle {
                accept pulseIn.pulse then evaluating;
            }
            state evaluating {
                do discriminate;
                if pulseIn.pulse.amplitude >= threshold then accepted;
                else rejected;
            }
            state accepted {
                entry { pulseOut.pulse.valid = true; }
                then idle;
            }
            state rejected {
                entry { /* discard pulse */ }
                then idle;
            }
        }

        satisfy RejectNoise by threshold;
    }

    part def Counter {
        port pulseIn : PulseInPort;
        port resultOut : CountOutPort;
        attribute totalCount : Count = 0;
        attribute countRate : CountRate = 0 [1/s];
        attribute measurementTime : MeasurementTime = 1 [s];
        attribute liveTime : Duration = 0 [s];

        action def RegisterPulse {
            in pulse : ElectricalPulse;
        }

        action def ComputeRate {
            in count : Count;
            in time : MeasurementTime;
            out rate : CountRate;
        }

        perform action register : RegisterPulse;
        perform action compute : ComputeRate;

        state counterState {
            entry; then armed;
            state armed {
                entry { totalCount = 0; liveTime = 0 [s]; }
                then counting;
            }
            state counting {
                accept pulseIn.pulse {
                    totalCount = totalCount + 1;
                }
                after measurementTime then finalizing;
            }
            state finalizing {
                do compute;
                then reporting;
            }
            state reporting {
                entry {
                    resultOut.result = CountResult {
                        totalCount = totalCount,
                        countRate = countRate,
                        measurementTime = measurementTime
                    };
                }
                then armed;
            }
        }
    }

    // ---- System assembly ----
    part def ScintillationCounterSystem {
        port radiationInput : RadiationInPort;
        port dataOutput : CountOutPort;

        part hvSupply : HighVoltageSupply {
            satisfy HVStability;
        }
        part scintillator : ScintillatorCrystal {
            satisfy ScintillationEfficiencyReq;
        }
        part pmt : PhotomultiplierTube;
        part preamp : PreAmplifier;
        part shaper : PulseShaper {
            satisfy PulseShapingQuality;
        }
        part discriminator : Discriminator {
            satisfy RejectNoise;
        }
        part counter : Counter;

        // External radiation into scintillator
        connect radiationInput to scintillator.radiationIn;

        // Light path: scintillator -> PMT
        connect scintillator.lightOut to pmt.lightIn;

        // HV supply to PMT
        connect hvSupply.hvOut to pmt.hvIn;

        // Electrical pulse chain
        connect pmt.pulseOut to preamp.pulseIn;
        connect preamp.pulseOut to shaper.pulseIn;
        connect shaper.pulseOut to discriminator.pulseIn;
        connect discriminator.pulseOut to counter.pulseIn;

        // Counter output to system data port
        connect counter.resultOut to dataOutput;

        // System-level requirement satisfaction
        satisfy DetectIonizingRadiation;
        satisfy MeasureIntensity;

        state systemOperation {
            entry; then standby;
            state standby {
                accept radiationInput.particle then detecting;
            }
            state detecting {
                doc /* Full signal chain active from scintillator through counter. */
            }
        }
    }
}
