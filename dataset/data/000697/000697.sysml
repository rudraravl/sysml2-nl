package 'Motorola APCOR System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Frequency {
        attribute value : Real;
        attribute unit : String = "MHz";
    }
    
    attribute def SignalStrength {
        attribute value : Real;
        attribute unit : String = "dBm";
    }
    
    attribute def DataRate {
        attribute value : Real;
        attribute unit : String = "kbps";
    }
    
    attribute def ChannelNumber {
        attribute value : Integer;
    }
    
    item def AudioSignal {
        attribute frequency : Frequency;
        attribute amplitude : SignalStrength;
    }
    
    item def RFSignal {
        attribute carrierFrequency : Frequency;
        attribute power : PowerValue;
        attribute modulation : String;
    }
    
    item def DigitalData {
        attribute payload : String;
        attribute rate : DataRate;
    }
    
    item def ControlCommand {
        attribute commandType : String;
        attribute channelNumber : ChannelNumber;
    }
    
    port def AudioPort {
        in item audioIn : AudioSignal;
        out item audioOut : AudioSignal;
    }
    
    port def RFPort {
        in item rfReceive : RFSignal;
        out item rfTransmit : RFSignal;
    }
    
    port def ControlPort {
        in item commandIn : ControlCommand;
        out attribute statusOut : String;
    }
    
    part def Microphone {
        out port audioOutput : AudioPort;
        
        action captureAudio {
            out capturedSignal : AudioSignal;
        }
    }
    
    part def Speaker {
        in port audioInput : AudioPort;
        
        action playAudio {
            in audioSignal : AudioSignal;
        }
    }
    
    part def AudioProcessor {
        in port micInput : AudioPort;
        out port spkOutput : AudioPort;
        out port digitalOutput;
        in port digitalInput;
        
        action processAudio {
            in audioSignal : AudioSignal;
            out processedAudio : AudioSignal;
        }
        
        action convertToDigital {
            in audioSignal : AudioSignal;
            out digitalData : DigitalData;
        }
        
        action convertToAnalog {
            in digitalData : DigitalData;
            out audioSignal : AudioSignal;
        }
    }
    
    part def Vocoder {
        in port analogInput;
        out port digitalOutput;
        in port digitalInput;
        out port analogOutput;
        
        action encodeVoice {
            in audio : AudioSignal;
            out encoded : DigitalData;
        }
        
        action decodeVoice {
            in encoded : DigitalData;
            out audio : AudioSignal;
        }
    }
    
    part def DigitalSignalProcessor {
        in port dataInput;
        out port dataOutput;
        in port controlInput : ControlPort;
        
        attribute currentChannel : ChannelNumber;
        attribute modulationType : String;
        
        action modulateSignal {
            in data : DigitalData;
            in channel : ChannelNumber;
            out modulatedSignal : RFSignal;
        }
        
        action demodulateSignal {
            in rfSignal : RFSignal;
            out data : DigitalData;
        }
        
        action selectChannel {
            in channelCmd : ChannelNumber;
            out selectedChannel : ChannelNumber;
        }
    }
    
    part def RFTransceiver {
        in port baseband;
        out port antenna : RFPort;
        in port control : ControlPort;
        
        attribute transmitPower : PowerValue;
        attribute receiveFrequency : Frequency;
        attribute operatingMode : String;
        
        action transmit {
            in signal : RFSignal;
            in power : PowerValue;
        }
        
        action receive {
            out signal : RFSignal;
        }
        
        action tuneFrequency {
            in targetFrequency : Frequency;
        }
    }
    
    part def PowerAmplifier {
        in port rfInput : RFPort;
        out port rfOutput : RFPort;
        in attribute powerSetting : PowerValue;
        
        attribute gain : Real;
        
        action amplify {
            in inputSignal : RFSignal;
            in gainSetting : Real;
            out outputSignal : RFSignal;
        }
    }
    
    part def Antenna {
        in port rfPort : RFPort;
        
        attribute frequency : Frequency;
        attribute gain : Real;
        attribute polarization : String;
    }
    
    part def Controller {
        out port systemControl : ControlPort;
        in attribute userInput : String;
        attribute systemStatus : String;
        
        action receiveCall;
        action transmitCall;
        action processUserCommand {
            in command : String;
            out controlCmd : ControlCommand;
        }
    }
    
    part def BatteryPack {
        attribute capacity : EnergyValue;
        attribute voltage : ElectricPotentialValue;
        attribute currentCharge : EnergyValue;
        
        action supplyPower {
            out powerOutput : PowerValue;
        }
    }
    
    part def APCORRadio {
        part microphone : Microphone;
        part speaker : Speaker;
        part audioProc : AudioProcessor;
        part vocoder : Vocoder;
        part dsp : DigitalSignalProcessor;
        part rfTransceiver : RFTransceiver;
        part powerAmp : PowerAmplifier;
        part antenna : Antenna;
        part controller : Controller;
        part battery : BatteryPack;
        
        connection micToAudioProc connect microphone.audioOutput to audioProc.micInput;
        connection audioProcToVocoder connect audioProc.digitalOutput to vocoder.analogInput;
        connection vocoderToDSP connect vocoder.digitalOutput to dsp.dataInput;
        connection dspToRF connect dsp.dataOutput to rfTransceiver.baseband;
        connection rfToPA connect rfTransceiver.antenna to powerAmp.rfInput;
        connection paToAntenna connect powerAmp.rfOutput to antenna.rfPort;
        
        connection dspFromRF connect rfTransceiver.baseband to dsp.dataInput;
        connection vocoderFromDSP connect dsp.dataOutput to vocoder.digitalInput;
        connection audioProcFromVocoder connect vocoder.analogOutput to audioProc.digitalInput;
        connection speakerFromAudioProc connect audioProc.spkOutput to speaker.audioInput;
        
        connection controlToDSP connect controller.systemControl to dsp.controlInput;
        connection controlToRF connect controller.systemControl to rfTransceiver.control;
    }
    
    action def CommunicateVoice {
        in voiceInput : AudioSignal;
        in channelConfig : ChannelNumber;
        out voiceOutput : AudioSignal;
    }
    
    action communicateOverRadio : CommunicateVoice {
        in voiceInput : AudioSignal;
        in channelConfig : ChannelNumber;
        out voiceOutput : AudioSignal;
        
        first start;
        then action captureAudio {
            in voice = voiceInput;
            out capturedSignal : AudioSignal;
        }
        then action processAudio {
            in audioSignal = captureAudio.capturedSignal;
            out processedAudio : AudioSignal;
        }
        then action encodeAudio {
            in audioSignal = processAudio.processedAudio;
            out digitalData : DigitalData;
        }
        then action modulateForTransmission {
            in data = encodeAudio.digitalData;
            in channel = channelConfig;
            out rfSignal : RFSignal;
        }
        then action transmitRF {
            in signal = modulateForTransmission.rfSignal;
        }
        then merge communicationLoop;
        
        then action receiveRF {
            out receivedSignal : RFSignal;
        }
        then action demodulateSignal {
            in rfSignal = receiveRF.receivedSignal;
            out decodedData : DigitalData;
        }
        then action decodeAudio {
            in data = demodulateSignal.decodedData;
            out audioSignal : AudioSignal;
        }
        then action playAudio {
            in audio = decodeAudio.audioSignal;
            out outputVoice = voiceOutput;
        }
        then communicationLoop;
    }
    
    requirement def CommunicationRequirement {
        doc /* The APCOR system shall provide reliable two-way voice communication 
               over assigned radio frequencies. */
        
        subject radio : APCORRadio;
        
        require constraint frequencyRange {
            doc /* Operating frequency shall be within allocated spectrum. */
        }
        
        require constraint audioQuality {
            doc /* Audio output shall maintain intelligibility under specified conditions. */
        }
        
        require constraint powerEfficiency {
            doc /* Battery life shall support minimum operational duration. */
        }
    }
    
    requirement <'APCOR-001'> primaryFunction : CommunicationRequirement {
        doc /* The Motorola APCOR system shall enable secure, reliable voice communication
               for public safety and commercial users operating in trunked radio networks.
               The system converts analog voice to digital format, modulates it onto 
               radio frequency carriers, transmits via antenna, receives incoming signals,
               demodulates and decodes them, and reproduces intelligible audio output. */
        
        subject apcorSystem : APCORRadio;
        
        assume constraint operatingEnvironment {
            doc /* System operates within specified temperature, humidity, and 
                   electromagnetic interference conditions. */
        }
        
        require constraint voiceLatency {
            doc /* End-to-end voice latency shall not exceed 200 milliseconds. */
        }
        
        require constraint channelSwitching {
            doc /* Channel switching time shall not exceed 500 milliseconds. */
        }
        
        require constraint transmitPowerControl {
            doc /* Transmit power shall be adjustable from 1W to 5W. */
        }
    }
    
    part apcorRadioSystem : APCORRadio {
        perform action communicate : CommunicateVoice;
        
        part :>> microphone {
            perform communicate.captureAudio;
        }
        part :>> speaker {
            perform communicate.playAudio;
        }
        part :>> audioProc {
            perform communicate.processAudio;
        }
        part :>> vocoder {
            perform communicate.encodeAudio;
            perform communicate.decodeAudio;
        }
        part :>> dsp {
            perform communicate.modulateForTransmission;
            perform communicate.demodulateSignal;
        }
        part :>> rfTransceiver {
            perform communicate.transmitRF;
            perform communicate.receiveRF;
        }
        part :>> powerAmp;
        part :>> antenna {
            attribute :>> frequency = Frequency { value = 800.0; };
            attribute :>> gain = 2.15;
        }
        part :>> controller;
        part :>> battery {
            attribute :>> capacity = 2000.0 [SI::Wh];
            attribute :>> voltage = 7.5 [SI::V];
        }
    }
}
