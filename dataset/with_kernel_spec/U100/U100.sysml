package 'Inflatable Penile Implant System' {
	package Definitions {
		private import ScalarValues::Real;
		private import ScalarValues::Boolean;
		private import ScalarValues::Integer;

		item def SterileSaline;

		port def FluidOutPort {
			out item fluid : SterileSaline;
		}
		port def FluidInPort {
			in item fluid : SterileSaline;
		}

		part def FluidReservoir {
			port supplyPort : FluidOutPort;
			port returnPort : FluidInPort;
			attribute maxVolume : Real = 100;
			attribute currentVolume : Real = 100;
		}

		part def ManualPump {
			port reservoirIntakePort : FluidInPort;
			port cylinderDeliveryPort : FluidOutPort;
			port cylinderReturnPort : FluidInPort;
			port reservoirReturnPort : FluidOutPort;
			attribute volumePerCompression : Real = 2;
			attribute maxOperatingPressure : Real = 180;
			attribute releaseValveOpen : Boolean = false;
			attribute squeezeCount : Integer = 0;
		}

		part def InflatableCylinder {
			port fillPort : FluidInPort;
			port drainPort : FluidOutPort;
			attribute maxVolume : Real = 25;
			attribute currentVolume : Real = 0;
			attribute currentPressure : Real = 0;
			attribute currentRigidity : Real = 0;
			attribute rigidityThreshold : Real = 0.85;
		}

		part def PenileImplantSystem {
			attribute maxOperatingPressure : Real = 180;
			attribute maxResidualCylinderVolume : Real = 2;
		}

		action def SqueezePump {
			in fluidIn : SterileSaline;
			out fluidOut : SterileSaline;
			attribute volumeTransferred : Real;
		}

		action def ActivateRelease {
			in fluidIn : SterileSaline;
			out fluidOut : SterileSaline;
			attribute volumeReturned : Real;
		}

		requirement def OnDemandErectileFunction {
			subject system : PenileImplantSystem;
		}

		requirement def PressureSafety {
			subject system : PenileImplantSystem;
			attribute pressureLimit : Real = 180;
		}

		requirement def CompleteReturnToFlaccid {
			subject system : PenileImplantSystem;
			attribute maxResidualVolume : Real = 2;
		}
	}

	package Usages {
		private import Definitions::*;

		part penileImplant : PenileImplantSystem {
			part reservoir : FluidReservoir;

			part pump : ManualPump {
				perform action squeeze : SqueezePump {
					in fluidIn = reservoirIntakePort.fluid;
					out fluidOut = cylinderDeliveryPort.fluid;
				}

				perform action release : ActivateRelease {
					in fluidIn = cylinderReturnPort.fluid;
					out fluidOut = reservoirReturnPort.fluid;
				}
			}

			part cylinders : InflatableCylinder[2];

			flow of fluid : SterileSaline
				from reservoir.supplyPort.fluid to pump.reservoirIntakePort.fluid;
			flow of fluid : SterileSaline
				from pump.cylinderDeliveryPort.fluid to cylinders.fillPort.fluid;
			flow of fluid : SterileSaline
				from cylinders.drainPort.fluid to pump.cylinderReturnPort.fluid;
			flow of fluid : SterileSaline
				from pump.reservoirReturnPort.fluid to reservoir.returnPort.fluid;

			exhibit state operation {
				initial;
				state flaccid;
				state inflating;
				state erect;
				state deflating;

				transition from initial to flaccid;
				transition from flaccid to inflating
					when pump.squeezeCount > 0;
				transition from inflating to erect
					when pump.squeezeCount >= 10;
				transition from erect to deflating
					when pump.releaseValveOpen;
				transition from deflating to flaccid
					when reservoir.currentVolume >= 90;
			}
		}

		requirement onDemandErectileReq : OnDemandErectileFunction {
			subject system = penileImplant;
		}
		requirement pressureSafetyReq : PressureSafety {
			subject system = penileImplant;
		}
		requirement returnToFlaccidReq : CompleteReturnToFlaccid {
			subject system = penileImplant;
		}

		satisfy onDemandErectileReq by penileImplant;
		satisfy pressureSafetyReq by penileImplant;
		satisfy returnToFlaccidReq by penileImplant;
	}
}
