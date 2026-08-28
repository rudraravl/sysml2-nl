package EchocardiographySimulation {

    import ScalarValues::*;

    // ===== Value Types =====
    value type Depth :> Real { unit 'mm'; }
    value type Thickness :> Real { unit 'mm'; }
    value type AcousticImpedance :> Real { unit 'MRayl'; }
    value type AttenuationCoefficient :> Real { unit 'dB/(cm*MHz)'; }
    value type Frequency :> Real { unit 'MHz'; }
    value type AcousticIntensity :> Real { unit 'mW/cm^2'; }
    value type Velocity :> Real { unit 'cm/s'; }
    value type Strain :> Real { unit '%'; }
    value type Time :> Real { unit 'ms'; }
    value type Distance :> Real { unit 'mm'; }
    value type Amplitude :> Real { unit 'mV'; }
    value type Gain :> Real { unit 'dB'; }
    value type SoundSpeed :> Real { unit 'm/s'; }
    value type PixelValue :> Real { unit 'dB'; }
    value type SNR :> Real { unit 'dB'; }
    value type Angle :> Real { unit 'deg'; }

    // ===== Item Definitions =====
    item def UltrasoundPulse {
        attribute frequency : Frequency := 3.5;
        attribute initialIntensity : AcousticIntensity := 10.0;
        attribute pulseDuration : Time := 0.5;
        attribute currentDistance : Distance := 0.0;
        attribute currentIntensity : AcousticIntensity := 10.0;
    }

    item def EchoSignal {
        attribute amplitude : Amplitude;
        attribute returnTime : Time;
        attribute sourceDepth : Depth;
        attribute frequency : Frequency;
        attribute boundaryIndex : Integer;
    }

    item def ProcessedSignal {
        attribute amplitude : Amplitude;
        attribute returnTime : Time;
        attribute sourceDepth : Depth;
        attribute gainApplied : Gain;
        attribute snr : SNR;
    }

    item def CardiacImage {
        attribute width : Integer := 512;
        attribute height : Integer := 512;
        attribute pixelData : PixelValue[0..*];
    }

    item def VelocityField {
        attribute velocities : Velocity[0..*];
        attribute depths : Depth[0..*];
        attribute timeStep : Time;
    }

    item def StrainMeasurement {
        attribute longitudinalStrain : Strain;
        attribute circumferentialStrain : Strain;
        attribute radialStrain : Strain;
        attribute regionId : String;
        attribute timestamp : Time;
    }

    // ===== Port Definitions =====
    port def PulseOutPort {
        out pulse : UltrasoundPulse;
    }

    port def PulseInPort {
        in pulse : UltrasoundPulse;
    }

    port def EchoOutPort {
        out echo : EchoSignal;
    }

    port def EchoInPort {
        in echo : EchoSignal;
    }

    port def RawEchoOutPort {
        out rawEcho : EchoSignal;
    }

    port def RawEchoInPort {
        in rawEcho : EchoSignal;
    }

    port def ProcessedSignalOutPort {
        out processed : ProcessedSignal;
    }

    port def ProcessedSignalInPort {
        in processed : ProcessedSignal;
    }

    port def VelocityOutPort {
        out velocityField : VelocityField;
    }

    port def VelocityInPort {
        in velocityField : VelocityField;
    }

    port def ImageOutPort {
        out image : CardiacImage;
    }

    port def StrainOutPort {
        out strain : StrainMeasurement;
    }

    // ===== Functions =====
    function def computeReflectionCoefficient(z1 : AcousticImpedance, z2 : AcousticImpedance) : Real {
        return (z2 - z1) / (z2 + z1);
    }

    function def computeAttenuatedIntensity(I0 : AcousticIntensity, alpha : AttenuationCoefficient, f : Frequency, d : Distance) : AcousticIntensity {
        return I0 * (10.0 ** (-alpha * f * (d / 10.0) / 10.0));
    }

    function def computeReturnTime(depth : Depth, c : SoundSpeed) : Time {
        return (2.0 * depth / 1000.0) / c * 1000.0;
    }

    function def computeDopplerShift(f0 : Frequency, v : Velocity, c : SoundSpeed, theta : Angle) : Frequency {
        attribute thetaRad : Real = theta * 3.14159265 / 180.0;
        return 2.0 * f0 * (v / 100.0) * (1.0 - thetaRad * thetaRad / 2.0) / c;
    }

    function def computeStrainFromVelocity(v1 : Velocity, v2 : Velocity, dt : Time, L : Distance) : Strain {
        return ((v2 - v1) * (dt / 1000.0)) / (L / 1000.0) * 100.0;
    }

    function def amplifySignal(input : Amplitude, gainValue : Gain) : Amplitude {
        return input * (10.0 ** (gainValue / 20.0));
    }

    function def filterNoise(input : Amplitude, noiseFloor : Amplitude) : Amplitude {
        return if input > noiseFloor then input else 0.0;
    }

    // ===== Tissue Layer =====
    part def TissueLayer {
        attribute name : String;
        attribute depth : Depth;
        attribute thickness : Thickness;
        attribute acousticImpedance : AcousticImpedance;
        attribute attenuationCoefficient : AttenuationCoefficient;
        attribute soundSpeed : SoundSpeed := 1540.0;
        attribute reflectionCoeffWithNext : Real := 0.0;
    }

    // ===== Heart Model =====
    part def HeartModel {
        port pulseInput : PulseInPort;
        port echoOutput : EchoOutPort;

        attribute mediumSoundSpeed : SoundSpeed := 1540.0;

        part pericardium : TissueLayer {
            attribute name := "Pericardium";
            attribute depth := 0.0;
            attribute thickness := 2.0;
            attribute acousticImpedance := 1.70;
            attribute attenuationCoefficient := 0.5;
        }

        part myocardium : TissueLayer {
            attribute name := "Myocardium";
            attribute depth := 2.0;
            attribute thickness := 10.0;
            attribute acousticImpedance := 1.65;
            attribute attenuationCoefficient := 1.2;
        }

        part endocardium : TissueLayer {
            attribute name := "Endocardium";
            attribute depth := 12.0;
            attribute thickness := 1.0;
            attribute acousticImpedance := 1.58;
            attribute attenuationCoefficient := 0.8;
        }

        part bloodPool : TissueLayer {
            attribute name := "BloodPool";
            attribute depth := 13.0;
            attribute thickness := 5.0;
            attribute acousticImpedance := 1.61;
            attribute attenuationCoefficient := 0.2;
        }

        attribute pericardiumMyocardiumR : Real = computeReflectionCoefficient(pericardium.acousticImpedance, myocardium.acousticImpedance);
        attribute myocardiumEndocardiumR : Real = computeReflectionCoefficient(myocardium.acousticImpedance, endocardium.acousticImpedance);
        attribute endocardiumBloodR : Real = computeReflectionCoefficient(endocardium.acousticImpedance, bloodPool.acousticImpedance);

        action def propagatePulse {
            in pulse : UltrasoundPulse;
            out echoes : EchoSignal[0..*];

            attribute pulseIntensity : AcousticIntensity := pulse.initialIntensity;
            attribute pulseDistance : Distance := 0.0;

            // Boundary 1: Pericardium -> Myocardium
            action computeEcho1 {
                attribute attenuatedI1 : AcousticIntensity = computeAttenuatedIntensity(pulseIntensity, pericardium.attenuationCoefficient, pulse.frequency, pericardium.thickness);
                attribute echoAmp1 : Amplitude = attenuatedI1 * pericardiumMyocardiumR;
                attribute echoTime1 : Time = computeReturnTime(myocardium.depth, mediumSoundSpeed);
                out echo1 : EchoSignal = EchoSignal{amplitude = echoAmp1, returnTime = echoTime1, sourceDepth = myocardium.depth, frequency = pulse.frequency, boundaryIndex = 1};
            }

            // Boundary 2: Myocardium -> Endocardium
            action computeEcho2 {
                attribute attenuatedI2 : AcousticIntensity = computeAttenuatedIntensity(pulseIntensity, myocardium.attenuationCoefficient, pulse.frequency, myocardium.thickness);
                attribute echoAmp2 : Amplitude = attenuatedI2 * myocardiumEndocardiumR;
                attribute echoTime2 : Time = computeReturnTime(endocardium.depth, mediumSoundSpeed);
                out echo2 : EchoSignal = EchoSignal{amplitude = echoAmp2, returnTime = echoTime2, sourceDepth = endocardium.depth, frequency = pulse.frequency, boundaryIndex = 2};
            }

            // Boundary 3: Endocardium -> BloodPool
            action computeEcho3 {
                attribute attenuatedI3 : AcousticIntensity = computeAttenuatedIntensity(pulseIntensity, endocardium.attenuationCoefficient, pulse.frequency, endocardium.thickness);
                attribute echoAmp3 : Amplitude = attenuatedI3 * endocardiumBloodR;
                attribute echoTime3 : Time = computeReturnTime(bloodPool.depth, mediumSoundSpeed);
                out echo3 : EchoSignal = EchoSignal{amplitude = echoAmp3, returnTime = echoTime3, sourceDepth = bloodPool.depth, frequency = pulse.frequency, boundaryIndex = 3};
            }
        }

        state def HeartSimulationStates {
            entry; then Waiting;

            state Waiting;

            transition from Waiting to Propagating
                when pulseInput.pulse.initialIntensity > 0.0;

            state Propagating {
                entry { perform propagatePulse; }
            }

            transition from Propagating to EmittingEchoes when done;

            state EmittingEchoes {
                entry { /* send echo signals to transducer */ }
            }

            transition from EmittingEchoes to Waiting when echoOutput.echo.returnTime >= 0.0;
        }

        exhibit HeartSimulationStates;
    }

    // ===== Ultrasound Transducer =====
    part def UltrasoundTransducer {
        port pulseOutput : PulseOutPort;
        port echoInput : EchoInPort;
        port rawEchoOutput : RawEchoOutPort;

        attribute operatingFrequency : Frequency := 3.5;
        attribute maxIntensity : AcousticIntensity := 10.0;
        attribute pulseDuration : Time := 0.5;
        attribute transducerAngle : Angle := 0.0;
        attribute capturedEchoCount : Integer := 0;

        action def emitPulse {
            out pulse : UltrasoundPulse;
            attribute generatedPulse : UltrasoundPulse = UltrasoundPulse{
                frequency = operatingFrequency,
                initialIntensity = maxIntensity,
                pulseDuration = pulseDuration,
                currentDistance = 0.0,
                currentIntensity = maxIntensity
            };
        }

        action def captureEcho {
            in echo : EchoSignal;
            out rawEcho : EchoSignal;
        }

        action def forwardRawEcho {
            in echo : EchoSignal;
            out forwarded : EchoSignal;
        }

        state def TransducerStateMachine {
            entry; then Idle;

            state Idle {
                entry { /* transducer ready for imaging */ }
            }

            transition from Idle to Transmitting when startImaging;

            state Transmitting {
                entry { perform emitPulse; }
            }

            transition from Transmitting to Receiving when pulseOutput.pulse.frequency > 0.0;

            state Receiving {
                entry { perform captureEcho; }
            }

            transition from Receiving to Forwarding when echoInput.echo.amplitude >= 0.0;

            state Forwarding {
                entry { perform forwardRawEcho; }
            }

            transition from Forwarding to Idle when rawEchoOutput.rawEcho.returnTime >= 0.0;
        }

        exhibit TransducerStateMachine;
    }

    // ===== Signal Processor =====
    part def SignalProcessor {
        port rawEchoInput : RawEchoInPort;
        port processedOutput : ProcessedSignalOutPort;

        attribute gain : Gain := 40.0;
        attribute noiseFloor : Amplitude := 0.01;
        attribute filterBandwidth : Frequency := 2.0;
        attribute processedCount : Integer := 0;

        action def processEcho {
            in rawEcho : EchoSignal;
            out processed : ProcessedSignal;

            action filterStep {
                in input : Amplitude;
                out filtered : Amplitude;
            }

            action amplifyStep {
                in input : Amplitude;
                out amplified : Amplitude;
            }

            attribute filteredAmp : Amplitude = filterNoise(rawEcho.amplitude, noiseFloor);
            attribute amplifiedAmp : Amplitude = amplifySignal(filteredAmp, gain);
            attribute computedSNR : SNR = 20.0 * (if amplifiedAmp > 0.0 then 1.0 else 0.0);
        }

        state def SignalProcessorStates {
            entry; then Ready;

            state Ready {
                entry { /* signal processor idle */ }
            }

            transition from Ready to Filtering when rawEchoInput.rawEcho.amplitude >= 0.0;

            state Filtering {
                entry { /* apply bandpass filter */ }
            }

            transition from Filtering to Amplifying when done;

            state Amplifying {
                entry { /* apply time-gain compensation */ }
            }

            transition from Amplifying to Outputting when done;

            state Outputting {
                entry { perform processEcho; }
            }

            transition from Outputting to Ready when processedOutput.processed.amplitude >= 0.0;
        }

        exhibit SignalProcessorStates;
    }

    // ===== Image Reconstructor =====
    part def ImageReconstructor {
        port processedInput : ProcessedSignalInPort;
        port imageOutput : ImageOutPort;

        attribute scanLines : Integer := 128;
        attribute imageWidth : Integer := 512;
        attribute imageHeight : Integer := 512;
        attribute collectedSignals : Integer := 0;

        action def reconstructImage {
            in signals : ProcessedSignal[0..*];
            out image : CardiacImage;

            action scanConvert {
                in polarData : ProcessedSignal[0..*];
                out cartesianData : PixelValue[0..*];
            }

            action applyLogCompression {
                in linearData : PixelValue[0..*];
                out compressedData : PixelValue[0..*];
            }
        }

        state def ImageReconstructorStates {
            entry; then Collecting;

            state Collecting {
                entry { /* accumulate processed signals across scan lines */ }
            }

            transition from Collecting to ScanConverting when collectedSignals >= scanLines;

            state ScanConverting {
                entry { /* convert polar coordinates to Cartesian */ }
            }

            transition from ScanConverting to Compressing when done;

            state Compressing {
                entry { /* apply log compression for display */ }
            }

            transition from Compressing to Assembling when done;

            state Assembling {
                entry { perform reconstructImage; }
            }

            transition from Assembling to Collecting when imageOutput.image.width > 0;
        }

        exhibit ImageReconstructorStates;
    }

    // ===== Doppler Analyzer =====
    part def DopplerAnalyzer {
        port processedInput : ProcessedSignalInPort;
        port velocityOutput : VelocityOutPort;

        attribute centerFrequency : Frequency := 3.5;
        attribute prf : Frequency := 5.0;
        attribute maxDetectableVelocity : Velocity := 100.0;
        attribute dopplerAngle : Angle := 30.0;
        attribute velocityCount : Integer := 0;

        action def computeVelocity {
            in signal : ProcessedSignal;
            out velocity : Velocity;

            attribute shift : Frequency = computeDopplerShift(centerFrequency, maxDetectableVelocity, 1540.0, dopplerAngle);
        }

        action def buildVelocityField {
            in velocities : Velocity[0..*];
            in depths : Depth[0..*];
            out field : VelocityField;
        }

        state def DopplerAnalyzerStates {
            entry; then Analyzing;

            state Analyzing {
                entry { perform computeVelocity; }
            }

            transition from Analyzing to Accumulating when processedInput.processed.amplitude >= 0.0;

            state Accumulating {
                entry { /* collect velocity samples over time */ }
            }

            transition from Accumulating to BuildingField when velocityCount >= 64;

            state BuildingField {
                entry { perform buildVelocityField; }
            }

            transition from BuildingField to Analyzing when velocityOutput.velocityField.velocities->size() > 0;
        }

        exhibit DopplerAnalyzerStates;
    }

    // ===== Strain Analyzer =====
    part def StrainAnalyzer {
        port velocityInput : VelocityInPort;
        port strainOutput : StrainOutPort;

        attribute segmentCount : Integer := 16;
        attribute baselineLength : Distance := 10.0;
        attribute timeStep : Time := 33.0;
        attribute strainComputed : Boolean := false;

        action def computeStrain {
            in velocityField : VelocityField;
            out strain : StrainMeasurement;

            action computeLongitudinal {
                in v1 : Velocity;
                in v2 : Velocity;
                out ls : Strain;
            }

            action computeCircumferential {
                in v1 : Velocity;
                in v2 : Velocity;
                out cs : Strain;
            }

            action computeRadial {
                in v1 : Velocity;
                in v2 : Velocity;
                out rs : Strain;
            }
        }

        state def StrainAnalyzerStates {
            entry; then Idle;

            state Idle {
                entry { /* strain analyzer waiting for velocity data */ }
            }

            transition from Idle to Computing when velocityInput.velocityField.velocities->size() > 0;

            state Computing {
                entry { perform computeStrain; }
            }

            transition from Computing to Outputting when strainComputed;

            state Outputting {
                entry { /* output strain measurement */ }
            }

            transition from Outputting to Idle when strainOutput.strain.longitudinalStrain != 0.0;
        }

        exhibit StrainAnalyzerStates;
    }

    // ===== Top-Level System =====
    part def EchocardiographySimulationSystem {
        port imageOutput : ImageOutPort;
        port velocityOutput : VelocityOutPort;
        port strainOutput : StrainOutPort;

        part transducer : UltrasoundTransducer;
        part heart : HeartModel;
        part signalProcessor : SignalProcessor;
        part imageReconstructor : ImageReconstructor;
        part dopplerAnalyzer : DopplerAnalyzer;
        part strainAnalyzer : StrainAnalyzer;

        connect transducer.pulseOutput to heart.pulseInput;
        connect heart.echoOutput to transducer.echoInput;
        connect transducer.rawEchoOutput to signalProcessor.rawEchoInput;
        connect signalProcessor.processedOutput to imageReconstructor.processedInput;
        connect signalProcessor.processedOutput to dopplerAnalyzer.processedInput;
        connect dopplerAnalyzer.velocityOutput to strainAnalyzer.velocityInput;
        connect imageReconstructor.imageOutput to imageOutput;
        connect dopplerAnalyzer.velocityOutput to velocityOutput;
        connect strainAnalyzer.strainOutput to strainOutput;

        state def SystemOperationStates {
            entry; then SystemReady;

            state SystemReady {
                entry { /* system initialized and ready for simulation */ }
            }

            transition from SystemReady to Imaging when startSimulation;

            state Imaging {
                entry { /* full echocardiography workflow in progress */ }
            }

            transition from Imaging to ResultsReady when imageOutput.image.width > 0 and velocityOutput.velocityField.velocities->size() > 0 and strainOutput.strain.longitudinalStrain != 0.0;

            state ResultsReady {
                entry { /* all clinical outputs generated */ }
            }

            transition from ResultsReady to SystemReady when reset;
        }

        exhibit SystemOperationStates;
    }

    // ===== Requirements =====
    requirement def EchocardiographyRequirement {
        doc /* Base requirement for the echocardiography simulation system. */
    }

    requirement def HeartModelRequirement :> EchocardiographyRequirement {
        doc /* The system shall model the heart as distinct tissue layers including myocardium, endocardium, and pericardium. */
        subject heartModel : HeartModel;
        constraint { heartModel.pericardium.name == "Pericardium" }
        constraint { heartModel.myocardium.name == "Myocardium" }
        constraint { heartModel.endocardium.name == "Endocardium" }
        constraint { heartModel.pericardium.acousticImpedance > 0.0 }
        constraint { heartModel.myocardium.acousticImpedance > 0.0 }
        constraint { heartModel.endocardium.acousticImpedance > 0.0 }
    }

    requirement def AcousticPropertiesRequirement :> EchocardiographyRequirement {
        doc /* Each tissue layer shall be defined by depth, acoustic impedance, and attenuation coefficient. */
        subject layer : TissueLayer;
        constraint { layer.depth >= 0.0 }
        constraint { layer.acousticImpedance > 0.0 }
        constraint { layer.attenuationCoefficient >= 0.0 }
        constraint { layer.thickness > 0.0 }
    }

    requirement def TransducerRequirement :> EchocardiographyRequirement {
        doc /* The ultrasound transducer shall emit a high-frequency sound pulse into the heart model. */
        subject transducer : UltrasoundTransducer;
        constraint { transducer.operatingFrequency >= 1.0 }
        constraint { transducer.operatingFrequency <= 15.0 }
        constraint { transducer.maxIntensity > 0.0 }
        constraint { transducer.pulseDuration > 0.0 }
    }

    requirement def EchoGenerationRequirement :> EchocardiographyRequirement {
        doc /* The system shall calculate sound wave reflections at layer boundaries and intensity attenuation over distance. */
        subject heart : HeartModel;
        constraint { heart.pericardiumMyocardiumR != 0.0 }
        constraint { heart.myocardiumEndocardiumR != 0.0 }
        constraint { heart.endocardiumBloodR != 0.0 }
    }

    requirement def SignalProcessingRequirement :> EchocardiographyRequirement {
        doc /* The signal processor shall clean and amplify weak echo signals. */
        subject processor : SignalProcessor;
        constraint { processor.gain > 0.0 }
        constraint { processor.noiseFloor >= 0.0 }
        constraint { processor.filterBandwidth > 0.0 }
    }

    requirement def ImageReconstructionRequirement :> EchocardiographyRequirement {
        doc /* The image reconstructor shall assemble echo data into a 2D cardiac image. */
        subject reconstructor : ImageReconstructor;
        constraint { reconstructor.imageWidth > 0 }
        constraint { reconstructor.imageHeight > 0 }
        constraint { reconstructor.scanLines > 0 }
    }

    requirement def DopplerAnalysisRequirement :> EchocardiographyRequirement {
        doc /* The Doppler analyzer shall calculate blood flow velocity within the heart. */
        subject doppler : DopplerAnalyzer;
        constraint { doppler.centerFrequency > 0.0 }
        constraint { doppler.maxDetectableVelocity > 0.0 }
        constraint { doppler.prf > 0.0 }
    }

    requirement def StrainAnalysisRequirement :> EchocardiographyRequirement {
        doc /* The strain analyzer shall measure deformation and contraction of heart muscle using velocity information. */
        subject strain : StrainAnalyzer;
        constraint { strain.segmentCount > 0 }
        constraint { strain.baselineLength > 0.0 }
        constraint { strain.timeStep > 0.0 }
    }

    requirement def FullWorkflowRequirement :> EchocardiographyRequirement {
        doc /* The system shall simulate the entire echocardiography workflow from pulse emission to clinical output generation. */
        subject system : EchocardiographySimulationSystem;
        constraint { system.transducer.operatingFrequency > 0.0 }
        constraint { system.heart.pericardium.acousticImpedance > 0.0 }
        constraint { system.signalProcessor.gain > 0.0 }
    }

    // ===== Requirement Usages =====
    requirement heartModelReq : HeartModelRequirement {
        subject heartModel : HeartModel;
    }

    requirement acousticPropsReq : AcousticPropertiesRequirement {
        subject layer : TissueLayer;
    }

    requirement transducerReq : TransducerRequirement {
        subject transducer : UltrasoundTransducer;
    }

    requirement echoGenReq : EchoGenerationRequirement {
        subject heart : HeartModel;
    }

    requirement signalProcReq : SignalProcessingRequirement {
        subject processor : SignalProcessor;
    }

    requirement imageReconReq : ImageReconstructionRequirement {
        subject reconstructor : ImageReconstructor;
    }

    requirement dopplerReq : DopplerAnalysisRequirement {
        subject doppler : DopplerAnalyzer;
    }

    requirement strainReq : StrainAnalysisRequirement {
        subject strain : StrainAnalyzer;
    }

    requirement workflowReq : FullWorkflowRequirement {
        subject system : EchocardiographySimulationSystem;
    }

    // ===== Instantiation =====
    part simulationInstance : EchocardiographySimulationSystem {
        // Configured with default parameters for standard echocardiography simulation
    }

    // ===== Requirement Satisfaction =====
    satisfaction heartModelReq by simulationInstance.heart;
    satisfaction acousticPropsReq by simulationInstance.heart.myocardium;
    satisfaction transducerReq by simulationInstance.transducer;
    satisfaction echoGenReq by simulationInstance.heart;
    satisfaction signalProcReq by simulationInstance.signalProcessor;
    satisfaction imageReconReq by simulationInstance.imageReconstructor;
    satisfaction dopplerReq by simulationInstance.dopplerAnalyzer;
    satisfaction strainReq by simulationInstance.strainAnalyzer;
    satisfaction workflowReq by simulationInstance;

}
