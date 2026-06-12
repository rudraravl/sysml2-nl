package AnalogImageProcessingSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def Illuminance :> ISQ::illuminance {
        unit = SI::lux;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Time :> ISQ::time {
        unit = SI::second;
    }

    attribute def PixelRate :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def SignalToNoiseRatio {
        :>> num : Real;
        unit = "dB";
    }

    attribute def Resolution {
        attribute horizontalPixels : Integer;
        attribute verticalPixels : Integer;
    }

    item def OpticalImage {
        attribute sceneIlluminance : Illuminance;
        attribute spectralBandStart : Frequency;
        attribute spectralBandEnd : Frequency;
        attribute frameRate : Frequency;
        attribute resolution : Resolution;
    }

    item def AnalogVideoSignal {
        attribute amplitude : Voltage;
        attribute dcOffset : Voltage;
        attribute bandwidth : Frequency;
        attribute pixelClockEquivalent : PixelRate;
        attribute snr : SignalToNoiseRatio;
        attribute frameRate : Frequency;
        attribute resolution : Resolution;
    }

    item def BiasReference {
        attribute referenceVoltage : Voltage;
        attribute referenceCurrent : Current;
        attribute noiseDensity : Voltage;
    }

    item def ProcessedAnalogImage {
        attribute contrastGain : Real;
        attribute edgeEnhancementGain : Real;
        attribute noiseReductionFactor : Real;
        attribute outputAmplitude : Voltage;
        attribute outputBandwidth : Frequency;
        attribute outputSnr : SignalToNoiseRatio;
        attribute resolution : Resolution;
    }

    port def OpticalInputPort {
        in item image : OpticalImage;
    }

    port def AnalogSignalPort {
        inout item signal : AnalogVideoSignal;
    }

    port def BiasPort {
        in item bias : BiasReference;
    }

    port def ProcessedImagePort {
        out item processedImage : ProcessedAnalogImage;
    }

    port def PowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute supplyCurrent : Current;
    }

    part def PhotodetectorArray {
        port opticalIn : OpticalInputPort;
        port analogOut : AnalogSignalPort;
        port biasIn : BiasPort;

        attribute quantumEfficiency : Real;
        attribute darkCurrent : Current;
        attribute conversionGain : Voltage;
        attribute operatingTemperature : Temperature;
        attribute nativeResolution : Resolution;

        action convertOpticalImageToAnalogSignal {
            in item incidentImage : OpticalImage;
            in item detectorBias : BiasReference;
            out item rawAnalogSignal : AnalogVideoSignal;
        }
    }

    part def CorrelatedDoubleSampler {
        port signalIn : AnalogSignalPort;
        port signalOut : AnalogSignalPort;
        port biasIn : BiasPort;

        attribute resetNoiseReduction : Real;
        attribute samplingAperture : Time;
        attribute maxPixelRate : PixelRate;

        action subtractResetLevel {
            in item rawSignal : AnalogVideoSignal;
            out item sampledSignal : AnalogVideoSignal;
        }
    }

    part def AnalogGainControl {
        port signalIn : AnalogSignalPort;
        port signalOut : AnalogSignalPort;
        port biasIn : BiasPort;

        attribute minimumGain : Real;
        attribute maximumGain : Real;
        attribute currentGain : Real;
        attribute settlingTime : Time;

        action regulateAmplitude {
            in item sampledSignal : AnalogVideoSignal;
            out item normalizedSignal : AnalogVideoSignal;
        }
    }

    part def SpatialFilterNetwork {
        port signalIn : AnalogSignalPort;
        port signalOut : AnalogSignalPort;

        attribute lowPassCorner : Frequency;
        attribute highPassCorner : Frequency;
        attribute edgeKernelStrength : Real;
        attribute temporalNoiseCutoff : Frequency;

        action filterImageSignal {
            in item normalizedSignal : AnalogVideoSignal;
            out item enhancedSignal : AnalogVideoSignal;
        }
    }

    part def AnalogFrameBuffer {
        port signalIn : AnalogSignalPort;
        port signalOut : AnalogSignalPort;
        port power : PowerPort;

        attribute storageCapacitancePerCell : Real;
        attribute holdTime : Time;
        attribute droopRate : Voltage;
        attribute bufferResolution : Resolution;

        action storeFrameChargePattern {
            in item enhancedSignal : AnalogVideoSignal;
            out item delayedSignal : AnalogVideoSignal;
        }
    }

    part def OutputDriver {
        port signalIn : AnalogSignalPort;
        port processedOut : ProcessedImagePort;
        port power : PowerPort;

        attribute outputImpedance : Real;
        attribute maximumOutputSwing : Voltage;
        attribute driveBandwidth : Frequency;

        action driveProcessedImageOutput {
            in item finalAnalogSignal : AnalogVideoSignal;
            out item processedImage : ProcessedAnalogImage;
        }
    }

    part def BiasAndTimingController {
        port detectorBiasOut : BiasPort;
        port samplerBiasOut : BiasPort;
        port gainBiasOut : BiasPort;
        port power : PowerPort;

        attribute masterClock : Frequency;
        attribute framePeriod : Time;
        attribute linePeriod : Time;
        attribute detectorReference : Voltage;
        attribute analogGround : Voltage;

        action generateBiasAndTiming {
            out item detectorBias : BiasReference;
            out item samplerBias : BiasReference;
            out item gainBias : BiasReference;
        }
    }

    part def AnalogImageProcessor {
        port opticalInput : OpticalInputPort;
        port processedOutput : ProcessedImagePort;
        port primaryPower : PowerPort;

        part detector : PhotodetectorArray {
            :>> quantumEfficiency = 0.72;
            :>> darkCurrent = 2.0e-9 [SI::ampere];
            :>> conversionGain = 18.0e-6 [SI::volt];
            :>> operatingTemperature = 300.0 [SI::kelvin];
            :>> nativeResolution.horizontalPixels = 1280;
            :>> nativeResolution.verticalPixels = 720;
        }

        part sampler : CorrelatedDoubleSampler {
            :>> resetNoiseReduction = 0.78;
            :>> samplingAperture = 12.0e-9 [SI::second];
            :>> maxPixelRate = 74.25e6 [SI::hertz];
        }

        part gainControl : AnalogGainControl {
            :>> minimumGain = 0.5;
            :>> maximumGain = 16.0;
            :>> currentGain = 4.0;
            :>> settlingTime = 3.0e-6 [SI::second];
        }

        part spatialFilter : SpatialFilterNetwork {
            :>> lowPassCorner = 22.0e6 [SI::hertz];
            :>> highPassCorner = 1.2e6 [SI::hertz];
            :>> edgeKernelStrength = 1.35;
            :>> temporalNoiseCutoff = 8.0e6 [SI::hertz];
        }

        part frameBuffer : AnalogFrameBuffer {
            :>> storageCapacitancePerCell = 2.5e-12;
            :>> holdTime = 16.67e-3 [SI::second];
            :>> droopRate = 0.8e-3 [SI::volt];
            :>> bufferResolution.horizontalPixels = 1280;
            :>> bufferResolution.verticalPixels = 720;
        }

        part outputDriver : OutputDriver {
            :>> outputImpedance = 75.0;
            :>> maximumOutputSwing = 1.2 [SI::volt];
            :>> driveBandwidth = 30.0e6 [SI::hertz];
        }

        part controller : BiasAndTimingController {
            :>> masterClock = 74.25e6 [SI::hertz];
            :>> framePeriod = 16.67e-3 [SI::second];
            :>> linePeriod = 22.22e-6 [SI::second];
            :>> detectorReference = 1.8 [SI::volt];
            :>> analogGround = 0.0 [SI::volt];
        }

        connect opticalInput to detector.opticalIn;
        connect detector.analogOut to sampler.signalIn;
        connect sampler.signalOut to gainControl.signalIn;
        connect gainControl.signalOut to spatialFilter.signalIn;
        connect spatialFilter.signalOut to frameBuffer.signalIn;
        connect frameBuffer.signalOut to outputDriver.signalIn;
        connect outputDriver.processedOut to processedOutput;

        connect primaryPower to controller.power;
        connect primaryPower to frameBuffer.power;
        connect primaryPower to outputDriver.power;

        connect controller.detectorBiasOut to detector.biasIn;
        connect controller.samplerBiasOut to sampler.biasIn;
        connect controller.gainBiasOut to gainControl.biasIn;

        state def ProcessingStateMachine {
            entry action initializeBiases;
            state Idle;
            state AcquireOpticalFrame;
            state ConvertToAnalog;
            state SampleAndSuppressResetNoise;
            state NormalizeGain;
            state ApplyAnalogSpatialFiltering;
            state StoreAndAlignFrame;
            state DriveProcessedOutput;
            state Fault;

            transition first Idle;
            transition Idle to AcquireOpticalFrame
                accept OpticalFrameAvailable;
            transition AcquireOpticalFrame to ConvertToAnalog
                after 1.0e-6 [SI::second];
            transition ConvertToAnalog to SampleAndSuppressResetNoise
                after 4.0e-6 [SI::second];
            transition SampleAndSuppressResetNoise to NormalizeGain
                after 3.0e-6 [SI::second];
            transition NormalizeGain to ApplyAnalogSpatialFiltering
                after 3.0e-6 [SI::second];
            transition ApplyAnalogSpatialFiltering to StoreAndAlignFrame
                after 6.0e-6 [SI::second];
            transition StoreAndAlignFrame to DriveProcessedOutput
                after 1.0e-3 [SI::second];
            transition DriveProcessedOutput to AcquireOpticalFrame
                after 16.67e-3 [SI::second];
            transition AcquireOpticalFrame to Fault
                accept BiasOutOfRange;
            transition ConvertToAnalog to Fault
                accept SaturationDetected;
            transition Fault to Idle
                accept ResetCommand;
        }

        action performPrimaryFunction {
            in item sceneImage : OpticalImage;
            out item enhancedImage : ProcessedAnalogImage;

            first start;
            then controller.generateBiasAndTiming;
            then detector.convertOpticalImageToAnalogSignal;
            then sampler.subtractResetLevel;
            then gainControl.regulateAmplitude;
            then spatialFilter.filterImageSignal;
            then frameBuffer.storeFrameChargePattern;
            then outputDriver.driveProcessedImageOutput;
            then done;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The system shall process an incoming optical image entirely in the analog signal domain to produce a contrast-normalized, noise-reduced, edge-enhanced analog image output suitable for downstream display, capture, or conversion. */

        subject processor : AnalogImageProcessor;

        require constraint {
            processor.detector.nativeResolution.horizontalPixels >= 1280 and
            processor.detector.nativeResolution.verticalPixels >= 720
        }
    }

    requirement def AnalogDomainRequirement {
        doc
        /* The system shall preserve the image representation as continuously varying voltage and charge signals from photodetection through output driving. */

        subject processor : AnalogImageProcessor;

        require constraint {
            processor.spatialFilter.lowPassCorner >= 20.0e6 [SI::hertz] and
            processor.outputDriver.driveBandwidth >= 30.0e6 [SI::hertz]
        }
    }

    requirement def NoisePerformanceRequirement {
        doc
        /* The processor shall reduce reset and temporal noise while maintaining usable image detail. */

        subject processor : AnalogImageProcessor;

        require constraint {
            processor.sampler.resetNoiseReduction >= 0.70 and
            processor.spatialFilter.temporalNoiseCutoff >= 6.0e6 [SI::hertz]
        }
    }

    requirement def FrameRateRequirement {
        doc
        /* The processor shall support real-time image processing at a nominal sixty frames per second. */

        subject processor : AnalogImageProcessor;

        require constraint {
            processor.controller.framePeriod <= 16.67e-3 [SI::second] and
            processor.controller.masterClock >= 74.25e6 [SI::hertz]
        }
    }

    requirement def OutputCompatibilityRequirement {
        doc
        /* The output driver shall provide a bounded analog image output swing into a standard video load. */

        subject processor : AnalogImageProcessor;

        require constraint {
            processor.outputDriver.outputImpedance == 75.0 and
            processor.outputDriver.maximumOutputSwing <= 1.2 [SI::volt]
        }
    }

    satisfy PrimaryFunctionRequirement by AnalogImageProcessor;
    satisfy AnalogDomainRequirement by AnalogImageProcessor;
    satisfy NoisePerformanceRequirement by AnalogImageProcessor;
    satisfy FrameRateRequirement by AnalogImageProcessor;
    satisfy OutputCompatibilityRequirement by AnalogImageProcessor;
}