package TubexSystemModel {
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        private import ISQ::*;
        private import ScalarValues::*;
        private import SI::*;

        item def Payload {
            attribute weight: ISQ::MassValue;
        }
        item def Document :> Payload;
        item def SmallItem :> Payload;
        item def Capsule {
            attribute id: ScalarValues::String;
            attribute sealed: ScalarValues::Boolean;
            item payload: Payload;
        }

        attribute def TransportRequestSignal {
            attribute destinationId: ScalarValues::String;
        }
        attribute def CapsuleLoadedSignal;
        attribute def PressureReachedSignal;
        attribute def CapsuleArrivedSignal {
            attribute stationId: ScalarValues::String;
        }
        attribute def CapsuleExtractedSignal;
        attribute def PressureNormalizedSignal;
        attribute def FaultSignal {
            attribute faultType: ScalarValues::String;
        }
        attribute def ResetSignal;

        port def TubePort;
        port def ControlPort;
        port def PressurePort;
        port def SafetyPort;
        port def RequestPort;

        action def LoadCapsule {
            in payload: Payload;
            out capsule: Capsule;
        }
        action def SealCapsule {
            in capsule: Capsule;
            out sealedCapsule: Capsule;
        }
        action def Pressurize {
            out pressure: ISQ::PressureValue;
        }
        action def LaunchCapsule {
            in capsule: Capsule;
        }
        action def TransportCapsule {
            in capsule: Capsule;
            out arrivedCapsule: Capsule;
        }
        action def ReceiveCapsule {
            in capsule: Capsule;
            out payload: Payload;
        }
        action def Depressurize {
            out pressure: ISQ::PressureValue;
        }
        action def MonitorSafety {
            out faultDetected: ScalarValues::Boolean;
        }

        part def SafetySensor {
            port safetyPort: SafetyPort;
            perform action monitorSafety: MonitorSafety;
        }
        part def LoadingStation {
            port tubePort: ~TubePort;
            port controlPort: ControlPort;
            perform action loadCapsule: LoadCapsule;
            perform action sealCapsule: SealCapsule;
        }
        part def ReceivingStation {
            attribute stationId: ScalarValues::String;
            port tubePort: TubePort;
            port controlPort: ControlPort;
            perform action receiveCapsule: ReceiveCapsule;
        }
        part def TubeNetwork {
            port mainTubePort: TubePort;
            port branch1Port: ~TubePort;
            port branch2Port: ~TubePort;
            port pressurePort: ~PressurePort;
            attribute currentPressure: ISQ::PressureValue;
        }
        part def PressureGenerator {
            port pressurePort: PressurePort;
            port controlPort: ControlPort;
            perform action pressurize: Pressurize;
            perform action depressurize: Depressurize;
        }
        part def SystemController {
            port requestPort: RequestPort;
            port loadingControlPort: ~ControlPort;
            port receivingControlPort1: ~ControlPort;
            port receivingControlPort2: ~ControlPort;
            port pressureControlPort: ~ControlPort;
            port safetyInPort: ~SafetyPort;

            exhibit state controllerStates {
                entry action initialize;
                state standby;
                state loading;
                state pressurizing;
                state transporting;
                state receiving;
                state depressurizing;
                state fault;

                transition init_to_standby
                    first start then standby;

                transition standby_to_loading
                    first standby
                    accept request: TransportRequestSignal via requestPort
                    then loading;

                transition loading_to_pressurizing
                    first loading
                    accept loaded: CapsuleLoadedSignal via loadingControlPort
                    then pressurizing;

                transition pressurizing_to_transporting
                    first pressurizing
                    accept reached: PressureReachedSignal via pressureControlPort
                    then transporting;

                transition transporting_to_receiving
                    first transporting
                    accept arrived: CapsuleArrivedSignal via receivingControlPort1
                    then receiving;

                transition receiving_to_depressurizing
                    first receiving
                    accept extracted: CapsuleExtractedSignal via receivingControlPort1
                    then depressurizing;

                transition depressurizing_to_standby
                    first depressurizing
                    accept normalized: PressureNormalizedSignal via pressureControlPort
                    then standby;

                transition standby_to_fault
                    first standby
                    accept fault: FaultSignal via safetyInPort
                    then fault;
                transition loading_to_fault
                    first loading
                    accept fault: FaultSignal via safetyInPort
                    then fault;
                transition pressurizing_to_fault
                    first pressurizing
                    accept fault: FaultSignal via safetyInPort
                    then fault;
                transition transporting_to_fault
                    first transporting
                    accept fault: FaultSignal via safetyInPort
                    then fault;
                transition receiving_to_fault
                    first receiving
                    accept fault: FaultSignal via safetyInPort
                    then fault;
                transition depressurizing_to_fault
                    first depressurizing
                    accept fault: FaultSignal via safetyInPort
                    then fault;

                transition fault_to_standby
                    first fault
                    accept reset: ResetSignal
                    then standby;
            }
        }
        part def TubexSystem {
            attribute maxSpeed: ISQ::SpeedValue = 8 [m/s];
            attribute maxPayloadWeight: ISQ::MassValue = 1.5 [kg];

            part controller: SystemController;
            part pressureGenerator: PressureGenerator;
            part tubeNetwork: TubeNetwork;
            part loadingStation: LoadingStation;
            part receivingStation1: ReceivingStation;
            part receivingStation2: ReceivingStation;
            part safetySensor: SafetySensor;

            connect loadingStation.tubePort to tubeNetwork.mainTubePort;
            connect tubeNetwork.branch1Port to receivingStation1.tubePort;
            connect tubeNetwork.branch2Port to receivingStation2.tubePort;
            connect pressureGenerator.pressurePort to tubeNetwork.pressurePort;
            connect controller.loadingControlPort to loadingStation.controlPort;
            connect controller.receivingControlPort1 to receivingStation1.controlPort;
            connect controller.receivingControlPort2 to receivingStation2.controlPort;
            connect controller.pressureControlPort to pressureGenerator.controlPort;
            connect safetySensor.safetyPort to controller.safetyInPort;
        }

        requirement def PayloadWeightRequirement {
            doc /* The capsule must carry payloads weighing up to 1.5 kg. */
            subject capsule: Capsule;
            constraint { capsule.payload.weight <= 1.5 [kg] }
        }
        requirement def SpeedRequirement {
            doc /* The system must achieve capsule transport speeds up to 8 m/s. */
            subject system: TubexSystem;
            constraint { system.maxSpeed <= 8 [m/s] }
        }
        requirement def SafetyRequirement {
            doc /* The system must enter a safe state when a fault is detected. */
            subject system: TubexSystem;
        }
    }

    package Usages {
        private import Definitions::*;

        part tubex: TubexSystem {
            part receivingStation1: ReceivingStation {
                :>> stationId = "Floor1";
            }
            part receivingStation2: ReceivingStation {
                :>> stationId = "Floor2";
            }
        }

        requirement payloadReq: PayloadWeightRequirement;
        requirement speedReq: SpeedRequirement {
            subject system = tubex;
        }
        requirement safetyReq: SafetyRequirement {
            subject system = tubex;
        }
    }
}
