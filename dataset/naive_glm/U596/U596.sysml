package AnalogImageProcessingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    value type Voltage :> Real {
        unit 'V';
    }
    value type Current :> Real {
        unit 'A';
    }
    value type Frequency :> Real {
        unit 'Hz';
    }
    value type Gain :> Real {
        unit 'V/V';
    }
    value type Luminance :> Real {
        unit 'cd/m^2';
    }
    value type ContrastRatio :> Real {
        unit 'ratio';
    }
    value type Impedance :> Real {
        unit 'ohm';
    }
    value type Time :> Real {
        unit 's';
    }
    value type Temperature :> Real {
        unit 'degC';
    }

    // ---- Item Types ----
    item def OpticalImage {
        attribute luminance : Luminance;
        attribute resolutionWidth : Integer;
        attribute resolutionHeight : Integer;
    }

    item def VideoSignal {
        attribute amplitude : Voltage;
        attribute bandwidth : Frequency;
    }

    item def RawVideoSignal :> VideoSignal {
        attribute noiseLevel : Voltage;
    }

    item def AmplifiedVideoSignal :> VideoSignal {
        attribute appliedGain : Gain;
    }

    item def FilteredVideoSignal :> VideoSignal {
        attribute cutoffFrequency : Frequency;
    }

    item def EnhancedVideoSignal :> VideoSignal {
        attribute contrast : ContrastRatio;
        attribute brightnessOffset : Voltage;
    }

    item def SyncPulses {
        attribute horizontalSyncFreq : Frequency;
        attribute verticalSyncFreq : Frequency;
        attribute pulseAmplitude : Voltage;
    }

    item def CompositeVideoSignal :> VideoSignal {
        attribute syncLevel : Voltage;
        attribute blankingLevel : Voltage;
        attribute whiteLevel : Voltage;
    }

    item def DrivenCompositeSignal :> CompositeVideoSignal {
        attribute outputImpedance : Impedance;
        attribute driveCurrent : Current;
    }

    // ---- Port Definitions ----
    port def OpticalPort {
        in item image : OpticalImage;
    }

    port def VideoInPort {
        in item signal : VideoSignal;
    }

    port def VideoOutPort {
        out item signal : VideoSignal;
    }

    port def RawVideoInPort {
        in item signal : RawVideoSignal;
    }

    port def RawVideoOutPort {
        out item signal : RawVideoSignal;
    }

    port def AmplifiedVideoInPort {
        in item signal : AmplifiedVideoSignal;
    }

    port def AmplifiedVideoOutPort {
        out item signal : AmplifiedVideoSignal;
    }

    port def FilteredVideoInPort {
        in item signal : FilteredVideoSignal;
    }

    port def FilteredVideoOutPort {
        out item signal : FilteredVideoSignal;
    }

    port def EnhancedVideoInPort {
        in item signal : EnhancedVideoSignal;
    }

    port def EnhancedVideoOutPort {
        out item signal : EnhancedVideoSignal;
    }

    port def SyncOutPort {
        out item pulses : SyncPulses;
    }

    port def CompositeOutPort {
        out item signal : CompositeVideoSignal;
    }

    port def DrivenOutPort {
        out item signal : DrivenCompositeSignal;
    }

    port def GainControlPort {
        in attribute gainSetting : Gain;
    }

    port def ContrastControlPort {
        in attribute contrastSetting : ContrastRatio;
    }

    port def BrightnessControlPort {
        in attribute brightnessSetting : Voltage;
    }

    // ---- Component Definitions ----

    part def PhotodetectorArray {
        attribute pixelCount : Integer;
        attribute responsivity : Real; // A per cd/m^2
        attribute operatingTemperature : Temperature;

        port opticalInput : OpticalPort;
        port rawOutput : RawVideoOutPort;

        action def ConvertImage {
            in image : OpticalImage;
            out signal : RawVideoSignal;
        }

        perform ConvertImage {
            in image = opticalInput.image;
            out signal = rawOutput.signal;
        }
    }

    part def VideoAmplifier {
        attribute nominalGain : Gain = 10.0 [V/V];
        attribute maxGain : Gain = 100.0 [V/V];
        attribute bandwidth : Frequency = 6.0e6 [Hz];

        port videoInput : RawVideoInPort;
        port videoOutput : AmplifiedVideoOutPort;
        port gainControl : GainControlPort;

        action def Amplify {
            in input : RawVideoSignal;
            in gain : Gain;
            out output : AmplifiedVideoSignal;
        }

        perform Amplify {
            in input = videoInput.signal;
            in gain = gainControl.gainSetting;
            out output = videoOutput.signal;
        }
    }

    part def LowPassFilter {
        attribute cutoffFrequency : Frequency = 4.5e6 [Hz];
        attribute order : Integer = 4;
        attribute insertionLoss : Real = 0.5;

        port videoInput : AmplifiedVideoInPort;
        port videoOutput : FilteredVideoOutPort;

        action def FilterSignal {
            in input : AmplifiedVideoSignal;
            out output : FilteredVideoSignal;
        }

        perform FilterSignal {
            in input = videoInput.signal;
            out output = videoOutput.signal;
        }
    }

    part def ContrastController {
        attribute nominalContrast : ContrastRatio = 1.0 [ratio];
        attribute maxContrast : ContrastRatio = 2.0 [ratio];

        port videoInput : FilteredVideoInPort;
        port videoOutput : EnhancedVideoOutPort;
        port contrastControl : ContrastControlPort;

        action def AdjustContrast {
            in input : FilteredVideoSignal;
            in contrast : ContrastRatio;
            out output : EnhancedVideoSignal;
        }

        perform AdjustContrast {
            in input = videoInput.signal;
            in contrast = contrastControl.contrastSetting;
            out output = videoOutput.signal;
        }
    }

    part def BrightnessController {
        attribute nominalBrightness : Voltage = 0.0 [V];
        attribute maxBrightness : Voltage = 0.5 [V];

        port videoInput : EnhancedVideoInPort;
        port videoOutput : EnhancedVideoOutPort;
        port brightnessControl : BrightnessControlPort;

        action def AdjustBrightness {
            in input : EnhancedVideoSignal;
            in brightness : Voltage;
            out output : EnhancedVideoSignal;
        }

        perform AdjustBrightness {
            in input = videoInput.signal;
            in brightness = brightnessControl.brightnessSetting;
            out output = videoOutput.signal;
        }
    }

    part def SyncGenerator {
        attribute horizontalSyncFreq : Frequency = 15.734e3 [Hz];
        attribute verticalSyncFreq : Frequency = 59.94 [Hz];
        attribute pulseAmplitude : Voltage = 0.3 [V];
        attribute stability : Real = 1.0e-6; // ppm

        port syncOutput : SyncOutPort;

        action def GenerateSync {
            out pulses : SyncPulses;
        }

        perform GenerateSync {
            out pulses = syncOutput.pulses;
        }
    }

    part def VideoMixer {
        attribute mixingRatio : Real = 0.7; // image to sync ratio

        port videoInput : EnhancedVideoInPort;
        port syncInput : SyncOutPort;
        port compositeOutput : CompositeOutPort;

        action def MixSignals {
            in video : EnhancedVideoSignal;
            in sync : SyncPulses;
            out composite : CompositeVideoSignal;
        }

        perform MixSignals {
            in video = videoInput.signal;
            in sync = syncInput.pulses;
            out composite = compositeOutput.signal;
        }
    }

    part def OutputDriver {
        attribute outputImpedance : Impedance = 75.0 [ohm];
        attribute maxDriveCurrent : Current = 0.1 [A];
        attribute cableLength : Real = 10.0; // meters

        port compositeInput : VideoInPort;
        port drivenOutput : DrivenOutPort;

        action def DriveOutput {
            in input : CompositeVideoSignal;
            out output : DrivenCompositeSignal;
        }

        perform DriveOutput {
            in input = compositeInput.signal;
            out output = drivenOutput.signal;
        }
    }

    // ---- User Control Panel ----
    part def UserControlPanel {
        attribute gainDial : Gain = 10.0 [V/V];
        attribute contrastDial : ContrastRatio = 1.0 [ratio];
        attribute brightnessDial : Voltage = 0.0 [V];

        port gainPort : GainControlPort;
        port contrastPort : ContrastControlPort;
        port brightnessPort : BrightnessControlPort;

        action def UpdateControls {
            out gain : Gain;
            out contrast : ContrastRatio;
            out brightness : Voltage;
        }

        perform UpdateControls {
            out gain = gainPort.gainSetting;
            out contrast = contrastPort.contrastSetting;
            out brightness = brightnessPort.brightnessSetting;
        }
    }

    // ---- System State Machine ----
    state def SystemStates {
        entry;
        idle;
        processing {
            entry;
            do ProcessVideo;
            exit;
        }
        fault {
            entry;
            do LogFault;
            exit;
        }

        transition idle_to_processing
            first idle then processing
            when powerOn;
        transition processing_to_idle
            first processing then idle
            when powerOff;
        transition processing_to_fault
            first processing then fault
            when errorDetected;
        transition fault_to_idle
            first fault then idle
            when faultCleared;
    }

    // ---- Top-Level System ----
    part def AnalogImageProcessingSystem {

        attribute systemBandwidth : Frequency = 5.0e6 [Hz];
        attribute powerConsumption : Real = 2.5; // watts
        attribute operatingTemperatureRangeMin : Temperature = -10.0 [degC];
        attribute operatingTemperatureRangeMax : Temperature = 55.0 [degC];

        // External interface ports
        port opticalInput : OpticalPort;
        port videoOutput : DrivenOutPort;

        // Internal parts
        part photodetectorArray : PhotodetectorArray {
            attribute pixelCount = 480000;
            attribute responsivity = 0.5;
        }
        part videoAmplifier : VideoAmplifier;
        part lowPassFilter : LowPassFilter;
        part contrastController : ContrastController;
        part brightnessController : BrightnessController;
        part syncGenerator : SyncGenerator;
        part videoMixer : VideoMixer;
        part outputDriver : OutputDriver;
        part userControlPanel : UserControlPanel;

        // Internal connections - signal pipeline
        connection opticalToDetector connect opticalInput to photodetectorArray.opticalInput;
        connection detectorToAmplifier connect photodetectorArray.rawOutput to videoAmplifier.videoInput;
        connection amplifierToFilter connect videoAmplifier.videoOutput to lowPassFilter.videoInput;
        connection filterToContrast connect lowPassFilter.videoOutput to contrastController.videoInput;
        connection contrastToBrightness connect contrastController.videoOutput to brightnessController.videoInput;
        connection brightnessToMixer connect brightnessController.videoOutput to videoMixer.videoInput;
        connection syncToMixer connect syncGenerator.syncOutput to videoMixer.syncInput;
        connection mixerToDriver connect videoMixer.compositeOutput to outputDriver.compositeInput;
        connection driverToOutput connect outputDriver.drivenOutput to videoOutput;

        // Control connections
        connection gainControl connect userControlPanel.gainPort to videoAmplifier.gainControl;
        connection contrastControl connect userControlPanel.contrastPort to contrastController.contrastControl;
        connection brightnessControl connect userControlPanel.brightnessPort to brightnessController.brightnessControl;

        // State machine
        exhibit SystemStates;

        // System-level processing action
        action def ProcessVideo {
            in image : OpticalImage;
            out composite : DrivenCompositeSignal;
        }

        action def LogFault {
            attribute faultCode : Integer;
            attribute faultTime : Time;
        }

        // System-level processing behavior
        perform ProcessVideo {
            in image = opticalInput.image;
            out composite = videoOutput.signal;
        }
    }

    // ---- Requirements ----
    requirement def OpticalConversionRequirement {
        subject photodetector : PhotodetectorArray;
        attribute minResponsivity : Real = 0.3;
        attribute minPixelCount : Integer = 250000;
        require {
            photodetector.responsivity >= minResponsivity and
            photodetector.pixelCount >= minPixelCount
        }
    }

    requirement def AmplificationRequirement {
        subject amplifier : VideoAmplifier;
        attribute requiredMaxGain : Gain = 100.0 [V/V];
        attribute requiredBandwidth : Frequency = 6.0e6 [Hz];
        require {
            amplifier.maxGain >= requiredMaxGain and
            amplifier.bandwidth >= requiredBandwidth
        }
    }

    requirement def FilteringRequirement {
        subject filter : LowPassFilter;
        attribute requiredCutoff : Frequency = 4.5e6 [Hz];
        attribute requiredOrder : Integer = 2;
        require {
            filter.cutoffFrequency <= requiredCutoff and
            filter.order >= requiredOrder
        }
    }

    requirement def EnhancementRequirement {
        subject contrastCtrl : ContrastController;
        subject brightnessCtrl : BrightnessController;
        attribute requiredMaxContrast : ContrastRatio = 2.0 [ratio];
        attribute requiredMaxBrightness : Voltage = 0.5 [V];
        require {
            contrastCtrl.maxContrast >= requiredMaxContrast and
            brightnessCtrl.maxBrightness >= requiredMaxBrightness
        }
    }

    requirement def SyncGenerationRequirement {
        subject syncGen : SyncGenerator;
        attribute requiredHSync : Frequency = 15.734e3 [Hz];
        attribute requiredVSync : Frequency = 59.94 [Hz];
        require {
            syncGen.horizontalSyncFreq == requiredHSync and
            syncGen.verticalSyncFreq == requiredVSync
        }
    }

    requirement def MixingRequirement {
        subject mixer : VideoMixer;
        require {
            mixer.mixingRatio > 0.0 and mixer.mixingRatio < 1.0
        }
    }

    requirement def OutputDriverRequirement {
        subject driver : OutputDriver;
        attribute requiredImpedance : Impedance = 75.0 [ohm];
        attribute requiredMaxCurrent : Current = 0.05 [A];
        require {
            driver.outputImpedance == requiredImpedance and
            driver.maxDriveCurrent >= requiredMaxCurrent
        }
    }

    requirement def SystemOperationRequirement {
        subject system : AnalogImageProcessingSystem;
        attribute requiredBandwidth : Frequency = 4.5e6 [Hz];
        attribute maxPower : Real = 5.0;
        require {
            system.systemBandwidth >= requiredBandwidth and
            system.powerConsumption <= maxPower
        }
    }

    requirement def SystemStateRequirement {
        subject system : AnalogImageProcessingSystem;
        require {
            system must support states idle, processing, and fault
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction opticalConversionSatisfies by photodetectorArray satisfy OpticalConversionRequirement;
    satisfaction amplificationSatisfies by videoAmplifier satisfy AmplificationRequirement;
    satisfaction filteringSatisfies by lowPassFilter satisfy FilteringRequirement;
    satisfaction enhancementSatisfies by contrastController, brightnessController satisfy EnhancementRequirement;
    satisfaction syncSatisfies by syncGenerator satisfy SyncGenerationRequirement;
    satisfaction mixingSatisfies by videoMixer satisfy MixingRequirement;
    satisfaction outputSatisfies by outputDriver satisfy OutputDriverRequirement;

}
