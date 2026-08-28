package 'STS-123 Mission Model' {
    private import ScalarValues::*;
    
    unit def kg;
    unit def N;
    unit def km;
    unit def s;
    unit def K;
    
    attribute def Mass :> Real;
    attribute def Force :> Real;
    attribute def Length :> Real;
    attribute def Time :> Real;
    attribute def Temperature :> Real;
    
    item def Propellant;
    item def LiquidHydrogen :> Propellant;
    item def LiquidOxygen :> Propellant;
    item def ElectricalPower;
    item def Command;
    item def Telemetry;
    item def Data;
    
    port def LH2Port {
        out item propellant : LiquidHydrogen;
    }
    port def LO2Port {
        out item propellant : LiquidOxygen;
    }
    port def ThrustPort {
        out attribute thrust : Force;
    }
    port def ControlPort {
        out item command : Command;
        in item telemetry : Telemetry;
    }
    port def PowerPort {
        out item power : ElectricalPower;
    }
    port def DataPort {
        out item data : Data;
    }
    port def MechanicalInterfacePort;
    port def DockingPort;
    
    interface def DockingInterface {
        end orbiterPort : DockingPort;
        end stationPort : DockingPort;
    }
    
    action def MainEngineBurn {
        in lh2 : LiquidHydrogen;
        in lox : LiquidOxygen;
        out thrust : Force;
    }
    action def SRBBurn {
        out thrust : Force;
    }
    action def OMSBurn {
        out thrust : Force;
    }
    action def RCSThrust {
        out thrust : Force;
    }
    
    part def ExternalTank {
        port lh2Out : LH2Port;
        port loxOut : LO2Port;
        attribute emptyMass : Mass = 26500 [kg];
        attribute lh2Mass : Mass = 100000 [kg];
        attribute loxMass : Mass = 600000 [kg];
        attribute temperature : Temperature = 20 [K];
    }
    
    part def SolidRocketBooster {
        port thrustOut : ThrustPort;
        attribute thrust : Force = 12500000 [N];
        attribute burnTime : Time = 124 [s];
        perform burn : SRBBurn {
            out thrust = thrustOut.thrust;
        }
    }
    
    part def SSME {
        port lh2In : ~LH2Port;
        port loxIn : ~LO2Port;
        port thrustOut : ThrustPort;
        attribute thrust : Force = 1668000 [N];
        perform burn : MainEngineBurn {
            in lh2 = lh2In.propellant;
            in lox = loxIn.propellant;
            out thrust = thrustOut.thrust;
        }
    }
    
    part def OrbitalManeuveringSystem {
        port thrustOut : ThrustPort;
        port controlIn : ~ControlPort;
        attribute thrust : Force = 53000 [N];
        perform burn : OMSBurn {
            out thrust = thrustOut.thrust;
        }
    }
    
    part def ReactionControlSystem {
        port thrustOut : ThrustPort;
        port controlIn : ~ControlPort;
        attribute thrust : Force = 4000 [N];
        attribute thrusterCount : Integer = 44;
        perform rcsThrust : RCSThrust {
            out thrust = thrustOut.thrust;
        }
    }
    
    part def GuidanceNavigationControl {
        port controlOut : ControlPort;
        attribute targetAltitude : Length = 340 [km];
    }
    
    part def KiboModule {
        port mechanicalInterface : MechanicalInterfacePort;
        port powerIn : ~PowerPort;
        port dataIn : ~DataPort;
        attribute mass : Mass = 4200 [kg];
        attribute isInstalled : Boolean = false;
    }
    
    part def DextreManipulator {
        port mechanicalInterface : MechanicalInterfacePort;
        port powerIn : ~PowerPort;
        port dataIn : ~DataPort;
        attribute mass : Mass = 1500 [kg];
        attribute armCount : Integer = 2;
        attribute isInstalled : Boolean = false;
    }
    
    part def PayloadBay {
        port mechanicalInterface : MechanicalInterfacePort;
        port powerIn : ~PowerPort;
        port dataIn : ~DataPort;
        port powerOut : PowerPort;
        port dataOut : DataPort;
        part kibo : KiboModule;
        part dextre : DextreManipulator;
        flow of bayPower : ElectricalPower from powerIn.power to powerOut.power;
        flow of bayData : Data from dataIn.data to dataOut.data;
        connect mechanicalInterface to kibo.mechanicalInterface;
        connect mechanicalInterface to dextre.mechanicalInterface;
        connect powerOut to kibo.powerIn;
        connect powerOut to dextre.powerIn;
        connect dataOut to kibo.dataIn;
        connect dataOut to dextre.dataIn;
    }
    
    part def EndeavourOrbiter {
        port lh2In : ~LH2Port;
        port loxIn : ~LO2Port;
        port leftThrustLoad : ~ThrustPort;
        port rightThrustLoad : ~ThrustPort;
        port dockingPort : DockingPort;
        port payloadMechanical : MechanicalInterfacePort;
        port payloadPower : PowerPort;
        port payloadData : DataPort;
        attribute crewCount : Integer = 7;
        part mainEngines : SSME[3];
        part oms : OrbitalManeuveringSystem;
        part rcs : ReactionControlSystem;
        part gnc : GuidanceNavigationControl;
        part payloadBay : PayloadBay;
        flow of lh2Distribution : LiquidHydrogen from lh2In.propellant to mainEngines.lh2In.propellant;
        flow of loxDistribution : LiquidOxygen from loxIn.propellant to mainEngines.loxIn.propellant;
        flow of omsCommand : Command from gnc.controlOut.command to oms.controlIn.command;
        flow of rcsCommand : Command from gnc.controlOut.command to rcs.controlIn.command;
        flow of omsTelemetry : Telemetry from oms.controlIn.telemetry to gnc.controlOut.telemetry;
        flow of rcsTelemetry : Telemetry from rcs.controlIn.telemetry to gnc.controlOut.telemetry;
        connect payloadMechanical to payloadBay.mechanicalInterface;
        connect payloadPower to payloadBay.powerIn;
        connect payloadData to payloadBay.dataIn;
    }
    
    part def SpaceShuttleStack {
        part orbiter : EndeavourOrbiter;
        part externalTank : ExternalTank;
        part leftSRB : SolidRocketBooster;
        part rightSRB : SolidRocketBooster;
        flow of lh2Supply : LiquidHydrogen from externalTank.lh2Out.propellant to orbiter.lh2In.propellant;
        flow of loxSupply : LiquidOxygen from externalTank.loxOut.propellant to orbiter.loxIn.propellant;
        connect leftSRB.thrustOut to orbiter.leftThrustLoad;
        connect rightSRB.thrustOut to orbiter.rightThrustLoad;
    }
    
    part def InternationalSpaceStation {
        port dockingPort : DockingPort;
        attribute altitude : Length = 350 [km];
    }
    
    state machine def MissionPhases {
        state PreLaunch;
        state Launch;
        state Ascent;
        state OrbitInsertion;
        state Rendezvous;
        state Docked;
        state PayloadOperations;
        state Undocking;
        state Deorbit;
        state Reentry;
        state Landing;
        state Done;
        transition from PreLaunch to Launch;
        transition from Launch to Ascent;
        transition from Ascent to OrbitInsertion;
        transition from OrbitInsertion to Rendezvous;
        transition from Rendezvous to Docked;
        transition from Docked to PayloadOperations;
        transition from PayloadOperations to Undocking;
        transition from Undocking to Deorbit;
        transition from Deorbit to Reentry;
        transition from Reentry to Landing;
        transition from Landing to Done;
    }
    
    part def MissionContext {
        attribute missionName : String = "STS-123";
        attribute targetAltitude : Length = 340 [km];
        attribute crewCount : Integer = 7;
        attribute crewReturned : Boolean = false;
        part stack : SpaceShuttleStack;
        part iss : InternationalSpaceStation;
        state missionPhases : MissionPhases;
    }
    
    requirement def MissionObjective {
        doc /* The STS-123 mission shall deliver and install the Kibo Japanese Experiment Logistics Module and the Dextre manipulator to the ISS, and return all seven crew members safely to Earth. */
    }
    
    requirement def OrbitAltitudeRequirement {
        doc /* The shuttle shall achieve a circular orbit between 330 and 350 km altitude. */
        attribute minAltitude : Length = 330 [km];
        attribute maxAltitude : Length = 350 [km];
    }
    
    requirement def CrewSafeReturnRequirement {
        doc /* The shuttle shall return all seven crew members safely to Earth. */
        attribute requiredCrewCount : Integer = 7;
    }
    
    requirement def PayloadDeliveryRequirement {
        doc /* The shuttle shall successfully transfer and install the Kibo module and Dextre manipulator at the ISS. */
    }
    
    part sts123Mission : MissionContext {
        interface : DockingInterface connect
            orbiterPort ::> stack.orbiter.dockingPort to
            stationPort ::> iss.dockingPort;
        satisfy MissionObjective;
        satisfy OrbitAltitudeRequirement;
        satisfy CrewSafeReturnRequirement;
        satisfy PayloadDeliveryRequirement;
    }
}
