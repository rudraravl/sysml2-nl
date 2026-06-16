package STS_133_System_Model {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def MissionIdentifier : String;
    attribute def CrewCount : Integer;
    attribute def Percent : Real {
        unit = "%";
    }

    attribute def Kilogram : Real {
        unit = "kg";
    }

    attribute def Meter : Real {
        unit = "m";
    }

    attribute def Newton : Real {
        unit = "N";
    }

    attribute def Second : Real {
        unit = "s";
    }

    attribute def Minute : Real {
        unit = "min";
    }

    attribute def Hour : Real {
        unit = "h";
    }

    attribute def Day : Real {
        unit = "d";
    }

    item def CryogenicOxygen;
    item def CryogenicHydrogen;
    item def MonomethylHydrazine;
    item def NitrogenTetroxide;
    item def ElectricalPower;
    item def CommandData;
    item def TelemetryData;
    item def VoiceData;
    item def VideoData;
    item def EnvironmentalControlFluid;
    item def PressurizedCargo;
    item def ExternalCargo;
    item def CrewMember;
    item def EVAEquipment;
    item def DockingLoad;
    item def RoboticCommand;
    item def ThermalEnergy;
    item def WasteGas;
    item def GuidanceStateVector;
    item def AttitudeControlImpulse;
    item def OrbitalManeuverImpulse;

    port def CryogenicFeedPort {
        out item oxygen : CryogenicOxygen;
        out item hydrogen : CryogenicHydrogen;
    }

    port def PropellantFeedPort {
        out item fuel : MonomethylHydrazine;
        out item oxidizer : NitrogenTetroxide;
    }

    port def PowerPort {
        out item powerOut : ElectricalPower;
        in item powerIn : ElectricalPower;
    }

    port def DataPort {
        in item command : CommandData;
        out item telemetry : TelemetryData;
    }

    port def CommunicationPort {
        in item voiceIn : VoiceData;
        out item voiceOut : VoiceData;
        out item videoOut : VideoData;
        in item commandIn : CommandData;
        out item telemetryOut : TelemetryData;
    }

    port def CargoTransferPort {
        out item pressurizedCargoOut : PressurizedCargo;
        in item returnCargoIn : PressurizedCargo;
    }

    port def ExternalPayloadPort {
        out item externalCargoOut : ExternalCargo;
        in item structuralLoadIn : DockingLoad;
        in item roboticCommandIn : RoboticCommand;
    }

    port def DockingPort {
        out item dockingLoadOut : DockingLoad;
        in item dockingLoadIn : DockingLoad;
        in item powerIn : ElectricalPower;
        out item telemetryOut : TelemetryData;
        in item commandIn : CommandData;
    }

    port def CrewTransferPort {
        out item crewOut : CrewMember;
        in item crewIn : CrewMember;
        out item evaEquipmentOut : EVAEquipment;
    }

    port def ThermalPort {
        out item rejectedHeat : ThermalEnergy;
        in item absorbedHeat : ThermalEnergy;
    }

    port def VentPort {
        out item wasteGas : WasteGas;
    }

    part def SpaceTransportationSystem133 {
        attribute missionId : MissionIdentifier = "STS-133";
        attribute orbiterName : String = "Discovery";
        attribute primaryFunction : String =
            "Deliver and install the Permanent Multipurpose Module Leonardo and Express Logistics Carrier 4 to the International Space Station while transporting crew, equipment, spares, and return cargo.";
        attribute nominalCrew : CrewCount = 6;
        attribute missionDuration : Day = 12.8 [d];
        attribute targetOrbitAltitude : Kilogram = 0 [kg];

        port groundLink : CommunicationPort;
        port issDockingInterface : DockingPort;
        port payloadBayExternalInterface : ExternalPayloadPort;
        port crewHatchInterface : CrewTransferPort;

        part launchStack : LaunchStack;
        part orbiter : OrbiterDiscovery;
        part externalTank : ExternalTank;
        part leftSolidRocketBooster : SolidRocketBooster;
        part rightSolidRocketBooster : SolidRocketBooster;
        part payloadElement : STS133PayloadSet;
        part crew : STS133Crew;
        part groundSegment : MissionControlSegment;
        part issTarget : InternationalSpaceStationSegment;

        connect launchStack.cryogenicSupply to externalTank.cryogenicFeed;
        connect externalTank.engineFeed to orbiter.mainPropulsion.cryogenicFeed;
        connect leftSolidRocketBooster.thrustAttach to launchStack.leftBoosterAttach;
        connect rightSolidRocketBooster.thrustAttach to launchStack.rightBoosterAttach;
        connect orbiter.payloadBay.externalPayloadPort to payloadElement.externalCargoInterface;
        connect orbiter.payloadBay.pressurizedCargoPort to payloadElement.pressurizedCargoInterface;
        connect orbiter.forwardHatch to issDockingInterface;
        connect issDockingInterface to issTarget.pressurizedMatingAdapter;
        connect orbiter.communicationSystem.spaceGroundPort to groundLink;
        connect groundLink to groundSegment.shuttleFlightControlLink;
        connect crew.crewTransfer to crewHatchInterface;
        connect crewHatchInterface to orbiter.forwardHatch;

        exhibit state missionLifeCycle : STS133MissionStateMachine;
        perform action executeMission : ExecuteSTS133Mission;
    }

    part def LaunchStack {
        attribute liftoffMass : Kilogram = 2040000 [kg];
        attribute stackHeight : Meter = 56.1 [m];
        attribute launchSite : String = "Kennedy Space Center Launch Complex 39A";

        port cryogenicSupply : CryogenicFeedPort;
        port leftBoosterAttach;
        port rightBoosterAttach;

        part ascentGuidance : AscentGuidanceComputer;
        part rangeSafety : RangeSafetySystem;
    }

    part def OrbiterDiscovery {
        attribute dryMass : Kilogram = 78300 [kg];
        attribute length : Meter = 37.2 [m];
        attribute wingspan : Meter = 23.8 [m];
        attribute landingMode : String = "unpowered runway landing";
        attribute crossRangeCapability : Meter = 1850000 [m];

        port forwardHatch : DockingPort;
        port aftPropulsionFeed : PropellantFeedPort;
        port thermalInterface : ThermalPort;
        port ventInterface : VentPort;

        part mainPropulsion : SpaceShuttleMainPropulsionSystem;
        part orbitalManeuveringSystem : OrbitalManeuveringSystem;
        part reactionControlSystem : ReactionControlSystem;
        part avionics : OrbiterAvionics;
        part communicationSystem : OrbiterCommunicationSystem;
        part electricalPowerSystem : OrbiterElectricalPowerSystem;
        part environmentalControlSystem : EnvironmentalControlAndLifeSupport;
        part payloadBay : PayloadBay;
        part dockingSystem : OrbiterDockingSystem;
        part remoteManipulatorSystem : ShuttleRemoteManipulatorSystem;
        part airlock : Airlock;
        part thermalProtectionSystem : ThermalProtectionSystem;
        part landingSystem : LandingSystem;

        connect mainPropulsion.powerPort to electricalPowerSystem.mainBus;
        connect avionics.dataBus to communicationSystem.avionicsData;
        connect avionics.powerPort to electricalPowerSystem.avionicsBus;
        connect environmentalControlSystem.powerPort to electricalPowerSystem.lifeSupportBus;
        connect payloadBay.powerPort to electricalPowerSystem.payloadBus;
        connect dockingSystem.dockingPort to forwardHatch;
        connect airlock.hatchPort to forwardHatch;
        connect remoteManipulatorSystem.payloadGrapplePort to payloadBay.externalPayloadPort;
        connect thermalProtectionSystem.thermalPort to thermalInterface;
        connect environmentalControlSystem.ventPort to ventInterface;
    }

    part def SpaceShuttleMainPropulsionSystem {
        attribute mainEngineCount : Integer = 3;
        attribute vacuumThrustPerEngine : Newton = 2279000 [N];
        attribute throttleRangeLow : Percent = 67 [%];
        attribute throttleRangeHigh : Percent = 109 [%];

        port cryogenicFeed : CryogenicFeedPort;
        port powerPort : PowerPort;

        part engine1 : MainEngine;
        part engine2 : MainEngine;
        part engine3 : MainEngine;
    }

    part def MainEngine {
        attribute propellantType : String = "liquid oxygen and liquid hydrogen";
        attribute restartableInFlight : Boolean = false;
        attribute gimbalCapability : Boolean = true;
        port feed : CryogenicFeedPort;
        port commandData : DataPort;
    }

    part def ExternalTank {
        attribute loadedMass : Kilogram = 756000 [kg];
        attribute length : Meter = 46.9 [m];
        attribute diameter : Meter = 8.4 [m];

        port cryogenicFeed : CryogenicFeedPort;
        port engineFeed : CryogenicFeedPort;

        part liquidOxygenTank : CryogenicTank {
            attribute storedFluid : String = "liquid oxygen";
            attribute nominalCapacity : Kilogram = 629000 [kg];
        }

        part liquidHydrogenTank : CryogenicTank {
            attribute storedFluid : String = "liquid hydrogen";
            attribute nominalCapacity : Kilogram = 106000 [kg];
        }
    }

    part def CryogenicTank {
        attribute storedFluid : String;
        attribute nominalCapacity : Kilogram;
        attribute insulationType : String = "spray-on foam insulation";
        port outlet : CryogenicFeedPort;
    }

    part def SolidRocketBooster {
        attribute boosterCountRole : String;
        attribute burnDuration : Second = 124 [s];
        attribute averageThrust : Newton = 12500000 [N];
        attribute recoveryMode : String = "parachute ocean recovery";

        port thrustAttach;
        port rangeSafetyData : DataPort;

        part solidMotor : ReusableSolidRocketMotor;
        part separationSystem : BoosterSeparationSystem;
        part recoverySystem : BoosterRecoverySystem;
    }

    part def ReusableSolidRocketMotor {
        attribute propellantMass : Kilogram = 503000 [kg];
        attribute grainType : String = "segmented solid propellant";
    }

    part def BoosterSeparationSystem {
        attribute separationTrigger : String = "post-burnout altitude and dynamic pressure criteria";
    }

    part def BoosterRecoverySystem {
        attribute parachuteCount : Integer = 3;
        attribute beaconEnabled : Boolean = true;
    }

    part def OrbitalManeuveringSystem {
        attribute engineCount : Integer = 2;
        attribute vacuumThrustPerEngine : Newton = 26700 [N];
        attribute propellantLoad : Kilogram = 21000 [kg];

        port propellantFeed : PropellantFeedPort;
        port impulseOut {
            out item impulse : OrbitalManeuverImpulse;
        }
        port commandData : DataPort;
    }

    part def ReactionControlSystem {
        attribute primaryThrusterCount : Integer = 38;
        attribute vernierThrusterCount : Integer = 6;
        attribute propellantType : String = "monomethylhydrazine and nitrogen tetroxide";

        port propellantFeed : PropellantFeedPort;
        port attitudeImpulseOut {
            out item impulse : AttitudeControlImpulse;
        }
        port commandData : DataPort;
    }

    part def OrbiterAvionics {
        attribute generalPurposeComputerCount : Integer = 5;
        attribute redundancyManagement : String = "quad-redundant primary avionics software system with backup flight system";

        port dataBus : DataPort;
        port powerPort : PowerPort;
        port guidanceOutput {
            out item stateVector : GuidanceStateVector;
        }

        part flightSoftware : FlightSoftware;
        part inertialMeasurementUnits : InertialNavigationSet;
        part displayAndControl : CrewDisplayAndControlSystem;
    }

    part def FlightSoftware {
        attribute ascentModeAvailable : Boolean = true;
        attribute rendezvousModeAvailable : Boolean = true;
        attribute entryModeAvailable : Boolean = true;
    }

    part def InertialNavigationSet {
        attribute unitCount : Integer = 3;
        attribute alignmentSupported : Boolean = true;
    }

    part def CrewDisplayAndControlSystem {
        attribute flightDeckStations : Integer = 4;
        attribute aftFlightDeckRoboticsStation : Boolean = true;
    }

    part def OrbiterCommunicationSystem {
        attribute KuBandAvailable : Boolean = true;
        attribute SBandAvailable : Boolean = true;
        attribute UHFEnabledForEVA : Boolean = true;

        port spaceGroundPort : CommunicationPort;
        port avionicsData : DataPort;
    }

    part def OrbiterElectricalPowerSystem {
        attribute fuelCellCount : Integer = 3;
        attribute nominalBusVoltage : Real = 28.0;

        port mainBus : PowerPort;
        port avionicsBus : PowerPort;
        port payloadBus : PowerPort;
        port lifeSupportBus : PowerPort;

        part fuelCell1 : FuelCell;
        part fuelCell2 : FuelCell;
        part fuelCell3 : FuelCell;
    }

    part def FuelCell {
        attribute reactants : String = "hydrogen and oxygen";
        attribute productWaterReusable : Boolean = true;
        port powerOutput : PowerPort;
    }

    part def EnvironmentalControlAndLifeSupport {
        attribute cabinPressure : Real = 101.3;
        attribute oxygenPartialPressureManaged : Boolean = true;
        attribute carbonDioxideRemovalEnabled : Boolean = true;
        attribute potableWaterGeneratedByFuelCells : Boolean = true;

        port powerPort : PowerPort;
        port thermalPort : ThermalPort;
        port ventPort : VentPort;
    }

    part def PayloadBay {
        attribute length : Meter = 18.3 [m];
        attribute diameter : Meter = 4.6 [m];
        attribute doorsRadiatorFunction : Boolean = true;

        port externalPayloadPort : ExternalPayloadPort;
        port pressurizedCargoPort : CargoTransferPort;
        port powerPort : PowerPort;
        port dataPort : DataPort;

        part payloadRetentionLatches : PayloadRetentionLatchSet;
        part radiatorPanels : PayloadBayRadiatorSet;
    }

    part def PayloadRetentionLatchSet {
        attribute latchCount : Integer = 12;
        attribute remoteReleaseEnabled : Boolean = true;
    }

    part def PayloadBayRadiatorSet {
        attribute heatRejectionRole : String = "orbiter active thermal control heat rejection on orbit";
        port thermalPort : ThermalPort;
    }

    part def OrbiterDockingSystem {
        attribute compatibleInterface : String = "ISS Pressurized Mating Adapter";
        attribute tunnelPressurizable : Boolean = true;
        attribute relativeMotionDamping : Boolean = true;

        port dockingPort : DockingPort;
        port powerPort : PowerPort;
        port dataPort : DataPort;
    }

    part def ShuttleRemoteManipulatorSystem {
        attribute armLength : Meter = 15.2 [m];
        attribute degreesOfFreedom : Integer = 6;
        attribute operatorStation : String = "aft flight deck";
        attribute payloadHandlingRole : String = "grapple, berth, and handoff payload elements during ISS assembly operations";

        port payloadGrapplePort : ExternalPayloadPort;
        port commandPort {
            in item command : RoboticCommand;
        }
        port dataPort : DataPort;
    }

    part def Airlock {
        attribute evaSupported : Boolean = true;
        attribute suitPorts : Integer = 2;

        port hatchPort : DockingPort;
        port crewPort : CrewTransferPort;
    }

    part def ThermalProtectionSystem {
        attribute reinforcedCarbonCarbonNoseAndWingLeadingEdges : Boolean = true;
        attribute silicaTileCoverage : Boolean = true;
        attribute reentryHeatingSurvivable : Boolean = true;

        port thermalPort : ThermalPort;
    }

    part def LandingSystem {
        attribute landingGearCount : Integer = 3;
        attribute brakingSystem : String = "main gear brakes with drag chute";
        attribute nominalLandingSite : String = "Kennedy Space Center Shuttle Landing Facility";
    }

    part def STS133PayloadSet {
        attribute totalDeliveredCargoMass : Kilogram = 12500 [kg];

        port externalCargoInterface : ExternalPayloadPort;
        port pressurizedCargoInterface : CargoTransferPort;

        part permanentMultipurposeModuleLeonardo : PermanentMultipurposeModuleLeonardo;
        part expressLogisticsCarrier4 : ExpressLogisticsCarrier4;
        part robonaut2 : Robonaut2;
        part spareEquipmentSet : ISSSparesAndLogisticsSet;

        connect permanentMultipurposeModuleLeonardo.transferPort to pressurizedCargoInterface;
        connect expressLogisticsCarrier4.externalMountPort to externalCargoInterface;
        connect spareEquipmentSet.pressurizedTransferPort to permanentMultipurposeModuleLeonardo.internalCargoPort;
        connect robonaut2.cargoInterface to permanentMultipurposeModuleLeonardo.internalCargoPort;
    }

    part def PermanentMultipurposeModuleLeonardo {
        attribute launchMass : Kilogram = 9500 [kg];
        attribute primaryRole : String = "permanent pressurized storage and logistics module for the ISS";
        attribute installedLocation : String = "ISS Unity nadir common berthing mechanism";
        attribute pressurizedVolume : Real = 70.0;

        port transferPort : CargoTransferPort;
        port internalCargoPort : CargoTransferPort;
        port berthingInterface : DockingPort;
        port powerDataInterface : DataPort;

        part cargoRacks : PressurizedRackSet;
        part environmentalInterfaces : PMMEnvironmentalInterface;
    }

    part def PressurizedRackSet {
        attribute rackCount : Integer = 16;
        attribute contents : String = "equipment racks, crew provisions, spares, and experiment support hardware";
    }

    part def PMMEnvironmentalInterface {
        attribute ventilationRequired : Boolean = true;
        attribute smokeDetectionRequired : Boolean = true;
        attribute lightingRequired : Boolean = true;
    }

    part def ExpressLogisticsCarrier4 {
        attribute launchMass : Kilogram = 3600 [kg];
        attribute primaryRole : String = "external spare parts and orbital replacement unit carrier";
        attribute installedLocation : String = "ISS starboard truss external logistics site";
        attribute payloadAttachmentSites : Integer = 6;

        port externalMountPort : ExternalPayloadPort;
        port stationPowerDataPort : DataPort;

        part heatRejectionSystemRadiator : ExternalOrbitalReplacementUnit;
        part sparePayloads : ExternalSpareSet;
    }

    part def ExternalOrbitalReplacementUnit {
        attribute unitRole : String = "replaceable ISS external subsystem component";
        attribute roboticInstallable : Boolean = true;
    }

    part def ExternalSpareSet {
        attribute containsRoboticCompatibleSpareParts : Boolean = true;
        attribute externalStorageDuration : Day = 3650 [d];
    }

    part def Robonaut2 {
        attribute mass : Kilogram = 136 [kg];
        attribute role : String = "technology demonstration humanoid assistant for ISS internal operations";
        attribute operationalEnvironment : String = "pressurized ISS cabin";

        port cargoInterface : CargoTransferPort;
    }

    part def ISSSparesAndLogisticsSet {
        attribute foodClothingAndEquipmentIncluded : Boolean = true;
        attribute maintenanceHardwareIncluded : Boolean = true;
        attribute returnCargoAllocated : Boolean = true;

        port pressurizedTransferPort : CargoTransferPort;
    }

    part def STS133Crew {
        attribute commander : String = "Steven Lindsey";
        attribute pilot : String = "Eric Boe";
        attribute missionSpecialist1 : String = "Alvin Drew";
        attribute missionSpecialist2 : String = "Steve Bowen";
        attribute missionSpecialist3 : String = "Michael Barratt";
        attribute missionSpecialist4 : String = "Nicole Stott";
        attribute crewSize : CrewCount = 6;

        port crewTransfer : CrewTransferPort;

        part flightDeckTeam : FlightDeckCrew;
        part evaTeam : EVACrew;
        part roboticsTeam : RoboticsCrew;
    }

    part def FlightDeckCrew {
        attribute ascentEntryOperators : Integer = 2;
        attribute rendezvousOperators : Integer = 4;
    }

    part def EVACrew {
        attribute evaCountPlanned : Integer = 2;
        attribute evaObjectives : String = "ISS maintenance, cable routing, camera installation, and preparation tasks";
    }

    part def RoboticsCrew {
        attribute shuttleArmOperators : Integer = 2;
        attribute stationArmCoordinationRequired : Boolean = true;
    }

    part def MissionControlSegment {
        attribute primaryControlCenter : String = "Johnson Space Center Mission Control Center";
        attribute launchControlCenter : String = "Kennedy Space Center";
        attribute trackingNetwork : String = "TDRSS and ground stations";

        port shuttleFlightControlLink : CommunicationPort;

        part flightDirectorConsole : FlightDirectorConsole;
        part propulsionConsole : DisciplineConsole;
        part guidanceConsole : DisciplineConsole;
        part evaConsole : DisciplineConsole;
        part payloadConsole : DisciplineConsole;
    }

    part def FlightDirectorConsole {
        attribute authority : String = "integrated mission execution authority";
    }

    part def DisciplineConsole {
        attribute consoleRole : String;
        port commandTelemetry : DataPort;
    }

    part def InternationalSpaceStationSegment {
        attribute destination : String = "International Space Station";
        attribute assemblyOperationSupported : Boolean = true;
        attribute crewLogisticsSupported : Boolean = true;

        port pressurizedMatingAdapter : DockingPort;
        port commonBerthingMechanism : DockingPort;
        port externalLogisticsSite : ExternalPayloadPort;
        port stationRoboticsCommand : ExternalPayloadPort;

        part stationRoboticArm : SpaceStationRemoteManipulatorSystem;
        part unityNode : ISSUnityNode;
        part trussSegment : ISSTrussSegment;

        connect commonBerthingMechanism to unityNode.nadirBerthingPort;
        connect externalLogisticsSite to trussSegment.elcMountSite;
        connect stationRoboticArm.payloadPort to externalLogisticsSite;
    }

    part def SpaceStationRemoteManipulatorSystem {
        attribute armLength : Meter = 17.6 [m];
        attribute mobileBaseCapable : Boolean = true;
        attribute payloadInstallRole : String = "install PMM and ELC-4 with shuttle arm support";

        port payloadPort : ExternalPayloadPort;
        port commandPort {
            in item command : RoboticCommand;
        }
    }

    part def ISSUnityNode {
        attribute moduleRole : String = "pressurized connecting node";
        port nadirBerthingPort : DockingPort;
    }

    part def ISSTrussSegment {
        attribute role : String = "external structural, power, and thermal backbone";
        port elcMountSite : ExternalPayloadPort;
    }

    action def ExecuteSTS133Mission {
        in item missionSystem : SpaceTransportationSystem133;
        out item deliveredPressurizedCargo : PressurizedCargo;
        out item deliveredExternalCargo : ExternalCargo;
        out item returnedCargo : PressurizedCargo;

        first startLaunchCountdown;
        then performAscent;
        then separateBoosters;
        then jettisonExternalTank;
        then performOrbitInsertion;
        then inspectThermalProtectionSystem;
        then rendezvousWithISS;
        then dockToISS;
        then transferCrewAndPressurizedCargo;
        then installPermanentMultipurposeModule;
        then installExpressLogisticsCarrier4;
        then conductEVAOperations;
        then loadReturnCargo;
        then undockFromISS;
        then performDeorbitBurn;
        then executeEntryAndLanding;
    }

    action def startLaunchCountdown {
        out item launchCommit : CommandData;
    }

    action def performAscent {
        in item launchCommit : CommandData;
        out item ascentTelemetry : TelemetryData;
    }

    action def separateBoosters {
        in item ascentTelemetry : TelemetryData;
        out item separationConfirmed : TelemetryData;
    }

    action def jettisonExternalTank {
        in item separationConfirmed : TelemetryData;
        out item tankSeparationConfirmed : TelemetryData;
    }

    action def performOrbitInsertion {
        in item tankSeparationConfirmed : TelemetryData;
        out item orbitState : GuidanceStateVector;
    }

    action def inspectThermalProtectionSystem {
        in item orbitState : GuidanceStateVector;
        out item inspectionData : VideoData;
    }

    action def rendezvousWithISS {
        in item orbitState : GuidanceStateVector;
        out item proximityOperationsState : GuidanceStateVector;
    }

    action def dockToISS {
        in item proximityOperationsState : GuidanceStateVector;
        out item hardMateConfirmed : DockingLoad;
    }

    action def transferCrewAndPressurizedCargo {
        in item hardMateConfirmed : DockingLoad;
        out item cargoTransferred : PressurizedCargo;
    }

    action def installPermanentMultipurposeModule {
        in item cargoTransferred : PressurizedCargo;
        out item pmmInstalled : DockingLoad;
    }

    action def installExpressLogisticsCarrier4 {
        out item elc4Installed : ExternalCargo;
    }

    action def conductEVAOperations {
        out item evaCompleted : TelemetryData;
    }

    action def loadReturnCargo {
        in item evaCompleted : TelemetryData;
        out item returnCargoReady : PressurizedCargo;
    }

    action def undockFromISS {
        in item returnCargoReady : PressurizedCargo;
        out item separationState : GuidanceStateVector;
    }

    action def performDeorbitBurn {
        in item separationState : GuidanceStateVector;
        out item entryInterfaceState : GuidanceStateVector;
    }

    action def executeEntryAndLanding {
        in item entryInterfaceState : GuidanceStateVector;
        out item wheelsStopTelemetry : TelemetryData;
    }

    state def STS133MissionStateMachine {
        entry action initializeMissionSystems;

        state Prelaunch;
        state PoweredAscent;
        state BoosterRecovery;
        state OrbitalInsertion;
        state OnOrbitCheckout;
        state Rendezvous;
        state DockedISSOperations;
        state PayloadInstallation;
        state EVAOperations;
        state Departure;
        state Entry;
        state Landing;
        state MissionComplete;
        state AbortMode;

        transition first Prelaunch;
        transition Prelaunch to PoweredAscent
            accept LaunchCommit
            then action igniteMainEnginesAndBoosters;

        transition PoweredAscent to BoosterRecovery
            accept BoosterBurnout
            then action commandBoosterSeparation;

        transition BoosterRecovery to OrbitalInsertion
            accept MainEngineCutoff
            then action separateExternalTank;

        transition OrbitalInsertion to OnOrbitCheckout
            accept OMSInsertionComplete
            then action openPayloadBayDoors;

        transition OnOrbitCheckout to Rendezvous
            accept ThermalInspectionComplete
            then action executePhasingBurns;

        transition Rendezvous to DockedISSOperations
            accept DockingConfirmed
            then action equalizePressureAndOpenHatches;

        transition DockedISSOperations to PayloadInstallation
            accept CargoTransferReady
            then action configureRobotics;

        transition PayloadInstallation to EVAOperations
            accept PMMAndELC4Installed
            then action configureAirlock;

        transition EVAOperations to Departure
            accept EVAAndReturnCargoComplete
            then action closeHatches;

        transition Departure to Entry
            accept SeparationAndDeorbitGo
            then action performDeorbitBurnCommand;

        transition Entry to Landing
            accept RunwayAcquired
            then action deployLandingGear;

        transition Landing to MissionComplete
            accept WheelsStop
            then action safeOrbiter;

        transition Prelaunch to AbortMode
            accept CriticalLaunchHold;
        transition PoweredAscent to AbortMode
            accept AscentAbortDeclared;
        transition OnOrbitCheckout to AbortMode
            accept CriticalOrbiterFault;
        transition Rendezvous to AbortMode
            accept RendezvousAbortCommand;
    }

    action def initializeMissionSystems;
    action def igniteMainEnginesAndBoosters;
    action def commandBoosterSeparation;
    action def separateExternalTank;
    action def openPayloadBayDoors;
    action def executePhasingBurns;
    action def equalizePressureAndOpenHatches;
    action def configureRobotics;
    action def configureAirlock;
    action def closeHatches;
    action def performDeorbitBurnCommand;
    action def deployLandingGear;
    action def safeOrbiter;

    requirement def PrimaryFunctionRequirement {
        doc /* The STS-133 system shall transport crew and logistics payloads from Earth to the International Space Station and return the orbiter and assigned return cargo safely to Earth. */
        subject sts133 : SpaceTransportationSystem133;
        require constraint {
            sts133.nominalCrew == 6
        }
    }

    requirement def PMMDeliveryRequirement {
        doc /* The STS-133 system shall deliver the Permanent Multipurpose Module Leonardo and support its permanent installation on the International Space Station. */
        subject payload : PermanentMultipurposeModuleLeonardo;
        require constraint {
            payload.launchMass <= 10000 [kg]
        }
    }

    requirement def ELC4DeliveryRequirement {
        doc /* The STS-133 system shall deliver Express Logistics Carrier 4 and support its installation on an ISS external logistics site. */
        subject carrier : ExpressLogisticsCarrier4;
        require constraint {
            carrier.payloadAttachmentSites >= 4
        }
    }

    requirement def CrewTransportRequirement {
        doc /* The STS-133 system shall provide ascent, on-orbit, docked, entry, and landing support for six crew members. */
        subject crew : STS133Crew;
        require constraint {
            crew.crewSize == 6
        }
    }

    requirement def DockingRequirement {
        doc /* The orbiter shall provide a pressurizable docking interface compatible with the ISS pressurized mating adapter to enable crew and cargo transfer. */
        subject dockingSystem : OrbiterDockingSystem;
        require constraint {
            dockingSystem.tunnelPressurizable == true
        }
    }

    requirement def RoboticsRequirement {
        doc /* The mission shall provide robotic handling capability for payload extraction, handoff, and installation coordination with ISS robotics. */
        subject arm : ShuttleRemoteManipulatorSystem;
        require constraint {
            arm.degreesOfFreedom == 6
        }
    }

    requirement def SafeReturnRequirement {
        doc /* The orbiter shall protect crew and vehicle through atmospheric entry and complete an unpowered runway landing after mission operations. */
        subject orbiter : OrbiterDiscovery;
        require constraint {
            orbiter.landingMode == "unpowered runway landing"
        }
    }

    requirement def CommunicationRequirement {
        doc /* The mission shall maintain command, telemetry, voice, and video communication between the orbiter and mission control during critical mission phases. */
        subject comm : OrbiterCommunicationSystem;
        require constraint {
            comm.SBandAvailable == true and comm.KuBandAvailable == true
        }
    }

    satisfy PrimaryFunctionRequirement by SpaceTransportationSystem133;
    satisfy PMMDeliveryRequirement by PermanentMultipurposeModuleLeonardo;
    satisfy ELC4DeliveryRequirement by ExpressLogisticsCarrier4;
    satisfy CrewTransportRequirement by STS133Crew;
    satisfy DockingRequirement by OrbiterDockingSystem;
    satisfy RoboticsRequirement by ShuttleRemoteManipulatorSystem;
    satisfy SafeReturnRequirement by OrbiterDiscovery;
    satisfy CommunicationRequirement by OrbiterCommunicationSystem;
}