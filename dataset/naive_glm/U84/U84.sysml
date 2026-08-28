package MedicalTherapyDevice {

    // ─────────────────────────────────────────────
    //  Value Types & Units
    // ─────────────────────────────────────────────

    package Units {
        import ISQ::*;
        import ScalarValues::*;

        value def ElectricPotential :> Real { unit 'V'; }
        value def ElectricCurrent :> Real { unit 'A'; }
        value def Energy :> Real { unit 'Wh'; }
        value def Power :> Real { unit 'W'; }
        value def TimeDuration :> Real { unit 'h'; }
        value def HeartRate :> Real { unit 'bpm'; }
        value def Pressure :> Real { unit 'mmHg'; }
        value def Temperature :> Real { unit '°C'; }
        value def DoseRate :> Real { unit 'mg/h'; }
        value def DoseVolume :> Real { unit 'mg'; }
        value def Percentage :> Real { unit '%'; }
    }

    // ─────────────────────────────────────────────
    //  Item Definitions
    // ─────────────────────────────────────────────

    item def ElectricalPower {
        attribute voltage : Units::ElectricPotential;
        attribute current : Units::ElectricCurrent;
    }

    item def TherapyParameters {
        attribute doseRate : Units::DoseRate;
        attribute duration : Units::TimeDuration;
        attribute totalDose : Units::DoseVolume;
    }

    item def TherapyDelivery {
        attribute currentDoseRate : Units::DoseRate;
        attribute elapsed : Units::TimeDuration;
        attribute remaining : Units::DoseVolume;
    }

    item def VitalSigns {
        attribute heartRate : Units::HeartRate;
        attribute systolicBP : Units::Pressure;
        attribute diastolicBP : Units::Pressure;
        attribute temperature : Units::Temperature;
    }

    item def DeviceStatus {
        attribute batteryLevel : Units::Percentage;
        attribute subsystemHealth : String;
        attribute faultCode : String;
    }

    item def AlarmSignal {
        attribute severity : String;
        attribute message : String;
        attribute timestamp : String;
    }

    item def SessionReport {
        attribute sessionId : String;
        attribute deliveredDose : Units::DoseVolume;
        attribute sessionDuration : Units::TimeDuration;
        attribute events : String;
    }

    item def UserCommand {
        attribute commandType : String;
        attribute parameters : TherapyParameters;
    }

    // ─────────────────────────────────────────────
    //  Port Definitions
    // ─────────────────────────────────────────────

    port def PowerPort {
        out power : ElectricalPower;
    }

    port def PowerSinkPort {
        in power : ElectricalPower;
    }

    port def TherapyParamPort {
        out params : TherapyParameters;
    }

    port def TherapyDeliveryPort {
        out delivery : TherapyDelivery;
    }

    port def VitalsMonitorPort {
        out vitals : VitalSigns;
    }

    port def StatusMonitorPort {
        out status : DeviceStatus;
    }

    port def AlarmPort {
        out alarm : AlarmSignal;
    }

    port def CommandPort {
        in command : UserCommand;
    }

    port def ReportPort {
        out report : SessionReport;
    }

    port def ControlSignalPort {
        out signal : String;
    }

    // ─────────────────────────────────────────────
    //  Requirements
    // ─────────────────────────────────────────────

    requirement def PowerRequirement {
        doc << The device shall operate on battery power for a minimum of 8 hours. >>
        subject device : Anything;
        objective {
            doc << Minimum battery life is 8 hours under normal operation. >>
            constraint { device.batteryLife >= 8 [Units::TimeDuration] }
        }
    }

    requirement def TherapyDeliveryRequirement {
        doc << The device shall deliver therapy at a controlled dose rate over a set duration. >>
        subject therapyUnit : Anything;
        objective {
            doc << Dose rate accuracy within ±5% of prescribed value. >>
            constraint { therapyUnit.doseRateAccuracy <= 5 [Units::Percentage] }
        }
    }

    requirement def SafetyMonitoringRequirement {
        doc << The safety monitor shall continuously monitor patient vitals and device status. >>
        subject safetyMonitor : Anything;
        objective {
            doc << Monitoring frequency at least once per second. >>
            constraint { safetyMonitor.monitoringInterval <= 1.0 [Units::TimeDuration] }
        }
    }

    requirement def EmergencyStopRequirement {
        doc << The device shall provide an emergency stop that immediately halts therapy. >>
        subject device : Anything;
        objective {
            doc << Emergency stop response time less than 1 second. >>
            constraint { device.emergencyStopResponseTime < 1.0 [Units::TimeDuration] }
        }
    }

    requirement def SelfTestRequirement {
        doc << The device shall perform a self-test upon power-on before entering ready state. >>
        subject device : Anything;
        objective {
            doc << Self-test must pass before therapy can be configured. >>
            constraint { device.selfTestPassed == true }
        }
    }

    // ─────────────────────────────────────────────
    //  State Machine for Device Lifecycle
    // ─────────────────────────────────────────────

    state defdef DeviceLifecycle {

        entry action {
            /* Initialize all subsystems */
        }

        state Off {
            entry action { /* Device powered off */ }
        }

        state PowerOn {
            entry action { /* Begin power-on sequence */ }
        }

        state SelfTest {
            entry action { /* Run diagnostic self-test on all subsystems */ }
            do action { /* Verify battery, therapy unit, sensors, processor */ }
            exit action { /* Record self-test result */ }
        }

        state Ready {
            entry action { /* Wait for clinician to configure treatment */ }
        }

        state Configured {
            entry action { /* Treatment parameters set, awaiting start */ }
        }

        state Active {
            entry action { /* Begin delivering therapy */ }
            do action { /* Continuously deliver dose and monitor vitals */ }
        }

        state Paused {
            entry action { /* Therapy paused, monitoring continues */ }
        }

        state Alarm {
            entry action { /* Trigger alarm, stop therapy, enter safe state */ }
            do action { /* Await clinician acknowledgement */ }
        }

        state Finalizing {
            entry action { /* Generate session report */ }
            do action { /* Record delivered dose, duration, events */ }
        }

        state Standby {
            entry action { /* Ready for next patient */ }
        }

        state EmergencyStop {
            entry action { /* Immediately halt all therapy and power down therapy unit */ }
            do action { /* Ensure safe state, retain logs */ }
        }

        transition Off -> PowerOn
            when powerOnRequested;

        transition PowerOn -> SelfTest
            when powerSequenceComplete;

        transition SelfTest -> Ready
            when selfTestPassed;

        transition SelfTest -> Alarm
            when selfTestFailed;

        transition Ready -> Configured
            when parametersConfigured;

        transition Configured -> Active
            when therapyStarted;

        transition Active -> Paused
            when therapyPaused;

        transition Paused -> Active
            when therapyResumed;

        transition Active -> Alarm
            when unsafeConditionDetected;

        transition Paused -> Alarm
            when unsafeConditionDetected;

        transition Active -> Finalizing
            when therapyComplete;

        transition Finalizing -> Standby
            when reportGenerated;

        transition Standby -> Ready
            when resetRequested;

        transition Alarm -> Ready
            when alarmAcknowledged;

        transition any -> EmergencyStop
            when emergencyStopTriggered;

        transition EmergencyStop -> Off
            when shutdownComplete;

        transition Standby -> Off
            when powerOffRequested;
    }

    // ─────────────────────────────────────────────
    //  Subsystem Parts
    // ─────────────────────────────────────────────

    part def RechargeableBattery {
        attribute capacity : Units::Energy = 50 [Units::Energy];
        attribute currentLevel : Units::Percentage = 100 [Units::Percentage];
        attribute minRuntime : Units::TimeDuration = 8 [Units::TimeDuration];

        port powerOut : PowerPort;

        satisfy PowerRequirement by currentLevel;

        action def Discharge {
            output energy : ElectricalPower;
        }
    }

    part def PowerManagementUnit {
        attribute outputVoltage : Units::ElectricPotential = 5 [Units::ElectricPotential];
        attribute maxCurrent : Units::ElectricCurrent = 3 [Units::ElectricCurrent];
        attribute efficiency : Units::Percentage = 95 [Units::Percentage];

        port powerIn : PowerSinkPort;
        port powerOut : PowerPort;

        action def Regulate {
            in raw : ElectricalPower;
            output regulated : ElectricalPower;
        }
    }

    part def TherapyDeliveryUnit {
        attribute doseRate : Units::DoseRate;
        attribute duration : Units::TimeDuration;
        attribute totalDose : Units::DoseVolume;
        attribute doseRateAccuracy : Units::Percentage = 3 [Units::Percentage];

        port powerIn : PowerSinkPort;
        port paramIn : TherapyParamPort;
        port deliveryOut : TherapyDeliveryPort;
        port controlIn : ControlSignalPort;

        satisfy TherapyDeliveryRequirement by doseRateAccuracy;

        action def DeliverTherapy {
            in params : TherapyParameters;
            in power : ElectricalPower;
            output delivery : TherapyDelivery;
        }

        action def StopDelivery {
            output delivery : TherapyDelivery;
        }
    }

    part def SafetyMonitor {
        attribute monitoringInterval : Units::TimeDuration = 1 [Units::TimeDuration];
        attribute heartRateMin : Units::HeartRate = 40 [Units::HeartRate];
        attribute heartRateMax : Units::HeartRate = 180 [Units::HeartRate];
        attribute systolicBPMin : Units::Pressure = 70 [Units::Pressure];
        attribute systolicBPMax : Units::Pressure = 200 [Units::Pressure];
        attribute tempMin : Units::Temperature = 34 [Units::Temperature];
        attribute tempMax : Units::Temperature = 40 [Units::Temperature];

        port vitalsIn : VitalsMonitorPort;
        port statusIn : StatusMonitorPort;
        port alarmOut : AlarmPort;
        port controlOut : ControlSignalPort;

        satisfy SafetyMonitoringRequirement by monitoringInterval;

        action def MonitorVitals {
            in vitals : VitalSigns;
            output isSafe : Boolean;
        }

        action def CheckDeviceStatus {
            in status : DeviceStatus;
            output isOperational : Boolean;
        }

        action def TriggerAlarm {
            in condition : String;
            output alarm : AlarmSignal;
        }

        action def HaltTherapy {
            output signal : String;
        }
    }

    part def ControlProcessor {
        attribute operatingMode : String;
        attribute clockSpeed : Units::ElectricCurrent = 0.5 [Units::ElectricCurrent];
        attribute firmwareVersion : String = "2.1.0";

        port powerIn : PowerSinkPort;
        port commandIn : CommandPort;
        port paramOut : TherapyParamPort;
        port controlOut : ControlSignalPort;
        port statusOut : StatusMonitorPort;
        port reportOut : ReportPort;

        action def ProcessCommand {
            in command : UserCommand;
            output params : TherapyParameters;
        }

        action def CoordinateTherapy {
            in params : TherapyParameters;
            in safetyStatus : Boolean;
            output signal : String;
        }

        action def GenerateReport {
            in sessionData : TherapyDelivery;
            output report : SessionReport;
        }

        exhibit state DeviceLifecycle;
    }

    part def UserInterface {
        attribute displayType : String = "LCD Touchscreen";
        attribute displaySize : Units::ElectricCurrent = 0.1 [Units::ElectricCurrent];

        port powerIn : PowerSinkPort;
        port commandOut : CommandPort;
        port alarmIn : AlarmPort;
        port reportIn : ReportPort;
        port statusIn : StatusMonitorPort;

        action def DisplayStatus {
            in status : DeviceStatus;
        }

        action def DisplayAlarm {
            in alarm : AlarmSignal;
        }

        action def AcceptUserInput {
            output command : UserCommand;
        }

        action def DisplayReport {
            in report : SessionReport;
        }
    }

    part def VitalSignsSensor {
        port vitalsOut : VitalsMonitorPort;
        port powerIn : PowerSinkPort;

        action def MeasureVitals {
            output vitals : VitalSigns;
        }
    }

    // ─────────────────────────────────────────────
    //  Power Subsystem
    // ─────────────────────────────────────────────

    part def PowerSubsystem {
        part battery : RechargeableBattery;
        part pmu : PowerManagementUnit;

        connect battery.powerOut to pmu.powerIn;

        port externalPowerIn : PowerSinkPort;
        port regulatedPowerOut : PowerPort;

        connect pmu.powerOut to regulatedPowerOut;
    }

    // ─────────────────────────────────────────────
    //  Therapy Subsystem
    // ─────────────────────────────────────────────

    part def TherapySubsystem {
        part therapyUnit : TherapyDeliveryUnit;

        port powerIn : PowerSinkPort;
        port paramIn : TherapyParamPort;
        port deliveryOut : TherapyDeliveryPort;
        port controlIn : ControlSignalPort;

        connect powerIn to therapyUnit.powerIn;
        connect paramIn to therapyUnit.paramIn;
        connect therapyUnit.deliveryOut to deliveryOut;
        connect controlIn to therapyUnit.controlIn;
    }

    // ─────────────────────────────────────────────
    //  Top-Level Medical Therapy Device
    // ─────────────────────────────────────────────

    part def MedicalTherapyDevice {
        attribute deviceName : String = "TherapyMed-1000";
        attribute deviceSerial : String;
        attribute batteryLife : Units::TimeDuration = 8 [Units::TimeDuration];
        attribute emergencyStopResponseTime : Units::TimeDuration = 0.5 [Units::TimeDuration];
        attribute selfTestPassed : Boolean;

        satisfy PowerRequirement by batteryLife;
        satisfy EmergencyStopRequirement by emergencyStopResponseTime;
        satisfy SelfTestRequirement by selfTestPassed;

        part powerSubsystem : PowerSubsystem;
        part therapySubsystem : TherapySubsystem;
        part safetyMonitor : SafetyMonitor;
        part controlProcessor : ControlProcessor;
        part userInterface : UserInterface;
        part vitalsSensor : VitalSignsSensor;

        // Power distribution
        connect powerSubsystem.regulatedPowerOut to therapySubsystem.powerIn;
        connect powerSubsystem.regulatedPowerOut to safetyMonitor.powerIn;
        connect powerSubsystem.regulatedPowerOut to controlProcessor.powerIn;
        connect powerSubsystem.regulatedPowerOut to userInterface.powerIn;
        connect powerSubsystem.regulatedPowerOut to vitalsSensor.powerIn;

        // Control processor sends therapy parameters to therapy subsystem
        connect controlProcessor.paramOut to therapySubsystem.paramIn;

        // Control processor sends control signals to therapy subsystem
        connect controlProcessor.controlOut to therapySubsystem.controlIn;

        // Safety monitor receives vitals from sensor
        connect vitalsSensor.vitalsOut to safetyMonitor.vitalsIn;

        // Safety monitor receives device status from control processor
        connect controlProcessor.statusOut to safetyMonitor.statusIn;

        // Safety monitor sends alarm and control signals
        connect safetyMonitor.alarmOut to userInterface.alarmIn;
        connect safetyMonitor.controlOut to therapySubsystem.controlIn;

        // User interface sends commands to control processor
        connect userInterface.commandOut to controlProcessor.commandIn;

        // Control processor sends status to user interface
        connect controlProcessor.statusOut to userInterface.statusIn;

        // Control processor generates reports to user interface
        connect controlProcessor.reportOut to userInterface.reportIn;

        // Therapy delivery output goes to patient (external)
        port patientTherapyPort : TherapyDeliveryPort;
        connect therapySubsystem.deliveryOut to patientTherapyPort;

        exhibit state DeviceLifecycle;
    }

}
