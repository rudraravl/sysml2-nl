package 'CEUS System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	
	attribute def MechanicalIndex :> Real;
	attribute def FrameRate :> Real;
	attribute def Concentration :> Real;
	
	attribute def StartCommand;
	attribute def InjectionComplete;
	attribute def EchoReceived;
	attribute def ImageReady;
	attribute def CycleComplete;
	
	item def OperatorCommand;
	item def MicrobubbleContrastAgent {
		attribute volume : VolumeValue;
		attribute size : LengthValue;
		attribute shellType : String;
		attribute concentration : Concentration;
	}
	item def UltrasoundPulse {
		attribute frequency : FrequencyValue;
		attribute power : PowerValue;
		attribute mechanicalIndex : MechanicalIndex;
	}
	item def EchoSignal;
	item def ProcessedSignal;
	item def ImageFrame {
		attribute frameRate : FrameRate;
		attribute resolution : LengthValue;
	}
	
	action def InjectContrast {
		in cmd : OperatorCommand;
		out agent : MicrobubbleContrastAgent;
	}
	action def TransmitPulse {
		out pulse : UltrasoundPulse;
	}
	action def ReceiveEcho {
		in pulse : UltrasoundPulse;
		out echo : EchoSignal;
	}
	action def ProcessSignal {
		in echo : EchoSignal;
		out processed : ProcessedSignal;
	}
	action def ReconstructImage {
		in processed : ProcessedSignal;
		out img : ImageFrame;
	}
	action def PerformCEUSImaging {
		in cmd : OperatorCommand;
		out img : ImageFrame;
	}
	
	part def ContrastInjector {
		port cmdPort { in cmd : OperatorCommand; }
		port agentPort { out agent : MicrobubbleContrastAgent; }
	}
	part def UltrasoundTransducer {
		attribute mechanicalIndex : MechanicalIndex;
		port pulsePort { out pulse : UltrasoundPulse; }
		port echoPort { in echo : EchoSignal; }
		port signalPort { out signal : EchoSignal; }
	}
	part def Patient {
		port agentPort { in agent : MicrobubbleContrastAgent; }
		port pulsePort { in pulse : UltrasoundPulse; }
		port echoPort { out echo : EchoSignal; }
	}
	part def SignalProcessor {
		port echoPort { in echo : EchoSignal; }
		port processedPort { out processed : ProcessedSignal; }
	}
	part def ImageReconstructor {
		attribute resolution : LengthValue;
		attribute frameRate : FrameRate;
		port processedPort { in processed : ProcessedSignal; }
		port imgPort { out img : ImageFrame; }
	}
	
	state def CEUSControl {
		initial state Idle;
		state Injecting;
		state Scanning;
		state Processing;
		state Displaying;
		
		transition from Idle to Injecting {
			accept StartCommand;
		}
		transition from Injecting to Scanning {
			accept InjectionComplete;
		}
		transition from Scanning to Processing {
			accept EchoReceived;
		}
		transition from Processing to Displaying {
			accept ImageReady;
		}
		transition from Displaying to Idle {
			accept CycleComplete;
		}
	}
	
	requirement def SafetyRequirement {
		subject system : CEUS_System;
		require constraint {
			system.transducer.mechanicalIndex < 0.5
		}
	}
	
	requirement def PerformanceRequirement {
		subject system : CEUS_System;
		require constraint {
			system.reconstructor.resolution < 0.5 [mm] &
			system.reconstructor.frameRate >= 20 [Hz]
		}
	}
	
	part def CEUS_System {
		port cmdPort { in cmd : OperatorCommand; }
		port imgPort { out img : ImageFrame; }
		
		part injector : ContrastInjector;
		part transducer : UltrasoundTransducer;
		part patient : Patient;
		part processor : SignalProcessor;
		part reconstructor : ImageReconstructor;
		
		bind cmdPort = injector.cmdPort;
		bind imgPort = reconstructor.imgPort;
		
		flow agentFlow of MicrobubbleContrastAgent 
			from injector.agentPort.agent to patient.agentPort.agent;
		flow pulseFlow of UltrasoundPulse 
			from transducer.pulsePort.pulse to patient.pulsePort.pulse;
		flow echoFlow of EchoSignal 
			from patient.echoPort.echo to transducer.echoPort.echo;
		flow echoToProcessorFlow of EchoSignal 
			from transducer.signalPort.signal to processor.echoPort.echo;
		flow processedFlow of ProcessedSignal 
			from processor.processedPort.processed to reconstructor.processedPort.processed;
	}
	
	action 'perform CEUS imaging' : PerformCEUSImaging {
		in cmd : OperatorCommand;
		out img : ImageFrame;
		
		action 'inject contrast' : InjectContrast {
			in cmd = 'perform CEUS imaging'::cmd;
		}
		action 'transmit pulse' : TransmitPulse;
		action 'receive echo' : ReceiveEcho;
		action 'process signal' : ProcessSignal;
		action 'reconstruct image' : ReconstructImage {
			out img = 'perform CEUS imaging'::img;
		}
		
		flow 'transmit pulse'.pulse to 'receive echo'.pulse;
		flow 'receive echo'.echo to 'process signal'.echo;
		flow 'process signal'.processed to 'reconstruct image'.processed;
		
		first start;
		then 'inject contrast';
		then 'transmit pulse';
		then 'receive echo';
		then 'process signal';
		then 'reconstruct image';
		then done;
	}
	
	part ceus_system : CEUS_System {
		perform 'perform CEUS imaging' {
			in cmd = cmdPort.cmd;
			out img = imgPort.img;
		}
		exhibit ceusControl : CEUSControl;
	}
	
	requirement safety_req : SafetyRequirement {
		subject system = ceus_system;
	}
	
	requirement performance_req : PerformanceRequirement {
		subject system = ceus_system;
	}
}
