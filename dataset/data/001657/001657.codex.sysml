package HomeLinkWirelessControlSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def FrequencyMHz :> Real {
        unit = "MHz";
    }

    attribute def PowerMilliWatt :> Real {
        unit = "mW";
    }

    attribute def TimeMillisecond :> Real {
        unit = "ms";
    }

    attribute def DistanceMeter :> Real {
        unit = "m";
    }

    attribute def VoltageVolt :> Real {
        unit = "V";
    }

    attribute def TemperatureCelsius :> Real {
        unit = "degC";
    }

    enum def ButtonId {
        enum button1;
        enum button2;
        enum button3;
    }

    enum def CommandType {
        enum openClose;
        enum gateToggle;
        enum lightToggle;
        enum securityArmDisarm;
    }

    enum def PairingResult {
        enum accepted;
        enum rejected;
        enum timeout;
        enum memoryFull;
    }

    item def ButtonPress {
        attribute button : ButtonId;
        attribute pressDuration : TimeMillisecond;
    }

    item def LearnedWirelessCode {
        attribute button : ButtonId;
        attribute command : CommandType;
        attribute carrierFrequency : FrequencyMHz;
        attribute rollingCodeEnabled : Boolean;
        attribute encryptedPayload : Boolean;
    }

    item def WirelessCommandFrame {
        attribute command : CommandType;
        attribute carrierFrequency : FrequencyMHz;
        attribute transmitPower : PowerMilliWatt;
        attribute rollingCounter : Integer;
        attribute frameDuration : TimeMillisecond;
    }

    item def PairingSignal {
        attribute detectedFrequency : FrequencyMHz;
        attribute sampleDuration : TimeMillisecond;
        attribute rollingCodeDetected : Boolean;
    }

    item def StatusIndication {
        attribute activeButton : ButtonId;
        attribute learningMode : Boolean;
        attribute transmitActive : Boolean;
        attribute faultPresent : Boolean;
    }

    item def VehiclePower {
        attribute supplyVoltage : VoltageVolt;
        attribute ignitionAvailable : Boolean;
    }

    item def DiagnosticEvent {
        attribute eventCode : String;
        attribute timestamp : TimeMillisecond;
        attribute recoverable : Boolean;
    }

    port def UserButtonPort {
        in item press : ButtonPress;
    }

    port def IndicatorPort {
        out item indication : StatusIndication;
    }

    port def PowerInputPort {
        in item power : VehiclePower;
    }

    port def RfReceivePort {
        in item pairingSignal : PairingSignal;
    }

    port def RfTransmitPort {
        out item commandFrame : WirelessCommandFrame;
    }

    port def MemoryAccessPort {
        out item storedCode : LearnedWirelessCode;
        in item retrievedCode : LearnedWirelessCode;
    }

    port def DiagnosticPort {
        out item event : DiagnosticEvent;
    }

    part def HomeLinkWirelessControlSystem {
        attribute supportedMinimumFrequency : FrequencyMHz = 286.0;
        attribute supportedMaximumFrequency : FrequencyMHz = 440.0;
        attribute nominalTransmitPower : PowerMilliWatt = 10.0;
        attribute maximumTransmitDuration : TimeMillisecond = 2000.0;
        attribute maximumOperatingRange : DistanceMeter = 30.0;
        attribute minimumSupplyVoltage : VoltageVolt = 9.0;
        attribute maximumSupplyVoltage : VoltageVolt = 16.0;
        attribute minimumOperatingTemperature : TemperatureCelsius = -40.0;
        attribute maximumOperatingTemperature : TemperatureCelsius = 85.0;

        port userButtons : UserButtonPort;
        port visualIndicator : IndicatorPort;
        port vehiclePowerInput : PowerInputPort;
        port wirelessReceiver : RfReceivePort;
        port wirelessTransmitter : RfTransmitPort;
        port diagnostics : DiagnosticPort;

        part controller : ControlModule;
        part rfModule : RadioFrequencyModule;
        part codeMemory : LearnedCodeMemory;
        part indicator : IndicatorModule;
        part powerConditioner : PowerConditioner;

        connect userButtons to controller.buttonInput;
        connect vehiclePowerInput to powerConditioner.vehiclePowerInput;
        connect powerConditioner.conditionedPowerOutput to controller.powerInput;
        connect powerConditioner.conditionedPowerOutput to rfModule.powerInput;
        connect wirelessReceiver to rfModule.receiveInput;
        connect controller.rfCommandOutput to rfModule.commandInput;
        connect rfModule.transmitOutput to wirelessTransmitter;
        connect controller.memoryAccess to codeMemory.access;
        connect controller.indicatorOutput to indicator.indicatorInput;
        connect indicator.externalIndicatorOutput to visualIndicator;
        connect controller.diagnosticOutput to diagnostics;

        perform action ProvideWirelessControl;
    }

    part def ControlModule {
        attribute activeButton : ButtonId;
        attribute learningModeEnabled : Boolean = false;
        attribute rollingCounter : Integer = 0;
        attribute commandAccepted : Boolean = false;

        port buttonInput : UserButtonPort;
        port powerInput : PowerInputPort;
        port rfCommandOutput : RfTransmitPort;
        port memoryAccess : MemoryAccessPort;
        port indicatorOutput : IndicatorPort;
        port diagnosticOutput : DiagnosticPort;

        state def OperationalStates {
            state Off;
            state Ready;
            state Learning;
            state Transmitting;
            state Fault;

            entry action InitializeController;
            transition first Off;
            transition Off_to_Ready
                first Off
                then Ready
                accept VehiclePower
                if power.supplyVoltage >= 9.0 and power.supplyVoltage <= 16.0;

            transition Ready_to_Learning
                first Ready
                then Learning
                accept ButtonPress
                if press.pressDuration >= 10000.0;

            transition Ready_to_Transmitting
                first Ready
                then Transmitting
                accept ButtonPress
                if press.pressDuration < 10000.0;

            transition Learning_to_Ready
                first Learning
                then Ready
                accept PairingSignal
                if pairingSignal.sampleDuration >= 500.0;

            transition Transmitting_to_Ready
                first Transmitting
                then Ready
                after 2000.0 [ms];

            transition Ready_to_Fault
                first Ready
                then Fault
                accept VehiclePower
                if power.supplyVoltage < 9.0 or power.supplyVoltage > 16.0;

            transition Fault_to_Ready
                first Fault
                then Ready
                accept VehiclePower
                if power.supplyVoltage >= 9.0 and power.supplyVoltage <= 16.0;
        }

        action def ProcessButtonPress {
            in item press : ButtonPress;
            out item commandFrame : WirelessCommandFrame;
            out item indication : StatusIndication;
        }

        action def LearnWirelessCode {
            in item pairingSignal : PairingSignal;
            out item learnedCode : LearnedWirelessCode;
            out item result : PairingResult;
        }

        action def GenerateCommandFrame {
            in item storedCode : LearnedWirelessCode;
            out item commandFrame : WirelessCommandFrame;
        }

        action def InitializeController {
            out item indication : StatusIndication;
        }
    }

    part def RadioFrequencyModule {
        attribute receiverSensitivity : PowerMilliWatt = 0.000001;
        attribute transmitPower : PowerMilliWatt = 10.0;
        attribute tunedFrequency : FrequencyMHz = 315.0;

        port powerInput : PowerInputPort;
        port receiveInput : RfReceivePort;
        port commandInput : RfTransmitPort;
        port transmitOutput : RfTransmitPort;

        action def DetectPairingSignal {
            in item pairingSignal : PairingSignal;
            out item normalizedSignal : PairingSignal;
        }

        action def TransmitCommand {
            in item commandFrame : WirelessCommandFrame;
            out item emittedFrame : WirelessCommandFrame;
        }
    }

    part def LearnedCodeMemory {
        attribute storedCodeCapacity : Integer = 3;
        attribute nonvolatileRetentionYears : Real = 10.0;

        port access : MemoryAccessPort;

        part slot1 : MemorySlot {
            attribute assignedButton = ButtonId::button1;
        }

        part slot2 : MemorySlot {
            attribute assignedButton = ButtonId::button2;
        }

        part slot3 : MemorySlot {
            attribute assignedButton = ButtonId::button3;
        }

        action def StoreCode {
            in item learnedCode : LearnedWirelessCode;
            out item result : PairingResult;
        }

        action def RetrieveCode {
            in button : ButtonId;
            out item retrievedCode : LearnedWirelessCode;
        }

        action def EraseAllCodes {
            out erased : Boolean;
        }
    }

    part def MemorySlot {
        attribute assignedButton : ButtonId;
        attribute occupied : Boolean = false;
        attribute writeCyclesUsed : Integer = 0;
        attribute maximumWriteCycles : Integer = 100000;

        item storedCode : LearnedWirelessCode;
    }

    part def IndicatorModule {
        port indicatorInput : IndicatorPort;
        port externalIndicatorOutput : IndicatorPort;

        action def ShowReady {
            out item indication : StatusIndication;
        }

        action def ShowLearning {
            out item indication : StatusIndication;
        }

        action def ShowTransmit {
            out item indication : StatusIndication;
        }

        action def ShowFault {
            out item indication : StatusIndication;
        }
    }

    part def PowerConditioner {
        attribute inputMinimumVoltage : VoltageVolt = 9.0;
        attribute inputMaximumVoltage : VoltageVolt = 16.0;
        attribute regulatedVoltage : VoltageVolt = 5.0;

        port vehiclePowerInput : PowerInputPort;
        port conditionedPowerOutput : PowerInputPort;

        action def RegulateVehiclePower {
            in item power : VehiclePower;
            out item regulatedPower : VehiclePower;
            out item diagnostic : DiagnosticEvent;
        }
    }

    action def ProvideWirelessControl {
        in item userPress : ButtonPress;
        in item vehiclePower : VehiclePower;
        in item incomingPairingSignal : PairingSignal;
        out item transmittedCommand : WirelessCommandFrame;
        out item userStatus : StatusIndication;

        first start;
        then validatePower;
        then interpretUserInput;
        then decideMode;

        action validatePower {
            in item vehiclePower : VehiclePower;
            out validPower : Boolean;
        }

        action interpretUserInput {
            in item userPress : ButtonPress;
            out selectedButton : ButtonId;
            out requestedLearning : Boolean;
        }

        action decideMode {
            in requestedLearning : Boolean;
            out transmitRequested : Boolean;
            out learnRequested : Boolean;
        }

        if learnRequested {
            then learnCode;
        } else {
            then transmitStoredCommand;
        }

        action learnCode {
            in item incomingPairingSignal : PairingSignal;
            out item learnedCode : LearnedWirelessCode;
            out item userStatus : StatusIndication;
        }

        action transmitStoredCommand {
            in selectedButton : ButtonId;
            out item transmittedCommand : WirelessCommandFrame;
            out item userStatus : StatusIndication;
        }

        then done;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : HomeLinkWirelessControlSystem;

        doc /* The HomeLink Wireless Control System shall provide integrated vehicle-based wireless control of compatible external access and convenience devices by learning authorized radio-frequency command codes and retransmitting the corresponding command when the vehicle user presses an assigned control button. */
    }

    requirement def FrequencySupportRequirement {
        subject system : HomeLinkWirelessControlSystem;

        require constraint {
            system.supportedMinimumFrequency <= 286.0 and
            system.supportedMaximumFrequency >= 440.0
        }

        doc /* The system shall support wireless control devices operating across the common HomeLink RF control band from 286 MHz through 440 MHz. */
    }

    requirement def ButtonCapacityRequirement {
        subject memory : LearnedCodeMemory;

        require constraint {
            memory.storedCodeCapacity == 3
        }

        doc /* The system shall provide three independently programmable command storage locations corresponding to three user control buttons. */
    }

    requirement def TransmissionDurationRequirement {
        subject system : HomeLinkWirelessControlSystem;

        require constraint {
            system.maximumTransmitDuration <= 2000.0
        }

        doc /* The system shall limit each command transmission to no more than 2000 ms after a momentary user button press. */
    }

    requirement def VehiclePowerRequirement {
        subject system : HomeLinkWirelessControlSystem;

        require constraint {
            system.minimumSupplyVoltage <= 9.0 and
            system.maximumSupplyVoltage >= 16.0
        }

        doc /* The system shall operate from the vehicle electrical supply across the 9 V to 16 V operating range. */
    }

    requirement def UserFeedbackRequirement {
        subject system : HomeLinkWirelessControlSystem;

        doc /* The system shall provide visible status feedback for ready, learning, transmitting, and fault conditions. */
    }

    requirement def NonvolatileMemoryRequirement {
        subject memory : LearnedCodeMemory;

        require constraint {
            memory.nonvolatileRetentionYears >= 10.0
        }

        doc /* Learned wireless codes shall be retained in nonvolatile memory for at least 10 years without vehicle power. */
    }

    requirement def RollingCodeRequirement {
        subject controller : ControlModule;

        doc /* When a learned external device uses rolling-code security, the controller shall generate command frames with an updated rolling counter for each authorized transmission. */
    }

    satisfy PrimaryFunctionRequirement by HomeLinkWirelessControlSystem;
    satisfy FrequencySupportRequirement by HomeLinkWirelessControlSystem;
    satisfy ButtonCapacityRequirement by LearnedCodeMemory;
    satisfy TransmissionDurationRequirement by HomeLinkWirelessControlSystem;
    satisfy VehiclePowerRequirement by HomeLinkWirelessControlSystem;
    satisfy UserFeedbackRequirement by IndicatorModule;
    satisfy NonvolatileMemoryRequirement by LearnedCodeMemory;
    satisfy RollingCodeRequirement by ControlModule;
}