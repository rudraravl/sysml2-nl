package ChainPumpSystem {
	private import ScalarValues::Real;
	private import ScalarValues::Integer;
	private import ScalarValues::String;
	private import ISQ::*;

	item def Water;
	item def MechanicalPower;
	item def ElectricalPower;

	port def WaterPort {
		out item water : Water;
	}

	port def WaterPortIn {
		in item water : Water;
	}

	port def MechanicalPowerPort {
		out item power : MechanicalPower;
	}

	port def MechanicalPowerPortIn {
		in item power : MechanicalPower;
	}

	port def ElectricalPowerPort {
		out item power : ElectricalPower;
	}

	port def ElectricalPowerPortIn {
		in item power : ElectricalPower;
	}

	port def SealPort;

	part def ElectricMotor {
		port powerIn : ElectricalPowerPortIn;
		port shaftOut : MechanicalPowerPort;
		attribute ratedPower : Real;
		attribute ratedSpeed : Real;
	}

	part def GearReducer {
		port shaftIn : MechanicalPowerPortIn;
		port shaftOut : MechanicalPowerPort;
		attribute gearRatio : Real;
		attribute outputTorque : Real;
	}

	part def DriveSprocket {
		port shaftIn : MechanicalPowerPortIn;
		port chainOut : MechanicalPowerPort;
		attribute pitchRadius : Real;
		attribute toothCount : Integer;
	}

	part def Disk {
		attribute diameter : Real;
		attribute material : String = "Rubber";
	}

	part def ChainDiskAssembly {
		port driveIn : MechanicalPowerPortIn;
		port sealOut : SealPort;
		part disks : Disk[*];
		attribute diskSpacing : Real;
		attribute chainLength : Real;
		attribute chainSpeed : Real;
	}

	part def HousingTube {
		port waterIn : WaterPortIn;
		port waterOut : WaterPort;
		port sealInterface : ~SealPort;
		attribute innerDiameter : Real;
		attribute length : Real;
		attribute inclinationAngle : Real;
		attribute crossSectionArea : Real = 3.14159 * (innerDiameter / 2.0) * (innerDiameter / 2.0);
	}

	part def LowerReservoir {
		port waterOut : WaterPort;
		attribute waterLevel : Real;
		item water : Water;
	}

	part def DischargeSpout {
		port waterIn : WaterPortIn;
		port waterOut : WaterPort;
		attribute flowRate : Real;
	}

	part def ElectricDriveUnit {
		part motor : ElectricMotor;
		part gearReducer : GearReducer;
		part driveSprocket : DriveSprocket;
		flow of power : MechanicalPower
			from motor.shaftOut.power to gearReducer.shaftIn.power;
		flow of power : MechanicalPower
			from gearReducer.shaftOut.power to driveSprocket.shaftIn.power;
	}

	action def DriveChain {
		in power : MechanicalPower;
		out chainSpeed : Real;
	}

	action def LiftWater {
		in waterIn : Water;
		in chainSpeed : Real;
		out waterOut : Water;
		out liftedHeight : Real;
		out flowRate : Real;
	}

	action def PumpOperation {
		in power : ElectricalPower;
		in waterIn : Water;
		out waterOut : Water;
		out actualLiftHeight : Real;
		out actualFlowRate : Real;
		private attribute chainSpeed : Real;
		perform action drive : DriveChain {
			in power = power;
			out chainSpeed = chainSpeed;
		}
		perform action lift : LiftWater {
			in waterIn = waterIn;
			in chainSpeed = chainSpeed;
			out waterOut = waterOut;
			out liftedHeight = actualLiftHeight;
			out flowRate = actualFlowRate;
		}
	}

	part def ChainPumpSystem {
		port powerIn : ElectricalPowerPortIn;
		port waterOut : WaterPort;

		attribute liftHeight : Real;
		attribute flowRate : Real;
		attribute fluidViscosity : Real;

		part driveUnit : ElectricDriveUnit;
		part housingTube : HousingTube;
		part chainAssembly : ChainDiskAssembly;
		part lowerReservoir : LowerReservoir;
		part dischargeSpout : DischargeSpout;

		flow of power : MechanicalPower
			from driveUnit.driveSprocket.chainOut.power to chainAssembly.driveIn.power;
		connect chainAssembly.sealOut to housingTube.sealInterface;
		flow of water : Water
			from lowerReservoir.waterOut.water to housingTube.waterIn.water;
		flow of water : Water
			from housingTube.waterOut.water to dischargeSpout.waterIn.water;
		flow of water : Water
			from dischargeSpout.waterOut.water to waterOut.water;

		attribute chainLinearSpeed : Real = chainAssembly.chainSpeed;
		attribute tubeCrossSectionArea : Real = housingTube.crossSectionArea;
		attribute computedFlowRate : Real = chainLinearSpeed * tubeCrossSectionArea;

		state machine PumpStates {
			state Off;
			state Running;
			transition from Off to Running when powerIn.power > 0;
			transition from Running to Off when powerIn.power == 0;
		}
	}

	requirement <'REQ-001'> LiftHeightRequirement {
		doc /* The system shall lift water to a height of at least 10 meters. */
		subject pump : ChainPumpSystem;
		assert constraint {
			pump.liftHeight >= 10.0
		}
	}

	requirement <'REQ-002'> FlowRateRequirement {
		doc /* The system shall deliver a flow rate of at least 5 liters per second. */
		subject pump : ChainPumpSystem;
		assert constraint {
			pump.flowRate >= 5.0
		}
	}

	requirement <'REQ-003'> ContinuousOperationRequirement {
		doc /* The system shall be designed for continuous, reliable operation. */
		subject pump : ChainPumpSystem;
	}

	requirement <'REQ-004'> FluidCompatibilityRequirement {
		doc /* The system shall handle low-viscosity fluids, specifically water. */
		subject pump : ChainPumpSystem;
		assert constraint {
			pump.fluidViscosity <= 0.001
		}
	}

	package Usages {
		part context {
			attribute liftHeight : Real = 12.0;
			attribute flowRate : Real = 6.0;

			part powerSource {
				port powerOut : ElectricalPowerPort;
				item power : ElectricalPower;
			}

			part pumpSystem : ChainPumpSystem {
				attribute liftHeight = 12.0;
				attribute flowRate = 6.0;
				attribute fluidViscosity = 0.00089;

				part driveUnit : ElectricDriveUnit {
					part motor : ElectricMotor {
						attribute ratedPower = 1500.0;
						attribute ratedSpeed = 150.0;
					}
					part gearReducer : GearReducer {
						attribute gearRatio = 10.0;
					}
					part driveSprocket : DriveSprocket {
						attribute pitchRadius = 0.05;
						attribute toothCount = 12;
					}
				}

				part housingTube : HousingTube {
					attribute innerDiameter = 0.15;
					attribute length = 12.0;
					attribute inclinationAngle = 45.0;
				}

				part chainAssembly : ChainDiskAssembly {
					attribute diskSpacing = 0.2;
					attribute chainLength = 24.0;
					attribute chainSpeed = 0.5;
					part disks : Disk[120] {
						attribute diameter = 0.148;
					}
				}

				part lowerReservoir : LowerReservoir {
					attribute waterLevel = 2.0;
					item water : Water;
				}

				part dischargeSpout : DischargeSpout {
					attribute flowRate = 6.0;
				}
			}

			part destination {
				port waterIn : WaterPortIn;
			}

			flow of power : ElectricalPower
				from powerSource.powerOut.power to pumpSystem.powerIn.power;
			flow of water : Water
				from pumpSystem.waterOut.water to destination.waterIn.water;

			perform action operation : PumpOperation {
				in power = powerSource.power;
				in waterIn = pumpSystem.lowerReservoir.water;
				out waterOut;
				out actualLiftHeight = pumpSystem.liftHeight;
				out actualFlowRate = pumpSystem.flowRate;
			}

			satisfy LiftHeightRequirement by pumpSystem;
			satisfy FlowRateRequirement by pumpSystem;
			satisfy ContinuousOperationRequirement by pumpSystem;
			satisfy FluidCompatibilityRequirement by pumpSystem;
		}
	}
}
