package LeadShieldingSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;

    // ---- Value types with units ----
    value type Thickness :> Real {
    }
    attribute def cm : UnitOfMeasure { }
    attribute def cm2 : UnitOfMeasure { }
    attribute def mSvPerHour : UnitOfMeasure { }
    attribute def mSv : UnitOfMeasure { }
    attribute def percent : UnitOfMeasure { }

    value type Length_cm :> Real {
        unit : cm;
    }
    value type DoseRate :> Real {
        unit : mSvPerHour;
    }
    value type Dose :> Real {
        unit : mSv;
    }
    value type AttenuationFactor :> Real {
        unit : percent;
    }

    // ---- Item types ----
    item def GammaRadiation {
        attribute energy : Real; // MeV
        attribute doseRate : DoseRate;
    }
    item def DoseReading {
        attribute measuredDoseRate : DoseRate;
        attribute timestamp : Real;
    }
    item def AlarmSignal {
        attribute active : Boolean;
        attribute severity : Integer;
    }
    item def InterlockCommand {
        attribute engage : Boolean;
    }

    // ---- Port definitions ----
    port def RadiationPort {
        out radiation : GammaRadiation;
    }
    port def DoseReadingPort {
        out reading : DoseReading;
    }
    port def AlarmSignalPort {
        out signal : AlarmSignal;
    }
    port def InterlockCommandPort {
        out command : InterlockCommand;
    }

    // ---- Requirements ----
    requirement def RadiationSafetyRequirement {
        doc "The system shall maintain radiation dose in the protected zone below the maximum permissible limit.";
        attribute maxPermissibleDoseRate : DoseRate = 1.0 [mSvPerHour];
        require protectedZoneDoseRate <= maxPermissibleDoseRate;
    }

    requirement def ShieldAttenuationRequirement {
        doc "The lead shield shall attenuate gamma radiation from a Cobalt-60 source by at least 95%.";
        attribute minAttenuation : AttenuationFactor = 95.0 [percent];
        require attenuationFactor >= minAttenuation;
    }

    requirement def AlarmResponseRequirement {
        doc "The alarm controller shall activate the alarm within 2 seconds of detecting a dose rate exceeding the safety limit.";
        attribute maxResponseTime : Real = 2.0;
        require responseTime <= maxResponseTime;
    }

    requirement def InterlockRequirement {
        doc "The safety interlock shall engage when radiation exceeds the safety limit to prevent personnel exposure.";
        require interlockEngaged == true when doseRateExceeded == true;
    }

    // ---- Parts ----

    part def Cobalt60Source {
        attribute activity : Real; // Becquerel
        attribute energy : Real = 1.252; // MeV average
        port sourcePort : RadiationPort;
    }

    part def LeadShield {
        attribute thickness : Length_cm = 7.5 [cm];
        attribute density : Real = 11.34; // g/cm3
        attribute attenuationFactor : AttenuationFactor = 97.0 [percent];
        port upstreamPort : RadiationPort;
        port downstreamPort : RadiationPort;

        action def Attenuate {
            in incomingRadiation : GammaRadiation;
            out attenuatedRadiation : GammaRadiation;
            perform {
                // Attenuation based on lead thickness and material properties
                attenuatedRadiation.doseRate := incomingRadiation.doseRate * (1.0 - attenuationFactor / 100.0);
            }
        }
    }

    part def DosimeterSensor {
        attribute sensitivity : Real;
        attribute measurementRange : DoseRate;
        port sensorInput : RadiationPort;
        port sensorOutput : DoseReadingPort;

        action def MeasureRadiation {
            in incomingRadiation : GammaRadiation;
            out reading : DoseReading;
            perform {
                reading.measuredDoseRate := incomingRadiation.doseRate;
                reading.timestamp := 0.0; // would be system clock
            }
        }
    }

    part def AlarmController {
        attribute safetyLimit : DoseRate = 1.0 [mSvPerHour];
        attribute responseTime : Real;
        attribute doseRateExceeded : Boolean = false;
        port controllerInput : DoseReadingPort;
        port alarmOutput : AlarmSignalPort;
        port interlockOutput : InterlockCommandPort;

        state def ControllerStates {
            initial Normal;
            state Normal {
                entry { alarmOutput.signal.active := false; interlockOutput.command.engage := false; doseRateExceeded := false; }
                transition Normal_Alert
                    first Normal
                    if controllerInput.reading.measuredDoseRate > safetyLimit
                    then Alert;
            }
            state Alert {
                entry { alarmOutput.signal.active := true; alarmOutput.signal.severity := 2; interlockOutput.command.engage := true; doseRateExceeded := true; }
                transition Alert_Normal
                    first Alert
                    if controllerInput.reading.measuredDoseRate <= safetyLimit
                    then Normal;
            }
        }

        action def EvaluateDose {
            in reading : DoseReading;
            out alarm : AlarmSignal;
            out interlock : InterlockCommand;
            perform {
                if reading.measuredDoseRate > safetyLimit {
                    alarm.active := true;
                    alarm.severity := 2;
                    interlock.engage := true;
                    doseRateExceeded := true;
                } else {
                    alarm.active := false;
                    alarm.severity := 0;
                    interlock.engage := false;
                    doseRateExceeded := false;
                }
            }
        }
    }

    part def AlarmDevice {
        attribute soundLevel : Real; // dB
        attribute strobeEnabled : Boolean = true;
        port alarmInput : AlarmSignalPort;

        action def ActivateAlarm {
            in signal : AlarmSignal;
            perform {
                if signal.active == true {
                    soundLevel := 100.0;
                    strobeEnabled := true;
                } else {
                    soundLevel := 0.0;
                    strobeEnabled := false;
                }
            }
        }
    }

    part def SafetyInterlock {
        attribute engaged : Boolean = false;
        attribute controlledEquipment : String;
        port interlockInput : InterlockCommandPort;

        action def EngageInterlock {
            in command : InterlockCommand;
            perform {
                engaged := command.engage;
            }
        }
    }

    // ---- Top-level system ----
    part def LeadShieldingSystem {
        satisfy RadiationSafetyRequirement;
        satisfy ShieldAttenuationRequirement;
        satisfy AlarmResponseRequirement;
        satisfy InterlockRequirement;

        part cobaltSource : Cobalt60Source {
            attribute activity := 3.7e13; // 1000 Ci in Bq
        }
        part leadShield : LeadShield;
        part dosimeter : DosimeterSensor;
        part alarmController : AlarmController;
        part alarmDevice : AlarmDevice;
        part safetyInterlock : SafetyInterlock {
            attribute controlledEquipment := "IrradiatorUnit";
        }

        // Protected zone concept
        attribute protectedZoneDoseRate : DoseRate;

        // Connections
        connection cobaltToShield : GammaRadiation
            connect cobaltSource.sourcePort.radiation to leadShield.upstreamPort.radiation;
        connection shieldToProtectedZone : GammaRadiation
            connect leadShield.downstreamPort.radiation to dosimeter.sensorInput.radiation;
        connection dosimeterToController : DoseReading
            connect dosimeter.sensorOutput.reading to alarmController.controllerInput.reading;
        connection controllerToAlarm : AlarmSignal
            connect alarmController.alarmOutput.signal to alarmDevice.alarmInput.signal;
        connection controllerToInterlock : InterlockCommand
            connect alarmController.interlockOutput.command to safetyInterlock.interlockInput.command;

        // State machine for overall system behavior
        state def SystemOperationStates {
            initial Operational;
            state Operational {
                entry { protectedZoneDoseRate := 0.0 [mSvPerHour]; }
                transition Operational_Warning
                    first Operational
                    if alarmController.doseRateExceeded == true
                    then Warning;
            }
            state Warning {
                entry { /* alarm and interlock active */ }
                transition Warning_Operational
                    first Warning
                    if alarmController.doseRateExceeded == false
                    then Operational;
            }
        }
    }

    // ---- Verification actions ----
    action def VerifyShieldAttenuation {
        in shield : LeadShield;
        in source : Cobalt60Source;
        out result : Boolean;
        perform {
            result := shield.attenuationFactor >= 95.0 [percent];
        }
    }

    action def VerifyAlarmResponse {
        in controller : AlarmController;
        in testDoseRate : DoseRate;
        out result : Boolean;
        perform {
            result := (testDoseRate > controller.safetyLimit) implies controller.responseTime <= 2.0;
        }
    }
}
