package 'Argus Retinal Prosthesis System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VisualFrame {
        attribute pixelData : Integer[*];
        attribute timestamp : ISQ::DurationValue;
        attribute brightness : Real;
    }
    
    attribute def StimulationPattern {
        attribute electrodeIndex : Integer;
        attribute pulseAmplitude : ISQ::ElectricCurrentValue;
        attribute pulseDuration : ISQ::DurationValue;
        attribute pulseFrequency : ISQ::FrequencyValue;
    }
    
    attribute def WirelessSignal {
        attribute dataPayload : StimulationPattern[*];
        attribute powerLevel : ISQ::PowerValue;
        attribute carrierFrequency : ISQ::FrequencyValue;
    }
    
    attribute def NeuralResponse {
        attribute activationLevel : Real;
        attribute responseLatency : ISQ::DurationValue;
    }
    
    attribute def SystemCommand;
    attribute def PowerOn :> SystemCommand;
    attribute def PowerOff :> SystemCommand;
    attribute def CalibrationMode :> SystemCommand;
    attribute def FrameReceived :> SystemCommand;
    attribute def ComputationComplete :> SystemCommand;
    attribute def TransmissionComplete :> SystemCommand;
    attribute def CalibrationComplete :> SystemCommand;
    
    port def VideoInputPort {
        out visualData : VisualFrame;
    }
    
    port def ProcessingPort {
        in rawFrame : VisualFrame;
        out stimPattern : StimulationPattern[*];
    }
    
    port def WirelessTxPort {
        in stimData : StimulationPattern[*];
        out wirelessOut : WirelessSignal;
    }
    
    port def WirelessRxPort {
        in wirelessIn : WirelessSignal;
        out receivedStim : StimulationPattern[*];
    }
    
    port def ElectrodePort {
        in stimCommands : StimulationPattern[*];
        out electricalPulses : ISQ::ElectricCurrentValue[*];
    }
    
    port def RetinalInterfacePort {
        in stimulationCurrent : ISQ::ElectricCurrentValue[*];
        out neuralActivity : NeuralResponse;
    }
    
    action def CaptureVisualScene {
        in ambientLight : ISQ::IlluminanceValue;
        out capturedFrame : VisualFrame;
    }
    
    action def ProcessVideoFrame {
        in rawFrame : VisualFrame;
        out stimulationMap : StimulationPattern[*];
    }
    
    action def TransmitWirelessSignal {
        in stimData : StimulationPattern[*];
        in powerSupply : ISQ::PowerValue;
        out wirelessSignal : WirelessSignal;
    }
    
    action def ReceiveWirelessSignal {
        in wirelessSignal : WirelessSignal;
        out decodedStim : StimulationPattern[*];
        out harvestedPower : ISQ::PowerValue;
    }
    
    action def GenerateElectricalPulses {
        in stimPattern : StimulationPattern[*];
        in powerSupply : ISQ::PowerValue;
        out currentPulses : ISQ::ElectricCurrentValue[*];
    }
    
    action def DeliverRetinalStimulation {
        in currentPulses : ISQ::ElectricCurrentValue[*];
        out appliedStimulation : ISQ::ElectricCurrentValue[*];
    }
    
    action def GenerateNeuralResponse {
        in appliedStimulation : ISQ::ElectricCurrentValue[*];
        out neuralActivity : NeuralResponse;
    }
    
    part def MiniatureCamera {
        doc /* External camera mounted on eyeglasses to capture visual scene */
        
        attribute resolution : Integer = 60;
        attribute frameRate : ISQ::FrequencyValue = 30.0 [SI::Hz];
        attribute fieldOfView : Real = 20.0;
        
        port videoOutput : VideoInputPort;
        
        perform action captureScene : CaptureVisualScene;
    }
    
    part def VideoProcessingUnit {
        doc /* External processor that converts video frames into electrode stimulation patterns */
        
        attribute processingLatency : ISQ::DurationValue = 0.033 [SI::s];
        attribute powerConsumption : ISQ::PowerValue = 1.5 [SI::W];
        attribute numberOfElectrodes : Integer = 60;
        
        port videoInput : ProcessingPort;
        port stimOutput : ProcessingPort;
        
        perform action processFrame : ProcessVideoFrame;
    }
    
    part def ExternalTransmitter {
        doc /* External coil that wirelessly transmits power and data to implant */
        
        attribute transmissionPower : ISQ::PowerValue = 0.25 [SI::W];
        attribute transmissionFrequency : ISQ::FrequencyValue = 13.56e6 [SI::Hz];
        attribute dataRate : Real = 10.0e6;
        
        port dataInput : WirelessTxPort;
        port wirelessOutput : WirelessTxPort;
        
        perform action transmitWireless : TransmitWirelessSignal;
    }
    
    part def ImplantedReceiver {
        doc /* Implanted coil and electronics that receive wireless power and data */
        
        attribute receiverSensitivity : ISQ::PowerValue = 0.001 [SI::W];
        attribute decodingLatency : ISQ::DurationValue = 0.001 [SI::s];
        
        port wirelessInput : WirelessRxPort;
        port dataOutput : WirelessRxPort;
        
        perform action receiveWireless : ReceiveWirelessSignal;
    }
    
    part def StimulatorElectronics {
        doc /* Implanted electronics that generate precise electrical pulses */
        
        attribute maxCurrent : ISQ::ElectricCurrentValue = 0.0015 [SI::'A'];
        attribute minPulseDuration : ISQ::DurationValue = 0.00001 [SI::s];
        attribute numberOfChannels : Integer = 60;
        
        port stimInput : ElectrodePort;
        port pulseOutput : ElectrodePort;
        
        perform action generatePulses : GenerateElectricalPulses;
    }
    
    part def ElectrodeArray {
        doc /* Implanted array of 60 electrodes positioned on retinal surface */
        
        attribute numberOfElectrodes : Integer = 60;
        attribute electrodeSpacing : ISQ::LengthValue = 0.000525 [SI::m];
        attribute arrayDimensions : String = "6x10";
        attribute electrodeDiameter : ISQ::LengthValue = 0.0002 [SI::m];
        
        port pulseInput : ElectrodePort;
        port retinalOutput : RetinalInterfacePort;
        
        perform action deliverStimulation : DeliverRetinalStimulation;
    }
    
    part def RetinalTissue {
        doc /* Target retinal ganglion cells that respond to electrical stimulation */
        
        port stimulationInput : RetinalInterfacePort;
        
        perform action respondToStimulation : GenerateNeuralResponse;
    }
    
    part def ArgusRetinalProsthesis {
        doc /* Complete Argus II retinal prosthesis system for vision restoration */
        
        part externalComponents {
            doc /* Components worn externally by the patient */
            
            part camera : MiniatureCamera {
                attribute resolution = 60;
                attribute frameRate = 30.0 [SI::Hz];
            }
            
            part vpu : VideoProcessingUnit {
                attribute processingLatency = 0.033 [SI::s];
                attribute numberOfElectrodes = 60;
            }
            
            part transmitter : ExternalTransmitter {
                attribute transmissionPower = 0.25 [SI::W];
                attribute transmissionFrequency = 13.56e6 [SI::Hz];
            }
            
            connect camera.videoOutput to vpu.videoInput;
            connect vpu.stimOutput to transmitter.dataInput;
        }
        
        part implantedComponents {
            doc /* Components surgically implanted in and around the eye */
            
            part receiver : ImplantedReceiver {
                attribute receiverSensitivity = 0.001 [SI::W];
            }
            
            part stimulator : StimulatorElectronics {
                attribute maxCurrent = 0.0015 [SI::'A'];
                attribute numberOfChannels = 60;
            }
            
            part electrodes : ElectrodeArray {
                attribute numberOfElectrodes = 60;
                attribute electrodeSpacing = 0.000525 [SI::m];
            }
            
            part retina : RetinalTissue;
            
            connect receiver.dataOutput to stimulator.stimInput;
            connect stimulator.pulseOutput to electrodes.pulseInput;
            connect electrodes.retinalOutput to retina.stimulationInput;
        }
        
        connect externalComponents.transmitter.wirelessOutput to implantedComponents.receiver.wirelessInput;
    }
    
    action def RestoreVisualPerception {
        doc /* Primary system function: Convert visual scenes into electrical stimulation to evoke visual perception */
        
        first start;
        
        then merge continuousOperation;
        
        then action capture : CaptureVisualScene {
            in ambientLight : ISQ::IlluminanceValue;
            out capturedFrame : VisualFrame;
        }
        
        flow capture.capturedFrame to process.rawFrame;
        
        then action process : ProcessVideoFrame {
            in rawFrame : VisualFrame;
            out stimulationMap : StimulationPattern[*];
        }
        
        flow process.stimulationMap to transmit.stimData;
        
        then action transmit : TransmitWirelessSignal {
            in stimData : StimulationPattern[*];
            in powerSupply : ISQ::PowerValue;
            out wirelessSignal : WirelessSignal;
        }
        
        flow transmit.wirelessSignal to receive.wirelessSignal;
        
        then action receive : ReceiveWirelessSignal {
            in wirelessSignal : WirelessSignal;
            out decodedStim : StimulationPattern[*];
            out harvestedPower : ISQ::PowerValue;
        }
        
        flow receive.decodedStim to generatePulses.stimPattern;
        flow receive.harvestedPower to generatePulses.powerSupply;
        
        then action generatePulses : GenerateElectricalPulses {
            in stimPattern : StimulationPattern[*];
            in powerSupply : ISQ::PowerValue;
            out currentPulses : ISQ::ElectricCurrentValue[*];
        }
        
        flow generatePulses.currentPulses to deliver.currentPulses;
        
        then action deliver : DeliverRetinalStimulation {
            in currentPulses : ISQ::ElectricCurrentValue[*];
            out appliedStimulation : ISQ::ElectricCurrentValue[*];
        }
        
        flow deliver.appliedStimulation to respond.appliedStimulation;
        
        then action respond : GenerateNeuralResponse {
            in appliedStimulation : ISQ::ElectricCurrentValue[*];
            out neuralActivity : NeuralResponse;
        }
        
        then continuousOperation;
    }
    
    requirement def SafetyRequirement {
        doc /* Safety requirements for implanted medical device */
    }
    
    requirement <'ARG-SAF-001'> stimulationSafety : SafetyRequirement {
        doc /* Electrical stimulation must remain within safe limits to prevent tissue damage */
        
        subject electrodes : ElectrodeArray;
        
        require constraint {
            doc /* Maximum current per electrode shall not exceed 1.5 mA */
            electrodes.maxCurrent <= 0.0015 [SI::'A']
        }
        
        require constraint {
            doc /* Maximum charge density shall not exceed 0.35 mC/cm² per phase */
        }
    }
    
    requirement <'ARG-SAF-002'> biocompatibility : SafetyRequirement {
        doc /* All implanted materials must be biocompatible */
        
        require constraint {
            doc /* Materials shall meet ISO 10993 biocompatibility standards */
        }
    }
    
    requirement def FunctionalRequirement {
        doc /* Functional requirements for vision restoration */
    }
    
    requirement <'ARG-FUN-001'> visualRestoration : FunctionalRequirement {
        doc /* System shall restore basic visual perception to blind patients with retinitis pigmentosa */
        
        subject system : ArgusRetinalProsthesis;
        
        require constraint {
            doc /* System shall provide minimum 60 independent stimulation points */
            system.implantedComponents.electrodes.numberOfElectrodes >= 60
        }
        
        require constraint {
            doc /* System shall operate at minimum 30 Hz frame rate */
            system.externalComponents.camera.frameRate >= 30.0 [SI::Hz]
        }
    }
    
    requirement <'ARG-FUN-002'> systemLatency : FunctionalRequirement {
        doc /* End-to-end latency requirement for real-time perception */
        
        subject system : ArgusRetinalProsthesis;
        
        require constraint {
            doc /* Total latency from image capture to retinal stimulation shall be less than 100 ms */
            system.externalComponents.vpu.processingLatency + 
            system.implantedComponents.receiver.decodingLatency < 0.1 [SI::s]
        }
    }
    
    requirement <'ARG-FUN-003'> wirelessReliability : FunctionalRequirement {
        doc /* Wireless link must maintain reliable operation */
        
        require constraint {
            doc /* Wireless data link shall maintain 99.9% uptime during active operation */
        }
        
        require constraint {
            doc /* Power transfer efficiency shall exceed 40% */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* Performance requirements for device operation */
    }
    
    requirement <'ARG-PER-001'> batteryLife : PerformanceRequirement {
        doc /* External battery must support full day of use */
        
        require constraint {
            doc /* External battery shall provide minimum 8 hours continuous operation */
        }
    }
    
    requirement <'ARG-PER-002'> deviceLongevity : PerformanceRequirement {
        doc /* Implanted components must function over device lifetime */
        
        require constraint {
            doc /* Implanted components shall maintain functionality for minimum 10 years */
        }
    }
    
    requirement <'ARG-PER-003'> spatialResolution : PerformanceRequirement {
        doc /* Electrode array must provide adequate spatial resolution */
        
        subject electrodes : ElectrodeArray;
        
        require constraint {
            doc /* Electrode spacing shall be 525 micrometers for 6x10 array */
            electrodes.electrodeSpacing == 0.000525 [SI::m]
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for Argus retinal prosthesis system */
        
        require visualRestoration;
        require systemLatency;
        require wirelessReliability;
        require stimulationSafety;
        require biocompatibility;
        require batteryLife;
        require deviceLongevity;
        require spatialResolution;
    }
    
    part argusSystem : ArgusRetinalProsthesis {
        satisfy systemRequirements;
        
        perform action restoreVision : RestoreVisualPerception {
            references externalComponents.camera perform capture;
            references externalComponents.vpu perform process;
            references externalComponents.transmitter perform transmit;
            references implantedComponents.receiver perform receive;
            references implantedComponents.stimulator perform generatePulses;
            references implantedComponents.electrodes perform deliver;
            references implantedComponents.retina perform respond;
        }
    }
}
