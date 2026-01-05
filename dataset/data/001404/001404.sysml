package 'Electric Vertical Takeoff and Landing Aircraft System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Metaobjects::SemanticMetadata;
    private import ModelingMetadata::*;
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;

    doc /* 
     * This model describes an electric Vertical Takeoff and Landing (eVTOL) aircraft system,
     * a disruptive innovation in urban air mobility. The system's primary function is to provide
     * rapid, emission-free point-to-point air transportation within urban environments, bypassing
     * ground traffic congestion entirely.
     * 
     * This technology disrupts traditional ground-based urban transportation and conventional
     * aviation by combining electric propulsion, autonomous flight capabilities, and vertical
     * takeoff/landing to enable operation from compact urban vertiports without requiring
     * traditional airport infrastructure.
     */

    attribute def GPSCoordinate {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
    }

    attribute def FlightPath {
        attribute waypoints : GPSCoordinate[2..*] ordered;
        attribute cruiseAltitude : LengthValue;
        attribute totalDistance : LengthValue;
    }

    attribute def BatteryState {
        attribute chargeLevel : Real;
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute remainingCapacity : ISQ::EnergyValue;
    }

    attribute def PassengerManifest {
        attribute passengerCount : Integer;
        attribute totalPassengerMass : MassValue;
        attribute cargoMass : MassValue;
    }

    enum def FlightPhase {
        preflight;
        verticalTakeoff;
        transition;
        cruise;
        approach;
        verticalLanding;
        shutdown;
    }

    enum def SystemHealth {
        nominal;
        degraded;
        critical;
        emergency;
    }

    attribute def FlightClearance;
    attribute def EmergencySignal;
    attribute def LandingApproval;
    attribute def MissionAssigned;
    attribute def ClearanceReceived;
    attribute def PassengersDisembarked;

    port def PowerBusPort {
        in powerDemand : ISQ::PowerValue;
        out powerSupply : ISQ::PowerValue;
    }

    port def ControlDataPort {
        inout commandData : ScalarValues::String;
        inout telemetryData : ScalarValues::String;
    }

    port def NavigationPort {
        in currentPosition : GPSCoordinate;
        out targetPosition : GPSCoordinate;
        inout flightPath : FlightPath;
    }

    port def CommunicationPort {
        inout airTrafficControl : ScalarValues::String;
        inout groundStation : ScalarValues::String;
    }

    port def PropulsionControlPort {
        out thrustCommand : ISQ::ForceValue;
        out rotorSpeed : ScalarValues::Real;
        in actualThrust : ISQ::ForceValue;
    }

    part def BatteryPack {
        port powerOut : PowerBusPort;
        attribute capacity : ISQ::EnergyValue;
        attribute state : BatteryState;
        attribute nominalVoltage : ISQ::ElectricPotentialValue;
        attribute maxDischargePower : ISQ::PowerValue;
    }

    part def ElectricMotor {
        port powerIn : PowerBusPort;
        port controlIn : PropulsionControlPort;
        attribute maxPower : ISQ::PowerValue;
        attribute efficiency : Real;
        attribute maxRPM : Real;
    }

    part def TiltRotor {
        port motorConnection : PropulsionControlPort;
        attribute rotorDiameter : LengthValue;
        attribute tiltAngle : Real;
        attribute maxThrust : ISQ::ForceValue;
    }

    part def FlightController {
        port navPort : NavigationPort;
        port controlPort : ControlDataPort;
        port commPort : CommunicationPort;
        attribute processingCapacity : Real;
        attribute redundancyLevel : Integer;
    }

    part def PassengerCabin {
        port cabinControl : ControlDataPort;
        attribute seatingCapacity : Integer;
        attribute maxPayload : MassValue;
        attribute currentManifest : PassengerManifest;
    }

    part def SensorSuite {
        port dataOut : ControlDataPort;
        attribute lidarRange : LengthValue;
        attribute radarRange : LengthValue;
        attribute cameraResolution : Integer;
    }

    part def VertiportStation {
        port landingPad : CommunicationPort;
        port chargingStation : PowerBusPort;
        attribute location : GPSCoordinate;
        attribute padIdentifier : ScalarValues::String;
    }

    part def PropulsionUnit {
        port powerIn : PowerBusPort;
        port controlIn : PropulsionControlPort;

        part motor : ElectricMotor {
            attribute :>> maxPower = 75[SI::kW];
            attribute :>> efficiency = 0.95;
            attribute :>> maxRPM = 3000.0;
        }

        part rotor : TiltRotor {
            attribute :>> rotorDiameter = 2.5[SI::m];
            attribute :>> maxThrust = 2000[SI::N];
        }

        connect motor.controlIn to rotor.motorConnection;
    }

    part def eVTOLAircraft {
        port mainPowerBus : PowerBusPort;
        port flightControl : ControlDataPort;
        port navigation : NavigationPort;
        port communications : CommunicationPort;

        part batterySystem : BatteryPack[4] {
            attribute :>> capacity = 150[SI::kW * SI::h];
            attribute :>> nominalVoltage = 800[SI::V];
            attribute :>> maxDischargePower = 500[SI::kW];
        }

        part propulsionUnits : PropulsionUnit[8];

        part flightComputer : FlightController {
            attribute :>> processingCapacity = 1000.0;
            attribute :>> redundancyLevel = 3;
        }

        part sensors : SensorSuite {
            attribute :>> lidarRange = 200[SI::m];
            attribute :>> radarRange = 5000[SI::m];
            attribute :>> cameraResolution = 4096;
        }

        part cabin : PassengerCabin {
            attribute :>> seatingCapacity = 4;
            attribute :>> maxPayload = 400[SI::kg];
        }

        connect batterySystem[1].powerOut to mainPowerBus;
        connect batterySystem[2].powerOut to mainPowerBus;
        connect batterySystem[3].powerOut to mainPowerBus;
        connect batterySystem[4].powerOut to mainPowerBus;
        connect mainPowerBus to propulsionUnits[1].powerIn;
        connect flightComputer.navPort to navigation;
        connect flightComputer.controlPort to flightControl;
        connect flightComputer.commPort to communications;
        connect sensors.dataOut to flightControl;
    }

    part def NetworkOperationsCenter {
        port fleetComms : CommunicationPort;
        port vertiportComms : CommunicationPort;
        attribute activeFlights : Integer;
        attribute scheduledMissions : Integer;
    }

    part def UrbanAirMobilityNetwork {
        part aircraft : eVTOLAircraft[10];
        part vertiports : VertiportStation[25];
        part operationsCenter : NetworkOperationsCenter;

        connect aircraft[1].communications to operationsCenter.fleetComms;
        connect vertiports[1].landingPad to operationsCenter.vertiportComms;
    }

    action def MonitorBatteryState {
        in batteryPacks : BatteryPack[*];
        out aggregateCharge : Real;
        out safeToFly : Boolean;
    }

    action def CalculateFlightPath {
        in origin : GPSCoordinate;
        in destination : GPSCoordinate;
        in weatherConditions : ScalarValues::String;
        out optimalPath : FlightPath;
        out estimatedDuration : ISQ::TimeValue;
    }

    action def ManagePropulsion {
        in currentPhase : FlightPhase;
        in targetThrust : ISQ::ForceValue;
        in tiltAngle : Real;
        out motorCommands : ScalarValues::Real[8];
    }

    action def CommunicateWithATC {
        in currentPosition : GPSCoordinate;
        in flightPlan : FlightPath;
        out clearance : FlightClearance;
    }

    action def ExecuteVerticalTakeoff {
        in initialPosition : GPSCoordinate;
        in targetAltitude : LengthValue;
        out finalPosition : GPSCoordinate;
        out thrustProfile : ISQ::ForceValue;
    }

    action def TransitionToForwardFlight {
        in currentAltitude : LengthValue;
        in targetSpeed : ISQ::SpeedValue;
        out rotorTiltSequence : ScalarValues::Real[*] ordered;
    }

    action def CruiseFlight {
        in flightPath : FlightPath;
        in cruiseSpeed : ISQ::SpeedValue;
        out energyConsumed : ISQ::EnergyValue;
    }

    action def ExecuteVerticalLanding {
        in approachPosition : GPSCoordinate;
        in landingPad : GPSCoordinate;
        out landingComplete : Boolean;
    }

    action def PerformUrbanAirMission {
        doc /* Primary function: Transport passengers rapidly through urban airspace,
               bypassing ground traffic by utilizing vertical takeoff and landing capabilities
               with zero emissions, disrupting traditional ground-based transportation. */

        in pickupLocation : GPSCoordinate;
        in dropoffLocation : GPSCoordinate;
        in passengers : PassengerManifest;
        out missionSuccess : Boolean;

        private attribute currentPhase : FlightPhase := FlightPhase::preflight;
        private attribute currentPosition : GPSCoordinate;
        private attribute batteryStatus : Real;
        private attribute flightPlan : FlightPath;

        first start;

        then action preflightCheck : MonitorBatteryState {
            in batteryPacks : BatteryPack[4];
            out aggregateCharge;
            out safeToFly;
        }

        then decide;
            if preflightCheck.safeToFly and preflightCheck.aggregateCharge >= 0.3 then planFlight;
            if preflightCheck.safeToFly == false or preflightCheck.aggregateCharge < 0.3 then abortMission;

        action planFlight : CalculateFlightPath {
            in origin = pickupLocation;
            in destination = dropoffLocation;
            in weatherConditions = "clear";
            out optimalPath;
            out estimatedDuration;
        }

        then assign flightPlan := planFlight.optimalPath;

        then action requestClearance : CommunicateWithATC {
            in currentPosition = pickupLocation;
            in flightPlan = flightPlan;
            out clearance;
        }

        then assign currentPhase := FlightPhase::verticalTakeoff;

        then action takeoff : ExecuteVerticalTakeoff {
            in initialPosition = pickupLocation;
            in targetAltitude = 500[SI::m];
            out finalPosition;
            out thrustProfile;
        }

        then assign currentPosition := takeoff.finalPosition;
        then assign currentPhase := FlightPhase::transition;

        then action transition : TransitionToForwardFlight {
            in currentAltitude = 500[SI::m];
            in targetSpeed = 80[SI::m / SI::s];
            out rotorTiltSequence;
        }

        then assign currentPhase := FlightPhase::cruise;

        then action cruise : CruiseFlight {
            in flightPath = flightPlan;
            in cruiseSpeed = 80[SI::m / SI::s];
            out energyConsumed;
        }

        then assign currentPhase := FlightPhase::approach;

        then action approach : TransitionToForwardFlight {
            in currentAltitude = 500[SI::m];
            in targetSpeed = 20[SI::m / SI::s];
            out rotorTiltSequence;
        }

        then assign currentPhase := FlightPhase::verticalLanding;

        then action land : ExecuteVerticalLanding {
            in approachPosition = currentPosition;
            in landingPad = dropoffLocation;
            out landingComplete;
        }

        then assign currentPhase := FlightPhase::shutdown;
        then assign missionSuccess := land.landingComplete;
        then done;

        action abortMission {
            then assign missionSuccess := false;
        }
        then done;
    }

    state def eVTOLOperationalStates {
        entry; then idle;

        state idle {
            entry action performSystemCheck;
        }

        state preflight {
            entry action checkBatteries;
            entry action verifyPassengers;
            do action requestFlightPlan;
        }

        state verticalTakeoff {
            do action applyVerticalThrust;
            do action monitorAltitude;
        }

        state transitionPhase {
            do action tiltRotors;
            do action accelerateForward;
        }

        state cruise {
            do action maintainAltitude;
            do action followFlightPath;
            do action monitorEnergy;
        }

        state approach {
            do action decelerateAircraft;
            do action tiltRotorsVertical;
        }

        state verticalLanding {
            do action descendVertically;
            do action alignWithPad;
        }

        state shutdown {
            entry action disengageMotors;
            entry action openDoors;
        }

        state emergency {
            entry action activateEmergencyProtocol;
            do action findEmergencyLanding;
        }

        transition idle_to_preflight
            first idle
            accept missionAssigned : MissionAssigned
            then preflight;

        transition preflight_to_takeoff
            first preflight
            accept clearanceReceived : ClearanceReceived
            then verticalTakeoff;

        transition takeoff_to_transition
            first verticalTakeoff
            then transitionPhase;

        transition transition_to_cruise
            first transitionPhase
            then cruise;

        transition cruise_to_approach
            first cruise
            then approach;

        transition approach_to_landing
            first approach
            accept landingApproval : LandingApproval
            then verticalLanding;

        transition landing_to_shutdown
            first verticalLanding
            then shutdown;

        transition shutdown_to_idle
            first shutdown
            accept passengersDisembarked : PassengersDisembarked
            then idle;

        transition any_to_emergency
            accept emergencySignal : EmergencySignal
            then emergency;
    }

    requirement def DisruptiveInnovationGoal {
        doc /* Transform urban transportation by providing rapid, emission-free air mobility
               that eliminates ground traffic delays and reduces urban congestion. */
    }

    requirement def UrbanAirMobilityRequirement {
        doc /* The eVTOL system shall transport passengers between urban vertiports within
               a 50 km radius in under 15 minutes, achieving speeds up to 200 km/h. */
        attribute maxRange : LengthValue = 50[SI::km];
        attribute maxTripTime : ISQ::TimeValue = 15[SI::min];
        attribute cruiseSpeed : ISQ::SpeedValue = 200[SI::km / SI::h];
    }

    requirement def ZeroEmissionRequirement {
        doc /* The aircraft shall produce zero direct emissions during all phases of flight,
               using only electric propulsion powered by rechargeable batteries. */
    }

    requirement def VerticalOperationRequirement {
        doc /* The system shall perform takeoff and landing vertically within a circular
               area no larger than 30 meters in diameter, enabling operation from compact
               urban vertiports without requiring runways. */
        attribute maxLandingArea : LengthValue = 30[SI::m];
    }

    requirement def SafetyRedundancyRequirement {
        doc /* All critical flight systems shall have triple redundancy to ensure safe
               operation even with multiple component failures. */
        attribute redundancyLevel : Integer = 3;

        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = high;
                technicalRisk = high;
                scheduleRisk = medium;
                costRisk = high;
            }
            originator = "Safety Board";
            owner = "Chief Engineer";
        }
    }

    requirement def BatteryEnduranceRequirement {
        doc /* The battery system shall provide sufficient energy for a 50 km mission plus
               30% reserve capacity for contingencies and diversions. */
        attribute minimumRange : LengthValue = 65[SI::km];
        attribute reserveCapacity : Real = 0.30;
    }

    requirement def PassengerCapacityRequirement {
        doc /* The aircraft shall accommodate 4 passengers plus pilot with total payload
               capacity of 400 kg to enable viable commercial operations. */
        attribute passengerCount : Integer = 4;
        attribute maxPayload : MassValue = 400[SI::kg];
    }

    requirement def AutonomousCapabilityRequirement {
        doc /* The system shall support fully autonomous flight operations with pilot
               oversight, reducing operational costs and enabling scalable deployment. */
    }

    requirement <'UAM-001'> urbanAirMobilitySystem {
        doc /* The eVTOL system shall revolutionize urban transportation by providing
               rapid, sustainable, point-to-point air mobility. */

        subject aircraft : eVTOLAircraft;

        require disruptiveGoal : DisruptiveInnovationGoal;
        require mobilityPerformance : UrbanAirMobilityRequirement;
        require zeroEmissions : ZeroEmissionRequirement;
        require verticalOps : VerticalOperationRequirement;
        require safetyRedundancy : SafetyRedundancyRequirement;
        require batteryEndurance : BatteryEnduranceRequirement;
        require passengerCapacity : PassengerCapacityRequirement;
        require autonomousCapability : AutonomousCapabilityRequirement;

        @StatusInfo {
            status = StatusKind::inProgress;
            risk {
                totalRisk = high;
                technicalRisk = high;
                scheduleRisk = medium;
                costRisk = high;
            }
            originator = "Urban Mobility Initiative";
            owner = "Program Director";
        }
    }

    part urbanAirMobilitySystem : UrbanAirMobilityNetwork {
        satisfy urbanAirMobilitySystem;

        perform action operationalMission[*] ordered
            references PerformUrbanAirMission;
    }
}
