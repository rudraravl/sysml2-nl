package ElectronLaunchVehicleSystem {

    package ValueDefinitions {
        value def Length :> Real { unit 'm'; }
        value def Mass :> Real { unit 'kg'; }
        value def Velocity :> Real { unit 'm/s'; }
        value def Altitude :> Real { unit 'm'; }
        value def Thrust :> Real { unit 'N'; }
        value def ThrottleSetting :> Real { unit '%'; min 0; max 100; }
        value def Frequency :> Real { unit 'MHz'; }
        value def Angle :> Real { unit 'deg'; }
        value def Duration :> Real { unit 's'; }
        value def DataRate :> Real { unit 'kbps'; }
    }

    package ItemDefinitions {
        item def TelemetryData {
            attribute altitude : Altitude;
            attribute velocity : Velocity;
            attribute propellantMass : Mass;
            attribute stageState : String;
            attribute healthStatus : String;
        }

        item def GuidanceCommand {
            attribute pitch : Angle;
            attribute yaw : Angle;
            attribute roll : Angle;
            attribute throttle : ThrottleSetting;
        }

        item def GroundCommand {
            attribute commandType : String;
            attribute authorization : Boolean;
        }

        item def PayloadData {
            attribute payloadMass : Mass;
            attribute targetOrbitAltitude : Altitude;
            attribute targetInclination : Angle;
        }

        item def SatellitePayload {
            attribute mass : Mass;
            attribute targetOrbit : String;
        }
    }

    package PortDefinitions {
        port def TelemetryOutPort {
            out telemetry : TelemetryData;
        }

        port def TelemetryInPort {
            in telemetry : TelemetryData;
        }

        port def CommandOutPort {
            out command : GroundCommand;
        }

        port def CommandInPort {
            in command : GroundCommand;
        }

        port def GuidanceOutPort {
            out guidance : GuidanceCommand;
        }

        port def GuidanceInPort {
            in guidance : GuidanceCommand;
        }

        port def PayloadDeployPort {
            out payload : SatellitePayload;
        }
    }

    package Interfaces {
        interface def TelemetryLink {
            end source : TelemetryOutPort;
            end target : TelemetryInPort;
        }

        interface def CommandLink {
            end source : CommandOutPort;
            end target : CommandInPort;
        }

        interface def GuidanceInterface {
            end source : GuidanceOutPort;
            end target : GuidanceInPort;
        }
    }

    package Components {

        part def RutherfordEngine {
            attribute maxThrust : Thrust = 25000 [N];
            attribute isVacuumOptimized : Boolean;
            attribute currentThrottle : ThrottleSetting = 0 [%];
            port in guidance : GuidanceInPort;
            
            action def Ignite;
            action def Shutdown;
            action def SetThrottle(in level : ThrottleSetting);
            
            perform action ignite : Ignite;
            perform action shutdown : Shutdown;
        }

        part def AvionicsSystem {
            attribute samplingRate : Frequency = 100 [MHz];
            port out telemetry : TelemetryOutPort;
            port in command : CommandInPort;
            port out guidance : GuidanceOutPort;
            
            attribute currentAltitude : Altitude;
            attribute currentVelocity : Velocity;
            attribute currentPropellantMass : Mass;
            attribute criticalFailure : Boolean = false;
            
            action def ExecuteFlightSequence;
            action def ComputeGuidance(out cmd : GuidanceCommand);
            action def MonitorHealth(out status : String);
            action def PackageTelemetry(out data : TelemetryData);
            action def ProcessCommand(in cmd : GroundCommand);
            
            state machine def AvionicsStates {
                entry;
                state Standby;
                state ActiveGuidance;
                state FailureMode;
                state SafeMode;
                
                transition from Standby to ActiveGuidance
                    when command.command.authorization == true;
                transition from ActiveGuidance to FailureMode
                    when self.criticalFailure == true;
                transition from FailureMode to SafeMode;
            }
        }

        part def FirstStage {
            attribute stageLength : Length = 12 [m];
            attribute dryMass : Mass = 1250 [kg];
            attribute propellantMass : Mass = 10200 [kg];
            part engines : RutherfordEngine[9] {
                attribute isVacuumOptimized = false;
            }
            port in guidance : GuidanceInPort;
            
            action def StageSeparation;
            perform action separate : StageSeparation;
        }

        part def SecondStage {
            attribute stageLength : Length = 6 [m];
            attribute dryMass : Mass = 900 [kg];
            attribute propellantMass : Mass = 2150 [kg];
            part engine : RutherfordEngine {
                attribute isVacuumOptimized = true;
            }
            port in guidance : GuidanceInPort;
            
            action def IgniteStage;
            action def ShutdownStage;
            perform action ignite : IgniteStage;
            perform action shutdown : ShutdownStage;
        }

        part def KickStage {
            attribute dryMass : Mass = 350 [kg];
            attribute propellantMass : Mass = 500 [kg];
            attribute isOptional : Boolean = true;
            
            action def CircularizationBurn;
            perform action burn : CircularizationBurn;
        }

        part def PayloadFairing {
            attribute fairingMass : Mass = 110 [kg];
            attribute jettisonAltitude : Altitude = 100000 [m];
            
            action def Jettison;
            perform action jettison : Jettison;
        }

        part def PayloadBay {
            attribute maxPayloadMass : Mass = 300 [kg];
            port out deploy : PayloadDeployPort;
            part payload : SatellitePayload;
            
            action def DeployPayload;
            perform action deployPayload : DeployPayload;
        }

        part def Rocket {
            attribute totalHeight : Length = 18 [m];
            attribute totalLiftOffMass : Mass = 13000 [kg];
            
            part firstStage : FirstStage;
            part secondStage : SecondStage;
            part kickStage : KickStage;
            part fairing : PayloadFairing;
            part payloadBay : PayloadBay;
            part avionics : AvionicsSystem;
            
            connection guidanceToFirstStage : GuidanceInterface
                connect avionics.guidance to firstStage.guidance;
            connection guidanceToSecondStage : GuidanceInterface
                connect avionics.guidance to secondStage.guidance;
            
            state machine def MissionSequence {
                state PreLaunchChecks;
                state Liftoff;
                state FirstStageAscent;
                state StageSeparation;
                state SecondStageAscent;
                state FairingJettison;
                state CoastPhase;
                state KickStageBurn;
                state PayloadDeployment;
                state MissionComplete;
                
                transition from PreLaunchChecks to Liftoff
                    when avionics.command.command.authorization == true;
                transition from Liftoff to FirstStageAscent;
                transition from FirstStageAscent to StageSeparation
                    when avionics.currentAltitude >= 80000 [m] 
                    and avionics.currentVelocity >= 2400 [m/s];
                transition from StageSeparation to SecondStageAscent;
                transition from SecondStageAscent to FairingJettison
                    when avionics.currentAltitude >= 100000 [m];
                transition from FairingJettison to CoastPhase;
                transition from CoastPhase to KickStageBurn;
                transition from KickStageBurn to PayloadDeployment;
                transition from PayloadDeployment to MissionComplete;
            }
        }

        part def GroundControlStation {
            attribute stationLocation : String;
            attribute commFrequency : Frequency = 2100 [MHz];
            attribute telemetryRate : DataRate = 512 [kbps];
            
            port in telemetry : TelemetryInPort;
            port out command : CommandOutPort;
            
            action def InitiatePreLaunchChecks;
            action def ReceiveTelemetry(in data : TelemetryData);
            action def SendAbortCommand;
            action def AuthorizeLaunch;
            
            perform action preLaunch : InitiatePreLaunchChecks;
            perform action authorize : AuthorizeLaunch;
            perform action abort : SendAbortCommand;
            
            state machine def GroundControlStates {
                state Idle;
                state Monitoring;
                state AbortDecision;
                state MissionTerminated;
                
                transition from Idle to Monitoring
                    when preLaunch.done;
                transition from Monitoring to AbortDecision
                    when telemetry.telemetry.healthStatus == "CRITICAL";
                transition from AbortDecision to MissionTerminated
                    when abort.done;
            }
        }
    }

    package System {
        part def ElectronLaunchSystem {
            part rocket : Components::Rocket;
            part groundStation : Components::GroundControlStation;
            
            connection telemetryDownlink : Interfaces::TelemetryLink
                connect rocket.avionics.telemetry to groundStation.telemetry;
            connection commandUplink : Interfaces::CommandLink
                connect groundStation.command to rocket.avionics.command;
        }
    }

    package Requirements {
        requirement def PayloadCapacityRequirement {
            doc /* The system shall deliver satellites up to 300 kg into low Earth orbit. */
            subject payloadBay : Components::PayloadBay;
            constraint { payloadBay.maxPayloadMass <= 300 [kg] }
        }

        requirement def OrbitalAccuracyRequirement {
            doc /* The kick stage shall place the satellite into its exact target orbit. */
            subject kickStage : Components::KickStage;
            constraint { kickStage.burn.done implies payloadBay.deployPayload.done }
        }

        requirement def ReliabilityRequirement {
            doc /* The avionics shall continuously monitor vehicle health and report critical failures. */
            subject avionics : Components::AvionicsSystem;
            constraint { avionics.criticalFailure == true implies avionics.telemetry.telemetry.healthStatus == "CRITICAL" }
        }

        requirement def FlightSafetyRequirement {
            doc /* The ground control station shall be able to send an abort command upon critical failure. */
            subject groundStation : Components::GroundControlStation;
            constraint { groundStation.abort.defined == true }
        }

        requirement def LaunchSequenceRequirement {
            doc /* The rocket shall execute the full autonomous flight sequence from pre-launch to payload deployment. */
            subject rocket : Components::Rocket;
            constraint { rocket.MissionSequence.MissionComplete.reached == true }
        }

        requirement def CommunicationRequirement {
            doc /* Telemetry shall be transmitted continuously from the rocket to the ground control station. */
            subject system : System::ElectronLaunchSystem;
            constraint { system.telemetryDownlink.defined == true }
        }

        requirement def VehicleDimensionRequirement {
            doc /* The Electron rocket shall stand 18 meters tall. */
            subject rocket : Components::Rocket;
            constraint { rocket.totalHeight == 18 [m] }
        }

        requirement def PropulsionConfigurationRequirement {
            doc /* The first stage shall use nine Rutherford engines and the second stage shall use one vacuum-optimized Rutherford engine. */
            subject rocket : Components::Rocket;
            constraint { rocket.firstStage.engines.size == 9 
                and rocket.secondStage.engine.isVacuumOptimized == true }
        }

        requirement package ElectronRequirements {
            requirement payloadCapacity : PayloadCapacityRequirement;
            requirement orbitalAccuracy : OrbitalAccuracyRequirement;
            requirement reliability : ReliabilityRequirement;
            requirement flightSafety : FlightSafetyRequirement;
            requirement launchSequence : LaunchSequenceRequirement;
            requirement communication : CommunicationRequirement;
            requirement vehicleDimension : VehicleDimensionRequirement;
            requirement propulsionConfig : PropulsionConfigurationRequirement;
        }
    }

    package Verification {
        verification def VerifyPayloadCapacity {
            subject payloadBay : Components::PayloadBay;
            objective { payloadBay.maxPayloadMass <= 300 [kg] }
            method { Static analysis of payload bay mass specification. }
        }

        verification def VerifyOrbitalAccuracy {
            subject kickStage : Components::KickStage;
            objective { kickStage.burn.done implies payloadBay.deployPayload.done }
            method { Simulation of kick stage circularization burn. }
        }

        verification def VerifyReliability {
            subject avionics : Components::AvionicsSystem;
            objective { avionics.criticalFailure == true implies avionics.telemetry.telemetry.healthStatus == "CRITICAL" }
            method { Fault injection test of avionics health monitoring. }
        }

        verification def VerifyFlightSafety {
            subject groundStation : Components::GroundControlStation;
            objective { groundStation.abort.defined == true }
            method { End-to-end abort command transmission test. }
        }

        verification def VerifyLaunchSequence {
            subject rocket : Components::Rocket;
            objective { rocket.MissionSequence.MissionComplete.reached == true }
            method { Full mission simulation from pre-launch to deployment. }
        }

        verification def VerifyCommunication {
            subject system : System::ElectronLaunchSystem;
            objective { system.telemetryDownlink.defined == true }
            method { RF link test between rocket and ground station. }
        }

        verification def VerifyVehicleDimension {
            subject rocket : Components::Rocket;
            objective { rocket.totalHeight == 18 [m] }
            method { Physical measurement of integrated vehicle. }
        }

        verification def VerifyPropulsionConfig {
            subject rocket : Components::Rocket;
            objective { rocket.firstStage.engines.size == 9 
                and rocket.secondStage.engine.isVacuumOptimized == true }
            method { Inspection of engine configuration. }
        }
    }

    package Satisfaction {
        satisfy Requirements::ElectronRequirements::payloadCapacity by Components::PayloadBay;
        satisfy Requirements::ElectronRequirements::orbitalAccuracy by Components::KickStage;
        satisfy Requirements::ElectronRequirements::reliability by Components::AvionicsSystem;
        satisfy Requirements::ElectronRequirements::flightSafety by Components::GroundControlStation;
        satisfy Requirements::ElectronRequirements::launchSequence by Components::Rocket;
        satisfy Requirements::ElectronRequirements::communication by System::ElectronLaunchSystem;
        satisfy Requirements::ElectronRequirements::vehicleDimension by Components::Rocket;
        satisfy Requirements::ElectronRequirements::propulsionConfig by Components::Rocket;

        verify Requirements::ElectronRequirements::payloadCapacity by Verification::VerifyPayloadCapacity;
        verify Requirements::ElectronRequirements::orbitalAccuracy by Verification::VerifyOrbitalAccuracy;
        verify Requirements::ElectronRequirements::reliability by Verification::VerifyReliability;
        verify Requirements::ElectronRequirements::flightSafety by Verification::VerifyFlightSafety;
        verify Requirements::ElectronRequirements::launchSequence by Verification::VerifyLaunchSequence;
        verify Requirements::ElectronRequirements::communication by Verification::VerifyCommunication;
        verify Requirements::ElectronRequirements::vehicleDimension by Verification::VerifyVehicleDimension;
        verify Requirements::ElectronRequirements::propulsionConfig by Verification::VerifyPropulsionConfig;
    }

}
