package CuriosityRover {

    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Units ----
    unit W;
    unit Wh;
    unit degC;
    unit kg;
    unit m;
    unit m_per_s;
    unit deg;
    unit kbps;
    unit V;
    unit percent;
    unit Nm;

    // ---- Value Types ----
    value def PowerValue :> Real { unit W; }
    value def EnergyValue :> Real { unit Wh; }
    value def TempValue :> Real { unit degC; }
    value def MassValue :> Real { unit kg; }
    value def DistanceValue :> Real { unit m; }
    value def VelocityValue :> Real { unit m_per_s; }
    value def AngleValue :> Real { unit deg; }
    value def DataRateValue :> Real { unit kbps; }
    value def VoltageValue :> Real { unit V; }
    value def SOCValue :> Real { unit percent; min 0; max 100; }
    value def TorqueValue :> Real { unit Nm; }

    // ---- Items ----
    item def Command {
        attribute targetX : DistanceValue;
        attribute targetY : DistanceValue;
        attribute action : String;
    }
    item def Telemetry {
        attribute healthStatus : String;
        attribute timestamp : String;
    }
    item def ScienceData {
        attribute payload : String;
        attribute source : String;
    }
    item def ImageData {
        attribute resolution : String;
        attribute panoramic : Boolean;
    }
    item def RockSample {
        attribute mass : MassValue;
        attribute origin : String;
    }
    item def GasSample {
        attribute composition : String;
        attribute temperature : TempValue;
    }
    item def ChemicalAnalysis {
        attribute elements : String;
        attribute organicDetected : Boolean;
    }
    item def PowerFlow {
        attribute power : PowerValue;
    }
    item def ThermalFlow {
        attribute heatRate : PowerValue;
    }
    item def NavigationSolution {
        attribute positionX : DistanceValue;
        attribute positionY : DistanceValue;
        attribute heading : AngleValue;
        attribute velocity : VelocityValue;
    }
    item def HazardMap {
        attribute obstacleDistances : DistanceValue[0..*];
        attribute clearPath : Boolean;
    }

    // ---- Ports ----
    port def PowerPort {
        out power : PowerFlow;
        in voltage : VoltageValue;
    }
    port def DataPort {
        out data : ScienceData;
        in command : Command;
    }
    port def ThermalPort {
        out heat : ThermalFlow;
    }
    port def CommandPort {
        in command : Command;
        out ack : Telemetry;
    }
    port def SamplePort {
        out sample : RockSample;
    }
    port def GasPort {
        out gas : GasSample;
    }
    port def DrivePort {
        in torque : TorqueValue;
    }
    port def NavPort {
        out solution : NavigationSolution;
        out hazardMap : HazardMap;
    }

    // ---- Mobility Subsystem ----
    part def Wheel {
        attribute diameter : DistanceValue = 0.5;
        attribute steerable : Boolean = true;
        port driveIn : DrivePort;
        attribute appliedTorque : TorqueValue;
        perform action drive {
            in torque : TorqueValue = driveIn.torque;
        }
    }

    part def RockerBogieSuspension {
        attribute wheelCount : Integer = 6;
        part wheels : Wheel[6];
        attribute groundContact : Boolean = true;
        perform action distributeLoad {
            out torques : TorqueValue[6];
        }
    }

    part def MobilitySubsystem {
        attribute maxSpeed : VelocityValue = 0.04;
        attribute climbCapability : DistanceValue = 0.65;
        part suspension : RockerBogieSuspension;
        port navIn : NavPort;
        port powerIn : PowerPort;
        perform action traverse {
            in solution : NavigationSolution = navIn.solution;
            in hazardMap : HazardMap = navIn.hazardMap;
            out torques : TorqueValue[6];
        }
    }

    // ---- Navigation Subsystem ----
    part def HazardCamera {
        attribute fieldOfView : AngleValue = 120;
        attribute stereo : Boolean = true;
        out image : ImageData;
    }

    part def IMU {
        attribute accelRange : Real = 2.0;
        attribute gyroRange : AngleValue = 500;
        out orientation : AngleValue;
        out acceleration : Real;
    }

    part def NavigationSubsystem {
        part hazardCamerasFront : HazardCamera[2];
        part hazardCamerasRear : HazardCamera[2];
        part imu : IMU;
        port navOut : NavPort;
        port powerIn : PowerPort;
        perform action computeSolution {
            in images : ImageData[0..*];
            in orientation : AngleValue;
            out solution : NavigationSolution;
            out hazardMap : HazardMap;
        }
    }

    // ---- Power Subsystem ----
    part def MMRTG {
        attribute nominalPower : PowerValue = 110;
        attribute fuelMass : MassValue = 4.8;
        port powerOut : PowerPort;
        perform action generatePower {
            out power : PowerFlow;
        }
    }

    part def BatteryPack {
        attribute capacity : EnergyValue = 42;
        attribute stateOfCharge : SOCValue = 100;
        port powerIn : PowerPort;
        port powerOut : PowerPort;
        perform action discharge {
            out power : PowerFlow;
        }
        perform action charge {
            in power : PowerFlow;
        }
    }

    part def PowerSubsystem {
        part mmrtg : MMRTG;
        part batteryPacks : BatteryPack[2];
        attribute totalAvailable : PowerValue;
        port powerBus : PowerPort;
        perform action managePower {
            in demand : PowerValue;
            out supply : PowerFlow;
        }
    }

    // ---- Thermal Control Subsystem ----
    part def Heater {
        attribute powerRating : PowerValue = 30;
        port powerIn : PowerPort;
        out heat : ThermalFlow;
        perform action heatUp {
            out heat : ThermalFlow;
        }
    }

    part def Radiator {
        attribute dissipationRate : PowerValue = 200;
        out heat : ThermalFlow;
        perform action dissipate {
            in internalHeat : ThermalFlow;
            out rejectedHeat : ThermalFlow;
        }
    }

    part def ThermalControlSubsystem {
        attribute minOpTemp : TempValue = -40;
        attribute maxOpTemp : TempValue = 50;
        part heaters : Heater[4];
        part radiators : Radiator[2];
        port powerIn : PowerPort;
        perform action regulateTemperature {
            in ambientTemp : TempValue;
            out internalTemp : TempValue;
        }
    }

    // ---- Science Instruments ----
    part def Mastcam {
        attribute resolution : String = "1600x1200";
        attribute colorCapable : Boolean = true;
        port powerIn : PowerPort;
        port dataOut : DataPort;
        perform action captureImage {
            out image : ImageData;
        }
    }

    part def ChemCam {
        attribute laserRange : DistanceValue = 7;
        attribute laserEnergy : EnergyValue = 15;
        port powerIn : PowerPort;
        port dataOut : DataPort;
        perform action zapRock {
            in target : String;
            out analysis : ChemicalAnalysis;
        }
    }

    part def Drill {
        attribute maxDepth : DistanceValue = 0.05;
        port powerIn : PowerPort;
        port sampleOut : SamplePort;
        perform action acquireSample {
            out sample : RockSample;
        }
    }

    part def SAM {
        attribute maxHeatingTemp : TempValue = 1100;
        port powerIn : PowerPort;
        port sampleIn : SamplePort;
        port gasOut : GasPort;
        port dataOut : DataPort;
        perform action heatSample {
            in sample : RockSample;
            out gas : GasSample;
        }
        perform action analyzeGas {
            in gas : GasSample;
            out analysis : ChemicalAnalysis;
        }
    }

    part def ScienceSuite {
        part mastcam : Mastcam;
        part chemcam : ChemCam;
        part drill : Drill;
        part sam : SAM;
        port powerIn : PowerPort;
        port dataOut : DataPort;
    }

    // ---- Avionics / Computer ----
    part def OnboardComputer {
        attribute clockSpeed : Real = 200;
        attribute memory : Real = 256;
        port commandIn : CommandPort;
        port dataOut : DataPort;
        port powerIn : PowerPort;
        perform action executeCommand {
            in command : Command;
            out ack : Telemetry;
        }
        perform action processData {
            in rawData : ScienceData;
            out processedData : ScienceData;
        }
    }

    // ---- Communications ----
    part def HighGainAntenna {
        attribute band : String = "X-band";
        attribute dataRate : DataRateValue = 32;
        port dataIn : DataPort;
        perform action transmitDirectToEarth {
            in data : ScienceData;
        }
    }

    part def UHFAntenna {
        attribute band : String = "UHF";
        attribute dataRate : DataRateValue = 256;
        port dataIn : DataPort;
        perform action relayViaOrbiter {
            in data : ScienceData;
        }
    }

    part def CommunicationSubsystem {
        part highGain : HighGainAntenna;
        part uhf : UHFAntenna;
        port powerIn : PowerPort;
        port dataIn : DataPort;
        perform action selectLink {
            in directAvailable : Boolean;
            out selected : String;
        }
    }

    // ---- Operational State Machine ----
    state def RoverOperationalMode {
        attribute batterySOC : SOCValue;
        entry;
        then Idle;

        state Idle {
            entry;
            perform action monitorHealth;
        }

        state Navigating {
            entry;
            perform action driveToTarget;
        }

        state Sampling {
            entry;
            perform action drillSample;
        }

        state Analyzing {
            entry;
            perform action runAnalysis;
        }

        state Communicating {
            entry;
            perform action transmitData;
        }

        state Charging {
            entry;
            perform action conservePower;
        }

        transition from Idle to Navigating
            when (commandReceived and command.action == "drive")
            accept Command;

        transition from Navigating to Sampling
            when (targetReached)
            accept NavigationSolution;

        transition from Navigating to Idle
            when (hazardDetected or targetUnreachable);

        transition from Sampling to Analyzing
            when (sampleAcquired)
            accept RockSample;

        transition from Analyzing to Communicating
            when (analysisComplete)
            accept ChemicalAnalysis;

        transition from Communicating to Idle
            when (transmissionComplete);

        transition from any to Charging
            when (batterySOC < 30);

        transition from Charging to Idle
            when (batterySOC >= 80);
    }

    // ---- Requirements ----
    requirement def MobilityRequirement {
        subject rover : MobilitySubsystem;
        attribute requiredWheels : Integer = 6;
        require rover.wheelCount == requiredWheels;
        require rover.climbCapability >= 0.5;
    }

    requirement def PowerRequirement {
        subject power : PowerSubsystem;
        require power.mmrtg.nominalPower >= 100;
        require power.batteryPacks->size == 2;
    }

    requirement def ThermalRequirement {
        subject thermal : ThermalControlSubsystem;
        require thermal.minOpTemp <= -40;
        require thermal.maxOpTemp >= 50;
    }

    requirement def ScienceRequirement {
        subject science : ScienceSuite;
        require science.chemcam.laserRange >= 7;
        require science.sam.maxHeatingTemp >= 1000;
    }

    requirement def CommunicationRequirement {
        subject comm : CommunicationSubsystem;
        require comm.highGain.band == "X-band";
        require comm.uhf.band == "UHF";
    }

    requirement def OperationalRequirement {
        subject mode : RoverOperationalMode;
        require mode.Idle.exists;
        require mode.Navigating.exists;
        require mode.Sampling.exists;
        require mode.Analyzing.exists;
        require mode.Communicating.exists;
        require mode.Charging.exists;
    }

    // ---- Top-level Rover Assembly ----
    part def CuriosityRover {
        attribute totalMass : MassValue = 899;
        attribute missionDuration : Real = 687;
        attribute landingSite : String = "Gale Crater";

        part mobility : MobilitySubsystem;
        part navigation : NavigationSubsystem;
        part power : PowerSubsystem;
        part thermal : ThermalControlSubsystem;
        part science : ScienceSuite;
        part computer : OnboardComputer;
        part comm : CommunicationSubsystem;

        // Power distribution
        connection powerToMobility connect power.powerBus to mobility.powerIn;
        connection powerToNav connect power.powerBus to navigation.powerIn;
        connection powerToThermal connect power.powerBus to thermal.powerIn;
        connection powerToScience connect power.powerBus to science.powerIn;
        connection powerToComputer connect power.powerBus to computer.powerIn;
        connection powerToComm connect power.powerBus to comm.powerIn;

        // Navigation to mobility
        connection navToMobility connect navigation.navOut to mobility.navIn;

        // Science data flow
        connection scienceToComputer connect science.dataOut to computer.dataOut;
        connection computerToComm connect computer.dataOut to comm.dataIn;

        // Command flow
        connection commandToComputer connect computer.commandIn to computer.commandIn;

        // Sample flow from drill to SAM
        connection drillToSAM connect science.drill.sampleOut to science.sam.sampleIn;

        // Gas flow within SAM handled internally

        // Operational behavior
        perform operationalMode : RoverOperationalMode;

        // Requirement satisfaction
        satisfy MobilityRequirement by mobility;
        satisfy PowerRequirement by power;
        satisfy ThermalRequirement by thermal;
        satisfy ScienceRequirement by science;
        satisfy CommunicationRequirement by comm;
        satisfy OperationalRequirement by operationalMode;
    }

    // ---- Mission Sequence Action ----
    action def TypicalMissionSequence {
        in rover : CuriosityRover;
        out result : ScienceData;

        action receiveCommand {
            out command : Command;
        }
        action driveToTarget {
            in command : Command;
            out solution : NavigationSolution;
        }
        action performScience {
            in solution : NavigationSolution;
            out sample : RockSample;
            out analysis : ChemicalAnalysis;
        }
        action transmitData {
            in analysis : ChemicalAnalysis;
            out data : ScienceData;
        }

        flow from receiveCommand.command to driveToTarget.command;
        flow from driveToTarget.solution to performScience.solution;
        flow from performScience.analysis to transmitData.analysis;
        flow from transmitData.data to result;
    }
}
