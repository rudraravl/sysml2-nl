package GeigerCounterSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "A"; }
    value type TimeValue :> Real { unit "s"; }
    value type Frequency :> Real { unit "Hz"; }
    value type Count :> Integer;
    value type CountPerMinute :> Real { unit "counts/min"; }
    value type Pressure :> Real { unit "Pa"; }

    // ---- Item types ----
    item def IonizingRadiation {
        attribute particleType : String;
        attribute energy : Real { unit "eV"; }
    }

    item def ElectricalPulse {
        attribute amplitude : Voltage;
        attribute duration : TimeValue;
    }

    item def ProcessedPulse {
        attribute amplitude : Voltage;
        attribute duration : TimeValue;
        attribute timestamp : TimeValue;
    }

    item def AudioClick {
        attribute loudness : Real { unit "dB"; }
    }

    item def DisplayReading {
        attribute rate : CountPerMinute;
        attribute timestamp : TimeValue;
    }

    // ---- Port definitions ----
    port def RadiationPort {
        out item radiation : IonizingRadiation;
    }

    port def PulsePort {
        out item pulse : ElectricalPulse;
    }

    port def ProcessedPulsePort {
        out item pulse : ProcessedPulse;
    }

    port def AudioPort {
        out item click : AudioClick;
    }

    port def DataPort {
        out item reading : DisplayReading;
    }

    port def PowerPort {
        out voltage : Voltage;
        out current : Current;
    }

    // ---- Requirements ----
    requirement def DetectIonizingRadiation {
        doc << "The system shall detect the presence of ionizing radiation including alpha, beta, and gamma particles.">>
        subject detector : GeigerCounter;
        objective {
            doc << "Detect ionizing radiation events in real time.">>
        }
        require detector.detectionSensitivity >= 1.0;
    }

    requirement def SupplyHighVoltage {
        doc << "The high-voltage supply shall provide a stable voltage of approximately 450 V to the Geiger-Muller tube.">>
        subject hvSupply : HighVoltageSupply;
        objective {
            doc << "Maintain stable tube bias voltage.">>
        }
        require hvSupply.nominalVoltage == 450.0 [V];
        require abs(hvSupply.outputVoltage - hvSupply.nominalVoltage) <= 5.0 [V];
    }

    requirement def LimitDeadTime {
        doc << "The Geiger-Muller tube dead time shall be approximately 100 microseconds.">>
        subject tube : GeigerMullerTube;
        objective {
            doc << "Ensure rapid recovery after each pulse.">>
        }
        require tube.deadTime == 100e-6 [s];
    }

    requirement def ProduceAudioFeedback {
        doc << "The system shall produce an audible click for each detected radiation event.">>
        subject audio : AudioIndicator;
        objective {
            doc << "Provide real-time intuitive feedback.">>
        }
        require audio.clickLoudness >= 60.0;
    }

    requirement def MeasureIntensity {
        doc << "The system shall measure radiation intensity in Counts Per Minute over a 60 second period.">>
        subject counter : RateCounter;
        objective {
            doc << "Quantify radiation intensity.">>
        }
        require counter.countingPeriod == 60.0 [s];
    }

    requirement def DisplayReadingValue {
        doc << "The display unit shall show the numerical radiation intensity value to the user.">>
        subject display : DisplayUnit;
        objective {
            doc << "Visual quantitative measurement.">>
        }
        require display.visible == true;
    }

    // ---- Part definitions ----

    part def HighVoltageSupply {
        attribute nominalVoltage : Voltage = 450.0 [V];
        attribute outputVoltage : Voltage;
        port powerOut : PowerPort;
        action def generateVoltage()
            in target : Voltage = nominalVoltage
            out v : Voltage;
        perform generateVoltage(nominalVoltage, outputVoltage);
        satisfy SupplyHighVoltage;
    }

    part def GeigerMullerTube {
        attribute operatingVoltage : Voltage = 450.0 [V];
        attribute deadTime : TimeValue = 100e-6 [s];
        attribute gasPressure : Pressure = 10000.0 [Pa];
        attribute tubeState : String;
        port radiationIn : RadiationPort;
        port powerIn : PowerPort;
        port pulseOut : PulsePort;
        satisfy LimitDeadTime;

        state def TubeLifecycle {
            state Idle;
            state Avalanche {
                entry {
                    // Generate electrical pulse
                    pulseOut.pulse.amplitude := 5.0 [V];
                    pulseOut.pulse.duration := 10e-6 [s];
                }
            }
            state DeadTime;
            transition Idle -> Avalanche
                when radiationIn.ration.isPresent();
            transition Avalanche -> DeadTime
                after deadTime;
            transition DeadTime -> Idle
                after deadTime;
        }
        exhibit TubeLifecycle;
    }

    part def PulseProcessor {
        attribute gain : Real = 100.0;
        attribute threshold : Voltage = 0.1 [V];
        port pulseIn : PulsePort;
        port pulseOut : ProcessedPulsePort;

        action def processPulse()
            in raw : ElectricalPulse
            out processed : ProcessedPulse {
                processed.amplitude := raw.amplitude * gain;
                processed.duration := raw.duration;
                processed.timestamp := now();
            }
        perform processPulse;
    }

    part def AudioIndicator {
        attribute clickLoudness : Real = 75.0;
        attribute enabled : Boolean = true;
        port pulseIn : ProcessedPulsePort;
        port audioOut : AudioPort;
        satisfy ProduceAudioFeedback;

        action def emitClick()
            in p : ProcessedPulse
            out c : AudioClick {
                c.loudness := clickLoudness;
            }
        perform emitClick;
    }

    part def RateCounter {
        attribute countingPeriod : TimeValue = 60.0 [s];
        attribute pulseCount : Count = 0;
        attribute currentRate : CountPerMinute = 0.0;
        port pulseIn : ProcessedPulsePort;
        port dataOut : DataPort;
        satisfy MeasureIntensity;

        action def tallyPulses()
            in p : ProcessedPulse {
                pulseCount := pulseCount + 1;
            }
        action def computeRate() {
            currentRate := (pulseCount * 60.0) / countingPeriod;
            dataOut.reading.rate := currentRate;
            dataOut.reading.timestamp := now();
            pulseCount := 0;
        }
        perform tallyPulses;
        perform computeRate every countingPeriod;
    }

    part def DisplayUnit {
        attribute visible : Boolean = true;
        attribute displayedValue : CountPerMinute;
        port dataIn : DataPort;
        satisfy DisplayReadingValue;

        action def updateDisplay()
            in r : DisplayReading {
                displayedValue := r.rate;
            }
        perform updateDisplay;
    }

    // ---- Top-level system ----
    part def GeigerCounter {
        attribute detectionSensitivity : Real = 1.0;
        satisfy DetectIonizingRadiation;

        part hvSupply : HighVoltageSupply;
        part gmTube : GeigerMullerTube;
        part processor : PulseProcessor;
        part audio : AudioIndicator;
        part counter : RateCounter;
        part display : DisplayUnit;

        // External radiation input port
        port externalRadiation : RadiationPort;

        connection powerConnection connect hvSupply.powerOut to gmTube.powerIn;
        connection radiationConnection connect externalRadiation to gmTube.radiationIn;
        connection rawPulseConnection connect gmTube.pulseOut to processor.pulseIn;
        connection processedToAudio connect processor.pulseOut to audio.pulseIn;
        connection processedToCounter connect processor.pulseOut to counter.pulseIn;
        connection audioOutput connect audio.audioOut;
        connection dataConnection connect counter.dataOut to display.dataIn;
    }

    part geigerCounter : GeigerCounter;
}
