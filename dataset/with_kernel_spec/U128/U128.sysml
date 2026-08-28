package TotallyImplantableCochlearImplant {
    private import ISQ::*;
    private import ScalarValues::*;

    item def SoundWave;
    item def AnalogSignal;
    item def DigitalAudio;
    item def ElectricalPulse;

    attribute def PowerValue :> Real {
        unit "W";
    }

    part def TitaniumEnclosure {
        attribute material : String = "Titanium";
        attribute hermeticallySealed : Boolean = true;
        attribute biocompatible : Boolean = true;
    }

    part def SubcutaneousMicrophone {
        port soundIn { in sound : SoundWave; }
        port analogOut { out analogSignal : AnalogSignal; }
        port powerIn { in power : PowerValue; }
    }

    part def SignalPreprocessor {
        port analogIn { in analogSignal : AnalogSignal; }
        port analogOut { out processedAnalogSignal : AnalogSignal; }
        port powerIn { in power : PowerValue; }
    }

    part def AnalogToDigitalConverter {
        port analogIn { in processedAnalogSignal : AnalogSignal; }
        port digitalOut { out digitalAudio : DigitalAudio; }
        port powerIn { in power : PowerValue; }
    }

    part def DigitalSignalProcessor {
        port digitalIn { in digitalAudio : DigitalAudio; }
        port stimulusCmdOut { out stimulusCommand : DigitalAudio; }
        port powerIn { in power : PowerValue; }
    }

    part def StimulusGenerator {
        port cmdIn { in stimulusCommand : DigitalAudio; }
        port pulseOut { out electricalPulse : ElectricalPulse; }
        port powerIn { in power : PowerValue; }
    }

    part def ElectrodeArray {
        attribute electrodeCount : Integer = 22;
        port pulseIn { in electricalPulse : ElectricalPulse; }
        port nerveStimOut { out nerveStimulation : ElectricalPulse; }
    }

    part def InternalBattery {
        attribute chargeLevel : Real;
        port powerChargeIn { in chargePower : PowerValue; }
        port powerOut { out supplyPower : PowerValue; }
    }

    part def WirelessChargingCoil {
        port chargeOut { out chargePower : PowerValue; }
    }

    part def ImplantableCochlearImplant {
        attribute soundPresent : Boolean;
        attribute chargerPresent : Boolean;
        attribute chargeComplete : Boolean;

        part enclosure : TitaniumEnclosure;
        part microphone : SubcutaneousMicrophone;
        part preprocessor : SignalPreprocessor;
        part adc : AnalogToDigitalConverter;
        part dsp : DigitalSignalProcessor;
        part stimGen : StimulusGenerator;
        part electrodeArray : ElectrodeArray;
        part battery : InternalBattery;
        part chargeCoil : WirelessChargingCoil;

        interface micToPreprocessor connect microphone.analogOut to preprocessor.analogIn {
            flow analogSignalFlow of AnalogSignal from microphone.analogOut.analogSignal to preprocessor.analogIn.analogSignal;
        }
        interface preprocToADC connect preprocessor.analogOut to adc.analogIn {
            flow processedAnalogFlow of AnalogSignal from preprocessor.analogOut.processedAnalogSignal to adc.analogIn.processedAnalogSignal;
        }
        interface adcToDSP connect adc.digitalOut to dsp.digitalIn {
            flow digitalAudioFlow of DigitalAudio from adc.digitalOut.digitalAudio to dsp.digitalIn.digitalAudio;
        }
        interface dspToStimGen connect dsp.stimulusCmdOut to stimGen.cmdIn {
            flow stimulusCmdFlow of DigitalAudio from dsp.stimulusCmdOut.stimulusCommand to stimGen.cmdIn.stimulusCommand;
        }
        interface stimGenToElectrode connect stimGen.pulseOut to electrodeArray.pulseIn {
            flow electricalPulseFlow of ElectricalPulse from stimGen.pulseOut.electricalPulse to electrodeArray.pulseIn.electricalPulse;
        }
        interface coilToBattery connect chargeCoil.chargeOut to battery.powerChargeIn {
            flow chargePowerFlow of PowerValue from chargeCoil.chargeOut.chargePower to battery.powerChargeIn.chargePower;
        }
        interface batteryToMic connect battery.powerOut to microphone.powerIn {
            flow powerFlowMic of PowerValue from battery.powerOut.supplyPower to microphone.powerIn.power;
        }
        interface batteryToPreproc connect battery.powerOut to preprocessor.powerIn {
            flow powerFlowPreproc of PowerValue from battery.powerOut.supplyPower to preprocessor.powerIn.power;
        }
        interface batteryToADC connect battery.powerOut to adc.powerIn {
            flow powerFlowADC of PowerValue from battery.powerOut.supplyPower to adc.powerIn.power;
        }
        interface batteryToDSP connect battery.powerOut to dsp.powerIn {
            flow powerFlowDSP of PowerValue from battery.powerOut.supplyPower to dsp.powerIn.power;
        }
        interface batteryToStimGen connect battery.powerOut to stimGen.powerIn {
            flow powerFlowStimGen of PowerValue from battery.powerOut.supplyPower to stimGen.powerIn.power;
        }

        state machine def implantStateMachine {
            state Off;
            state Idle;
            state Active;
            state Charging;

            transition from Off to Idle when battery.chargeLevel >= 10.0;
            transition from Idle to Active when soundPresent;
            transition from Active to Idle when soundPresent == false;
            transition from Idle to Charging when chargerPresent;
            transition from Active to Charging when chargerPresent;
            transition from Charging to Idle when chargeComplete;
            transition from Idle to Off when battery.chargeLevel < 10.0;
            transition from Active to Off when battery.chargeLevel < 10.0;
            transition from Charging to Off when battery.chargeLevel < 10.0;
        }

        constraint electrodeCountConstraint {
            electrodeArray.electrodeCount == 22;
        }
    }

    action def 'Capture Sound' { in sound : SoundWave; out analogSignal : AnalogSignal; }
    action def 'Preprocess Signal' { in analogSignal : AnalogSignal; out processedAnalogSignal : AnalogSignal; }
    action def 'Convert to Digital' { in processedAnalogSignal : AnalogSignal; out digitalAudio : DigitalAudio; }
    action def 'Process Audio' { in digitalAudio : DigitalAudio; out stimulusCommand : DigitalAudio; }
    action def 'Generate Stimulus' { in stimulusCommand : DigitalAudio; out electricalPulse : ElectricalPulse; }
    action def 'Stimulate Nerve' { in electricalPulse : ElectricalPulse; }

    action 'restore hearing' {
        in sound : SoundWave;
        action 'capture sound': 'Capture Sound' {
            in sound = 'restore hearing'::sound;
            out analogSignal : AnalogSignal;
        }
        flow 'capture sound'.analogSignal to 'preprocess signal'.analogSignal;
        action 'preprocess signal': 'Preprocess Signal' {
            in analogSignal : AnalogSignal;
            out processedAnalogSignal : AnalogSignal;
        }
        flow 'preprocess signal'.processedAnalogSignal to 'convert to digital'.processedAnalogSignal;
        action 'convert to digital': 'Convert to Digital' {
            in processedAnalogSignal : AnalogSignal;
            out digitalAudio : DigitalAudio;
        }
        flow 'convert to digital'.digitalAudio to 'process audio'.digitalAudio;
        action 'process audio': 'Process Audio' {
            in digitalAudio : DigitalAudio;
            out stimulusCommand : DigitalAudio;
        }
        flow 'process audio'.stimulusCommand to 'generate stimulus'.stimulusCommand;
        action 'generate stimulus': 'Generate Stimulus' {
            in stimulusCommand : DigitalAudio;
            out electricalPulse : ElectricalPulse;
        }
        flow 'generate stimulus'.electricalPulse to 'stimulate nerve'.electricalPulse;
        action 'stimulate nerve': 'Stimulate Nerve' {
            in electricalPulse : ElectricalPulse;
        }
    }

    requirement def TotallyImplantable {
        doc /* The system shall be fully implantable with no external hardware required for daily operation. */
    }
    requirement def HermeticSealing {
        doc /* The enclosure shall be hermetically sealed to prevent ingress of body fluids. */
    }
    requirement def Biocompatible {
        doc /* All materials in contact with body tissue shall be biocompatible. */
    }
    requirement def WirelessCharging {
        doc /* The battery shall be rechargeable wirelessly through the skin. */
    }
    requirement def ElectrodeCount {
        doc /* The electrode array shall contain exactly 22 individual electrodes. */
    }
    requirement def SignalProcessingChain {
        doc /* The system shall process sound through a microphone, preprocessor, ADC, DSP, and stimulus generator. */
    }

    part patientImplant : ImplantableCochlearImplant;

    satisfy TotallyImplantable by patientImplant;
    satisfy HermeticSealing by patientImplant.enclosure;
    satisfy Biocompatible by patientImplant.enclosure;
    satisfy WirelessCharging by patientImplant.chargeCoil;
    satisfy ElectrodeCount by patientImplant.electrodeArray;
    satisfy SignalProcessingChain by patientImplant;
}
