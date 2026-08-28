package UltrasoundImagingSystem {
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        private import ISQ::*;
        private import SI::*;

        enum def ImagingMode {
            BMode;
            MMode;
            Doppler;
        }

        attribute def FrequencyValue :> ScalarValues::Real {
            :>> unit = Hz;
        }

        attribute def DepthValue :> ScalarValues::Real {
            :>> unit = m;
        }

        attribute def AcousticEnergyValue :> ScalarValues::Real {
            :>> unit = J;
        }

        attribute def FrameRateValue :> ScalarValues::Real {
            :>> unit = Hz;
        }

        item def UltrasoundPulse {
            attribute frequency : FrequencyValue;
            attribute focalDepth : DepthValue;
        }

        item def Echo;
        item def ElectricalSignal;
        item def ScanLine;
        item def ImageFrame;

        port def AcousticPort {
            out item pulse : UltrasoundPulse;
            in item echo : Echo;
        }

        port def SignalOutPort {
            out item signal : ElectricalSignal;
        }

        port def SignalInPort {
            in item signal : ElectricalSignal;
        }

        port def ImageOutPort {
            out item imgFrame : ImageFrame;
        }

        port def ImageInPort {
            in item imgFrame : ImageFrame;
        }

        port def ControlPort {
            out attribute mode : ImagingMode;
            out attribute frequency : FrequencyValue;
            out attribute focalDepth : DepthValue;
        }

        part def PiezoelectricElement {
            attribute elementIndex : ScalarValues::Integer;
        }

        part def TransducerProbe {
            port acousticIf : AcousticPort;
            port txIn : SignalInPort;
            port rxOut : SignalOutPort;
            part elements : PiezoelectricElement[1..*];
        }

        part def ControlConsole {
            attribute selectedMode : ImagingMode;
            attribute scanFrequency : FrequencyValue;
            attribute focalDepth : DepthValue;
            port controlOut : ControlPort;
        }

        part def TransmitBeamformer {
            port controlIn : ControlPort;
            port txOut : SignalOutPort;
        }

        part def ReceiveBeamformer {
            port rxIn : SignalInPort;
            port beamOut : SignalOutPort;
        }

        part def SignalProcessingUnit {
            port signalIn : SignalInPort;
            port processedOut : SignalOutPort;
        }

        part def ScanConverter {
            port signalIn : SignalInPort;
            port imageOut : ImageOutPort;
        }

        part def ImageProcessor {
            port imageIn : ImageInPort;
            port imageOut : ImageOutPort;
        }

        part def DisplayMonitor {
            port imageIn : ImageInPort;
        }

        action def TransmitBeamform {
            in mode : ImagingMode;
            in frequency : FrequencyValue;
            in focalDepth : DepthValue;
            out txSignal : ElectricalSignal;
        }

        action def GeneratePulse {
            in txSignal : ElectricalSignal;
            out pulse : UltrasoundPulse;
        }

        action def ReceiveEcho {
            in echo : Echo;
            out rxSignal : ElectricalSignal;
        }

        action def ReceiveBeamform {
            in rxSignal : ElectricalSignal;
            out beamformedSignal : ElectricalSignal;
        }

        action def ProcessSignal {
            in beamformedSignal : ElectricalSignal;
            out processedSignal : ElectricalSignal;
        }

        action def ConvertScan {
            in processedSignal : ElectricalSignal;
            out imageFrame : ImageFrame;
        }

        action def EnhanceImage {
            in imageFrame : ImageFrame;
            out enhancedFrame : ImageFrame;
        }

        action def DisplayImage {
            in imageFrame : ImageFrame;
        }

        action def ImagingCycle {
            in mode : ImagingMode;
            in frequency : FrequencyValue;
            in focalDepth : DepthValue;
        }

        requirement def ImageQualityRequirement {
            doc /* The system shall provide high-resolution diagnostic images with sufficient penetration depth. */
            attribute minResolution : DepthValue;
            attribute minPenetrationDepth : DepthValue;
            constraint { minPenetrationDepth >= 0.10[SI::m] }
        }

        requirement def SafetyRequirement {
            doc /* The system shall limit the acoustic energy delivered to the patient. */
            attribute maxAcousticEnergy : AcousticEnergyValue;
            constraint { maxAcousticEnergy <= 0.05[SI::J] }
        }

        requirement def RealTimeRequirement {
            doc /* The system shall display live ultrasound video at a minimum frame rate. */
            attribute minFrameRate : FrameRateValue;
            constraint { minFrameRate >= 30[SI::Hz] }
        }
    }

    package Usages {
        part ultrasoundSystem {
            requirement imageQuality : ImageQualityRequirement {
                :>> minResolution = 0.001[SI::m];
                :>> minPenetrationDepth = 0.15[SI::m];
            }
            requirement safety : SafetyRequirement {
                :>> maxAcousticEnergy = 0.05[SI::J];
            }
            requirement realTime : RealTimeRequirement {
                :>> minFrameRate = 30[SI::Hz];
            }

            part controlConsole : ControlConsole {
                :>> selectedMode = ImagingMode::BMode;
                :>> scanFrequency = 5e6[SI::Hz];
                :>> focalDepth = 0.05[SI::m];
            }

            part transmitBeamformer : TransmitBeamformer;
            part transducerProbe : TransducerProbe {
                :>> elements[128];
            }
            part receiveBeamformer : ReceiveBeamformer;
            part signalProcessingUnit : SignalProcessingUnit;
            part scanConverter : ScanConverter;
            part imageProcessor : ImageProcessor;
            part displayMonitor : DisplayMonitor;

            connection controlToTx connect controlConsole.controlOut to transmitBeamformer.controlIn;
            connection txToProbe connect transmitBeamformer.txOut to transducerProbe.txIn;
            connection probeToRx connect transducerProbe.rxOut to receiveBeamformer.rxIn;
            connection rxToSignal connect receiveBeamformer.beamOut to signalProcessingUnit.signalIn;
            connection signalToScan connect signalProcessingUnit.processedOut to scanConverter.signalIn;
            connection scanToImage connect scanConverter.imageOut to imageProcessor.imageIn;
            connection imageToDisplay connect imageProcessor.imageOut to displayMonitor.imageIn;

            action imagingCycle : ImagingCycle {
                in mode : ImagingMode = controlConsole.selectedMode;
                in frequency : FrequencyValue = controlConsole.scanFrequency;
                in focalDepth : DepthValue = controlConsole.focalDepth;

                first start;
                then merge loopStart;
                then action transmit : TransmitBeamform {
                    in mode = imagingCycle::mode;
                    in frequency = imagingCycle::frequency;
                    in focalDepth = imagingCycle::focalDepth;
                    out txSignal : ElectricalSignal;
                }
                flow from transmit.txSignal to generate.txSignal;
                then action generate : GeneratePulse {
                    in txSignal : ElectricalSignal;
                    out pulse : UltrasoundPulse;
                }
                then action receive : ReceiveEcho {
                    in echo : Echo;
                    out rxSignal : ElectricalSignal;
                }
                flow from receive.rxSignal to beamform.rxSignal;
                then action beamform : ReceiveBeamform {
                    in rxSignal : ElectricalSignal;
                    out beamformedSignal : ElectricalSignal;
                }
                flow from beamform.beamformedSignal to process.beamformedSignal;
                then action process : ProcessSignal {
                    in beamformedSignal : ElectricalSignal;
                    out processedSignal : ElectricalSignal;
                }
                flow from process.processedSignal to convert.processedSignal;
                then action convert : ConvertScan {
                    in processedSignal : ElectricalSignal;
                    out imageFrame : ImageFrame;
                }
                flow from convert.imageFrame to enhance.imageFrame;
                then action enhance : EnhanceImage {
                    in imageFrame : ImageFrame;
                    out enhancedFrame : ImageFrame;
                }
                flow from enhance.enhancedFrame to display.imageFrame;
                then action display : DisplayImage {
                    in imageFrame : ImageFrame;
                }
                then loopStart;
            }
        }
    }
}
