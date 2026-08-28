package ScramblerTherapySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQElectromagnetism::*;

    /* Command and Signal Types */
    attribute def StartTherapyCommand;
    attribute def PauseCommand;
    attribute def ResumeCommand;
    attribute def StopCommand;
    attribute def EmergencyStopCommand;
    attribute def ConfigurationCommand;
    attribute def SessionCompleteSignal;
    attribute def ResetCommand;

    item def PainAssessment {
        attribute painLevel : Real;
        attribute timestamp : TimeValue;
    }

    item def TherapyParameters {
        attribute amplitude : ElectricPotentialValue;
        attribute frequency : FrequencyValue;
        attribute duration : TimeValue;
    }

    item def ScramblerSignal {
        attribute amplitude : ElectricPotentialValue;
        attribute frequency : FrequencyValue;
        attribute waveformPattern : String;
    }

    item def PatientFeedback {
        attribute painLevel : Real;
        attribute comfortLevel : Real;
    }

    item def SafetyStatus {
        attribute current : ElectricCurrentValue;
        attribute voltage : ElectricPotentialValue;
        attribute impedance : ElectricResistanceValue;
        attribute isSafe : Boolean;
    }

    item def PowerStatus {
        attribute batteryLevel : Real;
        attribute isMainsConnected : Boolean;
    }

    item def ControlCommand {
        attribute commandType : String;
    }

    /* Action Definitions */
    action def AssessPain { out painAssessment : PainAssessment; }

    action def GenerateScramblerSignal {
        in parameters : TherapyParameters;
        out signal : ScramblerSignal;
    }

    action def DeliverSignal { in signal : ScramblerSignal; }

    action def MonitorPatient { out feedback : PatientFeedback; }

    action def AdjustParameters {
        in feedback : PatientFeedback;
        in currentParameters : TherapyParameters;
        out newParameters : TherapyParameters;
    }

    action def CheckSafety {
        in signal : ScramblerSignal;
        in impedance : ElectricResistanceValue;
        out status : SafetyStatus;
    }

    action def HaltTherapy;

    action def SupplyPower { out power : PowerStatus; }

    action def TherapySession {
        in sessionDuration : TimeValue;
        in parameters : TherapyParameters;
        attribute elapsedTime : TimeValue;

        action initialAssessment : AssessPain;
        then loop action therapyCycle {
            action generate : GenerateScramblerSignal {
                in parameters = parameters;
                out signal;
            }
            then action deliver : DeliverSignal {
                in signal = generate.signal;
            }
            then action monitor : MonitorPatient;
            then action adjust : AdjustParameters {
                in feedback = monitor.feedback;
                in currentParameters = parameters;
                out newParameters;
            }
            then action safetyCheck : CheckSafety {
                in signal = generate.signal;
                in impedance : ElectricResistanceValue;
                out status;
            }
        } until therapyCycle.safetyCheck.status.isSafe == false or elapsedTime >= sessionDuration;
        then action finalAssessment : AssessPain;
        then done;
    }

    /* State Definition */
    state def OperationalStates;

    /* Component Definitions */
    part def SignalProcessingUnit {
        port parametersPort { in parameters : TherapyParameters; }
        port feedbackPort { in feedback : PatientFeedback; }
        port signalPort { out signal : ScramblerSignal; }
        port powerPort { in power : PowerStatus; }

        attribute currentAmplitude : ElectricPotentialValue;
        attribute currentFrequency : FrequencyValue;

        perform action generateSignal : GenerateScramblerSignal;
    }

    part def SurfaceElectrodeArray {
        port signalPort { in signal : ScramblerSignal; }
        port impedancePort { out impedance : ElectricResistanceValue; }
        port powerPort { in power : PowerStatus; }

        attribute electrodeCount : Integer;
        attribute placementLocation : String;
    }

    part def ControlPanel {
        port commandPort { out command : ControlCommand; }
        port feedbackOutputPort { out feedback : PatientFeedback; }
        port parametersPort { out parameters : TherapyParameters; }
        port statusPort { in status : SafetyStatus; }
        port painInputPort { in painAssessment : PainAssessment; }
        port powerStatusPort { in powerStatus : PowerStatus; }
        port powerPort { in power : PowerStatus; }

        attribute sessionDuration : TimeValue;
        attribute displayActive : Boolean;
    }

    part def SafetyMonitoringUnit {
        port signalPort { in signal : ScramblerSignal; }
        port impedancePort { in impedance : ElectricResistanceValue; }
        port statusPort { out status : SafetyStatus; }
        port haltPort { out haltCommand : ControlCommand; }
        port powerPort { in power : PowerStatus; }

        attribute maxCurrent : ElectricCurrentValue = 0.01;
        attribute maxVoltage : ElectricPotentialValue = 50;
        attribute maxImpedance : ElectricResistanceValue = 5000;

        perform action checkSafety : CheckSafety;
    }

    part def PowerManagementUnit {
        port powerPort { out power : PowerStatus; }

        attribute batteryLevel : Real;
        attribute isMainsConnected : Boolean;
        attribute isRecharging : Boolean;

        perform action supplyPower : SupplyPower;
    }

    part def ScramblerTherapySystem {
        port commandPort { in command : ControlCommand; }
        port painAssessmentPort { in painAssessment : PainAssessment; }

        attribute sessionDuration : TimeValue;
        attribute currentParameters : TherapyParameters;

        part signalProcessingUnit : SignalProcessingUnit;
        part electrodeArray : SurfaceElectrodeArray;
        part controlPanel : ControlPanel;
        part safetyMonitoringUnit : SafetyMonitoringUnit;
        part powerManagementUnit : PowerManagementUnit;

        perform action therapySession : TherapySession;
        exhibit state operationalStates : OperationalStates;
    }

    /* System Instance with Connections */
    part scramblerTherapySystem : ScramblerTherapySystem {
        interface signalDeliveryInterface connect signalProcessingUnit.signalPort to electrodeArray.signalPort {
            flow signalFlow of ScramblerSignal
                from signalProcessingUnit.signalPort.signal to electrodeArray.signalPort.signal;
        }

        interface feedbackInterface connect controlPanel.feedbackOutputPort to signalProcessingUnit.feedbackPort {
            flow feedbackFlow of PatientFeedback
                from controlPanel.feedbackOutputPort.feedback to signalProcessingUnit.feedbackPort.feedback;
        }

        interface parametersInterface connect controlPanel.parametersPort to signalProcessingUnit.parametersPort {
            flow parametersFlow of TherapyParameters
                from controlPanel.parametersPort.parameters to signalProcessingUnit.parametersPort.parameters;
        }

        interface safetyStatusInterface connect safetyMonitoringUnit.statusPort to controlPanel.statusPort {
            flow statusFlow of SafetyStatus
                from safetyMonitoringUnit.statusPort.status to controlPanel.statusPort.status;
        }

        interface impedanceInterface connect electrodeArray.impedancePort to safetyMonitoringUnit.impedancePort {
            flow impedanceFlow of ElectricResistanceValue
                from electrodeArray.impedancePort.impedance to safetyMonitoringUnit.impedancePort.impedance;
        }

        interface safetySignalTapInterface connect signalProcessingUnit.signalPort to safetyMonitoringUnit.signalPort {
            flow safetySignalFlow of ScramblerSignal
                from signalProcessingUnit.signalPort.signal to safetyMonitoringUnit.signalPort.signal;
        }

        interface powerStatusInterface connect powerManagementUnit.powerPort to controlPanel.powerStatusPort {
            flow powerStatusFlow of PowerStatus
                from powerManagementUnit.powerPort.power to controlPanel.powerStatusPort.powerStatus;
        }

        interface powerToSpuInterface connect powerManagementUnit.powerPort to signalProcessingUnit.powerPort {
            flow powerToSpuFlow of PowerStatus
                from powerManagementUnit.powerPort.power to signalProcessingUnit.powerPort.power;
        }

        interface powerToElectrodeInterface connect powerManagementUnit.powerPort to electrodeArray.powerPort {
            flow powerToElectrodeFlow of PowerStatus
                from powerManagementUnit.powerPort.power to electrodeArray.powerPort.power;
        }

        interface powerToSafetyInterface connect powerManagementUnit.powerPort to safetyMonitoringUnit.powerPort {
            flow powerToSafetyFlow of PowerStatus
                from powerManagementUnit.powerPort.power to safetyMonitoringUnit.powerPort.power;
        }

        interface powerToControlInterface connect powerManagementUnit.powerPort to controlPanel.powerPort {
            flow powerToControlFlow of PowerStatus
                from powerManagementUnit.powerPort.power to controlPanel.powerPort.power;
        }
    }

    /* Operational State Machine */
    state operationalStates : OperationalStates {
        entry; then idle;

        state idle;
        accept ConfigurationCommand then configuring;

        state configuring;
        accept StartTherapyCommand then activeTherapy;
        accept StopCommand then idle;

        state activeTherapy {
            do action runTherapy : TherapySession {
                in sessionDuration = scramblerTherapySystem.controlPanel.sessionDuration;
                in parameters = scramblerTherapySystem.currentParameters;
            }
        }
        accept PauseCommand then paused;
        accept EmergencyStopCommand then emergencyStop;
        accept SessionCompleteSignal then idle;

        state paused;
        accept ResumeCommand then activeTherapy;
        accept EmergencyStopCommand then emergencyStop;
        accept StopCommand then idle;

        state emergencyStop {
            entry action haltTherapy : HaltTherapy;
        }
        accept ResetCommand then idle;
    }

    /* Requirements */
    requirement def TherapySafetyRequirement {
        subject system : ScramblerTherapySystem;
        /* The system shall halt therapy within 100 ms when an unsafe condition is detected. */
    }

    requirement def SignalGenerationRequirement {
        subject spu : SignalProcessingUnit;
        /* The signal processing unit shall generate variable electrical waveforms with amplitude adjustable up to 100 V and frequency adjustable between 1 and 300 Hz. */
    }

    requirement def SessionDurationRequirement {
        subject cp : ControlPanel;
        /* The control panel shall allow therapy session duration to be set between 30 and 60 minutes. */
    }

    requirement def ImpedanceMonitoringRequirement {
        subject smu : SafetyMonitoringUnit;
        /* The safety monitoring unit shall continuously monitor skin impedance and halt therapy if impedance exceeds 5000 Ohm. */
    }

    requirement def CurrentLimitRequirement {
        subject smu : SafetyMonitoringUnit;
        /* The safety monitoring unit shall ensure delivered current does not exceed 10 mA. */
    }

    requirement def VoltageLimitRequirement {
        subject smu : SafetyMonitoringUnit;
        /* The safety monitoring unit shall ensure delivered voltage does not exceed 50 V. */
    }

    requirement def AdaptiveTherapyRequirement {
        subject system : ScramblerTherapySystem;
        /* The system shall automatically adjust stimulation parameters based on real-time patient feedback. */
    }

    requirement def PowerStabilityRequirement {
        subject pmu : PowerManagementUnit;
        /* The power management unit shall provide stable electrical power to all components during the entire therapy session. */
    }

    requirement def PainReductionRequirement {
        subject system : ScramblerTherapySystem;
        /* The therapy shall reduce the patient's pain level by at least 2 points on a 0-10 scale as measured by initial and final pain assessments. */
    }

    requirement therapySafetyReq : TherapySafetyRequirement;
    requirement signalGenReq : SignalGenerationRequirement;
    requirement sessionDurReq : SessionDurationRequirement;
    requirement impedanceMonReq : ImpedanceMonitoringRequirement;
    requirement currentLimitReq : CurrentLimitRequirement;
    requirement voltageLimitReq : VoltageLimitRequirement;
    requirement adaptiveTherapyReq : AdaptiveTherapyRequirement;
    requirement powerStabilityReq : PowerStabilityRequirement;
    requirement painReductionReq : PainReductionRequirement;
}
