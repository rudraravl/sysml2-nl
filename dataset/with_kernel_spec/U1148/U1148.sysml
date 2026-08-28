package MLInferencePlatform {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		attribute def ResponseTimeValue :> Real;
		attribute def UptimePercentValue :> Real;
		attribute def BatchSizeValue :> Integer;
		attribute def ConfidenceValue :> Real;
		
		item def RawData {
			attribute requestId : String;
			attribute payload : Real[0..*];
			attribute receivedAt : String;
		}
		
		item def PreprocessedData {
			attribute requestId : String;
			attribute normalizedValues : Real[0..*];
			attribute isValid : Boolean;
		}
		
		item def InferenceResult {
			attribute requestId : String;
			attribute prediction : String;
			attribute confidence : ConfidenceValue;
			attribute probabilities : Real[0..*];
		}
		
		item def PostprocessedResult {
			attribute requestId : String;
			attribute prediction : String;
			attribute confidence : ConfidenceValue;
			attribute responseBody : String;
		}
		
		item def MonitoringMetrics {
			attribute responseTime : ResponseTimeValue;
			attribute uptimePercent : UptimePercentValue;
			attribute status : String;
		}
		
		item def HealthAlert {
			attribute severity : String;
			attribute alertText : String;
		}
		
		item def ModelWeights {
			attribute parameterCount : Integer = 175000000;
			attribute architecture : String = "Transformer";
		}
		
		item def ModelUpdatePackage {
			attribute version : String;
			attribute source : String;
		}
		
		attribute def ModelLoadedSignal;
		attribute def UpdateTriggerSignal;
		attribute def MaintenanceCommandSignal;
		attribute def FaultDetectedSignal;
		attribute def RecoveredSignal;
		attribute def UpdateCompleteSignal;
		attribute def MaintenanceCompleteSignal;
		attribute def HealthThresholdExceededSignal;
		attribute def HealthNormalSignal;
		
		action def LoadModel;
		action def InitializePlatform;
		action def PreprocessData {
			in raw : RawData;
			out processed : PreprocessedData;
		}
		action def RunInference {
			in processed : PreprocessedData;
			out result : InferenceResult;
		}
		action def PostprocessResult {
			in result : InferenceResult;
			out formatted : PostprocessedResult;
		}
		action def MonitorHealth {
			in metrics : MonitoringMetrics;
			out alert : HealthAlert;
		}
		action def ApplyUpdate;
		action def PerformMaintenance;
		action def HandleError;
		
		state def PlatformStates;
		
		part def ModelCore {
			attribute parameterCount : Integer = 175000000;
			attribute architecture : String = "Transformer";
			port outWeights { out item weights : ModelWeights; }
		}
		
		part def InferenceEngine {
			attribute maxBatchSize : BatchSizeValue = 32;
			port inProcessed { in item processed : PreprocessedData; }
			port inWeights { in item weights : ModelWeights; }
			port inUpdate { in item update : ModelUpdatePackage; }
			port outResult { out item result : InferenceResult; }
			port outMetrics { out item metrics : MonitoringMetrics; }
			part model : ModelCore;
		}
		
		part def DataPreprocessor {
			port inRaw { in item raw : RawData; }
			port outProcessed { out item processed : PreprocessedData; }
		}
		
		part def ResultPostprocessor {
			port inResult { in item result : InferenceResult; }
			port outFormatted { out item formatted : PostprocessedResult; }
		}
		
		part def MonitoringSubsystem {
			attribute maxResponseTime : ResponseTimeValue = 200.0;
			attribute minUptimePercent : UptimePercentValue = 99.9;
			port inMetrics { in item metrics : MonitoringMetrics; }
			port outAlert { out item alert : HealthAlert; }
		}
		
		part def OpenSourceRepository {
			attribute repositoryUrl : String = "https://github.com/openmlplatform/inference-platform";
			attribute license : String = "MIT";
			attribute isPublic : Boolean = true;
			port outUpdate { out item update : ModelUpdatePackage; }
		}
		
		part def CommunityInterface {
			attribute issueTrackerUrl : String;
			attribute forumUrl : String;
			attribute contributionGuideUrl : String;
		}
		
		part def InferencePlatform {
			part modelCore : ModelCore;
			part inferenceEngine : InferenceEngine;
			part preprocessor : DataPreprocessor;
			part postprocessor : ResultPostprocessor;
			part monitor : MonitoringSubsystem;
			part repository : OpenSourceRepository;
			part community : CommunityInterface;
			
			port inRawData { in item raw : RawData; }
			port outResultPort { out item formatted : PostprocessedResult; }
			port outAlertPort { out item alert : HealthAlert; }
			
			connect inRawData to preprocessor.inRaw;
			connect preprocessor.outProcessed to inferenceEngine.inProcessed;
			connect inferenceEngine.outResult to postprocessor.inResult;
			connect postprocessor.outFormatted to outResultPort;
			connect modelCore.outWeights to inferenceEngine.inWeights;
			connect repository.outUpdate to inferenceEngine.inUpdate;
			connect inferenceEngine.outMetrics to monitor.inMetrics;
			connect monitor.outAlert to outAlertPort;
			
			exhibit state platformStates : PlatformStates;
		}
		
		requirement def LowLatencyRequirement {
			doc /* The platform shall respond to inference requests within 200 ms. */
		}
		
		requirement def HighThroughputRequirement {
			doc /* The platform shall process at least 1000 requests per second. */
		}
		
		requirement def OpenSourceRequirement {
			doc /* The platform code and model shall be publicly available under MIT license. */
		}
		
		requirement def ReliabilityRequirement {
			doc /* The platform shall maintain at least 99.9 percent uptime. */
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		action loadModel : LoadModel;
		action initializePlatform : InitializePlatform;
		action preprocessData : PreprocessData;
		action runInference : RunInference;
		action postprocessResult : PostprocessResult;
		action monitorHealth : MonitorHealth;
		action applyUpdate : ApplyUpdate;
		action performMaintenance : PerformMaintenance;
		action handleError : HandleError;
		
		part platform : InferencePlatform;
		
		state platformStates : PlatformStates parallel {
			state 'operational states' {
				entry; then initializing;
				state initializing {
					do loadModel;
					do initializePlatform;
				}
				accept ModelLoadedSignal then operational;
				state operational {
					do preprocessData;
					do runInference;
					do postprocessResult;
				}
				accept UpdateTriggerSignal then updating;
				accept FaultDetectedSignal then errorHandling;
				accept MaintenanceCommandSignal then maintenance;
				state updating {
					do applyUpdate;
				}
				accept UpdateCompleteSignal then operational;
				state maintenance {
					do performMaintenance;
				}
				accept MaintenanceCompleteSignal then operational;
				state errorHandling {
					do handleError;
				}
				accept RecoveredSignal then operational;
			}
			state 'health states' {
				entry; then healthNormal;
				state healthNormal {
					do monitorHealth;
				}
				accept HealthThresholdExceededSignal then healthDegraded;
				state healthDegraded {
					do handleError;
				}
				accept HealthNormalSignal then healthNormal;
			}
		}
		
		requirement lowLatency : LowLatencyRequirement;
		requirement highThroughput : HighThroughputRequirement;
		requirement openSource : OpenSourceRequirement;
		requirement reliability : ReliabilityRequirement;
		
		satisfy lowLatency by platform.monitor;
		satisfy highThroughput by platform.inferenceEngine;
		satisfy openSource by platform.repository;
		satisfy reliability by platform.monitor;
	}
}
