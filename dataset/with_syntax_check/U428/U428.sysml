package TubexTransportSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def PressureValue :> Real;
    attribute def VelocityValue :> Real;
    attribute def DistanceValue :> Real;
    
    enum def SystemStateKind {
        standby;
        loading;
        pressurizing;
        transporting;
        receiving;
        depressurizing;
        fault;
    }
    
    enum def CapsuleStatusKind {
        empty;
        loaded;
        sealed;
        inTransit;
        delivered;
    }
    
    item def Document {
        attribute mass : MassValue;
        attribute identifier : String;
        attribute priority : Integer;
    }
    
    item def TransportCapsule {
        attribute capsuleMass : MassValue = 0.3 [kg];
        attribute maxPayloadMass : MassValue = 1.5 [kg];
        attribute status : CapsuleStatusKind = CapsuleStatusKind::empty;
        item payload : Document[0..1];
        attribute payloadMass : MassValue = 0.0 [kg];
        attribute totalMass : MassValue = capsuleMass + payloadMass;
        
        assert constraint payloadLimit {
            payloadMass <= maxPayloadMass
        }
    }
    
    port def TubePort {
        in item receivedCapsule : TransportCapsule;
        out item sentCapsule : TransportCapsule;
        attribute pressure : PressureValue;
    }
    
    port def ControlPort {
        attribute commandSignal : String;
        attribute statusSignal : String;
    }
    
    port def PowerPort {
        attribute voltage : Real;
        attribute current : Real;
    }
    
    part def PressureGenerator {
        attribute maxPressure : PressureValue = 80000.0;
        attribute currentPressure : PressureValue = 0.0;
        attribute powerConsumption : Real;
        port powerIn : PowerPort;
        
        action def GeneratePressure {
            in targetPressure : PressureValue;
            out achievedPressure : PressureValue;
        }
        
        action def ReleasePressure {
            out finalPressure : PressureValue;
        }
    }
    
    part def TubeSegment {
        attribute segmentLength : LengthValue;
        attribute diameter : LengthValue = 0.1 [m];
        attribute maxPressure : PressureValue = 100000.0;
        port inlet : TubePort;
        port outlet : TubePort;
        
        assert constraint pressureSafety {
            inlet.pressure <= maxPressure and outlet.pressure <= maxPressure
        }
    }
    
    part def LoadingStation {
        attribute stationId : String;
        attribute maxLoadCapacity : Integer = 10;
        port tubeConnection : TubePort;
        port control : ControlPort;
        
        action def LoadDocument {
            in document : Document;
            out loadedCapsule : TransportCapsule;
        }
        
        action def SealCapsule {
            in capsule : TransportCapsule;
            out sealedCapsule : TransportCapsule;
        }
        
        action def LaunchCapsule {
            in capsule : TransportCapsule;
        }
    }
    
    part def ReceivingStation {
        attribute stationId : String;
        attribute bufferCapacity : Integer = 5;
        port tubeConnection : TubePort;
        port control : ControlPort;
        
        action def ReceiveCapsule {
            out receivedCapsule : TransportCapsule;
        }
        
        action def ExtractDocument {
            in capsule : TransportCapsule;
            out document : Document;
        }
        
        action def ReturnCapsule {
            in emptyCapsule : TransportCapsule;
        }
    }
    
    part def SafetySensor {
        attribute sensorId : String;
        attribute pressureThreshold : PressureValue = 90000.0;
        attribute obstructionDetected : Boolean = false;
        
        action def MonitorPressure {
            in currentPressure : PressureValue;
            out alarmTriggered : Boolean;
        }
        
        action def DetectObstruction {
            out obstructionStatus : Boolean;
        }
    }
    
    part def SystemController {
        attribute systemState : SystemStateKind = SystemStateKind::standby;
        attribute activeTransports : Integer = 0;
        port controlInterface : ControlPort;
        
        action def ProcessTransportRequest {
            in document : Document;
            in destinationId : String;
        }
        
        action def MonitorSystemHealth {
            out healthStatus : Boolean;
        }
    }
    
    part def Tubex {
        doc /*
         * Tubex is a pneumatic tube transport system that rapidly moves
         * documents and small items between stations using air pressure
         * differential within a sealed tube network.
         */
        
        attribute networkLength : LengthValue;
        attribute operatingPressure : PressureValue = 60000.0;
        attribute maxTransportSpeed : VelocityValue = 8.0;
        attribute systemState : SystemStateKind = SystemStateKind::standby;
        
        port mainPower : PowerPort;
        port systemControl : ControlPort;
        
        part controller : SystemController {
            attribute :>> systemState = systemState;
        }
        
        part pressureUnit : PressureGenerator {
            attribute :>> maxPressure = 80000.0;
        }
        
        part mainTube : TubeSegment {
            attribute :>> segmentLength = 50.0 [m];
            attribute :>> diameter = 0.1 [m];
        }
        
        part branchTube1 : TubeSegment {
            attribute :>> segmentLength = 15.0 [m];
        }
        
        part branchTube2 : TubeSegment {
            attribute :>> segmentLength = 20.0 [m];
        }
        
        part sendStation : LoadingStation {
            attribute :>> stationId = "SEND-01";
        }
        
        part receiveStation1 : ReceivingStation {
            attribute :>> stationId = "RECV-01";
        }
        
        part receiveStation2 : ReceivingStation {
            attribute :>> stationId = "RECV-02";
        }
        
        part pressureSensor1 : SafetySensor {
            attribute :>> sensorId = "PS-01";
        }
        
        part pressureSensor2 : SafetySensor {
            attribute :>> sensorId = "PS-02";
        }
        
        connection tubeNetwork1 connect sendStation.tubeConnection to mainTube.inlet;
        connection tubeNetwork2 connect mainTube.outlet to branchTube1.inlet;
        connection tubeNetwork3 connect mainTube.outlet to branchTube2.inlet;
        connection tubeNetwork4 connect branchTube1.outlet to receiveStation1.tubeConnection;
        connection tubeNetwork5 connect branchTube2.outlet to receiveStation2.tubeConnection;
        
        connection powerSupply connect mainPower to pressureUnit.powerIn;
        connection controlLink connect systemControl to controller.controlInterface;
        
        assert constraint operatingPressureLimit {
            operatingPressure <= pressureUnit.maxPressure and
            operatingPressure <= mainTube.maxPressure
        }
        
        assert constraint networkIntegrity {
            networkLength == mainTube.segmentLength + branchTube1.segmentLength + branchTube2.segmentLength
        }
    }
    
    action def MonitorSystemStatus {
        in currentState : SystemStateKind;
        in activeCapsules : Integer;
        out statusOk : Boolean;
    }
    
    action def InitiatePressurization {
        in targetPressure : PressureValue;
        out pressureReady : Boolean;
    }
    
    action def LoadAndSeal {
        in document : Document;
        out preparedCapsule : TransportCapsule;
    }
    
    action def TransportCapsule {
        in capsule : TransportCapsule;
        in destination : String;
        out deliveryConfirmed : Boolean;
    }
    
    action def ReceiveAndExtract {
        in arrivedCapsule : TransportCapsule;
        out extractedDocument : Document;
    }
    
    action def DepressurizeSystem {
        out systemSafe : Boolean;
    }
    
    action def HandleFault {
        in faultCode : String;
        out faultResolved : Boolean;
    }
    
    action def TubexTransportOperation {
        doc /*
         * Primary operational cycle for transporting a document through
         * the Tubex pneumatic tube system from sending station to
         * designated receiving station.
         */
        
        first start;
        then merge operationLoop;
        
        then action monitorStatus : MonitorSystemStatus {
            in currentState : SystemStateKind;
            in activeCapsules : Integer;
            out statusOk : Boolean;
        }
        
        then decide;
            if monitorStatus.statusOk then proceedWithTransport;
            if not monitorStatus.statusOk then handleFault;
        
        action proceedWithTransport {
            first pressurize;
            then action pressurize : InitiatePressurization {
                in targetPressure = 60000.0;
                out pressureReady : Boolean;
            }
            then action loadDocument : LoadAndSeal {
                in document : Document;
                out preparedCapsule : TransportCapsule;
            }
            then action transport : TransportCapsule {
                in capsule = loadDocument.preparedCapsule;
                in destination : String;
                out deliveryConfirmed : Boolean;
            }
            then action receive : ReceiveAndExtract {
                in arrivedCapsule = loadDocument.preparedCapsule;
                out extractedDocument : Document;
            }
            then action depressurize : DepressurizeSystem {
                out systemSafe : Boolean;
            }
        }
        then operationLoop;
        
        action handleFault : HandleFault {
            in faultCode : String;
            out faultResolved : Boolean;
        }
        then done;
    }
    
    state def TubexStateMachine {
        entry; then standby;
        
        state standby {
            entry assign systemState = SystemStateKind::standby;
        }
        transition standby_to_loading
            first standby
            accept TransportRequest
            then loading;
        
        state loading {
            entry assign systemState = SystemStateKind::loading;
            do action loadAction : LoadAndSeal;
        }
        transition loading_to_pressurizing
            first loading
            accept CapsuleSealed
            then pressurizing;
        
        state pressurizing {
            entry assign systemState = SystemStateKind::pressurizing;
            do action pressurizeAction : InitiatePressurization;
        }
        transition pressurizing_to_transporting
            first pressurizing
            accept PressureReached
            then transporting;
        
        state transporting {
            entry assign systemState = SystemStateKind::transporting;
            do action transportAction : TransportCapsule;
        }
        transition transporting_to_receiving
            first transporting
            accept CapsuleArrived
            then receiving;
        
        state receiving {
            entry assign systemState = SystemStateKind::receiving;
            do action receiveAction : ReceiveAndExtract;
        }
        transition receiving_to_depressurizing
            first receiving
            accept DocumentExtracted
            then depressurizing;
        
        state depressurizing {
            entry assign systemState = SystemStateKind::depressurizing;
            do action depressurizeAction : DepressurizeSystem;
        }
        transition depressurizing_to_standby
            first depressurizing
            accept SystemSafe
            then standby;
        
        state fault {
            entry assign systemState = SystemStateKind::fault;
        }
        transition any_to_fault
            accept SystemFault
            then fault;
        transition fault_to_standby
            first fault
            accept FaultCleared
            then standby;
    }
    
    requirement <'REQ-2000'> primaryTransportFunction {
        doc /*
         * The Tubex system shall transport documents and small items
         * between designated stations using pneumatic pressure differential
         * within a sealed tube network.
         */
        subject tubex : Tubex;
    }
    
    requirement <'REQ-2001'> transportSpeed {
        doc /*
         * The Tubex system shall achieve transport speeds up to 8 m/s
         * for capsules within the tube network.
         */
        subject tubex : Tubex;
        require constraint {
            tubex.maxTransportSpeed >= 8.0
        }
    }
    
    requirement <'REQ-2002'> payloadCapacity {
        doc /*
         * The Tubex system shall transport payloads with mass up to 1.5 kg
         * per capsule.
         */
        subject capsule : TransportCapsule;
        require constraint {
            capsule.maxPayloadMass >= 1.5 [kg]
        }
    }
    
    requirement <'REQ-2003'> pressureSafety {
        doc /*
         * The Tubex system shall maintain operating pressure below
         * maximum rated pressure of all tube segments.
         */
        subject tubex : Tubex;
        require constraint {
            tubex.operatingPressure <= tubex.mainTube.maxPressure
        }
    }
    
    requirement <'REQ-2004'> systemReliability {
        doc /*
         * The Tubex system shall detect obstructions and pressure
         * anomalies and transition to safe state within 2 seconds.
         */
        subject tubex : Tubex;
    }
    
    part officeTubexSystem : Tubex {
        doc /*
         * Complete Tubex pneumatic transport system installation for
         * multi-floor office building document distribution.
         */
        
        attribute :>> networkLength = 85.0 [m];
        attribute :>> operatingPressure = 60000.0;
        
        perform action operation : TubexTransportOperation;
        exhibit state behavior : TubexStateMachine;
        
        part redefines sendStation {
            attribute :>> stationId = "MAILROOM";
        }
        
        part redefines receiveStation1 {
            attribute :>> stationId = "FLOOR-3";
        }
        
        part redefines receiveStation2 {
            attribute :>> stationId = "FLOOR-5";
        }
    }
    
    satisfy primaryTransportFunction by officeTubexSystem;
    satisfy transportSpeed by officeTubexSystem;
    satisfy payloadCapacity by officeTubexSystem.sendStation;
    satisfy pressureSafety by officeTubexSystem;
    satisfy systemReliability by officeTubexSystem;
}
