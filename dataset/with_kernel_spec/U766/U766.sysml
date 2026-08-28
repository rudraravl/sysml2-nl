package ThreeAxisDigitalMagnetometer {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def MagneticFieldVector {
            attribute x :> ISQ::magneticFluxDensity;
            attribute y :> ISQ::magneticFluxDensity;
            attribute z :> ISQ::magneticFluxDensity;
            attribute magnitude :> ISQ::magneticFluxDensity;
        }
        attribute def RawAnalogSignal;
        attribute def ConditionedAnalogSignal;
        attribute def DigitalSample {
            attribute x : Integer;
            attribute y : Integer;
            attribute z : Integer;
        }
        attribute def CalibratedMeasurement :> MagneticFieldVector;
        attribute def TemperatureReading {
            attribute temp :> ISQ::temperature;
        }
        attribute def PowerSignal {
            attribute voltage :> ISQ::electricPotential;
            attribute current :> ISQ::electricCurrent;
        }
        attribute def CalibrationData {
            attribute hardIronOffset : MagneticFieldVector;
            attribute softIronScale : Real[3];
        }
        
        attribute def PowerOn;
        attribute def InitComplete;
        attribute def StartMeasurement;
        attribute def StopMeasurement;
        attribute def StartCalibration;
        attribute def CalibrationComplete;
        attribute def ErrorDetected;
        attribute def Reset;
        
        port def AnalogOutPort { out signal : RawAnalogSignal; }
        port def AnalogInPort { in signal : RawAnalogSignal; }
        port def ConditionedAnalogOutPort { out signal : ConditionedAnalogSignal; }
        port def ConditionedAnalogInPort { in signal : ConditionedAnalogSignal; }
        port def DigitalOutPort { out sample : DigitalSample; }
        port def DigitalInPort { in sample : DigitalSample; }
        port def TempOutPort { out tempReading : TemperatureReading; }
        port def TempInPort { in tempReading : TemperatureReading; }
        port def I2COutPort { out data : CalibratedMeasurement; }
        port def I2CInPort { in data : CalibratedMeasurement; }
        port def PowerInPort { in extVoltage :> ISQ::electricPotential; }
        port def PowerOutPort { out intPower : PowerSignal; }
        port def PowerConsumerPort { in intPower : PowerSignal; }
        
        action def SenseField { out signal : RawAnalogSignal; }
        action def ConditionSignal { in signal : RawAnalogSignal; out conditioned : ConditionedAnalogSignal; }
        action def Convert { in conditioned : ConditionedAnalogSignal; out sample : DigitalSample; }
        action def ProcessData { in sample : DigitalSample; in temp : TemperatureReading; out data : CalibratedMeasurement; }
        action def TransmitData { in data : CalibratedMeasurement; }
        action def RegulatePower { in extVoltage :> ISQ::electricPotential; out intPower : PowerSignal; }
        action def SenseTemperature { out tempReading : TemperatureReading; }
        action def PerformSelfTest;
        action def UpdateCalibration;
        
        part def SensingElement {
            port analogOut : AnalogOutPort;
            port powerIn : PowerConsumerPort;
            perform action senseField : SenseField;
        }
        part def SignalConditioner {
            port analogIn : AnalogInPort;
            port conditionedOut : ConditionedAnalogOutPort;
            port powerIn : PowerConsumerPort;
            perform action conditionSignal : ConditionSignal;
        }
        part def ADC {
            port conditionedIn : ConditionedAnalogInPort;
            port digitalOut : DigitalOutPort;
            port powerIn : PowerConsumerPort;
            perform action convert : Convert;
        }
        part def DigitalProcessor {
            port digitalIn : DigitalInPort;
            port tempIn : TempInPort;
            port i2cOut : I2COutPort;
            port powerIn : PowerConsumerPort;
            attribute calibration : CalibrationData;
            perform action processData : ProcessData;
            perform action updateCalibration : UpdateCalibration;
        }
        part def CommunicationInterface {
            port i2cIn : I2CInPort;
            port i2cOut : I2COutPort;
            port powerIn : PowerConsumerPort;
            perform action transmitData : TransmitData;
        }
        part def PowerManagementUnit {
            port powerIn : PowerInPort;
            port powerOut : PowerOutPort;
            perform action regulatePower : RegulatePower;
        }
        part def TemperatureSensor {
            port tempOut : TempOutPort;
            port powerIn : PowerConsumerPort;
            perform action senseTemperature : SenseTemperature;
        }
        
        state def MagnetometerStates {
            entry; then powerOff;
            state powerOff;
            transition powerOff_to_initializing
                first powerOff
                accept PowerOn
                then initializing;
            state initializing {
                action performSelfTest : PerformSelfTest;
                entry performSelfTest;
            }
            transition initializing_to_idle
                first initializing
                accept InitComplete
                then idle;
            state idle;
            transition idle_to_measuring
                first idle
                accept StartMeasurement
                then measuring;
            transition idle_to_calibrating
                first idle
                accept StartCalibration
                then calibrating;
            state measuring {
                action senseField : SenseField;
                action conditionSignal : ConditionSignal;
                action convert : Convert;
                action processData : ProcessData;
                action transmitData : TransmitData;
                do senseField;
                do conditionSignal;
                do convert;
                do processData;
                do transmitData;
            }
            transition measuring_to_idle
                first measuring
                accept StopMeasurement
                then idle;
            state calibrating {
                action updateCalibration : UpdateCalibration;
                do updateCalibration;
            }
            transition calibrating_to_idle
                first calibrating
                accept CalibrationComplete
                then idle;
            transition idle_to_fault
                first idle
                accept ErrorDetected
                then fault;
            transition measuring_to_fault
                first measuring
                accept ErrorDetected
                then fault;
            transition calibrating_to_fault
                first calibrating
                accept ErrorDetected
                then fault;
            state fault;
            transition fault_to_idle
                first fault
                accept Reset
                then idle;
        }
        
        part def ThreeAxisDigitalMagnetometer {
            port extPower : PowerInPort;
            port hostComm : I2COutPort;
            
            part sensingElement : SensingElement;
            part signalConditioner : SignalConditioner;
            part adc : ADC;
            part digitalProcessor : DigitalProcessor;
            part commInterface : CommunicationInterface;
            part powerUnit : PowerManagementUnit;
            part tempSensor : TemperatureSensor;
            
            action performSelfTest : PerformSelfTest;
            action updateCalibration : UpdateCalibration;
            
            connect powerUnit.powerOut to sensingElement.powerIn;
            connect powerUnit.powerOut to signalConditioner.powerIn;
            connect powerUnit.powerOut to adc.powerIn;
            connect powerUnit.powerOut to digitalProcessor.powerIn;
            connect powerUnit.powerOut to commInterface.powerIn;
            connect powerUnit.powerOut to tempSensor.powerIn;
            
            connect sensingElement.analogOut to signalConditioner.analogIn;
            connect signalConditioner.conditionedOut to adc.conditionedIn;
            connect adc.digitalOut to digitalProcessor.digitalIn;
            connect tempSensor.tempOut to digitalProcessor.tempIn;
            connect digitalProcessor.i2cOut to commInterface.i2cIn;
            connect extPower to powerUnit.powerIn;
            connect commInterface.i2cOut to hostComm;
            
            exhibit state opStates : MagnetometerStates;
        }
        
        requirement def CalibratedOutputRequirement {
            doc /* The magnetometer must provide calibrated digital output. */
            subject magnetometer : ThreeAxisDigitalMagnetometer;
        }
        requirement def PowerRegulationRequirement {
            doc /* The PMU must regulate external voltage to internal power. */
            subject pmu : PowerManagementUnit;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part magnetometer : ThreeAxisDigitalMagnetometer;
        
        requirement calibratedOutput : CalibratedOutputRequirement;
        requirement powerRegulation : PowerRegulationRequirement;
        
        satisfy calibratedOutput by magnetometer;
        satisfy powerRegulation by magnetometer.powerUnit;
    }
}
