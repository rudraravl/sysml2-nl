package NasalEPAPSystem {

    import ScalarValues::*;

    package Types {
        value type Pressure :> Real {
            doc /* Airway pressure in cmH2O */;
        }
        value type FlowRate :> Real {
            doc /* Airflow rate in L/min, negative for exhalation */;
        }
        value type Volume :> Real {
            doc /* Volume in mL */;
        }
        value type TimeDuration :> Real {
            doc /* Time duration in seconds */;
        }
        value type Fraction :> Real;
        value type ValvePosition :> Fraction {
            doc /* 0.0 = fully closed, 1.0 = fully open */;
        }

        enum BreathingPhase {
            inhalation;
            exhalation;
            transition;
            apnea;
        }

        enum AlarmLevel {
            none;
            low;
            high;
            critical;
        }

        enum DeviceState {
            off;
            standby;
            operating;
            emergencyShutdown;
        }
    }

    package Items {
        item Air;
        item def AirSample {
            attribute pressure: Types::Pressure;
            attribute flow: Types::FlowRate;
        }
    }

    package PortDefinitions {
        import Types::*;
        import Items::*;

        port def AirPort {
            attribute pressure: Pressure;
            attribute flow: FlowRate;
            flow air: Air;
        }

        port def BreathingSignalPort {
            attribute phase: BreathingPhase;
            attribute pressure: Pressure;
            attribute flow: FlowRate;
        }

        port def ValveCommandPort {
            attribute position: ValvePosition;
            attribute targetPressure: Pressure;
        }

        port def ValveFeedbackPort {
            attribute position: ValvePosition;
        }

        port def PressureFeedbackPort {
            attribute pressure: Pressure;
            attribute flow: FlowRate;
        }

        port def AlarmPort {
            attribute level: AlarmLevel;
            attribute message: String;
        }

        port def EmergencyPort {
            attribute shutdownRequested: Boolean;
        }

        port def PowerPort {
            attribute powerOn: Boolean;
            attribute voltage: Real;
        }
    }

    package Components {
        import Types::*;
        import Items::*;
        import PortDefinitions::*;

        part def NasalInterface {
            doc /* Nasal interface (mask or nasal prongs) connecting the therapeutic device to the patient airway */;
            attribute interfaceType: String = "nasal prongs";
            attribute deadSpaceVolume: Volume = 30;
            attribute sealIntegrity: Fraction = 0.95;

            port patientEnd: AirPort;
            port deviceEnd: AirPort;

            flow airConduit: Air from patientEnd to deviceEnd;
        }

        part def ExpiratoryValve {
            doc /* Expiratory valve that creates controlled resistance during exhalation to generate positive pressure */;
            attribute currentPosition: ValvePosition = 1.0;
            attribute maxResponseTime: TimeDuration = 0.05;
            attribute resistanceCoefficient: Real = 0.8;

            port airIn: AirPort;
            port airOut: AirPort;
            port commandIn: ValveCommandPort;
            port feedbackOut: ValveFeedbackPort;

            action def Actuate {
                in targetPosition: ValvePosition;
                out achievedPosition: ValvePosition;
            }

            action actuate: Actuate;

            flow airFlow: Air from airIn to airOut;
        }

        part def RespiratoryMonitor {
            doc /* Respiratory monitor that continuously senses airflow to detect breathing phase and measure airway pressure */;
            attribute samplingRate: Real = 1000;
            attribute inhalationFlowThreshold: FlowRate = 5;
            attribute exhalationFlowThreshold: FlowRate = -3;
            attribute apneaTimeout: TimeDuration = 10;
            attribute currentPhase: BreathingPhase = BreathingPhase::apnea;
            attribute measuredPressure: Pressure = 0;
            attribute measuredFlow: FlowRate = 0;

            port airSampling: AirPort;
            port breathingSignalOut: BreathingSignalPort;
            port pressureFeedback: PressureFeedbackPort;

            action def SampleAirflow {
                in sampledFlow: FlowRate;
                in sampledPressure: Pressure;
                out detectedPhase: BreathingPhase;
                out reportedPressure: Pressure;
                out reportedFlow: FlowRate;
            }

            action sample: SampleAirflow;

            action def UpdateReadings {
                out newPressure: Pressure;
                out newFlow: FlowRate;
                out newPhase: BreathingPhase;
            }

            action updateReadings: UpdateReadings;

            state machine BreathingDetection {
                state apnea;
                state inhalation;
                state exhalation;
                state transitionState;

                transition initial to apnea;

                transition apnea to inhalation
                    when airSampling.flow > inhalationFlowThreshold;

                transition apnea to exhalation
                    when airSampling.flow < exhalationFlowThreshold;

                transition inhalation to exhalation
                    when airSampling.flow < exhalationFlowThreshold;

                transition exhalation to inhalation
                    when airSampling.flow > inhalationFlowThreshold;

                transition inhalation to transitionState
                    when airSampling.flow <= inhalationFlowThreshold and airSampling.flow >= 0;

                transition exhalation to transitionState
                    when airSampling.flow >= exhalationFlowThreshold and airSampling.flow <= 0;

                transition transitionState to inhalation
                    when airSampling.flow > inhalationFlowThreshold;

                transition transitionState to exhalation
                    when airSampling.flow < exhalationFlowThreshold;

                entry apnea {
                    currentPhase = BreathingPhase::apnea;
                    breathingSignalOut.phase = currentPhase;
                    measuredPressure = airSampling.pressure;
                    measuredFlow = airSampling.flow;
                    breathingSignalOut.pressure = measuredPressure;
                    breathingSignalOut.flow = measuredFlow;
                    pressureFeedback.pressure = measuredPressure;
                    pressureFeedback.flow = measuredFlow;
                }

                entry inhalation {
                    currentPhase = BreathingPhase::inhalation;
                    breathingSignalOut.phase = currentPhase;
                    measuredPressure = airSampling.pressure;
                    measuredFlow = airSampling.flow;
                    breathingSignalOut.pressure = measuredPressure;
                    breathingSignalOut.flow = measuredFlow;
                    pressureFeedback.pressure = measuredPressure;
                    pressureFeedback.flow = measuredFlow;
                }

                entry exhalation {
                    currentPhase = BreathingPhase::exhalation;
                    breathingSignalOut.phase = currentPhase;
                    measuredPressure = airSampling.pressure;
                    measuredFlow = airSampling.flow;
                    breathingSignalOut.pressure = measuredPressure;
                    breathingSignalOut.flow = measuredFlow;
                    pressureFeedback.pressure = measuredPressure;
                    pressureFeedback.flow = measuredFlow;
                }

                entry transitionState {
                    currentPhase = BreathingPhase::transition;
                    breathingSignalOut.phase = currentPhase;
                    measuredPressure = airSampling.pressure;
                    measuredFlow = airSampling.flow;
                    breathingSignalOut.pressure = measuredPressure;
                    breathingSignalOut.flow = measuredFlow;
                    pressureFeedback.pressure = measuredPressure;
                    pressureFeedback.flow = measuredFlow;
                }
            }
        }

        part def PressureRegulator {
            doc /* Pressure regulator that controls the expiratory valve to maintain prescribed therapeutic pressure */;
            attribute prescribedPressure: Pressure = 5;
            attribute minTherapeuticPressure: Pressure = 3;
            attribute maxTherapeuticPressure: Pressure = 15;
            attribute adjustmentRate: Real = 0.5;
            attribute currentPhase: BreathingPhase = BreathingPhase::apnea;
            attribute currentMeasuredPressure: Pressure = 0;
            attribute currentMeasuredFlow: FlowRate = 0;
            attribute currentValvePosition: ValvePosition = 1.0;

            port breathingSignalIn: BreathingSignalPort;
            port pressureFeedbackIn: PressureFeedbackPort;
            port valveCommandOut: ValveCommandPort;
            port valveFeedbackIn: ValveFeedbackPort;

            action def RegulatePressure {
                in phase: BreathingPhase;
                in measuredPressure: Pressure;
                in measuredFlow: FlowRate;
                in currentValvePos: ValvePosition;
                out valvePosition: ValvePosition;
                out targetPressure: Pressure;
            }

            action regulate: RegulatePressure;

            state machine RegulationLogic {
                state idle;
                state inhalationRegulation;
                state exhalationRegulation;
                state transitionRegulation;

                transition initial to idle;

                transition idle to inhalationRegulation
                    when breathingSignalIn.phase == BreathingPhase::inhalation;

                transition idle to exhalationRegulation
                    when breathingSignalIn.phase == BreathingPhase::exhalation;

                transition idle to transitionRegulation
                    when breathingSignalIn.phase == BreathingPhase::transition;

                transition inhalationRegulation to exhalationRegulation
                    when breathingSignalIn.phase == BreathingPhase::exhalation;

                transition exhalationRegulation to inhalationRegulation
                    when breathingSignalIn.phase == BreathingPhase::inhalation;

                transition exhalationRegulation to transitionRegulation
                    when breathingSignalIn.phase == BreathingPhase::transition;

                transition transitionRegulation to exhalationRegulation
                    when breathingSignalIn.phase == BreathingPhase::exhalation;

                transition transitionRegulation to inhalationRegulation
                    when breathingSignalIn.phase == BreathingPhase::inhalation;

                entry idle {
                    valveCommandOut.position = 1.0;
                    valveCommandOut.targetPressure = 0;
                    currentValvePosition = 1.0;
                }

                entry inhalationRegulation {
                    valveCommandOut.position = 1.0;
                    valveCommandOut.targetPressure = 0;
                    currentValvePosition = 1.0;
                    currentPhase = BreathingPhase::inhalation;
                }

                entry exhalationRegulation {
                    currentPhase = BreathingPhase::exhalation;
                    valveCommandOut.targetPressure = prescribedPressure;
                    currentMeasuredPressure = pressureFeedbackIn.pressure;
                    if (pressureFeedbackIn.pressure < prescribedPressure) {
                        valveCommandOut.position = 0.3;
                    } else if (pressureFeedbackIn.pressure > prescribedPressure) {
                        valveCommandOut.position = 0.6;
                    } else {
                        valveCommandOut.position = 0.5;
                    }
                    currentValvePosition = valveCommandOut.position;
                }

                entry transitionRegulation {
                    currentPhase = BreathingPhase::transition;
                    valveCommandOut.position = 0.7;
                    valveCommandOut.targetPressure = prescribedPressure;
                    currentValvePosition = 0.7;
                }
            }
        }

        part def SafetyMonitor {
            doc /* Safety monitor that continuously checks airway pressure against predefined safety limits */;
            attribute maxSafePressure: Pressure = 20;
            attribute minSafePressure: Pressure = 2;
            attribute highAlarmThreshold: Pressure = 18;
            attribute lowAlarmThreshold: Pressure = 2.5;
            attribute apneaDetectionTime: TimeDuration = 10;
            attribute alarmActive: Boolean = false;
            attribute currentAlarmLevel: AlarmLevel = AlarmLevel::none;
            attribute alarmMessage: String = "";
            attribute measuredPressure: Pressure = 0;
            attribute measuredFlow: FlowRate = 0;

            port pressureFeedbackIn: PressureFeedbackPort;
            port alarmOut: AlarmPort;
            port emergencyOut: EmergencyPort;

            action def EvaluatePressure {
                in pressure: Pressure;
                in flow: FlowRate;
                out alarmLevel: AlarmLevel;
                out message: String;
                out shutdown: Boolean;
            }

            action evaluate: EvaluatePressure;

            state machine SafetyStateMachine {
                state monitoring;
                state lowPressureWarning;
                state highPressureWarning;
                state emergencyShutdown;

                transition initial to monitoring;

                transition monitoring to highPressureWarning
                    when pressureFeedbackIn.pressure > highAlarmThreshold;

                transition monitoring to lowPressureWarning
                    when pressureFeedbackIn.pressure < lowAlarmThreshold;

                transition highPressureWarning to monitoring
                    when pressureFeedbackIn.pressure <= highAlarmThreshold and pressureFeedbackIn.pressure >= lowAlarmThreshold;

                transition lowPressureWarning to monitoring
                    when pressureFeedbackIn.pressure >= lowAlarmThreshold and pressureFeedbackIn.pressure <= highAlarmThreshold;

                transition highPressureWarning to emergencyShutdown
                    when pressureFeedbackIn.pressure > maxSafePressure;

                transition lowPressureWarning to emergencyShutdown
                    when pressureFeedbackIn.pressure < minSafePressure;

                entry monitoring {
                    currentAlarmLevel = AlarmLevel::none;
                    alarmActive = false;
                    alarmOut.level = AlarmLevel::none;
                    alarmOut.message = "";
                    emergencyOut.shutdownRequested = false;
                    measuredPressure = pressureFeedbackIn.pressure;
                }

                entry highPressureWarning {
                    currentAlarmLevel = AlarmLevel::high;
                    alarmActive = true;
                    alarmOut.level = AlarmLevel::high;
                    alarmOut.message = "High airway pressure detected";
                    measuredPressure = pressureFeedbackIn.pressure;
                }

                entry lowPressureWarning {
                    currentAlarmLevel = AlarmLevel::low;
                    alarmActive = true;
                    alarmOut.level = AlarmLevel::low;
                    alarmOut.message = "Low airway pressure detected";
                    measuredPressure = pressureFeedbackIn.pressure;
                }

                entry emergencyShutdown {
                    currentAlarmLevel = AlarmLevel::critical;
                    alarmActive = true;
                    alarmOut.level = AlarmLevel::critical;
                    alarmOut.message = "Emergency shutdown: pressure out of safe range";
                    emergencyOut.shutdownRequested = true;
                    measuredPressure = pressureFeedbackIn.pressure;
                }
            }
        }

        part def AlarmUnit {
            doc /* Alarm unit that provides audible and visual alarms for safety events */;
            attribute audibleAlarmEnabled: Boolean = true;
            attribute visualAlarmEnabled: Boolean = true;
            attribute currentLevel: AlarmLevel = AlarmLevel::none;
            attribute currentMessage: String = "";
            attribute alarmActive: Boolean = false;

            port alarmIn: AlarmPort;

            action def TriggerAlarm {
                in level: AlarmLevel;
                in message: String;
            }

            action def ClearAlarm;

            action trigger: TriggerAlarm;
            action clearAlarm: ClearAlarm;

            state machine AlarmManagement {
                state noAlarm;
                state lowAlarm;
                state highAlarm;
                state criticalAlarm;

                transition initial to noAlarm;

                transition noAlarm to lowAlarm
                    when alarmIn.level == AlarmLevel::low;

                transition noAlarm to highAlarm
                    when alarmIn.level == AlarmLevel::high;

                transition noAlarm to criticalAlarm
                    when alarmIn.level == AlarmLevel::critical;

                transition lowAlarm to noAlarm
                    when alarmIn.level == AlarmLevel::none;

                transition highAlarm to noAlarm
                    when alarmIn.level == AlarmLevel::none;

                transition highAlarm to criticalAlarm
                    when alarmIn.level == AlarmLevel::critical;

                transition lowAlarm to criticalAlarm
                    when alarmIn.level == AlarmLevel::critical;

                transition criticalAlarm to noAlarm
                    when alarmIn.level == AlarmLevel::none;

                entry noAlarm {
                    currentLevel = AlarmLevel::none;
                    currentMessage = "";
                    alarmActive = false;
                }

                entry lowAlarm {
                    currentLevel = AlarmLevel::low;
                    currentMessage = alarmIn.message;
                    alarmActive = true;
                }

                entry highAlarm {
                    currentLevel = AlarmLevel::high;
                    currentMessage = alarmIn.message;
                    alarmActive = true;
                }

                entry criticalAlarm {
                    currentLevel = AlarmLevel::critical;
                    currentMessage = alarmIn.message;
                    alarmActive = true;
                }
            }
        }

        part def PowerSupply {
            doc /* Power supply that provides power to the therapeutic device and handles emergency shutdown */;
            attribute outputVoltage: Real = 12;
            attribute maxCurrent: Real = 2;
            attribute powerActive: Boolean = false;

            port powerOut: PowerPort;
            port emergencyIn: EmergencyPort;

            action def PowerOn;
            action def PowerOff;

            action powerOn: PowerOn;
            action powerOff: PowerOff;

            state machine PowerControl {
                state poweredOff;
                state poweredOn;
                state emergencyOff;

                transition initial to poweredOff;

                transition poweredOff to poweredOn
                    when powerActive == true;

                transition poweredOn to poweredOff
                    when powerActive == false;

                transition poweredOn to emergencyOff
                    when emergencyIn.shutdownRequested == true;

                transition emergencyOff to poweredOff
                    when emergencyIn.shutdownRequested == false and powerActive == false;

                entry poweredOn {
                    powerOut.powerOn = true;
                    powerOut.voltage = outputVoltage;
                }

                entry poweredOff {
                    powerOut.powerOn = false;
                    powerOut.voltage = 0;
                }

                entry emergencyOff {
                    powerOut.powerOn = false;
                    powerOut.voltage = 0;
                }
            }
        }

        part def TherapeuticDevice {
            doc /* Main therapeutic device containing the expiratory valve, respiratory monitor, pressure regulator, safety monitor, alarm unit, and power supply */;
            attribute deviceId: String;
            attribute deviceState: DeviceState = DeviceState::off;
            attribute prescribedPressure: Pressure = 5;
            attribute startupTime: TimeDuration = 2;
            attribute shutdownResponseTime: TimeDuration = 0.5;

            part expiratoryValve: ExpiratoryValve;
            part respiratoryMonitor: RespiratoryMonitor;
            part pressureRegulator: PressureRegulator;
            part safetyMonitor: SafetyMonitor;
            part alarmUnit: AlarmUnit;
            part powerSupply: PowerSupply;

            port airIntake: AirPort;
            port patientConnection: AirPort;

            connect airIntake to expiratoryValve.airIn;
            connect expiratoryValve.airOut to patientConnection;
            connect patientConnection to respiratoryMonitor.airSampling;

            connect respiratoryMonitor.breathingSignalOut to pressureRegulator.breathingSignalIn;
            connect respiratoryMonitor.pressureFeedback to pressureRegulator.pressureFeedbackIn;
            connect respiratoryMonitor.pressureFeedback to safetyMonitor.pressureFeedbackIn;

            connect pressureRegulator.valveCommandOut to expiratoryValve.commandIn;
            connect expiratoryValve.feedbackOut to pressureRegulator.valveFeedbackIn;

            connect safetyMonitor.alarmOut to alarmUnit.alarmIn;
            connect safetyMonitor.emergencyOut to powerSupply.emergencyIn;

            state machine DeviceOperation {
                state off;
                state standby;
                state operating;
                state emergencyShutdown;

                transition initial to off;

                transition off to standby
                    when powerSupply.powerOut.powerOn == true;

                transition standby to operating
                    when powerSupply.powerOut.powerOn == true;

                transition operating to standby
                    when powerSupply.powerOut.powerOn == true and safetyMonitor.emergencyOut.shutdownRequested == false;

                transition operating to emergencyShutdown
                    when safetyMonitor.emergencyOut.shutdownRequested == true;

                transition standby to off
                    when powerSupply.powerOut.powerOn == false;

                transition emergencyShutdown to off
                    when powerSupply.powerOut.powerOn == false;

                entry off {
                    deviceState = DeviceState::off;
                }

                entry standby {
                    deviceState = DeviceState::standby;
                }

                entry operating {
                    deviceState = DeviceState::operating;
                }

                entry emergencyShutdown {
                    deviceState = DeviceState::emergencyShutdown;
                }
            }
        }
    }

    part def NasalEPAPSystem {
        doc /* Nasal Expiratory Positive Airway Pressure (EPAP) system for treating obstructive sleep apnea */;
        attribute systemId: String;
        attribute systemVersion: String = "1.0";

        part therapeuticDevice: Components::TherapeuticDevice;
        part nasalInterface: Components::NasalInterface;

        port ambientAirIntake: PortDefinitions::AirPort;
        port patientAirway: PortDefinitions::AirPort;

        connect ambientAirIntake to therapeuticDevice.airIntake;
        connect therapeuticDevice.patientConnection to nasalInterface.deviceEnd;
        connect nasalInterface.patientEnd to patientAirway;
    }

    package Requirements {
        import Types::*;

        requirement def MaintainExpiratoryPressure {
            doc /* The system shall maintain a positive pressure in the user airway during exhalation to prevent airway collapse */;
            attribute pressure: Pressure;
            attribute phase: BreathingPhase;
            constraint { phase == BreathingPhase::exhalation implies pressure >= 3 and pressure <= 15 }
        }

        requirement def MinimizeInhalationResistance {
            doc /* During inhalation the valve shall open fully to provide minimal resistance for comfortable natural breathing */;
            attribute valvePosition: ValvePosition;
            attribute phase: BreathingPhase;
            constraint { phase == BreathingPhase::inhalation implies valvePosition >= 0.95 }
        }

        requirement def DetectBreathingPhase {
            doc /* The respiratory monitor shall detect inhalation and exhalation phases from the patient airflow */;
            attribute detectedPhase: BreathingPhase;
            attribute actualPhase: BreathingPhase;
            constraint { detectedPhase == actualPhase }
        }

        requirement def EnforceSafetyPressureLimits {
            doc /* The safety monitor shall prevent airway pressure from exceeding safe limits at all times */;
            attribute maxPressure: Pressure;
            constraint { maxPressure <= 20 }
        }

        requirement def EmergencyShutdownResponse {
            doc /* The system shall initiate emergency shutdown when pressure exceeds the maximum safe value */;
            attribute shutdownTime: TimeDuration;
            constraint { shutdownTime <= 1 }
        }

        requirement def ProvideAlarms {
            doc /* The system shall activate audible and visual alarms when pressure deviates from safe therapeutic range */;
            attribute alarmActivated: Boolean;
            attribute alarmLevel: AlarmLevel;
            constraint { alarmLevel != AlarmLevel::none implies alarmActivated == true }
        }

        requirement def NasalInterfaceSeal {
            doc /* The nasal interface shall form an effective pneumatic seal with the patient nares */;
            attribute sealIntegrity: Fraction;
            constraint { sealIntegrity >= 0.9 }
        }

        requirement def ResponsiveTherapy {
            doc /* The system shall respond to breathing phase changes within 100 milliseconds for responsive therapy */;
            attribute responseTime: TimeDuration;
            constraint { responseTime <= 0.1 }
        }

        requirement def PatientComfort {
            doc /* The system shall provide comfortable therapy by minimizing breathing resistance during inhalation */;
            attribute inhalationResistance: Pressure;
            constraint { inhalationResistance <= 2 }
        }

        requirement def SystemSafety {
            doc /* The entire system shall be safe for patient use under all operating conditions */;
            attribute maxOperatingPressure: Pressure;
            attribute minOperatingPressure: Pressure;
            constraint { maxOperatingPressure <= 20 and minOperatingPressure >= 0 }
        }

        requirement def ContinuousMonitoring {
            doc /* The respiratory monitor shall continuously sense airflow and pressure throughout therapy */;
            attribute monitoringActive: Boolean;
            attribute deviceState: DeviceState;
            constraint { deviceState == DeviceState::operating implies monitoringActive == true }
        }

        requirement def ValveAdjustmentAccuracy {
            doc /* The pressure regulator shall adjust the valve to maintain prescribed pressure within 1 cmH2O */;
            attribute actualPressure: Pressure;
            attribute prescribedPressure: Pressure;
            constraint { actualPressure >= prescribedPressure - 1 and actualPressure <= prescribedPressure + 1 }
        }
    }

    package Satisfaction {
        import Components::*;
        import Requirements::*;

        satisfaction PressureRegulator satisfies MaintainExpiratoryPressure;
        satisfaction PressureRegulator satisfies ValveAdjustmentAccuracy;
        satisfaction ExpiratoryValve satisfies MinimizeInhalationResistance;
        satisfaction ExpiratoryValve satisfies PatientComfort;
        satisfaction RespiratoryMonitor satisfies DetectBreathingPhase;
        satisfaction RespiratoryMonitor satisfies ContinuousMonitoring;
        satisfaction SafetyMonitor satisfies EnforceSafetyPressureLimits;
        satisfaction TherapeuticDevice satisfies EmergencyShutdownResponse;
        satisfaction AlarmUnit satisfies ProvideAlarms;
        satisfaction NasalInterface satisfies NasalInterfaceSeal;
        satisfaction PressureRegulator satisfies ResponsiveTherapy;
        satisfaction NasalEPAPSystem satisfies SystemSafety;
    }
}
