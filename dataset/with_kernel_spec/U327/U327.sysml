package 'NPWT System' {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def StartTherapySignal;
    attribute def StopTherapySignal;
    attribute def InitCompleteSignal;
    attribute def AlarmResolvedSignal;
    attribute def CanisterFullSignal;
    attribute def LeakDetectedSignal;

    item def Exudate;
    item def Air;

    action def PerformInitialization;
    action def ReleaseVacuum;

    action def RegulatePressure {
        in currentPressure : PressureValue;
        in targetPressure : PressureValue;
        out pumpCommand : Boolean;
    }

    action def MonitorCanister {
        in level : VolumeValue;
        in threshold : VolumeValue;
        out alarmSignal : Boolean;
    }

    action def DetectLeak {
        in currentPressure : PressureValue;
        in targetPressure : PressureValue;
        out leakDetected : Boolean;
    }

    part def WoundDressing {
        port exudatePort {
            out exudate : Exudate;
        }
        port airPort {
            out air : Air;
        }
        port pressurePort {
            out pressure : PressureValue;
        }
    }

    part def Tubing {
        port exudateInPort {
            in exudate : Exudate;
        }
        port exudateOutPort {
            out exudate : Exudate;
        }
        port airInPort {
            in air : Air;
        }
        port airOutPort {
            out air : Air;
        }
    }

    part def ExudateCanister {
        attribute capacity : VolumeValue = 500 [L];
        attribute currentLevel : VolumeValue = 0 [L];
        attribute fullThreshold : VolumeValue = 450 [L];

        port exudateInPort {
            in exudate : Exudate;
        }
        port airInPort {
            in air : Air;
        }
        port airOutPort {
            out air : Air;
        }
        port levelPort {
            out level : VolumeValue;
        }
    }

    part def VacuumPump {
        port airInPort {
            in air : Air;
        }
        port airOutPort {
            out air : Air;
        }
        port controlPort {
            in command : Boolean;
        }
        action startPump;
        action stopPump;
    }

    part def PressureSensor {
        port pressureInPort {
            in pressure : PressureValue;
        }
        port pressureOutPort {
            out pressure : PressureValue;
        }
        action sensePressure {
            out reading : PressureValue;
        }
    }

    part def AlarmUnit {
        port alarmInPort {
            in signal : Boolean;
        }
        action soundAlarm;
        action silenceAlarm;
    }

    part def ControlModule {
        attribute targetPressure : PressureValue = -16665 [Pa];
        attribute fullThreshold : VolumeValue = 450 [L];

        port pressureInPort {
            in pressure : PressureValue;
        }
        port levelInPort {
            in level : VolumeValue;
        }
        port pumpControlOutPort {
            out command : Boolean;
        }
        port alarmOutPort {
            out signal : Boolean;
        }

        state def ControlStates;
        state controlStates : ControlStates {
            entry; then off;

            state off;
            accept StartTherapySignal
                then initialization;

            state initialization {
                entry action performInit : PerformInitialization;
            }
            accept InitCompleteSignal
                then activeTherapy;

            state activeTherapy {
                do action regulate : RegulatePressure {
                    in currentPressure = pressureInPort.pressure;
                    in targetPressure = targetPressure;
                    out pumpCommand = pumpControlOutPort.command;
                }
                do action monitor : MonitorCanister {
                    in level = levelInPort.level;
                    in threshold = fullThreshold;
                    out alarmSignal = alarmOutPort.signal;
                }
                do action detectLeak : DetectLeak {
                    in currentPressure = pressureInPort.pressure;
                    in targetPressure = targetPressure;
                    out leakDetected;
                }
            }
            accept CanisterFullSignal
                then paused;
            accept LeakDetectedSignal
                then paused;
            accept StopTherapySignal
                then shutdown;

            state paused;
            accept AlarmResolvedSignal
                then activeTherapy;
            accept StopTherapySignal
                then shutdown;

            state shutdown {
                exit action release : ReleaseVacuum;
            }
        }
    }

    part def NPWTDevice {
        part dressing : WoundDressing;
        part tubing : Tubing;
        part canister : ExudateCanister;
        part pump : VacuumPump;
        part sensor : PressureSensor;
        part controller : ControlModule;
        part alarm : AlarmUnit;

        flow exudateFlow1 of Exudate
            from dressing.exudatePort.exudate to tubing.exudateInPort.exudate;
        flow exudateFlow2 of Exudate
            from tubing.exudateOutPort.exudate to canister.exudateInPort.exudate;

        flow airFlow1 of Air
            from dressing.airPort.air to tubing.airInPort.air;
        flow airFlow2 of Air
            from tubing.airOutPort.air to canister.airInPort.air;
        flow airFlow3 of Air
            from canister.airOutPort.air to pump.airInPort.air;

        flow pressureSenseFlow of PressureValue
            from dressing.pressurePort.pressure to sensor.pressureInPort.pressure;
        flow pressureReadingFlow of PressureValue
            from sensor.pressureOutPort.pressure to controller.pressureInPort.pressure;

        flow levelMonitorFlow of VolumeValue
            from canister.levelPort.level to controller.levelInPort.level;

        flow pumpCommandFlow of Boolean
            from controller.pumpControlOutPort.command to pump.controlPort.command;
        flow alarmCommandFlow of Boolean
            from controller.alarmOutPort.signal to alarm.alarmInPort.signal;
    }

    requirement def TargetPressureMaintenance {
        doc /* The system shall maintain the wound site pressure within ±500 Pa of the prescribed target pressure during active therapy. */
    }

    requirement def CanisterFullAlarm {
        doc /* The system shall trigger an audible alarm when the canister fluid level reaches 90% of its maximum capacity. */
    }

    requirement def LeakDetectionAlarm {
        doc /* The system shall detect air leaks that prevent maintaining target pressure and activate an audible alarm. */
    }

    requirement def ContinuousOperation {
        doc /* The system shall support continuous, uninterrupted operation for a minimum of 7 days under normal clinical conditions. */
    }

    requirement def SafePressureRange {
        doc /* The system target pressure shall be set between -26000 Pa and -5000 Pa as prescribed by a clinician. */
    }
}
