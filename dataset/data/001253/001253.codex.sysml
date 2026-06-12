package SmokeDetectorSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def SmokeConcentration :> Real {
        unit = "ppm";
    }

    attribute def TemperatureCelsius :> Real {
        unit = "degC";
    }

    attribute def BatteryVoltage :> Real {
        unit = "V";
    }

    attribute def SoundPressureLevel :> Real {
        unit = "dB";
    }

    attribute def TimeSeconds :> Real {
        unit = "s";
    }

    attribute def PercentCharge :> Real {
        unit = "%";
    }

    item def AirSample {
        attribute smokeLevel : SmokeConcentration;
        attribute temperature : TemperatureCelsius;
        attribute dustInterference : SmokeConcentration;
    }

    item def ElectricalPower {
        attribute voltage : BatteryVoltage;
        attribute availableCharge : PercentCharge;
    }

    item def AlarmSound {
        attribute loudness : SoundPressureLevel;
        attribute pulsePeriod : TimeSeconds;
    }

    item def StatusSignal {
        attribute alarmActive : Boolean;
        attribute faultActive : Boolean;
        attribute lowBattery : Boolean;
        attribute testMode : Boolean;
    }

    port def AirInletPort {
        in item sampledAir : AirSample;
    }

    port def PowerPort {
        in item suppliedPower : ElectricalPower;
    }

    port def AlarmOutputPort {
        out item sound : AlarmSound;
    }

    port def StatusPort {
        out item status : StatusSignal;
    }

    port def ControlPort {
        in item testCommand : Boolean;
        in item silenceCommand : Boolean;
    }

    action def SenseSmoke {
        in item air : AirSample;
        out attribute measuredSmoke : SmokeConcentration;
        out attribute measuredTemperature : TemperatureCelsius;
    }

    action def EvaluateHazard {
        in attribute measuredSmoke : SmokeConcentration;
        in attribute measuredTemperature : TemperatureCelsius;
        in attribute alarmThreshold : SmokeConcentration;
        out attribute smokeHazardDetected : Boolean;
    }

    action def SoundAlarm {
        in attribute hazardDetected : Boolean;
        out item alarmTone : AlarmSound;
    }

    action def ReportStatus {
        in attribute alarmActive : Boolean;
        in attribute faultActive : Boolean;
        in attribute lowBattery : Boolean;
        out item systemStatus : StatusSignal;
    }

    part def SmokeSensor {
        port airIn : AirInletPort;
        attribute measuredSmoke : SmokeConcentration;
        attribute measuredTemperature : TemperatureCelsius;
        attribute sensitivityDrift : SmokeConcentration = 0.0;
        attribute sensorFault : Boolean = false;

        perform action sense : SenseSmoke {
            in item air = airIn.sampledAir;
            out attribute measuredSmoke = measuredSmoke;
            out attribute measuredTemperature = measuredTemperature;
        }
    }

    part def BatteryPack {
        port powerOut : PowerPort;
        attribute nominalVoltage : BatteryVoltage = 9.0;
        attribute currentVoltage : BatteryVoltage = 9.0;
        attribute remainingCharge : PercentCharge = 100.0;
        attribute lowBatteryThreshold : BatteryVoltage = 7.2;

        item power : ElectricalPower {
            attribute voltage = currentVoltage;
            attribute availableCharge = remainingCharge;
        }
    }

    part def AlarmHorn {
        port alarmOut : AlarmOutputPort;
        attribute targetLoudness : SoundPressureLevel = 85.0;
        attribute pulsePeriod : TimeSeconds = 0.5;
        attribute active : Boolean = false;

        perform action sound : SoundAlarm {
            in attribute hazardDetected = active;
            out item alarmTone = alarmOut.sound;
        }
    }

    part def IndicatorLight {
        attribute greenReadyLight : Boolean = true;
        attribute redAlarmLight : Boolean = false;
        attribute yellowFaultLight : Boolean = false;
    }

    part def TestSilenceButton {
        port controls : ControlPort;
        attribute pressedForTest : Boolean = false;
        attribute pressedForSilence : Boolean = false;
    }

    part def ControlElectronics {
        port sensorInput : AirInletPort;
        port powerInput : PowerPort;
        port statusOut : StatusPort;
        port controls : ControlPort;

        attribute alarmThreshold : SmokeConcentration = 70.0;
        attribute alarmResetThreshold : SmokeConcentration = 45.0;
        attribute overTemperatureThreshold : TemperatureCelsius = 57.0;
        attribute silenceDuration : TimeSeconds = 480.0;
        attribute faultActive : Boolean = false;
        attribute alarmActive : Boolean = false;
        attribute lowBattery : Boolean = false;
        attribute testMode : Boolean = false;

        part sensor : SmokeSensor;
        part batteryMonitor : BatteryPack;
        part horn : AlarmHorn;
        part lights : IndicatorLight;

        connect sensorInput.sampledAir to sensor.airIn.sampledAir;
        connect powerInput.suppliedPower to batteryMonitor.powerOut.suppliedPower;

        perform action evaluate : EvaluateHazard {
            in attribute measuredSmoke = sensor.measuredSmoke;
            in attribute measuredTemperature = sensor.measuredTemperature;
            in attribute alarmThreshold = alarmThreshold;
            out attribute smokeHazardDetected = alarmActive;
        }

        perform action report : ReportStatus {
            in attribute alarmActive = alarmActive;
            in attribute faultActive = faultActive;
            in attribute lowBattery = lowBattery;
            out item systemStatus = statusOut.status;
        }

        state def DetectorOperatingState {
            entry action Initialize {
                lights.greenReadyLight := true;
                lights.redAlarmLight := false;
                lights.yellowFaultLight := false;
                horn.active := false;
            }

            state NormalMonitoring {
                entry action NormalEntry {
                    alarmActive := false;
                    horn.active := false;
                    lights.greenReadyLight := true;
                    lights.redAlarmLight := false;
                }
            }

            state SmokeAlarm {
                entry action AlarmEntry {
                    alarmActive := true;
                    horn.active := true;
                    lights.redAlarmLight := true;
                    lights.greenReadyLight := false;
                }
            }

            state SilencedAlarm {
                entry action SilenceEntry {
                    horn.active := false;
                    lights.redAlarmLight := true;
                }
            }

            state LowBatteryWarning {
                entry action LowBatteryEntry {
                    lowBattery := true;
                    lights.yellowFaultLight := true;
                }
            }

            state Fault {
                entry action FaultEntry {
                    faultActive := true;
                    horn.active := false;
                    lights.yellowFaultLight := true;
                    lights.greenReadyLight := false;
                }
            }

            transition NormalToAlarm
                first NormalMonitoring
                then SmokeAlarm
                if sensor.measuredSmoke >= alarmThreshold or sensor.measuredTemperature >= overTemperatureThreshold;

            transition AlarmToSilenced
                first SmokeAlarm
                then SilencedAlarm
                if controls.silenceCommand == true and sensor.measuredSmoke < alarmThreshold;

            transition SilencedToAlarm
                first SilencedAlarm
                then SmokeAlarm
                if sensor.measuredSmoke >= alarmThreshold;

            transition AlarmToNormal
                first SmokeAlarm
                then NormalMonitoring
                if sensor.measuredSmoke <= alarmResetThreshold and sensor.measuredTemperature < overTemperatureThreshold;

            transition NormalToLowBattery
                first NormalMonitoring
                then LowBatteryWarning
                if powerInput.suppliedPower.voltage <= batteryMonitor.lowBatteryThreshold;

            transition AnyToFault
                first NormalMonitoring
                then Fault
                if sensor.sensorFault == true or powerInput.suppliedPower.voltage <= 5.5;

            transition TestToAlarm
                first NormalMonitoring
                then SmokeAlarm
                if controls.testCommand == true;
        }
    }

    part def SmokeDetector {
        port ambientAir : AirInletPort;
        port batteryPower : PowerPort;
        port audibleAlarm : AlarmOutputPort;
        port status : StatusPort;
        port userControls : ControlPort;

        attribute installedCeilingHeight : LengthValue = 2.7 [m];
        attribute requiredAlarmLoudness : SoundPressureLevel = 85.0;
        attribute primaryFunction : String = "Continuously monitor ambient air for smoke particles and alert occupants with an audible alarm when a likely fire condition is detected.";

        part battery : BatteryPack;
        part controller : ControlElectronics;
        part button : TestSilenceButton;
        part horn : AlarmHorn;

        connect ambientAir.sampledAir to controller.sensorInput.sampledAir;
        connect battery.powerOut.suppliedPower to controller.powerInput.suppliedPower;
        connect userControls.testCommand to controller.controls.testCommand;
        connect userControls.silenceCommand to controller.controls.silenceCommand;
        connect controller.statusOut.status to status.status;
        connect horn.alarmOut.sound to audibleAlarm.sound;

        constraint alarmSoundLevel {
            horn.targetLoudness >= requiredAlarmLoudness;
        }

        constraint lowBatteryLimit {
            battery.currentVoltage >= 0.0;
        }
    }

    requirement def DetectSmokeRequirement {
        doc /* The smoke detector shall detect smoke concentration at or above 70 ppm in ambient air and enter the alarm state. */
        subject detector : SmokeDetector;
        require constraint {
            detector.controller.sensor.measuredSmoke >= detector.controller.alarmThreshold implies detector.controller.alarmActive == true;
        }
    }

    requirement def AudibleAlarmRequirement {
        doc /* When an alarm condition is active, the smoke detector shall emit an audible alarm of at least 85 dB. */
        subject detector : SmokeDetector;
        require constraint {
            detector.controller.alarmActive == true implies detector.horn.targetLoudness >= 85.0;
        }
    }

    requirement def LowBatteryRequirement {
        doc /* The smoke detector shall report a low-battery condition when supplied battery voltage is at or below 7.2 V. */
        subject detector : SmokeDetector;
        require constraint {
            detector.battery.currentVoltage <= detector.battery.lowBatteryThreshold implies detector.controller.lowBattery == true;
        }
    }

    requirement def TestFunctionRequirement {
        doc /* The smoke detector shall support a user test command that activates the alarm path without requiring smoke. */
        subject detector : SmokeDetector;
        require constraint {
            detector.userControls.testCommand == true implies detector.controller.alarmActive == true;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The primary function of the system is to monitor air for smoke and warn occupants at a high level through audible and status outputs. */
        subject detector : SmokeDetector;
    }

    part smokeDetectorSystem : SmokeDetector {
        part surroundingAir {
            item normalAir : AirSample {
                attribute smokeLevel = 0.0;
                attribute temperature = 22.0;
                attribute dustInterference = 3.0;
            }

            item smokyAir : AirSample {
                attribute smokeLevel = 120.0;
                attribute temperature = 35.0;
                attribute dustInterference = 5.0;
            }
        }

        item standbyPower : ElectricalPower {
            attribute voltage = 9.0;
            attribute availableCharge = 100.0;
        }

        item alarmStatus : StatusSignal;
        item evacuationTone : AlarmSound;
    }

    satisfy DetectSmokeRequirement by smokeDetectorSystem;
    satisfy AudibleAlarmRequirement by smokeDetectorSystem;
    satisfy LowBatteryRequirement by smokeDetectorSystem;
    satisfy TestFunctionRequirement by smokeDetectorSystem;
    satisfy PrimaryFunctionRequirement by smokeDetectorSystem;
}