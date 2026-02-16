package 'NegativePressureWoundTherapySystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def PressureValue :> Real;
	attribute def VolumeValue :> Real;
	attribute def TimeValue :> Real;
	attribute def FlowRateValue :> Real;
	
	item def Exudate {
		attribute volume : VolumeValue;
		attribute flowRate : FlowRateValue;
	}
	
	item def Air {
		attribute pressure : PressureValue;
	}
	
	port def VacuumOutPort {
		attribute pressure : PressureValue;
		out item airFlow : Air;
		in item exudateReturn : Exudate;
	}
	
	port def VacuumInPort {
		attribute pressure : PressureValue;
		in item airFlow : Air;
		out item exudateReturn : Exudate;
	}
	
	port def DressingPort {
		attribute pressure : PressureValue;
		in item vacuumAir : Air;
		out item woundExudate : Exudate;
	}
	
	part def VacuumPump {
		attribute targetPressure : PressureValue;
		attribute currentPressure : PressureValue;
		attribute maxFlowRate : FlowRateValue;
		attribute isPumpActive : Boolean;
		port pumpOutlet : VacuumOutPort;
		
		action def ActivatePump {
			in targetPressure : PressureValue;
			out achievedPressure : PressureValue;
		}
		
		action def DeactivatePump;
	}
	
	part def PressureSensor {
		attribute measuredPressure : PressureValue;
		attribute sensorAccuracy : PressureValue;
		
		action def MeasurePressure {
			out pressure : PressureValue;
		}
	}
	
	part def ExudateCanister {
		attribute maxCapacity : VolumeValue;
		attribute currentLevel : VolumeValue;
		attribute isCanisterFull : Boolean;
		port canisterInlet : VacuumInPort;
		port canisterOutlet : VacuumOutPort;
	}
	
	part def WoundDressing {
		attribute sealIntegrity : Real;
		attribute dressingType : String;
		port dressingInterface : DressingPort;
	}
	
	part def ControlModule {
		attribute therapySetPoint : PressureValue;
		attribute therapyDuration : TimeValue;
		attribute alarmActive : Boolean;
		attribute leakDetected : Boolean;
		
		action def MonitorPressure {
			in currentPressure : PressureValue;
			in targetPressure : PressureValue;
			out pressureDeviation : PressureValue;
		}
		
		action def CheckCanisterLevel {
			in currentLevel : VolumeValue;
			in maxCapacity : VolumeValue;
			out isFull : Boolean;
		}
		
		action def DetectLeak {
			in pressureDeviation : PressureValue;
			in threshold : PressureValue;
			out leakDetected : Boolean;
		}
		
		action def ActivateAlarm {
			in alarmReason : String;
		}
	}
	
	part def AlarmUnit {
		attribute alarmType : String;
		attribute isActive : Boolean;
		
		action def SoundAlarm {
			in reason : String;
		}
		
		action def SilenceAlarm;
	}
	
	state def TherapyOperationState {
		entry; then systemOff;
		
		state systemOff;
		transition powerOn first systemOff then initialization;
		
		state initialization;
		transition initComplete first initialization then therapyActive;
		
		state therapyActive;
		accept at when alarmCondition then therapyPaused;
		accept at when therapyComplete then therapyEnded;
		
		state therapyPaused;
		accept at when conditionResolved then therapyActive;
		accept at when userStop then therapyEnded;
		
		state therapyEnded;
		transition shutdown first therapyEnded then systemOff;
	}
	
	action def NPWTTherapyControl {
		first start;
		then merge monitoringLoop;
		
		then action measurePressure : ControlModule::MonitorPressure {
			in currentPressure : PressureValue;
			in targetPressure : PressureValue;
			out pressureDeviation : PressureValue;
		}
		
		then decide pressureCheck;
			if measurePressure.pressureDeviation > 10.0 then detectLeak;
			if measurePressure.pressureDeviation <= 10.0 then checkCanister;
		
		action detectLeak : ControlModule::DetectLeak {
			in pressureDeviation = measurePressure.pressureDeviation;
			in threshold : PressureValue;
			out leakDetected : Boolean;
		}
		
		then decide leakCheck;
			if detectLeak.leakDetected then activateLeakAlarm;
			if not detectLeak.leakDetected then checkCanister;
		
		action activateLeakAlarm : ControlModule::ActivateAlarm {
			in alarmReason = "Leak detected in system";
		}
		then done;
		
		action checkCanister : ControlModule::CheckCanisterLevel {
			in currentLevel : VolumeValue;
			in maxCapacity : VolumeValue;
			out isFull : Boolean;
		}
		
		then decide canisterCheck;
			if checkCanister.isFull then activateCanisterAlarm;
			if not checkCanister.isFull then monitoringLoop;
		
		action activateCanisterAlarm : ControlModule::ActivateAlarm {
			in alarmReason = "Canister full - replacement required";
		}
		then done;
	}
	
	part npwtSystem : NPWTSystem {
		attribute systemPressure : PressureValue;
		attribute therapyActive : Boolean;
		
		part controller : ControlModule {
			attribute :>> therapySetPoint = -125.0;
			attribute :>> therapyDuration = 72.0;
		}
		
		part pump : VacuumPump {
			attribute :>> targetPressure = -125.0;
			attribute :>> maxFlowRate = 5.0;
			port :>> pumpOutlet;
		}
		
		part sensor : PressureSensor {
			attribute :>> sensorAccuracy = 2.0;
		}
		
		part canister : ExudateCanister {
			attribute :>> maxCapacity = 500.0;
			attribute :>> currentLevel = 0.0;
			port :>> canisterInlet;
			port :>> canisterOutlet;
		}
		
		part dressing : WoundDressing {
			attribute :>> sealIntegrity = 1.0;
			attribute :>> dressingType = "Foam";
			port :>> dressingInterface;
		}
		
		part alarm : AlarmUnit {
			attribute :>> isActive = false;
		}
		
		connect pump.pumpOutlet to canister.canisterInlet;
		connect canister.canisterOutlet to dressing.dressingInterface;
		
		perform action therapyControl : NPWTTherapyControl;
		perform state operationState : TherapyOperationState;
	}
	
	part def NPWTSystem;
	
	requirement def PrimaryTherapyFunction {
		doc /* The NPWT system shall create and maintain a controlled negative pressure environment 
		     at the wound site to promote healing by removing excess exudate, reducing edema, 
		     increasing blood flow, and promoting granulation tissue formation. */
		
		subject system : NPWTSystem;
		
		require constraint pressureMaintenance {
			system.systemPressure >= -200.0 and system.systemPressure <= -50.0
		}
	}
	
	requirement def PressureControlRequirement {
		doc /* The system shall maintain the applied negative pressure within ±10% of the 
		     prescribed target pressure during active therapy. */
		
		subject system : NPWTSystem;
		refines PrimaryTherapyFunction;
		
		require constraint pressureAccuracy {
			abs(system.systemPressure - system.controller.therapySetPoint) <= 
			abs(system.controller.therapySetPoint * 0.1)
		}
	}
	
	requirement def ExudateManagementRequirement {
		doc /* The system shall continuously remove wound exudate and store it safely in a 
		     sealed canister, alerting when the canister reaches 90% capacity. */
		
		subject system : NPWTSystem;
		refines PrimaryTherapyFunction;
		
		require constraint canisterCapacity {
			system.canister.currentLevel < system.canister.maxCapacity * 0.9 or 
			system.alarm.isActive
		}
	}
	
	requirement def LeakDetectionRequirement {
		doc /* The system shall detect pressure leaks that prevent maintenance of target pressure 
		     and activate an alarm within 30 seconds of leak occurrence. */
		
		subject system : NPWTSystem;
		refines PressureControlRequirement;
		
		require constraint leakResponse {
			system.controller.leakDetected implies system.alarm.isActive
		}
	}
	
	requirement def ContinuousOperationRequirement {
		doc /* The system shall operate continuously for the prescribed therapy duration, 
		     typically 48-72 hours, with minimal interruption. */
		
		subject system : NPWTSystem;
		refines PrimaryTherapyFunction;
		
		require constraint therapyDuration {
			system.controller.therapyDuration >= 48.0
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The system shall not exceed maximum safe pressure limits and shall fail to a 
		     safe state in the event of malfunction. */
		
		subject system : NPWTSystem;
		
		require constraint pressureSafetyLimit {
			system.systemPressure >= -250.0
		}
	}
	
	requirement <'NPWT-SYS-001'> npwtSystemRequirement {
		doc /* The Negative-Pressure Wound Therapy system shall deliver controlled, continuous 
		     negative pressure therapy to promote wound healing through exudate removal, 
		     edema reduction, and enhanced tissue perfusion while ensuring patient safety 
		     and reliable operation. */
		
		assume constraint dressingSealed {
			npwtSystem.dressing.sealIntegrity >= 0.95
		}
		
		require primaryFunction : PrimaryTherapyFunction;
		require pressureControl : PressureControlRequirement;
		require exudateManagement : ExudateManagementRequirement;
		require leakDetection : LeakDetectionRequirement;
		require continuousOperation : ContinuousOperationRequirement;
		require safety : SafetyRequirement;
	}
}
