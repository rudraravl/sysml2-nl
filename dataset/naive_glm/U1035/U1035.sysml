package UAMNetwork {
    import ScalarValues::*;

    package Units {
        unit kg;
        unit m;
        unit s;
        unit m_per_s :> m / s;
        unit J :> kg * m**2 / s**2;
        unit W :> J / s;
        unit V;
        unit A;
        unit Hz :> 1 / s;
        unit deg;
        unit percent;
        unit K;
        unit Wh :> J;
        unit kW :> W;
        unit km :> m;
        unit m_per_s2 :> m / s**2;
    }

    package ValueTypes {
        value type Mass :> Real { unit Units::kg; }
        value type Distance :> Real { unit Units::m; }
        value type Altitude :> Real { unit Units::m; }
        value type Speed :> Real { unit Units::m_per_s; }
        value type Acceleration :> Real { unit Units::m_per_s2; }
        value type Energy :> Real { unit Units::Wh; }
        value type Power :> Real { unit Units::kW; }
        value type Voltage :> Real { unit Units::V; }
        value type Current :> Real { unit Units::A; }
        value type Frequency :> Real { unit Units::Hz; }
        value type Angle :> Real { unit Units::deg; }
        value type Percentage :> Real { unit Units::percent; }
        value type Temperature :> Real { unit Units::K; }
        value type Duration :> Real { unit Units::s; }
    }

    package Items {
        item def Passenger {
            attribute passengerId : String;
            attribute name : String;
            attribute weight : ValueTypes::Mass;
        }

        item def FlightRequest {
            attribute requestId : String;
            attribute originVertiportId : String;
            attribute destinationVertiportId : String;
            attribute passengers : Passenger[1..4];
            attribute requestedTime : String;
        }

        item def FlightPlan {
            attribute planId : String;
            attribute waypoints : String;
            attribute distance : ValueTypes::Distance;
            attribute estimatedDuration : ValueTypes::Duration;
            attribute energyRequired : ValueTypes::Energy;
            attribute cruiseAltitude : ValueTypes::Altitude;
        }

        item def ClearanceMessage {
            attribute clearanceId : String;
            attribute cleared : Boolean;
            attribute routeId : String;
            attribute slotTime : String;
        }

        item def TelemetryData {
            attribute aircraftId : String;
            attribute position : String;
            attribute altitude : ValueTypes::Altitude;
            attribute speed : ValueTypes::Speed;
            attribute batteryLevel : ValueTypes::Percentage;
            attribute phase : String;
            attribute timestamp : String;
        }

        item def WeatherData {
            attribute windSpeed : ValueTypes::Speed;
            attribute windDirection : ValueTypes::Angle;
            attribute visibility : ValueTypes::Distance;
            attribute temperature : ValueTypes::Temperature;
            attribute precipitation : Boolean;
        }

        item def ObstacleData {
            attribute sensorId : String;
            attribute range : ValueTypes::Distance;
            attribute bearing : ValueTypes::Angle;
            attribute elevation : ValueTypes::Angle;
            attribute confidence : ValueTypes::Percentage;
        }

        item def NavigationImage {
            attribute cameraId : String;
            attribute timestamp : String;
            attribute resolution : String;
        }

        item def ControlCommand {
            attribute pitch : ValueTypes::Angle;
            attribute roll : ValueTypes::Angle;
            attribute yaw : ValueTypes::Angle;
            attribute collectiveThrust : ValueTypes::Power;
        }

        item def PowerCommand {
            attribute targetPower : ValueTypes::Power;
            attribute tiltAngle : ValueTypes::Angle;
        }

        item def ElectricalPower {
            attribute voltage : ValueTypes::Voltage;
            attribute current : ValueTypes::Current;
        }

        item def MechanicalPower {
            attribute torque : Real;
            attribute rpm : Real;
        }

        item def BookingConfirmation {
            attribute confirmationId : String;
            attribute aircraftId : String;
            attribute departureTime : String;
            attribute fare : Real;
        }
    }

    package Requirements {

        requirement def TransportationRequirement {
            doc /* The UAM network shall provide rapid, on-demand, point-to-point air transportation within a city. */
            subject network : System::UAMNetwork;
            attribute maxResponseTime : ValueTypes::Duration = 600;
            objective {
                doc /* Passengers shall be transported between vertiports bypassing ground traffic. */
            }
            assume {
                doc /* City has sufficient vertiport coverage. */
            }
        }

        requirement def EmissionFreeRequirement {
            doc /* The eVTOL aircraft shall operate with zero direct emissions. */
            subject aircraft : System::eVTOL;
            objective {
                doc /* All propulsion energy shall be supplied by rechargeable batteries. */
            }
        }

        requirement def PassengerCapacityRequirement {
            doc /* The eVTOL aircraft shall carry up to four passengers. */
            subject aircraft : System::eVTOL;
            attribute maxPassengers : Integer = 4;
            objective {
                doc /* The aircraft cabin shall accommodate four passengers plus baggage. */
            }
        }

        requirement def PropulsionRedundancyRequirement {
            doc /* The propulsion system shall use eight tilt-rotors each with an individual electric motor. */
            subject aircraft : System::eVTOL;
            attribute rotorCount : Integer = 8;
            objective {
                doc /* The aircraft shall remain controllable after failure of any single rotor. */
            }
        }

        requirement def BatteryRedundancyRequirement {
            doc /* The aircraft shall be powered by four rechargeable battery packs providing redundant power. */
            subject aircraft : System::eVTOL;
            attribute packCount : Integer = 4;
            objective {
                doc /* The aircraft shall complete a safe landing after failure of any single battery pack. */
            }
        }

        requirement def FlightComputerRedundancyRequirement {
            doc /* The aircraft shall use a triple-redundant flight computer. */
            subject aircraft : System::eVTOL;
            attribute computerCount : Integer = 3;
            objective {
                doc /* Flight control shall continue after failure of any single flight computer. */
            }
        }

        requirement def SensorSuiteRequirement {
            doc /* The aircraft shall be equipped with LiDAR, radar, and high-resolution cameras. */
            subject aircraft : System::eVTOL;
            objective {
                doc /* The sensor suite shall support obstacle detection, weather awareness, and visual navigation. */
            }
        }

        requirement def MissionPhasesRequirement {
            doc /* A mission shall consist of preflight, takeoff, transition, cruise, approach, and landing phases. */
            subject aircraft : System::eVTOL;
            objective {
                doc /* The autonomous system shall manage each phase in communication with the operations center. */
            }
        }

        requirement def VertiportRequirement {
            doc /* The network shall include numerous ground-based vertiport stations. */
            subject vertiport : System::Vertiport;
            objective {
                doc /* Each vertiport shall support vertical takeoff and landing and battery charging. */
            }
        }

        requirement def NOCRequirement {
            doc /* A central Network Operations Center shall coordinate fleet operations. */
            subject noc : System::NetworkOperationsCenter;
            objective {
                doc /* The NOC shall issue clearances, monitor telemetry, and provide weather data. */
            }
        }

        requirement def VerticalTakeoffRequirement {
            doc /* The aircraft shall take off and land vertically from compact spaces. */
            subject aircraft : System::eVTOL;
            objective {
                doc /* The aircraft shall perform vertical takeoff and landing without a runway. */
            }
        }

        requirement def ForwardCruiseRequirement {
            doc /* The aircraft shall transition rotors forward for efficient high-speed cruise. */
            subject aircraft : System::eVTOL;
            objective {
                doc /* The aircraft shall achieve efficient airplane-mode cruise after transition. */
            }
        }
    }

    package Components {

        part def ElectricMotor {
            attribute motorId : String;
            attribute maxPower : ValueTypes::Power;
            attribute currentPower : ValueTypes::Power;
            attribute isOperational : Boolean = true;
            port electricalIn : Items::ElectricalPower;
            port mechanicalOut : Items::MechanicalPower;
            action spin {
                in power : Items::ElectricalPower;
                out mechanical : Items::MechanicalPower;
            }
        }

        part def TiltRotor {
            attribute rotorId : String;
            attribute maxThrust : ValueTypes::Power;
            attribute currentTiltAngle : ValueTypes::Angle = 0;
            attribute minTiltAngle : ValueTypes::Angle = 0;
            attribute maxTiltAngle : ValueTypes::Angle = 90;
            attribute isOperational : Boolean = true;
            port mechanicalIn : Items::MechanicalPower;
            port commandIn : Items::PowerCommand;
            port thrustOut : Items::ControlCommand;
            action tilt {
                in command : Items::PowerCommand;
                attribute newAngle : ValueTypes::Angle;
            }
        }

        part def BatteryPack {
            attribute packId : String;
            attribute capacity : ValueTypes::Energy;
            attribute currentCharge : ValueTypes::Energy;
            attribute nominalVoltage : ValueTypes::Voltage;
            attribute maxDischargeCurrent : ValueTypes::Current;
            attribute stateOfCharge : ValueTypes::Percentage;
            attribute isHealthy : Boolean = true;
            port powerOut : Items::ElectricalPower;
            action discharge {
                out power : Items::ElectricalPower;
            }
            action recharge {
                in externalPower : Items::ElectricalPower;
            }
        }

        abstract part def Sensor {
            attribute sensorId : String;
            attribute isOperational : Boolean = true;
            port dataOut : Items::ObstacleData;
            action sense {
                out data : Items::ObstacleData;
            }
        }

        part def LiDAR :> Sensor {
            attribute maxRange : ValueTypes::Distance = 200;
            attribute minRange : ValueTypes::Distance = 0.5;
            attribute updateRate : ValueTypes::Frequency = 20;
            attribute angularResolution : ValueTypes::Angle = 0.5;
        }

        part def Radar :> Sensor {
            attribute maxRange : ValueTypes::Distance = 5000;
            attribute updateRate : ValueTypes::Frequency = 10;
            attribute frequencyBand : String = "Ka";
        }

        part def Camera :> Sensor {
            attribute cameraId : String;
            attribute resolution : String;
            attribute fieldOfView : ValueTypes::Angle;
            attribute frameRate : ValueTypes::Frequency = 30;
            port imageOut : Items::NavigationImage;
            action capture {
                out image : Items::NavigationImage;
            }
        }

        part def FlightComputer {
            attribute computerId : String;
            attribute isPrimary : Boolean;
            attribute isActive : Boolean = true;
            attribute healthStatus : String = "nominal";
            port sensorDataIn : Items::ObstacleData;
            port imageIn : Items::NavigationImage;
            port planIn : Items::FlightPlan;
            port clearanceIn : Items::ClearanceMessage;
            port controlOut : Items::ControlCommand;
            port powerCommandOut : Items::PowerCommand;
            port telemetryOut : Items::TelemetryData;
            action processSensorData {
                in obstacle : Items::ObstacleData;
                in image : Items::NavigationImage;
                out control : Items::ControlCommand;
            }
            action computeFlightPath {
                in request : Items::FlightRequest;
                in weather : Items::WeatherData;
                out plan : Items::FlightPlan;
            }
            action generateTelemetry {
                out telemetry : Items::TelemetryData;
            }
        }

        part def Cabin {
            attribute seatCount : Integer = 4;
            attribute baggageCapacity : ValueTypes::Mass;
            part seats : PassengerSeat[4];
        }

        part def PassengerSeat {
            attribute seatId : String;
            attribute occupied : Boolean = false;
        }

        part def Airframe {
            attribute length : ValueTypes::Distance;
            attribute wingspan : ValueTypes::Distance;
            attribute emptyMass : ValueTypes::Mass;
            attribute maxTakeoffMass : ValueTypes::Mass;
        }
    }

    package System {

        part def eVTOL {
            attribute aircraftId : String;
            attribute model : String = "UAM-Tilt8";
            attribute maxPassengers : Integer = 4;
            attribute maxRange : ValueTypes::Distance = 50000;
            attribute cruiseSpeed : ValueTypes::Speed = 60;
            attribute maxAltitude : ValueTypes::Altitude = 3000;
            attribute currentPassengers : Integer = 0;
            attribute currentAltitude : ValueTypes::Altitude = 0;
            attribute currentSpeed : ValueTypes::Speed = 0;
            attribute distanceToDestination : ValueTypes::Distance = 0;
            attribute isLanded : Boolean = true;
            attribute totalFlightHours : ValueTypes::Duration = 0;

            part airframe : Components::Airframe {
                attribute length = 8.0;
                attribute wingspan = 9.5;
                attribute emptyMass = 1400;
                attribute maxTakeoffMass = 2500;
            }

            part cabin : Components::Cabin {
                attribute baggageCapacity = 80;
            }

            part batteries : Components::BatteryPack[4] {
                attribute capacity = 50000;
                attribute nominalVoltage = 400;
            }

            part motors : Components::ElectricMotor[8] {
                attribute maxPower = 150;
            }

            part rotors : Components::TiltRotor[8] {
                attribute maxThrust = 200;
            }

            part flightComputers : Components::FlightComputer[3] {
                attribute isPrimary = false;
            }

            part lidars : Components::LiDAR[2];
            part radars : Components::Radar[2];
            part cameras : Components::Camera[4] {
                attribute resolution = "4K";
                attribute fieldOfView = 120;
            }

            port bookingIn : Items::FlightRequest;
            port planPort : Items::FlightPlan;
            port clearancePort : Items::ClearanceMessage;
            port telemetryPort : Items::TelemetryData;
            port weatherPort : Items::WeatherData;
            port confirmationOut : Items::BookingConfirmation;

            connection batteryToMotor
                connect batteries.powerOut to motors.electricalIn;

            connection motorToRotor
                connect motors.mechanicalOut to rotors.mechanicalIn;

            connection lidarToComputer
                connect lidars.dataOut to flightComputers.sensorDataIn;

            connection radarToComputer
                connect radars.dataOut to flightComputers.sensorDataIn;

            connection cameraToComputer
                connect cameras.imageOut to flightComputers.imageIn;

            connection computerToRotor
                connect flightComputers.powerCommandOut to rotors.commandIn;

            state missionStateMachine {
                entry;
                then preflight;

                state preflight {
                    entry { /* Initiate pre-flight checks and request clearance */ }
                    do { /* Perform system diagnostics, compute flight path */ }
                    exit { /* Confirm clearance received */ }
                }

                state takeoff {
                    entry { /* Begin vertical takeoff */ }
                    do { /* Increase collective thrust, ascend vertically */ }
                    exit { /* Reach safe transition altitude */ }
                }

                state transition {
                    entry { /* Begin tilting rotors forward */ }
                    do { /* Gradually tilt rotors from 0 to 90 degrees, increase forward speed */ }
                    exit { /* Rotors fully forward, airplane mode achieved */ }
                }

                state cruise {
                    entry { /* Establish cruise at designated altitude and speed */ }
                    do { /* Follow flight plan waypoints, monitor systems */ }
                    exit { /* Approach destination within transition distance */ }
                }

                state approach {
                    entry { /* Begin transition back to vertical flight */ }
                    do { /* Tilt rotors back to vertical, reduce speed */ }
                    exit { /* Achieve hover above destination vertiport */ }
                }

                state landing {
                    entry { /* Begin precision vertical descent */ }
                    do { /* Descend to vertiport pad using sensor data */ }
                    exit { /* Touchdown confirmed */ }
                }

                state standby {
                    entry { /* Aircraft idle at vertiport */ }
                }

                transition preflight_to_takeoff
                    first preflight then takeoff
                    when clearancePort.cleared == true;

                transition takeoff_to_transition
                    first takeoff then transition
                    when currentAltitude > 50;

                transition transition_to_cruise
                    first transition then cruise
                    when rotors.currentTiltAngle >= 90;

                transition cruise_to_approach
                    first cruise then approach
                    when distanceToDestination < 1000;

                transition approach_to_landing
                    first approach then landing
                    when currentAltitude < 20;

                transition landing_to_standby
                    first landing then standby
                    when isLanded == true;

                transition standby_to_preflight
                    first standby then preflight
                    when bookingIn.requestId != null;
            }

            action performMission {
                in request : Items::FlightRequest;
                in weather : Items::WeatherData;
                out telemetry : Items::TelemetryData;

                action preflightCheck {
                    out status : Boolean;
                }

                action computePath {
                    in req : Items::FlightRequest;
                    in wx : Items::WeatherData;
                    out plan : Items::FlightPlan;
                }

                action verticalTakeoff {
                    out altitude : ValueTypes::Altitude;
                }

                action transitionToCruise {
                    in tiltTarget : ValueTypes::Angle;
                }

                action cruiseFlight {
                    in plan : Items::FlightPlan;
                }

                action transitionToHover {
                    out tiltAngle : ValueTypes::Angle;
                }

                action precisionLanding {
                    out landed : Boolean;
                }

                then preflightCheck;
                then computePath;
                then verticalTakeoff;
                then transitionToCruise;
                then cruiseFlight;
                then transitionToHover;
                then precisionLanding;
            }

            satisfy Requirements::EmissionFreeRequirement;
            satisfy Requirements::PassengerCapacityRequirement;
            satisfy Requirements::PropulsionRedundancyRequirement;
            satisfy Requirements::BatteryRedundancyRequirement;
            satisfy Requirements::FlightComputerRedundancyRequirement;
            satisfy Requirements::SensorSuiteRequirement;
            satisfy Requirements::MissionPhasesRequirement;
            satisfy Requirements::VerticalTakeoffRequirement;
            satisfy Requirements::ForwardCruiseRequirement;
        }

        part def Vertiport {
            attribute vertiportId : String;
            attribute name : String;
            attribute location : String;
            attribute latitude : Real;
            attribute longitude : Real;
            attribute landingPads : Integer = 2;
            attribute chargingStations : Integer = 2;
            attribute currentQueue : Integer = 0;
            attribute isOperational : Boolean = true;

            port arrivalPort : Items::TelemetryData;
            port departurePort : Items::FlightRequest;
            port confirmationPort : Items::BookingConfirmation;
            port chargingPort : Items::ElectricalPower;

            action acceptArrival {
                in telemetry : Items::TelemetryData;
            }

            action dispatchDeparture {
                in request : Items::FlightRequest;
                out confirmation : Items::BookingConfirmation;
            }

            action chargeAircraft {
                in aircraft : eVTOL;
                out power : Items::ElectricalPower;
            }

            satisfy Requirements::VertiportRequirement;
        }

        part def NetworkOperationsCenter {
            attribute nocId : String;
            attribute location : String;
            attribute monitoredAircraftCount : Integer = 0;
            attribute activeVertiportCount : Integer = 0;

            port telemetryIn : Items::TelemetryData;
            port clearanceOut : Items::ClearanceMessage;
            port weatherOut : Items::WeatherData;
            port flightPlanOut : Items::FlightPlan;
            port requestIn : Items::FlightRequest;

            action processTelemetry {
                in telemetry : Items::TelemetryData;
                out analysis : String;
            }

            action generateClearance {
                in request : Items::FlightRequest;
                in weather : Items::WeatherData;
                out clearance : Items::ClearanceMessage;
            }

            action broadcastWeather {
                out weather : Items::WeatherData;
            }

            action monitorFleet {
                in telemetry : Items::TelemetryData;
            }

            satisfy Requirements::NOCRequirement;
        }

        part def UAMNetwork {
            attribute networkId : String;
            attribute city : String;
            attribute operational : Boolean = true;

            part fleet : eVTOL[1..*];
            part vertiports : Vertiport[2..*];
            part noc : NetworkOperationsCenter;

            connection flightRequestFlow
                connect vertiports.departurePort to fleet.bookingIn;

            connection confirmationFlow
                connect fleet.confirmationOut to vertiports.confirmationPort;

            connection clearanceFlow
                connect noc.clearanceOut to fleet.clearancePort;

            connection telemetryFlow
                connect fleet.telemetryPort to noc.telemetryIn;

            connection weatherFlow
                connect noc.weatherOut to fleet.weatherPort;

            connection arrivalTelemetryFlow
                connect fleet.telemetryPort to vertiports.arrivalPort;

            connection requestToNOC
                connect vertiports.departurePort to noc.requestIn;

            connection planFlow
                connect noc.flightPlanOut to fleet.planPort;

            action operateNetwork {
                action receiveBooking {
                    in request : Items::FlightRequest;
                }

                action assignAircraft {
                    in request : Items::FlightRequest;
                    out aircraft : eVTOL;
                }

                action coordinateClearance {
                    in request : Items::FlightRequest;
                    out clearance : Items::ClearanceMessage;
                }

                action monitorFlight {
                    in telemetry : Items::TelemetryData;
                }

                action completeMission {
                    in telemetry : Items::TelemetryData;
                }

                then receiveBooking;
                then assignAircraft;
                then coordinateClearance;
                then monitorFlight;
                then completeMission;
            }

            satisfy Requirements::TransportationRequirement;
        }
    }
}
