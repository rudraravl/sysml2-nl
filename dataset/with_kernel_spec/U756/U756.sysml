package 'MEMS Magnetic Sensor Unit' {
    private import ISQ::*;
    private import ScalarValues::*;
    
    attribute def MagneticFluxDensityValue :> ScalarValues::Real;
    attribute def VoltageValue :> ScalarValues::Real;
    attribute def TemperatureValue :> ScalarValues::Real;
    
    item def RawAnalogSignal {
        attribute voltage : VoltageValue;
    }
    item def ConditionedAnalogSignal {
        attribute voltage : VoltageValue;
    }
    item def RawDigitalValue {
        attribute value : Integer;
    }
    item def CalibratedMagneticField {
        attribute x : MagneticFluxDensityValue;
        attribute y : MagneticFluxDensityValue;
        attribute z : MagneticFluxDensityValue;
        attribute temperature : TemperatureValue;
        attribute isSaturated : Boolean;
    }
    
    attribute def InitializeSignal;
    attribute def ReadySignal;
    attribute def StartMeasurementSignal;
    attribute def StopMeasurementSignal;
    attribute def SaturationAlert;
    attribute def ResetSignal;
    
    action def RegulatePower;
    action def SenseMagneticField;
    action def ConditionSignal;
    action def ConvertAnalogToDigital;
    action def SenseTemperature;
    action def ProcessData;
    action def PerformSelfTest;
    action def TransmitI2C;
    
    part def VoltageRegulator {
        in port extPower : VoltageValue;
        out port intPower : VoltageValue;
        action regulate : RegulatePower;
    }
    
    part def MEMSMagneticSensor {
        in port power : VoltageValue;
        out port rawSignal : RawAnalogSignal;
        action sense : SenseMagneticField;
    }
    
    part def SignalConditioner {
        in port power : VoltageValue;
        in port rawIn : RawAnalogSignal;
        out port conditionedOut : ConditionedAnalogSignal;
        action condition : ConditionSignal;
    }
    
    part def ADC {
        in port power : VoltageValue;
        in port analogIn : ConditionedAnalogSignal;
        out port digitalOut : RawDigitalValue;
        action convert : ConvertAnalogToDigital;
    }
    
    part def TemperatureSensor {
        in port power : VoltageValue;
        out port tempOut : TemperatureValue;
        action sense : SenseTemperature;
    }
    
    state def MicrocontrollerStates;
    
    part def Microcontroller {
        in port power : VoltageValue;
        in port rawDigitalIn : RawDigitalValue;
        in port tempIn : TemperatureValue;
        out port i2cOut : CalibratedMagneticField;
        
        attribute calibrationX : MagneticFluxDensityValue;
        attribute calibrationY : MagneticFluxDensityValue;
        attribute calibrationZ : MagneticFluxDensityValue;
        
        action processDataUsage : ProcessData;
        action performSelfTestUsage : PerformSelfTest;
        action transmitUsage : TransmitI2C;
        
        exhibit state mcuStates : MicrocontrollerStates {
            entry; then idle;
            state idle;
            accept InitializeSignal do performSelfTestUsage then init;
            state init;
            accept ReadySignal then ready;
            state ready;
            accept StartMeasurementSignal then active;
            state active;
            accept SaturationAlert then saturated;
            accept StopMeasurementSignal then ready;
            state saturated;
            accept ResetSignal then ready;
            accept StopMeasurementSignal then ready;
        }
    }
    
    part def I2CTransceiver {
        in port dataIn : CalibratedMagneticField;
        out port hostOut : CalibratedMagneticField;
        action transmit : TransmitI2C;
    }
    
    part def HostSystem {
        in port i2cIn : CalibratedMagneticField;
    }
    
    part def SensorUnit {
        in port externalPower : VoltageValue;
        out port i2cInterface : CalibratedMagneticField;
        
        part voltageRegulator : VoltageRegulator;
        part memsSensor : MEMSMagneticSensor;
        part signalConditioner : SignalConditioner;
        part adc : ADC;
        part tempSensor : TemperatureSensor;
        part microcontroller : Microcontroller;
        part i2cPort : I2CTransceiver;
        
        connect externalPower to voltageRegulator.extPower;
        connect voltageRegulator.intPower to memsSensor.power;
        connect voltageRegulator.intPower to signalConditioner.power;
        connect voltageRegulator.intPower to adc.power;
        connect voltageRegulator.intPower to tempSensor.power;
        connect voltageRegulator.intPower to microcontroller.power;
        
        connect memsSensor.rawSignal to signalConditioner.rawIn;
        connect signalConditioner.conditionedOut to adc.analogIn;
        connect adc.digitalOut to microcontroller.rawDigitalIn;
        connect tempSensor.tempOut to microcontroller.tempIn;
        connect microcontroller.i2cOut to i2cPort.dataIn;
        connect i2cPort.hostOut to i2cInterface;
    }
    
    part sensorModule : SensorUnit;
    part host : HostSystem;
    connect sensorModule.i2cInterface to host.i2cIn;
    
    requirement MeasurementAccuracy {
        doc "The unit shall measure magnetic field with an accuracy of 0.1 Gauss.";
    }
    requirement MeasurementRange {
        doc "The unit shall measure magnetic fields from -8 Gauss to +8 Gauss.";
    }
    requirement I2CCompliance {
        doc "The unit shall communicate via I2C standard protocol.";
    }
    requirement PowerConsumption {
        doc "The unit shall consume less than 10 mW in active mode.";
    }
    
    part sensorUnitInstance : SensorUnit {
        satisfy MeasurementAccuracy;
        satisfy MeasurementRange;
        satisfy I2CCompliance;
        satisfy PowerConsumption;
    }
}
