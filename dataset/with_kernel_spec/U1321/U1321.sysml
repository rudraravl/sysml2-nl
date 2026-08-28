package HomeAutomation_X10 {
    import ScalarValues::*;
    
    enum def X10Function {
        ON;
        OFF;
        DIM;
        BRIGHT;
        ALL_LIGHTS_ON;
    }

    item def X10Command {
        attribute houseCode: String;
        attribute unitCode: Integer;
        attribute function: X10Function;
    }

    attribute def FrequencyValue :> ScalarValues::Real;
    attribute def ElectricPotentialValue :> ScalarValues::Real;

    unit def MHz;
    unit def Hz;
    unit def V;

    item def RFSignal {
        attribute carrierFrequency: FrequencyValue = 310 [MHz];
        attribute payload: X10Command;
    }

    item def PowerLineSignal {
        attribute lineFrequency: FrequencyValue = 60 [Hz];
        attribute payload: X10Command;
    }

    item def ElectricalPower {
        attribute voltage: ElectricPotentialValue = 120 [V];
        attribute frequency: FrequencyValue = 60 [Hz];
    }

    port def SerialPort {
        out command: X10Command;
    }

    port def RFPort {
        out rfSignal: RFSignal;
    }

    port def PowerLinePort {
        out plSignal: PowerLineSignal;
    }

    port def ElectricalOutletPort {
        out power: ElectricalPower;
    }

    part def HostComputer {
        port serialOut: SerialPort;
    }

    part def FirecrackerTransmitter {
        port serialIn: ~SerialPort;
        port rfOut: RFPort;

        state TransmitterBehavior {
            entry then Waiting;
            state Waiting {
                accept cmd: X10Command via serialIn
                do send new RFSignal(payload = cmd) via rfOut;
                then Waiting;
            }
        }
    }

    part def RFReceiver {
        port rfIn: ~RFPort;
        port plOut: PowerLinePort;

        state ReceiverBehavior {
            entry then Listening;
            state Listening {
                accept rf: RFSignal via rfIn
                do send new PowerLineSignal(payload = rf.payload) via plOut;
                then Listening;
            }
        }
    }

    part def ControlledDevice {
        port powerIn: ~ElectricalOutletPort;
    }

    part def Lamp :> ControlledDevice;
    part def Appliance :> ControlledDevice;

    part def X10DeviceModule {
        attribute houseCode: String;
        attribute unitCode: Integer;

        port plIn: ~PowerLinePort;
        port outlet: ElectricalOutletPort;

        part controlledDevice: ControlledDevice;

        state DeviceControlStateMachine {
            entry then Off;
            state Off {
                accept sig: PowerLineSignal via plIn
                    if sig.payload.houseCode == houseCode and sig.payload.unitCode == unitCode
                        and (sig.payload.function == X10Function::ON
                             or sig.payload.function == X10Function::ALL_LIGHTS_ON)
                do send new ElectricalPower() via outlet;
                then On;
            }
            state On {
                accept sig: PowerLineSignal via plIn
                    if sig.payload.houseCode == houseCode and sig.payload.unitCode == unitCode
                        and sig.payload.function == X10Function::OFF
                then Off;

                accept sig: PowerLineSignal via plIn
                    if sig.payload.houseCode == houseCode and sig.payload.unitCode == unitCode
                        and (sig.payload.function == X10Function::DIM
                             or sig.payload.function == X10Function::BRIGHT)
                do send new ElectricalPower() via outlet;
                then On;
            }
        }
    }

    part def LampModule :> X10DeviceModule;
    part def ApplianceModule :> X10DeviceModule;

    requirement def RemoteControlRequirement {
        doc /* The system shall allow a user to remotely control household lights and appliances from a host computer. */
    }

    requirement def RFTransmissionRequirement {
        doc /* The Firecracker transmitter shall convert serial commands into 310 MHz RF signals. */
    }

    requirement def PowerLineInjectionRequirement {
        doc /* The RF receiver shall inject commands onto the home's 60 Hz AC power lines. */
    }

    requirement def AddressMatchingRequirement {
        doc /* X10 device modules shall execute commands only when the received house code and unit code match their configured address. */
    }

    requirement def CommandSupportRequirement {
        doc /* The system shall support on, off, dim, bright, and all lights on commands. */
    }

    part def HomeAutomationSystem {
        part hostComputer: HostComputer;
        part firecracker: FirecrackerTransmitter;
        part rfReceiver: RFReceiver;

        part lampModule: LampModule {
            :>> houseCode = "A";
            :>> unitCode = 1;
            part :>> controlledDevice : Lamp;
        }

        part applianceModule: ApplianceModule {
            :>> houseCode = "A";
            :>> unitCode = 2;
            part :>> controlledDevice : Appliance;
        }

        interface SerialConnection connect hostComputer.serialOut to firecracker.serialIn {
            flow cmdFlow of X10Command
                from hostComputer.serialOut.command to firecracker.serialIn.command;
        }

        interface RFConnection connect firecracker.rfOut to rfReceiver.rfIn {
            flow rfFlow of RFSignal
                from firecracker.rfOut.rfSignal to rfReceiver.rfIn.rfSignal;
        }

        interface PowerLineToLamp connect rfReceiver.plOut to lampModule.plIn {
            flow plFlowLamp of PowerLineSignal
                from rfReceiver.plOut.plSignal to lampModule.plIn.plSignal;
        }

        interface PowerLineToAppliance connect rfReceiver.plOut to applianceModule.plIn {
            flow plFlowAppliance of PowerLineSignal
                from rfReceiver.plOut.plSignal to applianceModule.plIn.plSignal;
        }

        interface LampPowerConnection connect lampModule.outlet to lampModule.controlledDevice.powerIn {
            flow lampPowerFlow of ElectricalPower
                from lampModule.outlet.power to lampModule.controlledDevice.powerIn.power;
        }

        interface AppliancePowerConnection connect applianceModule.outlet to applianceModule.controlledDevice.powerIn {
            flow appliancePowerFlow of ElectricalPower
                from applianceModule.outlet.power to applianceModule.controlledDevice.powerIn.power;
        }
    }

    requirement remoteControlReq : RemoteControlRequirement;
    requirement rfTransmissionReq : RFTransmissionRequirement;
    requirement powerLineInjectionReq : PowerLineInjectionRequirement;
    requirement addressMatchingReq : AddressMatchingRequirement;
    requirement commandSupportReq : CommandSupportRequirement;

    part homeSystem: HomeAutomationSystem;

    satisfy remoteControlReq by homeSystem;
    satisfy rfTransmissionReq by homeSystem;
    satisfy powerLineInjectionReq by homeSystem;
    satisfy addressMatchingReq by homeSystem;
    satisfy commandSupportReq by homeSystem;
}
