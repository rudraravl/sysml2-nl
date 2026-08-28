package VoltageDetectorSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQElectromagnetism::*;

    // ===== Value Types =====
    def VoltageValue :> Real {
        :>> unit = "V";
    }
    def VoltageThreshold :> Real {
        :>> unit = "V";
    }
    def FrequencyValue :> Real {
        :>> unit = "Hz";
    }
    def TimeValue :> Real {
        :>> unit = "s";
    }
    def BooleanSignal :> Boolean;

    // ===== Enumerations =====
    enum ViolationType {
        none = 0,
        underVoltage = 1,
        overVoltage = 2,
    }

    enum SystemState {
        initialization = 0,
        standby = 1,
        activeMonitoring = 2,
        alarm = 3,
    }

    enum MonitoringCommand {
        disable = 0,
        enable = 1,
    }

    // ===== Item Types =====
    item def VoltageReading {
        attribute measuredVoltage : VoltageValue;
        attribute timestamp : TimeValue;
        attribute valid : BooleanSignal;
    }

    item def ThresholdConfig {
        attribute upperLimit : VoltageThreshold;
        attribute lowerLimit : VoltageThreshold;
    }

    item def AlarmSignal {
        attribute active : BooleanSignal;
        attribute violationType : ViolationType;
        attribute measuredVoltage : VoltageValue;
    }

    item def ControlCommand {
        attribute monitoringCmd : MonitoringCommand;
        attribute newThreshold : ThresholdConfig;
        attribute clearAlarm : BooleanSignal;
    }

    // ===== Port Definitions =====
    port def ElectricalLinePort {
        out attribute lineVoltage : VoltageValue;
        out attribute lineFrequency : FrequencyValue;
    }

    port def VoltageReadingPort {
        out voltageReading : VoltageReading;
    }

    port def ThresholdConfigPort {
        in thresholdConfig : ThresholdConfig;
    }

    port def ViolationPort {
        out violationDetected : BooleanSignal;
        out violationType : ViolationType;
        out measuredVoltage : VoltageValue;
    }

    port def AlarmOutputPort {
        out alarmSignal : AlarmSignal;
    }

    port def ControlInterfacePort {
        in controlCommand : ControlCommand;
    }

    // ===== Requirements =====
    requirement def VoltageMonitoringRequirement {
        subject voltageDetector : VoltageDetectorSystem;
        objective {
            doc /* The system shall continuously monitor the incoming voltage and trigger an alarm when the voltage is outside the safe range. */
        }
        assume {
            doc /* The electrical line provides a voltage between 0 V and 1000 V. */
        }
    }

    requirement def SafeRangeRequirement {
        subject voltageDetector : VoltageDetectorSystem;
        attribute safeUpperLimit : VoltageThreshold = 240.0;
        attribute safeLowerLimit : VoltageThreshold = 200.0;
        objective {
            doc /* The system shall detect when measured voltage exceeds the upper limit or drops below the lower limit. */
        }
        require {
            doc /* The upper limit shall be greater than the lower limit. */
        }
    }

    requirement def AlarmActivationRequirement {
        subject voltageDetector : VoltageDetectorSystem;
        objective {
            doc /* The system shall activate an external alarm within 100 ms of detecting a voltage violation. */
        }
        attribute maxAlarmLatency : TimeValue = 0.1;
    }

    requirement def StateTransitionRequirement {
        subject voltageDetector : VoltageDetectorSystem;
        objective {
            doc /* The system shall transition through initialization, standby, active monitoring, and alarm states as defined. */
        }
    }

    // ===== Parts =====

    part def VoltageSensor {
        port electricalInput : ElectricalLinePort;
        port readingOutput : VoltageReadingPort;

        attribute samplingRate : FrequencyValue = 1000.0;
        attribute measurementAccuracy : VoltageValue = 0.5;
        attribute calibrationOffset : VoltageValue = 0.0;

        attribute currentVoltage : VoltageValue = 0.0;

        action measureVoltage {
            in lineVoltage : VoltageValue;
            out reading : VoltageReading;
        }

        perform action sensorBehavior {
            in lineVoltage : VoltageValue = electricalInput.lineVoltage;
            out reading : VoltageReading;

            action acquire {
                in rawVoltage : VoltageValue;
                out calibratedVoltage : VoltageValue;
            }
            then action format {
                in voltage : VoltageValue;
                out reading : VoltageReading;
            }
        }
    }

    part def ThresholdComparator {
        port readingInput : VoltageReadingPort;
        port configInput : ThresholdConfigPort;
        port violationOutput : ViolationPort;

        attribute upperThreshold : VoltageThreshold = 240.0;
        attribute lowerThreshold : VoltageThreshold = 200.0;
        attribute hysteresisBand : VoltageValue = 2.0;
        attribute currentViolation : ViolationType = ViolationType::none;

        action compareVoltage {
            in reading : VoltageReading;
            in upperLimit : VoltageThreshold;
            in lowerLimit : VoltageThreshold;
            out violationDetected : BooleanSignal;
            out violationType : ViolationType;
        }

        perform action comparatorBehavior {
            in reading : VoltageReading = readingInput.voltageReading;
            in config : ThresholdConfig = configInput.thresholdConfig;
            out violationDetected : BooleanSignal;
            out violationType : ViolationType;
            out measuredVoltage : VoltageValue;

            action updateThresholds {
                in config : ThresholdConfig;
                out upper : VoltageThreshold;
                out lower : VoltageThreshold;
            }
            then action evaluate {
                in reading : VoltageReading;
                in upper : VoltageThreshold;
                in lower : VoltageThreshold;
                out violationDetected : BooleanSignal;
                out violationType : ViolationType;
            }
        }
    }

    part def AlarmController {
        port violationInput : ViolationPort;
        port alarmOutput : AlarmOutputPort;

        attribute alarmActive : BooleanSignal = false;
        attribute currentViolationType : ViolationType = ViolationType::none;
        attribute alarmLatch : BooleanSignal = true;
        attribute lastMeasuredVoltage : VoltageValue = 0.0;

        action activateAlarm {
            in violationDetected : BooleanSignal;
            in violationType : ViolationType;
            in measuredVoltage : VoltageValue;
            out alarmSignal : AlarmSignal;
        }

        perform action alarmBehavior {
            in violationDetected : BooleanSignal = violationInput.violationDetected;
            in violationType : ViolationType = violationInput.violationType;
            in measuredVoltage : VoltageValue = violationInput.measuredVoltage;
            out alarmSignal : AlarmSignal;

            action latchViolation {
                in violationDetected : BooleanSignal;
                in violationType : ViolationType;
                in measuredVoltage : VoltageValue;
                out latched : BooleanSignal;
                out type : ViolationType;
                out voltage : VoltageValue;
            }
            then action generateSignal {
                in latched : BooleanSignal;
                in type : ViolationType;
                in voltage : VoltageValue;
                out alarmSignal : AlarmSignal;
            }
        }
    }

    part def ControlInterface {
        port controlPort : ControlInterfacePort;
        port configOutput : ThresholdConfigPort;

        attribute configuredUpperLimit : VoltageThreshold = 240.0;
        attribute configuredLowerLimit : VoltageThreshold = 200.0;
        attribute monitoringEnabled : BooleanSignal = false;

        action processCommand {
            in command : ControlCommand;
            out config : ThresholdConfig;
            out enableMonitoring : BooleanSignal;
        }

        perform action interfaceBehavior {
            in command : ControlCommand = controlPort.controlCommand;
            out config : ThresholdConfig;
            out enableMonitoring : BooleanSignal;

            action parseCommand {
                in command : ControlCommand;
                out newThreshold : ThresholdConfig;
                out enable : BooleanSignal;
                out clear : BooleanSignal;
            }
            then action applyConfig {
                in newThreshold : ThresholdConfig;
                out config : ThresholdConfig;
            }
        }
    }

    // ===== Main System =====
    part def VoltageDetectorSystem {
        // Requirements satisfaction
        satisfy VoltageMonitoringRequirement;
        satisfy SafeRangeRequirement;
        satisfy AlarmActivationRequirement;
        satisfy StateTransitionRequirement;

        // Ports
        port lineInput : ElectricalLinePort;
        port userControl : ControlInterfacePort;
        port alarmOutput : AlarmOutputPort;

        // Subcomponents
        part sensor : VoltageSensor {
            :>> electricalInput = lineInput;
        }
        part comparator : ThresholdComparator {
            attribute :>> upperThreshold = 240.0;
            attribute :>> lowerThreshold = 200.0;
        }
        part alarmController : AlarmController {
            :>> alarmOutput = alarmOutput;
        }
        part controlInterface : ControlInterface {
            :>> controlPort = userControl;
        }

        // Internal connections
        connection sensorToComparator connect sensor.readingOutput to comparator.readingInput;
        connection comparatorToAlarm connect comparator.violationOutput to alarmController.violationInput;
        connection controlToComparator connect controlInterface.configOutput to comparator.configInput;

        // System state machine
        attribute currentState : SystemState = SystemState::initialization;
        attribute initializationComplete : BooleanSignal = false;
        attribute monitoringEnabled : BooleanSignal = false;
        attribute faultDetected : BooleanSignal = false;
        attribute alarmCleared : BooleanSignal = false;

        state def VoltageDetectorStateMachine {
            entry action {
                doc /* Initialize system state. */
            }

            state initialization {
                entry action {
                    doc /* Perform self-test and load default thresholds. */
                }
                do action {
                    doc /* Calibrate sensor and verify comparator. */
                }
                exit action {
                    doc /* Mark initialization complete. */
                }
            }

            state standby {
                entry action {
                    doc /* System ready, waiting for enable command. */
                }
                do action {
                    doc /* Listen for control commands. */
                }
            }

            state activeMonitoring {
                entry action {
                    doc /* Begin continuous voltage monitoring. */
                }
                do action {
                    doc /* Sample voltage, compare against thresholds. */
                }
            }

            state alarm {
                entry action {
                    doc /* Activate alarm and latch violation type. */
                }
                do action {
                    doc /* Maintain alarm until cleared and voltage returns to safe range. */
                }
                exit action {
                    doc /* Deactivate alarm and reset latch. */
                }
            }

            transition initialization_to_standby
                from initialization
                to standby
                when initializationComplete == true;

            transition standby_to_active
                from standby
                to activeMonitoring
                when monitoringEnabled == true;

            transition active_to_alarm
                from activeMonitoring
                to alarm
                when faultDetected == true;

            transition alarm_to_active
                from alarm
                to activeMonitoring
                when alarmCleared == true && faultDetected == false;

            transition active_to_standby
                from activeMonitoring
                to standby
                when monitoringEnabled == false;
        }

        perform state systemStateMachine : VoltageDetectorStateMachine;

        // Allocation of behaviors to parts
        allocation sensorAllocation {
            subject sensor.measureVoltage;
        }
        allocation comparatorAllocation {
            subject comparator.compareVoltage;
        }
        allocation alarmAllocation {
            subject alarmController.activateAlarm;
        }
    }

    // ===== Top-level package usage =====
    part voltageDetectorSystem : VoltageDetectorSystem {
        :>> lineInput {
            :>> lineVoltage = 230.0;
            :>> lineFrequency = 50.0;
        }
    }
}
