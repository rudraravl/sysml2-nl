package 'Floor Plan System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def RoomIdentifier;
    attribute def OccupancyCount;
    attribute def AccessLevel;
    attribute def ZoneType;

    value def Position {
        attribute x : LengthValue;
        attribute y : LengthValue;
    }

    value def RoomDimensions {
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
    }

    attribute def FloorArea :> Real;

    port def EnvironmentalSensorPort {
        out temperature : TemperatureValue;
        out humidity : Real;
        out airQuality : Real;
    }

    port def EnvironmentalActuatorPort {
        in temperatureSetpoint : TemperatureValue;
        in ventilationLevel : Real;
    }

    port def LightingSensorPort {
        out ambientLight : IlluminanceValue;
        out occupancyDetected : Boolean;
    }

    port def LightingActuatorPort {
        in lightLevel : Real;
        in lightingEnabled : Boolean;
    }

    port def AccessControlPort {
        in accessRequest : AccessLevel;
        out accessGranted : Boolean;
        out doorLocked : Boolean;
    }

    port def PowerMonitorPort {
        out powerConsumption : PowerValue;
        in powerLimit : PowerValue;
    }

    part def Room {
        attribute roomId : RoomIdentifier;
        attribute roomType : ZoneType;
        attribute position : Position;
        attribute dimensions : RoomDimensions;
        attribute area : FloorArea;
        attribute maxOccupancy : OccupancyCount;
        attribute currentOccupancy : OccupancyCount;

        port envSensor : EnvironmentalSensorPort;
        port envActuator : EnvironmentalActuatorPort;
        port lightSensor : LightingSensorPort;
        port lightActuator : LightingActuatorPort;
        port accessControl : AccessControlPort;
        port powerMonitor : PowerMonitorPort;
    }

    part def Hallway {
        attribute hallwayId : RoomIdentifier;
        attribute position : Position;
        attribute dimensions : RoomDimensions;
        attribute connectedRooms : RoomIdentifier[2..*];

        port lightSensor : LightingSensorPort;
        port lightActuator : LightingActuatorPort;
        port accessControl : AccessControlPort;
    }

    part def HVACSystem {
        attribute systemId : String;
        attribute coolingCapacity : PowerValue;
        attribute heatingCapacity : PowerValue;
        attribute efficiency : Real;

        port zoneControls : EnvironmentalActuatorPort[*];
        port zoneSensors : EnvironmentalSensorPort[*];
        port powerInput : PowerMonitorPort;

        perform action regulateClimate[*];
    }

    part def LightingSystem {
        attribute systemId : String;
        attribute totalFixtures : Integer;
        attribute maxPowerDraw : PowerValue;

        port zoneControls : LightingActuatorPort[*];
        port zoneSensors : LightingSensorPort[*];
        port powerInput : PowerMonitorPort;

        perform action controlLighting[*];
    }

    part def AccessControlSystem {
        attribute systemId : String;
        attribute securityLevel : AccessLevel;
        attribute monitoredZones : Integer;

        port accessPoints : AccessControlPort[*];
        port powerInput : PowerMonitorPort;

        perform action manageAccess[*];
    }

    part def EnergyManagementSystem {
        attribute systemId : String;
        attribute totalCapacity : PowerValue;
        attribute currentLoad : PowerValue;
        attribute peakLoad : PowerValue;

        port powerOutputs : PowerMonitorPort[*];

        perform action optimizePower[*];
    }

    action def RegulateClimate {
        in targetTemperature : TemperatureValue;
        in currentTemperature : TemperatureValue;
        in currentHumidity : Real;
        in occupancyLevel : OccupancyCount;
        out hvacSetpoint : TemperatureValue;
        out ventilationCommand : Real;

        first start;
        then action measureConditions {
            out measuredTemp : TemperatureValue;
            out measuredHumidity : Real;
        }
        then decide;
            if measureConditions.measuredTemp < targetTemperature - 1.0[K] then heating;
            if measureConditions.measuredTemp > targetTemperature + 1.0[K] then cooling;
        action heating {
            then assign hvacSetpoint := targetTemperature + 2.0[K];
            then assign ventilationCommand := 0.3;
        }
        action cooling {
            then assign hvacSetpoint := targetTemperature - 2.0[K];
            then assign ventilationCommand := 0.7;
        }
        then done;
    }

    action def ControlLighting {
        in occupancyDetected : Boolean;
        in ambientLight : IlluminanceValue;
        in timeOfDay : Real;
        in targetIlluminance : IlluminanceValue;
        out lightingLevel : Real;
        out lightsEnabled : Boolean;

        first start;
        then action checkOccupancy {
            out isOccupied : Boolean;
        }
        then decide;
            if checkOccupancy.isOccupied then occupiedMode;
            if not checkOccupancy.isOccupied then unoccupiedMode;
        action occupiedMode {
            then decide;
                if ambientLight < targetIlluminance then supplementLight;
            action supplementLight {
                then assign lightingLevel := 0.8;
                then assign lightsEnabled := true;
            }
        }
        action unoccupiedMode {
            then assign lightingLevel := 0.1;
            then assign lightsEnabled := true;
        }
        then done;
    }

    action def ManageAccess {
        in accessRequest : AccessLevel;
        in currentTime : Real;
        in securityMode : String;
        out accessGranted : Boolean;
        out doorLocked : Boolean;
        out auditLog : String;

        first start;
        then action validateRequest {
            in request : AccessLevel;
            out isValid : Boolean;
        }
        then action checkAuthorization {
            in time : Real;
            in mode : String;
            out isAuthorized : Boolean;
        }
        then decide;
            if validateRequest.isValid and checkAuthorization.isAuthorized then grantAccess;
            else denyAccess;
        action grantAccess {
            then assign accessGranted := true;
            then assign doorLocked := false;
            then assign auditLog := "Access granted";
        }
        action denyAccess {
            then assign accessGranted := false;
            then assign doorLocked := true;
            then assign auditLog := "Access denied";
        }
        then done;
    }

    action def OptimizePower {
        in totalDemand : PowerValue;
        in availableCapacity : PowerValue;
        in priorityZones : Integer[*];
        out powerAllocation : PowerValue[*];
        out loadShedding : Boolean;

        first start;
        then action assessDemand {
            out demandLevel : Real;
        }
        then decide;
            if assessDemand.demandLevel > 0.9 then shedLoad;
            else normalOperation;
        action shedLoad {
            then assign loadShedding := true;
        }
        action normalOperation {
            then assign loadShedding := false;
        }
        then done;
    }

    state def FloorOperationalState {
        entry; then normalOperation;

        state normalOperation {
            entry action initializeSystems;
            do action monitorAllZones;
        }

        transition normalOperation to energySavingMode
            accept lowOccupancySignal : Boolean;

        state energySavingMode {
            entry action reduceNonEssentialSystems;
            do action maintainMinimalServices;
        }

        transition energySavingMode to normalOperation
            accept occupancyIncreaseSignal : Boolean;

        transition normalOperation to emergencyMode
            accept emergencyAlert : Boolean;

        state emergencyMode {
            entry action activateEmergencyProtocols;
            do action evacuationSupport;
        }

        transition emergencyMode to normalOperation
            accept allClearSignal : Boolean;
    }

    requirement def FloorPlanSystemRequirements {
        doc /* The floor plan system shall provide integrated building management for occupant comfort, safety, and energy efficiency. */

        requirement <'FP-001'> environmentalComfort {
            doc /* The system shall maintain temperature between 293 K and 297 K in occupied zones. */
        }

        requirement <'FP-002'> lightingAdequacy {
            doc /* The system shall provide minimum 300 lx illuminance in occupied workspaces. */
        }

        requirement <'FP-003'> energyEfficiency {
            doc /* The system shall reduce energy consumption by 30% during low occupancy periods. */
        }

        requirement <'FP-004'> accessSecurity {
            doc /* The system shall enforce access control policies and maintain audit logs. */
        }

        requirement <'FP-005'> occupancySafety {
            doc /* The system shall not exceed maximum occupancy limits in any zone. */
        }

        requirement <'FP-006'> emergencyResponse {
            doc /* The system shall unlock all doors and activate emergency lighting within 2 seconds of emergency signal. */
        }
    }

    part def FloorPlanSystem {
        doc /* 
        This system manages the integrated operation of a commercial building floor,
        coordinating environmental control, lighting, security access, and power distribution
        across multiple rooms and hallways. The primary function is to maintain optimal
        occupant comfort and safety while maximizing energy efficiency through intelligent
        monitoring and control of building subsystems based on real-time occupancy patterns,
        environmental conditions, and security requirements.
        */

        satisfy FloorPlanSystemRequirements;
    }

    action def OperateFloor {
        in targetTemperature : TemperatureValue;
        in currentTemperature : TemperatureValue;
        in currentHumidity : Real;
        in occupancyLevel : OccupancyCount;
        in occupancyDetected : Boolean;
        in ambientLight : IlluminanceValue;
        in timeOfDay : Real;
        in targetIlluminance : IlluminanceValue;
        in accessRequest : AccessLevel;
        in currentTime : Real;
        in securityMode : String;
        in totalDemand : PowerValue;
        in availableCapacity : PowerValue;
        in priorityZones : Integer[*];
        out hvacSetpoint : TemperatureValue;
        out ventilationCommand : Real;
        out lightingLevel : Real;
        out lightsEnabled : Boolean;
        out accessGranted : Boolean;
        out doorLocked : Boolean;
        out auditLog : String;
        out powerAllocation : PowerValue[*];
        out loadShedding : Boolean;
    }

    action floorOperation : OperateFloor {
        first start;
        then merge continuousOperation;

        action regulateClimate : RegulateClimate {
            in targetTemperature;
            in currentTemperature;
            in currentHumidity;
            in occupancyLevel;
            out hvacSetpoint;
            out ventilationCommand;
        }

        flow regulateClimate.hvacSetpoint to controlLighting;

        action controlLighting : ControlLighting {
            in occupancyDetected;
            in ambientLight;
            in timeOfDay;
            in targetIlluminance;
            out lightingLevel;
            out lightsEnabled;
        }

        flow controlLighting.lightsEnabled to manageAccess;

        action manageAccess : ManageAccess {
            in accessRequest;
            in currentTime;
            in securityMode;
            out accessGranted;
            out doorLocked;
            out auditLog;
        }

        flow manageAccess.accessGranted to optimizePower;

        action optimizePower : OptimizePower {
            in totalDemand;
            in availableCapacity;
            in priorityZones;
            out powerAllocation;
            out loadShedding;
        }

        then continuousOperation;
    }

    part floorPlanSystem : FloorPlanSystem {
        attribute floorNumber : Integer;
        attribute totalFloorArea : FloorArea;
        attribute buildingName : String;

        perform action operateFloor[*] references floorOperation;

        part office101 : Room {
            :>> roomId = "R101";
            :>> roomType = "Office";
            :>> maxOccupancy = 4;
            :>> area = 20.0;
        }

        part office102 : Room {
            :>> roomId = "R102";
            :>> roomType = "Office";
            :>> maxOccupancy = 4;
            :>> area = 20.0;
        }

        part conferenceRoom : Room {
            :>> roomId = "R103";
            :>> roomType = "Conference";
            :>> maxOccupancy = 16;
            :>> area = 50.0;
        }

        part breakRoom : Room {
            :>> roomId = "R104";
            :>> roomType = "Break Room";
            :>> maxOccupancy = 10;
            :>> area = 30.0;
        }

        part serverRoom : Room {
            :>> roomId = "R105";
            :>> roomType = "Server Room";
            :>> maxOccupancy = 2;
            :>> area = 15.0;
        }

        part restroom : Room {
            :>> roomId = "R106";
            :>> roomType = "Restroom";
            :>> maxOccupancy = 3;
            :>> area = 12.0;
        }

        part mainHallway : Hallway {
            :>> hallwayId = "H01";
            :>> connectedRooms = ("R101", "R102", "R103", "R104", "R105", "R106");
        }

        part hvacSystem : HVACSystem {
            :>> systemId = "HVAC-FL2";
            :>> coolingCapacity = 50000.0[W];
            :>> heatingCapacity = 40000.0[W];
            perform operateFloor.regulateClimate;
        }

        part lightingSystem : LightingSystem {
            :>> systemId = "LIGHT-FL2";
            :>> totalFixtures = 48;
            :>> maxPowerDraw = 5000.0[W];
            perform operateFloor.controlLighting;
        }

        part accessControlSystem : AccessControlSystem {
            :>> systemId = "ACCESS-FL2";
            :>> monitoredZones = 7;
            perform operateFloor.manageAccess;
        }

        part energyManagement : EnergyManagementSystem {
            :>> systemId = "ENERGY-FL2";
            :>> totalCapacity = 75000.0[W];
            perform operateFloor.optimizePower;
        }

        connection hvacToOffice101 connect hvacSystem.zoneControls to office101.envActuator;
        connection hvacSenseOffice101 connect office101.envSensor to hvacSystem.zoneSensors;

        connection hvacToOffice102 connect hvacSystem.zoneControls to office102.envActuator;
        connection hvacSenseOffice102 connect office102.envSensor to hvacSystem.zoneSensors;

        connection hvacToConference connect hvacSystem.zoneControls to conferenceRoom.envActuator;
        connection hvacSenseConference connect conferenceRoom.envSensor to hvacSystem.zoneSensors;

        connection hvacToBreak connect hvacSystem.zoneControls to breakRoom.envActuator;
        connection hvacSenseBreak connect breakRoom.envSensor to hvacSystem.zoneSensors;

        connection hvacToServer connect hvacSystem.zoneControls to serverRoom.envActuator;
        connection hvacSenseServer connect serverRoom.envSensor to hvacSystem.zoneSensors;

        connection lightToOffice101 connect lightingSystem.zoneControls to office101.lightActuator;
        connection lightSenseOffice101 connect office101.lightSensor to lightingSystem.zoneSensors;

        connection lightToOffice102 connect lightingSystem.zoneControls to office102.lightActuator;
        connection lightSenseOffice102 connect office102.lightSensor to lightingSystem.zoneSensors;

        connection lightToConference connect lightingSystem.zoneControls to conferenceRoom.lightActuator;
        connection lightSenseConference connect conferenceRoom.lightSensor to lightingSystem.zoneSensors;

        connection lightToBreak connect lightingSystem.zoneControls to breakRoom.lightActuator;
        connection lightSenseBreak connect breakRoom.lightSensor to lightingSystem.zoneSensors;

        connection lightToHallway connect lightingSystem.zoneControls to mainHallway.lightActuator;
        connection lightSenseHallway connect mainHallway.lightSensor to lightingSystem.zoneSensors;

        connection accessToOffice101 connect accessControlSystem.accessPoints to office101.accessControl;
        connection accessToOffice102 connect accessControlSystem.accessPoints to office102.accessControl;
        connection accessToConference connect accessControlSystem.accessPoints to conferenceRoom.accessControl;
        connection accessToServer connect accessControlSystem.accessPoints to serverRoom.accessControl;
        connection accessToHallway connect accessControlSystem.accessPoints to mainHallway.accessControl;

        connection powerToHVAC connect energyManagement.powerOutputs to hvacSystem.powerInput;
        connection powerToLighting connect energyManagement.powerOutputs to lightingSystem.powerInput;
        connection powerToAccess connect energyManagement.powerOutputs to accessControlSystem.powerInput;
        connection powerToOffice101 connect energyManagement.powerOutputs to office101.powerMonitor;
        connection powerToOffice102 connect energyManagement.powerOutputs to office102.powerMonitor;
        connection powerToConference connect energyManagement.powerOutputs to conferenceRoom.powerMonitor;
        connection powerToBreak connect energyManagement.powerOutputs to breakRoom.powerMonitor;
        connection powerToServer connect energyManagement.powerOutputs to serverRoom.powerMonitor;
    }
}
