package HomeUltrasoundSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Frequency :> ISQ::frequency;
    attribute def Voltage :> ISQ::electricPotential;
    attribute def Power :> ISQ::power;
    attribute def TimeDuration :> ISQ::time;
    attribute def Length :> ISQ::length;
    attribute def Temperature :> ISQ::thermodynamicTemperature;
    attribute def Pressure :> ISQ::pressure;
    attribute def AcousticIntensity {
        attribute value : Real;
        attribute unit : String = "mW/cm^2";
    }
    attribute def MechanicalIndex {
        attribute value : Real;
    }
    attribute def ThermalIndex {
        attribute value : Real;
    }
    attribute def FrameRate {
        attribute value : Real;
        attribute unit : String = "frames/s";
    }
    attribute def BatteryCharge {
        attribute value : Real;
        attribute unit : String = "%";
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : ISQ::electricCurrent;
        attribute power : Power;
    }

    item def UltrasoundPulse {
        attribute centerFrequency : Frequency;
        attribute pulseDuration : TimeDuration;
        attribute acousticPressure : Pressure;
        attribute mechanicalIndex : MechanicalIndex;
        attribute thermalIndex : ThermalIndex;
    }

    item def EchoSignal {
        attribute timeOfFlight : TimeDuration;
        attribute amplitude : Real;
        attribute probeElementId : Integer;
        attribute estimatedDepth : Length;
    }

    item def BeamformedScanline {
        attribute angle : Real;
        attribute depthRange : Length;
        attribute sampleCount : Integer;
    }

    item def UltrasoundImageFrame {
        attribute frameId : Integer;
        attribute capturedAt : TimeDuration;
        attribute widthPixels : Integer;
        attribute heightPixels : Integer;
        attribute frameRate : FrameRate;
        attribute imagingDepth : Length;
    }

    item def UserCommand {
        attribute commandKind : String;
        attribute requestedDepth : Length;
        attribute requestedGain : Real;
        attribute scanPreset : String;
    }

    item def SafetyStatus {
        attribute probeContactDetected : Boolean;
        attribute acousticOutputEnabled : Boolean;
        attribute batterySafe : Boolean;
        attribute probeTemperature : Temperature;
        attribute mechanicalIndex : MechanicalIndex;
        attribute thermalIndex : ThermalIndex;
        attribute message : String;
    }

    item def ExamRecord {
        attribute patientAlias : String;
        attribute examStart : TimeDuration;
        attribute examDuration : TimeDuration;
        attribute frameCount : Integer;
        attribute encrypted : Boolean;
    }

    port def PowerInPort {
        in item power : ElectricalPower;
    }

    port def PowerOutPort {
        out item power : ElectricalPower;
    }

    port def CommandInPort {
        in item command : UserCommand;
    }

    port def CommandOutPort {
        out item command : UserCommand;
    }

    port def PulseOutPort {
        out item pulse : UltrasoundPulse;
    }

    port def EchoInPort {
        in item echo : EchoSignal;
    }

    port def EchoOutPort {
        out item echo : EchoSignal;
    }

    port def ScanlineOutPort {
        out item scanline : BeamformedScanline;
    }

    port def ScanlineInPort {
        in item scanline : BeamformedScanline;
    }

    port def ImageOutPort {
        out item frame : UltrasoundImageFrame;
    }

    port def ImageInPort {
        in item frame : UltrasoundImageFrame;
    }

    port def SafetyOutPort {
        out item status : SafetyStatus;
    }

    port def SafetyInPort {
        in item status : SafetyStatus;
    }

    part def RechargeableBattery {
        attribute nominalVoltage : Voltage = 14.8[V];
        attribute capacity : Real = 4.0;
        attribute capacityUnit : String = "Ah";
        attribute charge : BatteryCharge;
        attribute minimumOperatingCharge : BatteryCharge = 15.0;
        port powerOut : PowerOutPort;

        state batteryState {
            state charged;
            state lowCharge;
            state depleted;

            entry; then charged;

            transition charged_to_low
                first charged
                accept when charge.value <= 20.0
                then lowCharge;

            transition low_to_depleted
                first lowCharge
                accept when charge.value <= 5.0
                then depleted;

            transition low_to_charged
                first lowCharge
                accept when charge.value > 25.0
                then charged;
        }
    }

    part def ProbeArray {
        attribute elementCount : Integer = 128;
        attribute centerFrequency : Frequency = 3.5[MHz];
        attribute maximumSurfaceTemperature : Temperature = 313.15[K];
        attribute activeApertureWidth : Length = 38[mm];

        port pulseOut : PulseOutPort;
        port echoOut : EchoOutPort;
        port safetyOut : SafetyOutPort;

        action transmitPulse {
            in item command : UserCommand;
            out item pulse : UltrasoundPulse;

            attribute selectedFrequency : Frequency = centerFrequency;
            attribute selectedMechanicalIndex : MechanicalIndex = 0.75;
            attribute selectedThermalIndex : ThermalIndex = 0.6;
        }

        action receiveEchoes {
            in item pulse : UltrasoundPulse;
            out item echo : EchoSignal;

            attribute receiveWindow : TimeDuration = 120[us];
            attribute maxDepth : Length = 160[mm];
        }
    }

    part def PulserReceiver {
        attribute transmitVoltage : Voltage = 80[V];
        attribute receiveGain : Real = 42.0;
        attribute maxPulseRepetitionFrequency : Frequency = 6[kHz];

        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port pulseOut : PulseOutPort;
        port echoIn : EchoInPort;
        port echoOut : EchoOutPort;
    }

    part def Beamformer {
        attribute channels : Integer = 128;
        attribute samplingFrequency : Frequency = 40[MHz];
        attribute dynamicFocusingEnabled : Boolean = true;

        port echoIn : EchoInPort;
        port scanlineOut : ScanlineOutPort;

        action formScanline {
            in item rawEcho : EchoSignal;
            out item scanline : BeamformedScanline;

            attribute apertureElementsUsed : Integer = 64;
            attribute speedOfSoundAssumption : Real = 1540.0;
            attribute speedUnit : String = "m/s";
        }
    }

    part def ImageProcessor {
        attribute defaultDepth : Length = 120[mm];
        attribute defaultGain : Real = 50.0;
        attribute speckleReductionLevel : Integer = 2;
        attribute frameRateTarget : FrameRate = 24.0;

        port scanlineIn : ScanlineInPort;
        port commandIn : CommandInPort;
        port imageOut : ImageOutPort;

        action createBModeFrame {
            in item scanline : BeamformedScanline;
            out item frame : UltrasoundImageFrame;

            attribute grayscaleLevels : Integer = 256;
            attribute widthPixels : Integer = 800;
            attribute heightPixels : Integer = 600;
        }
    }

    part def SafetyController {
        attribute maxMechanicalIndex : MechanicalIndex = 1.9;
        attribute maxThermalIndex : ThermalIndex = 1.0;
        attribute maxProbeTemperature : Temperature = 313.15[K];
        attribute minimumBatteryChargeForScan : BatteryCharge = 15.0;

        port safetyIn : SafetyInPort;
        port commandOut : CommandOutPort;
        port safetyOut : SafetyOutPort;

        action evaluateSafety {
            in item reportedStatus : SafetyStatus;
            out item approvedCommand : UserCommand;
            out item resultingStatus : SafetyStatus;
        }

        state safetyState {
            state idleSafe;
            state scanPermitted;
            state outputLimited;
            state scanInhibited;

            entry; then idleSafe;

            transition permit_scan
                first idleSafe
                accept when safetyIn.status.probeContactDetected and
                            safetyIn.status.batterySafe and
                            safetyIn.status.probeTemperature < maxProbeTemperature
                then scanPermitted;

            transition limit_output
                first scanPermitted
                accept when safetyIn.status.thermalIndex.value >= 0.8 or
                            safetyIn.status.mechanicalIndex.value >= 1.5
                then outputLimited;

            transition inhibit_from_scan
                first scanPermitted
                accept when not safetyIn.status.probeContactDetected or
                            safetyIn.status.probeTemperature >= maxProbeTemperature
                then scanInhibited;

            transition inhibit_from_limited
                first outputLimited
                accept when safetyIn.status.thermalIndex.value > maxThermalIndex.value or
                            safetyIn.status.mechanicalIndex.value > maxMechanicalIndex.value
                then scanInhibited;

            transition reset_to_idle
                first scanInhibited
                accept UserCommand
                then idleSafe;
        }
    }

    part def UserInterface {
        attribute displayDiagonal : Length = 152[mm];
        attribute touchEnabled : Boolean = true;
        attribute supportedPresets : String = "abdomen, bladder, vascular, obstetric preview";

        port commandOut : CommandOutPort;
        port imageIn : ImageInPort;
        port safetyIn : SafetyInPort;

        action requestScan {
            out item command : UserCommand;
            attribute preset : String = "abdomen";
            attribute depth : Length = 120[mm];
            attribute gain : Real = 50.0;
        }

        action presentImage {
            in item frame : UltrasoundImageFrame;
            in item status : SafetyStatus;
        }
    }

    part def SecureStorage {
        attribute localCapacity : Real = 128.0;
        attribute capacityUnit : String = "GB";
        attribute encryptionEnabled : Boolean = true;
        attribute retentionDays : Integer = 30;

        port imageIn : ImageInPort;

        action storeExamFrame {
            in item frame : UltrasoundImageFrame;
            out item record : ExamRecord;
        }
    }

    part def WirelessLink {
        attribute wifiEnabled : Boolean = true;
        attribute bluetoothEnabled : Boolean = true;
        attribute encryptedTransport : Boolean = true;

        port imageIn : ImageInPort;
        port safetyIn : SafetyInPort;

        action transmitExamSummary {
            in item record : ExamRecord;
            in item status : SafetyStatus;
        }
    }

    part def HomeUltrasoundSystem {
        attribute deviceMass : Real = 0.85;
        attribute massUnit : String = "kg";
        attribute nominalImagingDepth : Length = 120[mm];
        attribute primaryFunction : String =
            "Acquire ultrasound echo data at home, reconstruct a real-time B-mode image, display it to the user, and enforce acoustic and thermal safety limits.";

        part battery : RechargeableBattery;
        part userInterface : UserInterface;
        part safetyController : SafetyController;
        part pulserReceiver : PulserReceiver;
        part probeArray : ProbeArray;
        part beamformer : Beamformer;
        part imageProcessor : ImageProcessor;
        part secureStorage : SecureStorage;
        part wirelessLink : WirelessLink;

        connect battery.powerOut to pulserReceiver.powerIn;

        connect userInterface.commandOut to safetyController.commandOut;
        connect safetyController.commandOut to pulserReceiver.commandIn;
        connect safetyController.commandOut to imageProcessor.commandIn;

        connect pulserReceiver.pulseOut to probeArray.pulseOut;
        connect probeArray.echoOut to pulserReceiver.echoIn;
        connect pulserReceiver.echoOut to beamformer.echoIn;

        connect beamformer.scanlineOut to imageProcessor.scanlineIn;
        connect imageProcessor.imageOut to userInterface.imageIn;
        connect imageProcessor.imageOut to secureStorage.imageIn;
        connect imageProcessor.imageOut to wirelessLink.imageIn;

        connect probeArray.safetyOut to safetyController.safetyIn;
        connect safetyController.safetyOut to userInterface.safetyIn;
        connect safetyController.safetyOut to wirelessLink.safetyIn;

        action performHomeScan {
            in item scanRequest : UserCommand;
            out item diagnosticPreview : UltrasoundImageFrame;
            out item finalStatus : SafetyStatus;

            first start;
            then checkBattery;
            then verifyProbeContact;
            then enableAcousticOutput;
            then acquireEchoData;
            then reconstructImage;
            then displayFrame;
            then storeEncryptedFrame;
            then stopOutput;

            action start;
            action checkBattery;
            action verifyProbeContact;
            action enableAcousticOutput;
            action acquireEchoData;
            action reconstructImage;
            action displayFrame;
            action storeEncryptedFrame;
            action stopOutput;
        }

        state operatingState {
            state poweredOff;
            state standby;
            state ready;
            state scanning;
            state paused;
            state fault;

            entry; then poweredOff;

            transition power_on
                first poweredOff
                accept UserCommand
                then standby;

            transition initialize
                first standby
                accept when battery.charge.value > 15.0
                then ready;

            transition begin_scan
                first ready
                accept when safetyController.safetyState == safetyController.safetyState.scanPermitted
                then scanning;

            transition pause_scan
                first scanning
                accept UserCommand
                then paused;

            transition resume_scan
                first paused
                accept UserCommand
                then scanning;

            transition complete_scan
                first scanning
                accept UserCommand
                then ready;

            transition enter_fault
                first scanning
                accept when safetyController.safetyState == safetyController.safetyState.scanInhibited
                then fault;

            transition clear_fault
                first fault
                accept UserCommand
                then standby;

            transition power_down
                first standby
                accept UserCommand
                then poweredOff;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         * The home ultrasound system shall provide a high-level primary function
         * of producing a real-time ultrasound image preview from acoustic echoes
         * while being suitable for operation in a home environment.
         */
        subject system : HomeUltrasoundSystem;

        require constraint {
            system.primaryFunction ==
            "Acquire ultrasound echo data at home, reconstruct a real-time B-mode image, display it to the user, and enforce acoustic and thermal safety limits."
        }
    }

    requirement def ImagingPerformanceRequirement {
        doc
        /*
         * The system shall produce B-mode ultrasound image frames at a clinically
         * useful preview rate for guided home scanning.
         */
        subject system : HomeUltrasoundSystem;

        require constraint {
            system.imageProcessor.frameRateTarget.value >= 20.0
        }

        require constraint {
            system.imageProcessor.defaultDepth <= 160[mm]
        }
    }

    requirement def AcousticSafetyRequirement {
        doc
        /*
         * The system shall limit acoustic output so that mechanical and thermal
         * indices remain within conservative home-use limits.
         */
        subject system : HomeUltrasoundSystem;

        require constraint {
            system.safetyController.maxMechanicalIndex.value <= 1.9
        }

        require constraint {
            system.safetyController.maxThermalIndex.value <= 1.0
        }
    }

    requirement def ProbeTemperatureRequirement {
        doc
        /*
         * The probe shall not exceed the allowed surface temperature during
         * normal scanning.
         */
        subject system : HomeUltrasoundSystem;

        require constraint {
            system.probeArray.maximumSurfaceTemperature <= 313.15[K]
        }
    }

    requirement def BatteryOperationRequirement {
        doc
        /*
         * The system shall inhibit scanning when available battery charge is below
         * the minimum charge required for safe operation.
         */
        subject system : HomeUltrasoundSystem;

        require constraint {
            system.battery.minimumOperatingCharge.value >= 15.0
        }
    }

    requirement def DataProtectionRequirement {
        doc
        /*
         * The system shall store local exam image data using encryption and shall
         * transmit summaries only over encrypted transport.
         */
        subject system : HomeUltrasoundSystem;

        require constraint {
            system.secureStorage.encryptionEnabled == true
        }

        require constraint {
            system.wirelessLink.encryptedTransport == true
        }
    }

    satisfy PrimaryFunctionRequirement by HomeUltrasoundSystem;
    satisfy ImagingPerformanceRequirement by HomeUltrasoundSystem;
    satisfy AcousticSafetyRequirement by HomeUltrasoundSystem;
    satisfy ProbeTemperatureRequirement by HomeUltrasoundSystem;
    satisfy BatteryOperationRequirement by HomeUltrasoundSystem;
    satisfy DataProtectionRequirement by HomeUltrasoundSystem;
}