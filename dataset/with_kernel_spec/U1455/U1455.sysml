package CHP_Plant {
	private import ISQ::*;
	private import ScalarValues::*;

	item def NaturalGas {
		attribute massFlowRate : MassFlowRateValue;
	}
	item def Air {
		attribute massFlowRate : MassFlowRateValue;
		attribute pressure : PressureValue;
	}
	item def CombustionGas {
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
	}
	item def ExhaustGas {
		attribute temperature : TemperatureValue;
	}
	item def MechanicalPower {
		attribute torque : TorqueValue;
		attribute rotationalSpeed : ScalarValues::Real;
	}
	item def ElectricalPower {
		attribute power : PowerValue;
	}
	item def ThermalFluid {
		attribute temperature : TemperatureValue;
		attribute massFlowRate : MassFlowRateValue;
	}

	attribute def PowerDemand {
		attribute value : PowerValue;
	}
	attribute def FuelCmd {
		attribute massFlowRate : MassFlowRateValue;
	}
	attribute def AirCmd {
		attribute massFlowRate : MassFlowRateValue;
	}

	action def SupplyFuel {
		out fuel : NaturalGas;
	}
	action def CompressAir {
		out air : Air;
	}
	action def Combust {
		in fuel : NaturalGas;
		in air : Air;
		out gas : CombustionGas;
	}
	action def GenerateMechanicalPower {
		in gas : CombustionGas;
		out exhaust : ExhaustGas;
		out mechanicalPower : MechanicalPower;
	}
	action def GenerateElectricalPower {
		in mechanicalPower : MechanicalPower;
		out electricalPower : ElectricalPower;
	}
	action def RecoverHeat {
		in exhaust : ExhaustGas;
		out thermalFluid : ThermalFluid;
	}
	action def OperateCHP {
		in demand : PowerDemand;
		out electricalPower : ElectricalPower;
		out thermalFluid : ThermalFluid;
	}

	part def FuelSupplySystem {
		port fuelOut { out fuel : NaturalGas; }
		port fuelCmdIn { in cmd : FuelCmd; }
		action supplyFuel : SupplyFuel;
	}
	part def AirIntakeSystem {
		port airOut { out air : Air; }
		port airCmdIn { in cmd : AirCmd; }
		action compressAir : CompressAir;
	}
	part def CombustionChamber {
		port fuelIn { in fuel : NaturalGas; }
		port airIn { in air : Air; }
		port gasOut { out gas : CombustionGas; }
		action combust : Combust;
	}
	part def GasTurbine {
		port gasIn { in gas : CombustionGas; }
		port exhaustOut { out exhaust : ExhaustGas; }
		port mechanicalOut { out mechanicalPower : MechanicalPower; }
		action generateMechanicalPower : GenerateMechanicalPower;
	}
	part def ElectricalGenerator {
		port mechanicalIn { in mechanicalPower : MechanicalPower; }
		port electricalOut { out electricalPower : ElectricalPower; }
		action generateElectricalPower : GenerateElectricalPower;
	}
	part def HeatRecoveryUnit {
		port exhaustIn { in exhaust : ExhaustGas; }
		port fluidOut { out thermalFluid : ThermalFluid; }
		action recoverHeat : RecoverHeat;
	}

	part def ControlSystem {
		port demandIn { in demand : PowerDemand; }
		port electricalFeedback { in electricalPower : ElectricalPower; }
		port fuelCmdOut { out fuelCmd : FuelCmd; }
		port airCmdOut { out airCmd : AirCmd; }

		state controlState {
			entry; then Idle;
			state Idle;
			state Active {
				entry; then SteadyState;
				state SteadyState;
				state Increasing;
				state Decreasing;
				transition from SteadyState to Increasing
					when demandIn.demand.value > electricalFeedback.electricalPower.power;
				transition from SteadyState to Decreasing
					when demandIn.demand.value < electricalFeedback.electricalPower.power;
				transition from Increasing to SteadyState
					when demandIn.demand.value == electricalFeedback.electricalPower.power;
				transition from Decreasing to SteadyState
					when demandIn.demand.value == electricalFeedback.electricalPower.power;
			}
			transition from Idle to Active
				when demandIn.demand.value > 0;
			transition from Active to Idle
				when demandIn.demand.value == 0;
		}
	}

	part def CHPSystem {
		port demandIn { in demand : PowerDemand; }
		port electricalOut { out electricalPower : ElectricalPower; }
		port thermalOut { out thermalFluid : ThermalFluid; }

		action operateCHP : OperateCHP {
			in demand = demandIn.demand;
			out electricalPower = electricalOut.electricalPower;
			out thermalFluid = thermalOut.thermalFluid;
		}

		part fuelSupplySystem : FuelSupplySystem;
		part airIntakeSystem : AirIntakeSystem;
		part combustionChamber : CombustionChamber;
		part gasTurbine : GasTurbine;
		part electricalGenerator : ElectricalGenerator;
		part heatRecoveryUnit : HeatRecoveryUnit;
		part controlSystem : ControlSystem;

		flow fuelFlow of NaturalGas
			from fuelSupplySystem.fuelOut.fuel to combustionChamber.fuelIn.fuel;
		flow airFlow of Air
			from airIntakeSystem.airOut.air to combustionChamber.airIn.air;
		flow combustionGasFlow of CombustionGas
			from combustionChamber.gasOut.gas to gasTurbine.gasIn.gas;
		flow exhaustGasFlow of ExhaustGas
			from gasTurbine.exhaustOut.exhaust to heatRecoveryUnit.exhaustIn.exhaust;
		flow mechanicalPowerFlow of MechanicalPower
			from gasTurbine.mechanicalOut.mechanicalPower to electricalGenerator.mechanicalIn.mechanicalPower;
		flow electricalFeedbackFlow of ElectricalPower
			from electricalGenerator.electricalOut.electricalPower to controlSystem.electricalFeedback.electricalPower;

		flow fuelCmdFlow of FuelCmd
			from controlSystem.fuelCmdOut.fuelCmd to fuelSupplySystem.fuelCmdIn.cmd;
		flow airCmdFlow of AirCmd
			from controlSystem.airCmdOut.airCmd to airIntakeSystem.airCmdIn.cmd;
	}

	requirement def CHPPlantRequirement {
		doc /* The CHP system shall convert natural gas into electrical power and thermal energy efficiently. */
		subject chpSystem : CHPSystem;
	}

	requirement def CHPControlRequirement {
		doc /* The control system shall monitor electrical demand and adjust fuel and air flow to maintain target output. */
		subject controlSystem : ControlSystem;
	}

	requirement def CHPHeatRecoveryRequirement {
		doc /* Exhaust heat shall be captured by the heat recovery unit and transferred to a secondary medium. */
		subject heatRecoveryUnit : HeatRecoveryUnit;
	}

	requirement plantReq : CHPPlantRequirement {
		subject :>> chpSystem = chpPlant;
	}
	requirement controlReq : CHPControlRequirement {
		subject :>> controlSystem = chpPlant.controlSystem;
	}
	requirement heatReq : CHPHeatRecoveryRequirement {
		subject :>> heatRecoveryUnit = chpPlant.heatRecoveryUnit;
	}

	part chpPlant : CHPSystem;
}
