package PhotoswitchSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def LightLevel :> Real;
        attribute def VoltageValue :> Real;
        attribute def PowerValue :> Real;

        item def LightMeasurement {
            attribute level : LightLevel;
        }
        item def RelayCommand {
            attribute cmdState : PowerState;
        }
        item def ElectricalPower {
            attribute voltage : VoltageValue;
            attribute power : PowerValue;
        }

        enum def PowerState { on; off; }

        part def PhotosensitiveSensor {
            port lightOut {
                out light : LightMeasurement;
            }
            action senseLight {
                out sensed : LightMeasurement;
            }
        }

        part def ControlUnit {
            attribute activationThreshold : LightLevel;
            attribute deactivationThreshold : LightLevel;
            port lightIn {
                in light : LightMeasurement;
            }
            port relayCmdOut {
                out cmd : RelayCommand;
            }
            exhibit state controllerStates : ControllerStates;
        }

        state def ControllerStates {
            entry action initial {}
            transition initial then off;
            state off {
                entry do send new RelayCommand(cmdState = PowerState::off) to relayCmdOut;
            }
            state on {
                entry do send new RelayCommand(cmdState = PowerState::on) to relayCmdOut;
            }
            transition off_to_on
                first off
                accept light : LightMeasurement via lightIn
                if light.level < activationThreshold
                then on;
            transition on_to_off
                first on
                accept light : LightMeasurement via lightIn
                if light.level > deactivationThreshold
                then off;
        }

        part def ElectromechanicalRelay {
            port relayCmdIn {
                in cmd : RelayCommand;
            }
            port powerIn {
                in supply : ElectricalPower;
            }
            port powerOut {
                out loadPower : ElectricalPower;
            }
            exhibit state relayStates : RelayStates;
        }

        state def RelayStates {
            entry action initial {}
            transition initial then open;
            state open;
            state closed;
            transition open_to_closed
                first open
                accept cmd : RelayCommand via relayCmdIn
                if cmd.cmdState == PowerState::on
                then closed;
            transition closed_to_open
                first closed
                accept cmd : RelayCommand via relayCmdIn
                if cmd.cmdState == PowerState::off
                then open;
        }

        part def ElectricalLoad {
            attribute ratedPower : PowerValue;
            attribute ratedVoltage : VoltageValue;
            port powerIn {
                in power : ElectricalPower;
            }
            exhibit state loadStates : LoadStates;
        }

        state def LoadStates {
            entry action initial {}
            transition initial then unpowered;
            state unpowered;
            state powered;
            transition unpowered_to_powered
                first unpowered
                accept power : ElectricalPower via powerIn
                if power.power > 0 [W]
                then powered;
            transition powered_to_unpowered
                first powered
                accept power : ElectricalPower via powerIn
                if power.power == 0 [W]
                then unpowered;
        }

        part def PowerSource {
            attribute nominalVoltage : VoltageValue;
            port powerOut {
                out supply : ElectricalPower;
            }
            action supplyPower {
                out supplied : ElectricalPower;
            }
        }

        part def PhotoswitchAssembly {
            part sensor : PhotosensitiveSensor;
            part controller : ControlUnit;
            part relay : ElectromechanicalRelay;
            part load : ElectricalLoad;
            part mains : PowerSource;

            flow lightFlow of LightMeasurement
                from sensor.lightOut.light to controller.lightIn.light;
            flow cmdFlow of RelayCommand
                from controller.relayCmdOut.cmd to relay.relayCmdIn.cmd;
            flow supplyFlow of ElectricalPower
                from mains.powerOut.supply to relay.powerIn.supply;
            flow powerFlow of ElectricalPower
                from relay.powerOut.loadPower to load.powerIn.power;
        }
    }

    package Requirements {
        requirement def TurnOnWhenDark {
            doc /* The system shall turn on the connected load when ambient light drops below the activation threshold. */;
        }
        requirement def TurnOffWhenLight {
            doc /* The system shall turn off the connected load when ambient light rises above the deactivation threshold. */;
        }
        requirement def Hysteresis {
            doc /* The system shall use separate activation and deactivation thresholds to prevent rapid flickering under fluctuating light conditions. */;
        }
        requirement def LoadCapacity {
            doc /* The system shall handle loads up to 1000W at 120V. */;
        }
        requirement def MainsCompatibility {
            doc /* The system shall operate with standard 120V household electrical supply. */;
        }
    }

    package Usages {
        private import Definitions::*;
        private import Requirements::*;

        part photoswitch : PhotoswitchAssembly {
            part :>> controller {
                attribute activationThreshold = 10 [lux];
                attribute deactivationThreshold = 50 [lux];
            }
            part :>> load {
                attribute ratedPower = 1000 [W];
                attribute ratedVoltage = 120 [V];
            }
            part :>> mains {
                attribute nominalVoltage = 120 [V];
            }
            satisfy TurnOnWhenDark;
            satisfy TurnOffWhenLight;
            satisfy Hysteresis;
            satisfy LoadCapacity;
            satisfy MainsCompatibility;
        }
    }
}
