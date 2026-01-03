package MedicalDeviceSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def Voltage :> ISQ::voltage {
		attribute :>> num : Real;
		attribute :>> mRef : ISQ::VoltageUnit;
	}
	
	attribute def Current :> ISQ::electricCurrent {
		attribute :>> num : Real;
		attribute :>> mRef : ISQ::ElectricCurrentUnit;
	}
	
	attribute def Energy :> ISQ::energy {
		attribute :>> num : Real;
		attribute :>> mRef : ISQ::EnergyUnit;
	}
	
	attribute def FlowRate :> ISQ::volumeFlowRate {
		attribute :>> num : Real;
		attribute :>> mRef : ISQ::VolumeFlowRateUnit;
	}
	
	attribute def Volume :> ISQ::volume {
		attribute :>> num : Real;
		attribute :>> mRef : ISQ::VolumeUnit;
	}
	
	item def Medication {
		attribute name : String;
		attribute concentration : Real;
		attribute volume : Volume;
	}
	
	item def TherapyCommand {
		attribute targetFlowRate : FlowRate;
		attribute totalVolume : Volume;
		attribute duration : Real;
	}
	
	item def VitalSigns {
		attribute heartRate : Real;
		attribute bloodPressure : Real;
		attribute temperature : Real;
	}
	
	item def AlarmSignal {
		attribute severity : Integer;
		attribute message : String;
		attribute timestamp : Real;
	}
	
	port def PowerPort {
		attribute voltage : Voltage;
		attribute current : Current;
	}
	
	port def MedicationPort {
		in command : TherapyCommand;
		out medication : Medication;
	}
	
	port def MonitoringPort {
		out vitals : VitalSigns;
	}
	
	port def AlarmPort {
		out alarm : AlarmSignal;
	}
	
	part def Battery {
		attribute capacity : Energy;
		attribute currentCharge : Energy;
		attribute outputVoltage : Voltage;
		
		port powerOut : PowerPort;
		
		event occurrence depleted;
		event occurrence cannotBeCharged;
		event occurrence lowCharge;
		
		state batteryLifecycle {
			entry; then charged;
			
			state charged {
				entry assign currentCharge := capacity * 0.95;
			}
			
			transition charged_to_discharging
				first charged
				then discharging;
			
			state discharging {
				do action drainPower {
					assign currentCharge := currentCharge - (capacity * 0.01);
				}
			}
			
			transition discharging_to_low
				first discharging
				accept lowCharge
				then lowPower;
			
			state lowPower {
				entry assign currentCharge := capacity * 0.15;
			}
			
			transition low_to_depleted
				first lowPower
				accept depleted
				then empty;
			
			state empty {
				entry assign currentCharge := Energy(0.0, SI::J);
			}
		}
	}
	
	part def Sensor {
		port monitorOut : MonitoringPort;
		port powerIn : PowerPort;
		
		action measureVitals {
			out vitals : VitalSigns;
		}
	}
	
	part def PumpMechanism {
		attribute currentFlowRate : FlowRate;
		attribute deliveredVolume : Volume;
		
		port medicationIn : MedicationPort;
		port medicationOut : MedicationPort;
		port powerIn : PowerPort;
		
		action deliverMedication {
			in command : TherapyCommand;
			out delivered : Medication;
		}
		
		state pumpOperation {
			entry; then idle;
			
			state idle;
			
			transition idle_to_priming
				first idle
				then priming;
			
			state priming;
			
			transition priming_to_infusing
				first priming
				then infusing;
			
			state infusing {
				do action infuse references deliverMedication;
			}
			
			transition infusing_to_paused
				first infusing
				then paused;
			
			state paused;
			
			transition paused_to_infusing
				first paused
				then infusing;
			
			transition infusing_to_complete
				first infusing
				then complete;
			
			state complete;
		}
	}
	
	part def ControlUnit {
		port sensorInput : MonitoringPort;
		port pumpControl : MedicationPort;
		port alarmOut : AlarmPort;
		port powerIn : PowerPort;
		
		attribute deviceStatus : String;
		attribute therapyActive : Boolean;
		
		action processVitals {
			in vitals : VitalSigns;
			out command : TherapyCommand;
		}
		
		action monitorSafety {
			in vitals : VitalSigns;
			in batteryLevel : Real;
			out alarm : AlarmSignal;
		}
		
		state controllerStates {
			entry; then initialization;
			
			state initialization {
				entry assign deviceStatus := "Initializing";
			}
			
			transition init_to_standby
				first initialization
				then standby;
			
			state standby {
				entry assign deviceStatus := "Standby";
				entry assign therapyActive := false;
			}
			
			transition standby_to_active
				first standby
				then activeTherapy;
			
			state activeTherapy {
				entry assign deviceStatus := "Active";
				entry assign therapyActive := true;
				do action monitor references processVitals;
			}
			
			transition active_to_alarm
				first activeTherapy
				then alarmState;
			
			state alarmState {
				entry assign deviceStatus := "Alarm";
				do action raiseAlarm references monitorSafety;
			}
			
			transition alarm_to_standby
				first alarmState
				then standby;
			
			transition active_to_complete
				first activeTherapy
				then therapyComplete;
			
			state therapyComplete {
				entry assign deviceStatus := "Complete";
				entry assign therapyActive := false;
			}
		}
	}
	
	part def UserInterface {
		port alarmIn : AlarmPort;
		port powerIn : PowerPort;
		
		action displayStatus {
			in status : String;
		}
		
		action displayAlarm {
			in alarm : AlarmSignal;
		}
	}
	
	part def MedicalDevice {
		attribute deviceId : String;
		attribute firmwareVersion : String;
		
		part battery : Battery {
			attribute :>> capacity = Energy(144000.0, SI::J);
			attribute :>> outputVoltage = Voltage(12.0, SI::V);
		}
		
		part sensor : Sensor;
		
		part controller : ControlUnit;
		
		part pump : PumpMechanism;
		
		part ui : UserInterface;
		
		connection batteryToController : PowerPort
			connect battery.powerOut to controller.powerIn;
		
		connection batteryToPump : PowerPort
			connect battery.powerOut to pump.powerIn;
		
		connection batteryToSensor : PowerPort
			connect battery.powerOut to sensor.powerIn;
		
		connection batteryToUI : PowerPort
			connect battery.powerOut to ui.powerIn;
		
		connection sensorToController : MonitoringPort
			connect sensor.monitorOut to controller.sensorInput;
		
		connection controllerToPump : MedicationPort
			connect controller.pumpControl to pump.medicationIn;
		
		connection controllerToUI : AlarmPort
			connect controller.alarmOut to ui.alarmIn;
		
		event occurrence deviceStartup;
		event occurrence deviceShutdown;
		event occurrence therapyStarted;
		event occurrence therapyEnded;
		event occurrence deviceFails;
		
		perform action operateDevice {
			first start;
			then action initialize {
				out initialStatus : String;
			}
			then merge operationLoop;
			then action monitorAndDeliver {
				action sense references sensor.measureVitals;
				then action process references controller.processVitals;
				then action deliver references pump.deliverMedication;
			}
			then decide;
				if battery.currentCharge > battery.capacity * 0.2 then operationLoop;
				if battery.currentCharge <= battery.capacity * 0.2 then shutdown;
			action shutdown {
				action alarm references controller.monitorSafety;
				then action safeStop;
			}
			then done;
		}
	}
	
	part def Patient {
		attribute patientId : String;
		attribute currentVitals : VitalSigns;
		
		port vitalsOut : MonitoringPort;
		
		event occurrence therapyReceived;
		event occurrence therapyDelayed;
		event occurrence conditionChanged;
		
		ref device : MedicalDevice;
	}
	
	part medicalDeviceSystem {
		part device : MedicalDevice {
			attribute :>> deviceId = "MD-2024-7821";
			attribute :>> firmwareVersion = "3.2.1";
		}
		
		part patient : Patient {
			attribute :>> patientId = "PT-9456";
			ref :>> device = medicalDeviceSystem::device;
		}
		
		connection patientToSensor : MonitoringPort
			connect patient.vitalsOut to device.sensor.monitorOut;
		
		import CauseAndEffect::*;
		
		#causation connect device.battery.depleted to device.deviceFails;
		#causation connect device.battery.cannotBeCharged to device.deviceFails;
		#causation connect device.deviceFails to patient.therapyDelayed;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The medical device shall deliver prescribed medication therapy to a patient 
		       at a controlled rate while continuously monitoring patient vital signs. */
		subject device : MedicalDevice;
	}
	
	requirement def SafetyRequirement {
		doc /* The device shall detect unsafe conditions and enter a safe state 
		       by stopping therapy and alerting the operator. */
		subject device : MedicalDevice;
	}
	
	requirement def BatteryLifeRequirement {
		doc /* The device battery shall provide at least 8 hours of continuous operation. */
		subject battery : Battery;
		require constraint {
			battery.capacity >= Energy(28800.0, SI::J)
		}
	}
	
	requirement def DeliveryAccuracyRequirement {
		doc /* The medication delivery shall be accurate within 5 percent of prescribed flow rate. */
		subject pump : PumpMechanism;
	}
	
	requirement def AlarmResponseRequirement {
		doc /* The device shall raise an alarm within 2 seconds of detecting a critical condition. */
		subject controller : ControlUnit;
	}
	
	requirement deviceRequirements {
		doc /* Top-level requirements for medical device operation and safety. */
		
		require primaryFunction : PrimaryFunctionRequirement {
			subject device = medicalDeviceSystem.device;
		}
		
		require safety : SafetyRequirement {
			subject device = medicalDeviceSystem.device;
		}
		
		require batteryLife : BatteryLifeRequirement {
			subject battery = medicalDeviceSystem.device.battery;
		}
		
		require deliveryAccuracy : DeliveryAccuracyRequirement {
			subject pump = medicalDeviceSystem.device.pump;
		}
		
		require alarmResponse : AlarmResponseRequirement {
			subject controller = medicalDeviceSystem.device.controller;
		}
	}
	
	action def ProvideTherapy {
		in patient : Patient;
		in device : MedicalDevice;
		out therapyComplete : Boolean;
		
		first start;
		then action activateDevice references device.operateDevice;
		then merge continuousTherapy;
		then action therapyCycle {
			action monitorPatient references device.sensor.measureVitals;
			then action evaluateCondition references device.controller.processVitals;
			then action deliverDose references device.pump.deliverMedication;
		}
		then decide;
			if device.pump.deliveredVolume < device.pump.medicationIn.command.totalVolume then continuousTherapy;
			if device.pump.deliveredVolume >= device.pump.medicationIn.command.totalVolume then complete;
		action complete {
			assign therapyComplete := true;
		}
		then done;
	}
}
