package OrbitalSpacecraftSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import ISQSpace::*;

    // ===== Value Types =====
    attribute def Distance :> Length;
    attribute def VelocityValue :> Speed;
    attribute def MassValue :> Mass;
    attribute def PowerValue :> Power;
    attribute def EnergyValue :> Energy;
    attribute def DurationValue :> Duration;
    attribute def AngleValue :> PlaneAngle;
    attribute def ThrustValue :> Force;
    attribute def FrequencyValue :> Frequency;
    attribute def DataRateValue :> Real;

    // ===== Item Definitions =====
    item def OrbitalState {
        attribute altitude: Distance;
        attribute position: Distance[3];
        attribute velocity: VelocityValue[3];
        attribute attitude: AngleValue[3];
        attribute inclination: AngleValue;
    }

    item def BurnCommand {
        attribute deltaV: VelocityValue;
        attribute direction: AngleValue[3];
        attribute duration: DurationValue;
    }

    item def ThrustVector {
        attribute magnitude: ThrustValue;
        attribute direction: AngleValue[3];
        attribute burnDuration: DurationValue;
    }

    item def ElectricalPower {
        attribute voltage: Real;
        attribute current: Real;
        attribute powerLevel: PowerValue;
    }

    item def Telemetry {
        attribute spacecraftHealth: String;
        attribute orbitalState: OrbitalState;
        attribute timestamp: DurationValue;
        attribute batteryCharge: Real;
    }

    item def Command {
        attribute commandId: String;
        attribute parameter: String;
        attribute priority: Integer;
    }

    item def MissionData {
        attribute payloadId: String;
        attribute content: String;
        attribute size: Integer;
        attribute timestamp: DurationValue;
    }

    // ===== Port Definitions =====
    port def PowerOutPort {
        out power: ElectricalPower;
    }
    port def PowerInPort {
        in power: ElectricalPower;
    }
    port def CommandOutPort {
        out command: Command;
    }
    port def CommandInPort {
        in command: Command;
    }
    port def TelemetryOutPort {
        out telemetry: Telemetry;
    }
    port def TelemetryInPort {
        in telemetry: Telemetry;
    }
    port def MissionDataOutPort {
        out data: MissionData;
    }
    port def MissionDataInPort {
        in data: MissionData;
    }
    port def BurnCommandOutPort {
        out burnCommand: BurnCommand;
    }
    port def BurnCommandInPort {
        in burnCommand: BurnCommand;
    }
    port def ThrustOutPort {
        out thrust: ThrustVector;
    }
    port def ThrustInPort {
        in thrust: ThrustVector;
    }
    port def OrbitalStateOutPort {
        out state: OrbitalState;
    }
    port def OrbitalStateInPort {
        in state: OrbitalState;
    }

    // ===== Requirements =====
    requirement def OrbitalAccuracyRequirement {
        doc "The spacecraft shall achieve the target orbit within specified tolerances.";
        attribute targetAltitude: Distance = 550 [km];
        attribute altitudeTolerance: Distance = 5 [km];
        attribute inclinationTolerance: AngleValue = 0.1 [deg];
        attribute achievedAltitude: Distance;
        attribute achievedInclination: AngleValue;
        require achievedAltitude <= targetAltitude + altitudeTolerance
            and achievedAltitude >= targetAltitude - altitudeTolerance;
    }

    requirement def PropulsiveCapabilityRequirement {
        doc "The propulsion subsystem shall provide sufficient delta-V for orbit raising.";
        attribute requiredDeltaV: VelocityValue = 1500 [m/s];
        attribute availableDeltaV: VelocityValue;
        attribute propellantMass: MassValue = 200 [kg];
        require availableDeltaV >= requiredDeltaV;
    }

    requirement def PowerGenerationRequirement {
        doc "The EPS shall generate sufficient power during sunlight and eclipse.";
        attribute requiredPeakPower: PowerValue = 300 [W];
        attribute requiredBatteryCapacity: EnergyValue = 500 [Wh];
        attribute peakPower: PowerValue;
        attribute batteryCapacity: EnergyValue;
        require peakPower >= requiredPeakPower
            and batteryCapacity >= requiredBatteryCapacity;
    }

    requirement def CommunicationsRequirement {
        doc "The communications subsystem shall maintain reliable link with ground station.";
        attribute requiredDownlinkRate: DataRateValue = 10.0;
        attribute requiredUplinkRate: DataRateValue = 1.0;
        attribute operatingFrequency: FrequencyValue = 8.0 [GHz];
        attribute downlinkDataRate: DataRateValue;
        attribute uplinkDataRate: DataRateValue;
        require downlinkDataRate >= requiredDownlinkRate
            and uplinkDataRate >= requiredUplinkRate;
    }

    requirement def MissionDurationRequirement {
        doc "The spacecraft shall operate on-orbit for the specified mission duration.";
        attribute requiredDuration: DurationValue = 8760 [h];
        attribute designedDuration: DurationValue;
        require designedDuration >= requiredDuration;
    }

    // ===== Action Definitions =====
    action def DetermineOrbitalState {
        in sensorData: OrbitalState;
        out currentOrbit: OrbitalState;
    }

    action def ComputeBurn {
        in currentOrbit: OrbitalState;
        in targetOrbit: OrbitalState;
        out burnCommand: BurnCommand;
    }

    action def ExecuteBurn {
        in burnCommand: BurnCommand;
        out thrust: ThrustVector;
        out remainingPropellant: MassValue;
    }

    action def GeneratePower {
        in sunlight: Boolean;
        out power: ElectricalPower;
    }

    action def DistributePower {
        in power: ElectricalPower;
        out distributedPower: ElectricalPower;
    }

    action def TransmitTelemetry {
        in telemetry: Telemetry;
        out downlinkSignal: Telemetry;
    }

    action def ReceiveCommand {
        in uplinkSignal: Command;
        out command: Command;
    }

    action def OperatePayload {
        in command: Command;
        out missionData: MissionData;
    }

    action def StoreMissionData {
        in data: MissionData;
        out storedData: MissionData;
    }

    // ===== Part Definitions =====
    part def GNCSubsystem {
        attribute name: String = "GNC";
        attribute targetOrbit: OrbitalState;
        attribute currentOrbit: OrbitalState;
        attribute navigationAccuracy: Distance = 10 [m];
        attribute attitudeAccuracy: AngleValue = 0.01 [deg];

        port orbitalStateIn: OrbitalStateInPort;
        port burnCommandOut: BurnCommandOutPort;
        port commandIn: CommandInPort;
        port powerIn: PowerInPort;
        port telemetryOut: TelemetryOutPort;

        part flightComputer {
            attribute processingSpeed: Real = 1000.0;
            attribute memory: Integer = 1000000000;
        }
        part starTracker {
            attribute accuracy: AngleValue = 0.01 [deg];
            attribute updateRate: FrequencyValue = 5 [Hz];
        }
        part imu {
            attribute driftRate: AngleValue = 0.001 [deg/s];
            attribute bandwidth: FrequencyValue = 100 [Hz];
        }
        part gpsReceiver {
            attribute positionAccuracy: Distance = 10 [m];
            attribute velocityAccuracy: VelocityValue = 0.1 [m/s];
        }

        action determineState: DetermineOrbitalState {
            in sensorData: OrbitalState = currentOrbit;
            out currentOrbit;
        }

        action computeBurn: ComputeBurn {
            in currentOrbit;
            in targetOrbit;
            out burnCommand via burnCommandOut;
        }

        action reportTelemetry {
            out telemetry via telemetryOut;
        }
    }

    part def PropulsionSubsystem {
        attribute name: String = "Propulsion";
        attribute propellantMass: MassValue = 200 [kg];
        attribute thrustLevel: ThrustValue = 500 [N];
        attribute specificImpulse: DurationValue = 300 [s];
        attribute availableDeltaV: VelocityValue = 1500 [m/s];

        port burnCommandIn: BurnCommandInPort;
        port thrustOut: ThrustOutPort;
        port powerIn: PowerInPort;
        port telemetryOut: TelemetryOutPort;

        part propellantTank {
            attribute capacity: MassValue = 250 [kg];
            attribute currentMass: MassValue = 200 [kg];
        }
        part thruster {
            attribute maxThrust: ThrustValue = 500 [N];
            attribute minThrust: ThrustValue = 50 [N];
        }
        part propellantValve {
            attribute state: String = "closed";
        }
        part pressureRegulator {
            attribute outputPressure: Real = 20.0;
        }

        action executeBurn: ExecuteBurn {
            in burnCommand via burnCommandIn;
            out thrust via thrustOut;
            out remainingPropellant;
        }
    }

    part def EPSSubsystem {
        attribute name: String = "EPS";
        attribute peakPower: PowerValue = 400 [W];
        attribute batteryCapacity: EnergyValue = 500 [Wh];
        attribute busVoltage: Real = 28.0;
        attribute inSunlight: Boolean = true;

        port powerOut: PowerOutPort;
        port telemetryOut: TelemetryOutPort;

        part solarArray {
            attribute area: Real = 2.0;
            attribute efficiency: Real = 0.28;
            attribute generatedPower: PowerValue = 400 [W];
        }
        part battery {
            attribute capacity: EnergyValue = 500 [Wh];
            attribute chargeLevel: Real = 1.0;
            attribute depthOfDischarge: Real = 0.3;
        }
        part powerDistributionUnit {
            attribute outputVoltage: Real = 28.0;
            attribute conversionEfficiency: Real = 0.92;
        }
        part chargeController {
            attribute chargeCurrent: Real = 5.0;
        }

        action generatePower: GeneratePower {
            in sunlight: Boolean = inSunlight;
            out power via powerOut;
        }

        action distributePower: DistributePower {
            in power;
            out distributedPower;
        }
    }

    part def CommunicationsSubsystem {
        attribute name: String = "Comms";
        attribute downlinkDataRate: DataRateValue = 10.0;
        attribute uplinkDataRate: DataRateValue = 1.0;
        attribute operatingFrequency: FrequencyValue = 8.0 [GHz];
        attribute transmitterPower: PowerValue = 20 [W];

        port commandIn: CommandInPort;
        port telemetryIn: TelemetryInPort;
        port missionDataIn: MissionDataInPort;
        port commandOut: CommandOutPort;
        port telemetryOut: TelemetryOutPort;
        port powerIn: PowerInPort;

        part transmitter {
            attribute outputPower: PowerValue = 20 [W];
            attribute modulation: String = "QPSK";
        }
        part receiver {
            attribute sensitivity: Real = -120.0;
            attribute noiseFigure: Real = 2.0;
        }
        part antenna {
            attribute gain: Real = 30.0;
            attribute pointingAccuracy: AngleValue = 1 [deg];
        }
        part transponder {
            attribute bandwidth: FrequencyValue = 50 [MHz];
        }

        action transmitTelemetry: TransmitTelemetry {
            in telemetry via telemetryIn;
            out downlinkSignal via telemetryOut;
        }

        action receiveCommand: ReceiveCommand {
            in uplinkSignal via commandIn;
            out command via commandOut;
        }
    }

    part def PayloadSubsystem {
        attribute name: String = "Payload";
        attribute payloadType: String = "EarthObservationCamera";
        attribute dataRate: DataRateValue = 5.0;
        attribute powerConsumption: PowerValue = 50 [W];

        port commandIn: CommandInPort;
        port missionDataOut: MissionDataOutPort;
        port powerIn: PowerInPort;
        port telemetryOut: TelemetryOutPort;

        part instrument {
            attribute resolution: Distance = 5 [m];
            attribute fieldOfView: AngleValue = 10 [deg];
            attribute swathWidth: Distance = 50 [km];
        }
        part dataProcessor {
            attribute storageCapacity: Integer = 1000000000;
            attribute processingSpeed: Real = 500.0;
        }
        part dataStorage {
            attribute capacity: Integer = 5000000000;
            attribute usedSpace: Integer = 0;
        }

        action operatePayload: OperatePayload {
            in command via commandIn;
            out missionData via missionDataOut;
        }

        action storeData: StoreMissionData {
            in data;
            out storedData;
        }
    }

    part def Spacecraft {
        attribute name: String = "OrbitalSatellite";
        attribute targetOrbit: OrbitalState;
        attribute currentOrbit: OrbitalState;
        attribute missionPhase: String = "LaunchSeparation";
        attribute dryMass: MassValue = 500 [kg];

        port groundTelemetryOut: TelemetryOutPort;
        port groundCommandIn: CommandInPort;

        part gnc: GNCSubsystem;
        part propulsion: PropulsionSubsystem;
        part eps: EPSSubsystem;
        part comms: CommunicationsSubsystem;
        part payload: PayloadSubsystem;

        // Power distribution from EPS to all subsystems
        connection eps.powerOut to gnc.powerIn;
        connection eps.powerOut to propulsion.powerIn;
        connection eps.powerOut to comms.powerIn;
        connection eps.powerOut to payload.powerIn;

        // GNC commands propulsion for burns
        connection gnc.burnCommandOut to propulsion.burnCommandIn;

        // Propulsion thrust feedback to GNC for navigation updates
        connection propulsion.thrustOut to gnc.orbitalStateIn;

        // Communications routes commands to GNC
        connection comms.commandOut to gnc.commandIn;

        // GNC sends telemetry to communications
        connection gnc.telemetryOut to comms.telemetryIn;

        // Communications routes commands to payload
        connection comms.commandOut to payload.commandIn;

        // Payload sends mission data to communications for downlink
        connection payload.missionDataOut to comms.missionDataIn;

        // Spacecraft external interfaces to ground
        connection comms.telemetryOut to groundTelemetryOut;
        connection groundCommandIn to comms.commandIn;

        satisfy OrbitalAccuracyRequirement {
            attribute achievedAltitude = currentOrbit.altitude;
            attribute achievedInclination = currentOrbit.inclination;
        }
        satisfy PropulsiveCapabilityRequirement {
            attribute availableDeltaV = propulsion.availableDeltaV;
        }
        satisfy PowerGenerationRequirement {
            attribute peakPower = eps.peakPower;
            attribute batteryCapacity = eps.batteryCapacity;
        }
        satisfy CommunicationsRequirement {
            attribute downlinkDataRate = comms.downlinkDataRate;
            attribute uplinkDataRate = comms.uplinkDataRate;
        }
        satisfy MissionDurationRequirement {
            attribute designedDuration = 8760 [h];
        }

        exhibit state MissionPhaseStateMachine;
    }

    part def GroundControlStation {
        attribute name: String = "GroundStation";
        attribute location: String = "MissionControl";
        attribute antennaDiameter: Distance = 10 [m];

        port telemetryIn: TelemetryInPort;
        port commandOut: CommandOutPort;

        part groundAntenna {
            attribute diameter: Distance = 10 [m];
            attribute gain: Real = 45.0;
        }
        part groundReceiver {
            attribute noiseFigure: Real = 1.5;
            attribute systemTemperature: Real = 100.0;
        }
        part groundTransmitter {
            attribute outputPower: PowerValue = 100 [W];
        }
        part missionControlComputer {
            attribute processingPower: Real = 5000.0;
            attribute storage: Integer = 10000000000;
        }
        part missionPlanningSystem {
            attribute orbitDeterminationAccuracy: Distance = 5 [m];
        }

        action monitorTelemetry: TransmitTelemetry {
            in telemetry via telemetryIn;
            out downlinkSignal;
        }

        action sendCommand: ReceiveCommand {
            in uplinkSignal;
            out command via commandOut;
        }
    }

    part def MissionSystem {
        attribute missionName: String = "OrbitalMission";
        attribute missionDuration: DurationValue = 8760 [h];
        attribute launchDate: String = "2025-01-15";

        part spacecraft: Spacecraft;
        part groundStation: GroundControlStation;

        // Ground-to-space and space-to-ground links
        connection spacecraft.groundTelemetryOut to groundStation.telemetryIn;
        connection groundStation.commandOut to spacecraft.groundCommandIn;

        requirement orbitalAccuracy: OrbitalAccuracyRequirement;
        requirement propulsiveCapability: PropulsiveCapabilityRequirement;
        requirement powerGeneration: PowerGenerationRequirement;
        requirement communications: CommunicationsRequirement;
        requirement missionDuration: MissionDurationRequirement;
    }

    // ===== State Machine =====
    state def MissionPhaseStateMachine {
        entry;

        state LaunchSeparation {
            doc "Spacecraft has separated from launch vehicle and is in parking orbit.";
            entry;
            do {
                gnc.determineState();
            }
        }

        state OrbitRaising {
            doc "Autonomous orbit-raising maneuvers to reach operational altitude.";
            entry;
            do {
                gnc.determineState();
                gnc.computeBurn();
                propulsion.executeBurn();
            }
        }

        state OnOrbitOperations {
            doc "Primary mission operations with payload active.";
            entry;
            do {
                payload.operatePayload();
                comms.transmitTelemetry();
                comms.receiveCommand();
            }
        }

        state SafeMode {
            doc "Contingency operations due to anomaly.";
            entry;
            do {
                gnc.determineState();
                comms.transmitTelemetry();
            }
        }

        state EndOfLife {
            doc "Mission complete, spacecraft decommissioned.";
            entry;
        }

        transition from LaunchSeparation to OrbitRaising
            when currentOrbit.altitude > 200 [km];

        transition from OrbitRaising to OnOrbitOperations
            when currentOrbit.altitude >= targetOrbit.altitude;

        transition from OnOrbitOperations to SafeMode
            when eps.battery.chargeLevel < 0.2;

        transition from SafeMode to OnOrbitOperations
            when eps.battery.chargeLevel >= 0.5;

        transition from OnOrbitOperations to EndOfLife
            when propulsion.propellantTank.currentMass < 5 [kg];
    }

    // ===== Mission Instantiation =====
    part mission : MissionSystem {
        attribute missionName = "OrbitalSat-1";

        part spacecraft {
            attribute name = "OrbitalSat-1";
            attribute targetOrbit : OrbitalState {
                attribute altitude = 550 [km];
                attribute inclination = 53 [deg];
            }
            attribute currentOrbit : OrbitalState {
                attribute altitude = 200 [km];
                attribute inclination = 53 [deg];
            }
        }

        part groundStation {
            attribute name = "PrimaryGroundStation";
            attribute location = "Kourou";
        }
    }
}
