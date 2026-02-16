package IontophoresisSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ImpedanceValue {
		attribute magnitude : Real;
	}
	
	item def TherapeuticDrug {
		attribute ionicCharge : Real;
		attribute molecularWeight : Real;
		attribute concentration : Real;
	}
	
	item def CurrentCommand {
		attribute targetCurrent : ElectricCurrentValue;
	}
	
	item def ImpedanceMeasurement {
		attribute skinImpedance : ImpedanceValue;
		attribute timestamp : TimeValue;
	}
	
	enum def TreatmentState {
		idle;
		preparation;
		activeDelivery;
		completed;
		fault;
	}
	
	port def PowerPort {
		out attribute voltage : VoltageValue;
		out attribute current : ElectricCurrentValue;
	}
	
	port def DrugPort {
		out item drug : TherapeuticDrug;
		attribute flowRate : Real;
	}
	
	port def SkinContactPort {
		in attribute impedance : ImpedanceValue;
		attribute contactArea : AreaValue;
	}
	
	part def PowerSupply {
		port output : PowerPort;
		
		attribute maxVoltage : VoltageValue;
		attribute maxCurrent : ElectricCurrentValue;
		
		perform action generatePower {
			in requestedCurrent : ElectricCurrentValue;
			out suppliedVoltage : VoltageValue;
			out suppliedCurrent : ElectricCurrentValue;
		}
	}
	
	part def CurrentRegulator {
		port powerIn : ~PowerPort;
		port powerOut : PowerPort;
		
		attribute setpoint : ElectricCurrentValue;
		attribute measuredCurrent : ElectricCurrentValue;
		attribute controlGain : Real;
		
		perform action regulateCurrent {
			in targetCurrent : ElectricCurrentValue;
			in feedbackCurrent : ElectricCurrentValue;
			out outputVoltage : VoltageValue;
		}
	}
	
	part def DrugReservoir {
		port drugOutput : DrugPort;
		
		attribute storedDrug : TherapeuticDrug;
		attribute remainingVolume : VolumeValue;
		attribute initialDose : MassValue;
		
		perform action releaseDrug {
			in appliedField : VoltageValue;
			out drugFlow : TherapeuticDrug;
			out flowRate : Real;
		}
	}
	
	part def ActiveElectrode {
		port electricalInput : ~PowerPort;
		port drugInput : ~DrugPort;
		port skinInterface : SkinContactPort;
		
		attribute polarity : Real;
		attribute surfaceArea : AreaValue;
		attribute conductivity : Real;
		
		perform action deliverIons {
			in current : ElectricCurrentValue;
			in drugIons : TherapeuticDrug;
			out ionFlux : Real;
		}
	}
	
	part def ReturnElectrode {
		port electricalConnection : ~PowerPort;
		port skinInterface : SkinContactPort;
		
		attribute polarity : Real;
		attribute surfaceArea : AreaValue;
	}
	
	part def SkinBarrier {
		port activeContact : ~SkinContactPort;
		port returnContact : ~SkinContactPort;
		
		attribute epidermisResistance : ImpedanceValue;
		attribute dermisResistance : ImpedanceValue;
		attribute permeability : Real;
		
		perform action absorbDrug {
			in drugIons : TherapeuticDrug;
			in drivingCurrent : ElectricCurrentValue;
			out penetrationDepth : LengthValue;
			out absorbedDose : MassValue;
		}
	}
	
	part def ImpedanceSensor {
		attribute measuredImpedance : ImpedanceValue;
		
		perform action measureImpedance {
			in appliedVoltage : VoltageValue;
			in measuredCurrent : ElectricCurrentValue;
			out impedance : ImpedanceValue;
		}
	}
	
	part def SafetyMonitor {
		attribute maxSafeCurrent : ElectricCurrentValue;
		attribute maxTreatmentTime : TimeValue;
		attribute impedanceThreshold : ImpedanceValue;
		
		perform action checkSafety {
			in currentLevel : ElectricCurrentValue;
			in elapsedTime : TimeValue;
			in skinImpedance : ImpedanceValue;
			out isSafe : Boolean;
			out shutdownRequired : Boolean;
		}
	}
	
	part def TreatmentController {
		attribute currentState : TreatmentState;
		attribute targetDosage : MassValue;
		attribute deliveredDosage : MassValue;
		attribute treatmentDuration : TimeValue;
		
		perform action controlTreatment;
	}
	
	part iontophoresisDevice {
		part powerSupply : PowerSupply {
			attribute :>> maxVoltage = 60.0 [V];
			attribute :>> maxCurrent = 4.0e-3 [A];
		}
		
		part currentRegulator : CurrentRegulator {
			attribute :>> setpoint = 2.0e-3 [A];
			attribute :>> controlGain = 0.75;
		}
		
		part drugReservoir : DrugReservoir {
			attribute :>> storedDrug : TherapeuticDrug {
				attribute :>> ionicCharge = 1.0;
				attribute :>> molecularWeight = 350.0;
				attribute :>> concentration = 2.0;
			}
			attribute :>> initialDose = 0.04 [kg];
		}
		
		part activeElectrode : ActiveElectrode {
			attribute :>> polarity = 1.0;
			attribute :>> surfaceArea = 0.0012 [m^2];
			attribute :>> conductivity = 0.9;
		}
		
		part returnElectrode : ReturnElectrode {
			attribute :>> polarity = -1.0;
			attribute :>> surfaceArea = 0.002 [m^2];
		}
		
		part skinBarrier : SkinBarrier {
			attribute :>> permeability = 0.25;
		}
		
		part impedanceSensor : ImpedanceSensor;
		
		part safetyMonitor : SafetyMonitor {
			attribute :>> maxSafeCurrent = 4.0e-3 [A];
			attribute :>> maxTreatmentTime = 1800.0 [s];
		}
		
		part treatmentController : TreatmentController {
			attribute :>> currentState = TreatmentState::idle;
			attribute :>> targetDosage = 0.04 [kg];
		}
		
		connection powerToRegulator connect 
			powerSupply.output to currentRegulator.powerIn;
		
		connection regulatorToElectrode connect 
			currentRegulator.powerOut to activeElectrode.electricalInput;
		
		connection drugToElectrode connect 
			drugReservoir.drugOutput to activeElectrode.drugInput;
		
		connection activeToSkin connect 
			activeElectrode.skinInterface to skinBarrier.activeContact;
		
		connection returnToSkin connect 
			returnElectrode.skinInterface to skinBarrier.returnContact;
		
		perform action executeIontophoresis;
	}
	
	action def InitializeTreatment {
		in targetDose : MassValue;
		in drugType : TherapeuticDrug;
		out systemReady : Boolean;
	}
	
	action def ApplyElectricCurrent {
		in setCurrent : ElectricCurrentValue;
		in duration : TimeValue;
		out actualCurrent : ElectricCurrentValue;
		out appliedVoltage : VoltageValue;
	}
	
	action def TransportDrugIons {
		in drivingCurrent : ElectricCurrentValue;
		in drugMolecules : TherapeuticDrug;
		in tissueBarrier : ImpedanceValue;
		out ionicFlux : Real;
		out deliveryRate : Real;
	}
	
	action def MonitorProgress {
		in currentDose : MassValue;
		in targetDose : MassValue;
		in elapsedTime : TimeValue;
		out progressPercent : Real;
		out shouldContinue : Boolean;
	}
	
	action def TerminateTreatment {
		in finalDose : MassValue;
		in totalTime : TimeValue;
		out treatmentSummary : String;
	}
	
	action iontophoreticDelivery {
		first start;
		
		then action initialize : InitializeTreatment {
			in targetDose = iontophoresisDevice.treatmentController.targetDosage;
			in drugType = iontophoresisDevice.drugReservoir.storedDrug;
			out systemReady;
		}
		
		then merge treatmentCycle;
		
		then action applyCurrent : ApplyElectricCurrent {
			in setCurrent = iontophoresisDevice.currentRegulator.setpoint;
			in duration = 60.0 [s];
			out actualCurrent;
			out appliedVoltage;
		}
		
		then action transportIons : TransportDrugIons {
			in drivingCurrent = applyCurrent.actualCurrent;
			in drugMolecules = iontophoresisDevice.drugReservoir.storedDrug;
			in tissueBarrier = iontophoresisDevice.skinBarrier.epidermisResistance;
			out ionicFlux;
			out deliveryRate;
		}
		
		then action monitor : MonitorProgress {
			in currentDose = iontophoresisDevice.treatmentController.deliveredDosage;
			in targetDose = iontophoresisDevice.treatmentController.targetDosage;
			in elapsedTime = iontophoresisDevice.treatmentController.treatmentDuration;
			out progressPercent;
			out shouldContinue;
		}
		
		then decide;
			if monitor.shouldContinue then treatmentCycle;
			else terminate;
		
		action terminate : TerminateTreatment {
			in finalDose = iontophoresisDevice.treatmentController.deliveredDosage;
			in totalTime = iontophoresisDevice.treatmentController.treatmentDuration;
			out treatmentSummary;
		}
		
		then done;
	}
	
	state def TreatmentStateMachine {
		entry; then idle;
		
		state idle {
			entry assign iontophoresisDevice.treatmentController.currentState := TreatmentState::idle;
		}
		accept at idle then preparing when StartSignal;
		
		state preparing {
			entry assign iontophoresisDevice.treatmentController.currentState := TreatmentState::preparation;
			do action prepareSystem;
		}
		accept at preparing then delivering when ReadySignal;
		
		state delivering {
			entry assign iontophoresisDevice.treatmentController.currentState := TreatmentState::activeDelivery;
			do action performDelivery;
		}
		accept at delivering then completed when DoseCompleteSignal;
		accept at delivering then fault when SafetyAlarmSignal;
		
		state completed {
			entry assign iontophoresisDevice.treatmentController.currentState := TreatmentState::completed;
			do action finalizeTreatment;
		}
		accept at completed then idle when ResetSignal;
		
		state fault {
			entry assign iontophoresisDevice.treatmentController.currentState := TreatmentState::fault;
			do action handleFault;
		}
		accept at fault then idle when ClearFaultSignal;
	}
	
	requirement def TransdermalDeliveryRequirement {
		doc /* The system shall deliver therapeutic drug molecules across the skin barrier 
		       using controlled electric current to drive ionized compounds through tissue. */
		
		require constraint currentControl {
			iontophoresisDevice.currentRegulator.measuredCurrent <= 
			iontophoresisDevice.safetyMonitor.maxSafeCurrent
		}
		
		require constraint dosageAccuracy {
			(iontophoresisDevice.treatmentController.deliveredDosage / 
			 iontophoresisDevice.treatmentController.targetDosage) >= 0.85 and
			(iontophoresisDevice.treatmentController.deliveredDosage / 
			 iontophoresisDevice.treatmentController.targetDosage) <= 1.15
		}
	}
	
	requirement def PatientSafetyRequirement {
		doc /* The system shall ensure patient safety by limiting current exposure and 
		       monitoring tissue impedance throughout treatment. */
		
		require constraint currentLimit {
			iontophoresisDevice.currentRegulator.measuredCurrent <= 
			iontophoresisDevice.safetyMonitor.maxSafeCurrent
		}
		
		require constraint timeLimit {
			iontophoresisDevice.treatmentController.treatmentDuration <= 
			iontophoresisDevice.safetyMonitor.maxTreatmentTime
		}
		
		require constraint impedanceMonitoring {
			iontophoresisDevice.impedanceSensor.measuredImpedance.magnitude >= 
			iontophoresisDevice.safetyMonitor.impedanceThreshold.magnitude
		}
	}
	
	requirement <'IONTO-001'> primaryFunctionRequirement : TransdermalDeliveryRequirement {
		doc /* The iontophoresis system shall deliver ionized therapeutic drugs through 
		       intact skin using controlled low-level direct electric current, enabling 
		       non-invasive transdermal drug administration for localized or systemic therapy. 
		       The system applies a small electric potential difference across electrodes placed 
		       on the skin surface, creating an electric field that drives charged drug molecules 
		       through the stratum corneum and into underlying tissue layers. */
		
		assume constraint drugIsIonized {
			iontophoresisDevice.drugReservoir.storedDrug.ionicCharge != 0.0
		}
		
		assume constraint skinIntact {
			iontophoresisDevice.skinBarrier.permeability > 0.0 and
			iontophoresisDevice.skinBarrier.permeability < 1.0
		}
		
		require primaryFunctionRequirement;
		require safetyRequirement;
	}
	
	requirement safetyRequirement : PatientSafetyRequirement;
}
