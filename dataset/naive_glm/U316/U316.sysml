package MotorolaAPCORRadio {

  import ScalarValues::*;

  package Units {
    unit MHz;
    unit W;
    unit V;
    unit mA;
    unit dBm;
    unit kbps;
    unit Hz;
  }

  package ValueTypes {
    value def Frequency :> Real { unit MHz; }
    value def RFPower :> Real { unit W; }
    value def Voltage :> Real { unit V; }
    value def Current :> Real { unit mA; }
    value def SignalStrength :> Real { unit dBm; }
    value def BitRate :> Real { unit kbps; }
    value def AudioLevel :> Real;
    value def StateOfCharge :> Real;
  }

  package Items {
    item def AnalogAudio {
      attribute level : AudioLevel;
      attribute bandwidth : Frequency;
    }
    item def DigitalVoiceData {
      attribute bitRate : BitRate;
      attribute frameNumber : Integer;
      attribute encrypted : Boolean;
    }
    item def ModulatedSignal {
      attribute carrierFreq : Frequency;
      attribute modulationType : String;
      attribute symbolRate : BitRate;
    }
    item def RFSignal {
      attribute frequency : Frequency;
      attribute strength : SignalStrength;
      attribute bandwidth : Frequency;
    }
    item def ControlCommand {
      attribute commandType : String;
      attribute target : String;
      attribute priority : Integer;
    }
    item def UserInput {
      attribute inputType : String;
      attribute value : String;
    }
    item def DisplayInfo {
      attribute text : String;
      attribute channel : Integer;
      attribute batteryLevel : StateOfCharge;
    }
    item def ElectricalPower {
      attribute voltage : Voltage;
      attribute current : Current;
    }
  }

  package Ports {
    port def AnalogAudioOut { out item : AnalogAudio; }
    port def AnalogAudioIn { in item : AnalogAudio; }
    port def DigitalDataOut { out item : DigitalVoiceData; }
    port def DigitalDataIn { in item : DigitalVoiceData; }
    port def ModulatedOut { out item : ModulatedSignal; }
    port def ModulatedIn { in item : ModulatedSignal; }
    port def RFOut { out item : RFSignal; }
    port def RFIn { in item : RFSignal; }
    port def ControlOut { out item : ControlCommand; }
    port def ControlIn { in item : ControlCommand; }
    port def UserInputPort { in item : UserInput; }
    port def DisplayPort { out item : DisplayInfo; }
    port def PowerOut { out item : ElectricalPower; }
    port def PowerIn { in item : ElectricalPower; }
  }

  package Components {

    part def Microphone {
      port audioOut : AnalogAudioOut;
      attribute sensitivity : Real;
      attribute impedance : Real;
      action def CaptureVoice {
        in soundPressure : Real;
        out audio : AnalogAudio;
      }
      perform action capture : CaptureVoice;
    }

    part def Speaker {
      port audioIn : AnalogAudioIn;
      attribute maxVolume : AudioLevel;
      attribute impedance : Real;
      action def PlayAudio {
        in audio : AnalogAudio;
      }
      perform action play : PlayAudio;
    }

    part def AudioProcessor {
      port txIn : AnalogAudioIn;
      port txOut : AnalogAudioOut;
      port rxIn : AnalogAudioIn;
      port rxOut : AnalogAudioOut;
      attribute txGain : Real;
      attribute rxGain : Real;
      attribute noiseFilterEnabled : Boolean;
      action def ConditionTX {
        in raw : AnalogAudio;
        out conditioned : AnalogAudio;
      }
      action def ConditionRX {
        in raw : AnalogAudio;
        out conditioned : AnalogAudio;
      }
      perform action conditionTx : ConditionTX;
      perform action conditionRx : ConditionRX;
    }

    part def Vocoder {
      port analogIn : AnalogAudioIn;
      port digitalOut : DigitalDataOut;
      port digitalIn : DigitalDataIn;
      port analogOut : AnalogAudioOut;
      attribute codecType : String;
      attribute compressionRatio : Real;
      action def Encode {
        in audio : AnalogAudio;
        out data : DigitalVoiceData;
      }
      action def Decode {
        in data : DigitalVoiceData;
        out audio : AnalogAudio;
      }
      perform action encode : Encode;
      perform action decode : Decode;
    }

    part def DSP {
      port txDataIn : DigitalDataIn;
      port txModOut : ModulatedOut;
      port rxModIn : ModulatedIn;
      port rxDataOut : DigitalDataOut;
      port controlIn : ControlIn;
      attribute channelFrequency : Frequency;
      attribute modulationScheme : String;
      attribute encryptionEnabled : Boolean;
      action def Modulate {
        in data : DigitalVoiceData;
        in freq : Frequency;
        out modulated : ModulatedSignal;
      }
      action def Demodulate {
        in modulated : ModulatedSignal;
        out data : DigitalVoiceData;
      }
      perform action modulate : Modulate;
      perform action demodulate : Demodulate;
    }

    part def RFTransceiver {
      port txModIn : ModulatedIn;
      port txRFOut : RFOut;
      port rxRFIn : RFIn;
      port rxModOut : ModulatedOut;
      port controlIn : ControlIn;
      attribute tunedFrequency : Frequency;
      attribute txPower : RFPower;
      attribute rxSensitivity : SignalStrength;
      action def Upconvert {
        in modulated : ModulatedSignal;
        out rf : RFSignal;
      }
      action def Downconvert {
        in rf : RFSignal;
        out modulated : ModulatedSignal;
      }
      perform action upconvert : Upconvert;
      perform action downconvert : Downconvert;
    }

    part def PowerAmplifier {
      port rfIn : RFIn;
      port rfOut : RFOut;
      port powerIn : PowerIn;
      attribute gain : Real;
      attribute maxOutputPower : RFPower;
      attribute efficiency : Real;
      action def Amplify {
        in rf : RFSignal;
        out amplified : RFSignal;
      }
      perform action amplify : Amplify;
    }

    part def Antenna {
      port txRFIn : RFIn;
      port rxRFOut : RFOut;
      attribute frequencyRange : Frequency;
      attribute vswr : Real;
      attribute gain_dBi : Real;
      action def Transmit {
        in rf : RFSignal;
      }
      action def Receive {
        out rf : RFSignal;
      }
      perform action transmit : Transmit;
      perform action receive : Receive;
    }

    part def UserInterface {
      port userInputOut : Ports::UserInputPort;
      port displayIn : Ports::DisplayPort;
      attribute channelCount : Integer;
      attribute keypadLayout : String;
      action def ReadInput {
        out input : UserInput;
      }
      action def UpdateDisplay {
        in info : DisplayInfo;
      }
      perform action readInput : ReadInput;
      perform action updateDisplay : UpdateDisplay;
    }

    part def Controller {
      port userInputIn : Ports::UserInputPort;
      port displayOut : Ports::DisplayPort;
      port dspControl : ControlOut;
      port rfControl : ControlOut;
      attribute currentChannel : Integer;
      attribute volume : AudioLevel;
      attribute callActive : Boolean;

      action def ProcessUserInput {
        in input : UserInput;
        out command : ControlCommand;
        out display : DisplayInfo;
      }
      perform action processInput : ProcessUserInput;

      state def ControllerBehavior {
        entry action { /* initialize controller */ }
        state Idle {
          entry action { /* monitor for incoming calls or user input */ }
        }
        state Receiving {
          entry action { /* coordinate DSP and RFTransceiver for RX */ }
        }
        state Transmitting {
          entry action { /* coordinate DSP and RFTransceiver for TX */ }
        }
        transition idleToTx
          first Idle then Transmitting
          when userInputIn.input.inputType == "PTT";
        transition txToIdle
          first Transmitting then Idle
          when userInputIn.input.inputType == "PTT_Release";
        transition idleToRx
          first Idle then Receiving
          when rfControl.command.commandType == "IncomingCall";
        transition rxToIdle
          first Receiving then Idle
          when rfControl.command.commandType == "CallEnd";
      }
      perform state behavior : ControllerBehavior;
    }

    part def BatteryPack {
      port powerOut : PowerOut;
      attribute nominalVoltage : Voltage;
      attribute capacity_mAh : Real;
      attribute stateOfCharge : StateOfCharge;
      attribute rechargeable : Boolean;
      action def SupplyPower {
        out power : ElectricalPower;
      }
      perform action supply : SupplyPower;
    }

  }

  package Requirements {

    requirement def RadioCommunicationRequirement {
      doc /* The APCOR radio shall provide secure and reliable digital voice communication. */
      attribute requiredRange_km : Real;
      attribute requiredBatteryLife_h : Real;
      attribute supportedChannels : Integer;
    }

    requirement def TransmissionRequirement {
      doc /* The radio shall transmit digitized voice over an RF channel. */
      subject transmitter : Components::RFTransceiver;
      attribute maxTxPower : RFPower;
      attribute frequencyAccuracy : Frequency;
    }

    requirement def ReceptionRequirement {
      doc /* The radio shall receive and decode incoming digital voice signals. */
      subject receiver : Components::RFTransceiver;
      attribute minSensitivity : SignalStrength;
    }

    requirement def PowerRequirement {
      doc /* The radio shall operate from a rechargeable battery pack. */
      subject battery : Components::BatteryPack;
      attribute minRuntime_h : Real;
      attribute nominalVoltage : Voltage;
    }

    requirement def SecurityRequirement {
      doc /* The radio shall support encrypted digital voice communication. */
      subject dsp : Components::DSP;
      attribute encryptionRequired : Boolean;
    }

  }

  package APCORRadioSystem {

    part def APCORRadio {

      part microphone : Components::Microphone;
      part speaker : Components::Speaker;
      part audioProcessor : Components::AudioProcessor;
      part vocoder : Components::Vocoder;
      part dsp : Components::DSP;
      part rfTransceiver : Components::RFTransceiver;
      part powerAmplifier : Components::PowerAmplifier;
      part antenna : Components::Antenna;
      part userInterface : Components::UserInterface;
      part controller : Components::Controller;
      part batteryPack : Components::BatteryPack;

      connection micToAudioProc
        connect microphone.audioOut to audioProcessor.txIn;
      connection audioProcToVocoder
        connect audioProcessor.txOut to vocoder.analogIn;
      connection vocoderToDSP
        connect vocoder.digitalOut to dsp.txDataIn;
      connection dspToRFTransceiver
        connect dsp.txModOut to rfTransceiver.txModIn;
      connection rfTransceiverToPA
        connect rfTransceiver.txRFOut to powerAmplifier.rfIn;
      connection paToAntenna
        connect powerAmplifier.rfOut to antenna.txRFIn;

      connection antennaToRFTransceiver
        connect antenna.rxRFOut to rfTransceiver.rxRFIn;
      connection rfTransceiverToDSP
        connect rfTransceiver.rxModOut to dsp.rxModIn;
      connection dspToVocoder
        connect dsp.rxDataOut to vocoder.digitalIn;
      connection vocoderToAudioProc
        connect vocoder.analogOut to audioProcessor.rxIn;
      connection audioProcToSpeaker
        connect audioProcessor.rxOut to speaker.audioIn;

      connection uiToController
        connect userInterface.userInputOut to controller.userInputIn;
      connection controllerToUIDisplay
        connect controller.displayOut to userInterface.displayIn;
      connection controllerToDSP
        connect controller.dspControl to dsp.controlIn;
      connection controllerToRFTransceiver
        connect controller.rfControl to rfTransceiver.controlIn;

      connection batteryToPA
        connect batteryPack.powerOut to powerAmplifier.powerIn;

      satisfy Requirements::RadioCommunicationRequirement {
        requiredRange_km = 30.0;
        requiredBatteryLife_h = 8.0;
        supportedChannels = 16;
      }
      satisfy Requirements::TransmissionRequirement by rfTransceiver {
        maxTxPower = 5.0 [W];
        frequencyAccuracy = 0.001 [MHz];
      }
      satisfy Requirements::ReceptionRequirement by rfTransceiver {
        minSensitivity = -120.0 [dBm];
      }
      satisfy Requirements::PowerRequirement by batteryPack {
        minRuntime_h = 8.0;
        nominalVoltage = 7.5 [V];
      }
      satisfy Requirements::SecurityRequirement by dsp {
        encryptionRequired = true;
      }

    }

  }

}
