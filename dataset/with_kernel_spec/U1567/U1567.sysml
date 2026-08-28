package SpaceExplorationSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def PowerValue :> Real {
        doc /* Electrical power in watts (W). */
    }
    attribute def EnergyValue :> Real {
        doc /* Stored energy in joules (J). */
    }
    attribute def DataRateValue :> Real {
        doc /* Data rate in bits per second (bps). */
    }
    attribute def FuelMassValue :> Real {
        doc /* Propellant mass in kilograms (kg). */
    }
    attribute def ThrustValue :> Real {
        doc /* Thrust force in newtons (N). */
    }
    attribute def SignalStrengthValue :> Real {
        doc /* Signal strength in dBm. */
    }
    attribute def BatteryChargeValue :> Real {
        doc /* Battery charge as percentage (0-100). */
    }
    attribute def VelocityValue :> Real {
        doc /* Velocity in meters per second (m/s). */
    }

    attribute def LaunchComplete;
    attribute def TargetApproached;
    attribute def ApproachComplete;
    attribute def MissionComplete;
    attribute def LowPowerDetected;
    attribute def RecoveryCommand;
    attribute def CriticalFault;

    item def Command {
        attribute commandId : String;
        attribute commandType : String;
        attribute parameters : String;
    }
    item def Telemetry {
        attribute subsystemId : String;
        attribute healthStatus : String;
        attribute powerLevel : PowerValue;
        attribute temperature : TemperatureValue;
        attribute timestamp : String;
    }
    item def ScienceData {
        attribute dataId : String;
        attribute instrumentId : String;
        attribute compressed : Boolean;
        attribute dataSize : Integer;
    }
    item def NavigationSolution {
        attribute position : LengthValue;
        attribute velocity : VelocityValue;
        attribute timestamp : String;
    }
    item def ThrustCommand {
        attribute thrustMagnitude : ThrustValue;
        attribute duration : TimeValue;
        attribute direction : String;
    }
    item def PowerDistribution {
        attribute totalPower : PowerValue;
        attribute batteryCharge : BatteryChargeValue;
    }
    item def ThermalReading {
        attribute componentId : String;
        attribute temperature : TemperatureValue;
    }

    port def CommandPort {
        in command : Command;
    }
    port def TelemetryPort {
        out telemetry : Telemetry;
    }
    port def ScienceDataPort {
        out scienceData : ScienceData;
    }
    port def NavigationPort {
        out navSolution : NavigationSolution;
    }
    port def ThrustCommandPort {
        in thrustCmd : ThrustCommand;
    }
    port def ThrustCommandOutPort {
        out thrustCmd : ThrustCommand;
    }
    port def PowerOutPort {
        out power : PowerDistribution;
    }
    port def PowerInPort {
        in power : PowerDistribution;
    }
    port def ThermalPort {
        out thermalReading : ThermalReading;
    }
    port def GroundCommandPort {
        out command : Command;
    }
    port def GroundDataPort {
        in telemetry : Telemetry;
        in scienceData : ScienceData;
    }

    action def ActivateSystems;
    action def PerformLaunch;
    action def SeparateStages;
    action def StartCruise;
    action def NavigateToTarget;
    action def MonitorHealth;
    action def ManageThermal;
    action def PrepareInstruments;
    action def RefineNavigation;
    action def BeginScience;
    action def CollectData;
    action def ProcessData;
    action def TransmitData;
    action def ConservePower;
    action def MaintainContact;
    action def GeneratePower;
    action def StorePower;
    action def DistributePower;
    action def FireThrusters;
    action def ManageFuel;
    action def DeterminePosition;
    action def CalculateTrajectory;
    action def CommandCourseCorrection;
    action def CollectScienceData;
    action def ProcessScienceData;
    action def TransmitTelemetry;
    action def TransmitScienceData;
    action def ReceiveCommands;
    action def RegulateTemperature;
    action def SendCommands;
    action def ReceiveTelemetry;
    action def ReceiveScienceData;

    part def PowerSystem {
        attribute maxSolarOutput : PowerValue = 300.0;
        attribute maxBatteryCapacity : EnergyValue = 5000.0;
        attribute currentBatteryCharge : BatteryChargeValue = 100.0;
        port powerOut : PowerOutPort;
        perform action generatePower : GeneratePower;
        perform action storePower : StorePower;
        perform action distributePower : DistributePower;
        exhibit state powerStates {
            entry; then charging;
            state charging;
            accept when currentBatteryCharge < 20.0
                then discharging;
            state discharging;
            accept when currentBatteryCharge > 80.0
                then charging;
        }
    }

    part def PropulsionSystem {
        attribute fuelRemaining : FuelMassValue = 500.0;
        attribute maxThrust : ThrustValue = 500.0;
        port powerIn : PowerInPort;
        port thrustCommandIn : ThrustCommandPort;
        perform action fireThrusters : FireThrusters;
        perform action manageFuel : ManageFuel;
    }

    part def NavigationSystem {
        attribute currentPosition : LengthValue;
        attribute currentVelocity : VelocityValue;
        attribute targetDistance : LengthValue = 1000000000000.0;
        port powerIn : PowerInPort;
        port navOut : NavigationPort;
        port thrustCmdOut : ThrustCommandOutPort;
        perform action determinePosition : DeterminePosition;
        perform action calculateTrajectory : CalculateTrajectory;
        perform action commandCourseCorrection : CommandCourseCorrection;
    }

    part def ScienceInstrumentSuite {
        attribute dataStorageCapacity : Integer = 1000000;
        attribute currentDataStored : Integer = 0;
        port powerIn : PowerInPort;
        port scienceDataOut : ScienceDataPort;
        perform action collectData : CollectScienceData;
        perform action processData : ProcessScienceData;
        exhibit state instrumentStates {
            entry; then idle;
            state idle;
            accept when currentDataStored < dataStorageCapacity
                then collecting;
            state collecting;
            accept when currentDataStored > 1000
                then processing;
            state processing;
            accept when true
                then idle;
        }
    }

    part def CommunicationSystem {
        attribute antennaGain : SignalStrengthValue = 45.0;
        attribute downlinkRate : DataRateValue = 1000.0;
        port powerIn : PowerInPort;
        port commandIn : CommandPort;
        port scienceDataIn {
            in scienceData : ScienceData;
        }
        port telemetryOut : TelemetryPort;
        port scienceDataOut : ScienceDataPort;
        perform action receiveCommands : ReceiveCommands;
        perform action transmitTelemetry : TransmitTelemetry;
        perform action transmitScienceData : TransmitScienceData;
    }

    part def ThermalControlSystem {
        attribute minOperatingTemp : TemperatureValue = 233.0;
        attribute maxOperatingTemp : TemperatureValue = 323.0;
        attribute currentTemperature : TemperatureValue = 290.0;
        port powerIn : PowerInPort;
        port thermalOut : ThermalPort;
        perform action regulateTemperature : RegulateTemperature;
        exhibit state thermalStates {
            entry; then nominal;
            state nominal;
            accept when currentTemperature < minOperatingTemp
                then heating;
            accept when currentTemperature > maxOperatingTemp
                then cooling;
            state heating;
            accept when currentTemperature >= minOperatingTemp
                then nominal;
            state cooling;
            accept when currentTemperature <= maxOperatingTemp
                then nominal;
        }
    }

    part def SpaceProbe {
        attribute probeId : String = "DeepSpaceProbe-1";
        attribute targetName : String = "DistantCelestialBody";
        attribute targetDistance : LengthValue = 1000000000000.0;
        attribute autonomyEnabled : Boolean = true;

        port groundLinkCommand : CommandPort;
        port groundLinkTelemetry : TelemetryPort;
        port groundLinkScience : ScienceDataPort;

        part powerSystem : PowerSystem;
        part propulsionSystem : PropulsionSystem;
        part navigationSystem : NavigationSystem;
        part scienceSuite : ScienceInstrumentSuite;
        part commSystem : CommunicationSystem;
        part thermalSystem : ThermalControlSystem;

        bind groundLinkCommand = commSystem.commandIn;
        bind groundLinkTelemetry = commSystem.telemetryOut;
        bind groundLinkScience = commSystem.scienceDataOut;

        flow powerToPropulsion of PowerDistribution
            from powerSystem.powerOut.power to propulsionSystem.powerIn.power;
        flow powerToNavigation of PowerDistribution
            from powerSystem.powerOut.power to navigationSystem.powerIn.power;
        flow powerToScience of PowerDistribution
            from powerSystem.powerOut.power to scienceSuite.powerIn.power;
        flow powerToComm of PowerDistribution
            from powerSystem.powerOut.power to commSystem.powerIn.power;
        flow powerToThermal of PowerDistribution
            from powerSystem.powerOut.power to thermalSystem.powerIn.power;

        flow navToPropulsionCmd of ThrustCommand
            from navigationSystem.thrustCmdOut.thrustCmd
            to propulsionSystem.thrustCommandIn.thrustCmd;

        flow scienceToComm of ScienceData
            from scienceSuite.scienceDataOut.scienceData
            to commSystem.scienceDataIn.scienceData;

        action activateSystems : ActivateSystems;
        action performLaunch : PerformLaunch;
        action separateStages : SeparateStages;
        action startCruise : StartCruise;
        action navigateToTarget : NavigateToTarget;
        action monitorHealth : MonitorHealth;
        action manageThermal : ManageThermal;
        action prepareInstruments : PrepareInstruments;
        action refineNavigation : RefineNavigation;
        action beginScience : BeginScience;
        action collectData : CollectData;
        action processData : ProcessData;
        action transmitData : TransmitData;
        action conservePower : ConservePower;
        action maintainContact : MaintainContact;

        exhibit state missionPhases {
            entry; then launch;
            state launch {
                entry activateSystems;
                do performLaunch;
                exit separateStages;
            }
            accept LaunchComplete then cruise;
            state cruise {
                entry startCruise;
                do navigationSystem.calculateTrajectory;
            }
            accept TargetApproached then approach;
            state approach {
                entry prepareInstruments;
                do scienceSuite.collectData;
            }
            accept ApproachComplete then science;
            state science {
                entry beginScience;
                do scienceSuite.processData;
                exit commSystem.transmitScienceData;
            }
            accept MissionComplete then safeMode;
            accept LowPowerDetected then safeMode;
            accept CriticalFault then safeMode;
            state safeMode {
                entry conservePower;
                do commSystem.transmitTelemetry;
            }
            accept RecoveryCommand then cruise;
        }
    }

    part def GroundStation {
        attribute stationId : String = "GroundStation-1";
        attribute antennaDiameter : LengthValue = 70.0;
        port commandOut : GroundCommandPort;
        port dataIn : GroundDataPort;
        perform action sendCommands : SendCommands;
        perform action receiveTelemetry : ReceiveTelemetry;
        perform action receiveScienceData : ReceiveScienceData;
        exhibit state groundOps {
            entry; then monitoring;
            state monitoring;
            accept when true
                then commanding;
            state commanding;
            accept when true
                then monitoring;
        }
    }

    part def MissionSystem {
        part spaceProbe : SpaceProbe;
        part groundStation : GroundStation;

        flow commandFlow of Command
            from groundStation.commandOut.command
            to spaceProbe.groundLinkCommand.command;
        flow telemetryFlow of Telemetry
            from spaceProbe.groundLinkTelemetry.telemetry
            to groundStation.dataIn.telemetry;
        flow scienceDataFlow of ScienceData
            from spaceProbe.groundLinkScience.scienceData
            to groundStation.dataIn.scienceData;
    }

    requirement def MissionRequirement {
        doc /* The space exploration system shall navigate to a distant celestial target,
             * conduct scientific analysis, and transmit findings back to Earth. */
    }
    requirement def PowerRequirement {
        doc /* The power system shall generate, store, and distribute electrical power
             * to all probe subsystems throughout the mission duration. */
        attribute minBatteryCapacity : EnergyValue = 5000.0;
    }
    requirement def PropulsionRequirement {
        doc /* The propulsion system shall provide thrust for major maneuvers and
             * trajectory corrections, managing fuel to precisely control velocity changes. */
        attribute minFuelMass : FuelMassValue = 500.0;
    }
    requirement def NavigationRequirement {
        doc /* The navigation system shall continuously determine position and velocity,
             * calculate trajectory to target, and command propulsion adjustments. */
        attribute maxPositionError : LengthValue = 1000.0;
    }
    requirement def ScienceRequirement {
        doc /* The science instrument suite shall gather, process, and compress data
             * about the target body, managing storage and transmission. */
        attribute minDataStorage : Integer = 1000000;
    }
    requirement def CommunicationRequirement {
        doc /* The communication system shall receive commands from ground station and
             * transmit telemetry and science data across interplanetary distances. */
        attribute minDownlinkRate : DataRateValue = 1000.0;
        attribute maxLatency : TimeValue = 1200.0;
    }
    requirement def ThermalRequirement {
        doc /* The thermal control system shall maintain probe temperatures within
             * operational limits in deep space conditions. */
        attribute minTemp : TemperatureValue = 233.0;
        attribute maxTemp : TemperatureValue = 323.0;
    }
    requirement def AutonomyRequirement {
        doc /* The probe shall operate autonomously to handle time-delayed communication
             * over interplanetary distances. */
        attribute maxCommDelay : TimeValue = 1200.0;
    }

    requirement missionReq : MissionRequirement {
        subject missionSystem : MissionSystem;
    }
    requirement powerReq : PowerRequirement {
        subject powerSystem : PowerSystem;
    }
    requirement propulsionReq : PropulsionRequirement {
        subject propulsionSystem : PropulsionSystem;
    }
    requirement navReq : NavigationRequirement {
        subject navigationSystem : NavigationSystem;
    }
    requirement scienceReq : ScienceRequirement {
        subject scienceSuite : ScienceInstrumentSuite;
    }
    requirement commReq : CommunicationRequirement {
        subject commSystem : CommunicationSystem;
    }
    requirement thermalReq : ThermalRequirement {
        subject thermalSystem : ThermalControlSystem;
    }
    requirement autonomyReq : AutonomyRequirement {
        subject spaceProbe : SpaceProbe;
    }

    use case def NavigateToTarget {
        subject spaceProbe : SpaceProbe;
        actor groundStation : GroundStation;
        objective {
            doc /* Main Flow:
                  * 1. Ground station sends navigation target to probe.
                  * 2. Navigation system computes trajectory to target.
                  * 3. Propulsion system executes trajectory correction maneuvers.
                  * 4. Probe travels through cruise phase to approach target.
                  *
                  * Exception Flows:
                  * - If propulsion fuel is insufficient, enter safe mode and alert ground station.
                  * - If navigation system fails, revert to last known trajectory and await ground commands.
                  */
        }
    }
    use case def ConductScience {
        subject spaceProbe : SpaceProbe;
        actor groundStation : GroundStation;
        objective {
            doc /* Main Flow:
                  * 1. Probe enters science phase upon approach to target.
                  * 2. Science instrument suite collects data about target body.
                  * 3. Data is processed and compressed onboard.
                  * 4. Processed science data is transmitted to ground station.
                  *
                  * Exception Flows:
                  * - If data storage is full, enter safe mode and prioritize data transmission.
                  * - If instrument fails, switch to backup instruments if available.
                  */
        }
    }
    use case def MaintainHealth {
        subject spaceProbe : SpaceProbe;
        actor groundStation : GroundStation;
        objective {
            doc /* Main Flow:
                  * 1. Thermal control system regulates probe temperature continuously.
                  * 2. Power system manages solar charging and battery discharge.
                  * 3. Communication system transmits health telemetry to ground station.
                  * 4. Probe autonomously handles anomalies during communication delays.
                  *
                  * Exception Flows:
                  * - If temperature exceeds limits, enter safe mode.
                  * - If battery charge is critically low, shed non-essential power loads.
                  */
        }
    }
    use case def ExecuteMission {
        subject spaceProbe : SpaceProbe;
        actor groundStation : GroundStation;
        objective {
            doc /* The space probe executes the full mission sequence:
                  * navigation, science data collection, and health maintenance,
                  * operating autonomously despite interplanetary communication delays.
                  */
        }
    }

    use case executeMission : ExecuteMission {
        first start;
        then include use case navigateToTarget : NavigateToTarget {
            actor :>> groundStation = navigateToTarget::groundStation;
        }
        then include use case conductScience : ConductScience {
            actor :>> groundStation = conductScience::groundStation;
        }
        then include use case maintainHealth : MaintainHealth {
            actor :>> groundStation = maintainHealth::groundStation;
        }
        then done;
    }
}
