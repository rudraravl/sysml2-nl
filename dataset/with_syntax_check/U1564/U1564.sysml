package 'STS133_SpaceShuttleDiscoveryFinalMission' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MissionPhase;
    attribute def FlightDay;
    
    item def CargoModule {
        attribute mass : MassValue;
        attribute volume : VolumeValue;
    }
    
    item def PermanentMultipurposeModule :> CargoModule {
        attribute :>> mass = 9400.0[kg];
        attribute pressurizedVolume : VolumeValue = 21.0[m^3];
        attribute storageCapacity : MassValue = 8600.0[kg];
    }
    
    item def ExpressLogisticsCarrier4 :> CargoModule {
        attribute :>> mass = 5900.0[kg];
        attribute spareComponentsCount : Integer = 6;
    }
    
    item def Robonaut2 :> CargoModule {
        attribute :>> mass = 150.0[kg];
        attribute manipulatorCount : Integer = 2;
        attribute operationalModes : Integer = 4;
    }
    
    port def DockingPort {
        attribute isDocked : Boolean;
        attribute alignmentTolerance : LengthValue;
        attribute sealPressure : PressureValue;
    }
    
    port def CargoTransferPort {
        attribute transferRate : Real;
        attribute currentLoad : MassValue;
    }
    
    port def PropulsionPort {
        attribute thrust : ForceValue;
        attribute specificImpulse : Real;
        attribute fuelRemaining : MassValue;
    }
    
    port def CommunicationPort {
        attribute dataRate : Real;
        attribute signalStrength : Real;
    }
    
    part def OrbiterVehicle {
        attribute vehicleMass : MassValue = 110000.0[kg];
        attribute maxPayloadMass : MassValue = 24400.0[kg];
        attribute crewCapacity : Integer = 7;
        attribute orbiterDesignation : String;
        
        port dockingPort : DockingPort;
        port cargoPort : CargoTransferPort;
        port omsPropulsion : PropulsionPort;
        port rcsPropulsion : PropulsionPort;
        port commPort : CommunicationPort;
        
        part payloadBay {
            attribute bayLength : LengthValue = 18.3[m];
            attribute bayDiameter : LengthValue = 4.6[m];
        }
        
        part orbitalManeuveringSystem {
            attribute thrustPerEngine : ForceValue = 26700.0[N];
            attribute engineCount : Integer = 2;
        }
        
        part reactionControlSystem {
            attribute thrusterCount : Integer = 44;
            attribute thrustPerThruster : ForceValue = 3870.0[N];
        }
    }
    
    part def InternationalSpaceStation {
        attribute orbitAltitude : LengthValue = 350.0[km];
        attribute orbitInclination : Real = 51.6;
        attribute orbitalVelocity : SpeedValue = 7.66[km/s];
        attribute stationMass : MassValue = 419700.0[kg];
        
        port dockingPort : DockingPort;
        port cargoReceivingPort : CargoTransferPort;
        port commPort : CommunicationPort;
        
        part pressurizedModules {
            attribute totalVolume : VolumeValue = 916.0[m^3];
        }
    }
    
    connection def DockingConnection {
        end orbiterPort : DockingPort;
        end stationPort : DockingPort;
    }
    
    connection def CargoConnection {
        end sourcePort : CargoTransferPort;
        end destinationPort : CargoTransferPort;
    }
    
    action def LaunchAndAscent {
        in launchWindow : TimeValue;
        in targetInclination : Real;
        out orbitalAltitude : LengthValue;
        out orbitalVelocity : SpeedValue;
    }
    
    action def RendezvousSequence {
        in targetAltitude : LengthValue;
        in targetVelocity : SpeedValue;
        in relativeRange : LengthValue;
        out approachRate : SpeedValue;
        out rangeToTarget : LengthValue;
    }
    
    action def DockingSequence {
        in approachVelocity : SpeedValue;
        in alignmentError : LengthValue;
        out dockingSuccess : Boolean;
        out contactTime : TimeValue;
    }
    
    action def CargoTransferOperations {
        in cargoManifest : CargoModule[*];
        in transferDuration : TimeValue;
        out transferComplete : Boolean;
        out itemsTransferred : Integer;
    }
    
    action def ExtravehicularActivity {
        in evaObjectives : String[*];
        in evaDuration : TimeValue;
        out objectivesCompleted : Integer;
        out evaSuccess : Boolean;
    }
    
    action def UndockingSequence {
        in separationVelocity : SpeedValue;
        out undockingSuccess : Boolean;
        out separationDistance : LengthValue;
    }
    
    action def DeorbitAndEntry {
        in deorbitBurnDuration : TimeValue;
        in landingSite : String;
        out entryInterfaceTime : TimeValue;
        out landingSuccess : Boolean;
    }
    
    state def MissionPhaseStateMachine {
        attribute currentPhase : String;
        attribute flightDay : Integer;
        attribute isDocked : Boolean;
        attribute evaCount : Integer;
        
        entry; then prelaunch;
        
        state prelaunch;
        then launchPhase;
        
        state launchPhase;
        then onOrbitPhase;
        
        state onOrbitPhase {
            entry; then rendezvousApproach;
            
            state rendezvousApproach;
            then finalApproach;
            
            state finalApproach;
            then docking;
            
            state docking;
            then dockedOperations;
            
            state dockedOperations {
                entry; then hatchOpening;
                
                state hatchOpening;
                then cargoTransfer;
                
                state cargoTransfer;
                then evaPreparation;
                
                state evaPreparation;
                then evaOperations;
                
                state evaOperations;
                then jointOperations;
                
                state jointOperations;
                then hatchClosure;
                
                state hatchClosure;
            }
            then undocking;
            
            state undocking;
            then separationManeuvers;
            
            state separationManeuvers;
        }
        then deorbitPhase;
        
        state deorbitPhase;
        then landingPhase;
        
        state landingPhase;
        then missionComplete;
        
        state missionComplete;
    }
    
    action def ExecuteSTS133Mission {
        in missionDuration : TimeValue;
        in crewSize : Integer;
        in payloadManifest : CargoModule[*];
        in targetOrbitAltitude : LengthValue;
        out missionSuccess : Boolean;
        out totalFlightTime : TimeValue;
        
        first start;
        
        then action prelaunchPreparation {
            in vehicleCheckout : Boolean;
            out readyForLaunch : Boolean;
        }
        
        then action performLaunch : LaunchAndAscent {
            in launchWindow = 600.0[s];
            in targetInclination = 51.6;
            out orbitalAltitude : LengthValue;
            out orbitalVelocity : SpeedValue;
        }
        
        then action performRendezvous : RendezvousSequence {
            in targetAltitude = targetOrbitAltitude;
            in targetVelocity = 7.66[km/s];
            in relativeRange = 50000.0[m];
            out approachRate : SpeedValue;
            out rangeToTarget : LengthValue;
        }
        
        then action performDocking : DockingSequence {
            in approachVelocity = 0.1[m/s];
            in alignmentError = 0.05[m];
            out dockingSuccess : Boolean;
            out contactTime : TimeValue;
        }
        
        then action transferCargo : CargoTransferOperations {
            in cargoManifest = payloadManifest;
            in transferDuration = 259200.0[s];
            out transferComplete : Boolean;
            out itemsTransferred : Integer;
        }
        
        then action conductEVAs : ExtravehicularActivity {
            in evaObjectives = ("Install PMM", "Replace MMOD Shield");
            in evaDuration = 25200.0[s];
            out objectivesCompleted : Integer;
            out evaSuccess : Boolean;
        }
        
        then action performUndocking : UndockingSequence {
            in separationVelocity = 0.3[m/s];
            out undockingSuccess : Boolean;
            out separationDistance : LengthValue;
        }
        
        then action performDeorbit : DeorbitAndEntry {
            in deorbitBurnDuration = 180.0[s];
            in landingSite = "Kennedy Space Center";
            out entryInterfaceTime : TimeValue;
            out landingSuccess : Boolean;
        }
        
        then assign missionSuccess := performDeorbit.landingSuccess;
        then assign totalFlightTime := missionDuration;
        
        then done;
    }
    
    part def STS133MissionSystem {
        attribute missionDesignation : String;
        attribute launchDate : String;
        attribute missionDuration : TimeValue;
        attribute crewSize : Integer;
        
        part orbiter : OrbiterVehicle;
        part iss : InternationalSpaceStation;
        part pmm : PermanentMultipurposeModule;
        part elc4 : ExpressLogisticsCarrier4;
        part robonaut : Robonaut2;
    }
    
    part sts133Mission : STS133MissionSystem {
        attribute :>> missionDesignation = "STS-133";
        attribute :>> launchDate = "February 24, 2011";
        attribute :>> missionDuration = 1105920.0[s];
        attribute :>> crewSize = 6;
        
        part orbiter : OrbiterVehicle {
            attribute :>> orbiterDesignation = "Discovery OV-103";
        }
        
        part iss : InternationalSpaceStation;
        
        part pmm : PermanentMultipurposeModule;
        part elc4 : ExpressLogisticsCarrier4;
        part robonaut : Robonaut2;
        
        connection dockingLink : DockingConnection
            connect orbiter.dockingPort to iss.dockingPort;
        
        connection cargoLink : CargoConnection
            connect orbiter.cargoPort to iss.cargoReceivingPort;
        
        perform action missionExecution : ExecuteSTS133Mission {
            in missionDuration = sts133Mission::missionDuration;
            in crewSize = sts133Mission::crewSize;
            in payloadManifest = (pmm, elc4, robonaut);
            in targetOrbitAltitude = 350.0[km];
            out missionSuccess : Boolean;
            out totalFlightTime : TimeValue;
        }
        
        exhibit state missionPhases : MissionPhaseStateMachine;
    }
    
    requirement <'STS-133-REQ-001'> primaryMissionObjective {
        doc /*
            The STS-133 mission system shall deliver the Permanent Multipurpose Module (PMM),
            Express Logistics Carrier 4 (ELC-4), and Robonaut 2 to the International Space
            Station to enhance long-duration habitation capabilities, provide critical spare
            components, and demonstrate advanced robotic assistance technology.
        */
        
        subject mission : STS133MissionSystem;
        
        require constraint payloadDeliveryCapability {
            mission.pmm.mass + mission.elc4.mass + mission.robonaut.mass 
                <= mission.orbiter.maxPayloadMass
        }
        
        require constraint successfulCargoTransfer {
            mission.missionExecution.transferCargo.transferComplete == true
        }
    }
    
    requirement <'STS-133-REQ-002'> dockingRequirement {
        doc /*
            The orbiter shall successfully dock with the ISS at the Pressurized Mating
            Adapter 2 (PMA-2) on the Harmony module with alignment tolerance within
            specified limits.
        */
        
        require constraint dockingSuccess {
            sts133Mission.missionExecution.performDocking.dockingSuccess == true
        }
        
        require constraint approachVelocity {
            sts133Mission.missionExecution.performDocking.approachVelocity <= 0.15[m/s]
        }
    }
    
    requirement <'STS-133-REQ-003'> missionDurationRequirement {
        doc /*
            The mission shall be completed within the planned duration of approximately
            13 days to ensure crew safety and resource availability.
        */
        
        require constraint durationLimit {
            sts133Mission.missionDuration <= 1209600.0[s]
        }
    }
    
    requirement <'STS-133-REQ-004'> evaRequirement {
        doc /*
            The mission shall conduct two planned extravehicular activities (EVAs) to
            install the PMM and perform station maintenance tasks.
        */
        
        require constraint evaCompletion {
            sts133Mission.missionExecution.conductEVAs.evaSuccess == true
        }
        
        require constraint evaObjectivesAchieved {
            sts133Mission.missionExecution.conductEVAs.objectivesCompleted >= 2
        }
    }
    
    requirement <'STS-133-REQ-005'> safeReturnRequirement {
        doc /*
            The orbiter shall safely deorbit and land at the designated landing site
            with all crew members and return cargo intact.
        */
        
        require constraint landingSuccess {
            sts133Mission.missionExecution.performDeorbit.landingSuccess == true
        }
    }
}
