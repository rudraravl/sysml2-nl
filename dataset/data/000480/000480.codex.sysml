package OneTouchUltraSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def BloodGlucoseConcentration :> Real {
        unit = "mg/dL";
    }

    attribute def MicroliterVolume :> Real {
        unit = "uL";
    }

    attribute def SecondDuration :> Real {
        unit = "s";
    }

    attribute def Volt :> Real {
        unit = "V";
    }

    attribute def MilliampereHour :> Real {
        unit = "mAh";
    }

    attribute def CelsiusTemperature :> Real {
        unit = "degC";
    }

    attribute def PercentRelativeHumidity :> Real {
        unit = "%RH";
    }

    item def CapillaryWholeBlood {
        attribute sampleVolume : MicroliterVolume;
        attribute glucoseLevel : BloodGlucoseConcentration;
        attribute hematocritPercent : Real;
    }

    item def ElectrochemicalSignal {
        attribute currentMagnitude : Real {
            unit = "uA";
        }
        attribute integrationTime : SecondDuration;
        attribute temperatureCompensated : Boolean;
    }

    item def GlucoseReading {
        attribute measuredGlucose : BloodGlucoseConcentration;
        attribute measurementTime : SecondDuration;
        attribute valid : Boolean;
        attribute errorCode : String;
    }

    item def UserCommand {
        attribute commandName : String;
    }

    item def DisplayMessage {
        attribute text : String;
        attribute includesNumericReading : Boolean;
    }

    item def StoredReadingRecord {
        attribute glucose : BloodGlucoseConcentration;
        attribute timestampIndex : Integer;
        attribute controlSolutionFlag : Boolean;
        attribute valid : Boolean;
    }

    port def BloodApplicationPort {
        in item sample : CapillaryWholeBlood;
    }

    port def StripElectricalPort {
        out item signal : ElectrochemicalSignal;
        in item excitationVoltage : Volt;
    }

    port def ReadingPort {
        out item reading : GlucoseReading;
    }

    port def CommandPort {
        in item command : UserCommand;
    }

    port def DisplayPort {
        out item message : DisplayMessage;
    }

    port def MemoryPort {
        inout item record : StoredReadingRecord;
    }

    part def OneTouchUltraBloodGlucoseMonitoringSystem {

        attribute primaryFunction : String =
            "Accept a small capillary whole-blood sample applied to a compatible glucose test strip, electrochemically estimate blood glucose concentration, and present a clear user-readable result for diabetes self-monitoring.";

        attribute requiredSampleVolume : MicroliterVolume = 1.0;
        attribute nominalMeasurementDuration : SecondDuration = 5.0;
        attribute reportableRangeLow : BloodGlucoseConcentration = 20.0;
        attribute reportableRangeHigh : BloodGlucoseConcentration = 600.0;
        attribute operatingTemperatureMin : CelsiusTemperature = 6.0;
        attribute operatingTemperatureMax : CelsiusTemperature = 44.0;
        attribute operatingHumidityMax : PercentRelativeHumidity = 90.0;

        port bloodIn : BloodApplicationPort;
        port userIn : CommandPort;
        port displayOut : DisplayPort;
        port readingOut : ReadingPort;

        part meter : HandheldMeter;
        part testStrip : ElectrochemicalTestStrip;
        part userInterface : UserInterface;
        part battery : ReplaceableBattery;
        part memory : ReadingMemory;

        connect bloodIn to testStrip.sampleWell;
        connect testStrip.electrodeInterface to meter.stripConnector;
        connect userIn to userInterface.commandIn;
        connect meter.displayMessageOut to userInterface.displayIn;
        connect userInterface.displayOut to displayOut;
        connect meter.readingOut to readingOut;
        connect meter.memoryAccess to memory.memoryPort;
        connect battery.powerOut to meter.powerIn;
        connect battery.powerOut to userInterface.powerIn;

        perform action measureBloodGlucose : MeasureBloodGlucoseAction {
            in item sample : CapillaryWholeBlood;
            out item result : GlucoseReading;

            first startMeasurement;
            then verifyStrip;
            then verifySampleVolume;
            then acquireElectrochemicalSignal;
            then calculateGlucoseConcentration;
            then validateResult;
            then showAndStoreResult;

            action startMeasurement {
                in item command : UserCommand;
            }

            action verifyStrip {
                out validStrip : Boolean;
            }

            action verifySampleVolume {
                in item sample : CapillaryWholeBlood;
                out sufficientSample : Boolean;
            }

            action acquireElectrochemicalSignal {
                in item sample : CapillaryWholeBlood;
                out item signal : ElectrochemicalSignal;
            }

            action calculateGlucoseConcentration {
                in item signal : ElectrochemicalSignal;
                out concentration : BloodGlucoseConcentration;
            }

            action validateResult {
                in concentration : BloodGlucoseConcentration;
                out item result : GlucoseReading;
            }

            action showAndStoreResult {
                in item result : GlucoseReading;
            }
        }

        state def MeterOperationalState {
            state Off;
            state ReadyForStrip;
            state StripInserted;
            state WaitingForBlood;
            state Measuring;
            state DisplayingResult;
            state Error;
            state MemoryReview;

            transition initial then Off;

            transition Off_to_Ready
                first Off
                accept UserCommand
                if command.commandName == "powerOn"
                then ReadyForStrip;

            transition Ready_to_StripInserted
                first ReadyForStrip
                accept UserCommand
                if command.commandName == "insertStrip"
                then StripInserted;

            transition Strip_to_WaitingForBlood
                first StripInserted
                if meter.stripDetected == true and testStrip.usable == true
                then WaitingForBlood;

            transition Waiting_to_Measuring
                first WaitingForBlood
                accept CapillaryWholeBlood
                if sample.sampleVolume >= requiredSampleVolume
                then Measuring;

            transition Measuring_to_Display
                first Measuring
                if meter.currentReading.valid == true
                then DisplayingResult;

            transition Measuring_to_Error
                first Measuring
                if meter.currentReading.valid == false
                then Error;

            transition Display_to_Ready
                first DisplayingResult
                accept UserCommand
                if command.commandName == "removeStrip"
                then ReadyForStrip;

            transition Ready_to_Memory
                first ReadyForStrip
                accept UserCommand
                if command.commandName == "reviewMemory"
                then MemoryReview;

            transition Memory_to_Ready
                first MemoryReview
                accept UserCommand
                if command.commandName == "exitMemory"
                then ReadyForStrip;

            transition Any_to_Off
                first ReadyForStrip
                accept UserCommand
                if command.commandName == "powerOff"
                then Off;
        }
    }

    part def HandheldMeter {
        attribute stripDetected : Boolean;
        attribute currentReading : GlucoseReading;
        attribute analogExcitationVoltage : Volt = 0.4;
        attribute batteryLowThreshold : Volt = 2.6;
        attribute measurementDuration : SecondDuration = 5.0;
        attribute maxStoredReadings : Integer = 150;

        port stripConnector : StripElectricalPort;
        port readingOut : ReadingPort;
        port displayMessageOut : DisplayPort;
        port memoryAccess : MemoryPort;
        port powerIn : PowerInputPort;

        part analogFrontEnd : AnalogFrontEnd;
        part microcontroller : GlucoseProcessingController;
        part temperatureSensor : TemperatureSensor;
        part clock : MeasurementTimer;

        connect stripConnector to analogFrontEnd.stripPort;
        connect analogFrontEnd.signalOut to microcontroller.signalIn;
        connect temperatureSensor.temperatureOut to microcontroller.temperatureIn;
        connect clock.tickOut to microcontroller.timeIn;
        connect microcontroller.readingOut to readingOut;
        connect microcontroller.displayOut to displayMessageOut;
        connect microcontroller.memoryPort to memoryAccess;
    }

    part def ElectrochemicalTestStrip {
        attribute lotCalibrated : Boolean = true;
        attribute usable : Boolean = true;
        attribute minimumFillVolume : MicroliterVolume = 1.0;
        attribute enzymeChemistry : String = "glucose oxidase electrochemical reagent";
        attribute singleUse : Boolean = true;

        port sampleWell : BloodApplicationPort;
        port electrodeInterface : StripElectricalPort;

        part capillaryChannel : SampleCapillaryChannel;
        part reagentLayer : GlucoseReactiveLayer;
        part workingElectrode : Electrode;
        part referenceElectrode : Electrode;

        connect sampleWell to capillaryChannel.sampleIn;
        connect capillaryChannel.sampleOut to reagentLayer.sampleIn;
        connect reagentLayer.signalOut to electrodeInterface;
    }

    part def SampleCapillaryChannel {
        attribute filledVolume : MicroliterVolume;
        attribute fillComplete : Boolean;

        port sampleIn : BloodApplicationPort;
        port sampleOut : BloodApplicationPort;
    }

    part def GlucoseReactiveLayer {
        attribute reactionTime : SecondDuration = 3.0;
        attribute convertsGlucoseToCurrent : Boolean = true;

        port sampleIn : BloodApplicationPort;
        port signalOut : StripElectricalPort;
    }

    part def Electrode {
        attribute material : String;
        attribute exposedArea : Real {
            unit = "mm^2";
        }
    }

    part def AnalogFrontEnd {
        attribute inputCurrentRangeLow : Real {
            unit = "uA";
        } = 0.1;
        attribute inputCurrentRangeHigh : Real {
            unit = "uA";
        } = 100.0;
        attribute adcResolutionBits : Integer = 12;

        port stripPort : StripElectricalPort;
        port signalOut : ElectrochemicalSignalPort;
    }

    port def ElectrochemicalSignalPort {
        out item signal : ElectrochemicalSignal;
    }

    part def GlucoseProcessingController {
        attribute calibrationSlope : Real = 1.0;
        attribute calibrationOffset : BloodGlucoseConcentration = 0.0;
        attribute lowBattery : Boolean;
        attribute lastErrorCode : String;

        port signalIn : ElectrochemicalSignalPort;
        port temperatureIn : TemperaturePort;
        port timeIn : TimerPort;
        port readingOut : ReadingPort;
        port displayOut : DisplayPort;
        port memoryPort : MemoryPort;

        action def ComputeGlucoseReading {
            in item signal : ElectrochemicalSignal;
            in ambientTemperature : CelsiusTemperature;
            out item reading : GlucoseReading;

            attribute rawGlucose : BloodGlucoseConcentration;
            attribute compensatedGlucose : BloodGlucoseConcentration;
        }
    }

    part def TemperatureSensor {
        attribute accuracy : CelsiusTemperature = 1.0;
        port temperatureOut : TemperaturePort;
    }

    port def TemperaturePort {
        out ambientTemperature : CelsiusTemperature;
    }

    part def MeasurementTimer {
        attribute resolution : SecondDuration = 0.1;
        port tickOut : TimerPort;
    }

    port def TimerPort {
        out elapsedTime : SecondDuration;
    }

    part def UserInterface {
        port commandIn : CommandPort;
        port displayIn : DisplayPort;
        port displayOut : DisplayPort;
        port powerIn : PowerInputPort;

        part lcd : LiquidCrystalDisplay;
        part buttons : MeterButtons;

        connect commandIn to buttons.commandOut;
        connect displayIn to lcd.messageIn;
        connect lcd.messageOut to displayOut;
    }

    part def LiquidCrystalDisplay {
        attribute digitCount : Integer = 3;
        attribute supportsErrorMessages : Boolean = true;
        attribute supportsMemoryReview : Boolean = true;

        port messageIn : DisplayPort;
        port messageOut : DisplayPort;
    }

    part def MeterButtons {
        attribute buttonCount : Integer = 2;
        port commandOut : CommandPort;
    }

    part def ReadingMemory {
        attribute capacity : Integer = 150;
        attribute storedCount : Integer;
        port memoryPort : MemoryPort;
    }

    part def ReplaceableBattery {
        attribute nominalVoltage : Volt = 3.0;
        attribute remainingCapacity : MilliampereHour;
        port powerOut : PowerOutputPort;
    }

    port def PowerOutputPort {
        out voltage : Volt;
    }

    port def PowerInputPort {
        in voltage : Volt;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide a high-level blood glucose self-monitoring function based on a OneTouch Ultra-style handheld glucose meter. */
        subject system : OneTouchUltraBloodGlucoseMonitoringSystem;

        require constraint {
            system.requiredSampleVolume <= 1.0 and
            system.nominalMeasurementDuration <= 5.0 and
            system.reportableRangeLow <= 20.0 and
            system.reportableRangeHigh >= 600.0
        }
    }

    requirement def SampleAcceptanceRequirement {
        doc /* The system shall accept a capillary whole-blood sample of at least 1.0 uL through the test strip sample port. */
        subject strip : ElectrochemicalTestStrip;

        require constraint {
            strip.minimumFillVolume <= 1.0 and strip.singleUse == true
        }
    }

    requirement def ReadingDisplayRequirement {
        doc /* The system shall display a valid glucose reading or an error message after the measurement sequence completes. */
        subject ui : UserInterface;

        require constraint {
            ui.lcd.supportsErrorMessages == true
        }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The system shall classify and report glucose measurements over the normal OneTouch Ultra high-level reportable range. */
        subject system : OneTouchUltraBloodGlucoseMonitoringSystem;

        require constraint {
            system.reportableRangeLow == 20.0 and
            system.reportableRangeHigh == 600.0
        }
    }

    requirement def MemoryRequirement {
        doc /* The system shall retain recent glucose readings for later review by the user. */
        subject memory : ReadingMemory;

        require constraint {
            memory.capacity >= 150
        }
    }

    requirement def EnvironmentalOperatingRequirement {
        doc /* The system shall support measurement only inside defined operating temperature and humidity bounds. */
        subject system : OneTouchUltraBloodGlucoseMonitoringSystem;

        require constraint {
            system.operatingTemperatureMin >= 6.0 and
            system.operatingTemperatureMax <= 44.0 and
            system.operatingHumidityMax <= 90.0
        }
    }

    satisfy PrimaryFunctionRequirement by OneTouchUltraBloodGlucoseMonitoringSystem;
    satisfy SampleAcceptanceRequirement by ElectrochemicalTestStrip;
    satisfy ReadingDisplayRequirement by UserInterface;
    satisfy MeasurementRangeRequirement by OneTouchUltraBloodGlucoseMonitoringSystem;
    satisfy MemoryRequirement by ReadingMemory;
    satisfy EnvironmentalOperatingRequirement by OneTouchUltraBloodGlucoseMonitoringSystem;
}