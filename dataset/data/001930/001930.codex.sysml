package SpacecraftMissionSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Mass :> ISQ::mass {
        unit = SI::kg;
    }

    attribute def Length :> ISQ::length {
        unit = SI::m;
    }

    attribute def Area :> ISQ::area {
        unit = SI::m^2;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = SI::s;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::K;
    }

    attribute def ElectricPotential :> ISQ::electricPotential {
        unit = SI::V;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = SI::A;
    }

    attribute def ElectricPower :> ISQ::power {
        unit = SI::W;
    }

    attribute def Energy :> ISQ::energy {
        unit = SI::J;
    }

    attribute def DataRate {
        attribute value : Real;
        unit = "bit/s";
    }

    attribute def DataVolume {
        attribute value : Real;
        unit = "bit";
    }

    attribute def Frequency {
        attribute value : Real;
        unit = "Hz";
    }

    attribute def Angle {
        attribute value : Real;
        unit = "rad";
    }

    attribute def AngularRate {
        attribute value : Real;
        unit = "rad/s";
    }

    attribute def Velocity {
        attribute value : Real;
        unit = "m/s";
    }

    attribute def Acceleration {
        attribute value : Real;
        unit = "m/s^2";
    }

    attribute def Force {
        attribute value : Real;
        unit = "N";
    }

    attribute def Pressure {
        attribute value : Real;
        unit = "Pa";
    }

    attribute def OrbitAltitude :> Length;
    attribute def PropellantMass :> Mass;
    attribute def BatteryStateOfCharge {
        attribute value : Real;
        unit = "percent";
    }

    item def CommandPacket {
        attribute packetId : Integer;
        attribute executionTime : TimeDuration;
        attribute priority : Integer;
        attribute authenticated : Boolean;
    }

    item def TelemetryFrame {
        attribute frameId : Integer;
        attribute timestamp : TimeDuration;
        attribute healthStatusCode : Integer;
        attribute payloadDataVolume : DataVolume;
    }

    item def ScienceObservation {
        attribute observationId : Integer;
        attribute targetLatitude : Angle;
        attribute targetLongitude : Angle;
        attribute acquisitionTime : TimeDuration;
        attribute rawDataVolume : DataVolume;
        attribute processedDataVolume : DataVolume;
    }

    item def NavigationSolution {
        attribute epoch : TimeDuration;
        attribute positionX : Length;
        attribute positionY : Length;
        attribute positionZ : Length;
        attribute velocityX : Velocity;
        attribute velocityY : Velocity;
        attribute velocityZ : Velocity;
        attribute attitudeRoll : Angle;
        attribute attitudePitch : Angle;
        attribute attitudeYaw : Angle;
    }

    item def ElectricalEnergyFlow {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute power : ElectricPower;
    }

    item def ThermalEnergyFlow {
        attribute heatRate : ElectricPower;
        attribute sourceTemperature : Temperature;
        attribute sinkTemperature : Temperature;
    }

    item def PropellantFlow {
        attribute massFlowRate {
            attribute value : Real;
            unit = "kg/s";
        }
        attribute tankPressure : Pressure;
        attribute temperature : Temperature;
    }

    item def ThrustVector {
        attribute magnitude : Force;
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute duration : TimeDuration;
    }

    port def CommandReceiverPort {
        in item command : CommandPacket;
    }

    port def TelemetryTransmitterPort {
        out item telemetry : TelemetryFrame;
    }

    port def ScienceDataPort {
        out item observation : ScienceObservation;
    }

    port def NavigationDataPort {
        out item navigation : NavigationSolution;
    }

    port def ElectricalPowerPort {
        inout item electricalPower : ElectricalEnergyFlow;
    }

    port def ThermalInterfacePort {
        inout item thermalEnergy : ThermalEnergyFlow;
    }

    port def PropellantPort {
        out item propellant : PropellantFlow;
    }

    port def ThrustPort {
        out item thrust : ThrustVector;
    }

    port def DataBusPort {
        inout item command : CommandPacket;
        inout item telemetry : TelemetryFrame;
        inout item observation : ScienceObservation;
        inout item navigation : NavigationSolution;
    }

    part def Spacecraft {
        attribute dryMass : Mass;
        attribute launchMass : Mass;
        attribute designLife : TimeDuration;
        attribute nominalOrbitAltitude : OrbitAltitude;
        attribute maximumPowerGeneration : ElectricPower;
        attribute averagePayloadPower : ElectricPower;
        attribute storedEnergyCapacity : Energy;
        attribute downlinkRate : DataRate;
        attribute attitudeKnowledgeAccuracy : Angle;
        attribute attitudeControlAccuracy : Angle;
        attribute propellantCapacity : PropellantMass;

        port commandUplink : CommandReceiverPort;
        port telemetryDownlink : TelemetryTransmitterPort;
        port scienceDownlink : ScienceDataPort;
        port missionDataBus : DataBusPort;

        part structure : SpacecraftBusStructure;
        part electricalPowerSubsystem : ElectricalPowerSubsystem;
        part commandAndDataHandling : CommandAndDataHandlingSubsystem;
        part communications : CommunicationsSubsystem;
        part attitudeDeterminationAndControl : AttitudeDeterminationAndControlSubsystem;
        part propulsion : PropulsionSubsystem;
        part thermalControl : ThermalControlSubsystem;
        part payload : EarthObservationPayload;

        connect commandUplink.command to communications.commandReceiver.command;
        connect communications.dataBus.command to commandAndDataHandling.dataBus.command;
        connect commandAndDataHandling.dataBus.telemetry to communications.dataBus.telemetry;
        connect communications.telemetryTransmitter.telemetry to telemetryDownlink.telemetry;
        connect payload.scienceData.observation to commandAndDataHandling.dataBus.observation;
        connect commandAndDataHandling.dataBus.observation to communications.dataBus.observation;
        connect communications.scienceTransmitter.observation to scienceDownlink.observation;
        connect attitudeDeterminationAndControl.navigationOutput.navigation to commandAndDataHandling.dataBus.navigation;
        connect electricalPowerSubsystem.primaryBus.electricalPower to commandAndDataHandling.power.electricalPower;
        connect electricalPowerSubsystem.primaryBus.electricalPower to communications.power.electricalPower;
        connect electricalPowerSubsystem.primaryBus.electricalPower to attitudeDeterminationAndControl.power.electricalPower;
        connect electricalPowerSubsystem.primaryBus.electricalPower to propulsion.power.electricalPower;
        connect electricalPowerSubsystem.primaryBus.electricalPower to thermalControl.power.electricalPower;
        connect electricalPowerSubsystem.primaryBus.electricalPower to payload.power.electricalPower;
        connect propulsion.thrustOutput.thrust to attitudeDeterminationAndControl.externalTorqueInput.thrust;
        connect propulsion.thermalInterface.thermalEnergy to thermalControl.thermalBus.thermalEnergy;
        connect payload.thermalInterface.thermalEnergy to thermalControl.thermalBus.thermalEnergy;
        connect communications.thermalInterface.thermalEnergy to thermalControl.thermalBus.thermalEnergy;
        connect electricalPowerSubsystem.thermalInterface.thermalEnergy to thermalControl.thermalBus.thermalEnergy;
    }

    part def SpacecraftBusStructure {
        attribute busMass : Mass;
        attribute length : Length;
        attribute width : Length;
        attribute height : Length;
        attribute firstModeFrequency : Frequency;
        attribute payloadMountingFlatness : Length;
        attribute launchLoadLimit : Acceleration;
    }

    part def ElectricalPowerSubsystem {
        attribute solarArrayArea : Area;
        attribute solarArrayOutputEol : ElectricPower;
        attribute batteryCapacity : Energy;
        attribute batteryStateOfCharge : BatteryStateOfCharge;
        attribute regulatedBusVoltage : ElectricPotential;
        attribute eclipseSurvivalDuration : TimeDuration;

        port primaryBus : ElectricalPowerPort;
        port thermalInterface : ThermalInterfacePort;

        part solarArray : SolarArray;
        part battery : Battery;
        part powerControlUnit : PowerControlUnit;

        connect solarArray.powerOutput.electricalPower to powerControlUnit.arrayInput.electricalPower;
        connect battery.batteryPower.electricalPower to powerControlUnit.batteryInterface.electricalPower;
        connect powerControlUnit.regulatedOutput.electricalPower to primaryBus.electricalPower;
    }

    part def SolarArray {
        attribute deployedArea : Area;
        attribute conversionEfficiency : Real;
        attribute outputVoltage : ElectricPotential;
        attribute beginningOfLifePower : ElectricPower;
        attribute endOfLifePower : ElectricPower;
        port powerOutput : ElectricalPowerPort;
    }

    part def Battery {
        attribute capacity : Energy;
        attribute maximumDepthOfDischarge : BatteryStateOfCharge;
        attribute minimumOperationalSoc : BatteryStateOfCharge;
        attribute nominalVoltage : ElectricPotential;
        port batteryPower : ElectricalPowerPort;
    }

    part def PowerControlUnit {
        attribute busVoltage : ElectricPotential;
        attribute maximumLoadPower : ElectricPower;
        attribute conversionEfficiency : Real;
        port arrayInput : ElectricalPowerPort;
        port batteryInterface : ElectricalPowerPort;
        port regulatedOutput : ElectricalPowerPort;
    }

    part def CommandAndDataHandlingSubsystem {
        attribute processorClockFrequency : Frequency;
        attribute volatileMemory : DataVolume;
        attribute nonvolatileStorage : DataVolume;
        attribute maximumInternalDataRate : DataRate;
        attribute faultDetectionLatency : TimeDuration;

        port dataBus : DataBusPort;
        port power : ElectricalPowerPort;

        part flightComputer : FlightComputer;
        part massMemory : MassMemory;
        part softwareController : MissionSoftwareController;

        connect flightComputer.storageInterface.observation to massMemory.storageBus.observation;
        connect flightComputer.spacecraftBus.command to dataBus.command;
        connect flightComputer.spacecraftBus.telemetry to dataBus.telemetry;
        connect flightComputer.spacecraftBus.navigation to dataBus.navigation;
        connect massMemory.storageBus.observation to dataBus.observation;
    }

    part def FlightComputer {
        attribute processorPower : ElectricPower;
        attribute commandValidationTime : TimeDuration;
        attribute autonomousRecoveryEnabled : Boolean;
        port spacecraftBus : DataBusPort;
        port storageInterface : DataBusPort;
    }

    part def MassMemory {
        attribute capacity : DataVolume;
        attribute sustainedWriteRate : DataRate;
        attribute sustainedReadRate : DataRate;
        port storageBus : DataBusPort;
    }

    part def MissionSoftwareController {
        attribute releaseVersionMajor : Integer;
        attribute releaseVersionMinor : Integer;
        attribute safeModeEntryThreshold : Integer;
    }

    part def CommunicationsSubsystem {
        attribute uplinkFrequency : Frequency;
        attribute downlinkFrequency : Frequency;
        attribute commandUplinkRate : DataRate;
        attribute telemetryDownlinkRate : DataRate;
        attribute scienceDownlinkRate : DataRate;
        attribute antennaPointingRequirement : Angle;

        port commandReceiver : CommandReceiverPort;
        port telemetryTransmitter : TelemetryTransmitterPort;
        port scienceTransmitter : ScienceDataPort;
        port dataBus : DataBusPort;
        port power : ElectricalPowerPort;
        port thermalInterface : ThermalInterfacePort;

        part sBandTransceiver : SBandTransceiver;
        part xBandTransmitter : XBandTransmitter;
        part highGainAntenna : HighGainAntenna;
        part lowGainAntenna : LowGainAntenna;

        connect commandReceiver.command to sBandTransceiver.commandInput.command;
        connect sBandTransceiver.dataInterface.command to dataBus.command;
        connect dataBus.telemetry to sBandTransceiver.dataInterface.telemetry;
        connect sBandTransceiver.telemetryOutput.telemetry to telemetryTransmitter.telemetry;
        connect dataBus.observation to xBandTransmitter.scienceInput.observation;
        connect xBandTransmitter.scienceOutput.observation to scienceTransmitter.observation;
    }

    part def SBandTransceiver {
        attribute uplinkFrequency : Frequency;
        attribute downlinkFrequency : Frequency;
        attribute transmitterPower : ElectricPower;
        port commandInput : CommandReceiverPort;
        port telemetryOutput : TelemetryTransmitterPort;
        port dataInterface : DataBusPort;
    }

    part def XBandTransmitter {
        attribute carrierFrequency : Frequency;
        attribute transmitterPower : ElectricPower;
        attribute modulationEfficiency : Real;
        port scienceInput : ScienceDataPort;
        port scienceOutput : ScienceDataPort;
    }

    part def HighGainAntenna {
        attribute diameter : Length;
        attribute gain : Real;
        attribute beamwidth : Angle;
    }

    part def LowGainAntenna {
        attribute gain : Real;
        attribute fieldOfView : Angle;
    }

    part def AttitudeDeterminationAndControlSubsystem {
        attribute attitudeKnowledgeAccuracy : Angle;
        attribute attitudeControlAccuracy : Angle;
        attribute maximumSlewRate : AngularRate;
        attribute momentumStorageCapacity {
            attribute value : Real;
            unit = "N*m*s";
        }

        port power : ElectricalPowerPort;
        port navigationOutput : NavigationDataPort;
        port externalTorqueInput : ThrustPort;

        part starTracker : StarTracker;
        part inertialMeasurementUnit : InertialMeasurementUnit;
        part reactionWheelAssembly : ReactionWheelAssembly;
        part magnetorquerAssembly : MagnetorquerAssembly;
        part gpsReceiver : GpsReceiver;

        connect gpsReceiver.navigationOutput.navigation to navigationOutput.navigation;
    }

    part def StarTracker {
        attribute updateRate : Frequency;
        attribute accuracy : Angle;
        attribute powerConsumption : ElectricPower;
    }

    part def InertialMeasurementUnit {
        attribute angularRateRange : AngularRate;
        attribute biasStability : AngularRate;
        attribute updateRate : Frequency;
    }

    part def ReactionWheelAssembly {
        attribute wheelCount : Integer;
        attribute maximumTorque {
            attribute value : Real;
            unit = "N*m";
        }
        attribute momentumCapacity {
            attribute value : Real;
            unit = "N*m*s";
        }
        attribute powerConsumption : ElectricPower;
    }

    part def MagnetorquerAssembly {
        attribute rodCount : Integer;
        attribute maximumDipole {
            attribute value : Real;
            unit = "A*m^2";
        }
        attribute powerConsumption : ElectricPower;
    }

    part def GpsReceiver {
        attribute positionAccuracy : Length;
        attribute velocityAccuracy : Velocity;
        attribute updateRate : Frequency;
        port navigationOutput : NavigationDataPort;
    }

    part def PropulsionSubsystem {
        attribute totalPropellantCapacity : PropellantMass;
        attribute remainingPropellant : PropellantMass;
        attribute nominalThrust : Force;
        attribute specificImpulse {
            attribute value : Real;
            unit = "s";
        }
        attribute minimumImpulseBit {
            attribute value : Real;
            unit = "N*s";
        }

        port power : ElectricalPowerPort;
        port propellantFeed : PropellantPort;
        port thrustOutput : ThrustPort;
        port thermalInterface : ThermalInterfacePort;

        part propellantTank : PropellantTank;
        part pressureRegulator : PressureRegulator;
        part thrusterSet : ThrusterSet;

        connect propellantTank.outlet.propellant to pressureRegulator.inlet.propellant;
        connect pressureRegulator.outlet.propellant to thrusterSet.feed.propellant;
        connect thrusterSet.thrust.thrust to thrustOutput.thrust;
    }

    part def PropellantTank {
        attribute capacity : PropellantMass;
        attribute fillMass : PropellantMass;
        attribute maximumPressure : Pressure;
        port outlet : PropellantPort;
    }

    part def PressureRegulator {
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;
        port inlet : PropellantPort;
        port outlet : PropellantPort;
    }

    part def ThrusterSet {
        attribute thrusterCount : Integer;
        attribute thrustPerThruster : Force;
        attribute valveResponseTime : TimeDuration;
        port feed : PropellantPort;
        port thrust : ThrustPort;
    }

    part def ThermalControlSubsystem {
        attribute minimumEquipmentTemperature : Temperature;
        attribute maximumEquipmentTemperature : Temperature;
        attribute heaterPowerCapacity : ElectricPower;
        attribute radiatorArea : Area;

        port power : ElectricalPowerPort;
        port thermalBus : ThermalInterfacePort;

        part multilayerInsulation : MultilayerInsulation;
        part radiatorPanel : RadiatorPanel;
        part heaterController : HeaterController;
        part temperatureSensorNetwork : TemperatureSensorNetwork;
    }

    part def MultilayerInsulation {
        attribute coveredArea : Area;
        attribute effectiveEmissivity : Real;
    }

    part def RadiatorPanel {
        attribute area : Area;
        attribute emissivity : Real;
        attribute heatRejectionCapacity : ElectricPower;
    }

    part def HeaterController {
        attribute heaterChannelCount : Integer;
        attribute maximumHeaterPower : ElectricPower;
        attribute controlDeadband : Temperature;
    }

    part def TemperatureSensorNetwork {
        attribute sensorCount : Integer;
        attribute measurementAccuracy : Temperature;
        attribute samplingFrequency : Frequency;
    }

    part def EarthObservationPayload {
        attribute apertureDiameter : Length;
        attribute groundSampleDistance : Length;
        attribute swathWidth : Length;
        attribute detectorTemperature : Temperature;
        attribute observationDataRate : DataRate;
        attribute nominalObservationDuration : TimeDuration;

        port power : ElectricalPowerPort;
        port scienceData : ScienceDataPort;
        port thermalInterface : ThermalInterfacePort;

        part telescope : OpticalTelescope;
        part focalPlane : FocalPlaneAssembly;
        part payloadProcessor : PayloadDataProcessor;

        connect focalPlane.rawObservation.observation to payloadProcessor.processingInput.observation;
        connect payloadProcessor.processedObservation.observation to scienceData.observation;
    }

    part def OpticalTelescope {
        attribute apertureDiameter : Length;
        attribute focalLength : Length;
        attribute fieldOfView : Angle;
        attribute opticalTransmissionEfficiency : Real;
    }

    part def FocalPlaneAssembly {
        attribute detectorPixelCount : Integer;
        attribute detectorTemperature : Temperature;
        attribute integrationTime : TimeDuration;
        port rawObservation : ScienceDataPort;
    }

    part def PayloadDataProcessor {
        attribute compressionRatio : Real;
        attribute processingLatency : TimeDuration;
        attribute processorPower : ElectricPower;
        port processingInput : ScienceDataPort;
        port processedObservation : ScienceDataPort;
    }

    action def ExecutePrimaryMission {
        in item missionCommand : CommandPacket;
        out item deliveredTelemetry : TelemetryFrame;
        out item deliveredObservation : ScienceObservation;

        action receiveCommand;
        action validateCommand;
        action configureSpacecraft;
        action pointPayloadAtTarget;
        action acquireObservation;
        action processAndStoreData;
        action downlinkScienceData;
        action downlinkHealthTelemetry;

        first start;
        then receiveCommand;
        then validateCommand;
        then configureSpacecraft;
        then pointPayloadAtTarget;
        then acquireObservation;
        then processAndStoreData;
        then downlinkScienceData;
        then downlinkHealthTelemetry;
        then done;
    }

    action def PerformOrbitMaintenance {
        in item navigationEstimate : NavigationSolution;
        out item maneuverTelemetry : TelemetryFrame;

        action computeDeltaV;
        action configureAttitude;
        action armThrusters;
        action fireThrusters;
        action verifyOrbit;
        action reportManeuver;

        first start;
        then computeDeltaV;
        then configureAttitude;
        then armThrusters;
        then fireThrusters;
        then verifyOrbit;
        then reportManeuver;
        then done;
    }

    action def ManageSpacecraftHealth {
        out item healthTelemetry : TelemetryFrame;

        action collectSubsystemTelemetry;
        action evaluateFaultRules;
        action managePowerBalance;
        action regulateThermalState;
        action scheduleCommunications;
        action commandRecoveryIfNeeded;

        first start;
        then collectSubsystemTelemetry;
        then evaluateFaultRules;
        then managePowerBalance;
        then regulateThermalState;
        then scheduleCommunications;
        then commandRecoveryIfNeeded;
        then done;
    }

    state def SpacecraftOperationalStates {
        state Initializing;
        state LaunchSafe;
        state Commissioning;
        state NominalMission;
        state Observation;
        state DataDownlink;
        state OrbitMaintenance;
        state SafeMode;
        state EndOfLifePassivation;

        initial then Initializing;

        transition Initializing_to_LaunchSafe
            first Initializing
            accept when true
            then LaunchSafe;

        transition LaunchSafe_to_Commissioning
            first LaunchSafe
            accept CommandPacket
            if command.authenticated
            then Commissioning;

        transition Commissioning_to_NominalMission
            first Commissioning
            accept when true
            then NominalMission;

        transition NominalMission_to_Observation
            first NominalMission
            accept CommandPacket
            if command.authenticated and command.priority >= 5
            then Observation;

        transition Observation_to_DataDownlink
            first Observation
            accept when true
            then DataDownlink;

        transition DataDownlink_to_NominalMission
            first DataDownlink
            accept when true
            then NominalMission;

        transition NominalMission_to_OrbitMaintenance
            first NominalMission
            accept CommandPacket
            if command.authenticated and command.priority >= 7
            then OrbitMaintenance;

        transition OrbitMaintenance_to_NominalMission
            first OrbitMaintenance
            accept when true
            then NominalMission;

        transition Any_to_SafeMode
            first NominalMission
            accept when true
            if false
            then SafeMode;

        transition SafeMode_to_NominalMission
            first SafeMode
            accept CommandPacket
            if command.authenticated and command.priority >= 9
            then NominalMission;

        transition NominalMission_to_EndOfLifePassivation
            first NominalMission
            accept CommandPacket
            if command.authenticated and command.priority == 10
            then EndOfLifePassivation;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The spacecraft shall provide an autonomous orbital platform that observes selected Earth surface targets, stores and processes acquired payload data, and returns science data and health telemetry to ground operators. */
        subject spacecraft : Spacecraft;
        require constraint {
            spacecraft.designLife >= 157680000 [s]
        }
    }

    requirement def PayloadObservationRequirement {
        doc /* The spacecraft shall acquire Earth observation data with ground sample distance no greater than 5 m during scheduled observation windows. */
        subject payload : EarthObservationPayload;
        require constraint {
            payload.groundSampleDistance <= 5 [m]
        }
    }

    requirement def ScienceDataReturnRequirement {
        doc /* The spacecraft shall downlink processed science observations at a data rate sufficient to empty one full observation pass within a ground contact window. */
        subject spacecraft : Spacecraft;
        require constraint {
            spacecraft.downlinkRate >= 50000000 [bit/s]
        }
    }

    requirement def PowerPositiveRequirement {
        doc /* The spacecraft electrical power subsystem shall generate sufficient end-of-life power to support nominal bus loads, payload operation, communications, and battery recharge. */
        subject eps : ElectricalPowerSubsystem;
        require constraint {
            eps.solarArrayOutputEol >= 1200 [W]
        }
    }

    requirement def EclipseSurvivalRequirement {
        doc /* The spacecraft shall survive eclipse without ground intervention while maintaining critical avionics, communications receiver, and thermal control functions. */
        subject eps : ElectricalPowerSubsystem;
        require constraint {
            eps.eclipseSurvivalDuration >= 2100 [s]
        }
    }

    requirement def AttitudePointingRequirement {
        doc /* The spacecraft shall point the observation payload at commanded targets with sufficient stability for imaging. */
        subject adcs : AttitudeDeterminationAndControlSubsystem;
        require constraint {
            adcs.attitudeControlAccuracy <= 0.000174533 [rad]
        }
    }

    requirement def TelemetryRequirement {
        doc /* The spacecraft shall provide health and status telemetry for all major subsystems during every scheduled ground contact. */
        subject cdh : CommandAndDataHandlingSubsystem;
        require constraint {
            cdh.faultDetectionLatency <= 10 [s]
        }
    }

    requirement def ThermalRequirement {
        doc /* The spacecraft shall maintain all operational equipment within allowable thermal limits throughout nominal mission operations. */
        subject thermal : ThermalControlSubsystem;
        require constraint {
            thermal.minimumEquipmentTemperature >= 253 [K] and thermal.maximumEquipmentTemperature <= 323 [K]
        }
    }

    requirement def OrbitMaintenanceRequirement {
        doc /* The spacecraft shall perform commanded orbit maintenance maneuvers using onboard propulsion and verified navigation data. */
        subject propulsion : PropulsionSubsystem;
        require constraint {
            propulsion.totalPropellantCapacity >= 40 [kg]
        }
    }

    requirement def SafeModeRequirement {
        doc /* The spacecraft shall enter a power-positive safe mode when autonomous fault detection identifies loss of attitude control, critical thermal violation, or insufficient battery state of charge. */
        subject spacecraft : Spacecraft;
        require constraint {
            spacecraft.storedEnergyCapacity >= 1800000 [J]
        }
    }

    part spacecraftSystem : Spacecraft {
        attribute dryMass = 520 [kg];
        attribute launchMass = 680 [kg];
        attribute designLife = 189216000 [s];
        attribute nominalOrbitAltitude = 600000 [m];
        attribute maximumPowerGeneration = 1600 [W];
        attribute averagePayloadPower = 280 [W];
        attribute storedEnergyCapacity = 2200000 [J];
        attribute downlinkRate = 150000000 [bit/s];
        attribute attitudeKnowledgeAccuracy = 0.0000872665 [rad];
        attribute attitudeControlAccuracy = 0.000174533 [rad];
        attribute propellantCapacity = 55 [kg];

        part structure {
            attribute busMass = 115 [kg];
            attribute length = 1.8 [m];
            attribute width = 1.4 [m];
            attribute height = 1.6 [m];
            attribute firstModeFrequency = 45 [Hz];
            attribute payloadMountingFlatness = 0.00015 [m];
            attribute launchLoadLimit = 60 [m/s^2];
        }

        part electricalPowerSubsystem {
            attribute solarArrayArea = 8.5 [m^2];
            attribute solarArrayOutputEol = 1350 [W];
            attribute batteryCapacity = 2300000 [J];
            attribute batteryStateOfCharge = 82 [percent];
            attribute regulatedBusVoltage = 28 [V];
            attribute eclipseSurvivalDuration = 2400 [s];

            part solarArray {
                attribute deployedArea = 8.5 [m^2];
                attribute conversionEfficiency = 0.29;
                attribute outputVoltage = 42 [V];
                attribute beginningOfLifePower = 1650 [W];
                attribute endOfLifePower = 1350 [W];
            }

            part battery {
                attribute capacity = 2300000 [J];
                attribute maximumDepthOfDischarge = 35 [percent];
                attribute minimumOperationalSoc = 45 [percent];
                attribute nominalVoltage = 28 [V];
            }

            part powerControlUnit {
                attribute busVoltage = 28 [V];
                attribute maximumLoadPower = 1450 [W];
                attribute conversionEfficiency = 0.94;
            }
        }

        part commandAndDataHandling {
            attribute processorClockFrequency = 200000000 [Hz];
            attribute volatileMemory = 8589934592 [bit];
            attribute nonvolatileStorage = 8796093022208 [bit];
            attribute maximumInternalDataRate = 1000000000 [bit/s];
            attribute faultDetectionLatency = 5 [s];

            part flightComputer {
                attribute processorPower = 35 [W];
                attribute commandValidationTime = 0.25 [s];
                attribute autonomousRecoveryEnabled = true;
            }

            part massMemory {
                attribute capacity = 8796093022208 [bit];
                attribute sustainedWriteRate = 800000000 [bit/s];
                attribute sustainedReadRate = 800000000 [bit/s];
            }

            part softwareController {
                attribute releaseVersionMajor = 3;
                attribute releaseVersionMinor = 4;
                attribute safeModeEntryThreshold = 2;
            }
        }

        part communications {
            attribute uplinkFrequency = 2090000000 [Hz];
            attribute downlinkFrequency = 8475000000 [Hz];
            attribute commandUplinkRate = 32000 [bit/s];
            attribute telemetryDownlinkRate = 1000000 [bit/s];
            attribute scienceDownlinkRate = 150000000 [bit/s];
            attribute antennaPointingRequirement = 0.00872665 [rad];

            part sBandTransceiver {
                attribute uplinkFrequency = 2090000000 [Hz];
                attribute downlinkFrequency = 2270000000 [Hz];
                attribute transmitterPower = 12 [W];
            }

            part xBandTransmitter {
                attribute carrierFrequency = 8475000000 [Hz];
                attribute transmitterPower = 45 [W];
                attribute modulationEfficiency = 0.82;
            }

            part highGainAntenna {
                attribute diameter = 0.65 [m];
                attribute gain = 34.5;
                attribute beamwidth = 0.0349066 [rad];
            }

            part lowGainAntenna {
                attribute gain = 4.0;
                attribute fieldOfView = 2.0944 [rad];
            }
        }

        part attitudeDeterminationAndControl {
            attribute attitudeKnowledgeAccuracy = 0.0000872665 [rad];
            attribute attitudeControlAccuracy = 0.000174533 [rad];
            attribute maximumSlewRate = 0.0174533 [rad/s];
            attribute momentumStorageCapacity = 50 [N*m*s];

            part starTracker {
                attribute updateRate = 10 [Hz];
                attribute accuracy = 0.0000484814 [rad];
                attribute powerConsumption = 12 [W];
            }

            part inertialMeasurementUnit {
                attribute angularRateRange = 0.0872665 [rad/s];
                attribute biasStability = 0.000001 [rad/s];
                attribute updateRate = 100 [Hz];
            }

            part reactionWheelAssembly {
                attribute wheelCount = 4;
                attribute maximumTorque = 0.08 [N*m];
                attribute momentumCapacity = 50 [N*m*s];
                attribute powerConsumption = 80 [W];
            }

            part magnetorquerAssembly {
                attribute rodCount = 3;
                attribute maximumDipole = 90 [A*m^2];
                attribute powerConsumption = 30 [W];
            }

            part gpsReceiver {
                attribute positionAccuracy = 10 [m];
                attribute velocityAccuracy = 0.03 [m/s];
                attribute updateRate = 1 [Hz];
            }
        }

        part propulsion {
            attribute totalPropellantCapacity = 55 [kg];
            attribute remainingPropellant = 51 [kg];
            attribute nominalThrust = 1.0 [N];
            attribute specificImpulse = 220 [s];
            attribute minimumImpulseBit = 0.05 [N*s];

            part propellantTank {
                attribute capacity = 55 [kg];
                attribute fillMass = 51 [kg];
                attribute maximumPressure = 2400000 [Pa];
            }

            part pressureRegulator {
                attribute inletPressure = 2200000 [Pa];
                attribute outletPressure = 500000 [Pa];
            }

            part thrusterSet {
                attribute thrusterCount = 8;
                attribute thrustPerThruster = 1.0 [N];
                attribute valveResponseTime = 0.02 [s];
            }
        }

        part thermalControl {
            attribute minimumEquipmentTemperature = 253 [K];
            attribute maximumEquipmentTemperature = 323 [K];
            attribute heaterPowerCapacity = 220 [W];
            attribute radiatorArea = 2.4 [m^2];

            part multilayerInsulation {
                attribute coveredArea = 12 [m^2];
                attribute effectiveEmissivity = 0.03;
            }

            part radiatorPanel {
                attribute area = 2.4 [m^2];
                attribute emissivity = 0.86;
                attribute heatRejectionCapacity = 650 [W];
            }

            part heaterController {
                attribute heaterChannelCount = 16;
                attribute maximumHeaterPower = 220 [W];
                attribute controlDeadband = 3 [K];
            }

            part temperatureSensorNetwork {
                attribute sensorCount = 48;
                attribute measurementAccuracy = 1 [K];
                attribute samplingFrequency = 1 [Hz];
            }
        }

        part payload {
            attribute apertureDiameter = 0.45 [m];
            attribute groundSampleDistance = 3.5 [m];
            attribute swathWidth = 20000 [m];
            attribute detectorTemperature = 210 [K];
            attribute observationDataRate = 600000000 [bit/s];
            attribute nominalObservationDuration = 120 [s];

            part telescope {
                attribute apertureDiameter = 0.45 [m];
                attribute focalLength = 4.5 [m];
                attribute fieldOfView = 0.0698132 [rad];
                attribute opticalTransmissionEfficiency = 0.72;
            }

            part focalPlane {
                attribute detectorPixelCount = 48000000;
                attribute detectorTemperature = 210 [K];
                attribute integrationTime = 0.001 [s];
            }

            part payloadProcessor {
                attribute compressionRatio = 2.8;
                attribute processingLatency = 4 [s];
                attribute processorPower = 65 [W];
            }
        }
    }

    satisfy PrimaryFunctionRequirement by spacecraftSystem;
    satisfy ScienceDataReturnRequirement by spacecraftSystem;
    satisfy SafeModeRequirement by spacecraftSystem;
    satisfy PowerPositiveRequirement by spacecraftSystem.electricalPowerSubsystem;
    satisfy EclipseSurvivalRequirement by spacecraftSystem.electricalPowerSubsystem;
    satisfy PayloadObservationRequirement by spacecraftSystem.payload;
    satisfy AttitudePointingRequirement by spacecraftSystem.attitudeDeterminationAndControl;
    satisfy TelemetryRequirement by spacecraftSystem.commandAndDataHandling;
    satisfy ThermalRequirement by spacecraftSystem.thermalControl;
    satisfy OrbitMaintenanceRequirement by spacecraftSystem.propulsion;

    exhibit state SpacecraftOperationalStates by spacecraftSystem;
    perform action ExecutePrimaryMission by spacecraftSystem;
    perform action ManageSpacecraftHealth by spacecraftSystem;
    perform action PerformOrbitMaintenance by spacecraftSystem;
}