package SPHERES_High_Level_Model {
    import ScalarValues::*;
    import SI::*;

    item def CommandPacket {
        attribute sequenceId: Integer;
        attribute timeTag_s: Real;
        attribute mode: String;
    }

    item def TelemetryPacket {
        attribute vehicleId: String;
        attribute missionElapsedTime_s: Real;
        attribute healthSummary: String;
    }

    item def PropellantGas {
        attribute gasName: String = "CO2";
        attribute storagePressure_kPa: Real;
        attribute temperature_K: Real;
    }

    item def NavigationEstimate {
        attribute positionX_m: Real;
        attribute positionY_m: Real;
        attribute positionZ_m: Real;
        attribute roll_rad: Real;
        attribute pitch_rad: Real;
        attribute yaw_rad: Real;
        attribute velocityX_mps: Real;
        attribute velocityY_mps: Real;
        attribute velocityZ_mps: Real;
    }

    item def ForceCommand {
        attribute forceX_N: Real;
        attribute forceY_N: Real;
        attribute forceZ_N: Real;
        attribute torqueX_Nm: Real;
        attribute torqueY_Nm: Real;
        attribute torqueZ_Nm: Real;
    }

    item def ElectricalEnergy {
        attribute voltage_V: Real;
        attribute current_A: Real;
        attribute power_W: Real;
    }

    port def CommandPort {
        in item command: CommandPacket;
    }

    port def TelemetryPort {
        out item telemetry: TelemetryPacket;
    }

    port def NavigationPort {
        out item estimate: NavigationEstimate;
    }

    port def ControlPort {
        in item forceCommand: ForceCommand;
    }

    port def GasSupplyPort {
        out item propellant: PropellantGas;
    }

    port def ElectricalPowerPort {
        out item energy: ElectricalEnergy;
    }

    port def PoweredLoadPort {
        in item energy: ElectricalEnergy;
    }

    port def ThrusterNozzlePort {
        in item propellant: PropellantGas;
        out item impulseCommand: ForceCommand;
    }

    part def BatteryModule {
        attribute nominalVoltage_V: Real = 12.0;
        attribute capacity_Wh: Real = 72.0;
        attribute minimumOperatingVoltage_V: Real = 9.5;
        port powerOut: ElectricalPowerPort;
    }

    part def FlightComputer {
        attribute processorClock_MHz: Real = 200.0;
        attribute controlCycle_Hz: Real = 50.0;
        attribute commandTimeout_s: Real = 2.0;
        port commandIn: CommandPort;
        port telemetryOut: TelemetryPort;
        port navIn: NavigationPort;
        port controlOut: ControlPort;
        port powerIn: PoweredLoadPort;
    }

    part def NavigationSubsystem {
        attribute updateRate_Hz: Real = 25.0;
        attribute positionAccuracy_m: Real = 0.01;
        attribute attitudeAccuracy_rad: Real = 0.005;
        port navOut: NavigationPort;
        port powerIn: PoweredLoadPort;
    }

    part def ColdGasTank {
        attribute propellantMass_kg: Real = 0.170;
        attribute maximumPressure_kPa: Real = 6200.0;
        attribute minimumUsablePressure_kPa: Real = 700.0;
        port gasOut: GasSupplyPort;
    }

    part def Thruster {
        attribute thrust_N: Real = 0.12;
        attribute minimumPulse_s: Real = 0.020;
        attribute specificImpulse_s: Real = 65.0;
        port gasIn: ThrusterNozzlePort;
        port commandIn: ControlPort;
        port powerIn: PoweredLoadPort;
    }

    part def CommunicationsSubsystem {
        attribute radioFrequency_MHz: Real = 868.0;
        attribute linkRange_m: Real = 20.0;
        attribute telemetryRate_Hz: Real = 10.0;
        port commandFromGround: CommandPort;
        port telemetryToGround: TelemetryPort;
        port powerIn: PoweredLoadPort;
    }

    part def SPHERES_FreeFlyer {
        attribute vehicleName: String = "SPHERES";
        attribute expandedName: String = "Synchronized Position Hold Engage Reorient Experimental Satellite";
        attribute dryMass_kg: Real = 4.30;
        attribute maximumDiameter_m: Real = 0.22;
        attribute primaryFunction: String = "Provide a small, self-contained, free-flying spacecraft testbed that autonomously holds position, reorients, and maneuvers in a controlled microgravity volume for guidance, navigation, and control experiments.";

        port externalCommand: CommandPort;
        port externalTelemetry: TelemetryPort;

        part battery: BatteryModule;
        part computer: FlightComputer;
        part navigation: NavigationSubsystem;
        part propellantTank: ColdGasTank;
        part communications: CommunicationsSubsystem;

        part thrusterXP: Thruster;
        part thrusterXN: Thruster;
        part thrusterYP: Thruster;
        part thrusterYN: Thruster;
        part thrusterZP: Thruster;
        part thrusterZN: Thruster;
        part thrusterRollP: Thruster;
        part thrusterRollN: Thruster;
        part thrusterPitchP: Thruster;
        part thrusterPitchN: Thruster;
        part thrusterYawP: Thruster;
        part thrusterYawN: Thruster;

        connect externalCommand to communications.commandFromGround;
        connect communications.telemetryToGround to externalTelemetry;
        connect communications.commandFromGround to computer.commandIn;
        connect computer.telemetryOut to communications.telemetryToGround;
        connect navigation.navOut to computer.navIn;

        connect battery.powerOut to computer.powerIn;
        connect battery.powerOut to navigation.powerIn;
        connect battery.powerOut to communications.powerIn;
        connect battery.powerOut to thrusterXP.powerIn;
        connect battery.powerOut to thrusterXN.powerIn;
        connect battery.powerOut to thrusterYP.powerIn;
        connect battery.powerOut to thrusterYN.powerIn;
        connect battery.powerOut to thrusterZP.powerIn;
        connect battery.powerOut to thrusterZN.powerIn;

        connect propellantTank.gasOut to thrusterXP.gasIn;
        connect propellantTank.gasOut to thrusterXN.gasIn;
        connect propellantTank.gasOut to thrusterYP.gasIn;
        connect propellantTank.gasOut to thrusterYN.gasIn;
        connect propellantTank.gasOut to thrusterZP.gasIn;
        connect propellantTank.gasOut to thrusterZN.gasIn;
        connect propellantTank.gasOut to thrusterRollP.gasIn;
        connect propellantTank.gasOut to thrusterRollN.gasIn;
        connect propellantTank.gasOut to thrusterPitchP.gasIn;
        connect propellantTank.gasOut to thrusterPitchN.gasIn;
        connect propellantTank.gasOut to thrusterYawP.gasIn;
        connect propellantTank.gasOut to thrusterYawN.gasIn;

        connect computer.controlOut to thrusterXP.commandIn;
        connect computer.controlOut to thrusterXN.commandIn;
        connect computer.controlOut to thrusterYP.commandIn;
        connect computer.controlOut to thrusterYN.commandIn;
        connect computer.controlOut to thrusterZP.commandIn;
        connect computer.controlOut to thrusterZN.commandIn;
        connect computer.controlOut to thrusterRollP.commandIn;
        connect computer.controlOut to thrusterRollN.commandIn;
        connect computer.controlOut to thrusterPitchP.commandIn;
        connect computer.controlOut to thrusterPitchN.commandIn;
        connect computer.controlOut to thrusterYawP.commandIn;
        connect computer.controlOut to thrusterYawN.commandIn;
    }

    action def ReceiveExperimentCommand {
        in item command: CommandPacket;
        out item acceptedCommand: CommandPacket;
    }

    action def EstimatePoseAndRate {
        out item estimate: NavigationEstimate;
    }

    action def ComputeControlEffort {
        in item desiredState: NavigationEstimate;
        in item measuredState: NavigationEstimate;
        out item effort: ForceCommand;
    }

    action def PulseColdGasThrusters {
        in item effort: ForceCommand;
        in item propellant: PropellantGas;
    }

    action def ReportTelemetry {
        in item estimate: NavigationEstimate;
        out item telemetry: TelemetryPacket;
    }

    action def ExecutePrimaryFreeFlightExperiment {
        first start;
        then receiveCommand: ReceiveExperimentCommand;
        then estimateState: EstimatePoseAndRate;
        then computeEffort: ComputeControlEffort;
        then pulseThrusters: PulseColdGasThrusters;
        then reportStatus: ReportTelemetry;
        then done;
    }

    state def SPHERES_OperationalStateMachine {
        entry action InitializeVehicle;
        state Off;
        state Standby;
        state ReceiveCommand;
        state FreeFlightControl;
        state HoldPosition;
        state Reorient;
        state Translate;
        state SafeMode;

        transition first Off;
        transition Off then Standby accept PowerApplied;
        transition Standby then ReceiveCommand accept ValidGroundCommand;
        transition ReceiveCommand then HoldPosition accept HoldCommand;
        transition ReceiveCommand then Reorient accept ReorientCommand;
        transition ReceiveCommand then Translate accept TranslateCommand;
        transition HoldPosition then FreeFlightControl accept ControlCycleTick;
        transition Reorient then FreeFlightControl accept ControlCycleTick;
        transition Translate then FreeFlightControl accept ControlCycleTick;
        transition FreeFlightControl then ReceiveCommand accept ManeuverComplete;
        transition FreeFlightControl then SafeMode accept LowPressureOrLowBattery;
        transition SafeMode then Standby accept FaultCleared;
    }

    requirement def PrimaryFunctionRequirement {
        subject flyer: SPHERES_FreeFlyer;
        attribute requiredFunction: String = "The SPHERES-based system shall autonomously maintain and change its six-degree-of-freedom position and attitude in a microgravity test volume while exchanging commands and telemetry with an external operator.";
        require constraint {
            flyer.dryMass_kg <= 5.0 and
            flyer.maximumDiameter_m <= 0.30
        }
    }

    requirement def NavigationRequirement {
        subject navigation: NavigationSubsystem;
        attribute requiredAccuracy: String = "The navigation subsystem shall estimate vehicle position within 0.02 m and attitude within 0.01 rad during free-flight operations.";
        require constraint {
            navigation.positionAccuracy_m <= 0.02 and
            navigation.attitudeAccuracy_rad <= 0.01
        }
    }

    requirement def ControlRequirement {
        subject computer: FlightComputer;
        attribute requiredControlRate: String = "The flight computer shall close the guidance, navigation, and control loop at no less than 20 Hz.";
        require constraint {
            computer.controlCycle_Hz >= 20.0
        }
    }

    requirement def PropulsionRequirement {
        subject tank: ColdGasTank;
        attribute requiredPropulsion: String = "The propulsion subsystem shall provide stored cold gas to distributed thrusters for translation and rotation commands.";
        require constraint {
            tank.propellantMass_kg >= 0.100 and
            tank.maximumPressure_kPa >= 5000.0
        }
    }

    part spheresSystem: SPHERES_FreeFlyer;

    satisfy PrimaryFunctionRequirement by spheresSystem;
    satisfy NavigationRequirement by spheresSystem.navigation;
    satisfy ControlRequirement by spheresSystem.computer;
    satisfy PropulsionRequirement by spheresSystem.propellantTank;
}