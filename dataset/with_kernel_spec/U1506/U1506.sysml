package 'Precision Static Pressure Control System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	item def Air;
	item def PressurizedAir :> Air;
	
	attribute def StartCommand;
	attribute def ShutdownCommand;
	attribute def ResetCommand;
	attribute def OverPressureAlert;
	attribute def ValveCommand;
	attribute def PressureSignal;
	
	part def PressureRegulator {
		port airInPort { in airIn : Air; }
		port airOutPort { out airOut : PressurizedAir; }
	}
	
	part def PressureVessel {
		port airInPort { in airIn : PressurizedAir; }
		port airOutPort { out airOut : PressurizedAir; }
		port ventPort { out ventAir : PressurizedAir; }
		attribute targetPressure : PressureValue = 100 [kPa];
		attribute maxPressure : PressureValue = 150 [kPa];
		attribute currentPressure : PressureValue;
	}
	
	part def StaticPressureProbe {
		port pressurePort { out pressure : PressureValue; }
	}
	
	part def PressureTransmitter {
		port pressureInPort { in pressure : PressureValue; }
		port signalOutPort { out signal : PressureSignal; }
	}
	
	part def ControlValve {
		port airInPort { in airIn : PressurizedAir; }
		port airOutPort { out airOut : PressurizedAir; }
		port commandPort { in command : ValveCommand; }
	}
	
	part def EmergencyVent {
		port commandPort { in command : ValveCommand; }
		port ventInPort { in ventAir : PressurizedAir; }
		port ventOutPort { out ventedAir : PressurizedAir; }
	}
	
	part def PressureController {
		port signalInPort { in signal : PressureSignal; }
		port commandOutPort { out command : ValveCommand; }
		port startPort { in startCmd : StartCommand; }
		port shutdownPort { in shutdownCmd : ShutdownCommand; }
		port resetPort { in resetCmd : ResetCommand; }
		port alertPort { out alert : OverPressureAlert; }
	}
	
	action def MeasurePressure { out pressure : PressureValue; }
	action def ComparePressure { in measured : PressureValue; in target : PressureValue; out command : ValveCommand; }
	action def VentPressure;
	
	state def SystemStates;
	
	part def StaticPressureControlSystem {
		port airSupplyPort { in airSupply : Air; }
		port systemStartPort { in startCmd : StartCommand; }
		port systemShutdownPort { in shutdownCmd : ShutdownCommand; }
		port systemResetPort { in resetCmd : ResetCommand; }
		port systemVentPort { out ventedAir : PressurizedAir; }
		
		part regulator : PressureRegulator;
		part vessel : PressureVessel;
		part probe1 : StaticPressureProbe;
		part probe2 : StaticPressureProbe;
		part transmitter : PressureTransmitter;
		part controller : PressureController;
		part valve : ControlValve;
		part vent : EmergencyVent;
		
		flow airFlow1 of Air from airSupplyPort.airSupply to regulator.airInPort.airIn;
		flow airFlow2 of PressurizedAir from regulator.airOutPort.airOut to vessel.airInPort.airIn;
		flow airFlow3 of PressurizedAir from vessel.airOutPort.airOut to valve.airInPort.airIn;
		flow pressureFlow1 of PressureValue from probe1.pressurePort.pressure to transmitter.pressureInPort.pressure;
		flow pressureFlow2 of PressureValue from probe2.pressurePort.pressure to transmitter.pressureInPort.pressure;
		flow signalFlow of PressureSignal from transmitter.signalOutPort.signal to controller.signalInPort.signal;
		flow commandFlow of ValveCommand from controller.commandOutPort.command to valve.commandPort.command;
		flow ventCommandFlow of ValveCommand from controller.commandOutPort.command to vent.commandPort.command;
		flow ventAirFlow of PressurizedAir from vessel.ventPort.ventAir to vent.ventInPort.ventAir;
		flow ventedAirFlow of PressurizedAir from vent.ventOutPort.ventedAir to systemVentPort.ventedAir;
		
		bind systemStartPort = controller.startPort;
		bind systemShutdownPort = controller.shutdownPort;
		bind systemResetPort = controller.resetPort;
		
		action sensePressure : MeasurePressure;
		action comparePressure : ComparePressure;
		action ventPressure : VentPressure;
		
		exhibit state systemStates : SystemStates {
			entry; then standby;
			state standby;
			accept StartCommand
				then startup;
			state startup {
				do sensePressure;
			}
			accept when vessel.currentPressure >= vessel.targetPressure
				then operating;
			state operating {
				do sensePressure;
				do comparePressure;
			}
			accept when vessel.currentPressure > vessel.maxPressure
				do send new OverPressureAlert() to controller
				then alarm;
			state alarm {
				do ventPressure;
			}
			accept ResetCommand
				then standby;
			accept ShutdownCommand
				then shutdown;
			state shutdown {
				do ventPressure;
			}
			accept when vessel.currentPressure <= 0 [kPa]
				then standby;
		}
	}
	
	requirement def 'Maintain Pressure Stability' {
		doc /* The system shall maintain the vessel pressure within +/- 0.5 kPa of the setpoint during normal operation. */
	}
	requirement def 'Redundant Sensing' {
		doc /* The system shall utilize two independent static pressure probes for measurement accuracy and fault tolerance. */
	}
	requirement def 'Overpressure Safety' {
		doc /* The system shall automatically activate an emergency vent and transition to an alarm state if pressure exceeds the maximum safety limit. */
	}
	
	part system : StaticPressureControlSystem {
		satisfy 'maintain stability' : 'Maintain Pressure Stability';
		satisfy 'redundant sensing' : 'Redundant Sensing';
		satisfy 'overpressure safety' : 'Overpressure Safety';
	}
}
