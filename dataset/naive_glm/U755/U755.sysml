package MAP_Sensor_System {
    import ISQ::*;
    import ScalarValues::*;

    unit kPa;
    unit V;
    unit degC;

    value def PressureValue :> Real {
        unit kPa;
    }
    value def VoltageValue :> Real {
        unit V;
    }
    value def TemperatureValue :> Real {
        unit degC;
    }
    value def DigitalValue :> Integer;
    value def StatusCode :> Integer;

    item def Air {
        :>> pressure : PressureValue;
        :>> temperature : TemperatureValue;
    }

    item def DataPacket {
        :>> pressure : PressureValue;
        :>> temperature : TemperatureValue;
        :>> status : StatusCode;
    }

    requirement def OperationalRequirements {
        subject sensor : MAP_Sensor;
        requirement tempRange {
            subject sensor;
            constraint { -40 <= sensor.measuredTemp <= 150 }
        }
        requirement pressureRange {
            subject sensor;
            constraint { 10 <= sensor.measuredPressure <= 400 }
        }
        requirement responseTime {
            subject sensor;
            constraint { sensor.responseTime <= 1.0 }
        }
    }

    port def PneumaticPort {
        out item air : Air;
    }
    port def ElectricalPowerPort {
        in attribute voltage : VoltageValue;
        in attribute ground : VoltageValue;
    }
    port def DataPort {
        out item data : DataPacket;
    }
    port def DeformationPort {
        out attribute strain : Real;
    }
    port def AnalogVoltagePort {
        out attribute voltage : VoltageValue;
    }
    port def DigitalValuePort {
        out attribute value : DigitalValue;
    }
    port def TempDataPort {
        out attribute temp : TemperatureValue;
    }

    part def Intake_Manifold {
        port pneumaticOut : PneumaticPort;
    }

    part def ECU {
        port powerOut : ElectricalPowerPort;
        port dataIn : DataPort;
    }

    part def MAP_Sensor {
        port pneumaticIn : PneumaticPort;
        port powerIn : ElectricalPowerPort;
        port dataOut : DataPort;

        attribute measuredTemp : TemperatureValue;
        attribute measuredPressure : PressureValue;
        attribute responseTime : Real;

        satisfy OperationalRequirements by self;

        part piezoelectricElement {
            in port pressureIn : PneumaticPort;
            out port deformationOut : DeformationPort;
        }
        part strainGaugeBridge {
            in port defIn : DeformationPort;
            out port voltageOut : AnalogVoltagePort;
        }
        part signalAmplifier {
            in port ampIn : AnalogVoltagePort;
            out port ampOut : AnalogVoltagePort;
        }
        part temperatureSensor {
            out port tempOut : TempDataPort;
        }
        part temperatureCompensator {
            in port compIn : AnalogVoltagePort;
            in port tempIn : TempDataPort;
            out port compOut : AnalogVoltagePort;
        }
        part lowPassFilter {
            in port filterIn : AnalogVoltagePort;
            out port filterOut : AnalogVoltagePort;
        }
        part adc {
            in port adcIn : AnalogVoltagePort;
            out port adcOut : DigitalValuePort;
        }
        part microcontroller {
            in port mcuIn : DigitalValuePort;
            in port mcuTempIn : TempDataPort;
            out port mcuOut : DataPort;
        }

        connect pneumaticIn to piezoelectricElement.pressureIn;
        connect piezoelectricElement.deformationOut to strainGaugeBridge.defIn;
        connect strainGaugeBridge.voltageOut to signalAmplifier.ampIn;
        connect signalAmplifier.ampOut to temperatureCompensator.compIn;
        connect temperatureSensor.tempOut to temperatureCompensator.tempIn;
        connect temperatureCompensator.compOut to lowPassFilter.filterIn;
        connect lowPassFilter.filterOut to adc.adcIn;
        connect adc.adcOut to microcontroller.mcuIn;
        connect temperatureSensor.tempOut to microcontroller.mcuTempIn;
        connect microcontroller.mcuOut to dataOut;

        state machine MAP_Sensor_States {
            entry; then powerOn;
            state powerOn;
            transition from powerOn to selfTest when true;
            state selfTest;
            transition from selfTest to operational when selfTestPassed;
            transition from selfTest to fault when selfTestFailed;
            state operational;
            transition from operational to fault when faultDetected;
            state fault;
            transition from fault to operational when faultCleared;
        }
    }

    part MAP_Sensor_Context {
        part manifold : Intake_Manifold;
        part mapSensor : MAP_Sensor;
        part ecu : ECU;

        connect manifold.pneumaticOut to mapSensor.pneumaticIn;
        connect ecu.powerOut to mapSensor.powerIn;
        connect mapSensor.dataOut to ecu.dataIn;
    }
}
