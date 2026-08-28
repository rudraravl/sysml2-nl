package 'Oxygen Sensing Unit Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ISQElectromagnetism::*;

    package Definitions {
        item def GasSample {
            attribute oxygenFraction : Real;
            attribute pressure :> ISQ::pressure;
            attribute temperature :> ISQ::temperature;
        }

        enum def SensorStatus {
            normal;
            calibrating;
            error;
        }

        item def OxygenReading {
            attribute oxygenConcentration : Real;
            attribute confidence : Real;
            attribute sensorStatus : SensorStatus;
        }

        item def AnalogVoltage {
            attribute voltageValue :> ISQ::electricPotential;
        }

        item def DigitalValue {
            attribute rawCount : Real;
        }

        attribute def CalibrationData {
            attribute slope : Real;
            attribute offset : Real;
        }

        item def ElectricalPower {
            attribute voltage :> ISQ::electricPotential;
            attribute current :> ISQ::electricCurrent;
        }

        port def GasInPort { in item sample : GasSample; }
        port def PowerInPort { in item power : ElectricalPower; }
        port def ReadingOutPort { out item reading : OxygenReading; }
        port def AnalogSignalOutPort { out item voltage : AnalogVoltage; }
        port def AnalogSignalInPort { in item voltage : AnalogVoltage; }
        port def DigitalSignalOutPort { out item value : DigitalValue; }
        port def DigitalSignalInPort { in item value : DigitalValue; }
        port def HeaterPowerOutPort { out item heaterPower : ElectricalPower; }
        port def ElectronicsPowerOutPort { out item electronicsPower : ElectricalPower; }

        action def HeatUp { out temp : TemperatureValue; }
        action def SenseOxygen { in item sample : GasSample; out item voltage : AnalogVoltage; }
        action def AmplifySignal { in item voltage : AnalogVoltage; out item amplifiedVoltage : AnalogVoltage; }
        action def ConvertAnalogToDigital { in item voltage : AnalogVoltage; out item value : DigitalValue; }
        action def CalculateConcentration { in item value : DigitalValue; in calibration : CalibrationData; out item reading : OxygenReading; }
        action def MeasureOxygen {
            action sense : SenseOxygen;
            action amplify : AmplifySignal;
            action convert : ConvertAnalogToDigital;
            action calculate : CalculateConcentration;
        }
        action def RegulatePower;
        action def Calibrate;
        action def MonitorFaults;

        attribute def 'Power On';
        attribute def 'Warm Up Complete';
        attribute def 'Heater Fault';
        attribute def 'Measure Command';
        attribute def 'Measurement Complete';
        attribute def 'Calibrate Command';
        attribute def 'Calibration Complete';
        attribute def 'Fault Detected';
        attribute def 'Return To Ready';

        state def UnitStates;

        part def HeatingElement {
            attribute targetTemp : TemperatureValue = 923.15 [K];
            port powerIn : PowerInPort;
            perform action heatUp : HeatUp;
        }

        part def ZirconiaSensingElement {
            port gasIn : GasInPort;
            port voltageOut : AnalogSignalOutPort;
            attribute temperature :> ISQ::temperature;
            perform action senseOxygen : SenseOxygen;
        }

        part def SignalAmplifier {
            port voltageIn : AnalogSignalInPort;
            port amplifiedOut : AnalogSignalOutPort;
            attribute gain : Real = 100.0;
            perform action amplify : AmplifySignal;
        }

        part def ZirconiaOxygenSensor {
            port gasIn : GasInPort;
            port heaterPowerIn : PowerInPort;
            port analogOut : AnalogSignalOutPort;
            attribute targetTemperature :> ISQ::temperature = 923.15 [K];

            part heatingElement : HeatingElement;
            part sensingElement : ZirconiaSensingElement;
            part amplifier : SignalAmplifier;

            connect gasIn to sensingElement.gasIn;
            connect heaterPowerIn to heatingElement.powerIn;
            connect sensingElement.voltageOut to amplifier.voltageIn;
            connect amplifier.amplifiedOut to analogOut;
        }

        part def AnalogToDigitalConverter {
            port analogIn : AnalogSignalInPort;
            port powerIn : PowerInPort;
            port digitalOut : DigitalSignalOutPort;
            perform action convert : ConvertAnalogToDigital;
        }

        part def CalibrationMemory {
            port powerIn : PowerInPort;
            attribute storedCalibration : CalibrationData;
        }

        part def Microcontroller {
            port digitalIn : DigitalSignalInPort;
            port powerIn : PowerInPort;
            port readingOut : ReadingOutPort;
            part calibMem : CalibrationMemory;
            perform action calculate : CalculateConcentration;
            perform action monitorFaults : MonitorFaults;
        }

        part def SignalProcessor {
            port analogIn : AnalogSignalInPort;
            port powerIn : PowerInPort;
            port readingOut : ReadingOutPort;

            part adc : AnalogToDigitalConverter;
            part micro : Microcontroller;

            connect analogIn to adc.analogIn;
            connect powerIn to adc.powerIn;
            connect powerIn to micro.powerIn;
            connect adc.digitalOut to micro.digitalIn;
            connect micro.readingOut to readingOut;
        }

        part def PowerModule {
            port mainPowerIn : PowerInPort;
            port heaterPowerOut : HeaterPowerOutPort;
            port electronicsPowerOut : ElectronicsPowerOutPort;
            perform action regulatePower : RegulatePower;
        }

        part def OxygenSensingUnit {
            port gasIn : GasInPort;
            port powerIn : PowerInPort;
            port readingOut : ReadingOutPort;

            part sensor : ZirconiaOxygenSensor;
            part processor : SignalProcessor;
            part power : PowerModule;

            connect gasIn to sensor.gasIn;
            connect powerIn to power.mainPowerIn;
            connect power.heaterPowerOut to sensor.heaterPowerIn;
            connect power.electronicsPowerOut to processor.powerIn;
            connect sensor.analogOut to processor.analogIn;
            connect processor.readingOut to readingOut;

            exhibit state unitStates : UnitStates;
        }

        requirement def 'Operating Temperature Requirement' {
            doc /* The Zirconia sensing element shall be heated to and maintained at 923.15 K (650 C). */
            attribute requiredTemperature :> ISQ::temperature = 923.15 [K];
        }

        requirement def 'Accurate Oxygen Reading Requirement' {
            doc /* The unit shall output an oxygen reading containing concentration, confidence level, and sensor status. */
            attribute requiredConfidence : Real = 0.95;
        }
    }

    import Definitions::*;

    package Usages {
        private import Definitions::*;

        part oxygenUnit : OxygenSensingUnit;

        action regulateHeater : RegulatePower;
        action measureOxygen : MeasureOxygen;
        action calibrate : Calibrate;
        action monitorFaults : MonitorFaults;

        requirement operatingTemp : 'Operating Temperature Requirement';
        requirement accurateReading : 'Accurate Oxygen Reading Requirement';

        state 'unit states' : UnitStates {
            entry action initial {
            }
            transition initial then initializing;

            state initializing;
            accept 'Power On'
                then 'warming up';

            state 'warming up' {
                do oxygenUnit.sensor.heatingElement.heatUp;
            }
            accept when oxygenUnit.sensor.heatingElement.heatUp.temp >= oxygenUnit.sensor.heatingElement.targetTemp
                then ready;
            accept 'Heater Fault'
                then error;

            state ready;
            accept 'Measure Command'
                then measuring;
            accept 'Calibrate Command'
                then calibrating;
            accept 'Fault Detected'
                then error;

            state measuring {
                do measureOxygen;
            }
            accept 'Measurement Complete'
                then ready;
            accept 'Fault Detected'
                then error;

            state calibrating {
                do calibrate;
            }
            accept 'Calibration Complete'
                then ready;
            accept 'Fault Detected'
                then error;

            state error {
                do monitorFaults;
            }
            accept 'Return To Ready'
                then ready;
        }
    }
}
