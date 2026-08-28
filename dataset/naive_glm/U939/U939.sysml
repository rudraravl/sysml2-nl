package PhotonCountingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----

    value def Wavelength :> Real {
        unit nm;
    }

    value def Temperature :> Real {
        unit K;
    }

    value def CountRate :> Real {
        unit 'count/s';
    }

    value def Voltage :> Real {
        unit V;
    }

    value def Frequency :> Real {
        unit Hz;
    }

    value def Duration :> Real {
        unit s;
    }

    value def Power :> Real {
        unit W;
    }

    value def Dimensionless :> Real {
        unit 1;
    }

    item def Photon {
        attribute wavelength : Wavelength;
    }

    item def ElectricalPulse {
        attribute amplitude : Voltage;
        attribute width : Duration;
    }

    item def DigitalPulse {
        attribute amplitude : Voltage;
        attribute width : Duration;
    }

    item def CountData {
        attribute totalCount : Integer;
        attribute detectionRate : CountRate;
        attribute integrationTime : Duration;
        attribute darkCountRate : CountRate;
    }

    item def Command {
        attribute type : String;
    }

    // ---- Port Definitions ----

    port def OpticalPort {
        out photons : Photon;
    }

    port def AnalogSignalPort {
        out pulse : ElectricalPulse;
    }

    port def DigitalSignalPort {
        out pulse : DigitalPulse;
    }

    port def CountPort {
        out count : CountData;
    }

    port def CommandPort {
        in command : Command;
    }

    port def ThermalPort {
        out temperature : Temperature;
    }

    // ---- Requirements ----

    requirement def DetectVisiblePhotons {
        doc /* The system shall detect individual photons in the visible spectrum. */
        attribute wavelengthRangeMin : Wavelength = 380 [nm];
        attribute wavelengthRangeMax : Wavelength = 750 [nm];
        subject detector : PhotonDetectorModule;
        require { detector.detectedWavelength >= wavelengthRangeMin and detector.detectedWavelength <= wavelengthRangeMax; }
    }

    requirement def MaintainTargetTemperature {
        doc /* The thermal controller shall maintain the detector at -20°C. */
        attribute targetTemperature : Temperature = 253.15 [K];
        attribute tolerance : Temperature = 0.5 [K];
        subject thermal : ThermalController;
        require { abs(thermal.measuredTemperature - targetTemperature) <= tolerance; }
    }

    requirement def SupportHighCountRate {
        doc /* The counting logic shall support up to 10 million counts per second. */
        attribute maxCountRate : CountRate = 10000000 ['count/s'];
        subject counter : CountingLogic;
        require { counter.maxSupportedRate <= maxCountRate; }
    }

    requirement def RejectNoise {
        doc /* The discriminator shall reject low-amplitude noise below threshold. */
        attribute noiseThreshold : Voltage = 0.05 [V];
        subject disc : PulseDiscriminator;
        require { disc.threshold >= noiseThreshold; }
    }

    requirement def MinimizeDarkCounts {
        doc /* The system shall minimize dark counts through cooling and calibration. */
        attribute maxDarkCountRate : CountRate = 1000 ['count/s'];
        subject system : PhotonCountingInstrument;
        require { system.measuredDarkCountRate <= maxDarkCountRate; }
    }

    // ---- Parts ----

    part def PhotonDetectorModule {
        port in opticalInput : OpticalPort;
        port out rawPulseOut : AnalogSignalPort;
        port in thermalFeedback : ThermalPort;

        attribute detectedWavelength : Wavelength;
        attribute operatingMode : String = "Geiger";
        attribute biasVoltage : Voltage = 350 [V];
        attribute darkCountRate : CountRate;

        attribute targetTemperature : Temperature = 253.15 [K];

        state detectorBehavior {
            entry; then Idle;
            state Idle;
            state Biased;
            state Detecting;
            transition from Idle to Biased when biasVoltage > 300 [V];
            transition from Biased to Detecting when thermalFeedback.temperature <= targetTemperature;
        }

        perform detectPhoton {
            in photon : Photon;
            out pulse : ElectricalPulse;
        }
    }

    part def ThermalController {
        port out coolingOutput : ThermalPort;
        port in temperatureSensor : ThermalPort;

        attribute targetTemperature : Temperature = 253.15 [K];
        attribute measuredTemperature : Temperature;
        attribute coolingPower : Power = 5 [W];
        attribute tolerance : Temperature = 0.5 [K];

        state thermalControl {
            entry; then Off;
            state Off;
            state Cooling;
            state Stable;
            state OverTemp;
            transition from Off to Cooling when targetTemperature < measuredTemperature;
            transition from Cooling to Stable when abs(measuredTemperature - targetTemperature) <= tolerance;
            transition from Stable to Cooling when abs(measuredTemperature - targetTemperature) > tolerance;
            transition from Stable to OverTemp when measuredTemperature > 260 [K];
            transition from OverTemp to Cooling when measuredTemperature < 258 [K];
        }

        perform regulateTemperature {
            in current : Temperature;
            out adjusted : Temperature;
        }
    }

    part def SignalConditioner {
        port in pulseIn : AnalogSignalPort;
        port out pulseOut : DigitalSignalPort;

        attribute gain : Dimensionless = 1000;
        attribute outputAmplitude : Voltage = 3.3 [V];
        attribute bandwidth : Frequency = 50000000 [Hz];

        perform conditionSignal {
            in raw : ElectricalPulse;
            out shaped : DigitalPulse;
        }
    }

    part def PulseDiscriminator {
        port in pulseIn : DigitalSignalPort;
        port out pulseOut : DigitalSignalPort;

        attribute threshold : Voltage = 0.05 [V];
        attribute rejectionRatio : Dimensionless = 0.95;

        perform discriminate {
            in pulse : DigitalPulse;
            out valid : DigitalPulse;
        }
    }

    part def CountingLogic {
        port in pulseIn : DigitalSignalPort;
        port out dataOut : CountPort;
        port in commandIn : CommandPort;

        attribute totalCount : Integer = 0;
        attribute integrationTime : Duration = 1 [s];
        attribute detectionRate : CountRate;
        attribute maxSupportedRate : CountRate = 10000000 ['count/s'];
        attribute countingActive : Boolean = false;

        state countingState {
            entry; then Ready;
            state Ready;
            state Counting;
            state Complete;
            transition from Ready to Counting when commandIn.command.type == "start";
            transition from Counting to Complete when integrationTime == 0 [s];
            transition from Complete to Ready when commandIn.command.type == "reset";
        }

        perform accumulateCounts {
            in pulse : DigitalPulse;
            out data : CountData;
        }
    }

    part def DataInterface {
        port in dataIn : CountPort;
        port out externalOutput : CountPort;
        port in commandIn : CommandPort;

        attribute baudRate : Frequency = 115200 [Hz];
        attribute protocol : String = "USB";

        perform transmitData {
            in data : CountData;
            out transmitted : CountData;
        }
    }

    part def CalibrationModule {
        port in detectorFeedback : AnalogSignalPort;
        port out commandOut : CommandPort;
        port in thermalStatus : ThermalPort;

        attribute darkCountRate : CountRate;
        attribute calibrationInterval : Duration = 300 [s];
        attribute lastCalibration : Duration = 0 [s];
        attribute correctionFactor : Dimensionless = 1.0;

        state calibrationState {
            entry; then Inactive;
            state Inactive;
            state Measuring;
            state Correcting;
            transition from Inactive to Measuring when lastCalibration >= calibrationInterval;
            transition from Measuring to Correcting when darkCountRate > 0 ['count/s'];
            transition from Correcting to Inactive when correctionFactor != 1.0;
        }

        perform calibrate {
            in feedback : ElectricalPulse;
            out command : Command;
        }
    }

    // ---- Top-level System ----

    part def PhotonCountingInstrument {
        port in opticalInput : OpticalPort;
        port out dataOutput : CountPort;
        port in commandInput : CommandPort;

        attribute measuredDarkCountRate : CountRate;

        satisfy DetectVisiblePhotors :> DetectVisiblePhotons;
        satisfy MaintainTargetTemp :> MaintainTargetTemperature;
        satisfy SupportHighRate :> SupportHighCountRate;
        satisfy RejectNoiseReq :> RejectNoise;
        satisfy MinimizeDark :> MinimizeDarkCounts;

        part detector : PhotonDetectorModule {
            port in opticalInput redefines opticalInput;
        }

        part thermal : ThermalController;

        part conditioner : SignalConditioner;

        part discriminator : PulseDiscriminator;

        part counter : CountingLogic;

        part dataInterface : DataInterface {
            port out externalOutput redefines dataOutput;
            port in commandIn redefines commandInput;
        }

        part calibration : CalibrationModule;

        // Connections
        connection opticalInput to detector.opticalInput;
        connection detector.rawPulseOut to conditioner.pulseIn;
        connection conditioner.pulseOut to discriminator.pulseIn;
        connection discriminator.pulseOut to counter.pulseIn;
        connection counter.dataOut to dataInterface.dataIn;
        connection commandInput to dataInterface.commandIn;
        connection commandInput to counter.commandIn;
        connection thermal.coolingOutput to detector.thermalFeedback;
        connection detector.rawPulseOut to calibration.detectorFeedback;
        connection thermal.coolingOutput to calibration.thermalStatus;
        connection calibration.commandOut to counter.commandIn;

        // System-level state machine
        state systemOperation {
            entry; then PowerOn;
            state PowerOn {
                entry; then Initializing;
            }
            state Initializing {
                doc /* System initializes and begins cooldown. */
            }
            state Cooldown {
                doc /* Detector cooling toward target temperature. */
            }
            state Standby {
                doc /* Target temperature reached; ready for commands. */
            }
            state Calibrating {
                doc /* Performing dark count calibration routine. */
            }
            state Measuring {
                doc /* Active photon counting measurement cycle. */
            }
            state Error {
                doc /* Fault condition detected, e.g., excessive dark counts. */
            }

            transition from PowerOn to Initializing when true;
            transition from Initializing to Cooldown when thermal.measuredTemperature < 270 [K];
            transition from Cooldown to Standby when abs(thermal.measuredTemperature - 253.15 [K]) <= 0.5 [K];
            transition from Standby to Calibrating when commandInput.command.type == "calibrate";
            transition from Standby to Measuring when commandInput.command.type == "measure";
            transition from Calibrating to Standby when calibration.correctionFactor != 1.0;
            transition from Measuring to Standby when counter.integrationTime == 0 [s];
            transition from Standby to Error when measuredDarkCountRate > 1000 ['count/s'];
            transition from Measuring to Error when measuredDarkCountRate > 1000 ['count/s'];
            transition from Error to Standby when commandInput.command.type == "reset" and measuredDarkCountRate <= 1000 ['count/s'];
        }
    }

}
