package StroboscopeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def FlashFrequencyValue :> ISQ::FrequencyValue;
    attribute def FlashDurationValue :> ISQ::TimeValue;
    attribute def LightIntensityValue :> ISQ::LuminousIntensityValue;
    attribute def RotationalFrequencyValue :> ISQ::FrequencyValue;

    item def ElectricalPower {
        attribute voltage :> ISQ::VoltageValue;
        attribute current :> ISQ::ElectricCurrentValue;
    }

    item def TriggerSignal {
        attribute timestamp :> ISQ::TimeValue;
        attribute enabled : Boolean;
    }

    item def FlashCommand {
        attribute frequency : FlashFrequencyValue;
        attribute intensity : LightIntensityValue;
    }

    item def LightPulse {
        attribute intensity : LightIntensityValue;
        attribute duration : FlashDurationValue;
    }

    port def PowerPort {
        in item power : ElectricalPower;
    }

    port def ControlPort {
        in item command : FlashCommand;
    }

    port def TriggerPort {
        out item trigger : TriggerSignal;
    }

    port def LightPort {
        out item light : LightPulse;
    }

    action def ConvertPower {
        in attribute inputPower : ElectricalPower;
        out attribute outputPower : ElectricalPower;
    }

    action def GenerateTrigger {
        in attribute targetFrequency : FlashFrequencyValue;
        out attribute triggerPulse : TriggerSignal;
    }

    action def ProduceFlash {
        in attribute trigger : TriggerSignal;
        in attribute power : ElectricalPower;
        out attribute flash : LightPulse;
    }

    part def PowerSupply {
        port powerIn : PowerPort;
        port powerOut : PowerPort;

        attribute inputVoltage :> ISQ::VoltageValue;
        attribute outputVoltage :> ISQ::VoltageValue;

        perform action convert : ConvertPower;
    }

    part def FrequencyController {
        port controlIn : ControlPort;
        port triggerOut : TriggerPort;

        attribute setFrequency : FlashFrequencyValue;
        attribute currentFrequency : FlashFrequencyValue;

        perform action generateTriggers : GenerateTrigger;
    }

    part def FlashTube {
        port powerIn : PowerPort;
        port triggerIn : TriggerPort;
        port lightOut : LightPort;

        attribute chargeVoltage :> ISQ::VoltageValue;
        attribute flashEnergy :> ISQ::EnergyValue;
        attribute peakIntensity : LightIntensityValue;

        perform action flash : ProduceFlash;
    }

    part def ReflectorAssembly {
        port lightIn : LightPort;
        port lightOut : LightPort;

        attribute reflectivity : Real;
        attribute focusAngle :> ISQ::AngleValue;

        perform action focusLight {
            in attribute incomingLight : LightPulse;
            out attribute focusedLight : LightPulse;
        }
    }

    part def UserInterface {
        port controlOut : ControlPort;

        attribute frequencyDial : Real;
        attribute powerSwitch : Boolean;
        attribute displayedFrequency : FlashFrequencyValue;

        perform action processInput {
            in attribute dialPosition : Real;
            in attribute switchState : Boolean;
            out attribute command : FlashCommand;
        }
    }

    part def Stroboscope {
        attribute operatingFrequency : FlashFrequencyValue;
        attribute minFrequency : FlashFrequencyValue;
        attribute maxFrequency : FlashFrequencyValue;
        attribute flashIntensity : LightIntensityValue;

        port externalPower : PowerPort;
        port lightOutput : LightPort;

        part powerSupply : PowerSupply;

        part controller : FrequencyController;

        part flashTube : FlashTube;

        part reflector : ReflectorAssembly;

        part userInterface : UserInterface;

        connect externalPower to powerSupply.powerIn;
        connect powerSupply.powerOut to flashTube.powerIn;
        connect userInterface.controlOut to controller.controlIn;
        connect controller.triggerOut to flashTube.triggerIn;
        connect flashTube.lightOut to reflector.lightIn;
        connect reflector.lightOut to lightOutput;

        perform action operateStroboscope {
            first start;

            then action initializePower {
                perform powerSupply.convert;
            }

            then action getUserInput {
                perform userInterface.processInput;
            }

            then merge continuousOperation;

            then action controlFlashing {
                perform controller.generateTriggers;
            }

            then action produceFlash {
                perform flashTube.flash;
            }

            then action focusOutput {
                perform reflector.focusLight;
            }

            then decide;
                if userInterface.powerSwitch then continuousOperation;
                if not userInterface.powerSwitch then shutdown;

            action shutdown;
            then done;
        }
    }

    requirement def StroboscopeFunctionalRequirement {
        doc /* The stroboscope shall produce periodic high-intensity light flashes at a user-controllable 
               frequency to enable visual analysis of rotating or oscillating objects by making them 
               appear stationary or slow-moving when the flash frequency matches or is a multiple of 
               the object's motion frequency. */

        subject stroboscopeSystem : Stroboscope;

        require constraint frequencyRange {
            doc /* The flash frequency shall be adjustable from 1 Hz to 3000 Hz. */
            stroboscopeSystem.operatingFrequency >= stroboscopeSystem.minFrequency and
            stroboscopeSystem.operatingFrequency <= stroboscopeSystem.maxFrequency
        }

        require constraint flashSynchronization {
            doc /* The flash timing shall be stable and synchronized with the control signal. */
            stroboscopeSystem.controller.currentFrequency == stroboscopeSystem.controller.setFrequency
        }
    }

    requirement primaryMission : StroboscopeFunctionalRequirement {
        doc /* The stroboscope system shall freeze the apparent motion of rotating or vibrating objects 
               by synchronizing high-intensity light flashes with the object's motion frequency, enabling 
               precise visual inspection and measurement of dynamic systems. */
    }

    action def MeasureRotationalSpeed {
        in attribute targetObject : String;
        in attribute strobeFrequency : FlashFrequencyValue;
        out attribute measuredSpeed : RotationalFrequencyValue;

        doc /* Determine rotational speed by adjusting strobe frequency until motion appears stationary. */
    }

    occurrence def StroboscopicMeasurement {
        ref part device : Stroboscope;

        message powerOn
            from device.userInterface
            to device.powerSupply;

        then message setFrequency of FlashCommand
            from device.userInterface.controlOut
            to device.controller.controlIn;

        then message triggerFlash of TriggerSignal
            from device.controller.triggerOut
            to device.flashTube.triggerIn;

        then message emitLight of LightPulse
            from device.flashTube.lightOut
            to device.reflector.lightIn;

        then message outputBeam of LightPulse
            from device.reflector.lightOut
            to device.lightOutput;
    }
}
