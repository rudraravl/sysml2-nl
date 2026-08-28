package WakeOnLAN {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def MACAddress :> String;

    attribute def MagicPacket {
        attribute syncHeader : String;
        attribute targetMAC : MACAddress;
        attribute repeatCount : Integer = 16;
    }
    attribute def WakeSignal;
    attribute def ShutdownSignal;
    attribute def StandbyCommand;
    attribute def TriggerWakeup;

    port def NetworkPort {
        in packet : MagicPacket;
        out sendPacket : MagicPacket;
    }
    port def PowerPort {
        out wake : WakeSignal;
    }

    action def BootSystem;
    action def LoadOS;
    action def RestoreFullPower;

    state def InitiatorStates;
    state def NICStates;
    state def PMCStates;
    state def ComputerStates;
    state def SwitchStates;

    part def InitiatorDevice {
        port networkOut : NetworkPort;
        attribute targetMAC : MACAddress;
    }

    part def NIC {
        port networkIn : ~NetworkPort;
        port powerOut : PowerPort;
        attribute ownMAC : MACAddress;
    }

    part def PowerManagementController {
        port powerIn : ~PowerPort;
        attribute standbyPowerLimit : Real = 5.0;
    }

    part def CPU;

    part def TargetComputer {
        part nic : NIC;
        part pmc : PowerManagementController;
        part cpu : CPU;
        port networkPort : NetworkPort;

        connect networkPort to nic.networkIn;
        connect nic.powerOut to pmc.powerIn;
    }

    part def NetworkSwitch {
        port port1 : NetworkPort;
        port port2 : NetworkPort;
    }

    part def WOLSystem {
        part initiator : InitiatorDevice;
        part switch : NetworkSwitch;
        part target : TargetComputer;

        connect initiator.networkOut to switch.port1;
        connect switch.port2 to target.networkPort;
    }

    action bootSystem : BootSystem;
    action loadOS : LoadOS;
    action restoreFullPower : RestoreFullPower;

    state initiatorStates : InitiatorStates {
        in initiator : InitiatorDevice;
        entry; then idle;
        state idle;
        accept TriggerWakeup
            do send new MagicPacket() to initiator.networkOut
            then idle;
    }

    state nicStates : NICStates {
        in nic : NIC;
        entry; then listening;
        state listening;
        accept MagicPacket
            do send new WakeSignal() to nic.powerOut
            then listening;
    }

    state pmcStates : PMCStates {
        in pmc : PowerManagementController;
        entry; then standby;
        state standby;
        accept WakeSignal
            then awake;
        state awake {
            entry restoreFullPower;
            do bootSystem;
            do loadOS;
        }
        accept ShutdownSignal
            then standby;
    }

    state computerStates : ComputerStates {
        entry; then off;
        state off;
        accept StandbyCommand then standby;
        state standby;
        accept WakeSignal then awake;
        state awake;
        accept ShutdownSignal then off;
    }

    state switchStates : SwitchStates {
        entry; then active;
        state active;
    }

    requirement def 'Remote Wake-Up Requirement' {
        doc /* The system shall enable remotely powering on a target computer from a low-power standby state using a Magic Packet. */
        subject wolSystem : WOLSystem;
    }

    requirement def 'Low Power Standby Requirement' {
        doc /* The target computer in standby state shall consume less than 5 watts of power. */
        subject targetComputer : TargetComputer;
    }
}
