package 'Gravitational Energy Storage System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	package Definitions {
		alias Mass for MassValue;
		alias Height for LengthValue;
		alias Power for PowerValue;
		alias Efficiency for Real;

		attribute def ChargeCmd;
		attribute def DischargeCmd;
		attribute def StandbyCmd;

		item def ElectricalEnergy;
		item def MechanicalEnergy;

		port def ElectricalPort {
			inout electricalEnergy : ElectricalEnergy;
		}
		port def MechanicalPort {
			inout mechanicalEnergy : MechanicalEnergy;
		}
		port def ControlInPort {
			in chargeCmd : ChargeCmd;
			in dischargeCmd : DischargeCmd;
			in standbyCmd : StandbyCmd;
		}
		port def ControlOutPort {
			out chargeCmd : ChargeCmd;
			out dischargeCmd : DischargeCmd;
			out standbyCmd : StandbyCmd;
		}
		port def SensorPort {
			out height : Height;
		}

		part def Grid {
			port powerPort : ElectricalPort;
		}
		part def PowerConverter {
			port gridPort : ElectricalPort;
			port genPort : ElectricalPort;
			attribute efficiency : Efficiency = 0.75;
		}
		part def Generator {
			port mechPort : MechanicalPort;
			port elecPort : ElectricalPort;
		}
		part def HoistingMechanism {
			port mechPort : MechanicalPort;
			port elecPort : ElectricalPort;
			port controlPort : ControlInPort;
		}
		part def MassBlock {
			port sensorPort : SensorPort;
			attribute mass : Mass = 500000 [kg];
			attribute maxHeight : Height = 120 [m];
			attribute currentHeight : Height;
		}
		part def SystemController {
			port cmdPort : ControlInPort;
			port monitorPort : SensorPort;
			port hoistCmdPort : ControlOutPort;
		}
		part def GravitationalStorageSystem;

		action def Charge {
			in electricalEnergy : ElectricalEnergy;
			out mechanicalEnergy : MechanicalEnergy;
		}
		action def Discharge {
			in mechanicalEnergy : MechanicalEnergy;
			out electricalEnergy : ElectricalEnergy;
		}

		state def SystemControllerStateMachine {
			region {
				state Standby;
				state Charging;
				state Discharging;
				transition from Standby to Charging accept chargeCmd : ChargeCmd;
				transition from Standby to Discharging accept dischargeCmd : DischargeCmd;
				transition from Charging to Standby accept standbyCmd : StandbyCmd;
				transition from Discharging to Standby accept standbyCmd : StandbyCmd;
			}
		}

		requirement def StorageCapacity {
			attribute maxMass : Mass = 500000 [kg];
			attribute maxHeight : Height = 120 [m];
		}
		requirement def PowerOutput {
			attribute minPower : Power = 4 [MW];
		}
		requirement def RoundTripEfficiency {
			attribute minEfficiency : Efficiency = 0.75;
		}
	}

	package Usages {
		private import Definitions::*;
		
		part gravitationalStorageSystem : GravitationalStorageSystem {
			part grid : Grid;
			part powerConverter : PowerConverter;
			part generator : Generator;
			part hoistingMechanism : HoistingMechanism;
			part massBlock : MassBlock;
			part systemController : SystemController;

			flow gridToConverter of ElectricalEnergy 
				from grid.powerPort.electricalEnergy to powerConverter.gridPort.electricalEnergy;
			flow converterToGrid of ElectricalEnergy 
				from powerConverter.gridPort.electricalEnergy to grid.powerPort.electricalEnergy;
			flow converterToHoist of ElectricalEnergy 
				from powerConverter.genPort.electricalEnergy to hoistingMechanism.elecPort.electricalEnergy;
			flow hoistToConverter of ElectricalEnergy 
				from hoistingMechanism.elecPort.electricalEnergy to powerConverter.genPort.electricalEnergy;
			flow converterToGen of ElectricalEnergy 
				from powerConverter.genPort.electricalEnergy to generator.elecPort.electricalEnergy;
			flow genToConverter of ElectricalEnergy 
				from generator.elecPort.electricalEnergy to powerConverter.genPort.electricalEnergy;
			flow genToHoist of MechanicalEnergy 
				from generator.mechPort.mechanicalEnergy to hoistingMechanism.mechPort.mechanicalEnergy;
			flow hoistToGen of MechanicalEnergy 
				from hoistingMechanism.mechPort.mechanicalEnergy to generator.mechPort.mechanicalEnergy;
			flow heightDataFlow of Height 
				from massBlock.sensorPort.height to systemController.monitorPort.height;

			connect systemController.hoistCmdPort to hoistingMechanism.controlPort;

			state systemState : SystemControllerStateMachine;

			requirement storageCapacity : StorageCapacity {
				subject massBlock;
			}
			requirement powerOutput : PowerOutput {
				subject generator;
			}
			requirement roundTripEfficiency : RoundTripEfficiency {
				subject powerConverter;
			}
		}
	}
}
