package DaintreeLightingControl {
    public import ISQ::*;
    public import ScalarValues::*;

    // ===== Value Types =====
    value type Illuminance {
        > :> Real;
        unit "lx";
    }
    value type DimLevel {
        > :> Real;
        min = 0.0;
        max = 100.0;
        unit "%";
    }
    value type PowerConsumption {
        > :> Real;
        unit "W";
    }
    value type Energy {
        > :> Real;
        unit "J";
    }
    value type TimeDuration {
        > :> Real;
        unit "s";
    }
    value type NodeAddress {
        > :> Integer;
    }
    value type SignalStrength {
        > :> Real;
        unit "dBm";
    }

    // ===== Enumerations =====
    enum OccupancyStatus { occupied; vacant; unknown; }
    enum FixtureState { on; off; fault; }
    enum NetworkRole { coordinator; router; endDevice; }
    enum ControlMode { manual; auto; calibration; emergency; }

    // ===== Item Types =====
    item def OccupancyReport {
        attribute status : OccupancyStatus;
        attribute sensorId : NodeAddress;
        attribute timestamp : TimeDuration;
    }
    item def DaylightReport {
        attribute lightLevel : Illuminance;
        attribute sensorId : NodeAddress;
        attribute timestamp : TimeDuration;
    }
    item def DimmingCommand {
        attribute targetFixture : NodeAddress;
        attribute dimLevel : DimLevel;
        attribute commandId : Integer;
    }
    item def PowerReport {
        attribute fixtureId : NodeAddress;
        attribute instantaneousPower : PowerConsumption;
        attribute cumulativeEnergy : Energy;
        attribute timestamp : TimeDuration;
    }
    item def NetworkBeacon {
        attribute sourceId : NodeAddress;
        attribute role : NetworkRole;
        attribute rssi : SignalStrength;
        attribute hopCount : Integer;
    }
    item def Heartbeat {
        attribute nodeId : NodeAddress;
        attribute uptime : TimeDuration;
        attribute batteryLevel : Real;
    }
    item def ConfigurationUpdate {
        attribute targetNode : NodeAddress;
        attribute parameterSet : String;
        attribute version : Integer;
    }
    item def SystemAlert {
        attribute alertType : String;
        attribute sourceNode : NodeAddress;
        attribute severity : Integer;
        attribute description : String;
    }

    // ===== Port Definitions =====
    port def WirelessMeshPort {
        out item beacons : NetworkBeacon;
        in item incomingBeacons : NetworkBeacon;
        out item occupancyData : OccupancyReport;
        out item daylightData : DaylightReport;
        out item powerData : PowerReport;
        in item dimmingCommands : DimmingCommand;
        out item heartbeats : Heartbeat;
        in item configUpdates : ConfigurationUpdate;
        out item alerts : SystemAlert;
    }

    port def BMSIntegrationPort {
        out item powerReports : PowerReport;
        out item systemAlerts : SystemAlert;
        in item configUpdates : ConfigurationUpdate;
        out item statusReports : String;
    }

    port def FixtureControlPort {
        in item dimmingCommands : DimmingCommand;
        out item powerReports : PowerReport;
    }

    port def SensorOutputPort {
        out item occupancyData : OccupancyReport;
        out item daylightData : DaylightReport;
    }

    // ===== Interfaces =====
    interface def WirelessMeshLink {
        end source : WirelessMeshPort;
        end destination : WirelessMeshPort;
    }
    interface def GatewayBMSLink {
        end gatewaySide : BMSIntegrationPort;
        end bmsSide : BMSIntegrationPort;
    }

    // ===== Requirements =====
    requirement def EnergyEfficiencyRequirement {
        doc "The system shall reduce lighting energy consumption by at least 50% compared to non-dimmed baseline."
        attribute targetReduction : Real = 0.5;
        require {
            subject :> PowerConsumption;
        }
    }
    requirement def OccupancyResponseRequirement {
        doc "The system shall turn off lights within 30 seconds of a space becoming vacant."
        attribute maxVacantTimeout : TimeDuration = 30.0 [s];
    }
    requirement def DaylightHarvestingRequirement {
        doc "The system shall adjust fixture dimming levels based on measured ambient daylight to maintain a target illuminance."
        attribute targetIlluminance : Illuminance = 500.0 [lx];
        attribute tolerance : Illuminance = 50.0 [lx];
    }
    requirement def MeshReliabilityRequirement {
        doc "The wireless mesh network shall maintain connectivity with 99.9% uptime using self-healing routing."
        attribute minUptime : Real = 0.999;
    }
    requirement def FixtureAddressabilityRequirement {
        doc "Each lighting fixture shall be individually addressable on the network for independent dimming control."
    }
    requirement def PowerMeteringRequirement {
        doc "Each fixture shall report instantaneous power consumption and cumulative energy at least every 60 seconds."
        attribute maxReportInterval : TimeDuration = 60.0 [s];
    }
    requirement def SensorLatencyRequirement {
        doc "Sensor data shall reach the Area Controller within 5 seconds of detection."
        attribute maxLatency : TimeDuration = 5.0 [s];
    }

    requirement def DaintreeSystemRequirements {
        satisfy EnergyEfficiencyRequirement;
        satisfy OccupancyResponseRequirement;
        satisfy DaylightHarvestingRequirement;
        satisfy MeshReliabilityRequirement;
        satisfy FixtureAddressabilityRequirement;
        satisfy PowerMeteringRequirement;
        satisfy SensorLatencyRequirement;
    }

    // ===== Part Definitions =====

    part def ControllableBallast {
        attribute currentDimLevel : DimLevel = 0.0;
        attribute minDimLevel : DimLevel = 1.0;
        attribute maxDimLevel : DimLevel = 100.0;
        attribute rampRate : Real = 5.0; // % per second

        action def RampToLevel(targetLevel : DimLevel) {
            // Gradually ramp dim level to target
        }

        perform action setDimLevel {
            in dimLevel : DimLevel;
            then action applyRamp {
                in target : DimLevel = dimLevel;
            }
        }
    }

    part def PowerMeter {
        attribute instantaneousPower : PowerConsumption = 0.0 [W];
        attribute cumulativeEnergy : Energy = 0.0 [J];
        attribute reportInterval : TimeDuration = 60.0 [s];
        attribute lastReportTime : TimeDuration = 0.0 [s];

        action def MeasurePower {
            out power : PowerConsumption;
        }
        action def AccumulateEnergy {
            in power : PowerConsumption;
            in duration : TimeDuration;
            out energy : Energy;
        }
        action def GenerateReport {
            in power : PowerConsumption;
            in energy : Energy;
            out report : PowerReport;
        }

        perform action measure {
            out power : PowerConsumption;
            then action accumulate {
                in power : PowerConsumption;
                in duration : TimeDuration;
                out energy : Energy;
            }
            then action report {
                in power : PowerConsumption;
                in energy : Energy;
                out report : PowerReport;
            }
        }
    }

    part def LightingFixture {
        attribute fixtureId : NodeAddress;
        attribute state : FixtureState = off;
        attribute ratedPower : PowerConsumption;
        attribute currentDimLevel : DimLevel = 0.0;
        attribute targetIlluminance : Illuminance = 500.0 [lx];

        port meshPort : WirelessMeshPort;
        port controlPort : FixtureControlPort;

        part ballast : ControllableBallast {
            attribute currentDimLevel :>> currentDimLevel;
        }
        part powerMeter : PowerMeter;

        satisfy FixtureAddressabilityRequirement;
        satisfy PowerMeteringRequirement;

        action def ProcessDimmingCommand {
            in command : DimmingCommand;
            out powerReport : PowerReport;
        }

        perform action receiveCommand {
            in command : DimmingCommand via controlPort.dimmingCommands;
            then if command.targetFixture == fixtureId {
                then action applyDimming {
                    in dimLevel : DimLevel = command.dimLevel;
                    then action updateBallast {
                        in level : DimLevel = dimLevel;
                        ref ballast.setDimLevel(level);
                    }
                    then action updateState {
                        if dimLevel > 0.0 {
                            then set state = on;
                        } else {
                            then set state = off;
                        }
                    }
                }
                then action measurePower {
                    ref powerMeter.measure();
                }
                then action sendReport {
                    out report : PowerReport via meshPort.powerData;
                }
            }
        }
    }

    part def OccupancySensor {
        attribute sensorId : NodeAddress;
        attribute currentStatus : OccupancyStatus = unknown;
        attribute motionTimeout : TimeDuration = 15.0 [s];
        attribute lastMotionTime : TimeDuration = 0.0 [s];
        attribute detectionRange : Real = 12.0; // meters
        attribute sensitivity : Real = 0.8;

        port meshPort : WirelessMeshPort;
        port sensorOutput : SensorOutputPort;

        state def OccupancyDetectionStateMachine {
            entry action initialize { set currentStatus = unknown; }

            state unknown {
                entry action broadcastUnknown {
                    out report : OccupancyReport via meshPort.occupancyData;
                }
                transition to occupied on motionDetected;
            }
            state occupied {
                entry action broadcastOccupied {
                    out report : OccupancyReport {
                        attribute status = OccupancyStatus::occupied;
                        attribute sensorId = sensorId;
                    } via meshPort.occupancyData;
                }
                transition to vacant on noMotionTimeout {
                    guard lastMotionTime + motionTimeout < currentTime;
                }
            }
            state vacant {
                entry action broadcastVacant {
                    out report : OccupancyReport {
                        attribute status = OccupancyStatus::vacant;
                        attribute sensorId = sensorId;
                    } via meshPort.occupancyData;
                }
                transition to occupied on motionDetected;
            }
        }

        exhibit OccupancyDetectionStateMachine;

        action def DetectMotion {
            out motionDetected : Boolean;
        }
        action def EvaluateTimeout {
            in lastMotion : TimeDuration;
            in timeout : TimeDuration;
            out timedOut : Boolean;
        }

        perform action detect {
            out motionDetected : Boolean;
            then if motionDetected {
                then action updateMotionTime {
                    set lastMotionTime = currentTime;
                }
                then action sendOccupancyReport {
                    out report : OccupancyReport {
                        attribute status = OccupancyStatus::occupied;
                        attribute sensorId = sensorId;
                        attribute timestamp = currentTime;
                    } via sensorOutput.occupancyData;
                }
            } else {
                then action checkTimeout {
                    in lastMotion : TimeDuration = lastMotionTime;
                    in timeout : TimeDuration = motionTimeout;
                    out timedOut : Boolean;
                    then if timedOut {
                        then action sendVacantReport {
                            out report : OccupancyReport {
                                attribute status = OccupancyStatus::vacant;
                                attribute sensorId = sensorId;
                                attribute timestamp = currentTime;
                            } via sensorOutput.occupancyData;
                        }
                    }
                }
            }
        }
    }

    part def DaylightSensor {
        attribute sensorId : NodeAddress;
        attribute measuredIlluminance : Illuminance = 0.0 [lx];
        attribute reportInterval : TimeDuration = 30.0 [s];
        attribute maxRange : Illuminance = 10000.0 [lx];
        attribute calibrationOffset : Illuminance = 0.0 [lx];

        port meshPort : WirelessMeshPort;
        port sensorOutput : SensorOutputPort;

        action def MeasureIlluminance {
            out illuminance : Illuminance;
        }
        action def SendDaylightReport {
            in level : Illuminance;
            out report : DaylightReport;
        }

        perform action measure {
            out rawIlluminance : Illuminance;
            then action calibrate {
                in raw : Illuminance = rawIlluminance;
                out calibrated : Illuminance = raw + calibrationOffset;
            }
            then action report {
                in level : Illuminance = calibrated;
                out report : DaylightReport {
                    attribute lightLevel = level;
                    attribute sensorId = sensorId;
                    attribute timestamp = currentTime;
                } via sensorOutput.daylightData;
            }
        }
    }

    part def WirelessAreaController {
        attribute controllerId : NodeAddress;
        attribute zoneId : String;
        attribute controlMode : ControlMode = auto;
        attribute targetIlluminance : Illuminance = 500.0 [lx];
        attribute minDimLevel : DimLevel = 10.0;
        attribute maxDimLevel : DimLevel = 100.0;
        attribute vacantDimLevel : DimLevel = 0.0;
        attribute occupiedDimLevel : DimLevel = 100.0;
        attribute daylightThreshold : Illuminance = 300.0 [lx];
        attribute highDaylightThreshold : Illuminance = 700.0 [lx];
        attribute vacantTimeout : TimeDuration = 30.0 [s];
        attribute lastOccupancyStatus : OccupancyStatus = unknown;
        attribute lastDaylightLevel : Illuminance = 0.0 [lx];
        attribute managedFixtures : NodeAddress[0..*];

        port meshPort : WirelessMeshPort;

        satisfy OccupancyResponseRequirement {
            attribute maxVacantTimeout = vacantTimeout;
        }
        satisfy DaylightHarvestingRequirement {
            attribute targetIlluminance = targetIlluminance;
        }
        satisfy SensorLatencyRequirement;

        action def ComputeDimLevel {
            in occupancy : OccupancyStatus;
            in daylight : Illuminance;
            in target : Illuminance;
            out dimLevel : DimLevel;
        }

        action def ProcessSensorData {
            in occupancyReport : OccupancyReport;
            in daylightReport : DaylightReport;
            out dimmingCommands : DimmingCommand[0..*];
        }

        action def SendDimmingCommands {
            in commands : DimmingCommand[0..*];
        }

        perform action receiveSensorData {
            in occupancyReport : OccupancyReport via meshPort.occupancyData;
            in daylightReport : DaylightReport via meshPort.daylightData;
            then action updateState {
                set lastOccupancyStatus = occupancyReport.status;
                set lastDaylightLevel = daylightReport.lightLevel;
            }
            then action computeDimming {
                in occupancy : OccupancyStatus = lastOccupancyStatus;
                in daylight : Illuminance = lastDaylightLevel;
                in target : Illuminance = targetIlluminance;
                out dimLevel : DimLevel;
                // Control logic:
                // If vacant -> dim 0
                // If occupied and high daylight -> dim low
                // If occupied and low daylight -> dim high
                // If occupied and medium daylight -> proportional
                if occupancy == OccupancyStatus::vacant {
                    then set dimLevel = vacantDimLevel;
                } else if occupancy == OccupancyStatus::occupied {
                    then if daylight >= highDaylightThreshold {
                        then set dimLevel = minDimLevel;
                    } else if daylight <= daylightThreshold {
                        then set dimLevel = maxDimLevel;
                    } else {
                        then action proportionalDim {
                            in dl : Illuminance = daylight;
                            in dlThresh : Illuminance = daylightThreshold;
                            in dhThresh : Illuminance = highDaylightThreshold;
                            out level : DimLevel;
                            // Linear interpolation between thresholds
                            set level = maxDimLevel - ((dl - dlThresh) / (dhThresh - dlThresh)) * (maxDimLevel - minDimLevel);
                        }
                        then set dimLevel = proportionalDim.level;
                    }
                } else {
                    then set dimLevel = minDimLevel;
                }
            }
            then action generateCommands {
                in level : DimLevel = computeDimming.dimLevel;
                in fixtures : NodeAddress[0..*] = managedFixtures;
                out commands : DimmingCommand[0..*];
                // Generate one command per managed fixture
            }
            then action sendCommands {
                in commands : DimmingCommand[0..*] = generateCommands.commands;
                out dimmingCommands : DimmingCommand via meshPort.dimmingCommands;
            }
        }

        state def ControllerStateMachine {
            entry action initController {
                set controlMode = ControlMode::auto;
            }

            state autoMode {
                entry action enableAutoControl;
                transition to manualMode on manualOverride;
                transition to emergencyMode on emergencySignal;
            }
            state manualMode {
                entry action enableManualControl;
                transition to autoMode on autoRestore;
                transition to emergencyMode on emergencySignal;
            }
            state emergencyMode {
                entry action enableFullBrightness {
                    // Set all fixtures to max
                }
                transition to autoMode on emergencyClear;
            }
        }

        exhibit ControllerStateMachine;
    }

    part def NetworkGateway {
        attribute gatewayId : NodeAddress;
        attribute networkRole : NetworkRole = coordinator;
        attribute managedNodes : NodeAddress[0..*];
        attribute maxNodes : Integer = 500;
        attribute heartbeatInterval : TimeDuration = 120.0 [s];
        attribute firmwareVersion : String = "3.2.1";

        port meshPort : WirelessMeshPort;
        port bmsPort : BMSIntegrationPort;

        satisfy MeshReliabilityRequirement;

        action def CoordinateNetwork {
            in beacons : NetworkBeacon[0..*];
            out routingUpdates : ConfigurationUpdate[0..*];
        }

        action def ManageHeartbeats {
            in heartbeats : Heartbeat[0..*];
            out alerts : SystemAlert[0..*];
        }

        action def BridgeToBMS {
            in powerReports : PowerReport[0..*];
            in alerts : SystemAlert[0..*];
            out statusReports : String[0..*];
            in configUpdates : ConfigurationUpdate[0..*];
        }

        perform action coordinate {
            in beacons : NetworkBeacon[0..*] via meshPort.incomingBeacons;
            out routingUpdates : ConfigurationUpdate[0..*] via meshPort.configUpdates;
        }
        perform action monitorHeartbeats {
            in heartbeats : Heartbeat[0..*] via meshPort.heartbeats;
            out alerts : SystemAlert[0..*] via meshPort.alerts;
        }
        perform action bridge {
            in powerReports : PowerReport[0..*] via meshPort.powerData;
            in alerts : SystemAlert[0..*] via meshPort.alerts;
            out statusReports : String[0..*] via bmsPort.statusReports;
            in configUpdates : ConfigurationUpdate[0..*] via bmsPort.configUpdates;
        }

        state def GatewayStateMachine {
            entry action initializeNetwork {
                set networkRole = NetworkRole::coordinator;
            }

            state networkUp {
                entry action broadcastBeacon {
                    out beacon : NetworkBeacon {
                        attribute sourceId = gatewayId;
                        attribute role = NetworkRole::coordinator;
                        attribute rssi = 0.0 [dBm];
                        attribute hopCount = 0;
                    } via meshPort.beacons;
                }
                transition to networkDegraded on nodeFailure;
                transition to networkDown on criticalFailure;
            }
            state networkDegraded {
                entry action initiateSelfHealing;
                transition to networkUp on healingComplete;
                transition to networkDown on criticalFailure;
            }
            state networkDown {
                entry action alertBMS {
                    out alert : SystemAlert {
                        attribute alertType = "NetworkDown";
                        attribute sourceNode = gatewayId;
                        attribute severity = 3;
                        attribute description = "Mesh network is down";
                    } via bmsPort.systemAlerts;
                }
                transition to networkUp on manualRecovery;
            }
        }

        exhibit GatewayStateMachine;
    }

    part def WirelessMeshNetwork {
        attribute networkId : String = "DaintreeMesh-001";
        attribute channel : Integer = 15;
        attribute encryptionEnabled : Boolean = true;
        attribute maxHops : Integer = 8;

        part gateway : NetworkGateway;
        part controllers : WirelessAreaController[0..*];
        part fixtures : LightingFixture[0..*];
        part occupancySensors : OccupancySensor[0..*];
        part daylightSensors : DaylightSensor[0..*];

        connection meshLinks : WirelessMeshLink connect gateway.meshPort to controllers.meshPort;
        connection controllerToFixtureLinks : WirelessMeshLink connect controllers.meshPort to fixtures.meshPort;
        connection controllerToOccupancyLinks : WirelessMeshLink connect controllers.meshPort to occupancySensors.meshPort;
        connection controllerToDaylightLinks : WirelessMeshLink connect controllers.meshPort to daylightSensors.meshPort;
        connection fixtureToFixtureLinks : WirelessMeshLink connect fixtures.meshPort to fixtures.meshPort;
        connection sensorToSensorLinks : WirelessMeshLink connect occupancySensors.meshPort to daylightSensors.meshPort;
    }

    // ===== Top-Level System =====
    part def DaintreeLightingSystem {
        attribute systemName : String = "Daintree Networks Lighting Control System";
        attribute buildingId : String;
        attribute installationDate : String;
        attribute totalZones : Integer;

        satisfy DaintreeSystemRequirements;

        part meshNetwork : WirelessMeshNetwork {
            part gateway : NetworkGateway;
            part zoneControllers : WirelessAreaController[1..*];
            part fixtures : LightingFixture[1..*];
            part occSensors : OccupancySensor[1..*];
            part daySensors : DaylightSensor[1..*];
        }

        // External interface to Building Management System
        port bmsInterface : BMSIntegrationPort;

        connection gatewayBMS : GatewayBMSLink connect meshNetwork.gateway.bmsPort to bmsInterface;

        // Example zone configuration
        part def ZoneConfiguration {
            attribute zoneName : String;
            attribute zoneId : String;
            ref controller : WirelessAreaController;
            ref fixtures : LightingFixture[1..*];
            ref occupancySensors : OccupancySensor[1..*];
            ref daylightSensors : DaylightSensor[0..*];
        }

        attribute zones : ZoneConfiguration[1..*];

        action def SystemStartup {
            then action initializeGateway {
                ref meshNetwork.gateway.initializeNetwork();
            }
            then action discoverNodes {
                // Gateway discovers all network nodes
            }
            then action assignAddresses {
                // Assign network addresses to all devices
            }
            then action configureControllers {
                // Push zone configurations to area controllers
            }
            then action verifyConnectivity {
                // Confirm all nodes are reachable
            }
            then action enableAutomation {
                // Switch controllers to auto mode
            }
        }

        action def SystemShutdown {
            then action dimAllFixtures {
                // Gradually dim all fixtures to 0
            }
            then action closeGatewayConnection {
                // Close BMS connection
            }
            then action powerDownNetwork {
                // Power down mesh network
            }
        }

        perform action startup : SystemStartup;
        perform action shutdown : SystemShutdown;
    }
}
