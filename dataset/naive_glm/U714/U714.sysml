package H2SSensingUnit {
    public import ScalarValues::*;
    public import ISQ::*;

    // ---- Value Types with Units ----
    item def H2SConcentration :> RealValue {
        attribute unit : String = "ppm";
    }
    item def Voltage :> RealValue {
        attribute unit : String = "mV";
    }
    item def DigitalValue :> IntegerValue;
    item def Temperature :> RealValue {
        attribute unit : String = "degC";
    }
    item def TimeStamp :> IntegerValue {
        attribute unit : String = "ms";
    }
    item def ResponseTime :> RealValue {
        attribute unit : String = "s";
    }
    item def Lifetime :> RealValue {
        attribute unit : String = "year";
    }

    // ---- Item Definitions ----
    item def AirSample;
    item def H2SGas;
    item def PowerSignal {
        attribute voltage : Voltage;
    }
    item def RegulatedPower {
        attribute voltage : Voltage;
    }
    item def AnalogSignal {
        attribute voltage : Voltage;
    }
    item def DigitalSample {
        attribute value : DigitalValue;
    }
    item def SensorReading {
        attribute concentration : H2SConcentration;
        attribute temperature : Temperature;
        attribute timestamp : TimeStamp;
    }
    item def AlarmSignal {
        attribute level : AlarmLevel;
    }
    enum def AlarmLevel { low; high; none; }

    // ---- Port Definitions ----
    port def GasIntakePort {
        out item sample : AirSample;
    }
    port def PowerPort {
        in item power : PowerSignal;
    }
    port def DataPort {
        out item reading : SensorReading;
    }
    port def AlarmPort {
        out item alarm : AlarmSignal;
    }
    port def AnalogOutPort {
        out item signal : AnalogSignal;
    }
    port def AnalogInPort {
        in item signal : AnalogSignal;
    }
    port def DigitalOutPort {
        out item sample : DigitalSample;
    }
    port def DigitalInPort {
        in item sample : DigitalSample;
    }
    port def RegulatedPowerOutPort {
        out item power : RegulatedPower;
    }
    port def RegulatedPowerInPort {
        in item power : RegulatedPower;
    }
    port def TempOutPort {
        out item temp : Temperature;
    }
    port def TempInPort {
        in item temp : Temperature;
    }

    // ---- Requirements ----
    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : ResponseTime = 30.0;
        subject sensingUnit : H2SSensingUnit;
        require sensingUnit.responseTime <= maxResponseTime;
    }
    requirement def LifetimeRequirement {
        attribute minLifetime : Lifetime = 1.0;
        subject sensingUnit : H2SSensingUnit;
        require sensingUnit.operationalLifetime >= minLifetime;
    }
    requirement def AccuracyRequirement {
        attribute tolerance : H2SConcentration = 2.0;
        subject sensingUnit : H2SSensingUnit;
        require sensingUnit.measurementError <= tolerance;
    }
    requirement def AlarmThresholdRequirement {
        attribute lowThreshold : H2SConcentration = 10.0;
        attribute highThreshold : H2SConcentration = 50.0;
        subject sensingUnit : H2SSensingUnit;
        require sensingUnit.lowAlarmThreshold == lowThreshold
            and sensingUnit.highAlarmThreshold == highThreshold;
    }

    // ---- Part Definitions ----
    part def ElectrochemicalSensingCell {
        attribute sensitivity : Voltage = 0.45; // mV per ppm
        port gasIn : GasIntakePort;
        port analogOut : AnalogOutPort;
        port powerIn : RegulatedPowerInPort;
        attribute rawVoltage : Voltage;

        action def GenerateSignal {
            in item air : AirSample;
            out item signal : AnalogSignal;
        }
        perform GenerateSignal;
    }

    part def SignalAmplifier {
        attribute gain : Real = 100.0;
        port analogIn : AnalogInPort;
        port analogOut : AnalogOutPort;
        port powerIn : RegulatedPowerInPort;

        action def Amplify {
            in item inputSignal : AnalogSignal;
            out item outputSignal : AnalogSignal;
        }
        perform Amplify;
    }

    part def AnalogToDigitalConverter {
        attribute resolution : Integer = 16;
        attribute samplingRate : Real = 10.0; // Hz
        port analogIn : AnalogInPort;
        port digitalOut : DigitalOutPort;
        port powerIn : RegulatedPowerInPort;

        action def Convert {
            in item inputSignal : AnalogSignal;
            out item outputSample : DigitalSample;
        }
        perform Convert;
    }

    part def TemperatureCompensator {
        port tempOut : TempOutPort;
        port powerIn : RegulatedPowerInPort;
        attribute currentTemp : Temperature;

        action def MeasureTemperature {
            out item temp : Temperature;
        }
        perform MeasureTemperature;
    }

    part def Microprocessor {
        attribute lowAlarmThreshold : H2SConcentration = 10.0;
        attribute highAlarmThreshold : H2SConcentration = 50.0;
        attribute calibrationOffset : H2SConcentration = 0.0;
        attribute calibrationScale : Real = 1.0;
        attribute currentConcentration : H2SConcentration;
        attribute currentTemperature : Temperature;
        attribute currentTimestamp : TimeStamp;

        port digitalIn : DigitalInPort;
        port tempIn : TempInPort;
        port dataOut : DataPort;
        port alarmOut : AlarmPort;
        port powerIn : RegulatedPowerInPort;

        state machine def OperatingStates {
            initial entry to PowerOnSetup;
            state PowerOnSetup {
                entry { /* initialize calibration data and self-test */ }
                transition to Standby when true;
            }
            state Standby {
                entry { /* idle mode, low power */ }
                transition to ActiveMeasuring when true;
            }
            state ActiveMeasuring {
                entry { /* continuously sample and compute concentration */ }
                transition to AlarmState when currentConcentration >= lowAlarmThreshold;
            }
            state AlarmState {
                entry { /* emit alarm signal */ }
                transition to ActiveMeasuring when currentConcentration < lowAlarmThreshold;
            }
        }
        perform OperatingStates;

        action def ProcessReading {
            in item sample : DigitalSample;
            in item temp : Temperature;
            out item reading : SensorReading;
            out item alarm : AlarmSignal;
        }
        perform ProcessReading;
    }

    part def PowerRegulator {
        attribute outputVoltage : Voltage = 3.3;
        port powerIn : PowerPort;
        port regulatedOut : RegulatedPowerOutPort;

        action def Regulate {
            in item inputPower : PowerSignal;
            out item outputPower : RegulatedPower;
        }
        perform Regulate;
    }

    // ---- Top-level H2S Sensing Unit ----
    part def H2SSensingUnit {
        attribute responseTime : ResponseTime = 30.0;
        attribute operationalLifetime : Lifetime = 1.0;
        attribute measurementError : H2SConcentration = 1.5;
        attribute lowAlarmThreshold : H2SConcentration = 10.0;
        attribute highAlarmThreshold : H2SConcentration = 50.0;

        port gasIntake : GasIntakePort;
        port powerInput : PowerPort;
        port dataOutput : DataPort;
        port alarmOutput : AlarmPort;

        part sensingCell : ElectrochemicalSensingCell {
            port gasIn : GasIntakePort;
            port analogOut : AnalogOutPort;
            port powerIn : RegulatedPowerInPort;
        }
        part amplifier : SignalAmplifier {
            port analogIn : AnalogInPort;
            port analogOut : AnalogOutPort;
            port powerIn : RegulatedPowerInPort;
        }
        part adc : AnalogToDigitalConverter {
            port analogIn : AnalogInPort;
            port digitalOut : DigitalOutPort;
            port powerIn : RegulatedPowerInPort;
        }
        part tempCompensator : TemperatureCompensator {
            port tempOut : TempOutPort;
            port powerIn : RegulatedPowerInPort;
        }
        part microprocessor : Microprocessor {
            port digitalIn : DigitalInPort;
            port tempIn : TempInPort;
            port dataOut : DataPort;
            port alarmOut : AlarmPort;
            port powerIn : RegulatedPowerInPort;
        }
        part powerRegulator : PowerRegulator {
            port powerIn : PowerPort;
            port regulatedOut : RegulatedPowerOutPort;
        }

        // External port bindings
        connect gasIntake to sensingCell.gasIn;
        connect powerInput to powerRegulator.powerIn;
        connect microprocessor.dataOut to dataOutput;
        connect microprocessor.alarmOut to alarmOutput;

        // Internal connections
        connect sensingCell.analogOut to amplifier.analogIn;
        connect amplifier.analogOut to adc.analogIn;
        connect adc.digitalOut to microprocessor.digitalIn;
        connect tempCompensator.tempOut to microprocessor.tempIn;

        // Power distribution
        connect powerRegulator.regulatedOut to sensingCell.powerIn;
        connect powerRegulator.regulatedOut to amplifier.powerIn;
        connect powerRegulator.regulatedOut to adc.powerIn;
        connect powerRegulator.regulatedOut to tempCompensator.powerIn;
        connect powerRegulator.regulatedOut to microprocessor.powerIn;

        satisfy ResponseTimeRequirement by this;
        satisfy LifetimeRequirement by this;
        satisfy AccuracyRequirement by this;
        satisfy AlarmThresholdRequirement by this;
    }
}
