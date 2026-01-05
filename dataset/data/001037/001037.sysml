package 'Electron Launch Vehicle System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Altitude :> ISQ::LengthValue;
    attribute def Velocity :> ISQ::SpeedValue;
    attribute def Acceleration :> ISQ::AccelerationValue;
    attribute def PropellantMass :> ISQ::MassValue;
    attribute def Thrust :> ISQ::ForceValue;
    attribute def PayloadMass :> ISQ::MassValue;
    attribute def FlightTime :> ISQ::TimeValue;
    attribute def PitchAngle :> ISQ::DimensionlessQuantityValue;
    
    enum def FlightPhase {
        prelaunch;
        firstStageAscent;
        stageSeparation;
        secondStageAscent;
        coastPhase;
        kickStageIgnition;
        orbitalInsertion;
        payloadDeployment;
        missionComplete;
    }
    
    enum def VehicleStatus {
        nominal;
        degraded;
        critical;
        aborted;
    }
    
    item def Payload {
        attribute mass : PayloadMass;
        attribute targetOrbitAltitude : Altitude;
        attribute targetInclination : PitchAngle;
    }
    
    item def TelemetryData {
        attribute currentAltitude : Altitude;
        attribute currentVelocity : Velocity;
        attribute currentAcceleration : Acceleration;
        attribute remainingPropellant : PropellantMass;
        attribute vehicleStatus : VehicleStatus;
        attribute flightPhase : FlightPhase;
    }
    
    item def LaunchCommand {
        attribute authorized : Boolean;
        attribute countdown : FlightTime;
    }
    
    item def GuidanceCommand {
        attribute pitchAngle : PitchAngle;
        attribute yawAngle : PitchAngle;
        attribute rollAngle : PitchAngle;
        attribute throttleSetting : Real;
    }
    
    port def TelemetryPort {
        out telemetry : TelemetryData;
    }
    
    port def CommandPort {
        in launchCmd : LaunchCommand;
        in abortCmd : Boolean;
    }
    
    port def GuidancePort {
        in guidance : GuidanceCommand;
        out currentAttitude : PitchAngle[3];
    }
    
    port def PropulsionPort {
        out thrust : Thrust;
        in throttleCommand : Real;
    }
    
    action def ComputeTrajectory {
        in currentAltitude : Altitude;
        in currentVelocity : Velocity;
        in targetAltitude : Altitude;
        in vehicleMass : ISQ::MassValue;
        out requiredThrust : Thrust;
        out pitchProfile : PitchAngle;
    }
    
    action def MonitorVehicleHealth {
        in telemetry : TelemetryData;
        in criticalParameters : Real[*];
        out healthStatus : VehicleStatus;
        out abortRecommendation : Boolean;
    }
    
    action def ExecuteStageSeparation {
        in currentVelocity : Velocity;
        in currentAltitude : Altitude;
        out separationComplete : Boolean;
        out stageJettisoned : Boolean;
    }
    
    action def DeployPayload {
        in orbitalVelocity : Velocity;
        in orbitalAltitude : Altitude;
        in payload : Payload;
        out deploymentSuccess : Boolean;
    }
    
    part def RutherfordEngine {
        attribute nominalThrust : Thrust;
        attribute specificImpulse : Real;
        attribute propellantFlowRate : Real;
        
        port propulsion : PropulsionPort;
        
        attribute currentThrust : Thrust;
        attribute isOperating : Boolean;
    }
    
    part def FirstStage {
        attribute dryMass : ISQ::MassValue;
        attribute propellantCapacity : PropellantMass;
        attribute currentPropellant : PropellantMass;
        
        part engines : RutherfordEngine[9];
        
        port propulsionOut : PropulsionPort;
        
        perform action burn {
            in throttle : Real;
            out totalThrust : Thrust;
            out burnTime : FlightTime;
        }
    }
    
    part def SecondStage {
        attribute dryMass : ISQ::MassValue;
        attribute propellantCapacity : PropellantMass;
        attribute currentPropellant : PropellantMass;
        
        part engine : RutherfordEngine;
        
        port propulsionOut : PropulsionPort;
        
        perform action burn {
            in throttle : Real;
            out thrust : Thrust;
            out burnTime : FlightTime;
        }
    }
    
    part def KickStage {
        attribute dryMass : ISQ::MassValue;
        attribute propellantCapacity : PropellantMass;
        
        port propulsionOut : PropulsionPort;
        
        perform action circularize {
            in targetAltitude : Altitude;
            out finalOrbit : Boolean;
        }
    }
    
    part def AvionicsSystem {
        port telemetryOut : TelemetryPort;
        port commandIn : CommandPort;
        port guidanceOut : GuidancePort;
        
        perform action flightControl {
            in launchCommand : LaunchCommand;
            in currentState : TelemetryData;
            out guidanceCommands : GuidanceCommand;
        }
        
        perform action healthMonitoring : MonitorVehicleHealth {
            in telemetry;
            in criticalParameters;
            out healthStatus;
            out abortRecommendation;
        }
    }
    
    part def PayloadFairing {
        attribute mass : ISQ::MassValue;
        
        perform action jettison {
            in altitude : Altitude;
            out jettisonComplete : Boolean;
        }
    }
    
    part def GroundControl {
        port commandOut : CommandPort;
        port telemetryIn : TelemetryPort;
        
        perform action missionManagement {
            in telemetry : TelemetryData;
            out commands : LaunchCommand;
            out abortDecision : Boolean;
        }
    }
    
    action def LaunchSequence {
        in launchAuthorization : LaunchCommand;
        in targetPayload : Payload;
        out missionSuccess : Boolean;
        
        private attribute currentAltitude : Altitude := 0.0 [m];
        private attribute currentVelocity : Velocity := 0.0 [m/s];
        
        first start;
        
        then action prelaunchChecks {
            in authorization = launchAuthorization;
            out readyForLaunch : Boolean;
        }
        
        then decide;
            if prelaunchChecks.readyForLaunch then liftoff;
            if not prelaunchChecks.readyForLaunch then abortMission;
        
        action liftoff {
            action firstStageBurn {
                in throttle : Real := 1.0;
                out thrust : Thrust;
                out burnDuration : FlightTime;
            }
            
            then assign currentAltitude := 80000.0 [m];
            then assign currentVelocity := 2300.0 [m/s];
            
            then action separateFirstStage : ExecuteStageSeparation {
                in currentVelocity = currentVelocity;
                in currentAltitude = currentAltitude;
                out separationComplete;
                out stageJettisoned;
            }
            
            then action secondStageBurn {
                in throttle : Real := 1.0;
                out thrust : Thrust;
                out burnDuration : FlightTime;
            }
            
            then assign currentAltitude := 200000.0 [m];
            then assign currentVelocity := 7200.0 [m/s];
            
            then action jettisonFairing {
                in altitude = currentAltitude;
                out complete : Boolean;
            }
            
            then action coast {
                in duration : FlightTime := 300.0 [s];
                out coastComplete : Boolean;
            }
            
            then action kickStageBurn {
                in targetAltitude = targetPayload.targetOrbitAltitude;
                out orbitalVelocity : Velocity;
            }
            
            then assign currentVelocity := kickStageBurn.orbitalVelocity;
            
            then action verifyOrbit {
                in altitude = currentAltitude;
                in velocity = currentVelocity;
                in target = targetPayload.targetOrbitAltitude;
                out orbitAchieved : Boolean;
            }
            
            then decide;
                if verifyOrbit.orbitAchieved then deployPayloadAction;
                if not verifyOrbit.orbitAchieved then partialSuccess;
            
            action deployPayloadAction : DeployPayload {
                in orbitalVelocity = currentVelocity;
                in orbitalAltitude = currentAltitude;
                in payload = targetPayload;
                out deploymentSuccess;
            }
            
            then assign missionSuccess := deployPayloadAction.deploymentSuccess;
            
            action partialSuccess {
                then assign missionSuccess := false;
            }
        }
        
        action abortMission {
            then assign missionSuccess := false;
        }
        
        then done;
    }
    
    part def ElectronLaunchVehicle {
        doc /* 
            Electron is a two-stage orbital launch vehicle designed to deliver small satellites
            to low Earth orbit. The vehicle uses electric pump-fed Rutherford engines and features
            an optional kick stage for precise orbital insertion.
        */
        
        attribute totalMass : ISQ::MassValue;
        attribute height : ISQ::LengthValue := 18.0 [m];
        attribute diameter : ISQ::LengthValue := 1.2 [m];
        attribute currentPhase : FlightPhase := FlightPhase::prelaunch;
        
        part stage1 : FirstStage {
            attribute :>> dryMass := 950.0 [kg];
            attribute :>> propellantCapacity := 9500.0 [kg];
            attribute :>> currentPropellant := 9500.0 [kg];
        }
        
        part stage2 : SecondStage {
            attribute :>> dryMass := 250.0 [kg];
            attribute :>> propellantCapacity := 2150.0 [kg];
            attribute :>> currentPropellant := 2150.0 [kg];
        }
        
        part kickStage : KickStage {
            attribute :>> dryMass := 50.0 [kg];
            attribute :>> propellantCapacity := 120.0 [kg];
        }
        
        part fairing : PayloadFairing {
            attribute :>> mass := 50.0 [kg];
        }
        
        part avionics : AvionicsSystem;
        
        part payloadBay {
            attribute maxPayloadMass : PayloadMass := 300.0 [kg];
            attribute currentPayload : Payload;
        }
        
        port vehicleTelemetry : TelemetryPort;
        port vehicleCommand : CommandPort;
        port vehicleGuidance : GuidancePort;
        
        connect avionics.telemetryOut to vehicleTelemetry;
        connect avionics.commandIn to vehicleCommand;
        connect avionics.guidanceOut to vehicleGuidance;
        
        perform action mission : LaunchSequence {
            in launchAuthorization;
            in targetPayload = payloadBay.currentPayload;
            out missionSuccess;
        }
    }
    
    part groundStation : GroundControl;
    
    part electron : ElectronLaunchVehicle;
    
    connect groundStation.commandOut to electron.vehicleCommand;
    connect groundStation.telemetryIn to electron.vehicleTelemetry;
    
    requirement def <'REQ-001'> PrimaryMissionRequirement {
        doc /* 
            The Electron launch vehicle shall deliver small satellite payloads with mass
            up to 300 kg to low Earth orbit altitudes between 300 km and 1200 km.
        */
        
        subject vehicle : ElectronLaunchVehicle;
        
        require constraint payloadCapacity {
            vehicle.payloadBay.maxPayloadMass <= 300.0 [kg]
        }
        
        require constraint orbitAltitudeRange {
            vehicle.payloadBay.currentPayload.targetOrbitAltitude >= 300000.0 [m] and
            vehicle.payloadBay.currentPayload.targetOrbitAltitude <= 1200000.0 [m]
        }
    }
    
    requirement def <'REQ-002'> LaunchReliabilityRequirement {
        doc /* 
            The launch vehicle shall achieve successful orbital insertion and payload
            deployment with a reliability of at least 95% over the operational lifetime.
        */
    }
    
    requirement def <'REQ-003'> FlightSafetyRequirement {
        doc /* 
            The vehicle avionics system shall continuously monitor vehicle health and
            execute autonomous abort procedures if critical parameters exceed safe limits.
        */
        
        require constraint healthMonitoring {
            electron.avionics.healthMonitoring.healthStatus != VehicleStatus::critical
        }
    }
    
    requirement def <'REQ-004'> StageSeparationRequirement {
        doc /* 
            Stage separation shall occur at an altitude above 80 km and velocity
            exceeding 2000 m/s to ensure safe clearance and second stage ignition.
        */
    }
    
    requirement <'SYS-001'> electronSystemRequirement {
        doc /* 
            Primary Function: The Electron launch vehicle system shall autonomously execute
            a complete launch sequence from liftoff through orbital insertion, delivering
            small satellite payloads to their designated low Earth orbits with high precision
            and reliability through coordinated operation of multi-stage propulsion, guidance,
            and deployment systems.
        */
        
        satisfy PrimaryMissionRequirement by electron;
        satisfy LaunchReliabilityRequirement by electron.mission;
        satisfy FlightSafetyRequirement by electron.avionics;
        satisfy StageSeparationRequirement by electron.mission;
    }
}
