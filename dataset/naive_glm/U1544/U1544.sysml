package SPHERES {
    import ScalarValues::*;
    import ISQ::*;

    // ══════════════════════════════════════════════════════════
    // Value Types with Units
    // ══════════════════════════════════════════════════════════

    value type Distance :> Real {
        unit mm;
        unit cm = 10 * mm;
        unit m = 1000 * mm;
    }

    value type LinearVelocity :> Real {
        unit mm_per_s;
        unit m_per_s = 1000 * mm_per_s;
    }

    value type LinearAcceleration :> Real {
        unit mm_per_s2;
    }

    value type Angle :> Real {
        unit rad;
        unit deg = 0.017453292519943295 * rad;
    }

    value type AngularRate :> Real {
        unit rad_per_s;
        unit deg_per_s = 0.017453292519943295 * rad_per_s;
    }

    value type ForceValue :> Real {
        unit mN;
        unit N = 1000 * mN;
    }

    value type TorqueValue :> Real {
        unit mN_m;
    }

    value type MassValue :> Real {
        unit g;
        unit kg = 1000 * g;
    }

    value type Duration :> Real {
        unit ms;
        unit s = 1000 * ms;
        unit min = 60 * s;
    }

    value type PressureValue :> Real {
        unit Pa;
        unit kPa = 1000 * Pa;
        unit MPa = 1000000 * Pa;
    }

    value type Volume :> Real {
        unit mL;
        unit L = 1000 * mL;
    }

    value type Fraction :> Real {
        unit percent;
    }

    value type PowerValue :> Real {
        unit mW;
        unit W = 1000 * mW;
    }

    value type EnergyValue :> Real {
        unit mJ;
        unit J = 1000 * mJ;
    }

    value type ChargeValue :> Real {
        unit mAh;
        unit Ah = 1000 * mAh;
    }

    value type Voltage :> Real {
        unit mV;
        unit V = 1000 * mV;
    }

    value type Current :> Real {
        unit mA;
        unit A = 1000 * mA;
    }

    value type DataRate :> Real {
        unit kbps;
        unit Mbps = 1000 * kbps;
    }

    value type Frequency :> Real {
        unit Hz;
        unit kHz = 1000 * Hz;
    }

    // ══════════════════════════════════════════════════════════
    // Attribute Definitions
    // ══════════════════════════════════════════════════════════

    attribute def Position {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
    }

    attribute def Attitude {
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }

    attribute def StateVector {
        attribute position : Position;
        attribute velocity : LinearVelocity;
        attribute attitude : Attitude;
        attribute angularRate : AngularRate;
    }

    attribute def RangeBearing {
        attribute range : Distance;
        attribute azimuth : Angle;
        attribute elevation : Angle;
    }

    attribute def TargetState {
        attribute relativePosition : Position;
        attribute relativeVelocity : LinearVelocity;
        attribute bearing : RangeBearing;
    }

    attribute def ThrusterPulse {
        attribute thrusterId : Integer;
        attribute duration : Duration;
        attribute dutyCycle : Fraction;
    }

    attribute def ThrusterCommandSet {
        attribute pulses : ThrusterPulse[12];
    }

    attribute def ControlSolution {
        attribute netForce : ForceValue;
        attribute netTorque : TorqueValue;
        attribute thrusterCommands : ThrusterCommandSet;
    }

    attribute def TelemetryPacket {
        attribute stateVector : StateVector;
        attribute targetState : TargetState;
        attribute batteryLevel : Fraction;
        attribute propellantRemaining : Fraction;
        attribute systemStatus : String;
    }

    attribute def CommandPacket {
        attribute commandId : Integer;
        attribute commandType : String;
        attribute targetPosition : Position;
    }

    // ══════════════════════════════════════════════════════════
    // Item Definitions
    // ══════════════════════════════════════════════════════════

    item def CO2Gas;
    item def ThrusterCommand;
    item def BeaconSignal;
    item def Telemetry;
    item def Command;

    // ══════════════════════════════════════════════════════════
    // Port Definitions
    // ══════════════════════════════════════════════════════════

    port def StateVectorPort {
        out stateVector : StateVector;
    }

    port def BeaconSignalPort {
        out beaconSignal : BeaconSignal;
    }

    port def ControlSolutionPort {
        out controlSolution : ControlSolution;
    }

    port def GasSupplyPort {
        out co2 : CO2Gas;
    }

    port def PowerPort {
        out voltage : Voltage;
        out current : Current;
    }

    port def CommandPort {
        in commands : Command;
    }

    port def TelemetryPort {
        out telemetry : Telemetry;
    }

    // ══════════════════════════════════════════════════════════
    // Action Definitions
    // ══════════════════════════════════════════════════════════

    action def ComputeNavigation {
        in sensorState : StateVector;
        in beaconMeasurements : BeaconSignal[0..5];
        out estimatedState : StateVector;
    }

    action def ComputeControl {
        in currentState : StateVector;
        in targetState : TargetState;
        out controlSolution : ControlSolution;
    }

    action def AllocateThrusters {
        in netForce : ForceValue;
        in netTorque : TorqueValue;
        out thrusterCommands : ThrusterCommandSet;
    }

    action def FireThrusters {
        in thrusterCommands : ThrusterCommandSet;
    }

    action def MeasureAttitude {
        out attitude : Attitude;
        out angularRate : AngularRate;
    }

    action def MeasureRangeBearing {
        out rangeBearing : RangeBearing;
    }

    action def TransmitTelemetry {
        in telemetry : Telemetry;
    }

    action def ReceiveCommands {
        out commands : Command;
    }

    action def SelfTest {
        out status : String;
        out passFlag : Boolean;
    }

    // ══════════════════════════════════════════════════════════
    // Requirement Definitions
    // ══════════════════════════════════════════════════════════

    requirement def PositionalAccuracyRequirement {
        doc '''The SPHERES satellite shall maintain positional accuracy within 2 cm of the target during proximity operations.''';
        subject satellite : SPHERESSatellite;
        attribute positionError : Distance;
        constraint { positionError <= 2 'cm'; }
    }

    requirement def PropellantEfficiencyRequirement {
        doc '''The SPHERES satellite shall complete complex maneuvers using a minimal amount of CO2 propellant.''';
        subject satellite : SPHERESSatellite;
        attribute propellantUsed : Volume;
        attribute maneuversCompleted : Integer;
        constraint { propellantUsed <= 50 'mL'; }
    }

    requirement def SixDOFControlRequirement {
        doc '''The propulsion subsystem shall provide six-degrees-of-freedom control enabling translation on three orthogonal axes and rotation on three orthogonal axes.''';
        subject propulsion : PropulsionSubsystem;
        attribute thrusterCount : Integer;
        constraint { thrusterCount == 12; }
    }

    requirement def AutonomousNavigationRequirement {
        doc '''The SPHERES satellite shall autonomously navigate toward a target and perform proximity maneuvers without human intervention.''';
        subject satellite : SPHERESSatellite;
        attribute operatorIntervention : Boolean;
        constraint { operatorIntervention == false; }
    }

    requirement def MicrogravityOperationRequirement {
        doc '''The SPHERES system shall operate in the microgravity environment of the International Space Station.''';
        subject satellite : SPHERESSatellite;
        attribute operatingGravity : Real;
        constraint { operatingGravity < 0.000001; }
    }

    requirement def BatteryEnduranceRequirement {
        doc '''The onboard rechargeable battery shall power the satellite for at least one complete test session.''';
        subject battery : Battery;
        attribute endurance : Duration;
        constraint { endurance >= 1800 's'; }
    }

    requirement def TelemetryDownlinkRequirement {
        doc '''The communications subsystem shall transmit telemetry data, including status and position, to the control station.''';
        subject comms : CommunicationsSubsystem;
    }

    requirement def RendezvousManeuverRequirement {
        doc '''The GNC shall autonomously compute thrust commands to close the distance to a target while preserving propellant.''';
        subject gnc : GNCComputer;
        attribute closureRate : LinearVelocity;
        constraint { closureRate > 0 'mm_per_s'; }
    }

    // ══════════════════════════════════════════════════════════
    // Part Definitions — Leaf Components
    // ══════════════════════════════════════════════════════════

    part def CO2Tank {
        doc '''Compressed CO2 gas propellant tank supplying all twelve thruster modules.''';
        attribute capacity : Volume = 200 'mL';
        attribute currentVolume : Volume;
        attribute nominalPressure : PressureValue = 5 'MPa';
        port gasOut : GasSupplyPort;
    }

    part def ThrusterModule {
        doc '''Individual thruster module that releases controlled pulses of CO2 gas. Twelve modules provide full six-degrees-of-freedom control.''';
        attribute thrusterId : Integer;
        attribute thrustDirection : Attitude;
        attribute maxForce : ForceValue = 50 'mN';
        attribute totalPulsesFired : Integer;
        port commandIn : ~ControlSolutionPort;
        port gasIn : ~GasSupplyPort;
        action fire :> FireThrusters;
    }

    part def IMUSensor {
        doc '''Inertial Measurement Unit continuously tracking the satellite's orientation and changes in velocity.''';
        attribute sampleRate : Frequency = 100 'Hz';
        attribute bias : Attitude;
        port stateOut : StateVectorPort;
        action measure :> MeasureAttitude;
    }

    part def UltrasonicBeacon {
        doc '''Ultrasonic beacon measuring range and bearing to other objects. Five beacons provide spatial coverage.''';
        attribute beaconId : Integer;
        attribute maxRange : Distance = 2 'm';
        attribute accuracy : Distance = 5 'mm';
        port rangeOut : BeaconSignalPort;
        action measure :> MeasureRangeBearing;
    }

    part def Battery {
        doc '''Onboard rechargeable battery powering the entire satellite system.''';
        attribute capacity : ChargeValue = 2200 'mAh';
        attribute nominalVoltage : Voltage = 7.4 'V';
        attribute currentCharge : ChargeValue;
        attribute currentLevel : Fraction;
        attribute temperature : Real;
        port powerOut : PowerPort;
        satisfy BatteryEnduranceRequirement;
    }

    // ══════════════════════════════════════════════════════════
    // Part Definitions — Subsystems
    // ══════════════════════════════════════════════════════════

    part def PropulsionSubsystem {
        doc '''Propulsion subsystem using compressed CO2 gas as propellant. Twelve thruster modules positioned around the body provide full six-degrees-of-freedom control for translation and rotation.''';
        part co2Tank : CO2Tank;
        part thrusters : ThrusterModule[12];
        port commandIn : ~ControlSolutionPort;
        port powerIn : ~PowerPort;
        connection co2Tank.gasOut to thrusters.gasIn;
        satisfy SixDOFControlRequirement;
    }

    part def SensorSubsystem {
        doc '''Sensor subsystem consisting of one IMU and five ultrasonic beacons to determine range and bearing to other objects and track the satellite's orientation and velocity changes.''';
        part imu : IMUSensor;
        part beacons : UltrasonicBeacon[5];
        port stateOut : StateVectorPort;
        port beaconOut : BeaconSignalPort;
        port powerIn : ~PowerPort;
        connection imu.stateOut to stateOut;
        connection beacons.rangeOut to beaconOut;
    }

    part def GNCComputer {
        doc '''Guidance, Navigation, and Control computer. Processes raw sensor data to build an accurate picture of current position, velocity, and attitude. Compares to target's location, calculates necessary forces and torques to close the distance, and determines precise firing commands for each of the twelve thrusters.''';
        attribute clockRate : Frequency = 1000 'Hz';
        attribute positionErrorEstimate : Distance;
        port sensorIn : ~StateVectorPort;
        port beaconIn : ~BeaconSignalPort;
        port controlOut : ControlSolutionPort;
        port powerIn : ~PowerPort;
        action navigate :> ComputeNavigation;
        action control :> ComputeControl;
        action allocate :> AllocateThrusters;
        satisfy RendezvousManeuverRequirement;
    }

    part def PowerSubsystem {
        doc '''Power subsystem distributing electrical power from the rechargeable battery to all satellite subsystems.''';
        part battery : Battery;
        port powerOut : PowerPort;
        connection battery.powerOut to powerOut;
    }

    part def CommunicationsSubsystem {
        doc '''Communications subsystem allowing the satellite to receive commands from and transmit telemetry data — such as status and position — back to a control station.''';
        attribute dataRate : DataRate = 100 'kbps';
        attribute frequencyBand : Frequency = 2.4 'kHz';
        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;
        port powerIn : ~PowerPort;
        action transmit :> TransmitTelemetry;
        action receive :> ReceiveCommands;
        satisfy TelemetryDownlinkRequirement;
    }

    part def StructureAssembly {
        doc '''Compact, roughly spherical mechanical structure housing all subsystems of the SPHERES satellite.''';
        attribute diameter : Distance = 220 'mm';
        attribute mass : MassValue = 4.0 'kg';
        attribute material : String = "Polycarbonate";
    }

    // ══════════════════════════════════════════════════════════
    // Part Definitions — Top-Level Satellite
    // ══════════════════════════════════════════════════════════

    part def SPHERESSatellite {
        doc '''A compact, self-contained, roughly spherical free-flying testbed satellite with its own power, propulsion, sensing, and computing capabilities. Designed for autonomous proximity operations — rendezvous, docking, and formation flying — in the microgravity environment of the International Space Station.''';

        attribute satelliteId : String;
        attribute positionError : Distance;
        attribute propellantUsed : Volume;

        part structure : StructureAssembly;
        part propulsion : PropulsionSubsystem;
        part sensors : SensorSubsystem;
        part gnc : GNCComputer;
        part power : PowerSubsystem;
        part comms : CommunicationsSubsystem;

        port toControlStation : TelemetryPort;
        port fromControlStation : CommandPort;

        // Internal data and power connections
        connection sensors.stateOut to gnc.sensorIn;
        connection sensors.beaconOut to gnc.beaconIn;
        connection gnc.controlOut to propulsion.commandIn;
        connection power.powerOut to propulsion.powerIn;
        connection power.powerOut to sensors.powerIn;
        connection power.powerOut to gnc.powerIn;
        connection power.powerOut to comms.powerIn;
        connection fromControlStation to comms.commandIn;
        connection comms.telemetryOut to toControlStation;

        // State machine behavior
        attribute powered : Boolean = false;
        attribute initialized : Boolean = false;
        attribute targetAcquired : Boolean = false;
        attribute withinApproachRange : Boolean = false;
        attribute targetReached : Boolean = false;
        attribute operationComplete : Boolean = false;
        attribute faultDetected : Boolean = false;

        state operational {
            state Off;
            state Initialization;
            state Standby;
            state Active {
                state Idle;
                state Navigating;
                state Maneuvering;
            }
            state Recovery;

            transition from Off to Initialization when powered;
            transition from Initialization to Standby when initialized;
            transition from Standby to Active::Idle when targetAcquired;
            transition from Active::Idle to Active::Navigating when targetAcquired;
            transition from Active::Navigating to Active::Maneuvering when withinApproachRange;
            transition from Active::Maneuvering to Active::Idle when targetReached;
            transition from Active::Idle to Standby when operationComplete;
            transition from Standby to Off when not powered;
            transition from Active to Recovery when faultDetected;
            transition from Recovery to Standby when not faultDetected;
        }

        satisfy PositionalAccuracyRequirement;
        satisfy AutonomousNavigationRequirement;
        satisfy MicrogravityOperationRequirement;
        satisfy PropellantEfficiencyRequirement;
    }

    // ══════════════════════════════════════════════════════════
    // Part Definitions — External Control Station
    // ══════════════════════════════════════════════════════════

    part def ControlStation {
        doc '''Station-based control facility that issues commands to and receives telemetry from one or more SPHERES satellites operating in the microgravity test environment.''';
        attribute stationId : String;
        attribute operatorInterface : String;
        port commandOut : ~CommandPort;
        port telemetryIn : ~TelemetryPort;
        part satellites : SPHERESSatellite[0..*];
        connection commandOut to satellites.fromControlStation;
        connection satellites.toControlStation to telemetryIn;
    }

    // ══════════════════════════════════════════════════════════
    // Connection Definitions
    // ══════════════════════════════════════════════════════════

    connection def StateDataLink {
        doc '''Connection carrying a state vector from a sensor output to a GNC input.''';
        end source : StateVectorPort;
        end target : ~StateVectorPort;
    }

    connection def BeaconDataLink {
        doc '''Connection carrying beacon signals from ultrasonic beacons to the GNC.''';
        end source : BeaconSignalPort;
        end target : ~BeaconSignalPort;
    }

    connection def ControlDataLink {
        doc '''Connection carrying control solution — including thruster firing commands — from the GNC to the propulsion subsystem.''';
        end source : ControlSolutionPort;
        end target : ~ControlSolutionPort;
    }

    connection def CO2SupplyLink {
        doc '''Connection supplying compressed CO2 gas from the tank to thruster modules.''';
        end source : GasSupplyPort;
        end target : ~GasSupplyPort;
    }

    connection def PowerLink {
        doc '''Connection distributing electrical power from the battery to consuming subsystems.''';
        end source : PowerPort;
        end target : ~PowerPort;
    }

    connection def CommandDataLink {
        doc '''Connection delivering commands from the control station to the satellite's communications subsystem.''';
        end source : ~CommandPort;
        end target : CommandPort;
    }

    connection def TelemetryDataLink {
        doc '''Connection transmitting telemetry from the satellite's communications subsystem to the control station.''';
        end source : TelemetryPort;
        end target : ~TelemetryPort;
    }
}
