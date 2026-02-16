package 'Gas Lift System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def GasInjectionRate :> ISQ::VolumeFlowRateValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeFlowRateUnit;
	}

	attribute def OilProductionRate :> ISQ::VolumeFlowRateValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeFlowRateUnit;
	}

	attribute def WellDepth :> ISQ::LengthValue {
		attribute :>> num : Real;
		attribute :>> mRef : LengthUnit;
	}

	attribute def ReservoirPressure :> ISQ::PressureValue {
		attribute :>> num : Real;
		attribute :>> mRef : PressureUnit;
	}

	attribute def FluidDensity :> ISQ::DensityValue {
		attribute :>> num : Real;
		attribute :>> mRef : DensityUnit;
	}

	item def CompressedGas;
	item def ReservoirFluid;
	item def AeratedFluid;

	port def GasSupplyPort {
		out gasFlow : GasInjectionRate;
		out gasPressure : ISQ::PressureValue;
	}

	port def ProductionPort {
		out oilFlow : OilProductionRate;
		out gasFlow : GasInjectionRate;
	}

	port def AnnulusPort {
		in gasFlow : GasInjectionRate;
		in gasPressure : ISQ::PressureValue;
	}

	port def InjectionPort {
		out gasFlow : GasInjectionRate;
	}

	part def GasCompressor {
		doc /* Compresses low-pressure gas to high-pressure for injection into the well annulus. */
		
		port gasInlet {
			in gasFlow : GasInjectionRate;
			in inletPressure : ISQ::PressureValue;
		}
		port gasOutlet : GasSupplyPort;

		attribute compressionRatio : Real;
		attribute efficiency : Real;
		attribute powerConsumption : ISQ::PowerValue;
		attribute dischargePressure : ISQ::PressureValue;
	}

	part def GasLiftValve {
		doc /* Controls gas injection from annulus into production tubing at specific depth. */
		
		port annulusInput : AnnulusPort;
		port injectionOutput : InjectionPort;

		attribute openingPressure : ISQ::PressureValue;
		attribute orificeSize : ISQ::AreaValue;
		attribute depth : WellDepth;
		attribute isOpen : Boolean;
		attribute currentAnnulusPressure : ISQ::PressureValue;

		exhibit state valveStateMachine {
			entry; then closed;
			
			state closed;
			state open;

			transition closedToOpen
				first closed
				accept when currentAnnulusPressure >= openingPressure
				then open;

			transition openToClosed
				first open
				accept when currentAnnulusPressure < openingPressure
				then closed;
		}
	}

	part def ProductionTubing {
		doc /* Conduit for lifting aerated fluid from reservoir to surface. */
		
		port tubingInlet {
			in oilFlow : OilProductionRate;
			in gasFlow : GasInjectionRate;
		}
		port tubingOutlet : ProductionPort;

		attribute innerDiameter : ISQ::LengthValue;
		attribute length : WellDepth;
		attribute roughness : ISQ::LengthValue;
	}

	part def Annulus {
		doc /* Annular space between casing and tubing for gas distribution. */
		
		port annulusTop {
			in gasSupply : GasInjectionRate;
			in supplyPressure : ISQ::PressureValue;
		}
		port annulusBottom {
			out gasFlow : GasInjectionRate;
			out annulusPressure : ISQ::PressureValue;
		}

		attribute outerDiameter : ISQ::LengthValue;
		attribute innerDiameter : ISQ::LengthValue;
		attribute depth : WellDepth;
	}

	part def Reservoir {
		doc /* Subsurface formation containing oil and gas. */
		
		port reservoirOutlet {
			out oilFlow : OilProductionRate;
			out reservoirPressure : ReservoirPressure;
		}

		attribute pressure : ReservoirPressure;
		attribute permeability : Real;
		attribute porosity : Real;
		attribute fluidDensity : FluidDensity;
		attribute productivityIndex : Real;
	}

	part def FlowController {
		doc /* Monitors and controls gas injection to optimize production. */
		
		port controlInput {
			in measuredProductionRate : OilProductionRate;
			in measuredPressure : ISQ::PressureValue;
		}
		port controlOutput {
			out targetGasRate : GasInjectionRate;
		}

		attribute targetProductionRate : OilProductionRate;
		attribute controlGain : Real;
	}

	action def CompressGas {
		in lowPressureGas : CompressedGas;
		in targetPressure : ISQ::PressureValue;
		out highPressureGas : CompressedGas;
	}

	action def InjectGas {
		in highPressureGas : CompressedGas;
		in wellDepth : WellDepth;
		out injectedGas : CompressedGas;
	}

	action def AerateFluid {
		in reservoirFluid : ReservoirFluid;
		in injectedGas : CompressedGas;
		out aeratedFluid : AeratedFluid;
	}

	action def LiftFluid {
		in aeratedFluid : AeratedFluid;
		in wellDepth : WellDepth;
		out producedFluid : AeratedFluid;
	}

	action def MonitorProduction {
		in currentProductionRate : OilProductionRate;
		in currentPressure : ISQ::PressureValue;
		out productionStatus : Real;
	}

	action def AdjustGasInjection {
		in productionStatus : Real;
		in targetProductionRate : OilProductionRate;
		out requiredGasRate : GasInjectionRate;
	}

	action def PerformGasLift {
		doc /* High-level behavior describing continuous gas lift operation. */
		
		in gasSupply : CompressedGas;
		in reservoirFluid : ReservoirFluid;
		in targetProduction : OilProductionRate;
		in wellDepth : WellDepth;
		out producedFluid : AeratedFluid;

		first start;
		then merge continuousOperation;

		then action compress : CompressGas {
			in lowPressureGas = gasSupply;
			in targetPressure : ISQ::PressureValue;
			out highPressureGas : CompressedGas;
		}

		flow compress.highPressureGas to inject.highPressureGas;

		then action inject : InjectGas {
			in wellDepth = wellDepth;
			out injectedGas : CompressedGas;
		}

		flow inject.injectedGas to aerate.injectedGas;

		then action aerate : AerateFluid {
			in reservoirFluid = reservoirFluid;
			out aeratedFluid : AeratedFluid;
		}

		flow aerate.aeratedFluid to lift.aeratedFluid;

		then action lift : LiftFluid {
			in wellDepth = wellDepth;
			out liftedFluid : AeratedFluid;
		}

		then action monitor : MonitorProduction {
			in currentProductionRate : OilProductionRate;
			in currentPressure : ISQ::PressureValue;
			out productionStatus : Real;
		}

		then action adjust : AdjustGasInjection {
			in productionStatus = monitor.productionStatus;
			in targetProductionRate = targetProduction;
			out requiredGasRate : GasInjectionRate;
		}

		then continuousOperation;
	}

	part def GasLiftSystem {
		doc /* 
		 * Artificial lift system that injects compressed gas into the production tubing
		 * to reduce the density of the fluid column, thereby reducing bottomhole pressure
		 * and enabling increased oil production from reservoirs with insufficient natural
		 * pressure to lift fluids to the surface.
		 */

		attribute wellDepth : WellDepth;
		attribute targetProduction : OilProductionRate;

		part compressor : GasCompressor;
		part annulus : Annulus;
		part gasLiftValve1 : GasLiftValve;
		part gasLiftValve2 : GasLiftValve;
		part gasLiftValve3 : GasLiftValve;
		part productionTubing : ProductionTubing;
		part reservoir : Reservoir;
		part flowController : FlowController;

		perform action gasLiftOperation : PerformGasLift;
	}

	part gasLiftSystem : GasLiftSystem {
		attribute wellDepth = 2500.0 [SI::m];
		attribute targetProduction = 500.0 [SI::m3/SI::d];

		part compressor : GasCompressor {
			attribute compressionRatio = 3.5;
			attribute efficiency = 0.85;
			attribute dischargePressure = 10.0e6 [SI::Pa];

			perform gasLiftOperation.compress;
		}

		part annulus : Annulus {
			attribute depth = gasLiftSystem.wellDepth;
			attribute outerDiameter = 0.178 [SI::m];
			attribute innerDiameter = 0.089 [SI::m];
		}

		part gasLiftValve1 : GasLiftValve {
			attribute depth = 2000.0 [SI::m];
			attribute openingPressure = 8.0e6 [SI::Pa];
			attribute orificeSize = 0.0005 [SI::m2];

			perform gasLiftOperation.inject;
		}

		part gasLiftValve2 : GasLiftValve {
			attribute depth = 1500.0 [SI::m];
			attribute openingPressure = 6.5e6 [SI::Pa];
			attribute orificeSize = 0.0006 [SI::m2];
		}

		part gasLiftValve3 : GasLiftValve {
			attribute depth = 1000.0 [SI::m];
			attribute openingPressure = 5.0e6 [SI::Pa];
			attribute orificeSize = 0.0007 [SI::m2];
		}

		part productionTubing : ProductionTubing {
			attribute innerDiameter = 0.062 [SI::m];
			attribute length = gasLiftSystem.wellDepth;
			attribute roughness = 0.000046 [SI::m];

			perform gasLiftOperation.lift;
		}

		part reservoir : Reservoir {
			attribute pressure = 12.0e6 [SI::Pa];
			attribute permeability = 100.0;
			attribute porosity = 0.22;
			attribute productivityIndex = 0.00001;

			perform gasLiftOperation.aerate;
		}

		part flowController : FlowController {
			attribute targetProductionRate = gasLiftSystem.targetProduction;
			attribute controlGain = 1.2;

			perform gasLiftOperation.monitor;
			perform gasLiftOperation.adjust;
		}

		connect compressor.gasOutlet to annulus.annulusTop;
		connect annulus.annulusBottom to gasLiftValve1.annulusInput;
		connect annulus.annulusBottom to gasLiftValve2.annulusInput;
		connect annulus.annulusBottom to gasLiftValve3.annulusInput;
		connect gasLiftValve1.injectionOutput to productionTubing.tubingInlet;
		connect gasLiftValve2.injectionOutput to productionTubing.tubingInlet;
		connect gasLiftValve3.injectionOutput to productionTubing.tubingInlet;
		connect reservoir.reservoirOutlet to productionTubing.tubingInlet;

		item flow from compressor.gasInlet : CompressedGas;
		item flow from compressor.gasOutlet to annulus.annulusTop : CompressedGas;
		item flow from reservoir.reservoirOutlet to productionTubing.tubingInlet : ReservoirFluid;
		item flow from productionTubing.tubingOutlet : AeratedFluid;
	}

	requirement def ArtificialLiftRequirement {
		doc /* 
		 * The gas lift system shall inject compressed gas into the production tubing
		 * to reduce fluid column density and enable economic oil production from wells
		 * with insufficient reservoir pressure.
		 */
		subject gasLiftSystem : GasLiftSystem;
	}

	requirement def ProductionRequirement {
		doc /* 
		 * The system shall maintain oil production rate at or above the target
		 * production rate by continuously adjusting gas injection.
		 */
		subject gasLiftSystem : GasLiftSystem;
	}

	requirement def GasInjectionRequirement {
		doc /* 
		 * The system shall inject gas at multiple depths through gas lift valves
		 * to optimize lifting efficiency across the wellbore.
		 */
		subject gasLiftSystem : GasLiftSystem;
	}

	requirement def PressureReductionRequirement {
		doc /* 
		 * The system shall reduce the bottomhole flowing pressure to enable
		 * sufficient reservoir influx for sustained production.
		 */
		subject gasLiftSystem : GasLiftSystem;
	}

	requirement <'GLS-REQ-001'> primaryFunction : ArtificialLiftRequirement;
	requirement <'GLS-REQ-002'> productionTarget : ProductionRequirement;
	requirement <'GLS-REQ-003'> gasInjection : GasInjectionRequirement;
	requirement <'GLS-REQ-004'> pressureReduction : PressureReductionRequirement;

	satisfy primaryFunction by gasLiftSystem;
	satisfy productionTarget by gasLiftSystem;
	satisfy gasInjection by gasLiftSystem;
	satisfy pressureReduction by gasLiftSystem;
}
