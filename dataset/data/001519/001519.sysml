package OpenHardwareEnvironmentalMonitor {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def HardwareLicense {
        attribute licenseName : String;
        attribute version : String;
        attribute allowsCommercialUse : Boolean;
        attribute requiresAttribution : Boolean;
        attribute sharealike : Boolean;
    }
    
    attribute def FirmwareVersion {
        attribute major : Integer;
        attribute minor : Integer;
        attribute patch : Integer;
    }
    
    item def SensorReading {
        attribute timestamp : Real;
        attribute temperature : TemperatureValue;
        attribute humidity : Real;
        attribute pressure : PressureValue;
    }
    
    item def DisplayData {
        attribute temperatureDisplay : TemperatureValue;
        attribute humidityDisplay : Real;
        attribute pressureDisplay : PressureValue;
        attribute statusMessage : String;
    }
    
    item def PowerSignal {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    port def SensorDataPort {
        out item reading : SensorReading;
    }
    
    port def DisplayPort {
        in item displayInfo : DisplayData;
    }
    
    port def PowerInputPort {
        in item power : PowerSignal;
    }
    
    port def PowerOutputPort {
        out item power : PowerSignal;
    }
    
    part def EnvironmentalSensor {
        attribute sensorType : String;
        attribute measurementRange : Real[2];
        attribute accuracy : Real;
        
        port dataOut : SensorDataPort;
        port powerIn : PowerInputPort;
        
        perform action acquireData : AcquireEnvironmentalData;
    }
    
    part def OpenSourceMicrocontroller {
        attribute processorArchitecture : String;
        attribute clockSpeed : FrequencyValue;
        attribute ramSize : Real;
        attribute flashSize : Real;
        attribute firmware : FirmwareVersion;
        
        port sensorInput : SensorDataPort;
        port displayOutput : DisplayPort;
        port powerIn : PowerInputPort;
        
        perform action processAndDisplay : ProcessSensorData;
    }
    
    part def LCDDisplay {
        attribute screenSize : LengthValue;
        attribute resolution : Integer[2];
        attribute backlight : Boolean;
        
        port dataIn : DisplayPort;
        port powerIn : PowerInputPort;
        
        perform action showData : DisplayInformation;
    }
    
    part def OpenHardwarePowerSupply {
        attribute inputVoltageRange : ElectricPotentialValue[2];
        attribute outputVoltage : ElectricPotentialValue;
        attribute maxOutputCurrent : ElectricCurrentValue;
        attribute efficiency : Real;
        
        port powerOut : PowerOutputPort[*];
        
        perform action regulatePower : RegulatePowerOutput;
    }
    
    action def AcquireEnvironmentalData {
        in attribute samplingRate : FrequencyValue;
        out attribute temperature : TemperatureValue;
        out attribute humidity : Real;
        out attribute pressure : PressureValue;
    }
    
    action def ProcessSensorData {
        in attribute rawReading : SensorReading;
        out attribute processedDisplay : DisplayData;
        
        first start;
        then action validateData {
            in reading = rawReading;
            out validReading : SensorReading;
        }
        then action formatForDisplay {
            in validData = validateData.validReading;
            out formattedData : DisplayData;
        }
        then assign processedDisplay := formatForDisplay.formattedData;
        then done;
    }
    
    action def DisplayInformation {
        in attribute displayContent : DisplayData;
    }
    
    action def RegulatePowerOutput {
        in attribute inputVoltage : ElectricPotentialValue;
        out attribute regulatedVoltage : ElectricPotentialValue;
        out attribute outputCurrent : ElectricCurrentValue;
    }
    
    action def MonitorEnvironmentContinuously {
        in attribute updateInterval : TimeValue;
        out attribute currentReading : SensorReading;
        out attribute displayOutput : DisplayData;
        
        first start;
        then merge loopStart;
        
        action acquire : AcquireEnvironmentalData {
            in samplingRate = 1.0;
            out temperature;
            out humidity;
            out pressure;
        }
        
        then action packageReading {
            private attribute tempReading : SensorReading {
                attribute timestamp = 0.0;
                attribute temperature = acquire.temperature;
                attribute humidity = acquire.humidity;
                attribute pressure = acquire.pressure;
            }
        }
        
        then assign currentReading := packageReading.tempReading;
        
        then action process : ProcessSensorData {
            in rawReading = currentReading;
            out processedDisplay;
        }
        
        then assign displayOutput := process.processedDisplay;
        then loopStart;
    }
    
    state machine def MonitorOperationStates {
        entry; then powerOn;
        
        state powerOn {
            entry assign systemStatus = "Powering On";
        }
        transition powerOn_to_initializing
            first powerOn
            then initializing;
        
        state initializing {
            entry assign systemStatus = "Initializing Sensors";
        }
        transition initializing_to_monitoring
            first initializing
            then monitoring;
        
        state monitoring {
            entry assign systemStatus = "Active Monitoring";
            
            state acquiring;
            state processing;
            state displaying;
            
            transition acquiring_to_processing
                first acquiring
                then processing;
            
            transition processing_to_displaying
                first processing
                then displaying;
            
            transition displaying_to_acquiring
                first displaying
                then acquiring;
        }
        
        transition monitoring_to_error
            first monitoring
            accept ErrorEvent
            then error;
        
        state error {
            entry assign systemStatus = "Error State";
        }
        
        transition error_to_initializing
            first error
            accept ResetEvent
            then initializing;
        
        attribute systemStatus : String;
    }
    
    requirement def OpenHardwareCompliance {
        doc /* All hardware components shall be based on open hardware designs with 
               publicly available schematics, PCB layouts, and bill of materials under 
               an approved open hardware license. */
        
        require constraint designFilesAvailable {
            doc /* Complete design files must be available in editable formats. */
        }
        
        require constraint bomPublished {
            doc /* Bill of materials with part numbers and suppliers must be publicly accessible. */
        }
        
        require constraint licenseCompliant {
            doc /* All designs must use OSI-approved open hardware licenses. */
        }
    }
    
    requirement def SystemFunctionRequirement {
        doc /* The system shall continuously monitor environmental conditions and 
               display real-time temperature, humidity, and pressure readings. */
        
        require constraint continuousMonitoring {
            doc /* System shall acquire sensor data at minimum 1 Hz rate. */
        }
        
        require constraint displayUpdate {
            doc /* Display shall update within 100ms of new sensor data availability. */
        }
        
        require constraint measurementAccuracy {
            doc /* Temperature accuracy ±0.5°C, humidity ±3%, pressure ±1 hPa. */
        }
    }
    
    requirement def PowerRequirement {
        doc /* The system shall operate from standard USB power supply (5V DC). */
        
        require constraint inputVoltage {
            doc /* Input voltage shall be 5V ±5%. */
        }
        
        require constraint powerConsumption {
            doc /* Total system power consumption shall not exceed 2.5W. */
        }
        
        require constraint powerEfficiency {
            doc /* Power supply efficiency shall be minimum 85%. */
        }
    }
    
    part openHardwareMonitor : OpenHardwareEnvironmentalMonitor {
        doc /* An open hardware environmental monitoring system that continuously measures 
               temperature, humidity, and atmospheric pressure, then displays the readings 
               on an LCD screen. The system is built entirely from open hardware components 
               with publicly available designs, enabling community modification, improvement, 
               and replication. All hardware schematics, PCB layouts, firmware source code, 
               and documentation are released under open licenses to promote transparency, 
               education, and collaborative development. */
        
        attribute hardwareLicense : HardwareLicense {
            attribute licenseName = "CERN Open Hardware License";
            attribute version = "2.0-S";
            attribute allowsCommercialUse = true;
            attribute requiresAttribution = true;
            attribute sharealike = true;
        }
        
        attribute updateRate : TimeValue = 1.0;
        
        part temperatureSensor : EnvironmentalSensor {
            attribute sensorType = "DHT22";
            attribute measurementRange = (-40.0, 80.0);
            attribute accuracy = 0.5;
        }
        
        part humiditySensor : EnvironmentalSensor {
            attribute sensorType = "DHT22";
            attribute measurementRange = (0.0, 100.0);
            attribute accuracy = 2.0;
        }
        
        part pressureSensor : EnvironmentalSensor {
            attribute sensorType = "BMP280";
            attribute measurementRange = (300.0, 1100.0);
            attribute accuracy = 1.0;
        }
        
        part controller : OpenSourceMicrocontroller {
            attribute processorArchitecture = "AVR ATmega328P";
            attribute clockSpeed = 16000000.0;
            attribute ramSize = 2048.0;
            attribute flashSize = 32768.0;
            attribute firmware : FirmwareVersion {
                attribute major = 1;
                attribute minor = 2;
                attribute patch = 3;
            }
            
            perform action dataProcessing : ProcessSensorData;
        }
        
        part display : LCDDisplay {
            attribute screenSize = 0.0508;
            attribute resolution = (128, 64);
            attribute backlight = true;
            
            perform action rendering : DisplayInformation;
        }
        
        part powerSupply : OpenHardwarePowerSupply {
            attribute inputVoltageRange = (4.75, 5.25);
            attribute outputVoltage = 5.0;
            attribute maxOutputCurrent = 0.5;
            attribute efficiency = 0.87;
        }
        
        connection powerToController connect powerSupply.powerOut to controller.powerIn;
        connection powerToDisplay connect powerSupply.powerOut to display.powerIn;
        connection powerToTempSensor connect powerSupply.powerOut to temperatureSensor.powerIn;
        connection powerToHumiditySensor connect powerSupply.powerOut to humiditySensor.powerIn;
        connection powerToPressureSensor connect powerSupply.powerOut to pressureSensor.powerIn;
        
        connection tempDataFlow connect temperatureSensor.dataOut to controller.sensorInput;
        connection humidityDataFlow connect humiditySensor.dataOut to controller.sensorInput;
        connection pressureDataFlow connect pressureSensor.dataOut to controller.sensorInput;
        
        connection displayDataFlow connect controller.displayOutput to display.dataIn;
        
        perform action mainOperation : MonitorEnvironmentContinuously {
            in updateInterval = updateRate;
            out currentReading;
            out displayOutput;
        }
        
        exhibit state operationalBehavior : MonitorOperationStates;
        
        satisfy hwCompliance : OpenHardwareCompliance;
        satisfy funcReq : SystemFunctionRequirement;
        satisfy pwrReq : PowerRequirement;
    }
    
    part def OpenHardwareEnvironmentalMonitor {
        doc /* Primary function: Continuously acquire environmental sensor data (temperature, 
               humidity, atmospheric pressure) using open hardware sensors and microcontroller, 
               process the measurements, and display real-time readings on an LCD screen. The 
               system provides accessible environmental monitoring capabilities while maintaining 
               complete design transparency through open hardware licensing, enabling users to 
               study, modify, manufacture, and distribute the design freely. */
    }
}
