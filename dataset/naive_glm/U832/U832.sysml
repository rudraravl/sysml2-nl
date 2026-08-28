package DigitalPressureGauge {
    import ISQ::*;
    import SI::*;

    item def Fluid;
    value type Pressure :> Real { unit "Pa"; }
    value type Voltage :> Real { unit "V"; }
    value type Frequency :> Real { unit "Hz"; }
    value type Time :> Real { unit "s"; }

    port def FluidPort { out fluid : Fluid; }
    port def PowerPort { out voltage : Voltage; }
    port def RawSignalPort { out signal : Voltage; }
    port def CorrectedPressurePort { out pressure : Pressure; }
    port def CalibrationStatusPort { out status : Boolean; }
    port def AlarmStatePort { out state : String; }

    part def PowerSupply {
        out port voltageOut : PowerPort;
    }

    part def PressureSensor {
        in port fluidContact : FluidPort;
        in port powerIn : PowerPort;
        out port rawSignalOut : RawSignalPort;
        
        attribute operatingRange : Pressure = 1000 [Pa];
        
        action def SensePressure {
            in fluid : Fluid;
            in power : Voltage;
            out rawSignal : Voltage;
        }
    }

    part def SignalProcessor {
        in port rawSignalIn : RawSignalPort;
        out port correctedPressureOut : CorrectedPressurePort;
        out port calibrationStatusOut : CalibrationStatusPort;
        
        attribute calibrationFactor : Real = 1.0;
        attribute zeroOffset : Pressure = 0 [Pa];
        attribute calibrationValid : Boolean = true;
        
        action def ProcessSignal {
            in rawSignal : Voltage;
            in factor : Real;
            in offset : Pressure;
            out correctedPressure : Pressure;
            out status : Boolean;
        }
    }

    part def DisplayUnit {
        in port pressureIn : CorrectedPressurePort;
        in port calibrationStatusIn : CalibrationStatusPort;
        in port alarmStateIn : AlarmStatePort;
        
        attribute resolution : Pressure = 0.1 [Pa];
        attribute refreshRate : Frequency = 10 [Hz];
        
        action def UpdateDisplay {
            in pressure : Pressure;
            in status : Boolean;
            in alarm : String;
        }
    }

    part def AlarmController {
        in port pressureIn : CorrectedPressurePort;
        out port alarmStateOut : AlarmStatePort;
        
        attribute highThreshold : Pressure = 800 [Pa];
        attribute lowThreshold : Pressure = 200 [Pa];
        attribute hysteresis : Pressure = 10 [Pa];
        
        state alarmStateMachine {
            state Normal;
            state HighPressureAlarm;
            state LowPressureAlarm;
            
            transition from Normal to HighPressureAlarm
                when pressureIn.pressure > highThreshold;
            transition from HighPressureAlarm to Normal
                when pressureIn.pressure < (highThreshold - hysteresis);
            transition from Normal to LowPressureAlarm
                when pressureIn.pressure < lowThreshold;
            transition from LowPressureAlarm to Normal
                when pressureIn.pressure > (lowThreshold + hysteresis);
        }
    }

    part def DigitalPressureGaugeSystem {
        part fluidLine : Fluid;
        part powerSource : PowerSupply;
        
        part sensor : PressureSensor;
        part processor : SignalProcessor;
        part display : DisplayUnit;
        part alarm : AlarmController;
        
        flow fluidLine to sensor.fluidContact.fluid;
        connect powerSource.voltageOut to sensor.powerIn;
        connect sensor.rawSignalOut to processor.rawSignalIn;
        connect processor.correctedPressureOut to display.pressureIn;
        connect processor.calibrationStatusOut to display.calibrationStatusIn;
        connect processor.correctedPressureOut to alarm.pressureIn;
        connect alarm.alarmStateOut to display.alarmStateIn;
    }

    requirement def MeasurementAccuracy {
        subject gauge : DigitalPressureGaugeSystem;
        attribute requiredAccuracy : Pressure = 0.1 [Pa];
        constraint { gauge.sensor.operatingRange <= 1000 [Pa] }
    }
    
    requirement def ResponseTime {
        subject gauge : DigitalPressureGaugeSystem;
        attribute maxResponseTime : Time = 0.1 [s];
        constraint { gauge.display.refreshRate >= 10 [Hz] }
    }
    
    requirement def AlarmReliability {
        subject gauge : DigitalPressureGaugeSystem;
        constraint { gauge.alarm.hysteresis > 0 [Pa] }
    }
}
