package RoboticSpaceExploration {

    package Units {
        unit km;
        unit m;
        unit s;
        unit kg;
        unit N;
        unit W;
        unit Wh;
        unit V;
        unit A;
        unit degC;
        unit bps;
        unit MB;
        unit km_per_s :> km / s;
        unit m_per_s :> m / s;
    }

    package ValueTypes {
        value type Distance :> Real { unit km; }
        value type Velocity :> Real { unit km_per_s; }
        value type DeltaV :> Real { unit m_per_s; }
        value type Power :> Real { unit W; }
        value type Energy :> Real { unit Wh; }
        value type Voltage :> Real { unit V; }
        value type Current :> Real { unit A; }
        value type Temperature :> Real { unit degC; }
        value type Mass :> Real { unit kg; }
        value type Thrust :> Real { unit N; }
        value type Duration :> Real { unit s; }
        value type DataRate :> Real { unit bps; }
        value type DataVolume :> Real { unit MB; }
        value type FuelMass :> Real { unit kg; }
        value type Confidence :> Real;
    }

    package Items {
        item def Command {
            attribute sequenceId : Integer;
            attribute priority : Integer;
        }
        item def Telemetry {
            attribute timestamp : Duration;
            attribute healthStatus : String;
        }
        item def ScienceData {
            attribute volume : DataVolume;
            attribute compressed : Boolean;
            attribute targetId : String;
        }
        item def NavigationSolution {
            attribute position : Distance[3];
            attribute velocity : Velocity[3];
            attribute confidence : Confidence;
        }
        item def ThrustCommand {
            attribute deltaV : DeltaV;
            attribute duration : Duration;
            attribute axis : Integer;
        }
        item def PowerFlow {
            attribute voltage : Voltage;
            attribute current : Current;
        }
        item def ThermalLoad {
            attribute internalTemp : Temperature;
            attribute externalTemp : Temperature;
        }
        item def RFSignal {
            attribute frequency : Real;
            attribute dataRate : DataRate;
        }
    }

    package Ports {
        port def PowerPort {
            out power : PowerFlow;
        }
        port def PowerSinkPort {
            in power : PowerFlow;
        }
        port def CommandLinkPort {
            in command : Command;
            out telemetry : Telemetry;
        }
        port def ScienceDataPort {
            in scienceData : ScienceData;
        }
        port def NavSolutionPort {
            out solution : NavigationSolution;
        }
        port def ThrustCommandPort {
            in command : ThrustCommand;
        }
        port def ThermalPort {
            out load : ThermalLoad;
        }
        port def RFLinkPort {
            out downlink : ScienceData;
            out telemetry : Telemetry;
            in uplink : Command;
        }
    }

    package Components {

        part def SolarPanel {
            attribute area : Real;
            attribute outputPower : Power;
            port powerOut : PowerPort;
            action generate;
        }

        part def Battery {
            attribute capacity : Energy;
            attribute chargeLevel : Energy;
            attribute voltage : Voltage;
            port powerOut : PowerPort;
            port chargeIn : PowerSinkPort;
            action charge;
            action discharge;
        }

        part def PowerSystem {
            attribute busVoltage : Voltage := 28 [V];
            attribute totalPower : Power;
            attribute availableEnergy : Energy;
            part solarPanel : SolarPanel;
            part battery : Battery;
            port powerOut : PowerPort;
            exhibit state PowerState {
                entry; then Nominal;
                state Nominal {
                    entry; then Generating;
                    state Generating;
                    state Distributing;
                    transition from Generating to Distributing when solarPanel.outputPower > 0 [W];
                    transition from Distributing to Generating when battery.chargeLevel < battery.capacity;
                }
                state Degraded;
                transition from Nominal to Degraded when availableEnergy < 100 [Wh];
                transition from Degraded to Nominal when solarPanel.outputPower > 50 [W];
            }
            action generatePower {
                out power : PowerFlow;
            }
            action storeEnergy;
            action distributePower {
                in power : PowerFlow;
            }
        }

        part def PropulsionSystem {
            attribute thrust : Thrust;
            attribute specificImpulse : Real;
            attribute fuelRemaining : FuelMass;
            attribute totalDeltaV : DeltaV;
            port commandIn : ThrustCommandPort;
            port powerIn : PowerSinkPort;
            exhibit state PropulsionState {
                entry; then Idle;
                state Idle;
                state Firing;
                state Depleted;
                transition from Idle to Firing when commandIn.command.deltaV > 0 [m_per_s];
                transition from Firing to Idle when fuelRemaining > 0 [kg];
                transition from Firing to Depleted when fuelRemaining <= 0 [kg];
            }
            action executeBurn {
                in command : ThrustCommand;
                out consumedFuel : FuelMass;
            }
            action performTrajectoryCorrection {
                in command : ThrustCommand;
            }
        }

        part def StarTracker {
            attribute accuracy : Real;
            port solutionOut : NavSolutionPort;
            action determineAttitude;
        }

        part def IMU {
            port solutionOut : NavSolutionPort;
            action measureAcceleration;
        }

        part def NavigationSystem {
            attribute currentPosition : Distance[3];
            attribute currentVelocity : Velocity[3];
            attribute targetPosition : Distance[3];
            attribute courseError : DeltaV;
            part starTracker : StarTracker;
            part imu : IMU;
            port solutionOut : NavSolutionPort;
            port thrustCommandOut : ThrustCommandPort;
            port powerIn : PowerSinkPort;
            exhibit state NavigationState {
                entry; then Determining;
                state Determining;
                state Planning;
                state Correcting;
                transition from Determining to Planning when solutionOut.solution.confidence > 0.8;
                transition from Planning to Correcting when courseError > 0.5 [m_per_s];
                transition from Correcting to Determining when thrustCommandOut.command.deltaV == 0 [m_per_s];
            }
            action computePosition {
                out solution : NavigationSolution;
            }
            action calculateTrajectory {
                in solution : NavigationSolution;
                out requiredDeltaV : DeltaV;
            }
            action generateThrustCommand {
                in deltaV : DeltaV;
                out command : ThrustCommand;
            }
        }

        part def Spectrometer {
            attribute spectralRange : Real;
            port dataOut : ScienceDataPort;
            action measureComposition;
        }

        part def Imager {
            attribute resolution : Real;
            port dataOut : ScienceDataPort;
            action captureImage;
        }

        part def ScienceInstrumentSuite {
            attribute dataBuffer : DataVolume;
            attribute compressionRatio : Real;
            part spectrometer : Spectrometer;
            part imager : Imager;
            port dataOut : ScienceDataPort;
            port powerIn : PowerSinkPort;
            exhibit state ScienceState {
                entry; then Standby;
                state Standby;
                state Collecting;
                state Processing;
                transition from Standby to Collecting when powerIn.power.voltage > 0 [V];
                transition from Collecting to Processing when dataBuffer > 500 [MB];
                transition from Processing to Standby when dataBuffer < 100 [MB];
            }
            action collectData {
                out scienceData : ScienceData;
            }
            action processData {
                in raw : ScienceData;
                out compressed : ScienceData;
            }
            action compressData {
                in data : ScienceData;
                out compressed : ScienceData;
            }
        }

        part def HighGainAntenna {
            attribute gain : Real;
            attribute pointingAccuracy : Real;
            port rfLink : RFLinkPort;
            action transmit {
                in data : ScienceData;
            }
            action receive {
                out command : Command;
            }
        }

        part def CommunicationSystem {
            attribute downlinkRate : DataRate;
            attribute uplinkRate : DataRate;
            attribute commandQueue : Command[*];
            part antenna : HighGainAntenna;
            port rfLink : RFLinkPort;
            port dataIn : ScienceDataPort;
            port powerIn : PowerSinkPort;
            exhibit state CommState {
                entry; then Listening;
                state Listening;
                state Transmitting;
                transition from Listening to Transmitting when dataIn.scienceData.volume > 0 [MB];
                transition from Transmitting to Listening when antenna.rfLink.downlink.volume == 0 [MB];
            }
            action receiveCommand {
                out command : Command;
            }
            action transmitTelemetry {
                in telemetry : Telemetry;
            }
            action transmitScienceData {
                in data : ScienceData;
            }
        }

        part def Heater {
            attribute power : Power;
            port powerIn : PowerSinkPort;
            action heat;
        }

        part def Radiator {
            attribute area : Real;
            action radiate;
        }

        part def ThermalControlSystem {
            attribute setpoint : Temperature := -20 [degC];
            attribute currentTemp : Temperature;
            attribute minTemp : Temperature := -40 [degC];
            attribute maxTemp : Temperature := 50 [degC];
            part heater : Heater;
            part radiator : Radiator;
            port thermalOut : ThermalPort;
            port powerIn : PowerSinkPort;
            exhibit state ThermalState {
                entry; then Stable;
                state Stable;
                state Heating;
                state Cooling;
                transition from Stable to Heating when currentTemp < minTemp;
                transition from Stable to Cooling when currentTemp > maxTemp;
                transition from Heating to Stable when currentTemp >= setpoint;
                transition from Cooling to Stable when currentTemp <= setpoint;
            }
            action regulateTemperature {
                out load : ThermalLoad;
            }
        }

        part def OnboardComputer {
            attribute clockSpeed : Real;
            attribute memory : DataVolume;
            port powerIn : PowerSinkPort;
            action executeAutonomy;
            action manageHealth;
        }

        part def SpaceProbe {
            attribute probeId : String;
            attribute missionPhase : String;
            attribute autonomyLevel : Confidence;
            part powerSystem : PowerSystem;
            part propulsionSystem : PropulsionSystem;
            part navigationSystem : NavigationSystem;
            part scienceSuite : ScienceInstrumentSuite;
            part communicationSystem : CommunicationSystem;
            part thermalSystem : ThermalControlSystem;
            part onboardComputer : OnboardComputer;
            port rfLink : RFLinkPort;
            exhibit state MissionPhaseStateMachine {
                entry; then Launch;
                state Launch {
                    entry; then Activating;
                    state Activating;
                    transition from Activating to Cruise when powerSystem.availableEnergy > 500 [Wh];
                }
                state Cruise {
                    entry; then Monitoring;
                    state Monitoring;
                    state CourseCorrecting;
                    transition from Monitoring to CourseCorrecting when navigationSystem.courseError > 0.5 [m_per_s];
                    transition from CourseCorrecting to Monitoring when propulsionSystem.fuelRemaining > 0 [kg];
                    transition from Cruise to Approach when navigationSystem.currentPosition ~ navigationSystem.targetPosition;
                }
                state Approach {
                    entry; then RefiningNavigation;
                    state RefiningNavigation;
                    state PreparingInstruments;
                    transition from RefiningNavigation to PreparingInstruments when navigationSystem.solutionOut.solution.confidence > 0.95;
                    transition from Approach to Science when scienceSuite.spectrometer.dataOut.scienceData.volume > 0 [MB];
                }
                state Science {
                    entry; then Collecting;
                    state Collecting;
                    state Processing;
                    state Transmitting;
                    transition from Collecting to Processing when scienceSuite.dataBuffer > 500 [MB];
                    transition from Processing to Transmitting when scienceSuite.dataOut.scienceData.compressed == true;
                    transition from Transmitting to Collecting when communicationSystem.antenna.rfLink.downlink.volume == 0 [MB];
                    transition from Science to SafeMode when powerSystem.availableEnergy < 100 [Wh];
                }
                state SafeMode {
                    entry; then Conserving;
                    state Conserving;
                    state MaintainingContact;
                    transition from Conserving to MaintainingContact when communicationSystem.commandQueue->size() > 0;
                    transition from MaintainingContact to Conserving when communicationSystem.antenna.rfLink.downlink.volume == 0 [MB];
                    transition from SafeMode to Science when powerSystem.availableEnergy > 500 [Wh];
                }
            }
            action activateSystems;
            action monitorHealth {
                out telemetry : Telemetry;
            }
            action performAutonomousOperation;
        }

        part def GroundAntenna {
            attribute diameter : Real;
            attribute gain : Real;
            port rfLink : RFLinkPort;
            action sendCommand {
                out command : Command;
            }
            action receiveData {
                in data : ScienceData;
            }
        }

        part def MissionControlCenter {
            attribute missionName : String;
            attribute operators : Integer;
            part antenna : GroundAntenna;
            port rfLink : RFLinkPort;
            exhibit state GroundOpsState {
                entry; then Planning;
                state Planning;
                state Commanding;
                state Receiving;
                transition from Planning to Commanding when antenna.rfLink.uplink.sequenceId > 0;
                transition from Commanding to Receiving when antenna.rfLink.downlink.volume > 0 [MB];
                transition from Receiving to Planning when antenna.rfLink.downlink.volume == 0 [MB];
            }
            action planMission {
                out command : Command;
            }
            action uplinkCommand {
                in command : Command;
            }
            action analyzeScienceData {
                in data : ScienceData;
            }
            action monitorTelemetry {
                in telemetry : Telemetry;
            }
        }

        part def GroundStation {
            attribute stationId : String;
            attribute location : String;
            part controlCenter : MissionControlCenter;
            port rfLink : RFLinkPort;
        }

    }

    package Requirements {

        requirement def PowerAvailabilityRequirement {
            attribute minEnergy : Energy := 500 [Wh];
            subject powerSystem : Components::PowerSystem;
            require powerSystem.availableEnergy >= minEnergy;
        }

        requirement def PropulsionDeltaVRequirement {
            attribute requiredDeltaV : DeltaV := 2000 [m_per_s];
            subject propulsion : Components::PropulsionSystem;
            require propulsion.totalDeltaV >= requiredDeltaV;
        }

        requirement def NavigationAccuracyRequirement {
            attribute minConfidence : Confidence := 0.95;
            subject navigation : Components::NavigationSystem;
            require navigation.solutionOut.solution.confidence >= minConfidence;
        }

        requirement def ScienceDataRequirement {
            attribute minDataVolume : DataVolume := 1000 [MB];
            subject suite : Components::ScienceInstrumentSuite;
            require suite.dataBuffer >= minDataVolume;
        }

        requirement def CommunicationLinkRequirement {
            attribute minDownlink : DataRate := 1000 [bps];
            subject comm : Components::CommunicationSystem;
            require comm.downlinkRate >= minDownlink;
        }

        requirement def ThermalSurvivalRequirement {
            attribute lowerBound : Temperature := -40 [degC];
            attribute upperBound : Temperature := 50 [degC];
            subject thermal : Components::ThermalControlSystem;
            require thermal.currentTemp >= lowerBound and thermal.currentTemp <= upperBound;
        }

        requirement def AutonomyRequirement {
            attribute minAutonomy : Confidence := 0.9;
            subject probe : Components::SpaceProbe;
            require probe.autonomyLevel >= minAutonomy;
        }

        requirement def MissionPhaseRequirement {
            subject probe : Components::SpaceProbe;
            require probe.missionPhase in {'Launch', 'Cruise', 'Approach', 'Science', 'SafeMode'};
        }

        requirement SpaceExplorationSystemRequirements {
            requirement powerReq : PowerAvailabilityRequirement;
            requirement propulsionReq : PropulsionDeltaVRequirement;
            requirement navReq : NavigationAccuracyRequirement;
            requirement scienceReq : ScienceDataRequirement;
            requirement commReq : CommunicationLinkRequirement;
            requirement thermalReq : ThermalSurvivalRequirement;
            requirement autonomyReq : AutonomyRequirement;
            requirement phaseReq : MissionPhaseRequirement;
        }

    }

    package System {

        part def SpaceExplorationMission {
            attribute missionName : String := "DeepSpaceProbeMission";
            attribute targetBody : String;
            attribute launchDate : String;
            part probe : Components::SpaceProbe;
            part groundStation : Components::GroundStation;
            connection rfLinkConnection connect probe.rfLink to groundStation.rfLink;
            connection powerDistribution connect probe.powerSystem.powerOut to probe.propulsionSystem.powerIn;
            connection powerDistributionNav connect probe.powerSystem.powerOut to probe.navigationSystem.powerIn;
            connection powerDistributionScience connect probe.powerSystem.powerOut to probe.scienceSuite.powerIn;
            connection powerDistributionComm connect probe.powerSystem.powerOut to probe.communicationSystem.powerIn;
            connection powerDistributionThermal connect probe.powerSystem.powerOut to probe.thermalSystem.powerIn;
            connection powerDistributionComputer connect probe.powerSystem.powerOut to probe.onboardComputer.powerIn;
            connection navToPropulsion connect probe.navigationSystem.thrustCommandOut to probe.propulsionSystem.commandIn;
            connection scienceToComm connect probe.scienceSuite.dataOut to probe.communicationSystem.dataIn;
            satisfy Requirements::SpaceExplorationSystemRequirements by probe, groundStation;
        }

    }

}
