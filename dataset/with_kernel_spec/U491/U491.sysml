package 'CycloidalDrive' {
	private import ISQ::*;
	private import ScalarValues::*;
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		alias Torque for ISQ::TorqueValue;
		alias AngularVelocity for ISQ::AngularVelocityValue;
		alias Temperature for ISQ::TemperatureValue;

		item def Oil;
		item def MechanicalPower {
			attribute torque : Torque;
			attribute angularVelocity : AngularVelocity;
		}

		port def MechanicalPort {
			out item power : MechanicalPower;
		}

		port def OilPort {
			out item oil : Oil;
		}

		part def InputShaft {
			port input : ~MechanicalPort;
			port output : MechanicalPort;
		}

		part def EccentricDisc {
			port input : ~MechanicalPort;
			port output : MechanicalPort;
		}

		part def PinRing;

		part def Housing {
			part pinRing : PinRing;
			port oilIn : ~OilPort;
			port oilOut : OilPort;
		}

		part def CycloidalGear {
			port input : ~MechanicalPort;
			port output : MechanicalPort;
		}

		part def OutputShaft {
			port input : ~MechanicalPort;
			port output : MechanicalPort;
		}

		part def BearingAssembly {
			port oilIn : ~OilPort;
			port oilOut : OilPort;
		}

		part def LubricationSystem {
			port oilOut : OilPort;
		}

		part def CycloidalDrive {
			port inputPort : ~MechanicalPort;
			port outputPort : MechanicalPort;
			exhibit state operationalStates : OperationalStates;
			exhibit state healthStates : HealthStates;
			perform action reduceSpeed : ReduceSpeed;
			attribute maxTemp : Temperature = 353.15;
			attribute maxTorque : Torque = 150.0;
		}

		action def ReduceSpeed {
			in inputPower : MechanicalPower;
			out outputPower : MechanicalPower;
		}

		action def MonitorSystem {
			out temp : Temperature;
			out torque : Torque;
		}

		state def OperationalStates;
		state def HealthStates;

		attribute def StartCmd;
		attribute def StopCmd;
		attribute def OverloadFault;
		attribute def OverheatFault;
		attribute def ResetCmd;

		requirement def HighPrecision {
			doc /* The reducer shall achieve positioning accuracy within 1 arc-minute. */
		}
		requirement def HighTorque {
			doc /* The reducer shall provide output torque of at least 100 N*m. */
		}
		requirement def LargeReductionRatio {
			doc /* The reduction ratio shall be at least 50:1. */
		}
		requirement def CompactSize {
			doc /* The reducer shall fit within a 200 mm diameter cylindrical envelope. */
		}
		requirement def LubricationRequirement {
			doc /* The system shall include a lubrication system to reduce friction and wear. */
		}
	}

	package Usages {
		private import Definitions::*;

		part cycloidalDrive : CycloidalDrive {
			part inputShaft : InputShaft;
			part eccentricDisc : EccentricDisc;
			part housing : Housing;
			part cycloidalGear : CycloidalGear;
			part outputShaft : OutputShaft;
			part inputBearing : BearingAssembly;
			part outputBearing : BearingAssembly;
			part lubricationSystem : LubricationSystem;

			flow of MechanicalPower from inputPort.power to inputShaft.input.power;
			flow of MechanicalPower from inputShaft.output.power to eccentricDisc.input.power;
			flow of MechanicalPower from eccentricDisc.output.power to cycloidalGear.input.power;
			flow of MechanicalPower from cycloidalGear.output.power to outputShaft.input.power;
			flow of MechanicalPower from outputShaft.output.power to outputPort.power;

			flow of oil : Oil from lubricationSystem.oilOut.oil to housing.oilIn.oil;
			flow of oil : Oil from lubricationSystem.oilOut.oil to inputBearing.oilIn.oil;
			flow of oil : Oil from lubricationSystem.oilOut.oil to outputBearing.oilIn.oil;

			action reduceSpeed : ReduceSpeed {
				in inputPower = inputPort.power;
				out outputPower = outputPort.power;
			}

			action monitorSystem : MonitorSystem;

			state operationalStates : OperationalStates {
				entry; then idle;
				state idle;
				accept StartCmd then running;
				state running {
					do reduceSpeed;
				}
				accept StopCmd then idle;
				accept OverloadFault then overload;
				accept OverheatFault then overload;
				state overload;
				accept ResetCmd then idle;
			}

			state healthStates : HealthStates {
				entry; then normal;
				do monitorSystem;
				state normal;
				accept when monitorSystem.temp > cycloidalDrive.maxTemp
					do send new OverheatFault() to cycloidalDrive
					then degraded;
				accept when monitorSystem.torque > cycloidalDrive.maxTorque
					do send new OverloadFault() to cycloidalDrive
					then degraded;
				state degraded;
				accept ResetCmd then normal;
			}
		}

		requirement highPrecision : HighPrecision;
		requirement highTorque : HighTorque;
		requirement largeReductionRatio : LargeReductionRatio;
		requirement compactSize : CompactSize;
		requirement lubricationRequirement : LubricationRequirement;

		satisfy highPrecision by cycloidalDrive;
		satisfy highTorque by cycloidalDrive;
		satisfy largeReductionRatio by cycloidalDrive;
		satisfy compactSize by cycloidalDrive;
		satisfy lubricationRequirement by cycloidalDrive.lubricationSystem;
	}
}
