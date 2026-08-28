package MLInferencePlatform {

    import ScalarValues::*;

    package Units {
        unit ms;
        unit s;
        unit req_per_s;
        unit percent;
        unit MB;
        unit params;

        value type Millisecond :> Real { unit ms; }
        value type Second :> Real { unit s; }
        value type RequestsPerSecond :> Real { unit req_per_s; }
        value type Percent :> Real { unit percent; }
        value type Megabyte :> Real { unit MB; }
        value type ParameterCount :> Integer { unit params; }
    }

    package Items {
        import Units::*;

        item def RawData {
            attribute payload : String;
            attribute sourceId : String;
            attribute timestamp : String;
            attribute sizeMB : Megabyte;
        }

        item def PreprocessedData {
            attribute tensorRef : String;
            attribute sequenceLength : Positive;
            attribute normalized : Boolean;
            attribute validated : Boolean;
        }

        item def InferenceResult {
            attribute logitsRef : String;
            attribute confidence : Real;
            attribute batchId : String;
            attribute generatedAt : String;
        }

        item def PredictionResponse {
            attribute result : String;
            attribute confidence : Real;
            attribute latencyMs : Millisecond;
            attribute requestId : String;
        }

        item def HealthMetric {
            attribute responseTimeMs : Millisecond;
            attribute uptimePercent : Percent;
            attribute throughputRps : RequestsPerSecond;
            attribute errorRatePercent : Percent;
            attribute status : String;
        }

        item def ModelArtifact {
            attribute version : String;
            attribute parameterCount : ParameterCount;
            attribute checksum : String;
            attribute sizeMB : Megabyte;
        }

        item def SoftwarePatch {
            attribute patchId : String;
            attribute version : String;
            attribute description : String;
        }
    }

    package Interfaces {
        import Items::*;

        port def DataInputPort {
            in item raw : RawData;
        }

        port def PreprocessedDataPort {
            out item preprocessed : PreprocessedData;
        }

        port def InferenceResultPort {
            out item result : InferenceResult;
        }

        port def ResponsePort {
            out item response : PredictionResponse;
        }

        port def HealthPort {
            out item metric : HealthMetric;
        }

        port def ModelUpdatePort {
            in item artifact : ModelArtifact;
            in item patch : SoftwarePatch;
        }
    }

    package Requirements {
        import Units::*;

        requirement def InferenceLatencyRequirement {
            doc "The platform shall return predictions within acceptable latency.";
            attribute maxLatencyMs : Millisecond = 200;
        }

        requirement def ThroughputRequirement {
            doc "The platform shall support high-throughput batch inference.";
            attribute minThroughputRps : RequestsPerSecond = 100;
        }

        requirement def UptimeRequirement {
            doc "The platform shall maintain high availability.";
            attribute minUptimePercent : Percent = 99.9;
        }

        requirement def OpenSourceRequirement {
            doc "The platform shall be open-source under a permissive MIT license.";
            attribute license : String = "MIT";
        }

        requirement def ZeroDowntimeUpdateRequirement {
            doc "The platform shall support updates without significant downtime.";
            attribute maxDowntimeMs : Millisecond = 5000;
        }

        requirement def MonitoringRequirement {
            doc "The platform shall continuously monitor performance and health against thresholds.";
        }

        requirement def CommunityTransparencyRequirement {
            doc "The platform shall expose issue trackers, discussion forums, and contribution guidelines.";
        }

        requirement inferenceLatencyReq : InferenceLatencyRequirement;
        requirement throughputReq : ThroughputRequirement;
        requirement uptimeReq : UptimeRequirement;
        requirement openSourceReq : OpenSourceRequirement;
        requirement zeroDowntimeReq : ZeroDowntimeUpdateRequirement;
        requirement monitoringReq : MonitoringRequirement;
        requirement communityReq : CommunityTransparencyRequirement;
    }

    package Components {
        import Items::*;
        import Interfaces::*;
        import Units::*;

        part def ModelCore {
            attribute parameterCount : ParameterCount = 175000000;
            attribute architecture : String = "Transformer";
            attribute version : String = "1.0.0";
            attribute loaded : Boolean = false;

            exhibit state ModelLifecycle {
                entry; then Unloaded;
                state Unloaded;
                accept load
                    then Loading;
                state Loading {
                    entry action { loaded = false; }
                    do action { loaded = true; }
                    then Loaded;
                }
                state Loaded;
                accept unload
                    then Unloaded;
            }
        }

        part def InferenceEngine {
            attribute batchSize : Positive = 32;
            attribute optimizedForSpeed : Boolean = true;
            attribute maxConcurrency : Positive = 16;

            port engineIn : PreprocessedDataPort;
            port engineOut : InferenceResultPort;

            part model : ModelCore;

            exhibit state EngineBehavior {
                entry; then Idle;
                state Idle;
                accept preprocessed via engineIn
                    then Executing;
                state Executing {
                    entry action { /* invoke model */ }
                    do action { /* batched forward pass */ }
                    then Emitting;
                }
                state Emitting {
                    send result via engineOut
                        then Idle;
                }
            }
        }

        part def DataPreprocessor {
            attribute normalizationEnabled : Boolean = true;
            attribute validationEnabled : Boolean = true;
            attribute cleaningRulesVersion : String = "1.0.0";

            port preIn : DataInputPort;
            port preOut : PreprocessedDataPort;

            exhibit state PreprocessBehavior {
                entry; then Ready;
                state Ready;
                accept raw via preIn
                    then Cleaning;
                state Cleaning {
                    entry action { /* strip noise, deduplicate */ }
                    then Validating;
                }
                state Validating {
                    entry action { /* schema and range checks */ }
                    then Normalizing;
                }
                state Normalizing {
                    entry action { /* scale and tokenize */ }
                    then Emitting;
                }
                state Emitting {
                    send preprocessed via preOut
                        then Ready;
                }
            }
        }

        part def ResultPostprocessor {
            attribute format : String = "REST_JSON";
            attribute weightedAveragingEnabled : Boolean = true;

            port postIn : InferenceResultPort;
            port postOut : ResponsePort;

            exhibit state PostprocessBehavior {
                entry; then Ready;
                state Ready;
                accept result via postIn
                    then Formatting;
                state Formatting {
                    entry action { /* build standardized structure */ }
                    then Averaging;
                }
                state Averaging {
                    entry action { /* weighted averaging of logits */ }
                    then Emitting;
                }
                state Emitting {
                    send response via postOut
                        then Ready;
                }
            }
        }

        part def MonitoringSubsystem {
            attribute responseTimeThresholdMs : Millisecond = 200;
            attribute uptimeThresholdPercent : Percent = 99.9;
            attribute throughputThresholdRps : RequestsPerSecond = 100;
            attribute errorRateThresholdPercent : Percent = 1.0;

            attribute responseTimeMs : Millisecond;
            attribute uptimePercent : Percent;
            attribute throughputRps : RequestsPerSecond;
            attribute errorRatePercent : Percent;

            port monOut : HealthPort;

            exhibit state MonitoringBehavior {
                entry; then Collecting;
                state Collecting {
                    entry action { /* sample metrics */ }
                    then Evaluating;
                }
                state Evaluating {
                    if (responseTimeMs > responseTimeThresholdMs) then Alerting
                    else if (uptimePercent < uptimeThresholdPercent) then Alerting
                    else if (errorRatePercent > errorRateThresholdPercent) then Alerting
                    else Healthy;
                }
                state Healthy {
                    send metric via monOut
                        then Collecting;
                }
                state Alerting {
                    send metric via monOut
                        then Collecting;
                }
            }
        }

        part def OpenSourceRepository {
            attribute url : String = "https://github.com/example/ml-platform";
            attribute license : String = "MIT";
            attribute versionControl : String = "Git";
            attribute defaultBranch : String = "main";

            port updatePort : ModelUpdatePort;

            exhibit state RepositoryBehavior {
                entry; then Stable;
                state Stable;
                accept artifact via updatePort
                    then Publishing;
                accept patch via updatePort
                    then Publishing;
                state Publishing {
                    entry action { /* tag and release */ }
                    then Stable;
                }
            }
        }

        part def CommunityInterface {
            attribute issueTrackerUrl : String = "https://github.com/example/ml-platform/issues";
            attribute discussionForumUrl : String = "https://github.com/example/ml-platform/discussions";
            attribute contributionGuidelinesUrl : String = "https://github.com/example/ml-platform/CONTRIBUTING.md";
            attribute codeOfConductUrl : String = "https://github.com/example/ml-platform/CODE_OF_CONDUCT.md";
        }
    }

    package System {
        import Items::*;
        import Interfaces::*;
        import Components::*;
        import Units::*;
        import Requirements::*;

        part def MLInferencePlatform {
            attribute responseTimeMs : Millisecond;
            attribute uptimePercent : Percent;
            attribute throughputRps : RequestsPerSecond;
            attribute license : String = "MIT";

            satisfy inferenceLatencyReq;
            satisfy throughputReq;
            satisfy uptimeReq;
            satisfy openSourceReq;
            satisfy zeroDowntimeReq;
            satisfy monitoringReq;
            satisfy communityReq;

            port dataIn : DataInputPort;
            port responseOut : ResponsePort;
            port healthOut : HealthPort;
            port updateIn : ModelUpdatePort;

            part preprocessor : DataPreprocessor;
            part engine : InferenceEngine;
            part postprocessor : ResultPostprocessor;
            part monitor : MonitoringSubsystem;
            part repository : OpenSourceRepository;
            part community : CommunityInterface;

            connection rawFlow connect dataIn to preprocessor.preIn;
            connection preprocessedFlow connect preprocessor.preOut to engine.engineIn;
            connection resultFlow connect engine.engineOut to postprocessor.postIn;
            connection responseFlow connect postprocessor.postOut to responseOut;
            connection healthFlow connect monitor.monOut to healthOut;
            connection updateFlow connect updateIn to repository.updatePort;

            exhibit state PlatformOperation {
                entry; then Uninitialized;
                state Uninitialized;
                transition init from Uninitialized to Initializing
                    when true;

                state Initializing {
                    entry action { /* load configuration */ }
                    do action { /* load model artifacts into engine */ }
                    then Ready;
                }

                state Ready {
                    transition startOp from Ready to Operational
                        when true;
                }

                state Operational {
                    parallel {
                        state ProcessingCycle {
                            entry; then AwaitingRequest;
                            state AwaitingRequest;
                            accept raw via dataIn
                                then Serving;
                            state Serving {
                                entry action { /* preprocess, infer, postprocess */ }
                                then AwaitingRequest;
                            }
                        }
                        state MonitoringCycle {
                            entry; then Sampling;
                            state Sampling {
                                entry action { /* collect health metrics */ }
                                then Reporting;
                            }
                            state Reporting {
                                send metric via healthOut
                                    then Sampling;
                            }
                        }
                    }
                }

                transition requestUpdate from Operational to Updating
                    when updateIn.artifact.version != engine.model.version;

                state Updating {
                    entry action { /* stage new model version */ }
                    do action { /* hot-swap model with zero downtime */ }
                    then Operational;
                }

                transition requestMaintenance from Operational to Maintenance
                    when false;

                state Maintenance {
                    entry action { /* drain requests, run diagnostics */ }
                    then Ready;
                }

                transition detectError from Operational to ErrorHandling
                    when monitor.errorRatePercent > monitor.errorRateThresholdPercent;

                state ErrorHandling {
                    entry action { /* capture fault, isolate failing component */ }
                    do action { /* attempt recovery */ }
                    then Ready;
                }

                transition shutdown from Operational to Terminating
                    when false;

                state Terminating {
                    entry action { /* flush queues, release resources */ }
                }
            }
        }
    }
}
