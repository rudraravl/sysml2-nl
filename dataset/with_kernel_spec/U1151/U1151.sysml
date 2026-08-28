package EnvironmentalMonitoringStation {
    private import ScalarValues::*;
    private import ISQ::*;
    public import Definitions::*;

    package Definitions {
        attribute def PowerSignal {
            attribute voltage :> ISQ::electricPotential;
            attribute current :> ISQ::electricCurrent;
        }

        attribute def TemperatureReading {
            attribute value :> ISQ::temperature;
            attribute isValid : Boolean;
        }

        attribute def HumidityReading {
            attribute relativeHumidity : Real;
            attribute isValid : Boolean;
        }

        attribute def PressureReading {
            attribute value :> ISQ::pressure;
            attribute isValid : Boolean;
        }

        attribute def DisplayData {
            attribute temperature : TemperatureReading;
            attribute humidity : HumidityReading;
            attribute pressure : PressureReading;
            attribute systemStatus : String;
        }

        attribute def PowerOnSignal;
        attribute def ResetSignal;
        attribute def SensorFaultSignal;

        port def PowerPort {
            in power : PowerSignal;
        }

        port def TemperatureDataPort {
            out reading : TemperatureReading;
        }

        port def HumidityDataPort {
            out reading : HumidityReading;
        }

        port def PressureDataPort {
            out reading : PressureReading;
        }

        port def DisplayPort {
            in data : DisplayData;
        }

        interface def PowerInterface {
            end supplier : PowerPort;
            end consumer : PowerPort;
        }

        interface def TemperatureDataInterface {
            end source : TemperatureDataPort;
            end target : TemperatureDataPort;
        }

        interface def HumidityDataInterface {
            end source : HumidityDataPort;
            end target : HumidityDataPort;
        }

        interface def PressureDataInterface {
            end source : PressureDataPort;
            end target : PressureDataPort;
        }

        interface def DisplayDataInterface {
            end source : DisplayPort;
            end target : DisplayPort;
        }

        action def InitializeSensors;
        action def AcquireData {
            out temp : TemperatureReading;
            out humidity : HumidityReading;
            out pressure : PressureReading;
        }
        action def ProcessData {
            in rawTemp : TemperatureReading;
            in rawHumidity : HumidityReading;
            in rawPressure : PressureReading;
            out processedData : DisplayData;
        }
        action def UpdateDisplay {
            in data : DisplayData;
        }
        action def DetectFault;
        action def RegulatePower;
        action def SenseTemperature {
            out reading : TemperatureReading;
        }
        action def SenseHumidity {
            out reading : HumidityReading;
        }
        action def SensePressure {
            out reading : PressureReading;
        }
        action def RenderDisplay {
            in data : DisplayData;
        }

        state def MonitorStates;

        part def PowerSupplyUnit {
            attribute inputVoltage :> ISQ::electricPotential;
            attribute mcuOutputVoltage :> ISQ::electricPotential;
            attribute sensorOutputVoltage :> ISQ::electricPotential;
            attribute displayOutputVoltage :> ISQ::electricPotential;
            attribute efficiency : Real;
            attribute isOpenSource : Boolean = true;

            port powerInput : PowerPort;
            port mcuPowerOut : PowerPort;
            port sensorPowerOut : PowerPort;
            port displayPowerOut : PowerPort;

            perform action regulatePower : RegulatePower;
        }

        part def TemperatureSensor {
            attribute sensorModel : String;
            attribute isOpenSource : Boolean = true;
            attribute minRange :> ISQ::temperature;
            attribute maxRange :> ISQ::temperature;

            port powerIn : PowerPort;
            port dataOut : TemperatureDataPort;

            perform action senseTemperature : SenseTemperature;
        }

        part def HumiditySensor {
            attribute sensorModel : String;
            attribute isOpenSource : Boolean = true;
            attribute minRange : Real;
            attribute maxRange : Real;

            port powerIn : PowerPort;
            port dataOut : HumidityDataPort;

            perform action senseHumidity : SenseHumidity;
        }

        part def PressureSensor {
            attribute sensorModel : String;
            attribute isOpenSource : Boolean = true;
            attribute minRange :> ISQ::pressure;
            attribute maxRange :> ISQ::pressure;

            port powerIn : PowerPort;
            port dataOut : PressureDataPort;

            perform action sensePressure : SensePressure;
        }

        part def LCDDisplay {
            attribute displayType : String = "LCD";
            attribute width : Integer;
            attribute height : Integer;
            attribute isOpenSource : Boolean = true;

            port powerIn : PowerPort;
            port dataIn : DisplayPort;

            perform action renderDisplay : RenderDisplay;
        }

        part def OpenSourceMicrocontroller {
            attribute firmwareVersion : String;
            attribute isOpenSource : Boolean = true;
            attribute clockRate :> ISQ::frequency;

            port powerIn : PowerPort;
            port tempDataIn : TemperatureDataPort;
            port humidityDataIn : HumidityDataPort;
            port pressureDataIn : PressureDataPort;
            port displayOut : DisplayPort;

            perform action initializeSensors : InitializeSensors;
            perform action acquireData : AcquireData;
            perform action processData : ProcessData;
            perform action updateDisplay : UpdateDisplay;
            perform action detectFault : DetectFault;
        }

        part def EnvironmentalMonitoringStation {
            attribute stationId : String;
            attribute isOpenSource : Boolean = true;
            attribute firmwareUrl : String;
            attribute schematicsUrl : String;
            attribute componentListUrl : String;

            port externalPower : PowerPort;

            part microcontroller : OpenSourceMicrocontroller;
            part temperatureSensor : TemperatureSensor;
            part humiditySensor : HumiditySensor;
            part pressureSensor : PressureSensor;
            part display : LCDDisplay;
            part powerSupply : PowerSupplyUnit;

            exhibit state monitorStates : MonitorStates;
        }

        requirement def OpenHardwareRequirement {
            doc
            /* All design schematics, component lists, and firmware shall be
               publicly available, allowing anyone to build, modify, or repair. */
        }

        requirement def ContinuousMonitoringRequirement {
            doc
            /* The system shall continuously measure and display real-time
               temperature, humidity, and atmospheric pressure. */
        }

        requirement def PowerRegulationRequirement {
            doc
            /* The power supply unit shall take a standard USB input voltage
               and regulate and distribute correct power to all subsystems. */
        }

        requirement def FaultHandlingRequirement {
            doc
            /* The system shall recognize faults, enter an error state,
               and allow reset to resume normal operation. */
        }
    }

    package Usages {
        private import Definitions::*;

        action initializeSensors : InitializeSensors;
        action acquireData : AcquireData;
        action processData : ProcessData;
        action updateDisplay : UpdateDisplay;
        action detectFault : DetectFault;

        state monitorStates : MonitorStates {
            entry; then poweredOff;
            state poweredOff;
            accept PowerOnSignal
                then initializing;
            state initializing {
                entry initializeSensors;
            }
            transition first initializing then monitoring;
            state monitoring {
                entry; then acquire;
                state acquire {
                    do acquireData;
                }
                transition first acquire then process;
                state process {
                    do processData;
                }
                transition first process then displayUpdate;
                state displayUpdate {
                    do updateDisplay;
                }
                transition first displayUpdate then acquire;
            }
            transition first monitoring.acquire accept SensorFaultSignal then error;
            transition first monitoring.process accept SensorFaultSignal then error;
            transition first monitoring.displayUpdate accept SensorFaultSignal then error;
            state error {
                entry detectFault;
            }
            transition first error accept ResetSignal then initializing;
        }

        part station : EnvironmentalMonitoringStation {
            attribute stationId = "EMS-001";
            attribute firmwareUrl = "https://open-ems.org/firmware";
            attribute schematicsUrl = "https://open-ems.org/schematics";
            attribute componentListUrl = "https://open-ems.org/bom";

            connection powerInputConn : PowerInterface
                connect externalPower to powerSupply.powerInput;
            connection mcuPowerConn : PowerInterface
                connect powerSupply.mcuPowerOut to microcontroller.powerIn;
            connection tempSensorPowerConn : PowerInterface
                connect powerSupply.sensorPowerOut to temperatureSensor.powerIn;
            connection humiditySensorPowerConn : PowerInterface
                connect powerSupply.sensorPowerOut to humiditySensor.powerIn;
            connection pressureSensorPowerConn : PowerInterface
                connect powerSupply.sensorPowerOut to pressureSensor.powerIn;
            connection displayPowerConn : PowerInterface
                connect powerSupply.displayPowerOut to display.powerIn;
            connection tempDataConn : TemperatureDataInterface
                connect temperatureSensor.dataOut to microcontroller.tempDataIn;
            connection humidityDataConn : HumidityDataInterface
                connect humiditySensor.dataOut to microcontroller.humidityDataIn;
            connection pressureDataConn : PressureDataInterface
                connect pressureSensor.dataOut to microcontroller.pressureDataIn;
            connection displayDataConn : DisplayDataInterface
                connect microcontroller.displayOut to display.dataIn;
        }

        requirement openHardwareReq : OpenHardwareRequirement;
        requirement continuousMonitoringReq : ContinuousMonitoringRequirement;
        requirement powerRegulationReq : PowerRegulationRequirement;
        requirement faultHandlingReq : FaultHandlingRequirement;

        satisfy openHardwareReq by station;
        satisfy continuousMonitoringReq by station;
        satisfy powerRegulationReq by station.powerSupply;
        satisfy faultHandlingReq by station.microcontroller;
    }
}
