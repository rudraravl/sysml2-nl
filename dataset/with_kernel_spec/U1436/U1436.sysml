package 'TurbofanEngineSystem' {
	public import Definitions::*;
	public import Usages::*;
	
	package Definitions {
		private import ISQ::*;
		private import ScalarValues::*;
		alias Torque for ISQ::TorqueValue;
		alias Force for ISQ::ForceValue;
		
		item def Air;
		item def CompressedAir;
		item def Fuel;
		item def ExhaustGas;
		
		attribute def StartCmd;
		attribute def ShutdownCmd;
		attribute def ThrottleCmd;
		
		action def 'Intake Air' { out air: Air; }
		action def 'Compress Air' { in air: Air; out compressedAir: CompressedAir; in rotationalPower: Torque; }
		action def 'Combust Fuel' { in compressedAir: CompressedAir; in fuel: Fuel; out exhaustGas: ExhaustGas; }
		action def 'Expand Gas' { in exhaustGas: ExhaustGas; out expandedGas: ExhaustGas; out rotationalPower: Torque; }
		action def 'Exhaust Gas' { in expandedGas: ExhaustGas; out thrust: Force; }
		action def 'Generate Thrust' { in fuel: Fuel; out thrust: Force; }
		
		state def EngineStates;
		
		requirement def ThrustRequirement {
			doc /* The engine must produce over 100,000 N of thrust. */
			subject engine;
			require engine.thrust > 100000;
		}
		
		requirement def EfficiencyRequirement {
			doc /* The engine must maintain high fuel efficiency. */
			subject engine;
			require engine.efficiency > 0.3;
		}
	}
	
	package Usages {
		part def TurbofanEngine {
			port fuelPort { in fuel: Fuel; }
			port controlPort { in startCmd: StartCmd; in shutdownCmd: ShutdownCmd; in throttleCmd: ThrottleCmd; }
			out thrust: Force;
			attribute efficiency: Real = 0.35;
			
			action 'generate thrust' : 'Generate Thrust' {
				in fuel = fuelPort.fuel;
				out thrust: Force;
				action 'intake air' : 'Intake Air';
				flow 'intake air'.air to 'compress air'.air;
				action 'compress air' : 'Compress Air';
				flow 'compress air'.compressedAir to 'combust fuel'.compressedAir;
				action 'combust fuel' : 'Combust Fuel';
				flow 'combust fuel'.exhaustGas to 'expand gas'.exhaustGas;
				action 'expand gas' : 'Expand Gas';
				flow 'expand gas'.expandedGas to 'exhaust gas'.expandedGas;
				action 'exhaust gas' : 'Exhaust Gas';
				bind thrust = 'exhaust gas'.thrust;
			}
			
			part airIntake {
				out air: Air;
				perform 'generate thrust'.'intake air' {
					out air = self.air;
				}
			}
			part compressor {
				in air: Air;
				out compressedAir: CompressedAir;
				in rotationalPower: Torque;
				perform 'generate thrust'.'compress air' {
					in air = self.air;
					out compressedAir = self.compressedAir;
					in rotationalPower = self.rotationalPower;
				}
			}
			part combustionChamber {
				in compressedAir: CompressedAir;
				in fuel: Fuel;
				out exhaustGas: ExhaustGas;
				perform 'generate thrust'.'combust fuel' {
					in compressedAir = self.compressedAir;
					in fuel = self.fuel;
					out exhaustGas = self.exhaustGas;
				}
			}
			part turbine {
				in exhaustGas: ExhaustGas;
				out expandedGas: ExhaustGas;
				out rotationalPower: Torque;
				perform 'generate thrust'.'expand gas' {
					in exhaustGas = self.exhaustGas;
					out expandedGas = self.expandedGas;
					out rotationalPower = self.rotationalPower;
				}
			}
			part shaft {
				in rotationalPowerIn: Torque;
				out rotationalPowerOut: Torque;
				bind rotationalPowerOut = rotationalPowerIn;
			}
			part exhaustNozzle {
				in expandedGas: ExhaustGas;
				out thrust: Force;
				perform 'generate thrust'.'exhaust gas' {
					in expandedGas = self.expandedGas;
					out thrust = self.thrust;
				}
			}
			part controlSystem {
				in startCmd: StartCmd;
				in shutdownCmd: ShutdownCmd;
				in throttleCmd: ThrottleCmd;
			}
			
			bind airIntake.air = compressor.air;
			bind compressor.compressedAir = combustionChamber.compressedAir;
			bind combustionChamber.exhaustGas = turbine.exhaustGas;
			bind turbine.expandedGas = exhaustNozzle.expandedGas;
			bind exhaustNozzle.thrust = self.thrust;
			bind turbine.rotationalPower = shaft.rotationalPowerIn;
			bind shaft.rotationalPowerOut = compressor.rotationalPower;
			bind combustionChamber.fuel = fuelPort.fuel;
			bind controlSystem.startCmd = controlPort.startCmd;
			bind controlSystem.shutdownCmd = controlPort.shutdownCmd;
			bind controlSystem.throttleCmd = controlPort.throttleCmd;
			
			state 'engine states' : EngineStates {
				entry; then off;
				state off;
				accept startCmd: StartCmd then starting;
				state starting {
					entry; then spooling;
					state spooling;
					accept throttleCmd: ThrottleCmd then running;
				}
				state running;
				accept shutdownCmd: ShutdownCmd then shutdown;
				state shutdown;
				then off;
			}
		}
		
		part engine : TurbofanEngine {
			requirement thrustReq : ThrustRequirement {
				subject engine = self;
			}
			requirement effReq : EfficiencyRequirement {
				subject engine = self;
			}
			satisfy thrustReq by self;
			satisfy effReq by self;
		}
	}
}
