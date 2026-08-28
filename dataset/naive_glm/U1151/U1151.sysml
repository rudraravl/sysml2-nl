package EnvironmentalMonitoringStation {
    import ISQ::*;
    import SI::*;

    // ---- Value types with units ----
    value def TemperatureValue :> Real {
        :>> unit = 'K';
    }
    value def TemperatureCelsius :> Real {
        :>> unit = '°C';
    }
    value def HumidityPercent :> Real {
        :>> unit = '%';
    }
    value def PressureValue :> Real {
        :>> unit = 'Pa';
    }
    value def VoltageValue :> Real {
        :>> unit = 'V';
    }
    value def CurrentValue :> Real {
        :>> unit = 'A';
    }
    value def FrequencyValue :> Real {
        :>> unit = 'Hz';
    }

    // ---- Item definitions ----
    item def RawTemperature {
        attribute value : TemperatureValue;
    }
    item def RawHumidity {
        attribute value : HumidityPercent;
    }
    item def RawPressure {
        attribute value : PressureValue;
    }
    item def ProcessedTemperature {
        attribute value : TemperatureCelsius;
        attribute timestamp : Time;
        attribute valid : Boolean;
    }
    item def ProcessedHumidity {
        attribute value : HumidityPercent;
        attribute timestamp : Time;
        attribute valid : Boolean;
    }
    item def ProcessedPressure {
        attribute value : PressureValue;
        attribute timestamp : Time;
        attribute valid : Boolean;
    }
    item def DisplayData {
        attribute temperature : TemperatureCelsius;
        attribute humidity : HumidityPercent;
        attribute pressure : PressureValue;
        attribute status : String;
        attribute timestamp : Time;
    }
    item def PowerRail {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    item def StatusMessage {
        attribute code : Integer;
        attribute message : String;
    }

    // ---- Port definitions ----
    port def PowerInPort {
        attribute inVoltage : VoltageValue;
        attribute inCurrent : CurrentValue;
    }
    port def PowerOutPort {
        attribute outVoltage : VoltageValue;
        attribute outCurrent : CurrentValue;
    }
    port def TempDataOutPort {
        out item temp : RawTemperature;
    }
    port def HumidityDataOutPort {
        out item hum : RawHumidity;
    }
    port def PressureDataOutPort {
        out item pres : RawPressure;
    }
    port def TempDataInPort {
        in item temp : RawTemperature;
    }
    port def HumidityDataInPort {
        in item hum : RawHumidity;
    }
    port def PressureDataInPort {
        in item pres : RawPressure;
    }
    port def DisplayDataOutPort {
        out item data : DisplayData;
    }
    port def DisplayDataInPort {
        in item data : DisplayData;
    }
    port def StatusOutPort {
        out item status : StatusMessage;
    }

    // ---- Requirements ----
    requirement def EnvironmentalMonitoringRequirement {
        doc /* The station shall continuously measure and display temperature, humidity, and atmospheric pressure. */
        subject station : EnvironmentalMonitoringStation;
        objective {
            station.measurementActive == true;
        }
    }

    requirement def OpenSourceRequirement {
        doc /* All design schematics, component lists, and firmware shall be publicly available. */
        subject station : EnvironmentalMonitoringStation;
        attribute schematicsPublished : Boolean = true;
        attribute bomPublished : Boolean = true;
        attribute firmwarePublished : Boolean = true;
        constraint { schematicsPublished and bomPublished and firmwarePublished }
    }

    requirement def PowerRegulationRequirement {
        doc /* The power supply shall regulate USB input to required rails. */
        subject psu : PowerSupplyUnit;
        attribute inputVoltage : VoltageValue = 5.0;
        attribute mcuVoltage : VoltageValue = 3.3;
        attribute sensorVoltage : VoltageValue = 3.3;
        attribute displayVoltage : VoltageValue = 5.0;
        constraint { inputVoltage == 5.0 }
    }

    requirement def FaultHandlingRequirement {
        doc /* The system shall enter an error state upon fault and allow reset to resume. */
        subject station : EnvironmentalMonitoringStation;
        constraint { station.canReset == true }
    }

    requirement def MonitoringStationRequirements {
        requirement envReq : EnvironmentalMonitoringRequirement;
        requirement openReq : OpenSourceRequirement;
        requirement powerReq : PowerRegulationRequirement;
        requirement faultReq : FaultHandlingRequirement;
    }

    // ---- Part definitions ----

    part def EnvironmentalMonitoringStation {
        attribute canReset : Boolean = true;
        attribute measurementActive : Boolean;
        attribute openHardwareLicense : String = 'CC-BY-SA 4.0';
        attribute firmwareRepository : String = 'https://github.com/open-env-monitor';

        port powerInput : PowerInPort;

        part microcontroller : Microcontroller;
        part temperatureSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part pressureSensor : PressureSensor;
        part powerSupply : PowerSupplyUnit;
        part display : LCDDisplay;

        connection powerInToPSU connect powerInput to powerSupply.input;
        connection psuToMCU connect powerSupply.mcuOutput to microcontroller.powerPort;
        connection psuToTemp connect powerSupply.sensorOutput to temperatureSensor.powerPort;
        connection psuToHum connect powerSupply.sensorOutput to humiditySensor.powerPort;
        connection psuToPres connect powerSupply.sensorOutput to pressureSensor.powerPort;
        connection psuToDisplay connect powerSupply.displayOutput to display.powerPort;

        connection tempToMCU connect temperatureSensor.dataPort to microcontroller.tempIn;
        connection humToMCU connect humiditySensor.dataPort to microcontroller.humidityIn;
        connection presToMCU connect pressureSensor.dataPort to microcontroller.pressureIn;

        connection mcuToDisplay connect microcontroller.displayOut to display.dataIn;

        satisfy MonitoringStationRequirements by self;

        exhibit state behavior StationStateMachine {
            attribute faultDetected : Boolean = false;
            attribute resetRequested : Boolean = false;

            state init {
                entry {
                    microcontroller.initializeSensors();
                    microcontroller.initializeDisplay();
                    measurementActive = false;
                }
                do {
                    microcontroller.runSelfTest();
                }
                transition init to monitoring
                    when microcontroller.sensorsReady == true
                    if !faultDetected;
                transition init to errorState
                    when faultDetected == true;
            }

            state monitoring {
                entry {
                    measurementActive = true;
                }
                do {
                    microcontroller.acquireSensorData();
                    microcontroller.processMeasurements();
                    microcontroller.updateDisplay();
                }
                transition monitoring to monitoring
                    when microcontroller.acquisitionTimerExpired == true
                    if !faultDetected;
                transition monitoring to errorState
                    when faultDetected == true;
            }

            state errorState {
                entry {
                    measurementActive = false;
                    microcontroller.reportError();
                    display.showError();
                }
                transition errorState to init
                    when resetRequested == true
                    if canReset;
            }
        }
    }

    part def Microcontroller {
        attribute architecture : String = 'AVR-RISC';
        attribute clockFrequency : FrequencyValue = 16e6;
        attribute firmwareVersion : String = 'v1.0.0';
        attribute sensorsReady : Boolean;
        attribute acquisitionTimerExpired : Boolean;

        port powerPort : PowerInPort;
        port tempIn : TempDataInPort;
        port humidityIn : HumidityDataInPort;
        port pressureIn : PressureDataInPort;
        port displayOut : DisplayDataOutPort;
        port statusOut : StatusOutPort;

        private attribute lastTemperature : ProcessedTemperature;
        private attribute lastHumidity : ProcessedHumidity;
        private attribute lastPressure : ProcessedPressure;

        action initializeSensors {
            out sensorsReady : Boolean;
        }
        action initializeDisplay {}
        action runSelfTest {}
        action acquireSensorData {
            in rawTemp : RawTemperature;
            in rawHum : RawHumidity;
            in rawPres : RawPressure;
        }
        action processMeasurements {
            in rawTemp : RawTemperature;
            in rawHum : RawHumidity;
            in rawPres : RawPressure;
            out procTemp : ProcessedTemperature;
            out procHum : ProcessedHumidity;
            out procPres : ProcessedPressure;
        }
        action updateDisplay {
            in procTemp : ProcessedTemperature;
            in procHum : ProcessedHumidity;
            in procPres : ProcessedPressure;
            out data : DisplayData;
        }
        action reportError {
            out status : StatusMessage;
        }

        exhibit state behavior MCUStateMachine {
            state booting {
                entry { sensorsReady = false; }
                transition booting to ready
                    when sensorsReady == true;
            }
            state ready {
                transition ready to acquiring
                    when acquisitionTimerExpired == true;
            }
            state acquiring {
                entry { acquireSensorData(); }
                transition acquiring to processing;
            }
            state processing {
                entry { processMeasurements(); }
                transition processing to displaying;
            }
            state displaying {
                entry { updateDisplay(); }
                transition displaying to ready;
            }
        }
    }

    part def TemperatureSensor {
        attribute sensorType : String = 'DS18B20';
        attribute measurementRangeMin : TemperatureCelsius = -55.0;
        attribute measurementRangeMax : TemperatureCelsius = 125.0;
        attribute accuracy : TemperatureCelsius = 0.5;

        port powerPort : PowerInPort;
        port dataPort : TempDataOutPort;

        action readTemperature {
            out raw : RawTemperature;
        }
    }

    part def HumiditySensor {
        attribute sensorType : String = 'DHT22';
        attribute measurementRangeMin : HumidityPercent = 0.0;
        attribute measurementRangeMax : HumidityPercent = 100.0;
        attribute accuracy : HumidityPercent = 2.0;

        port powerPort : PowerInPort;
        port dataPort : HumidityDataOutPort;

        action readHumidity {
            out raw : RawHumidity;
        }
    }

    part def PressureSensor {
        attribute sensorType : String = 'BMP280';
        attribute measurementRangeMin : PressureValue = 30000.0;
        attribute measurementRangeMax : PressureValue = 110000.0;
        attribute accuracy : PressureValue = 12.0;

        port powerPort : PowerInPort;
        port dataPort : PressureDataOutPort;

        action readPressure {
            out raw : RawPressure;
        }
    }

    part def PowerSupplyUnit {
        attribute inputVoltageNominal : VoltageValue = 5.0;
        attribute mcuRailVoltage : VoltageValue = 3.3;
        attribute sensorRailVoltage : VoltageValue = 3.3;
        attribute displayRailVoltage : VoltageValue = 5.0;
        attribute efficiency : Real = 0.85;

        port input : PowerInPort;
        port mcuOutput : PowerOutPort;
        port sensorOutput : PowerOutPort;
        port displayOutput : PowerOutPort;

        action regulatePower {
            in inputRail : PowerRail;
            out mcuRail : PowerRail;
            out sensorRail : PowerRail;
            out displayRail : PowerRail;
        }

        satisfy PowerRegulationRequirement by self;
    }

    part def LCDDisplay {
        attribute displayType : String = 'LCD 16x2';
        attribute widthChars : Integer = 16;
        attribute heightChars : Integer = 2;
        attribute backlightEnabled : Boolean = true;

        port powerPort : PowerInPort;
        port dataIn : DisplayDataInPort;

        action renderDisplay {
            in data : DisplayData;
        }
        action showError {}
    }
}
