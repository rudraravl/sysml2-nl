package UnattendedGroundSensorSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    enum def TargetCategory {
        personnel;
        lightVehicle;
        heavyVehicle;
        animal;
        unknown;
    }

    enum def SeverityLevel {
        routine;
        moderate;
        high;
        critical;
    }

    enum def NodeModeKind {
        activeSurveillance;
        standby;
        lowPower;
    }

    enum def SensorKind {
        seismic;
        acoustic;
        passiveInfrared;
        magnetic;
    }

    attribute def GeospatialPosition {
        attribute latitude : ScalarValues::Real;
        attribute longitude : ScalarValues::Real;
        attribute altitude : ISQ::LengthValue;
    }

    attribute def SensorSample {
        attribute sensorKind : SensorKind;
        attribute timestamp : ISQ::TimeValue;
        attribute amplitude : ScalarValues::Real;
        attribute confidence : ScalarValues::Real;
    }

    attribute def TargetClassification {
        attribute category : TargetCategory;
        attribute confidence : ScalarValues::Real;
        attribute timestamp : ISQ::TimeValue;
    }

    attribute def TargetAlert {
        attribute alertId : String;
        attribute category : TargetCategory;
        attribute severity : SeverityLevel;
        attribute confidence : ScalarValues::Real;
        attribute detectionTime : ISQ::TimeValue;
        attribute location : GeospatialPosition;
        attribute reportingNodeId : String;
    }

    attribute def BatteryStatus {
        attribute chargeLevel : ScalarValues::Real;
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute temperature : ISQ::TemperatureValue;
    }

    attribute def CommandMessage {
        attribute targetNodeId : String;
        attribute desiredMode : NodeModeKind;
    }

    attribute def TransmissionComplete;

    attribute def SigActivate;
    attribute def SigDeactivate;
    attribute def SigEnterLowPower;
    attribute def SigExitLowPower;

    port def SensorDataPort {
        out attribute sample : SensorSample;
    }

    port def ClassificationPort {
        out attribute classification : TargetClassification;
    }

    port def AlertPort {
        out attribute alert : TargetAlert;
    }

    port def BatteryStatusPort {
        out attribute status : BatteryStatus;
    }

    port def PowerControlPort {
        out attribute mode : NodeModeKind;
    }

    port def SolarPowerPort {
        out attribute power : ISQ::PowerValue;
    }

    port def CommandPort {
        in attribute command : CommandMessage;
    }

    port def RfPort {
        in attribute incomingAlert : TargetAlert;
        out attribute outgoingAlert : TargetAlert;
    }

    requirement def LongDurationAutonomy {
        doc /* Each sensor node shall operate autonomously for at least 90 days without maintenance under nominal solar conditions. */
        attribute minimumDurationDays : ScalarValues::Integer = 90;
    }

    requirement def AutonomousPerimeterSurveillance {
        doc /* The UGS network shall autonomously detect, classify, and report ground-based intrusions along a perimeter without operator intervention. */
    }

    requirement def MultisensorFusionReduction {
        doc /* Each node shall fuse data from seismic, acoustic, passive infrared, and magnetic sensors to classify targets and reduce false alarms caused by weather or non-threatening wildlife. */
    }

    requirement def SecureRFMeshReporting {
        doc /* Nodes shall transmit high-confidence alerts over a secure RF mesh network to the central command center. */
    }

    requirement def LowPowerManagement {
        doc /* Each node shall automatically manage active surveillance, standby, and low-power modes based on battery level and sensor activity to conserve energy. */
    }

    action def FuseSensorData {
        in seismic : SensorSample;
        in acoustic : SensorSample;
        in pir : SensorSample;
        in magnetic : SensorSample;
        out classification : TargetClassification;
        first start;
        then action correlateSeismicAcoustic;
        then action correlatePirMagnetic;
        then action determineTargetCategory;
        then done;
    }

    action def GenerateAlert {
        in classification : TargetClassification;
        in location : GeospatialPosition;
        in nodeId : String;
        out alert : TargetAlert;
        first start;
        then action determineSeverity;
        then action assembleAlertMessage;
        then done;
    }

    action def TransmitAlert {
        in alert : TargetAlert;
        out completion : TransmissionComplete;
        first start;
        then action encryptAlert;
        then action sendAlert;
        then done;
    }

    action def DetectGroundVibration {
        out sample : SensorSample;
        first start;
        then action senseVibration;
        then action filterSignal;
        then done;
    }

    action def ListenForSound {
        out sample : SensorSample;
        first start;
        then action captureAudio;
        then action identifySignature;
        then done;
    }

    action def DetectHeatSignature {
        out sample : SensorSample;
        first start;
        then action senseInfrared;
        then action validateMovement;
        then done;
    }

    action def DetectMetalMass {
        out sample : SensorSample;
        first start;
        then action senseMagneticField;
        then action compareThreshold;
        then done;
    }

    action def ReportBatteryStatus {
        out status : BatteryStatus;
        first start;
        then action measureCharge;
        then action measureVoltage;
        then action measureTemperature;
        then done;
    }

    action def GeneratePower {
        out power : ISQ::PowerValue;
        first start;
        then action captureSunlight;
        then action convertPhotovoltaic;
        then done;
    }

    action def MonitorPower {
        in status : BatteryStatus;
        out mode : NodeModeKind;
        first start;
        then action evaluateBatteryLevel;
        then action selectOperatingMode;
        then done;
    }

    action def ShowAlert {
        in alert : TargetAlert;
        first start;
        then action renderAlert;
        then action acknowledgeOperator;
        then done;
    }

    action def StoreAlertRecord {
        in alert : TargetAlert;
        first start;
        then action persistAlert;
        then done;
    }

    action def RouteAlert {
        in alert : TargetAlert;
        first start;
        then action lookUpRoute;
        then action forwardToNextHop;
        then done;
    }

    part def Sensor {
        port dataOut : SensorDataPort;
        port modeIn : PowerControlPort;
    }

    part def SeismicSensor :> Sensor {
        attribute sensitivity : ScalarValues::Real;
        perform action detectGroundVibration : DetectGroundVibration;
    }

    part def AcousticSensor :> Sensor {
        attribute frequencyRange : ScalarValues::Real;
        perform action listenForSound : ListenForSound;
    }

    part def PassiveInfraredSensor :> Sensor {
        attribute detectionRange : ISQ::LengthValue;
        perform action detectHeatSignature : DetectHeatSignature;
    }

    part def MagneticSensor :> Sensor {
        attribute detectionThreshold : ScalarValues::Real;
        perform action detectMetalMass : DetectMetalMass;
    }

    part def SignalProcessor {
        port seismicIn : SensorDataPort;
        port acousticIn : SensorDataPort;
        port pirIn : SensorDataPort;
        port magneticIn : SensorDataPort;
        port classificationOut : ClassificationPort;
        port modeIn : PowerControlPort;
        attribute highConfidenceThreshold : ScalarValues::Real = 0.85;
        perform action fuseSensorData : FuseSensorData;
        exhibit state processingStates {
            entry; then idle;
            state idle;
            transition t_seismic
                first idle
                accept sample : SensorSample via seismicIn
                then fusing;
            transition t_acoustic
                first idle
                accept sample : SensorSample via acousticIn
                then fusing;
            transition t_pir
                first idle
                accept sample : SensorSample via pirIn
                then fusing;
            transition t_magnetic
                first idle
                accept sample : SensorSample via magneticIn
                then fusing;
            state fusing {
                do fuseSensorData;
            }
            transition fusing_high_confidence
                first fusing
                accept classification : TargetClassification
                if classification.confidence >= highConfidenceThreshold
                do send classification to classificationOut
                then idle;
            transition fusing_low_confidence
                first fusing
                accept classification : TargetClassification
                if classification.confidence < highConfidenceThreshold
                then idle;
        }
    }

    part def CommunicationModule {
        port classificationIn : ClassificationPort;
        port commandIn : CommandPort;
        port modeIn : PowerControlPort;
        port rfPort : RfPort;
        port alertLog : AlertPort;
        attribute nodeLocation : GeospatialPosition;
        attribute nodeId : String;
        perform action generateAlert : GenerateAlert;
        perform action transmitAlert : TransmitAlert;
        exhibit state transmissionStates {
            entry; then idle;
            state idle;
            transition t_classified
                first idle
                accept classification : TargetClassification via classificationIn
                if classification.confidence >= 0.85
                do generateAlert
                then transmitting;
            state transmitting {
                do transmitAlert;
            }
            transition transmitting_idle
                first transmitting
                accept completion : TransmissionComplete
                then idle;
        }
    }

    part def DataLogger {
        port classificationIn : ClassificationPort;
        port alertIn : AlertPort;
        attribute storageCapacity : ScalarValues::Real;
        perform action storeClassification {
            in data : TargetClassification;
            first start;
            then action writeClassificationRecord;
            then done;
        }
        perform action storeAlert {
            in alert : TargetAlert;
            first start;
            then action writeAlertRecord;
            then done;
        }
    }

    part def Battery {
        attribute capacity : ISQ::EnergyValue;
        attribute currentCharge : ISQ::EnergyValue;
        port statusOut : BatteryStatusPort;
        port chargeIn : SolarPowerPort;
        perform action reportStatus : ReportBatteryStatus;
    }

    part def SolarPanel {
        attribute area : ISQ::AreaValue;
        port powerOut : SolarPowerPort;
        perform action generatePower : GeneratePower;
    }

    part def PowerManagementUnit {
        port batteryStatusIn : BatteryStatusPort;
        port solarPowerIn : SolarPowerPort;
        port modeOut : PowerControlPort;
        attribute lowBatteryThreshold : ScalarValues::Real = 0.2;
        attribute criticalBatteryThreshold : ScalarValues::Real = 0.1;
        perform action monitorPower : MonitorPower;
        exhibit state powerManagementStates {
            entry; then managing;
            state managing;
            transition t_critical
                first managing
                accept status : BatteryStatus via batteryStatusIn
                if status.chargeLevel < criticalBatteryThreshold
                do send NodeModeKind::lowPower to modeOut
                then managing;
            transition t_low
                first managing
                accept status : BatteryStatus via batteryStatusIn
                if status.chargeLevel >= criticalBatteryThreshold and status.chargeLevel < lowBatteryThreshold
                do send NodeModeKind::standby to modeOut
                then managing;
            transition t_normal
                first managing
                accept status : BatteryStatus via batteryStatusIn
                if status.chargeLevel >= lowBatteryThreshold
                do send NodeModeKind::activeSurveillance to modeOut
                then managing;
        }
    }

    part def DisplayUnit {
        perform action showAlert : ShowAlert;
    }

    part def AlertDatabase {
        perform action storeAlertRecord : StoreAlertRecord;
    }

    part def RoutingTable {
        attribute routeEntries : String[0..*];
    }

    part def RFMeshNetwork {
        port nodePort : RfPort[1..*];
        port commandCenterPort : RfPort;
        part routingTable : RoutingTable;
        perform action routeAlert : RouteAlert;
        exhibit state routingStates {
            entry; then routing;
            state routing;
            transition t_route
                first routing
                accept alert : TargetAlert via nodePort
                do routeAlert
                then routing;
        }
    }

    part def CommandCenter {
        port rfPort : RfPort;
        part alertDisplay : DisplayUnit;
        part alertDatabase : AlertDatabase;
        perform action receiveAlert {
            in alert : TargetAlert;
            first start;
            then action displayAlert;
            then action storeAlert;
            then done;
        }
        exhibit state monitoringStates {
            entry; then monitoring;
            state monitoring;
            transition t_receive
                first monitoring
                accept alert : TargetAlert via rfPort
                do receiveAlert
                then monitoring;
        }
    }

    part def SensorNode {
        attribute nodeId : String;
        attribute location : GeospatialPosition;
        part seismicSensor : SeismicSensor;
        part acousticSensor : AcousticSensor;
        part pirSensor : PassiveInfraredSensor;
        part magneticSensor : MagneticSensor;
        part signalProcessor : SignalProcessor;
        part communicationModule : CommunicationModule;
        part dataLogger : DataLogger;
        part powerManagementUnit : PowerManagementUnit;
        part battery : Battery;
        part solarPanel : SolarPanel;
        port commandPort : CommandPort;
        port rfPort : RfPort;

        connect seismicSensor.dataOut to signalProcessor.seismicIn;
        connect acousticSensor.dataOut to signalProcessor.acousticIn;
        connect pirSensor.dataOut to signalProcessor.pirIn;
        connect magneticSensor.dataOut to signalProcessor.magneticIn;
        connect signalProcessor.classificationOut to communicationModule.classificationIn;
        connect signalProcessor.classificationOut to dataLogger.classificationIn;
        connect communicationModule.alertLog to dataLogger.alertIn;
        connect communicationModule.rfPort to rfPort;
        connect commandPort to communicationModule.commandIn;
        connect battery.statusOut to powerManagementUnit.batteryStatusIn;
        connect solarPanel.powerOut to battery.chargeIn;
        connect powerManagementUnit.modeOut to seismicSensor.modeIn;
        connect powerManagementUnit.modeOut to acousticSensor.modeIn;
        connect powerManagementUnit.modeOut to pirSensor.modeIn;
        connect powerManagementUnit.modeOut to magneticSensor.modeIn;
        connect powerManagementUnit.modeOut to signalProcessor.modeIn;
        connect powerManagementUnit.modeOut to communicationModule.modeIn;

        exhibit state nodeModes {
            entry; then standby;
            state standby;
            transition t_activate
                first standby
                accept SigActivate
                then activeSurveillance;
            transition t_enter_low
                first standby
                accept SigEnterLowPower
                then lowPower;
            transition t_cmd_active
                first standby
                accept command : CommandMessage via commandPort
                if command.desiredMode == NodeModeKind::activeSurveillance
                then activeSurveillance;
            state activeSurveillance;
            transition t_deactivate
                first activeSurveillance
                accept SigDeactivate
                then standby;
            transition t_active_low
                first activeSurveillance
                accept SigEnterLowPower
                then lowPower;
            transition t_cmd_standby
                first activeSurveillance
                accept command : CommandMessage via commandPort
                if command.desiredMode == NodeModeKind::standby
                then standby;
            transition t_cmd_low
                first activeSurveillance
                accept command : CommandMessage via commandPort
                if command.desiredMode == NodeModeKind::lowPower
                then lowPower;
            state lowPower;
            transition t_exit_low
                first lowPower
                accept SigExitLowPower
                then standby;
            transition t_low_activate
                first lowPower
                accept SigActivate
                then activeSurveillance;
            transition t_cmd_low_active
                first lowPower
                accept command : CommandMessage via commandPort
                if command.desiredMode == NodeModeKind::activeSurveillance
                then activeSurveillance;
            transition t_cmd_low_standby
                first lowPower
                accept command : CommandMessage via commandPort
                if command.desiredMode == NodeModeKind::standby
                then standby;
        }
    }

    part def UnattendedGroundSensorSystem {
        part sensorNodes : SensorNode[1..*];
        part commandCenter : CommandCenter;
        part meshNetwork : RFMeshNetwork;

        connect sensorNodes.rfPort to meshNetwork.nodePort;
        connect commandCenter.rfPort to meshNetwork.commandCenterPort;
    }

    requirement req_LongDurationAutonomy : LongDurationAutonomy;
    requirement req_AutonomousPerimeterSurveillance : AutonomousPerimeterSurveillance;
    requirement req_MultisensorFusionReduction : MultisensorFusionReduction;
    requirement req_SecureRFMeshReporting : SecureRFMeshReporting;
    requirement req_LowPowerManagement : LowPowerManagement;

    satisfy req_LongDurationAutonomy by PowerManagementUnit;
    satisfy req_AutonomousPerimeterSurveillance by UnattendedGroundSensorSystem;
    satisfy req_MultisensorFusionReduction by SignalProcessor;
    satisfy req_SecureRFMeshReporting by CommunicationModule;
    satisfy req_LowPowerManagement by PowerManagementUnit;
}
