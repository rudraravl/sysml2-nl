package StroboscopeSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;

    // ---- Value types with units ----
    def FrequencyValue :> Real {
        :>> unit = Hz;
    }
    def VoltageValue :> Real {
        :>> unit = V;
    }
    def CurrentValue :> Real {
        :>> unit = A;
    }
    def PowerValue :> Real {
        :>> unit = W;
    }
    def LuminousFluxValue :> Real {
        :>> unit = lm;
    }
    def DurationValue :> Real {
        :>> unit = s;
    }
    def AngleValue :> Real {
        :>> unit = deg;
    }

    // ---- Item definitions ----
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    item def TriggerSignal {
        attribute timestamp : TimeValue;
        attribute pulseWidth : DurationValue;
    }
    item def FrequencyCommand {
        attribute targetFrequency : FrequencyValue;
    }
    item def LightBeam {
        attribute intensity : LuminousFluxValue;
        attribute direction : AngleValue;
        attribute duration : DurationValue;
    }
    item def DisplayData {
        attribute displayedFrequency : FrequencyValue;
        attribute powerStatus : Boolean;
    }

    // ---- Port definitions ----
    port def PowerInPort {
        out power : ElectricalPower;
    }
    port def PowerOutPort {
        in power : ElectricalPower;
    }
    port def CommandOutPort {
        out command : FrequencyCommand;
    }
    port def CommandInPort {
        in command : FrequencyCommand;
    }
    port def TriggerOutPort {
        out trigger : TriggerSignal;
    }
    port def TriggerInPort {
        in trigger : TriggerSignal;
    }
    port def LightOutPort {
        out beam : LightBeam;
    }
    port def LightInPort {
        in beam : LightBeam;
    }
    port def DisplayOutPort {
        out data : DisplayData;
    }
    port def DisplayInPort {
        in data : DisplayData;
    }

    // ---- Requirements ----
    requirement def StroboscopeRequirement {
        subject stroboscope : Stroboscope;
        objective {
            doc /* The stroboscope shall produce high-intensity, short-duration light flashes at a precise, user-adjustable frequency. */
        }
    }

    requirement def FlashFrequencyRangeRequirement {
        subject controller : FrequencyController;
        attribute minFrequency : FrequencyValue = 1.0 [Hz];
        attribute maxFrequency : FrequencyValue = 1000.0 [Hz];
        constraint { controller.commandedFrequency >= minFrequency and controller.commandedFrequency <= maxFrequency }
    }

    requirement def FlashStabilityRequirement {
        subject controller : FrequencyController;
        attribute frequencyTolerance : FrequencyValue = 0.01 [Hz];
        constraint { abs(controller.actualFrequency - controller.commandedFrequency) <= frequencyTolerance }
    }

    requirement def FlashDurationRequirement {
        subject tube : FlashTube;
        attribute maxFlashDuration : DurationValue = 0.0001 [s];
        constraint { tube.flashDuration <= maxFlashDuration }
    }

    requirement def BeamFocusRequirement {
        subject reflector : ReflectorAssembly;
        attribute beamAngle : AngleValue = 15.0 [deg];
        constraint { reflector.outputBeamAngle <= beamAngle }
    }

    requirement def PowerConversionRequirement {
        subject supply : PowerSupply;
        attribute requiredOutputVoltage : VoltageValue = 300.0 [V];
        attribute voltageTolerance : VoltageValue = 1.0 [V];
        constraint { abs(supply.outputVoltage - requiredOutputVoltage) <= voltageTolerance }
    }

    // ---- Parts ----

    part def UserInterface {
        attribute isPoweredOn : Boolean = false;
        attribute dialSetting : FrequencyValue = 0.0 [Hz];
        attribute displayedFrequency : FrequencyValue = 0.0 [Hz];

        port commandOut : CommandOutPort;
        port displayIn : DisplayInPort;

        part powerSwitch {
            attribute state : Boolean = false;
            action def toggle {
                in newState : Boolean;
                then { powerSwitch.state = newState; }
            }
        }
        part frequencyDial {
            attribute currentSetting : FrequencyValue = 0.0 [Hz];
            action def adjust {
                in newFrequency : FrequencyValue;
                then { frequencyDial.currentSetting = newFrequency; }
            }
        }
        part digitalDisplay {
            attribute content : DisplayData;
        }

        action def sendCommand {
            in freq : FrequencyValue;
            out cmd : FrequencyCommand;
            then { cmd.targetFrequency = freq; }
        }

        state machine PowerStateMachine {
            entry; off; on;
            transition off -> on
                when powerSwitch.state == true
                do { UserInterface::isPoweredOn = true; };
            transition on -> off
                when powerSwitch.state == false
                do { UserInterface::isPoweredOn = false; };
        }

        action def operate {
            // User adjusts dial; command is sent to controller
            do { sendCommand(dialSetting, commandOut.command); }
        }
    }

    part def PowerSupply {
        attribute inputVoltage : VoltageValue;
        attribute outputVoltage : VoltageValue = 300.0 [V];
        attribute outputCurrent : CurrentValue;
        attribute isStable : Boolean = true;

        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;

        action def convertPower {
            in rawPower : ElectricalPower;
            out regulatedPower : ElectricalPower;
            then {
                regulatedPower.voltage = PowerSupply::outputVoltage;
                regulatedPower.current = rawPower.current;
            }
        }

        state machine SupplyStateMachine {
            entry; idle; active; fault;
            transition entry -> idle;
            transition idle -> active
                when powerIn.power != null
                do { PowerSupply::isStable = true; };
            transition active -> fault
                when abs(PowerSupply::outputVoltage - 300.0 [V]) > 1.0 [V]
                do { PowerSupply::isStable = false; };
            transition fault -> idle
                when powerIn.power == null;
        }

        action def supply {
            do { convertPower(powerIn.power, powerOut.power); }
        }
    }

    part def FrequencyController {
        attribute commandedFrequency : FrequencyValue = 0.0 [Hz];
        attribute actualFrequency : FrequencyValue = 0.0 [Hz];
        attribute isRunning : Boolean = false;
        attribute triggerCount : Integer = 0;

        port commandIn : CommandInPort;
        port triggerOut : TriggerOutPort;
        port displayOut : DisplayOutPort;

        action def processCommand {
            in cmd : FrequencyCommand;
            then {
                FrequencyController::commandedFrequency = cmd.targetFrequency;
                FrequencyController::actualFrequency = cmd.targetFrequency;
            }
        }

        action def generateTrigger {
            out trig : TriggerSignal;
            then {
                trig.timestamp = now();
                trig.pulseWidth = 0.00001 [s];
                FrequencyController::triggerCount = FrequencyController::triggerCount + 1;
            }
        }

        state machine ControllerStateMachine {
            entry; standby; running; stopped;
            transition entry -> standby;
            transition standby -> running
                when commandIn.command != null and commandedFrequency > 0.0 [Hz]
                do { FrequencyController::isRunning = true; };
            transition running -> stopped
                when commandedFrequency == 0.0 [Hz]
                do { FrequencyController::isRunning = false; };
            transition stopped -> standby
                when commandIn.command == null;
            state running {
                do {
                    while (FrequencyController::isRunning) {
                        generateTrigger(triggerOut.trigger);
                        wait(1.0 [s] / FrequencyController::actualFrequency);
                    }
                }
            }
        }

        action def control {
            do {
                processCommand(commandIn.command);
                displayOut.data.displayedFrequency = commandedFrequency;
                displayOut.data.powerStatus = isRunning;
            }
        }
    }

    part def FlashTube {
        attribute flashDuration : DurationValue = 0.00005 [s];
        attribute peakIntensity : LuminousFluxValue = 50000.0 [lm];
        attribute energyStored : PowerValue = 50.0 [W];
        attribute isReady : Boolean = true;

        port powerIn : PowerInPort;
        port triggerIn : TriggerInPort;
        port lightOut : LightOutPort;

        action def discharge {
            in trig : TriggerSignal;
            out beam : LightBeam;
            then {
                beam.intensity = FlashTube::peakIntensity;
                beam.direction = 0.0 [deg];
                beam.duration = FlashTube::flashDuration;
            }
        }

        state machine TubeStateMachine {
            entry; charging; ready; flashing;
            transition entry -> charging;
            transition charging -> ready
                when powerIn.power != null and energyStored >= 50.0 [W]
                do { FlashTube::isReady = true; };
            transition ready -> flashing
                when triggerIn.trigger != null
                do { FlashTube::isReady = false; };
            transition flashing -> charging
                when FlashTube::isReady == false
                do { FlashTube::isReady = true; };
        }

        action def flash {
            do { discharge(triggerIn.trigger, lightOut.beam); }
        }
    }

    part def ReflectorAssembly {
        attribute reflectivity : Real = 0.95;
        attribute outputBeamAngle : AngleValue = 12.0 [deg];
        attribute focalLength : LengthValue = 0.05 [m];

        port lightIn : LightInPort;
        port lightOut : LightOutPort;

        action def focusBeam {
            in incoming : LightBeam;
            out outgoing : LightBeam;
            then {
                outgoing.intensity = incoming.intensity * ReflectorAssembly::reflectivity;
                outgoing.direction = 0.0 [deg];
                outgoing.duration = incoming.duration;
            }
        }

        action def reflect {
            do { focusBeam(lightIn.beam, lightOut.beam); }
        }
    }

    // ---- Top-level Stroboscope ----
    part def Stroboscope {
        attribute modelNumber : String = "STB-1000";
        attribute serialNumber : String;
        attribute isOperational : Boolean = true;

        port externalPower : PowerInPort;
        port outputBeam : LightOutPort;

        part ui : UserInterface {
            port commandOut : CommandOutPort;
            port displayIn : DisplayInPort;
        }
        part psu : PowerSupply {
            port powerIn : PowerInPort;
            port powerOut : PowerOutPort;
        }
        part controller : FrequencyController {
            port commandIn : CommandInPort;
            port triggerOut : TriggerOutPort;
            port displayOut : DisplayOutPort;
        }
        part tube : FlashTube {
            port powerIn : PowerInPort;
            port triggerIn : TriggerInPort;
            port lightOut : LightOutPort;
        }
        part reflector : ReflectorAssembly {
            port lightIn : LightInPort;
            port lightOut : LightOutPort;
        }

        // Connections
        connection externalPower to psu.powerIn;
        connection psu.powerOut to tube.powerIn;
        connection ui.commandOut to controller.commandIn;
        connection controller.triggerOut to tube.triggerIn;
        connection controller.displayOut to ui.displayIn;
        connection tube.lightOut to reflector.lightIn;
        connection reflector.lightOut to outputBeam;

        // Requirements satisfaction
        satisfy stroboscopeReq : StroboscopeRequirement by stroboscope;
        satisfy flashFreqReq : FlashFrequencyRangeRequirement by controller;
        satisfy flashStabReq : FlashStabilityRequirement by controller;
        satisfy flashDurReq : FlashDurationRequirement by tube;
        satisfy beamFocusReq : BeamFocusRequirement by reflector;
        satisfy powerConvReq : PowerConversionRequirement by psu;

        action def startupSequence {
            do {
                ui.powerSwitch.toggle(true);
                wait(0.5 [s]);
                ui.frequencyDial.adjust(10.0 [Hz]);
                ui.operate();
            }
        }

        action def shutdownSequence {
            do {
                ui.frequencyDial.adjust(0.0 [Hz]);
                wait(0.2 [s]);
                ui.powerSwitch.toggle(false);
            }
        }

        state machine SystemStateMachine {
            entry; poweredOff; initializing; ready; operating;
            transition entry -> poweredOff;
            transition poweredOff -> initializing
                when externalPower.power != null
                do { Stroboscope::isOperational = true; };
            transition initializing -> ready
                when psu.isStable == true
                do { startupSequence(); };
            transition ready -> operating
                when controller.isRunning == true;
            transition operating -> ready
                when controller.isRunning == false;
            transition ready -> poweredOff
                when externalPower.power == null
                do { shutdownSequence(); };
        }
    }

    // ---- Instantiated system ----
    part stroboscopeInstance : Stroboscope {
        attribute serialNumber = "SN-2024-0001";
    }
}
