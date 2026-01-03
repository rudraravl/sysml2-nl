package 'ATNAA System Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def InjectionCommand;
	attribute def SafetyState {
		attribute engaged : Boolean;
	}
	attribute def DeliveryStatus {
		attribute complete : Boolean;
		attribute volumeDelivered : VolumeValue;
	}
	
	item def Atropine {
		attribute concentration : Real;
		attribute volume : VolumeValue;
	}
	
	item def Pralidoxime {
		attribute concentration : Real;
		attribute volume : VolumeValue;
	}
	
	part def SafetyMechanism {
		attribute safetyEngaged : Boolean := true;
		out port safetyStatus : SafetyState;
	}
	
	part def SpringMechanism {
		attribute compressionForce : ForceValue;
		attribute releaseEnergy : EnergyValue;
		out port mechanicalForce : ForceValue;
	}
	
	part def PlungerAssembly {
		in port driveForce : ForceValue;
		out port deliveryPressure : PressureValue;
	}
	
	part def DualChamberCartridge {
		attribute atropineVolume : VolumeValue := 2.1[mL];
		attribute pralidoximeVolume : VolumeValue := 0.7[mL];
		in port injectionPressure : PressureValue;
		out port drugFlow : VolumeValue;
	}
	
	part def NeedleAssembly {
		attribute needleLength : LengthValue := 38[mm];
		attribute needleGauge : Real := 21.0;
		in port drugInput : VolumeValue;
		out port tissueDelivery : VolumeValue;
	}
	
	part def PressureSensor {
		in port pressureInput : PressureValue;
		out port deliveryComplete : Boolean;
	}
	
	part def IndicatorWindow {
		in port deliveryStatus : DeliveryStatus;
	}
	
	action def DisengageSafety {
		in safetyState : SafetyState;
		out safetyDisengaged : Boolean;
	}
	
	action def ActivateInjection {
		in command : InjectionCommand;
		in safetyDisengaged : Boolean;
		out injectionTriggered : Boolean;
	}
	
	action def ReleaseSpring {
		in trigger : Boolean;
		out force : ForceValue;
	}
	
	action def DrivePlunger {
		in force : ForceValue;
		out pressure : PressureValue;
		out volumeExpelled : VolumeValue;
	}
	
	action def DeliverAntidote {
		in pressure : PressureValue;
		in cartridgeVolume : VolumeValue;
		out deliveredVolume : VolumeValue;
		out deliveryTime : TimeValue;
	}
	
	action def MonitorDelivery {
		in pressure : PressureValue;
		in volumeDelivered : VolumeValue;
		out status : DeliveryStatus;
	}
	
	action def PerformAutoInjection {
		in safetyInput : SafetyState;
		in injectionCmd : InjectionCommand;
		out finalStatus : DeliveryStatus;
		
		first start;
		
		then action disengageSafety : DisengageSafety {
			in safetyState = safetyInput;
			out safetyDisengaged : Boolean;
		}
		
		then decide;
			if disengageSafety.safetyDisengaged then activateInjection;
			if not disengageSafety.safetyDisengaged then abortInjection;
		
		action activateInjection : ActivateInjection {
			in command = injectionCmd;
			in safetyDisengaged = disengageSafety.safetyDisengaged;
			out injectionTriggered : Boolean;
		}
		
		flow activateInjection.injectionTriggered to releaseSpring.trigger;
		
		then action releaseSpring : ReleaseSpring {
			in trigger : Boolean;
			out force : ForceValue;
		}
		
		flow releaseSpring.force to drivePlunger.force;
		
		then action drivePlunger : DrivePlunger {
			in force : ForceValue;
			out pressure : PressureValue;
			out volumeExpelled : VolumeValue;
		}
		
		flow drivePlunger.pressure to deliverAntidote.pressure;
		flow drivePlunger.volumeExpelled to deliverAntidote.cartridgeVolume;
		
		then action deliverAntidote : DeliverAntidote {
			in pressure : PressureValue;
			in cartridgeVolume : VolumeValue;
			out deliveredVolume : VolumeValue;
			out deliveryTime : TimeValue;
		}
		
		flow deliverAntidote.deliveredVolume to monitorDelivery.volumeDelivered;
		flow drivePlunger.pressure to monitorDelivery.pressure;
		
		then action monitorDelivery : MonitorDelivery {
			in pressure : PressureValue;
			in volumeDelivered : VolumeValue;
			out status : DeliveryStatus;
		}
		
		then assign finalStatus := monitorDelivery.status;
		then done;
		
		action abortInjection;
		then done;
	}
	
	part def ATNAA {
		doc /*
			Antidote Treatment Nerve Agent Auto-injector (ATNAA)
			Primary Function: Rapidly deliver a precise dual-chamber antidote combination 
			(atropine and pralidoxime) through automatic intramuscular injection upon 
			activation, providing immediate treatment for nerve agent exposure in emergency 
			field conditions.
		*/
		
		part safetyMechanism : SafetyMechanism;
		part springMechanism : SpringMechanism;
		part plungerAssembly : PlungerAssembly;
		part cartridge : DualChamberCartridge;
		part needleAssembly : NeedleAssembly;
		part pressureSensor : PressureSensor;
		part indicator : IndicatorWindow;
		
		connection springToPlunger connect 
			springMechanism.mechanicalForce to plungerAssembly.driveForce;
		
		connection plungerToCartridge connect 
			plungerAssembly.deliveryPressure to cartridge.injectionPressure;
		
		connection cartridgeToNeedle connect 
			cartridge.drugFlow to needleAssembly.drugInput;
		
		connection plungerToSensor connect 
			plungerAssembly.deliveryPressure to pressureSensor.pressureInput;
		
		perform action autoInjection : PerformAutoInjection {
			in safetyInput : SafetyState;
			in injectionCmd : InjectionCommand;
			out finalStatus : DeliveryStatus;
		}
	}
	
	part atnaaDevice : ATNAA {
		part redefines safetyMechanism {
			perform autoInjection.disengageSafety;
		}
		
		part redefines springMechanism {
			perform autoInjection.releaseSpring;
		}
		
		part redefines plungerAssembly {
			perform autoInjection.drivePlunger;
		}
		
		part redefines cartridge {
			perform autoInjection.deliverAntidote;
		}
		
		part redefines pressureSensor {
			perform autoInjection.monitorDelivery;
		}
	}
	
	requirement def DeliveryPerformanceRequirement {
		doc /* The ATNAA shall deliver the complete antidote dose within specified parameters. */
		
		require constraint deliveryVolume {
			doc /* Total delivered volume shall be 2.8 mL ± 0.15 mL (2.1 mL atropine + 0.7 mL pralidoxime). */
		}
		
		require constraint deliveryTime {
			doc /* Complete dose delivery shall occur within 10 seconds of activation. */
		}
		
		require constraint injectionDepth {
			doc /* Needle penetration shall achieve intramuscular depth of at least 25 mm. */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The ATNAA shall incorporate safety mechanisms to prevent accidental discharge. */
		
		require constraint safetyEngagement {
			doc /* Safety mechanism shall remain engaged until deliberate removal by user. */
		}
		
		require constraint activationForce {
			doc /* Activation shall require minimum force of 15 N to prevent accidental triggering. */
		}
	}
	
	requirement def ReliabilityRequirement {
		doc /* The ATNAA shall maintain operational readiness under field conditions. */
		
		require constraint shelfLife {
			doc /* Device shall maintain full functionality for minimum 24 months from manufacture. */
		}
		
		require constraint temperatureRange {
			doc /* Device shall operate reliably in temperature range -10°C to +50°C. */
		}
		
		require constraint mechanicalReliability {
			doc /* Spring mechanism shall achieve 99.5% successful activation rate. */
		}
	}
	
	requirement atnaaOperationalRequirements {
		subject atnaaDevice;
		
		require constraint deliveryPerformance : DeliveryPerformanceRequirement;
		require constraint safety : SafetyRequirement;
		require constraint reliability : ReliabilityRequirement;
		
		assume constraint usageContext {
			doc /* The ATNAA is deployed in emergency field conditions for immediate nerve agent exposure treatment. */
		}
		
		assume constraint userTraining {
			doc /* Users receive basic training on ATNAA activation and application procedures. */
		}
	}
}
