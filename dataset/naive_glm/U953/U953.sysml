package HomeAutomationSystem {
    import ScalarValues::Boolean;
    import ScalarValues::Integer;
    import ScalarValues::Real;
    import ScalarValues::String;

    unit degC;
    unit percent;
    unit lux;
    unit watt;
    unit s;

    value def Temperature :> Real { unit : degC; }
    value def Humidity :> Real { unit : percent; }
    value def Illuminance :> Real { unit : lux; }
    value def Power :> Real { unit : watt; }
    value def ElapsedTime :> Real { unit : s; }
    value def AirQuality :> Integer;

    item def OccupancyData {
        attribute roomId : String;
        attribute occupied : Boolean;
    }
    item def EnvironmentData {
        attribute roomId : String;
        attribute temperature : Temperature;
        attribute humidity : Humidity;
        attribute airQuality : AirQuality;
    }
    item def AmbientLightData {
        attribute roomId : String;
        attribute illuminance : Illuminance;
    }
    item def HVACCommand {
        attribute targetTemp : Temperature;
        attribute mode : String;
    }
    item def LightingCommand {
        attribute roomId : String;
        attribute on : Boolean;
        attribute brightness : Real;
        attribute colorTemp : Temperature;
    }
    item def SecurityCommand {
        attribute armed : Boolean;
        attribute doorsLocked : Boolean;
    }

    port def MotionSensorPort {
        out motionData : OccupancyData;
    }
    port def MotionControllerPort {
        in motionData : OccupancyData;
    }
    port def EnvironmentSensorPort {
        out envData : EnvironmentData;
    }
    port def EnvironmentControllerPort {
        in envData : EnvironmentData;
    }
    port def LightSensorPort {
        out lightData : AmbientLightData;
    }
    port def LightControllerPort {
        in lightData : AmbientLightData;
    }
    port def HVACControlPort {
        out hvacCmd : HVACCommand;
    }
    port def HVACActuatorPort {
        in hvacCmd : HVACCommand;
    }
    port def LightingControlPort {
        out lightCmd : LightingCommand;
    }
    port def LightingActuatorPort {
        in lightCmd : LightingCommand;
    }
    port def SecurityControlPort {
        out secCmd : SecurityCommand;
    }
    port def SecurityActuatorPort {
        in secCmd : SecurityCommand;
    }

    part def MotionSensor {
        port motionOut : MotionSensorPort;
    }
    part def EnvironmentalSensor {
        port envOut : EnvironmentSensorPort;
    }
    part def AmbientLightSensor {
        port lightOut : LightSensorPort;
    }

    part def HVACController {
        port hvacIn : HVACActuatorPort;
        attribute currentRoomTemp : Temperature;
        state machine HVACStates {
            state idle;
            state heating;
            state cooling;
            transition from idle to heating when hvacIn.hvacCmd.targetTemp > currentRoomTemp;
            transition from idle to cooling when hvacIn.hvacCmd.targetTemp < currentRoomTemp;
            transition from heating to idle when hvacIn.hvacCmd.targetTemp <= currentRoomTemp;
            transition from cooling to idle when hvacIn.hvacCmd.targetTemp >= currentRoomTemp;
        }
    }

    part def SmartLightingSystem {
        port lightingIn : LightingActuatorPort;
        state machine LightingStates {
            state off;
            state on;
            transition from off to on when lightingIn.lightCmd.on == true;
            transition from on to off when lightingIn.lightCmd.on == false;
        }
    }

    part def SecuritySystem {
        port securityIn : SecurityActuatorPort;
        attribute intrusionDetected : Boolean;
        state machine SecurityStates {
            state disarmed;
            state armed;
            state alarm;
            transition from disarmed to armed when securityIn.secCmd.armed == true;
            transition from armed to disarmed when securityIn.secCmd.armed == false;
            transition from armed to alarm when intrusionDetected == true;
            transition from alarm to disarmed when securityIn.secCmd.armed == false;
        }
    }

    part def CentralController {
        port motionIn : MotionControllerPort;
        port envIn : EnvironmentControllerPort;
        port lightIn : LightControllerPort;
        port hvacOut : HVACControlPort;
        port lightingOut : LightingControlPort;
        port securityOut : SecurityControlPort;

        attribute isOccupied : Boolean;
        attribute currentMode : String;
        attribute timeSinceLastMotion : ElapsedTime;

        state machine ControlStates {
            state home {
                entry {
                    hvacOut.hvacCmd = HVACCommand(targetTemp = 22.0, mode = "comfort");
                    lightingOut.lightCmd = LightingCommand(roomId = "all", on = true, brightness = 80.0, colorTemp = 2700.0);
                    securityOut.secCmd = SecurityCommand(armed = false, doorsLocked = false);
                }
            }
            state away {
                entry {
                    hvacOut.hvacCmd = HVACCommand(targetTemp = 18.0, mode = "energy_saving");
                    lightingOut.lightCmd = LightingCommand(roomId = "all", on = false, brightness = 0.0, colorTemp = 0.0);
                    securityOut.secCmd = SecurityCommand(armed = true, doorsLocked = true);
                }
            }
            state sleep {
                entry {
                    hvacOut.hvacCmd = HVACCommand(targetTemp = 20.0, mode = "comfort");
                    lightingOut.lightCmd = LightingCommand(roomId = "all", on = false, brightness = 10.0, colorTemp = 2200.0);
                    securityOut.secCmd = SecurityCommand(armed = true, doorsLocked = true);
                }
            }

            transition from home to away after 1800 [s] when !isOccupied;
            transition from away to home when isOccupied;
            transition from home to sleep after 21600 [s] when !isOccupied;
            transition from sleep to home when isOccupied;
        }
    }

    part def HomeAutomationSystem {
        part controller : CentralController;
        part motionSensor : MotionSensor;
        part envSensor : EnvironmentalSensor;
        part lightSensor : AmbientLightSensor;
        part hvac : HVACController;
        part lighting : SmartLightingSystem;
        part security : SecuritySystem;

        connect motionSensor.motionOut to controller.motionIn;
        connect envSensor.envOut to controller.envIn;
        connect lightSensor.lightOut to controller.lightIn;
        connect controller.hvacOut to hvac.hvacIn;
        connect controller.lightingOut to lighting.lightingIn;
        connect controller.securityOut to security.securityIn;
    }

    requirement def HomeAutomationRequirements {
        doc /* The system shall automatically manage climate, lighting, and security based on occupancy. */
        subject system : HomeAutomationSystem;
        require system.controller.isOccupied == false implies system.security.securityIn.secCmd.armed == true;
        require system.controller.isOccupied == false implies system.hvac.hvacIn.hvacCmd.targetTemp <= 18.0;
        require system.controller.isOccupied == false implies system.lighting.lightingIn.lightCmd.on == false;
        require system.controller.isOccupied == true implies system.security.securityIn.secCmd.armed == false;
    }
}
