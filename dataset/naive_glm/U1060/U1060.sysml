package BuildingManagementSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQTemperature::*;
    import ISQVolumeFlowRate::*;
    import ISQEnergy::*;
    import ISQPower::*;
    import ISQTime::*;
    import ISQDimensionless::*;

    // ===== Value Types =====
    attribute def TemperatureValue :> Real { unit '°C'; }
    attribute def HumidityValue :> Real { unit '%'; }
    attribute def CO2Value :> Real { unit 'ppm'; }
    attribute def IlluminanceValue :> Real { unit 'lux'; }
    attribute def PowerValue :> Real { unit 'W'; }
    attribute def EnergyValue :> Real { unit 'J'; }
    attribute def AirflowValue :> Real { unit 'm3/s'; }
    attribute def OccupancyCount :> Integer;
    attribute def CredentialID :> String;
    attribute def AccessEventID :> String;
    attribute def DemandLevel :> Real { unit '%'; }

    // ===== Items =====
    item def TemperatureReading { attribute value : TemperatureValue; attribute zoneId : String; }
    item def HumidityReading { attribute value : HumidityValue; attribute zoneId : String; }
    item def AirQualityReading { attribute value : CO2Value; attribute zoneId : String; }
    item def OccupancyReading { attribute count : OccupancyCount; attribute zoneId : String; }
    item def IlluminanceReading { attribute value : IlluminanceValue; attribute zoneId : String; }
    item def PowerReading { attribute value : PowerValue; attribute sourceId : String; }
    item def AccessCredential { attribute id : CredentialID; attribute valid : Boolean; }
    item def AccessEvent { attribute id : AccessEventID; attribute credentialId : CredentialId; attribute doorId : String; attribute granted : Boolean; attribute timestamp : TimeValue; }
    item def HVACCommand { attribute zoneId : String; attribute heating : Boolean; attribute cooling : Boolean; attribute ventilation : Boolean; attribute fanSpeed : Real; }
    item def LightingCommand { attribute zoneId : String; attribute on : Boolean; attribute brightness : Real; }
    item def DoorCommand { attribute doorId : String; attribute locked : Boolean; }
    item def PowerAllocation { attribute targetId : String; attribute maxPower : PowerValue; }
    item def EmergencySignal { attribute active : Boolean; attribute type : String; }
    item def ModeChangeCommand { attribute mode : String; }

    // ===== Port Definitions =====
    port def SensorDataPort {
        out temp : TemperatureReading;
        out humidity : HumidityReading;
        out airQuality : AirQualityReading;
        out occupancy : OccupancyReading;
        out illuminance : IlluminanceReading;
    }
    port def HVACControlPort { in command : HVACCommand; }
    port def LightingControlPort { in command : LightingCommand; }
    port def AccessControlPort { in command : DoorCommand; out event : AccessEvent; in credential : AccessCredential; }
    port def PowerPort { in reading : PowerReading; out allocation : PowerAllocation; }
    port def EmergencyPort { in signal : EmergencySignal; }
    port def ModePort { in command : ModeChangeCommand; }

    // ===== Requirements =====
    requirement def ComfortRequirement {
        attribute targetTemp : TemperatureValue = 22.0;
        attribute targetHumidity : HumidityValue = 50.0;
        attribute maxCO2 : CO2Value = 1000.0;
        require constraint { temp.value >= 20.0 and temp.value <= 24.0 }
        require constraint { humidity.value >= 40.0 and humidity.value <= 60.0 }
        require constraint { airQuality.value <= maxCO2 }
    }
    requirement def EnergyEfficiencyRequirement {
        attribute maxFloorPower : PowerValue = 50000.0;
        require constraint { totalPower.value <= maxFloorPower }
    }
    requirement def SafetyRequirement {
        require constraint { emergency.active implies allDoorsUnlocked and allLightsOn }
    }
    requirement def AccessSecurityRequirement {
        require constraint { door.locked implies not credential.valid }
    }

    // ===== Sensor Parts =====
    part def TemperatureSensor {
        attribute zoneId : String;
        out tempOut : TemperatureReading;
        private attribute currentValue : TemperatureValue = 22.0;
        action update { send tempOut(TemperatureReading{value=currentValue, zoneId=zoneId}); }
    }
    part def HumiditySensor {
        attribute zoneId : String;
        out humidityOut : HumidityReading;
        private attribute currentValue : HumidityValue = 50.0;
        action update { send humidityOut(HumidityReading{value=currentValue, zoneId=zoneId}); }
    }
    part def AirQualitySensor {
        attribute zoneId : String;
        out airQualityOut : AirQualityReading;
        private attribute currentValue : CO2Value = 400.0;
        action update { send airQualityOut(AirQualityReading{value=currentValue, zoneId=zoneId}); }
    }
    part def OccupancySensor {
        attribute zoneId : String;
        out occupancyOut : OccupancyReading;
        private attribute currentCount : OccupancyCount = 0;
        action detect { send occupancyOut(OccupancyReading{count=currentCount, zoneId=zoneId}); }
    }
    part def AmbientLightSensor {
        attribute zoneId : String;
        out illuminanceOut : IlluminanceReading;
        private attribute currentValue : IlluminanceValue = 300.0;
        action update { send illuminanceOut(IlluminanceReading{value=currentValue, zoneId=zoneId}); }
    }
    part def PowerMeter {
        attribute sourceId : String;
        out powerOut : PowerReading;
        private attribute currentValue : PowerValue = 0.0;
        action measure { send powerOut(PowerReading{value=currentValue, sourceId=sourceId}); }
    }
    part def CardReader {
        attribute doorId : String;
        out credentialOut : AccessCredential;
        in eventIn : AccessEvent;
        action readCredential { send credentialOut(AccessCredential{id="unknown", valid=false}); }
    }

    // ===== Actuator Parts =====
    part def HVACActuator {
        attribute zoneId : String;
        in cmdIn : HVACCommand;
        attribute heatingActive : Boolean = false;
        attribute coolingActive : Boolean = false;
        attribute ventilationActive : Boolean = false;
        attribute fanSpeed : Real = 0.0;
        action execute { assign heatingActive = cmdIn.heating; assign coolingActive = cmdIn.cooling; assign ventilationActive = cmdIn.ventilation; assign fanSpeed = cmdIn.fanSpeed; }
    }
    part def LightingActuator {
        attribute zoneId : String;
        in cmdIn : LightingCommand;
        attribute on : Boolean = false;
        attribute brightness : Real = 0.0;
        action execute { assign on = cmdIn.on; assign brightness = cmdIn.brightness; }
    }
    part def DoorLock {
        attribute doorId : String;
        in cmdIn : DoorCommand;
        attribute locked : Boolean = true;
        action execute { assign locked = cmdIn.locked; }
    }

    // ===== Core Subsystems =====
    part def HVACSystem {
        in tempData : TemperatureReading;
        in humidityData : HumidityReading;
        in airQualityData : AirQualityReading;
        in occupancyData : OccupancyReading;
        out hvacCmd : HVACCommand;
        in modeCmd : ModeChangeCommand;
        in powerAlloc : PowerAllocation;
        attribute currentMode : String = "Normal";
        attribute setpointTemp : TemperatureValue = 22.0;
        attribute deadband : TemperatureValue = 1.0;
        private attribute currentTemp : TemperatureValue;
        private attribute currentHumidity : HumidityValue;
        private attribute currentCO2 : CO2Value;
        private attribute currentOccupancy : OccupancyCount;
        action computeControl {
            assign currentTemp = tempData.value;
            assign currentHumidity = humidityData.value;
            assign currentCO2 = airQualityData.value;
            assign currentOccupancy = occupancyData.count;
            if (currentMode == "Emergency") {
                send hvacCmd(HVACCommand{zoneId=tempData.zoneId, heating=false, cooling=false, ventilation=true, fanSpeed=1.0});
            } else if (currentMode == "EnergySaving") {
                if (currentOccupancy > 0) {
                    if (currentTemp > setpointTemp + deadband) { send hvacCmd(HVACCommand{zoneId=tempData.zoneId, heating=false, cooling=true, ventilation=true, fanSpeed=0.5}); }
                    else if (currentTemp < setpointTemp - deadband) { send hvacCmd(HVACCommand{zoneId=tempData.zoneId, heating=true, cooling=false, ventilation=false, fanSpeed=0.5}); }
                    else { send hvacCmd(HVACCommand{zoneId=tempData.zoneId, heating=false, cooling=false, ventilation=false, fanSpeed=0.0}); }
                } else {
                    send hvacCmd(HVACCommand{zoneId=tempData.zoneId, heating=false, cooling=false, ventilation=false, fanSpeed=0.0});
                }
            } else {
                if (currentOccupancy > 0) {
                    if (currentTemp > setpointTemp + deadband) { send hvacCmd(HVACCommand{zoneId=tempData.zoneId, heating=false, cooling=true, ventilation=true, fanSpeed=1.0}); }
                    else if (currentTemp < setpointTemp - deadband) { send hvacCmd(HVACCommand{zoneId=tempData.zoneId, heating=true, cooling=false, ventilation=true, fanSpeed=1.0}); }
                    else if (currentCO2 > 800.0) { send hvacCmd(HVACCommand{zoneId=tempData.zoneId, heating=false, cooling=false, ventilation=true, fanSpeed=0.7}); }
                    else { send hvacCmd(HVACCommand{zoneId=tempData.zoneId, heating=false, cooling=false, ventilation=false, fanSpeed=0.0}); }
                } else {
                    send hvacCmd(HVACCommand{zoneId=tempData.zoneId, heating=false, cooling=false, ventilation=false, fanSpeed=0.0});
                }
            }
        }
        state def HVACBehavior {
            entry; then Normal;
            state Normal;
            transition Normal to EnergySaving when modeCmd.mode == "EnergySaving";
            state EnergySaving;
            transition EnergySaving to Normal when modeCmd.mode == "Normal";
            transition Normal to Emergency when modeCmd.mode == "Emergency";
            transition EnergySaving to Emergency when modeCmd.mode == "Emergency";
            state Emergency;
            transition Emergency to Normal when modeCmd.mode == "Normal";
        }
    }

    part def LightingSystem {
        in occupancyData : OccupancyReading;
        in illuminanceData : IlluminanceReading;
        out lightingCmd : LightingCommand;
        in modeCmd : ModeChangeCommand;
        in powerAlloc : PowerAllocation;
        attribute currentMode : String = "Normal";
        private attribute currentOccupancy : OccupancyCount;
        private attribute currentIlluminance : IlluminanceValue;
        action computeControl {
            assign currentOccupancy = occupancyData.count;
            assign currentIlluminance = illuminanceData.value;
            if (currentMode == "Emergency") {
                send lightingCmd(LightingCommand{zoneId=occupancyData.zoneId, on=true, brightness=1.0});
            } else if (currentMode == "EnergySaving") {
                if (currentOccupancy > 0) {
                    if (currentIlluminance < 200.0) { send lightingCmd(LightingCommand{zoneId=occupancyData.zoneId, on=true, brightness=0.5}); }
                    else { send lightingCmd(LightingCommand{zoneId=occupancyData.zoneId, on=false, brightness=0.0}); }
                } else {
                    send lightingCmd(LightingCommand{zoneId=occupancyData.zoneId, on=false, brightness=0.0});
                }
            } else {
                if (currentOccupancy > 0) {
                    if (currentIlluminance < 500.0) {
                        attribute dimLevel : Real = (500.0 - currentIlluminance) / 500.0;
                        send lightingCmd(LightingCommand{zoneId=occupancyData.zoneId, on=true, brightness=dimLevel});
                    } else { send lightingCmd(LightingCommand{zoneId=occupancyData.zoneId, on=false, brightness=0.0}); }
                } else {
                    send lightingCmd(LightingCommand{zoneId=occupancyData.zoneId, on=false, brightness=0.0});
                }
            }
        }
        state def LightingBehavior {
            entry; then Normal;
            state Normal;
            transition Normal to EnergySaving when modeCmd.mode == "EnergySaving";
            state EnergySaving;
            transition EnergySaving to Normal when modeCmd.mode == "Normal";
            transition Normal to Emergency when modeCmd.mode == "Emergency";
            transition EnergySaving to Emergency when modeCmd.mode == "Emergency";
            state Emergency;
            transition Emergency to Normal when modeCmd.mode == "Normal";
        }
    }

    part def AccessControlSystem {
        in credential : AccessCredential;
        in modeCmd : ModeChangeCommand;
        out doorCmd : DoorCommand;
        out accessEvent : AccessEvent;
        in powerAlloc : PowerAllocation;
        attribute currentMode : String = "Normal";
        attribute authorizedIds : CredentialID[0..*] = ['EMP001', 'EMP002', 'EMP003', 'SEC001'];
        attribute scheduledAccessZones : String[0..*] = ['Office1', 'Office2', 'Office3', 'ConferenceRoom', 'BreakRoom', 'Restroom', 'Hallway'];
        attribute restrictedZones : String[0..*] = ['ServerRoom'];
        private attribute currentDoorId : String;
        private attribute currentCredId : CredentialID;
        private attribute isAuthorized : Boolean;
        action evaluateAccess {
            assign currentCredId = credential.id;
            assign isAuthorized = authorizedIds.contains(currentCredId);
            if (currentMode == "Emergency") {
                send doorCmd(DoorCommand{doorId=currentDoorId, locked=false});
                send accessEvent(AccessEvent{id="EVT" + currentDoorId, credentialId=currentCredId, doorId=currentDoorId, granted=true, timestamp=0.0});
            } else if (currentMode == "EnergySaving") {
                send doorCmd(DoorCommand{doorId=currentDoorId, locked=true});
                send accessEvent(AccessEvent{id="EVT" + currentDoorId, credentialId=currentCredId, doorId=currentDoorId, granted=false, timestamp=0.0});
            } else {
                if (isAuthorized) {
                    send doorCmd(DoorCommand{doorId=currentDoorId, locked=false});
                    send accessEvent(AccessEvent{id="EVT" + currentDoorId, credentialId=currentCredId, doorId=currentDoorId, granted=true, timestamp=0.0});
                } else {
                    send doorCmd(DoorCommand{doorId=currentDoorId, locked=true});
                    send accessEvent(AccessEvent{id="EVT" + currentDoorId, credentialId=currentCredId, doorId=currentDoorId, granted=false, timestamp=0.0});
                }
            }
        }
        state def AccessBehavior {
            entry; then Normal;
            state Normal;
            transition Normal to EnergySaving when modeCmd.mode == "EnergySaving";
            state EnergySaving;
            transition EnergySaving to Normal when modeCmd.mode == "Normal";
            transition Normal to Emergency when modeCmd.mode == "Emergency";
            transition EnergySaving to Emergency when modeCmd.mode == "Emergency";
            state Emergency;
            transition Emergency to Normal when modeCmd.mode == "Normal";
        }
    }

    part def EnergyManagementSystem {
        in powerReadings : PowerReading[0..*];
        in modeCmd : ModeChangeCommand;
        out powerAllocations : PowerAllocation[0..*];
        out emergencySignal : EmergencySignal;
        attribute currentMode : String = "Normal";
        attribute totalPowerLimit : PowerValue = 50000.0;
        attribute currentTotalPower : PowerValue = 0.0;
        attribute loadSheddingThreshold : PowerValue = 40000.0;
        attribute hvacPowerLimit : PowerValue = 25000.0;
        attribute lightingPowerLimit : PowerValue = 15000.0;
        attribute accessPowerLimit : PowerValue = 5000.0;
        action monitorAndAllocate {
            assign currentTotalPower = 0.0;
            for p in powerReadings { assign currentTotalPower = currentTotalPower + p.value; }
            if (currentMode == "Emergency") {
                send emergencySignal(EmergencySignal{active=true, type="Fire"});
                send powerAllocations(PowerAllocation{targetId="HVAC", maxPower=hvacPowerLimit});
                send powerAllocations(PowerAllocation{targetId="Lighting", maxPower=lightingPowerLimit});
                send powerAllocations(PowerAllocation{targetId="Access", maxPower=accessPowerLimit});
            } else if (currentMode == "EnergySaving") {
                send emergencySignal(EmergencySignal{active=false, type="None"});
                send powerAllocations(PowerAllocation{targetId="HVAC", maxPower=hvacPowerLimit * 0.5});
                send powerAllocations(PowerAllocation{targetId="Lighting", maxPower=lightingPowerLimit * 0.5});
                send powerAllocations(PowerAllocation{targetId="Access", maxPower=accessPowerLimit});
            } else {
                send emergencySignal(EmergencySignal{active=false, type="None"});
                if (currentTotalPower > loadSheddingThreshold) {
                    send powerAllocations(PowerAllocation{targetId="HVAC", maxPower=hvacPowerLimit * 0.8});
                    send powerAllocations(PowerAllocation{targetId="Lighting", maxPower=lightingPowerLimit * 0.7});
                    send powerAllocations(PowerAllocation{targetId="Access", maxPower=accessPowerLimit});
                } else {
                    send powerAllocations(PowerAllocation{targetId="HVAC", maxPower=hvacPowerLimit});
                    send powerAllocations(PowerAllocation{targetId="Lighting", maxPower=lightingPowerLimit});
                    send powerAllocations(PowerAllocation{targetId="Access", maxPower=accessPowerLimit});
                }
            }
        }
        state def EMSBehavior {
            entry; then Normal;
            state Normal;
            transition Normal to EnergySaving when modeCmd.mode == "EnergySaving";
            state EnergySaving;
            transition EnergySaving to Normal when modeCmd.mode == "Normal";
            transition Normal to Emergency when modeCmd.mode == "Emergency";
            transition EnergySaving to Emergency when modeCmd.mode == "Emergency";
            state Emergency;
            transition Emergency to Normal when modeCmd.mode == "Normal";
        }
    }

    // ===== Room Definitions =====
    part def Room {
        attribute zoneId : String;
        attribute hasDoor : Boolean = false;
        port sensorDataOut : SensorDataPort;
        port hvacControlIn : HVACControlPort;
        port lightingControlIn : LightingControlPort;
        port accessControlIn : AccessControlPort;
        part tempSensor : TemperatureSensor { attribute zoneId = Room::zoneId; }
        part humiditySensor : HumiditySensor { attribute zoneId = Room::zoneId; }
        part airQualitySensor : AirQualitySensor { attribute zoneId = Room::zoneId; }
        part occupancySensor : OccupancySensor { attribute zoneId = Room::zoneId; }
        part ambientLightSensor : AmbientLightSensor { attribute zoneId = Room::zoneId; }
        part hvacActuator : HVACActuator { attribute zoneId = Room::zoneId; }
        part lightingActuator : LightingActuator { attribute zoneId = Room::zoneId; }
        part doorLock : DoorLock { attribute doorId = Room::zoneId; }
        part cardReader : CardReader { attribute doorId = Room::zoneId; }
        connect tempSensor.tempOut to sensorDataOut.temp;
        connect humiditySensor.humidityOut to sensorDataOut.humidity;
        connect airQualitySensor.airQualityOut to sensorDataOut.airQuality;
        connect occupancySensor.occupancyOut to sensorDataOut.occupancy;
        connect ambientLightSensor.illuminanceOut to sensorDataOut.illuminance;
        connect hvacControlIn.command to hvacActuator.cmdIn;
        connect lightingControlIn.command to lightingActuator.cmdIn;
        connect accessControlIn.command to doorLock.cmdIn;
        connect accessControlIn.credential to cardReader.credentialOut;
        connect cardReader.eventIn to accessControlIn.event;
    }

    part def Office :> Room {
        attribute zoneId : String = "Office";
    }
    part def ConferenceRoom :> Room {
        attribute zoneId : String = "ConferenceRoom";
    }
    part def ServerRoom :> Room {
        attribute zoneId : String = "ServerRoom";
        attribute requiresHighSecurity : Boolean = true;
    }
    part def BreakRoom :> Room {
        attribute zoneId : String = "BreakRoom";
    }
    part def Restroom :> Room {
        attribute zoneId : String = "Restroom";
    }
    part def Hallway :> Room {
        attribute zoneId : String = "Hallway";
        attribute hasDoor : Boolean = false;
    }

    // ===== Floor Controller =====
    part def FloorController {
        in sensorData : SensorDataPort[0..*];
        in powerReadings : PowerReading[0..*];
        out modeCommands : ModeChangeCommand;
        out emergencySignal : EmergencySignal;
        attribute currentMode : String = "Normal";
        attribute totalOccupancy : OccupancyCount = 0;
        attribute emergencyDetected : Boolean = false;
        action evaluateMode {
            assign totalOccupancy = 0;
            for s in sensorData { assign totalOccupancy = totalOccupancy + s.occupancy.count; }
            if (emergencyDetected) {
                send modeCommands(ModeChangeCommand{mode="Emergency"});
                send emergencySignal(EmergencySignal{active=true, type="Fire"});
            } else if (totalOccupancy == 0) {
                send modeCommands(ModeChangeCommand{mode="EnergySaving"});
                send emergencySignal(EmergencySignal{active=false, type="None"});
            } else {
                send modeCommands(ModeChangeCommand{mode="Normal"});
                send emergencySignal(EmergencySignal{active=false, type="None"});
            }
        }
        state def ControllerBehavior {
            entry; then Normal;
            state Normal {
                entry { assign currentMode = "Normal"; }
            }
            transition Normal to EnergySaving when totalOccupancy == 0 and not emergencyDetected;
            state EnergySaving {
                entry { assign currentMode = "EnergySaving"; }
            }
            transition EnergySaving to Normal when totalOccupancy > 0 and not emergencyDetected;
            transition Normal to Emergency when emergencyDetected;
            transition EnergySaving to Emergency when emergencyDetected;
            state Emergency {
                entry { assign currentMode = "Emergency"; }
            }
            transition Emergency to Normal when not emergencyDetected and totalOccupancy > 0;
            transition Emergency to EnergySaving when not emergencyDetected and totalOccupancy == 0;
        }
    }

    // ===== Main Floor System =====
    part def FloorBMSSystem {
        attribute floorId : String = "Floor1";
        attribute floorArea : Real = 1000.0;
        
        // Core subsystems
        part hvacSystem : HVACSystem;
        part lightingSystem : LightingSystem;
        part accessControlSystem : AccessControlSystem;
        part energyManagementSystem : EnergyManagementSystem;
        part floorController : FloorController;
        
        // Rooms
        part office1 : Office { attribute zoneId = "Office1"; }
        part office2 : Office { attribute zoneId = "Office2"; }
        part office3 : Office { attribute zoneId = "Office3"; }
        part conferenceRoom : ConferenceRoom;
        part serverRoom : ServerRoom;
        part breakRoom : BreakRoom;
        part restroom : Restroom;
        part hallway : Hallway;
        
        // Power meters
        part hvacPowerMeter : PowerMeter { attribute sourceId = "HVAC"; }
        part lightingPowerMeter : PowerMeter { attribute sourceId = "Lighting"; }
        part accessPowerMeter : PowerMeter { attribute sourceId = "Access"; }
        
        // Connections from rooms to floor controller
        connect office1.sensorDataOut to floorController.sensorData;
        connect office2.sensorDataOut to floorController.sensorData;
        connect office3.sensorDataOut to floorController.sensorData;
        connect conferenceRoom.sensorDataOut to floorController.sensorData;
        connect serverRoom.sensorDataOut to floorController.sensorData;
        connect breakRoom.sensorDataOut to floorController.sensorData;
        connect restroom.sensorDataOut to floorController.sensorData;
        connect hallway.sensorDataOut to floorController.sensorData;
        
        // Connections from floor controller to subsystems
        connect floorController.modeCommands to hvacSystem.modeCmd;
        connect floorController.modeCommands to lightingSystem.modeCmd;
        connect floorController.modeCommands to accessControlSystem.modeCmd;
        connect floorController.modeCommands to energyManagementSystem.modeCmd;
        connect floorController.emergencySignal to energyManagementSystem.emergencySignal;
        
        // Connections from rooms to HVAC system
        connect office1.sensorDataOut.temp to hvacSystem.tempData;
        connect office1.sensorDataOut.humidity to hvacSystem.humidityData;
        connect office1.sensorDataOut.airQuality to hvacSystem.airQualityData;
        connect office1.sensorDataOut.occupancy to hvacSystem.occupancyData;
        connect office2.sensorDataOut.temp to hvacSystem.tempData;
        connect office2.sensorDataOut.humidity to hvacSystem.humidityData;
        connect office2.sensorDataOut.airQuality to hvacSystem.airQualityData;
        connect office2.sensorDataOut.occupancy to hvacSystem.occupancyData;
        connect office3.sensorDataOut.temp to hvacSystem.tempData;
        connect office3.sensorDataOut.humidity to hvacSystem.humidityData;
        connect office3.sensorDataOut.airQuality to hvacSystem.airQualityData;
        connect office3.sensorDataOut.occupancy to hvacSystem.occupancyData;
        connect conferenceRoom.sensorDataOut.temp to hvacSystem.tempData;
        connect conferenceRoom.sensorDataOut.humidity to hvacSystem.humidityData;
        connect conferenceRoom.sensorDataOut.airQuality to hvacSystem.airQualityData;
        connect conferenceRoom.sensorDataOut.occupancy to hvacSystem.occupancyData;
        connect serverRoom.sensorDataOut.temp to hvacSystem.tempData;
        connect serverRoom.sensorDataOut.humidity to hvacSystem.humidityData;
        connect serverRoom.sensorDataOut.airQuality to hvacSystem.airQualityData;
        connect serverRoom.sensorDataOut.occupancy to hvacSystem.occupancyData;
        connect breakRoom.sensorDataOut.temp to hvacSystem.tempData;
        connect breakRoom.sensorDataOut.humidity to hvacSystem.humidityData;
        connect breakRoom.sensorDataOut.airQuality to hvacSystem.airQualityData;
        connect breakRoom.sensorDataOut.occupancy to hvacSystem.occupancyData;
        connect restroom.sensorDataOut.temp to hvacSystem.tempData;
        connect restroom.sensorDataOut.humidity to hvacSystem.humidityData;
        connect restroom.sensorDataOut.airQuality to hvacSystem.airQualityData;
        connect restroom.sensorDataOut.occupancy to hvacSystem.occupancyData;
        connect hallway.sensorDataOut.temp to hvacSystem.tempData;
        connect hallway.sensorDataOut.humidity to hvacSystem.humidityData;
        connect hallway.sensorDataOut.airQuality to hvacSystem.airQualityData;
        connect hallway.sensorDataOut.occupancy to hvacSystem.occupancyData;
        
        // Connections from HVAC system to room actuators
        connect hvacSystem.hvacCmd to office1.hvacControlIn.command;
        connect hvacSystem.hvacCmd to office2.hvacControlIn.command;
        connect hvacSystem.hvacCmd to office3.hvacControlIn.command;
        connect hvacSystem.hvacCmd to conferenceRoom.hvacControlIn.command;
        connect hvacSystem.hvacCmd to serverRoom.hvacControlIn.command;
        connect hvacSystem.hvacCmd to breakRoom.hvacControlIn.command;
        connect hvacSystem.hvacCmd to restroom.hvacControlIn.command;
        connect hvacSystem.hvacCmd to hallway.hvacControlIn.command;
        
        // Connections from rooms to lighting system
        connect office1.sensorDataOut.occupancy to lightingSystem.occupancyData;
        connect office1.sensorDataOut.illuminance to lightingSystem.illuminanceData;
        connect office2.sensorDataOut.occupancy to lightingSystem.occupancyData;
        connect office2.sensorDataOut.illuminance to lightingSystem.illuminanceData;
        connect office3.sensorDataOut.occupancy to lightingSystem.occupancyData;
        connect office3.sensorDataOut.illuminance to lightingSystem.illuminanceData;
        connect conferenceRoom.sensorDataOut.occupancy to lightingSystem.occupancyData;
        connect conferenceRoom.sensorDataOut.illuminance to lightingSystem.illuminanceData;
        connect serverRoom.sensorDataOut.occupancy to lightingSystem.occupancyData;
        connect serverRoom.sensorDataOut.illuminance to lightingSystem.illuminanceData;
        connect breakRoom.sensorDataOut.occupancy to lightingSystem.occupancyData;
        connect breakRoom.sensorDataOut.illuminance to lightingSystem.illuminanceData;
        connect restroom.sensorDataOut.occupancy to lightingSystem.occupancyData;
        connect restroom.sensorDataOut.illuminance to lightingSystem.illuminanceData;
        connect hallway.sensorDataOut.occupancy to lightingSystem.occupancyData;
        connect hallway.sensorDataOut.illuminance to lightingSystem.illuminanceData;
        
        // Connections from lighting system to room actuators
        connect lightingSystem.lightingCmd to office1.lightingControlIn.command;
        connect lightingSystem.lightingCmd to office2.lightingControlIn.command;
        connect lightingSystem.lightingCmd to office3.lightingControlIn.command;
        connect lightingSystem.lightingCmd to conferenceRoom.lightingControlIn.command;
        connect lightingSystem.lightingCmd to serverRoom.lightingControlIn.command;
        connect lightingSystem.lightingCmd to breakRoom.lightingControlIn.command;
        connect lightingSystem.lightingCmd to restroom.lightingControlIn.command;
        connect lightingSystem.lightingCmd to hallway.lightingControlIn.command;
        
        // Connections from card readers to access control system
        connect office1.cardReader.credentialOut to accessControlSystem.credential;
        connect office2.cardReader.credentialOut to accessControlSystem.credential;
        connect office3.cardReader.credentialOut to accessControlSystem.credential;
        connect conferenceRoom.cardReader.credentialOut to accessControlSystem.credential;
        connect serverRoom.cardReader.credentialOut to accessControlSystem.credential;
        connect breakRoom.cardReader.credentialOut to accessControlSystem.credential;
        
        // Connections from access control system to door locks
        connect accessControlSystem.doorCmd to office1.accessControlIn.command;
        connect accessControlSystem.doorCmd to office2.accessControlIn.command;
        connect accessControlSystem.doorCmd to office3.accessControlIn.command;
        connect accessControlSystem.doorCmd to conferenceRoom.accessControlIn.command;
        connect accessControlSystem.doorCmd to serverRoom.accessControlIn.command;
        connect accessControlSystem.doorCmd to breakRoom.accessControlIn.command;
        
        // Connections from power meters to energy management system
        connect hvacPowerMeter.powerOut to energyManagementSystem.powerReadings;
        connect lightingPowerMeter.powerOut to energyManagementSystem.powerReadings;
        connect accessPowerMeter.powerOut to energyManagementSystem.powerReadings;
        
        // Connections from energy management system to subsystems
        connect energyManagementSystem.powerAllocations to hvacSystem.powerAlloc;
        connect energyManagementSystem.powerAllocations to lightingSystem.powerAlloc;
        connect energyManagementSystem.powerAllocations to accessControlSystem.powerAlloc;
        
        // Requirements satisfaction
        satisfy ComfortRequirement by hvacSystem;
        satisfy EnergyEfficiencyRequirement by energyManagementSystem;
        satisfy SafetyRequirement by floorController;
        satisfy AccessSecurityRequirement by accessControlSystem;
    }
}
