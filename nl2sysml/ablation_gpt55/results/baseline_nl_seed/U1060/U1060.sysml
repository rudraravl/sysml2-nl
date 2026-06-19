package FloorPlanBasedFacilityModel {
    import ScalarValues::*;

    enum def SpaceUseKind {
        enum reception;
        enum openOffice;
        enum conference;
        enum support;
        enum hygiene;
        enum circulation;
        enum utility;
        enum safety;
    }

    enum def FacilityModeKind {
        enum unoccupied;
        enum opening;
        enum occupied;
        enum emergency;
        enum maintenance;
        enum energySaving;
    }

    attribute def Length {
        attribute value : Real;
        attribute unit : String = "m";
    }

    attribute def Area {
        attribute value : Real;
        attribute unit : String = "m^2";
    }

    attribute def VolumeFlowRate {
        attribute value : Real;
        attribute unit : String = "m^3/s";
    }

    attribute def Temperature {
        attribute value : Real;
        attribute unit : String = "K";
    }

    attribute def Power {
        attribute value : Real;
        attribute unit : String = "W";
    }

    attribute def Illuminance {
        attribute value : Real;
        attribute unit : String = "lx";
    }

    attribute def Count {
        attribute value : Integer;
        attribute unit : String = "count";
    }

    attribute def Ratio {
        attribute value : Real;
        attribute unit : String = "1";
    }

    item def Occupant {
        attribute identifier : String;
    }

    item def ConditionedAir {
        attribute supplyTemperature : Temperature;
        attribute flowRate : VolumeFlowRate;
    }

    item def ReturnAir {
        attribute returnTemperature : Temperature;
        attribute flowRate : VolumeFlowRate;
    }

    item def ElectricalEnergy {
        attribute availablePower : Power;
    }

    item def LightingCommand {
        attribute targetIlluminance : Illuminance;
        attribute enableAutomaticControl : Boolean;
    }

    item def AccessCommand {
        attribute unlockPublicEntry : Boolean;
        attribute unlockStaffEntry : Boolean;
    }

    item def AlarmSignal {
        attribute active : Boolean;
        attribute message : String;
    }

    item def OccupancyReport {
        attribute occupiedCount : Count;
        attribute estimatedDensity : Ratio;
    }

    item def FloorPlanDescription {
        attribute drawingName : String;
        attribute revision : String;
        attribute scaleRatio : Ratio;
        attribute grossArea : Area;
    }

    port def OccupantFlowPort {
        in item arrivingOccupant : Occupant;
        out item departingOccupant : Occupant;
    }

    port def AirZonePort {
        in item suppliedAir : ConditionedAir;
        out item returnedAir : ReturnAir;
    }

    port def ElectricalLoadPort {
        in item receivedEnergy : ElectricalEnergy;
    }

    port def LightingControlPort {
        in item command : LightingCommand;
        out item occupancy : OccupancyReport;
    }

    port def AccessControlPort {
        in item command : AccessCommand;
        out item occupancy : OccupancyReport;
    }

    port def AlarmPort {
        in item alarm : AlarmSignal;
    }

    port def FloorPlanPort {
        in item planInput : FloorPlanDescription;
        out item occupancySummary : OccupancyReport;
    }

    connection def OccupantRoute {
        end source : OccupantFlowPort;
        end target : OccupantFlowPort;
        attribute clearWidth : Length;
    }

    connection def AirDistributionConnection {
        end source : AirZonePort;
        end target : AirZonePort;
    }

    connection def ElectricalConnection {
        end source : ElectricalLoadPort;
        end target : ElectricalLoadPort;
    }

    connection def LightingControlConnection {
        end controller : LightingControlPort;
        end zone : LightingControlPort;
    }

    connection def AccessControlConnection {
        end controller : AccessControlPort;
        end accessPoint : AccessControlPort;
    }

    connection def AlarmConnection {
        end source : AlarmPort;
        end receiver : AlarmPort;
    }

    part def EntryDoor {
        attribute clearWidth : Length {
            :>> value = 1.80;
        }
        attribute isFireRated : Boolean = true;
        port access : OccupantFlowPort;
        port accessControl : AccessControlPort;
        port alarmInterface : AlarmPort;
    }

    part def InteriorDoor {
        attribute clearWidth : Length {
            :>> value = 0.95;
        }
        attribute isFireRated : Boolean = false;
        port access : OccupantFlowPort;
        port alarmInterface : AlarmPort;
    }

    part def Lobby {
        attribute roomNumber : String = "L100";
        attribute intendedUse : SpaceUseKind = SpaceUseKind::reception;
        attribute length : Length {
            :>> value = 12.0;
        }
        attribute width : Length {
            :>> value = 8.0;
        }
        attribute netArea : Area {
            :>> value = 96.0;
        }
        attribute nominalCapacity : Count {
            :>> value = 40;
        }
        part publicEntry : EntryDoor;
        part corridorDoor : InteriorDoor;
        port publicAccess : OccupantFlowPort;
        port corridorAccess : OccupantFlowPort;
        port supplyAir : AirZonePort;
        port electricalLoad : ElectricalLoadPort;
        port lightingZone : LightingControlPort;
        port alarmDevice : AlarmPort;
    }

    part def OpenOffice {
        attribute roomNumber : String = "O110";
        attribute intendedUse : SpaceUseKind = SpaceUseKind::openOffice;
        attribute length : Length {
            :>> value = 20.0;
        }
        attribute width : Length {
            :>> value = 14.0;
        }
        attribute netArea : Area {
            :>> value = 280.0;
        }
        attribute nominalCapacity : Count {
            :>> value = 42;
        }
        port primaryAccess : OccupantFlowPort;
        port secondaryAccess : OccupantFlowPort;
        port supplyAir : AirZonePort;
        port electricalLoad : ElectricalLoadPort;
        port lightingZone : LightingControlPort;
        port alarmDevice : AlarmPort;
    }

    part def ConferenceRoom {
        attribute roomNumber : String = "C120";
        attribute intendedUse : SpaceUseKind = SpaceUseKind::conference;
        attribute length : Length {
            :>> value = 10.0;
        }
        attribute width : Length {
            :>> value = 7.5;
        }
        attribute netArea : Area {
            :>> value = 75.0;
        }
        attribute nominalCapacity : Count {
            :>> value = 24;
        }
        port mainAccess : OccupantFlowPort;
        port supplyAir : AirZonePort;
        port electricalLoad : ElectricalLoadPort;
        port lightingZone : LightingControlPort;
        port alarmDevice : AlarmPort;
    }

    part def BreakRoom {
        attribute roomNumber : String = "B130";
        attribute intendedUse : SpaceUseKind = SpaceUseKind::support;
        attribute length : Length {
            :>> value = 8.0;
        }
        attribute width : Length {
            :>> value = 6.0;
        }
        attribute netArea : Area {
            :>> value = 48.0;
        }
        attribute nominalCapacity : Count {
            :>> value = 14;
        }
        port mainAccess : OccupantFlowPort;
        port supplyAir : AirZonePort;
        port electricalLoad : ElectricalLoadPort;
        port lightingZone : LightingControlPort;
        port alarmDevice : AlarmPort;
    }

    part def Restroom {
        attribute roomNumber : String;
        attribute intendedUse : SpaceUseKind = SpaceUseKind::hygiene;
        attribute length : Length {
            :>> value = 6.0;
        }
        attribute width : Length {
            :>> value = 4.0;
        }
        attribute netArea : Area {
            :>> value = 24.0;
        }
        attribute nominalCapacity : Count {
            :>> value = 6;
        }
        port mainAccess : OccupantFlowPort;
        port exhaustAir : AirZonePort;
        port electricalLoad : ElectricalLoadPort;
        port lightingZone : LightingControlPort;
        port alarmDevice : AlarmPort;
    }

    part def MechanicalElectricalRoom {
        attribute roomNumber : String = "M150";
        attribute intendedUse : SpaceUseKind = SpaceUseKind::utility;
        attribute length : Length {
            :>> value = 7.0;
        }
        attribute width : Length {
            :>> value = 6.0;
        }
        attribute netArea : Area {
            :>> value = 42.0;
        }
        attribute nominalCapacity : Count {
            :>> value = 3;
        }
        port staffAccess : OccupantFlowPort;
        port supplyAir : AirZonePort;
        port electricalLoad : ElectricalLoadPort;
        port lightingZone : LightingControlPort;
        port alarmDevice : AlarmPort;
    }

    part def MainCorridor {
        attribute roomNumber : String = "H101";
        attribute intendedUse : SpaceUseKind = SpaceUseKind::circulation;
        attribute length : Length {
            :>> value = 42.0;
        }
        attribute width : Length {
            :>> value = 2.4;
        }
        attribute netArea : Area {
            :>> value = 100.8;
        }
        attribute nominalCapacity : Count {
            :>> value = 80;
        }
        port lobbyAccess : OccupantFlowPort;
        port officeAccess : OccupantFlowPort;
        port conferenceAccess : OccupantFlowPort;
        port breakRoomAccess : OccupantFlowPort;
        port restroomAccessA : OccupantFlowPort;
        port restroomAccessB : OccupantFlowPort;
        port mechanicalAccess : OccupantFlowPort;
        port emergencyExitAccess : OccupantFlowPort;
        port supplyAir : AirZonePort;
        port electricalLoad : ElectricalLoadPort;
        port lightingZone : LightingControlPort;
        port alarmDevice : AlarmPort;
    }

    part def EmergencyExitStair {
        attribute roomNumber : String = "S160";
        attribute intendedUse : SpaceUseKind = SpaceUseKind::safety;
        attribute length : Length {
            :>> value = 8.0;
        }
        attribute width : Length {
            :>> value = 2.2;
        }
        attribute netArea : Area {
            :>> value = 17.6;
        }
        attribute nominalCapacity : Count {
            :>> value = 120;
        }
        part exitDoor : EntryDoor;
        port corridorAccess : OccupantFlowPort;
        port exteriorDischarge : OccupantFlowPort;
        port pressurizationAir : AirZonePort;
        port electricalLoad : ElectricalLoadPort;
        port lightingZone : LightingControlPort;
        port alarmDevice : AlarmPort;
    }

    part def ArchitecturalFloorPlan {
        attribute planName : String = "Headquarters Office Floor 01";
        attribute revision : String = "A";
        attribute scale : Ratio {
            :>> value = 0.01;
        }
        attribute grossArea : Area {
            :>> value = 820.0;
        }
        attribute usableArea : Area {
            :>> value = 683.4;
        }

        part lobby : Lobby;
        part openOffice : OpenOffice;
        part conferenceRoom : ConferenceRoom;
        part breakRoom : BreakRoom;
        part restroomA : Restroom {
            attribute :>> roomNumber = "R140";
        }
        part restroomB : Restroom {
            attribute :>> roomNumber = "R141";
        }
        part mechanicalRoom : MechanicalElectricalRoom;
        part mainCorridor : MainCorridor;
        part emergencyStair : EmergencyExitStair;

        port planInterface : FloorPlanPort;

        connection lobbyToCorridor : OccupantRoute connect lobby.corridorAccess to mainCorridor.lobbyAccess {
            attribute :>> clearWidth {
                :>> value = 1.80;
            }
        }

        connection corridorToOffice : OccupantRoute connect mainCorridor.officeAccess to openOffice.primaryAccess {
            attribute :>> clearWidth {
                :>> value = 1.60;
            }
        }

        connection corridorToConference : OccupantRoute connect mainCorridor.conferenceAccess to conferenceRoom.mainAccess {
            attribute :>> clearWidth {
                :>> value = 1.20;
            }
        }

        connection corridorToBreakRoom : OccupantRoute connect mainCorridor.breakRoomAccess to breakRoom.mainAccess {
            attribute :>> clearWidth {
                :>> value = 1.10;
            }
        }

        connection corridorToRestroomA : OccupantRoute connect mainCorridor.restroomAccessA to restroomA.mainAccess {
            attribute :>> clearWidth {
                :>> value = 0.95;
            }
        }

        connection corridorToRestroomB : OccupantRoute connect mainCorridor.restroomAccessB to restroomB.mainAccess {
            attribute :>> clearWidth {
                :>> value = 0.95;
            }
        }

        connection corridorToMechanical : OccupantRoute connect mainCorridor.mechanicalAccess to mechanicalRoom.staffAccess {
            attribute :>> clearWidth {
                :>> value = 0.95;
            }
        }

        connection corridorToEmergencyStair : OccupantRoute connect mainCorridor.emergencyExitAccess to emergencyStair.corridorAccess {
            attribute :>> clearWidth {
                :>> value = 1.50;
            }
        }
    }

    part def HvacSystem {
        attribute designSupplyTemperature : Temperature {
            :>> value = 291.15;
        }
        attribute maximumSupplyFlow : VolumeFlowRate {
            :>> value = 4.20;
        }
        port lobbyZone : AirZonePort;
        port officeZone : AirZonePort;
        port conferenceZone : AirZonePort;
        port breakZone : AirZonePort;
        port restroomExhaustA : AirZonePort;
        port restroomExhaustB : AirZonePort;
        port corridorZone : AirZonePort;
        port mechanicalZone : AirZonePort;
        port stairPressurization : AirZonePort;
        perform action regulateAir : RegulateAirByFloorPlan;
    }

    part def LightingSystem {
        attribute normalTargetIlluminance : Illuminance {
            :>> value = 500.0;
        }
        attribute corridorTargetIlluminance : Illuminance {
            :>> value = 150.0;
        }
        port lobbyLighting : LightingControlPort;
        port officeLighting : LightingControlPort;
        port conferenceLighting : LightingControlPort;
        port breakLighting : LightingControlPort;
        port restroomLightingA : LightingControlPort;
        port restroomLightingB : LightingControlPort;
        port corridorLighting : LightingControlPort;
        port mechanicalLighting : LightingControlPort;
        port stairLighting : LightingControlPort;
        perform action adaptLighting : AdaptLightingByOccupancy;
    }

    part def AccessControlSystem {
        port publicEntryControl : AccessControlPort;
        port staffEntryControl : AccessControlPort;
        port conferenceAccessControl : AccessControlPort;
        port mechanicalAccessControl : AccessControlPort;
        perform action manageAccess : ManageAccessByFloorPlan;
    }

    part def LifeSafetySystem {
        attribute maximumEvacuationCapacity : Count {
            :>> value = 120;
        }
        port lobbyAlarm : AlarmPort;
        port officeAlarm : AlarmPort;
        port conferenceAlarm : AlarmPort;
        port breakAlarm : AlarmPort;
        port restroomAlarmA : AlarmPort;
        port restroomAlarmB : AlarmPort;
        port corridorAlarm : AlarmPort;
        port mechanicalAlarm : AlarmPort;
        port stairAlarm : AlarmPort;
        perform action coordinateEvacuation : CoordinateEvacuation;
    }

    part def BuildingServices {
        part hvac : HvacSystem;
        part lighting : LightingSystem;
        part accessControl : AccessControlSystem;
        part lifeSafety : LifeSafetySystem;
    }

    action def ReadFloorPlan {
        in item floorPlanInput : FloorPlanDescription;
        out item interpretedPlan : FloorPlanDescription;
    }

    action def AllocateSpaces {
        in item interpretedPlan : FloorPlanDescription;
        out item expectedOccupancy : OccupancyReport;
    }

    action def RegulateAirByFloorPlan {
        in item occupancy : OccupancyReport;
        out item conditionedAir : ConditionedAir;
    }

    action def AdaptLightingByOccupancy {
        in item occupancy : OccupancyReport;
        out item command : LightingCommand;
    }

    action def ManageAccessByFloorPlan {
        in item occupancy : OccupancyReport;
        out item command : AccessCommand;
    }

    action def CoordinateEvacuation {
        in item occupancy : OccupancyReport;
        out item alarm : AlarmSignal;
    }

    action def CoordinateFloorUse {
        doc /* Primary high-level function: interpret the floor plan, organize people and services by space, support safe circulation, and coordinate HVAC, lighting, access, and life-safety behavior for the occupied floor. */
        in item floorPlanInput : FloorPlanDescription;
        in item currentOccupancy : OccupancyReport;
        out item occupancySummary : OccupancyReport;
        out item lightingCommand : LightingCommand;
        out item accessCommand : AccessCommand;
        out item alarmSignal : AlarmSignal;

        action readPlan : ReadFloorPlan;
        action allocateBySpace : AllocateSpaces;
        action regulateAir : RegulateAirByFloorPlan;
        action adaptLighting : AdaptLightingByOccupancy;
        action manageAccess : ManageAccessByFloorPlan;
        action coordinateEvacuation : CoordinateEvacuation;

        succession readThenAllocate first readPlan then allocateBySpace;
        succession allocateThenAir first allocateBySpace then regulateAir;
        succession allocateThenLighting first allocateBySpace then adaptLighting;
        succession allocateThenAccess first allocateBySpace then manageAccess;
        succession allocateThenSafety first allocateBySpace then coordinateEvacuation;
    }

    action def PrepareBuildingForOccupancy {
        out item command : AccessCommand;
    }

    action def MaintainComfort {
        in item occupancy : OccupancyReport;
        out item air : ConditionedAir;
        out item light : LightingCommand;
    }

    action def SupportEmergencyEvacuation {
        in item occupancy : OccupancyReport;
        out item alarm : AlarmSignal;
    }

    action def ReduceEnergyUse {
        out item light : LightingCommand;
    }

    action def PerformMaintenance {
        out item alarm : AlarmSignal;
    }

    state def FacilityOperatingModes {
        entry; then Unoccupied;

        state Unoccupied {
            entry action reduceLoads : ReduceEnergyUse;
        }

        state Opening {
            entry action prepare : PrepareBuildingForOccupancy;
        }

        state Occupied {
            entry action maintain : MaintainComfort;
        }

        state Emergency {
            entry action evacuate : SupportEmergencyEvacuation;
        }

        state Maintenance {
            entry action service : PerformMaintenance;
        }

        state EnergySaving {
            entry action conserve : ReduceEnergyUse;
        }

        transition beginDay first Unoccupied then Opening;
        transition admitOccupants first Opening then Occupied;
        transition afterHours first Occupied then EnergySaving;
        transition closeFloor first EnergySaving then Unoccupied;
        transition emergencyFromOccupied first Occupied then Emergency;
        transition emergencyFromOpening first Opening then Emergency;
        transition resetAfterEmergency first Emergency then Maintenance;
        transition returnToService first Maintenance then Unoccupied;
    }

    requirement def PrimaryFunctionRequirement {
        subject facility : FloorPlanBasedFacilitySystem;
        doc /* The system shall use the floor plan as the organizing basis for the floor and shall coordinate occupancy, circulation, comfort, access, lighting, and life-safety services at a high level. */
    }

    requirement def FloorPlanCompletenessRequirement {
        subject plan : ArchitecturalFloorPlan;
        doc /* The floor plan shall identify primary spaces, circulation paths, emergency egress, service rooms, access points, and gross and usable areas. */
    }

    requirement def SafeCirculationRequirement {
        subject plan : ArchitecturalFloorPlan;
        doc /* The floor plan shall provide connected occupant routes from all occupied rooms to the lobby corridor and emergency stair. */
    }

    requirement def ServiceCoverageRequirement {
        subject facility : FloorPlanBasedFacilitySystem;
        doc /* HVAC, lighting, access control, and life-safety services shall be allocated to all regularly occupied and circulation spaces defined by the floor plan. */
    }

    part def FloorPlanBasedFacilitySystem {
        doc /* A floor-plan-based facility system whose primary function is to organize spaces and coordinate building services for safe, comfortable, and efficient use of the floor. */

        attribute name : String = "Floor Plan Based Office Facility System";
        attribute currentMode : FacilityModeKind = FacilityModeKind::unoccupied;
        attribute designOccupantCapacity : Count {
            :>> value = 109;
        }

        part floorPlan : ArchitecturalFloorPlan;
        part services : BuildingServices;

        port floorPlanInterface : FloorPlanPort;
        port publicOccupantAccess : OccupantFlowPort;
        port emergencyDischarge : OccupantFlowPort;

        perform action primaryFunction : CoordinateFloorUse;
        exhibit state operatingModes : FacilityOperatingModes;

        connection publicEntryRoute : OccupantRoute connect publicOccupantAccess to floorPlan.lobby.publicAccess {
            attribute :>> clearWidth {
                :>> value = 1.80;
            }
        }

        connection emergencyDischargeRoute : OccupantRoute connect floorPlan.emergencyStair.exteriorDischarge to emergencyDischarge {
            attribute :>> clearWidth {
                :>> value = 1.50;
            }
        }

        connection lobbyAir : AirDistributionConnection connect services.hvac.lobbyZone to floorPlan.lobby.supplyAir;
        connection officeAir : AirDistributionConnection connect services.hvac.officeZone to floorPlan.openOffice.supplyAir;
        connection conferenceAir : AirDistributionConnection connect services.hvac.conferenceZone to floorPlan.conferenceRoom.supplyAir;
        connection breakRoomAir : AirDistributionConnection connect services.hvac.breakZone to floorPlan.breakRoom.supplyAir;
        connection restroomAirA : AirDistributionConnection connect services.hvac.restroomExhaustA to floorPlan.restroomA.exhaustAir;
        connection restroomAirB : AirDistributionConnection connect services.hvac.restroomExhaustB to floorPlan.restroomB.exhaustAir;
        connection corridorAir : AirDistributionConnection connect services.hvac.corridorZone to floorPlan.mainCorridor.supplyAir;
        connection mechanicalAir : AirDistributionConnection connect services.hvac.mechanicalZone to floorPlan.mechanicalRoom.supplyAir;
        connection stairAir : AirDistributionConnection connect services.hvac.stairPressurization to floorPlan.emergencyStair.pressurizationAir;

        connection lobbyLightingControl : LightingControlConnection connect services.lighting.lobbyLighting to floorPlan.lobby.lightingZone;
        connection officeLightingControl : LightingControlConnection connect services.lighting.officeLighting to floorPlan.openOffice.lightingZone;
        connection conferenceLightingControl : LightingControlConnection connect services.lighting.conferenceLighting to floorPlan.conferenceRoom.lightingZone;
        connection breakLightingControl : LightingControlConnection connect services.lighting.breakLighting to floorPlan.breakRoom.lightingZone;
        connection restroomLightingControlA : LightingControlConnection connect services.lighting.restroomLightingA to floorPlan.restroomA.lightingZone;
        connection restroomLightingControlB : LightingControlConnection connect services.lighting.restroomLightingB to floorPlan.restroomB.lightingZone;
        connection corridorLightingControl : LightingControlConnection connect services.lighting.corridorLighting to floorPlan.mainCorridor.lightingZone;
        connection mechanicalLightingControl : LightingControlConnection connect services.lighting.mechanicalLighting to floorPlan.mechanicalRoom.lightingZone;
        connection stairLightingControl : LightingControlConnection connect services.lighting.stairLighting to floorPlan.emergencyStair.lightingZone;

        connection publicDoorControl : AccessControlConnection connect services.accessControl.publicEntryControl to floorPlan.lobby.publicEntry.accessControl;
        connection staffDoorControl : AccessControlConnection connect services.accessControl.staffEntryControl to floorPlan.emergencyStair.exitDoor.accessControl;
        connection mechanicalDoorControl : AccessControlConnection connect services.accessControl.mechanicalAccessControl to floorPlan.mechanicalRoom.staffAccess;
        connection conferenceDoorControl : AccessControlConnection connect services.accessControl.conferenceAccessControl to floorPlan.conferenceRoom.mainAccess;

        connection lobbyAlarmConnection : AlarmConnection connect services.lifeSafety.lobbyAlarm to floorPlan.lobby.alarmDevice;
        connection officeAlarmConnection : AlarmConnection connect services.lifeSafety.officeAlarm to floorPlan.openOffice.alarmDevice;
        connection conferenceAlarmConnection : AlarmConnection connect services.lifeSafety.conferenceAlarm to floorPlan.conferenceRoom.alarmDevice;
        connection breakAlarmConnection : AlarmConnection connect services.lifeSafety.breakAlarm to floorPlan.breakRoom.alarmDevice;
        connection restroomAlarmConnectionA : AlarmConnection connect services.lifeSafety.restroomAlarmA to floorPlan.restroomA.alarmDevice;
        connection restroomAlarmConnectionB : AlarmConnection connect services.lifeSafety.restroomAlarmB to floorPlan.restroomB.alarmDevice;
        connection corridorAlarmConnection : AlarmConnection connect services.lifeSafety.corridorAlarm to floorPlan.mainCorridor.alarmDevice;
        connection mechanicalAlarmConnection : AlarmConnection connect services.lifeSafety.mechanicalAlarm to floorPlan.mechanicalRoom.alarmDevice;
        connection stairAlarmConnection : AlarmConnection connect services.lifeSafety.stairAlarm to floorPlan.emergencyStair.alarmDevice;
    }

    part headquartersFloorSystem : FloorPlanBasedFacilitySystem;

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
        subject facility = headquartersFloorSystem;
    }

    requirement floorPlanCompletenessRequirement : FloorPlanCompletenessRequirement {
        subject plan = headquartersFloorSystem.floorPlan;
    }

    requirement safeCirculationRequirement : SafeCirculationRequirement {
        subject plan = headquartersFloorSystem.floorPlan;
    }

    requirement serviceCoverageRequirement : ServiceCoverageRequirement {
        subject facility = headquartersFloorSystem;
    }
}
