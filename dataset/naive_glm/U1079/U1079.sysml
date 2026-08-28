package AssistiveLivingSystem {
    import ScalarValues::*;

    // -------- Units --------
    unit bpm;
    unit degC;
    unit lux;
    unit s;

    // -------- Value Types --------
    value type HeartRate :> Real {
        unit bpm;
    }
    value type Temperature :> Real {
        unit degC;
    }
    value type Illuminance :> Real {
        unit lux;
    }
    value type TimeSeconds :> Real {
        unit s;
    }

    // -------- Item Definitions --------
    item def VitalSigns {
        attribute heartRate : HeartRate;
        attribute bloodOxygen : Real;
        attribute timestamp : String;
    }

    item def FallEvent {
        attribute location : String;
        attribute impactMagnitude : Real;
        attribute confirmed : Boolean;
        attribute timestamp : String;
    }

    item def Alert {
        attribute severity : Integer;
        attribute source : String;
        attribute message : String;
        attribute timestamp : String;
    }

    item def VoiceCommand {
        attribute rawText : String;
        attribute intent : String;
        attribute target : String;
    }

    item def EnvironmentCommand {
        attribute targetTemperature : Temperature;
        attribute targetBrightness : Illuminance;
        attribute manualOverride : Boolean;
    }

    item def MedicationDose {
        attribute medicationName : String;
        attribute scheduledTime : String;
        attribute quantity : Integer;
        attribute dispensed : Boolean;
    }

    item def Notification {
        attribute recipient : String;
        attribute message : String;
        attribute urgent : Boolean;
    }

    // -------- Port Definitions --------
    port def VitalSignsPort {
        out vitalSigns : VitalSigns;
    }
    port def VitalReceivePort {
        in vitalSigns : VitalSigns;
    }
    port def HealthAlertPort {
        out alert : Alert;
    }
    port def AlertReceivePort {
        in alert : Alert;
    }
    port def FallEventPort {
        out fallEvent : FallEvent;
    }
    port def FallReceivePort {
        in fallEvent : FallEvent;
    }
    port def VoiceCommandPort {
        out command : VoiceCommand;
    }
    port def EnvironmentCommandPort {
        out envCommand : EnvironmentCommand;
    }
    port def EnvironmentControlPort {
        in envCommand : EnvironmentCommand;
    }
    port def ThermostatControlPort {
        in setPoint : Temperature;
    }
    port def LightingControlPort {
        in brightness : Illuminance;
    }
    port def NotificationPort {
        out notification : Notification;
    }
    port def NotificationReceivePort {
        in notification : Notification;
    }
    port def EmergencyCallPort {
        out call : Alert;
    }
    port def EmergencyCallReceivePort {
        in call : Alert;
    }
    port def MedicationReminderPort {
        out reminder : String;
    }
    port def MedicationReminderReceivePort {
        in reminder : String;
    }
    port def DispensePort {
        out dose : MedicationDose;
    }
    port def ConfirmationPort {
        in confirmed : Boolean;
    }

    // -------- Part Definitions --------
    part def User {
        attribute name : String;
        attribute age : Integer;
        attribute location : String;
    }

    part def WearableHealthMonitor {
        port vitalOut : VitalSignsPort;
        port healthAlertOut : HealthAlertPort;

        attribute currentHeartRate : HeartRate;
        attribute bloodOxygen : Real;
        attribute abnormalHigh : HeartRate = 120;
        attribute abnormalLow : HeartRate = 40;
        attribute currentVitalSigns : VitalSigns;
        attribute currentAlert : Alert;

        action analyzeVitalSigns {
            in vitalSigns : VitalSigns;
            out alert : Alert;
        }

        state healthMonitoring {
            state Normal;
            state AbnormalDetected;
            transition to_abnormal
                from Normal to AbnormalDetected
                when currentHeartRate > abnormalHigh or currentHeartRate < abnormalLow;
            transition to_normal
                from AbnormalDetected to Normal
                when currentHeartRate >= abnormalLow and currentHeartRate <= abnormalHigh;
        }
    }

    part def FallDetectionSensor {
        port fallOut : FallEventPort;

        attribute location : String;
        attribute accelerationThreshold : Real = 3.0;
        attribute currentAcceleration : Real;
        attribute orientationChanged : Boolean;
        attribute reset : Boolean;
        attribute detectedFall : FallEvent;

        state fallDetection {
            state Idle;
            state FallSuspected;
            state FallConfirmed;
            transition idle_to_suspected
                from Idle to FallSuspected
                when currentAcceleration > accelerationThreshold;
            transition suspected_to_confirmed
                from FallSuspected to FallConfirmed
                when orientationChanged == true;
            transition confirmed_to_idle
                from FallConfirmed to Idle
                when reset == true;
        }
    }

    part def VoiceAssistantModule {
        port commandOut : VoiceCommandPort;
        port envCommandOut : EnvironmentCommandPort;
        port reminderIn : MedicationReminderReceivePort;

        attribute wakeWordDetected : Boolean;
        attribute commandReceived : Boolean;
        attribute commandProcessed : Boolean;
        attribute currentCommand : VoiceCommand;

        state listening {
            state Idle;
            state Listening;
            state Processing;
            transition idle_to_listening
                from Idle to Listening
                when wakeWordDetected == true;
            transition listening_to_processing
                from Listening to Processing
                when commandReceived == true;
            transition processing_to_idle
                from Processing to Idle
                when commandProcessed == true;
        }

        action parseCommand {
            in rawText : String;
            out command : VoiceCommand;
        }
    }

    part def EnvironmentController {
        port commandIn : EnvironmentControlPort;
        port thermostatPort : ThermostatControlPort;
        port lightingPort : LightingControlPort;

        attribute currentTemperature : Temperature;
        attribute targetTemperature : Temperature;
        attribute currentBrightness : Illuminance;
        attribute targetBrightness : Illuminance;
        attribute manualOverride : Boolean;

        state environmentManagement {
            state Automatic;
            state Manual;
            transition auto_to_manual
                from Automatic to Manual
                when manualOverride == true;
            transition manual_to_auto
                from Manual to Automatic
                when manualOverride == false;
        }

        action adjustThermostat {
            in setPoint : Temperature;
        }
        action adjustLighting {
            in brightness : Illuminance;
        }
    }

    part def Thermostat {
        port controlPort : ThermostatControlPort;

        attribute currentTemperature : Temperature;
        attribute setPoint : Temperature;
        attribute heatingActive : Boolean;
        attribute coolingActive : Boolean;

        state thermostatControl {
            state Idle;
            state Heating;
            state Cooling;
            transition to_heating
                from Idle to Heating
                when currentTemperature < setPoint;
            transition to_cooling
                from Idle to Cooling
                when currentTemperature > setPoint;
            transition heating_to_idle
                from Heating to Idle
                when currentTemperature >= setPoint;
            transition cooling_to_idle
                from Cooling to Idle
                when currentTemperature <= setPoint;
        }
    }

    part def LightingSystem {
        port controlPort : LightingControlPort;

        attribute currentBrightness : Illuminance;
        attribute targetBrightness : Illuminance;

        state lightingControl {
            state Off;
            state Dim;
            state Bright;
            transition to_dim
                from Off to Dim
                when targetBrightness > 0 and targetBrightness < 300;
            transition to_bright
                from Dim to Bright
                when targetBrightness >= 300;
            transition bright_to_dim
                from Bright to Dim
                when targetBrightness < 300 and targetBrightness > 0;
            transition to_off
                from Dim to Off
                when targetBrightness == 0;
        }
    }

    part def EmergencyResponseUnit {
        port vitalIn : VitalReceivePort;
        port healthAlertIn : AlertReceivePort;
        port fallIn : FallReceivePort;
        port caregiverOut : NotificationPort;
        port emergencyCallOut : EmergencyCallPort;

        attribute contactList : String[0..*];
        attribute severeThreshold : Integer = 4;
        attribute responseProtocolActive : Boolean;
        attribute currentAlert : Alert;
        attribute currentFall : FallEvent;

        state emergencyResponse {
            state Monitoring;
            state SevereResponse;
            state NonUrgentResponse;
            transition to_severe
                from Monitoring to SevereResponse
                when currentAlert.severity >= severeThreshold;
            transition to_nonurgent
                from Monitoring to NonUrgentResponse
                when currentAlert.severity > 0 and currentAlert.severity < severeThreshold;
            transition severe_to_monitoring
                from SevereResponse to Monitoring
                when responseProtocolActive == false;
            transition nonurgent_to_monitoring
                from NonUrgentResponse to Monitoring
                when responseProtocolActive == false;
        }

        action callEmergencyServices {
            in alert : Alert;
        }
        action notifyCaregiver {
            in alert : Alert;
            in urgent : Boolean;
        }
        action logEvent {
            in alert : Alert;
        }
    }

    part def AutomatedMedicationDispenser {
        port voiceReminderOut : MedicationReminderPort;
        port visualReminderOut : MedicationReminderPort;
        port dispenseOut : DispensePort;
        port confirmationIn : ConfirmationPort;

        attribute schedule : MedicationDose[0..*];
        attribute currentDose : MedicationDose;
        attribute scheduledTimeReached : Boolean;
        attribute reminderActive : Boolean;
        attribute userConfirmed : Boolean;
        attribute doseDispensed : Boolean;

        state medicationSchedule {
            state Idle;
            state ReminderActive;
            state WaitingConfirmation;
            state Dispensed;
            transition idle_to_reminder
                from Idle to ReminderActive
                when scheduledTimeReached == true;
            transition reminder_to_waiting
                from ReminderActive to WaitingConfirmation
                when reminderActive == true;
            transition waiting_to_dispensed
                from WaitingConfirmation to Dispensed
                when userConfirmed == true;
            transition dispensed_to_idle
                from Dispensed to Idle
                when doseDispensed == true;
        }

        action issueReminder {
            out reminder : String;
        }
        action dispenseDose {
            in confirmed : Boolean;
            out dose : MedicationDose;
        }
    }

    part def CaregiverContact {
        port notificationIn : NotificationReceivePort;
        attribute name : String;
        attribute phone : String;
        attribute email : String;
    }

    part def EmergencyService {
        port callIn : EmergencyCallReceivePort;
        attribute name : String;
        attribute dispatchAddress : String;
    }

    // -------- Top-Level System --------
    part def AssistiveLivingSystem {
        part user : User;
        part healthMonitor : WearableHealthMonitor;
        part fallSensor : FallDetectionSensor;
        part voiceAssistant : VoiceAssistantModule;
        part environmentController : EnvironmentController;
        part thermostat : Thermostat;
        part lighting : LightingSystem;
        part emergencyUnit : EmergencyResponseUnit;
        part medicationDispenser : AutomatedMedicationDispenser;
        part caregiver : CaregiverContact;
        part emergencyService : EmergencyService;

        connections {
            connect healthMonitor.vitalOut to emergencyUnit.vitalIn;
            connect healthMonitor.healthAlertOut to emergencyUnit.healthAlertIn;
            connect fallSensor.fallOut to emergencyUnit.fallIn;
            connect voiceAssistant.commandOut to emergencyUnit.healthAlertIn;
            connect voiceAssistant.envCommandOut to environmentController.commandIn;
            connect environmentController.thermostatPort to thermostat.controlPort;
            connect environmentController.lightingPort to lighting.controlPort;
            connect medicationDispenser.voiceReminderOut to voiceAssistant.reminderIn;
            connect medicationDispenser.visualReminderOut to voiceAssistant.reminderIn;
            connect emergencyUnit.caregiverOut to caregiver.notificationIn;
            connect emergencyUnit.emergencyCallOut to emergencyService.callIn;
        }

        satisfy ContinuousMonitoringRequirement by healthMonitor;
        satisfy FallDetectionRequirement by fallSensor;
        satisfy VoiceControlRequirement by voiceAssistant;
        satisfy EnvironmentControlRequirement by environmentController;
        satisfy EmergencyResponseRequirement by emergencyUnit;
        satisfy MedicationDispenserRequirement by medicationDispenser;
    }

    // -------- Requirements --------
    requirement def ContinuousMonitoringRequirement {
        subject system : AssistiveLivingSystem;
        requirement
            "The system shall continuously monitor the user's vital signs including heart rate and blood oxygen.";
    }

    requirement def FallDetectionRequirement {
        subject system : AssistiveLivingSystem;
        requirement
            "The system shall automatically detect sudden falls and identify the user's location within the home.";
    }

    requirement def VoiceControlRequirement {
        subject system : AssistiveLivingSystem;
        requirement
            "The system shall allow the user to control home functions, including temperature, lighting, and help signaling, via spoken commands.";
    }

    requirement def EnvironmentControlRequirement {
        subject system : AssistiveLivingSystem;
        requirement
            "The system shall automatically and manually adjust temperature and brightness to maintain a comfortable and safe living environment.";
    }

    requirement def EmergencyResponseRequirement {
        subject system : AssistiveLivingSystem;
        requirement
            "The system shall receive alerts from the health monitor and fall detection sensors and execute predefined response protocols based on alert severity, including automatic calls to emergency services and caregiver notifications for severe events.";
    }

    requirement def MedicationDispenserRequirement {
        subject system : AssistiveLivingSystem;
        requirement
            "The system shall follow a medication schedule, issue voice and visual reminders when a dose is due, and dispense medication only after the user confirms readiness.";
    }
}
