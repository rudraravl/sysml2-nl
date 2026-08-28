package 'Surgical Drape System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def BodyFluid;

		port def FluidPort {
			in item fluid : BodyFluid;
		}

		part def BarrierLayer {
			attribute filtrationEfficiency : Real = 95.0;
		}

		part def AbsorbentLayer {
			attribute maxFluidCapacity : Real = 500.0;
			attribute currentFluidVolume : Real = 0.0;
			port fluidInPort : FluidPort;
		}

		part def AdhesiveStrip;
		part def Fenestration;
		part def ReinforcementZone;

		connection def LayerLamination {
			end barrierSide : BarrierLayer;
			end absorbentSide : AbsorbentLayer;
		}

		action def InspectPackaging;
		action def OpenAndUnfold;
		action def PositionOverPatient;
		action def SecureDrape;
		action def MonitorIntegrity {
			out barrierCompromised : Boolean;
			out isSaturated : Boolean;
		}
		action def AlertSurgicalTeam;
		action def ReplaceDrape;
		action def RemoveDrape;
		action def DisposeDrape;

		attribute def StartProcedure;
		attribute def CompromiseDetected;
		attribute def FluidSaturated;
		attribute def ResumeProcedure;
		attribute def CompleteProcedure;

		state def DrapeLifecycle {
			entry; then packaged;
			state packaged;
			accept 'InspectPackaging' then inspected;
			state inspected;
			accept 'OpenAndUnfold' then opened;
			state opened;
			accept 'PositionOverPatient' then positioned;
			state positioned;
			accept 'SecureDrape' then secured;
			state secured;
			accept 'StartProcedure' then inUse;
			state inUse;
			accept 'CompromiseDetected' then compromised;
			accept 'FluidSaturated' then saturated;
			state compromised;
			accept 'ReplaceDrape' then replaced;
			state saturated;
			accept 'ReplaceDrape' then replaced;
			state replaced;
			accept 'ResumeProcedure' then inUse;
			accept 'CompleteProcedure' then removed;
			state removed;
			accept 'DisposeDrape' then disposed;
			state disposed;
		}

		part def SurgicalDrape {
			part barrierLayer : BarrierLayer;
			part absorbentLayer : AbsorbentLayer;
			part adhesiveStrip[4] : AdhesiveStrip;
			part fenestration : Fenestration;
			part reinforcementZone[2] : ReinforcementZone;

			port fluidInPort : FluidPort;

			connection lamination : LayerLamination
				connect barrierLayer to absorbentLayer;

			flow of fluid : BodyFluid
				from fluidInPort.fluid to absorbentLayer.fluidInPort.fluid;

			exhibit state lifecycle : DrapeLifecycle;
		}

		requirement def SterileBarrierRequirement {
			subject drape : SurgicalDrape;
			doc /* The barrier layer shall provide microbial filtration efficiency of at least 95 percent. */
			constraint { drape.barrierLayer.filtrationEfficiency >= 95.0 }
		}

		requirement def FluidManagementRequirement {
			subject drape : SurgicalDrape;
			doc /* The absorbent layer shall be capable of holding up to 500 mL of body fluid. */
			constraint { drape.absorbentLayer.maxFluidCapacity >= 500.0 }
		}

		requirement def ControlledAccessRequirement {
			subject drape : SurgicalDrape;
			doc /* The drape shall include a fenestration providing controlled access for surgical instruments. */
		}

		requirement def DurabilityRequirement {
			subject drape : SurgicalDrape;
			doc /* The drape shall include reinforcement zones to resist tearing and fluid strike-through. */
		}
	}

	public import Definitions::*;

	package Usages {
		private import Definitions::*;

		part surgicalDrape : SurgicalDrape;

		requirement sterileBarrier : SterileBarrierRequirement;
		requirement fluidManagement : FluidManagementRequirement;
		requirement controlledAccess : ControlledAccessRequirement;
		requirement durability : DurabilityRequirement;

		satisfy sterileBarrier by surgicalDrape.barrierLayer;
		satisfy fluidManagement by surgicalDrape.absorbentLayer;
		satisfy controlledAccess by surgicalDrape.fenestration;
		satisfy durability by surgicalDrape.reinforcementZone;
	}
}
