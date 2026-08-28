package 'Taccola Hydraulic System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	package Definitions {
		item def Water {
			attribute volume : ISQ::VolumeValue;
		}

		attribute def Volume :> ISQ::VolumeValue;
		attribute def FlowRate :> ISQ::VolumeFlowRateValue;
		attribute def Torque :> ISQ::TorqueValue;
		attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
		attribute def LinearPosition :> ISQ::LengthValue;

		attribute def WaterAvailable;
		attribute def ReservoirFull;
		attribute def ReservoirEmpty;

		port def WaterPort {
			out item water : Water;
		}

		port def TorquePort {
			out torque : Torque;
			out speed : RotationalSpeed;
		}

		port def LinearMotionPort {
			out position : LinearPosition;
		}

		part def UpperReservoir {
			attribute capacity : Volume = 10.0 [m^3];
			attribute currentLevel : Volume;
			attribute fullThreshold : Volume = 8.0 [m^3];
			attribute emptyThreshold : Volume = 0.0 [m^3];
			port waterInPort : ~WaterPort;
			port waterOutPort : WaterPort;
		}

		part def Siphon {
			attribute triggerLevel : Volume = 8.0 [m^3];
			port waterInPort : ~WaterPort;
			port waterOutPort : WaterPort;
		}

		part def WaterWheel {
			port waterInPort : ~WaterPort;
			port torqueOutPort : TorquePort;
		}

		part def AxleShaft {
			port torqueInPort : ~TorquePort;
			port torqueOutPort : TorquePort;
		}

		part def CrankMechanism {
			port torqueInPort : ~TorquePort;
			port motionOutPort : LinearMotionPort;
		}

		part def PumpingBellows {
			port motionInPort : ~LinearMotionPort;
			port waterInPort : ~WaterPort;
			port waterOutPort : WaterPort;
		}

		part def WaterSource {
			port waterOutPort : WaterPort;
		}

		part def ElevatedDestination {
			port waterInPort : ~WaterPort;
		}

		part def TaccolaSystem {
			part upperReservoir : UpperReservoir;
			part siphon : Siphon;
			part waterWheel : WaterWheel;
			part axleShaft : AxleShaft;
			part crankMechanism : CrankMechanism;
			part pumpingBellows : PumpingBellows;

			port drivingWaterIn : ~WaterPort;
			port lowerSourceWaterIn : ~WaterPort;
			port destinationWaterOut : WaterPort;
		}

		action def CollectWater {
			in water : Water;
			out reservoirWater : Water;
		}

		action def TriggerSiphon {
			in reservoirWater : Water;
			out siphonWater : Water;
		}

		action def DriveWheel {
			in siphonWater : Water;
			out torque : Torque;
			out speed : RotationalSpeed;
		}

		action def TransferRotation {
			in torqueIn : Torque;
			in speedIn : RotationalSpeed;
			out torqueOut : Torque;
			out speedOut : RotationalSpeed;
		}

		action def ConvertToLinearMotion {
			in torque : Torque;
			in speed : RotationalSpeed;
			out position : LinearPosition;
		}

		action def PumpWater {
			in position : LinearPosition;
			in sourceWater : Water;
			out pumpedWater : Water;
		}

		action def OperateSystem {
			in drivingWater : Water;
			in lowerSourceWater : Water;
			out pumpedWater : Water;

			action collectWater : CollectWater;
			action triggerSiphon : TriggerSiphon;
			action driveWheel : DriveWheel;
			action transferRotation : TransferRotation;
			action convertMotion : ConvertToLinearMotion;
			action pumpWater : PumpWater;

			first start;
			then collectWater;
			then triggerSiphon;
			then driveWheel;
			then transferRotation;
			then convertMotion;
			then pumpWater;
			then done;
		}

		state def SystemStates {
			entry; then idle;
			state idle;
			transition idle_to_filling
				first idle
				accept WaterAvailable
				then filling;
			state filling;
			transition filling_to_overflowing
				first filling
				accept ReservoirFull
				then overflowing_operating;
			state overflowing_operating;
			transition overflowing_to_filling
				first overflowing_operating
				accept ReservoirEmpty
				then filling;
		}

		requirement SelfRegulatingCycle {
			doc /* The system must operate continuously without external power or manual intervention. */
			subject system : TaccolaSystem;
			require constraint {
				system.upperReservoir.currentLevel >= 0.0 [m^3]
			}
		}

		requirement GravityPowered {
			doc /* The system must utilize only gravitational potential energy and water flow. */
			subject system : TaccolaSystem;
		}

		requirement SiphonTrigger {
			doc /* The siphon must activate automatically when the reservoir reaches a predetermined level. */
			subject siphon : Siphon;
			require constraint {
				siphon.triggerLevel > 0.0 [m^3]
			}
		}
	}

	public import Definitions::*;

	package Usages {
		private import Definitions::*;

		part taccolaSystem : TaccolaSystem {
			exhibit state systemStates : SystemStates;

			flow of water : Water
				from drivingWaterIn.water to upperReservoir.waterInPort.water;

			part upperReservoir : UpperReservoir {
				perform action collectWater : CollectWater {
					in water = waterInPort.water;
					out reservoirWater = waterOutPort.water;
				}
			}

			flow of water : Water
				from upperReservoir.waterOutPort.water to siphon.waterInPort.water;

			part siphon : Siphon {
				perform action triggerSiphon : TriggerSiphon {
					in reservoirWater = waterInPort.water;
					out siphonWater = waterOutPort.water;
				}
			}

			flow of water : Water
				from siphon.waterOutPort.water to waterWheel.waterInPort.water;

			part waterWheel : WaterWheel {
				perform action driveWheel : DriveWheel {
					in siphonWater = waterInPort.water;
					out torque = torqueOutPort.torque;
					out speed = torqueOutPort.speed;
				}
			}

			flow of torque : Torque
				from waterWheel.torqueOutPort.torque to axleShaft.torqueInPort.torque;
			flow of speed : RotationalSpeed
				from waterWheel.torqueOutPort.speed to axleShaft.torqueInPort.speed;

			part axleShaft : AxleShaft {
				perform action transferRotation : TransferRotation {
					in torqueIn = torqueInPort.torque;
					in speedIn = torqueInPort.speed;
					out torqueOut = torqueOutPort.torque;
					out speedOut = torqueOutPort.speed;
				}
			}

			flow of torque : Torque
				from axleShaft.torqueOutPort.torque to crankMechanism.torqueInPort.torque;
			flow of speed : RotationalSpeed
				from axleShaft.torqueOutPort.speed to crankMechanism.torqueInPort.speed;

			part crankMechanism : CrankMechanism {
				perform action convertMotion : ConvertToLinearMotion {
					in torque = torqueInPort.torque;
					in speed = torqueInPort.speed;
					out position = motionOutPort.position;
				}
			}

			flow of position : LinearPosition
				from crankMechanism.motionOutPort.position to pumpingBellows.motionInPort.position;

			part pumpingBellows : PumpingBellows {
				perform action pumpWater : PumpWater {
					in position = motionInPort.position;
					in sourceWater = waterInPort.water;
					out pumpedWater = waterOutPort.water;
				}
			}

			flow of water : Water
				from lowerSourceWaterIn.water to pumpingBellows.waterInPort.water;

			flow of water : Water
				from pumpingBellows.waterOutPort.water to destinationWaterOut.water;

			perform action operateSystem : OperateSystem {
				in drivingWater = drivingWaterIn.water;
				in lowerSourceWater = lowerSourceWaterIn.water;
				out pumpedWater = destinationWaterOut.water;
			}
		}

		satisfy SelfRegulatingCycle by taccolaSystem;
		satisfy GravityPowered by taccolaSystem;
		satisfy SiphonTrigger by taccolaSystem.siphon;

		part taccolaPumpingStation {
			part drivingWaterSource : WaterSource;
			part lowerWaterSource : WaterSource;
			part elevatedDestination : ElevatedDestination;

			part engine : TaccolaSystem;

			flow of water : Water
				from drivingWaterSource.waterOutPort.water to engine.drivingWaterIn.water;
			flow of water : Water
				from lowerWaterSource.waterOutPort.water to engine.lowerSourceWaterIn.water;
			flow of water : Water
				from engine.destinationWaterOut.water to elevatedDestination.waterInPort.water;
		}
	}
}
