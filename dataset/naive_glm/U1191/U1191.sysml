package SpacecraftModel {
    import ISQ::*;
    import ScalarValues::*;

    item def Command {
        attribute commandString : String;
    }
    item def ScienceData {
        attribute payload : String;
    }
    item def Telemetry {
        attribute healthStatus : String;
        attribute sciencePayload : ScienceData;
    }
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    item def Thrust {
        attribute magnitude : ForceValue;
    }
    item def AttitudeData {
        attribute isStable : Boolean;
        attribute orientation : AngleValue;
    }
    item def NavigationData {
        attribute position : LengthValue;
        attribute velocity : VelocityValue;
    }

    port def PowerOutPort { out power : ElectricalPower; }
    port def PowerInPort { in power : ElectricalPower; }
    port def CmdOutPort { out command : Command; }
    port def CmdInPort { in command : Command; }
    port def TelemOutPort { out telemetry : Telemetry; }
    port def TelemInPort { in telemetry : Telemetry; }
    port def SciDataOutPort { out data : ScienceData; }
    port def SciDataInPort { in data : ScienceData; }
    port def NavDataOutPort { out data : NavigationData; }
    port def NavDataInPort { in data : NavigationData; }
    port def AttDataOutPort { out data : AttitudeData; }
    port def AttDataInPort { in data : AttitudeData; }
    port def ThrustPort { out thrust : Thrust; }

    part def PowerSubsystem {
        attribute mass : MassValue = 500 [kg];
        port powerOut : PowerOutPort;
        part solarArray {
            attribute generationRate : PowerValue = 1500 [W];
        }
        part battery {
            attribute capacity : EnergyValue = 5000 [Wh];
        }
    }

    part def CommunicationSubsystem {
        attribute mass : MassValue = 100 [kg];
        port powerIn : PowerInPort;
        port cmdIn : CmdInPort;
        port cmdOut : CmdOutPort;
        port telemIn : TelemInPort;
        port telemOut : TelemOutPort;
        part highGainAntenna;
    }

    part def CommandDataHandling {
        attribute mass : MassValue = 50 [kg];
        port powerIn : PowerInPort;
        port cmdIn : CmdInPort;
        port telemOut : TelemOutPort;
        port sciDataIn : SciDataInPort;
        port navDataIn : NavDataInPort;
        port attDataIn : AttDataInPort;
        port cmdOut : CmdOutPort;
    }

    part def AttitudeControlSubsystem {
        attribute mass : MassValue = 200 [kg];
        port powerIn : PowerInPort;
        port cmdIn : CmdInPort;
        port attDataOut : AttDataOutPort;
        port navDataIn : NavDataInPort;
    }

    part def PropulsionSubsystem {
        attribute mass : MassValue = 800 [kg];
        attribute fuelMass : MassValue = 500 [kg];
        port powerIn : PowerInPort;
        port cmdIn : CmdInPort;
        port thrustOut : ThrustPort;
    }

    part def ScienceInstrumentSubsystem {
        attribute mass : MassValue = 300 [kg];
        port powerIn : PowerInPort;
        port cmdIn : CmdInPort;
        port sciDataOut : SciDataOutPort;
    }

    part def NavigationSubsystem {
        attribute mass : MassValue = 150 [kg];
        port powerIn : PowerInPort;
        port navDataOut : NavDataOutPort;
    }

    part def Spacecraft {
        attribute totalMassLimit : MassValue = 5000 [kg];
        attribute totalMass : MassValue = (cdh.mass + power.mass + comm.mass + attCtrl.mass + prop.mass + sciInst.mass + nav.mass);
        
        part cdh : CommandDataHandling;
        part power : PowerSubsystem;
        part comm : CommunicationSubsystem;
        part attCtrl : AttitudeControlSubsystem;
        part prop : PropulsionSubsystem;
        part sciInst : ScienceInstrumentSubsystem;
        part nav : NavigationSubsystem;

        connect power.powerOut to cdh.powerIn;
        connect power.powerOut to comm.powerIn;
        connect power.powerOut to attCtrl.powerIn;
        connect power.powerOut to prop.powerIn;
        connect power.powerOut to sciInst.powerIn;
        connect power.powerOut to nav.powerIn;

        connect comm.cmdOut to cdh.cmdIn;
        connect cdh.telemOut to comm.telemIn;
        
        connect sciInst.sciDataOut to cdh.sciDataIn;
        connect nav.navDataOut to cdh.navDataIn;
        connect nav.navDataOut to attCtrl.navDataIn;
        connect attCtrl.attDataOut to cdh.attDataIn;

        connect cdh.cmdOut to attCtrl.cmdIn;
        connect cdh.cmdOut to prop.cmdIn;
        connect cdh.cmdOut to sciInst.cmdIn;

        state def SpacecraftMission {
            state GeneratingPower;
            state ListeningForCommands;
            state DeterminingAttitude;
            state Navigating;
            state AcquiringScienceData;
            state TransmittingData;
            
            transition from GeneratingPower to ListeningForCommands;
            transition from ListeningForCommands to DeterminingAttitude;
            transition from DeterminingAttitude to Navigating;
            transition from Navigating to AcquiringScienceData;
            transition from AcquiringScienceData to TransmittingData;
            transition from TransmittingData to GeneratingPower;
        }
        
        part missionController {
            exhibit SpacecraftMission;
        }
    }

    requirement def MassLimitRequirement {
        attribute limit : MassValue = 5000 [kg];
        subject spacecraft : Spacecraft;
        require spacecraft.totalMass <= limit;
    }

    requirement def PowerSupplyRequirement {
        subject powerSubsystem : PowerSubsystem;
        require powerSubsystem.battery.capacity > 0 [Wh];
    }

    requirement def AttitudeStabilityRequirement {
        subject attCtrlSubsystem : AttitudeControlSubsystem;
        require attCtrlSubsystem.attDataOut.data.isStable == true;
    }
}
