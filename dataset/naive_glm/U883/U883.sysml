package SmokeDetectorModel {
    import ScalarValues::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQTime::*;

    // ---------- Value Types ----------
    value type SmokeConcentrationValue :> Real {
        :> unit = ug_per_m3;
    }
    value type SoundPressureLevelValue :> Real {
        :> unit = dB;
    }
    value type BatteryChargeValue :> Real {
        :> unit = percent;
    }
    value type VoltageValue :> Real {
        :> unit = V;
    }
    value type FlowRateValue :> Real {
        :> unit = mL_per_s;
    }

    item def SmokeSample {
        attribute concentration : SmokeConcentrationValue;
    }

    item def AirSample {
        attribute smoke : SmokeConcentrationValue;
    }

    item def AlarmSignal {
        attribute active : Boolean;
    }

    item def LightSignal {
        attribute active : Boolean;
        attribute color : String = "red";
    }

    item def BatteryStatus {
        attribute charge : BatteryChargeValue;
        attribute voltage : VoltageValue;
    }

    item def TestCommand {
        attribute requested : Boolean;
    }

    item def ResetCommand {
        attribute requested : Boolean;
    }

    // ---------- Interfaces / Ports ----------
    port def AirIntakePort {
        out item air : AirSample;
    }

    port def AlarmDrivePort {
        out item alarm : AlarmSignal;
    }

    port def LightDrivePort {
        out item light : LightSignal;
    }

    port def BatteryMonitorPort {
        out item status : BatteryStatus;
    }

    port def UserCommandPort {
        in item test : TestCommand;
        in item reset : ResetCommand;
    }

    port def SensorReadPort {
        out item sample : SmokeSample;
    }

    // ---------- Thresholds ----------
    attribute def SmokeThreshold {
        attribute alarmThreshold : SmokeConcentrationValue = 0.1 [ug_per_m3];
        attribute lowBatteryThreshold : BatteryChargeValue = 20 [percent];
    }

    // ---------- Parts ----------
    part def AirSamplingChamber {
        port intake : AirIntakePort;
        attribute flowRate : FlowRateValue = 5.0 [mL_per_s];
        action def SampleAir() {
            in air : AirSample;
            out sample : SmokeSample;
        }
        perform action sampleAir : SampleAir;
    }

    part def OpticalSmokeSensor {
        port airIn : AirIntakePort;
        port readOut : SensorReadPort;
        attribute sensitivity : SmokeConcentrationValue = 0.01 [ug_per_m3];
        action def MeasureSmoke() {
            in air : AirSample;
            out sample : SmokeSample;
        }
        perform action measure : MeasureSmoke;
        flow airIn.air to measure.air;
        flow measure.sample to readOut.sample;
    }

    part def AudibleAlarm {
        port drive : AlarmDrivePort;
        attribute minSoundLevel : SoundPressureLevelValue = 85.0 [dB];
        attribute currentLevel : SoundPressureLevelValue;
        action def SoundAlarm() {
            in alarm : AlarmSignal;
        }
        perform action sound : SoundAlarm;
        flow drive.alarm to sound.alarm;
    }

    part def VisualIndicator {
        port drive : LightDrivePort;
        attribute flashRate : Real = 1.0; // Hz
        action def FlashLight() {
            in light : LightSignal;
        }
        perform action flash : FlashLight;
        flow drive.light to flash.light;
    }

    part def BatteryPack {
        port monitor : BatteryMonitorPort;
        attribute nominalVoltage : VoltageValue = 9.0 [V];
        attribute capacity : BatteryChargeValue = 100.0 [percent];
        attribute currentCharge : BatteryChargeValue = 100.0 [percent];
        action def Discharge() {
            out status : BatteryStatus;
        }
        perform action discharge : Discharge;
        flow discharge.status to monitor.status;
    }

    part def ControlInterface {
        port userCmd : UserCommandPort;
        action def AcceptUserInput() {
            out test : TestCommand;
            out reset : ResetCommand;
        }
        perform action acceptInput : AcceptUserInput;
        flow acceptInput.test to userCmd.test;
        flow acceptInput.reset to userCmd.reset;
    }

    part def ControlUnit {
        port sensorInput : SensorReadPort;
        port batteryInput : BatteryMonitorPort;
        port userPort : UserCommandPort;
        port alarmOutput : AlarmDrivePort;
        port lightOutput : LightDrivePort;

        attribute thresholds : SmokeThreshold;
        attribute currentSmoke : SmokeConcentrationValue;
        attribute currentBattery : BatteryChargeValue;

        state def ControlStateMachine {
            entry; then standby;

            state standby {
                entry action {
                    currentSmoke = sensorInput.sample.concentration;
                    currentBattery = batteryInput.status.charge;
                }
                do action MonitorAir {
                    in sample : SmokeSample = sensorInput.sample;
                    in status : BatteryStatus = batteryInput.status;
                    out smokeLevel : SmokeConcentrationValue = currentSmoke;
                    out batteryLevel : BatteryChargeValue = currentBattery;
                }
            }

            state alarming {
                entry action {
                    alarmOutput.alarm.active = true;
                    lightOutput.light.active = true;
                }
                do action ActivateAlerts;
                exit action {
                    alarmOutput.alarm.active = false;
                    lightOutput.light.active = false;
                }
            }

            state lowBattery {
                entry action {
                    lightOutput.light.active = true;
                    lightOutput.light.color = "red";
                }
                do action SignalLowBattery;
            }

            state selfTest {
                entry action {
                    alarmOutput.alarm.active = true;
                    lightOutput.light.active = true;
                }
                do action RunDiagnostics;
                exit action {
                    alarmOutput.alarm.active = false;
                    lightOutput.light.active = false;
                }
            }

            transition t_standby_to_alarm
                first standby
                accept when currentSmoke > thresholds.alarmThreshold
                then alarming;

            transition t_alarm_to_standby
                first alarming
                accept when userPort.reset.requested and currentSmoke <= thresholds.alarmThreshold
                then standby;

            transition t_standby_to_lowBattery
                first standby
                accept when currentBattery < thresholds.lowBatteryThreshold
                then lowBattery;

            transition t_lowBattery_to_standby
                first lowBattery
                accept when currentBattery >= thresholds.lowBatteryThreshold
                then standby;

            transition t_standby_to_selfTest
                first standby
                accept when userPort.test.requested
                then selfTest;

            transition t_selfTest_to_standby
                first selfTest
                accept when true
                then standby;

            transition t_lowBattery_to_alarm
                first lowBattery
                accept when currentSmoke > thresholds.alarmThreshold
                then alarming;
        }

        perform state behavior : ControlStateMachine;
    }

    // ---------- Top-level Smoke Detector ----------
    part def SmokeDetector {
        part controlUnit : ControlUnit;
        part sensor : OpticalSmokeSensor;
        part chamber : AirSamplingChamber;
        part siren : AudibleAlarm;
        part indicator : VisualIndicator;
        part battery : BatteryPack;
        part interface : ControlInterface;

        // Air sampling chain
        connection def AirFlowConnection {
            end source : AirIntakePort;
            end target : AirIntakePort;
        }

        connection airToChamber : AirFlowConnection connect chamber.intake to sensor.airIn;
        connection chamberToSensor : AirFlowConnection connect chamber.intake to sensor.airIn;

        // Sensor to control unit
        connection sensorRead : SensorReadPort connect sensor.readOut to controlUnit.sensorInput;

        // Battery to control unit
        connection batteryStatus : BatteryMonitorPort connect battery.monitor to controlUnit.batteryInput;

        // Control unit to alarms
        connection alarmDrive : AlarmDrivePort connect controlUnit.alarmOutput to siren.drive;
        connection lightDrive : LightDrivePort connect controlUnit.lightOutput to indicator.drive;

        // User interface to control unit
        connection userCommands : UserCommandPort connect interface.userCmd to controlUnit.userPort;
    }

    // ---------- Requirements ----------
    requirement def DetectSmokeRequirement {
        subject detector : SmokeDetector;
        objective {
            doc /* The detector shall continuously monitor air for smoke concentration. */
            assert detector.sensor.readOut.sample.concentration >= 0.0 [ug_per_m3];
        }
    }

    requirement def AlarmThresholdRequirement {
        subject detector : SmokeDetector;
        attribute threshold : SmokeConcentrationValue = 0.1 [ug_per_m3];
        objective {
            doc /* The detector shall raise an alarm when smoke concentration exceeds the threshold. */
            assert detector.controlUnit.currentSmoke > threshold implies detector.controlUnit.alarmOutput.alarm.active;
        }
    }

    requirement def AudibleAlarmRequirement {
        subject detector : SmokeDetector;
        attribute minLevel : SoundPressureLevelValue = 85.0 [dB];
        objective {
            doc /* The audible alarm shall emit at least 85 dB when active. */
            assert detector.siren.currentLevel >= minLevel;
        }
    }

    requirement def VisualAlertRequirement {
        subject detector : SmokeDetector;
        objective {
            doc /* A flashing red LED shall indicate alarm and low battery states. */
            assert detector.indicator.drive.light.color == "red";
        }
    }

    requirement def BatteryMonitoringRequirement {
        subject detector : SmokeDetector;
        attribute lowThreshold : BatteryChargeValue = 20.0 [percent];
        objective {
            doc /* The control unit shall monitor battery charge and enter low battery state below threshold. */
            assert detector.battery.monitor.status.charge < lowThreshold implies detector.controlUnit.currentBattery < lowThreshold;
        }
    }

    requirement def SelfTestRequirement {
        subject detector : SmokeDetector;
        objective {
            doc /* The user shall be able to trigger a self-test verifying sensor and alarm operation. */
            assert detector.interface.userCmd.test.requested implies detector.controlUnit.userPort.test.requested;
        }
    }

    requirement def ResetRequirement {
        subject detector : SmokeDetector;
        objective {
            doc /* The user shall be able to reset the alarm after the air is clear. */
            assert detector.interface.userCmd.reset.requested implies detector.controlUnit.userPort.reset.requested;
        }
    }

    requirement def StandbyOperationRequirement {
        subject detector : SmokeDetector;
        objective {
            doc /* During normal operation the detector shall be in standby mode monitoring air. */
            assert detector.controlUnit.controlStateMachine.standby.isActive;
        }
    }

    // ---------- Package-level configuration ----------
    part smokeDetectorInstance : SmokeDetector {
        // Default thresholds applied at instance level
        attribute alarmThreshold : SmokeConcentrationValue = 0.1 [ug_per_m3];
        attribute lowBatteryThreshold : BatteryChargeValue = 20.0 [percent];
    }

    // Satisfy bindings
    satisfy detectSmokeReq : DetectSmokeRequirement by smokeDetectorInstance;
    satisfy alarmThresholdReq : AlarmThresholdRequirement by smokeDetectorInstance;
    satisfy audibleAlarmReq : AudibleAlarmRequirement by smokeDetectorInstance;
    satisfy visualAlertReq : VisualAlertRequirement by smokeDetectorInstance;
    satisfy batteryMonitoringReq : BatteryMonitoringRequirement by smokeDetectorInstance;
    satisfy selfTestReq : SelfTestRequirement by smokeDetectorInstance;
    satisfy resetReq : ResetRequirement by smokeDetectorInstance;
    satisfy standbyOperationReq : StandbyOperationRequirement by smokeDetectorInstance;
}
