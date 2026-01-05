package SubstanceBasedMedicalDeviceSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ConcentrationValue :> Real {
		doc /* Concentration in milligrams per milliliter */
	}
	
	attribute def FlowRateValue :> Real {
		doc /* Flow rate in milliliters per hour */
	}
	
	item def TherapeuticSubstance {
		attribute name : String;
		attribute concentration : ConcentrationValue;
		attribute volume : VolumeValue;
		attribute temperature : TemperatureValue;
	}
	
	item def InsulinSolution :> TherapeuticSubstance {
		attribute batchNumber : String;
		attribute expirationDate : String;
	}
	
	port def SubstanceFlowPort {
		in item substance : TherapeuticSubstance;
		out item substance : TherapeuticSubstance;
	}
	
	port def ControlSignalPort {
		in attribute commandedRate : FlowRateValue;
		out attribute actualRate : FlowRateValue;
	}
	
	port def SensorDataPort {
		out attribute measuredVolume : VolumeValue;
		out attribute measuredPressure : PressureValue;
		out attribute systemStatus : String;
	}
	
	part def SubstanceReservoir {
		attribute capacity : VolumeValue;
		attribute currentLevel : VolumeValue;
		port flowOut : SubstanceFlowPort;
		port sensorData : SensorDataPort;
		
		action def CheckLevel {
			out levelReading : VolumeValue;
		}
	}
	
	part def InfusionPump {
		attribute pumpSpeed : Real;
		attribute operatingPressure : PressureValue;
		port flowIn : SubstanceFlowPort;
		port flowOut : SubstanceFlowPort;
		port controlSignal : ControlSignalPort;
		
		action def AdjustPumpRate {
			in targetRate : FlowRateValue;
			out achievedRate : FlowRateValue;
		}
	}
	
	part def FlowController {
		attribute targetFlowRate : FlowRateValue;
		attribute actualFlowRate : FlowRateValue;
		attribute tolerancePercent : Real;
		port controlOut : ControlSignalPort;
		port sensorIn : SensorDataPort;
		
		action def RegulateFlow {
			in desiredRate : FlowRateValue;
			in currentRate : FlowRateValue;
			out correctedRate : FlowRateValue;
		}
	}
	
	part def SafetyMonitor {
		attribute maxSafeFlowRate : FlowRateValue;
		attribute minSafeFlowRate : FlowRateValue;
		attribute alarmActive : Boolean;
		port monitoringIn : SensorDataPort;
		
		action def CheckSafetyLimits {
			in currentRate : FlowRateValue;
			out safetyViolation : Boolean;
		}
	}
	
	part def PatientInterface {
		attribute patientID : String;
		attribute bodyWeight : MassValue;
		port substanceDelivery : SubstanceFlowPort;
		
		event occurrence therapyStarted;
		event occurrence therapyCompleted;
		event occurrence adverseEvent;
	}
	
	action def LoadSubstanceReservoir {
		in item substanceToLoad : TherapeuticSubstance;
		in targetVolume : VolumeValue;
		out loadSuccess : Boolean;
	}
	
	action def PrimeDeliverySystem {
		in primingVolume : VolumeValue;
		out primingComplete : Boolean;
	}
	
	action def DeliverTherapeuticDose {
		in item therapeuticSubstance : TherapeuticSubstance;
		in prescribedDose : VolumeValue;
		in prescribedRate : FlowRateValue;
		in therapyDuration : TimeValue;
		out deliverySuccess : Boolean;
		
		private attribute elapsedTime : TimeValue := 0.0 [s];
		private attribute deliveredVolume : VolumeValue := 0.0 [mL];
		
		first start;
		then action loadReservoir : LoadSubstanceReservoir {
			in substanceToLoad = therapeuticSubstance;
			in targetVolume = prescribedDose;
			out loadSuccess;
		}
		
		then decide;
			if loadReservoir.loadSuccess then primeSystem;
			if !loadReservoir.loadSuccess then abortDelivery;
		
		action primeSystem : PrimeDeliverySystem {
			in primingVolume = 2.0 [mL];
			out primingComplete;
		}
		
		then decide;
			if primeSystem.primingComplete then beginInfusion;
			if !primeSystem.primingComplete then abortDelivery;
		
		action beginInfusion;
		then merge infusionLoop;
		
		then action monitorDelivery {
			out currentVolume : VolumeValue;
			out currentTime : TimeValue;
		}
		
		then decide;
			if monitorDelivery.currentVolume < prescribedDose and 
			   monitorDelivery.currentTime < therapyDuration then checkSafety;
			if monitorDelivery.currentVolume >= prescribedDose or 
			   monitorDelivery.currentTime >= therapyDuration then completeInfusion;
		
		action checkSafety {
			out safetyOK : Boolean;
		}
		
		then decide;
			if checkSafety.safetyOK then infusionLoop;
			if !checkSafety.safetyOK then emergencyStop;
		
		action completeInfusion {
			assign deliverySuccess := true;
		}
		then done;
		
		action emergencyStop {
			assign deliverySuccess := false;
		}
		then done;
		
		action abortDelivery {
			assign deliverySuccess := false;
		}
		then done;
	}
	
	state def InfusionDeviceStates {
		entry; then standby;
		
		state standby {
			doc /* Device is powered on but not actively delivering therapy */
		}
		
		accept at standby
			if loadCommandReceived
			then loading;
		
		state loading {
			doc /* Reservoir is being filled with therapeutic substance */
			do action loadingAction;
		}
		
		accept at loading
			if loadingComplete
			then priming;
		
		accept at loading
			if loadingFailed
			then fault;
		
		state priming {
			doc /* System is being primed to remove air from delivery pathway */
			do action primingAction;
		}
		
		accept at priming
			if primingComplete
			then ready;
		
		accept at priming
			if primingFailed
			then fault;
		
		state ready {
			doc /* Device is ready to begin therapy delivery */
		}
		
		accept at ready
			if startCommandReceived
			then infusing;
		
		accept at ready
			if cancelCommandReceived
			then standby;
		
		state infusing {
			doc /* Actively delivering therapeutic substance to patient */
			do action infusingAction;
		}
		
		accept at infusing
			if pauseCommandReceived
			then paused;
		
		accept at infusing
			if therapyComplete
			then completed;
		
		accept at infusing
			if safetyLimitExceeded
			then alarm;
		
		state paused {
			doc /* Therapy delivery temporarily suspended */
		}
		
		accept at paused
			if resumeCommandReceived
			then infusing;
		
		accept at paused
			if stopCommandReceived
			then standby;
		
		state completed {
			doc /* Prescribed therapy has been fully delivered */
		}
		
		accept at completed
			if acknowledgeCommandReceived
			then standby;
		
		state alarm {
			doc /* Safety violation detected, delivery halted */
			do action alarmAction;
		}
		
		accept at alarm
			if alarmResetCommandReceived
			then standby;
		
		state fault {
			doc /* System fault requiring service intervention */
		}
		
		accept at fault
			if faultClearedCommandReceived
			then standby;
		
		event loadCommandReceived;
		event loadingComplete;
		event loadingFailed;
		event primingComplete;
		event primingFailed;
		event startCommandReceived;
		event cancelCommandReceived;
		event pauseCommandReceived;
		event therapyComplete;
		event safetyLimitExceeded;
		event resumeCommandReceived;
		event stopCommandReceived;
		event acknowledgeCommandReceived;
		event alarmResetCommandReceived;
		event faultClearedCommandReceived;
		
		action loadingAction;
		action primingAction;
		action infusingAction;
		action alarmAction;
	}
	
	part substanceBasedMedicalDevice {
		doc /*
			A substance-based medical device that delivers therapeutic substances
			to patients at controlled rates. The system ensures safe, accurate,
			and monitored delivery of medications through automated control and
			continuous safety monitoring.
		*/
		
		attribute deviceID : String;
		attribute manufacturerName : String;
		attribute modelNumber : String;
		
		part reservoir : SubstanceReservoir {
			attribute :>> capacity = 500.0 [mL];
			attribute :>> currentLevel = 0.0 [mL];
		}
		
		part pump : InfusionPump {
			attribute :>> pumpSpeed = 0.0;
			attribute :>> operatingPressure = 0.0 [Pa];
		}
		
		part controller : FlowController {
			attribute :>> targetFlowRate = 0.0 [mL/h];
			attribute :>> actualFlowRate = 0.0 [mL/h];
			attribute :>> tolerancePercent = 10.0;
		}
		
		part safetyMonitor : SafetyMonitor {
			attribute :>> maxSafeFlowRate = 250.0 [mL/h];
			attribute :>> minSafeFlowRate = 0.1 [mL/h];
			attribute :>> alarmActive = false;
		}
		
		ref patient : PatientInterface;
		
		connection reservoirToPump connect reservoir.flowOut to pump.flowIn;
		connection pumpToPatient connect pump.flowOut to patient.substanceDelivery;
		connection controllerToPump connect controller.controlOut to pump.controlSignal;
		connection reservoirToSafety connect reservoir.sensorData to safetyMonitor.monitoringIn;
		connection pumpToController connect pump.controlSignal to controller.controlOut;
		
		perform action deliverTherapy : DeliverTherapeuticDose[*] ordered;
		
		exhibit state deviceOperation : InfusionDeviceStates;
	}
	
	requirement <'REQ-SYS-001'> primaryFunctionRequirement {
		doc /*
			The substance-based medical device shall deliver therapeutic substances
			to patients at prescribed flow rates with accuracy within ±10% of the
			target rate throughout the therapy duration.
		*/
		
		subject device : substanceBasedMedicalDevice;
		
		require constraint flowRateAccuracy {
			device.controller.actualFlowRate >= device.controller.targetFlowRate * 0.9 and
			device.controller.actualFlowRate <= device.controller.targetFlowRate * 1.1
		}
	}
	
	requirement <'REQ-SYS-002'> safetyMonitoringRequirement {
		doc /*
			The device shall continuously monitor delivery parameters and activate
			alarms when flow rates exceed safe operating limits.
		*/
		
		subject device : substanceBasedMedicalDevice;
		
		require constraint safetyLimitsEnforced {
			device.controller.actualFlowRate > device.safetyMonitor.maxSafeFlowRate or
			device.controller.actualFlowRate < device.safetyMonitor.minSafeFlowRate
			implies device.safetyMonitor.alarmActive
		}
	}
	
	requirement <'REQ-SYS-003'> reservoirMonitoringRequirement {
		doc /*
			The device shall monitor reservoir levels and alert when remaining
			volume falls below 10% of capacity.
		*/
		
		subject device : substanceBasedMedicalDevice;
		
		require constraint lowVolumeAlert {
			device.reservoir.currentLevel < device.reservoir.capacity * 0.1
			implies device.safetyMonitor.alarmActive
		}
	}
	
	requirement <'REQ-SYS-004'> operationalStateRequirement {
		doc /*
			The device shall maintain proper operational state transitions and
			enter alarm state upon detection of any safety violations during
			active therapy delivery.
		*/
		
		subject device : substanceBasedMedicalDevice;
		
		assume constraint activeDelivery {
			device.deviceOperation.infusing
		}
		
		require constraint safetyResponse {
			device.deviceOperation.safetyLimitExceeded implies
			device.deviceOperation.alarm
		}
	}
	
	requirement deviceMissionRequirement {
		doc /*
			The primary function of the substance-based medical device is to
			safely and accurately deliver prescribed therapeutic substances to
			patients through automated, controlled infusion with continuous
			monitoring and safety enforcement.
		*/
		
		subject device : substanceBasedMedicalDevice;
		
		require primaryFunctionRequirement;
		require safetyMonitoringRequirement;
		require reservoirMonitoringRequirement;
		require operationalStateRequirement;
	}
}
