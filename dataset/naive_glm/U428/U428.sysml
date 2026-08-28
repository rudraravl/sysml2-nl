package Tubex {

    import ScalarValues::*;

    //==================================================================
    // VALUE TYPES (with units)
    //==================================================================
    value type MassKg {
        unit 'kg';
    }
    value type VelocityMps {
        unit 'm/s';
    }
    value type PressurePa {
        unit 'Pa';
    }
    value type LengthM {
        unit 'm';
    }
    value type TimeS {
        unit 's';
    }
    value type FlowRate {
        unit 'm^3/s';
    }
    value type Volume {
        unit 'm^3';
    }

    //==================================================================
    // ENUMERATIONS
    //==================================================================
    enumeration def Direction {
        in;
        out;
    }
    enumeration def StationRole {
        sender;
        receiver;
        bidirectional;
    }
    enumeration def OperationState {
        standby;
        loading;
        pressurizing;
        transporting;
        receiving;
        depressurizing;
        faulted;
    }
    enumeration def FaultKind {
        none;
        overPressure;
        obstruction;
        communication;
    }
    enumeration def CapsuleStatus {
        empty;
        loaded;
        sealed;
        inTransit;
        delivered;
    }

    //==================================================================
    // ITEMS (physical things carried by the system)
    //==================================================================
    item def Document {
        attribute pageCount : Integer;
        attribute folded : Boolean;
    }

    item def SmallItem {
        attribute mass : MassKg;
        attribute description : String;
    }

    item def Payload {
        attribute mass : MassKg;
        attribute description : String;
        item documents : Document [0..*];
        item articles : SmallItem [0..*];
        constraint maxMass { self.mass <= 1.5 [MassKg] }
    }

    item def Capsule {
        attribute id : String;
        attribute sealed : Boolean;
        attribute atOrigin : Boolean;
        attribute atDestination : Boolean;
        attribute status : CapsuleStatus = CapsuleStatus::empty;
        item payload : Payload [0..1];
    }

    //==================================================================
    // SIGNALS (control events)
    //==================================================================
    item def LoadRequest;
    item def SealComplete;
    item def PressureReady;
    item def CapsuleArrived;
    item def PayloadExtracted;
    item def VentComplete;
    item def FaultDetected;
    item def ResetCommand;
    item def StartTransport;

    //==================================================================
    // PORT DEFINITIONS
    //==================================================================
    port def AirPort {
        attribute pressure : PressurePa;
        attribute flow : FlowRate;
        attribute direction : Direction;
    }

    port def CapsuleFlowPort {
        item capsule : Capsule [0..*];
        attribute direction : Direction;
    }

    port def ControlPort {
        attribute enabled : Boolean;
        attribute targetState : OperationState;
    }

    port def SensorPort {
        attribute pressure : PressurePa;
        attribute obstruction : Boolean;
        attribute fault : Boolean;
        attribute faultKind : FaultKind;
    }

    port def RequestPort {
        attribute originId : String;
        attribute destinationId : String;
        attribute accepted : Boolean;
    }

    //==================================================================
    // CONNECTION DEFINITIONS
    //==================================================================
    connection def AirFlowConnection {
        end a : AirPort;
        end b : AirPort;
        attribute pressure : PressurePa;
    }

    connection def CapsuleTransfer {
        end a : CapsuleFlowPort;
        end b : CapsuleFlowPort;
    }

    connection def ControlLink {
        end a : ControlPort;
        end b : ControlPort;
    }

    connection def SensorLink {
        end a : SensorPort;
        end b : SensorPort;
    }

    connection def RequestLink {
        end a : RequestPort;
        end b : RequestPort;
    }

    //==================================================================
    // ACTION DEFINITIONS
    //==================================================================
    action def LoadAction {
        in payload : Payload;
        out capsule : Capsule;
        attribute sealingTime : TimeS = 1.0 [TimeS];
        do {
            capsule.payload := payload;
            capsule.sealed := true;
            capsule.status := CapsuleStatus::sealed;
        }
    }

    action def PressurizeAction {
        in targetPressure : PressurePa;
        out actualPressure : PressurePa;
        attribute rampTime : TimeS = 3.0 [TimeS];
        do {
            actualPressure := targetPressure;
        }
    }

    action def TransportAction {
        in capsule : Capsule;
        attribute maxVelocity : VelocityMps = 8.0 [VelocityMps];
        attribute distance : LengthM;
        do {
            capsule.status := CapsuleStatus::inTransit;
        }
    }

    action def ReceiveAction {
        in capsule : Capsule;
        out payload : Payload;
        do {
            capsule.status := CapsuleStatus::delivered;
            payload := capsule.payload;
        }
    }

    action def DepressurizeAction {
        out ventedPressure : PressurePa;
        attribute ventTime : TimeS = 2.0 [TimeS];
        do {
            ventedPressure := 101000.0 [PressurePa];
        }
    }

    action def EvaluateSafety {
        in sensor : SensorPort;
        out safe : Boolean;
        do {
            if (sensor.fault == true) {
                safe := false;
            } else {
                safe := true;
            }
        }
    }

    //==================================================================
    // PART DEFINITIONS - Pressure Generator
    //==================================================================
    part def PressureGenerator {
        attribute id : String;
        attribute maxPressure : PressurePa = 80000.0 [PressurePa];
        attribute standbyPressure : PressurePa = 101000.0 [PressurePa];
        attribute operatingPressure : PressurePa = 75000.0 [PressurePa];
        attribute running : Boolean = false;
        attribute enabled : Boolean = false;
        port airOut : AirPort;
        port controlIn : ControlPort;

        action pressurize : PressurizeAction;
        action depressurize : DepressurizeAction;

        constraint maxOperatingPressure {
            operatingPressure <= maxPressure;
        }
    }

    //==================================================================
    // PART DEFINITIONS - Safety Sensor
    //==================================================================
    part def SafetySensor {
        attribute id : String;
        attribute location : String;
        attribute pressureLimit : PressurePa = 90000.0 [PressurePa];
        attribute obstruction : Boolean = false;
        attribute overPressure : Boolean = false;
        attribute fault : Boolean = false;
        attribute faultKind : FaultKind = FaultKind::none;
        port dataOut : SensorPort;

        action def Monitor {
            in currentPressure : PressurePa;
            do {
                if (currentPressure > pressureLimit) {
                    overPressure := true;
                    faultKind := FaultKind::overPressure;
                    fault := true;
                } else {
                    overPressure := false;
                }
                if (obstruction == true) {
                    faultKind := FaultKind::obstruction;
                    fault := true;
                }
            }
        }

        action monitor : Monitor;
    }

    //==================================================================
    // PART DEFINITIONS - System Controller
    //==================================================================
    part def SystemController {
        attribute id : String;
        attribute mode : OperationState = OperationState::standby;
        attribute lastFault : FaultKind = FaultKind::none;
        attribute allowedMaxSpeed : VelocityMps = 8.0 [VelocityMps];
        attribute allowedMaxPayload : MassKg = 1.5 [MassKg];
        attribute loadRequestPending : Boolean = false;
        attribute capsuleSealed : Boolean = false;
        attribute pressureReady : Boolean = false;
        attribute capsuleArrived : Boolean = false;
        attribute payloadExtracted : Boolean = false;
        attribute ventComplete : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute resetRequested : Boolean = false;

        port sensorIn : SensorPort;
        port requestIn : RequestPort;
        port pressureCtrlOut : ControlPort;
        port stationCtrlOut : ControlPort;
        port diverterCtrlOut : ControlPort;

        action evaluateSafety : EvaluateSafety;

        action def HaltPressure {
            do {
                pressureCtrlOut.enabled := false;
            }
        }

        state machine ControllerSM {
            state standby {
                entry {
                    mode := OperationState::standby;
                    pressureCtrlOut.enabled := false;
                }
            }
            state loading {
                entry {
                    mode := OperationState::loading;
                }
            }
            state pressurizing {
                entry {
                    mode := OperationState::pressurizing;
                    pressureCtrlOut.enabled := true;
                }
            }
            state transporting {
                entry {
                    mode := OperationState::transporting;
                }
            }
            state receiving {
                entry {
                    mode := OperationState::receiving;
                }
            }
            state depressurizing {
                entry {
                    mode := OperationState::depressurizing;
                    pressureCtrlOut.enabled := false;
                }
            }
            state faulted {
                entry {
                    mode := OperationState::faulted;
                    pressureCtrlOut.enabled := false;
                }
                do {
                    HaltPressure();
                }
            }

            transition t_standby_loading
                first standby then loading
                accept LoadRequest
                guard { faultDetected == false };

            transition t_loading_pressurizing
                first loading then pressurizing
                accept SealComplete
                guard { faultDetected == false };

            transition t_pressurizing_transporting
                first pressurizing then transporting
                accept PressureReady
                guard { faultDetected == false };

            transition t_transporting_receiving
                first transporting then receiving
                accept CapsuleArrived
                guard { faultDetected == false };

            transition t_receiving_depressurizing
                first receiving then depressurizing
                accept PayloadExtracted
                guard { faultDetected == false };

            transition t_depressurizing_standby
                first depressurizing then standby
                accept VentComplete
                guard { faultDetected == false };

            transition t_standby_faulted
                first standby then faulted
                accept FaultDetected;

            transition t_loading_faulted
                first loading then faulted
                accept FaultDetected;

            transition t_pressurizing_faulted
                first pressurizing then faulted
                accept FaultDetected;

            transition t_transporting_faulted
                first transporting then faulted
                accept FaultDetected;

            transition t_receiving_faulted
                first receiving then faulted
                accept FaultDetected;

            transition t_depressurizing_faulted
                first depressurizing then faulted
                accept FaultDetected;

            transition t_faulted_standby
                first faulted then standby
                accept ResetCommand
                guard { faultDetected == false };
        }
    }

    //==================================================================
    // PART DEFINITIONS - Stations
    //==================================================================
    part def Station {
        attribute id : String;
        attribute ready : Boolean = true;
        attribute hasArrivedCapsule : Boolean = false;
        port capsulePort : CapsuleFlowPort;
        port controlIn : ControlPort;
        port requestOut : RequestPort;
    }

    part def LoadingStation :> Station {
        attribute role : StationRole = StationRole::sender;
        attribute payloadLoaded : Boolean = false;
        attribute capsuleSealed : Boolean = false;
        attribute capsuleLaunched : Boolean = false;

        action load : LoadAction;
        action seal : LoadAction;
        action launch : TransportAction;

        action def PrepareForLaunch {
            in p : Payload;
            do {
                load(p);
                seal(p);
                capsuleSealed := true;
            }
        }
    }

    part def ReceivingStation :> Station {
        attribute role : StationRole = StationRole::receiver;
        attribute capsuleArrived : Boolean = false;
        attribute payloadExtracted : Boolean = false;

        action receive : ReceiveAction;
        action extract : ReceiveAction;

        action def ProcessArrival {
            in c : Capsule;
            do {
                receive(c);
                extract(c);
                payloadExtracted := true;
            }
        }
    }

    //==================================================================
    // PART DEFINITIONS - Tube Segment
    //==================================================================
    part def TubeSegment {
        attribute id : String;
        attribute length : LengthM;
        attribute innerDiameter : LengthM = 0.1 [LengthM];
        attribute cleared : Boolean = true;
        attribute pressured : Boolean = false;
        port airIn : AirPort;
        port airOut : AirPort;
        port capsuleIn : CapsuleFlowPort;
        port capsuleOut : CapsuleFlowPort;

        constraint maxSpeedInTube {
            8.0 [VelocityMps] <= 8.0 [VelocityMps];
        }
    }

    //==================================================================
    // PART DEFINITIONS - Diverter (junction)
    //==================================================================
    part def Diverter {
        attribute id : String;
        attribute selectedBranch : Integer = 0;
        port airIn : AirPort;
        port airOutA : AirPort;
        port airOutB : AirPort;
        port capsuleIn : CapsuleFlowPort;
        port capsuleOutA : CapsuleFlowPort;
        port capsuleOutB : CapsuleFlowPort;
        port controlIn : ControlPort;

        action def SelectBranch {
            in branch : Integer;
            do {
                selectedBranch := branch;
            }
        }

        action select : SelectBranch;
    }

    //==================================================================
    // REQUIREMENTS
    //==================================================================
    requirement def PayloadCapacityRequirement {
        doc /* The system shall transport payloads up to a maximum mass of 1.5 kg. */
        subject p : Payload;
        constraint maxMass1 {
            p.mass <= 1.5 [MassKg]
        }
    }

    requirement def MaxSpeedRequirement {
        doc /* The system shall not propel capsules faster than 8 m/s. */
        subject s : VelocityMps;
        constraint maxSpeed1 {
            s <= 8.0 [VelocityMps]
        }
    }

    requirement def TubeNetworkTopologyRequirement {
        doc /* A single main tube shall connect the loading station to a diverter that branches to exactly two receiving stations. */
        subject sys : TubeNetworkAssembly;
        constraint topology1 {
            sys.mainTube.isDefined == true
        }
        constraint topology2 {
            sys.branch1.isDefined == true and sys.branch2.isDefined == true
        }
        constraint topology3 {
            sys.floorStation1.isDefined == true and sys.floorStation2.isDefined == true
        }
    }

    requirement def SafetyRequirement {
        doc /* The system shall halt operations and enter a safe state when a fault (over-pressure or obstruction) is detected. */
        subject ctrl : SystemController;
        constraint haltOnFault {
            if ctrl.faultDetected == true then ctrl.mode == OperationState::faulted;
        }
    }

    requirement def OperationalCycleRequirement {
        doc /* The system shall cycle through standby, loading, pressurizing, transporting, receiving, and depressurizing states. */
        subject ctrl : SystemController;
        constraint allowedStates {
            ctrl.mode == OperationState::standby
            or ctrl.mode == OperationState::loading
            or ctrl.mode == OperationState::pressurizing
            or ctrl.mode == OperationState::transporting
            or ctrl.mode == OperationState::receiving
            or ctrl.mode == OperationState::depressurizing
            or ctrl.mode == OperationState::faulted
        }
    }

    requirement def StandbyRequirement {
        doc /* The system shall begin each operating cycle in the standby state and return to it after depressurizing. */
        subject ctrl : SystemController;
        constraint startState {
            ctrl.mode == OperationState::standby
        }
    }

    requirement def CapsuleSealingRequirement {
        doc /* At a loading station, a document shall be placed in a capsule, sealed, and launched into the network. */
        subject station : LoadingStation;
        constraint sealedBeforeLaunch {
            station.capsuleLaunched == true implies station.capsuleSealed == true
        }
    }

    //==================================================================
    // TOP-LEVEL ASSEMBLY: TubeNetworkAssembly
    //==================================================================
    part def TubeNetworkAssembly {
        attribute systemName : String = "Tubex";
        attribute systemId : String = "TUBEX-1";
        attribute nominalMaxSpeed : VelocityMps = 8.0 [VelocityMps];
        attribute nominalMaxPayload : MassKg = 1.5 [MassKg];

        // --- Loading station (central sending station, e.g. mailroom) ---
        part loadingStation : LoadingStation {
            attribute id : String = "Central-Mailroom";
            attribute role : StationRole = StationRole::sender;
        }

        // --- Receiving stations (e.g. floors) ---
        part floorStation1 : ReceivingStation {
            attribute id : String = "Floor-2";
            attribute role : StationRole = StationRole::receiver;
        }
        part floorStation2 : ReceivingStation {
            attribute id : String = "Floor-5";
            attribute role : StationRole = StationRole::receiver;
        }

        // --- Tube segments ---
        part mainTube : TubeSegment {
            attribute id : String = "T-Main";
            attribute length : LengthM = 25.0 [LengthM];
            attribute innerDiameter : LengthM = 0.10 [LengthM];
        }
        part branch1 : TubeSegment {
            attribute id : String = "T-Branch-1";
            attribute length : LengthM = 12.0 [LengthM];
            attribute innerDiameter : LengthM = 0.10 [LengthM];
        }
        part branch2 : TubeSegment {
            attribute id : String = "T-Branch-2";
            attribute length : LengthM = 15.0 [LengthM];
            attribute innerDiameter : LengthM = 0.10 [LengthM];
        }

        // --- Diverter ---
        part diverter : Diverter {
            attribute id : String = "Div-1";
        }

        // --- Pressure generator ---
        part pressureGen : PressureGenerator {
            attribute id : String = "PG-1";
            attribute maxPressure : PressurePa = 80000.0 [PressurePa];
            attribute operatingPressure : PressurePa = 75000.0 [PressurePa];
        }

        // --- System controller ---
        part controller : SystemController {
            attribute id : String = "Ctrl-1";
            attribute allowedMaxSpeed : VelocityMps = 8.0 [VelocityMps];
            attribute allowedMaxPayload : MassKg = 1.5 [MassKg];
        }

        // --- Safety sensors ---
        part sensorMain : SafetySensor {
            attribute id : String = "S-Main";
            attribute location : String = "MainTube";
            attribute pressureLimit : PressurePa = 90000.0 [PressurePa];
        }
        part sensor1 : SafetySensor {
            attribute id : String = "S1";
            attribute location : String = "Branch1";
            attribute pressureLimit : PressurePa = 90000.0 [PressurePa];
        }
        part sensor2 : SafetySensor {
            attribute id : String = "S2";
            attribute location : String = "Branch2";
            attribute pressureLimit : PressurePa = 90000.0 [PressurePa];
        }

        // --- Active items in transit ---
        item activeCapsule : Capsule {
            attribute id : String = "CAP-001";
        }
        item activePayload : Payload {
            attribute mass : MassKg = 0.0 [MassKg];
        }

        // ===== Connections: Air flow =====
        connection : AirFlowConnection connect pressureGen.airOut to mainTube.airIn;
        connection : AirFlowConnection connect mainTube.airOut to diverter.airIn;
        connection : AirFlowConnection connect diverter.airOutA to branch1.airIn;
        connection : AirFlowConnection connect diverter.airOutB to branch2.airIn;

        // ===== Connections: Capsule flow =====
        connection : CapsuleTransfer connect loadingStation.capsulePort to mainTube.capsuleIn;
        connection : CapsuleTransfer connect mainTube.capsuleOut to diverter.capsuleIn;
        connection : CapsuleTransfer connect diverter.capsuleOutA to branch1.capsuleIn;
        connection : CapsuleTransfer connect diverter.capsuleOutB to branch2.capsuleIn;
        connection : CapsuleTransfer connect branch1.capsuleOut to floorStation1.capsulePort;
        connection : CapsuleTransfer connect branch2.capsuleOut to floorStation2.capsulePort;

        // ===== Connections: Control signals =====
        connection : ControlLink connect controller.pressureCtrlOut to pressureGen.controlIn;
        connection : ControlLink connect controller.stationCtrlOut to loadingStation.controlIn;
        connection : ControlLink connect controller.stationCtrlOut to floorStation1.controlIn;
        connection : ControlLink connect controller.stationCtrlOut to floorStation2.controlIn;
        connection : ControlLink connect controller.diverterCtrlOut to diverter.controlIn;

        // ===== Connections: Sensor data =====
        connection : SensorLink connect sensorMain.dataOut to controller.sensorIn;
        connection : SensorLink connect sensor1.dataOut to controller.sensorIn;
        connection : SensorLink connect sensor2.dataOut to controller.sensorIn;

        // ===== Connections: Requests =====
        connection : RequestLink connect loadingStation.requestOut to controller.requestIn;

        // --- System-level constraints ---
        constraint maxPayloadOfSystem {
            nominalMaxPayload == 1.5 [MassKg]
        }
        constraint maxSpeedOfSystem {
            nominalMaxSpeed == 8.0 [VelocityMps]
        }

        // --- Operational orchestration behavior ---
        state machine SystemCycle {
            state standby;
            state loading;
            state pressurizing;
            state transporting;
            state receiving;
            state depressurizing;

            transition first standby then loading accept LoadRequest;
            transition first loading then pressurizing accept SealComplete;
            transition first pressurizing then transporting accept PressureReady;
            transition first transporting then receiving accept CapsuleArrived;
            transition first receiving then depressurizing accept PayloadExtracted;
            transition first depressurizing then standby accept VentComplete;
        }
    }

    //==================================================================
    // REQUIREMENT USAGES AND SATISFACTION
    //==================================================================
    requirement reqPayload : PayloadCapacityRequirement {
        subject p = TubeNetworkAssembly::activePayload;
    }
    requirement reqMaxSpeed : MaxSpeedRequirement {
        subject s = TubeNetworkAssembly::nominalMaxSpeed;
    }
    requirement reqTopology : TubeNetworkTopologyRequirement {
        subject sys : TubeNetworkAssembly;
    }
    requirement reqSafety : SafetyRequirement {
        subject ctrl = TubeNetworkAssembly::controller;
    }
    requirement reqCycle : OperationalCycleRequirement {
        subject ctrl = TubeNetworkAssembly::controller;
    }
    requirement reqStandby : StandbyRequirement {
        subject ctrl = TubeNetworkAssembly::controller;
    }
    requirement reqSealing : CapsuleSealingRequirement {
        subject station = TubeNetworkAssembly::loadingStation;
    }

    satisfy reqPayload by TubeNetworkAssembly;
    satisfy reqMaxSpeed by TubeNetworkAssembly;
    satisfy reqTopology by TubeNetworkAssembly;
    satisfy reqSafety by TubeNetworkAssembly;
    satisfy reqCycle by TubeNetworkAssembly;
    satisfy reqStandby by TubeNetworkAssembly;
    satisfy reqSealing by TubeNetworkAssembly::loadingStation;
}
