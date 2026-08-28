package SelfEvolvingDataPlatform {

	import ScalarValues::*;
	import ISQ::*;

	// ---------- Value types with units ----------

	value def ProcessingSpeed :> Real {
		unit ops_per_s;
	}
	unit ops_per_s { 
		def : "operations per second";
	}

	value def PowerDraw :> Real {
		unit watt;
	}
	unit watt :> ISQ::watt;

	value def Latency :> Real {
		unit ms;
	}
	unit ms {
		def : "millisecond";
	}

	value def Efficiency :> Real {
		unit ops_per_W;
	}
	unit ops_per_W {
		def : "operations per watt";
	}

	value def Throughput :> Real {
		unit Mb_per_s;
	}
	unit Mb_per_s {
		def : "megabits per second";
	}

	value type DataStream :> Real;

	item def DataPacket {
		attribute payload : DataStream;
		attribute timestamp : Real;
	}

	// ---------- Interfaces / Ports ----------

	port def DataInputPort {
		in item dataIn : DataPacket;
	}

	port def DataOutputPort {
		out item dataOut : DataPacket;
	}

	port def MetricPort {
		out attribute throughput : Throughput;
		out attribute latency : Latency;
		out attribute efficiency : Efficiency;
	}

	port def EvolutionCommandPort {
		out attribute targetGeneration : Integer;
		out attribute activate : Boolean;
	}

	port def ControlPort {
		in attribute command : String;
	}

	// ---------- Processor base ----------

	part def ProcessorBase {
		attribute generation : Integer;
		attribute maxSpeed : ProcessingSpeed;
		attribute powerDraw : PowerDraw;
		attribute parallelChannels : Integer;
		attribute active : Boolean = false;

		port dataIn : DataInputPort;
		port dataOut : DataOutputPort;
		port control : ControlPort;

		attribute currentThroughput : Throughput = 0 [Mb_per_s];
		attribute currentLatency : Latency = 0 [ms];
		attribute currentEfficiency : Efficiency = 0 [ops_per_W];

		state machine behavior : ProcessorStates;

		state machine def ProcessorStates {
			entry idle;
			then processing;

			state idle {
				entry { active = false; }
			}

			state processing {
				entry { active = true; }
				do processAction;
			}

			transition t1 idle -> processing
				when control.command == "activate";
			transition t2 processing -> idle
				when control.command == "deactivate";
		}

		action def processAction {
			in item packet : DataPacket;
			out item processed : DataPacket;
		}

		action processAction : processAction {
			// Compute derived metrics
		}
	}

	// ---------- First-Generation Processor ----------

	part def FirstGenProcessor :> ProcessorBase {
		attribute generation = 1;
		attribute maxSpeed = 1000 [ops_per_s];
		attribute powerDraw = 10 [watt];
		attribute parallelChannels = 1;

		action override processAction {
			// Baseline sequential processing
			currentThroughput = 50 [Mb_per_s];
			currentLatency = 20 [ms];
			currentEfficiency = maxSpeed / powerDraw;
		}
	}

	// ---------- Second-Generation Processor ----------

	part def SecondGenProcessor :> ProcessorBase {
		attribute generation = 2;
		attribute maxSpeed = 4000 [ops_per_s];
		attribute powerDraw = 15 [watt];
		attribute parallelChannels = 4;

		action override processAction {
			// Parallel channel processing
			currentThroughput = 200 [Mb_per_s];
			currentLatency = 8 [ms];
			currentEfficiency = maxSpeed / powerDraw;
		}
	}

	// ---------- Third-Generation Processor ----------

	part def ThirdGenProcessor :> ProcessorBase {
		attribute generation = 3;
		attribute maxSpeed = 16000 [ops_per_s];
		attribute powerDraw = 20 [watt];
		attribute parallelChannels = 16;
		attribute adaptiveOptimization : Boolean = true;

		attribute optimizationFactor : Real = 1.0;

		action override processAction {
			// Adaptive optimization: adjust factor based on load
			if (adaptiveOptimization) {
				optimizationFactor = 1.2;
			}
			currentThroughput = 800 [Mb_per_s] * optimizationFactor;
			currentLatency = 2 [ms];
			currentEfficiency = (maxSpeed * optimizationFactor) / powerDraw;
		}
	}

	// ---------- Performance Analyzer ----------

	part def PerformanceAnalyzer {
		attribute throughputThreshold : Throughput = 150 [Mb_per_s];
		attribute latencyThreshold : Latency = 15 [ms];
		attribute efficiencyThreshold : Efficiency = 150 [ops_per_W];

		attribute measuredThroughput : Throughput = 0 [Mb_per_s];
		attribute measuredLatency : Latency = 0 [ms];
		attribute measuredEfficiency : Efficiency = 0 [ops_per_W];

		attribute currentGeneration : Integer = 1;
		attribute evolutionNeeded : Boolean = false;

		port metricsIn : MetricPort;
		port analysisOut : EvolutionCommandPort;

		state machine behavior : AnalyzerStates;

		state machine def AnalyzerStates {
			entry monitoring;
			state monitoring {
				do analyzeMetrics;
			}
			transition t1 monitoring -> monitoring
				when metricsIn.efficiency < efficiencyThreshold
				{ evolutionNeeded = true; currentGeneration = currentGeneration + 1; analysisOut.targetGeneration = currentGeneration; analysisOut.activate = true; }
			transition t2 monitoring -> monitoring
				when metricsIn.latency > latencyThreshold
				{ evolutionNeeded = true; currentGeneration = currentGeneration + 1; analysisOut.targetGeneration = currentGeneration; analysisOut.activate = true; }
			transition t3 monitoring -> monitoring
				when metricsIn.throughput < throughputThreshold
				{ evolutionNeeded = true; currentGeneration = currentGeneration + 1; analysisOut.targetGeneration = currentGeneration; analysisOut.activate = true; }
		}

		action def analyzeMetrics {
			in attribute thr : Throughput;
			in attribute lat : Latency;
			in attribute eff : Efficiency;
		}

		action analyzeMetrics : analyzeMetrics {
			measuredThroughput = metricsIn.throughput;
			measuredLatency = metricsIn.latency;
			measuredEfficiency = metricsIn.efficiency;
		}
	}

	// ---------- Evolution Controller ----------

	part def EvolutionController {
		attribute activeGeneration : Integer = 1;
		attribute maxGeneration : Integer = 3;
		attribute transitioning : Boolean = false;

		port commandIn : EvolutionCommandPort;
		port gen1Control : ControlPort;
		port gen2Control : ControlPort;
		port gen3Control : ControlPort;

		state machine behavior : ControllerStates;

		state machine def ControllerStates {
			entry standby;
			then evaluating;

			state standby {
				entry { transitioning = false; }
			}

			state evaluating {
				do evaluateCommand;
			}

			state transitioningGen {
				entry { transitioning = true; }
				do performTransition;
			}

			transition t1 standby -> evaluating
				when commandIn.activate == true;

			transition t2 evaluating -> transitioningGen
				when commandIn.targetGeneration > activeGeneration
				& activeGeneration < maxGeneration;

			transition t3 transitioningGen -> standby
				when activeGeneration == commandIn.targetGeneration;
		}

		action def evaluateCommand {
			in attribute target : Integer;
		}

		action evaluateCommand : evaluateCommand {
			// Determine next generation
		}

		action def performTransition {
			in attribute fromGen : Integer;
			in attribute toGen : Integer;
		}

		action performTransition : performTransition {
			if (activeGeneration == 1) { gen1Control.command = "deactivate"; }
			if (activeGeneration == 2) { gen2Control.command = "deactivate"; }
			if (activeGeneration == 3) { gen3Control.command = "deactivate"; }

			if (commandIn.targetGeneration == 2) { gen2Control.command = "activate"; }
			if (commandIn.targetGeneration == 3) { gen3Control.command = "activate"; }

			activeGeneration = commandIn.targetGeneration;
		}
	}

	// ---------- Platform ----------

	part def DataPlatform {
		port inputStream : DataInputPort;
		port outputStream : DataOutputPort;

		part gen1 : FirstGenProcessor {
			attribute generation = 1;
		}
		part gen2 : SecondGenProcessor {
			attribute generation = 2;
		}
		part gen3 : ThirdGenProcessor {
			attribute generation = 3;
		}

		part analyzer : PerformanceAnalyzer;
		part controller : EvolutionController;

		// Active processor metric multiplexer (simplified: gen1 feeds analyzer initially)
		connection gen1.dataOut to outputStream;
		connection gen2.dataOut to outputStream;
		connection gen3.dataOut to outputStream;

		connection gen1.dataOut to inputStream;
		connection gen2.dataOut to inputStream;
		connection gen3.dataOut to inputStream;

		// Metric feedback from active processor to analyzer
		connection gen1.metricsFeedback to analyzer.metricsIn;
		connection gen2.metricsFeedback to analyzer.metricsIn;
		connection gen3.metricsFeedback to analyzer.metricsIn;

		// Analyzer to controller
		connection analyzer.analysisOut to controller.commandIn;

		// Controller to processors
		connection controller.gen1Control to gen1.control;
		connection controller.gen2Control to gen2.control;
		connection controller.gen3Control to gen3.control;

		// Initial activation
		state machine behavior : PlatformLifecycle;

		state machine def PlatformLifecycle {
			entry initialization;
			then operational;
			then shutdown;

			state initialization {
				entry { gen1.control.command = "activate"; controller.activeGeneration = 1; }
			}

			state operational {
				// Platform runs autonomously; processors and controller manage evolution
			}

			state shutdown {
				entry {
					gen1.control.command = "deactivate";
					gen2.control.command = "deactivate";
					gen3.control.command = "deactivate";
				}
			}
		}
	}

	// Add metric output port to processors (extension)
	port def MetricOutputPort {
		out attribute throughput : Throughput;
		out attribute latency : Latency;
		out attribute efficiency : Efficiency;
	}

	// ---------- Requirements ----------

	requirement def ProcessingRequirement {
		subject : DataPlatform;
		objective {
			doc "The platform shall process continuous streams of data.";
		}
	}

	requirement def GenerationUpgradeRequirement {
		subject : DataPlatform;
		objective {
			doc "The platform shall autonomously transition from first-generation to second-generation and third-generation processors when efficiency thresholds are not met.";
		}
	}

	requirement def PerformanceMonitoringRequirement {
		subject : PerformanceAnalyzer;
		objective {
			doc "The analyzer shall continuously monitor throughput, latency, and efficiency against predefined thresholds.";
		}
	}

	requirement def SeamlessTransitionRequirement {
		subject : EvolutionController;
		objective {
			doc "The controller shall deactivate the older processor and bring the next-generation processor online without manual intervention.";
		}
	}

	requirement def FirstGenCapabilityRequirement {
		subject : FirstGenProcessor;
		objective {
			doc "The first-generation processor shall provide baseline sequential processing with a defined speed and power draw.";
		}
	}

	requirement def SecondGenCapabilityRequirement {
		subject : SecondGenProcessor;
		objective {
			doc "The second-generation processor shall provide parallel processing channels and improved energy efficiency.";
		}
	}

	requirement def ThirdGenCapabilityRequirement {
		subject : ThirdGenProcessor;
		objective {
			doc "The third-generation processor shall provide a high number of parallel channels and adaptive optimization for maximum performance and minimal power consumption.";
		}
	}

	requirement platformReq : ProcessingRequirement {
		subject = DataPlatform;
	}

	requirement upgradeReq : GenerationUpgradeRequirement {
		subject = DataPlatform;
	}

	requirement monitoringReq : PerformanceMonitoringRequirement {
		subject = PerformanceAnalyzer;
	}

	requirement transitionReq : SeamlessTransitionRequirement {
		subject = EvolutionController;
	}

	requirement gen1Req : FirstGenCapabilityRequirement {
		subject = FirstGenProcessor;
	}

	requirement gen2Req : SecondGenCapabilityRequirement {
		subject = SecondGenProcessor;
	}

	requirement gen3Req : ThirdGenCapabilityRequirement {
		subject = ThirdGenProcessor;
	}

}
