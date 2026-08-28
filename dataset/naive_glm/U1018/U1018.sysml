package IRRemoteControlSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    value type Distance :> Real { unit 'm'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type Latency :> Real { unit 'ms'; }
    value type Voltage :> Real { unit 'V'; }
    value type ButtonCount :> Integer;
    value type DeviceAddress :> Integer;
    value type FunctionCode :> Integer;

    // ---- Enumerations ----
    enum def ButtonId {
        POWER = 0;
        VOLUME_UP = 1;
        VOLUME_DOWN = 2;
        CHANNEL_UP = 3;
        CHANNEL_DOWN = 4;
        MUTE = 5;
        MENU = 6;
        OK = 7;
        UP = 8;
        DOWN = 9;
        LEFT = 10;
        RIGHT = 11;
        BACK = 12;
        HOME = 13;
        NUMBER_0 = 14;
        NUMBER_1 = 15;
        NUMBER_2 = 16;
        NUMBER_3 = 17;
        NUMBER_4 = 18;
        NUMBER_5 = 19;
        NUMBER_6 = 20;
        NUMBER_7 = 21;
        NUMBER_8 = 22;
        NUMBER_9 = 23;
        INFO = 24;
    }

    enum def TVState {
        POWER_OFF;
        STANDBY;
        ACTIVE;
    }

    // ---- Item Definitions ----
    item def ButtonPress {
        attribute buttonId : ButtonId;
    }

    item def DigitalCommand {
        attribute address : DeviceAddress;
        attribute functionCode : FunctionCode;
        attribute timestamp : Time;
    }

    item def IRSignal {
        attribute carrierFrequency : Frequency = 38000.0;
        attribute modulatedData : DigitalCommand;
        attribute signalStrength : Real;
    }

    item def ActionRequest {
        attribute functionCode : FunctionCode;
    }

    // ---- Port Definitions ----
    port def IROutputPort {
        out irSignal : IRSignal;
    }

    port def IRInputPort {
        in irSignal : IRSignal;
    }

    port def CommandFlowPort {
        out command : DigitalCommand;
    }

    port def ActionFlowPort {
        in action : ActionRequest;
    }

    // ---- Requirements ----
    requirement def RemoteControlRequirement {
        attribute buttonCount : ButtonCount = 25;
        subject remoteControl : RemoteControl;
        require remoteControl.buttonCount == 25;
    }

    requirement def CarrierFrequencyRequirement {
        attribute carrierFreq : Frequency = 38000.0;
        subject emitter : IREmitter;
        require emitter.carrierFrequency == 38000.0;
    }

    requirement def DetectionRangeRequirement {
        attribute maxRange : Distance = 12.0;
        subject photodetector : IRPhotodetector;
        require photodetector.maxDetectionRange >= 12.0;
    }

    requirement def LatencyRequirement {
        attribute maxLatency : Latency = 100.0;
        subject system : IRRemoteControlSystem;
        require system.endToEndLatency < 100.0;
    }

    requirement def LineOfSightRequirement {
        subject receiver : IRReceiverModule;
        require receiver.requiresLineOfSight == true;
    }

    // ---- Part Definitions ----
    part def Battery {
        attribute nominalVoltage : Voltage = 3.0;
        attribute capacity_mAh : Integer = 800;
    }

    part def Button {
        attribute id : ButtonId;
        in item press : ButtonPress;
    }

    part def Microcontroller {
        attribute deviceAddress : DeviceAddress = 1;
        in item buttonPress : ButtonPress;
        out item command : DigitalCommand;
        action generateCommand {
            in buttonPress : ButtonPress;
            out command : DigitalCommand;
        }
    }

    part def IREmitter {
        attribute carrierFrequency : Frequency = 38000.0;
        in item command : DigitalCommand;
        out irSignal : IRSignal;
        action modulate {
            in command : DigitalCommand;
            out irSignal : IRSignal;
        }
    }

    part def IRPhotodetector {
        attribute maxDetectionRange : Distance = 12.0;
        in irSignal : IRSignal;
        out detectedSignal : IRSignal;
        action detect {
            in irSignal : IRSignal;
            out detectedSignal : IRSignal;
        }
    }

    part def Demodulator {
        in item irSignal : IRSignal;
        out item command : DigitalCommand;
        action demodulate {
            in irSignal : IRSignal;
            out command : DigitalCommand;
        }
    }

    part def RemoteControl {
        attribute buttonCount : ButtonCount = 25;
        part battery : Battery;
        part buttons[25] : Button;
        part microcontroller : Microcontroller;
        part emitter : IREmitter {
            port irOutput : IROutputPort;
        }

        connection buttonToMicrocontroller connect buttons.press to microcontroller.buttonPress;
        connection microcontrollerToEmitter connect microcontroller.command to emitter.command;

        satisfy RemoteControlRequirement by self;
    }

    part def IRReceiverModule {
        attribute requiresLineOfSight : Boolean = true;
        part photodetector : IRPhotodetector {
            port irInput : IRInputPort;
        }
        part demodulator : Demodulator;

        connection detectorToDemodulator connect photodetector.detectedSignal to demodulator.irSignal;

        satisfy LineOfSightRequirement by self;
    }

    part def TVDisplay {
        attribute brightness : Real;
        attribute currentChannel : Integer;
        attribute volume : Integer;
    }

    part def TVSpeaker {
        attribute volume : Integer;
        attribute muted : Boolean = false;
    }

    part def Television {
        attribute currentState : TVState = TVState::POWER_OFF;
        attribute currentChannel : Integer = 1;
        attribute volume : Integer = 20;
        attribute endToEndLatency : Latency;

        part receiverModule : IRReceiverModule {
            port irInput : IRInputPort;
        }
        part display : TVDisplay;
        part speaker : TVSpeaker;

        in item command : DigitalCommand;
        out item action : ActionRequest;

        state machine TVStateMachine {
            entry action { attribute currentState = TVState::POWER_OFF; }

            state powerOff {
                entry action { display.brightness = 0.0; speaker.muted = true; }
                transition powerOffToStandby
                    first powerOff
                    if command.functionCode == ButtonId::POWER::functionCode
                    then standby;
            }

            state standby {
                entry action { attribute currentState = TVState::STANDBY; display.brightness = 0.0; }
                transition standbyToActive
                    first standby
                    if command.functionCode == ButtonId::POWER::functionCode
                    then active;
                transition standbyToPowerOff
                    first standby
                    if command.functionCode == ButtonId::POWER::functionCode and command.address != 1
                    then powerOff;
            }

            state active {
                entry action { attribute currentState = TVState::ACTIVE; display.brightness = 1.0; speaker.muted = false; }

                do action processCommands {
                    if command.functionCode == ButtonId::VOLUME_UP::functionCode {
                        volume = volume + 1;
                        speaker.volume = volume;
                    }
                    if command.functionCode == ButtonId::VOLUME_DOWN::functionCode {
                        volume = volume - 1;
                        speaker.volume = volume;
                    }
                    if command.functionCode == ButtonId::CHANNEL_UP::functionCode {
                        currentChannel = currentChannel + 1;
                        display.currentChannel = currentChannel;
                    }
                    if command.functionCode == ButtonId::CHANNEL_DOWN::functionCode {
                        currentChannel = currentChannel - 1;
                        display.currentChannel = currentChannel;
                    }
                    if command.functionCode == ButtonId::MUTE::functionCode {
                        speaker.muted = !speaker.muted;
                    }
                    if command.functionCode == ButtonId::POWER::functionCode {
                        attribute currentState = TVState::STANDBY;
                    }
                }

                transition activeToStandby
                    first active
                    if command.functionCode == ButtonId::POWER::functionCode
                    then standby;
            }
        }

        connection receiverToCommand connect receiverModule.demodulator.command to self.command;

        satisfy DetectionRangeRequirement by receiverModule.photodetector;
    }

    part def IRRemoteControlSystem {
        part remote : RemoteControl;
        part tv : Television;

        attribute endToEndLatency : Latency;

        // Wireless IR link between remote emitter and TV receiver
        connection irLink connect remote.emitter.irOutput.irSignal to tv.receiverModule.irInput.irSignal;

        satisfy LatencyRequirement by self;
    }

    // ---- Requirement Satisfaction ----
    part remoteControlUnit : RemoteControl {
        satisfy CarrierFrequencyRequirement by emitter;
    }

    part televisionUnit : Television {
        satisfy DetectionRangeRequirement by receiverModule.photodetector;
    }

    part system : IRRemoteControlSystem {
        satisfy LatencyRequirement by self;
    }

}
