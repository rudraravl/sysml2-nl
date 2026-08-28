package PLCBUS_HomeAutomation {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    enum def PLCBUSCommand {
        enum on;
        enum off;
        enum dim;
        enum statusRequest;
        enum statusResponse;
    }

    attribute def Address {
        attribute homeCode : Integer;
        attribute unitCode : Integer;
    }

    item def PLCBUSMessage {
        attribute homeCode : Integer;
        attribute unitCode : Integer;
        attribute command : PLCBUSCommand;
        attribute dimLevel : Real = 0.0;
    }

    port def PLCBUSPort {
        in item msgIn : PLCBUSMessage;
        out item msgOut : PLCBUSMessage;
    }

    part def PowerLineNetwork {
        attribute voltage : ElectricPotentialValue = 120 [V];
        attribute frequency : FrequencyValue = 60 [Hz];
        port plcbusInterface : PLCBUSPort;
    }

    part def PLCBUSTransceiver {
        attribute carrierFrequency : FrequencyValue = 131000 [Hz];
        port linePort : ~PLCBUSPort;
        port devicePort : ~PLCBUSPort;

        action modulate {
            in digitalMsg : PLCBUSMessage;
            out carrierSignal : Real;
        }
        action demodulate {
            in carrierSignal : Real;
            out digitalMsg : PLCBUSMessage;
        }
    }

    abstract part def PLCBUSDevice {
        attribute address : Address;
        port plcbusPort : ~PLCBUSPort;
        part transceiver : PLCBUSTransceiver;

        connect transceiver.linePort to plcbusPort;
    }

    part def Relay {
        attribute relayState : Boolean = false;
    }

    part def DimmerCircuit {
        attribute level : Real = 0.0;
    }

    part def DimmableLight :> PLCBUSDevice {
        attribute brightness : Real = 0.0;
        part relay : Relay;
        part dimmerCircuit : DimmerCircuit;

        action respondToStatus {
            first start;
            then send PLCBUSMessage { homeCode = address.homeCode; unitCode = address.unitCode; command = PLCBUSCommand::statusResponse; dimLevel = brightness; } to plcbusPort;
            then done;
        }

        state machine lightBehavior {
            state off;
            state on;
            state dimming;
            transition first initial -> off;
            transition t1: off -> on accept msg : PLCBUSMessage if msg.homeCode == address.homeCode and msg.unitCode == address.unitCode and msg.command == PLCBUSCommand::on;
            transition t2: on -> off accept msg : PLCBUSMessage if msg.homeCode == address.homeCode and msg.unitCode == address.unitCode and msg.command == PLCBUSCommand::off;
            transition t3: on -> dimming accept msg : PLCBUSMessage if msg.homeCode == address.homeCode and msg.unitCode == address.unitCode and msg.command == PLCBUSCommand::dim;
            transition t4: dimming -> on accept msg : PLCBUSMessage if msg.homeCode == address.homeCode and msg.unitCode == address.unitCode and msg.command == PLCBUSCommand::on;
            transition t5: dimming -> off accept msg : PLCBUSMessage if msg.homeCode == address.homeCode and msg.unitCode == address.unitCode and msg.command == PLCBUSCommand::off;
            transition t6: on -> on accept msg : PLCBUSMessage if msg.homeCode == address.homeCode and msg.unitCode == address.unitCode and msg.command == PLCBUSCommand::statusRequest;
        }
    }

    part def SwitchedOutlet :> PLCBUSDevice {
        attribute isOn : Boolean = false;
        part relay : Relay;

        action respondToStatus {
            first start;
            then send PLCBUSMessage { homeCode = address.homeCode; unitCode = address.unitCode; command = PLCBUSCommand::statusResponse; dimLevel = if isOn then 1.0 else 0.0; } to plcbusPort;
            then done;
        }

        state machine outletBehavior {
            state off;
            state on;
            transition first initial -> off;
            transition t1: off -> on accept msg : PLCBUSMessage if msg.homeCode == address.homeCode and msg.unitCode == address.unitCode and msg.command == PLCBUSCommand::on;
            transition t2: on -> off accept msg : PLCBUSMessage if msg.homeCode == address.homeCode and msg.unitCode == address.unitCode and msg.command == PLCBUSCommand::off;
            transition t3: on -> on accept msg : PLCBUSMessage if msg.homeCode == address.homeCode and msg.unitCode == address.unitCode and msg.command == PLCBUSCommand::statusRequest;
        }
    }

    part def WallSwitch :> PLCBUSDevice {
        attribute isPressed : Boolean = false;
        attribute targetAddress : Address;
        attribute targetCommand : PLCBUSCommand = PLCBUSCommand::on;

        action onPress {
            first start;
            then send PLCBUSMessage { homeCode = targetAddress.homeCode; unitCode = targetAddress.unitCode; command = targetCommand; } to plcbusPort;
            then done;
        }

        state machine switchBehavior {
            state idle;
            state pressed;
            transition first initial -> idle;
            transition t1: idle -> pressed when isPressed == true;
            transition t2: pressed -> idle when isPressed == false;
        }
    }

    part def PLCBUSController :> PLCBUSDevice {
        attribute scheduled
