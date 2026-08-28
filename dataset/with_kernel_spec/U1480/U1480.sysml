package 'Reciprocating ICE System' {
	private import ISQ::*;
	private import ScalarValues::*;
	private import SI::*;

	item def FuelAirMixture;
	item def CombustionGas;
	item def Coolant;
	item def LubricatingOil;

	attribute def Displacement :> ISQ::VolumeValue;
	attribute def CompressionRatio :> Real;
	attribute def ThermalEfficiency :> Real;

	port def MechanicalPowerPort {
		out torque : TorqueValue;
		out speed : AngularVelocityValue;
	}

	port def FluidFlowPort {
		out pressure : PressureValue;
		out temperature : TemperatureValue;
	}

	port def ThermalPort {
		out temperature : TemperatureValue;
	}

	part def Engine {
		attribute displacement : Displacement;
		attribute compressionRatio : CompressionRatio;
		attribute thermalEfficiency : ThermalEfficiency;
		port powerOutput : MechanicalPowerPort;
		port coolantPort : FluidFlowPort;
		port fuelPort : FluidFlowPort;
		port oilPort : FluidFlowPort;
	}

	part def Cylinder {
		port intakePort : ~FluidFlowPort;
		port exhaustPort : FluidFlowPort;
		port thermalPort : ~ThermalPort;
	}

	part def Piston;
	part def Valve;
	part def SparkPlug;
	part def Crankshaft {
		port mechanicalPort : MechanicalPowerPort;
		port oilIn : ~FluidFlowPort;
	}
	part def Camshaft;
	part def FuelSystem {
		port fuelOut : FluidFlowPort;
	}
	part def CoolingSystem {
		port coolantOut : FluidFlowPort;
	}
	part def LubricationSystem {
		port oilOut : FluidFlowPort;
	}

	action def IntakeStroke {
		in fuelAirMixture : FuelAirMixture;
	}
	action def CompressionStroke;
	action def PowerStroke {
		out combustionGas : CombustionGas;
	}
	action def ExhaustStroke {
		in combustionGas : CombustionGas;
	}

	action def FourStrokeCycle {
		in fuelAirMixture : FuelAirMixture;
		out combustionGas : CombustionGas;
		action intake : IntakeStroke {
			in fuelAirMixture = FourStrokeCycle::fuelAirMixture;
		}
		then action compression : CompressionStroke;
		then action power : PowerStroke {
			out combustionGas = FourStrokeCycle::combustionGas;
		}
		then action exhaust : ExhaustStroke {
			in combustionGas = power.combustionGas;
		}
		then done;
	}

	requirement def EnginePerformanceRequirements {
		attribute minPower : PowerValue;
		attribute minTorque : TorqueValue;
		attribute minThermalEfficiency : Real;
		attribute maxOperatingTemp : TemperatureValue;

		requirement powerRequirement {
			doc /* The engine must produce at least the minimum power. */
			subject engine : Engine;
			require constraint { engine.powerOutput.torque * engine.powerOutput.speed >= minPower }
		}
		requirement torqueRequirement {
			doc /* The engine must produce at least the minimum torque. */
			subject engine : Engine;
			require constraint { engine.powerOutput.torque >= minTorque }
		}
		requirement efficiencyRequirement {
			doc /* The engine must achieve the minimum thermal efficiency. */
			subject engine : Engine;
			require constraint { engine.thermalEfficiency >= minThermalEfficiency }
		}
		requirement temperatureRequirement {
			doc /* The engine must not exceed the maximum safe operating temperature. */
			subject engine : Engine;
			require constraint { engine.coolantPort.temperature <= maxOperatingTemp }
		}
	}

	package Usages {
		part engine : Engine {
			part cylinders[*] : Cylinder {
				part piston : Piston;
				part intakeValve : Valve;
				part exhaustValve : Valve;
				part sparkPlug : SparkPlug;

				perform fourStroke : FourStrokeCycle;
			}
			part crankshaft : Crankshaft;
			part camshaft : Camshaft;
			part fuelSystem : FuelSystem;
			part coolingSystem : CoolingSystem;
			part lubricationSystem : LubricationSystem;

			connect fuelSystem.fuelOut to cylinders.intakePort;
			connect coolingSystem.coolantOut to cylinders.thermalPort;
			connect lubricationSystem.oilOut to crankshaft.oilIn;
			connect crankshaft.mechanicalPort to powerOutput;
		}

		variation part engineConfig :> engine {
			variant part '4CylEngine' {
				part :>> cylinders[4];
				attribute :>> displacement = 2000 [mL];
				attribute :>> compressionRatio = 10.5;
			}
			variant part 'V6Engine' {
				part :>> cylinders[6];
				attribute :>> displacement = 3500 [mL];
				attribute :>> compressionRatio = 11.0;
			}
		}

		part vehicleEngine :> engineConfig::'4CylEngine' {
			requirement req : EnginePerformanceRequirements {
				attribute minPower = 100 [kW];
				attribute minTorque = 150 [N*m];
				attribute minThermalEfficiency = 0.35;
				attribute maxOperatingTemp = 383 [K];
			}
			satisfy req;
		}
	}
}
