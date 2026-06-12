package UnattendedGroundSensorSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Probability : Real {
        doc /* Dimensionless likelihood in the closed interval [0,1]. */
    }

    attribute def ConfidenceScore : Real {
        doc /* Dimensionless confidence score in the closed interval [0,1]. */
    }

    attribute def BatteryStateOfCharge : Real {
        doc /* Battery state of charge as percent. */
        unit = "%";
    }

    attribute def DataRate : Real {
        doc /* Digital data throughput. */
        unit = "bit/s";
    }

    attribute def Latitude : Real {
        unit = "deg";
    }

    attribute def Longitude : Real {
        unit = "deg";
    }

    attribute def ClassificationLabel : String;

    item def SeismicWaveform {
        attribute sampleRate : Frequency;
        attribute peakAcceleration : Acceleration;
        attribute duration : Time;
    }

    item def AcousticWaveform {
        attribute sampleRate : Frequency;
        attribute soundPressureLevel : Real;
        attribute dominantFrequency : Frequency;
        attribute duration : Time;
    }

    item def MagneticDisturbance {
        attribute fluxDensityChange : MagneticFluxDensity;
        attribute duration : Time;
    }

    item def RawSensorFrame {
        attribute frameId : Integer;
        attribute timestamp : Time;
        item seismic : SeismicWaveform;
        item acoustic : AcousticWaveform;
        item magnetic : MagneticDisturbance;
    }

    item def DetectionReport {
        attribute reportId : Integer;
        attribute timestamp : Time;
        attribute targetClass : ClassificationLabel;
        attribute confidence : ConfidenceScore;
        attribute estimatedRange : Length;
        attribute bearing : Real {
            unit = "deg";
        }
        attribute nodeLatitude : Latitude;
        attribute nodeLongitude : Longitude;
    }

    item def HealthStatus {
        attribute timestamp : Time;
        attribute stateOfCharge : BatteryStateOfCharge;
        attribute enclosureTemperature : Temperature;
        attribute linkQuality : Probability;
        attribute faultCode : Integer;
    }

    item def CommandMessage {
        attribute commandId : Integer;
        attribute timestamp : Time;
        attribute commandName : String;
        attribute parameterValue : Real;
    }

    item def EncryptedPacket {
        attribute packetId : Integer;
        attribute timestamp : Time;
        attribute payloadBits : Integer;
        attribute authenticationTagValid : Boolean;
    }

    port def SeismicSensePort {
        out item sensedSeismic : SeismicWaveform;
    }

    port def AcousticSensePort {
        out item sensedAcoustic : AcousticWaveform;
    }

    port def MagneticSensePort {
        out item sensedMagnetic : MagneticDisturbance;
    }

    port def SensorFramePort {
        out item frameOut : RawSensorFrame;
        in item frameIn : RawSensorFrame;
    }

    port def ReportPort {
        out item reportOut : DetectionReport;
        in item reportIn : DetectionReport;
    }

    port def HealthPort {
        out item healthOut : HealthStatus;
        in item healthIn : HealthStatus;
    }

    port def CommandPort {
        in item commandIn : CommandMessage;
        out item commandOut : CommandMessage;
    }

    port def PacketPort {
        out item packetOut : EncryptedPacket;
        in item packetIn : EncryptedPacket;
    }

    port def PowerPort {
        out attribute suppliedVoltage : ElectricPotential;
        out attribute suppliedCurrent : ElectricCurrent;
    }

    part def SeismicSensor {
        attribute sensitivity : Real {
            unit = "V/(m/s^2)";
        }
        attribute noiseFloor : Acceleration;
        port sense : SeismicSensePort;
    }

    part def AcousticSensor {
        attribute sensitivity : Real {
            unit = "V/Pa";
        }
        attribute lowerBandLimit : Frequency;
        attribute upperBandLimit : Frequency;
        port sense : AcousticSensePort;
    }

    part def MagneticSensor {
        attribute sensitivity : Real {
            unit = "V/T";
        }
        attribute minimumDetectableFluxChange : MagneticFluxDensity;
        port sense : MagneticSensePort;
    }

    part def SensorFusionProcessor {
        attribute processingLatency : Time;
        attribute minimumDetectionConfidence : ConfidenceScore;
        port seismicIn : SeismicSensePort;
        port acousticIn : AcousticSensePort;
        port magneticIn : MagneticSensePort;
        port frameOut : SensorFramePort;
        port reportOut : ReportPort;

        action fuseAndClassify {
            in item seismic : SeismicWaveform;
            in item acoustic : AcousticWaveform;
            in item magnetic : MagneticDisturbance;
            out item report : DetectionReport;

            first start;
            then validateSignalQuality;
            then extractFeatures;
            then correlateModalities;
            then classifyTarget;
            then estimateLocation;
            then publishReport;
        }
    }

    part def RadioTransceiver {
        attribute transmitPower : Power;
        attribute receiveSensitivity : Power;
        attribute nominalDataRate : DataRate;
        attribute operatingFrequency : Frequency;
        port reportIn : ReportPort;
        port healthIn : HealthPort;
        port commandOut : CommandPort;
        port packetOut : PacketPort;
        port packetIn : PacketPort;
    }

    part def CryptographicModule {
        attribute keyAge : Time;
        attribute encryptionEnabled : Boolean;
        port plainReportIn : ReportPort;
        port plainHealthIn : HealthPort;
        port commandOut : CommandPort;
        port encryptedOut : PacketPort;
        port encryptedIn : PacketPort;

        action encryptAndAuthenticate {
            in item report : DetectionReport;
            out item packet : EncryptedPacket;
        }

        action decryptAndVerify {
            in item packet : EncryptedPacket;
            out item command : CommandMessage;
        }
    }

    part def PowerSubsystem {
        attribute batteryCapacity : ElectricCharge;
        attribute stateOfCharge : BatteryStateOfCharge;
        attribute nominalVoltage : ElectricPotential;
        attribute sleepPowerDraw : Power;
        attribute activePowerDraw : Power;
        port powerOut : PowerPort;
        port healthOut : HealthPort;
    }

    part def PositioningModule {
        attribute latitude : Latitude;
        attribute longitude : Longitude;
        attribute positionUncertainty : Length;
    }

    part def Enclosure {
        attribute ingressProtectionRating : String;
        attribute operatingLowTemperature : Temperature;
        attribute operatingHighTemperature : Temperature;
        attribute mass : Mass;
    }

    part def UnattendedGroundSensorNode {
        attribute nodeId : String;
        attribute deploymentLifetime : Time;
        attribute detectionRangePerson : Length;
        attribute detectionRangeVehicle : Length;

        part seismicSensor : SeismicSensor {
            attribute sensitivity = 2.5;
            attribute noiseFloor = 0.00002 [m/s^2];
        }

        part acousticSensor : AcousticSensor {
            attribute sensitivity = 0.012;
            attribute lowerBandLimit = 20 [Hz];
            attribute upperBandLimit = 8000 [Hz];
        }

        part magneticSensor : MagneticSensor {
            attribute sensitivity = 50000;
            attribute minimumDetectableFluxChange = 0.00000002 [T];
        }

        part fusionProcessor : SensorFusionProcessor {
            attribute processingLatency = 2 [s];
            attribute minimumDetectionConfidence = 0.75;
        }

        part crypto : CryptographicModule {
            attribute keyAge = 0 [s];
            attribute encryptionEnabled = true;
        }

        part radio : RadioTransceiver {
            attribute transmitPower = 2 [W];
            attribute nominalDataRate = 9600;
            attribute operatingFrequency = 915 [MHz];
        }

        part power : PowerSubsystem {
            attribute batteryCapacity = 72000 [C];
            attribute stateOfCharge = 100;
            attribute nominalVoltage = 12 [V];
            attribute sleepPowerDraw = 0.08 [W];
            attribute activePowerDraw = 3.5 [W];
        }

        part position : PositioningModule {
            attribute latitude = 38.8895;
            attribute longitude = -77.0353;
            attribute positionUncertainty = 5 [m];
        }

        part enclosure : Enclosure {
            attribute ingressProtectionRating = "IP67";
            attribute operatingLowTemperature = 233.15 [K];
            attribute operatingHighTemperature = 328.15 [K];
            attribute mass = 4.2 [kg];
        }

        port networkPackets : PacketPort;
        port remoteCommands : CommandPort;
        port nodeHealth : HealthPort;

        connect seismicSensor.sense to fusionProcessor.seismicIn;
        connect acousticSensor.sense to fusionProcessor.acousticIn;
        connect magneticSensor.sense to fusionProcessor.magneticIn;
        connect fusionProcessor.reportOut to crypto.plainReportIn;
        connect power.healthOut to crypto.plainHealthIn;
        connect crypto.encryptedOut to radio.packetIn;
        connect radio.packetOut to networkPackets;
        connect networkPackets to crypto.encryptedIn;
        connect crypto.commandOut to remoteCommands;
        connect power.healthOut to nodeHealth;

        state def NodeOperatingState {
            entry action initializeNode;
            state Dormant;
            state Monitoring;
            state Detecting;
            state Reporting;
            state LowPower;
            state Faulted;

            transition initial then Dormant;
            transition Dormant_to_Monitoring
                first Dormant
                accept CommandMessage
                if commandName == "ARM"
                then Monitoring;

            transition Monitoring_to_Detecting
                first Monitoring
                if seismicSensor.sense.sensedSeismic.peakAcceleration > 0.001 [m/s^2]
                then Detecting;

            transition Detecting_to_Reporting
                first Detecting
                if fusionProcessor.minimumDetectionConfidence <= 0.75
                then Reporting;

            transition Reporting_to_Monitoring
                first Reporting
                after 5 [s]
                then Monitoring;

            transition Monitoring_to_LowPower
                first Monitoring
                if power.stateOfCharge < 20
                then LowPower;

            transition LowPower_to_Monitoring
                first LowPower
                accept CommandMessage
                if commandName == "WAKE"
                then Monitoring;

            transition any_to_Faulted
                first Monitoring
                if power.stateOfCharge < 5
                then Faulted;
        }
    }

    part def SensorGateway {
        attribute gatewayId : String;
        attribute maxNodeCount : Integer;
        attribute backhaulDataRate : DataRate;

        port nodePacketIn : PacketPort;
        port commandToNode : CommandPort;
        port reportOut : ReportPort;
        port healthOut : HealthPort;

        action receiveForwardAndStore {
            in item packet : EncryptedPacket;
            out item report : DetectionReport;
            out item health : HealthStatus;

            first receivePacket;
            then verifyOrigin;
            then decryptPayload;
            then correlateWithOtherNodes;
            then forwardToOperator;
            then archiveEvent;
        }
    }

    part def OperatorControlStation {
        attribute stationId : String;
        attribute operatorCount : Integer;
        port reportIn : ReportPort;
        port healthIn : HealthPort;
        port commandOut : CommandPort;

        action assessDetection {
            in item report : DetectionReport;
            out attribute alertAccepted : Boolean;

            first displayDetection;
            then compareWithRulesOfEngagement;
            then requestConfirmationIfNeeded;
            then logDecision;
        }
    }

    part def UnattendedGroundSensorNetwork {
        doc /* A distributed unattended ground sensor system that covertly monitors an area, detects ground activity using seismic, acoustic, and magnetic signatures, classifies likely target type, and reports validated detections to a remote operator without continuous human presence. */

        attribute monitoredAreaRadius : Length;
        attribute requiredOperationalDuration : Time;
        attribute requiredDetectionProbability : Probability;
        attribute requiredFalseAlarmRatePerDay : Real {
            unit = "1/d";
        }

        part node1 : UnattendedGroundSensorNode {
            attribute nodeId = "UGS-N-001";
            attribute deploymentLifetime = 30 [d];
            attribute detectionRangePerson = 50 [m];
            attribute detectionRangeVehicle = 250 [m];
        }

        part node2 : UnattendedGroundSensorNode {
            attribute nodeId = "UGS-N-002";
            attribute deploymentLifetime = 30 [d];
            attribute detectionRangePerson = 50 [m];
            attribute detectionRangeVehicle = 250 [m];
        }

        part node3 : UnattendedGroundSensorNode {
            attribute nodeId = "UGS-N-003";
            attribute deploymentLifetime = 30 [d];
            attribute detectionRangePerson = 50 [m];
            attribute detectionRangeVehicle = 250 [m];
        }

        part gateway : SensorGateway {
            attribute gatewayId = "UGS-GW-01";
            attribute maxNodeCount = 64;
            attribute backhaulDataRate = 1000000;
        }

        part controlStation : OperatorControlStation {
            attribute stationId = "UGS-OCS-01";
            attribute operatorCount = 2;
        }

        connect node1.networkPackets to gateway.nodePacketIn;
        connect node2.networkPackets to gateway.nodePacketIn;
        connect node3.networkPackets to gateway.nodePacketIn;
        connect gateway.reportOut to controlStation.reportIn;
        connect gateway.healthOut to controlStation.healthIn;
        connect controlStation.commandOut to gateway.commandToNode;
        connect gateway.commandToNode to node1.remoteCommands;
        connect gateway.commandToNode to node2.remoteCommands;
        connect gateway.commandToNode to node3.remoteCommands;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall autonomously monitor a deployed ground area and report probable personnel or vehicle movement to a remote operator without local human attendance. */
        attribute minimumDetectionProbability : Probability = 0.90;
        attribute maximumReportLatency : Time = 10 [s];
    }

    requirement def MultiPhenomenologyDetectionRequirement {
        doc /* Each sensor node shall combine at least two independent sensing phenomenologies before issuing a target detection report unless commanded into single-sensor diagnostic mode. */
        attribute minimumModalities : Integer = 2;
    }

    requirement def ClassificationRequirement {
        doc /* The system shall classify detected activity as person, wheeled vehicle, tracked vehicle, animal, or unknown with an associated confidence score. */
        attribute minimumClassificationConfidence : ConfidenceScore = 0.75;
    }

    requirement def LowPowerRequirement {
        doc /* Each deployed sensor node shall support low-power unattended operation for not less than thirty days while armed. */
        attribute minimumOperationalDuration : Time = 30 [d];
        attribute maximumSleepPower : Power = 0.10 [W];
    }

    requirement def SecureReportingRequirement {
        doc /* Detection reports and command messages shall be encrypted and authenticated before transmission over the radio link. */
        attribute authenticationRequired : Boolean = true;
        attribute encryptionRequired : Boolean = true;
    }

    requirement def HealthMonitoringRequirement {
        doc /* Each node shall periodically report battery state, enclosure temperature, link quality, and fault status to the gateway. */
        attribute maximumHealthReportInterval : Time = 3600 [s];
    }

    requirement def EnvironmentalRequirement {
        doc /* Each node shall operate while buried or concealed outdoors across the specified environmental range. */
        attribute minimumIngressProtection : String = "IP67";
        attribute lowTemperatureLimit : Temperature = 233.15 [K];
        attribute highTemperatureLimit : Temperature = 328.15 [K];
    }

    satisfy PrimaryFunctionRequirement by UnattendedGroundSensorNetwork;
    satisfy MultiPhenomenologyDetectionRequirement by SensorFusionProcessor;
    satisfy ClassificationRequirement by SensorFusionProcessor;
    satisfy LowPowerRequirement by PowerSubsystem;
    satisfy SecureReportingRequirement by CryptographicModule;
    satisfy HealthMonitoringRequirement by PowerSubsystem;
    satisfy EnvironmentalRequirement by Enclosure;

    constraint def DetectionLatencyConstraint {
        in processingLatency : Time;
        in communicationLatency : Time;
        in maximumReportLatency : Time;
        processingLatency + communicationLatency <= maximumReportLatency;
    }

    constraint def BatteryEnduranceConstraint {
        in capacity : ElectricCharge;
        in voltage : ElectricPotential;
        in averagePower : Power;
        in requiredDuration : Time;
        capacity * voltage >= averagePower * requiredDuration;
    }

    analysis def MissionCoverageAnalysis {
        subject network : UnattendedGroundSensorNetwork;
        objective verifyCoverage;
        constraint coverageRadius {
            network.monitoredAreaRadius <= 250 [m];
        }
        constraint detectionPerformance {
            network.requiredDetectionProbability >= 0.90;
        }
        constraint falseAlarmPerformance {
            network.requiredFalseAlarmRatePerDay <= 3;
        }
    }

    part deployedUGSNetwork : UnattendedGroundSensorNetwork {
        attribute monitoredAreaRadius = 250 [m];
        attribute requiredOperationalDuration = 30 [d];
        attribute requiredDetectionProbability = 0.90;
        attribute requiredFalseAlarmRatePerDay = 3;
    }
}