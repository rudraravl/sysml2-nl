package UPB_Home_Automation {

    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQElectromagnetism::*;
    private import SI::*;

    package Definitions {

        attribute def CommandRequest;
        attribute def StatusReceived;
        attribute def TurnOn;
        attribute def TurnOff;
        attribute def SetLevel;

        enum def CommandKind {
            enum turnOn;
            enum turnOff;
            enum setLevel;
            enum statusRequest;
            enum statusReport;
        }

        attribute def UPBAddress {
            attribute networkId : Integer;
            attribute unitId : Integer;
        }

        item def UPBPacket {
            attribute targetAddress : UPBAddress;
            attribute sourceAddress : UPBAddress;
            attribute command : CommandKind;
            attribute level : Real;
        }

        port def UPBPort {
            in item rxPacket : UPBPacket;
            out item txPacket : UPBPacket;
        }

        port def PowerPort {
            attribute voltage : ElectricPotential = 120 [V];
            attribute frequency : Frequency = 60 [Hz];
        }

        part def UPBController {
            attribute controllerAddress : UPBAddress;
            port powerPort : PowerPort;
            port upbPort : UPBPort;
            perform action sendCommand : SendCommand;
            perform action receiveStatus : ReceiveStatus;
            exhibit state controllerStates : ControllerStates;
        }

        abstract part def UPBDevice {
            attribute deviceAddress : UPBAddress;
            attribute powerConsumption : Power;
            port powerPort : PowerPort;
            port upbPort : UPBPort;
            perform action processCommand : ProcessCommand;
            perform action reportStatus : ReportStatus;
        }

        part def DimmableLight :> UPBDevice {
            attribute brightness : Real;
            exhibit state lightStates : LightStates;
        }

        part def SwitchedOutlet :> UPBDevice {
            attribute isOn : Boolean;
            exhibit state outletStates : OutletStates;
        }

        part def PowerLineBus {
            port controllerIF : UPBPort;
            port deviceIF1 : UPBPort;
            port deviceIF2 : UPBPort;
            port deviceIF3 : UPBPort;
            attribute carrierFreq : Frequency = 4.0e6 [Hz];
            attribute lineVoltage : ElectricPotential = 120 [V];
            attribute lineFrequency : Frequency = 60 [Hz];
        }

        action def SendCommand {
            in target : UPBAddress;
            in cmd : CommandKind;
            in lvl : Real default 100;
            out packet : UPBPacket;
        }

        action def ReceiveStatus {
            in packet : UPBPacket;
        }

        action def ProcessCommand {
            in packet : UPBPacket;
            out ackPacket : UPBPacket;
        }

        action def ReportStatus {
            out packet : UPBPacket;
        }

        action def ModulateSignal {
            in data : UPBPacket;
            attribute carrier : Frequency;
        }

        state def ControllerStates {
            entry; then idle;
            state idle;
            accept CommandRequest
                then idle;
            accept StatusReceived
                then idle;
        }

        state def LightStates {
            entry; then off;
            state off;
            accept TurnOn
                then on;
            accept SetLevel
                then dimmed;
            state on;
            accept TurnOff
                then off;
            accept SetLevel
                then dimmed;
            state dimmed;
            accept TurnOff
                then off;
            accept TurnOn
                then on;
        }

        state def OutletStates {
            entry; then off;
            state off;
            accept TurnOn
                then on;
            state on;
            accept TurnOff
                then off;
        }

        requirement def UPBCommunicationRequirement {
            doc /* The system shall transmit digital control packets over existing AC power lines. */
            subject upbSystem;
        }

        requirement def DeviceAddressingRequirement {
            doc /* Each UPB device shall have a unique network address. */
            subject upbDevice : UPBDevice;
        }

        requirement def CommandExecutionRequirement {
            doc /* A device shall execute only commands whose target address matches its own address. */
            subject upbDevice : UPBDevice;
        }

        requirement def StatusReportingRequirement {
            doc /* Devices shall report their status back to the controller via the powerline. */
            subject upbDevice : UPBDevice;
        }
    }

    package Usages {
        private import Definitions::*;

        part upbSystem {
            satisfy upbCommReq : UPBCommunicationRequirement;
            satisfy deviceAddrReq : DeviceAddressingRequirement;
            satisfy cmdExecReq : CommandExecutionRequirement;
            satisfy statusRepReq : StatusReportingRequirement;

            part controller : UPBController {
                attribute :>> controllerAddress = UPBAddress { networkId = 1; unitId = 0; };
            }

            part powerLineBus : PowerLineBus;

            connect controller.upbPort to powerLineBus.controllerIF;

            part livingRoomLight : DimmableLight {
                attribute :>> deviceAddress = UPBAddress { networkId = 1; unitId = 1; };
                attribute :>> brightness = 100;
                attribute :>> powerConsumption = 60 [W];
            }

            connect livingRoomLight.upbPort to powerLineBus.deviceIF1;

            part bedroomLight : DimmableLight {
                attribute :>> deviceAddress = UPBAddress { networkId = 1; unitId = 2; };
                attribute :>> brightness = 50;
                attribute :>> powerConsumption = 30 [W];
            }

            connect bedroomLight.upbPort to powerLineBus.deviceIF2;

            part kitchenOutlet : SwitchedOutlet {
                attribute :>> deviceAddress = UPBAddress { networkId = 1; unitId = 3; };
                attribute :>> powerConsumption = 0 [W];
            }

            connect kitchenOutlet.upbPort to powerLineBus.deviceIF3;

            flow commandFlow of UPBPacket
                from controller.upbPort.txPacket to powerLineBus.controllerIF.rxPacket;

            flow broadcastFlow1 of UPBPacket
                from powerLineBus.deviceIF1.txPacket to livingRoomLight.upbPort.rxPacket;

            flow broadcastFlow2 of UPBPacket
                from powerLineBus.deviceIF2.txPacket to bedroomLight.upbPort.rxPacket;

            flow broadcastFlow3 of UPBPacket
                from powerLineBus.deviceIF3.txPacket to kitchenOutlet.upbPort.rxPacket;

            flow statusFlow1 of UPBPacket
                from livingRoomLight.upbPort.txPacket to powerLineBus.deviceIF1.rxPacket;

            flow statusFlow2 of UPBPacket
                from bedroomLight.upbPort.txPacket to powerLineBus.deviceIF2.rxPacket;

            flow statusFlow3 of UPBPacket
                from kitchenOutlet.upbPort.txPacket to powerLineBus.deviceIF3.rxPacket;

            flow statusReturnFlow of UPBPacket
                from powerLineBus.controllerIF.txPacket to controller.upbPort.rxPacket;
        }
    }
}
