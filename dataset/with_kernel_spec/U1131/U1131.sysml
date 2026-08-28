package CloudInfrastructure {
	private import ScalarValues::*;

	attribute def Gbps :> Real;
	attribute def Millisecond :> Real;
	attribute def Gigabyte :> Real;
	attribute def Terabyte :> Real;
	attribute def CoreCount :> Integer;
	attribute def Percent :> Real;
	attribute def Second :> Real;

	attribute def WorkloadRequest {
		attribute jobId : String;
		attribute cpuDemand : CoreCount;
		attribute memoryDemand : Gigabyte;
		attribute storageDemand : Gigabyte;
		attribute priority : Integer;
	}

	attribute def TelemetryData {
		attribute nodeId : String;
		attribute cpuUtilization : Percent;
		attribute memoryUtilization : Percent;
		attribute storageUtilization : Percent;
		attribute throughput : Real;
		attribute temperature : Real;
	}

	attribute def PredictiveInsight {
		attribute predictedDemand : Real;
		attribute bottleneckNodeId : String;
		attribute trendDirection : String;
		attribute confidenceScore : Real;
		attribute estimatedEfficiency : Percent;
	}

	attribute def OptimizationCommand {
		attribute commandType : String;
		attribute sourceNodeId : String;
		attribute targetNodeId : String;
		attribute resourceAmount : Gigabyte;
	}

	attribute def NodeStatus {
		attribute nodeId : String;
		attribute cpuUtilization : Percent;
		attribute memoryUtilization : Percent;
		attribute storageUtilization : Percent;
		attribute isAvailable : Boolean;
	}

	attribute def InitializeSystem;
	attribute def EnterMaintenance;
	attribute def ExitMaintenance;
	attribute def Shutdown;

	action def BootSystem;
	action def ConnectNodes;

	action def ReceiveWorkload {
		in request : WorkloadRequest;
	}

	action def SelectBestNode {
		in request : WorkloadRequest;
		in statuses : NodeStatus[0..*];
		out assignedWorkload : WorkloadRequest;
	}

	action def ProcessWorkload {
		in workload : WorkloadRequest;
	}

	action def CollectTelemetry {
		out telemetry : TelemetryData;
	}

	action def AnalyzePerformance {
		in telemetry : TelemetryData[0..*];
		out insight : PredictiveInsight;
	}

	action def ReviewAndOptimize {
		in insight : PredictiveInsight;
		out command : OptimizationCommand;
	}

	action def ExecuteCommand {
		in command : OptimizationCommand;
	}

	action def PerformMaintenance;

	part def ComputeNode {
		attribute nodeId : String;
		attribute cpuCores : CoreCount = 64;
		attribute memoryCapacity : Gigabyte = 256;
		attribute storageCapacity : Terabyte = 2;
		attribute cpuUtilization : Percent;
		attribute memoryUtilization : Percent;
		attribute storageUtilization : Percent;
		attribute isAvailable : Boolean = true;

		port workloadPort {
			in workload : WorkloadRequest;
		}
		port telemetryPort {
			out telemetry : TelemetryData;
		}
		port commandPort {
			in command : OptimizationCommand;
		}
		port networkPort {
			inout data;
		}
	}

	part def NetworkFabric {
		attribute bandwidth : Gbps = 100;
		attribute latency : Millisecond = 0.01;
		attribute nodeCount : Integer = 500;
		port fabricPort {
			inout data;
		}
	}

	part def LoadBalancer {
		port requestPort {
			in request : WorkloadRequest;
		}
		port statusPort {
			in nodeStatus : NodeStatus;
		}
		port assignmentPort {
			out assignedWorkload : WorkloadRequest;
		}
	}

	part def AnalyticsEngine {
		port telemetryPort {
			in telemetry : TelemetryData;
		}
		port insightPort {
			out insight : PredictiveInsight;
		}
	}

	part def OptimizationController {
		port insightPort {
			in insight : PredictiveInsight;
		}
		port commandPort {
			out command : OptimizationCommand;
		}
		attribute targetEfficiency : Percent = 85;
		attribute reviewInterval : Second = 10;
	}

	part def CloudPlatform {
		port externalRequestPort {
			in request : WorkloadRequest;
		}
		part loadBalancer : LoadBalancer;
		part computeNodes : ComputeNode[500];
		part networkFabric : NetworkFabric;
		part analyticsEngine : AnalyticsEngine;
		part optimizationController : OptimizationController;
	}

	part cloudPlatform : CloudPlatform {
		bind externalRequestPort = loadBalancer.requestPort;

		flow workloadFlow of WorkloadRequest
			from loadBalancer.assignmentPort.assignedWorkload to computeNodes.workloadPort.workload;

		flow telemetryFlow of TelemetryData
			from computeNodes.telemetryPort.telemetry to analyticsEngine.telemetryPort.telemetry;

		flow insightFlow of PredictiveInsight
			from analyticsEngine.insightPort.insight to optimizationController.insightPort.insight;

		flow commandFlow of OptimizationCommand
			from optimizationController.commandPort.command to computeNodes.commandPort.command;

		state platformStates {
			state Initialization {
				do action boot;
				state ConnectingNodes {
					do action connect;
				}
				transition first ConnectingNodes accept InitializeSystem then NormalOperation;
			}

			state NormalOperation {
				state Active parallel {
					state WorkloadProcessing {
						state Receiving {
							do action receive;
						}
						transition first Receiving then Assigning;
						state Assigning {
							do action select;
						}
						transition first Assigning then Processing;
						state Processing {
							do action process;
						}
						transition first Processing then Receiving;
					}

					state AnalyticsAndOptimization {
						state Collecting {
							do action collect;
						}
						transition first Collecting then Analyzing;
						state Analyzing {
							do action analyze;
						}
						transition first Analyzing then Optimizing;
						state Optimizing {
							do action optimize;
						}
						transition first Optimizing then Collecting;
					}
				}
			}

			state Maintenance {
				do action maintain;
			}

			transition first NormalOperation accept EnterMaintenance then Maintenance;
			transition first Maintenance accept ExitMaintenance then NormalOperation;
			transition first NormalOperation accept Shutdown then done;
			transition first Maintenance accept Shutdown then done;
		}
	}

	requirement def ComputeNodeSpec {
		attribute requiredCpuCores : CoreCount = 64;
		attribute requiredMemory : Gigabyte = 256;
		attribute requiredStorage : Terabyte = 2;
		attribute requiredNodeCount : Integer = 500;
	}

	requirement def NetworkFabricSpec {
		attribute requiredBandwidth : Gbps = 100;
		attribute maxLatency : Millisecond = 0.01;
	}

	requirement def OptimizationSpec {
		attribute targetEfficiency : Percent = 85;
		attribute reviewInterval : Second = 10;
	}

	requirement def PlatformStateSpec {
		attribute requiredStates : String;
	}

	requirement computeNodesRequirement : ComputeNodeSpec {
		subject computeNodes : ComputeNode[500];
	}

	requirement networkFabricRequirement : NetworkFabricSpec {
		subject networkFabric : NetworkFabric;
	}

	requirement optimizationRequirement : OptimizationSpec {
		subject optimizationController : OptimizationController;
	}

	requirement platformStateRequirement : PlatformStateSpec {
		subject cloudPlatform : CloudPlatform;
		constraint { requiredStates == "Initialization, NormalOperation, Maintenance"; }
	}
}
