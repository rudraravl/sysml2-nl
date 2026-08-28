package 'Bedwetting Alarm System' {
    private import ScalarValues::*;
    private import ISQ::*;

    requirement def 'Bedwetting Alarm Requirements' {
        requirement 'Moisture Detection' {
            doc /* The system shall detect moisture beyond a sensitivity threshold and signal the control unit. */
        }
        requirement 'Dual Alarm Activation' {
            doc /* Upon receiving a signal from the sensor, the control unit shall immediately activate both an audible alarm and a tactile vibration alert. */
        }
        requirement 'Persistent Alarms' {
            doc /* The alarms shall persist until manually turned off via a reset button. */
        }
        requirement 'Adjustable Sensitivity' {
            doc /* The user shall be able to adjust moisture sensitivity to prevent false alarms from sweat while ensuring quick detection. */
        }
        requirement 'Portable Battery Power' {
            doc /* The system shall be portable, self-contained, and powered by an internal battery pack for extended nighttime use. */
        }
    }

    requirement bedwettingAlarmReq : 'Bedwetting Alarm Requirements';

    attribute def MoistureLevel :> ScalarValues::Real;
    attribute def SensitivityThreshold :> ScalarValues::Real;
    attribute def BatteryLevel :> ScalarValues::Real;

    item def MoistureAlert;
    item def AlarmStart;
    item def AlarmStop;
    item def PowerOnCommand;
    item def PowerOffCommand;
    item def ResetCommand;
    item def SensitivityUpdate {
        attribute threshold : SensitivityThreshold;
    }
    item def Power;
    item def PowerOnButtonPress;
    item def PowerOffButtonPress;
    item def ResetButtonPress;
    item def SensitivityButtonPress;

    port def MoistureOutPort { out alert : MoistureAlert; }
    port def MoistureInPort { in alert : MoistureAlert; }
    port def AlarmCmdPort { out start : AlarmStart; out stop : AlarmStop; }
    port def AlarmRcvPort { in start : AlarmStart; in stop : AlarmStop; }
    port def CmdOutPort {
        out powerOn : PowerOnCommand;
        out powerOff : PowerOffCommand;
        out reset : ResetCommand;
        out sensitivity : SensitivityUpdate;
    }
    port def CmdInPort {
        in powerOn : PowerOnCommand;
        in powerOff : PowerOffCommand;
        in reset : ResetCommand;
        in sensitivity : SensitivityUpdate;
    }
    port def ThresholdOutPort { out update : SensitivityUpdate; }
    port def ThresholdInPort { in update : SensitivityUpdate; }
    port def PwrOutPort { out power : Power; }
    port def PwrInPort { in power : Power; }

    action def SenseMoisture { out reading : MoistureLevel; }
    action def EmitSound;
    action def EmitVibration;

    part def MoistureSensorPad {
        port moistureOut : MoistureOutPort;
        port thresholdIn : ThresholdInPort;
        port powerIn : PwrInPort;
        attribute currentThreshold : SensitivityThreshold = 50.0;
        perform action sense : SenseMoisture;
        exhibit state sensorStates {
            entry; then active;
            state active {
                do sense;
            }
            accept when sense.reading > currentThreshold
                do send new MoistureAlert() to moistureOut
                then active;
            accept SensitivityUpdate via thresholdIn
                then active;
        }
    }

    part def Speaker {
        port alarmIn : AlarmRcvPort;
        port powerIn : PwrInPort;
        perform action emitSound : EmitSound;
        exhibit state speakerStates {
            entry; then silent;
            state silent;
            accept AlarmStart via alarmIn
                then sounding;
            state sounding {
                do emitSound;
            }
            accept AlarmStop via alarmIn
                then silent;
        }
    }

    part def VibrationMotor {
        port alarmIn : AlarmRcvPort;
        port powerIn : PwrInPort;
        perform action emitVibration : EmitVibration;
        exhibit state motorStates {
            entry; then idle;
            state idle;
            accept AlarmStart via alarmIn
                then vibrating;
            state vibrating {
                do emitVibration;
            }
            accept AlarmStop via alarmIn
                then idle;
        }
    }

    part def UserInterface {
        port commandOut : CmdOutPort;
        port powerIn : PwrInPort;
        attribute currentSensitivity : SensitivityThreshold = 50.0;
        exhibit state uiStates {
            entry; then idle;
            state idle;
            accept PowerOnButtonPress
                do send new PowerOnCommand() to commandOut
                then idle;
            accept PowerOffButtonPress
                do send new PowerOffCommand() to commandOut
                then idle;
            accept ResetButtonPress
                do send new ResetCommand() to commandOut
                then idle;
            accept SensitivityButtonPress
                do send new SensitivityUpdate(threshold = currentSensitivity) to commandOut
                then idle;
        }
    }

    part def BatteryPack {
        port powerOut : PwrOutPort;
        attribute level : BatteryLevel = 100.0;
    }

    part def ControlUnit {
        port moistureIn : MoistureInPort;
        port alarmOut : AlarmCmdPort;
        port commandIn : CmdInPort;
        port thresholdOut : ThresholdOutPort;
        port powerIn : PwrInPort;
        exhibit state systemStates {
            entry; then off;
            state off;
            accept PowerOnCommand via commandIn
                then monitoring;
            state monitoring;
            accept MoistureAlert via moistureIn
                do send new AlarmStart() to alarmOut
                then alarming;
            accept s : SensitivityUpdate via commandIn
                do send s to thresholdOut
                then monitoring;
            accept PowerOffCommand via commandIn
                then off;
            state alarming;
            accept ResetCommand via commandIn
                do send new AlarmStop() to alarmOut
                then monitoring;
            accept PowerOffCommand via commandIn
                do send new AlarmStop() to alarmOut
                then off;
        }
    }

    part def BedwettingAlarmSystem {
        satisfy bedwettingAlarmReq;

        part sensorPad : MoistureSensorPad;
        part controlUnit : ControlUnit;
        part speaker : Speaker;
        part vibrator : VibrationMotor;
        part ui : UserInterface;
        part battery : BatteryPack;

        connect battery.powerOut to sensorPad.powerIn;
        connect battery.powerOut to controlUnit.powerIn;
        connect battery.powerOut to speaker.powerIn;
        connect battery.powerOut to vibrator.powerIn;
        connect battery.powerOut to ui.powerIn;
        connect sensorPad.moistureOut to controlUnit.moistureIn;
        connect controlUnit.alarmOut to speaker.alarmIn;
        connect controlUnit.alarmOut to vibrator.alarmIn;
        connect ui.commandOut to controlUnit.commandIn;
        connect controlUnit.thresholdOut to sensorPad.thresholdIn;
    }

    part bedwettingAlarmSystem : BedwettingAlarmSystem;
}
