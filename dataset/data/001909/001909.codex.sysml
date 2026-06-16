package CapeCanaveralLaunchSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Latitude :> Real {
        unit = "deg";
    }

    attribute def Longitude :> Real {
        unit = "deg";
    }

    attribute def TemperatureCelsius :> Real {
        unit = "degC";
    }

    attribute def WindSpeed :> Real {
        unit = "m/s";
    }

    attribute def Pressure :> Real {
        unit = "kPa";
    }

    attribute def MassFlowRate :> Real {
        unit = "kg/s";
    }

    attribute def DataRate :> Real {
        unit = "Mb/s";
    }

    attribute def Percent :> Real {
        unit = "%";
    }

    item def LaunchVehicle {
        attribute vehicleId : String;
        attribute liftoffMass : MassValue;
        attribute height : LengthValue;
        attribute propellantLoad : MassValue;
    }

    item def Payload {
        attribute payloadId : String;
        attribute payloadMass : MassValue;
        attribute targetOrbitAltitude : LengthValue;
        attribute targetOrbitInclination : Latitude;
    }

    item def Propellant {
        attribute propellantKind : String;
        attribute temperature : TemperatureCelsius;
        attribute pressure : Pressure;
        attribute quantity : MassValue;
    }

    item def TelemetryFrame {
        attribute timestamp : String;
        attribute downlinkRate : DataRate;
        attribute vehicleStateVectorValid : Boolean;
    }

    item def WeatherObservation {
        attribute windSpeed : WindSpeed;
        attribute lightningRisk : Percent;
        attribute cloudCeiling : LengthValue;
        attribute visibility : LengthValue;
    }

    item def LaunchCommand {
        attribute commandId : String;
        attribute authorizationValid : Boolean;
        attribute countdownTime : TimeValue;
    }

    port def FluidTransferPort {
        out item propellant : Propellant;
        attribute maxFlowRate : MassFlowRate;
    }

    port def VehicleServicePort {
        in item propellant : Propellant;
        in item command : LaunchCommand;
        out item telemetry : TelemetryFrame;
    }

    port def TelemetryPort {
        out item telemetry : TelemetryFrame;
        attribute nominalRate : DataRate;
    }

    port def CommandPort {
        in item command : LaunchCommand;
    }

    port def WeatherDataPort {
        out item observation : WeatherObservation;
    }

    port def RangeSafetyPort {
        in item telemetry : TelemetryFrame;
        out item command : LaunchCommand;
    }

    part def CapeCanaveralLaunchRange {
        attribute siteName : String = "Cape Canaveral Space Force Station";
        attribute latitude : Latitude = 28.3922;
        attribute longitude : Longitude = -80.6077;

        part launchPad : LaunchPad;
        part propellantFarm : PropellantFarm;
        part launchControlCenter : LaunchControlCenter;
        part rangeSafetySystem : RangeSafetySystem;
        part weatherStation : WeatherStation;
        part trackingNetwork : TrackingNetwork;
        part emergencyResponse : EmergencyResponseSystem;

        port weatherOut : WeatherDataPort;
        port rangeCommand : RangeSafetyPort;

        connect weatherStation.weatherOut to launchControlCenter.weatherIn;
        connect weatherStation.weatherOut to rangeSafetySystem.weatherIn;
        connect propellantFarm.fuelOutlet to launchPad.fuelInlet;
        connect propellantFarm.oxidizerOutlet to launchPad.oxidizerInlet;
        connect launchPad.vehicleService to launchControlCenter.vehicleInterface;
        connect launchPad.vehicleTelemetry to trackingNetwork.telemetryIn;
        connect trackingNetwork.telemetryOut to launchControlCenter.telemetryIn;
        connect trackingNetwork.telemetryOut to rangeSafetySystem.telemetryIn;
        connect rangeSafetySystem.commandOut to launchPad.rangeCommandIn;
        connect launchControlCenter.launchCommandOut to launchPad.launchCommandIn;
    }

    part def LaunchPad {
        attribute padIdentifier : String = "SLC-40";
        attribute flameTrenchTemperatureLimit : TemperatureCelsius = 1200.0;
        attribute holdDownReleaseReady : Boolean;
        attribute lightningProtectionReady : Boolean;

        part serviceTower : ServiceTower;
        part transporterErector : TransporterErector;
        part flameDeflector : FlameDeflector;
        part umbilicalMast : UmbilicalMast;
        part vehicle : LaunchVehicleOnPad;

        port fuelInlet : FluidTransferPort;
        port oxidizerInlet : FluidTransferPort;
        port vehicleService : VehicleServicePort;
        port vehicleTelemetry : TelemetryPort;
        port launchCommandIn : CommandPort;
        port rangeCommandIn : CommandPort;

        connect fuelInlet to umbilicalMast.fuelTransfer;
        connect oxidizerInlet to umbilicalMast.oxidizerTransfer;
        connect umbilicalMast.vehicleService to vehicle.servicePort;
        connect vehicle.telemetryOut to vehicleTelemetry;
        connect launchCommandIn to vehicle.commandIn;
        connect rangeCommandIn to vehicle.rangeSafetyIn;
    }

    part def PropellantFarm {
        attribute fuelInventory : MassValue = 420000.0 [kg];
        attribute oxidizerInventory : MassValue = 900000.0 [kg];
        attribute tankPressure : Pressure = 690.0;

        part fuelTank : StorageTank;
        part oxidizerTank : StorageTank;
        part transferPumps : PumpSet;
        part chilldownSystem : ChilldownSystem;

        port fuelOutlet : FluidTransferPort;
        port oxidizerOutlet : FluidTransferPort;
    }

    part def StorageTank {
        attribute capacity : MassValue;
        attribute storedPropellantKind : String;
        attribute currentQuantity : MassValue;
        attribute storageTemperature : TemperatureCelsius;
        attribute storagePressure : Pressure;
    }

    part def PumpSet {
        attribute pumpCount : Integer = 6;
        attribute totalFlowRate : MassFlowRate = 2500.0;
        attribute redundantPumpAvailable : Boolean;
    }

    part def ChilldownSystem {
        attribute targetLineTemperature : TemperatureCelsius = -180.0;
        attribute chilldownComplete : Boolean;
    }

    part def ServiceTower {
        attribute crewAccessReady : Boolean;
        attribute serviceArmRetracted : Boolean;
    }

    part def TransporterErector {
        attribute vehicleVertical : Boolean;
        attribute erectorRetracted : Boolean;
    }

    part def FlameDeflector {
        attribute waterDelugeActive : Boolean;
        attribute acousticSuppressionFlow : MassFlowRate = 18000.0;
    }

    part def UmbilicalMast {
        port fuelTransfer : FluidTransferPort;
        port oxidizerTransfer : FluidTransferPort;
        port vehicleService : VehicleServicePort;

        attribute umbilicalsConnected : Boolean;
        attribute quickDisconnectArmed : Boolean;
    }

    part def LaunchVehicleOnPad {
        item vehicle : LaunchVehicle;
        item missionPayload : Payload;

        attribute avionicsReady : Boolean;
        attribute propulsionReady : Boolean;
        attribute flightSoftwareLoaded : Boolean;
        attribute autonomousFlightSafetyEnabled : Boolean;

        port servicePort : VehicleServicePort;
        port telemetryOut : TelemetryPort;
        port commandIn : CommandPort;
        port rangeSafetyIn : CommandPort;
    }

    part def LaunchControlCenter {
        attribute consoleCrewReady : Boolean;
        attribute launchDirectorGo : Boolean;
        attribute missionDirectorGo : Boolean;
        attribute automatedSequencerArmed : Boolean;

        part countdownSequencer : CountdownSequencer;
        part missionManagementConsole : MissionManagementConsole;
        part groundDataSystem : GroundDataSystem;

        port vehicleInterface : VehicleServicePort;
        port weatherIn : WeatherDataPort;
        port telemetryIn : TelemetryPort;
        port launchCommandOut : CommandPort;
    }

    part def CountdownSequencer {
        attribute currentTMinus : TimeValue;
        attribute holdActive : Boolean;
        attribute terminalCountStarted : Boolean;
    }

    part def MissionManagementConsole {
        attribute launchCommitCriteriaSatisfied : Boolean;
        attribute payloadCustomerGo : Boolean;
    }

    part def GroundDataSystem {
        attribute dataArchiveRate : DataRate = 1200.0;
        attribute commandLinkHealthy : Boolean;
    }

    part def RangeSafetySystem {
        attribute rangeClear : Boolean;
        attribute flightTerminationEnabled : Boolean;
        attribute publicSafetyRiskAcceptable : Boolean;

        port weatherIn : WeatherDataPort;
        port telemetryIn : TelemetryPort;
        port commandOut : RangeSafetyPort;
    }

    part def WeatherStation {
        attribute observationInterval : TimeValue = 30.0 [s];
        attribute lightningFieldMillReady : Boolean;
        attribute radarAvailable : Boolean;

        port weatherOut : WeatherDataPort;
    }

    part def TrackingNetwork {
        attribute radarTrackValid : Boolean;
        attribute opticalTrackValid : Boolean;
        attribute telemetryLock : Boolean;

        part radarSite : RadarTracker;
        part telemetryAntenna : TelemetryAntenna;
        part opticalTracker : OpticalTracker;

        port telemetryIn : TelemetryPort;
        port telemetryOut : TelemetryPort;
    }

    part def RadarTracker {
        attribute rangeAccuracy : LengthValue = 5.0 [m];
        attribute updateRate : FrequencyValue = 20.0 [Hz];
    }

    part def TelemetryAntenna {
        attribute receiveRate : DataRate = 400.0;
        attribute signalToNoiseRatio : Real;
    }

    part def OpticalTracker {
        attribute angularResolution : Real;
        attribute daylightCapable : Boolean;
    }

    part def EmergencyResponseSystem {
        attribute fireSuppressionReady : Boolean;
        attribute evacuationRouteOpen : Boolean;
        attribute medicalTeamReady : Boolean;
        attribute hazardousAreaSecured : Boolean;
    }

    action def PrepareLaunchVehicle {
        in vehicle : LaunchVehicle;
        in payload : Payload;
        out prepared : Boolean;

        first start;
        then verifyPayloadIntegration;
        then loadFlightSoftware;
        then connectGroundServices;
        then runIntegratedTests;
        then done;

        action verifyPayloadIntegration;
        action loadFlightSoftware;
        action connectGroundServices;
        action runIntegratedTests;
    }

    action def LoadPropellant {
        in fuel : Propellant;
        in oxidizer : Propellant;
        out loaded : Boolean;

        first start;
        then chillTransferLines;
        then beginSlowFill;
        then transitionToFastFill;
        then topOffTanks;
        then verifyStablePressures;
        then done;

        action chillTransferLines;
        action beginSlowFill;
        action transitionToFastFill;
        action topOffTanks;
        action verifyStablePressures;
    }

    action def ConductCountdown {
        in observation : WeatherObservation;
        in vehicleTelemetry : TelemetryFrame;
        out launchCommit : Boolean;

        first start;
        then pollMissionTeams;
        then evaluateWeatherRules;
        then evaluateRangeSafety;
        then armAutomatedSequencer;
        then issueLaunchCommand;
        then done;

        action pollMissionTeams;
        action evaluateWeatherRules;
        action evaluateRangeSafety;
        action armAutomatedSequencer;
        action issueLaunchCommand;
    }

    action def ExecuteLaunch {
        in command : LaunchCommand;
        out liftoffConfirmed : Boolean;

        first start;
        then igniteMainEngines;
        then verifyThrust;
        then releaseHoldDowns;
        then clearTower;
        then transferToFlightTracking;
        then done;

        action igniteMainEngines;
        action verifyThrust;
        action releaseHoldDowns;
        action clearTower;
        action transferToFlightTracking;
    }

    state def LaunchCampaignStateMachine {
        entry action initializeCampaign;

        state CampaignPlanned;
        state VehicleIntegrated;
        state OnPad;
        state PropellantLoading;
        state TerminalCount;
        state Liftoff;
        state AscentTracking;
        state Scrubbed;
        state Secured;

        transition first CampaignPlanned;
        transition CampaignPlanned then VehicleIntegrated
            accept VehicleIntegrationComplete;
        transition VehicleIntegrated then OnPad
            accept RolloutComplete;
        transition OnPad then PropellantLoading
            accept LaunchDirectorGo;
        transition PropellantLoading then TerminalCount
            accept TankingComplete;
        transition TerminalCount then Liftoff
            accept LaunchCommandIssued
            if launchCommitCriteriaSatisfied;
        transition TerminalCount then Scrubbed
            accept HoldOrAbort
            if not launchCommitCriteriaSatisfied;
        transition Liftoff then AscentTracking
            accept TowerClear;
        transition Scrubbed then Secured
            accept SafingComplete;
        transition AscentTracking then Secured
            accept VehicleBeyondRange;

        attribute launchCommitCriteriaSatisfied : Boolean;

        action initializeCampaign;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         * The Cape Canaveral launch range system shall provide integrated coastal launch infrastructure
         * whose primary high-level function is to safely prepare, command, launch, and track orbital
         * launch vehicles from Cape Canaveral while protecting personnel, public safety, payloads,
         * ground assets, and surrounding air and sea space.
         */

        subject system : CapeCanaveralLaunchRange;

        require constraint {
            system.launchPad.holdDownReleaseReady == true and
            system.rangeSafetySystem.rangeClear == true and
            system.launchControlCenter.launchDirectorGo == true;
        }
    }

    requirement def WeatherSafetyRequirement {
        doc
        /*
         * The system shall inhibit launch when observed weather violates launch commit criteria.
         */

        subject weather : WeatherObservation;

        require constraint {
            weather.windSpeed <= 15.0 and
            weather.lightningRisk <= 5.0 and
            weather.visibility >= 8000.0 [m];
        }
    }

    requirement def RangeSafetyRequirement {
        doc
        /*
         * The range safety system shall maintain valid tracking and command authority during powered flight.
         */

        subject range : RangeSafetySystem;

        require constraint {
            range.rangeClear == true and
            range.flightTerminationEnabled == true and
            range.publicSafetyRiskAcceptable == true;
        }
    }

    requirement def PropellantReadinessRequirement {
        doc
        /*
         * The propellant farm and pad umbilicals shall deliver conditioned propellant to the vehicle
         * within required pressure, temperature, and flow limits before terminal count.
         */

        subject farm : PropellantFarm;

        require constraint {
            farm.fuelInventory >= 300000.0 [kg] and
            farm.oxidizerInventory >= 650000.0 [kg] and
            farm.transferPumps.totalFlowRate >= 2000.0;
        }
    }

    requirement def TelemetryRequirement {
        doc
        /*
         * The tracking network shall receive, archive, and distribute vehicle telemetry from ignition
         * through range handover.
         */

        subject network : TrackingNetwork;

        require constraint {
            network.telemetryLock == true and
            network.radarTrackValid == true;
        }
    }

    satisfy PrimaryFunctionRequirement by CapeCanaveralLaunchRange;
    satisfy WeatherSafetyRequirement by WeatherStation;
    satisfy RangeSafetyRequirement by RangeSafetySystem;
    satisfy PropellantReadinessRequirement by PropellantFarm;
    satisfy TelemetryRequirement by TrackingNetwork;

    part capeCanaveralOperationalSystem : CapeCanaveralLaunchRange {
        attribute siteName = "Cape Canaveral Space Force Station Integrated Launch Range";

        part launchPad {
            attribute padIdentifier = "Space Launch Complex 40";
            attribute holdDownReleaseReady = true;
            attribute lightningProtectionReady = true;

            part vehicle {
                attribute avionicsReady = true;
                attribute propulsionReady = true;
                attribute flightSoftwareLoaded = true;
                attribute autonomousFlightSafetyEnabled = true;

                item vehicle {
                    attribute vehicleId = "CCAFS-Orbital-Launch-Vehicle-01";
                    attribute liftoffMass = 549000.0 [kg];
                    attribute height = 70.0 [m];
                    attribute propellantLoad = 509000.0 [kg];
                }

                item missionPayload {
                    attribute payloadId = "Coastal-Orbit-Payload-A";
                    attribute payloadMass = 8200.0 [kg];
                    attribute targetOrbitAltitude = 550000.0 [m];
                    attribute targetOrbitInclination = 53.0;
                }
            }
        }

        part rangeSafetySystem {
            attribute rangeClear = true;
            attribute flightTerminationEnabled = true;
            attribute publicSafetyRiskAcceptable = true;
        }

        part launchControlCenter {
            attribute consoleCrewReady = true;
            attribute launchDirectorGo = true;
            attribute missionDirectorGo = true;
            attribute automatedSequencerArmed = true;
        }

        part trackingNetwork {
            attribute radarTrackValid = true;
            attribute opticalTrackValid = true;
            attribute telemetryLock = true;
        }

        part emergencyResponse {
            attribute fireSuppressionReady = true;
            attribute evacuationRouteOpen = true;
            attribute medicalTeamReady = true;
            attribute hazardousAreaSecured = true;
        }
    }
}