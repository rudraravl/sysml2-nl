package 'Amorphous Metal Transformer' {
	private import ScalarValues::*;
	private import ISQ::*;
	public import Definitions::*;

	package Definitions {
		item def ElectricalPower {
			attribute voltage : ISQ::ElectricPotentialValue;
			attribute current : ISQ::ElectricCurrentValue;
		}
		item def ThermalEnergy {
			attribute temperature : ISQ::TemperatureValue;
		}

		port def HVInputPort {
			in power : ElectricalPower;
		}
		port def LVOutputPort {
			out power : ElectricalPower;
		}
		port def MagneticPort {
			inout flux : ISQ::MagneticFluxValue;
		}
		port def ThermalPort {
			out heat : ThermalEnergy;
		}
		port def ProtectionMonitorPort {
			in outputVoltage : ISQ::ElectricPotentialValue;
			in outputCurrent : ISQ::ElectricCurrentValue;
			out trip : Boolean;
		}

		interface def MagneticCoupling {
			end windingEnd : MagneticPort;
			end coreEnd : MagneticPort;
		}
		interface def ThermalLink {
			end sourcePort : ThermalPort;
			end sinkPort : ThermalPort;
		}
		interface def ProtectionLink {
			end outputEnd : LVOutputPort;
			end monitorEnd : ProtectionMonitorPort;
		}

		part def AmorphousMetalCore {
			attribute coreTemp : ISQ::TemperatureValue;
			attribute maxCoreTemp : ISQ::TemperatureValue;
			port magneticPrimary : MagneticPort;
			port magneticSecondary : MagneticPort;
			port thermalOut : ThermalPort;
		}
		part def PrimaryWinding {
			port hvIn : HVInputPort;
			port magneticOut : MagneticPort;
		}
		part def SecondaryWinding {
			port lvOut : LVOutputPort;
			port magneticIn : MagneticPort;
		}
		part def CoolingSystem {
			port thermalIn : ThermalPort;
			perform action 'dissipate heat' : 'Dissipate Heat';
		}
		part def ProtectionCircuit {
			port monitor : ProtectionMonitorPort;
			attribute tripActive : Boolean;
			perform action 'monitor output' : 'Monitor Output';
			perform action 'trip breaker' : 'Trip Breaker';
		}
		part def AmorphousMetalTransformer {
			attribute maxCoreTemp : ISQ::TemperatureValue;
			attribute minEfficiency : ScalarValues::Real = 0.98;
			part primary : PrimaryWinding;
			part secondary : SecondaryWinding;
			part core : AmorphousMetalCore;
			part coolingSystem : CoolingSystem;
			part protectionCircuit : ProtectionCircuit;

			interface : MagneticCoupling connect
				windingEnd ::> primary.magneticOut to
				coreEnd ::> core.magneticPrimary;
			interface : MagneticCoupling connect
				windingEnd ::> secondary.magneticIn to
				coreEnd ::> core.magneticSecondary;
			interface : ThermalLink connect
				sourcePort ::> core.thermalOut to
				sinkPort ::> coolingSystem.thermalIn;
			interface : ProtectionLink connect
				outputEnd ::> secondary.lvOut to
				monitorEnd ::> protectionCircuit.monitor;

			perform action 'transform power' : 'Transform Power';
			exhibit state 'transformer states' : 'Transformer States';
		}

		action def 'Build Magnetic Field';
		action def 'Transform Power';
		action def 'Dissipate Heat' { out heatRemoved : ISQ::PowerValue; }
		action def 'Monitor Output' { out isOverload : Boolean; out isOvervoltage : Boolean; }
		action def 'Trip Breaker' { out tripSignal : Boolean; }
		action def 'Shutdown Safely';

		state def 'Transformer States';

		attribute def 'Energize Signal';
		attribute def 'Stable Field';
		attribute def 'Load Reduced';
		attribute def 'Issue Resolved';
		attribute def 'Trip Signal';

		requirement def 'High Efficiency Requirement' {
			subject transformer : AmorphousMetalTransformer;
			attribute minEfficiency : ScalarValues::Real = 0.98;
			doc /* The transformer shall operate with an efficiency of at least 98 percent due to the low-loss amorphous metal core. */
			constraint { transformer.minEfficiency >= 0.98 }
		}
		requirement def 'Low Core Loss Requirement' {
			subject core : AmorphousMetalCore;
			doc /* The amorphous metal core shall exhibit significantly lower core losses than traditional silicon steel cores. */
		}
		requirement def 'Thermal Safety Requirement' {
			subject transformer : AmorphousMetalTransformer;
			attribute maxCoreTemp : ISQ::TemperatureValue;
			doc /* The cooling system shall maintain core temperature below the degradation threshold. */
			constraint { transformer.core.coreTemp < transformer.maxCoreTemp }
		}
		requirement def 'Overload Protection Requirement' {
			subject transformer : AmorphousMetalTransformer;
			doc /* The protection circuit shall detect overload and overvoltage conditions and trip the transformer offline. */
		}
	}

	package Usages {
		private import Definitions::*;

		action 'build magnetic field' : 'Build Magnetic Field';
		action 'transform power' : 'Transform Power';
		action 'dissipate heat' : 'Dissipate Heat';
		action 'monitor output' : 'Monitor Output';
		action 'trip breaker' : 'Trip Breaker';
		action 'shutdown safely' : 'Shutdown Safely';

		part transformer : AmorphousMetalTransformer;

		state 'transformer states' : 'Transformer States' {
			entry; then offline;

			state offline;
			accept 'Energize Signal'
				then startup;

			state startup {
				entry 'build magnetic field';
			}
			accept 'Stable Field'
				then 'normal operation';

			state 'normal operation' {
				entry 'transform power';
				do 'monitor output';
			}
			accept when 'monitor output'.isOverload
				then overload;
			accept when 'monitor output'.isOvervoltage
				do send new 'Trip Signal'() to transformer.protectionCircuit
				then fault;
			accept when transformer.core.coreTemp > transformer.maxCoreTemp
				do send new 'Trip Signal'() to transformer.protectionCircuit
				then fault;

			state overload {
				do 'monitor output';
			}
			accept 'Load Reduced'
				then 'normal operation';
			accept when 'monitor output'.isOvervoltage
				do send new 'Trip Signal'() to transformer.protectionCircuit
				then fault;
			accept when transformer.core.coreTemp > transformer.maxCoreTemp
				do send new 'Trip Signal'() to transformer.protectionCircuit
				then fault;

			state fault {
				entry 'trip breaker';
				do 'shutdown safely';
			}
			accept 'Issue Resolved'
				then offline;
		}

		requirement highEfficiencyReq : 'High Efficiency Requirement';
		requirement lowCoreLossReq : 'Low Core Loss Requirement';
		requirement thermalSafetyReq : 'Thermal Safety Requirement';
		requirement overloadProtectionReq : 'Overload Protection Requirement';
	}
}
