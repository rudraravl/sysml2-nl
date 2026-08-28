package HomeAutomationSystem {

    package Types {
        value type Frequency {
            unit "Hz";
        }

        value type Power {
            unit "W";
        }

        value type Voltage {
            unit "V";
        }

        value type BrightnessLevel {
            unit "%";
        }

        enum def CommandType {
            on;
            off;
            dim;
            bright;
            allLightsOn;
            allUnitsOff;
        }

        enum def HouseCode {
            A;
            B;
            C;
            D;
            E;
            F;
            G;
            H;
            I;
            J;
            K;
            L;
            M;
            N;
            O;
            P;
        }

        enum def UnitCode {
            unit1;
            unit2;
            unit3;
            unit4;
            unit5;
            unit6;
            unit7;
            unit8;
            unit9;
            unit10;
            unit11;
            unit12;
            unit13;
            unit14;
            unit15;
            unit16;
        }

        enum def ModuleType {
            lampModule;
            applianceModule;
        }

        item def X10Address {
            attribute houseCode : HouseCode;
            attribute unitCode : UnitCode;
        }

        item def X10Command {
            attribute address : X10Address;
            attribute commandType : CommandType;
            attribute brightnessLevel : BrightnessLevel = 100;
        }

        item def RFSignal {
            attribute carrierFrequency : Frequency = 310e6;
            attribute payload : X10Command;
        }

        item def PowerLineSignal {
            attribute carrierFrequency : Frequency = 120e3;
            attribute payload : X10Command;
        }

        item def ElectricalPower {
            attribute voltage : Voltage = 120;
            attribute frequency : Frequency = 60;
        }
    }

    package Ports {
        port def SerialPort {
            out item command : Types::X10Command;
        }

        port def RFPort {
            out item rfSignal : Types::RFSignal;
        }

        port def PowerLinePort {
            out item powerLineSignal : Types::PowerLineSignal;
        }

        port def PowerOutletPort {
            out item power : Types::ElectricalPower;
        }
    }

    package Actions {
        action def EncodeCommand {
            in item command : Types::X10Command;
            out item rfSignal : Types::RFSignal;
        }

        action def DemodulateSignal {
            in item rfSignal : Types::RFSignal;
            out item command : Types::X10Command;
        }

        action def InjectPowerLine {
            in item command : Types::X10Command;
            out item powerLineSignal : Types::PowerLineSignal;
        }

        action def ExecuteDeviceCommand {
            in item powerLineSignal : Types::PowerLineSignal;
            in item moduleAddress : Types::X10Address;
            out attribute isOn : Boolean;
            out attribute brightness : Types::BrightnessLevel;
        }
    }

    package Components {

        part def HostComputer {
            port serialOut : Ports::SerialPort;

            attribute currentCommand : Types::X10Command;
            attribute commandReady : Boolean = false;
            attribute commandSent : Boolean = false;

            part userInterface {
                attribute isRunning : Boolean = true;
                attribute selectedHouseCode : Types::HouseCode;
                attribute selectedUnitCode : Types::UnitCode;
                attribute selectedCommand : Types::CommandType;
            }

            state ControlState {
                entry; then Idle;

                state Idle {
                    entry action {
                        /* Waiting for user to initiate a command via software */
                    }
                }

                state AcceptingCommand {
                    entry action {
                        /* User selects device address and command type via software UI */
                        commandReady = true;
                    }
                }

                state SendingCommand {
                    entry action {
                        /* Transmit X10 command to Firecracker via serial port */
                        serialOut.command = currentCommand;
                        commandSent = true;
                    }
                }

                transition from Idle to AcceptingCommand
                    when userInterface.selectedCommand != null;

                transition from AcceptingCommand to SendingCommand
                    when commandReady == true;

                transition from SendingCommand to Idle
                    when commandSent == true;
            }
        }

        part def FirecrackerTransmitter {
            port serialIn : ~Ports::SerialPort;
            port rfOut : Ports::RFPort;

            attribute carrierFrequency : Types::Frequency = 310e6;
            attribute receivedCommand : Types::X10Command;
            attribute rfSignalReady : Boolean = false;
            attribute rfSignalSent : Boolean = false;

            constraint {
                carrierFrequency == 310e6;
            }

            state TransmitterState {
                entry; then Listening;

                state Listening {
                    entry action {
                        /* Waiting for command from host computer via serial port */
                    }
                }

                state Encoding {
                    entry action {
                        /* Convert digital X10 command to 310 MHz RF signal format */
                        rfOut.rfSignal = Types::RFSignal {
                            carrierFrequency = 310e6,
                            payload = receivedCommand
                        };
                        rfSignalReady = true;
                    }
                }

                state Broadcasting {
                    entry action {
                        /* Transmit 310 MHz RF signal wirelessly through antenna */
                        rfSignalSent = true;
                    }
                }

                transition from Listening to Encoding
                    when serialIn.command != null;

                transition from Encoding to Broadcasting
                    when rfSignalReady == true;

                transition from Broadcasting to Listening
                    when rfSignalSent == true;
            }
        }

        part def RFReceiver {
            port rfIn : ~Ports::RFPort;
            port powerLineOut : Ports::PowerLinePort;
            port powerIn : ~Ports::PowerOutletPort;

            attribute acLineFrequency : Types::Frequency = 60;
            attribute receivedSignal : Types::RFSignal;
            attribute demodulatedCommand : Types::X10Command;
            attribute signalDemodulated : Boolean = false;
            attribute signalInjected : Boolean = false;

            constraint {
                acLineFrequency == 60;
            }

            state ReceiverState {
                entry; then Monitoring;

                state Monitoring {
                    entry action {
                        /* Listening for 310 MHz RF signals from Firecracker transmitter */
                    }
                }

                state Demodulating {
                    entry action {
                        /* Extract X10 command from 310 MHz RF carrier signal */
                        demodulatedCommand = receivedSignal.payload;
                        signalDemodulated = true;
                    }
                }

                state Injecting {
                    entry action {
                        /* Inject X10 command onto 60 Hz AC power line */
                        powerLineOut.powerLineSignal = Types::PowerLineSignal {
                            carrierFrequency = 120e3,
                            payload = demodulatedCommand
                        };
                        signalInjected = true;
                    }
                }

                transition from Monitoring to Demodulating
                    when rfIn.rfSignal != null;

                transition from Demodulating to Injecting
                    when signalDemodulated == true;

                transition from Injecting to Monitoring
                    when signalInjected == true;
            }
        }

        part def X10DeviceModule {
            port powerLineIn : ~Ports::PowerLinePort;
            port powerIn : ~Ports::PowerOutletPort;
            port deviceOut : Ports::PowerOutletPort;

            attribute address : Types::X10Address;
            attribute moduleType : Types::ModuleType;
            attribute isOn : Boolean = false;
            attribute brightness : Types::BrightnessLevel = 100;
            attribute connectedLoad : Types::Power;
            attribute supportsDimming : Boolean = false;
            attribute commandProcessed : Boolean = false;

            state DeviceState {
                entry; then Standby;

                state Standby {
                    entry action {
                        /* Monitoring power line for X10 commands matching this module address */
                    }
                }

                state Processing {
                    entry action {
                        /* Parse incoming power line signal and check address match */
                    }
                }

                state On {
                    entry action {
                        isOn = true;
                        brightness = 100;
                        deviceOut.power = Types::ElectricalPower {
                            voltage = 120,
                            frequency = 60
                        };
                    }
                }

                state Off {
                    entry action {
                        isOn = false;
                    }
                }

                state Dimmed {
                    entry action {
                        if brightness > 0 {
                            brightness = brightness - 10;
                        }
                        isOn = (brightness > 0);
                    }
                }

                state Brightened {
                    entry action {
                        if brightness < 100 {
                            brightness = brightness + 10;
                        }
                        isOn = true;
                    }
                }

                transition from Standby to Processing
                    when powerLineIn.powerLineSignal != null;

                transition from Processing to On
                    when powerLineIn.powerLineSignal.payload.commandType == Types::CommandType::on
                    and powerLineIn.powerLineSignal.payload.address == address;

                transition from Processing to Off
                    when powerLineIn.powerLineSignal.payload.commandType == Types::CommandType::off
                    and powerLineIn.powerLineSignal.payload.address == address;

                transition from Processing to Dimmed
                    when powerLineIn.powerLineSignal.payload.commandType == Types::CommandType::dim
                    and powerLineIn.powerLineSignal.payload.address == address
                    and supportsDimming == true;

                transition from Processing to Brightened
                    when powerLineIn.powerLineSignal.payload.commandType == Types::CommandType::bright
                    and powerLineIn.powerLineSignal.payload.address == address
                    and supportsDimming == true;

                transition from Processing to On
                    when powerLineIn.powerLineSignal.payload.commandType == Types::CommandType::allLightsOn
                    and moduleType == Types::ModuleType::lampModule;

                transition from Processing to Off
                    when powerLineIn.powerLineSignal.payload.commandType == Types::CommandType::allUnitsOff
                    and powerLineIn.powerLineSignal.payload.address.houseCode == address.houseCode;

                transition from On to Standby
                    when commandProcessed == true;

                transition from Off to Standby
                    when commandProcessed == true;

                transition from Dimmed to Standby
                    when commandProcessed == true;

                transition from Brightened to Standby
                    when commandProcessed == true;
            }
        }

        part def LampModule :> X10DeviceModule {
            attribute moduleType : Types::ModuleType = Types::ModuleType::lampModule;
            attribute supportsDimming : Boolean = true;
        }

        part def ApplianceModule :> X10DeviceModule {
            attribute moduleType : Types::ModuleType = Types::ModuleType::applianceModule;
            attribute supportsDimming : Boolean = false;
        }
    }

    package Requirements {

        requirement def RemoteControlRequirement {
            doc "The system shall allow a user to remotely control household lights and appliances from a host computer.";
        }

        requirement def RFCommunicationRequirement {
            doc "The Firecracker transmitter shall broadcast commands via 310 MHz RF signals.";
            attribute carrierFrequency : Types::Frequency = 310e6;
        }

        requirement def PowerLineCommunicationRequirement {
            doc "The RF receiver shall inject commands onto the existing 60 Hz AC power line.";
            attribute acLineFrequency : Types::Frequency = 60;
        }

        requirement def DeviceAddressingRequirement {
            doc "Each X10 device module shall be configured with a unique house code and unit code address.";
        }

        requirement def CommandSupportRequirement {
            doc "The system shall support on, off, dim, bright, all lights on, and all units off commands.";
        }

        requirement def NoNewWiringRequirement {
            doc "The system shall operate using existing household electrical wiring without requiring new wiring installation.";
        }

        requirement def SerialInterfaceRequirement {
            doc "The Firecracker transmitter shall connect to the host computer via a serial port interface.";
        }

        requirement def RFReceptionRequirement {
            doc "The RF receiver shall demodulate valid 310 MHz RF signals and convert them to power line commands.";
        }

        requirement def ModuleResponseRequirement {
            doc "Each X10 device module shall monitor the power line and execute commands matching its configured address.";
        }
    }

    package SystemAssembly {

        part def HomeAutomationSystem {
            part hostComputer : Components::HostComputer {
                attribute currentCommand : Types::X10Command = Types::X10Command {
                    address = Types::X10Address {
                        houseCode = Types::HouseCode::A,
                        unitCode = Types::UnitCode::unit1
                    },
                    commandType = Types::CommandType::on,
                    brightnessLevel = 100
                };
            }

            part firecracker : Components::FirecrackerTransmitter;

            part rfReceiver : Components::RFReceiver;

            part livingRoomLamp : Components::LampModule {
                attribute address : Types::X10Address = Types::X10Address {
                    houseCode = Types::HouseCode::A,
                    unitCode = Types::UnitCode::unit1
                };
                attribute connectedLoad : Types::Power = 60;
            }

            part kitchenAppliance : Components::ApplianceModule {
                attribute address : Types::X10Address = Types::X10Address {
                    houseCode = Types::HouseCode::A,
                    unitCode = Types::UnitCode::unit2
                };
                attribute connectedLoad : Types::Power = 1500;
            }

            part bedroomLamp : Components::LampModule {
                attribute address : Types::X10Address = Types::X10Address {
                    houseCode = Types::HouseCode::A,
                    unitCode = Types::UnitCode::unit3
                };
                attribute connectedLoad : Types::Power = 75;
            }

            part outdoorLamp : Components::LampModule {
                attribute address : Types::X10Address = Types::X10Address {
                    houseCode = Types::HouseCode::A,
                    unitCode = Types::UnitCode::unit4
                };
                attribute connectedLoad : Types::Power = 100;
            }

            part livingRoomFan : Components::ApplianceModule {
                attribute address : Types::X10Address = Types::X10Address {
                    houseCode = Types::HouseCode::B,
                    unitCode = Types::UnitCode::unit1
                };
                attribute connectedLoad : Types::Power = 80;
            }

            connection serialLink connect hostComputer.serialOut to firecracker.serialIn;

            connection rfLink connect firecracker.rfOut to rfReceiver.rfIn;

            connection powerLineToLivingRoom connect rfReceiver.powerLineOut to livingRoomLamp.powerLineIn;
            connection powerLineToKitchen connect rfReceiver.powerLineOut to kitchenAppliance.powerLineIn;
            connection powerLineToBedroom connect rfReceiver.powerLineOut to bedroomLamp.powerLineIn;
            connection powerLineToOutdoor connect rfReceiver.powerLineOut to outdoorLamp.powerLineIn;
            connection powerLineToFan connect rfReceiver.powerLineOut to livingRoomFan.powerLineIn;

            connection livingRoomLampPower connect livingRoomLamp.deviceOut to livingRoomLamp.powerIn;
            connection kitchenAppliancePower connect kitchenAppliance.deviceOut to kitchenAppliance.powerIn;
            connection bedroomLampPower connect bedroomLamp.deviceOut to bedroomLamp.powerIn;
            connection outdoorLampPower connect outdoorLamp.deviceOut to outdoorLamp.powerIn;
            connection livingRoomFanPower connect livingRoomFan.deviceOut to livingRoomFan.powerIn;

            satisfy Requirements::RemoteControlRequirement;
            satisfy Requirements::RFCommunicationRequirement;
            satisfy Requirements::PowerLineCommunicationRequirement;
            satisfy Requirements::DeviceAddressingRequirement;
            satisfy Requirements::CommandSupportRequirement;
            satisfy Requirements::NoNewWiringRequirement;
            satisfy Requirements::SerialInterfaceRequirement;
            satisfy Requirements::RFReceptionRequirement;
            satisfy Requirements::ModuleResponseRequirement;
        }
    }
}
