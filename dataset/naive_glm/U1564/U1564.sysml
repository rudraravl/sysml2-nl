package STS_133_Mission {

    // Units
    unit kg;
    unit m3;
    unit km;
    unit km_per_s;
    unit sec;
    unit deg;
    unit N;
    unit count;

    // Value Types
    value type Mass :> Real { unit kg; }
    value type Volume :> Real { unit m3; }
    value type OrbitalDistance :> Real { unit km; }
    value type OrbitalVelocity :> Real { unit km_per_s; }
    value type Duration :> Real { unit sec; }
    value type AngularPosition :> Real { unit deg; }
    value type ThrustForce :> Real { unit N; }
    value type CrewSize :> Integer { unit count; }
    value type ThrusterNum :> Integer { unit count; }

    // Enumerations
    enum DockingState { Undocked, Docked }
    enum SystemStatus { Nominal, OffNominal, Standby, Active }
    enum MissionPhaseType { PreLaunch, Ascent, Rendezvous, Docking, Operations, Undocking, FlyAround, Deorbit, Entry, Landing }

    // Item definitions
    item def Cargo {
        attribute mass : Mass;
        attribute volume : Volume;
    }
    item def PMM :> Cargo {
        attribute internalVolume : Volume;
    }
    item def ELC4 :> Cargo {
        attribute sparePartsCount : Integer;
    }
    item def Robonaut2 :> Cargo {
        attribute isHumanoid : Boolean = true;
    }

    // Port definitions
    port def DockingPort {
        attribute state : DockingState;
    }
    port def ThrusterPort {
        out thrust : ThrustForce;
    }

    // Requirements
    requirement def MissionObjective {
        doc { The STS-133 mission shall deliver critical hardware and supplies to the ISS. }
    }
    requirement def CrewRequirement {
        doc { The Discovery orbiter shall be configured for a crew of six. }
        attribute requiredCrewSize : CrewSize = 6;
    }
    requirement def EVARequirement {
        doc { The mission shall execute two planned spacewalks for installation and maintenance. }
        attribute requiredEVACount : Integer = 2;
    }

    // Part definitions
    part def Spacecraft {
        attribute status : SystemStatus;
        port dockingPort : DockingPort;
    }

    part def Orbiter :> Spacecraft {
        attribute crewSize : CrewSize;
        part payloadBay {
            attribute capacity : Volume;
            item cargo : Cargo[*];
        }
        part oms {
            attribute maxThrust : ThrustForce;
        }
        part rcs {
            attribute thrusterCount : ThrusterNum;
            port thrusters : ThrusterPort[*];
        }
    }

    part def ISS :> Spacecraft {
        attribute totalVolume : Volume;
        part exterior {
            attribute mountingPoints : Integer;
        }
    }

    // Actions
    action def LaunchAscentAction {
        out altitude : OrbitalDistance;
        out velocity : OrbitalVelocity;
    }
    action def RendezvousAction {
        in targetPosition : OrbitalDistance;
        out relativeVelocity : OrbitalVelocity;
    }
    action def DockingAction {
        in orbiterPort : DockingPort;
        in issPort : DockingPort;
    }
    action def CargoTransferAction {
        in cargoItem : Cargo;
    }
    action def EVAAction {
        in duration : Duration;
        in taskDescription : String;
    }
    action def UndockingAction {
        out relativeDistance : OrbitalDistance;
    }
    action def FlyAroundAction {
        out inspectionAngle : AngularPosition;
    }
    action def DeorbitEntryLandingAction {
        in deorbitBurnDuration : Duration;
    }

    // Main System
    part STS_133_MissionSystem {
        requirement reqObjective : MissionObjective;
        requirement reqCrew : CrewRequirement;
        requirement reqEVA : EVARequirement;

        part discovery : Orbiter {
            attribute crewSize = 6;
            part payloadBay {
                attribute capacity = 315;
                item pmm : PMM {
                    attribute mass = 12000;
                    attribute volume = 70;
                    attribute internalVolume = 70;
                }
                item elc4 : ELC4 {
                    attribute mass = 4000;
                    attribute volume = 50;
                    attribute sparePartsCount = 12;
                }
                item robonaut2 : Robonaut2 {
                    attribute mass = 300;
                    attribute volume = 1;
                }
            }
            part oms {
                attribute maxThrust = 53000;
            }
            part rcs {
                attribute thrusterCount = 44;
            }
            port dockingPort : DockingPort;

            state orbiterOps {
                state PreLaunch;
                state Ascent;
                state Rendezvous;
                state Docking;
                state Operations;
                state Undocking;
                state FlyAround;
                state Deorbit;
                state Entry;
                state Landing;

                transition from PreLaunch to Ascent;
                transition from Ascent to Rendezvous;
                transition from Rendezvous to Docking;
                transition from Docking to Operations;
                transition from Operations to Undocking;
                transition from Undocking to FlyAround;
                transition from FlyAround to Deorbit;
                transition from Deorbit to Entry;
                transition from Entry to Landing;
            }
        }

        part iss : ISS {
            attribute totalVolume = 900;
            part exterior {
                attribute mountingPoints = 10;
            }
            port dockingPort : DockingPort;
        }

        connect discovery.dockingPort to iss.dockingPort;

        action missionSequence {
            action launchAscent : LaunchAscentAction;
            action rendezvous : RendezvousAction;
            action docking : DockingAction;
            action operations {
                action transferPMM : CargoTransferAction;
                action transferELC4 : CargoTransferAction;
                action transferRobonaut2 : CargoTransferAction;
                action eva1 : EVAAction;
                action eva2 : EVAAction;
            }
            action undocking : UndockingAction;
            action flyAround : FlyAroundAction;
            action deorbitEntryLanding : DeorbitEntryLandingAction;

            launchAscent -> rendezvous;
            rendezvous -> docking;
            docking -> operations;
            operations -> undocking;
            undocking -> flyAround;
            flyAround -> deorbitEntryLanding;
        }

        state missionState {
            state PreLaunch;
            state LaunchAscent {
                perform missionSequence.launchAscent;
            }
            state Rendezvous {
                perform missionSequence.rendezvous;
            }
            state Docking {
                perform missionSequence.docking;
            }
            state Operations {
                perform missionSequence.operations;
            }
            state Undocking {
                perform missionSequence.undocking;
            }
            state FlyAround {
                perform missionSequence.flyAround;
            }
            state DeorbitEntryLanding {
                perform missionSequence.deorbitEntryLanding;
            }

            transition from PreLaunch to LaunchAscent;
            transition from LaunchAscent to Rendezvous;
            transition from Rendezvous to Docking;
            transition from Docking to Operations;
            transition from Operations to Undocking;
            transition from Undocking to FlyAround;
            transition from FlyAround to DeorbitEntryLanding;
        }
    }
}
