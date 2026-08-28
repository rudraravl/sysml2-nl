package MedicalTherapyDevice {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type ChargeLevel > Real { unit 'percent'; }
    value type HeartRate > Real { unit 'bpm'; }
    value type Temperature > Real { unit 'degC'; }
    value type SignalIntensity > Real { unit 'mA'; }
    value type SignalDuration > Real { unit 's'; }
    value type ElectricalCurrent > Real { unit 'A'; }
    value type PowerLevel > Real { unit 'W'; }
    value type Voltage > Real { unit 'V'; }

    // ===== Enumerations =====
    enum def PowerState { normal; lowPower; depleted; charging; }
    enum def DeviceMode { standby; safetyCheck; activeTherapy; alarm; shutdown; }
    enum def TherapyWaveform { sinusoidal; pulsed; constant; ramp; }
    enum def SafetyStatus { safe; warning; critical; }
    enum def CommandKind { startTreatment; stopTreatment; adjustParameters; emergencyStop; }

    // ===== Item Definitions =====
    item def VitalSigns {
        attribute heartRate : HeartRate;
        attribute bodyTemperature : Temperature;
        attribute timestamp : TimeInstant;
    }

    item def TherapyParameters {
        attribute intensity : SignalIntensity;
        attribute waveform : TherapyWaveform;
        attribute duration : SignalDuration;
        attribute maxIntensity : SignalIntensity;
    }

    item def OperatorCommand {
        attribute command : CommandKind;
        attribute parameters : TherapyParameters;
    }

    item def SystemStatus {
        attribute mode : DeviceMode;
        attribute batteryLevel : ChargeLevel;
        attribute safetyStatus : SafetyStatus;
        attribute activeErrors : String;
    }

    item def SafetyAlert {
        attribute status : SafetyStatus;
        attribute description : String;
        attribute measuredValue : Real;
        attribute threshold : Real;
    }

    item def TherapyFeedback {
        attribute patientResponse : VitalSigns;
        attribute deliveredIntensity : SignalIntensity;
        attribute withinLimits : Boolean;
    }

    // ===== Port Definitions =====
    port def PowerPort {
        out voltage : Voltage;
        out current : ElectricalCurrent;
    }

    port def VitalSignsPort {
        out vitalData : VitalSigns;
    }

    port def TherapyPort {
        in parameters : TherapyParameters;
        out feedback : TherapyFeedback;
    }

    port def CommandPort {
        in command : OperatorCommand;
        out status : SystemStatus;
    }

    port def SafetyPort {
        out alert : SafetyAlert;
    }

    port def BatteryMonitorPort {
        out chargeLevel : ChargeLevel;
        out powerState : PowerState;
    }

    // ===== Power Management Unit =====
    part def PowerManagementUnit {
        port powerOut : PowerPort;
        port monitorOut : BatteryMonitorPort;

        attribute batteryCapacity : ChargeLevel = 100;
        attribute currentCharge : ChargeLevel = 100;
        attribute lowPowerThreshold : ChargeLevel = 20;
        attribute depletedThreshold : ChargeLevel = 5;
        attribute powerState : PowerState = PowerState::normal;
        attribute charging : Boolean = false;

        state def BatteryBehavior {
            entry; then Normal;

            state Normal {
                entry { powerState = PowerState::normal; }
                do { updateCharge(); }
                transition on if currentCharge <= lowPowerThreshold to LowPower;
                transition on if charging to Charging;
            }

            state LowPower {
                entry { powerState = PowerState::lowPower; }
                do { updateCharge(); }
                transition on if currentCharge <= depletedThreshold to Depleted;
                transition on if charging to Charging;
                transition on if currentCharge > lowPowerThreshold to Normal;
            }

            state Depleted {
                entry { powerState = PowerState::depleted; }
                transition on if charging to Charging;
            }

            state Charging {
                entry { powerState = PowerState::charging; }
                do { chargeBattery(); }
                transition on if currentCharge >= 100 to Normal;
            }
        }

        action updateCharge :> Action {
            in current : PowerLevel;
            out newCharge : ChargeLevel;
        }

        action chargeBattery :> Action {
            out newCharge : ChargeLevel;
        }

        state machine : BatteryBehavior;
    }

    // ===== Biometric Sensor =====
    part def BiometricSensor {
        port vitalOut : VitalSignsPort;
        port powerIn : PowerPort;

        attribute measuredHeartRate : HeartRate;
        attribute measuredTemperature : Temperature;
        attribute validRange : Boolean;
        attribute calibrationFactor : Real = 1.0;
        attribute heartRateMin : HeartRate = 30;
        attribute heartRateMax : HeartRate = 220;
        attribute tempMin : Temperature = 30.0;
        attribute tempMax : Temperature = 42.0;

        state def SensorBehavior {
            entry; then Idle;

            state Idle {
                transition on if powerIn.voltage > 0 to Measuring;
            }

            state Measuring {
                entry { acquireVitalSigns(); }
                do { validateData(); }
                transition on if validRange to Transmitting;
                transition on if !validRange to ErrorState;
            }

            state Transmitting {
                entry { transmitVitalSigns(); }
                transition to Measuring;
            }

            state ErrorState {
                entry { flagSensorError(); }
                transition on if validRange to Measuring;
            }
        }

        action acquireVitalSigns :> Action {
            out heartRate : HeartRate;
            out temperature : Temperature;
        }

        action validateData :> Action {
            in heartRate : HeartRate;
            in temperature : Temperature;
            out isValid : Boolean;
        }

        action transmitVitalSigns :> Action {
            out vitalData : VitalSigns;
        }

        action flagSensorError :> Action;

        state machine : SensorBehavior;
    }

    // ===== Therapy Generator =====
    part def TherapyGenerator {
        port therapyOut : TherapyPort;
        port powerIn : PowerPort;
        port safetyIn : SafetyPort;

        attribute currentParameters : TherapyParameters;
        attribute deliveredIntensity : SignalIntensity;
        attribute maxSafeIntensity : SignalIntensity = 50.0;
        attribute active : Boolean = false;
        attribute modulationFactor : Real = 1.0;

        state def GeneratorBehavior {
            entry; then Standby;

            state Standby {
                transition on if therapyOut.parameters.intensity > 0 to Generating;
            }

            state Generating {
                entry { generateSignal(); }
                do { modulateOutput(); }
                transition on if safetyIn.alert.status == SafetyStatus::critical to EmergencyStop;
                transition on if !active to Standby;
            }

            state EmergencyStop {
                entry { haltOutput(); }
                transition to Standby on if active == false;
            }
        }

        action generateSignal :> Action {
            in params : TherapyParameters;
            out signal : SignalIntensity;
        }

        action modulateOutput :> Action {
            in feedback : TherapyFeedback;
            in safetyAlert : SafetyAlert;
            out adjustedIntensity : SignalIntensity;
        }

        action haltOutput :> Action;

        state machine : GeneratorBehavior;
    }

    // ===== Control Processor =====
    part def ControlProcessor {
        port commandPort : CommandPort;
        port sensorIn : VitalSignsPort;
        port therapyControl : TherapyPort;
        port batteryMonitor : BatteryMonitorPort;
        port safetyMonitor : SafetyPort;
        port powerIn : PowerPort;

        attribute currentMode : DeviceMode = DeviceMode::standby;
        attribute currentVitals : VitalSigns;
        attribute currentTherapy : TherapyParameters;
        attribute systemStatus : SystemStatus;
        attribute treatmentProtocol : TherapyParameters;
        attribute adjustmentThreshold : HeartRate = 5.0;

        state def ProcessorBehavior {
            entry; then Standby;

            state Standby {
                entry { currentMode = DeviceMode::standby; }
                do { monitorSystemStatus(); }
                transition on if commandPort.command.command == CommandKind::startTreatment to SafetyCheck;
                transition on if batteryMonitor.powerState == PowerState::depleted to Shutdown;
                transition on if safetyMonitor.alert.status == SafetyStatus::critical to Alarm;
            }

            state SafetyCheck {
                entry { currentMode = DeviceMode::safetyCheck; }
                do { performSafetyCheck(); }
                transition on if safetyMonitor.alert.status == SafetyStatus::safe to ActiveTherapy;
                transition on if safetyMonitor.alert.status == SafetyStatus::warning to Alarm;
                transition on if safetyMonitor.alert.status == SafetyStatus::critical to Shutdown;
            }

            state ActiveTherapy {
                entry { currentMode = DeviceMode::activeTherapy; }
                do { therapyLoop(); }
                transition on if commandPort.command.command == CommandKind::stopTreatment to Standby;
                transition on if safetyMonitor.alert.status == SafetyStatus::critical to Shutdown;
                transition on if safetyMonitor.alert.status == SafetyStatus::warning to Alarm;
                transition on if batteryMonitor.powerState == PowerState::depleted to Shutdown;
            }

            state Alarm {
                entry { currentMode = DeviceMode::alarm; }
                do { raiseAlarm(); }
                transition on if safetyMonitor.alert.status == SafetyStatus::safe to Standby;
                transition on if safetyMonitor.alert.status == SafetyStatus::critical to Shutdown;
            }

            state Shutdown {
                entry { currentMode = DeviceMode::shutdown; }
                do { performShutdown(); }
            }
        }

        action monitorSystemStatus :> Action {
            out status : SystemStatus;
        }

        action performSafetyCheck :> Action {
            in batteryLevel : ChargeLevel;
            in safetyAlert : SafetyAlert;
            out isSafe : Boolean;
        }

        action therapyLoop :> Action {
            in vitals : VitalSigns;
            in feedback : TherapyFeedback;
            out adjustedParams : TherapyParameters;
        }

        action raiseAlarm :> Action {
            in alert : SafetyAlert;
        }

        action performShutdown :> Action;

        action analyzeVitals :> Action {
            in vitals : VitalSigns;
            in protocol : TherapyParameters;
            out adjustedParams : TherapyParameters;
        }

        state machine : ProcessorBehavior;
    }

    // ===== Safety Interlock =====
    part def SafetyInterlock {
        port safetyOut : SafetyPort;
        port powerIn : PowerPort;
        port therapyMonitor : TherapyPort;

        attribute maxTemperature : Temperature = 42.0;
        attribute maxCurrent : ElectricalCurrent = 0.1;
        attribute currentStatus : SafetyStatus = SafetyStatus::safe;
        attribute temperatureThreshold : Temperature = 40.0;
        attribute currentThreshold : ElectricalCurrent = 0.08;

        state def InterlockBehavior {
            entry; then Monitoring;

            state Monitoring {
                do { checkConditions(); }
                transition on if currentStatus == SafetyStatus::warning to WarningState;
                transition on if currentStatus == SafetyStatus::critical to CriticalState;
            }

            state WarningState {
                entry { issueWarning(); }
                do { checkConditions(); }
                transition on if currentStatus == SafetyStatus::safe to Monitoring;
                transition on if currentStatus == SafetyStatus::critical to CriticalState;
            }

            state CriticalState {
                entry { triggerShutdown(); }
                do { checkConditions(); }
                transition on if currentStatus == SafetyStatus::safe to Monitoring;
            }
        }

        action checkConditions :> Action {
            in temperature : Temperature;
            in current : ElectricalCurrent;
            out status : SafetyStatus;
        }

        action issueWarning :> Action {
            out alert : SafetyAlert;
        }

        action triggerShutdown :> Action {
            out alert : SafetyAlert;
        }

        state machine : InterlockBehavior;
    }

    // ===== Top-Level Device =====
    part def ClosedLoopTherapyDevice {
        port operatorInterface : CommandPort;
        port patientTherapy : TherapyPort;
        port patientSensing : VitalSignsPort;

        part powerManagement : PowerManagementUnit {
            port powerOut : PowerPort;
            port monitorOut : BatteryMonitorPort;
        }

        part biometricSensor : BiometricSensor {
            port vitalOut : VitalSignsPort;
            port powerIn : PowerPort;
        }

        part therapyGenerator : TherapyGenerator {
            port therapyOut : TherapyPort;
            port powerIn : PowerPort;
            port safetyIn : SafetyPort;
        }

        part controlProcessor : ControlProcessor {
            port commandPort : CommandPort;
            port sensorIn : VitalSignsPort;
            port therapyControl : TherapyPort;
            port batteryMonitor : BatteryMonitorPort;
            port safetyMonitor : SafetyPort;
            port powerIn : PowerPort;
        }

        part safetyInterlock : SafetyInterlock {
            port safetyOut : SafetyPort;
            port powerIn : PowerPort;
            port therapyMonitor : TherapyPort;
        }

        // Connections
        connection powerToSensor : PowerPort connect powerManagement.powerOut to biometricSensor.powerIn;
        connection powerToGenerator : PowerPort connect powerManagement.powerOut to therapyGenerator.powerIn;
        connection powerToProcessor : PowerPort connect powerManagement.powerOut to controlProcessor.powerIn;
        connection powerToInterlock : PowerPort connect powerManagement.powerOut to safetyInterlock.powerIn;

        connection sensorToProcessor : VitalSignsPort connect biometricSensor.vitalOut to controlProcessor.sensorIn;
        connection sensorToPatient : VitalSignsPort connect biometricSensor.vitalOut to patientSensing;

        connection processorToGenerator : TherapyPort connect controlProcessor.therapyControl to therapyGenerator.therapyOut;
        connection generatorToPatient : TherapyPort connect therapyGenerator.therapyOut to patientTherapy;

        connection batteryToProcessor : BatteryMonitorPort connect powerManagement.monitorOut to controlProcessor.batteryMonitor;

        connection interlockToProcessor : SafetyPort connect safetyInterlock.safetyOut to controlProcessor.safetyMonitor;
        connection interlockToGenerator : SafetyPort connect safetyInterlock.safetyOut to therapyGenerator.safetyIn;

        connection generatorToInterlock : TherapyPort connect therapyGenerator.therapyOut to safetyInterlock.therapyMonitor;

        connection operatorToDevice : CommandPort connect operatorInterface to controlProcessor.commandPort;
    }

    // ===== Requirements =====
    requirement def ContinuousMonitoring {
        doc { The device shall continuously monitor patient vital signs including heart rate and temperature. }
        subject device : ClosedLoopTherapyDevice;
        objective { device.biometricSensor.vitalOut.vitalData.heartRate > 0 and device.biometricSensor.vitalOut.vitalData.bodyTemperature > 0; }
    }

    requirement def ClosedLoopTherapy {
        doc { The device shall automatically adjust therapeutic signal based on real-time patient response. }
        subject device : ClosedLoopTherapyDevice;
        objective { device.controlProcessor.currentMode == DeviceMode::activeTherapy implies device.therapyGenerator.deliveredIntensity <= device.therapyGenerator.maxSafeIntensity; }
    }

    requirement def PowerManagement {
        doc { The power management unit shall enter low-power state when charge falls below 20 percent and signal depletion below 5 percent. }
        subject pmu : PowerManagementUnit;
        objective { pmu.currentCharge <= 20 implies pmu.powerState == PowerState::lowPower; }
    }

    requirement def SafetyProtection {
        doc { The safety interlock shall trigger alarm or shutdown when temperature exceeds 40 degC or current exceeds 0.08 A. }
        subject interlock : SafetyInterlock;
        objective { interlock.currentStatus != SafetyStatus::safe when interlock.temperatureThreshold exceeded; }
    }

    requirement def TherapyPrecision {
        doc { The therapy generator shall precisely control signal intensity, waveform, and duration within safe limits. }
        subject generator : TherapyGenerator;
        objective { generator.deliveredIntensity <= generator.maxSafeIntensity; }
    }

    requirement def DataValidation {
        doc { The biometric sensor shall validate data accuracy before transmission to the control processor. }
        subject sensor : BiometricSensor;
        objective { sensor.validRange == true when sensor.vitalOut.vitalData transmitted; }
    }

    requirement def OperatorControl {
        doc { The control processor shall process operator commands and initiate safety checks before activating therapy. }
        subject processor : ControlProcessor;
        objective { processor.commandPort.command.command == CommandKind::startTreatment implies processor.currentMode == DeviceMode::safetyCheck; }
    }

    requirement def SystemReliability {
        doc { The device shall maintain safe operation under all conditions including battery depletion and sensor errors. }
        subject device : ClosedLoopTherapyDevice;
        objective { device.controlProcessor.currentMode != DeviceMode::activeTherapy when device.safetyInterlock.currentStatus == SafetyStatus::critical; }
    }

    requirement def TreatmentProtocol {
        doc { The device shall deliver therapy according to a pre-defined treatment protocol with adjustable parameters. }
        subject device : ClosedLoopTherapyDevice;
        objective { device.controlProcessor.treatmentProtocol.intensity > 0 and device.controlProcessor.treatmentProtocol.duration > 0; }
    }

    requirement package DeviceRequirements {
        requirement req1 : ContinuousMonitoring;
        requirement req2 : ClosedLoopTherapy;
        requirement req3 : PowerManagement;
        requirement req4 : SafetyProtection;
        requirement req5 : TherapyPrecision;
        requirement req6 : DataValidation;
        requirement req7 : OperatorControl;
        requirement req8 : SystemReliability;
        requirement req9 : TreatmentProtocol;
    }

    // ===== Verification =====
    verification def VerifyContinuousMonitoring {
        subject device : ClosedLoopTherapyDevice;
        objective { device.biometricSensor.vitalOut.vitalData.heartRate > 0; }
    }

    verification def VerifySafetyInterlock {
        subject interlock : SafetyInterlock;
        objective { interlock.currentStatus == SafetyStatus::critical when interlock.maxTemperature exceeded; }
    }

    verification def VerifyPowerManagement {
        subject pmu : PowerManagementUnit;
        objective { pmu.powerState == PowerState::lowPower when pmu.currentCharge <= 20; }
    }
}
