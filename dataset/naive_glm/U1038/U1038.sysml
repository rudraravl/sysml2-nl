package DomusIntelligentHomeSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    value def TemperatureValue :> Real { unit = 'degC'; }
    value def HumidityValue :> Real { unit = '%'; }
    value def AirQualityValue :> Real { unit = 'ppm'; }
    value def PowerValue :> Real { unit = 'W'; }
    value def EnergyValue :> Real { unit = 'kWh'; }
    value def LightIntensityValue :> Real { unit = 'lux'; }
    value def DimmingLevel :> Real { min = 0; max = 100; unit = '%'; }
    value def OccupancyCount :> Integer { min = 0; }

    // ---------- Enumerations ----------
    enum def OccupancyState { values occupied; unoccupied; }
    enum def SecurityMode { values disarmed; monitoring; armed; }
    enum def SystemMode { values active; away; night; }
    enum def DoorState { values open; closed; }
    enum def MotionState { values motion; noMotion; }

    // ---------- Item Types ----------
    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute zoneId : String;
    }
    item def HumidityReading {
        attribute value : HumidityValue;
        attribute zoneId : String;
    }
    item def AirQualityReading {
        attribute value : AirQualityValue;
        attribute zoneId : String;
    }
    item def OccupancyReading {
        attribute state : OccupancyState;
        attribute count : OccupancyCount;
        attribute zoneId : String;
    }
    item def LightLevelReading {
        attribute value : LightIntensityValue;
        attribute zoneId : String;
    }
    item def MotionReading {
        attribute state : MotionState;
        attribute zoneId : String;
    }
    item def DoorReading {
        attribute state : DoorState;
        attribute sensorId : String;
    }
    item def PowerReading {
        attribute value : PowerValue;
        attribute subsystemId : String;
    }
    item def ClimateCommand {
        attribute zoneId : String;
        attribute targetTemp : TemperatureValue;
        attribute enabled : Boolean;
    }
    item def LightingCommand {
        attribute zoneId : String;
        attribute dimmingLevel : DimmingLevel;
        attribute enabled : Boolean;
    }
    item def SecurityCommand {
        attribute mode : SecurityMode;
    }
    item def EnergyReport {
        attribute totalPower : PowerValue;
        attribute periodEnergy : EnergyValue;
    }

    // ---------- Port Definitions ----------
    port def SensorOut {
        out temp : TemperatureReading;
        out humidity : HumidityReading;
        out airQuality : AirQualityReading;
        out occupancy : OccupancyReading;
        out lightLevel : LightLevelReading;
    }
    port def MotionSensorOut {
        out motion : MotionReading;
    }
    port def DoorSensorOut {
        out door : DoorReading;
    }
    port def CameraOut {
        out motion : MotionReading;
        out streamId : String;
    }
    port def ControllerCmdOut {
        out climateCmd : ClimateCommand;
        out lightingCmd : LightingCommand;
        out securityCmd : SecurityCommand;
    }
    port def PowerReportOut {
        out power : PowerReading;
        out energy : EnergyReport;
    }
    port def ControllerDataIn {
        in sensorData : SensorOut;
        in motionData : MotionSensorOut;
        in doorData : DoorSensorOut;
        in cameraData : CameraOut;
        in powerData : PowerReportOut;
    }

    // ---------- Sensor Parts ----------
    part def EnvironmentalSensor {
        attribute zoneId : String;
        port sensorOut : SensorOut;
        attribute currentTemp : TemperatureValue = 22.0;
        attribute currentHumidity : HumidityValue = 45.0;
        attribute currentAirQuality : AirQualityValue = 400.0;
        attribute currentLightLevel : LightIntensityValue = 200.0;
        action updateReadings {
            send sensorOut.temp(TemperatureReading{value = currentTemp; zoneId = zoneId;});
            send sensorOut.humidity(HumidityReading{value = currentHumidity; zoneId = zoneId;});
            send sensorOut.airQuality(AirQualityReading{value = currentAirQuality; zoneId = zoneId;});
            send sensorOut.lightLevel(LightLevelReading{value = currentLightLevel; zoneId = zoneId;});
        }
    }
    part def OccupancySensor {
        attribute zoneId : String;
        port sensorOut : SensorOut;
        attribute occupancyState : OccupancyState = OccupancyState::unoccupied;
        attribute personCount : OccupancyCount = 0;
        action detectPresence {
            send sensorOut.occupancy(OccupancyReading{state = occupancyState; count = personCount; zoneId = zoneId;});
        }
    }
    part def MotionDetector {
        attribute zoneId : String;
        port motionOut : MotionSensorOut;
        attribute motionState : MotionState = MotionState::noMotion;
        action detectMotion {
            send motionOut.motion(MotionReading{state = motionState; zoneId = zoneId;});
        }
    }
    part def DoorSensor {
        attribute sensorId : String;
        port doorOut : DoorSensorOut;
        attribute doorState : DoorState = DoorState::closed;
        action detectDoor {
            send doorOut.door(DoorReading{state = doorState; sensorId = sensorId;});
        }
    }
    part def Camera {
        attribute cameraId : String;
        attribute zoneId : String;
        port cameraOut : CameraOut;
        attribute motionState : MotionState = MotionState::noMotion;
        action captureStream {
            send cameraOut.motion(MotionReading{state = motionState; zoneId = zoneId;});
            send cameraOut.streamId(cameraId);
        }
    }

    // ---------- Zone ----------
    part def Zone {
        attribute zoneId : String;
        attribute zoneName : String;
        part environmentalSensor : EnvironmentalSensor {
            attribute zoneId = redefines Zone::zoneId;
        }
        part occupancySensor : OccupancySensor {
            attribute zoneId = redefines Zone::zoneId;
        }
        part motionDetector : MotionDetector {
            attribute zoneId = redefines Zone::zoneId;
        }
        port zoneSensorOut : SensorOut;
        port zoneMotionOut : MotionSensorOut;
        bind environmentalSensor.sensorOut = zoneSensorOut;
        bind occupancySensor.sensorOut = zoneSensorOut;
        bind motionDetector.motionOut = zoneMotionOut;
    }

    // ---------- Subsystems ----------
    part def ClimateControlSystem {
        attribute targetTemp : TemperatureValue = 22.0;
        attribute nightTargetTemp : TemperatureValue = 18.0;
        attribute awayTargetTemp : TemperatureValue = 15.0;
        port cmdIn : ControllerCmdOut;
        port powerOut : PowerReportOut;
        attribute currentPower : PowerValue = 0.0;
        attribute zoneActive : Boolean = false;
        state def ClimateBehavior {
            entry; then idle;
            state idle;
            transition idle_to_heating
                first idle
                accept cmdIn.climateCommand
                if cmdIn.climateCommand.enabled and cmdIn.climateCommand.targetTemp > currentTemp
                then heating;
            state heating {
                entry action { currentPower = 1500.0; }
            }
            transition heating_to_idle
                first heating
                accept cmdIn.climateCommand
                if not cmdIn.climateCommand.enabled
                then idle;
            transition heating_to_cooling
                first heating
                accept cmdIn.climateCommand
                if cmdIn.climateCommand.targetTemp < currentTemp
                then cooling;
            state cooling {
                entry action { currentPower = 1200.0; }
            }
            transition cooling_to_idle
                first cooling
                accept cmdIn.climateCommand
                if not cmdIn.climateCommand.enabled
                then idle;
            transition cooling_to_heating
                first cooling
                accept cmdIn.climateCommand
                if cmdIn.climateCommand.targetTemp > currentTemp
                then heating;
        }
        action reportPower {
            send powerOut.power(PowerReading{value = currentPower; subsystemId = "ClimateControl";});
        }
    }

    part def LightingSystem {
        port cmdIn : ControllerCmdOut;
        port powerOut : PowerReportOut;
        attribute currentPower : PowerValue = 0.0;
        attribute zoneDimming : DimmingLevel = 0.0;
        state def LightingBehavior {
            entry; then off;
            state off {
                entry action { currentPower = 0.0; zoneDimming = 0.0; }
            }
            transition off_to_on
                first off
                accept cmdIn.lightingCommand
                if cmdIn.lightingCommand.enabled
                then on;
            state on {
                entry action { zoneDimming = cmdIn.lightingCommand.dimmingLevel; currentPower = zoneDimming * 0.6; }
            }
            transition on_to_off
                first on
                accept cmdIn.lightingCommand
                if not cmdIn.lightingCommand.enabled
                then off;
            transition on_adjust
                first on
                accept cmdIn.lightingCommand
                if cmdIn.lightingCommand.enabled
                then on;
        }
        action reportPower {
            send powerOut.power(PowerReading{value = currentPower; subsystemId = "Lighting";});
        }
    }

    part def SecuritySystem {
        port cmdIn : ControllerCmdOut;
        port motionIn : MotionSensorOut;
        port doorIn : DoorSensorOut;
        port cameraIn : CameraOut;
        port powerOut : PowerReportOut;
        attribute currentMode : SecurityMode = SecurityMode::disarmed;
        attribute currentPower : PowerValue = 50.0;
        attribute alarmTriggered : Boolean = false;
        state def SecurityBehavior {
            entry; then disarmed;
            state disarmed {
                entry action { currentMode = SecurityMode::disarmed; currentPower = 50.0; }
            }
            transition disarmed_to_monitoring
                first disarmed
                accept cmdIn.securityCommand
                if cmdIn.securityCommand.mode == SecurityMode::monitoring
                then monitoring;
            transition disarmed_to_armed
                first disarmed
                accept cmdIn.securityCommand
                if cmdIn.securityCommand.mode == SecurityMode::armed
                then armed;
            state monitoring {
                entry action { currentMode = SecurityMode::monitoring; currentPower = 80.0; }
            }
            transition monitoring_to_armed
                first monitoring
                accept cmdIn.securityCommand
                if cmdIn.securityCommand.mode == SecurityMode::armed
                then armed;
            transition monitoring_to_disarmed
                first monitoring
                accept cmdIn.securityCommand
                if cmdIn.securityCommand.mode == SecurityMode::disarmed
                then disarmed;
            state armed {
                entry action { currentMode = SecurityMode::armed; currentPower = 100.0; }
            }
            transition armed_to_disarmed
                first armed
                accept cmdIn.securityCommand
                if cmdIn.securityCommand.mode == SecurityMode::disarmed
                then disarmed;
            transition armed_to_alarm
                first armed
                accept motionIn.motion
                if motionIn.motion.state == MotionState::motion
                then alarm;
            transition armed_to_alarm_door
                first armed
                accept doorIn.door
                if doorIn.door.state == DoorState::open
                then alarm;
            state alarm {
                entry action { alarmTriggered = true; currentPower = 200.0; }
            }
            transition alarm_to_disarmed
                first alarm
                accept cmdIn.securityCommand
                if cmdIn.securityCommand.mode == SecurityMode::disarmed
                then disarmed;
        }
        action reportPower {
            send powerOut.power(PowerReading{value = currentPower; subsystemId = "Security";});
        }
    }

    part def EnergyManagementSystem {
        port powerIn : PowerReportOut;
        port powerOut : PowerReportOut;
        attribute totalPower : PowerValue = 0.0;
        attribute periodEnergy : EnergyValue = 0.0;
        attribute readingsReceived : Integer = 0;
        action aggregatePower {
            accept powerIn.power {
                totalPower = totalPower + powerIn.power.value;
                readingsReceived = readingsReceived + 1;
            }
            send powerOut.power(PowerReading{value = totalPower; subsystemId = "EnergyManagement";});
            send powerOut.energy(EnergyReport{totalPower = totalPower; periodEnergy = periodEnergy + totalPower * 0.001;});
        }
    }

    // ---------- Central Controller ----------
    part def CentralController {
        port dataIn : ControllerDataIn;
        port cmdOut : ControllerCmdOut;
        port powerIn : PowerReportOut;
        attribute currentMode : SystemMode = SystemMode::active;
        attribute comfortTemp : TemperatureValue = 22.0;
        attribute nightTemp : TemperatureValue = 18.0;
        attribute awayTemp : TemperatureValue = 15.0;
        attribute occupiedZones : Integer = 0;
        attribute totalOccupants : OccupancyCount = 0;
        attribute totalPower : PowerValue = 0.0;
        state def ControllerMode {
            entry; then active;
            state active {
                entry action {
                    currentMode = SystemMode::active;
                    send cmdOut.securityCommand(SecurityCommand{mode = SecurityMode::monitoring;});
                }
            }
            transition active_to_away
                first active
                accept dataIn.sensorData.occupancy
                if totalOccupants == 0
                then away;
            transition active_to_night
                first active
                accept dataIn.sensorData.occupancy
                if currentMode == SystemMode::active and totalOccupants > 0
                then night;
            state away {
                entry action {
                    currentMode = SystemMode::away;
                    send cmdOut.climateCommand(ClimateCommand{zoneId = "all"; targetTemp = awayTemp; enabled = true;});
                    send cmdOut.lightingCommand(LightingCommand{zoneId = "all"; dimmingLevel = 0.0; enabled = false;});
                    send cmdOut.securityCommand(SecurityCommand{mode = SecurityMode::armed;});
                }
            }
            transition away_to_active
                first away
                accept dataIn.sensorData.occupancy
                if totalOccupants > 0
                then active;
            state night {
                entry action {
                    currentMode = SystemMode::night;
                    send cmdOut.climateCommand(ClimateCommand{zoneId = "bedroom"; targetTemp = nightTemp; enabled = true;});
                    send cmdOut.lightingCommand(LightingCommand{zoneId = "all"; dimmingLevel = 10.0; enabled = true;});
                    send cmdOut.securityCommand(SecurityCommand{mode = SecurityMode::armed;});
                }
            }
            transition night_to_active
                first night
                accept dataIn.sensorData.occupancy
                if currentMode == SystemMode::night and totalOccupants > 0
                then active;
        }
        action processSensorData {
            accept dataIn.sensorData.occupancy {
                if dataIn.sensorData.occupancy.state == OccupancyState::occupied {
                    occupiedZones = occupiedZones + 1;
                    totalOccupants = totalOccupants + dataIn.sensorData.occupancy.count;
                    send cmdOut.climateCommand(ClimateCommand{zoneId = dataIn.sensorData.occupancy.zoneId; targetTemp = comfortTemp; enabled = true;});
                    send cmdOut.lightingCommand(LightingCommand{zoneId = dataIn.sensorData.occupancy.zoneId; dimmingLevel = 80.0; enabled = true;});
                } else {
                    occupiedZones = occupiedZones - 1;
                    send cmdOut.climateCommand(ClimateCommand{zoneId = dataIn.sensorData.occupancy.zoneId; targetTemp = awayTemp; enabled = false;});
                    send cmdOut.lightingCommand(LightingCommand{zoneId = dataIn.sensorData.occupancy.zoneId; dimmingLevel = 0.0; enabled = false;});
                }
            }
        }
        action processPowerData {
            accept powerIn.power {
                totalPower = totalPower + powerIn.power.value;
            }
        }
    }

    // ---------- Home ----------
    part def DomusHome {
        part controller : CentralController;
        part climate : ClimateControlSystem;
        part lighting : LightingSystem;
        part security : SecuritySystem;
        part energy : EnergyManagementSystem;

        part livingRoom : Zone {
            attribute zoneId = "livingRoom";
            attribute zoneName = "Living Room";
        }
        part masterBedroom : Zone {
            attribute zoneId = "masterBedroom";
            attribute zoneName = "Master Bedroom";
        }
        part kitchen : Zone {
            attribute zoneId = "kitchen";
            attribute zoneName = "Kitchen";
        }
        part bathroom : Zone {
            attribute zoneId = "bathroom";
            attribute zoneName = "Bathroom";
        }

        part frontDoorSensor : DoorSensor {
            attribute sensorId = "frontDoor";
        }
        part backDoorSensor : DoorSensor {
            attribute sensorId = "backDoor";
        }
        part frontCamera : Camera {
            attribute cameraId = "frontCam";
            attribute zoneId = "entrance";
        }
        part backCamera : Camera {
            attribute cameraId = "backCam";
            attribute zoneId = "backyard";
        }

        connection connectLivingRoom
            connect livingRoom.zoneSensorOut to controller.dataIn.sensorData;
        connection connectMasterBedroom
            connect masterBedroom.zoneSensorOut to controller.dataIn.sensorData;
        connection connectKitchen
            connect kitchen.zoneSensorOut to controller.dataIn.sensorData;
        connection connectBathroom
            connect bathroom.zoneSensorOut to controller.dataIn.sensorData;

        connection connectLivingRoomMotion
            connect livingRoom.zoneMotionOut to controller.dataIn.motionData;
        connection connectMasterBedroomMotion
            connect masterBedroom.zoneMotionOut to controller.dataIn.motionData;
        connection connectKitchenMotion
            connect kitchen.zoneMotionOut to controller.dataIn.motionData;
        connection connectBathroomMotion
            connect bathroom.zoneMotionOut to controller.dataIn.motionData;

        connection connectFrontDoor
            connect frontDoorSensor.doorOut to controller.dataIn.doorData;
        connection connectBackDoor
            connect backDoorSensor.doorOut to controller.dataIn.doorData;
        connection connectFrontCamera
            connect frontCamera.cameraOut to controller.dataIn.cameraData;
        connection connectBackCamera
            connect backCamera.cameraOut to controller.dataIn.cameraData;

        connection controllerToClimate
            connect controller.cmdOut to climate.cmdIn;
        connection controllerToLighting
            connect controller.cmdOut to lighting.cmdIn;
        connection controllerToSecurity
            connect controller.cmdOut to security.cmdIn;

        connection climateToEnergy
            connect climate.powerOut to energy.powerIn;
        connection lightingToEnergy
            connect lighting.powerOut to energy.powerIn;
        connection securityToEnergy
            connect security.powerOut to energy.powerIn;
        connection energyToController
            connect energy.powerOut to controller.powerIn;
    }

    // ---------- Requirements ----------
    requirement def ClimateEfficiencyRequirement {
        doc
        /* The climate control system shall only condition occupied zones. */
        ;
        subject climate : ClimateControlSystem;
        objective {
            assert climate.zoneActive implies occupiedZones > 0
        }
    }
    requirement def LightingAutomationRequirement {
        doc
        /* The lighting system shall turn lights on when a zone becomes occupied and off when unoccupied. */
        ;
        subject lighting : LightingSystem;
        objective {
            assert (occupancyState == OccupancyState::occupied) implies lighting.zoneDimming > 0
        }
    }
    requirement def SecurityModeRequirement {
        doc
        /* The security system shall arm when the home enters away mode and monitor when active. */
        ;
        subject security : SecuritySystem;
        objective {
            assert (currentMode == SystemMode::away) implies security.currentMode == SecurityMode::armed
        }
    }
    requirement def EnergyTrackingRequirement {
        doc
        /* The energy management system shall track total power consumption of all subsystems. */
        ;
        subject energy : EnergyManagementSystem;
        objective {
            assert energy.totalPower >= 0
        }
    }
    requirement def AwayModeRequirement {
        doc
        /* When the last occupant leaves, the system shall enter away mode, lower thermostat, turn off lights, and arm security. */
        ;
        subject controller : CentralController;
        objective {
            assert (totalOccupants == 0) implies controller.currentMode == SystemMode::away
        }
    }
    requirement def ArrivalModeRequirement {
        doc
        /* Upon arrival, the system shall return to active mode and restore comfort settings. */
        ;
        subject controller : CentralController;
        objective {
            assert (totalOccupants > 0 and controller.currentMode == SystemMode::away) implies controller.currentMode == SystemMode::active
        }
    }

    requirement DomusSystemRequirements {
        subject home : DomusHome;
        satisfy climateEfficiency : ClimateEfficiencyRequirement {
            subject climate = home.climate;
        }
        satisfy lightingAutomation : LightingAutomationRequirement {
            subject lighting = home.lighting;
        }
        satisfy securityMode : SecurityModeRequirement {
            subject security = home.security;
        }
        satisfy energyTracking : EnergyTrackingRequirement {
            subject energy = home.energy;
        }
        satisfy awayMode : AwayModeRequirement {
            subject controller = home.controller;
        }
        satisfy arrivalMode : ArrivalModeRequirement {
            subject controller = home.controller;
        }
    }

}
