package VisualProsthesisSystem {

    import ScalarValues::*;

    // ===== Unit Definitions =====
    unit hz;
    unit ua;
    unit v;
    unit pct;
    unit degc;
    unit ms;
    unit ghz;

    // ===== Value Types =====
    value type FrameRate :> Real {
        unit hz;
    }

    value type ElectricCurrent :> Real {
        unit ua;
    }

    value type Voltage :> Real {
        unit v;
    }

    value type BatteryLevel :> Real {
        unit pct;
    }

    value type TemperatureValue :> Real {
        unit degc;
    }

    value type PulseDuration :> Real {
        unit ms;
    }

    value type FrequencyValue :> Real {
        unit hz;
    }

    value type CarrierFrequency :> Real {
        unit ghz;
    }

    // ===== Item Definitions =====
    item def ImageFrame {
        attribute width : Integer = 640;
        attribute height : Integer = 480;
        attribute frameRate : FrameRate = 30;
        attribute timestamp : String;
        attribute pixelData : Integer[*];
    }

    item def ProcessedImage {
        attribute width : Integer = 60;
        attribute height : Integer = 60;
        attribute edgeEnhanced : Boolean = true;
        attribute contrastLevel : Real;
        attribute timestamp : String;
        attribute pixelIntensity : Real[60];
    }

    item def StimulationPattern {
        attribute electrodeCount : Integer = 60;
        attribute currents : ElectricCurrent[60];
        attribute pulseDurations : PulseDuration[60];
        attribute stimulationFrequency : FrequencyValue;
        attribute timestamp : String;
    }

    item def TissueResponse {
        attribute impedance : Real;
        attribute temperature : TemperatureValue;
        attribute activityLevel : Real;
        attribute safe : Boolean;
        attribute timestamp : String;
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute parameter : String;
        attribute value : Real;
        attribute timestamp : String;
    }

    item def SystemData {
        attribute batteryLevel : BatteryLevel;
        attribute electrodeStatus : Boolean[60];
        attribute errorFlags : String[*];
        attribute tissueSafetyStatus : Boolean;
        attribute timestamp : String;
    }

    // ===== Port Definitions =====
    port def VideoOutPort {
        out image : ImageFrame;
    }

    port def VideoInPort {
        in image : ImageFrame;
    }

    port def ProcessedImageOutPort {
        out image : ProcessedImage;
    }

    port def ProcessedImageInPort {
        in image : ProcessedImage;
    }

    port def StimulationOutPort {
        out pattern : StimulationPattern;
    }

    port def StimulationInPort {
        in pattern : StimulationPattern;
    }

    port def TissueResponseOutPort {
        out response : TissueResponse;
    }

    port def TissueResponseInPort {
        in response : TissueResponse;
    }

    port def PowerOutPort {
        out supplyVoltage : Voltage;
        in loadCurrent : ElectricCurrent;
    }

    port def PowerInPort {
        in supplyVoltage : Voltage;
        out loadCurrent : ElectricCurrent;
    }

    port def CommandInPort {
        in command : ControlCommand;
    }

    port def DataOutPort {
        out data : SystemData;
    }

    port def CommPort {
        in command : ControlCommand;
        out data : SystemData;
    }

    // ===== Requirements =====
    requirement def VisionRestorationRequirement {
        doc "The system shall restore partial vision to individuals with retinal degenerative diseases.";
    }

    requirement def CameraCaptureRequirement :> VisionRestorationRequirement {
        doc "The external camera shall capture the user's surroundings at 30 frames per second.";
        attribute requiredFrameRate : FrameRate = 30;
        subject camera : ExternalCamera;
        require { camera.frameRate == requiredFrameRate; }
    }

    requirement def ImageProcessingRequirement :> VisionRestorationRequirement {
        doc "The image processing unit shall perform edge detection and contrast enhancement on raw video.";
        subject processor : ImageProcessingUnit;
        require { processor.edgeDetectionEnabled == true; }
        require { processor.contrastEnhancementEnabled == true; }
    }

    requirement def StimulationMappingRequirement :> VisionRestorationRequirement {
        doc "The stimulus generator shall map processed image patterns to a 60-electrode grid with calculated current levels.";
        subject generator : StimulusGenerator;
        require { generator.electrodeGridSize == 60; }
        require { generator.maxCurrent <= 600; }
    }

    requirement def ElectrodeArrayRequirement :> VisionRestorationRequirement {
        doc "The retinal electrode array shall deliver controlled electrical pulses via 60 microelectrodes to remaining retinal nerve cells.";
        subject array : RetinalElectrodeArray;
        require { array.electrodeCount == 60; }
        require { array.maxCurrent <= 1000; }
    }

    requirement def SafetyMonitoringRequirement :> VisionRestorationRequirement {
        doc "The implant shall monitor retinal tissue response to stimulation and enter safety shutdown when unsafe conditions are detected.";
        subject array : RetinalElectrodeArray;
        require { array.monitoringEnabled == true; }
    }

    requirement def BatteryPowerRequirement :> VisionRestorationRequirement {
        doc "The battery unit shall manage power distribution to all components and support a low-power conservation mode.";
        subject battery : BatteryUnit;
        require { battery.lowPowerModeSupported == true; }
        require { battery.lowPowerThreshold <= 20; }
    }

    requirement def WirelessCommunicationRequirement :> VisionRestorationRequirement {
        doc "The wireless transceiver shall receive control commands and transmit system data for calibration and monitoring.";
        subject transceiver : WirelessTransceiver;
        require { transceiver.commandReceptionEnabled == true; }
        require { transceiver.dataTransmissionEnabled == true; }
    }

    // ===== Component Part Definitions =====

    part def ExternalCamera {
        attribute frameRate : FrameRate = 30;
        attribute resolution : String = "640x480";
        attribute fieldOfView : Real = 60;
        attribute powerConsumption : ElectricCurrent = 50;

        port videoOut : VideoOutPort;
        port powerIn : PowerInPort;

        action def CaptureFrame {
            in timestamp : String;
            out frame : ImageFrame;

            action senseLight {
                out rawPixels : Integer[*];
            }

            action encodeFrame {
                in pixels : Integer[*];
                in ts : String;
                out img : ImageFrame;
            }

            flow senseLight.rawPixels -> encodeFrame.pixels;
            flow timestamp -> encodeFrame.ts;
            flow encodeFrame.img -> frame;
        }

        perform CaptureFrame;
    }

    part def ImageProcessingUnit {
        attribute edgeDetectionEnabled : Boolean = true;
        attribute contrastEnhancementEnabled : Boolean = true;
        attribute targetContrast : Real = 0.8;
        attribute processingLatency : PulseDuration = 5;
        attribute powerConsumption : ElectricCurrent = 200;

        port videoIn : VideoInPort;
        port imageOut : ProcessedImageOutPort;
        port powerIn : PowerInPort;
        port cmdPort : CommandInPort;

        action def ProcessImage {
            in raw : ImageFrame;
            out processed : ProcessedImage;

            action downsample {
                in input : ImageFrame;
                out reduced : Integer[60];
            }

            action detectEdges {
                in pixels : Integer[60];
                out edges : Real[60];
            }

            action enhanceContrast {
                in edges : Real[60];
                in target : Real;
                out intensities : Real[60];
            }

            action assembleOutput {
                in intensities : Real[60];
                in ts : String;
                out result : ProcessedImage;
            }

            flow raw -> downsample.input;
            flow downsample.reduced -> detectEdges.pixels;
            flow detectEdges.edges -> enhanceContrast.edges;
            flow targetContrast -> enhanceContrast.target;
            flow enhanceContrast.intensities -> assembleOutput.intensities;
            flow raw.timestamp -> assembleOutput.ts;
            flow assembleOutput.result -> processed;
        }

        perform ProcessImage;
    }

    part def StimulusGenerator {
        attribute electrodeGridSize : Integer = 60;
        attribute maxCurrent : ElectricCurrent = 600;
        attribute baseFrequency : FrequencyValue = 50;
        attribute pulseDuration : PulseDuration = 1;
        attribute powerConsumption : ElectricCurrent = 150;

        port imageIn : ProcessedImageInPort;
        port stimulationOut : StimulationOutPort;
        port tissueResponseIn : TissueResponseInPort;
        port powerIn : PowerInPort;
        port cmdPort : CommandInPort;

        action def GeneratePattern {
            in image : ProcessedImage;
            in safetyFeedback : TissueResponse;
            out pattern : StimulationPattern;

            action mapImageToGrid {
                in img : ProcessedImage;
                out gridValues : Real[60];
            }

            action calculateCurrents {
                in grid : Real[60];
                in safety : TissueResponse;
                in maxLim : ElectricCurrent;
                out currents : ElectricCurrent[60];
            }

            action assemblePattern {
                in currents : ElectricCurrent[60];
                in freq : FrequencyValue;
                in dur : PulseDuration;
                in ts : String;
                out pat : StimulationPattern;
            }

            flow image -> mapImageToGrid.img;
            flow mapImageToGrid.gridValues -> calculateCurrents.grid;
            flow safetyFeedback -> calculateCurrents.safety;
            flow maxCurrent -> calculateCurrents.maxLim;
            flow calculateCurrents.currents -> assemblePattern.currents;
            flow baseFrequency -> assemblePattern.freq;
            flow pulseDuration -> assemblePattern.dur;
            flow image.timestamp -> assemblePattern.ts;
            flow assemblePattern.pat -> pattern;
        }

        perform GeneratePattern;
    }

    part def RetinalElectrodeArray {
        attribute electrodeCount : Integer = 60;
        attribute maxCurrent : ElectricCurrent = 1000;
        attribute monitoringEnabled : Boolean = true;
        attribute pulseDuration : PulseDuration = 1;
        attribute impedanceThreshold : Real = 10000;
        attribute temperatureThreshold : TemperatureValue = 40;
        attribute powerConsumption : ElectricCurrent = 100;

        port stimulationIn : StimulationInPort;
        port tissueResponseOut : TissueResponseOutPort;
        port powerIn : PowerInPort;

        state def ImplantOperation {
            entry;
            then Idle;

            state Idle {
                doc "Electrode array is powered but not actively stimulating.";
            }

            state Stimulating {
                doc "Microelectrodes are delivering controlled electrical pulses to retinal nerve cells.";
            }

            state Monitoring {
                doc "Tissue response is being measured following stimulation.";
            }

            state SafetyShutdown {
                doc "Stimulation halted due to unsafe tissue response.";
            }

            transition idle_to_stimulating
                source Idle
                target Stimulating
                when stimulationIn.pattern != null;

            transition stimulating_to_monitoring
                source Stimulating
                target Monitoring
                after 1;

            transition monitoring_to_stimulating
                source Monitoring
                target Stimulating
                when tissueResponseOut.response.safe == true;

            transition monitoring_to_safety
                source Monitoring
                target SafetyShutdown
                when tissueResponseOut.response.safe == false;

            transition safety_to_idle
                source SafetyShutdown
                target Idle
                when tissueResponseOut.response.safe == true
                and cmdReset == true;
        }

        attribute cmdReset : Boolean = false;

        exhibit ImplantOperation;

        action def DeliverStimulation {
            in pattern : StimulationPattern;
            out response : TissueResponse;

            action deliverPulses {
                in pat : StimulationPattern;
            }

            action measureImpedance {
                out impedance : Real;
            }

            action measureTemperature {
                out temp : TemperatureValue;
            }

            action evaluateSafety {
                in imp : Real;
                in t : TemperatureValue;
                out safe : Boolean;
                out resp : TissueResponse;
            }

            flow pattern -> deliverPulses.pat;
            flow deliverPulses -> measureImpedance;
            flow measureImpedance.impedance -> evaluateSafety.imp;
            flow measureTemperature.temp -> evaluateSafety.t;
            flow evaluateSafety.resp -> response;
        }

        perform DeliverStimulation;
    }

    part def BatteryUnit {
        attribute nominalVoltage : Voltage = 3.7;
        attribute currentLevel : BatteryLevel = 100;
        attribute lowPowerModeSupported : Boolean = true;
        attribute lowPowerThreshold : BatteryLevel = 20;
        attribute chargeCapacity : Real = 1000;
        attribute powerConsumption : ElectricCurrent = 10;

        port powerOutCamera : PowerOutPort;
        port powerOutProcessor : PowerOutPort;
        port powerOutGenerator : PowerOutPort;
        port powerOutArray : PowerOutPort;
        port powerOutTransceiver : PowerOutPort;
        port cmdPort : CommandInPort;
        port dataOut : DataOutPort;

        state def PowerManagement {
            entry;
            then NormalMode;

            state NormalMode {
                doc "Full power distribution to all components.";
                entry;
                attribute outputVoltage : Voltage = 3.7;
            }

            state LowPowerMode {
                doc "Reduced power output to conserve energy when battery level is low.";
                entry;
                attribute outputVoltage : Voltage = 2.5;
            }

            state Charging {
                doc "Battery is being recharged.";
                entry;
                attribute outputVoltage : Voltage = 3.7;
            }

            state Fault {
                doc "Battery fault detected.";
            }

            transition normal_to_low
                source NormalMode
                target LowPowerMode
                when currentLevel <= lowPowerThreshold;

            transition low_to_normal
                source LowPowerMode
                target NormalMode
                when currentLevel > lowPowerThreshold + 10;

            transition normal_to_charging
                source NormalMode
                target Charging
                when cmdPort.command.commandType == "startCharging";

            transition low_to_charging
                source LowPowerMode
                target Charging
                when cmdPort.command.commandType == "startCharging";

            transition charging_to_normal
                source Charging
                target NormalMode
                when cmdPort.command.commandType == "stopCharging";

            transition to_fault
                source NormalMode
                target Fault
                when currentLevel <= 0;

            transition fault_to_charging
                source Fault
                target Charging
                when cmdPort.command.commandType == "startCharging";
        }

        exhibit PowerManagement;

        action def DistributePower {
            in level : BatteryLevel;
            out voltageCamera : Voltage;
            out voltageProcessor : Voltage;
            out voltageGenerator : Voltage;
            out voltageArray : Voltage;
            out voltageTransceiver : Voltage;

            action determineMode {
                in lvl : BatteryLevel;
                in threshold : BatteryLevel;
                out mode : String;
            }

            action setVoltages {
                in m : String;
                out vCam : Voltage;
                out vProc : Voltage;
                out vGen : Voltage;
                out vArr : Voltage;
                out vTrans : Voltage;
            }

            flow level -> determineMode.lvl;
            flow lowPowerThreshold -> determineMode.threshold;
            flow determineMode.mode -> setVoltages.m;
            flow setVoltages.vCam -> voltageCamera;
            flow setVoltages.vProc -> voltageProcessor;
            flow setVoltages.vGen -> voltageGenerator;
            flow setVoltages.vArr -> voltageArray;
            flow setVoltages.vTrans -> voltageTransceiver;
        }

        perform DistributePower;
    }

    part def WirelessTransceiver {
        attribute commandReceptionEnabled : Boolean = true;
        attribute dataTransmissionEnabled : Boolean = true;
        attribute carrierFrequency : CarrierFrequency = 2.4;
        attribute dataRate : Real = 250;
        attribute powerConsumption : ElectricCurrent = 30;

        port commPort : CommPort;
        port powerIn : PowerInPort;

        action def ReceiveCommand {
            in rawSignal : Real;
            out command : ControlCommand;

            action demodulate {
                in signal : Real;
                out bits : String;
            }

            action decode {
                in bits : String;
                out cmd : ControlCommand;
            }

            flow rawSignal -> demodulate.signal;
            flow demodulate.bits -> decode.bits;
            flow decode.cmd -> command;
        }

        action def TransmitData {
            in data : SystemData;

            action encode {
                in d : SystemData;
                out bits : String;
            }

            action modulate {
                in bits : String;
                out signal : Real;
            }

            flow data -> encode.d;
            flow encode.bits -> modulate.bits;
        }

        perform ReceiveCommand;
        perform TransmitData;
    }

    // ===== System Assembly =====
    part def BionicEyeSystem {
        doc "Visual prosthesis system (bionic eye) that captures visual information, processes it, and translates it into electrical stimulation patterns delivered to the retina.";

        part glassesCamera : ExternalCamera;
        part imageProcessor : ImageProcessingUnit;
        part stimulusGenerator : StimulusGenerator;
        part electrodeArray : RetinalElectrodeArray;
        part battery : BatteryUnit;
        part transceiver : WirelessTransceiver;

        // Video data path
        connection videoLink connect glassesCamera.videoOut to imageProcessor.videoIn;

        // Processed image data path
        connection imageLink connect imageProcessor.imageOut to stimulusGenerator.imageIn;

        // Stimulation pattern delivery
        connection stimLink connect stimulusGenerator.stimulationOut to electrodeArray.stimulationIn;

        // Tissue response feedback to stimulus generator for safety-aware current adjustment
        connection tissueFeedback connect electrodeArray.tissueResponseOut to stimulusGenerator.tissueResponseIn;

        // Power distribution
        connection powerCamera connect battery.powerOutCamera to glassesCamera.powerIn;
        connection powerProcessor connect battery.powerOutProcessor to imageProcessor.powerIn;
        connection powerGenerator connect battery.powerOutGenerator to stimulusGenerator.powerIn;
        connection powerArray connect battery.powerOutArray to electrodeArray.powerIn;
        connection powerTransceiver connect battery.powerOutTransceiver to transceiver.powerIn;

        // Command distribution from transceiver
        connection cmdProcessor connect transceiver.commPort to imageProcessor.cmdPort;
        connection cmdGenerator connect transceiver.commPort to stimulusGenerator.cmdPort;
        connection cmdBattery connect transceiver.commPort to battery.cmdPort;
        connection cmdArray connect transceiver.commPort to electrodeArray.cmdPort;

        // Requirement satisfaction
        satisfy CameraCaptureRequirement by glassesCamera;
        satisfy ImageProcessingRequirement by imageProcessor;
        satisfy StimulationMappingRequirement by stimulusGenerator;
        satisfy ElectrodeArrayRequirement by electrodeArray;
        satisfy SafetyMonitoringRequirement by electrodeArray;
        satisfy BatteryPowerRequirement by battery;
        satisfy WirelessCommunicationRequirement by transceiver;
    }

}
