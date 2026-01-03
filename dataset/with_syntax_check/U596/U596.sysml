package 'Analog Image Processing System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def PixelVoltage :> ISQ::ElectricPotentialValue;
    attribute def SignalGain :> Real;
    attribute def FilterBandwidth :> ISQ::FrequencyValue;
    attribute def NoiseFloor :> ISQ::ElectricPotentialValue;
    attribute def ContrastLevel :> Real;
    attribute def BrightnessOffset :> ISQ::ElectricPotentialValue;
    attribute def ScanRate :> ISQ::FrequencyValue;
    
    item def AnalogVideoSignal {
        attribute luminance : PixelVoltage;
        attribute chrominance : PixelVoltage;
        attribute syncPulse : ISQ::ElectricPotentialValue;
        attribute bandwidth : ISQ::FrequencyValue;
        attribute noiseLevel : NoiseFloor;
    }
    
    item def OpticalImage {
        attribute intensity : ISQ::LuminousIntensityValue;
        attribute spatialResolution : ISQ::LengthValue;
    }
    
    port def OpticalInputPort {
        in item scene : OpticalImage;
    }
    
    port def AnalogSignalPort {
        inout item signal : AnalogVideoSignal;
    }
    
    port def ControlInputPort {
        in attribute gain : SignalGain;
        in attribute brightness : BrightnessOffset;
        in attribute contrast : ContrastLevel;
    }
    
    part def PhotodetectorArray {
        port opticalIn : OpticalInputPort;
        port videoOut : AnalogSignalPort;
        
        attribute pixelCount : Integer;
        attribute responsivity : Real;
        attribute darkCurrent : ISQ::ElectricCurrentValue;
        
        perform action convertOpticalToElectrical {
            in opticalScene : OpticalImage;
            out rawVideoSignal : AnalogVideoSignal;
        }
    }
    
    part def VideoAmplifier {
        port signalIn : AnalogSignalPort;
        port signalOut : AnalogSignalPort;
        port controlIn : ControlInputPort;
        
        attribute gainRange : SignalGain;
        attribute inputImpedance : ISQ::ResistanceValue;
        attribute outputImpedance : ISQ::ResistanceValue;
        attribute bandwidth : FilterBandwidth;
        
        perform action amplifyVideo {
            in inputSignal : AnalogVideoSignal;
            in gainSetting : SignalGain;
            out amplifiedSignal : AnalogVideoSignal;
        }
    }
    
    part def LowPassFilter {
        port filterIn : AnalogSignalPort;
        port filterOut : AnalogSignalPort;
        
        attribute cutoffFrequency : FilterBandwidth;
        attribute rolloffRate : Real;
        attribute passbandRipple : ISQ::ElectricPotentialValue;
        
        perform action filterHighFrequencyNoise {
            in noisySignal : AnalogVideoSignal;
            out filteredSignal : AnalogVideoSignal;
            
            first start;
            then action removeNoise {
                in signal : AnalogVideoSignal;
                out cleanSignal : AnalogVideoSignal;
            }
            then done;
        }
    }
    
    part def ContrastController {
        port videoIn : AnalogSignalPort;
        port videoOut : AnalogSignalPort;
        port controlIn : ControlInputPort;
        
        attribute contrastRange : ContrastLevel;
        attribute dynamicRange : ISQ::ElectricPotentialValue;
        
        perform action adjustContrast {
            in inputVideo : AnalogVideoSignal;
            in contrastSetting : ContrastLevel;
            out contrastAdjustedVideo : AnalogVideoSignal;
            
            first start;
            then action expandDynamicRange {
                in signal : AnalogVideoSignal;
                in contrast : ContrastLevel;
                out expandedSignal : AnalogVideoSignal;
            }
            then done;
        }
    }
    
    part def BrightnessController {
        port videoIn : AnalogSignalPort;
        port videoOut : AnalogSignalPort;
        port controlIn : ControlInputPort;
        
        attribute offsetRange : BrightnessOffset;
        attribute dcBias : ISQ::ElectricPotentialValue;
        
        perform action adjustBrightness {
            in inputVideo : AnalogVideoSignal;
            in brightnessSetting : BrightnessOffset;
            out brightnessAdjustedVideo : AnalogVideoSignal;
            
            first start;
            then action addDCOffset {
                in signal : AnalogVideoSignal;
                in offset : BrightnessOffset;
                out offsetSignal : AnalogVideoSignal;
            }
            then done;
        }
    }
    
    part def SyncGenerator {
        port syncOut : AnalogSignalPort;
        
        attribute horizontalFrequency : ScanRate;
        attribute verticalFrequency : ScanRate;
        attribute syncAmplitude : ISQ::ElectricPotentialValue;
        
        perform action generateSyncPulses {
            out syncSignal : AnalogVideoSignal;
        }
    }
    
    part def VideoMixer {
        port videoIn : AnalogSignalPort;
        port syncIn : AnalogSignalPort;
        port compositeOut : AnalogSignalPort;
        
        attribute mixingRatio : Real;
        
        perform action combineVideoAndSync {
            in videoSignal : AnalogVideoSignal;
            in syncSignal : AnalogVideoSignal;
            out compositeSignal : AnalogVideoSignal;
        }
    }
    
    part def OutputDriver {
        port signalIn : AnalogSignalPort;
        port signalOut : AnalogSignalPort;
        
        attribute outputImpedance : ISQ::ResistanceValue;
        attribute driveStrength : ISQ::ElectricCurrentValue;
        
        perform action driveOutput {
            in processedSignal : AnalogVideoSignal;
            out outputSignal : AnalogVideoSignal;
        }
    }
    
    attribute def StartProcessingSignal;
    attribute def ProcessingErrorSignal;
    attribute def ResetSignal;
    
    state def ProcessingMode {
        entry; then active;
        
        state idle;
        state active {
            state capturing;
            state amplifying;
            state filtering;
            state enhancing;
            state outputting;
        }
        state fault;
        
        transition idleToActive
            first idle
            accept startCmd : StartProcessingSignal
            then active;
            
        transition captureToAmplify
            first active.capturing
            then active.amplifying;
            
        transition amplifyToFilter
            first active.amplifying
            then active.filtering;
            
        transition filterToEnhance
            first active.filtering
            then active.enhancing;
            
        transition enhanceToOutput
            first active.enhancing
            then active.outputting;
            
        transition outputToCapture
            first active.outputting
            then active.capturing;
            
        transition errorToFault
            first active
            accept errorCmd : ProcessingErrorSignal
            then fault;
            
        transition faultToIdle
            first fault
            accept resetCmd : ResetSignal
            then idle;
    }
    
    action def ProcessAnalogImage {
        in opticalInput : OpticalImage;
        in gainControl : SignalGain;
        in brightnessControl : BrightnessOffset;
        in contrastControl : ContrastLevel;
        out processedVideo : AnalogVideoSignal;
        
        private attribute rawSignal : AnalogVideoSignal;
        private attribute amplifiedSignal : AnalogVideoSignal;
        private attribute filteredSignal : AnalogVideoSignal;
        private attribute contrastEnhancedSignal : AnalogVideoSignal;
        private attribute brightnessAdjustedSignal : AnalogVideoSignal;
        private attribute syncSignal : AnalogVideoSignal;
        private attribute compositeSignal : AnalogVideoSignal;
        
        first start;
        then action photoConversion {
            in scene = opticalInput;
            out videoSignal = rawSignal;
        }
        then action amplification {
            in inputSignal = rawSignal;
            in gain = gainControl;
            out amplifiedOutput = amplifiedSignal;
        }
        then action filtering {
            in noisyInput = amplifiedSignal;
            out cleanOutput = filteredSignal;
        }
        then action contrastAdjustment {
            in videoInput = filteredSignal;
            in contrastLevel = contrastControl;
            out contrastOutput = contrastEnhancedSignal;
        }
        then action brightnessAdjustment {
            in videoInput = contrastEnhancedSignal;
            in brightnessLevel = brightnessControl;
            out brightnessOutput = brightnessAdjustedSignal;
        }
        then merge syncMerge;
        action syncGeneration {
            out syncPulses = syncSignal;
        }
        then syncMerge;
        then action videoMixing {
            in video = brightnessAdjustedSignal;
            in sync = syncSignal;
            out composite = compositeSignal;
        }
        then action outputDrive {
            in input = compositeSignal;
            out output = processedVideo;
        }
        then done;
    }
    
    part def AnalogImageProcessingSystem {
        doc /* 
            An analog image processing system that captures optical images and processes them
            through a continuous-time analog signal chain to produce enhanced composite video output.
            The system performs photoelectric conversion, amplification, noise filtering, contrast
            enhancement, brightness adjustment, sync generation, and signal mixing entirely in the
            analog domain to minimize latency and preserve signal fidelity.
        */
        
        port opticalInput : OpticalInputPort;
        port videoOutput : AnalogSignalPort;
        port userControls : ControlInputPort;
        
        part photodetector : PhotodetectorArray {
            pixelCount = 640 * 480;
            responsivity = 0.65;
            darkCurrent = 1.0e-9[ISQ::ampere];
        }
        
        part amplifier : VideoAmplifier {
            gainRange = 20.0;
            inputImpedance = 1.0e6[ISQ::ohm];
            outputImpedance = 75.0[ISQ::ohm];
            bandwidth = 6.0e6[ISQ::hertz];
        }
        
        part lowPassFilter : LowPassFilter {
            cutoffFrequency = 5.5e6[ISQ::hertz];
            rolloffRate = 48.0;
            passbandRipple = 0.1[ISQ::volt];
        }
        
        part contrastControl : ContrastController {
            contrastRange = 2.0;
            dynamicRange = 1.0[ISQ::volt];
        }
        
        part brightnessControl : BrightnessController {
            offsetRange = 0.5[ISQ::volt];
            dcBias = 0.3[ISQ::volt];
        }
        
        part syncGen : SyncGenerator {
            horizontalFrequency = 15.734e3[ISQ::hertz];
            verticalFrequency = 59.94[ISQ::hertz];
            syncAmplitude = 0.3[ISQ::volt];
        }
        
        part mixer : VideoMixer {
            mixingRatio = 0.7;
        }
        
        part outputDriver : OutputDriver {
            outputImpedance = 75.0[ISQ::ohm];
            driveStrength = 0.1[ISQ::ampere];
        }
        
        attribute operatingMode : ProcessingMode;
        
        connect opticalInput to photodetector.opticalIn;
        connect photodetector.videoOut to amplifier.signalIn;
        connect amplifier.signalOut to lowPassFilter.filterIn;
        connect lowPassFilter.filterOut to contrastControl.videoIn;
        connect contrastControl.videoOut to brightnessControl.videoIn;
        connect brightnessControl.videoOut to mixer.videoIn;
        connect syncGen.syncOut to mixer.syncIn;
        connect mixer.compositeOut to outputDriver.signalIn;
        connect outputDriver.signalOut to videoOutput;
        connect userControls to amplifier.controlIn;
        connect userControls to contrastControl.controlIn;
        connect userControls to brightnessControl.controlIn;
        
        perform action processImage : ProcessAnalogImage {
            in opticalInput = AnalogImageProcessingSystem::opticalInput.scene;
            in gainControl = AnalogImageProcessingSystem::userControls.gain;
            in brightnessControl = AnalogImageProcessingSystem::userControls.brightness;
            in contrastControl = AnalogImageProcessingSystem::userControls.contrast;
            out processedVideo = AnalogImageProcessingSystem::videoOutput.signal;
        }
    }
    
    requirement def SignalQualityRequirement {
        doc /* The analog processing chain shall maintain high signal quality throughout. */
        
        subject processingSystem : AnalogImageProcessingSystem;
        
        require constraint signalToNoiseRatio {
            doc /* The signal-to-noise ratio shall exceed 55 dB at the output. */
        }
        
        require constraint frequencyResponse {
            doc /* The frequency response shall be flat within ±1 dB from DC to 5 MHz. */
        }
        
        require constraint totalHarmonicDistortion {
            doc /* Total harmonic distortion shall be less than 1% at nominal signal levels. */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The system shall process images with minimal latency and power consumption. */
        
        subject processingSystem : AnalogImageProcessingSystem;
        
        require constraint processingLatency {
            doc /* End-to-end processing latency shall not exceed 50 microseconds. */
        }
        
        require constraint powerConsumption {
            doc /* Total power consumption shall be less than 2 watts during active processing. */
        }
        
        require constraint thermalStability {
            doc /* Signal drift due to temperature variation shall be less than 0.5% over 0-50°C range. */
        }
    }
    
    requirement def FunctionalRequirement {
        doc /* The system shall provide complete analog image processing capabilities. */
        
        subject processingSystem : AnalogImageProcessingSystem;
        
        require constraint opticalConversion {
            doc /* The system shall convert optical images to analog video signals with linear response. */
        }
        
        require constraint signalAmplification {
            doc /* The system shall provide adjustable gain from 0 dB to 20 dB. */
        }
        
        require constraint noiseFiltering {
            doc /* The system shall filter high-frequency noise above 5.5 MHz. */
        }
        
        require constraint imageEnhancement {
            doc /* The system shall provide independent contrast and brightness adjustment. */
        }
        
        require constraint syncGeneration {
            doc /* The system shall generate standard composite video sync signals. */
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for the analog image processing system. */
        
        subject analogProcessor : AnalogImageProcessingSystem;
        
        require signalQuality : SignalQualityRequirement {
            subject processingSystem = analogProcessor;
        }
        
        require performance : PerformanceRequirement {
            subject processingSystem = analogProcessor;
        }
        
        require functionality : FunctionalRequirement {
            subject processingSystem = analogProcessor;
        }
        
        assume constraint operatingConditions {
            doc /* The system operates within specified temperature, voltage, and illumination ranges. */
        }
    }
    
    part analogImageProcessingSystem : AnalogImageProcessingSystem;
}
