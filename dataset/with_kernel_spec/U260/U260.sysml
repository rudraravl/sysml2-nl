package 'ElectronicInjectorPenSystem' {
	private import ISQ::*;
	private import ScalarValues::*;

	attribute def DoseVolume :> ISQ::volume;
	attribute def ForceMeasure :> ISQ::force;
	attribute def PressureMeasure :> ISQ::pressure;
	attribute def BatteryLevel :> ScalarValues::Real;
	attribute def ErrorStatus :> ScalarValues::String;

	attribute def AttachNeedleSignal;
	attribute def SelectDoseSignal;
	attribute def PrimeSignal;
	attribute def PrimeCompleteSignal;
	attribute def InjectSignal;
	attribute def InjectionCompleteSignal;
	attribute def ResetSignal;

	port def FluidPort;
	port def MechanicalPort;
	port def ElectricalPort;
	port def UserInterfacePort;

	connection def FluidConnection {
		end : FluidPort[1];
		end : FluidPort[1];
	}
	connection def MechanicalConnection {
		end : MechanicalPort[1];
		end : MechanicalPort[1];
	}
	connection def ElectricalConnection {
		end : ElectricalPort[1];
		end : ElectricalPort[1];
	}

	part def MedicationCartridge {
		attribute totalVolume : DoseVolume;
		attribute remainingVolume : DoseVolume;
		port fluidOut : FluidPort;
		port plungerInterface : MechanicalPort;
	}

	part def Needle {
		attribute gauge : ScalarValues::Integer;
		attribute needleLength : ISQ::length;
		port fluidIn : FluidPort;
		port fluidOut : FluidPort;
	}

	part def ProtectiveCap {
		attribute isAttached : Boolean;
		port capInterface : MechanicalPort;
	}

	part def NeedleShield {
		attribute isDeployed : Boolean;
		port shieldInterface : MechanicalPort;
		action deploy;
	}

	part def NeedleAssembly {
		part needle : Needle[1];
		part cap : ProtectiveCap[1];
		part shield : NeedleShield[1];
		port fluidPort : FluidPort;
		port capPort : MechanicalPort;
		port shieldPort : MechanicalPort;
	}

	part def DoseSelectionMechanism {
		attribute selectedDose : DoseVolume;
		port dialInput : UserInterfacePort;
		port doseSignalOut : ElectricalPort;
		action setDose;
	}

	part def ElectronicDisplay {
		attribute displayedDose : DoseVolume;
		attribute batteryLevel : BatteryLevel;
		attribute statusMessage : ErrorStatus;
		port displayInput : ElectricalPort;
		port userView : UserInterfacePort;
		action updateDisplay;
	}

	part def Plunger {
		attribute position : ISQ::length;
	}

	part def PlungerDriveMechanism {
		part plunger : Plunger[1];
		attribute appliedForce : ForceMeasure;
		attribute measuredPressure : PressureMeasure;
		attribute maxSafeForce : ForceMeasure;
		port driveOutput : MechanicalPort;
		port powerInput : ElectricalPort;
		port sensorFeedback : ElectricalPort;
		action applyForce;
		action monitorPressure;
	}

	part def CapSensor {
		attribute capDetected : Boolean;
		port sensorOut : ElectricalPort;
	}

	part def SafetyLockMechanism {
		attribute isLocked : Boolean;
		attribute activationEnabled : Boolean;
		port capSensorInput : ElectricalPort;
		port buttonBlocker : MechanicalPort;
		action lockSystem;
		action unlockSystem;
		action deployShield;
	}

	part def InjectorPen {
		part cartridge : MedicationCartridge[1];
		part needleAssembly : NeedleAssembly[1];
		part doseDial : DoseSelectionMechanism[1];
		part display : ElectronicDisplay[1];
		part plungerDrive : PlungerDriveMechanism[1];
		part safetyLock : SafetyLockMechanism[1];
		part capSensor : CapSensor[1];

		connection fluidPath : FluidConnection
			connect cartridge.fluidOut to needleAssembly.fluidPort;
		connection drivePath : MechanicalConnection
			connect plungerDrive.driveOutput to cartridge.plungerInterface;
		connection powerPath : ElectricalConnection
			connect plungerDrive.powerInput to display.displayInput;
		connection doseSignalPath : ElectricalConnection
			connect doseDial.doseSignalOut to display.displayInput;
		connection capSensorPath : ElectricalConnection
			connect capSensor.sensorOut to safetyLock.capSensorInput;
		connection shieldDrivePath : MechanicalConnection
			connect safetyLock.buttonBlocker to needleAssembly.shieldPort;

		state def PenOperationalStates;
		state penStates : PenOperationalStates {
			in operatingPen : InjectorPen;
			entry; then idle;

			state idle;
			accept AttachNeedleSignal then needleAttached;

			state needleAttached;
			accept SelectDoseSignal then doseSelected;

			state doseSelected;
			accept PrimeSignal then priming;

			state priming {
				entry action clearAirBubbles { }
			}
			accept PrimeCompleteSignal then readyToInject;

			state readyToInject;
			accept InjectSignal
				if operatingPen.safetyLock.activationEnabled
				then injecting;

			state injecting {
				entry action applyPlungerForce { }
				do action monitorDeliveryPressure { }
				exit action updateDisplayStatus { }
			}
			accept InjectionCompleteSignal then withdrawing;

			state withdrawing {
				entry action deployNeedleShield { }
			}
			accept ResetSignal then idle;
		}
	}

	requirement def SafetyRequirement {
		doc /* Base safety requirement definition */
	}
	requirement def OperationalRequirement {
		doc /* Base operational requirement definition */
	}

	requirement safetyLockRequirement : SafetyRequirement {
		subject pen : InjectorPen;
		doc /* Prevent accidental injection when protective cap is still attached */
		requirement constraint { pen.needleAssembly.cap.isAttached implies pen.safetyLock.isLocked }
	}

	requirement needleShieldRequirement : SafetyRequirement {
		subject pen : InjectorPen;
		doc /* Shield must deploy upon injection completion to prevent needle-stick injuries */
		requirement constraint { pen.needleAssembly.shield.isDeployed }
	}

	requirement doseAccuracyRequirement : OperationalRequirement {
		subject pen : InjectorPen;
		doc /* Displayed dose must match selected dose */
		requirement constraint { pen.display.displayedDose == pen.doseDial.selectedDose }
	}

	requirement forceLimitRequirement : OperationalRequirement {
		subject pen : InjectorPen;
		doc /* Applied plunger force must not exceed safe limit */
		requirement constraint { pen.plungerDrive.appliedForce <= pen.plungerDrive.maxSafeForce }
	}

	requirement displayRequirement : OperationalRequirement {
		subject pen : InjectorPen;
		doc /* Display must show selected dose, battery level, and any system errors */
		requirement constraint { pen.display.batteryLevel >= 0 }
	}

	requirement primingRequirement : OperationalRequirement {
		subject pen : InjectorPen;
		doc /* Pen must be primed to clear air bubbles before injection */
		requirement constraint { pen.needleAssembly.cap.isAttached == false }
	}

	part standardInjectorPen : InjectorPen {
		doc /* Default reusable injector pen with replaceable cartridge and disposable needle */
	}
}
