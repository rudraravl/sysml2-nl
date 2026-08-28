package TemperatureSensingUnit {
    attribute def Voltage :> ScalarValues::Real;
    attribute def DigitalCode :> ScalarValues::Integer;
    attribute def Temperature :> ScalarValues::Real;

    item def StartMeasurement;
    item def ConversionComplete;
    item def CalibrationComplete;
    item def TransmitAck;
    item def ErrorEvent;
    item def Reset;

    port def PowerPort {
        in attribute voltage : Voltage;
    }
    port def AnalogOutPort {
        out attribute voltage : Voltage;
    }
    port def AnalogInPort {
        in attribute voltage : Voltage;
    }
    port def DigitalOutPort {
        out attribute code : DigitalCode;
    }
    port def DigitalInPort {
        in attribute code : DigitalCode;
    }
    port def ControlPort {
        in attribute command : ScalarValues::String;
        out attribute status : ScalarValues::String;
    }

    part def SiliconBandgapSensor {
        port powerIn : PowerPort;
        port analogOut : AnalogOutPort;
        port control : ControlPort;
        attribute bjt1Area : ScalarValues::Real;
        attribute bjt2Area : ScalarValues::Real;
        attribute referenceVoltage : Voltage = 1.2;
        perform action generateVoltage;
    }

    part def AnalogToDigitalConverter {
        port powerIn : PowerPort;
        port analogIn : AnalogInPort;
        port digitalOut : DigitalOutPort;
        port control : ControlPort;
        attribute resolutionBits : ScalarValues::Integer = 12;
        perform action convert;
    }

    part def SignalProcessor {
        port powerIn : PowerPort;
        port digitalIn : DigitalInPort;
        port digitalOut : DigitalOutPort;
        port control : ControlPort;
        attribute offsetCorrection : DigitalCode;
        attribute gainCorrection : ScalarValues::Real;
        perform action calibrate;
    }

    action def GenerateVoltage {
        out voltage : Voltage;
    }
    action def Convert {
        in voltage : Voltage;
        out code : DigitalCode;
    }
    action def Calibrate {
        in code : DigitalCode;
        out calibratedCode : DigitalCode;
    }
    action def StartConversion;
    action def ProcessData;
    action def TransmitData;
    action def HandleError;

    state def ControllerStates {
        entry; then Idle;
        state Idle;
        transition first Idle accept StartMeasurement then Measuring;
        state Measuring {
            do action StartConversion;
        }
        transition first Measuring accept ConversionComplete then Processing;
        state Processing {
            do action ProcessData;
        }
        transition first Processing accept CalibrationComplete then Ready;
        state Ready {
            do action TransmitData;
        }
        transition first Ready accept TransmitAck then Idle;
        state ErrorState {
            do action HandleError;
        }
        transition first Measuring accept ErrorEvent then ErrorState;
        transition first Processing accept ErrorEvent then ErrorState;
        transition first ErrorState accept Reset then Idle;
    }

    part def SensorController {
        port powerIn : PowerPort;
        port control : ControlPort;
        exhibit state controllerStates : ControllerStates;
    }

    part def TemperatureSensorModule {
        port powerIn : PowerPort;
        port dataOut : DigitalOutPort;
        attribute ambientTemp : Temperature;
        attribute measurementError : Temperature;

        part sensor : SiliconBandgapSensor;
        part adc : AnalogToDigitalConverter;
        part processor : SignalProcessor;
        part controller : SensorController;

        connect powerIn to sensor.powerIn;
        connect powerIn to adc.powerIn;
        connect powerIn to processor.powerIn;
        connect powerIn to controller.powerIn;

        connect sensor.analogOut to adc.analogIn;
        connect adc.digitalOut to processor.digitalIn;
        connect processor.digitalOut to dataOut;
        
        connect controller.control to sensor.control;
        connect controller.control to adc.control;
        connect controller.control to processor.control;
    }

    requirement def AccuracyRequirement {
        attribute maxError : Temperature = 0.5;
        subject tempSensor : TemperatureSensorModule;
        assert constraint { tempSensor.measurementError <= maxError }
    }

    requirement def OperatingRangeRequirement {
        attribute minTemp : Temperature = -40;
        attribute maxTemp : Temperature = 125;
        subject tempSensor : TemperatureSensorModule;
        assert constraint { tempSensor.ambientTemp >= minTemp and tempSensor.ambientTemp <= maxTemp }
    }

    part tempSensorUnit : TemperatureSensorModule {
        satisfy accuracyReq : AccuracyRequirement;
        satisfy opRangeReq : OperatingRangeRequirement;
    }
}
