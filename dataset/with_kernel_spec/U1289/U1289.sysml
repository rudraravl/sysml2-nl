package HomeLinkSystem {
    import ScalarValues::*;
    
    attribute def Voltage :> Real { unit "V"; }
    attribute def Frequency :> Real { unit "MHz"; }
    attribute def Distance :> Real { unit "m"; }

    item def DeviceCode {
        attribute manufacturerId : String;
        attribute deviceId : String;
    }
    item def RollingCode {
        attribute code : Integer;
    }
    item def RFSignal {
        attribute frequency : Frequency = 315;
        attribute rollingCode : RollingCode;
        attribute command : String;
    }
    item def RemoteSignal {
        attribute manufacturerId : String;
        attribute deviceId : String;
    }
    item def ButtonPress {
        attribute buttonId : Integer;
    }
    item def LearnCommand;
    item def ActivationCommand {
        attribute action : String;
    }

    port def PowerPort {
        out item voltage : Voltage;
    }
    port def RFPort {
        out item rfSignal : RFSignal;
        in item remoteSignal : RemoteSignal;
    }
    port def DoorControlPort {
        out item command : ActivationCommand;
    }

    part def Button {
        attribute buttonId : Integer;
    }
    part def Processor;
    part def MemoryUnit {
        attribute slots : DeviceCode[3];
        attribute counter : Integer = 0;
    }
    part def RFTransceiver {
        port rf : ~RFPort;
    }

    part def TransmitterModule {
        attribute powerInput : Voltage = 12;
        attribute range : Distance = 30;

        part buttons : Button[3];
        part processor : Processor;
        part memory : MemoryUnit;
        part transceiver : RFTransceiver;

        port powerIn : ~PowerPort;
        port rfPort : RFPort;

        connect transceiver.rf to rfPort;

        action retrieveCode;
        action generateRollingCode;
        action transmitSignal;
        action listenForRemote;
        action captureAndStore;

        state def TransmitterStates {
            entry; then standby;
            state standby;
            accept buttonPress : ButtonPress
                do retrieveCode
                then transmitting;
            accept learnCommand : LearnCommand
                then learning;
            state transmitting {
                entry; do generateRollingCode;
                do transmitSignal;
            }
            transition first transmitting then standby;
            state learning {
                entry; do listenForRemote;
                accept remoteSignal : RemoteSignal
                    do captureAndStore
                    then standby;
            }
        }

        state transmitterStates : TransmitterStates;
    }

    part def RFReceiver {
        port rf : RFPort;
    }
    part def Authenticator {
        port doorControl : DoorControlPort;
        attribute valid : Boolean = false;
    }
    part def GarageDoorMechanism {
        port control : ~DoorControlPort;
    }

    part def ReceiverSystem {
        part receiver : RFReceiver;
        part auth : Authenticator;
        part door : GarageDoorMechanism;
        port rfPort : ~RFPort;

        connect receiver.rf to rfPort;
        connect auth.doorControl to door.control;

        action authenticate;
        action sendActivationCommand;

        state def ReceiverStates {
            entry; then listening;
            state listening;
            accept rfSignal : RFSignal
                do authenticate
                then authenticated;
            state authenticated {
                entry; do sendActivationCommand;
            }
            transition first authenticated then listening;
        }

        state receiverStates : ReceiverStates;
    }

    part def GarageDoor {
        part mechanism : GarageDoorMechanism;
        part receiverSystem : ReceiverSystem;
    }

    part def HandheldRemote {
        port rfOut : ~RFPort;
    }

    part def Vehicle {
        port powerOut : PowerPort;
        part transmitter : TransmitterModule;

        connect powerOut to transmitter.powerIn;
    }

    connection def RFConnection {
        end transmitterPort : RFPort;
        end receiverPort : ~RFPort;
    }

    part homeLinkSystem {
        part vehicle : Vehicle;
        part garageDoor : GarageDoor;
        part handheldRemote : HandheldRemote;

        connection rfLink : RFConnection
            connect vehicle.transmitter.rfPort to garageDoor.receiverSystem.rfPort;
        connect handheldRemote.rfOut to vehicle.transmitter.rfPort;
    }

    requirement def OperationalRangeRequirement {
        doc "The system shall have a reliable operating range of at least 30 meters.";
        attribute minRange : Distance = 30;
    }
    requirement def RollingCodeSecurityRequirement {
        doc "The system shall use rolling code technology to prevent unauthorized replay attacks.";
    }
    requirement def ThreeProgrammableButtonsRequirement {
        doc "The transmitter module shall have three programmable buttons for up to three devices.";
    }
    requirement def ProgrammingModeRequirement {
        doc "The system shall support a programming mode to learn signals from existing remotes.";
    }
    requirement def PowerSupplyRequirement {
        doc "The in-vehicle module shall be powered by the car's 12-volt electrical system.";
        attribute supplyVoltage : Voltage = 12;
    }
    requirement def FrequencyBandRequirement {
        doc "The system shall transmit on the 315 MHz frequency band.";
        attribute targetFreq : Frequency = 315;
    }

    requirement operationalRange : OperationalRangeRequirement;
    requirement rollingCodeSecurity : RollingCodeSecurityRequirement;
    requirement threeButtons : ThreeProgrammableButtonsRequirement;
    requirement programmingMode : ProgrammingModeRequirement;
    requirement powerSupply : PowerSupplyRequirement;
    requirement frequencyBand : FrequencyBandRequirement;

    satisfy operationalRange by TransmitterModule;
    satisfy rollingCodeSecurity by TransmitterModule;
    satisfy threeButtons by TransmitterModule;
    satisfy programmingMode by TransmitterModule;
    satisfy powerSupply by TransmitterModule;
    satisfy frequencyBand by TransmitterModule;
}
