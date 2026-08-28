package ODDManagementSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        attribute def WeatherCondition : String;
        attribute def RoadType : String;
        attribute def TrafficDensity : String;
        attribute def DrivingMode : String;

        attribute def ODDViolation;
        attribute def ODDCompliant;
        attribute def ManualOverrideRequest;
        attribute def ResumeAutonomous;

        port def WeatherDataPort {
            out condition : WeatherCondition;
            out temperature : TemperatureValue;
        }
        port def VisibilityDataPort {
            out range : LengthValue;
        }
        port def RoadDataPort {
            out roadType : RoadType;
            out traffic : TrafficDensity;
            out curveSharpness : Real;
        }
        port def VehicleDataPort {
            out speed : SpeedValue;
        }
        port def ODDStatusPort {
            out status : String;
        }
        port def ModeCommandPort {
            out mode : DrivingMode;
        }

        action def SenseWeather {
            out condition : WeatherCondition;
            out temperature : TemperatureValue;
        }
        action def SenseVisibility {
            out range : LengthValue;
        }
        action def SenseRoad {
            out roadType : RoadType;
            out traffic : TrafficDensity;
            out curveSharpness : Real;
        }
        action def SenseSpeed {
            out speed : SpeedValue;
        }
        action def EvaluateODD {
            in condition : WeatherCondition;
            in temperature : TemperatureValue;
            in range : LengthValue;
            in roadType : RoadType;
            in traffic : TrafficDensity;
            in curveSharpness : Real;
            in speed : SpeedValue;
            out status : String;
        }

        part def WeatherSensor {
            port out dataPort : WeatherDataPort;
            perform action senseWeather : SenseWeather;
        }
        part def VisibilitySensor {
            port out dataPort : VisibilityDataPort;
            perform action senseVisibility : SenseVisibility;
        }
        part def RoadSensor {
            port out dataPort : RoadDataPort;
            perform action senseRoad : SenseRoad;
        }
        part def VehicleSensor {
            port out dataPort : VehicleDataPort;
            perform action senseSpeed : SenseSpeed;
        }

        part def ODDMonitor {
            port in weatherIn : WeatherDataPort;
            port in visibilityIn : VisibilityDataPort;
            port in roadIn : RoadDataPort;
            port in vehicleIn : VehicleDataPort;
            port out statusOut : ODDStatusPort;

            attribute maxSpeed : SpeedValue = 120 [km/h];
            attribute minVisibility : LengthValue = 100 [m];

            perform action evaluateODD : EvaluateODD;
        }

        state def ControllerStates {
            entry; then autonomous;
            state autonomous;
            accept ODDViolation then degraded;
            state degraded;
            accept ODDCompliant then autonomous;
            accept ManualOverrideRequest then manualOverride;
            state manualOverride;
            accept ResumeAutonomous then autonomous;
        }

        part def DecisionController {
            port in statusIn : ODDStatusPort;
            port out modeOut : ModeCommandPort;
            exhibit state controllerStates : ControllerStates;
        }

        part def AutonomousVehicle {
            part weatherSensor : WeatherSensor;
            part visibilitySensor : VisibilitySensor;
            part roadSensor : RoadSensor;
            part vehicleSensor : VehicleSensor;
            part oddMonitor : ODDMonitor;
            part decisionController : DecisionController;

            connect weatherSensor.dataPort to oddMonitor.weatherIn;
            connect visibilitySensor.dataPort to oddMonitor.visibilityIn;
            connect roadSensor.dataPort to oddMonitor.roadIn;
            connect vehicleSensor.dataPort to oddMonitor.vehicleIn;
            connect oddMonitor.statusOut to decisionController.statusIn;
        }
    }

    part autonomousVehicle : AutonomousVehicle;

    package Requirements {
        private import Definitions::*;

        requirement def SafeSpeedRequirement {
            doc /* The autonomous system shall only operate when vehicle speed is below 120 km/h. */
            attribute limit : SpeedValue = 120 [km/h];
            subject speed : SpeedValue;
            requirement {
                constraint { speed <= limit }
            }
        }

        requirement def SafeVisibilityRequirement {
            doc /* The autonomous system shall only operate when visibility exceeds 100 meters. */
            attribute limit : LengthValue = 100 [m];
            subject visibility : LengthValue;
            requirement {
                constraint { visibility >= limit }
            }
        }

        requirement def SafeWeatherRequirement {
            doc /* The autonomous system shall only operate in clear, cloudy, or light rain conditions. */
            subject weather : WeatherCondition;
            requirement {
                constraint { weather == "clear" or weather == "cloudy" or weather == "lightRain" }
            }
        }

        requirement def SafeRoadTypeRequirement {
            doc /* The autonomous system shall only operate on highways or urban streets. */
            subject roadType : RoadType;
            requirement {
                constraint { roadType == "highway" or roadType == "urbanStreet" }
            }
        }

        requirement def SafeTrafficRequirement {
            doc /* The autonomous system shall only operate in light to moderate traffic. */
            subject traffic : TrafficDensity;
            requirement {
                constraint { traffic == "light" or traffic == "moderate" }
            }
        }

        requirement def SafeDegradationRequirement {
            doc /* Upon ODD violation, the system shall disengage autonomous mode and transition to degraded or manual override. */
            subject vehicle : AutonomousVehicle;
        }

        requirement 'Speed Limit Satisfaction' : SafeSpeedRequirement {
            subject speed = autonomousVehicle.oddMonitor.vehicleIn.speed;
        }
        requirement 'Visibility Limit Satisfaction' : SafeVisibilityRequirement {
            subject visibility = autonomousVehicle.oddMonitor.visibilityIn.range;
        }
        requirement 'Weather Condition Satisfaction' : SafeWeatherRequirement {
            subject weather = autonomousVehicle.oddMonitor.weatherIn.condition;
        }
        requirement 'Road Type Satisfaction' : SafeRoadTypeRequirement {
            subject roadType = autonomousVehicle.oddMonitor.roadIn.roadType;
        }
        requirement 'Traffic Density Satisfaction' : SafeTrafficRequirement {
            subject traffic = autonomousVehicle.oddMonitor.roadIn.traffic;
        }
    }
}
