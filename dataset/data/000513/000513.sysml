package TotallyImplantableCochlearImplantSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def SignalAmplitude :> Real;
    attribute def FrequencyBand :> Real;
    attribute def StimulationIntensity :> Real;
    attribute def ChargeLevel :> Real;

    item def AcousticWave {
        attribute frequency : FrequencyBand;
        attribute amplitude : SignalAmplitude;
        attribute soundPressureLevel : Real;
    }

    item def AnalogAudioSignal {
        attribute voltage : Real;
        attribute frequencyContent : FrequencyBand[*];
    }

    item def DigitalAudioData {
        attribute sampleRate : Real;
        attribute bitDepth : Integer;
        attribute channelData : Integer[*];
    }

    item def ElectricalStimulus {
        attribute current : Real;
        attribute pulseWidth : DurationValue;
        attribute electrodeChannel : Integer;
        attribute stimulationRate : Real;
    }

    item def WirelessPowerSignal {
        attribute transferredPower : PowerValue;
        attribute efficiency : Real;
    }

    port def AcousticInputPort {
        in acousticWave : AcousticWave;
    }

    port def AnalogSignalPort {
        out analogSignal : AnalogAudioSignal;
    }

    port def DigitalDataPort {
        out digitalData : DigitalAudioData;
    }

    port def StimulusOutputPort {
        out stimulus : ElectricalStimulus;
    }

    port def PowerTransferPort {
        in powerSignal : WirelessPowerSignal;
    }

    port def BatteryPort {
        out suppliedPower : PowerValue;
    }

    part def SubcutaneousMicrophone {
        doc /* Internal microphone positioned under the skin to capture sound vibrations. */
        attribute sensitivity : Real = 0.92;
        attribute frequencyResponse : FrequencyBand[2] = (100.0, 8500.0);
        attribute noiseFloor : Real = 25.0;
        port acousticIn : AcousticInputPort;
        port signalOut : AnalogSignalPort;
    }

    part def SignalPreprocessor {
        doc /* Amplifies and filters the analog signal from the microphone. */
        attribute gain : Real = 40.0;
        attribute filterType : String = "bandpass";
        port analogIn : AnalogSignalPort;
        port analogOut : AnalogSignalPort;
    }

    part def AnalogToDigitalConverter {
        doc /* Converts preprocessed analog audio to digital format. */
        attribute samplingRate : Real = 44100.0;
        attribute resolution : Integer = 16;
        port analogIn : AnalogSignalPort;
        port digitalOut : DigitalDataPort;
    }

    part def DigitalSignalProcessor {
        doc /* Processes digital audio and extracts frequency-specific information. */
        attribute processingChannels : Integer = 22;
        attribute processingLatency : DurationValue = 3.0 [SI::s];
        attribute spectralResolution : Integer = 128;
        port digitalIn : DigitalDataPort;
        port digitalOut : DigitalDataPort;
    }

    part def StimulusGenerator {
        doc /* Generates electrical stimulation patterns for the electrode array. */
        attribute maxCurrent : Real = 1.75;
        attribute pulseRate : Real = 900.0;
        attribute dynamicRange : Real = 60.0;
        port digitalIn : DigitalDataPort;
        port stimulusOut : StimulusOutputPort;
    }

    part def ElectrodeArray {
        doc /* Array of electrodes inserted into the cochlea for neural stimulation. */
        attribute numberOfElectrodes : Integer = 22;
        attribute insertionDepth : LengthValue = 24.0 [SI::mm];
        attribute electrodeSpacing : LengthValue = 0.75 [SI::mm];
        attribute impedance : Real = 8.5;
        port stimulusIn : StimulusOutputPort;
    }

    part def RechargeableBattery {
        doc /* Internal battery providing power to all implant components. */
        attribute capacity : Real = 180.0;
        attribute voltage : Real = 3.8;
        attribute currentCharge : ChargeLevel;
        attribute cycleLife : Integer = 1500;
        port chargingIn : PowerTransferPort;
        port powerOut : BatteryPort;
    }

    part def WirelessChargingCoil {
        doc /* Receives wireless power through the skin for battery recharging. */
        attribute coilDiameter : LengthValue = 18.0 [SI::mm];
        attribute operatingFrequency : Real = 13.56;
        attribute transferEfficiency : Real = 0.78;
        port rfIn : PowerTransferPort;
        port powerOut : PowerTransferPort;
    }

    part def BiocompatibleEnclosure {
        doc /* Hermetically sealed housing protecting internal electronics. */
        attribute material : String = "titanium";
        attribute volume : VolumeValue = 1.8 [SI::'cm^3'];
        attribute sealIntegrity : String = "IP68";
    }

    part def TotallyImplantableCochlearImplant {
        doc /* Complete cochlear implant system with all components fully implanted. */
        attribute totalMass : MassValue = 14.2 [SI::g];
        attribute operatingTemperature : TemperatureValue = 310.0 [SI::K];
        attribute deviceLifetime : DurationValue = 15.0 [SI::a];

        part microphone : SubcutaneousMicrophone;
        part preprocessor : SignalPreprocessor;
        part adc : AnalogToDigitalConverter;
        part dsp : DigitalSignalProcessor;
        part stimGen : StimulusGenerator;
        part electrodes : ElectrodeArray;
        part battery : RechargeableBattery;
        part chargingCoil : WirelessChargingCoil;
        part enclosure : BiocompatibleEnclosure;

        connection micToPreproc connect microphone.signalOut to preprocessor.analogIn;
        connection preprocToAdc connect preprocessor.analogOut to adc.analogIn;
        connection adcToDsp connect adc.digitalOut to dsp.digitalIn;
        connection dspToStimGen connect dsp.digitalOut to stimGen.digitalIn;
        connection stimGenToElectrodes connect stimGen.stimulusOut to electrodes.stimulusIn;
        connection coilToBattery connect chargingCoil.powerOut to battery.chargingIn;

        perform action hearingRestorationCycle[*] ordered references restoreHearing;
    }

    action def CaptureAcousticSignal {
        in ambientSound : AcousticWave;
        out capturedSignal : AnalogAudioSignal;
    }

    action def ConvertToDigital {
        in analogSignal : AnalogAudioSignal;
        out digitalSignal : DigitalAudioData;
    }

    action def ProcessAudioSpectrum {
        in rawDigitalData : DigitalAudioData;
        out processedData : DigitalAudioData;
    }

    action def GenerateStimulation {
        in audioData : DigitalAudioData;
        out stimulusPattern : ElectricalStimulus[*];
    }

    action def DeliverNeuralStimulus {
        in stimulusPattern : ElectricalStimulus[*];
    }

    action def MonitorBatteryStatus {
        in currentCharge : ChargeLevel;
        out chargingNeeded : Boolean;
    }

    action restoreHearing {
        doc /* Primary function: convert acoustic signals to neural stimulation. */
        first start;
        then merge continuousOperation;
        then action captureSound : CaptureAcousticSignal {
            in ambientSound : AcousticWave;
            out capturedSignal : AnalogAudioSignal;
        }
        then action convertSignal : ConvertToDigital {
            in analogSignal = captureSound.capturedSignal;
            out digitalSignal : DigitalAudioData;
        }
        then action processSpectrum : ProcessAudioSpectrum {
            in rawDigitalData = convertSignal.digitalSignal;
            out processedData : DigitalAudioData;
        }
        then action generateStim : GenerateStimulation {
            in audioData = processSpectrum.processedData;
            out stimulusPattern : ElectricalStimulus[*];
        }
        then action deliverStim : DeliverNeuralStimulus {
            in stimulusPattern = generateStim.stimulusPattern;
        }
        then action checkBattery : MonitorBatteryStatus {
            in currentCharge : ChargeLevel;
            out chargingNeeded : Boolean;
        }
        then decide;
            if checkBattery.chargingNeeded then enterChargingMode;
            if !checkBattery.chargingNeeded then continuousOperation;
        action enterChargingMode;
        then done;
    }

    requirement def SystemGoal;
    requirement def FunctionalRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    requirement def PowerRequirement;

    requirement <'REQ-TICI-001'> restoreAuditoryPerception : SystemGoal {
        doc /* The totally implantable cochlear implant shall restore functional hearing 
             * by converting acoustic signals into electrical stimulation of the auditory nerve,
             * enabling the user to perceive sound without external devices.
            */
        subject implant : TotallyImplantableCochlearImplant;
    }

    requirement <'REQ-TICI-002'> fullImplantability : FunctionalRequirement {
        doc /* All system components including microphone, processor, battery, and charging 
             * mechanism shall be fully implantable with no external hardware required for 
             * normal operation.
            */
        subject implant : TotallyImplantableCochlearImplant;
        assert constraint {
            implant.microphone != null &&
            implant.battery != null &&
            implant.chargingCoil != null
        }
    }

    requirement <'REQ-TICI-003'> frequencyCoverage : PerformanceRequirement {
        doc /* The internal microphone shall capture acoustic signals across the speech 
             * frequency range from 100 Hz to 8500 Hz with sensitivity of at least 0.90.
            */
        subject mic :>> TotallyImplantableCochlearImplant::microphone;
        assert constraint {
            mic.frequencyResponse[1] <= 100.0 &&
            mic.frequencyResponse[2] >= 8500.0 &&
            mic.sensitivity >= 0.90
        }
    }

    requirement <'REQ-TICI-004'> processingLatency : PerformanceRequirement {
        doc /* The digital signal processor shall process audio signals with a latency 
             * not exceeding 5 milliseconds to maintain natural sound perception.
            */
        subject dsp :>> TotallyImplantableCochlearImplant::dsp;
        assert constraint {
            dsp.processingLatency <= 5.0 [SI::s]
        }
    }

    requirement <'REQ-TICI-005'> stimulationChannels : FunctionalRequirement {
        doc /* The electrode array shall provide at least 22 independent stimulation 
             * channels for high-resolution frequency discrimination.
            */
        subject electrodes :>> TotallyImplantableCochlearImplant::electrodes;
        assert constraint {
            electrodes.numberOfElectrodes >= 22
        }
    }

    requirement <'REQ-TICI-006'> safeCurrent : SafetyRequirement {
        doc /* The stimulus generator shall limit maximum stimulation current to 1.75 mA 
             * to prevent tissue damage and ensure patient safety.
            */
        subject stimGen :>> TotallyImplantableCochlearImplant::stimGen;
        assert constraint {
            stimGen.maxCurrent <= 1.75
        }
    }

    requirement <'REQ-TICI-007'> batteryCapacity : PowerRequirement {
        doc /* The rechargeable battery shall provide sufficient capacity for at least 
             * 16 hours of continuous operation between charges.
            */
        subject battery :>> TotallyImplantableCochlearImplant::battery;
        assert constraint {
            battery.capacity >= 180.0
        }
    }

    requirement <'REQ-TICI-008'> wirelessChargingEfficiency : PowerRequirement {
        doc /* The wireless charging system shall achieve power transfer efficiency 
             * of at least 75% through skin and tissue.
            */
        subject coil :>> TotallyImplantableCochlearImplant::chargingCoil;
        assert constraint {
            coil.transferEfficiency >= 0.75
        }
    }

    requirement <'REQ-TICI-009'> massConstraint : FunctionalRequirement {
        doc /* The total mass of the implantable device shall not exceed 15 grams 
             * to minimize surgical complexity and patient discomfort.
            */
        subject implant : TotallyImplantableCochlearImplant;
        assert constraint {
            implant.totalMass <= 15.0 [SI::g]
        }
    }

    requirement <'REQ-TICI-010'> biocompatibility : SafetyRequirement {
        doc /* All implanted components shall be constructed from biocompatible materials 
             * suitable for long-term implantation with hermetic sealing.
            */
        subject enclosure :>> TotallyImplantableCochlearImplant::enclosure;
        assert constraint {
            enclosure.material == "titanium" &&
            enclosure.sealIntegrity == "IP68"
        }
    }

    requirement <'REQ-TICI-011'> deviceLongevity : FunctionalRequirement {
        doc /* The implant shall maintain operational functionality for a minimum 
             * of 15 years under normal physiological conditions.
            */
        subject implant : TotallyImplantableCochlearImplant;
        assert constraint {
            implant.deviceLifetime >= 15.0 [SI::a]
        }
    }

    part totallyImplantableCochlearImplantInstance : TotallyImplantableCochlearImplant;

    satisfy restoreAuditoryPerception by totallyImplantableCochlearImplantInstance.hearingRestorationCycle;
    satisfy fullImplantability by totallyImplantableCochlearImplantInstance;
    satisfy frequencyCoverage by totallyImplantableCochlearImplantInstance.microphone;
    satisfy processingLatency by totallyImplantableCochlearImplantInstance.dsp;
    satisfy stimulationChannels by totallyImplantableCochlearImplantInstance.electrodes;
    satisfy safeCurrent by totallyImplantableCochlearImplantInstance.stimGen;
    satisfy batteryCapacity by totallyImplantableCochlearImplantInstance.battery;
    satisfy wirelessChargingEfficiency by totallyImplantableCochlearImplantInstance.chargingCoil;
    satisfy massConstraint by totallyImplantableCochlearImplantInstance;
    satisfy biocompatibility by totallyImplantableCochlearImplantInstance.enclosure;
    satisfy deviceLongevity by totallyImplantableCochlearImplantInstance;
}
