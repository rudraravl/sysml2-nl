package UGS_System {

    import ScalarValues::*;
    import QuantityKinds::*;
    import SI::*;

    // ===== Value Types =====
    valueType Voltage :> Real { unit "V"; }
    valueType Power :> Real { unit "W"; }
    valueType Frequency :> Real { unit "Hz"; }
    valueType Temperature :> Real { unit "degC"; }
    valueType ConfidenceLevel :> Real { unit "percent"; }
    valueType SeverityLevel :> Real { unit "percent"; }
    valueType BatteryLevel :> Real { unit "percent"; }
    valueType Latitude :> Real { unit "deg"; }
    valueType Longitude :> Real { unit "deg"; }
    valueType NodeId :> String;
    valueType TimeStamp :> String;

    // ===== Item Types =====
    item def SeismicSignal {
        attribute amplitude : Real [1]; // in micrometers
        attribute frequency : Frequency [1];
    }

    item def AcousticSignal {
        attribute soundPressure : Real [1]; // in dB
        attribute frequency : Frequency [1];
    }

    item def IRSignature {
        attribute temperatureDelta : Temperature [1];
        attribute motionDetected : Boolean [1];
    }

    item def MagneticFlux {
        attribute strength : Real [1]; // in microtesla
    }

    item def SensorData {
        attribute nodeId : NodeId [1];
        attribute timeStamp : TimeStamp [1];
        attribute seismic : SeismicSignal [0..1];
        attribute acoustic : AcousticSignal [0..1];
        attribute ir : IRSignature [0..1];
        attribute magnetic : MagneticFlux [0..1];
    }

    enum def TargetType {
        personnel;
        lightVehicle;
        heavyVehicle;
        animal;
        unknown;
    }

    item def ClassifiedTarget {
        attribute target : TargetType [1];
        attribute confidence : ConfidenceLevel [1];
        attribute severity : SeverityLevel [1];
        attribute latitude : Latitude [1];
        attribute longitude : Longitude [1];
        attribute timeStamp : TimeStamp [1];
        attribute nodeId : NodeId [1];
    }

    item def AlertMessage :> ClassifiedTarget {
        attribute encrypted : Boolean [1] = true;
    }

    item def PowerStatus {
        attribute batteryLevel : BatteryLevel [1];
        attribute solarInput : Power [1];
        attribute load : Power [1];
    }

    enum def OperatingMode {
        active;
        standby;
        lowPower;
    }

    // ===== Ports & Interfaces =====
    port def SeismicOut { out seismic : SeismicSignal; }
    port def AcousticOut { out acoustic : AcousticSignal; }
    port def IROut { out ir : IRSignature; }
    port def MagneticOut { out magnetic : MagneticFlux; }
    port def SensorDataOut { out data : SensorData; }
    port def AlertOut { out alert : AlertMessage; }
    port def AlertIn { in alert : AlertMessage; }
    port def PowerPort { out status : PowerStatus; }
    port def ModePort { out mode : OperatingMode; }

    interface def SeismicInterface {
        end source : SeismicOut;
        end dest : SensorDataOut;
        flow seismic from source.seismic to dest.data.seismic;
    }

    interface def AcousticInterface {
        end source : AcousticOut;
        end dest : SensorDataOut;
        flow acoustic from source.acoustic to dest.data.acoustic;
    }

    interface def IRInterface {
        end source : IROut;
        end dest : SensorDataOut;
        flow ir from source.ir to dest.data.ir;
    }

    interface def MagneticInterface {
        end source : MagneticOut;
        end dest : SensorDataOut;
        flow magnetic from source.magnetic to dest.data.magnetic;
    }

    interface def AlertInterface {
        end source : AlertOut;
        end dest : AlertIn;
        flow alert from source.alert to dest.alert;
    }

    // ===== Parts: Sensors =====
    part def SeismicSensor {
        attribute sensitivity : Real [1] = 0.5;
        port seismicOut : SeismicOut;
        action detectSeismic {
            out s : SeismicSignal;
        }
    }

    part def AcousticSensor {
        attribute frequencyRange : Frequency [2] = (20.0, 20000.0);
        port acousticOut : AcousticOut;
        action detectAcoustic {
            out a : AcousticSignal;
        }
    }

    part def PIRSensor {
        attribute detectionRange : Real [1] = 12.0; // meters
        port irOut : IROut;
        action detectIR {
            out ir : IRSignature;
        }
    }

    part def MagneticSensor {
        attribute detectionThreshold : Real [1] = 5.0; // microtesla
        port magneticOut : MagneticOut;
        action detectMagnetic {
            out m : MagneticFlux;
        }
    }

    // ===== Part: Signal Processor =====
    part def SignalProcessor {
        port dataIn : SensorDataOut;
        port classifiedOut : AlertOut;
        attribute confidenceThreshold : ConfidenceLevel [1] = 75.0;
        attribute severityThreshold : SeverityLevel [1] = 50.0;

        action fuseAndClassify {
            in data : SensorData;
            out target : ClassifiedTarget;
        }

        action determineSeverity {
            in target : TargetType;
            in confidence : ConfidenceLevel;
            out severity : SeverityLevel;
        }

        action generateAlert {
            in target : ClassifiedTarget;
            out alert : AlertMessage;
        }
    }

    // ===== Part: Data Logger =====
    part def DataLogger {
        attribute capacity : Integer [1] = 10000;
        attribute records : ClassifiedTarget [*] ordered;
        action logTarget {
            in target : ClassifiedTarget;
        }
        action retrieveLogs {
            out logs : ClassifiedTarget [*];
        }
    }

    // ===== Part: Communication Module =====
    part def CommunicationModule {
        port alertIn : AlertOut;
        port rfOut : AlertOut;
        attribute meshId : NodeId [1];
        attribute encryptionEnabled : Boolean [1] = true;
        action transmitAlert {
            in alert : AlertMessage;
        }
    }

    // ===== Part: Power Management Unit =====
    part def PowerManagementUnit {
        attribute batteryCapacity : Real [1] = 100.0; // Ah
        attribute solarPanelRating : Power [1] = 5.0;
        attribute minBatteryForActive : BatteryLevel [1] = 40.0;
        attribute minBatteryForStandby : BatteryLevel [1] = 20.0;
        port powerOut : PowerPort;
        port modeOut : ModePort;
        action managePower {
            in batteryLevel : BatteryLevel;
            in activity : Boolean;
            out mode : OperatingMode;
        }
    }

    part def Battery {
        attribute currentLevel : BatteryLevel [1] = 100.0;
        attribute voltage : Voltage [1] = 12.0;
    }

    part def SolarPanel {
        attribute ratedPower : Power [1] = 5.0;
        action harvestEnergy {
            out power : Power;
        }
    }

    // ===== Part: Sensor Node =====
    part def SensorNode {
        attribute nodeId : NodeId [1];
        attribute location_lat : Latitude [1];
        attribute location_lon : Longitude [1];
        attribute currentMode : OperatingMode [1] = OperatingMode::standby;

        port seismicPort : SeismicOut;
        port acousticPort : AcousticOut;
        port irPort : IROut;
        port magneticPort : MagneticOut;
        port dataPort : SensorDataOut;
        port alertPort : AlertOut;
        port powerPort : PowerPort;
        port modePort : ModePort;

        part seismicSensor : SeismicSensor {
            port seismicOut : SeismicOut;
        }
        part acousticSensor : AcousticSensor {
            port acousticOut : AcousticOut;
        }
        part pirSensor : PIRSensor {
            port irOut : IROut;
        }
        part magneticSensor : MagneticSensor {
            port magneticOut : MagneticOut;
        }
        part processor : SignalProcessor {
            port dataIn : SensorDataOut;
            port classifiedOut : AlertOut;
        }
        part dataLogger : DataLogger;
        part commModule : CommunicationModule {
            port alertIn : AlertOut;
            port rfOut : AlertOut;
        }
        part powerUnit : PowerManagementUnit {
            port powerOut : PowerPort;
            port modeOut : ModePort;
        }
        part battery : Battery;
        part solarPanel : SolarPanel;

        // Internal connections
        connection seismicConn : SeismicInterface connect seismicSensor.seismicOut to processor.dataIn;
        connection acousticConn : AcousticInterface connect acousticSensor.acousticOut to processor.dataIn;
        connection irConn : IRInterface connect pirSensor.irOut to processor.dataIn;
        connection magneticConn : MagneticInterface connect magneticSensor.magneticOut to processor.dataIn;
        connection alertConn : AlertInterface connect processor.classifiedOut to commModule.alertIn;
        connection rfConn : AlertInterface connect commModule.rfOut to alertPort;

        // State machine for node operation
        state def NodeStateMachine {
            state Active {
                entry action {
                    // Begin active surveillance
                }
                do action {
                    // Continuously sample sensors and fuse data
                }
            }
            state Standby {
                entry action {
                    // Reduce sampling rate
                }
            }
            state LowPower {
                entry action {
                    // Minimal sampling, conserve energy
                }
            }
            transition Active_to_Standby
                from Active to Standby
                when powerPort.status.batteryLevel < powerUnit.minBatteryForActive;
            transition Standby_to_LowPower
                from Standby to LowPower
                when powerPort.status.batteryLevel < powerUnit.minBatteryForStandby;
            transition LowPower_to_Standby
                from LowPower to Standby
                when powerPort.status.batteryLevel > powerUnit.minBatteryForStandby + 10.0;
            transition Standby_to_Active
                from Standby to Active
                when powerPort.status.batteryLevel > powerUnit.minBatteryForActive + 10.0;
            transition Any_to_Active_on_Intrusion
                from Standby to Active
                when seismicPort.seismic.amplitude > 0.8;
        }

        // Classification action
        action classifyTarget {
            in data : SensorData;
            out target : ClassifiedTarget;
        }
    }

    // ===== Part: RF Mesh Network =====
    part def RFMeshNetwork {
        attribute networkId : NodeId [1];
        attribute encryptionKey : String [1];
        part nodes : SensorNode [*];
        action routeAlert {
            in alert : AlertMessage;
            out routed : AlertMessage;
        }
    }

    // ===== Part: Command Center =====
    part def CommandCenter {
        attribute centerId : NodeId [1];
        attribute operatorCount : Integer [1] = 5;
        port alertIn : AlertIn;
        part display : OperatorDisplay;
        part database : AlertDatabase;
        action receiveAlert {
            in alert : AlertMessage;
        }
        action displayAlert {
            in alert : AlertMessage;
        }
        action storeAlert {
            in alert : AlertMessage;
        }
    }

    part def OperatorDisplay {
        attribute resolution : String [1] = "1920x1080";
        action showAlert {
            in alert : AlertMessage;
        }
    }

    part def AlertDatabase {
        attribute capacity : Integer [1] = 1000000;
        attribute storedAlerts : AlertMessage [*] ordered;
        action store {
            in alert : AlertMessage;
        }
        action query {
            in criteria : String;
            out results : AlertMessage [*];
        }
    }

    // ===== Top-level System =====
    part def UGSSystem {
        attribute systemName : String [1] = "Unattended Ground Sensor System";
        part network : RFMeshNetwork {
            part nodes : SensorNode [*];
        }
        part commandCenter : CommandCenter {
            port alertIn : AlertIn;
        }
        connection meshToCommand : AlertInterface connect network.nodes.alertPort to commandCenter.alertIn;
    }

    // ===== Requirements =====
    requirement def DetectionRequirement {
        attribute minConfidence : ConfidenceLevel [1] = 75.0;
        subject sensorNode : SensorNode;
        objective {
            doc /* The sensor node shall detect and classify ground-based intrusions with a confidence of at least minConfidence. */
        }
    }

    requirement def MultiSensorRequirement {
        subject sensorNode : SensorNode;
        objective {
            doc /* Each sensor node shall include seismic, acoustic, PIR, and magnetic sensors. */
        }
    }

    requirement def FalseAlarmReductionRequirement {
        attribute maxFalseAlarmRate : Real [1] = 0.05;
        subject sensorNode : SensorNode;
        objective {
            doc /* The multi-sensor fusion shall reduce false alarms caused by weather or non-threatening wildlife. */
        }
    }

    requirement def AlertTransmissionRequirement {
        subject sensorNode : SensorNode;
        objective {
            doc /* When a target is classified with high confidence, the node shall transmit a detailed alert over a secure RF mesh network. */
        }
    }

    requirement def AlertContentRequirement {
        subject alert : AlertMessage;
        objective {
            doc /* The alert shall include time, location, type of target, and severity level. */
        }
    }

    requirement def LocalStorageRequirement {
        subject sensorNode : SensorNode;
        objective {
            doc /* The node shall store alert data locally in a data logger for later retrieval. */
        }
    }

    requirement def AutonomousOperationRequirement {
        attribute minDurationDays : Integer [1] = 90;
        subject sensorNode : SensorNode;
        objective {
            doc /* The node shall operate autonomously for at least minDurationDays without maintenance. */
        }
    }

    requirement def PowerManagementRequirement {
        subject sensorNode : SensorNode;
        objective {
            doc /* The node shall manage battery and solar power and switch between active, standby, and low-power modes based on battery levels and activity. */
        }
    }

    requirement def CommandCenterRequirement {
        subject commandCenter : CommandCenter;
        objective {
            doc /* The command center shall receive alerts from all nodes and allow operators to monitor the security of a large area. */
        }
    }

    requirement SensorNodeRequirements :> MultiSensorRequirement, DetectionRequirement, FalseAlarmReductionRequirement, AlertTransmissionRequirement, LocalStorageRequirement, AutonomousOperationRequirement, PowerManagementRequirement {
    }

    requirement SystemRequirements :> SensorNodeRequirements, AlertContentRequirement, CommandCenterRequirement {
    }

    // ===== Satisfaction =====
    satisfaction satisfy SensorNodeRequirements by SensorNode;
    satisfaction satisfy AlertContentRequirement by AlertMessage;
    satisfaction satisfy CommandCenterRequirement by CommandCenter;
    satisfaction satisfy AutonomousOperationRequirement by SensorNode.powerUnit;
    satisfaction satisfy PowerManagementRequirement by SensorNode.powerUnit;
    satisfaction satisfy LocalStorageRequirement by SensorNode.dataLogger;
    satisfaction satisfy AlertTransmissionRequirement by SensorNode.commModule;
    satisfaction satisfy FalseAlarmReductionRequirement by SensorNode.processor;
    satisfaction satisfy DetectionRequirement by SensorNode.processor;
    satisfaction satisfy MultiSensorRequirement by SensorNode;

}
