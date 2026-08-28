package BiliblanketPhototherapySystem {

    import ScalarValues::*;

    // ─── Value Types with Units ───
    value type TemperatureValue = Real { unit: "°C"; }
    value type WavelengthValue  = Real { unit: "nm"; }
    value type IrradianceValue  = Real { unit: "µW/cm²"; }
    value type VoltageValue     = Real { unit: "V"; }
    value type CurrentValue     = Real { unit: "A"; }
    value type PowerValue       = Real { unit: "W"; }
    value type DurationValue    = Real { unit: "min"; }
    value type PercentValue     = Real { unit: "%"; }
    value type AreaValue        = Real { unit: "cm²"; }
    value type LengthValue      = Real { unit: "mm"; }
    value type FrequencyValue   = Real { unit: "Hz"; }

    // ─── Item Definitions ───
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute isDC    : Boolean;
    }

    item def TherapeuticLight {
        attribute peakWavelength   : WavelengthValue;
        attribute irradiance       : IrradianceValue;
        attribute spectralRangeMin : WavelengthValue;
        attribute spectralRangeMax : WavelengthValue;
    }

    item def TemperatureReading {
        attribute value      : TemperatureValue;
        attribute timestamp  : DurationValue;
    }

    item def ControlCommand {
        attribute commandType      : String;
        attribute targetIntensity  : PercentValue;
        attribute targetDuration   : DurationValue;
    }

    item def AlarmSignal {
        attribute alarmType : String;
        attribute severity   : String;
    }

    // ─── Port Definitions ───
    port def PowerInPort {
        in power : ElectricalPower;
    }

    port def PowerOutPort {
        out power : ElectricalPower;
    }

    port def LightOutPort {
        out light : TherapeuticLight;
    }

    port def LightInPort {
        in light : TherapeuticLight;
    }

    port def TempDataOutPort {
        out tempReading : TemperatureReading;
    }

    port def TempDataInPort {
        in tempReading : TemperatureReading;
    }

    port def ControlCmdOutPort {
        out cmd : ControlCommand;
    }

    port def ControlCmdInPort {
        in cmd : ControlCommand;
    }

    port def AlarmOutPort {
        out alarm : AlarmSignal;
    }

    port def AlarmInPort {
        in alarm : AlarmSignal;
    }

    // ─── Requirement Definitions ───
    requirement def TreatJaundiceReq {
        doc /* The system shall reduce bilirubin levels in newborn infants by exposing their skin to therapeutic blue-green light. */;
    }

    requirement def WavelengthReq {
        doc /* The LED light engine shall produce light with a peak wavelength of approximately 475 nm in the blue-green spectrum, which is most effective for breaking down bilirubin. */;
        attribute requiredPeakWavelength : WavelengthValue = 475;
    }

    requirement def IntensityControlReq {
        doc /* The user shall be able to set the treatment light intensity within a safe and effective range via the control module. */;
    }

    requirement def DurationControlReq {
        doc /* The user shall be able to set the treatment duration in minutes via the control module. */;
    }

    requirement def OverheatProtectionReq {
        doc /* If the fiber optic pad surface temperature exceeds 38 °C, the system shall automatically shut down the light and trigger an alarm. */;
        attribute maxSafeTemperature : TemperatureValue = 38;
    }

    requirement def EvenLightDistributionReq {
        doc /* The fiber optic pad shall distribute therapeutic light evenly over its surface to maximize skin exposure and allow it to be wrapped comfortably around the infant. */;
    }

    requirement def PowerConversionReq {
        doc /* The power supply shall convert standard wall outlet AC voltage into low-voltage DC power for the system's electronics. */;
    }

    // ─── Part Definitions ───

    part def PowerSupply {
        attribute ratedInputVoltage  : VoltageValue = 220;
        attribute ratedOutputVoltage  : VoltageValue = 12;
        attribute ratedOutputCurrent  : CurrentValue = 5;
        attribute ratedOutputPower    : PowerValue    = 60;
        attribute inputIsAC           : Boolean       = true;
        attribute outputIsDC          : Boolean       = true;

        port powerIn  : PowerInPort;
        port powerOut : PowerOutPort;

        action def convertACtoDC {
            in  inputPower  : ElectricalPower;
            out outputPower : ElectricalPower;
        }
    }

    part def ControlModule {
        attribute maxSafeTemperature       : TemperatureValue = 38;
        attribute currentIntensity         : PercentValue;
        attribute remainingTime            : DurationValue;
        attribute setDuration             : DurationValue;
        attribute setIntensity            : PercentValue;
        attribute isPowered               : Boolean  = false;
        attribute startRequested          : Boolean  = false;
        attribute stopRequested           : Boolean  = false;
        attribute timerExpired            : Boolean  = false;
        attribute temperatureExceedsLimit : Boolean  = false;
        attribute faultAcknowledged       : Boolean  = false;

        port powerIn    : PowerInPort;
        port uiCmdIn    : ControlCmdInPort;
        port ledCmdOut  : ControlCmdOutPort;
        port tempIn     : TempDataInPort;
        port alarmOut  : AlarmOutPort;

        action def processTemperature {
            in  reading       : TemperatureReading;
            out exceedsLimit  : Boolean;
        }

        action def startTherapy {
            in  intensity  : PercentValue;
            in  duration   : DurationValue;
        }

        action def stopLight;

        action def triggerOverheatAlarm {
            out alarm : AlarmSignal;
        }

        state machine operatingStates {
            state Off {
                entry { currentIntensity = 0; }
            }

            state Standby {
                entry { currentIntensity = 0; }
            }

            state Active {
                entry { remainingTime = setDuration; currentIntensity = setIntensity; }
                do    { /* continuously deliver light and monitor temperature */ }
            }

            state Fault {
                entry { currentIntensity = 0; }
            }

            transition initial     : initial  -> Off;
            transition powerOn     : Off      -> Standby  when isPowered;
            transition beginTreatment : Standby  -> Active  when startRequested;
            transition timerEnds   : Active    -> Standby  when timerExpired;
            transition userStop    : Active    -> Standby  when stopRequested;
            transition overheat    : Active    -> Fault    when temperatureExceedsLimit;
            transition resetFault  : Fault     -> Standby  when faultAcknowledged;
        }
    }

    part def LEDLightEngine {
        attribute peakWavelength    : WavelengthValue = 475;
        attribute spectralRangeMin  : WavelengthValue = 420;
        attribute spectralRangeMax  : WavelengthValue = 530;
        attribute maxIrradiance     : IrradianceValue = 35;
        attribute currentIrradiance  : IrradianceValue;

        port powerIn  : PowerInPort;
        port cmdIn    : ControlCmdInPort;
        port lightOut : LightOutPort;

        action def generateLight {
            in  cmd   : ControlCommand;
            in  power : ElectricalPower;
            out light : TherapeuticLight;
        }
    }

    part def FiberOpticPad {
        attribute surfaceArea                : AreaValue     = 600;
        attribute thickness                  : LengthValue   = 5;
        attribute flexibilityRating          : String        = "high";
        attribute lightDistributionUniformity : PercentValue = 95;
        attribute surfaceTemperature         : TemperatureValue = 25;

        port lightIn : LightInPort;

        action def distributeLight {
            in  incomingLight   : TherapeuticLight;
            out distributedLight : TherapeuticLight;
        }
    }

    part def TemperatureSensor {
        attribute measurementRangeMin : TemperatureValue = 10;
        attribute measurementRangeMax : TemperatureValue = 50;
        attribute accuracy            : TemperatureValue = 0.5;
        attribute samplingRate        : FrequencyValue   = 1;

        port tempOut : TempDataOutPort;

        action def measureTemperature {
            in  padTemperature : TemperatureValue;
            out reading        : TemperatureReading;
        }
    }

    part def AlarmIndicator {
        attribute isAudible   : Boolean = true;
        attribute isVisual    : Boolean = true;
        attribute alarmActive : Boolean = false;

        port alarmIn : AlarmInPort;

        action def triggerAlarm {
            in signal : AlarmSignal;
        }

        action def clearAlarm;
    }

    part def UserInterface {
        attribute displayType       : String       = "LCD";
        attribute hasKeypad         : Boolean      = true;
        attribute selectedIntensity : PercentValue = 50;
        attribute selectedDuration  : DurationValue = 30;

        port cmdOut : ControlCmdOutPort;

        action def setTreatmentParameters {
            in intensity : PercentValue;
            in duration  : DurationValue;
        }

        action def requestStart;
        action def requestStop;
        action def acknowledgeFault;
    }

    // ─── System Assembly ───
    part def BiliblanketPhototherapySystem {
        attribute modelName            : String          = "Biliblanket-1.0";
        attribute maxSafeTemperature    : TemperatureValue = 38;
        attribute therapeuticWavelength : WavelengthValue  = 475;

        part powerSupply     : PowerSupply;
        part controlModule   : ControlModule;
        part ledEngine       : LEDLightEngine;
        part fiberOpticPad   : FiberOpticPad;
        part tempSensor      : TemperatureSensor;
        part alarmIndicator  : AlarmIndicator;
        part userInterface   : UserInterface;

        // Connections
        connection powerToControl  : powerSupply.powerOut    to controlModule.powerIn;
        connection powerToLED      : powerSupply.powerOut    to ledEngine.powerIn;
        connection uiToControl      : userInterface.cmdOut    to controlModule.uiCmdIn;
        connection controlToLED     : controlModule.ledCmdOut  to ledEngine.cmdIn;
        connection ledToPad         : ledEngine.lightOut      to fiberOpticPad.lightIn;
        connection sensorToControl   : tempSensor.tempOut      to controlModule.tempIn;
        connection controlToAlarm    : controlModule.alarmOut   to alarmIndicator.alarmIn;

        // Requirement usages
        requirement treatJaundiceReq        : TreatJaundiceReq;
        requirement wavelengthSpec          : WavelengthReq;
        requirement intensityControlReq     : IntensityControlReq;
        requirement durationControlReq      : DurationControlReq;
        requirement overheatProtectionReq   : OverheatProtectionReq;
        requirement evenLightDistributionReq : EvenLightDistributionReq;
        requirement powerConversionReq      : PowerConversionReq;
    }
}
