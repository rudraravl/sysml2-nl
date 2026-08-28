package 'Medical Autoinjector' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def Epinephrine {
		attribute concentration : Real;
	}

	item def Medication {
		attribute drug : Epinephrine;
		attribute volume : VolumeValue;
	}

	attribute def CapRemovedSignal;
	attribute def PressureAppliedSignal;
	attribute def PlungerReleasedSignal;
	attribute def NeedleDeployedSignal;
	attribute def InjectionCompleteSignal;
	attribute def ShieldLockedSignal;

	action def 'Remove Safety Cap';
	action def 'Apply Pressure';
	action def 'Release Plunger';
	action def 'Deploy Needle';
	action def 'Inject Medication';
	action def 'Activate Indicator';
	action def 'Deploy Shield';

	state def 'Autoinjector States';

	part def MedicationCartridge {
		attribute dose : VolumeValue = 0.3 [mL];
		attribute remainingVolume : VolumeValue := dose;
		port pushPort {
			in medicationPushed : PlungerReleasedSignal;
		}
		port medicationOut {
			out medication : Medication;
		}
	}

	part def SafetyCap {
		attribute isRemoved : Boolean = false;
		port capPort {
			out capRemoved : CapRemovedSignal;
		}
	}

	part def ActivationMechanism {
		attribute triggerPressure : PressureValue = 5.0 [Pa];
		port armPort {
			in capRemoved : CapRemovedSignal;
		}
		port pressurePort {
			in pressureApplied : PressureAppliedSignal;
		}
		port plungerReleasePort {
			out plungerReleased : PlungerReleasedSignal;
		}
	}

	part def SpringDrivenPlunger {
		attribute releaseTime : TimeValue = 10.0 [s];
		attribute storedForce : ForceValue = 50.0 [N];
		port plungerReleasePort {
			in plungerReleased : PlungerReleasedSignal;
		}
		port needleDeployPort {
			out needleDeployed : NeedleDeployedSignal;
		}
		port medicationPushPort {
			out medicationPushed : PlungerReleasedSignal;
		}
	}

	part def NeedleAssembly {
		attribute deploymentDepth : LengthValue = 15 [mm];
		port needleDeployPort {
			in needleDeployed : NeedleDeployedSignal;
		}
		port medicationIn {
			in medication : Medication;
		}
		port medicationOut {
			out deliveredMedication : Medication;
		}
	}

	part def StatusIndicator {
		attribute feedbackType : String = "click";
		port indicatorPort {
			in injectionStarted : PlungerReleasedSignal;
			in injectionComplete : InjectionCompleteSignal;
		}
	}

	part def NeedleShield {
		attribute isLocked : Boolean = false;
		port shieldDeployPort {
			in shieldDeploy : InjectionCompleteSignal;
		}
		port shieldLockPort {
			out shieldLocked : ShieldLockedSignal;
		}
	}

	part def Autoinjector {
		perform action 'provide injection': 'Provide Injection';
		perform action 'deploy needle': 'Deploy Needle';
		perform action 'inject medication': 'Inject Medication';
		perform action 'activate indicator': 'Activate Indicator';
		exhibit state 'autoinjector states': 'Autoinjector States';

		port armPort {
			in capRemoved : CapRemovedSignal;
		}
		port pressurePort {
			in pressureApplied : PressureAppliedSignal;
		}
		port shieldLockPort {
			out shieldLocked : ShieldLockedSignal;
		}

		part medicationCartridge : MedicationCartridge;
		part safetyCap : SafetyCap;
		part activationMechanism : ActivationMechanism;
		part springDrivenPlunger : SpringDrivenPlunger;
		part needleAssembly : NeedleAssembly;
		part statusIndicator : StatusIndicator;
		part needleShield : NeedleShield;

		flow capRemovedFlow of CapRemovedSignal
			from safetyCap.capPort.capRemoved to activationMechanism.armPort.capRemoved;

		flow plungerReleasedFlow of PlungerReleasedSignal
			from activationMechanism.plungerReleasePort.plungerReleased to springDrivenPlunger.plungerReleasePort.plungerReleased;

		flow needleDeployedFlow of NeedleDeployedSignal
			from springDrivenPlunger.needleDeployPort.needleDeployed to needleAssembly.needleDeployPort.needleDeployed;

		flow medicationPushedFlow of PlungerReleasedSignal
			from springDrivenPlunger.medicationPushPort.medicationPushed to medicationCartridge.pushPort.medicationPushed;

		flow injectionStartedFlow of PlungerReleasedSignal
			from springDrivenPlunger.medicationPushPort.medicationPushed to statusIndicator.indicatorPort.injectionStarted;

		flow medicationFlow of Medication
			from medicationCartridge.medicationOut.medication to needleAssembly.medicationIn.medication;

		flow injectionCompleteFlow of InjectionCompleteSignal
			from statusIndicator.indicatorPort.injectionComplete to needleShield.shieldDeployPort.shieldDeploy;

		flow shieldLockedFlow of ShieldLockedSignal
			from needleShield.shieldLockPort.shieldLocked to shieldLockPort.shieldLocked;
	}

	action def 'Provide Injection' {
		action 'remove safety cap': 'Remove Safety Cap';
		action 'apply pressure': 'Apply Pressure';
		action 'release plunger': 'Release Plunger';
		action 'deploy needle': 'Deploy Needle';
		action 'inject medication': 'Inject Medication';
		action 'activate indicator': 'Activate Indicator';
		action 'deploy shield': 'Deploy Shield';
	}

	part autoinjector : Autoinjector {
		exhibit state 'autoinjector states': 'Autoinjector States' {
			entry; then inert;
			state inert;
			accept CapRemovedSignal
				then armed;
			state armed;
			accept PressureAppliedSignal
				if pressurePort.pressureApplied >= activationMechanism.triggerPressure
				do send new PlungerReleasedSignal() to springDrivenPlunger.plungerReleasePort
				then activated;
			state activated {
				entry 'deploy needle';
				do 'inject medication';
				exit 'activate indicator';
			}
			accept InjectionCompleteSignal
				then complete;
			state complete;
			accept ShieldLockedSignal
				then safe;
			state safe;
		}
	}

	part environment {
		port patientDoseReceived {
			in deliveredMedication : Medication;
		}
	}

	interface environmentInterface connect autoinjector.needleAssembly.medicationOut to environment.patientDoseReceived {
		flow medicationDelivery of Medication
			from autoinjector.needleAssembly.medicationOut.deliveredMedication to environment.patientDoseReceived.deliveredMedication;
	}

	requirement def 'Rapid Administration Requirement' {
		doc /* The device must allow rapid self-administration within 10 seconds. */
		subject : Autoinjector;
		predicate {
			subject.springDrivenPlunger.releaseTime <= 10 [s];
		}
	}

	requirement def 'Safety Cap Requirement' {
		doc /* The device must be initially inert and protected by a safety cap. */
		subject : Autoinjector;
		predicate {
			subject.safetyCap.isRemoved == false;
		}
	}

	requirement def 'Activation Pressure Requirement' {
		doc /* The activation mechanism must require a specific pressure to trigger, preventing accidental discharge. */
		subject : Autoinjector;
		predicate {
			subject.activationMechanism.triggerPressure >= 5.0 [Pa];
		}
	}

	requirement def 'Injection Depth Requirement' {
		doc /* The needle must deploy to a precise, predetermined subcutaneous depth. */
		subject : Autoinjector;
		predicate {
			subject.needleAssembly.deploymentDepth == 15 [mm];
		}
	}

	requirement def 'Dose Volume Requirement' {
		doc /* The device must deliver a fixed dose of 0.3 mL of medication. */
		subject : Autoinjector;
		predicate {
			subject.medicationCartridge.dose == 0.3 [mL];
		}
	}

	requirement def 'Post-Injection Safety Requirement' {
		doc /* The needle shield must automatically deploy and lock permanently after injection to prevent needlestick injuries. */
		subject : Autoinjector;
		predicate {
			subject.needleShield.isLocked == true;
		}
	}

	requirement def 'User Feedback Requirement' {
		doc /* The status indicator must provide visual or audible feedback when injection starts and completes. */
		subject : Autoinjector;
		predicate {
			subject.statusIndicator.feedbackType != "";
		}
	}

	satisfy 'Rapid Administration Requirement' by autoinjector;
	satisfy 'Safety Cap Requirement' by autoinjector.safetyCap;
	satisfy 'Activation Pressure Requirement' by autoinjector.activationMechanism;
	satisfy 'Injection Depth Requirement' by autoinjector.needleAssembly;
	satisfy 'Dose Volume Requirement' by autoinjector.medicationCartridge;
	satisfy 'Post-Injection Safety Requirement' by autoinjector.needleShield;
	satisfy 'User Feedback Requirement' by autoinjector.statusIndicator;
}
