package IndoorAirQualitySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CO2Concentration :> Real;
    attribute def VOCConcentration :> Real;
    attribute def ParticulateMatterDensity :> Real;
    attribute def RelativeHumidityPercent :> Real;
    attribute def AirQualityIndexValue :> Integer;
    attribute def FanSpeedPercent :> Real;
    
    enum def SystemMode {
        enum idle;
        enum monitoring;
        enum ventilating;
        enum purifying;
        enum alert;
    }
    
    enum def FilterStatus {
        enum clean;
        enum normal;
        enum dirty;
        enum replace;
    }
    
    item def AirQualityMeasurement {
        attribute co2Level : CO2Concentration;
        attribute vocLevel : VOCConcentration;
        attribute pm25Level : ParticulateMatterDensity;
        attribute humidity : RelativeHumidityPercent;
        attribute temperature : TemperatureValue;
        attribute timestamp : String;
    }
    
    item def ControlCommand {
        attribute ventilationSpeed : FanSpeedPercent;
        attribute purifierActive : Boolean;
        attribute mode : SystemMode;
    }
    
    port def SensorPort {
        out measurement : AirQualityMeasurement;
    }
    
    port def ActuatorPort {
        in command : ControlCommand;
    }
    
    port def DataPort {
        out data : AirQualityMeasurement;
    }
    
    part def MultiSensor {
        doc /* Integrated sensor module measuring CO2, VOC, PM2.5, temperature, and humidity */
        
        attribute co2Reading : CO2Concentration;
        attribute vocReading : VOCConcentration;
        attribute pm25Reading : ParticulateMatterDensity;
        attribute humidityReading : RelativeHumidityPercent;
        attribute temperatureReading : TemperatureValue;
        
        port sensorOutput : SensorPort;
        
        perform action sense {
            out reading : AirQualityMeasurement;
        }
    }
    
    part def VentilationFan {
        doc /* Variable speed ventilation fan for air exchange */
        
        attribute currentSpeed : FanSpeedPercent;
        attribute maxFlowRate : VolumeFlowRateValue;
        attribute powerConsumption : PowerValue;
        
        port controlInput : ActuatorPort;
        
        perform action adjustVentilation {
            in targetSpeed : FanSpeedPercent;
            out actualSpeed : FanSpeedPercent;
        }
    }
    
    part def AirPurifier {
        doc /* HEPA filtration system for particulate removal */
        
        attribute isActive : Boolean;
        attribute filterCondition : FilterStatus;
        attribute filterLifeRemaining : Real;
        attribute purificationRate : VolumeFlowRateValue;
        
        port controlInput : ActuatorPort;
        
        perform action purify {
            in activate : Boolean;
            in airQuality : AirQualityMeasurement;
            out cleanedAir : AirQualityMeasurement;
        }
    }
    
    part def HumidityRegulator {
        doc /* Humidity control system maintaining optimal moisture levels */
        
        attribute targetHumidity : RelativeHumidityPercent;
        attribute currentHumidity : RelativeHumidityPercent;
        attribute isDehumidifying : Boolean;
        
        port controlInput : ActuatorPort;
        
        perform action regulate {
            in currentLevel : RelativeHumidityPercent;
            in targetLevel : RelativeHumidityPercent;
            out adjustedLevel : RelativeHumidityPercent;
        }
    }
    
    part def ControlProcessor {
        doc /* Central processing unit analyzing air quality and issuing control commands */
        
        attribute currentMode : SystemMode;
        attribute qualityIndex : AirQualityIndexValue;
        
        port sensorInput : SensorPort;
        port ventilationControl : ActuatorPort;
        port purifierControl : ActuatorPort;
        port humidityControl : ActuatorPort;
        port dataOutput : DataPort;
        
        perform action processAirQuality;
    }
    
    part def UserInterface {
        doc /* Display and control interface for user interaction */
        
        attribute displayedIndex : AirQualityIndexValue;
        attribute userSetpoint : RelativeHumidityPercent;
        
        port dataInput : DataPort;
        
        perform action displayStatus {
            in measurement : AirQualityMeasurement;
            in index : AirQualityIndexValue;
        }
    }
    
    action def MeasureAirQuality {
        out measurement : AirQualityMeasurement;
    }
    
    action def CalculateAirQualityIndex {
        in measurement : AirQualityMeasurement;
        out index : AirQualityIndexValue;
        out exceedsCO2Threshold : Boolean;
        out exceedsVOCThreshold : Boolean;
        out exceedsPMThreshold : Boolean;
        out exceedsHumidityRange : Boolean;
    }
    
    action def DetermineVentilationSpeed {
        in index : AirQualityIndexValue;
        in co2Level : CO2Concentration;
        out speed : FanSpeedPercent;
    }
    
    action def DeterminePurifierState {
        in pm25Level : ParticulateMatterDensity;
        in vocLevel : VOCConcentration;
        out activate : Boolean;
    }
    
    action def DetermineHumidityAction {
        in currentHumidity : RelativeHumidityPercent;
        in targetHumidity : RelativeHumidityPercent;
        out adjustmentNeeded : Boolean;
    }
    
    action def IssueCommands {
        in ventSpeed : FanSpeedPercent;
        in purifierOn : Boolean;
        in humidityAdjust : Boolean;
        out command : ControlCommand;
    }
    
    action def ManageIndoorAirQuality {
        doc /* Primary control loop for continuous air quality management */
        
        first start;
        then merge continuousControl;
        
        action measure : MeasureAirQuality {
            out measurement : AirQualityMeasurement;
        }
        
        then action calculate : CalculateAirQualityIndex {
            in measurement = measure.measurement;
            out index : AirQualityIndexValue;
            out exceedsCO2Threshold : Boolean;
            out exceedsVOCThreshold : Boolean;
            out exceedsPMThreshold : Boolean;
            out exceedsHumidityRange : Boolean;
        }
        
        then action determineVent : DetermineVentilationSpeed {
            in index = calculate.index;
            in co2Level = measure.measurement.co2Level;
            out speed : FanSpeedPercent;
        }
        
        then action determinePurifier : DeterminePurifierState {
            in pm25Level = measure.measurement.pm25Level;
            in vocLevel = measure.measurement.vocLevel;
            out activate : Boolean;
        }
        
        then action determineHumidity : DetermineHumidityAction {
            in currentHumidity = measure.measurement.humidity;
            in targetHumidity = 50.0;
            out adjustmentNeeded : Boolean;
        }
        
        then decide;
            if calculate.exceedsCO2Threshold or calculate.exceedsVOCThreshold or 
               calculate.exceedsPMThreshold or calculate.exceedsHumidityRange 
            then issueControlCommands;
            else maintainNormalOperation;
        
        action issueControlCommands : IssueCommands {
            in ventSpeed = determineVent.speed;
            in purifierOn = determinePurifier.activate;
            in humidityAdjust = determineHumidity.adjustmentNeeded;
            out command : ControlCommand;
        }
        
        then continuousControl;
        
        action maintainNormalOperation : IssueCommands {
            in ventSpeed = 20.0;
            in purifierOn = false;
            in humidityAdjust = false;
            out command : ControlCommand;
        }
        
        then continuousControl;
    }
    
    part indoorAirQualitySystem : IndoorAirQualitySystemAssembly {
        doc /* 
            The Indoor Air Quality System continuously monitors and maintains healthy indoor 
            air conditions by measuring CO2, volatile organic compounds, particulate matter, 
            temperature, and humidity. Based on real-time analysis, the system automatically 
            controls ventilation, air purification, and humidity regulation to ensure optimal 
            air quality for occupant health, comfort, and productivity.
        */
        
        perform action controlAirQuality[*] ordered references ManageIndoorAirQuality;
        
        part sensors : MultiSensor[3] {
            doc /* Multiple sensors for comprehensive room coverage */
            perform controlAirQuality.measure;
        }
        
        part ventilation : VentilationFan {
            perform controlAirQuality.determineVent;
        }
        
        part purifier : AirPurifier {
            perform controlAirQuality.determinePurifier;
        }
        
        part humidityControl : HumidityRegulator {
            perform controlAirQuality.determineHumidity;
        }
        
        part controller : ControlProcessor {
            perform controlAirQuality.calculate;
            perform controlAirQuality.issueControlCommands;
        }
        
        part display : UserInterface {
            perform action showStatus references UserInterface::displayStatus;
        }
        
        connect sensors.sensorOutput to controller.sensorInput;
        connect controller.ventilationControl to ventilation.controlInput;
        connect controller.purifierControl to purifier.controlInput;
        connect controller.humidityControl to humidityControl.controlInput;
        connect controller.dataOutput to display.dataInput;
    }
    
    part def IndoorAirQualitySystemAssembly;
    
    requirement def AirQualityStandard {
        doc /* Industry standards for acceptable indoor air quality parameters */
        
        subject system : IndoorAirQualitySystemAssembly;
        
        require constraint co2Limit {
            doc /* CO2 concentration shall not exceed 1000 ppm during occupied hours */
        }
        
        require constraint vocLimit {
            doc /* Total VOC concentration shall remain below 500 ppb */
        }
        
        require constraint pm25Limit {
            doc /* PM2.5 particulate matter shall be maintained below 35 μg/m³ */
        }
        
        require constraint humidityRange {
            doc /* Relative humidity shall be maintained between 30% and 60% */
        }
        
        require constraint temperatureRange {
            doc /* Temperature shall be maintained between 20°C and 24°C */
        }
    }
    
    requirement def SystemPerformance {
        doc /* Performance requirements for system operation */
        
        subject system : IndoorAirQualitySystemAssembly;
        
        require constraint responseTime {
            doc /* System shall respond to air quality degradation within 2 minutes */
        }
        
        require constraint measurementAccuracy {
            doc /* Sensor measurements shall be accurate within ±5% of actual values */
        }
        
        require constraint continuousOperation {
            doc /* System shall operate continuously with 99.5% uptime */
        }
        
        require constraint energyEfficiency {
            doc /* System power consumption shall not exceed 150W during normal operation */
        }
    }
    
    requirement healthyIndoorEnvironment : AirQualityStandard {
        doc /* 
            The indoor air quality system shall maintain a healthy and comfortable 
            environment by continuously monitoring multiple air quality parameters and 
            automatically activating appropriate mitigation systems when quality thresholds 
            are exceeded, ensuring occupant health, safety, and productivity.
        */
        
        subject monitoredEnvironment = indoorAirQualitySystem;
        
        assume constraint occupiedSpace {
            doc /* The monitored space is regularly occupied by people during business hours */
        }
        
        assume constraint powerSupply {
            doc /* Continuous electrical power is available to all system components */
        }
        
        assume constraint ventilationAccess {
            doc /* The space has access to outdoor air for ventilation exchange */
        }
        
        require constraint automaticControl {
            doc /* All mitigation systems shall activate automatically without user intervention */
        }
        
        require constraint multiParameterMonitoring {
            doc /* System shall simultaneously monitor CO2, VOC, PM2.5, temperature, and humidity */
        }
        
        require constraint adaptiveResponse {
            doc /* Ventilation and purification intensity shall scale with air quality degradation */
        }
        
        require constraint userNotification {
            doc /* System shall display current air quality index and status to occupants */
        }
        
        require constraint maintenanceAlert {
            doc /* System shall alert when filter replacement or maintenance is required */
        }
    }
    
    requirement systemReliability : SystemPerformance {
        doc /* System shall operate reliably and efficiently under all normal conditions */
        
        subject reliableSystem = indoorAirQualitySystem;
        
        require constraint sensorRedundancy {
            doc /* Multiple sensors shall provide measurement redundancy for critical parameters */
        }
        
        require constraint failsafeOperation {
            doc /* System shall default to maximum ventilation if sensor or control failure occurs */
        }
        
        require constraint dataLogging {
            doc /* System shall log air quality measurements at minimum 1-minute intervals */
        }
    }
}
