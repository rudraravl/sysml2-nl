package MarsRoverSystem {

    // ===== Value types with units =====
    attribute def Length :> Real { unit 'm'; }
    attribute def Distance :> Real { unit 'm'; }
    attribute def Speed :> Real { unit 'm/s'; }
    attribute def Mass :> Real { unit 'kg'; }
    attribute def Temperature :> Real { unit 'K'; }
    attribute def Power :> Real { unit 'W'; }
    attribute def Energy :> Real { unit 'J'; }
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Angle :> Real { unit 'rad'; }
    attribute def Time :> Real { unit 's'; }
    attribute def DataRate :> Real { unit 'bit/s'; }
    attribute def DataVolume :> Real { unit 'bit'; }
    attribute def Percent :> Real { unit '%'; }
    attribute def Irradiance :> Real { unit 'W/m^2'; }

    // ===== Item definitions =====
    item def Command {
        attribute commandId : String;
        attribute target : String;
        attribute parameters : String;
        attribute priority : Integer;
    }
    item def ScienceData {
        attribute dataId : String;
        attribute source : String;
        attribute payload : String;
        attribute timestamp : Time;
    }
    item def ImageData :> ScienceData {
        attribute resolution : String;
        attribute widthPixels : Integer;
        attribute heightPixels : Integer;
    }
    item def SpectrometryData :> ScienceData {
        attribute elementList : String;
        attribute concentrationSummary : String;
    }
    item def Telemetry :> ScienceData {
        attribute batteryLevel : Percent;
        attribute internalTemp : Temperature;
        attribute positionX : Length;
        attribute positionY : Length;
        attribute heading : Angle;
    }
    item def Position {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }
    item def Orientation {
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }
    item def NavSolution {
        attribute position : Position;
        attribute orientation : Orientation;
        attribute confidence : Percent;
    }
    item def RockSample {
        attribute sampleId : String;
        attribute location : Position;
        attribute prepared : Boolean;
    }
    item def PowerStatus {
        attribute batteryLevel : Percent;
        attribute solarOutput : Power;
        attribute load : Power;
        attribute mode : String;
    }

    // ===== Port definitions =====
    port def PowerPort {
        attribute voltage : Voltage;
        attribute current : Current;
        in item powerStatus : PowerStatus;
        out item demand : Power;
    }
    port def DataPort {
        in item rx : Command;
        out item tx : ScienceData;
    }
    port def NavDataPort {
        out item navSolution : NavSolution;
    }
    port def ImagePort {
        out item image : ImageData;
    }
    port def SpectroPort {
        out item data : SpectrometryData;
    }
    port def ControlPort {
        in item command : Command;
        out item status : String;
    }
    port def ThermalPort {
        attribute temperature : Temperature;
        out item tempReading : Temperature;
    }
    port def DriveCmdPort {
        in item target : Position;
        in item speed : Speed;
        out item driveStatus : String;
    }

    // ===== Wheel =====
    part def Wheel {
        attribute radius : Length = 0.13 [m];
        attribute maxTorque : Real = 5.0;
        attribute motorCurrent : Current;
        port drivePower : PowerPort;
        part motor {
            attribute ratedVoltage : Voltage = 24 [V];
            attribute stallCurrent : Current = 8.0 [A];
        }
        action def rotate {
            in speed : Speed;
            in duration : Time;
        }
    }

    // ===== Mobility subsystem =====
    part def MobilitySubsystem {
        attribute wheelCount : Integer = 6;
        attribute currentSpeed : Speed;
        attribute totalDistance : Distance;
        part wheels[6] : Wheel;
        port driveCmd : DriveCmdPort;
        port powerIn : PowerPort;
        port navIn : NavDataPort;
        action def traverse {
            in target : Position;
            in nav : NavSolution;
            out distanceTraveled : Distance;
        }
        action def stop;
    }

    // ===== Navigation system =====
    part def InertialSensor {
        attribute updateRate : Real = 100.0;
        attribute driftRate : Real;
        port imuOut : NavDataPort;
        port powerIn : PowerPort;
        action def sample {
            out solution : NavSolution;
        }
    }
    part def NavCamera {
        attribute fieldOfView : Angle = 1.047 [rad];
        attribute resolution : String;
        port imgOut : ImagePort;
        port powerIn : PowerPort;
        action def capture {
            out image : ImageData;
        }
    }
    part def NavigationSystem {
        part imu : InertialSensor;
        part navCams[2] : NavCamera;
        port navOut : NavDataPort;
        port powerIn : PowerPort;
        action def computePosition {
            in image : ImageData;
            in imu : NavSolution;
            out solution : NavSolution;
        }
    }

    // ===== Power subsystem =====
    part def SolarPanelArray {
        attribute area : Real = 1.2;
        attribute efficiency : Percent = 28.0 [%];
        attribute outputPower : Power;
        port powerOut : PowerPort;
        action def generatePower {
            in irradiance : Irradiance;
            out power : Power;
        }
    }
    part def BatteryModule {
        attribute capacity : Energy = 4.0e6 [J];
        attribute chargeLevel : Percent = 100.0 [%];
        attribute nominalVoltage : Voltage = 28 [V];
        port powerPort : PowerPort;
        action def charge {
            in power : Power;
            in duration : Time;
        }
        action def discharge {
            out power : Power;
            in duration : Time;
        }
    }
    part def PowerManagementUnit {
        attribute totalLoad : Power;
        attribute solarInput : Power;
        attribute batteryState : Percent;
        attribute lowPowerThreshold : Percent = 10.0 [%];
        attribute rechargeThreshold : Percent = 30.0 [%];
        port distribution[6] : PowerPort;
        port batteryPort : PowerPort;
        port solarPort[2] : PowerPort;
        action def managePower {
            in status : PowerStatus;
            out allocation : Power;
        }
        action def enterLowPowerMode;
        action def exitLowPowerMode;
    }
    part def PowerSubsystem {
        part solarArrays[2] : SolarPanelArray;
        part battery : BatteryModule;
        part pmu : PowerManagementUnit;
        port roverPowerBus : PowerPort;
        connection s1 connect solarArrays[1].powerOut to pmu.solarPort[1];
        connection s2 connect solarArrays[2].powerOut to pmu.solarPort[2];
        connection b1 connect battery.powerPort to pmu.batteryPort;
        connection d1 connect pmu.distribution[1] to roverPowerBus;
    }

    // ===== Science payload =====
    part def Mast {
        attribute height : Length = 1.2 [m];
        attribute panAngle : Angle;
        attribute tiltAngle : Angle;
        action def point {
            in pan : Angle;
            in tilt : Angle;
        }
    }
    part def PanoramicCamera {
        attribute resolution : String = "20MP";
        attribute sensorWidthPixels : Integer = 5472;
        attribute sensorHeightPixels : Integer = 3648;
        port imageOut : ImagePort;
        port powerIn : PowerPort;
        action def capture {
            in target : String;
            out image : ImageData;
        }
    }
    part def RockAbrasionTool {
        attribute maxGrindDepth : Length = 0.005 [m];
        attribute motorPower : Power = 10.0 [W];
        port powerIn : PowerPort;
        port control : ControlPort;
        action def grind {
            in sample : RockSample;
            in depth : Length;
            out preparedSample : RockSample;
        }
    }
    part def AlphaParticleXRaySpectrometer {
        attribute analysisTime : Time = 300.0 [s];
        attribute detectionRange : String;
        port powerIn : PowerPort;
        port control : ControlPort;
        port dataOut : SpectroPort;
        action def analyze {
            in sample : RockSample;
            out data : SpectrometryData;
        }
    }
    part def SciencePayload {
        part mast : Mast;
        part pancams[2] : PanoramicCamera;
        part rat : RockAbrasionTool;
        part apxs : AlphaParticleXRaySpectrometer;
        port powerIn : PowerPort;
        port dataOut : DataPort;
        port controlBus : ControlPort;
        connection m1 connect mast to pancams[1];
        connection m2 connect mast to pancams[2];
        connection i1 connect pancams[1].imageOut to dataOut;
        connection i2 connect pancams[2].imageOut to dataOut;
        connection sp1 connect apxs.dataOut to dataOut;
        connection c1 connect controlBus to rat.control;
        connection c2 connect controlBus to apxs.control;
    }

    // ===== Communications subsystem =====
    part def HighGainAntenna {
        attribute gain : Real = 42.0;
        attribute pointingAzimuth : Angle;
        attribute pointingElevation : Angle;
        port rfLink : DataPort;
        port powerIn : PowerPort;
        action def steer {
            in azimuth : Angle;
            in elevation : Angle;
        }
        action def transmit {
            in data : ScienceData;
            out ack : String;
        }
        action def receive {
            out command : Command;
        }
    }
    part def CommunicationsSubsystem {
        part antenna : HighGainAntenna;
        attribute downlinkRate : DataRate = 256.0 [bit/s];
        attribute uplinkRate : DataRate = 1024.0 [bit/s];
        port uplink : DataPort;
        port downlink : DataPort;
        port powerIn : PowerPort;
        connection u1 connect antenna.rfLink to uplink;
        connection d1 connect antenna.rfLink to downlink;
    }

    // ===== Onboard computer =====
    part def OnboardComputer {
        attribute clockSpeed : Real = 200.0e6;
        attribute memory : DataVolume = 2.0e9 [bit];
        attribute storage : DataVolume = 8.0e12 [bit];
        port cmdBus : ControlPort;
        port dataBus : DataPort;
        port powerIn : PowerPort;
        action def processCommand {
            in command : Command;
            out directive : String;
        }
        action def gatherData {
            in science : ScienceData;
            out packet : ScienceData;
        }
        action def prepareTransmission {
            in data : ScienceData[*];
            out bundle : ScienceData;
        }
        action def checkPowerStatus {
            in status : PowerStatus;
            out action : String;
        }
    }

    // ===== Thermal control system =====
    part def ThermalControlSystem {
        attribute minOpTemp : Temperature = 223.0 [K];
        attribute maxOpTemp : Temperature = 323.0 [K];
        attribute internalTemp : Temperature;
        port thermalBus : ThermalPort;
        port powerIn : PowerPort;
        action def heat {
            in target : Temperature;
        }
        action def cool {
            in target : Temperature;
        }
        action def regulate {
            in current : Temperature;
            out action : String;
        }
    }

    // ===== Rover operational state machine =====
    state def RoverOperationalStates {
        attribute batteryLevel : Percent;
        entry action { /* initialize rover systems */ }
        state Idle {
            entry action { /* await commands from Earth */ }
        }
        state Driving {
            entry action { /* traverse to target location */ }
        }
        state Analyzing {
            state Imaging {
                entry action { /* capture panoramic images */ }
            }
            state Grinding {
                entry action { /* abrade rock surface */ }
            }
            state Spectrometry {
                entry action { /* run APXS analysis */ }
            }
            transition init then Imaging;
            transition from Imaging to Grinding when imagingComplete;
            transition from Grinding to Spectrometry when grindingComplete;
        }
        state Transmitting {
            entry action { /* send science and engineering data */ }
        }
        state LowPower {
            entry action { /* cease non-essential loads, recharge */ }
        }
        transition init then Idle;
        transition from Idle to Driving when driveCommandReceived;
        transition from Driving to Analyzing when targetReached;
        transition from Analyzing to Transmitting when analysisComplete;
        transition from Transmitting to Idle when transmissionComplete;
        transition from Idle to LowPower when batteryLevel < 10.0 [%];
        transition from Driving to LowPower when batteryLevel < 10.0 [%];
        transition from Analyzing to LowPower when batteryLevel < 10.0 [%];
        transition from Transmitting to LowPower when batteryLevel < 10.0 [%];
        transition from LowPower to Idle when batteryLevel > 30.0 [%];
    }

    // ===== Top-level Mars Rover =====
    part def MarsRover {
        attribute name : String = "MarsRover";
        attribute mass : Mass = 900.0 [kg];
        attribute position : Position;
        attribute orientation : Orientation;
        attribute missionTime : Time;

        part mobility : MobilitySubsystem;
        part navigation : NavigationSystem;
        part power : PowerSubsystem;
        part science : SciencePayload;
        part comms : CommunicationsSubsystem;
        part computer : OnboardComputer;
        part thermal : ThermalControlSystem;

        port earthLink : DataPort;
        port powerStatusOut : PowerPort;

        // Power distribution
        connection p_mob connect power.roverPowerBus to mobility.powerIn;
        connection p_nav connect power.roverPowerBus to navigation.powerIn;
        connection p_sci connect power.roverPowerBus to science.powerIn;
        connection p_com connect power.roverPowerBus to comms.powerIn;
        connection p_cpu connect power.roverPowerBus to computer.powerIn;
        connection p_thm connect power.roverPowerBus to thermal.powerIn;

        // Navigation data to mobility
        connection n_mob connect navigation.navOut to mobility.navIn;

        // Command and data bus
        connection c_uplink connect earthLink to comms.uplink;
        connection c_cmd connect comms.uplink to computer.cmdBus;
        connection c_data connect computer.dataBus to comms.downlink;
        connection c_downlink connect comms.downlink to earthLink;

        // Science data to computer
        connection s_data connect science.dataOut to computer.dataBus;

        // Control directives to subsystems
        connection c_drive connect computer.cmdBus to mobility.driveCmd;
        connection c_sci connect computer.cmdBus to science.controlBus;

        // Thermal monitoring
        connection t_cpu connect thermal.thermalBus to computer.powerIn;

        // Power status reporting
        connection p_status connect power.roverPowerBus to powerStatusOut;

        // Operational behavior
        state machine operationalStates : RoverOperationalStates {
            redef batteryLevel = power.battery.chargeLevel;
        }
    }

    // ===== Requirements =====
    requirement def MobilityRequirement {
        subject rover : MarsRover;
        constraint { rover.mobility.wheelCount == 6; }
        constraint { rover.mass <= 1000.0 [kg]; }
    }
    requirement def PowerRequirement {
        subject rover : MarsRover;
        constraint { rover.power.battery.capacity >= 3.0e6 [J]; }
        constraint { rover.power.solarArrays->size == 2; }
        constraint { rover.power.pmu.lowPowerThreshold <= 15.0 [%]; }
    }
    requirement def ScienceRequirement {
        subject rover : MarsRover;
        constraint { rover.science.pancams->size == 2; }
        constraint { rover.science.rat.maxGrindDepth >= 0.005 [m]; }
        constraint { rover.science.apxs.analysisTime <= 600.0 [s]; }
    }
    requirement def CommunicationsRequirement {
        subject rover : MarsRover;
        constraint { rover.comms.antenna.gain >= 35.0; }
        constraint { rover.comms.downlinkRate >= 128.0 [bit/s]; }
    }
    requirement def ThermalRequirement {
        subject rover : MarsRover;
        constraint { rover.thermal.minOpTemp <= 223.0 [K]; }
        constraint { rover.thermal.maxOpTemp >= 323.0 [K]; }
    }
    requirement def MissionRequirement {
        subject rover : MarsRover;
        constraint { rover.comms.earthLink.tx is ScienceData; }
        constraint { rover.operationalStates.LowPower.defined; }
    }

    // ===== Mission scenario =====
    action def MissionCycle {
        in rover : MarsRover;
        action checkPower {
            out status : PowerStatus;
        }
        action receiveCommands {
            out commands : Command[*];
        }
        action driveToTarget {
            in target : Position;
            out nav : NavSolution;
        }
        action performScience {
            action captureImages {
                out images : ImageData[*];
            }
            action prepareRockSurface {
                in sample : RockSample;
                out prepared : RockSample;
            }
            action analyzeComposition {
                in sample : RockSample;
                out data : SpectrometryData;
            }
            transition first then captureImages;
            transition from captureImages to prepareRockSurface;
            transition from prepareRockSurface to analyzeComposition;
        }
        action transmitData {
            in data : ScienceData[*];
            out ack : String;
        }
        transition init then checkPower;
        transition from checkPower to receiveCommands;
        transition from receiveCommands to driveToTarget;
        transition from driveToTarget to performScience;
        transition from performScience to transmitData;
    }

}
