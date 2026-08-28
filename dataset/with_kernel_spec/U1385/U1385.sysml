package 'Bicycle Pump System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	package Definitions {
		item def Air {
			attribute pressure : PressureValue;
			attribute temperature : TemperatureValue;
		}

		port def AirOutPort {
			out item air : Air;
		}

		port def AirInPort {
			in item air : Air;
		}

		port def MechanicalPort {
			in displacement : LengthValue;
			out force : ForceValue;
		}

		attribute def 'Start Pumping';
		attribute def 'Handle Pushed Down';
		attribute def 'Handle Pulled Up';
		attribute def 'Stop Pumping';
		attribute def 'Pressure Differential';
		attribute def 'Pressure Equalized';

		part def Atmosphere {
			attribute ambientPressure : PressureValue = 101.325[kPa];
			port airOutPort : AirOutPort;
		}

		part def InflatableTarget {
			attribute targetPressure : PressureValue;
			port airInPort : AirInPort;
		}

		part def Handle {
			port pistonInterface : MechanicalPort;
			attribute appliedForce : ForceValue;
			attribute strokeLength : LengthValue;
		}

		part def Piston {
			port handleInterface : ~MechanicalPort;
			port cylinderInterface : MechanicalPort;
			attribute position : LengthValue;
		}

		part def Cylinder {
			port pistonInterface : ~MechanicalPort;
			port intakePort : AirInPort;
			port outletPort : AirOutPort;
			attribute chamberVolume : VolumeValue;
			attribute chamberPressure : PressureValue;
		}

		part def CheckValve {
			attribute isOpen : Boolean = false;
			port inletPort : AirInPort;
			port outletPort : AirOutPort;
			exhibit state valveStates : ValveStates;
		}

		part def IntakeValve :> CheckValve;
		part def OutletValve :> CheckValve;

		part def Hose {
			port inletPort : AirInPort;
			port outletPort : AirOutPort;
			attribute hosePressure : PressureValue;
		}

		part def Pump {
			port extIntakePort : AirInPort;
			port extOutletPort : AirOutPort;

			part handle : Handle;
			part piston : Piston;
			part cylinder : Cylinder;
			part intakeValve : IntakeValve;
			part outletValve : OutletValve;
			part hose : Hose;

			connector handleToPiston connect handle.pistonInterface to piston.handleInterface;
			connector pistonToCylinder connect piston.cylinderInterface to cylinder.pistonInterface;
			connector extIntakeConnect connect extIntakePort to intakeValve.inletPort;
			connector intakeToCylinder connect intakeValve.outletPort to cylinder.intakePort;
			connector cylinderToOutlet connect cylinder.outletPort to outletValve.inletPort;
			connector outletToHose connect outletValve.outletPort to hose.inletPort;
			connector hoseToExtOutlet connect hose.outletPort to extOutletPort;

			perform action pumpCycle : PumpCycle;
			exhibit state pumpStates : PumpStates;
		}

		action def PumpCycle {
			in airIn : Air;
			out airOut : Air;
			action upstroke {
				doc /* Draws atmospheric air into the chamber through the intake valve. */
			}
			action downstroke {
				doc /* Compresses trapped air and expels it through the outlet valve. */
			}
			succession first upstroke then downstroke;
			succession first downstroke then upstroke;
		}

		state def PumpStates {
			state idle;
			state upstroke {
				doc /* Handle is pulled up, intake valve opens, air enters chamber. */
			}
			state downstroke {
				doc /* Handle is pushed down, intake valve closes, outlet valve opens. */
			}
			transition startUpstroke
				first idle
				accept 'Start Pumping'
				then upstroke;
			transition upToDown
				first upstroke
				accept 'Handle Pushed Down'
				then downstroke;
			transition downToUp
				first downstroke
				accept 'Handle Pulled Up'
				then upstroke;
			transition stopPumping
				first downstroke
				accept 'Stop Pumping'
				then idle;
		}

		state def ValveStates {
			state closed;
			state open;
			transition openValve
				first closed
				accept 'Pressure Differential'
				then open;
			transition closeValve
				first open
				accept 'Pressure Equalized'
				then closed;
		}

		requirement def <'1'> DeliveryPressureRequirement {
			doc /* The pump shall deliver air at a pressure of at least 400 kPa. */
			subject pump : Pump;
			attribute minPressure : PressureValue = 400[kPa];
			require constraint { pump.extOutletPort.air.pressure >= minPressure }
		}

		requirement def <'2'> ValveInterlockRequirement {
			doc /* The intake and outlet valves must never be open at the same time. */
			subject pump : Pump;
			require constraint { not (pump.intakeValve.isOpen and pump.outletValve.isOpen) }
		}

		requirement def <'3'> CompressionEfficiencyRequirement {
			doc /* The chamber pressure during downstroke shall exceed the hose pressure to open the outlet valve. */
			subject pump : Pump;
			require constraint { pump.cylinder.chamberPressure > pump.hose.hosePressure }
		}
	}

	package Usages {
		private import Definitions::*;

		part context {
			part atmosphere : Atmosphere;
			part pump : Pump;
			part target : InflatableTarget;

			flow of air : Air
				from atmosphere.airOutPort.air to pump.extIntakePort.air;

			flow of air : Air
				from pump.extOutletPort.air to target.airInPort.air;

			satisfy DeliveryPressureRequirement by pump;
			satisfy ValveInterlockRequirement by pump;
			satisfy CompressionEfficiencyRequirement by pump;
		}
	}
}
