package 'Internal Combustion Engine System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FuelFlowRate :> ISQ::MassFlowRateValue;
	attribute def AirFlowRate :> ISQ::MassFlowRateValue;
	attribute def EngineSpeed :> ISQ::AngularVelocityValue;
	attribute def EngineTorque :> ISQ::TorqueValue;
	attribute def EnginePower :> ISQ::PowerValue;
	attribute def EngineTemperature :> ISQ::ThermodynamicTemperatureValue;
	attribute def EnginePressure :> ISQ::PressureValue;
	attribute def Displacement :> ISQ::VolumeValue;
	
	item def FuelAirMixture {
		attribute fuelFlow : FuelFlowRate;
		attribute airFlow : AirFlowRate;
		attribute ratio : Real;
	}
	
	item def ExhaustGas {
		attribute temperature : EngineTemperature;
		attribute pressure : EnginePressure;
		attribute massFlow : ISQ::MassFlowRateValue;
	}
	
	item def IgnitionSignal;
	item def ThrottleCommand;
	item def StartCommand;
	item def StopCommand;
	
	port def FuelIntakePort {
		in item fuelMixture : FuelAirMixture;
	}
	
	port def ExhaustPort {
		out item exhaustGas : ExhaustGas;
	}
	
	port def MechanicalOutputPort {
		out torque : EngineTorque;
		out speed : EngineSpeed;
		out power : EnginePower;
	}
	
	port def ControlInputPort {
		in throttle : ThrottleCommand;
		in startCmd : StartCommand;
		in stopCmd : StopCommand;
	}
	
	part def FuelInjectionSystem {
		port fuelOut : FuelIntakePort;
		attribute injectionRate : FuelFlowRate;
		
		action injectFuel {
			in throttlePosition : Real;
			in airFlow : AirFlowRate;
			out mixture : FuelAirMixture;
		}
	}
	
	part def AirIntakeSystem {
		attribute airFlowRate : AirFlowRate;
		
		action supplyAir {
			in throttleOpening : Real;
			out airFlow : AirFlowRate;
		}
	}
	
	part def CombustionChamber {
		port fuelIn : FuelIntakePort;
		port exhaustOut : ExhaustPort;
		
		attribute chamberPressure : EnginePressure;
		attribute chamberTemperature : EngineTemperature;
		attribute displacement : Displacement;
		
		action combustMixture {
			in mixture : FuelAirMixture;
			in ignition : IgnitionSignal;
			out combustionForce : ISQ::ForceValue;
			out exhaust : ExhaustGas;
		}
	}
	
	part def PistonAssembly {
		attribute pistonDisplacement : ISQ::LengthValue;
		attribute pistonVelocity : ISQ::SpeedValue;
		
		action convertCombustionForce {
			in combustionForce : ISQ::ForceValue;
			out linearMotion : ISQ::SpeedValue;
		}
	}
	
	part def CrankshaftAssembly {
		port mechanicalOut : MechanicalOutputPort;
		
		attribute angularVelocity : EngineSpeed;
		attribute outputTorque : EngineTorque;
		
		action convertToRotation {
			in linearMotion : ISQ::SpeedValue;
			out torque : EngineTorque;
			out speed : EngineSpeed;
			out power : EnginePower;
		}
	}
	
	part def IgnitionSystem {
		attribute sparkTiming : Real;
		
		action generateIgnition {
			in engineSpeed : EngineSpeed;
			in timing : Real;
			out ignition : IgnitionSignal;
		}
	}
	
	part def ExhaustSystem {
		port exhaustIn : ExhaustPort;
		
		action expelExhaust {
			in exhaust : ExhaustGas;
		}
	}
	
	part def CoolingSystem {
		attribute coolantTemperature : EngineTemperature;
		
		action regulateTemperature {
			in engineTemp : EngineTemperature;
			out cooledTemp : EngineTemperature;
		}
	}
	
	state def EngineOperationalState {
		entry; then off;
		
		state off;
		state cranking;
		state running {
			state idle;
			state accelerating;
			state cruising;
			state decelerating;
		}
		state stopping;
		
		transition crankTransition
			first off
			accept startCmd : StartCommand
			then cranking;
			
		transition ignitionTransition
			first cranking
			accept ignition : IgnitionSignal
			then running.idle;
			
		transition accelerateTransition
			first running.idle
			accept throttleIncrease : ThrottleCommand
			then running.accelerating;
			
		transition cruiseTransition
			first running.accelerating
			accept throttleStable : ThrottleCommand
			then running.cruising;
			
		transition decelerateTransition
			first running.cruising
			accept throttleDecrease : ThrottleCommand
			then running.decelerating;
			
		transition idleTransition
			first running.decelerating
			then running.idle;
			
		transition stopTransition
			first running
			accept stopCmd : StopCommand
			then stopping;
			
		transition offTransition
			first stopping
			then off;
	}
	
	part def InternalCombustionEngine {
		port controlInput : ControlInputPort;
		port mechanicalOutput : MechanicalOutputPort;
		port fuelIntake : FuelIntakePort;
		port exhaustOutput : ExhaustPort;
		
		attribute numberOfCylinders : Integer;
		attribute totalDisplacement : Displacement;
		attribute compressionRatio : Real;
		
		part fuelSystem : FuelInjectionSystem;
		part airIntake : AirIntakeSystem;
		part combustionChamber[numberOfCylinders] : CombustionChamber;
		part pistonAssembly[numberOfCylinders] : PistonAssembly;
		part crankshaft : CrankshaftAssembly;
		part ignitionSystem : IgnitionSystem;
		part exhaustSystem : ExhaustSystem;
		part coolingSystem : CoolingSystem;
		
		connect fuelSystem.fuelOut to fuelIntake;
		connect fuelIntake to combustionChamber.fuelIn;
		connect combustionChamber.exhaustOut to exhaustSystem.exhaustIn;
		connect exhaustSystem.exhaustIn to exhaustOutput;
		connect crankshaft.mechanicalOut to mechanicalOutput;
		
		exhibit state operationalState : EngineOperationalState;
		
		perform action convertChemicalToMechanicalEnergy {
			in throttleCmd : ThrottleCommand;
			out deliveredTorque : EngineTorque;
			out deliveredSpeed : EngineSpeed;
			out deliveredPower : EnginePower;
			
			first start;
			then merge continueOperation;
			
			action intakeCycle {
				action supplyAir : airIntake.supplyAir {
					in throttleOpening : Real;
					out airFlow : AirFlowRate;
				}
				action injectFuel : fuelSystem.injectFuel {
					in throttlePosition : Real;
					in airFlow : AirFlowRate;
					out mixture : FuelAirMixture;
				}
			}
			
			then action compressionCycle {
				action compressMixture {
					in mixture : FuelAirMixture;
					out compressedMixture : FuelAirMixture;
				}
			}
			
			then action powerCycle {
				action ignite : ignitionSystem.generateIgnition {
					in engineSpeed : EngineSpeed;
					in timing : Real;
					out ignition : IgnitionSignal;
				}
				action combust : combustionChamber[1].combustMixture {
					in mixture : FuelAirMixture;
					in ignition : IgnitionSignal;
					out combustionForce : ISQ::ForceValue;
					out exhaust : ExhaustGas;
				}
				action drivePiston : pistonAssembly[1].convertCombustionForce {
					in combustionForce : ISQ::ForceValue;
					out linearMotion : ISQ::SpeedValue;
				}
				action rotateCrankshaft : crankshaft.convertToRotation {
					in linearMotion : ISQ::SpeedValue;
					out torque : EngineTorque;
					out speed : EngineSpeed;
					out power : EnginePower;
				}
				
				flow rotateCrankshaft.torque to convertChemicalToMechanicalEnergy.deliveredTorque;
				flow rotateCrankshaft.speed to convertChemicalToMechanicalEnergy.deliveredSpeed;
				flow rotateCrankshaft.power to convertChemicalToMechanicalEnergy.deliveredPower;
			}
			
			then action exhaustCycle {
				action expel {
					in exhaust : ExhaustGas;
				}
			}
			
			then continueOperation;
		}
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The internal combustion engine shall convert chemical energy stored in fuel 
		       into mechanical rotational energy delivered through a crankshaft. */
		
		subject engine : InternalCombustionEngine;
		
		require constraint {
			engine.mechanicalOutput.torque.magnitude > 0.0 and
			engine.mechanicalOutput.speed.magnitude > 0.0
		}
	}
	
	requirement def PowerOutputRequirement {
		doc /* The engine shall deliver specified power output at rated speed. */
		
		subject engine : InternalCombustionEngine;
		
		attribute ratedPower : EnginePower;
		attribute ratedSpeed : EngineSpeed;
		
		require constraint {
			engine.mechanicalOutput.power.magnitude >= ratedPower.magnitude
		}
	}
	
	requirement def CombustionEfficiencyRequirement {
		doc /* The combustion chamber shall maintain efficient combustion conditions. */
		
		subject chamber : CombustionChamber;
		
		require constraint {
			chamber.chamberTemperature.magnitude > 500.0 and
			chamber.chamberPressure.magnitude > 100000.0
		}
	}
	
	requirement def OperationalSafetyRequirement {
		doc /* The engine shall safely transition between operational states. */
		
		subject engine : InternalCombustionEngine;
	}
	
	part vehicleEngine : InternalCombustionEngine {
		:>> numberOfCylinders = 4;
		:>> totalDisplacement = 2.0;
		:>> compressionRatio = 10.5;
		
		satisfy primaryFunction : PrimaryFunctionRequirement by vehicleEngine;
		satisfy powerOutput : PowerOutputRequirement by vehicleEngine {
			:>> ratedPower.magnitude = 150000.0;
			:>> ratedSpeed.magnitude = 5500.0;
		}
		satisfy combustionEfficiency : CombustionEfficiencyRequirement by vehicleEngine.combustionChamber[1];
		satisfy operationalSafety : OperationalSafetyRequirement by vehicleEngine;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Internal Combustion Engine System'::*;

    part testSubject : InternalCombustionEngine {
    :>> throttleOpening = 0.0;
    }

    part testSubject : InternalCombustionEngine {
        exhibit state operationalState : EngineOperationalState;
    }
}
