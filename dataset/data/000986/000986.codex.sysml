package BedwettingAlarmSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def Millisecond :> Real {
        unit = "ms";
    }

    attribute def Decibel :> Real {
        unit = "dB";
    }

    attribute def Volt :> Real {
        unit = "V";
    }

    attribute def MilliampereHour :> Real {
        unit = "mAh";
    }

    attribute def Gram :> Real {
        unit = "g";
    }

    item def MoistureSignal {
        attribute moistureLevel : Percent;
        attribute sampleTime : Millisecond;
    }

    item def AlarmCommand {
        attribute audibleEnabled : Boolean;
        attribute vibrationEnabled : Boolean;
        attribute ledEnabled : Boolean;
        attribute intensity : Percent;
    }

    item def CaregiverNotification {
        attribute eventTime : Millisecond;
        attribute moistureDetected : Boolean;
        attribute alarmAcknowledged : Boolean;
    }

    item def UserInput {
        attribute resetPressed : Boolean;
        attribute testPressed : Boolean;
        attribute sensitivitySetting : Percent;
    }

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute capacityRemaining : Percent;
    }

    port def MoistureProbePort {
        out moistureSignal : MoistureSignal;
    }

    port def AlarmActuationPort {
        in alarmCommand : AlarmCommand;
    }

    port def UserControlPort {
        out userInput : UserInput;
    }

    port def PowerPort {
        in power : ElectricalPower;
    }

    port def NotificationPort {
        out notification : CaregiverNotification;
    }

    action def SampleMoisture {
        in threshold : Percent;
        in sensorReading : MoistureSignal;
        out wetnessDetected : Boolean;
    }

    action def ActivateAlarm {
        in wetnessDetected : Boolean;
        out command : AlarmCommand;
    }

    action def AcknowledgeAndReset {
        in controls : UserInput;
        out resetRequested : Boolean;
    }

    action def NotifyCaregiver {
        in wetnessDetected : Boolean;
        in acknowledged : Boolean;
        out notification : CaregiverNotification;
    }

    state def AlarmOperatingState {
        entry action InitializeSystem;

        state Off;
        state Monitoring;
        state WetnessConfirmed;
        state Alerting;
        state Acknowledged;
        state LowBattery;
        state TestMode;

        transition initial then Off;

        transition PowerApplied
            first Off
            then Monitoring;

        transition MoistureAboveThreshold
            first Monitoring
            then WetnessConfirmed;

        transition ConfirmedWetness
            first WetnessConfirmed
            then Alerting;

        transition ResetPressed
            first Alerting
            then Acknowledged;

        transition ResetComplete
            first Acknowledged
            then Monitoring;

        transition BatteryLow
            first Monitoring
            then LowBattery;

        transition BatteryReplaced
            first LowBattery
            then Monitoring;

        transition TestPressed
            first Monitoring
            then TestMode;

        transition TestComplete
            first TestMode
            then Monitoring;
    }

    part def MoistureSensor {
        attribute detectionThreshold : Percent = 35.0;
        attribute samplingPeriod : Millisecond = 250.0;
        attribute washable : Boolean = true;

        port probePort : MoistureProbePort;

        perform action sample : SampleMoisture;
    }

    part def ControlUnit {
        attribute debounceTime : Millisecond = 500.0;
        attribute alarmLatchEnabled : Boolean = true;
        attribute maxContinuousAlarmTime : Millisecond = 900000.0;

        port sensorInput : MoistureProbePort;
        port alarmOutput : AlarmActuationPort;
        port controls : UserControlPort;
        port notificationOutput : NotificationPort;
        port powerInput : PowerPort;

        perform state operatingState : AlarmOperatingState;
        perform action alarmActivation : ActivateAlarm;
        perform action resetHandling : AcknowledgeAndReset;
        perform action caregiverNotice : NotifyCaregiver;
    }

    part def AudibleAlarm {
        attribute soundPressureLevel : Decibel = 85.0;
        attribute tonePulsePeriod : Millisecond = 750.0;

        port actuatorPort : AlarmActuationPort;
    }

    part def VibrationAlarm {
        attribute vibrationIntensity : Percent = 90.0;
        attribute vibrationPulsePeriod : Millisecond = 500.0;

        port actuatorPort : AlarmActuationPort;
    }

    part def VisualIndicator {
        attribute ledBrightness : Percent = 80.0;
        attribute flashPeriod : Millisecond = 1000.0;

        port actuatorPort : AlarmActuationPort;
    }

    part def UserControls {
        attribute resetButtonForce : Gram = 120.0;
        attribute sensitivityMinimum : Percent = 10.0;
        attribute sensitivityMaximum : Percent = 90.0;

        port controlPort : UserControlPort;
    }

    part def BatteryPack {
        attribute nominalVoltage : Volt = 3.0;
        attribute ratedCapacity : MilliampereHour = 1000.0;
        attribute lowBatteryThreshold : Percent = 15.0;

        port powerOutput : PowerPort;
    }

    part def CaregiverInterface {
        attribute localNotificationEnabled : Boolean = true;
        attribute wirelessNotificationEnabled : Boolean = false;

        port notificationInput : NotificationPort;
    }

    part def BedwettingAlarmSystem {
        doc /* Primary function: detect moisture from bedwetting as early as practical and alert the child or caregiver so the child can wake, stop urinating, and participate in nighttime continence training. */

        attribute systemMass : Gram = 160.0;
        attribute normalOperatingVoltage : Volt = 3.0;
        attribute defaultSensitivity : Percent = 35.0;

        part moistureSensor : MoistureSensor;
        part controller : ControlUnit;
        part audibleAlarm : AudibleAlarm;
        part vibrationAlarm : VibrationAlarm;
        part visualIndicator : VisualIndicator;
        part userControls : UserControls;
        part battery : BatteryPack;
        part caregiverInterface : CaregiverInterface;

        connect moistureSensor.probePort to controller.sensorInput;
        connect controller.alarmOutput to audibleAlarm.actuatorPort;
        connect controller.alarmOutput to vibrationAlarm.actuatorPort;
        connect controller.alarmOutput to visualIndicator.actuatorPort;
        connect userControls.controlPort to controller.controls;
        connect battery.powerOutput to controller.powerInput;
        connect controller.notificationOutput to caregiverInterface.notificationInput;
    }

    requirement def DetectWetnessRequirement {
        doc /* The system shall detect moisture at or above the configured threshold and classify the condition as wetness. */
        attribute maximumDetectionLatency : Millisecond = 1000.0;
        attribute defaultThreshold : Percent = 35.0;
    }

    requirement def AlertUserRequirement {
        doc /* The system shall generate audible, vibration, and visual alerts when wetness is confirmed. */
        attribute minimumSoundLevel : Decibel = 75.0;
        attribute minimumVibrationIntensity : Percent = 60.0;
    }

    requirement def ResetRequirement {
        doc /* The system shall continue alerting until reset by the user or caregiver after wetness detection. */
        attribute resetDebounceTime : Millisecond = 500.0;
    }

    requirement def LowBatteryRequirement {
        doc /* The system shall indicate low battery before remaining capacity is insufficient for one night of monitoring. */
        attribute lowBatteryThreshold : Percent = 15.0;
    }

    requirement def SafetyComfortRequirement {
        doc /* The system shall operate using low-voltage battery power and wearable components suitable for overnight child use. */
        attribute maximumOperatingVoltage : Volt = 3.3;
        attribute maximumWearableMass : Gram = 200.0;
    }

    requirement detectWetness : DetectWetnessRequirement;
    requirement alertUser : AlertUserRequirement;
    requirement resetAlarm : ResetRequirement;
    requirement lowBattery : LowBatteryRequirement;
    requirement safetyComfort : SafetyComfortRequirement;

    satisfy detectWetness by BedwettingAlarmSystem::moistureSensor;
    satisfy alertUser by BedwettingAlarmSystem::audibleAlarm;
    satisfy alertUser by BedwettingAlarmSystem::vibrationAlarm;
    satisfy alertUser by BedwettingAlarmSystem::visualIndicator;
    satisfy resetAlarm by BedwettingAlarmSystem::controller;
    satisfy lowBattery by BedwettingAlarmSystem::battery;
    satisfy safetyComfort by BedwettingAlarmSystem;

}