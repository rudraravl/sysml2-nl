package STS123 {

    package Units {
        value def Length :> ISQ::Length { unit m; }
        value def Mass :> ISQ::Mass { unit kg; }
        value def Force :> ISQ::Force { unit N; }
        value def Thrust :> ISQ::Force { unit kN; }
        value def Volume :> ISQ::Volume { unit m3; }
        value def Time :> ISQ::Time { unit s; }
        value def Velocity :> ISQ::Velocity { unit m_per_s; }
        value def Altitude :> ISQ::Length { unit km; }
        value def Power :> ISQ::Power { unit kW; }
        value def Temperature :> ISQ::Temperature { unit K; }
        value def Pressure :> ISQ::Pressure { unit kPa; }
        value def DataRate :> Real { unit Mb_per_s; }
        value def Angle :> Real { unit deg; }
    }

    package ItemDefs {
        item def CryoPropellant {
            attribute kind : String;
            attribute mass : Mass;
            attribute temp : Temperature;
        }
        item def LiquidHydrogen :> CryoPropellant {
            redefines kind = "LH2";
            redefines temp = 20.0 [K];
        }
        item def LiquidOxygen :> CryoPropellant {
            redefines kind = "LOX";
            redefines temp = 90.0 [K];
        }
        item def SolidPropellant {
            attribute mass : Mass;
            attribute burnTime : Time;
        }
        item def Command {
            attribute id : String;
        }
        item def Telemetry {
            attribute timestamp : Time;
            attribute value : Real;
        }
        item def ElectricalPower {
            attribute voltage : Real;
            attribute current : Real;
        }
        item def DataSignal {
            attribute rate : DataRate;
        }
        item def CrewMember {
            attribute name : String;
            attribute role : String;
        }
    }

    package Ports {
        port def MechanicalMount {
            attribute loadCapacity : Force;
        }
        port def PowerPort {
            attribute maxPower : Power;
            out power : ElectricalPower;
        }
        port def DataPort {
            attribute rate : DataRate;
            in cmd : Command;
            out tlm : Telemetry;
        }
        port def PropellantFeed {
            attribute flowRate : Real;
            out propellant : CryoPropellant;
        }
        port def ThrustPort {
            attribute thrust : Thrust;
            out thrustVector : Force;
        }
        port def DockingPort {
            attribute status : String;
        }
        port def RCSJetPort {
            attribute thrust : Thrust;
        }
    }

    package Components {

        part def ExternalTank {
            attribute dryMass : Mass = 26535 [kg];
            attribute length : Length = 47.0 [m];
            port lh2Feed : PropellantFeed;
            port loxFeed : PropellantFeed;
            part lh2Tank {
                attribute capacity : Volume = 1497.0 [m3];
                item storedPropellant : LiquidHydrogen;
            }
            part loxTank {
                attribute capacity : Volume = 553.0 [m3];
                item storedPropellant : LiquidOxygen;
            }
        }

        part def SolidRocketBooster {
            attribute dryMass : Mass = 91230 [kg];
            attribute burnTime : Time = 124.0 [s];
            attribute thrust : Thrust = 12500.0 [kN];
            port thrustOut : ThrustPort;
            part motor {
                item propellant : SolidPropellant {
                    redefines mass = 501000 [kg];
                    redefines burnTime = 124.0 [s];
                }
            }
        }

        part def MainEngine {
            attribute thrust : Thrust = 1759.0 [kN];
            port lh2In : PropellantFeed;
            port loxIn : PropellantFeed;
            port thrustOut : ThrustPort;
        }

        part def OMS {
            attribute thrust : Thrust = 26.7 [kN];
            attribute fuelMass : Mass = 10000 [kg];
            port thrustOut : ThrustPort;
        }

        part def RCSThruster {
            attribute thrust : Thrust = 3.87 [kN];
            port jetOut : RCSJetPort;
        }

        part def RCS {
            part fwdThrusters : RCSThruster[8];
            part aftThrusters : RCSThruster[12];
        }

        part def GNC {
            port dataIn : DataPort;
            port dataOut : DataPort;
            attribute navAccuracy : Angle = 0.01 [deg];
            part imu;
            part starTracker;
            part computer;
        }

        part def PayloadBay {
            attribute volume : Volume = 300.0 [m3];
            port mechMount : MechanicalMount;
            port powerOut : PowerPort;
            port dataOut : DataPort;
        }

        part def RoboticArm {
            attribute length : Length = 15.0 [m];
            attribute dof : Integer = 6;
            port baseMount : MechanicalMount;
            port powerIn : PowerPort;
            port dataIn : DataPort;
        }

        part def KiboModule {
            attribute dryMass : Mass = 8300 [kg];
            attribute pressurizedVolume : Volume = 14.9 [m3];
            attribute internalPressure : Pressure = 101.3 [kPa];
            port mount : MechanicalMount;
            port powerIn : PowerPort;
            port dataIn : DataPort;
        }

        part def Dextre {
            attribute dryMass : Mass = 1560 [kg];
            attribute armReach : Length = 3.5 [m];
            part leftArm : RoboticArm;
            part rightArm : RoboticArm;
            port baseMount : MechanicalMount;
            port powerIn : PowerPort;
            port dataIn : DataPort;
        }

        part def Orbiter {
            attribute name : String = "Endeavour";
            attribute dryMass : Mass = 78000 [kg];
            attribute crewSize : Integer = 7;
            port dockingPort : DockingPort;
            part mainEngines : MainEngine[3];
            part oms : OMS;
            part rcs : RCS;
            part gnc : GNC;
            part payloadBay : PayloadBay;
            part shuttleArm : RoboticArm;
            item crew : CrewMember[7];
        }

        part def LaunchStack {
            part orbiter : Orbiter;
            part externalTank : ExternalTank;
            part leftSRB : SolidRocketBooster;
            part rightSRB : SolidRocketBooster;
        }

        part def ISS {
            port dockingPort : DockingPort;
            port powerOut : PowerPort;
            port dataOut : DataPort;
        }

        part def Runway {
            attribute length : Length = 4500 [m];
        }
    }

    package Mission {

        part def STS123Mission {
            attribute missionName : String = "STS-123";
            attribute targetOrbitMin : Altitude = 330.0 [km];
            attribute targetOrbitMax : Altitude = 350.0 [km];
            attribute crewSize : Integer = 7;
            part launchStack : Components::LaunchStack;
            part iss : Components::ISS;
            part runway : Components::Runway;
            part kibo : Components::KiboModule;
            part dextre : Components::Dextre;
            perform missionPhases : MissionStateMachine;
        }

        state def MissionStateMachine {

            state PreLaunch {
                entry :> action initSystems {
                    // Initialize all subsystems and verify readiness
                }
            }

            state Ascent {
                entry :> action igniteEngines;
                do :> action monitorAscent;
                exit :> action jettisonSRBs;
            }

            state OrbitInsertion {
                entry :> action mainEngineCutoff;
                do :> action achieveOrbit;
                exit :> action etSeparation;
            }

            state Rendezvous {
                do :> action performRendezvousManeuvers;
            }

            state Docked {
                entry :> action dockWithISS;
                do :> action transferPayload;
                exit :> action undockFromISS;
            }

            state Deorbit {
                entry :> action performDeorbitBurn;
                do :> action configureForReentry;
            }

            state Reentry {
                do :> action atmosphericReentry;
            }

            state Landing {
                entry :> action approachRunway;
                do :> action touchdown;
                exit :> action safing;
            }

            transition from PreLaunch to Ascent
                when launchStack.orbiter.gnc.dataIn.cmd.id == "LAUNCH";

            transition from Ascent to OrbitInsertion
                when launchStack.orbiter.gnc.dataIn.cmd.id == "MECO";

            transition from OrbitInsertion to Rendezvous
                when launchStack.orbiter.gnc.dataIn.cmd.id == "RENDEZVOUS";

            transition from Rendezvous to Docked
                when launchStack.orbiter.dockingPort.status == "DOCKED";

            transition from Docked to Deorbit
                when launchStack.orbiter.gnc.dataIn.cmd.id == "DEORBIT";

            transition from Deorbit to Reentry
                when launchStack.orbiter.gnc.dataIn.cmd.id == "ENTRY";

            transition from Reentry to Landing
                when launchStack.orbiter.gnc.dataIn.cmd.id == "LAND";
        }

        action def igniteEngines {
            // Ignite SRBs and main engines simultaneously
        }
        action def monitorAscent {
            // Monitor thrust, trajectory, and vehicle health
        }
        action def jettisonSRBs {
            // Separate SRBs at burnout
        }
        action def mainEngineCutoff {
            // Shut down main engines at target velocity
        }
        action def achieveOrbit {
            // Use OMS for orbit circularization
        }
        action def etSeparation {
            // Jettison external tank
        }
        action def performRendezvousManeuvers {
            // Execute phasing and rendezvous burns
        }
        action def dockWithISS {
            // Dock orbiter to ISS
        }
        action def transferPayload {
            // Use robotic arm to install Kibo and Dextre
        }
        action def undockFromISS {
            // Separate from ISS
        }
        action def performDeorbitBurn {
            // OMS burn to reduce velocity for reentry
        }
        action def configureForReentry {
            // Configure vehicle for atmospheric entry
        }
        action def atmosphericReentry {
            // Guide vehicle through atmosphere
        }
        action def approachRunway {
            // Terminal area energy management and approach
        }
        action def touchdown {
            // Land on runway
        }
        action def safing {
            // Power down and safe vehicle systems
        }
        action def initSystems {
            // Initialize all subsystems
        }
    }

    package Requirements {

        requirement def LaunchStackRequirement {
            subject launchStack : Components::LaunchStack;
            requirement {
                launchStack.orbiter.name == "Endeavour"
            }
            requirement {
                launchStack.externalTank.lh2Tank.capacity > 1400.0 [m3]
            }
            requirement {
                launchStack.externalTank.loxTank.capacity > 500.0 [m3]
            }
            requirement {
                launchStack.leftSRB.thrust > 12000.0 [kN]
            }
            requirement {
                launchStack.rightSRB.thrust > 12000.0 [kN]
            }
        }

        requirement def OrbiterRequirement {
            subject orbiter : Components::Orbiter;
            requirement {
                orbiter.crewSize == 7
            }
            requirement {
                orbiter.mainEngines.size == 3
            }
            requirement {
                orbiter.oms.thrust > 20.0 [kN]
            }
            requirement {
                orbiter.rcs.fwdThrusters.size >= 4
            }
            requirement {
                orbiter.rcs.aftThrusters.size >= 8
            }
        }

        requirement def PayloadRequirement {
            subject payloadBay : Components::PayloadBay;
            subject kibo : Components::KiboModule;
            subject dextre : Components::Dextre;
            requirement {
                payloadBay.volume > 250.0 [m3]
            }
            requirement {
                kibo.pressurizedVolume > 10.0 [m3]
            }
            requirement {
                kibo.internalPressure == 101.3 [kPa]
            }
            requirement {
                dextre.leftArm.dof >= 6
            }
            requirement {
                dextre.rightArm.dof >= 6
            }
            requirement {
                dextre.armReach >= 3.0 [m]
            }
        }

        requirement def MissionRequirement {
            subject mission : Mission::STS123Mission;
            requirement {
                mission.targetOrbitMin >= 330.0 [km]
            }
            requirement {
                mission.targetOrbitMax <= 350.0 [km]
            }
            requirement {
                mission.crewSize == 7
            }
            requirement {
                mission.missionPhases.Landing.isFinal
            }
        }

        requirement def SafetyRequirement {
            subject orbiter : Components::Orbiter;
            requirement {
                orbiter.gnc.navAccuracy <= 0.1 [deg]
            }
            requirement {
                orbiter.dockingPort.status in {"DOCKED", "UNDOCKED"}
            }
        }

        requirement def STS123SystemRequirement {
            subject mission : Mission::STS123Mission;
            satisfy LaunchStackRequirement by mission.launchStack;
            satisfy OrbiterRequirement by mission.launchStack.orbiter;
            satisfy PayloadRequirement by mission.launchStack.orbiter.payloadBay,
                mission.kibo, mission.dextre;
            satisfy MissionRequirement by mission;
            satisfy SafetyRequirement by mission.launchStack.orbiter;
        }
    }

    package Connections {

        connection def ETToOrbiterPropellant {
            end etLH2 : PropellantFeed;
            end orbiterLH2 : PropellantFeed;
        }
        connection def SRBToOrbiterThrust {
            end srbThrust : ThrustPort;
            end orbiterAttach : ThrustPort;
        }
        connection def PayloadBayToKibo {
            end bayMount : MechanicalMount;
            end kiboMount : MechanicalMount;
            end bayPower : PowerPort;
            end kiboPower : PowerPort;
            end bayData : DataPort;
            end kiboData : DataPort;
        }
        connection def PayloadBayToDextre {
            end bayMount : MechanicalMount;
            end dextreMount : MechanicalMount;
            end bayPower : PowerPort;
            end dextrePower : PowerPort;
            end bayData : DataPort;
            end dextreData : DataPort;
        }
        connection def OrbiterToISSDocking {
            end orbiterDock : DockingPort;
            end issDock : DockingPort;
        }
        connection def GNCToOMS {
            end gncOut : DataPort;
            end omsIn : DataPort;
        }
        connection def GNCToRCS {
            end gncOut : DataPort;
            end rcsIn : DataPort;
        }
    }

    package SystemAssembly {

        part sts123System : Mission::STS123Mission {
            part launchStack : Components::LaunchStack {
                part orbiter : Components::Orbiter {
                    part mainEngines : Components::MainEngine[3] {
                        // Each engine receives propellant from ET
                    }
                    part oms : Components::OMS;
                    part rcs : Components::RCS;
                    part gnc : Components::GNC;
                    part payloadBay : Components::PayloadBay;
                    part shuttleArm : Components::RoboticArm;
                }
                part externalTank : Components::ExternalTank;
                part leftSRB : Components::SolidRocketBooster;
                part rightSRB : Components::SolidRocketBooster;
            }
            part iss : Components::ISS;
            part runway : Components::Runway;
            part kibo : Components::KiboModule;
            part dextre : Components::Dextre;

            connection etLH2ToOrbiter : Connections::ETToOrbiterPropellant
                connect launchStack.externalTank.lh2Feed to launchStack.orbiter.mainEngines[1].lh2In;
            connection etLOXToOrbiter : Connections::ETToOrbiterPropellant
                connect launchStack.externalTank.loxFeed to launchStack.orbiter.mainEngines[1].loxIn;
            connection leftSRBThrust : Connections::SRBToOrbiterThrust
                connect launchStack.leftSRB.thrustOut to launchStack.orbiter.mainEngines[1].thrustOut;
            connection rightSRBThrust : Connections::SRBToOrbiterThrust
                connect launchStack.rightSRB.thrustOut to launchStack.orbiter.mainEngines[1].thrustOut;
            connection payloadBayToKibo : Connections::PayloadBayToKibo
                connect launchStack.orbiter.payloadBay.mechMount to kibo.mount;
            connection payloadBayToDextre : Connections::PayloadBayToDextre
                connect launchStack.orbiter.payloadBay.mechMount to dextre.baseMount;
            connection orbiterToISS : Connections::OrbiterToISSDocking
                connect launchStack.orbiter.dockingPort to iss.dockingPort;
            connection gncToOMS : Connections::GNCToOMS
                connect launchStack.orbiter.gnc.dataOut to launchStack.orbiter.oms.thrustOut;
            connection gncToRCS : Connections::GNCToRCS
                connect launchStack.orbiter.gnc.dataOut to launchStack.orbiter.rcs.fwdThrusters[1].jetOut;
        }
    }
}
