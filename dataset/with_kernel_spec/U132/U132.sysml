package 'Vaginal Syringe System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def MedicinalFluid;

	port def FluidPort {
		in item fluidIn : MedicinalFluid;
		out item fluidOut : MedicinalFluid;
	}
	port def MechanicalPort;

	part def Barrel {
		attribute capacity : Real = 150 [SI::millilitre];
		attribute material : String = "Medical-grade polypropylene";
		attribute hasGraduations : Boolean = true;
		port fluidPort : FluidPort;
		port plungerInterface : MechanicalPort;
	}

	part def Plunger {
		attribute sealType : String = "Reliable elastomeric seal";
		port plungerInterface : MechanicalPort;
		port handlePort : MechanicalPort;
	}

	part def Nozzle {
		attribute tipDesign : String = "Smooth, rounded, atraumatic";
		attribute length : Real = 100 [SI::millimetre];
		port fluidInlet : FluidPort;
		port tipPort : FluidPort;
		port capAttachment : MechanicalPort;
	}

	part def SafetyCap {
		attribute tamperEvident : Boolean = true;
		port attachment : MechanicalPort;
	}

	part def VaginalSyringe {
		port fluidInPort : FluidPort;
		port fluidOutPort : FluidPort;

		part barrel : Barrel;
		part plunger : Plunger;
		part nozzle : Nozzle;
		part safetyCap : SafetyCap;

		bind barrel.fluidPort.fluidOut = nozzle.fluidInlet.fluidIn;
		bind barrel.plungerInterface = plunger.plungerInterface;
		bind nozzle.capAttachment = safetyCap.attachment;
		bind fluidInPort.fluidIn = barrel.fluidPort.fluidIn;
		bind nozzle.tipPort.fluidOut = fluidOutPort.fluidOut;
	}

	part def Person;

	action def VerifySterility {
		in device : VaginalSyringe;
	}
	action def FillBarrel {
		in device : VaginalSyringe;
		in fluid : MedicinalFluid;
	}
	action def PositionDevice {
		in device : VaginalSyringe;
	}
	action def DispenseFluid {
		in device : VaginalSyringe;
		in force : Real;
	}

	state machine def SyringeOperation {
		state SterileIdle;
		state SterilityVerified;
		state Filled;
		state Positioned;
		state Dispensing;
		state Used;
		state done final;

		transition initial -> SterileIdle;
		transition SterileIdle -> SterilityVerified;
		transition SterilityVerified -> Filled;
		transition Filled -> Positioned;
		transition Positioned -> Dispensing;
		transition Dispensing -> Used;
		transition Used -> done;
	}

	use case def 'Administer Vaginal Irrigation' {
		subject syringe : VaginalSyringe;
		actor provider : Person;
		objective {
			doc /* Deliver medicinal or cleansing fluid into the vaginal cavity
			     * safely and comfortably. */
		}
	}

	requirement def SterilityRequirement {
		subject syringe : VaginalSyringe;
		doc /* The safety cap must be tamper-evident to guarantee sterility before use. */
	}
	requirement def SingleUseRequirement {
		subject syringe : VaginalSyringe;
		doc /* The system is intended for one-time use only to prevent cross-contamination. */
	}
	requirement def CapacityRequirement {
		subject barrel : Barrel;
		doc /* The barrel must hold up to 150 mL of fluid. */
		constraint { barrel.capacity <= 150 [SI::millilitre] }
	}
	requirement def AtraumaticTipRequirement {
		subject nozzle : Nozzle;
		doc /* The nozzle tip must be smooth, rounded, and atraumatic to prevent tissue injury. */
	}
	requirement def GraduationMarkingsRequirement {
		subject barrel : Barrel;
		doc /* The barrel must have clear graduation markings for accurate volume measurement. */
	}
	requirement def MaterialRequirement {
		subject barrel : Barrel;
		doc /* The barrel shall be manufactured from medical-grade polypropylene. */
	}

	part syringeSystem : VaginalSyringe {
		perform op : SyringeOperation;
		satisfy sterilityReq : SterilityRequirement;
		satisfy singleUseReq : SingleUseRequirement;
		satisfy capacityReq : CapacityRequirement by barrel;
		satisfy atraumaticReq : AtraumaticTipRequirement by nozzle;
		satisfy graduationReq : GraduationMarkingsRequirement by barrel;
		satisfy materialReq : MaterialRequirement by barrel;
	}
}
