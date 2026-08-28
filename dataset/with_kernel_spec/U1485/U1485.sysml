package 'Roots Supercharger System' {
	package Definitions {
		private import ISQ::*;
		private import ScalarValues::*;

		alias Torque for TorqueValue;
		alias Pressure for PressureValue;
		alias Temperature for TemperatureValue;
		alias Volume for VolumeValue;
		alias VolumeFlowRate for VolumeFlowRateValue;
		alias AngularSpeed for AngularVelocityValue;

		item def Air {
			attribute temperature : Temperature;
			attribute pressure : Pressure;
		}
		item def PressurizedAir {
			attribute temperature : Temperature;
			attribute pressure : Pressure;
		}
		item def CooledAir {
			attribute temperature : Temperature;
			attribute pressure : Pressure;
		}
		item def Oil {
			attribute temperature : Temperature;
			attribute pressure : Pressure;
		}
		item def Heat;

		attribute def EngineStart;
		attribute def EngineStop;

		port def DriveOutPort {
			out torque : Torque;
			out speed : AngularSpeed;
		}
		port def DriveInPort {
			in torque : Torque;
			in speed : AngularSpeed;
		}
		port def AirOutPort {
			out item air : Air;
		}
		port def AirInPort {
			in item air : Air;
		}
		port def PressurizedAirOutPort {
			out item air : PressurizedAir;
		}
		port def PressurizedAirInPort {
			in item air : PressurizedAir;
		}
		port def CooledAirOutPort {
			out item air : CooledAir;
		}
		port def CooledAirInPort {
			in item air : CooledAir;
		}
		port def OilOutPort {
			out item oil : Oil;
		}
		port def OilInPort {
			in item oil : Oil;
		}
		port def HeatOutPort {
			out item heat : Heat;
		}
		port def HeatInPort {
			in item heat : Heat;
		}

		part def Engine {
			port drivePort : DriveOutPort;
			port airIntakePort : CooledAirInPort;
			attribute cylinderCount : Integer = 6;
		}

		part def BeltAndPulley {
			port driveInPort : DriveInPort;
			port driveOutPort : DriveOutPort;
			attribute driveRatio : Real;
		}

		part def Rotor;
		part def MaleRotor :> Rotor {
			attribute lobeCount : Integer = 3;
		}
		part def FemaleRotor :> Rotor {
			attribute lobeCount : Integer = 3;
		}
		part def Bearing;
		part def FrontBearing :> Bearing;
		part def RearBearing :> Bearing;

		part def SealingSystem {
			attribute sealMaterial : String = "PTFE";
		}

		part def RotorAssembly {
			part maleRotor : MaleRotor;
			part femaleRotor : FemaleRotor;
			part frontBearing : FrontBearing;
			part rearBearing : RearBearing;
			attribute rotationalSpeed : AngularSpeed;
		}

		part def RootsSupercharger {
			port drivePort : DriveInPort;
			port airInPort : AirInPort;
			port airOutPort : PressurizedAirOutPort;
			port oilInPort : OilInPort;
			port oilOutPort : OilOutPort;
			part rotorAssembly : RotorAssembly;
			part sealingSystem : SealingSystem;
			attribute displacementVolume : Volume;
			attribute boostPressure : Pressure;
		}

		part def Intercooler {
			port airInPort : PressurizedAirInPort;
			port airOutPort : CooledAirOutPort;
			port heatOutPort : HeatOutPort;
			attribute efficiency : Real;
			attribute outletTemperature : Temperature;
		}

		part def IntakeManifold {
			port airInPort : CooledAirInPort;
			port airOutPort : CooledAirOutPort;
			attribute plenumVolume : Volume;
		}

		part def OilPump;
		part def OilReservoir;
		part def OilCooler;

		part def LubricationSystem {
			port oilOutPort : OilOutPort;
			port oilReturnPort : OilInPort;
			part pump : OilPump;
			part reservoir : OilReservoir;
			part cooler : OilCooler;
			attribute oilPressure : Pressure;
			attribute oilFlowRate : VolumeFlowRate;
		}

		action def 'Force Induction' {
			in driveTorque : Torque;
			in ambientAir : Air;
			out pressurizedAir : PressurizedAir;
		}
		action def 'Cool Pressurized Air' {
			in hotAir : PressurizedAir;
			out cooledAir : CooledAir;
			out wasteHeat : Heat;
		}
		action def 'Distribute Air' {
			in cooledAir : CooledAir;
			out distributedAir : CooledAir;
		}
		action def 'Circulate Oil' {
			out supplyOil : Oil;
			in returnOil : Oil;
		}
		action def 'Provide Forced Induction' {
			in driveTorque : Torque;
			in ambientAir : Air;
			out distributedAir : CooledAir;
			out returnOil : Oil;
		}

		requirement def BoostPerformance {
			doc /* The supercharger shall deliver a minimum boost pressure of 1.0 bar at rated engine speed. */
			attribute minBoostPressure : Pressure;
		}
		requirement def AirLeakagePrevention {
			doc /* The sealing system shall limit air leakage to less than 1 percent of displacement per rotation. */
			attribute maxLeakageRate : Real = 0.01;
		}
		requirement def OilContaminationPrevention {
			doc /* Seals shall prevent lubricating oil from entering the pressurized air stream. */
		}
		requirement def IntercoolerEfficiency {
			doc /* The intercooler shall reduce charge air temperature by at least 50 degrees Celsius. */
			attribute minTempDrop : Temperature;
		}
		requirement def LubricationContinuity {
			doc /* Bearings shall receive continuous oil supply at 2 to 5 bar pressure. */
			attribute minPressure : Pressure;
			attribute maxPressure : Pressure;
		}
	}

	package Usages {
		private import Definitions::*;

		part superchargerSystem {
			part ambientEnvironment {
				port airOutPort : AirOutPort;
				port heatSinkPort : HeatInPort;
			}

			part engine : Engine {
				port :>> drivePort;
				port :>> airIntakePort;
			}

			part beltAndPulley : BeltAndPulley {
				port :>> driveInPort;
				port :>> driveOutPort;
			}

			part supercharger : RootsSupercharger {
				port :>> drivePort;
				port :>> airInPort;
				port :>> airOutPort;
				port :>> oilInPort;
				port :>> oilOutPort;
				part :>> rotorAssembly {
					part :>> maleRotor;
					part :>> femaleRotor;
					part :>> frontBearing;
					part :>> rearBearing;
				}
				part :>> sealingSystem;
			}

			part intercooler : Intercooler {
				port :>> airInPort;
				port :>> airOutPort;
				port :>> heatOutPort;
			}

			part intakeManifold : IntakeManifold {
				port :>> airInPort;
				port :>> airOutPort;
			}

			part lubricationSystem : LubricationSystem {
				port :>> oilOutPort;
				port :>> oilReturnPort;
				part :>> pump;
				part :>> reservoir;
				part :>> cooler;
			}

			connect engine.drivePort to beltAndPulley.driveInPort;
			connect beltAndPulley.driveOutPort to supercharger.drivePort;

			flow of ambientAir : Air
				from ambientEnvironment.airOutPort.air to supercharger.airInPort.air;
			flow of pressurizedAir : PressurizedAir
				from supercharger.airOutPort.air to intercooler.airInPort.air;
			flow of cooledAir : CooledAir
				from intercooler.airOutPort.air to intakeManifold.airInPort.air;
			flow of distributedAir : CooledAir
				from intakeManifold.airOutPort.air to engine.airIntakePort.air;

			flow of wasteHeat : Heat
				from intercooler.heatOutPort.heat to ambientEnvironment.heatSinkPort.heat;

			flow of supplyOil : Oil
				from lubricationSystem.oilOutPort.oil to supercharger.oilInPort.oil;
			flow of returnOil : Oil
				from supercharger.oilOutPort.oil to lubricationSystem.oilReturnPort.oil;

			requirement boostReq : BoostPerformance;
			requirement sealReq : AirLeakagePrevention;
			requirement oilContamReq : OilContaminationPrevention;
			requirement intercoolerReq : IntercoolerEfficiency;
			requirement lubeReq : LubricationContinuity;

			satisfy boostReq by supercharger;
			satisfy sealReq by supercharger.sealingSystem;
			satisfy oilContamReq by supercharger.sealingSystem;
			satisfy intercoolerReq by intercooler;
			satisfy lubeReq by lubricationSystem;

			perform action 'provide forced induction' : 'Provide Forced Induction' {
				in driveTorque = engine.drivePort.torque;
				in ambientAir = ambientEnvironment.airOutPort.air;
				out distributedAir = engine.airIntakePort.air;
				out returnOil = lubricationSystem.oilReturnPort.oil;

				loop {
					accept startCmd : EngineStart;
					then action {
						action 'force induction' : 'Force Induction' {
							in driveTorque = 'provide forced induction'::driveTorque;
							in ambientAir = 'provide forced induction'::ambientAir;
							out pressurizedAir : PressurizedAir;
						}
						flow 'force induction'.pressurizedAir to 'cool pressurized air'.hotAir;
						action 'cool pressurized air' : 'Cool Pressurized Air' {
							in hotAir : PressurizedAir;
							out cooledAir : CooledAir;
							out wasteHeat : Heat;
						}
						flow 'cool pressurized air'.cooledAir to 'distribute air'.cooledAir;
						action 'distribute air' : 'Distribute Air' {
							in cooledAir : CooledAir;
							out distributedAir = 'provide forced induction'::distributedAir;
						}
						action 'circulate oil' : 'Circulate Oil' {
							out supplyOil : Oil;
							in returnOil = 'provide forced induction'::returnOil;
						}
					}
					then accept stopCmd : EngineStop;
				}
			}
		}
	}
}
