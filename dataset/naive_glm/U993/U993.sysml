package AUVSystemModel {

    package Definitions {

        // ---- Value Types with Units ----
        attribute def DistanceUnit :> Units::LengthUnit;
        attribute def VelocityUnit :> Units::SpeedUnit;
        attribute def AngleUnit :> Units::PlaneAngleUnit;
        attribute def PressureUnit :> Units::PressureUnit;
        attribute def TemperatureUnit :> Units::TemperatureUnit;
        attribute def ConductivityUnit :> Units::ConductivityUnit;
        attribute def EnergyUnit :> Units::EnergyUnit;
        attribute def VoltageUnit :> Units::ElectricPotentialUnit;
        attribute def CurrentUnit :> Units::ElectricCurrentUnit;
        attribute def MassUnit :> Units::MassUnit;
        attribute def FrequencyUnit :> Units::FrequencyUnit;
        attribute def DataRateUnit :> Units::DataRateUnit;

        attribute def Depth :> Real {
            unit 'm' : DistanceUnit;
        }
        attribute def Speed :> Real {
            unit 'm/s' : VelocityUnit;
        }
        attribute def Heading :> Real {
            unit 'deg' : AngleUnit;
        }
        attribute def Pitch :> Real {
            unit 'deg' : AngleUnit;
        }
        attribute def Roll :> Real {
            unit 'deg' : AngleUnit;
        }
        attribute def Pressure :> Real {
            unit 'Pa' : PressureUnit;
        }
        attribute def Temperature :> Real {
            unit 'degC' : TemperatureUnit;
        }
        attribute def Conductivity :> Real {
            unit 'S/m' : ConductivityUnit;
        }
        attribute def Salinity :> Real;
        attribute def Energy :> Real {
            unit 'J' : EnergyUnit;
        }
        attribute def Voltage :> Real {
            unit 'V' : VoltageUnit;
        }
        attribute def Current :> Real {
            unit 'A' : CurrentUnit;
        }
        attribute def Mass :> Real {
            unit 'kg' : MassUnit;
        }
        attribute def Frequency :> Real {
            unit 'Hz' : FrequencyUnit;
        }
        attribute def DataRate :> Real {
            unit 'bit/s' : DataRateUnit;
        }
        attribute def Percent :> Real;

        // ---- Item Types ----
        item def ElectricalPower {
            attribute voltage : Voltage;
            attribute current : Current;
        }
        item def Position {
            attribute latitude : Real;
            attribute longitude : Real;
            attribute depth : Depth;
        }
        item def Orientation {
            attribute heading : Heading;
            attribute pitch : Pitch;
            attribute roll : Roll;
        }
        item def VelocityVector {
            attribute surge : Speed;
            attribute sway : Speed;
            attribute heave : Speed;
        }
        item def Waypoint {
            attribute latitude : Real;
            attribute longitude : Real;
            attribute targetDepth : Depth;
            attribute targetSpeed : Speed;
        }
        item def MissionPlan {
            attribute waypoints : Waypoint[1..*] ordered;
            attribute surveyTasks : String[0..*];
        }
        item def CTDData {
            attribute conductivity : Conductivity;
            attribute temperature : Temperature;
            attribute depth : Depth;
            attribute salinity : Salinity;
            attribute pressure : Pressure;
        }
        item def ImageData {
            attribute timestamp : String;
            attribute resolution : String;
            attribute frame : String;
        }
        item def SonarData {
            attribute range : Depth;
            attribute intensity : Real;
            attribute map : String;
        }
        item def TelemetryMessage {
            attribute position : Position;
            attribute orientation : Orientation;
            attribute status : String;
        }
        item def CommandMessage {
            attribute command : String;
            attribute parameter : String;
        }
        item def GPSFix {
            attribute latitude : Real;
            attribute longitude : Real;
            attribute fixQuality : Percent;
        }
        item def IMUData {
            attribute orientation : Orientation;
            attribute angularRate : Real[3];
            attribute acceleration : Real[3];
        }
        item def DepthReading {
            attribute depth : Depth;
        }
        item def DopplerReading {
            attribute velocity : VelocityVector;
            attribute altitude : Depth;
        }
        item def ThrustCommand {
            attribute forwardThrust : Real;
            attribute verticalThrust : Real;
            attribute lateralThrust : Real;
        }

        // ---- Port Definitions ----
        port def PowerPort {
            out power : ElectricalPower;
        }
        port def PowerInPort {
            in power : ElectricalPower;
        }
        port def ControlPort {
            out command : ThrustCommand;
        }
        port def NavDataPort {
            out position : Position;
            out orientation : Orientation;
            out velocity : VelocityVector;
        }
        port def SensorDataPort {
            out ctd : CTDData;
            out image : ImageData;
            out sonar : SonarData;
        }
        port def CommPort {
            in downlink : TelemetryMessage;
            out uplink : CommandMessage;
        }
        port def MissionPort {
            out plan : MissionPlan;
            in status : String;
        }
        port def GPSDataPort {
            out fix : GPSFix;
        }
        port def IMUDataPort {
            out data : IMUData;
        }
        port def DepthDataPort {
            out reading : DepthReading;
        }
        port def DopplerDataPort {
            out reading : DopplerReading;
        }
    }

    package Subsystems {

        part def BatteryPack {
            attribute capacity : Energy;
            attribute chargeLevel : Percent;
            attribute nominalVoltage : Voltage;
            attribute maxCurrent : Current;

            port powerOut : Definitions::PowerPort;

            attribute def ChargingState :> String;
            state def BatteryState;
            state machine BatteryStateMachine {
                state Discharging;
                state Charging;
                state Faulted;
                transition Discharging -> Charging when chargeLevel < 5.0;
                transition Charging -> Discharging when chargeLevel >= 95.0;
                transition Discharging -> Faulted when nominalVoltage < 10.0;
            }

            action def DistributePower {
                out distributedPower : ElectricalPower;
            }
        }

        part def Thruster {
            attribute thrustRating : Real;
            attribute direction : String;
            port powerIn : Definitions::PowerInPort;
            port commandIn : Definitions::ControlPort;
            action def Actuate {
                in cmd : Definitions::ThrustCommand;
            }
        }

        part def PropulsionSystem {
            part forwardThruster : Thruster { :>> direction = "forward"; }
            part verticalThruster : Thruster { :>> direction = "vertical"; }
            part lateralThruster : Thruster { :>> direction = "lateral"; }

            port powerIn : Definitions::PowerInPort;
            port commandIn : Definitions::ControlPort;

            connection powerDistribution {
                powerIn.power -> forwardThruster.powerIn.power;
                powerIn.power -> verticalThruster.powerIn.power;
                powerIn.power -> lateralThruster.powerIn.power;
            }
            connection commandDistribution {
                commandIn.command -> forwardThruster.commandIn.command;
                commandIn.command -> verticalThruster.commandIn.command;
                commandIn.command -> lateralThruster.commandIn.command;
            }

            action def Maneuver {
                in cmd : Definitions::ThrustCommand;
            }
        }

        part def MissionController {
            attribute missionPlan : Definitions::MissionPlan;
            attribute currentWaypointIndex : Integer;
            attribute operationalDepth : Definitions::Depth;
            attribute targetSpeed : Definitions::Speed;

            port navIn : Definitions::NavDataPort;
            port thrustOut : Definitions::ControlPort;
            port commPort : Definitions::CommPort;
            port missionPort : Definitions::MissionPort;
            port payloadControl : Definitions::ControlPort;

            state def OperationalState;
            state machine MissionStateMachine {
                state Standby;
                state Descending;
                state Transit;
                state Survey;
                state Ascending;
                state EmergencyAscent;
                state Recovered;

                transition Standby -> Descending when missionPort.plan.received;
                transition Descending -> Transit when navIn.position.depth >= operationalDepth;
                transition Transit -> Survey when currentWaypointIndex == missionPlan.waypoints.size;
                transition Survey -> Ascending when missionPlan.surveyTasks.completed;
                transition Ascending -> Recovered when navIn.position.depth <= 0.5;
                transition Standby -> EmergencyAscent when commPort.uplink.command == "abort";
                transition Descending -> EmergencyAscent when navIn.position.depth > 6000.0;
                transition Transit -> EmergencyAscent when commPort.uplink.command == "abort";
                transition Survey -> EmergencyAscent when commPort.uplink.command == "abort";
                transition EmergencyAscent -> Recovered when navIn.position.depth <= 0.5;
            }

            action def ExecuteMission {
                in plan : Definitions::MissionPlan;
                out thrustCmd : Definitions::ThrustCommand;
            }
            action def ComputeGuidance {
                in position : Definitions::Position;
                in target : Definitions::Waypoint;
                out cmd : Definitions::ThrustCommand;
            }
            action def MonitorHealth {
                out status : String;
            }
        }

        part def GPSReceiver {
            port dataOut : Definitions::GPSDataPort;
            action def AcquireFix {
                out fix : Definitions::GPSFix;
            }
        }

        part def IMU {
            port dataOut : Definitions::IMUDataPort;
            action def Sample {
                out data : Definitions::IMUData;
            }
        }

        part def DepthSensor {
            port dataOut : Definitions::DepthDataPort;
            action def MeasureDepth {
                out reading : Definitions::DepthReading;
            }
        }

        part def DopplerSonar {
            port dataOut : Definitions::DopplerDataPort;
            action def MeasureVelocity {
                out reading : Definitions::DopplerReading;
            }
        }

        part def NavigationSystem {
            part gps : GPSReceiver;
            part imu : IMU;
            part depth : DepthSensor;
            part doppler : DopplerSonar;

            port navOut : Definitions::NavDataPort;
            port powerIn : Definitions::PowerInPort;

            action def FuseSensors {
                in gpsFix : Definitions::GPSFix;
                in imuData : Definitions::IMUData;
                in depthReading : Definitions::DepthReading;
                in dopplerReading : Definitions::DopplerReading;
                out position : Definitions::Position;
                out orientation : Definitions::Orientation;
                out velocity : Definitions::VelocityVector;
            }
        }

        part def CTDSensor {
            port dataOut : Definitions::SensorDataPort;
            action def SampleCTD {
                out ctd : Definitions::CTDData;
            }
        }

        part def Camera {
            port dataOut : Definitions::SensorDataPort;
            attribute resolution : String;
            action def CaptureImage {
                out image : Definitions::ImageData;
            }
        }

        part def SonarSystem {
            port dataOut : Definitions::SensorDataPort;
            attribute frequency : Definitions::Frequency;
            action def ScanSeabed {
                out sonar : Definitions::SonarData;
            }
        }

        part def SensorPayload {
            part ctd : CTDSensor;
            part camera : Camera { :>> resolution = "12MP"; }
            part sonar : SonarSystem { :>> frequency = 200.0; }

            port dataOut : Definitions::SensorDataPort;
            port powerIn : Definitions::PowerInPort;
            port controlIn : Definitions::ControlPort;

            action def CollectData {
                out ctdData : Definitions::CTDData;
                out imageData : Definitions::ImageData;
                out sonarData : Definitions::SonarData;
            }
        }

        part def AcousticModem {
            attribute frequency : Definitions::Frequency;
            attribute maxDepth : Definitions::Depth;
            port commPort : Definitions::CommPort;
            action def TransmitAcoustic {
                in msg : Definitions::TelemetryMessage;
            }
            action def ReceiveAcoustic {
                out cmd : Definitions::CommandMessage;
            }
        }

        part def SatelliteTransceiver {
            attribute dataRate : Definitions::DataRate;
            port commPort : Definitions::CommPort;
            action def TransmitSatellite {
                in msg : Definitions::TelemetryMessage;
            }
            action def ReceiveSatellite {
                out cmd : Definitions::CommandMessage;
            }
        }

        part def CommunicationSystem {
            part acoustic : AcousticModem { :>> frequency = 9000.0; :>> maxDepth = 6000.0; }
            part satellite : SatelliteTransceiver { :>> dataRate = 100000.0; }

            port commPort : Definitions::CommPort;
            port powerIn : Definitions::PowerInPort;

            state def CommMode;
            state machine CommStateMachine {
                state SubmergedMode;
                state SurfaceMode;
                transition SubmergedMode -> SurfaceMode when navDepth <= 0.5;
                transition SurfaceMode -> SubmergedMode when navDepth > 0.5;
            }
        }

        part def Hull {
            attribute maxOperatingDepth : Definitions::Depth;
            attribute mass : Definitions::Mass;
            attribute length : Definitions::DistanceUnit;
            attribute diameter : Definitions::DistanceUnit;
        }
    }

    package AUV {

        part auvVehicle {
            attribute name : String = "Surveyor-1";
            attribute maxDepth : Definitions::Depth = 6000.0;

            part hull : Subsystems::Hull {
                :>> maxOperatingDepth = 6000.0;
                :>> mass = 120.0;
                :>> length = 3.5;
                :>> diameter = 0.6;
            }

            part battery : Subsystems::BatteryPack {
                :>> capacity = 50000000.0;
                :>> chargeLevel = 100.0;
                :>> nominalVoltage = 24.0;
                :>> maxCurrent = 50.0;
            }

            part propulsion : Subsystems::PropulsionSystem;
            part missionController : Subsystems::MissionController;
            part navigation : Subsystems::NavigationSystem;
            part payload : Subsystems::SensorPayload;
            part communication : Subsystems::CommunicationSystem;

            // Power distribution connections
            connection battery.powerOut.power -> propulsion.powerIn.power;
            connection battery.powerOut.power -> navigation.powerIn.power;
            connection battery.powerOut.power -> payload.powerIn.power;
            connection battery.powerOut.power -> communication.powerIn.power;

            // Control and data connections
            connection missionController.thrustOut.command -> propulsion.commandIn.command;
            connection navigation.navOut.position -> missionController.navIn.position;
            connection navigation.navOut.orientation -> missionController.navIn.orientation;
            connection navigation.navOut.velocity -> missionController.navIn.velocity;
            connection missionController.payloadControl.command -> payload.controlIn.command;
            connection payload.dataOut.ctd -> communication.commPort.downlink;
            connection payload.dataOut.image -> communication.commPort.downlink;
            connection payload.dataOut.sonar -> communication.commPort.downlink;
            connection communication.commPort.uplink -> missionController.commPort.uplink;

            // Navigation sensor internal connections
            connection navigation.gps.dataOut.fix -> navigation.navOut.position;
            connection navigation.imu.dataOut.data -> navigation.navOut.orientation;
            connection navigation.depth.dataOut.reading -> navigation.navOut.position;
            connection navigation.doppler.dataOut.reading -> navigation.navOut.velocity;
        }
    }

    package Requirements {

        requirement def OperationalRequirement {
            doc "The AUV shall operate autonomously for oceanographic surveys.";
        }

        requirement AutonomyRequirement :> OperationalRequirement {
            subject auv : AUV::auvVehicle;
            doc "The AUV shall execute pre-programmed missions without direct human control."
            require auv.missionController.missionPlan.waypoints.size >= 1;
        }

        requirement DepthRequirement :> OperationalRequirement {
            subject auv : AUV::auvVehicle;
            doc "The AUV shall operate at depths up to 6000 m."
            require auv.maxDepth <= 6000.0;
        }

        requirement PropulsionRequirement :> OperationalRequirement {
            subject auv : AUV::auvVehicle;
            doc "The AUV shall control movement in three dimensions using forward, vertical, and lateral thrusters."
            require auv.propulsion.forwardThruster.direction == "forward";
            require auv.propulsion.verticalThruster.direction == "vertical";
            require auv.propulsion.lateralThruster.direction == "lateral";
        }

        requirement NavigationRequirement :> OperationalRequirement {
            subject auv : AUV::auvVehicle;
            doc "The AUV shall calculate position, depth, and heading using GPS, IMU, depth sensor, and Doppler sonar."
            require auv.navigation.gps.allocated;
            require auv.navigation.imu.allocated;
            require auv.navigation.depth.allocated;
            require auv.navigation.doppler.allocated;
        }

        requirement PayloadRequirement :> OperationalRequirement {
            subject auv : AUV::auvVehicle;
            doc "The AUV shall collect CTD, image, and sonar data."
            require auv.payload.ctd.allocated;
            require auv.payload.camera.allocated;
            require auv.payload.sonar.allocated;
        }

        requirement CommunicationRequirement :> OperationalRequirement {
            subject auv : AUV::auvVehicle;
            doc "The AUV shall communicate via acoustic modem while submerged and satellite transceiver at the surface."
            require auv.communication.acoustic.allocated;
            require auv.communication.satellite.allocated;
        }

        requirement EmergencyAscentRequirement :> OperationalRequirement {
            subject auv : AUV::auvVehicle;
            doc "The AUV shall execute an emergency ascent when a problem is detected."
            require auv.missionController.MissionStateMachine.EmergencyAscent.allocated;
        }

        requirement PowerRequirement :> OperationalRequirement {
            subject auv : AUV::auvVehicle;
            doc "The AUV battery pack shall distribute electricity to all components."
            require auv.battery.powerOut.allocated;
        }
    }
}
