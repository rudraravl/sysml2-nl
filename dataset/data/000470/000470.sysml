package MedicalDeviceSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	attribute def VoltageValue :> Real;
	attribute def CurrentValue :> Real;
	attribute def EnergyValue :> Real;
	attribute def DoseValue :> Real;
	attribute def FlowRateValue :> Real;
	
	attribute def DeviceStatus {
		attribute isOperational : Boolean;
		attribute isPowered : Boolean;
		attribute isSafeToOperate : Boolean;
	}
	
	attribute def TherapyParameters {
		attribute doseRate : DoseValue;
		attribute duration : DurationValue;
		attribute totalDose : DoseValue;
	}
	
	attribute def BatteryState {
		attribute chargeLevel : Real;
		attribute voltage : VoltageValue;
		attribute remainingEnergy : EnergyValue;
		attribute isChargeable : Boolean;
	}
	
	attribute def PatientVitals {
		attribute heartRate : Real;
		attribute bloodPressure : Real;
		attribute temperature : Real;
	}
	
	item def TherapySignal {
		attribute parameters : TherapyParameters;
	}
	
	item def PowerSupplySignal {
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
	}
	
	item def MonitoringData {
		attribute vitals : PatientVitals;
		attribute deviceStatus : DeviceStatus;
	}
	
	port def PowerPort {
		out item powerOut : PowerSupplySignal;
	}
	
	port def TherapyPort {
		out item therapyOut : TherapySignal;
	}
	
	port def MonitoringPort {
		in item monitoringIn : MonitoringData;
	}
	
	part def Battery {
		attribute batteryState : BatteryState;
		port powerOutput : PowerPort;
		
		event occurrence depleted;
		event occurrence cannotBeCharged;
		
		action def SupplyPower {
			in requiredEnergy : EnergyValue;
			out suppliedEnergy : EnergyValue;
		}
		
		action def MonitorCharge {
			out currentCharge : Real;
		}
	}
	
	part def PowerManagement {
		attribute outputVoltage : VoltageValue;
		attribute outputCurrent : CurrentValue;
		port powerIn : PowerPort;
		port powerOut : PowerPort;
		
		action def RegulatePower {
			in inputVoltage : VoltageValue;
			out regulatedVoltage : VoltageValue;
		}
		
		action def MonitorPowerStatus {
			out powerAvailable : Boolean;
		}
	}
	
	part def TherapyDeliveryUnit {
		attribute currentParameters : TherapyParameters;
		port therapyOutput : TherapyPort;
		port powerInput : PowerPort;
		
		action def DeliverTherapy {
			in parameters : TherapyParameters;
			out deliveryStatus : Boolean;
		}
		
		action def AdjustDose {
			in currentDose : DoseValue;
			in targetDose : DoseValue;
			out adjustedDose : DoseValue;
		}
	}
	
	part def SafetyMonitor {
		attribute safetyStatus : DeviceStatus;
		port monitoringInput : MonitoringPort;
		
		action def CheckSafetyConditions {
			in vitals : PatientVitals;
			in deviceStatus : DeviceStatus;
			out isSafe : Boolean;
		}
		
		action def TriggerAlarm {
			in alarmCondition : String;
			out alarmActivated : Boolean;
		}
		
		action def InitiateShutdown {
			out shutdownComplete : Boolean;
		}
	}
	
	part def ControlProcessor {
		attribute operatingMode : String;
		
		action def ProcessCommands {
			in userCommand : String;
			out commandExecuted : Boolean;
		}
		
		action def CoordinateTherapy {
			in therapyRequest : TherapyParameters;
			in safetyStatus : Boolean;
			out therapyAuthorized : Boolean;
		}
	}
	
	part def UserInterface {
		attribute displayState : String;
		
		action def DisplayStatus {
			in status : DeviceStatus;
			in parameters : TherapyParameters;
		}
		
		action def AcceptInput {
			out userParameters : TherapyParameters;
		}
		
		action def ShowAlarm {
			in alarmMessage : String;
		}
	}
	
	event def PowerOnEvent;
	event def SelfTestPassEvent;
	event def ConfigurationCompleteEvent;
	event def StartTherapyEvent;
	event def PauseEvent;
	event def ResumeEvent;
	event def SafetyViolationEvent;
	event def CriticalAlarmEvent;
	event def AlarmClearedEvent;
	event def ResetEvent;
	event def TherapyCompleteEvent;
	event def AcknowledgeEvent;
	event def EmergencyStopEvent;
	
	action def InitializeSystem;
	action def PerformSelfTest;
	action def MonitorBatteryAction;
	action def EnableControls;
	action def AwaitConfiguration;
	action def ValidateParameters;
	action def BeginTherapyDelivery;
	action def ContinuousMonitoring;
	action def ActiveTherapyDelivery;
	action def SuspendTherapy;
	action def MaintainMonitoring;
	action def ActivateAlarmAction;
	action def NotifyUser;
	action def SecureDevice;
	action def FinalizeSession;
	action def GenerateReport;
	action def EmergencyShutdownAction;
	
	state def MedicalDeviceStates {
		entry; then powerOff;
		
		state powerOff {
			entry action initializeSystem : InitializeSystem;
		}
		
		transition powerOff_to_standby
			first powerOff
			accept PowerOnEvent
			then standby;
		
		state standby {
			entry action performSelfTest : PerformSelfTest;
			do action monitorBattery : MonitorBatteryAction;
		}
		
		transition standby_to_ready
			first standby
			accept SelfTestPassEvent
			then ready;
		
		state ready {
			entry action enableControls : EnableControls;
			do action awaitConfiguration : AwaitConfiguration;
		}
		
		transition ready_to_configured
			first ready
			accept ConfigurationCompleteEvent
			then configured;
		
		state configured {
			entry action validateParameters : ValidateParameters;
		}
		
		transition configured_to_active
			first configured
			accept StartTherapyEvent
			then active;
		
		state active {
			entry action beginTherapyDelivery : BeginTherapyDelivery;
			
			state monitoringPatient {
				do action continuousMonitoring : ContinuousMonitoring;
			}
			
			state deliveringTherapy {
				do action activeTherapyDelivery : ActiveTherapyDelivery;
			}
		}
		
		transition active_to_paused
			first active
			accept PauseEvent
			then paused;
		
		state paused {
			entry action suspendTherapy : SuspendTherapy;
			do action maintainMonitoring : MaintainMonitoring;
		}
		
		transition paused_to_active
			first paused
			accept ResumeEvent
			then active;
		
		transition to_alarm
			first active
			accept SafetyViolationEvent
			then alarm;
		
		transition to_alarm_from_paused
			first paused
			accept CriticalAlarmEvent
			then alarm;
		
		state alarm {
			entry action activateAlarm : ActivateAlarmAction;
			do action notifyUser : NotifyUser;
		}
		
		transition alarm_to_safe
			first alarm
			accept AlarmClearedEvent
			then safe;
		
		state safe {
			entry action secureDevice : SecureDevice;
		}
		
		transition safe_to_standby
			first safe
			accept ResetEvent
			then standby;
		
		transition active_to_complete
			first active
			accept TherapyCompleteEvent
			then complete;
		
		state complete {
			entry action finalizeSession : FinalizeSession;
			do action generateReport : GenerateReport;
		}
		
		transition complete_to_standby
			first complete
			accept AcknowledgeEvent
			then standby;
		
		transition to_emergency
			first active
			accept EmergencyStopEvent
			then emergency;
		
		state emergency {
			entry action emergencyShutdown : EmergencyShutdownAction;
		}
		
		transition emergency_to_powerOff
			first emergency
			then powerOff;
	}
	
	action def ProvideTherapeuticTreatment {
		doc /* Primary system function: Deliver controlled therapeutic treatment to patient 
		     while continuously monitoring safety parameters and patient condition. */
		
		first start;
		then action initialize : InitializeDevice;
		then action configure : ConfigureTherapy;
		then merge therapyLoop;
		
		action monitor : MonitorPatientAndDevice {
			out vitals : PatientVitals;
			out deviceStatus : DeviceStatus;
		}
		then therapyLoop;
		
		then action checkSafety : EvaluateSafety {
			in vitals = monitor.vitals;
			in status = monitor.deviceStatus;
			out isSafe : Boolean;
		}
		
		then decide;
			if checkSafety.isSafe == true then deliver;
			if checkSafety.isSafe == false then alarm;
		
		action deliver : DeliverDose {
			in parameters = configure.therapyParameters;
			out doseDelivered : DoseValue;
		}
		then checkCompletion;
		
		action checkCompletion : CheckTherapyComplete {
			in totalDelivered : DoseValue;
			in targetDose : DoseValue;
			out isComplete : Boolean;
		}
		
		then decide;
			if checkCompletion.isComplete == false then therapyLoop;
			if checkCompletion.isComplete == true then finalize;
		
		action alarm : ActivateAlarm {
			in alarmReason : String;
		}
		then shutdown;
		
		action shutdown : SafeShutdown;
		then done;
		
		action finalize : FinalizeTherapy;
		then done;
	}
	
	action def InitializeDevice {
		out initializationSuccess : Boolean;
	}
	
	action def ConfigureTherapy {
		out therapyParameters : TherapyParameters;
	}
	
	action def MonitorPatientAndDevice {
		out vitals : PatientVitals;
		out deviceStatus : DeviceStatus;
	}
	
	action def EvaluateSafety {
		in vitals : PatientVitals;
		in status : DeviceStatus;
		out isSafe : Boolean;
	}
	
	action def DeliverDose {
		in parameters : TherapyParameters;
		out doseDelivered : DoseValue;
	}
	
	action def CheckTherapyComplete {
		in totalDelivered : DoseValue;
		in targetDose : DoseValue;
		out isComplete : Boolean;
	}
	
	action def ActivateAlarm {
		in alarmReason : String;
	}
	
	action def SafeShutdown {
		out shutdownComplete : Boolean;
	}
	
	action def FinalizeTherapy {
		out sessionReport : String;
	}
	
	requirement def FunctionalRequirement;
	requirement def SafetyRequirement;
	requirement def PowerRequirement;
	
	part def MedicalDevice {
		doc /* Medical therapeutic device for controlled delivery of treatment 
		     to patients under continuous safety monitoring. */
		
		part powerSubsystem {
			part battery : Battery {
				attribute :>> batteryState : BatteryState {
					attribute :>> chargeLevel = 100.0;
					attribute :>> voltage : VoltageValue;
					attribute :>> remainingEnergy : EnergyValue;
					attribute :>> isChargeable = true;
				}
			}
			
			part powerMgmt : PowerManagement {
				attribute :>> outputVoltage : VoltageValue;
				attribute :>> outputCurrent : CurrentValue;
			}
			
			connection connect battery.powerOutput to powerMgmt.powerIn;
		}
		
		part therapySubsystem {
			part deliveryUnit : TherapyDeliveryUnit {
				attribute :>> currentParameters : TherapyParameters {
					attribute :>> doseRate : DoseValue;
					attribute :>> duration : DurationValue;
					attribute :>> totalDose : DoseValue;
				}
			}
			
			connection connect powerSubsystem.powerMgmt.powerOut to deliveryUnit.powerInput;
		}
		
		part safetyMonitor : SafetyMonitor {
			attribute :>> safetyStatus : DeviceStatus {
				attribute :>> isOperational = true;
				attribute :>> isPowered = true;
				attribute :>> isSafeToOperate = true;
			}
		}
		
		part controlProcessor : ControlProcessor {
			attribute :>> operatingMode = "Standby";
		}
		
		part userInterface : UserInterface {
			attribute :>> displayState = "Ready";
		}
		
		ref patient {
			attribute vitals : PatientVitals {
				attribute :>> heartRate = 72.0;
				attribute :>> bloodPressure = 120.0;
				attribute :>> temperature = 37.0;
			}
		}
		
		connection monitoringConnection connect 
			safetyMonitor.monitoringInput to patient;
		
		connection therapyConnection connect 
			therapySubsystem.deliveryUnit.therapyOutput to patient;
		
		perform action primaryFunction : ProvideTherapeuticTreatment {
			doc /* Deliver controlled therapeutic treatment to patient while 
			     continuously monitoring safety parameters and patient condition. */
		}
	}
	
	requirement <'FR-001'> primaryFunction : FunctionalRequirement {
		doc /* The medical device shall deliver therapeutic treatment according to 
		     prescribed parameters with accuracy within ±5% of target dose. */
		subject device : MedicalDevice;
	}
	
	requirement <'SR-001'> continuousMonitoring : SafetyRequirement {
		doc /* The device shall continuously monitor patient vital signs and device 
		     status during therapy delivery. */
		subject device : MedicalDevice;
		assert constraint {
			device.safetyMonitor.safetyStatus.isOperational == true
		}
	}
	
	requirement <'SR-002'> automaticShutdown : SafetyRequirement {
		doc /* The device shall automatically cease therapy and activate alarm 
		     when unsafe conditions are detected. */
		subject device : MedicalDevice;
		assert constraint {
			device.safetyMonitor.safetyStatus.isSafeToOperate == true
		}
	}
	
	requirement <'PR-001'> batteryOperation : PowerRequirement {
		doc /* The device shall maintain therapy delivery for minimum 8 hours 
		     on battery power at nominal dose rate. */
		subject device : MedicalDevice;
		assert constraint {
			device.powerSubsystem.battery.batteryState.chargeLevel >= 10.0
		}
	}
	
	requirement <'SR-003'> batteryFailureHandling : SafetyRequirement {
		doc /* The device shall detect battery depletion or charging failure 
		     and safely terminate therapy with user notification. */
		subject device : MedicalDevice;
	}
	
	part medicalDevice : MedicalDevice;
}
