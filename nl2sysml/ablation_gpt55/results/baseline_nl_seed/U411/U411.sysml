package SyringeFilterModel {
	private import ScalarValues::*;

	attribute def Volume_mL :> Real;
	attribute def FlowRate_mL_per_s :> Real;
	attribute def Pressure_kPa :> Real;
	attribute def Force_N :> Real;
	attribute def Length_um :> Real;
	attribute def ParticleConcentration_count_per_mL :> Real;
	attribute def FiltrationEfficiency_percent :> Real;
	attribute def Temperature_C :> Real;
	attribute def Time_s :> Real;

	enum def FluidCompatibility {
		enum aqueous;
		enum organicSolvent;
		enum proteinSolution;
		enum cellCultureMedia;
	}

	enum def SterilityState {
		enum nonSterile;
		enum sterile;
		enum bioburdenReduced;
	}

	enum def FilterCondition {
		enum unused;
		enum primed;
		enum filtering;
		enum complete;
		enum clogged;
		enum disposed;
	}

	item def LiquidSample {
		attribute volume : Volume_mL;
		attribute temperature : Temperature_C;
		attribute particleLoad : ParticleConcentration_count_per_mL;
		attribute compatibility : FluidCompatibility;
		attribute sterility : SterilityState;
	}

	item def UnfilteredLiquidSample :> LiquidSample {
		attribute particleLoad : ParticleConcentration_count_per_mL = 100000.0;
		attribute sterility : SterilityState = SterilityState::nonSterile;
	}

	item def FilteredLiquidSample :> LiquidSample {
		attribute particleLoad : ParticleConcentration_count_per_mL = 100.0;
		attribute sterility : SterilityState = SterilityState::bioburdenReduced;
	}

	item def RetainedParticleMass {
		attribute retainedParticleCount : ParticleConcentration_count_per_mL;
		attribute retainedParticleDiameterMinimum : Length_um;
	}

	item def AirBubble {
		attribute volume : Volume_mL;
	}

	port def SampleInletPort {
		in item incomingSample : LiquidSample;
	}

	port def SampleOutletPort {
		out item outgoingSample : LiquidSample;
	}

	port def VentPort {
		out item displacedAir : AirBubble;
	}

	port def ManualForcePort {
		in appliedForce : Force_N;
	}

	port def PressurePort {
		out generatedPressure : Pressure_kPa;
	}

	part def SyringeBarrel {
		attribute capacity : Volume_mL = 10.0;
		attribute loadedVolume : Volume_mL = 5.0;
		attribute maximumWorkingPressure : Pressure_kPa = 690.0;

		port outlet : SampleOutletPort;
	}

	part def Plunger {
		attribute thumbForce : Force_N = 30.0;
		attribute travelTime : Time_s = 8.0;

		port forceInput : ManualForcePort;
		port pressureOutput : PressurePort;
	}

	part def LuerLockTip {
		attribute internalDeadVolume : Volume_mL = 0.05;
		attribute leakTightPressure : Pressure_kPa = 690.0;

		port inlet : SampleInletPort;
		port outlet : SampleOutletPort;
	}

	part def ManualSyringe {
		attribute nominalVolume : Volume_mL = 10.0;
		attribute deliveredFlowRate : FlowRate_mL_per_s = 0.6;

		part barrel : SyringeBarrel;
		part plunger : Plunger;
		part tip : LuerLockTip;

		port operatorForce : ManualForcePort;
		port sampleOutlet : SampleOutletPort;

		connect operatorForce to plunger.forceInput;
		connect barrel.outlet to tip.inlet;
		connect tip.outlet to sampleOutlet;
	}

	part def FilterHousing {
		attribute internalHoldUpVolume : Volume_mL = 0.10;
		attribute maximumOperatingPressure : Pressure_kPa = 520.0;
		attribute condition : FilterCondition = FilterCondition::unused;

		port inlet : SampleInletPort;
		port outlet : SampleOutletPort;
		port vent : VentPort;
	}

	part def SupportScreen {
		attribute meshOpening : Length_um = 100.0;
		attribute pressureDropAtNominalFlow : Pressure_kPa = 5.0;

		port upstream : SampleInletPort;
		port downstream : SampleOutletPort;
	}

	part def FilterMembrane {
		attribute poreSize : Length_um = 0.22;
		attribute effectiveArea : Real = 4.15;
		attribute thickness : Length_um = 120.0;
		attribute nominalFlowRate : FlowRate_mL_per_s = 0.6;
		attribute particleRemovalEfficiency : FiltrationEfficiency_percent = 99.9;
		attribute maximumDifferentialPressure : Pressure_kPa = 520.0;
		attribute minimumRetainedParticleDiameter : Length_um = 0.22;

		port upstream : SampleInletPort;
		port downstream : SampleOutletPort;
	}

	part def SealGasket {
		attribute compressionForce : Force_N = 12.0;
		attribute bypassLeakRate : FlowRate_mL_per_s = 0.0;
	}

	part def SyringeFilterAssembly {
		attribute ratedPoreSize : Length_um = 0.22;
		attribute ratedSampleVolume : Volume_mL = 10.0;
		attribute ratedPressure : Pressure_kPa = 520.0;
		attribute condition : FilterCondition = FilterCondition::unused;

		part housing : FilterHousing;
		part inletSupport : SupportScreen;
		part membrane : FilterMembrane;
		part outletSupport : SupportScreen;
		part gasket : SealGasket;

		port inlet : SampleInletPort;
		port outlet : SampleOutletPort;
		port airVent : VentPort;

		connect inlet to housing.inlet;
		connect housing.inlet to inletSupport.upstream;
		connect inletSupport.downstream to membrane.upstream;
		connect membrane.downstream to outletSupport.upstream;
		connect outletSupport.downstream to housing.outlet;
		connect housing.outlet to outlet;
		connect housing.vent to airVent;
	}

	part def CollectionVial {
		attribute capacity : Volume_mL = 15.0;
		attribute collectedVolume : Volume_mL = 0.0;
		attribute sterility : SterilityState = SterilityState::sterile;

		port inlet : SampleInletPort;
		port vent : VentPort;
	}

	action def LoadSampleIntoSyringe {
		in item sourceSample : UnfilteredLiquidSample;
		out item loadedSample : UnfilteredLiquidSample;

		attribute loadedVolume : Volume_mL = 5.0;
	}

	action def ApplyManualPressure {
		in force : Force_N;
		out pressure : Pressure_kPa;

		attribute targetFlowRate : FlowRate_mL_per_s = 0.6;
	}

	action def RetainParticlesAtMembrane {
		in item membraneFeed : UnfilteredLiquidSample;
		out item filtrate : FilteredLiquidSample;
		out item retainedParticles : RetainedParticleMass;

		attribute poreSize : Length_um = 0.22;
		attribute removalEfficiency : FiltrationEfficiency_percent = 99.9;
	}

	action def DeliverFiltrateToVial {
		in item filtrateIn : FilteredLiquidSample;
		out item collectedFiltrate : FilteredLiquidSample;

		attribute deliveredVolume : Volume_mL = 4.85;
	}

	action def PrimarySyringeFilterFunction {
		in item rawSample : UnfilteredLiquidSample;
		in operatorForce : Force_N;
		out item cleanSample : FilteredLiquidSample;
		out item separatedParticles : RetainedParticleMass;

		action load : LoadSampleIntoSyringe;
		action pressurize : ApplyManualPressure;
		action separate : RetainParticlesAtMembrane;
		action collect : DeliverFiltrateToVial;

		flow rawSample to load.sourceSample;
		flow load.loadedSample to separate.membraneFeed;
		flow operatorForce to pressurize.force;
		flow separate.filtrate to collect.filtrateIn;
		flow collect.collectedFiltrate to cleanSample;
		flow separate.retainedParticles to separatedParticles;
	}

	state def FiltrationLifecycle {
		state Ready;
		state Loaded;
		state Primed;
		state Filtering;
		state Complete;
		state Clogged;
		state Disposed;

		entry; then Ready;

		transition readyToLoaded first Ready then Loaded;
		transition loadedToPrimed first Loaded then Primed;
		transition primedToFiltering first Primed then Filtering;
		transition filteringToComplete first Filtering then Complete;
		transition filteringToClogged first Filtering then Clogged;
		transition completeToDisposed first Complete then Disposed;
		transition cloggedToDisposed first Clogged then Disposed;
	}

	constraint def PoreRetentionCriterion {
		in poreSize : Length_um;
		in minimumParticleDiameter : Length_um;

		assert constraint { minimumParticleDiameter >= poreSize }
	}

	constraint def PressureSafetyCriterion {
		in appliedPressure : Pressure_kPa;
		in ratedPressure : Pressure_kPa;

		assert constraint { appliedPressure <= ratedPressure }
	}

	constraint def CollectionCapacityCriterion {
		in deliveredVolume : Volume_mL;
		in vialCapacity : Volume_mL;

		assert constraint { deliveredVolume <= vialCapacity }
	}

	part def SyringeFilterSystem {
		attribute maximumProcessVolume : Volume_mL = 10.0;
		attribute nominalOperatingPressure : Pressure_kPa = 250.0;
		attribute nominalFlowRate : FlowRate_mL_per_s = 0.6;
		attribute primaryFunction : String = "Force an unfiltered liquid sample from a syringe through a porous membrane so that particles larger than the rated pore size are retained and clarified filtrate is delivered to a receiving container.";

		part syringe : ManualSyringe;
		part filter : SyringeFilterAssembly;
		part receiver : CollectionVial;

		port operatorForceInput : ManualForcePort;
		port unfilteredSampleInterface : SampleInletPort;
		port filteredSampleInterface : SampleOutletPort;

		connect operatorForceInput to syringe.operatorForce;
		connect syringe.sampleOutlet to filter.inlet;
		connect filter.outlet to receiver.inlet;
		connect filter.outlet to filteredSampleInterface;

		perform action filtration : PrimarySyringeFilterFunction;
		exhibit state lifecycle : FiltrationLifecycle;
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The syringe filter system shall provide the high-level function of clarifying a liquid sample by using syringe-generated pressure to drive the sample through a membrane that retains particles at or above the rated pore size and delivers the filtered liquid to a collection vial. */

		subject system : SyringeFilterSystem;

		require constraint {
			system.filter.membrane.poreSize <= 0.22
		}

		require constraint {
			system.filter.membrane.particleRemovalEfficiency >= 99.9
		}
	}

	requirement def PressureSafetyRequirement {
		doc /* The syringe filter system shall operate without exceeding the rated pressure of the filter assembly during manual syringe actuation. */

		subject system : SyringeFilterSystem;

		require constraint {
			system.nominalOperatingPressure <= system.filter.ratedPressure
		}
	}

	requirement def CollectionRequirement {
		doc /* The collection vial shall have enough capacity to receive the expected filtrate volume from the syringe filter system. */

		subject system : SyringeFilterSystem;

		require constraint {
			system.maximumProcessVolume <= system.receiver.capacity
		}
	}

	part syringeFilterSystem : SyringeFilterSystem;

	requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
		subject system = syringeFilterSystem;
	}

	requirement pressureSafetyRequirement : PressureSafetyRequirement {
		subject system = syringeFilterSystem;
	}

	requirement collectionRequirement : CollectionRequirement {
		subject system = syringeFilterSystem;
	}
}
