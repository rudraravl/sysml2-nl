package CombinedCyclePowerPlantModel {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def FuelFlowRate :> massFlowRate;
	attribute def AirFlowRate :> massFlowRate;
	attribute def ExhaustFlow :> massFlowRate;
	attribute def MechPower :> power;
	attribute def ElecPower :> power;
	attribute def GridVoltage :> electricPotential;
	attribute def GridFreq :> frequency;
	attribute def StateOfCharge :> Real;
	attribute def ResponseTime :> time;
	attribute def Efficiency :> Real;

	attribute def GridDemandSignal {
		attribute demand : ElecPower;
		attribute voltage : GridVoltage;
		attribute freq : GridFreq;
	}

	enum def PlantCommand {
		literal start;
		literal stop;
		literal emergencyStop;
		literal reset;
	}

	enum def StorageCommand {
		literal charge;
		literal discharge;
		literal idle;
	}

	package Behaviors {
		action def CombustFuel {
			in fuelCmd : FuelFlowRate;
			in airCmd : AirFlowRate;
			out shaftPower : MechPower;
			out exhaustFlow : ExhaustFlow;
		}

		action def GenerateElectricity {
			in shaftPower : MechPower;
			out genPower : ElecPower;
		}

		action def RecoverHeat {
			in exhaustFlow : ExhaustFlow;
			out recoveredPower : ElecPower;
		}

		action def ConditionPower {
			in primaryPower : ElecPower;
			in secondaryPower : ElecPower;
			in storageDischarge : ElecPower;
			out gridPower : ElecPower;
			out storageCharge : ElecPower;
			out gridVoltage : GridVoltage;
			out gridFreq : GridFreq;
		}

		action def ManageStorage {
			in cmd : StorageCommand;
			in charge : ElecPower;
			out discharge : ElecPower;
			inout soc : StateOfCharge;
		}

		action def ControlPlant {
			in cmd : PlantCommand;
			in gridDemand : GridDemandSignal;
			out fuelCmd : FuelFlowRate;
			out airCmd : AirFlowRate;
			out storageCmd : StorageCommand;
		}

		state def ControlStateBehavior {
			initial state off;
			state starting;
			state running;
			state stopping;
			state emergency;

			transition from off to starting;
			transition from starting to running;
			transition from running to stopping;
			transition from stopping to off;
			transition from running to emergency;
			transition from emergency to off;
		}
	}

	package Components {
		private import Behaviors::*;

		part def GasTurbine {
			port fuelIn : FuelFlowRate;
			port airIn : AirFlowRate;
			port shaftOut : MechPower;
			port exhaustOut : ExhaustFlow;

			perform action combust : CombustFuel {
				in fuelCmd = fuelIn;
				in airCmd = airIn;
				out shaftPower = shaftOut;
				out exhaustFlow = exhaustOut;
			}
		}

		part def ElectricalGenerator {
			port shaftIn : MechPower;
			port genPowerOut : ElecPower;

			perform action generate : GenerateElectricity {
				in shaftPower = shaftIn;
				out genPower = genPowerOut;
			}
		}

		part def HeatRecoverySystem {
			port exhaustIn : ExhaustFlow;
			port recoveredPowerOut : ElecPower;

			perform action recover : RecoverHeat {
				in exhaustFlow = exhaustIn;
				out recoveredPower = recoveredPowerOut;
			}
		}

		part def PowerConditioningUnit {
			port primaryPowerIn : ElecPower;
			port secondaryPowerIn : ElecPower;
			port storageDischargeIn : ElecPower;
			port gridPowerOut : ElecPower;
			port storageChargeOut : ElecPower;
			port gridVoltageOut : GridVoltage;
			port gridFreqOut : GridFreq;

			perform action condition : ConditionPower {
				in primaryPower = primaryPowerIn;
				in secondaryPower = secondaryPowerIn;
				in storageDischarge = storageDischargeIn;
				out gridPower = gridPowerOut;
				out storageCharge = storageChargeOut;
				out gridVoltage = gridVoltageOut;
				out gridFreq = gridFreqOut;
			}
		}

		part def EnergyStorageSystem {
			port cmd : StorageCommand;
			port chargeIn : ElecPower;
			port dischargeOut : ElecPower;
			attribute soc : StateOfCharge;
			attribute maxDischargeRate : ElecPower = 10.0 [MW];
			attribute responseTime : ResponseTime = 100.0 [ms];

			perform action manage : ManageStorage {
				in cmd = cmd;
				in charge = chargeIn;
				out discharge = dischargeOut;
				inout soc = soc;
			}
		}

		part def ControlSystem {
			port cmdIn : PlantCommand;
			port gridDemandIn : GridDemandSignal;
			port fuelCmdOut : FuelFlowRate;
			port airCmdOut : AirFlowRate;
			port storageCmdOut : StorageCommand;

			perform action control : ControlPlant {
				in cmd = cmdIn;
				in gridDemand = gridDemandIn;
				out fuelCmd = fuelCmdOut;
				out airCmd = airCmdOut;
				out storageCmd = storageCmdOut;
			}

			state controlStates : ControlStateBehavior;
		}

		part def Operator {
			port cmdOut : PlantCommand;
		}

		part def RegionalGrid {
			port powerIn : ElecPower;
			port voltageIn : GridVoltage;
			port freqIn : GridFreq;
			port demandOut : GridDemandSignal;
		}

		part def CombinedCyclePowerPlant {
			part gasTurbine : GasTurbine;
			part generator : ElectricalGenerator;
			part heatRecovery : HeatRecoverySystem;
			part powerConditioning : PowerConditioningUnit;
			part energyStorage : EnergyStorageSystem;
			part controlSystem : ControlSystem;

			port cmd : PlantCommand;
			port gridDemand : GridDemandSignal;
			port gridOutput : ElecPower;
			port gridVoltage : GridVoltage;
			port gridFreq : GridFreq;
			attribute netEfficiency : Efficiency;

			connect controlSystem.fuelCmdOut to gasTurbine.fuelIn;
			connect controlSystem.airCmdOut to gasTurbine.airIn;
			connect gasTurbine.shaftOut to generator.shaftIn;
			connect gasTurbine.exhaustOut to heatRecovery.exhaustIn;
			connect generator.genPowerOut to powerConditioning.primaryPowerIn;
			connect heatRecovery.recoveredPowerOut to powerConditioning.secondaryPowerIn;
			connect energyStorage.dischargeOut to powerConditioning.storageDischargeIn;
			connect powerConditioning.storageChargeOut to energyStorage.chargeIn;
			connect controlSystem.storageCmdOut to energyStorage.cmd;
			connect powerConditioning.gridPowerOut to gridOutput;
			connect powerConditioning.gridVoltageOut to gridVoltage;
			connect powerConditioning.gridFreqOut to gridFreq;
			connect cmd to controlSystem.cmdIn;
			connect gridDemand to controlSystem.gridDemandIn;
		}
	}

	package Requirements {
		private import Components::*;

		requirement reliablePower {
			subject plant : CombinedCyclePowerPlant;
			require constraint {
				plant.gridOutput >= 100.0 [MW]
			}
		}

		requirement gridQuality {
			subject plant : CombinedCyclePowerPlant;
			attribute nomVoltage : GridVoltage = 230.0 [kV];
			attribute nomFreq : GridFreq = 60.0 [Hz];
			require constraint {
				plant.gridVoltage >= 0.95 * nomVoltage and
				plant.gridVoltage <= 1.05 * nomVoltage and
				plant.gridFreq >= nomFreq - 0.1 [Hz] and
				plant.gridFreq <= nomFreq + 0.1 [Hz]
			}
		}

		requirement combinedCycleEfficiency {
			subject plant : CombinedCyclePowerPlant;
			attribute minEff : Efficiency = 0.60;
			require constraint {
				plant.netEfficiency >= minEff
			}
		}

		requirement storageResponse {
			subject ess : EnergyStorageSystem;
			attribute maxTime : ResponseTime = 100.0 [ms];
			require constraint {
				ess.responseTime <= maxTime
			}
		}

		requirement loadFollowing {
			subject plant : CombinedCyclePowerPlant;
			attribute maxError : ElecPower = 5.0 [MW];
			require constraint {
				plant.gridOutput - plant.gridDemand.demand >= -maxError and
				plant.gridOutput - plant.gridDemand.demand <= maxError
			}
		}
	}

	package Plant {
		private import Components::*;
		private import Requirements::*;

		part def PlantSystem {
			part plant : CombinedCyclePowerPlant;
			part operator : Operator;
			part grid : RegionalGrid;

			connect operator.cmdOut to plant.cmd;
			connect plant.gridOutput to grid.powerIn;
			connect plant.gridVoltage to grid.voltageIn;
			connect plant.gridFreq to grid.freqIn;
			connect grid.demandOut to plant.gridDemand;
		}

		part plantSystem : PlantSystem;

		satisfy reliablePower by plantSystem.plant;
		satisfy gridQuality by plantSystem.plant;
		satisfy combinedCycleEfficiency by plantSystem.plant;
		satisfy storageResponse by plantSystem.plant.energyStorage;
		satisfy loadFollowing by plantSystem.plant;
	}
}
