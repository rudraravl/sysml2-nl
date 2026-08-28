package 'Self-Evolving Data Platform' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		private import ScalarValues::*;
		private import ISQ::*;

		item def DataStream;
		item def ProcessedData;

		attribute def DataThroughput :> Real;
		attribute def Latency :> Real;
		attribute def Efficiency :> Real;
		attribute def PowerDraw :> Real;

		attribute def EvolutionCommand;
		attribute def DeactivateCommand;
		attribute def ActivateCommand;

		item def PerformanceMetrics {
			attribute throughput : DataThroughput;
			attribute latency : Latency;
			attribute efficiency : Efficiency;
		}

		abstract part def Processor {
			attribute speed : DataThroughput;
			attribute power : PowerDraw;
			attribute channels : Integer;
			port dataInPort { in data : DataStream; }
			port dataOutPort { out data : ProcessedData; out metrics : PerformanceMetrics; }
			port controlPort { in activate : ActivateCommand; in deactivate : DeactivateCommand; }
			perform action processData : ProcessData;
			exhibit state processorStates : ProcessorStates;
		}

		state def ProcessorStates {
			entry; then inactive;
			state inactive;
			transition 'inactive-to-active'
				first inactive
				accept ActivateCommand
				then active;
			state active;
			transition 'active-to-inactive'
				first active
				accept DeactivateCommand
				then inactive;
		}

		part def FirstGenProcessor :> Processor {
			attribute speed = 100.0;
			attribute power = 50.0;
			attribute channels = 1;
		}

		part def SecondGenProcessor :> Processor {
			attribute speed = 500.0;
			attribute power = 40.0;
			attribute channels = 4;
		}

		part def ThirdGenProcessor :> Processor {
			attribute speed = 2000.0;
			attribute power = 35.0;
			attribute channels = 16;
			attribute adaptiveOptimization = true;
		}

		action def ProcessData {
			in data : DataStream;
			out processed : ProcessedData;
			out metrics : PerformanceMetrics;
		}

		part def PerformanceAnalyzer {
			port metricsInPort { in metrics : PerformanceMetrics; }
			port commandOutPort { out command : EvolutionCommand; }
			attribute efficiencyThreshold : Efficiency = 80.0;
			perform action monitorPerformance : MonitorPerformance;
		}

		action def MonitorPerformance {
			in metrics : PerformanceMetrics;
			in threshold : Efficiency;
			out command : EvolutionCommand;
		}

		part def EvolutionController {
			port commandInPort { in command : EvolutionCommand; }
			port gen1ControlPort { out deactivate : DeactivateCommand; out activate : ActivateCommand; }
			port gen2ControlPort { out deactivate : DeactivateCommand; out activate : ActivateCommand; }
			port gen3ControlPort { out deactivate : DeactivateCommand; out activate : ActivateCommand; }

			exhibit state controllerStates : ControllerStates;
		}

		state def ControllerStates {
			entry; then gen1Active;
			state gen1Active;
			transition 'gen1-to-gen2'
				first gen1Active
				accept EvolutionCommand
				then gen2Active;
			state gen2Active;
			transition 'gen2-to-gen3'
				first gen2Active
				accept EvolutionCommand
				then gen3Active;
			state gen3Active;
		}

		part def DataProcessingPlatform {
			port dataInPort { in data : DataStream; }
			port dataOutPort { out data : ProcessedData; }

			part gen1 : FirstGenProcessor;
			part gen2 : SecondGenProcessor;
			part gen3 : ThirdGenProcessor;
			part analyzer : PerformanceAnalyzer;
			part controller : EvolutionController;

			flow dataFlowIn of DataStream from dataInPort.data to gen1.dataInPort.data;
			flow dataFlowGen1ToGen2 of DataStream from gen1.dataOutPort.data to gen2.dataInPort.data;
			flow dataFlowGen2ToGen3 of DataStream from gen2.dataOutPort.data to gen3.dataInPort.data;
			flow dataFlowOut of ProcessedData from gen3.dataOutPort.data to dataOutPort.data;

			flow metricsFlow of PerformanceMetrics from gen1.dataOutPort.metrics to analyzer.metricsInPort.metrics;

			flow commandFlow of EvolutionCommand from analyzer.commandOutPort.command to controller.commandInPort.command;

			connect controller.gen1ControlPort to gen1.controlPort;
			connect controller.gen2ControlPort to gen2.controlPort;
			connect controller.gen3ControlPort to gen3.controlPort;
		}

		requirement def AutonomousEvolutionRequirement {
			doc
			/*
			 * The platform shall autonomously upgrade its processor generation
			 * when the current efficiency falls below the predefined threshold.
			 */
		}
	}

	package Usages {
		private import Definitions::*;

		part platform : DataProcessingPlatform;

		requirement autonomousEvolution : AutonomousEvolutionRequirement {
			subject platformSubject : DataProcessingPlatform;
		}

		satisfy autonomousEvolution by platform;
	}
}
