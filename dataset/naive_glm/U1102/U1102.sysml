package IR_Sensor_System {

    comment /* High-Performance Infrared Sensor System
               A sophisticated thermal camera that detects invisible heat radiation
               and converts it into a visual thermal image. */;

    // ============ Value Types ============
    value type TemperatureK :> Real;
    value type PowerW :> Real;
    value type VoltageV :> Real;
    value type CurrentA :> Real;
    value type FrequencyHz :> Real;
    value type LengthM :> Real;
    value type LengthUm :> Real;
    value type TimeS :> Real;
    value type Dimensionless :> Real;

    // ============ Item Definitions ============
    item def InfraredRadiation {
        attribute wavelength: LengthUm [1] default 10.0;
        attribute intensity: Dimensionless [1] default 1.0;
        attribute sourceTemperature: TemperatureK [1] default 300.0;
    }

    item def FocusedRadiation {
        attribute wavelength: LengthUm [1] default 10.0;
        attribute intensity: Dimensionless [1] default 1.0;
        attribute focusQuality: Dimensionless [1] default 0.95;
    }

    item def RawElectricalSignal {
        attribute voltageLevel: VoltageV [1] default 0.0;
        attribute pixelRow: Integer [1];
        attribute pixelCol: Integer [1];
        attribute timestamp: TimeS [1] default 0.0;
    }

    item def CalibratedData {
        attribute pixelRow: Integer [1];
        attribute pixelCol: Integer [1];
        attribute calibratedValue: Dimensionless [1] default 0.0;
        attribute gainApplied: Dimensionless [1] default 1.0;
        attribute offsetApplied: Dimensionless [1] default 0.0;
    }

    item def TemperatureMap {
        attribute width: Integer [1] default 640;
        attribute height: Integer [1] default 480;
        attribute pixelData: TemperatureK [*];
        attribute minTemp: TemperatureK [1] default 273.0;
        attribute maxTemp: TemperatureK [1] default 373.0;
    }

    item def ThermalImage {
        attribute width: Integer [1] default 640;
        attribute height: Integer [1] default 480;
        attribute frameRate: FrequencyHz [1] default 30.0;
        attribute colorPalette: String [1] default "iron";
        attribute timestamp: TimeS [1] default 0.0;
        attribute encoding: String [1] default "RAW16";
    }

    item def ElectricalPower {
        attribute voltage: VoltageV [1] default 12.0;
        attribute current: CurrentA [1] default 2.0;
        attribute maxPower: PowerW [1] default 25.0;
    }

    // ============ Port Definitions ============
    port def SceneRadiationPort {
        out item radiation: InfraredRadiation;
    }

    port def FocusedRadiationPort {
        out item radiation: FocusedRadiation;
    }

    port def RawSignalPort {
        out item signal: RawElectricalSignal;
    }

    port def TemperatureMapPort {
        out item map: TemperatureMap;
    }

    port def ThermalImagePort {
        out item image: ThermalImage;
    }

    port def PowerPort {
        out item power: ElectricalPower;
    }

    // ============ Part Definitions ============

    part def OpticalSystem {
        comment /* Lens assembly that gathers infrared radiation from a scene
                   and focuses it onto the focal plane array. */;
        attribute focalLength: LengthM [1] default 0.025;
        attribute aperture: LengthM [1] default 0.015;
        attribute spectralRangeMin: LengthUm [1] default 8.0;
        attribute spectralRangeMax: LengthUm [1] default 14.0;
        attribute transmissionEfficiency: Dimensionless [1] default 0.92;
        attribute fNumber: Dimensionless [1] default 1.4;
        attribute lensMaterial: String [1] default "Germanium";
        attribute powerConsumption: PowerW [1] default 0.5;

        port radiationIn: >>SceneRadiationPort;
        port radiationOut: FocusedRadiationPort;
        port powerIn: >>PowerPort;

        action focusRadiation {
            in radiation: InfraredRadiation;
            out focused: FocusedRadiation;
        }
    }

    part def FocalPlaneArray {
        comment /* Core sensor chip containing a grid of detector elements
                   that convert focused infrared radiation into raw electrical signals. */;
        attribute detectorWidth: Integer [1] default 640;
        attribute detectorHeight: Integer [1] default 480;
        attribute pixelPitch: LengthM [1] default 17.0e-6;
        attribute operatingTemperature: TemperatureK [1] default 77.0;
        attribute currentTemperature: TemperatureK [1] default 293.0;
        attribute noiseEquivalentTempDiff: TemperatureK [1] default 0.05;
        attribute quantumEfficiency: Dimensionless [1] default 0.85;
        attribute integrationTime: TimeS [1] default 0.016;
        attribute detectorType: String [1] default "InSb";
        attribute powerConsumption: PowerW [1] default 1.5;

        port radiationIn: >>FocusedRadiationPort;
        port signalOut: RawSignalPort;
        port powerIn: >>PowerPort;

        action convertRadiation {
            in radiation: FocusedRadiation;
            out signal: RawElectricalSignal;
        }

        action readOutPixels {
            out signals: RawElectricalSignal [*];
        }
    }

    part def CryogenicCooler {
        comment /* Refrigeration unit that maintains the focal plane array
                   at a cryogenic operating temperature of 77 Kelvin. */;
        attribute targetTemperature: TemperatureK [1] default 77.0;
        attribute cooldownTime: TimeS [1] default 300.0;
        attribute coolingCapacity: PowerW [1] default 1.5;
        attribute currentTemperature: TemperatureK [1] default 293.0;
        attribute powerConsumption: PowerW [1] default 8.0;
        attribute coolerType: String [1] default "StirlingCycle";
        attribute meanTimeBetweenFailure: TimeS [1] default 8000.0;
        attribute vibrationLevel: Dimensionless [1] default 0.02;

        port powerIn: >>PowerPort;

        action coolDown {
            in initialTemp: TemperatureK;
            in targetTemp: TemperatureK;
            out finalTemp: TemperatureK;
        }

        action maintainTemperature {
            in target: TemperatureK;
            out actual: TemperatureK;
        }

        action stabilizeTemperature {
            in current: TemperatureK;
            in target: TemperatureK;
            out stable: Boolean;
        }
    }

    part def SignalProcessingUnit {
        comment /* Processor that corrects raw data, applies calibration factors,
                   and converts electrical signals into a precise temperature map. */;
        attribute processingRate: FrequencyHz [1] default 60.0;
        attribute gainValue: Dimensionless [1] default 1.0;
        attribute offsetValue: Dimensionless [1] default 0.0;
        attribute badPixelMask: Boolean [*];
        attribute calibrationCoefficients: Dimensionless [*];
        attribute powerConsumption: PowerW [1] default 3.0;
        attribute processorType: String [1] default "FPGA";
        attribute memorySize: Integer [1] default 512;
        attribute nonUniformityCorrection: Boolean [1] default true;

        port signalIn: >>RawSignalPort;
        port dataOut: TemperatureMapPort;
        port powerIn: >>PowerPort;

        action correctRawData {
            in signal: RawElectricalSignal;
            out corrected: CalibratedData;
        }

        action applyCalibration {
            in data: CalibratedData;
            out calibrated: CalibratedData;
        }

        action generateTemperatureMap {
            in data: CalibratedData;
            out map: TemperatureMap;
        }

        action performNonUniformityCorrection {
            in raw: RawElectricalSignal [*];
            out corrected: RawElectricalSignal [*];
        }
    }

    part def ImageFormationModule {
        comment /* Assembles the temperature map into a standard,
                   viewable thermal image or video frame. */;
        attribute frameRate: FrequencyHz [1] default 30.0;
        attribute resolutionWidth: Integer [1] default 640;
        attribute resolutionHeight: Integer [1] default 480;
        attribute colorPalette: String [1] default "iron";
        attribute powerConsumption: PowerW [1] default 2.0;
        attribute outputFormat: String [1] default "RAW16";
        attribute autoGainControl: Boolean [1] default true;
        attribute digitalZoom: Dimensionless [1] default 1.0;

        port dataIn: >>TemperatureMapPort;
        port imageOut: ThermalImagePort;
        port powerIn: >>PowerPort;

        action assembleImage {
            in map: TemperatureMap;
            out image: ThermalImage;
        }

        action applyColorPalette {
            in map: TemperatureMap;
            in palette: String;
            out image: ThermalImage;
        }

        action encodeFrame {
            in image: ThermalImage;
            out encoded: ThermalImage;
        }
    }

    part def PowerManagementUnit {
        comment /* Manages and distributes electrical power from an external source
                   to all subsystems of the infrared sensor. */;
        attribute inputVoltage: VoltageV [1] default 12.0;
        attribute totalPowerBudget: PowerW [1] default 25.0;
        attribute efficiency: Dimensionless [1] default 0.92;
        attribute outputVoltage: VoltageV [1] default 5.0;
        attribute powerConsumption: PowerW [1] default 1.0;
        attribute overCurrentProtection: Boolean [1] default true;
        attribute thermalShutdown: Boolean [1] default true;
        attribute inputCurrentLimit: CurrentA [1] default 3.0;

        port powerIn: >>PowerPort;
        port powerOutOptical: PowerPort;
        port powerOutFPA: PowerPort;
        port powerOutCooler: PowerPort;
        port powerOutSPU: PowerPort;
        port powerOutIFM: PowerPort;

        action distributePower {
            in input: ElectricalPower;
            out opticalPower: ElectricalPower;
            out fpaPower: ElectricalPower;
            out coolerPower: ElectricalPower;
            out spuPower: ElectricalPower;
            out ifmPower: ElectricalPower;
        }

        action regulateVoltage {
            in inputVoltage: VoltageV;
            out outputVoltage: VoltageV;
        }

        action monitorPower {
            in totalPower: PowerW;
            out status: Boolean;
        }
    }

    // ============ Event Definitions ============
    event def PowerOnEvent;
    event def TemperatureStableEvent;
    event def CalibrationCompleteEvent;
    event def CaptureCommandEvent;
    event def CaptureCompleteEvent;
    event def PowerOffEvent;
    event def FaultEvent;

    // ============ Action Definitions ============
    action def CoolDownSequence {
        comment /* Activates the cryogenic cooler and monitors the focal plane array
                   temperature until it reaches the operating point of 77 Kelvin. */;
        in cooler: CryogenicCooler;
        in fpa: FocalPlaneArray;
        out stable: Boolean;
    }

    action def CalibrationSequence {
        comment /* Runs a calibration routine using the signal processing unit
                   to establish gain and offset correction factors. */;
        in spu: SignalProcessingUnit;
        in fpa: FocalPlaneArray;
        out complete: Boolean;
    }

    action def CaptureSequence {
        comment /* Executes the full image capture chain: optics focus radiation,
                   FPA converts to electrical signals, SPU generates temperature map,
                   and IFM assembles the final thermal image. */;
        in optical: OpticalSystem;
        in fpa: FocalPlaneArray;
        in spu: SignalProcessingUnit;
        in ifm: ImageFormationModule;
        out image: ThermalImage;
    }

    action def MaintainTempSequence {
        comment /* Maintains the focal plane array at cryogenic operating temperature
                   during idle and ready states. */;
        in cooler: CryogenicCooler;
    }

    // ============ Main System ============
    part def IRSensorSystem {
        comment /* High-performance infrared sensor system that detects invisible
                   heat radiation and converts it into a visual thermal image. */;
        attribute systemName: String [1] default "HighPerformanceIRSensor";
        attribute manufacturer: String [1] default "ThermalVisionCorp";
        attribute modelNumber: String [1] default "TV-IR-640";
        attribute serialNumber: String [1];
        attribute systemTemperature: TemperatureK [1] default 293.0;
        attribute isReady: Boolean [1] default false;
        attribute totalPowerConsumption: PowerW [1] default 0.0;
        attribute firmwareVersion: String [1] default "2.4.1";

        port externalPower: >>PowerPort;
        port imageOutput: ThermalImagePort;
        port sceneInput: >>SceneRadiationPort;

        // Subsystem parts
        part opticalSystem: OpticalSystem;
        part focalPlaneArray: FocalPlaneArray;
        part cryogenicCooler: CryogenicCooler;
        part signalProcessingUnit: SignalProcessingUnit;
        part imageFormationModule: ImageFormationModule;
        part powerManagementUnit: PowerManagementUnit;

        // Internal flow connections
        connection radiationPath
            connect opticalSystem.radiationOut
            to focalPlaneArray.radiationIn;

        connection signalPath
            connect focalPlaneArray.signalOut
            to signalProcessingUnit.signalIn;

        connection dataPath
            connect signalProcessingUnit.dataOut
            to imageFormationModule.dataIn;

        // Power distribution connections
        connection powerToOptical
            connect powerManagementUnit.powerOutOptical
            to opticalSystem.powerIn;

        connection powerToFPA
            connect powerManagementUnit.powerOutFPA
            to focalPlaneArray.powerIn;

        connection powerToCooler
            connect powerManagementUnit.powerOutCooler
            to cryogenicCooler.powerIn;

        connection powerToSPU
            connect powerManagementUnit.powerOutSPU
            to signalProcessingUnit.powerIn;

        connection powerToIFM
            connect powerManagementUnit.powerOutIFM
            to imageFormationModule.powerIn;

        // External interface connections
        connection externalPowerIn
            connect externalPower
            to powerManagementUnit.powerIn;

        connection sceneRadiationIn
            connect sceneInput
            to opticalSystem.radiationIn;

        connection imageOutputOut
            connect imageFormationModule.imageOut
            to imageOutput;

        // System-level actions
        action coolDownAction {
            comment /* Activate cryogenic cooler and bring FPA to 77K. */;
        }

        action calibrationAction {
            comment /* Run calibration routine to establish correction factors. */;
        }

        action maintainTempAction {
            comment /* Maintain FPA at operating temperature. */;
        }

        action captureAction {
            comment /* Execute full capture chain to produce thermal image. */;
        }

        // Operational State Machine
        state operationalBehavior {
            comment /* System operation follows: power-on initialization,
                       optional calibration, ready standby, and capture. */;

            state off {
                comment /* System is powered down. All subsystems inactive. */;
            }

            state initializing {
                comment /* Cryogenic cooler brings detector down to required
                           operating temperature of 77 Kelvin. */;
                do coolDownAction;
            }

            state calibration {
                comment /* Calibration routine runs to correct raw data and
                           apply calibration factors. */;
                do calibrationAction;
            }

            state ready {
                comment /* System is ready and can be commanded to capture
                           an image. Maintains operating temperature. */;
                do maintainTempAction;
            }

            state capturing {
                comment /* Full capture chain executes: optics gather radiation,
                           detector converts to signals, processors generate
                           temperature map, and image is formed. */;
                do captureAction;
            }

            state fault {
                comment /* System has detected a fault and requires attention. */;
            }

            transition offToInit
                first off
                then initializing
                accept PowerOnEvent;

            transition initToCalibration
                first initializing
                then calibration
                accept TemperatureStableEvent;

            transition calibrationToReady
                first calibration
                then ready
                accept CalibrationCompleteEvent;

            transition readyToCapturing
                first ready
                then capturing
                accept CaptureCommandEvent;

            transition capturingToReady
                first capturing
                then ready
                accept CaptureCompleteEvent;

            transition readyToOff
                first ready
                then off
                accept PowerOffEvent;

            transition initToFault
                first initializing
                then fault
                accept FaultEvent;

            transition calibrationToFault
                first calibration
                then fault
                accept FaultEvent;

            transition readyToFault
                first ready
                then fault
                accept FaultEvent;

            transition capturingToFault
                first capturing
                then fault
                accept FaultEvent;

            transition faultToOff
                first fault
                then off
                accept PowerOffEvent;
        }
    }

    // ============ Requirements ============

    requirement def CryogenicTempRequirement {
        doc /* The cryogenic cooler shall maintain the focal plane array
               at or below 77 Kelvin during operation. */;
        subject cooler: CryogenicCooler;
        constraint { cooler.currentTemperature <= 77.0 }
    }

    requirement def DetectionSensitivityRequirement {
        doc /* The focal plane array shall achieve a noise equivalent
               temperature difference of 50 millikelvin or better. */;
        subject fpa: FocalPlaneArray;
        constraint { fpa.noiseEquivalentTempDiff <= 0.05 }
    }

    requirement def FrameRateRequirement {
        doc /* The image formation module shall produce thermal images
               at a minimum frame rate of 30 Hz. */;
        subject ifm: ImageFormationModule;
        constraint { ifm.frameRate >= 30.0 }
    }

    requirement def ResolutionRequirement {
        doc /* The focal plane array shall have a minimum resolution
               of 640 by 480 detector elements. */;
        subject fpa: FocalPlaneArray;
        constraint { fpa.detectorWidth >= 640 and fpa.detectorHeight >= 480 }
    }

    requirement def PowerBudgetRequirement {
        doc /* The total system power consumption shall not exceed 25 watts. */;
        subject pmu: PowerManagementUnit;
        constraint { pmu.totalPowerBudget <= 25.0 }
    }

    requirement def SpectralRangeRequirement {
        doc /* The optical system shall detect infrared radiation
               in the 8 to 14 micrometer long-wave infrared spectral band. */;
        subject optics: OpticalSystem;
        constraint { optics.spectralRangeMin >= 8.0 and optics.spectralRangeMax <= 14.0 }
    }

    requirement def InitializationTimeRequirement {
        doc /* The cryogenic cooler shall bring the detector to operating
               temperature within 5 minutes of power-on. */;
        subject cooler: CryogenicCooler;
        constraint { cooler.cooldownTime <= 300.0 }
    }

    requirement def OpticalTransmissionRequirement {
        doc /* The optical system shall achieve a minimum transmission
               efficiency of 90 percent across the operational spectral band. */;
        subject optics: OpticalSystem;
        constraint { optics.transmissionEfficiency >= 0.90 }
    }

    requirement def QuantumEfficiencyRequirement {
        doc /* The focal plane array shall achieve a minimum quantum
               efficiency of 80 percent at the peak wavelength. */;
        subject fpa: FocalPlaneArray;
        constraint { fpa.quantumEfficiency >= 0.80 }
    }

    requirement def PowerEfficiencyRequirement {
        doc /* The power management unit shall operate at a minimum
               efficiency of 90 percent. */;
        subject pmu: PowerManagementUnit;
        constraint { pmu.efficiency >= 0.90 }
    }

    requirement def CoolerReliabilityRequirement {
        doc /* The cryogenic cooler shall have a mean time between failures
               of at least 8000 hours. */;
        subject cooler: CryogenicCooler;
        constraint { cooler.meanTimeBetweenFailure >= 8000.0 }
    }

    // ============ Requirement Usages ============
    requirement cryoTempReq : CryogenicTempRequirement {
        subject cooler := cryogenicCooler;
    }

    requirement sensitivityReq : DetectionSensitivityRequirement {
        subject fpa := focalPlaneArray;
    }

    requirement frameRateReq : FrameRateRequirement {
        subject ifm := imageFormationModule;
    }

    requirement resolutionReq : ResolutionRequirement {
        subject fpa := focalPlaneArray;
    }

    requirement powerBudgetReq : PowerBudgetRequirement {
        subject pmu := powerManagementUnit;
    }

    requirement spectralReq : SpectralRangeRequirement {
        subject optics := opticalSystem;
    }

    requirement initTimeReq : InitializationTimeRequirement {
        subject cooler := cryogenicCooler;
    }

    requirement transmissionReq : OpticalTransmissionRequirement {
        subject optics := opticalSystem;
    }

    requirement quantumEffReq : QuantumEfficiencyRequirement {
        subject fpa := focalPlaneArray;
    }

    requirement powerEffReq : PowerEfficiencyRequirement {
        subject pmu := powerManagementUnit;
    }

    requirement coolerReliabilityReq : CoolerReliabilityRequirement {
        subject cooler := cryogenicCooler;
    }
}
