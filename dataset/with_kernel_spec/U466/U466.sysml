package 'Mechanical Dispensing System' {
	private import ISQ::PressureValue;
	private import ISQ::VolumeValue;
	private import ISQ::ForceValue;
	private import ISQ::LengthValue;
	private import ISQ::AngleValue;
	private import ScalarValues::Real;
	private import ScalarValues::Integer;
	private import ScalarValues::Boolean;
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		item def LiquidProduct;
		attribute def TriggerSignal;
		attribute def ReleaseSignal;

		value type Pressure :> PressureValue;
		value type Volume :> VolumeValue;
		value type Force :> ForceValue;
		value type Length :> LengthValue;
		value type DropletSize :> Length;
		value type SprayAngle :> AngleValue;

		port def FluidPort {
			inout item product : LiquidProduct;
			attribute pressure : Pressure;
		}
		port def MechanicalPort {
			attribute force : Force;
		}

		part def ProductReservoir {
			port productOut : FluidPort;
			attribute capacity : Volume := 500.0;
			attribute fillLevel : Real := 0.8;
			attribute isFull : Boolean = fillLevel >= 0.95;
			attribute isLow : Boolean = fillLevel <= 0.15;
		}
		part def Actuator {
			port mechOut : MechanicalPort;
			attribute actuated : Boolean := false;
			attribute appliedForce : Force := 5.0;
		}
		part def PumpAssembly {
			port productIn : FluidPort;
			port mechIn : MechanicalPort;
			port productOut : FluidPort;
			attribute chamberVolume : Volume := 2.0;
			attribute chamberPressure : Pressure := 0.0;
			attribute strokeCount : Integer := 0;
			attribute maxStrokes : Integer := 1000;
		}
		part def ValveSystem {
			port valveIn : FluidPort;
			port valveOut : FluidPort;
			attribute open : Boolean := false;
			attribute openingThreshold : Pressure := 100000.0;
		}
		part def NozzleAssembly {
			port nozzleIn : FluidPort;
			port sprayOut : FluidPort;
			attribute orificeDiameter : Length := 0.5;
			attribute sprayAngle : SprayAngle := 60.0;
			attribute dropletSize : DropletSize := 50.0;
		}

		action def ActuatePump {
			in force : Force;
			out mechWork : Force;
		}
		action def Intake {
			in product : LiquidProduct;
			out chamberProduct : LiquidProduct;
		}
		action def Compress {
			in chamberProduct : LiquidProduct;
			out pressurized : LiquidProduct;
			out pressure : Pressure;
		}
		action def Discharge {
			in pressurized : LiquidProduct;
			out dispensed : LiquidProduct;
		}
		action def ControlFlow {
			in product : LiquidProduct;
			in pressure : Pressure;
			out product : LiquidProduct;
		}
		action def Atomize {
			in liquid : LiquidProduct;
			out spray : LiquidProduct;
		}
		action def PumpCycle {
			in product : LiquidProduct;
			out dispensed : LiquidProduct;
		}

		requirement def DispensePreciseDose {
			doc
			/*
			 * The system shall dispense a precise, controlled dose of
			 * liquid product per actuation.
			 */
		}
		requirement def AtomizeSpray {
			doc
			/*
			 * The nozzle shall atomize the dispensed liquid into a fine
			 * mist of droplets within the specified droplet size.
			 */
		}
		requirement def PreventBackflow {
			doc
			/*
			 * The valve shall prevent backflow of liquid when the pump
			 * pressure drops below the opening threshold.
			 */
		}
		requirement def IndicateProductLevel {
			doc
			/*
			 * The system shall indicate whether the product reservoir is
			 * full, at a normal level, or running low.
			 */
		}
		requirement def SustainPumpStrokes {
			doc
			/*
			 * The pump assembly shall be capable of operating for a
			 * defined number of strokes, including priming operations.
			 */
		}
	}

	package Usages {
		part dispensingSystem {
			satisfy DispensePreciseDose;
			satisfy AtomizeSpray;
			satisfy PreventBackflow;
			satisfy IndicateProductLevel;
			satisfy SustainPumpStrokes;

			part reservoir : ProductReservoir;
			part actuator : Actuator {
				perform action actuatePump : ActuatePump {
					in force = appliedForce;
					out mechWork = mechOut.force;
				}
			}
			part pump : PumpAssembly;
			part valve : ValveSystem;
			part nozzle : NozzleAssembly;

			flow reservoir.productOut.product to pump.productIn.product;
			flow actuator.mechOut.force to pump.mechIn.force;
			flow pump.productOut.product to valve.valveIn.product;
			flow valve.valveOut.product to nozzle.nozzleIn.product;

			state dispensing {
				state idle;
				accept TriggerSignal then actuating;
				state actuating {
					entry assign pump.strokeCount := pump.strokeCount + 1;
				}
				then intake;
				state intake {
					entry assign pump.chamberPressure := 0.0;
				}
				then compression;
				state compression {
					entry assign pump.chamberPressure := 200000.0;
				}
				then discharge;
				state discharge {
					entry assign valve.open := pump.chamberPressure >= valve.openingThreshold;
					exit assign valve.open := false;
				}
				then idle;
			}
		}
	}
}
