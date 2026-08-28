package 'Carpuject Medication Delivery System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def Force :> ISQ::ForceValue;
	attribute def Pressure :> ISQ::PressureValue;
	attribute def FlowRate :> ISQ::VolumeFlowRateValue;
	attribute def Volume :> ISQ::VolumeValue;

	item def Medication {
		attribute name : String;
		attribute concentration : Real;
		attribute volume : Volume;
	}

	item def UnlockCommand;
	item def PrimeCommand;
	item def TriggerSignal {
		attribute appliedForce : Force;
	}
	item def EmptySignal;

	port def MechanicalPort;
	port def MedicationFlowPort;
	port def ControlPort;

	part def BarrelHolder {
		attribute reusable : Boolean = true;
		port cartridgeSlot : MechanicalPort;
		port needleMount : MechanicalPort;
		port triggerMount : MechanicalPort;
	}

	part def GlassCartridge {
		attribute sterile : Boolean = true;
		attribute preFilled : Boolean = true;
		ref medication : Medication[1];
		attribute remainingVolume : Volume;
		port plungerInterface : MechanicalPort;
		port dischargePort : MedicationFlowPort;
	}

	part def RubberPlunger {
		attribute sterile : Boolean = true;
		port driveInterface : MechanicalPort;
		port sealFace : MechanicalPort;
	}

	part def NeedleAssembly {
		attribute sterile : Boolean = true;
		attribute singleUse : Boolean = true;
		attribute gauge : Real;
		port hubPort : MedicationFlowPort;
		port tipPort : MedicationFlowPort;
	}

	part def SafetyMechanism {
		attribute locked : Boolean = true;
		port unlockPort : ControlPort;
		port triggerLockPort : MechanicalPort;
	}

	part def ActivationTrigger {
		attribute requiredForce : Force = 5.0 [N];
		port drivePort : MechanicalPort;
		port plungerDrivePort : MechanicalPort;
	}

	action def AdvancePlunger {
		in activation : TriggerSignal;
		out flowRate : FlowRate;
		out pressure : Pressure;
		out deliveredVolume : Volume;
	}

	action def DeliverMedication {
		in trigger : TriggerSignal;
		out deliveryPressure : Pressure;
		out totalDelivered : Volume;
		out empty : EmptySignal;

		action 'advance plunger' : AdvancePlunger {
			in activation = DeliverMedication::trigger;
			out flowRate : FlowRate;
			out pressure : Pressure;
			out deliveredVolume : Volume;
		}
		flow 'advance plunger'.pressure to deliveryPressure;
		flow 'advance plunger'.deliveredVolume to totalDelivered;
	}

	state def CarpujectLifecycle {
		entry; then secured;
		state secured;
		accept unlock : UnlockCommand
			then ready;
		state ready;
		accept prime : PrimeCommand
			then primed;
		state primed;
		accept activate : TriggerSignal
			[ activate.appliedForce >= 5.0 [N] ]
			then injecting;
		state injecting;
		accept empty : EmptySignal
			then complete;
		state complete;
	}

	part def CarpujectDevice {
		part barrelHolder : BarrelHolder;
		part cartridge : GlassCartridge;
		part plunger : RubberPlunger;
		part needle : NeedleAssembly;
		part safety : SafetyMechanism;
		part trigger : ActivationTrigger;

		port userPort : ControlPort;

		connector plungerToCartridge from plunger.sealFace to cartridge.plungerInterface;
		connector cartridgeToNeedle from cartridge.dischargePort to needle.hubPort;
		connector safetyToTrigger from safety.triggerLockPort to trigger.drivePort;
		connector triggerToPlunger from trigger.plungerDrivePort to plunger.driveInterface;

		state carpujectLifecycle : CarpujectLifecycle {
			port :>> userPort;
		}

		action 'deliver medication' : DeliverMedication {
			in trigger : TriggerSignal;
			out deliveryPressure : Pressure;
			out totalDelivered : Volume;
			out empty : EmptySignal;
		}
	}

	requirement def SterilityRequirement {
		doc /* The medication path must remain sterile until the point of use. */;
		subject device : CarpujectDevice;
		constraint { device.needle.sterile == true }
		constraint { device.cartridge.sterile == true }
		constraint { device.plunger.sterile == true }
	}

	requirement def SafetyLockRequirement {
		doc /* Safety mechanism must be locked initially, requiring deliberate action to unlock. */;
		subject device : CarpujectDevice;
		constraint { device.safety.locked == true }
	}

	requirement def TriggerForceRequirement {
		doc /* Activation trigger must require a specific minimum force to prevent accidental discharge. */;
		subject device : CarpujectDevice;
		constraint { device.trigger.requiredForce >= 3.0 [N] }
	}

	requirement def ControlledDeliveryRequirement {
		doc /* System must deliver medication at a controlled flow rate and pressure. */;
		subject device : CarpujectDevice;
		constraint { device.cartridge.remainingVolume >= 0.0 }
	}

	requirement sterilityReq : SterilityRequirement;
	requirement safetyLockReq : SafetyLockRequirement;
	requirement triggerForceReq : TriggerForceRequirement;
	requirement controlledDeliveryReq : ControlledDeliveryRequirement;

	part carpuject : CarpujectDevice {
		satisfy sterilityReq by self;
		satisfy safetyLockReq by self;
		satisfy triggerForceReq by self;
		satisfy controlledDeliveryReq by self;
	}
}
