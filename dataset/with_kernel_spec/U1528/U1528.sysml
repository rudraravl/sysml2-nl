package 'Hydroelectric Turbine System' {
	private import SI::*;
	private import ISQ::*;
	private import ScalarValues::*;
	
	item def Water;
	
	public import LogicalModel::*;
	public import PhysicalModel::*;
	
	package Ports {
		port def WaterInPort { 
			in item water : Water; 
			in pressure : Real; 
			in flowRate : Real; 
		}
		port def WaterOutPort { 
			out item water : Water; 
			out pressure : Real; 
			out flowRate : Real; 
		}
		port def MechanicalPort { 
			out torque : Real; 
			out speed : Real; 
		}
		port def ElectricalPort { 
			out power : Real; 
			out voltage : Real; 
			out frequency : Real; 
		}
		port def SpeedPort { 
			out speed : Real; 
		}
		port def VaneControlPort { 
			out vaneAngle : Real; 
		}
	}
	
	package Interfaces {
		private import Ports::*;
		
		interface def WaterFlowInterface {
			end supplier : WaterOutPort;
			end consumer : WaterInPort;
		}
		interface def MechanicalDriveInterface {
			end driver : MechanicalPort;
			end driven : MechanicalPort;
		}
		interface def SpeedTransmissionInterface {
			end source : SpeedPort;
			end target : SpeedPort;
		}
		interface def VaneControlInterface {
			end controller : VaneControlPort;
			end actuator : VaneControlPort;
		}
	}
	
	package LogicalModel {
		private import Ports::*;
		
		action def DistributeWater {
			in water : Water; 
			in pressure : Real; 
			in flowRate : Real;
			out distributedWater : Water; 
			out distPressure : Real; 
			out distFlowRate : Real;
		}
		action def RegulateFlow {
			in inWater : Water; 
			in targetSpeed : Real;
			out regulatedWater : Water; 
			out vaneAngle : Real;
		}
		action def GenerateTorque {
			in water : Water; 
			in pressure : Real;
			out torque : Real; 
			out speed : Real; 
			out outWater : Water;
		}
		action def DischargeWater {
			in water : Water; 
			in pressure : Real;
			out dischargedWater : Water; 
			out outPressure : Real;
		}
		action def TransmitTorque {
			in inTorque : Real; 
			in inSpeed : Real;
			out outTorque : Real; 
			out outSpeed : Real;
		}
		action def GenerateElectricity {
			in inTorque : Real; 
			in inSpeed : Real;
			out power : Real; 
			out voltage : Real; 
			out frequency : Real;
		}
		action def ProvidePower {
			in water : Water; 
			in pressure : Real; 
			in flowRate : Real;
			out power : Real; 
			out voltage : Real; 
			out frequency : Real;
		}
		
		action providePower : ProvidePower {
			in water : Water; 
			in pressure : Real; 
			in flowRate : Real;
			out power : Real; 
			out voltage : Real; 
			out frequency : Real;
			
			action distributeWater : DistributeWater {
				in water = providePower::water;
				in pressure = providePower::pressure;
				in flowRate = providePower::flowRate;
				out distributedWater : Water;
				out distPressure : Real;
				out distFlowRate : Real;
			}
			
			action regulateFlow : RegulateFlow {
				in inWater : Water;
				in targetSpeed : Real;
				out regulatedWater : Water;
				out vaneAngle : Real;
			}
			flow distributeWater.distributedWater to regulateFlow.inWater;
			
			action generateTorque : GenerateTorque {
				in water : Water;
				in pressure : Real;
				out torque : Real;
				out speed : Real;
				out outWater : Water;
			}
			flow regulateFlow.regulatedWater to generateTorque.water;
			flow distributeWater.distPressure to generateTorque.pressure;
			
			action dischargeWater : DischargeWater {
				in water : Water;
				in pressure : Real;
				out dischargedWater : Water;
				out outPressure : Real;
			}
			flow generateTorque.outWater to dischargeWater.water;
			flow distributeWater.distPressure to dischargeWater.pressure;
			
			action transmitTorque : TransmitTorque {
				in inTorque : Real;
				in inSpeed : Real;
				out outTorque : Real;
				out outSpeed : Real;
			}
			flow generateTorque.torque to transmitTorque.inTorque;
			flow generateTorque.speed to transmitTorque.inSpeed;
			
			action generateElectricity : GenerateElectricity {
				in inTorque : Real;
				in inSpeed : Real;
				out power : Real;
				out voltage : Real;
				out frequency : Real;
			}
			flow transmitTorque.outTorque to generateElectricity.inTorque;
			flow transmitTorque.outSpeed to generateElectricity.inSpeed;
		}
		
		state def GovernorBehavior {
			state Monitoring;
			state Adjusting;
			transition monitor_to_adjust 
				first Monitoring 
				then Adjusting;
			transition adjust_to_monitor 
				first Adjusting 
				then Monitoring;
		}
	}
	
	package PhysicalModel {
		private import Ports::*;
		private import Interfaces::*;
		private import LogicalModel::*;
		
		part def SpiralCasing {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
		}
		part def GuideVanes {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			port vaneControlIn : VaneControlPort;
			attribute vaneCount : Integer = 20;
		}
		part def GovernorSystem {
			port speedIn : SpeedPort;
			port vaneControlOut : VaneControlPort;
			attribute targetSpeed : Real = 100.0;
			state governorControl : GovernorBehavior;
		}
		part def Runner {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			port mechOut : MechanicalPort;
			port speedOut : SpeedPort;
			attribute bladeCount : Integer = 16;
		}
		part def DraftTube {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
		}
		part def BearingAssembly {
		}
		part def Shaft {
			port mechIn : MechanicalPort;
			port mechOut : MechanicalPort;
			part bearings : BearingAssembly[2];
		}
		part def Generator {
			port mechIn : MechanicalPort;
			port generatorOutput : ElectricalPort;
		}
		
		part def HydroelectricTurbineSystem {
			attribute totalWeight : Real = 38000.0;
			attribute efficiency : Real = 0.88;
			
			port waterIntake : WaterInPort;
			port waterDischarge : WaterOutPort;
			port generatorOutput : ElectricalPort;
			
			part spiralCasing : SpiralCasing {
				perform providePower.distributeWater;
			}
			part guideVanes : GuideVanes {
				perform providePower.regulateFlow;
			}
			part governorSystem : GovernorSystem {
				perform providePower.regulateFlow;
			}
			part runner : Runner {
				perform providePower.generateTorque;
			}
			part draftTube : DraftTube {
				perform providePower.dischargeWater;
			}
			part shaft : Shaft {
				perform providePower.transmitTorque;
			}
			part generator : Generator {
				perform providePower.generateElectricity;
			}
			
			bind waterIntake = spiralCasing.waterIn;
			interface : WaterFlowInterface connect 
				supplier ::> spiralCasing.waterOut to 
				consumer ::> guideVanes.waterIn;
			interface : WaterFlowInterface connect 
				supplier ::> guideVanes.waterOut to 
				consumer ::> runner.waterIn;
			interface : WaterFlowInterface connect 
				supplier ::> runner.waterOut to 
				consumer ::> draftTube.waterIn;
			bind waterDischarge = draftTube.waterOut;
			
			interface : SpeedTransmissionInterface connect 
				source ::> runner.speedOut to 
				target ::> governorSystem.speedIn;
			interface : VaneControlInterface connect 
				controller ::> governorSystem.vaneControlOut to 
				actuator ::> guideVanes.vaneControlIn;
			
			interface : MechanicalDriveInterface connect 
				driver ::> runner.mechOut to 
				driven ::> shaft.mechIn;
			interface : MechanicalDriveInterface connect 
				driver ::> shaft.mechOut to 
				driven ::> generator.mechIn;
			
			bind generatorOutput = generator.generatorOutput;
		}
		
		part hydroTurbineSystem : HydroelectricTurbineSystem;
	}
	
	package RequirementModel {
		private import PhysicalModel::*;
		
		requirement powerOutputReq {
			subject system : HydroelectricTurbineSystem;
			require constraint { system.generatorOutput.power >= 40.0 }
		}
		requirement gridFreqReq {
			subject system : HydroelectricTurbineSystem;
			require constraint { system.generatorOutput.frequency == 60.0 }
		}
		requirement gridVoltageReq {
			subject system : HydroelectricTurbineSystem;
			require constraint { system.generatorOutput.voltage == 13.8 }
		}
		requirement efficiencyReq {
			subject system : HydroelectricTurbineSystem;
			require constraint { system.efficiency >= 0.88 }
		}
		requirement weightReq {
			subject system : HydroelectricTurbineSystem;
			require constraint { system.totalWeight <= 38000.0 }
		}
		
		satisfy powerOutputReq by hydroTurbineSystem;
		satisfy gridFreqReq by hydroTurbineSystem;
		satisfy gridVoltageReq by hydroTurbineSystem;
		satisfy efficiencyReq by hydroTurbineSystem;
		satisfy weightReq by hydroTurbineSystem;
	}
	
	package AllocationModel {
		private import LogicalModel::*;
		private import PhysicalModel::*;
		
		allocation def LogicalToPhysicalAllocation {
			end logical : ProvidePower;
			end physical : HydroelectricTurbineSystem;
		}
		
		allocation providePowerAlloc : LogicalToPhysicalAllocation 
			allocate logical ::> providePower to physical ::> hydroTurbineSystem {
			allocate providePower.distributeWater to hydroTurbineSystem.spiralCasing;
			allocate providePower.regulateFlow to hydroTurbineSystem.governorSystem;
			allocate providePower.regulateFlow to hydroTurbineSystem.guideVanes;
			allocate providePower.generateTorque to hydroTurbineSystem.runner;
			allocate providePower.dischargeWater to hydroTurbineSystem.draftTube;
			allocate providePower.transmitTorque to hydroTurbineSystem.shaft;
			allocate providePower.generateElectricity to hydroTurbineSystem.generator;
		}
	}
}
