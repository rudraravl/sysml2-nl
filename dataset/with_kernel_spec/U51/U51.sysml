package ClosedLoopTherapyDevice {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQElectromagnetism::*;
    private import ISQThermodynamics::*;

    package Definitions {
        value type HeartRateValue :> Real;
        value type TemperatureValue :> Real;
        value type CurrentValue :> Real;
        value type ChargeLevelValue :> Real;
        value type IntensityValue :> Real;
        value type DurationValue :> Real;
        value type ImpedanceValue :> Real;

        enum def WaveformKind {
            enum sinusoidal;
            enum square;
            enum pulsed;
        }

        item def VitalSigns {
            attribute heartRate : HeartRateValue;
            attribute temperature : TemperatureValue;
            attribute valid : Boolean;
        }
        item def TherapyParameters {
            attribute intensity : IntensityValue;
            attribute waveform : WaveformKind;
            attribute duration : DurationValue;
        }
        item def TherapyFeedback {
            attribute deliveredIntensity : IntensityValue;
            attribute patientImpedance : ImpedanceValue;
            attribute withinSafeLimits : Boolean;
        }
        item def OperatorCommand {
            attribute beginTreatment : Boolean;
            attribute stopTreatment : Boolean;
            attribute requestedIntensity : IntensityValue;
        }
        item def SystemStatus {
            attribute batteryCharge : ChargeLevelValue;
            attribute errorPresent : Boolean;
            attribute therapyActive : Boolean;
        }
        item def SafetyAlert {
            attribute overTemperature : Boolean;
            attribute overCurrent : Boolean;
            attribute shutdownRequired : Boolean;
        }
        item def ChargeStatus {
            attribute chargeLevel : ChargeLevelValue;
            attribute depleted : Boolean;
        }

        attribute def StartTherapyCommand;
        attribute def StopTherapyCommand;
        attribute def ResetCommand;
        attribute def AlarmSignal;
        attribute def ShutdownSignal;
        attribute def SafetyCheckPassed;
        attribute def SafetyCheckFailed;
        attribute def ReturnToNormal;

        action def MonitorBattery {
            out chargeLevel : ChargeLevelValue;
            out depleted : Boolean;
        }
        action def SenseVitals {
            out vitals : VitalSigns;
        }
        action def ValidateVitals {
            in rawVitals : VitalSigns;
            out validatedVitals : VitalSigns;
        }
        action def GenerateTherapy {
            in params : TherapyParameters;
            out feedback : TherapyFeedback;
        }
        action def AnalyzeVitals {
            in vitals : VitalSigns;
            in feedback : TherapyFeedback;
            out adjustedParams : TherapyParameters;
        }
        action def CheckSafety {
            in vitals : VitalSigns;
            in feedback : TherapyFeedback;
            out safe : Boolean;
            out alert : SafetyAlert;
        }
        action def TriggerAlarm {
            in alert : SafetyAlert;
        }
        action def PerformSafetyCheck {
            out safe : Boolean;
        }
        action def ReducePowerConsumption;
        action def SignalDepleted;

        part def PowerManagementUnit {
            port chargePort {
                out chargeStatus : ChargeStatus;
            }
            perform action 'monitor battery' : MonitorBattery;
            exhibit state 'power states' : 'Power States';
        }

        part def BiometricSensor {
            port vitalsPort {
                out vitals : VitalSigns;
            }
            perform action 'sense vitals' : SenseVitals;
            perform action 'validate vitals' : ValidateVitals;
        }

        part def TherapyGenerator {
            port therapyInPort {
                in params : TherapyParameters;
            }
            port therapyOutPort {
                out feedback : TherapyFeedback;
            }
            perform action 'generate therapy' : GenerateTherapy;
            exhibit state 'therapy states' : 'Therapy States';
        }

        part def ControlProcessor {
            port commandPort {
                in command : OperatorCommand;
            }
            port vitalsInPort {
                in vitals : VitalSigns;
            }
            port feedbackPort {
                in feedback : TherapyFeedback;
            }
            port therapyOutPort {
                out params : TherapyParameters;
            }
            port statusPort {
                out status : SystemStatus;
            }
            port chargeInPort {
                in chargeStatus : ChargeStatus;
            }
            port safetyInPort {
                in alert : SafetyAlert;
            }
            perform action 'analyze vitals' : AnalyzeVitals;
            perform action 'perform safety check' : PerformSafetyCheck;
            exhibit state 'control states' : 'Control States';
        }

        part def SafetyInterlock {
            port vitalsInPort {
                in vitals : VitalSigns;
            }
            port feedbackInPort {
                in feedback : TherapyFeedback;
            }
            port alertPort {
                out alert : SafetyAlert;
            }
            port shutdownPort {
                out shutdown : Boolean;
            }
            perform action 'check safety' : CheckSafety;
            perform action 'trigger alarm' : TriggerAlarm;
            exhibit state 'safety states' : 'Safety States';
        }

        part def OperatorPanel {
            port commandPort {
                out command : OperatorCommand;
            }
        }

        part def PortableMedicalDeviceSystem {
            part powerManagement : PowerManagementUnit;
            part biometricSensor : BiometricSensor;
            part therapyGenerator : TherapyGenerator;
            part controlProcessor : ControlProcessor;
            part safetyInterlock : SafetyInterlock;
            part operatorPanel : OperatorPanel;
        }

        state def 'Power States' {
            entry; then normal;
            state normal {
                do 'monitor battery';
            }
            transition 'normal-to-lowPower'
                first normal
                accept when 'monitor battery'.chargeLevel < 20
                then lowPower;
            state lowPower {
                do 'ReducePowerConsumption';
            }
            transition 'lowPower-to-depleted'
                first lowPower
                accept when 'monitor battery'.chargeLevel < 5
                then depleted;
            state depleted {
                do 'SignalDepleted';
            }
            transition 'depleted-to-normal'
                first depleted
                accept when 'monitor battery'.chargeLevel > 20
                then normal;
        }

        state def 'Therapy States' {
            entry; then idle;
            state idle;
            transition 'idle-to-active'
                first idle
                accept 'TherapyParameters'
                then active;
            state active {
                do 'generate therapy';
            }
            transition 'active-to-idle'
                first active
                accept 'StopTherapyCommand'
                then idle;
        }

        state def 'Control States' {
            entry; then standby;
            state standby;
            transition 'standby-to-safetyCheck'
                first standby
                accept 'StartTherapyCommand'
                do 'perform safety check'
                then safetyCheck;
            state safetyCheck;
            transition 'safetyCheck-to-active'
                first safetyCheck
                accept 'SafetyCheckPassed'
                then active;
            transition 'safetyCheck-to-alarm'
                first safetyCheck
                accept 'SafetyCheckFailed'
                then alarm;
            state active {
                entry 'sense vitals';
                do 'analyze vitals';
            }
            transition 'active-to-standby-stop'
                first active
                accept 'StopTherapyCommand'
                then standby;
            transition 'active-to-standby-alert'
                first active
                accept 'SafetyAlert'
                then standby;
            state alarm;
            transition 'alarm-to-standby'
                first alarm
                accept 'ResetCommand'
                then standby;
        }

        state def 'Safety States' {
            entry; then monitoring;
            state monitoring {
                do 'check safety';
            }
            transition 'monitoring-to-alarm-temp'
                first monitoring
                accept when 'check safety'.alert.overTemperature
                do 'trigger alarm'
                then alarm;
            transition 'monitoring-to-alarm-current'
                first monitoring
                accept when 'check safety'.alert.overCurrent
                do 'trigger alarm'
                then alarm;
            state alarm {
                do 'trigger alarm';
            }
            transition 'alarm-to-monitoring'
                first alarm
                accept 'ReturnToNormal'
                then monitoring;
        }

        requirement def AccuracyRequirement {
            doc /* The biometric sensor shall measure heart rate within ±2 bpm and temperature within ±0.1 °C. */
            subject : biometricSensor : BiometricSensor;
        }

        requirement def ReliabilityRequirement {
            doc /* The device shall operate continuously for at least 4 hours on a full charge. */
            subject : powerManagement : PowerManagementUnit;
        }

        requirement def SafeOperationRequirement {
            doc /* The safety interlock shall trigger an alarm or shutdown when unsafe conditions are detected. */
            subject : safetyInterlock : SafetyInterlock;
        }

        requirement def ClosedLoopRequirement {
            doc /* The system shall continuously monitor vitals, deliver therapy, and adjust based on response. */
            subject : device : PortableMedicalDeviceSystem;
        }
    }

    package Usages {
        private import Definitions::*;

        part deviceSystem : PortableMedicalDeviceSystem {
            part :>> powerManagement {
                port :>> chargePort {
                    out chargeStatus : ChargeStatus;
                }
            }
            part :>> biometricSensor {
                port :>> vitalsPort {
                    out vitals : VitalSigns;
                }
            }
            part :>> therapyGenerator {
                port :>> therapyInPort {
                    in params : TherapyParameters;
                }
                port :>> therapyOutPort {
                    out feedback : TherapyFeedback;
                }
            }
            part :>> controlProcessor {
                port :>> commandPort {
                    in command : OperatorCommand;
                }
                port :>> vitalsInPort {
                    in vitals : VitalSigns;
                }
                port :>> feedbackPort {
                    in feedback : TherapyFeedback;
                }
                port :>> therapyOutPort {
                    out params : TherapyParameters;
                }
                port :>> statusPort {
                    out status : SystemStatus;
                }
                port :>> chargeInPort {
                    in chargeStatus : ChargeStatus;
                }
                port :>> safetyInPort {
                    in alert : SafetyAlert;
                }
            }
            part :>> safetyInterlock {
                port :>> vitalsInPort {
                    in vitals : VitalSigns;
                }
                port :>> feedbackInPort {
                    in feedback : TherapyFeedback;
                }
                port :>> alertPort {
                    out alert : SafetyAlert;
                }
                port :>> shutdownPort {
                    out shutdown : Boolean;
                }
            }
            part :>> operatorPanel {
                port :>> commandPort {
                    out command : OperatorCommand;
                }
            }

            flow chargeFlow of ChargeStatus
                from powerManagement.chargePort.chargeStatus
                to controlProcessor.chargeInPort.chargeStatus;
            flow vitalsFlow of VitalSigns
                from biometricSensor.vitalsPort.vitals
                to controlProcessor.vitalsInPort.vitals;
            flow vitalsToSafetyFlow of VitalSigns
                from biometricSensor.vitalsPort.vitals
                to safetyInterlock.vitalsInPort.vitals;
            flow therapyParamsFlow of TherapyParameters
                from controlProcessor.therapyOutPort.params
                to therapyGenerator.therapyInPort.params;
            flow therapyFeedbackFlow of TherapyFeedback
                from therapyGenerator.therapyOutPort.feedback
                to controlProcessor.feedbackPort.feedback;
            flow feedbackToSafetyFlow of TherapyFeedback
                from therapyGenerator.therapyOutPort.feedback
                to safetyInterlock.feedbackInPort.feedback;
            flow safetyAlertFlow of SafetyAlert
                from safetyInterlock.alertPort.alert
                to controlProcessor.safetyInPort.alert;
            flow commandFlow of OperatorCommand
                from operatorPanel.commandPort.command
                to controlProcessor.commandPort.command;
        }

        satisfy reqAccuracy : AccuracyRequirement {
            subject :>> biometricSensor = deviceSystem.biometricSensor;
        }
        satisfy reqReliability : ReliabilityRequirement {
            subject :>> powerManagement = deviceSystem.powerManagement;
        }
        satisfy reqSafeOperation : SafeOperationRequirement {
            subject :>> safetyInterlock = deviceSystem.safetyInterlock;
        }
        satisfy reqClosedLoop : ClosedLoopRequirement {
            subject :>> device = deviceSystem;
        }

        action def ClosedLoopTreatment {
            in command : OperatorCommand;
            out finalStatus : SystemStatus;

            first start;
            then action safetyCheck : PerformSafetyCheck {
                out safe : Boolean;
            }
            then decide;
            if safetyCheck.safe then therapyLoop;
            if !safetyCheck.safe then endTreatment;

            loop action therapyLoop {
                action sense : SenseVitals {
                    out vitals : VitalSigns;
                }
                then action validate : ValidateVitals {
                    in rawVitals : VitalSigns = sense.vitals;
                    out validatedVitals : VitalSigns;
                }
                then action analyze : AnalyzeVitals {
                    in vitals : VitalSigns = validate.validatedVitals;
                    in feedback : TherapyFeedback;
                    out adjustedParams : TherapyParameters;
                }
                then action generate : GenerateTherapy {
                    in params : TherapyParameters = analyze.adjustedParams;
                    out feedback : TherapyFeedback;
                }
                then action checkSafety : CheckSafety {
                    in vitals : VitalSigns = validate.validatedVitals;
                    in feedback : TherapyFeedback = generate.feedback;
                    out safe : Boolean;
                    out alert : SafetyAlert;
                }
            } until command.stopTreatment or !therapyLoop.checkSafety.safe;

            then action endTreatment;
            then done;
        }

        state 'device operation' parallel {
            ref device : PortableMedicalDeviceSystem;

            state 'operational states' {
                entry; then standby;

                state standby;
                transition 'standby-to-safetyCheck'
                    first standby
                    accept 'StartTherapyCommand'
                    do device.controlProcessor.'perform safety check'
                    then safetyCheck;

                state safetyCheck {
                    entry device.controlProcessor.'perform safety check';
                }
                transition 'safetyCheck-to-active'
                    first safetyCheck
                    accept 'SafetyCheckPassed'
                    then activeTherapy;
                transition 'safetyCheck-to-alarm'
                    first safetyCheck
                    accept 'SafetyCheckFailed'
                    then alarmState;

                state activeTherapy {
                    entry device.therapyGenerator.'generate therapy';
                    do device.biometricSensor.'sense vitals';
                    do device.controlProcessor.'analyze vitals';
                }
                transition 'active-to-standby-stop'
                    first activeTherapy
                    accept 'StopTherapyCommand'
                    then standby;
                transition 'active-to-alarm'
                    first activeTherapy
                    accept 'SafetyAlert' if device.safetyInterlock.alertPort.alert.shutdownRequired
                    then alarmState;

                state alarmState {
                    entry device.safetyInterlock.'trigger alarm';
                }
                transition 'alarm-to-standby'
                    first alarmState
                    accept 'ResetCommand'
                    then standby;
            }

            state 'health states' {
                entry; then normal;

                state normal {
                    do device.powerManagement.'monitor battery';
                }
                transition 'normal-to-lowPower'
                    first normal
                    accept when device.powerManagement.'monitor battery'.chargeLevel < 20
                    then lowPower;

                state lowPower {
                    do 'ReducePowerConsumption';
                }
                transition 'lowPower-to-depleted'
                    first lowPower
                    accept when device.powerManagement.'monitor battery'.chargeLevel < 5
                    then depleted;

                state depleted {
                    do 'SignalDepleted';
                }
                transition 'depleted-to-normal'
                    first depleted
                    accept when device.powerManagement.'monitor battery'.chargeLevel > 20
                    then normal;
            }
        }
    }
}
