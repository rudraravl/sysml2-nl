package CochlearImplantSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ---- Value Types with Units ----
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Power :> Real { unit 'W'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type Pressure :> Real { unit 'Pa'; }
    value type Charge :> Real { unit 'C'; }
    value type Temperature :> Real { unit 'K'; }
    value type Duration_ms :> Real { unit 'ms'; }
    value type DataRate :> Real { unit 'bit/s'; }
    value type Length_mm :> Real { unit 'mm'; }
    value type Area_mm2 :> Real { unit 'mm2'; }
    value type Impedance_kOhm :> Real { unit 'kOhm'; }
    value type Capacity_mAh :> Real { unit 'mAh'; }
    
    // ---- Enumerations ----
    enum OperatingState { Off, Standby, Active, Charging, Fault; }
    enum BatteryState { Depleted, Low, Nominal, Full; }
    enum EnclosureMaterial { TitaniumGrade4, TitaniumGrade5; }
    
    // ---- Item Definitions ----
    item def SoundWave {
        attribute soundPressure : Pressure;
        attribute dominantFrequency : Frequency;
    }
    
    item def AnalogSignal {
        attribute voltage : Voltage;
        attribute bandwidth : Frequency;
        attribute signalToNoiseRatio_dB : Real;
    }
    
    item def DigitalAudio {
        attribute sampleRate : Frequency;
        attribute bitDepth : Integer;
        attribute dataRate : DataRate;
    }
    
    item def FrequencyChannel {
        attribute centerFrequency : Frequency;
        attribute amplitude : Real;
        attribute channelIndex : Integer;
    }
    
    item def StimulusPulse {
        attribute amplitude : Current;
        attribute pulseWidth : Duration_ms;
        attribute electrodeIndex : Integer;
        attribute stimulationRate : Frequency;
    }
    
    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute charge : Charge;
    }
    
    // ---- Port Definitions ----
    port def AcousticPort {
        out sound : SoundWave;
    }
    
    port def AnalogSignalPort {
        out signal : AnalogSignal;
    }
    
    port def DigitalAudioPort {
        out audio : DigitalAudio;
    }
    
    port def ChannelDataPort {
        out channels : FrequencyChannel[1..*];
    }
    
    port def StimulusPort {
        out pulses : StimulusPulse[1..*];
    }
    
    port def PowerPort {
        out energy : ElectricalEnergy;
    }
    
    port def ChargingPort {
        in energy : ElectricalEnergy;
    }
    
    // ---- Part Definitions ----
    
    part def TitaniumEnclosure {
        attribute material : EnclosureMaterial = EnclosureMaterial::TitaniumGrade5;
        attribute hermeticallySealed : Boolean = true;
        attribute length : Length_mm = 35.0;
        attribute width : Length_mm = 25.0;
        attribute thickness : Length_mm = 6.0;
        attribute maxOperatingTemperature : Temperature = 310.15;
        attribute hermeticLeakRate : Real = 1e-9;
        attribute biocompatibilityStandard : String = "ISO 10993";
    }
    
    part def SubcutaneousMicrophone {
        port acousticInput : AcousticPort;
        port analogOutput : AnalogSignalPort;
        
        attribute sensitivity_mVPa : Real = 50.0;
        attribute frequencyRangeMin : Frequency = 100.0;
        attribute frequencyRangeMax : Frequency = 8000.0;
        attribute diameter : Length_mm = 8.0;
        attribute depth : Length_mm = 3.0;
        
        action def CaptureSound {
            in sound : SoundWave;
            out signal : AnalogSignal;
        }
        
        perform action capture : CaptureSound {
            in sound = acousticInput.sound;
            out signal = analogOutput.signal;
        }
    }
    
    part def SignalPreprocessor {
        port analogInput : AnalogSignalPort;
        port analogOutput : AnalogSignalPort;
        port powerInput : PowerPort;
        
        attribute gain_dB : Real = 40.0;
        attribute lowCutoff : Frequency = 100.0;
        attribute highCutoff : Frequency = 8000.0;
        attribute noiseFloor : Voltage = 1e-6;
        attribute powerConsumption : Power = 0.0005;
        
        action def Amplify {
            in inputSignal : AnalogSignal;
            out amplifiedSignal : AnalogSignal;
        }
        
        action def Filter {
            in amplifiedSignal : AnalogSignal;
            out filteredSignal : AnalogSignal;
        }
        
        perform action amplify : Amplify {
            in inputSignal = analogInput.signal;
            out amplifiedSignal;
        }
        
        perform action filter : Filter {
            in amplifiedSignal = amplify.amplifiedSignal;
            out filteredSignal = analogOutput.signal;
        }
    }
    
    part def AnalogToDigitalConverter {
        port analogInput : AnalogSignalPort;
        port digitalOutput : DigitalAudioPort;
        port powerInput : PowerPort;
        
        attribute sampleRate : Frequency = 16000.0;
        attribute bitDepth : Integer = 16;
        attribute signalToNoiseRatio_dB : Real = 90.0;
        attribute powerConsumption : Power = 0.0003;
        
        action def Convert {
            in analog : AnalogSignal;
            out digital : DigitalAudio;
        }
        
        perform action convert : Convert {
            in analog = analogInput.signal;
            out digital = digitalOutput.audio;
        }
    }
    
    part def DigitalSignalProcessor {
        port digitalInput : DigitalAudioPort;
        port channelOutput : ChannelDataPort;
        port powerInput : PowerPort;
        
        attribute numChannels : Integer = 22;
        attribute processingLatency : Duration_ms = 5.0;
        attribute clockFrequency : Frequency = 100000000.0;
        attribute powerConsumption : Power = 0.005;
        
        action def DecomposeIntoChannels {
            in digital : DigitalAudio;
            out channels : FrequencyChannel[1..*];
        }
        
        action def AssignElectrodeMapping {
            in channels : FrequencyChannel[1..*];
            out mappedChannels : FrequencyChannel[1..*];
        }
        
        perform action decompose : DecomposeIntoChannels {
            in digital = digitalInput.audio;
            out channels;
        }
        
        perform action mapElectrodes : AssignElectrodeMapping {
            in channels = decompose.channels;
            out mappedChannels = channelOutput.channels;
        }
    }
    
    part def StimulusGenerator {
        port channelInput : ChannelDataPort;
        port stimulusOutput : StimulusPort;
        port powerInput : PowerPort;
        
        attribute maxPulseAmplitude : Current = 0.001;
        attribute maxPulseWidth : Duration_ms = 0.4;
        attribute maxStimulationRate : Frequency = 1000.0;
        attribute powerConsumption : Power = 0.002;
        
        action def GenerateStimulus {
            in channels : FrequencyChannel[1..*];
            out pulses : StimulusPulse[1..*];
        }
        
        perform action generate : GenerateStimulus {
            in channels = channelInput.channels;
            out pulses = stimulusOutput.pulses;
        }
    }
    
    part def Electrode {
        attribute index : Integer;
        attribute surfaceArea : Area_mm2 = 0.5;
        attribute impedance : Impedance_kOhm = 5.0;
        attribute material : String = "Platinum-Iridium";
    }
    
    part def ElectrodeArray {
        port stimulusInput : StimulusPort;
        
        attribute electrodeCount : Integer = 22;
        attribute arrayLength : Length_mm = 25.0;
        attribute electrodeSpacing : Length_mm = 0.8;
        attribute insertionDepth : Length_mm = 20.0;
        attribute carrierMaterial : String = "Medical-grade silicone";
        
        part electrodes : Electrode[22] {
            attribute index redefines index = @index + 1;
        }
        
        action def DeliverStimulation {
            in pulses : StimulusPulse[1..*];
        }
        
        perform action deliver : DeliverStimulation {
            in pulses = stimulusInput.pulses;
        }
    }
    
    part def RechargeableBattery {
        port powerOutput : PowerPort;
        port chargingInput : ChargingPort;
        
        attribute capacity : Capacity_mAh = 200.0;
        attribute nominalVoltage : Voltage = 3.7;
        attribute currentCharge : Capacity_mAh = 200.0;
        attribute chargeCycles : Integer = 0;
        attribute maxChargeCycles : Integer = 2000;
        attribute batteryState : BatteryState = BatteryState::Full;
        attribute maxTemperature : Temperature = 315.0;
        
        action def Discharge {
            out energy : ElectricalEnergy;
        }
        
        action def Recharge {
            in energy : ElectricalEnergy;
        }
        
        perform action discharge : Discharge {
            out energy = powerOutput.energy;
        }
        
        perform action recharge : Recharge {
            in energy = chargingInput.energy;
        }
    }
    
    part def WirelessChargingCoil {
        port chargingOutput : PowerPort;
        
        attribute operatingFrequency : Frequency = 125000.0;
        attribute couplingEfficiency : Real = 0.85;
        attribute coilDiameter : Length_mm = 20.0;
        attribute turns : Integer = 15;
        attribute wireGauge : String = "AWG 38";
        
        action def ReceiveEnergy {
            out energy : ElectricalEnergy;
        }
        
        perform action receive : ReceiveEnergy {
            out energy = chargingOutput.energy;
        }
    }
    
    part def PowerDistributionBus {
        port batteryInput : PowerPort;
        port preprocessorOutput : PowerPort;
        port adcOutput : PowerPort;
        port dspOutput : PowerPort;
        port stimulusGenOutput : PowerPort;
        
        action def DistributePower {
            in energy : ElectricalEnergy;
            out toPreprocessor : ElectricalEnergy;
            out toADC : ElectricalEnergy;
            out toDSP : ElectricalEnergy;
            out toStimulusGen : ElectricalEnergy;
        }
        
        perform action distribute : DistributePower {
            in energy = batteryInput.energy;
            out toPreprocessor = preprocessorOutput.energy;
            out toADC = adcOutput.energy;
            out toDSP = dspOutput.energy;
            out toStimulusGen = stimulusGenOutput.energy;
        }
    }
    
    // ---- State Machine ----
    state def SystemOperation {
        entry action initializeSystem {
            /* Power on self-test, initialize DSP firmware */
        }
        
        state Off {
            entry action powerOffAllSubsystems {
                /* Disable all active components */
            }
            transition to Standby
                when battery.currentCharge > 0.0
                if battery.batteryState != BatteryState::Depleted;
        }
        
        state Standby {
            entry action enterLowPowerMode {
                /* Reduce clock speeds, disable stimulation */
            }
            transition to Active
                when microphone.acousticInput.sound.soundPressure > 0.001
                if battery.batteryState != BatteryState::Depleted;
            transition to Charging
                when chargingCoil.receive.energy.voltage > 0.0
                if true;
        }
        
        state Active {
            entry action enableSignalProcessing {
                /* Enable microphone, preprocessor, ADC, DSP, stimulus generator */
            }
            do action processAudioChain {
                /* Continuous sound capture and stimulation delivery */
            }
            transition to Standby
                when microphone.acousticInput.sound.soundPressure < 0.0005
                if true;
            transition to Charging
                when chargingCoil.receive.energy.voltage > 0.0
                if true;
            transition to Fault
                when battery.batteryState == BatteryState::Depleted
                if true;
        }
        
        state Charging {
            entry action enableWirelessCharging {
                /* Activate charging coil, monitor battery temperature */
            }
            do action chargeBattery {
                /* Battery recharging in progress */
            }
            transition to Standby
                when battery.batteryState == BatteryState::Full
                if true;
            transition to Fault
                when battery.maxTemperature > 315.0
                if true;
        }
        
        state Fault {
            entry action enterSafeMode {
                /* Disable all stimulation, preserve battery */
            }
            transition to Off
                if true;
        }
    }
    
    // ---- Main System Assembly ----
    part def TotallyImplantableCochlearImplant {
        attribute systemName : String = "TICI-22";
        attribute manufacturer : String = "BioHear Systems";
        attribute implantLocation : String = "Temporal bone recess";
        attribute designLifeYears : Integer = 25;
        attribute systemVersion : String = "1.0";
        
        port externalAcousticPort : AcousticPort;
        port externalChargingPort : ChargingPort;
        
        part enclosure : TitaniumEnclosure;
        
        part microphone : SubcutaneousMicrophone {
            port acousticInput : AcousticPort;
        }
        
        part preprocessor : SignalPreprocessor;
        part adc : AnalogToDigitalConverter;
        part dsp : DigitalSignalProcessor;
        part stimulusGen : StimulusGenerator;
        part electrodeArray : ElectrodeArray;
        part battery : RechargeableBattery;
        part chargingCoil : WirelessChargingCoil;
        part powerBus : PowerDistributionBus;
        
        // Connections - Signal Chain
        connection acousticToMicrophone
            connect externalAcousticPort to microphone.acousticInput;
        
        connection micToPreproc
            connect microphone.analogOutput to preprocessor.analogInput;
        
        connection preprocToADC
            connect preprocessor.analogOutput to adc.analogInput;
        
        connection adcToDSP
            connect adc.digitalOutput to dsp.digitalInput;
        
        connection dspToStimGen
            connect dsp.channelOutput to stimulusGen.channelInput;
        
        connection stimGenToElectrode
            connect stimulusGen.stimulusOutput to electrodeArray.stimulusInput;
        
        // Connections - Power Distribution
        connection batteryToBus
            connect battery.powerOutput to powerBus.batteryInput;
        
        connection busToPreprocessor
            connect powerBus.preprocessorOutput to preprocessor.powerInput;
        
        connection busToADC
            connect powerBus.adcOutput to adc.powerInput;
        
        connection busToDSP
            connect powerBus.dspOutput to dsp.powerInput;
        
        connection busToStimGen
            connect powerBus.stimulusGenOutput to stimulusGen.powerInput;
        
        // Connections - Charging
        connection externalChargingToCoil
            connect externalChargingPort to chargingCoil.chargingOutput;
        
        connection coilToBattery
            connect chargingCoil.chargingOutput to battery.chargingInput;
        
        // State machine
        exhibit state systemState : SystemOperation;
        
        // Requirement satisfaction
        satisfy req1 : FunctionalHearingRestoration by this;
        satisfy req2 : TotallyImplantableDesign by this;
        satisfy req3 : BiocompatibleEnclosure by enclosure;
        satisfy req4 : WirelessRecharging by chargingCoil;
        satisfy req5 : MultiChannelStimulation by electrodeArray;
    }
    
    // ---- Requirements ----
    req def FunctionalHearingRestoration {
        doc /* The system shall restore functional hearing in individuals with severe to profound hearing loss. */
        attribute targetPatientPopulation : String = "Severe to profound sensorineural hearing loss";
        attribute minimumSpeechUnderstanding_pct : Real = 60.0;
        attribute maxProcessingLatency_ms : Duration_ms = 10.0;
    }
    
    req def TotallyImplantableDesign {
        doc /* The system shall operate without any external hardware for daily operation. */
        attribute externalComponentsRequired : Integer = 0;
        attribute continuousOperationHours : Real = 24.0;
        attribute noExternalHardwareForDailyUse : Boolean = true;
    }
    
    req def BiocompatibleEnclosure {
        doc /* The entire system shall be housed within a hermetically sealed, biocompatible titanium enclosure designed for long-term implantation. */
        attribute enclosureMaterial : String = "Titanium";
        attribute hermeticSealLeakRate : Real = 1e-9;
        attribute biocompatibilityStandard : String = "ISO 10993";
        attribute designLifeYears : Integer = 25;
    }
    
    req def WirelessRecharging {
        doc /* The battery shall be rechargeable non-invasively through the skin via a wireless charging coil, eliminating the need for surgical battery replacements. */
        attribute chargingMethod : String = "Inductive coupling";
        attribute chargeTime_hours : Real = 2.0;
        attribute batteryReplacementRequired : Boolean = false;
        attribute minChargeCycles : Integer = 2000;
    }
    
    req def MultiChannelStimulation {
        doc /* The electrode array shall contain 22 individual electrodes surgically inserted into the cochlea, delivering electrical stimulation that bypasses damaged parts of the ear. */
        attribute electrodeCount : Integer = 22;
        attribute maxStimulationRatePerElectrode : Frequency = 1000.0;
        attribute frequencyChannels : Integer = 22;
        attribute maxPulseAmplitude : Current = 0.001;
        attribute insertionDepth_mm : Length_mm = 20.0;
    }
}
