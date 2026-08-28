package ScramblerTherapySystem {
    import ISQ::*;
    import ScalarValues::*;
    import Time::*;

    // ---------- Value Types ----------
    value def VoltageValue :> Real { unit 'V'; }
    value def CurrentValue :> Real { unit 'mA'; }
    value def FrequencyValue :> Real { unit 'Hz'; }
    value def ImpedanceValue :> Real { unit 'kOhm'; }
    value def DurationValue :> Real { unit 'min'; }
    value def PowerValue :> Real { unit 'W'; }
    value def AmplitudeValue :> Real { unit 'mA'; }
    value def PulseWidthValue :> Real { unit 'us'; }

    // ---------- Enumerations ----------
    enum def OperationalState {
        idle;
        configuring;
        activeTherapy;
        paused;
        emergencyStop;
    }

    enum def SafetyCondition {
        normal;
        warning;
        critical;
    }

    enum def PowerSource {
        battery;
        mains;
    }

    enum def TherapyPhase {
        initialAssessment;
        activeCycle;
        finalAssessment;
    }

    // ---------- Item Definitions ----------
    item def ElectricalSignal {
        attribute amplitude : AmplitudeValue;
        attribute frequency : FrequencyValue;
        attribute pulseWidth : PulseWidthValue;
        attribute duration : DurationValue;
    }

    item def PatientFeedback {
        attribute painLevel : Integer(0..10);
        attribute comfortLevel : Integer(0..10);
        attribute timestamp : Time;
    }

    item def TherapyParameters {
        attribute amplitude : AmplitudeValue;
        attribute frequency : FrequencyValue;
        attribute sessionDuration : DurationValue;
    }

    item def SafetyStatus {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute impedance : ImpedanceValue;
        attribute condition : SafetyCondition;
    }

    item def PowerFlow {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute source : PowerSource;
    }

    item def SafetyCommand {
        attribute haltTherapy : Boolean;
        attribute reason : String;
    }

    item def ElectrodeContact {
        attribute contactImpedance : ImpedanceValue;
        attribute contactQuality : Real(0.0..1.0);
    }

    // ---------- Port Definitions ----------
    port def SignalOutputPort {
        out signal : ElectricalSignal;
    }

    port def SignalInputPort {
        in signal : ElectricalSignal;
    }

    port def FeedbackPort {
        in feedback : PatientFeedback;
        out parameters : TherapyParameters;
    }

    port def MonitoringPort {
        out status : SafetyStatus;
        in command : SafetyCommand;
    }

    port def PowerPort {
        out power : PowerFlow;
    }

    port def ContactSensePort {
        out contact : ElectrodeContact;
    }

    // ---------- Action Definitions ----------
    action def GenerateSignal {
        in parameters : TherapyParameters;
        out signal : ElectricalSignal;
    }

    action def AdjustParameters {
        in feedback : PatientFeedback;
        in current : TherapyParameters;
        out updated : TherapyParameters;
    }

    action def AssessPain {
        in feedback : PatientFeedback;
        out level : Integer(0..10);
    }

    action def CheckSafety {
        in status : SafetyStatus;
        out command : SafetyCommand;
    }

    // ---------- Part Definitions ----------
    part def SignalProcessingUnit {
        port signalOut : SignalOutputPort;
        port control : FeedbackPort;
        port powerIn : PowerPort;
        port monitor : MonitoringPort;

        attribute currentParameters : TherapyParameters;
        attribute maxAmplitude : AmplitudeValue = 5.0;
        attribute maxFrequency : FrequencyValue = 150.0;
        attribute minFrequency : FrequencyValue = 10.0;

        private attribute lastFeedback : PatientFeedback;

        action generateSignal : GenerateSignal {
            in parameters = currentParameters;
            out signal : ElectricalSignal;
        }

        action adjustParameters : AdjustParameters {
            in feedback = lastFeedback;
            in current = currentParameters;
            out updated : TherapyParameters;
        }

        state machine signalBehavior {
            initial start;
            state idle;
            state generating {
                entry generateSignal;
            }
            state adjusting {
                entry adjustParameters;
            }
            transition idle -> generating when powerIn.power.received;
            transition generating -> adjusting when control.feedback.received;
            transition adjusting -> generating when adjustParameters.updated.generated;
            transition generating -> idle when monitor.command.haltTherapy == true;
        }
    }

    part def SurfaceElectrodeArray {
        port signalIn : SignalInputPort;
        port contactOut : ContactSensePort;

        attribute electrodeCount : Integer = 4;
        attribute contact : ElectrodeContact;
        attribute maxImpedance : ImpedanceValue = 50.0;

        action deliverSignal {
            in signal : ElectricalSignal;
        }

        action measureContact {
            out contact : ElectrodeContact;
        }
    }

    part def ControlPanel {
        port feedbackOut : FeedbackPort;
        port powerIn : PowerPort;

        attribute sessionDuration : DurationValue;
        attribute elapsed : DurationValue;
        attribute painLevel : Integer(0..10);
        attribute comfortLevel : Integer(0..10);

        action setDuration(in d : DurationValue);
        action inputFeedback(out f : PatientFeedback);
        action displayProgress;
        action haltTherapy;

        state machine panelBehavior {
            initial start;
            state idle;
            state configuring {
                entry setDuration;
            }
            state monitoring {
                entry displayProgress;
            }
            transition idle -> configuring when sessionDuration.requested;
            transition configuring -> monitoring when sessionDuration.set;
            transition monitoring -> idle when elapsed >= sessionDuration;
        }
    }

    part def SafetyMonitoringUnit {
        port monitorOut : MonitoringPort;
        port powerIn : PowerPort;
        port contactIn : ContactSensePort;

        attribute maxVoltage : VoltageValue = 24.0;
        attribute maxCurrent : CurrentValue = 50.0;
        attribute maxImpedance : ImpedanceValue = 50.0;
        attribute minImpedance : ImpedanceValue = 0.5;
        attribute currentStatus : SafetyStatus;

        action checkSafety : CheckSafety {
            in status = currentStatus;
            out command : SafetyCommand;
        }

        action measureOutput {
            out voltage : VoltageValue;
            out current : CurrentValue;
        }

        state machine safetyBehavior {
            initial start;
            state monitoring {
                entry checkSafety;
            }
            state alarm;
            transition monitoring -> alarm when currentStatus.condition == critical;
            transition alarm -> monitoring when currentStatus.condition == normal;
        }
    }

    part def PowerManagementUnit {
        port powerOut : PowerPort [4];
        port powerOutSPU : PowerPort;
        port powerOutCP : PowerPort;
        port powerOutSMU : PowerPort;
        port powerOutSEA : PowerPort;

        attribute source : PowerSource;
        attribute batteryLevel : Real(0.0..1.0) = 1.0;
        attribute outputVoltage : VoltageValue = 12.0;
        attribute maxOutputCurrent : CurrentValue = 2000.0;

        action distributePower {
            out power : PowerFlow;
        }

        action chargeBattery {
            in source : PowerSource;
        }

        state machine powerBehavior {
            initial start;
            state onBattery;
            state onMains;
            state charging;
            transition onBattery -> onMains when source == mains;
            transition onMains -> onBattery when source == battery;
            transition onBattery -> charging when batteryLevel < 0.2;
            transition charging -> onBattery when batteryLevel >= 0.9;
        }
    }

    // ---------- Top-level System ----------
    part def ScramblerTherapySystem {
        port clinician : FeedbackPort;
        port patient : SignalOutputPort;

        part spu : SignalProcessingUnit;
        part electrodes : SurfaceElectrodeArray;
        part panel : ControlPanel;
        part smu : SafetyMonitoringUnit;
        pmu : PowerManagementUnit;

        attribute operationalState : OperationalState = idle;
        attribute sessionDuration : DurationValue;
        attribute phase : TherapyPhase;

        connection def SignalDelivery {
            end source : SignalOutputPort;
            end target : SignalInputPort;
        }

        connection def PowerDistribution {
            end source : PowerPort;
            end target : PowerPort;
        }

        connection def FeedbackFlow {
            end from : FeedbackPort;
            end to : FeedbackPort;
        }

        connection def MonitoringFlow {
            end from : MonitoringPort;
            end to : MonitoringPort;
        }

        connection def ContactFlow {
            end from : ContactSensePort;
            end to : ContactSensePort;
        }

        connection signalPath : SignalDelivery connect spu.signalOut to electrodes.signalIn;
        connection feedbackPath : FeedbackFlow connect panel.feedbackOut to spu.control;
        connection clinicianPath : FeedbackFlow connect clinician to panel.feedbackOut;
        connection patientPath : SignalDelivery connect spu.signalOut to patient;

        connection spuPower : PowerDistribution connect pmu.powerOutSPU to spu.powerIn;
        connection cpPower : PowerDistribution connect pmu.powerOutCP to panel.powerIn;
        connection smuPower : PowerDistribution connect pmu.powerOutSMU to smu.powerIn;

        connection monitorPath : MonitoringFlow connect spu.monitor to smu.monitorOut;
        connection contactPath : ContactFlow connect electrodes.contactOut to smu.contactIn;

        action therapySession {
            action initialAssessment : AssessPain;
            action activeCycle {
                action deliver : GenerateSignal;
                action monitor : CheckSafety;
                action adjust : AdjustParameters;
            }
            action finalAssessment : AssessPain;
        }

        state machine systemBehavior {
            initial start;
            state idle;
            state configuring {
                entry panel.setDuration;
            }
            state activeTherapy {
                entry spu.generateSignal;
            }
            state paused;
            state emergencyStop {
                entry smu.checkSafety;
            }
            transition idle -> configuring when clinician.parameters.received;
            transition configuring -> activeTherapy when panel.sessionDuration.set;
            transition activeTherapy -> paused when clinician.feedback.received;
            transition paused -> activeTherapy when clinician.parameters.received;
            transition activeTherapy -> emergencyStop when smu.currentStatus.condition == critical;
            transition paused -> emergencyStop when smu.currentStatus.condition == critical;
            transition emergencyStop -> idle when smu.currentStatus.condition == normal;
            transition activeTherapy -> idle when panel.elapsed >= panel.sessionDuration;
        }
    }

    // ---------- Requirements ----------
    requirement def SafetyRequirement {
        subject system : ScramblerTherapySystem;
        objective :> Real;
    }

    requirement SafeOutputLimits : SafetyRequirement {
        doc "The system shall limit electrical output to safe predefined values."
        constraint { system.smu.maxVoltage <= 24.0 and system.smu.maxCurrent <= 50.0 }
    }

    requirement EmergencyStop : SafetyRequirement {
        doc "The system shall halt therapy instantly when an unsafe condition is detected."
        constraint { system.operationalState == emergencyStop implies system.smu.currentStatus.condition == critical }
    }

    requirement AdaptiveTherapy {
        doc "The system shall adjust stimulation parameters based on real-time patient feedback."
        subject system : ScramblerTherapySystem;
        constraint { system.spu.adjustParameters.feedback.painLevel >= 0 }
    }

    requirement SessionDuration {
        doc "A therapy session shall last between 30 and 60 minutes."
        subject system : ScramblerTherapySystem;
        constraint { 30.0 <= system.sessionDuration and system.sessionDuration <= 60.0 }
    }

    requirement ElectrodeContactQuality {
        doc "The system shall monitor electrode-to-skin impedance and halt if out of range."
        subject system : ScramblerTherapySystem;
        constraint { system.electrodes.contact.contactImpedance <= system.electrodes.maxImpedance }
    }

    requirement PowerStability {
        doc "The power management unit shall supply stable power to all components."
        subject system : ScramblerTherapySystem;
        constraint { system.pmu.outputVoltage >= 11.5 and system.pmu.outputVoltage <= 12.5 }
    }
}
