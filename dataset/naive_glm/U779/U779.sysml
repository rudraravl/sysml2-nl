package MorphixChameleonSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Units =====

    unit lux;
    unit nm;
    unit cd_per_m2;
    unit percent;
    unit s;
    unit Hz;

    // ===== Value Types =====

    value def LuminanceValue :> Real {
        unit lux;
    }

    value def WavelengthValue :> Real {
        unit nm;
    }

    value def IntensityValue :> Real {
        unit cd_per_m2;
    }

    value def AdaptationSpeed :> Real {
        unit percent;
    }

    value def PatternAccuracy :> Real {
        unit percent;
    }

    value def TimeValue :> Real {
        unit s;
    }

    value def FrequencyValue :> Real {
        unit Hz;
    }

    value def CoverageArea :> Real {
        unit m2;
    }

    // ===== Enumerations =====

    enum def ThreatLevel {
        low;
        medium;
        high;
        critical;
    }

    enum def SystemMode {
        standby;
        sensing;
        analyzing;
        adapting;
        emergency;
    }

    enum def SensorStatus {
        nominal;
        degraded;
        faulted;
    }

    // ===== Item Types =====

    item def RawVisualData {
        attribute luminance : LuminanceValue;
        attribute wavelength : WavelengthValue;
        attribute intensity : IntensityValue;
        attribute spatialPattern : String;
        attribute sensorId : Integer;
        attribute timestamp : TimeValue;
    }

    item def EnvironmentalSignature {
        attribute dominantWavelength : WavelengthValue;
        attribute averageLuminance : LuminanceValue;
        attribute texturePattern : String;
        attribute colorPalette : String;
        attribute confidence : PatternAccuracy;
        attribute signatureId : Integer;
    }

    item def ThreatReport {
        attribute threatLevel : ThreatLevel;
        attribute observationLikelihood : PatternAccuracy;
        attribute recommendedUrgency : AdaptationSpeed;
        attribute detectedAnomalies : String;
        attribute reportId : Integer;
    }

    item def CamouflageCommand {
        attribute targetPattern : String;
        attribute targetWavelength : WavelengthValue;
        attribute targetLuminance : LuminanceValue;
        attribute adaptationSpeed : AdaptationSpeed;
        attribute intensity : IntensityValue;
        attribute commandId : Integer;
    }

    item def DisplayedPattern {
        attribute currentPattern : String;
        attribute currentWavelength : WavelengthValue;
        attribute currentLuminance : LuminanceValue;
        attribute coverageArea : CoverageArea;
        attribute refreshRate : FrequencyValue;
        attribute renderId : Integer;
    }

    item def PerformanceFeedback {
        attribute accuracy : PatternAccuracy;
        attribute responseTime : TimeValue;
        attribute deviationIndex : Real;
        attribute recommendation : String;
        attribute feedbackId : Integer;
    }

    // ===== Port Definitions =====

    port def RawVisualDataOut {
        out rawVisualData : RawVisualData;
    }

    port def RawVisualDataIn {
        in rawVisualData : RawVisualData;
    }

    port def EnvironmentalSignatureOut {
        out environmentalSignature : EnvironmentalSignature;
    }

    port def EnvironmentalSignatureIn {
        in environmentalSignature : EnvironmentalSignature;
    }

    port def ThreatReportOut {
        out threatReport : ThreatReport;
    }

    port def ThreatReportIn {
        in threatReport : ThreatReport;
    }

    port def CamouflageCommandOut {
        out camouflageCommand : CamouflageCommand;
    }

    port def CamouflageCommandIn {
        in camouflageCommand : CamouflageCommand;
    }

    port def DisplayedPatternOut {
        out displayedPattern : DisplayedPattern;
    }

    port def DisplayedPatternIn {
        in displayedPattern : DisplayedPattern;
    }

    port def PerformanceFeedbackOut {
        out performanceFeedback : PerformanceFeedback;
    }

    port def PerformanceFeedbackIn {
        in performanceFeedback : PerformanceFeedback;
    }

    // ===== Part Definitions =====

    part def OpticalSensorArray {
        port visualOut : RawVisualDataOut;
        attribute sensorCount : Integer = 360;
        attribute fieldOfView : Real = 360.0;
        attribute captureRate : FrequencyValue = 60.0 [Hz];
        attribute spectralRangeMin : WavelengthValue = 380.0 [nm];
        attribute spectralRangeMax : WavelengthValue = 780.0 [nm];
        attribute status : SensorStatus = SensorStatus::nominal;

        action def CaptureEnvironment {
            in sensorIndex : Integer;
            out capturedData : RawVisualData;
        }

        action def CaptureAllSensors {
            out aggregatedData : RawVisualData;
        }

        exhibit state SensorStateMachine {
            entry; then Active;
            state Active {
                entry;
                do action CaptureAllSensors;
                transition on completion to Active;
            }
            state Degraded {
                entry;
                transition on completion to Active;
            }
        }
    }

    part def PatternAnalysisUnit {
        port visualIn : RawVisualDataIn;
        port signatureOut : EnvironmentalSignatureOut;
        attribute processingLatency : TimeValue = 0.05 [s];
        attribute algorithmVersion : String = "NeuralPatternMatcher-v3.2";
        attribute signatureCounter : Integer = 0;

        action def AnalyzeVisualData {
            in raw : RawVisualData;
            out signature : EnvironmentalSignature;
        }

        action def GenerateSignature {
            in raw : RawVisualData;
            out signature : EnvironmentalSignature;
        }

        exhibit state AnalysisStateMachine {
            entry; then Idle;
            state Idle {
                transition when visualIn.rawVisualData is received to Processing;
            }
            state Processing {
                entry;
                do action AnalyzeVisualData;
                transition on completion to Idle;
            }
        }
    }

    part def ThreatAssessmentModule {
        port signatureIn : EnvironmentalSignatureIn;
        port threatOut : ThreatReportOut;
        attribute threatThreshold : PatternAccuracy = 75.0 [percent];
        attribute assessmentLatency : TimeValue = 0.03 [s];
        attribute reportCounter : Integer = 0;

        action def AssessThreat {
            in signature : EnvironmentalSignature;
            out report : ThreatReport;
        }

        action def EvaluateContext {
            in signature : EnvironmentalSignature;
            out urgency : AdaptationSpeed;
            out level : ThreatLevel;
        }

        exhibit state ThreatStateMachine {
            entry; then Monitoring;
            state Monitoring {
                entry;
                do action AssessThreat;
                transition on completion to Monitoring;
            }
        }
    }

    part def AdaptationController {
        port signatureIn : EnvironmentalSignatureIn;
        port threatIn : ThreatReportIn;
        port feedbackIn : PerformanceFeedbackIn;
        port commandOut : CamouflageCommandOut;
        attribute neuralModel : String = "NeuralPatternMatching";
        attribute maxAdaptationSpeed : AdaptationSpeed = 100.0 [percent];
        attribute currentMode : SystemMode = SystemMode::standby;
        attribute commandCounter : Integer = 0;
        attribute learningRate : Real = 0.01;

        action def ComputeCamouflage {
            in signature : EnvironmentalSignature;
            in threat : ThreatReport;
            in feedback : PerformanceFeedback;
            out command : CamouflageCommand;
        }

        action def MatchNeuralPattern {
            in signature : EnvironmentalSignature;
            out targetPattern : String;
            out targetWavelength : WavelengthValue;
            out targetLuminance : LuminanceValue;
        }

        action def AdjustSpeedAndIntensity {
            in threat : ThreatReport;
            in feedback : PerformanceFeedback;
            out adaptationSpeed : AdaptationSpeed;
            out intensity : IntensityValue;
        }

        exhibit state ControllerStateMachine {
            entry; then Standby;

            state Standby {
                entry { currentMode = SystemMode::standby; }
                transition when signatureIn.environmentalSignature is received to Sensing;
            }

            state Sensing {
                entry { currentMode = SystemMode::sensing; }
                transition on completion to Analyzing;
            }

            state Analyzing {
                entry { currentMode = SystemMode::analyzing; }
                do action ComputeCamouflage;
                transition on completion to Adapting;
            }

            state Adapting {
                entry { currentMode = SystemMode::adapting; }
                transition when threatIn.threatReport.threatLevel == ThreatLevel::critical to Emergency;
                transition on completion to Standby;
            }

            state Emergency {
                entry { currentMode = SystemMode::emergency; }
                do action ComputeCamouflage;
                transition on completion to Adapting;
            }
        }
    }

    part def ChromatophoreNetwork {
        port commandIn : CamouflageCommandIn;
        port displayOut : DisplayedPatternOut;
        attribute cellDensity : Integer = 10000;
        attribute colorGamut : String = "FullVisibleSpectrum";
        attribute responseTime : TimeValue = 0.02 [s];
        attribute refreshRate : FrequencyValue = 120.0 [Hz];
        attribute totalCoverageArea : CoverageArea = 1.5 [m2];
        attribute renderCounter : Integer = 0;

        action def RenderPattern {
            in command : CamouflageCommand;
            out display : DisplayedPattern;
        }

        action def ActivateChromatophores {
            in command : CamouflageCommand;
            out wavelength : WavelengthValue;
            out luminance : LuminanceValue;
        }

        exhibit state ChromatophoreStateMachine {
            entry; then Idle;

            state Idle {
                transition when commandIn.camouflageCommand is received to Activating;
            }

            state Activating {
                entry;
                do action ActivateChromatophores;
                transition on completion to Displaying;
            }

            state Displaying {
                entry;
                do action RenderPattern;
                transition on completion to Idle;
            }
        }
    }

    part def PerformanceMonitor {
        port signatureIn : EnvironmentalSignatureIn;
        port displayIn : DisplayedPatternIn;
        port feedbackOut : PerformanceFeedbackOut;
        attribute accuracyThreshold : PatternAccuracy = 90.0 [percent];
        attribute maxResponseTime : TimeValue = 0.1 [s];
        attribute feedbackCounter : Integer = 0;

        action def EvaluatePerformance {
            in signature : EnvironmentalSignature;
            in display : DisplayedPattern;
            out feedback : PerformanceFeedback;
        }

        action def ComputeDeviation {
            in signature : EnvironmentalSignature;
            in display : DisplayedPattern;
            out deviation : Real;
            out accuracy : PatternAccuracy;
        }

        exhibit state MonitorStateMachine {
            entry; then Evaluating;
            state Evaluating {
                entry;
                do action EvaluatePerformance;
                transition on completion to Evaluating;
            }
        }
    }

    // ===== Top-level System =====

    part def MorphixChameleonSystem {
        attribute systemId : String = "Morphix-CS-001";
        attribute operationalStatus : SystemMode = SystemMode::standby;
        attribute powerConsumption : Real = 45.0;

        part opticalSensorArray : OpticalSensorArray;
        part patternAnalysisUnit : PatternAnalysisUnit;
        part threatAssessmentModule : ThreatAssessmentModule;
        part adaptationController : AdaptationController;
        part chromatophoreNetwork : ChromatophoreNetwork;
        part performanceMonitor : PerformanceMonitor;

        // Optical sensors -> Pattern analysis
        connection opticalSensorArray.visualOut to patternAnalysisUnit.visualIn {
            flow of RawVisualData;
        }

        // Pattern analysis -> Threat assessment
        connection patternAnalysisUnit.signatureOut to threatAssessmentModule.signatureIn {
            flow of EnvironmentalSignature;
        }

        // Pattern analysis -> Adaptation controller
        connection patternAnalysisUnit.signatureOut to adaptationController.signatureIn {
            flow of EnvironmentalSignature;
        }

        // Threat assessment -> Adaptation controller
        connection threatAssessmentModule.threatOut to adaptationController.threatIn {
            flow of ThreatReport;
        }

        // Adaptation controller -> Chromatophore network
        connection adaptationController.commandOut to chromatophoreNetwork.commandIn {
            flow of CamouflageCommand;
        }

        // Chromatophore network -> Performance monitor
        connection chromatophoreNetwork.displayOut to performanceMonitor.displayIn {
            flow of DisplayedPattern;
        }

        // Pattern analysis -> Performance monitor (target signature)
        connection patternAnalysisUnit.signatureOut to performanceMonitor.signatureIn {
            flow of EnvironmentalSignature;
        }

        // Performance monitor -> Adaptation controller (feedback loop)
        connection performanceMonitor.feedbackOut to adaptationController.feedbackIn {
            flow of PerformanceFeedback;
        }

        satisfaction CamouflageConcealmentRequirement by MorphixChameleonSystem;
        satisfaction OpticalSensingRequirement by opticalSensorArray;
        satisfaction PatternAnalysisRequirement by patternAnalysisUnit;
        satisfaction ThreatAssessmentRequirement by threatAssessmentModule;
        satisfaction AdaptationControlRequirement by adaptationController;
        satisfaction ChromatophoreRenderingRequirement by chromatophoreNetwork;
        satisfaction PerformanceFeedbackRequirement by performanceMonitor;
        satisfaction ContinuousOperationRequirement by MorphixChameleonSystem;
    }

    // ===== Requirements =====

    requirement def CamouflageConcealmentRequirement {
        doc /* The Morphix Chameleon System shall provide real-time adaptive camouflage by detecting the surrounding visual environment and replicating its colors, patterns, and textures on a display surface. */
        attribute maxDetectionTime : TimeValue = 0.1 [s];
        attribute minPatternAccuracy : PatternAccuracy = 90.0 [percent];
        subject : MorphixChameleonSystem;
    }

    requirement def OpticalSensingRequirement {
        doc /* The optical sensor array shall capture 360-degree visual information including light spectrums, intensity, and spatial patterns. */
        attribute minFieldOfView : Real = 360.0;
        attribute minCaptureRate : FrequencyValue = 30.0 [Hz];
        attribute minSpectralRangeMin : WavelengthValue = 380.0 [nm];
        attribute maxSpectralRangeMax : WavelengthValue = 780.0 [nm];
        subject : OpticalSensorArray;
    }

    requirement def PatternAnalysisRequirement {
        doc /* The Pattern Analysis Unit shall produce an environmental signature from raw visual data within the specified latency. */
        attribute maxLatency : TimeValue = 0.05 [s];
        attribute minConfidence : PatternAccuracy = 80.0 [percent];
        subject : PatternAnalysisUnit;
    }

    requirement def ThreatAssessmentRequirement {
        doc /* The Threat Assessment Module shall evaluate the environmental signature for danger or observation and determine the urgency for camouflage change. */
        attribute maxAssessmentLatency : TimeValue = 0.03 [s];
        subject : ThreatAssessmentModule;
    }

    requirement def AdaptationControlRequirement {
        doc /* The Adaptation Controller shall compute the ideal camouflage pattern using Neural Pattern Matching and adjust speed and intensity based on threat level. */
        attribute maxComputationTime : TimeValue = 0.04 [s];
        attribute maxAdaptationSpeed : AdaptationSpeed = 100.0 [percent];
        subject : AdaptationController;
    }

    requirement def ChromatophoreRenderingRequirement {
        doc /* The Chromatophore Network shall rapidly change color across a vast spectrum to physically display the computed camouflage pattern. */
        attribute maxResponseTime : TimeValue = 0.05 [s];
        attribute minCellDensity : Integer = 5000;
        attribute minRefreshRate : FrequencyValue = 60.0 [Hz];
        subject : ChromatophoreNetwork;
    }

    requirement def PerformanceFeedbackRequirement {
        doc /* The Performance Monitor shall continuously compare the displayed pattern against the target environmental signature and provide feedback to the Adaptation Controller. */
        attribute minAccuracyThreshold : PatternAccuracy = 90.0 [percent];
        attribute maxFeedbackLatency : TimeValue = 0.1 [s];
        subject : PerformanceMonitor;
    }

    requirement def ContinuousOperationRequirement {
        doc /* The system shall operate in a continuous cycle of sensing, analyzing, and adapting to maintain optimal concealment as the environment or threat level changes. */
        attribute maxCycleTime : TimeValue = 0.2 [s];
        subject : MorphixChameleonSystem;
    }
}
