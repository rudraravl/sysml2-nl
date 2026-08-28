package 'Dental Handpiece System' {
	private import ScalarValues::*;
	private import ISQ::*;
	import Definitions::*;

	package Definitions {
		attribute def RPM :> Real;

		item def CompressedAir;
		item def CoolingWater;
		item def ControlSignal;
		item def MechanicalPower {
			attribute speed : RPM;
			attribute torque : Real;
		}
		item def Burr;

		port def AirOutPort { out air : CompressedAir; }
		port def AirInPort { in air : CompressedAir; }
		port def WaterOutPort { out water : CoolingWater; }
		port def WaterInPort { in water : CoolingWater; }
		port def ControlOutPort { out signal : ControlSignal; }
		port def ControlInPort { in signal : ControlSignal; }
		port def MechanicalOutPort { out power : MechanicalPower; }
		port def MechanicalInPort { in power : MechanicalPower; }

		part def DentalHandpiece {
			port waterInPort : WaterInPort;
			exhibit state handpieceStates : HandpieceStates;
		}

		part def AirTurbine {
			attribute maxSpeed : RPM = 400000;
			port airSupplyPort : AirInPort;
			port mechanicalOutPort : MechanicalOutPort;
			perform action rotate : RotateBurr;
		}

		part def FootPedal {
			attribute depressionLevel : Real;
			port controlOutPort : ControlOutPort;
		}

		part def WaterDeliverySystem {
			attribute flowRate : Real;
			port waterSupplyPort : WaterOutPort;
			port controlInPort : ControlInPort;
			perform action spray : SprayWater;
		}

		part def BearingAssembly {
			port mechanicalInPort : MechanicalInPort;
			port mechanicalOutPort : MechanicalOutPort;
		}

		part def BurrChuck {
			port mechanicalInPort : MechanicalInPort;
			ref item burr : Burr;
		}

		part def ControlModule {
			port pedalInPort : ControlInPort;
			port airOutPort : AirOutPort;
			port waterOutPort : ControlOutPort;
			exhibit state controllerStates : ControllerStates;
		}

		action def RotateBurr {
			in air : CompressedAir;
			out power : MechanicalPower;
		}
		action def SprayWater {
			in signal : ControlSignal;
			out water : CoolingWater;
		}
		action def RegulateAirflow {
			in signal : ControlSignal;
			out air : CompressedAir;
		}
		action def StopAirflow {
			out air : CompressedAir;
		}

		state def HandpieceStates;
		state def ControllerStates;

		requirement def SpeedRequirement {
			doc /* The turbine must achieve up to 400,000 RPM. */
			attribute maxSpeed : RPM;
			constraint { maxSpeed >= 400000 }
		}
		requirement def CoolingRequirement {
			doc /* Cooling water must be sprayed when speed exceeds threshold. */
			attribute speedThreshold : RPM;
			constraint { speedThreshold > 0 }
		}
		requirement def SafetyInterlockRequirement {
			doc /* Operation must be prevented if cooling water supply is insufficient. */
			attribute waterSupplySufficient : Boolean;
			constraint { waterSupplySufficient == true }
		}
	}

	package Usages {
		private import Definitions::*;

		part handpiece : DentalHandpiece {
			part controlModule : ControlModule {
				exhibit state controllerStates : ControllerStates {
					entry; then standby;
					state standby;
					accept when handpiece.footPedal.depressionLevel > 0.0 and handpiece.waterDeliverySystem.flowRate > 0.0
						then operating;
					state operating {
						do action regulateAirflow : RegulateAirflow;
						do action sprayWater : SprayWater;
					}
					accept when handpiece.footPedal.depressionLevel == 0.0
						then shutdown;
					state shutdown {
						entry action stopAirflow : StopAirflow;
						then standby;
					}
				}
			}

			part footPedal : FootPedal {
				port controlOutPort {
					out signal : ControlSignal;
				}
			}

			part airTurbine : AirTurbine {
				port airSupplyPort {
					in air : CompressedAir;
				}
				port mechanicalOutPort {
					out power : MechanicalPower;
				}
			}

			part waterDeliverySystem : WaterDeliverySystem {
				port waterSupplyPort {
					out water : CoolingWater;
				}
				port controlInPort {
					in signal : ControlSignal;
				}
			}

			part bearingAssembly : BearingAssembly {
				port mechanicalInPort {
					in power : MechanicalPower;
				}
				port mechanicalOutPort {
					out power : MechanicalPower;
				}
			}

			part burrChuck : BurrChuck {
				port mechanicalInPort {
					in power : MechanicalPower;
				}
				ref burr : Burr;
			}

			flow airFlow of CompressedAir from controlModule.airOutPort.air to airTurbine.airSupplyPort.air;
			flow waterFlow of CoolingWater from waterDeliverySystem.waterSupplyPort.water to handpiece.waterInPort.water;
			flow controlFlow of ControlSignal from footPedal.controlOutPort.signal to controlModule.pedalInPort.signal;
			flow waterControlFlow of ControlSignal from controlModule.waterOutPort.signal to waterDeliverySystem.controlInPort.signal;
			flow mechanicalFlow1 of MechanicalPower from airTurbine.mechanicalOutPort.power to bearingAssembly.mechanicalInPort.power;
			flow mechanicalFlow2 of MechanicalPower from bearingAssembly.mechanicalOutPort.power to burrChuck.mechanicalInPort.power;
		}

		requirement speedReq : SpeedRequirement {
			attribute maxSpeed = 400000;
		}
		requirement coolingReq : CoolingRequirement {
			attribute speedThreshold = 10000;
		}
		requirement safetyReq : SafetyInterlockRequirement {
			attribute waterSupplySufficient = true;
		}
	}
}
