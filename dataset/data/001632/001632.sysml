package X10_HomeAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def HouseCode :> String;
    attribute def UnitCode :> Integer;
    attribute def DimLevel :> Real;

    enum def X10Function {
        allUnitsOff;
        allLightsOn;
        on;
        off;
        dim;
        bright;
        allLightsOff;
        extendedCode;
        hailRequest;
        hailAcknowledge;
        presetDim1;
        presetDim2;
        extendedData;
        statusOn;
        statusOff;
        statusRequest;
    }

    item def X10Frame {
        attribute houseCode : HouseCode;
        attribute unitCode : UnitCode;
        attribute functionCode : X10Function;
        attribute timestamp : TimeInstantValue;
    }

    port def X10BusPort {
        inout item x10Frame : X10Frame;
    }

    port def PowerLinePort {
        in item voltage : VoltageValue;
        in item frequency : FrequencyValue;
        out item modulatedSignal : X10Frame;
    }

    port def DeviceControlPort {
        out item controlSignal : Boolean;
        out item intensityLevel : DimLevel;
    }

    part def X10Transceiver {
        attribute carrierFrequency : FrequencyValue = 120000 [Hz];
        attribute bitRate : FrequencyValue = 60 [Hz];
        
        port powerLine : PowerLinePort;
        port x10Bus : X10BusPort;

        action def ModulateSignal {
            in digitalFrame : X10Frame;
            out analogSignal : X10Frame;
        }

        action def DemodulateSignal {
            in analogSignal : X10Frame;
            out digitalFrame : X10Frame;
        }

        perform action transmitReceive {
            first start;
            then merge txRxLoop;
            
            action checkMode;
            then decide;
            
            if checkMode then transmit;
            if checkMode then receive;
            
            action transmit : ModulateSignal {
                in digitalFrame;
                out analogSignal;
            }
            then txRxLoop;
            
            action receive : DemodulateSignal {
                in analogSignal;
                out digitalFrame;
            }
            then txRxLoop;
        }
    }

    part def X10Controller {
        attribute controllerHouseCode : HouseCode = "A";
        
        port x10Bus : X10BusPort;
        port userInterface;

        action def GenerateCommand {
            in targetHouse : HouseCode;
            in targetUnit : UnitCode;
            in function : X10Function;
            out command : X10Frame;
        }

        perform action controlSequence {
            first start;
            then merge controlLoop;
            
            action readUserInput {
                out desiredHouse : HouseCode;
                out desiredUnit : UnitCode;
                out desiredFunction : X10Function;
            }
            
            then action generateCmd : GenerateCommand {
                in targetHouse = readUserInput.desiredHouse;
                in targetUnit = readUserInput.desiredUnit;
                in function = readUserInput.desiredFunction;
                out command;
            }
            
            then action transmitCmd {
                in cmdFrame = generateCmd.command;
            }
            
            then controlLoop;
        }
    }

    part def X10Module {
        attribute assignedHouseCode : HouseCode;
        attribute assignedUnitCode : UnitCode;
        attribute deviceState : Boolean = false;
        attribute currentDimLevel : DimLevel = 0.0;
        
        port x10Bus : X10BusPort;
        port deviceControl : DeviceControlPort;

        action def ProcessCommand {
            in receivedFrame : X10Frame;
            out newState : Boolean;
            out newDimLevel : DimLevel;
        }

        state def ModuleStateMachine {
            entry; then idle;
            
            state idle;
            
            state listening;
            
            transition idle_to_listening
                first idle
                accept incomingFrame : X10Frame via x10Bus
                then listening;
            
            state addressMatch;
            
            transition listening_to_addressMatch
                first listening
                if incomingFrame.houseCode == assignedHouseCode and 
                   incomingFrame.unitCode == assignedUnitCode
                then addressMatch;
            
            transition listening_to_idle
                first listening
                if incomingFrame.houseCode != assignedHouseCode or 
                   incomingFrame.unitCode != assignedUnitCode
                then idle;
            
            state executing;
            
            transition addressMatch_to_executing
                first addressMatch
                then executing;
            
            state deviceOn;
            
            state deviceOff;
            
            state dimming;
            
            state brightening;
            
            transition executing_to_on
                first executing
                if incomingFrame.functionCode == X10Function::on
                then deviceOn;
            
            transition executing_to_off
                first executing
                if incomingFrame.functionCode == X10Function::off
                then deviceOff;
            
            transition executing_to_dim
                first executing
                if incomingFrame.functionCode == X10Function::dim
                then dimming;
            
            transition executing_to_bright
                first executing
                if incomingFrame.functionCode == X10Function::bright
                then brightening;
            
            transition deviceOn_to_idle
                first deviceOn
                then idle;
            
            transition deviceOff_to_idle
                first deviceOff
                then idle;
            
            transition dimming_to_idle
                first dimming
                then idle;
            
            transition brightening_to_idle
                first brightening
                then idle;
        }
    }

    part def LampModule :> X10Module {
        attribute maxWattage : PowerValue = 300 [W];
        attribute minDimLevel : DimLevel = 0.0;
        attribute maxDimLevel : DimLevel = 100.0;
        
        assert constraint dimLevelRange {
            currentDimLevel >= minDimLevel and currentDimLevel <= maxDimLevel
        }
        
        assert constraint wattageLimit {
            maxWattage <= 300 [W]
        }
    }

    part def ApplianceModule :> X10Module {
        attribute maxLoad : PowerValue = 1800 [W];
        attribute isSwitchOnly : Boolean = true;
        
        assert constraint loadLimit {
            maxLoad <= 1800 [W]
        }
        
        assert constraint noModulation {
            isSwitchOnly == true
        }
    }

    part def WallSwitch :> X10Module {
        attribute isThreeWay : Boolean = false;
        attribute localControlEnabled : Boolean = true;
    }

    part def PowerLineInterface {
        attribute lineVoltage : VoltageValue = 120 [V];
        attribute lineFrequency : FrequencyValue = 60 [Hz];
        attribute couplingCapacitance : Real = 0.1;
        
        port acPower {
            in item voltage : VoltageValue;
            in item frequency : FrequencyValue;
        }
        
        port x10Signal : X10BusPort;
        
        action def CoupleSignal {
            in powerlineVoltage : VoltageValue;
            in x10Frame : X10Frame;
            out coupledSignal : X10Frame;
        }
        
        action def FilterNoise {
            in rawSignal : X10Frame;
            out cleanSignal : X10Frame;
        }
    }

    part x10HomeSystem : X10HomeAutomationSystem {
        attribute systemHouseCode : HouseCode = "A";
        attribute totalDevices : Integer = 4;
        
        part mainController : X10Controller {
            attribute :>> controllerHouseCode = "A";
        }
        
        part transceiver : X10Transceiver {
            attribute :>> carrierFrequency = 120000 [Hz];
        }
        
        part powerlineInterface : PowerLineInterface {
            attribute :>> lineVoltage = 120 [V];
            attribute :>> lineFrequency = 60 [Hz];
        }
        
        part livingRoomLamp : LampModule {
            attribute :>> assignedHouseCode = "A";
            attribute :>> assignedUnitCode = 1;
            attribute :>> maxWattage = 150 [W];
        }
        
        part bedroomLamp : LampModule {
            attribute :>> assignedHouseCode = "A";
            attribute :>> assignedUnitCode = 2;
            attribute :>> maxWattage = 100 [W];
        }
        
        part kitchenAppliance : ApplianceModule {
            attribute :>> assignedHouseCode = "A";
            attribute :>> assignedUnitCode = 3;
            attribute :>> maxLoad = 1500 [W];
        }
        
        part hallwaySwitch : WallSwitch {
            attribute :>> assignedHouseCode = "A";
            attribute :>> assignedUnitCode = 4;
            attribute :>> isThreeWay = false;
        }
        
        connection controllerToTransceiver
            connect mainController.x10Bus to transceiver.x10Bus;
        
        connection transceiverToPowerline
            connect transceiver.powerLine to powerlineInterface.acPower;
        
        connection powerlineToLivingRoom
            connect powerlineInterface.x10Signal to livingRoomLamp.x10Bus;
        
        connection powerlineToBedroom
            connect powerlineInterface.x10Signal to bedroomLamp.x10Bus;
        
        connection powerlineToKitchen
            connect powerlineInterface.x10Signal to kitchenAppliance.x10Bus;
        
        connection powerlineToHallway
            connect powerlineInterface.x10Signal to hallwaySwitch.x10Bus;
    }

    part def X10HomeAutomationSystem;

    requirement <'REQ-X10-001'> remoteDeviceControl {
        doc /* The X10 system shall provide remote control capability for 
             * electrical devices throughout a home using powerline carrier 
             * communication without requiring additional wiring.
             */
        subject system : X10HomeAutomationSystem;
    }

    requirement <'REQ-X10-002'> standardizedAddressing {
        doc /* The system shall support standardized addressing using 16 house 
             * codes (A-P) and 16 unit codes (1-16) to uniquely identify up to 
             * 256 devices per installation.
             */
        subject system : X10HomeAutomationSystem;
    }

    requirement <'REQ-X10-003'> powerlineCarrierFrequency {
        doc /* The powerline interface shall modulate X10 commands on a 120 kHz 
             * carrier frequency synchronized to the AC power zero-crossing.
             */
        subject interface : PowerLineInterface;
        
        assert constraint {
            x10HomeSystem.transceiver.carrierFrequency == 120000 [Hz]
        }
    }

    requirement <'REQ-X10-004'> lampModuleCapacity {
        doc /* Lamp modules shall support incandescent and resistive loads up to 
             * 300 watts with dimming capability from 0% to 100%.
             */
        subject lamp : LampModule;
        
        assert constraint {
            lamp.maxWattage <= 300 [W] and 
            lamp.minDimLevel == 0.0 and 
            lamp.maxDimLevel == 100.0
        }
    }

    requirement <'REQ-X10-005'> applianceModuleCapacity {
        doc /* Appliance modules shall support resistive and inductive loads up 
             * to 1800 watts with on/off control only.
             */
        subject appliance : ApplianceModule;
        
        assert constraint {
            appliance.maxLoad <= 1800 [W] and 
            appliance.isSwitchOnly == true
        }
    }

    requirement <'REQ-X10-006'> commandSet {
        doc /* The system shall support standard X10 function codes including 
             * On, Off, Dim, Bright, All Lights On, All Lights Off, and 
             * All Units Off.
             */
        subject system : X10HomeAutomationSystem;
    }

    requirement <'REQ-X10-007'> bidirectionalCommunication {
        doc /* The transceiver shall support both transmission and reception of 
             * X10 frames to enable two-way communication and status reporting.
             */
        subject transceiver : X10Transceiver;
    }

    satisfy remoteDeviceControl by x10HomeSystem;
    satisfy standardizedAddressing by x10HomeSystem;
    satisfy powerlineCarrierFrequency by x10HomeSystem.powerlineInterface;
    satisfy lampModuleCapacity by x10HomeSystem.livingRoomLamp;
    satisfy lampModuleCapacity by x10HomeSystem.bedroomLamp;
    satisfy applianceModuleCapacity by x10HomeSystem.kitchenAppliance;
    satisfy commandSet by x10HomeSystem.mainController;
    satisfy bidirectionalCommunication by x10HomeSystem.transceiver;
}
