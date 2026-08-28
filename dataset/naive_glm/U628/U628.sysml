package CO_Detector_System {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Concentration :> Real { unit 'ppm'; }
    value def Voltage :> Real { unit 'V'; }
    value def Duration :> Real { unit 's'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Percent :> Real { unit '%'; }

    // ===== Item Types =====
    item def Air;
    item def COGas :> Air;
    item def COReading {
        attribute concentration : Concentration;
        attribute timestamp : DateTime;
    }
    item def AlarmCommand {
        attribute level : AlarmLevel;
    }
    item def LowBatteryAlert;
    item def BatteryStatus {
        attribute charge : Percent;
        attribute voltage : Voltage;
    }

    enumeration def AlarmLevel { literal none; literal warning; literal danger; literal critical; }
    enumeration def BatteryState { literal normal; literal low; literal depleted; }

    // ===== Requirements =====
    requirement def DetectCO {
        subject detector : CO_Detector;
        objective {
            doc "The detector shall continuously monitor ambient air for CO concentration."
        }
        require detector.sensor.samplingActive == true;
    }

    requirement def AlarmThresholds {
        subject detector : CO_Detector;
        objective {
            doc "The detector shall trigger alarms based on concentration and exposure duration."
        }
        require {
            constraint { (concentration >= 150 [ppm]) implies (exposureTime >= 0 [s]) }
            constraint { (concentration >= 70 [ppm] and concentration < 150 [ppm]) implies (exposureTime >= 60 [s]) }
            constraint { (concentration >= 30 [ppm] and concentration < 70 [ppm]) implies (exposureTime >= 1800 [s]) }
        }
        attribute concentration : Concentration;
        attribute exposureTime : Duration;
    }

    requirement def LowBatteryWarning {
        subject detector : CO_Detector;
        objective {
            doc "The detector shall emit a distinct low-battery warning when battery charge falls below threshold."
        }
        require detector.battery.charge < 15 [%];
    }

    requirement def PowerSupply {
        subject detector : CO_Detector;
        objective {
            doc "The system shall be powered by a 9V battery."
        }
        require detector.battery.nominalVoltage == 9 [V];
    }

    // ===== Port Definitions =====
    port def AirPort {
        out item air : Air;
    }
    port def COReadingPort {
        out item reading : COReading;
    }
    port def AlarmCommandPort {
        in item command : AlarmCommand;
    }
    port def BatteryStatusPort {
        out item status : BatteryStatus;
    }
    port def LowBatteryPort {
        out item alert : LowBatteryAlert;
    }
    port def PowerPort {
        out attribute voltage : Voltage;
    }

    // ===== Parts =====
    part def ElectrochemicalSensor {
        port airIn : AirPort;
        port readingOut : COReadingPort;
        attribute samplingActive : Boolean = true;
        attribute currentConcentration : Concentration = 0 [ppm];

        action def SampleAir {
            in item ambientAir : Air;
            out item reading : COReading;
        }

        action sample continuously {
            bind ambientAir = airIn.air;
            bind reading.concentration = currentConcentration;
            bind readingOut.reading = reading;
        }
    }

    part def CentralProcessingUnit {
        port readingIn : COReadingPort;
        port alarmOut : AlarmCommandPort;
        port batteryStatusIn : BatteryStatusPort;
        port lowBatteryIn : LowBatteryPort;

        attribute currentConcentration : Concentration = 0 [ppm];
        attribute exposureTime : Duration = 0 [s];
        attribute lastReadingTime : DateTime;
        attribute alarmLevel : AlarmLevel = AlarmLevel::none;
        attribute batteryLow : Boolean = false;

        state def CPUStates {
            entry; then Monitoring;

            state Monitoring;
            state Evaluating;
            state AlarmActive;
            state LowBatteryWarning;

            transition Monitoring -> Evaluating
                when readingIn.reading != null;

            transition Evaluating -> AlarmActive
                when alarmLevel != AlarmLevel::none and alarmLevel != AlarmLevel::warning;

            transition Evaluating -> Monitoring
                when alarmLevel == AlarmLevel::none;

            transition Monitoring -> LowBatteryWarning
                when lowBatteryIn.alert != null;

            transition LowBatteryWarning -> Monitoring
                when lowBatteryIn.alert == null;

            transition AlarmActive -> Monitoring
                when currentConcentration < 30 [ppm];
        }

        action def AnalyzeReading {
            in item reading : COReading;
            out item command : AlarmCommand;
            attribute conc : Concentration;
            attribute expTime : Duration;

            // Immediate alarm for very high concentrations
            if conc >= 150 [ppm] {
                command.level := AlarmLevel::critical;
            } else if conc >= 70 [ppm] and expTime >= 60 [s] {
                command.level := AlarmLevel::danger;
            } else if conc >= 30 [ppm] and expTime >= 1800 [s] {
                command.level := AlarmLevel::warning;
            } else {
                command.level := AlarmLevel::none;
            }
        }

        action def ProcessBatteryStatus {
            in item status : BatteryStatus;
            attribute charge : Percent;
            if charge < 15 [%] {
                batteryLow := true;
            } else {
                batteryLow := false;
            }
        }

        exhibit CPUStates;
    }

    part def AudioVisualAlarm {
        port commandIn : AlarmCommandPort;
        port powerIn : PowerPort;

        attribute buzzerFrequency : Frequency = 3100 [Hz];
        attribute buzzerActive : Boolean = false;
        attribute ledActive : Boolean = false;
        attribute lowBatteryChirpActive : Boolean = false;

        part buzzer : PiezoBuzzer;
        part led : LEDIndicator;

        part def PiezoBuzzer {
            attribute frequency : Frequency = 3100 [Hz];
            attribute active : Boolean = false;
        }

        part def LEDIndicator {
            attribute color : String = "red";
            attribute active : Boolean = false;
        }

        state def AlarmStates {
            entry; then Idle;

            state Idle;
            state Sounding;
            state LowBatteryChirp;

            transition Idle -> Sounding
                when commandIn.command.level == AlarmLevel::danger
                    or commandIn.command.level == AlarmLevel::critical;

            transition Sounding -> Idle
                when commandIn.command.level == AlarmLevel::none;

            transition Idle -> LowBatteryChirp
                when commandIn.command.level == AlarmLevel::warning;

            transition LowBatteryChirp -> Idle
                when commandIn.command.level == AlarmLevel::none;
        }

        exhibit AlarmStates;
    }

    part def BatteryPowerSystem {
        port statusOut : BatteryStatusPort;
        port lowBatteryOut : LowBatteryPort;
        port powerOut : PowerPort;

        attribute nominalVoltage : Voltage = 9 [V];
        attribute currentVoltage : Voltage = 9 [V];
        attribute charge : Percent = 100 [%];
        attribute state : BatteryState = BatteryState::normal;
        attribute lowThreshold : Percent = 15 [%];

        action def MonitorCharge {
            out item status : BatteryStatus;
            out item alert : LowBatteryAlert;
            attribute currentCharge : Percent;

            if currentCharge < lowThreshold and state == BatteryState::normal {
                state := BatteryState::low;
                alert := LowBatteryAlert{};
            } else if currentCharge >= lowThreshold and state == BatteryState::low {
                state := BatteryState::normal;
            }

            status.charge := currentCharge;
            status.voltage := currentVoltage;
        }

        action monitorCharge continuously {
            bind statusOut.status = MonitorCharge.status;
            bind lowBatteryOut.alert = MonitorCharge.alert;
            bind powerOut.voltage = currentVoltage;
        }
    }

    // ===== Top-level System =====
    part def CO_Detector {
        port ambientAir : AirPort;

        requirement detectCO : DetectCO { }
        requirement alarmThresholds : AlarmThresholds { }
        requirement lowBatteryWarn : LowBatteryWarning { }
        requirement powerSupply : PowerSupply { }

        part sensor : ElectrochemicalSensor {
            bind airIn = ambientAir;
        }

        part processor : CentralProcessingUnit;

        part alarm : AudioVisualAlarm;

        part battery : BatteryPowerSystem {
            attribute nominalVoltage = 9 [V];
        }

        connection sensor.readingOut to processor.readingIn;
        connection processor.alarmOut to alarm.commandIn;
        connection battery.statusOut to processor.batteryStatusIn;
        connection battery.lowBatteryOut to processor.lowBatteryIn;
        connection battery.powerOut to alarm.powerIn;

        // Internal power distribution
        connection battery.powerOut to sensor.powerPort
            if false; // sensor draws from same rail conceptually

        satisfy detectCO by sensor;
        satisfy alarmThresholds by processor;
        satisfy lowBatteryWarn by processor;
        satisfy powerSupply by battery;
    }
}
