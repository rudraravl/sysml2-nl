package HomeUltrasoundDevice {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Temperature :> Real { unit "degC"; }
    value def Frequency :> Real { unit "MHz"; }
    value def Voltage :> Real { unit "V"; }
    value def Current :> Real {> Real { unit "mAh"; }
    value def Duration :> Real { unit "h"; }
    value def Power :> Real { unit "W"; }
    value def Resolution :> Real { unit "pixel"; }
    value def ScreenSize :> Real { unit "inch"; }
    value def AcousticPressure :> Real { unit "kPa"; }

    // ===== Enumerations =====
    enum def ImagingMode {
        enum B_MODE;
        enum M_MODE;
        enum COLOR_DOPPLER;
    }

    enum def OperatingState {
        enum OFF;
        enum STANDBY;
        enum ACTIVE_IMAGING;
        enum FREEZE_FRAME;
    }

    // ===== Item Types =====
    item def AcousticPulse {
        attribute frequency : Frequency;
        attribute pressure : AcousticPressure;
    }

    item def EchoData {
        attribute amplitude : Real;
        attribute depth : Real;
        attribute timeOfFlight : Real;
    }

    item def RawChannelData {
        attribute elementId : Integer;
        attribute samples : Real[0..*];
    }

    item def ScanLine {
        attribute lineIndex : Integer;
        attribute depthSamples : Real[0..*];
    }

    item def ProcessedData {
        attribute scanLines : ScanLine[0..*];
        attribute gain : Real;
    }

    item def UltrasoundImage {
        attribute width : Resolution;
        attribute height : Resolution;
        attribute frameRate : Real;
        attribute mode : ImagingMode;
    }

    item def ControlCommand {
        attribute targetState : OperatingState;
        attribute imagingMode : ImagingMode;
        attribute gainSetting : Real;
    }

    item def PowerStatus {
        attribute batteryLevel : BatteryCapacity;
        attribute charging : Boolean;
    }

    // ===== Requirements =====
    requirement def PortabilityRequirement {
        doc "The device shall be portable and self-contained for home use."
        attribute minBatteryLife : Duration = 3.0 [h];
        constraint { batteryLife >= minBatteryLife }
    }

    requirement def SafetyRequirement {
        doc "The transducer surface temperature shall not exceed safe limits."
        attribute maxSurfaceTemp : Temperature = 41.0 [degC];
        constraint { surfaceTemperature <= maxSurfaceTemp }
    }

    requirement def ImagingRequirement {
        doc "The device shall support B-mode, M-mode, and Color Doppler imaging."
        constraint { supportedModes == {ImagingMode::B_MODE, ImagingMode::M_MODE, ImagingMode::COLOR_DOPPLER} }
    }

    requirement def DisplayRequirement {
        doc "The display shall be a 10.1-inch high-resolution screen."
        attribute minScreenSize : ScreenSize = 10.1 [inch];
        constraint { screenSize >= minScreenSize }
    }

    requirement def LifecycleRequirement {
        doc "The system shall transition through off, standby, active imaging, and freeze-frame states."
    }

    // ===== Parts =====
    part def TransducerArray {
        port acousticOut : out AcousticPulse;
        port echoIn : in EchoData;
        port channelDataOut : out RawChannelData;
        port thermalReadingOut : out Temperature;

        attribute numElements : Integer = 128;
        attribute centerFrequency : Frequency = 7.5 [MHz];
        attribute surfaceTemperature : Temperature;

        action def TransmitPulse {
            out pulse : AcousticPulse;
        }
        action def ReceiveEcho {
            in echo : EchoData;
            out raw : RawChannelData;
        }
    }

    part def ThermalMonitor {
        port tempIn : in Temperature;
        port safetyAlertOut : out Boolean;
        port powerCutOut : out Boolean;

        attribute threshold : Temperature = 41.0 [degC];
        attribute warningThreshold : Temperature = 39.0 [degC];

        state thermalStateMachine {
            state Normal;
            state Warning;
            state Critical;

            transition Normal_to_Warning first Normal if tempIn.value >= warningThreshold.value
                then Warning;
            transition Warning_to_Critical first Warning if tempIn.value >= threshold.value
                then Critical;
            transition Warning_to_Normal first Warning if tempIn.value < warningThreshold.value
                then Normal;
            transition Critical_to_Normal first Critical if tempIn.value < warningThreshold.value
                then Normal;
        }
    }

    part def Beamformer {
        port rawDataIn : in RawChannelData;
        port scanLineOut : out ScanLine;

        attribute focusDepth : Real;
        attribute apertureSize : Integer;

        action def FocusData {
            in raw : RawChannelData[0..*];
            out line : ScanLine;
        }
    }

    part def SignalProcessor {
        port scanLineIn : in ScanLine;
        port processedDataOut : out ProcessedData;

        attribute filterCutoff : Frequency = 5.0 [MHz];
        attribute gain : Real = 1.0;

        action def FilterNoise {
            in line : ScanLine;
            out filtered : ScanLine;
        }
        action def EnhanceSignal {
            in filtered : ScanLine;
            out enhanced : ScanLine;
        }
    }

    part def ImageProcessor {
        port processedDataIn : in ProcessedData;
        port imageOut : out UltrasoundImage;

        attribute currentMode : ImagingMode = ImagingMode::B_MODE;
        attribute frameBuffer : UltrasoundImage[0..*];

        action def AssembleImage {
            in data : ProcessedData;
            out image : UltrasoundImage;
        }
    }

    part def DisplayModule {
        port imageIn : in UltrasoundImage;
        port touchInputOut : out ControlCommand;

        attribute screenSize : ScreenSize = 10.1 [inch];
        attribute resolutionWidth : Resolution = 1920;
        attribute resolutionHeight : Resolution = 1200;

        action def RenderImage {
            in image : UltrasoundImage;
        }
    }

    part def PowerManagement {
        port powerOut : out Power;
        port statusOut : out PowerStatus;
        port chargeIn : in Voltage;

        attribute batteryCapacity : BatteryCapacity = 6000 [mAh];
        attribute batteryLife : Duration = 3.5 [h];
        attribute outputVoltage : Voltage = 12.0 [V];
        attribute currentCharge : BatteryCapacity;

        state powerStateMachine {
            state Discharging;
            state Charging;
            state LowBattery;
            state FullyCharged;

            transition Discharging_to_LowBattery first Discharging if currentCharge.value < batteryCapacity.value * 0.15
                then LowBattery;
            transition LowBattery_to_Charging first LowBattery if chargeIn.value > 0.0
                then Charging;
            transition Discharging_to_Charging first Discharging if chargeIn.value > 0.0
                then Charging;
            transition Charging_to_FullyCharged first Charging if currentCharge.value >= batteryCapacity.value
                then FullyCharged;
            transition FullyCharged_to_Discharging first FullyCharged if chargeIn.value == 0.0
                then Discharging;
            transition Charging_to_Discharging first Charging if chargeIn.value == 0.0
                then Discharging;
        }
    }

    part def ControlInterface {
        port commandOut : out ControlCommand;
        port statusIn : in PowerStatus;
        port thermalAlertIn : in Boolean;

        attribute physicalButtons : Boolean = true;
        attribute touchscreen : Boolean = true;
        attribute currentOperatingState : OperatingState = OperatingState::OFF;

        action def HandleUserInput {
            out command : ControlCommand;
        }
    }

    // ===== Top-level System =====
    part HomeUltrasoundSystem {
        satisfy PortabilityRequirement;
        satisfy SafetyRequirement;
        satisfy ImagingRequirement;
        satisfy DisplayRequirement;
        satisfy LifecycleRequirement;

        part transducerArray : TransducerArray {
            attribute supportedModes : ImagingMode[3] = {ImagingMode::B_MODE, ImagingMode::M_MODE, ImagingMode::COLOR_DOPPLER};
        }
        part thermalMonitor : ThermalMonitor;
        part beamformer : Beamformer;
        part signalProcessor : SignalProcessor;
        part imageProcessor : ImageProcessor;
        part displayModule : DisplayModule;
        part powerManagement : PowerManagement;
        part controlInterface : ControlInterface;

        // Internal connections
        connection transducerToBeamformer connect transducerArray.channelDataOut to beamformer.rawDataIn;
        connection beamformerToSignalProcessor connect beamformer.scanLineOut to signalProcessor.scanLineIn;
        connection signalProcessorToImageProcessor connect signalProcessor.processedDataOut to imageProcessor.processedDataIn;
        connection imageProcessorToDisplay connect imageProcessor.imageOut to displayModule.imageIn;
        connection transducerToThermalMonitor connect transducerArray.thermalReadingOut to thermalMonitor.tempIn;
        connection thermalMonitorToControlInterface connect thermalMonitor.safetyAlertOut to controlInterface.thermalAlertIn;
        connection displayToControlInterface connect displayModule.touchInputOut to controlInterface.commandOut;
        connection powerToAll connect powerManagement.powerOut to transducerArray;
        connection powerToBeamformer connect powerManagement.powerOut to beamformer;
        connection powerToSignalProcessor connect powerManagement.powerOut to signalProcessor;
        connection powerToImageProcessor connect powerManagement.powerOut to imageProcessor;
        connection powerToDisplay connect powerManagement.powerOut to displayModule;
        connection powerToControlInterface connect powerManagement.powerOut to controlInterface;
        connection powerStatusToControlInterface connect powerManagement.statusOut to controlInterface.statusIn;

        // System lifecycle state machine
        state systemLifecycle {
            state Off;
            state Standby;
            state ActiveImaging;
            state FreezeFrame;

            transition Off_to_Standby first Off if controlInterface.commandOut.targetState == OperatingState::STANDBY
                then Standby;
            transition Standby_to_ActiveImaging first Standby if controlInterface.commandOut.targetState == OperatingState::ACTIVE_IMAGING
                then ActiveImaging;
            transition ActiveImaging_to_FreezeFrame first ActiveImaging if controlInterface.commandOut.targetState == OperatingState::FREEZE_FRAME
                then FreezeFrame;
            transition FreezeFrame_to_ActiveImaging first FreezeFrame if controlInterface.commandOut.targetState == OperatingState::ACTIVE_IMAGING
                then ActiveImaging;
            transition ActiveImaging_to_Standby first ActiveImaging if controlInterface.commandOut.targetState == OperatingState::STANDBY
                then Standby;
            transition FreezeFrame_to_Standby first FreezeFrame if controlInterface.commandOut.targetState == OperatingState::STANDBY
                then Standby;
            transition Standby_to_Off first Standby if controlInterface.commandOut.targetState == OperatingState::OFF
                then Off;
            transition ActiveImaging_to_Off first ActiveImaging if controlInterface.commandOut.targetState == OperatingState::OFF
                then Off;
            transition FreezeFrame_to_Off first FreezeFrame if controlInterface.commandOut.targetState == OperatingState::OFF
                then Off;
            transition AnyState_to_Standby first ActiveImaging if thermalMonitor.powerCutOut.value == true
                then Standby;
        }
    }
}
