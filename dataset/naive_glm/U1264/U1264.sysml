package X10_Home_Automation {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value type FrequencyUnit > Real {
        attribute unit : String = "Hz";
    }

    value type VoltageUnit > Real {
        attribute unit : String = "V";
    }

    value type PowerUnit > Real {
        attribute unit : String = "W";
    }

    value type HouseCodeType > String;
    value type UnitCodeType > Integer;

    enum X10Function {
        on;
        off;
        dim;
        bright;
        statusRequest;
        statusReport;
    }

    value type DimLevel > Real {
        attribute unit : String = "%";
        attribute min : Real = 0.0;
        attribute max : Real = 100.0;
    }

    item def X10Address {
        attribute houseCode : HouseCodeType;
        attribute unitCode : UnitCodeType;
    }

    item def X10CommandPacket {
        attribute address : X10Address;
        attribute function : X10Function;
        attribute dimAmount : DimLevel[0..1];
    }

    item def X10StatusReport {
        attribute address : X10Address;
        attribute isOn : Boolean;
        attribute dimLevel : DimLevel[0..1];
    }

    item def PowerLineSignal {
        attribute carrierFrequency : FrequencyUnit = 120000.0 [Hz];
        attribute amplitude : VoltageUnit;
        attribute encodedPacket : X10CommandPacket;
    }

    item def ACLinePower {
        attribute voltage : VoltageUnit = 120.0 [V];
        attribute frequency : FrequencyUnit = 60.0 [Hz];
    }

    // ===== Ports =====

    port def DigitalCommandPort {
        out packet : X10CommandPacket;
        in status : X10StatusReport;
    }

    port def PowerLinePort {
        out signal : PowerLineSignal;
        in receivedSignal : PowerLineSignal;
        out acPower : ACLinePower;
    }

    port def LoadPort {
        out acPower : ACLinePower;
    }

    port def LocalControlPort {
        in manualSwitch : Boolean;
    }

    // ===== Requirements =====

    requirement def X10SystemRequirement {
        doc "The X10 home automation system shall control electrical devices remotely by sending signals over existing electrical wiring."
        attribute maxDevices : Integer = 256;
        attribute carrierFrequency : FrequencyUnit = 120000.0 [Hz];
        attribute lineVoltage : VoltageUnit = 120.0 [V];
        attribute lineFrequency : FrequencyUnit = 60.0 [Hz];
    }

    requirement def ControllerRequirement {
        subject controller : MainController;
        doc "The main controller shall generate digital command packets containing a House Code, Unit Code, and function."
    }

    requirement def TransceiverRequirement {
        subject transceiver : Transceiver;
        doc "The transceiver shall modulate digital commands into 120 kHz carrier signals and demodulate received power line signals."
    }

    requirement def PowerLineInterfaceRequirement {
        subject pli : PowerLineInterface;
        doc "The power line interface shall inject the 120 kHz signal onto the 120V/60Hz AC wiring."
    }

    requirement def ModuleRequirement {
        subject module : X10Module;
        doc "Each module shall execute the function only when its assigned address matches the command address."
    }

    requirement def LampModuleRequirement :> ModuleRequirement {
        subject module : LampModule;
        doc "Lamp modules shall support on, off, dim, and bright functions for loads up to 300 W."
        attribute maxLoad : PowerUnit = 300.0 [W];
    }

    requirement def ApplianceModuleRequirement :> ModuleRequirement {
        subject module : ApplianceModule;
        doc "Appliance modules shall support on and off functions for loads up to 1800 W."
        attribute maxLoad : PowerUnit = 1800.0 [W];
    }

    requirement def WallSwitchRequirement :> ModuleRequirement {
        subject module : WallSwitch;
        doc "Wall switches shall support on, off, and dim functions while permitting local manual control."
    }

    // ===== Behaviors =====

    state machine def X10ModuleBehavior {

        attribute address : X10Address;
        attribute isOn : Boolean = false;
        attribute dimLevel : DimLevel = 100.0;

        state Off {
            entry { isOn = false; }
            transition Off_On
                first Off
                accept packet : X10CommandPacket
                if packet.address == address and packet.function == X10Function::on
                then On;
            transition Off_Dim
                first Off
                accept packet : X10CommandPacket
                if packet.address == address and packet.function == X10Function::dim
                then Dimming;
        }

        state On {
            entry { isOn = true; dimLevel = 100.0; }
            transition On_Off
                first On
                accept packet : X10CommandPacket
                if packet.address == address and packet.function == X10Function::off
                then Off;
            transition On_Dim
                first On
                accept packet : X10CommandPacket
                if packet.address == address and packet.function == X10Function::dim
                then Dimming;
            transition On_Bright
                first On
                accept packet : X10CommandPacket
                if packet.address == address and packet.function == X10Function::bright
                then Dimming;
        }

        state Dimming {
            transition Dimming_Off
                first Dimming
                accept packet : X10CommandPacket
                if packet.address == address and packet.function == X10Function::off
                then Off;
            transition Dimming_On
                first Dimming
                accept packet : X10CommandPacket
                if packet.address == address and packet.function == X10Function::on
                then On;
            transition Dimming_Adjust
                first Dimming
                accept packet : X10CommandPacket
                if packet.address == address and (packet.function == X10Function::dim or packet.function == X10Function::bright)
                then Dimming;
        }
    }

    action def GenerateCommand {
        in houseCode : HouseCodeType;
        in unitCode : UnitCodeType;
        in function : X10Function;
        in dimAmount : DimLevel[0..1];
        out packet : X10CommandPacket;
    }

    action def ModulateSignal {
        in packet : X10CommandPacket;
        out signal : PowerLineSignal;
    }

    action def DemodulateSignal {
        in signal : PowerLineSignal;
        out packet : X10CommandPacket;
    }

    action def InjectSignal {
        in signal : PowerLineSignal;
        in acPower : ACLinePower;
        out combinedSignal : PowerLineSignal;
    }

    // ===== Parts =====

    part def MainController {
        port digitalOut : DigitalCommandPort;
        attribute issuedCommands : X10CommandPacket[0..*];

        perform action issueCommand : GenerateCommand {
            in houseCode = HouseCodeType("A");
            in unitCode = 1;
            in function = X10Function::on;
            in dimAmount = ();
            out packet = digitalOut.packet;
        }

        satisfy ControllerRequirement {
            subject controller = Self;
        }
    }

    part def Transceiver {
        port digitalIn : DigitalCommandPort;
        port lineSide : PowerLinePort;

        perform action modulate : ModulateSignal {
            in packet = digitalIn.packet;
            out signal = lineSide.signal;
        }

        perform action demodulate : DemodulateSignal {
            in signal = lineSide.receivedSignal;
            out packet = digitalIn.status;
        }

        satisfy TransceiverRequirement {
            subject transceiver = Self;
        }
    }

    part def PowerLineInterface {
        port transceiverSide : PowerLinePort;
        port wiringSide : PowerLinePort;
        attribute linePower : ACLinePower = ACLinePower{voltage = 120.0; frequency = 60.0;};

        perform action inject : InjectSignal {
            in signal = transceiverSide.signal;
            in acPower = linePower;
            out combinedSignal = wiringSide.signal;
        }

        satisfy PowerLineInterfaceRequirement {
            subject pli = Self;
        }
    }

    part def ElectricalWiring {
        port interfaceSide : PowerLinePort;
        port modulePorts : PowerLinePort[1..*];
        attribute linePower : ACLinePower = ACLinePower{voltage = 120.0; frequency = 60.0;};

        flow linePower to modulePorts.acPower;
        flow interfaceSide.signal to modulePorts.signal;
        flow modulePorts.receivedSignal to interfaceSide.receivedSignal;
    }

    part def X10Module {
        abstract attribute address : X10Address;
        attribute isOn : Boolean = false;
        attribute dimLevel : DimLevel = 100.0;
        port lineIn : PowerLinePort;
        port loadOut : LoadPort;

        perform behavior moduleBehavior : X10ModuleBehavior {
            attribute address = Self.address;
        }

        satisfy ModuleRequirement {
            subject module = Self;
        }
    }

    part def LampModule :> X10Module {
        attribute maxLoad : PowerUnit = 300.0 [W];
        attribute supportsDimming : Boolean = true;

        satisfy LampModuleRequirement {
            subject module = Self;
        }
    }

    part def ApplianceModule :> X10Module {
        attribute maxLoad : PowerUnit = 1800.0 [W];
        attribute supportsDimming : Boolean = false;

        satisfy ApplianceModuleRequirement {
            subject module = Self;
        }
    }

    part def WallSwitch :> X10Module {
        attribute maxLoad : PowerUnit = 500.0 [W];
        attribute supportsDimming : Boolean = true;
        port localControl : LocalControlPort;

        satisfy WallSwitchRequirement {
            subject module = Self;
        }
    }

    part def ElectricalLoad {
        abstract attribute ratedPower : PowerUnit;
        port powerIn : LoadPort;
        attribute isEnergized : Boolean = false;
    }

    part def Lamp :> ElectricalLoad {
        attribute ratedPower : PowerUnit = 60.0 [W];
        attribute brightness : DimLevel = 100.0;
    }

    part def Appliance :> ElectricalLoad {
        attribute ratedPower : PowerUnit = 1200.0 [W];
    }

    part def CeilingLight :> ElectricalLoad {
        attribute ratedPower : PowerUnit = 75.0 [W];
        attribute brightness : DimLevel = 100.0;
    }

    // ===== System Composition =====

    part def X10System {

        satisfy X10SystemRequirement;

        part controller : MainController {
            attribute assignedHouseCode : HouseCodeType = "A";
        }

        part transceiver : Transceiver;

        part powerLineInterface : PowerLineInterface;

        part wiring : ElectricalWiring {
            part moduleSlots : PowerLinePort[1..256];
        }

        part livingRoomLampModule : LampModule {
            attribute address = X10Address{houseCode = "A"; unitCode = 1;};
        }

        part kitchenApplianceModule : ApplianceModule {
            attribute address = X10Address{houseCode = "A"; unitCode = 2;};
        }

        part hallwayWallSwitch : WallSwitch {
            attribute address = X10Address{houseCode = "A"; unitCode = 3;};
        }

        part bedroomLampModule : LampModule {
            attribute address = X10Address{houseCode = "A"; unitCode = 4;};
        }

        part livingRoomLamp : Lamp;
        part kitchenCoffeeMaker : Appliance;
        part hallwayCeilingLight : CeilingLight;
        part bedroomLamp : Lamp;

        connect controller.digitalOut to transceiver.digitalIn;
        connect transceiver.lineSide to powerLineInterface.transceiverSide;
        connect powerLineInterface.wiringSide to wiring.interfaceSide;

        connect wiring.modulePorts[1] to livingRoomLampModule.lineIn;
        connect wiring.modulePorts[2] to kitchenApplianceModule.lineIn;
        connect wiring.modulePorts[3] to hallwayWallSwitch.lineIn;
        connect wiring.modulePorts[4] to bedroomLampModule.lineIn;

        connect livingRoomLampModule.loadOut to livingRoomLamp.powerIn;
        connect kitchenApplianceModule.loadOut to kitchenCoffeeMaker.powerIn;
        connect hallwayWallSwitch.loadOut to hallwayCeilingLight.powerIn;
        connect bedroomLampModule.loadOut to bedroomLamp.powerIn;
    }

}
