package 'Penile Implant System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PumpActivationSignal;
	attribute def ValveActivationSignal;
	attribute def FluidTransferComplete;
	
	item def SalineFluid {
		attribute volume : VolumeValue;
		attribute pressure : PressureValue;
	}
	
	port def FluidPort {
		inout flow saline : SalineFluid;
	}
	
	port def ControlPort {
		in signal : Boolean;
	}
	
	part def FluidReservoir {
		attribute capacity : VolumeValue;
		attribute currentVolume : VolumeValue;
		port fluidOut : FluidPort;
	}
	
	part def ManualPump {
		attribute strokeVolume : VolumeValue;
		attribute compressionCount : Integer;
		port fluidIn : FluidPort;
		port fluidOut : FluidPort;
		port controlIn : ControlPort;
	}
	
	part def ReleaseValve {
		attribute isOpen : Boolean;
		attribute flowResistance : Real;
		port fluidIn : FluidPort;
		port fluidOut : FluidPort;
		port controlIn : ControlPort;
	}
	
	part def InflatableCylinder {
		attribute maxVolume : VolumeValue;
		attribute currentVolume : VolumeValue;
		attribute currentPressure : PressureValue;
		attribute maxPressure : PressureValue;
		attribute rigidityIndex : Real;
		port fluidIn : FluidPort;
		port fluidOut : FluidPort;
	}
	
	part def ThreeComponentImplant {
		part reservoir : FluidReservoir {
			attribute :>> capacity = 100.0 ['mL'];
			attribute :>> currentVolume = 100.0 ['mL'];
		}
		
		part pump : ManualPump {
			attribute :>> strokeVolume = 5.0 ['mL'];
			attribute :>> compressionCount = 0;
		}
		
		part releaseValve : ReleaseValve {
			attribute :>> isOpen = false;
			attribute :>> flowResistance = 0.1;
		}
		
		part leftCylinder : InflatableCylinder {
			attribute :>> maxVolume = 50.0 ['mL'];
			attribute :>> currentVolume = 0.0 ['mL'];
			attribute :>> currentPressure = 0.0 ['kPa'];
			attribute :>> maxPressure = 220.0 ['kPa'];
			attribute :>> rigidityIndex = 0.0;
		}
		
		part rightCylinder : InflatableCylinder {
			attribute :>> maxVolume = 50.0 ['mL'];
			attribute :>> currentVolume = 0.0 ['mL'];
			attribute :>> currentPressure = 0.0 ['kPa'];
			attribute :>> maxPressure = 220.0 ['kPa'];
			attribute :>> rigidityIndex = 0.0;
		}
		
		connect reservoir.fluidOut to pump.fluidIn;
		connect pump.fluidOut to leftCylinder.fluidIn;
		connect pump.fluidOut to rightCylinder.fluidIn;
		connect leftCylinder.fluidOut to releaseValve.fluidIn;
		connect rightCylinder.fluidOut to releaseValve.fluidIn;
		connect releaseValve.fluidOut to reservoir.fluidOut;
	}
	
	action def TransferFluid {
		in sourceVolume : VolumeValue;
		in transferAmount : VolumeValue;
		out newSourceVolume : VolumeValue;
		out newTargetVolume : VolumeValue;
	}
	
	action def CalculatePressure {
		in fluidVolume : VolumeValue;
		in cylinderMaxVolume : VolumeValue;
		out pressure : PressureValue;
	}
	
	action def CalculateRigidity {
		in currentPressure : PressureValue;
		in maxPressure : PressureValue;
		out rigidity : Real;
	}
	
	action def CompressPump {
		in strokeVolume : VolumeValue;
		in numberOfStrokes : Integer;
		out totalVolumeTransferred : VolumeValue;
	}
	
	action def OpenValve {
		out valveState : Boolean;
	}
	
	action def InflateDevice {
		in reservoirVolume : VolumeValue;
		in targetPressure : PressureValue;
		out leftCylinderPressure : PressureValue;
		out rightCylinderPressure : PressureValue;
		out leftRigidity : Real;
		out rightRigidity : Real;
		
		first start;
		then merge pumpCycle;
		then action compress : CompressPump {
			in strokeVolume = 5.0 ['mL'];
			in numberOfStrokes = 1;
			out totalVolumeTransferred;
		}
		then action transferLeft : TransferFluid {
			in sourceVolume = reservoirVolume;
			in transferAmount = compress.totalVolumeTransferred / 2.0;
			out newSourceVolume;
			out newTargetVolume;
		}
		then action transferRight : TransferFluid {
			in sourceVolume = transferLeft.newSourceVolume;
			in transferAmount = compress.totalVolumeTransferred / 2.0;
			out newSourceVolume;
			out newTargetVolume;
		}
		then action calcLeftPressure : CalculatePressure {
			in fluidVolume = transferLeft.newTargetVolume;
			in cylinderMaxVolume = 50.0 ['mL'];
			out pressure;
		}
		then action calcRightPressure : CalculatePressure {
			in fluidVolume = transferRight.newTargetVolume;
			in cylinderMaxVolume = 50.0 ['mL'];
			out pressure;
		}
		then action calcLeftRigidity : CalculateRigidity {
			in currentPressure = calcLeftPressure.pressure;
			in maxPressure = 220.0 ['kPa'];
			out rigidity;
		}
		then action calcRightRigidity : CalculateRigidity {
			in currentPressure = calcRightPressure.pressure;
			in maxPressure = 220.0 ['kPa'];
			out rigidity;
		}
		then assign leftCylinderPressure := calcLeftPressure.pressure;
		then assign rightCylinderPressure := calcRightPressure.pressure;
		then assign leftRigidity := calcLeftRigidity.rigidity;
		then assign rightRigidity := calcRightRigidity.rigidity;
		then decide;
			if leftCylinderPressure < targetPressure then pumpCycle;
			if leftCylinderPressure >= targetPressure then done;
	}
	
	action def DeflateDevice {
		in leftCylinderVolume : VolumeValue;
		in rightCylinderVolume : VolumeValue;
		out reservoirVolume : VolumeValue;
		
		first start;
		then action openReleaseValve : OpenValve {
			out valveState;
		}
		then action returnLeftFluid : TransferFluid {
			in sourceVolume = leftCylinderVolume;
			in transferAmount = leftCylinderVolume;
			out newSourceVolume;
			out newTargetVolume;
		}
		then action returnRightFluid : TransferFluid {
			in sourceVolume = rightCylinderVolume;
			in transferAmount = rightCylinderVolume;
			out newSourceVolume;
			out newTargetVolume;
		}
		then assign reservoirVolume := returnLeftFluid.newTargetVolume + returnRightFluid.newTargetVolume;
		then done;
	}
	
	state def ImplantOperationalStates {
		entry; then flaccidState;
		
		state flaccidState;
		
		transition flaccidToInflating
			first flaccidState
			accept pumpActivation : PumpActivationSignal
			then inflatingState;
		
		state inflatingState {
			entry action performInflation : InflateDevice {
				in reservoirVolume = 100.0 ['mL'];
				in targetPressure = 200.0 ['kPa'];
				out leftCylinderPressure;
				out rightCylinderPressure;
				out leftRigidity;
				out rightRigidity;
			}
		}
		
		transition inflatingToErect
			first inflatingState
			if performInflation.leftRigidity >= 0.85 and performInflation.rightRigidity >= 0.85
			then erectState;
		
		state erectState;
		
		transition erectToDeflating
			first erectState
			accept valveActivation : ValveActivationSignal
			then deflatingState;
		
		state deflatingState {
			entry action performDeflation : DeflateDevice {
				in leftCylinderVolume = 50.0 ['mL'];
				in rightCylinderVolume = 50.0 ['mL'];
				out reservoirVolume;
			}
		}
		
		transition deflatingToFlaccid
			first deflatingState
			if performDeflation.reservoirVolume >= 95.0 ['mL']
			then flaccidState;
	}
	
	action def OperateImplantSystem {
		in activationSignal : PumpActivationSignal;
		in deactivationSignal : ValveActivationSignal;
		
		first start;
		loop {
			accept pumpSignal : PumpActivationSignal;
			then action inflateAction : InflateDevice {
				in reservoirVolume = 100.0 ['mL'];
				in targetPressure = 200.0 ['kPa'];
				out leftCylinderPressure;
				out rightCylinderPressure;
				out leftRigidity;
				out rightRigidity;
			}
			then action accept valveSignal : ValveActivationSignal;
			then action deflateAction : DeflateDevice {
				in leftCylinderVolume = 50.0 ['mL'];
				in rightCylinderVolume = 50.0 ['mL'];
				out reservoirVolume;
			}
		}
	}
	
	requirement def FunctionalRequirement;
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	requirement def BiocompatibilityRequirement;
	
	requirement <'REQ-001'> primaryFunction : FunctionalRequirement {
		doc /*
		The penile implant system shall provide on-demand erectile function by hydraulically 
		transferring saline fluid from a reservoir to paired inflatable cylinders through 
		manual pump activation, and returning fluid to the reservoir through valve release.
		*/
		text "The system shall enable user-controlled erection and deflation on demand.";
	}
	
	requirement <'REQ-002'> pressureSafetyLimit : SafetyRequirement {
		doc /*
		The maximum pressure in each inflatable cylinder shall not exceed 220 kPa to prevent 
		tissue damage and device failure.
		*/
		text "Cylinder pressure shall not exceed 220 kPa.";
		
		subject implant : ThreeComponentImplant;
		
		require constraint {
			implant.leftCylinder.currentPressure <= implant.leftCylinder.maxPressure and
			implant.rightCylinder.currentPressure <= implant.rightCylinder.maxPressure
		}
	}
	
	requirement <'REQ-003'> rigidityPerformance : PerformanceRequirement {
		doc /*
		The system shall achieve at least 85% rigidity index in both cylinders to provide 
		adequate functional rigidity for intercourse.
		*/
		text "Both cylinders shall achieve rigidity index >= 0.85.";
		
		subject inflateAction : InflateDevice;
		
		require constraint {
			inflateAction.leftRigidity >= 0.85 and
			inflateAction.rightRigidity >= 0.85
		}
	}
	
	requirement <'REQ-004'> deflationCompleteness : PerformanceRequirement {
		doc /*
		The system shall return at least 95% of transferred fluid to the reservoir during 
		deflation to ensure complete flaccidity.
		*/
		text "Deflation shall return >= 95% of fluid to reservoir.";
		
		subject deflateAction : DeflateDevice;
		
		require constraint {
			deflateAction.reservoirVolume >= 95.0 ['mL']
		}
	}
	
	requirement <'REQ-005'> biocompatibleMaterials : BiocompatibilityRequirement {
		doc /*
		All components in contact with body tissue or fluids shall be constructed from 
		biocompatible materials meeting ISO 10993 standards for implantable medical devices.
		*/
		text "All materials shall meet ISO 10993 biocompatibility standards.";
		
		subject implant : ThreeComponentImplant;
	}
	
	requirement systemRequirements {
		doc /*
		The penile implant system shall restore erectile function through a hydraulic mechanism 
		that allows the user to achieve, maintain, and release an erection safely and reliably.
		*/
		
		assume constraint properImplantation {
			doc /* The device is surgically implanted with all components properly connected. */
		}
		
		assume constraint adequateReservoirFill {
			doc /* The reservoir is filled with sterile saline to specified capacity. */
		}
		
		require primaryFunction;
		require pressureSafetyLimit;
		require rigidityPerformance;
		require deflationCompleteness;
		require biocompatibleMaterials;
	}
	
	part implantSystem : ThreeComponentImplant {
		perform action systemOperation : OperateImplantSystem;
		
		exhibit state operationalBehavior : ImplantOperationalStates;
	}
	
	satisfy systemRequirements by implantSystem;
}
