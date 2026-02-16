package OperationalDesignDomainSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;
    private import Metaobjects::SemanticMetadata;
    private import ModelingMetadata::*;
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;

    attribute def TemperatureValue :> Real;
    attribute def VelocityValue :> Real;
    attribute def DistanceValue :> Real;
    attribute def IlluminanceValue :> Real;
    attribute def PrecipitationRate :> Real;
    attribute def VisibilityDistance :> Real;
    attribute def AngleValue :> Real;

    enum def WeatherCondition {
        clear;
        cloudy;
        lightRain;
        heavyRain;
        snow;
        fog;
    }

    enum def RoadType {
        highway;
        urbanStreet;
        ruralRoad;
        parkingLot;
    }

    enum def TimeOfDay {
        day;
        dusk;
        night;
        dawn;
    }

    enum def TrafficDensity {
        light;
        moderate;
        heavy;
        congested;
    }

    enum def SystemMode {
        initializing;
        monitoring;
        autonomous;
        degraded;
        manualOverride;
        shutdown;
    }

    attribute def OperationalConditions {
        attribute weatherCondition : WeatherCondition;
        attribute roadType : RoadType;
        attribute timeOfDay : TimeOfDay;
        attribute trafficDensity : TrafficDensity;
        attribute ambientTemperature : TemperatureValue;
        attribute visibility : VisibilityDistance;
        attribute precipitationRate : PrecipitationRate;
        attribute vehicleSpeed : VelocityValue;
        attribute roadCurvature : AngleValue;
    }

    attribute def ODDLimits {
        attribute maxSpeed : VelocityValue;
        attribute minVisibility : VisibilityDistance;
        attribute maxPrecipitation : PrecipitationRate;
        attribute minTemperature : TemperatureValue;
        attribute maxTemperature : TemperatureValue;
        attribute maxRoadCurvature : AngleValue;
        attribute allowedWeather : WeatherCondition[1..*];
        attribute allowedRoadTypes : RoadType[1..*];
        attribute allowedTimeOfDay : TimeOfDay[1..*];
        attribute allowedTrafficDensity : TrafficDensity[1..*];
    }

    item def SensorData {
        attribute weatherData : WeatherCondition;
        attribute temperatureData : TemperatureValue;
        attribute visibilityData : VisibilityDistance;
        attribute roadTypeData : RoadType;
        attribute trafficData : TrafficDensity;
        attribute speedData : VelocityValue;
        attribute curvatureData : AngleValue;
    }

    item def ControlCommand {
        attribute targetSpeed : VelocityValue;
        attribute targetSteering : AngleValue;
        attribute mode : SystemMode;
    }

    port def SensorPort {
        out data : SensorData;
    }

    port def ControlPort {
        in command : ControlCommand;
        out status : SystemMode;
    }

    port def MonitorPort {
        in conditions : OperationalConditions;
        out oddCompliance : Boolean;
    }

    part def EnvironmentalSensor {
        attribute sensorId : String;
        port sensorOutput : SensorPort;
    }

    part def WeatherSensor :> EnvironmentalSensor {
        attribute currentWeather : WeatherCondition;
        attribute temperature : TemperatureValue;
        attribute precipitation : PrecipitationRate;
    }

    part def VisibilitySensor :> EnvironmentalSensor {
        attribute visibilityRange : VisibilityDistance;
        attribute illuminance : IlluminanceValue;
    }

    part def RoadSensor :> EnvironmentalSensor {
        attribute detectedRoadType : RoadType;
        attribute trafficLevel : TrafficDensity;
        attribute curvature : AngleValue;
    }

    part def VehicleSensor {
        attribute currentSpeed : VelocityValue;
        attribute position : DistanceValue;
        port vehicleDataOutput : SensorPort;
    }

    part def ODDMonitor {
        attribute currentConditions : OperationalConditions;
        attribute definedLimits : ODDLimits;
        attribute isWithinODD : Boolean;
        port conditionInput : MonitorPort;
        port statusOutput : MonitorPort;
    }

    part def DecisionController {
        attribute systemMode : SystemMode;
        port monitorInput : MonitorPort;
        port controlOutput : ControlPort;
    }

    part def AutonomousVehicleSystem {
        attribute systemName : String = "Autonomous Vehicle ODD System";
        attribute operationalStatus : SystemMode;

        part weatherSensor : WeatherSensor {
            attribute :>> sensorId = "WS-001";
        }

        part visibilitySensor : VisibilitySensor {
            attribute :>> sensorId = "VS-001";
        }

        part roadSensor : RoadSensor {
            attribute :>> sensorId = "RS-001";
        }

        part vehicleSensor : VehicleSensor {
            attribute :>> currentSpeed;
            attribute :>> position;
        }

        part oddMonitor : ODDMonitor {
            attribute :>> definedLimits : ODDLimits {
                attribute :>> maxSpeed = 120.0;
                attribute :>> minVisibility = 100.0;
                attribute :>> maxPrecipitation = 5.0;
                attribute :>> minTemperature = 268.15;
                attribute :>> maxTemperature = 313.15;
                attribute :>> maxRoadCurvature = 0.1745;
                attribute :>> allowedWeather = (WeatherCondition::clear, WeatherCondition::cloudy, WeatherCondition::lightRain);
                attribute :>> allowedRoadTypes = (RoadType::highway, RoadType::urbanStreet);
                attribute :>> allowedTimeOfDay = (TimeOfDay::day, TimeOfDay::dusk, TimeOfDay::dawn);
                attribute :>> allowedTrafficDensity = (TrafficDensity::light, TrafficDensity::moderate);
            }
        }

        part controller : DecisionController;

        connection weatherData connect weatherSensor.sensorOutput to oddMonitor.conditionInput;
        connection visibilityData connect visibilitySensor.sensorOutput to oddMonitor.conditionInput;
        connection roadData connect roadSensor.sensorOutput to oddMonitor.conditionInput;
        connection vehicleData connect vehicleSensor.vehicleDataOutput to oddMonitor.conditionInput;
        connection monitorStatus connect oddMonitor.statusOutput to controller.monitorInput;
        connection systemControl connect controller.controlOutput to oddMonitor.conditionInput;

        perform action monitorAndControl;
    }

    action def CollectEnvironmentalData {
        out weather : WeatherCondition;
        out temperature : TemperatureValue;
        out visibility : VisibilityDistance;
        out roadType : RoadType;
        out traffic : TrafficDensity;
        out speed : VelocityValue;
        out curvature : AngleValue;
    }

    action def EvaluateODD {
        in conditions : OperationalConditions;
        in limits : ODDLimits;
        out withinODD : Boolean;
    }

    action def DetermineSystemMode {
        in oddStatus : Boolean;
        in currentMode : SystemMode;
        out newMode : SystemMode;
    }

    action def ExecuteAutonomousControl {
        in mode : SystemMode;
        out controlCmd : ControlCommand;
    }

    action monitorAndControl : MonitorAndControlODD {
        first start;
        then merge continuousMonitoring;
        
        then action collectData : CollectEnvironmentalData {
            out weatherData : WeatherCondition;
            out tempData : TemperatureValue;
            out visData : VisibilityDistance;
            out roadData : RoadType;
            out trafficData : TrafficDensity;
            out speedData : VelocityValue;
            out curvatureData : AngleValue;
        }
        
        then action evaluateConditions : EvaluateODD {
            in conditions : OperationalConditions;
            in limits : ODDLimits;
            out withinODD : Boolean;
        }
        
        then decide;
            if evaluateConditions.withinODD then maintainAutonomous;
            if not evaluateConditions.withinODD then degradeOperation;
        
        action maintainAutonomous : DetermineSystemMode {
            in oddStatus = evaluateConditions.withinODD;
            in currentMode : SystemMode;
            out newMode : SystemMode;
        }
        then action executeAutonomous : ExecuteAutonomousControl {
            in mode = maintainAutonomous.newMode;
            out controlCmd : ControlCommand;
        }
        then continuousMonitoring;
        
        action degradeOperation : DetermineSystemMode {
            in oddStatus = evaluateConditions.withinODD;
            in currentMode : SystemMode;
            out newMode : SystemMode;
        }
        then action executeDegraded : ExecuteAutonomousControl {
            in mode = degradeOperation.newMode;
            out controlCmd : ControlCommand;
        }
        then continuousMonitoring;
    }

    action def MonitorAndControlODD;

    constraint def ODDComplianceConstraint {
        in conditions : OperationalConditions;
        in limits : ODDLimits;
        
        conditions.vehicleSpeed <= limits.maxSpeed and
        conditions.visibility >= limits.minVisibility and
        conditions.precipitationRate <= limits.maxPrecipitation and
        conditions.ambientTemperature >= limits.minTemperature and
        conditions.ambientTemperature <= limits.maxTemperature and
        conditions.roadCurvature <= limits.maxRoadCurvature
    }

    requirement def OperationalRequirement;
    requirement operationalRequirements : OperationalRequirement[*] nonunique;

    metadata def operational :> SemanticMetadata {
        :>> baseType = operationalRequirements meta SysML::RequirementUsage;
    }

    requirement <'REQ-ODD-001'> operationalDesignDomainCompliance {
        doc /* The autonomous vehicle system shall operate only within 
             * its defined Operational Design Domain, which specifies 
             * the environmental, geographic, traffic, and operational 
             * conditions under which the system is designed to function safely.
             */
        
        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = high;
                technicalRisk = high;
                scheduleRisk = medium;
                costRisk = medium;
            }
            originator = "Safety Engineering Team";
            owner = "System Architect";
        }
        
        subject avSystem : AutonomousVehicleSystem;
    }

    requirement <'REQ-ODD-002'> environmentalMonitoring {
        doc /* The system shall continuously monitor environmental 
             * conditions including weather, visibility, road type, 
             * traffic density, vehicle speed, and road curvature 
             * to determine ODD compliance.
             */
        
        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = medium;
                technicalRisk = medium;
                scheduleRisk = low;
                costRisk = low;
            }
            originator = "Sensor Integration Team";
            owner = "Software Lead";
        }
        
        subject monitor : ODDMonitor;
    }

    requirement <'REQ-ODD-003'> speedLimit {
        doc /* The system shall not operate autonomously when vehicle 
             * speed exceeds 120 km/h.
             */
        
        subject avSystem : AutonomousVehicleSystem;
        
        assert constraint {
            avSystem.vehicleSensor.currentSpeed <= 120.0
        }
    }

    requirement <'REQ-ODD-004'> visibilityLimit {
        doc /* The system shall not operate autonomously when visibility 
             * is less than 100 meters.
             */
        
        subject avSystem : AutonomousVehicleSystem;
        
        assert constraint {
            avSystem.visibilitySensor.visibilityRange >= 100.0
        }
    }

    requirement <'REQ-ODD-005'> weatherRestriction {
        doc /* The system shall only operate in clear, cloudy, or 
             * light rain weather conditions.
             */
        
        subject avSystem : AutonomousVehicleSystem;
    }

    requirement <'REQ-ODD-006'> systemResponse {
        doc /* The system shall transition to a degraded or manual override 
             * state when conditions fall outside the defined ODD.
             */
        
        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = high;
                technicalRisk = high;
                scheduleRisk = low;
                costRisk = medium;
            }
            originator = "Safety Engineering Team";
            owner = "Control Systems Lead";
        }
        
        subject controller : DecisionController;
    }

    requirement <'REQ-ODD-007'> roadCurvatureLimit {
        doc /* The system shall not operate autonomously on roads with 
             * curvature exceeding 10 degrees (0.1745 radians).
             */
        
        subject avSystem : AutonomousVehicleSystem;
        
        assert constraint {
            avSystem.roadSensor.curvature <= 0.1745
        }
    }

    #operational requirement primaryFunction {
        doc /* The primary function of the Operational Design Domain 
             * system is to continuously monitor environmental and 
             * operational conditions, evaluate them against predefined 
             * safe operating limits, and automatically adjust the 
             * autonomous vehicle's operational state to ensure safe 
             * operation only within validated conditions. The system 
             * enables autonomous driving by maintaining awareness of 
             * the operating environment and enforcing operational boundaries.
             */
        
        assume #operational constraint validSensors {
            doc /* All environmental sensors provide accurate and 
                 * timely data with sufficient reliability.
                 */
        }
        
        require #operational operationalDesignDomainCompliance;
        require #operational environmentalMonitoring;
        require #operational speedLimit;
        require #operational visibilityLimit;
        require #operational weatherRestriction;
        require #operational systemResponse;
        require #operational roadCurvatureLimit;
    }

    part avSystemInstance : AutonomousVehicleSystem;

    satisfy operationalDesignDomainCompliance by avSystemInstance;
    satisfy environmentalMonitoring by avSystemInstance.oddMonitor;
    satisfy speedLimit by avSystemInstance;
    satisfy visibilityLimit by avSystemInstance;
    satisfy weatherRestriction by avSystemInstance;
    satisfy systemResponse by avSystemInstance.controller;
    satisfy roadCurvatureLimit by avSystemInstance;
}
