package SpaceProbeMissionModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Mass :> ISQ::mass {
        unit = SI::kg;
    }

    attribute def Distance :> ISQ::length {
        unit = SI::m;
    }

    attribute def Power :> ISQ::power {
        unit = SI::W;
    }

    attribute def Energy :> ISQ::energy {
        unit = SI::J;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::K;
    }

    attribute def DataRate :> ScalarValues::Real {
        unit = SI::bit / SI::s;
    }

    attribute def Frequency :> ISQ::frequency {
        unit = SI::Hz;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::V;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = SI::s;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute power : Power;
    }

    item def ScienceData {
        attribute volume : ScalarValues::Real;
        attribute rate : DataRate;
        attribute priority : ScalarValues::Integer;
    }

    item def TelemetryData {
        attribute healthStatus : ScalarValues::String;
        attribute batteryStateOfCharge : ScalarValues::Real;
        attribute thermalMargin : Temperature;
        attribute faultCount : ScalarValues::Integer;
    }

    item def CommandData {
        attribute commandId : ScalarValues::String;
        attribute executionTime : TimeDuration;
        attribute authenticated : ScalarValues::Boolean;
    }

    item def Propellant {
        attribute mass : Mass;
        attribute specificImpulse : TimeDuration;
    }

    item def ThermalEnergy {
        attribute heatFlow : Power;
        attribute temperature : Temperature;
    }

    item def RadioSignal {
        attribute carrierFrequency : Frequency;
        attribute dataRate : DataRate;
        attribute receivedPower : Power;
    }

    item def NavigationSolution {
        attribute positionError : Distance;
        attribute velocityError : ScalarValues::Real;
        attribute timeTag : TimeDuration;
    }

    port def PowerPort {
        out item powerOut : ElectricalPower;
        in item powerIn : ElectricalPower;
    }

    port def DataPort {
        out item dataOut : ScienceData;
        in item commandIn : CommandData;
    }

    port def TelemetryPort {
        out item telemetryOut : TelemetryData;
    }

    port def ThermalPort {
        out item heatOut : ThermalEnergy;
        in item heatIn : ThermalEnergy;
    }

    port def PropellantPort {
        out item propellantOut : Propellant;
    }

    port def RadioPort {
        out item downlink : RadioSignal;
        in item uplink : RadioSignal;
    }

    port def NavigationPort {
        out item navOut : NavigationSolution;
    }

    part def SolarArray {
        attribute deployedArea : ISQ::area = 22 [SI::m^2];
        attribute peakGeneratedPower : Power = 2400 [SI::W];
        attribute endOfLifeGeneratedPower : Power = 1600 [SI::W];

        port powerInterface : PowerPort;

        action generateElectricalPower {
            out item producedPower : ElectricalPower;
        }
    }

    part def Battery {
        attribute capacity : Energy = 5400000 [SI::J];
        attribute nominalVoltage : Voltage = 50 [SI::V];
        attribute minimumStateOfCharge : ScalarValues::Real = 0.25;
        attribute maximumStateOfCharge : ScalarValues::Real = 1.0;

        port powerInterface : PowerPort;

        action storeEnergy {
            in item chargingPower : ElectricalPower;
        }

        action deliverEnergy {
            out item batteryPower : ElectricalPower;
        }
    }

    part def PowerControlUnit {
        attribute regulatedBusVoltage : Voltage = 50 [SI::V];
        attribute maximumBusPower : Power = 2200 [SI::W];

        port arrayPower : PowerPort;
        port batteryPower : PowerPort;
        port spacecraftBusPower : PowerPort;

        action regulatePower {
            in item sourcePower : ElectricalPower;
            out item regulatedPower : ElectricalPower;
        }
    }

    part def SciencePayload {
        attribute payloadMass : Mass = 65 [SI::kg];
        attribute nominalPowerDemand : Power = 420 [SI::W];
        attribute observationDataRate : DataRate = 250000 [SI::bit / SI::s];

        port powerPort : PowerPort;
        port scienceDataPort : DataPort;
        port thermalPort : ThermalPort;

        action observeTarget {
            out item observationData : ScienceData;
        }

        action calibrateInstruments {
            out item calibrationData : ScienceData;
        }
    }

    part def FlightComputer {
        attribute processorPowerDemand : Power = 85 [SI::W];
        attribute solidStateMemoryCapacity : ScalarValues::Real = 2.0e12;
        attribute commandAuthenticationRequired : ScalarValues::Boolean = true;

        port powerPort : PowerPort;
        port payloadDataPort : DataPort;
        port telecomDataPort : DataPort;
        port telemetryPort : TelemetryPort;
        port navigationPort : NavigationPort;

        action processCommands {
            in item command : CommandData;
        }

        action storeScienceData {
            in item scienceData : ScienceData;
        }

        action generateTelemetry {
            out item telemetry : TelemetryData;
        }

        action selectMissionMode {
            in item navigation : NavigationSolution;
            out item modeCommand : CommandData;
        }
    }

    part def TelecommunicationSystem {
        attribute highGainAntennaDiameter : Distance = 2.5 [SI::m];
        attribute xBandFrequency : Frequency = 8400000000 [SI::Hz];
        attribute kaBandFrequency : Frequency = 32000000000 [SI::Hz];
        attribute maximumDownlinkRate : DataRate = 2000000 [SI::bit / SI::s];

        port powerPort : PowerPort;
        port radioPort : RadioPort;
        port dataPort : DataPort;
        port telemetryPort : TelemetryPort;
        port thermalPort : ThermalPort;

        action receiveCommands {
            in item uplinkSignal : RadioSignal;
            out item command : CommandData;
        }

        action transmitScienceData {
            in item scienceData : ScienceData;
            out item downlinkSignal : RadioSignal;
        }

        action transmitTelemetry {
            in item telemetry : TelemetryData;
            out item downlinkSignal : RadioSignal;
        }
    }

    part def PropulsionSystem {
        attribute dryMass : Mass = 48 [SI::kg];
        attribute propellantCapacity : Mass = 120 [SI::kg];
        attribute mainEngineThrust : ScalarValues::Real = 22;
        attribute attitudeThrusterThrust : ScalarValues::Real = 0.9;

        port powerPort : PowerPort;
        port propellantPort : PropellantPort;
        port telemetryPort : TelemetryPort;
        port thermalPort : ThermalPort;

        action executeTrajectoryCorrection {
            in item navigation : NavigationSolution;
            out item propellantUsed : Propellant;
        }

        action desaturateReactionWheels {
            out item propellantUsed : Propellant;
        }
    }

    part def AttitudeControlSystem {
        attribute pointingAccuracy : ScalarValues::Real = 0.05;
        attribute wheelMomentumCapacity : ScalarValues::Real = 18;
        attribute safeModeSunPointingError : ScalarValues::Real = 5.0;

        port powerPort : PowerPort;
        port navigationPort : NavigationPort;
        port telemetryPort : TelemetryPort;

        action pointHighGainAntenna {
            in item navigation : NavigationSolution;
        }

        action pointScienceInstruments {
            in item navigation : NavigationSolution;
        }

        action pointSolarArrayToSun {
            in item navigation : NavigationSolution;
        }
    }

    part def NavigationSystem {
        attribute positionKnowledgeAccuracy : Distance = 1000 [SI::m];
        attribute velocityKnowledgeAccuracy : ScalarValues::Real = 0.02;

        port powerPort : PowerPort;
        port navigationPort : NavigationPort;
        port telemetryPort : TelemetryPort;

        action estimateState {
            out item navigationSolution : NavigationSolution;
        }
    }

    part def ThermalControlSystem {
        attribute minimumEquipmentTemperature : Temperature = 253 [SI::K];
        attribute maximumEquipmentTemperature : Temperature = 323 [SI::K];
        attribute radiatorArea : ISQ::area = 4.5 [SI::m^2];
        attribute survivalHeaterPower : Power = 180 [SI::W];

        port powerPort : PowerPort;
        port payloadThermalPort : ThermalPort;
        port telecomThermalPort : ThermalPort;
        port propulsionThermalPort : ThermalPort;

        action rejectWasteHeat {
            in item heatLoad : ThermalEnergy;
            out item rejectedHeat : ThermalEnergy;
        }

        action maintainSurvivalTemperature {
            in item heaterPower : ElectricalPower;
            out item controlledHeat : ThermalEnergy;
        }
    }

    part def DeepSpaceNetwork {
        attribute uplinkFrequency : Frequency = 7160000000 [SI::Hz];
        attribute downlinkFrequency : Frequency = 8400000000 [SI::Hz];
        attribute nominalCommandRate : DataRate = 2000 [SI::bit / SI::s];

        port radioPort : RadioPort;

        action sendCommands {
            out item uplinkSignal : RadioSignal;
        }

        action receiveMissionData {
            in item downlinkSignal : RadioSignal;
        }
    }

    part def SpaceProbe {
        attribute launchMass : Mass = 850 [SI::kg];
        attribute dryMass : Mass = 610 [SI::kg];
        attribute designLife : TimeDuration = 315576000 [SI::s];
        attribute cruisePowerDemand : Power = 750 [SI::W];
        attribute scienceModePowerDemand : Power = 1450 [SI::W];
        attribute minimumDownlinkRate : DataRate = 50000 [SI::bit / SI::s];

        port groundRadio : RadioPort;

        part solarArray : SolarArray;
        part battery : Battery;
        part powerControlUnit : PowerControlUnit;
        part sciencePayload : SciencePayload;
        part flightComputer : FlightComputer;
        part telecommunicationSystem : TelecommunicationSystem;
        part propulsionSystem : PropulsionSystem;
        part attitudeControlSystem : AttitudeControlSystem;
        part navigationSystem : NavigationSystem;
        part thermalControlSystem : ThermalControlSystem;

        connect solarArray.powerInterface to powerControlUnit.arrayPower;
        connect battery.powerInterface to powerControlUnit.batteryPower;
        connect powerControlUnit.spacecraftBusPower to sciencePayload.powerPort;
        connect powerControlUnit.spacecraftBusPower to flightComputer.powerPort;
        connect powerControlUnit.spacecraftBusPower to telecommunicationSystem.powerPort;
        connect powerControlUnit.spacecraftBusPower to propulsionSystem.powerPort;
        connect powerControlUnit.spacecraftBusPower to attitudeControlSystem.powerPort;
        connect powerControlUnit.spacecraftBusPower to navigationSystem.powerPort;
        connect powerControlUnit.spacecraftBusPower to thermalControlSystem.powerPort;

        connect sciencePayload.scienceDataPort to flightComputer.payloadDataPort;
        connect flightComputer.telecomDataPort to telecommunicationSystem.dataPort;
        connect flightComputer.telemetryPort to telecommunicationSystem.telemetryPort;
        connect navigationSystem.navigationPort to flightComputer.navigationPort;
        connect navigationSystem.navigationPort to attitudeControlSystem.navigationPort;

        connect sciencePayload.thermalPort to thermalControlSystem.payloadThermalPort;
        connect telecommunicationSystem.thermalPort to thermalControlSystem.telecomThermalPort;
        connect propulsionSystem.thermalPort to thermalControlSystem.propulsionThermalPort;

        connect telecommunicationSystem.radioPort to groundRadio;

        action performPrimaryMission {
            first startMission;
            then estimateTrajectory;
            then pointInstruments;
            then acquireScienceObservations;
            then storeAndCompressData;
            then downlinkMissionData;
            then reportHealth;

            action startMission {
                out item initialTelemetry : TelemetryData;
            }

            action estimateTrajectory {
                out item navigation : NavigationSolution;
            }

            action pointInstruments {
                in item navigation : NavigationSolution;
            }

            action acquireScienceObservations {
                out item scienceData : ScienceData;
            }

            action storeAndCompressData {
                in item scienceData : ScienceData;
                out item compressedScienceData : ScienceData;
            }

            action downlinkMissionData {
                in item compressedScienceData : ScienceData;
                out item downlink : RadioSignal;
            }

            action reportHealth {
                out item telemetry : TelemetryData;
            }
        }

        state def OperationalState {
            entry action initializeProbe;

            state LaunchConfiguration;
            state Commissioning;
            state Cruise;
            state ScienceObservation;
            state DataDownlink;
            state TrajectoryCorrection;
            state SafeMode;
            state EndOfMission;

            transition first LaunchConfiguration then Commissioning
                accept after 86400 [SI::s];

            transition Commissioning then Cruise
                accept CommandData
                if commandId == "COMMISSIONING_COMPLETE" and authenticated == true;

            transition Cruise then ScienceObservation
                accept CommandData
                if commandId == "BEGIN_SCIENCE_SEQUENCE" and authenticated == true;

            transition ScienceObservation then DataDownlink
                accept after 7200 [SI::s];

            transition DataDownlink then Cruise
                accept after 14400 [SI::s];

            transition Cruise then TrajectoryCorrection
                accept CommandData
                if commandId == "EXECUTE_TCM" and authenticated == true;

            transition TrajectoryCorrection then Cruise
                accept after 1800 [SI::s];

            transition Cruise then SafeMode
                accept TelemetryData
                if batteryStateOfCharge < 0.25 or faultCount > 3;

            transition ScienceObservation then SafeMode
                accept TelemetryData
                if batteryStateOfCharge < 0.25 or thermalMargin < 5 [SI::K];

            transition DataDownlink then SafeMode
                accept TelemetryData
                if faultCount > 3;

            transition SafeMode then Cruise
                accept CommandData
                if commandId == "RECOVER_NOMINAL_OPERATIONS" and authenticated == true;

            transition Cruise then EndOfMission
                accept CommandData
                if commandId == "TERMINATE_MISSION" and authenticated == true;
        }
    }

    part missionGroundSystem : DeepSpaceNetwork;
    part interplanetaryProbe : SpaceProbe;

    connect missionGroundSystem.radioPort to interplanetaryProbe.groundRadio;

    requirement def PrimaryFunctionRequirement {
        doc /* The space probe shall autonomously travel through deep space, maintain its own health, collect scientific observations of assigned targets, store and process the resulting data, and transmit mission data and telemetry to Earth. */

        subject probe : SpaceProbe;

        require constraint {
            probe.minimumDownlinkRate >= 50000 [SI::bit / SI::s]
        }

        require constraint {
            probe.designLife >= 315576000 [SI::s]
        }
    }

    requirement def PowerAvailabilityRequirement {
        doc /* The space probe shall provide regulated electrical power to all mission-critical subsystems during cruise, science observation, communication, and safe-mode operations. */

        subject probe : SpaceProbe;

        require constraint {
            probe.solarArray.endOfLifeGeneratedPower >= probe.scienceModePowerDemand
        }

        require constraint {
            probe.powerControlUnit.regulatedBusVoltage == 50 [SI::V]
        }
    }

    requirement def ScienceDataRequirement {
        doc /* The space probe shall collect scientific data with onboard instruments and preserve that data until it is successfully transmitted to the ground system. */

        subject probe : SpaceProbe;

        require constraint {
            probe.sciencePayload.observationDataRate >= 250000 [SI::bit / SI::s]
        }

        require constraint {
            probe.flightComputer.solidStateMemoryCapacity >= 2.0e12
        }
    }

    requirement def CommunicationRequirement {
        doc /* The space probe shall receive authenticated commands from Earth and transmit science data and health telemetry through a deep-space radio link. */

        subject probe : SpaceProbe;

        require constraint {
            probe.telecommunicationSystem.maximumDownlinkRate >= 2000000 [SI::bit / SI::s]
        }

        require constraint {
            probe.flightComputer.commandAuthenticationRequired == true
        }
    }

    requirement def AutonomyRequirement {
        doc /* The space probe shall enter safe mode without ground intervention when power, thermal, or fault conditions threaten mission survival. */

        subject probe : SpaceProbe;

        require constraint {
            probe.battery.minimumStateOfCharge >= 0.25
        }

        require constraint {
            probe.thermalControlSystem.minimumEquipmentTemperature <= 253 [SI::K]
        }

        require constraint {
            probe.thermalControlSystem.maximumEquipmentTemperature >= 323 [SI::K]
        }
    }

    requirement def NavigationAndPointingRequirement {
        doc /* The space probe shall estimate its trajectory and orient antennas, instruments, and solar arrays to support navigation, communication, science, and power generation. */

        subject probe : SpaceProbe;

        require constraint {
            probe.navigationSystem.positionKnowledgeAccuracy <= 1000 [SI::m]
        }

        require constraint {
            probe.attitudeControlSystem.pointingAccuracy <= 0.05
        }
    }

    satisfy PrimaryFunctionRequirement by interplanetaryProbe;
    satisfy PowerAvailabilityRequirement by interplanetaryProbe.powerControlUnit;
    satisfy ScienceDataRequirement by interplanetaryProbe.sciencePayload;
    satisfy CommunicationRequirement by interplanetaryProbe.telecommunicationSystem;
    satisfy AutonomyRequirement by interplanetaryProbe.flightComputer;
    satisfy NavigationAndPointingRequirement by interplanetaryProbe.attitudeControlSystem;
}