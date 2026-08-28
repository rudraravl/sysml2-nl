package BuildingManagementSystemFloor {
    private import ScalarValues::*;
    private import ISQ::*;

    alias Temperature for ISQ::TemperatureValue;
    alias Power for ISQ::PowerValue;
    alias Energy for ISQ::EnergyValue;
    alias Time for ISQ::TimeValue;
    alias Length for ISQ::LengthValue;

    attribute def ClimateReading {
        doc /* Sensor reading for temperature, humidity, and CO2 level */
        attribute temperature : Temperature;
        attribute humidity : Real;
        attribute co2ppm : Real;
    }

    attribute def OccupancyReading {
        attribute occupied : Boolean;
        attribute personCount : Integer;
    }

    attribute def LightingReading {
        attribute ambientLux : Real;
        attribute lightOn : Boolean;
    }

    attribute def AccessEvent {
        attribute credential : String;
        attribute timestamp : Time;
        attribute granted : Boolean;
    }

    attribute def PowerReading {
        attribute activePower : Power;
        attribute totalEnergy : Energy;
    }

    attribute def ControlCommand {
        attribute commandType : String;
        attribute setpoint : Real;
    }

    port def RoomEnvironmentSensorPort {
        out climate : ClimateReading;
        out occupancy : OccupancyReading;
        out lighting : LightingReading;
    }

    port def HVACControlCommandPort {
        out command : ControlCommand;
    }

    port def LightingControlCommandPort {
        out command : ControlCommand;
    }

    port def DoorLockControlCommandPort {
        out command : ControlCommand;
    }

    port def AccessEventPort {
        out accessEvent : AccessEvent;
    }

    port def PowerSupplyPort {
        out power : PowerReading;
    }

    port def PowerDemandPort {
        in power : PowerReading;
    }

    port def LoadShedCommandPort {
        out command : ControlCommand;
    }

    part def Room {
        attribute name : String;
        attribute floorArea : Real;
        port envSensorPort : RoomEnvironmentSensorPort;
        port hvacCmdPort : ~HVACControlCommandPort;
        port lightingCmdPort : ~LightingControlCommandPort;
        port doorCmdPort : ~DoorLockControlCommandPort;
        port doorEventPort : AccessEventPort;
    }

    part def Office :> Room;
    part def ConferenceRoom :> Room;
    part def ServerRoom :> Room;
    part def BreakRoom :> Room;
    part def Restroom :> Room;
    part def Hallway :> Room;

    part def HVACSystem {
        port envSensorPort : ~RoomEnvironmentSensorPort;
        port hvacCmdPort : HVACControlCommandPort;
        port powerDemandPort : PowerDemandPort;
        port loadShedCmdPort : ~LoadShedCommandPort;
        attribute setPoint : Temperature;
        perform action regulateClimate;
    }

    part def LightingSystem {
        port envSensorPort : ~RoomEnvironmentSensorPort;
        port lightingCmdPort : LightingControlCommandPort;
        port powerDemandPort : PowerDemandPort;
        port loadShedCmdPort : ~LoadShedCommandPort;
        perform action controlLighting;
    }

    part def AccessControlSystem {
        port doorEventPort : ~AccessEventPort;
        port doorCmdPort : DoorLockControlCommandPort;
        port powerDemandPort : PowerDemandPort;
        perform action manageAccess;
    }

    part def EnergyManagementSystem {
        port powerSupplyPort : PowerSupplyPort;
        port loadShedCmdPort : LoadShedCommandPort;
        attribute totalPower : Power;
        perform action monitorPower;
        perform action shedLoad;
    }

    part def BMSController {
        attribute floorEmpty : Boolean;
        attribute fireAlarm : Boolean;
        attribute allClear : Boolean;
        exhibit state floorModes : FloorModes;
        perform action coordinateSystems;
    }

    state def FloorModes {
        state normal;
        state energySaving;
        state emergency;
        transition from normal to energySaving when floorEmpty == true;
        transition from energySaving to normal when floorEmpty == false;
        transition from normal to emergency when fireAlarm == true;
        transition from energySaving to emergency when fireAlarm == true;
        transition from emergency to normal when allClear == true;
    }

    action def regulateClimate {
        in climate : ClimateReading;
        in occupancy : OccupancyReading;
        in setPoint : Temperature;
        out command : ControlCommand;
    }

    action def controlLighting {
        in occupancy : OccupancyReading;
        in lighting : LightingReading;
        out command : ControlCommand;
    }

    action def manageAccess {
        in accessEvent : AccessEvent;
        out command : ControlCommand;
    }

    action def monitorPower {
        in power : PowerReading;
        out shedCommand : ControlCommand;
    }

    action def shedLoad {
        in command : ControlCommand;
    }

    action def coordinateSystems {
        in climate : ClimateReading;
        in occupancy : OccupancyReading;
        in lighting : LightingReading;
        in accessEvent : AccessEvent;
        in power : PowerReading;
    }

    requirement def ComfortReqDef {
        doc /* Maintain temperature within 2 degrees of setpoint in occupied rooms */
        attribute measuredTemperature : Temperature;
        attribute setTemperature : Temperature;
        require constraint { abs(measuredTemperature - setTemperature) <= 2 }
    }

    requirement def AirQualityReqDef {
        doc /* Keep CO2 concentration below threshold */
        attribute co2Level : Real;
        attribute maxCO2Level : Real;
        require constraint { co2Level <= maxCO2Level }
    }

    requirement def LightingEnergySavingReqDef {
        doc /* Dim artificial lights when daylight is sufficient */
        attribute ambientLight : Real;
        attribute targetLightLevel : Real;
        require constraint { ambientLight >= targetLightLevel }
    }

    requirement def AccessControlReqDef {
        doc /* Grant access only to authorized credentials */
        attribute accessGranted : Boolean;
        attribute authorized : Boolean;
        require constraint { accessGranted == authorized }
    }

    requirement def EnergyEfficiencyReqDef {
        doc /* Total power consumption shall not exceed maximum allowed */
        attribute totalPower : Power;
        attribute maxPower : Power;
        require constraint { totalPower <= maxPower }
    }

    requirement def EmergencyModeReqDef {
        doc /* In emergency, all doors must unlock and all lights must turn on */
        attribute emergency : Boolean;
        attribute doorsUnlocked : Boolean;
        attribute lightsOn : Boolean;
        require constraint { emergency == true implies (doorsUnlocked == true and lightsOn == true) }
    }

    part floorContext {
        part hallway : Hallway;
        part office1 : Office;
        part office2 : Office;
        part conference : ConferenceRoom;
        part server : ServerRoom;
        part breakRoom : BreakRoom;
        part restroom : Restroom;

        part hvac : HVACSystem;
        part lighting : LightingSystem;
        part access : AccessControlSystem;
        part energy : EnergyManagementSystem;
        part controller : BMSController;

        flow office1ToHVAC_climate from office1.envSensorPort.climate to hvac.envSensorPort.climate;
        flow office1ToHVAC_occ from office1.envSensorPort.occupancy to hvac.envSensorPort.occupancy;
        flow office1ToLighting_light from office1.envSensorPort.lighting to lighting.envSensorPort.lighting;
        flow office1ToLighting_occ from office1.envSensorPort.occupancy to lighting.envSensorPort.occupancy;

        flow office2ToHVAC_climate from office2.envSensorPort.climate to hvac.envSensorPort.climate;
        flow office2ToHVAC_occ from office2.envSensorPort.occupancy to hvac.envSensorPort.occupancy;
        flow office2ToLighting_light from office2.envSensorPort.lighting to lighting.envSensorPort.lighting;
        flow office2ToLighting_occ from office2.envSensorPort.occupancy to lighting.envSensorPort.occupancy;

        flow confToHVAC_climate from conference.envSensorPort.climate to hvac.envSensorPort.climate;
        flow confToHVAC_occ from conference.envSensorPort.occupancy to hvac.envSensorPort.occupancy;
        flow confToLighting_light from conference.envSensorPort.lighting to lighting.envSensorPort.lighting;
        flow confToLighting_occ from conference.envSensorPort.occupancy to lighting.envSensorPort.occupancy;

        flow srvToHVAC_climate from server.envSensorPort.climate to hvac.envSensorPort.climate;
        flow srvToHVAC_occ from server.envSensorPort.occupancy to hvac.envSensorPort.occupancy;
        flow srvToLighting_light from server.envSensorPort.lighting to lighting.envSensorPort.lighting;
        flow srvToLighting_occ from server.envSensorPort.occupancy to lighting.envSensorPort.occupancy;

        flow brkToHVAC_climate from breakRoom.envSensorPort.climate to hvac.envSensorPort.climate;
        flow brkToHVAC_occ from breakRoom.envSensorPort.occupancy to hvac.envSensorPort.occupancy;
        flow brkToLighting_light from breakRoom.envSensorPort.lighting to lighting.envSensorPort.lighting;
        flow brkToLighting_occ from breakRoom.envSensorPort.occupancy to lighting.envSensorPort.occupancy;

        flow rstToHVAC_climate from restroom.envSensorPort.climate to hvac.envSensorPort.climate;
        flow rstToHVAC_occ from restroom.envSensorPort.occupancy to hvac.envSensorPort.occupancy;
        flow rstToLighting_light from restroom.envSensorPort.lighting to lighting.envSensorPort.lighting;
        flow rstToLighting_occ from restroom.envSensorPort.occupancy to lighting.envSensorPort.occupancy;

        flow hllToHVAC_climate from hallway.envSensorPort.climate to hvac.envSensorPort.climate;
        flow hllToHVAC_occ from hallway.envSensorPort.occupancy to hvac.envSensorPort.occupancy;
        flow hllToLighting_light from hallway.envSensorPort.lighting to lighting.envSensorPort.lighting;
        flow hllToLighting_occ from hallway.envSensorPort.occupancy to lighting.envSensorPort.occupancy;

        flow hvacToOffice1_cmd from hvac.hvacCmdPort.command to office1.hvacCmdPort.command;
        flow hvacToOffice2_cmd from hvac.hvacCmdPort.command to office2.hvacCmdPort.command;
        flow hvacToConf_cmd from hvac.hvacCmdPort.command to conference.hvacCmdPort.command;
        flow hvacToSrv_cmd from hvac.hvacCmdPort.command to server.hvacCmdPort.command;
        flow hvacToBrk_cmd from hvac.hvacCmdPort.command to breakRoom.hvacCmdPort.command;
        flow hvacToRst_cmd from hvac.hvacCmdPort.command to restroom.hvacCmdPort.command;
        flow hvacToHll_cmd from hvac.hvacCmdPort.command to hallway.hvacCmdPort.command;

        flow lightToOffice1_cmd from lighting.lightingCmdPort.command to office1.lightingCmdPort.command;
        flow lightToOffice2_cmd from lighting.lightingCmdPort.command to office2.lightingCmdPort.command;
        flow lightToConf_cmd from lighting.lightingCmdPort.command to conference.lightingCmdPort.command;
        flow lightToSrv_cmd from lighting.lightingCmdPort.command to server.lightingCmdPort.command;
        flow lightToBrk_cmd from lighting.lightingCmdPort.command to breakRoom.lightingCmdPort.command;
        flow lightToRst_cmd from lighting.lightingCmdPort.command to restroom.lightingCmdPort.command;
        flow lightToHll_cmd from lighting.lightingCmdPort.command to hallway.lightingCmdPort.command;

        flow office1ToAccess_evt from office1.doorEventPort.accessEvent to access.doorEventPort.accessEvent;
        flow office2ToAccess_evt from office2.doorEventPort.accessEvent to access.doorEventPort.accessEvent;
        flow confToAccess_evt from conference.doorEventPort.accessEvent to access.doorEventPort.accessEvent;
        flow srvToAccess_evt from server.doorEventPort.accessEvent to access.doorEventPort.accessEvent;
        flow brkToAccess_evt from breakRoom.doorEventPort.accessEvent to access.doorEventPort.accessEvent;
        flow rstToAccess_evt from restroom.doorEventPort.accessEvent to access.doorEventPort.accessEvent;
        flow hllToAccess_evt from hallway.doorEventPort.accessEvent to access.doorEventPort.accessEvent;

        flow accessToOffice1_cmd from access.doorCmdPort.command to office1.doorCmdPort.command;
        flow accessToOffice2_cmd from access.doorCmdPort.command to office2.doorCmdPort.command;
        flow accessToConf_cmd from access.doorCmdPort.command to conference.doorCmdPort.command;
        flow accessToSrv_cmd from access.doorCmdPort.command to server.doorCmdPort.command;
        flow accessToBrk_cmd from access.doorCmdPort.command to breakRoom.doorCmdPort.command;
        flow accessToRst_cmd from access.doorCmdPort.command to restroom.doorCmdPort.command;
        flow accessToHll_cmd from access.doorCmdPort.command to hallway.doorCmdPort.command;

        flow energyToHVAC_pwr from energy.powerSupplyPort.power to hvac.powerDemandPort.power;
        flow energyToLighting_pwr from energy.powerSupplyPort.power to lighting.powerDemandPort.power;
        flow energyToAccess_pwr from energy.powerSupplyPort.power to access.powerDemandPort.power;

        flow energyToHVAC_shed from energy.loadShedCmdPort.command to hvac.loadShedCmdPort.command;
        flow energyToLighting_shed from energy.loadShedCmdPort.command to lighting.loadShedCmdPort.command;
    }
}
