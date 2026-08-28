package ODDManagement {
    import ScalarValues::*;
    import ScalarFunctions::*;
    import ISQ::*;

    // ============================================================
    // Value Types
    // ============================================================
    value type SpeedValue :> Real { unit 'km/h'; }
    value type DistanceValue :> Real { unit 'm'; }
    value type TemperatureValue :> Real { unit 'degC'; }

    item def WeatherCondition :> ScalarValues::EnumeratedValue {
        enum literal Clear;
        enum literal Cloudy;
        enum literal LightRain;
        enum literal HeavyRain;
        enum literal Fog;
        enum literal Snow;
    }

    item def RoadType :> ScalarValues::EnumeratedValue {
        enum literal Highway;
        enum literal UrbanStreet;
        enum literal RuralRoad;
        enum literal OffRoad;
    }

    item def TrafficDensity :> ScalarValues::EnumeratedValue {
        enum literal Light;
        enum literal Moderate;
        enum literal Heavy;
        enum literal Congested;
    }

    item def CurveSharpness :> ScalarValues::EnumeratedValue {
        enum literal Straight;
        enum literal Gentle;
        enum literal Sharp;
        enum literal VerySharp;
    }

    item def DrivingMode :> ScalarValues::EnumeratedValue {
        enum literal Autonomous;
        enum literal Degraded;
        enum literal ManualOverride;
    }

    // ============================================================
    // Item Definitions (data carried on flows)
    // ============================================================
    item def WeatherData {
        attribute condition : WeatherCondition;
        attribute temperature : TemperatureValue;
    }

    item def VisibilityData {
        attribute distance : DistanceValue;
    }

    item def RoadData {
        attribute roadType : RoadType;
        attribute traffic : TrafficDensity;
        attribute curve : CurveSharpness;
    }

    item def VehicleData {
        attribute speed : SpeedValue;
    }

    item def ODDStatus {
        attribute withinLimits : Boolean;
        attribute violatedCondition : String;
        attribute timestamp : String;
    }

    item def ModeCommand {
        attribute mode : DrivingMode;
        attribute reason : String;
    }

    // ============================================================
    // Operational Limits (configuration)
    // ============================================================
    part def ODDLimits {
        attribute maxSpeed : SpeedValue = 120;
        attribute minVisibility : DistanceValue = 100;
        attribute minTemperature : TemperatureValue = -10;
        attribute maxTemperature : TemperatureValue = 45;
        attribute allowedWeather : WeatherCondition[0..*] = (WeatherCondition::Clear, WeatherCondition::Cloudy, WeatherCondition::LightRain);
        attribute allowedRoads : RoadType[0..*] = (RoadType::Highway, RoadType::UrbanStreet);
        attribute allowedTraffic : TrafficDensity[0..*] = (TrafficDensity::Light, TrafficDensity::Moderate);
        attribute allowedCurves : CurveSharpness[0..*] = (CurveSharpness::Straight, CurveSharpness::Gentle);
    }

    // ============================================================
    // Sensors
    // ============================================================
    part def WeatherSensor {
        out port weatherOut : WeatherData;
        attribute condition : WeatherCondition = WeatherCondition::Clear;
        attribute temperature : TemperatureValue = 20;
        action def senseWeather {
            out data : WeatherData;
            perform {
                data.condition := self.condition;
                data.temperature := self.temperature;
            }
        }
        action senseWeather();
    }

    part def VisibilitySensor {
        out port visibilityOut : VisibilityData;
        attribute distance : DistanceValue = 200;
        action def senseVisibility {
            out data : VisibilityData;
            perform { data.distance := self.distance; }
        }
        action senseVisibility();
    }

    part def RoadSensor {
        out port roadOut : RoadData;
        attribute roadType : RoadType = RoadType::Highway;
        attribute traffic : TrafficDensity = TrafficDensity::Light;
        attribute curve : CurveSharpness = CurveSharpness::Straight;
        action def senseRoad {
            out data : RoadData;
            perform {
                data.roadType := self.roadType;
                data.traffic := self.traffic;
                data.curve := self.curve;
            }
        }
        action senseRoad();
    }

    part def VehicleSensor {
        out port vehicleOut : VehicleData;
        attribute speed : SpeedValue = 0;
        action def senseVehicle {
            out data : VehicleData;
            perform { data.speed := self.speed; }
        }
        action senseVehicle();
    }

    // ============================================================
    // ODD Monitor
    // ============================================================
    part def ODDMonitor {
        in port weatherIn : WeatherData;
        in port visibilityIn : VisibilityData;
        in port roadIn : RoadData;
        in port vehicleIn : VehicleData;
        out port statusOut : ODDStatus;

        attribute limits : ODDLimits;

        attribute lastStatus : ODDStatus;

        action def evaluateConditions {
            in weather : WeatherData;
            in visibility : VisibilityData;
            in road : RoadData;
            in vehicle : VehicleData;
            out status : ODDStatus;
            private attribute violations : String[0..*];

            perform {
                if vehicle.speed > limits.maxSpeed then
                    violations := violations.append("Speed exceeds maximum");
                if visibility.distance < limits.minVisibility then
                    violations := violations.append("Visibility below minimum");
                if not limits.allowedWeather.contains(weather.condition) then
                    violations := violations.append("Weather condition not permitted");
                if weather.temperature < limits.minTemperature then
                    violations := violations.append("Temperature below minimum");
                if weather.temperature > limits.maxTemperature then
                    violations := violations.append("Temperature above maximum");
                if not limits.allowedRoads.contains(road.roadType) then
                    violations := violations.append("Road type not permitted");
                if not limits.allowedTraffic.contains(road.traffic) then
                    violations := violations.append("Traffic density too high");
                if not limits.allowedCurves.contains(road.curve) then
                    violations := violations.append("Curve sharpness not permitted");

                if violations.isEmpty() then {
                    status.withinLimits := true;
                    status.violatedCondition := "None";
                } else {
                    status.withinLimits := false;
                    status.violatedCondition := violations.first();
                }
            }
        }

        action evaluateConditions();

        state def ODDMonitorBehavior {
            entry; then Monitoring;
            state Monitoring {
                entry {
                    self.evaluateConditions(
                        in weather = weatherIn,
                        in visibility = visibilityIn,
                        in road = roadIn,
                        in vehicle = vehicleIn,
                        out status = lastStatus
                    );
                    statusOut.send(lastStatus);
                }
                do {
                    self.evaluateConditions(
                        in weather = weatherIn,
                        in visibility = visibilityIn,
                        in road = roadIn,
                        in vehicle = vehicleIn,
                        out status = lastStatus
                    );
                    statusOut.send(lastStatus);
                }
            }
        }

        exhibit ODDMonitorBehavior();
    }

    // ============================================================
    // Decision Controller
    // ============================================================
    part def DecisionController {
        in port statusIn : ODDStatus;
        out port modeOut : ModeCommand;

        attribute currentMode : DrivingMode = DrivingMode::Autonomous;
        attribute violationCount : Integer = 0;
        attribute violationThreshold : Integer = 1;

        action def decideMode {
            in status : ODDStatus;
            out command : ModeCommand;
            perform {
                if status.withinLimits then {
                    if currentMode != DrivingMode::Autonomous then {
                        currentMode := DrivingMode::Autonomous;
                        command.mode := DrivingMode::Autonomous;
                        command.reason := "Conditions returned to safe limits";
                        violationCount := 0;
                    } else {
                        command.mode := DrivingMode::Autonomous;
                        command.reason := "Maintaining autonomous mode";
                    }
                } else {
                    violationCount := violationCount + 1;
                    if violationCount >= violationThreshold then {
                        if status.violatedCondition == "Speed exceeds maximum" or
                           status.violatedCondition == "Visibility below minimum" then {
                            currentMode := DrivingMode::ManualOverride;
                            command.mode := DrivingMode::ManualOverride;
                            command.reason := status.violatedCondition;
                        } else {
                            currentMode := DrivingMode::Degraded;
                            command.mode := DrivingMode::Degraded;
                            command.reason := status.violatedCondition;
                        }
                    } else {
                        command.mode := currentMode;
                        command.reason := "Tolerating transient violation";
                    }
                }
            }
        }

        action decideMode();

        state def DecisionControllerBehavior {
            entry; then AutonomousMode;
            state AutonomousMode {
                entry { modeOut.send(ModeCommand(mode => DrivingMode::Autonomous, reason => "Initial autonomous mode")); }
                transition to DegradedMode
                    when statusIn.receive().withinLimits == false and
                         statusIn.receive().violatedCondition != "Speed exceeds maximum" and
                         statusIn.receive().violatedCondition != "Visibility below minimum";
                transition to ManualOverrideMode
                    when statusIn.receive().withinLimits == false and
                         (statusIn.receive().violatedCondition == "Speed exceeds maximum" or
                          statusIn.receive().violatedCondition == "Visibility below minimum");
            }
            state DegradedMode {
                entry { modeOut.send(ModeCommand(mode => DrivingMode::Degraded, reason => "Degraded due to ODD violation")); }
                transition to AutonomousMode
                    when statusIn.receive().withinLimits == true;
                transition to ManualOverrideMode
                    when statusIn.receive().withinLimits == false and
                         (statusIn.receive().violatedCondition == "Speed exceeds maximum" or
                          statusIn.receive().violatedCondition == "Visibility below minimum");
            }
            state ManualOverrideMode {
                entry { modeOut.send(ModeCommand(mode => DrivingMode::ManualOverride, reason => "Manual override due to critical ODD violation")); }
                transition to AutonomousMode
                    when statusIn.receive().withinLimits == true;
            }
        }

        exhibit DecisionControllerBehavior();
    }

    // ============================================================
    // Vehicle Interface (actuator side)
    // ============================================================
    part def VehicleController {
        in port modeIn : ModeCommand;
        attribute activeMode : DrivingMode = DrivingMode::Autonomous;
        action def applyMode {
            in cmd : ModeCommand;
            perform {
                activeMode := cmd.mode;
            }
        }
        action applyMode();
        state def VehicleControllerBehavior {
            entry; then Idle;
            state Idle {
                transition to Active when modeIn.receive().mode == DrivingMode::Autonomous;
                transition to Degraded when modeIn.receive().mode == DrivingMode::Degraded;
                transition to Manual when modeIn.receive().mode == DrivingMode::ManualOverride;
            }
            state Active {
                entry { self.applyMode(in cmd = modeIn.receive()); }
                transition to Degraded when modeIn.receive().mode == DrivingMode::Degraded;
                transition to Manual when modeIn.receive().mode == DrivingMode::ManualOverride;
            }
            state Degraded {
                entry { self.applyMode(in cmd = modeIn.receive()); }
                transition to Active when modeIn.receive().mode == DrivingMode::Autonomous;
                transition to Manual when modeIn.receive().mode == DrivingMode::ManualOverride;
            }
            state Manual {
                entry { self.applyMode(in cmd = modeIn.receive()); }
                transition to Active when modeIn.receive().mode == DrivingMode::Autonomous;
            }
        }
        exhibit VehicleControllerBehavior();
    }

    // ============================================================
    // ODD Management System (top-level assembly)
    // ============================================================
    part def ODDManagementSystem {
        part weatherSensor : WeatherSensor;
        part visibilitySensor : VisibilitySensor;
        part roadSensor : RoadSensor;
        part vehicleSensor : VehicleSensor;
        part monitor : ODDMonitor {
            attribute limits : ODDLimits = ODDLimits();
        }
        part controller : DecisionController;
        part vehicleController : VehicleController;

        connection weatherSensor.weatherOut to monitor.weatherIn;
        connection visibilitySensor.visibilityOut to monitor.visibilityIn;
        connection roadSensor.roadOut to monitor.roadIn;
        connection vehicleSensor.vehicleOut to monitor.vehicleIn;
        connection monitor.statusOut to controller.statusIn;
        connection controller.modeOut to vehicleController.modeIn;

        action def runCycle {
            perform {
                weatherSensor.senseWeather();
                visibilitySensor.senseVisibility();
                roadSensor.senseRoad();
                vehicleSensor.senseVehicle();
            }
        }
        action runCycle();
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def ODDSafetyRequirement {
        doc "The autonomous vehicle shall operate in self-driving mode only within predefined safe environmental and driving conditions.";
    }

    requirement def SpeedLimitRequirement :> ODDSafetyRequirement {
        doc "The system shall only permit autonomous mode when vehicle speed is below 120 km/h.";
        attribute maxSpeed : SpeedValue = 120;
        subject self : ODDManagementSystem;
        require { self.monitor.limits.maxSpeed == maxSpeed; }
    }

    requirement def VisibilityRequirement :> ODDSafetyRequirement {
        doc "The system shall only permit autonomous mode when forward visibility is at least 100 m.";
        attribute minVisibility : DistanceValue = 100;
        subject self : ODDManagementSystem;
        require { self.monitor.limits.minVisibility == minVisibility; }
    }

    requirement def WeatherRequirement :> ODDSafetyRequirement {
        doc "The system shall only permit autonomous mode in clear, cloudy, or light rain conditions.";
        subject self : ODDManagementSystem;
        require {
            self.monitor.limits.allowedWeather == (WeatherCondition::Clear, WeatherCondition::Cloudy, WeatherCondition::LightRain);
        }
    }

    requirement def RoadRequirement :> ODDSafetyRequirement {
        doc "The system shall only permit autonomous mode on highways or urban streets with light to moderate traffic.";
        subject self : ODDManagementSystem;
        require {
            self.monitor.limits.allowedRoads == (RoadType::Highway, RoadType::UrbanStreet) and
            self.monitor.limits.allowedTraffic == (TrafficDensity::Light, TrafficDensity::Moderate);
        }
    }

    requirement def DegradationRequirement :> ODDSafetyRequirement {
        doc "If any ODD condition is violated, the system shall transition to degraded or manual override mode.";
        subject self : ODDManagementSystem;
        require {
            (self.monitor.statusOut.receive().withinLimits == false) implies
            (self.controller.modeOut.receive().mode != DrivingMode::Autonomous);
        }
    }

    requirement def RecoveryRequirement :> ODDSafetyRequirement {
        doc "When all ODD conditions return within limits, the system shall be capable of returning to autonomous mode.";
        subject self : ODDManagementSystem;
        require {
            (self.monitor.statusOut.receive().withinLimits == true) implies
            (self.controller.modeOut.receive().mode == DrivingMode::Autonomous);
        }
    }

    requirement package ODDRequirements {
        requirement oddSafety : ODDSafetyRequirement;
        requirement speedLimit : SpeedLimitRequirement;
        requirement visibility : VisibilityRequirement;
        requirement weather : WeatherRequirement;
        requirement road : RoadRequirement;
        requirement degradation : DegradationRequirement;
        requirement recovery : RecoveryRequirement;
    }

    // ============================================================
    // Verification
    // ============================================================
    verification def VerifySpeedLimit {
        subject system : ODDManagementSystem;
        objective {
            doc "Confirm autonomous mode disengages when speed exceeds 120 km/h.";
        }
        perform {
            system.vehicleSensor.speed := 130;
            system.runCycle();
            assert system.controller.modeOut.receive().mode != DrivingMode::Autonomous;
        }
    }

    verification def VerifyVisibility {
        subject system : ODDManagementSystem;
        objective {
            doc "Confirm autonomous mode disengages when visibility drops below 100 m.";
        }
        perform {
            system.visibilitySensor.distance := 50;
            system.runCycle();
            assert system.controller.modeOut.receive().mode != DrivingMode::Autonomous;
        }
    }

    verification def VerifyRecovery {
        subject system : ODDManagementSystem;
        objective {
            doc "Confirm autonomous mode resumes when conditions return to safe limits.";
        }
        perform {
            system.weatherSensor.condition := WeatherCondition::HeavyRain;
            system.runCycle();
            assert system.controller.modeOut.receive().mode != DrivingMode::Autonomous;
            system.weatherSensor.condition := WeatherCondition::Clear;
            system.runCycle();
            assert system.controller.modeOut.receive().mode == DrivingMode::Autonomous;
        }
    }
}
