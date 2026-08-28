package 'Internal_Combustion_Engine_System' {
	private import ISQ::*;
	private import ScalarValues::*;
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		alias Torque for ISQ::TorqueValue;
		alias Volume for ISQ::VolumeValue;
		alias ThermodynamicTemperature for ISQ::ThermodynamicTemperatureValue;
		alias AngularVelocity for ISQ::AngularVelocityValue;
		alias Force for ISQ::ForceValue;

		attribute def EngineStartSignal;
		attribute def EngineStopSignal;
		attribute def ThrottleCommand;
		attribute def SparkSignal;
		attribute def EngineRunningSignal;
		attribute def EngineStoppedSignal;
		attribute def AccelerateSignal;
		attribute def CruiseSignal;
		attribute def DecelerateSignal;
		attribute def IdleSignal;

		item def Air;
		item def Fuel;
		item def FuelAirMixture;
		item def ExhaustGas;
		item def Coolant;

		action def 'Draw Air' {
			out air: Air;
		}
		action def 'Inject Fuel' {
			in throttle: ThrottleCommand;
			out fuel: Fuel;
		}
		action def 'Mix Air and Fuel' {
			in air: Air;
			in fuel: Fuel;
			out mixture: FuelAirMixture;
		}
		action def 'Compress Mixture' {
			in mixture: FuelAirMixture;
			out compressedMixture: FuelAirMixture;
		}
		action def 'Ignite Mixture' {
			in compressedMixture: FuelAirMixture;
			in spark: SparkSignal;
			out combustionForce: Force;
			out exhaustGas: ExhaustGas;
		}
		action def 'Convert Linear to Rotational' {
			in combustionForce: Force;
			out torque: Torque;
			out speed: AngularVelocity;
		}
		action def 'Expel Exhaust' {
			in exhaustGas: ExhaustGas;
			out expelledGas: ExhaustGas;
		}
		action def 'Cool Engine' {
			in coolantIn: Coolant;
			out coolantOut: Coolant;
			out temperature: ThermodynamicTemperature;
		}
		action def 'Generate Mechanical Power' {
			in throttle: ThrottleCommand;
			in spark: SparkSignal;
			out torque: Torque;
			out speed: AngularVelocity;
			out expelledGas: ExhaustGas;
			out temperature: ThermodynamicTemperature;

			action 'draw air': 'Draw Air' {
				out air: Air;
			}
			action 'inject fuel': 'Inject Fuel' {
				in throttle = 'Generate Mechanical Power'::throttle;
				out fuel: Fuel;
			}
			flow 'draw air'.air to 'mix air and fuel'.air;
			flow 'inject fuel'.fuel to 'mix air and fuel'.fuel;
			action 'mix air and fuel': 'Mix Air and Fuel' {
				in air: Air;
				in fuel: Fuel;
				out mixture: FuelAirMixture;
			}
			flow 'mix air and fuel'.mixture to 'compress mixture'.mixture;
			action 'compress mixture': 'Compress Mixture' {
				in mixture: FuelAirMixture;
				out compressedMixture: FuelAirMixture;
			}
			flow 'compress mixture'.compressedMixture to 'ignite mixture'.compressedMixture;
			action 'ignite mixture': 'Ignite Mixture' {
				in compressedMixture: FuelAirMixture;
				in spark = 'Generate Mechanical Power'::spark;
				out combustionForce: Force;
				out exhaustGas: ExhaustGas;
			}
			flow 'ignite mixture'.combustionForce to 'convert to rotation'.combustionForce;
			flow 'ignite mixture'.exhaustGas to 'expel exhaust'.exhaustGas;
			action 'convert to rotation': 'Convert Linear to Rotational' {
				in combustionForce: Force;
				out torque: Torque;
				out speed: AngularVelocity;
			}
			action 'expel exhaust': 'Expel Exhaust' {
				in exhaustGas: ExhaustGas;
				out expelledGas: ExhaustGas;
			}
			action 'cool engine': 'Cool Engine' {
				in coolantIn: Coolant;
				out coolantOut: Coolant;
				out temperature: ThermodynamicTemperature;
			}
			flow 'convert to rotation'.torque to 'Generate Mechanical Power'::torque;
			flow 'convert to rotation'.speed to 'Generate Mechanical Power'::speed;
			flow 'expel exhaust'.expelledGas to 'Generate Mechanical Power'::expelledGas;
			flow 'cool engine'.temperature to 'Generate Mechanical Power'::temperature;
		}

		part def AirIntakeSystem {
			port airOutPort {
				out air: Air;
			}
		}

		part def FuelInjectionSystem {
			port throttleInPort {
				in throttle: ThrottleCommand;
			}
			port fuelOutPort {
				out fuel: Fuel;
			}
		}

		part def PistonAssembly {
			port forceOutPort {
				out combustionForce: Force;
			}
		}

		part def CombustionChamber {
			attribute cylinderNumber : Integer;
			port airInPort {
				in air: Air;
			}
			port fuelInPort {
				in fuel: Fuel;
			}
			port sparkInPort {
				in spark: SparkSignal;
			}
			port forceOutPort {
				out combustionForce: Force;
			}
			port exhaustOutPort {
				out expelledGas: ExhaustGas;
			}
			part piston : PistonAssembly;
		}

		part def IgnitionSystem {
			port sparkOutPort {
				out spark: SparkSignal;
			}
		}

		part def CrankshaftAssembly {
			port forceInPort {
				in combustionForce: Force;
			}
			port torqueOutPort {
				out torque: Torque;
			}
			port speedOutPort {
				out speed: AngularVelocity;
			}
		}

		part def ExhaustSystem {
			port exhaustInPort {
				in exhaustGas: ExhaustGas;
			}
			port exhaustOutPort {
				out expelledGas: ExhaustGas;
			}
		}

		part def CoolingSystem {
			port temperatureOutPort {
				out temperature: ThermodynamicTemperature;
			}
		}

		part def Engine {
			attribute displacement : Volume;
			attribute cylinderCount : Integer;
			port throttlePort {
				in throttle: ThrottleCommand;
			}
			port startPort {
				in start: EngineStartSignal;
			}
			port stopPort {
				in stop: EngineStopSignal;
			}
			port torquePort {
				out torque: Torque;
			}
			port speedPort {
				out speed: AngularVelocity;
			}
			port exhaustPort {
				out expelledGas: ExhaustGas;
			}

			part airIntake : AirIntakeSystem;
			part fuelInjection : FuelInjectionSystem;
			part combustionChambers : CombustionChamber [4];
			part ignition : IgnitionSystem;
			part crankshaft : CrankshaftAssembly;
			part exhaust : ExhaustSystem;
			part cooling : CoolingSystem;
		}

		state def EngineStates {
			entry; then off;
			state off;
			transition off_to_cranking
				first off
				accept EngineStartSignal
				then cranking;
			state cranking;
			transition cranking_to_running
				first cranking
				accept EngineRunningSignal
				then running;
			state running {
				entry; then idle;
				state idle;
				transition idle_to_accelerating
					first idle
					accept AccelerateSignal
					then accelerating;
				state accelerating;
				transition accelerating_to_cruising
					first accelerating
					accept CruiseSignal
					then cruising;
				state cruising;
				transition cruising_to_decelerating
					first cruising
					accept DecelerateSignal
					then decelerating;
				state decelerating;
				transition decelerating_to_idle
					first decelerating
					accept IdleSignal
					then idle;
			}
			transition running_to_stopping
				first running
				accept EngineStopSignal
				then stopping;
			state stopping;
			transition stopping_to_off
				first stopping
				accept EngineStoppedSignal
				then off;
		}

		requirement def EngineConfigurationRequirement {
			subject engine : Engine;
			attribute requiredCylinders : Integer = 4;
			attribute requiredDisplacement : Volume = 0.002 [m^3];
			require engine.cylinderCount == requiredCylinders;
			require engine.displacement == requiredDisplacement;
		}

		requirement def EnginePowerRequirement {
			subject engine : Engine;
			attribute minTorque : Torque = 150 [N*m];
			attribute maxSpeed : AngularVelocity = 733 [rad/s];
			require engine.torquePort.torque >= minTorque;
			require engine.speedPort.speed <= maxSpeed;
		}

		requirement def CoolingRequirement {
			subject cooling : CoolingSystem;
			attribute maxOperatingTemp : ThermodynamicTemperature = 378 [K];
			require cooling.temperatureOutPort.temperature <= maxOperatingTemp;
		}

		requirement def FourStrokeCycleRequirement {
			subject engine : Engine;
			doc
			/*
			 * The engine shall implement a four-stroke combustion cycle
			 * comprising intake, compression, power, and exhaust strokes.
			 */
			require engine.cylinderCount == 4;
		}
	}

	package Usages {
		part engine : Engine {
			attribute displacement = 0.002 [m^3];
			attribute cylinderCount = 4;

			connect airIntake.airOutPort to combustionChambers.airInPort;
			connect fuelInjection.fuelOutPort to combustionChambers.fuelInPort;
			connect ignition.sparkOutPort to combustionChambers.sparkInPort;
			connect combustionChambers.forceOutPort to crankshaft.forceInPort;
			connect combustionChambers.exhaustOutPort to exhaust.exhaustInPort;
			connect crankshaft.torqueOutPort to torquePort;
			connect crankshaft.speedOutPort to speedPort;
			connect exhaust.exhaustOutPort to exhaustPort;

			perform 'Generate Mechanical Power' {
				in throttle = throttlePort.throttle;
				in spark = ignition.sparkOutPort.spark;
				out torque = torquePort.torque;
				out speed = speedPort.speed;
				out expelledGas = exhaustPort.expelledGas;
				out temperature = cooling.temperatureOutPort.temperature;
			}

			part :>> airIntake {
				perform 'Generate Mechanical Power'.'draw air' {
					out air = airOutPort.air;
				}
			}
			part :>> fuelInjection {
				port :>> throttleInPort {
					in throttle = engine.throttlePort.throttle;
				}
				perform 'Generate Mechanical Power'.'inject fuel' {
					in throttle = throttleInPort.throttle;
					out fuel = fuelOutPort.fuel;
				}
			}
			part :>> crankshaft {
				perform 'Generate Mechanical Power'.'convert to rotation' {
					in combustionForce = forceInPort.combustionForce;
					out torque = torqueOutPort.torque;
					out speed = speedOutPort.speed;
				}
			}
			part :>> exhaust {
				perform 'Generate Mechanical Power'.'expel exhaust' {
					in exhaustGas = exhaustInPort.exhaustGas;
					out expelledGas = exhaustOutPort.expelledGas;
				}
			}
		}

		state engineStates : EngineStates;

		satisfy EngineConfigurationRequirement by engine;
		satisfy EnginePowerRequirement by engine;
		satisfy CoolingRequirement by engine.cooling;
		satisfy FourStrokeCycleRequirement by engine;
	}
}
