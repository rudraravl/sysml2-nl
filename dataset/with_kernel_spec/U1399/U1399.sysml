package HalfWaveRectifier {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	
	package Definitions {
		attribute def Voltage :> Real {
			doc "Electric potential in Volts";
		}
		attribute def Current :> Real {
			doc "Electric current in Amperes";
		}
		attribute def Resistance :> Real {
			doc "Electrical resistance in Ohms";
		}
		
		item def ElectricalSignal {
			attribute voltage : Voltage;
			attribute current : Current;
		}
		
		port def ElectricalPort {
			out item signal : ElectricalSignal;
		}
		
		part def VoltageSource {
			attribute amplitude : Voltage;
			attribute frequency : Real;
			port outputPort : ElectricalPort;
			port returnPort : ~ElectricalPort;
		}
		
		state def DiodeStates {
			in sourceVoltage : Voltage;
			in threshold : Voltage = 0.7;
			in breakdown : Voltage = 50.0;
			
			state Off;
			state ForwardBiased;
			state ReverseBiased;
			state Breakdown;
			
			transition toForward {
				from Off;
				to ForwardBiased;
				guard { sourceVoltage > threshold }
			}
			transition toOffFromForward {
				from ForwardBiased;
				to Off;
				guard { sourceVoltage <= threshold }
			}
			transition toReverse {
				from Off;
				to ReverseBiased;
				guard { sourceVoltage < 0 }
			}
			transition toOffFromReverse {
				from ReverseBiased;
				to Off;
				guard { sourceVoltage >= 0 and sourceVoltage <= threshold }
			}
			transition toForwardFromReverse {
				from ReverseBiased;
				to ForwardBiased;
				guard { sourceVoltage > threshold }
			}
			transition toBreakdown {
				from ReverseBiased;
				to Breakdown;
				guard { sourceVoltage <= -breakdown }
			}
			transition toReverseFromBreakdown {
				from Breakdown;
				to ReverseBiased;
				guard { sourceVoltage > -breakdown }
			}
			transition toOffFromBreakdown {
				from Breakdown;
				to Off;
				guard { sourceVoltage >= 0 and sourceVoltage <= threshold }
			}
			transition toForwardFromBreakdown {
				from Breakdown;
				to ForwardBiased;
				guard { sourceVoltage > threshold }
			}
		}
		
		part def Diode {
			attribute forwardThreshold : Voltage = 0.7;
			attribute reverseBreakdown : Voltage = 50.0;
			attribute forwardResistance : Resistance = 0.01;
			attribute reverseResistance : Resistance = 1000000.0;
			
			port anode : ~ElectricalPort;
			port cathode : ElectricalPort;
			
			exhibit diodeBehavior : DiodeStates {
				in sourceVoltage = anode.signal.voltage;
				in threshold = forwardThreshold;
				in breakdown = reverseBreakdown;
			}
		}
		
		part def LoadResistor {
			attribute resistance : Resistance;
			port inputPort : ~ElectricalPort;
			port outputPort : ElectricalPort;
		}
		
		action def RectifyAC {
			in inputSignal : ElectricalSignal;
			out outputSignal : ElectricalSignal;
		}
		
		interface def Wire {
			end outPort : ElectricalPort;
			end inPort : ~ElectricalPort;
		}
		
		part def HalfWaveRectifier {
			part source : VoltageSource;
			part diode : Diode;
			part load : LoadResistor;
			
			interface : Wire connect 
				outPort ::> source.outputPort to 
				inPort ::> diode.anode;
				
			interface : Wire connect 
				outPort ::> diode.cathode to 
				inPort ::> load.inputPort;
				
			interface : Wire connect 
				outPort ::> load.outputPort to 
				inPort ::> source.returnPort;
				
			perform rectify : RectifyAC {
				in inputSignal = source.outputPort.signal;
				out outputSignal = load.inputPort.signal;
			}
		}
		
		requirement def RectificationRequirement {
			subject rectifier : HalfWaveRectifier;
			objective {
				doc "The system shall convert an AC input voltage to a pulsating DC output voltage across the load.";
				constraint { rectifier.load.inputPort.signal.voltage >= 0 }
			}
		}
	}
	
	package Usages {
		part myRectifier : HalfWaveRectifier;
		
		requirement rectification : RectificationRequirement {
			subject rectifier = myRectifier;
		}
	}
}
