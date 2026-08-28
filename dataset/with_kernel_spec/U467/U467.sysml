package 'Archimedes Screw Pump System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ScalarValues::String;
	private import ISQ::VolumeFlowRate;
	private import ISQ::Angle;
	private import ISQ::AngularVelocity;
	private import ISQ::Length;
	private import ISQ::Torque;
	private import SI::m;
	private import SI::deg;
	private import SI::N;
	private import SI::s;

	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		item def Water;
		item def WaterVolume {
			attribute volume : Real [m^3];
		}
		attribute def StartCommand;
		attribute def StopCommand;
		attribute def WaterLevelSignal {
			attribute sufficient : Boolean;
		}
		attribute def MotorSpeed {
			attribute angularVelocity : AngularVelocity;
		}

		port def WaterInPort {
			in item water : Water;
		}
		port def WaterOutPort {
			out item water : Water;
		}
		port def RotationalDrivePort {
			out torque : Torque;
			out speed : MotorSpeed;
		}
		port def CommandPort {
			in startCmd : StartCommand;
			in stopCmd : StopCommand;
		}
		port def WaterLevelPort {
			out signal : WaterLevelSignal;
		}

		part def LowerBasin {
			port waterOutPort : WaterOutPort;
			port levelPort : WaterLevelPort;
			attribute waterAvailable : Boolean = true;
		}
		part def UpperBasin {
			port waterInPort : WaterInPort;
		}
		part def ElectricMotor {
			port drivePort : RotationalDrivePort;
			port cmdPort : CommandPort;
			attribute ratedTorque : Torque;
		}
		part def HelicalBlade {
			attribute material : String = "Steel";
			attribute length : Length;
			attribute pitch : Length;
		}
		part def CentralShaft {
			attribute material : String = "Steel";
			attribute length : Length;
			attribute diameter : Length;
		}
		part def TubularHousing {
			attribute inclination : Angle = 30 [deg];
			attribute material : String = "Steel";
		}
		part def ScrewAssembly {
			port drivePort : ~RotationalDrivePort;
			port waterInPort : WaterInPort;
			port waterOutPort : WaterOutPort;
			part blade : HelicalBlade;
			part shaft : CentralShaft;
			part housing : TubularHousing;
		}
		part def Controller {
			port cmdPort : CommandPort;
			port levelPort : ~WaterLevelPort;
			port motorCmdPort : CommandPort;
		}

		action def ScoopWater {
			in item waterIn : Water;
			out item waterTrapped : Water;
		}
		action def LiftWater {
			in item waterTrapped : Water;
			out item waterLifted : Water;
		}
		action def DischargeWater {
			in item waterLifted : Water;
			out item waterOut : Water;
		}
		action def PumpWater {
			in item waterIn : Water;
			out item waterOut : Water;
		}

		state def ControllerStates {
			initial state idle;
			state starting;
			state accelerating;
			state operating;
			state stopping;
			transition first idle then starting accept startCmd : StartCommand;
			transition first starting then accelerating;
			transition first accelerating then operating;
			transition first operating then stopping accept stopCmd : StopCommand;
			transition first stopping then idle;
		}

		requirement def MinFlowRateRequirement {
			doc "The system shall lift water at a minimum flow rate of 0.1 cubic meters per second.";
			assert constraint { flowRate >= 0.1 [m^3/s] }
			attribute flowRate : VolumeFlowRate;
		}
		requirement def ContinuousOperationRequirement {
			doc "The system shall operate continuously as long as sufficient water is available in the lower basin.";
		}
		requirement def InclinationRequirement {
			doc "The screw assembly shall be set at a fixed inclination of 30 degrees.";
			assert constraint { inclination == 30 [deg] }
			attribute inclination : Angle;
		}
	}

	package Usages {
		part screwPumpSystem {
			requirement minFlowReq : MinFlowRateRequirement {
				attribute flowRate = 0.1 [m^3/s];
			}
			requirement continuousOpReq : ContinuousOperationRequirement;
			requirement inclinationReq : InclinationRequirement {
				attribute inclination = 30 [deg];
			}

			part lowerBasin : LowerBasin {
				perform action provideWater {
					out item water : Water;
				}
			}
			part upperBasin : UpperBasin;

			part motor : ElectricMotor {
				attribute ratedTorque = 500 [N*m];
			}

			part screwAssembly : ScrewAssembly {
				part :>> blade : HelicalBlade {
					attribute length = 6 [m];
					attribute pitch = 1.5 [m];
				}
				part :>> shaft : CentralShaft {
					attribute length = 6 [m];
					attribute diameter = 0.3 [m];
				}
				part :>> housing : TubularHousing {
					attribute inclination = 30 [deg];
				}

				perform action pumpWater : PumpWater {
					in item waterIn : Water;
					out item waterOut : Water;

					action scoopWater : ScoopWater {
						in item waterIn = pumpWater.waterIn;
						out item waterTrapped : Water;
					}
					flow scoopWater.waterTrapped to liftWater.waterTrapped;
					action liftWater : LiftWater {
						in item waterTrapped : Water;
						out item waterLifted : Water;
					}
					flow liftWater.waterLifted to dischargeWater.waterLifted;
					action dischargeWater : DischargeWater {
						in item waterLifted : Water;
						out item waterOut = pumpWater.waterOut;
					}
				}
			}

			part controller : Controller {
				exhibit state stateMachine : ControllerStates;
			}

			interface waterIntakeInterface
				connect lowerBasin.waterOutPort to screwAssembly.waterInPort {
					flow waterFlow of Water
						from lowerBasin.waterOutPort.water to screwAssembly.waterInPort.water;
				}
			interface waterDischargeInterface
				connect screwAssembly.waterOutPort to upperBasin.waterInPort {
					flow waterFlow of Water
						from screwAssembly.waterOutPort.water to upperBasin.waterInPort.water;
				}
			interface driveInterface
				connect motor.drivePort to screwAssembly.drivePort {
					flow torqueFlow of Torque
						from motor.drivePort.torque to screwAssembly.drivePort.torque;
					flow speedFlow of MotorSpeed
						from motor.drivePort.speed to screwAssembly.drivePort.speed;
				}
			interface motorCommandInterface
				connect controller.motorCmdPort to motor.cmdPort {
					flow startCmdFlow of StartCommand
						from controller.motorCmdPort.startCmd to motor.cmdPort.startCmd;
					flow stopCmdFlow of StopCommand
						from controller.motorCmdPort.stopCmd to motor.cmdPort.stopCmd;
				}
			interface waterLevelInterface
				connect lowerBasin.levelPort to controller.levelPort {
					flow levelSignalFlow of WaterLevelSignal
						from lowerBasin.levelPort.signal to controller.levelPort.signal;
				}
		}
	}
}
