package ISFET_pH_Sensor_System {
    import ScalarValues::*;

    // Value Types
    value def pH :> Real;
    value def Voltage :> Real;
    value def Current :> Real;
    value def Temperature :> Real;
    value def Time :> Real;
    value def DigitalValue :> Integer;

    // Items
    item def AqueousSolution {
        attribute ph : pH;
        attribute temp : Temperature;
    }
    
    item def DigitalSignal {
        attribute value : DigitalValue;
    }

    // Ports
    port def FluidPort {
        in solution : AqueousSolution;
    }
    port def VoltagePort {
        out voltage : Voltage;
    }
    port def CurrentPort {
        out current : Current;
    }
    port def DigitalPort {
        out data : DigitalSignal;
    }

    // Parts
    part def IonSensitiveMembrane {
        port in solutionPort : FluidPort;
        port out surfaceVoltagePort : VoltagePort;
        
        action def ReactToHydrogenIons {
            in solution : AqueousSolution;
            out voltage : Voltage;
        }
    }

    part def FETTransistor {
        port in gateVoltagePort : VoltagePort;
        port in referenceVoltagePort : VoltagePort;
        port out drainCurrentPort : CurrentPort;
        
        action def ModulateCurrent {
            in gateVoltage : Voltage;
            in referenceVoltage : Voltage;
            out drainCurrent : Current;
        }
    }

    part def ReferenceElectrode {
        port out referenceVoltagePort : VoltagePort;
        attribute referenceVoltage : Voltage = 0.0;
    }

    part def TransimpedanceAmplifier {
        port in currentInputPort : CurrentPort;
        port out voltageOutputPort : VoltagePort;
        attribute gain : Real = 1000000.0;
        
        action def ConvertCurrentToVoltage {
            in current : Current;
            out voltage : Voltage;
        }
    }

    part def AnalogToDigitalConverter {
        port in analogInputPort : VoltagePort;
        port out digitalOutputPort : DigitalPort;
        attribute resolution : Integer = 16;
        
        action def SampleAndConvert {
            in voltage : Voltage;
            out digitalValue : DigitalSignal;
        }
    }

    part def Microcontroller {
        port in digitalInputPort : DigitalPort;
        port in temperatureSensorPort : VoltagePort;
        port out phOutputPort : DigitalPort;
        
        attribute calibratedPH : pH;
        
        action def calculatePH {
            in digitalValue : DigitalSignal;
            in tempVoltage : Voltage;
            out phValue : pH;
        }
        
        action def outputPH {
            in phValue : pH;
            out digitalOut : DigitalSignal;
        }
        
        state measurementBehavior {
            state Idle;
            state Processing {
                entry do calculatePH();
            }
            state Outputting {
                entry do outputPH();
            }
            transition from Idle to Processing when digitalInputPort.data.value > 0;
            transition from Processing to Outputting;
            transition from Outputting to Idle;
        }
    }

    // Composite System
    part def DigitalPHSensorSystem {
        port in fluidInput : FluidPort;
        port in ambientTempSensor : VoltagePort;
        port out phOutput : DigitalPort;
        
        attribute measurementError : Real;
        attribute responseTime : Time;
        attribute ambientTemp : Temperature;
        
        part membrane : IonSensitiveMembrane;
        part fet : FETTransistor;
        part refElectrode : ReferenceElectrode;
        part tia : TransimpedanceAmplifier;
        part adc : AnalogToDigitalConverter;
        part mcu : Microcontroller;
        
        // Connections
        connect fluidInput.solution to membrane.solutionPort.solution;
        connect membrane.surfaceVoltagePort.voltage to fet.gateVoltagePort.voltage;
        connect refElectrode.referenceVoltagePort.voltage to fet.referenceVoltagePort.voltage;
        connect fet.drainCurrentPort.current to tia.currentInputPort.current;
        connect tia.voltageOutputPort.voltage to adc.analogInputPort.voltage;
        connect adc.digitalOutputPort.data to mcu.digitalInputPort.data;
        connect ambientTempSensor.voltage to mcu.temperatureSensorPort.voltage;
        connect mcu.phOutputPort.data to phOutput.data;
    }

    // Requirements
    requirement def MeasurementRangeRequirement {
        subject sensor : DigitalPHSensorSystem;
        constraint { sensor.mcu.calibratedPH >= 0 and sensor.mcu.calibratedPH <= 14 }
    }
    
    requirement def AccuracyRequirement {
        subject sensor : DigitalPHSensorSystem;
        attribute maxError : Real = 0.02;
        constraint { sensor.measurementError <= maxError }
    }
    
    requirement def ResponseTimeRequirement {
        subject sensor : DigitalPHSensorSystem;
        attribute maxResponseTime : Time = 10.0;
        constraint { sensor.responseTime <= maxResponseTime }
    }
    
    requirement def OperatingTemperatureRequirement {
        subject sensor : DigitalPHSensorSystem;
        attribute minTemp : Temperature = 0.0;
        attribute maxTemp : Temperature = 100.0;
        constraint { sensor.ambientTemp >= minTemp and sensor.ambientTemp <= maxTemp }
    }
}
