package 'Fluorescent Chloride Sensor System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def ChlorideConcentration :> ISQ::AmountOfSubstanceConcentrationValue;
    attribute def FluorescenceIntensity :> ISQ::LuminousIntensityValue;
    attribute def ExcitationWavelength :> ISQ::LengthValue;
    attribute def EmissionWavelength :> ISQ::LengthValue;
    attribute def QuenchingRatio :> Real;
    attribute def CalibrationCoefficient :> Real;
    attribute def SensorCommand;
    attribute def MeasurementComplete;
    attribute def TempStable;
    attribute def CalibrationDone;
    attribute def AcquisitionComplete;
    attribute def ComputationComplete;
    attribute def FlushComplete;
    attribute def FaultDetected;

    item def OpticalSignal {
        attribute wavelength : ISQ::LengthValue;
        attribute intensity : FluorescenceIntensity;
    }

    item def FluidSample {
        attribute chlorideLevel : ChlorideConcentration;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute pH : Real;
    }

    item def ElectricalData {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute digitalValue : Real;
    }

    port def OpticalInputPort {
        in excitation : OpticalSignal;
    }

    port def OpticalOutputPort {
        out emission : OpticalSignal;
    }

    port def FluidInterfacePort {
        in sample : FluidSample;
    }

    port def DataOutputPort {
        out concentration : ChlorideConcentration;
        out rawIntensity : FluorescenceIntensity;
    }

    port def ControlPort {
        in command : SensorCommand;
        out status : MeasurementComplete;
    }

    part def LEDExcitationSource {
        attribute nominalWavelength : ExcitationWavelength;
        attribute opticalPower : ISQ::PowerValue;
        attribute operatingCurrent : ISQ::ElectricCurrentValue;
        port lightOutput : OpticalOutputPort;
    }

    part def OpticalFilter {
        attribute centerWavelength : ISQ::LengthValue;
        attribute bandwidth : ISQ::LengthValue;
        attribute transmittance : Real;
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;
    }

    part def FluorescentIndicatorChamber {
        attribute chamberVolume : ISQ::VolumeValue;
        attribute dyeConcentration : ChlorideConcentration;
        attribute sternVolmerConstant : Real;
        port excitationInput : OpticalInputPort;
        port emissionOutput : OpticalOutputPort;
        port fluidInput : FluidInterfacePort;
    }

    part def Photodetector {
        attribute spectralResponse : Real;
        attribute activeArea : ISQ::AreaValue;
        attribute responsivity : Real;
        port opticalInput : OpticalInputPort;
        port electricalOutput : DataOutputPort;
    }

    part def SignalConditioner {
        attribute amplificationGain : Real;
        attribute filterFrequency : ISQ::FrequencyValue;
        attribute adcResolution : Real;
        port analogInput : DataOutputPort;
        port digitalOutput : DataOutputPort;
    }

    part def Microprocessor {
        attribute processingSpeed : ISQ::FrequencyValue;
        attribute memoryCapacity : Real;
        attribute calibrationTable : CalibrationCoefficient[*];
        port dataInput : DataOutputPort;
        port resultOutput : DataOutputPort;
        port control : ControlPort;
    }

    part def FlowCell {
        attribute flowRate : Real;
        attribute pathLength : ISQ::LengthValue;
        attribute windowMaterial : String;
        port sampleInlet : FluidInterfacePort;
        port sampleOutlet : FluidInterfacePort;
        port opticalAccess : OpticalInputPort;
    }

    action def GenerateExcitation {
        in powerLevel : ISQ::PowerValue;
        in wavelength : ExcitationWavelength;
        out excitationBeam : OpticalSignal;
    }

    action def FilterExcitation {
        in inputLight : OpticalSignal;
        in filterSpec : ISQ::LengthValue;
        out filteredLight : OpticalSignal;
    }

    action def ExciteFluorophore {
        in excitationLight : OpticalSignal;
        in sampleFluid : FluidSample;
        out emittedFluorescence : OpticalSignal;
    }

    action def FilterEmission {
        in emissionLight : OpticalSignal;
        in filterSpec : ISQ::LengthValue;
        out filteredEmission : OpticalSignal;
    }

    action def DetectPhotons {
        in opticalInput : OpticalSignal;
        in detectorGain : Real;
        out electricalSignal : ElectricalData;
    }

    action def ConditionSignal {
        in rawSignal : ElectricalData;
        in amplification : Real;
        out processedSignal : ElectricalData;
    }

    action def CalculateConcentration {
        in fluorescenceData : ElectricalData;
        in calibration : CalibrationCoefficient;
        in baselineIntensity : FluorescenceIntensity;
        out chlorideConcentration : ChlorideConcentration;
    }

    action def PerformMeasurementCycle {
        in sampleInput : FluidSample;
        in calibrationData : CalibrationCoefficient;
        out measuredConcentration : ChlorideConcentration;
        out measurementStatus : MeasurementComplete;

        first start;
        then action initiate {
            doc /* Initialize measurement sequence */
        }
        then action excite : GenerateExcitation {
            in powerLevel = 0.050 [SI::W];
            in wavelength = 365.0e-9 [SI::m];
            out excitationBeam;
        }
        then action filterExc : FilterExcitation {
            in inputLight = excite.excitationBeam;
            in filterSpec = 365.0e-9 [SI::m];
            out filteredLight;
        }
        then action interact : ExciteFluorophore {
            in excitationLight = filterExc.filteredLight;
            in sampleFluid = sampleInput;
            out emittedFluorescence;
        }
        then action filterEm : FilterEmission {
            in emissionLight = interact.emittedFluorescence;
            in filterSpec = 460.0e-9 [SI::m];
            out filteredEmission;
        }
        then action detect : DetectPhotons {
            in opticalInput = filterEm.filteredEmission;
            in detectorGain = 100.0;
            out electricalSignal;
        }
        then action condition : ConditionSignal {
            in rawSignal = detect.electricalSignal;
            in amplification = 10.0;
            out processedSignal;
        }
        then action compute : CalculateConcentration {
            in fluorescenceData = condition.processedSignal;
            in calibration = calibrationData;
            in baselineIntensity = 1000.0 [SI::cd];
            out chlorideConcentration;
        }
        then assign measuredConcentration := compute.chlorideConcentration;
        then assign measurementStatus := MeasurementComplete;
        then done;
    }

    state def SensorOperationalStates {
        entry; then standby;

        state standby {
            doc /* Sensor powered but inactive */
        }

        state warmup {
            doc /* LED and electronics stabilizing */
        }

        state calibration {
            doc /* Running calibration with standards */
            entry action calibrate;
        }

        state measuring {
            doc /* Active measurement in progress */
            entry action measure : PerformMeasurementCycle;
        }

        state dataProcessing {
            doc /* Computing concentration from fluorescence */
        }

        state flushing {
            doc /* Cleaning flow cell between samples */
        }

        state error {
            doc /* Fault condition detected */
        }

        transition standby_to_warmup
            first standby
            accept powerOn : SensorCommand
            then warmup;

        transition warmup_to_calibration
            first warmup
            accept tempStable : TempStable
            then calibration;

        transition calibration_to_standby
            first calibration
            accept calibrationDone : CalibrationDone
            then standby;

        transition standby_to_measuring
            first standby
            accept startMeasurement : SensorCommand
            then measuring;

        transition measuring_to_dataProcessing
            first measuring
            accept acquisitionComplete : AcquisitionComplete
            then dataProcessing;

        transition dataProcessing_to_flushing
            first dataProcessing
            accept computationComplete : ComputationComplete
            then flushing;

        transition flushing_to_standby
            first flushing
            accept flushComplete : FlushComplete
            then standby;

        transition any_to_error
            first standby
            accept faultDetected : FaultDetected
            then error;

        transition error_to_standby
            first error
            accept reset : SensorCommand
            then standby;
    }

    part fluorescenceChlorideSensor : FluorescenceChlorideSensor {
        doc /* Integrated fluorescent chloride sensor system for real-time ion monitoring */

        part excitationLED : LEDExcitationSource {
            attribute :>> nominalWavelength = 365.0e-9 [SI::m];
            attribute :>> opticalPower = 0.050 [SI::W];
            attribute :>> operatingCurrent = 0.020 [SI::A];
        }

        part excitationFilter : OpticalFilter {
            attribute :>> centerWavelength = 365.0e-9 [SI::m];
            attribute :>> bandwidth = 10.0e-9 [SI::m];
            attribute :>> transmittance = 0.95;
        }

        part sensingChamber : FluorescentIndicatorChamber {
            attribute :>> chamberVolume = 100.0e-9 [SI::m3];
            attribute :>> dyeConcentration = 10.0 [SI::mol/SI::m3];
            attribute :>> sternVolmerConstant = 118.0;
        }

        part emissionFilter : OpticalFilter {
            attribute :>> centerWavelength = 460.0e-9 [SI::m];
            attribute :>> bandwidth = 40.0e-9 [SI::m];
            attribute :>> transmittance = 0.90;
        }

        part detector : Photodetector {
            attribute :>> spectralResponse = 0.85;
            attribute :>> activeArea = 1.0e-6 [SI::m2];
            attribute :>> responsivity = 0.4;
        }

        part signalProcessor : SignalConditioner {
            attribute :>> amplificationGain = 10.0;
            attribute :>> filterFrequency = 1000.0 [SI::Hz];
            attribute :>> adcResolution = 16.0;
        }

        part controller : Microprocessor {
            attribute :>> processingSpeed = 100.0e6 [SI::Hz];
            attribute :>> memoryCapacity = 512.0;
            perform action continuousMeasurement {
                loop {
                    accept measureCommand : SensorCommand;
                    then action measurementCycle : PerformMeasurementCycle {
                        in sampleInput;
                        in calibrationData = controller.calibrationTable;
                        out measuredConcentration;
                        out measurementStatus;
                    }
                    then action transmitResult {
                        in result = measurementCycle.measuredConcentration;
                    }
                }
            }
        }

        part flowSystem : FlowCell {
            attribute :>> flowRate = 1.0;
            attribute :>> pathLength = 10.0e-3 [SI::m];
            attribute :>> windowMaterial = "quartz";
        }

        connection excitationPath connect excitationLED.lightOutput to excitationFilter.opticalIn;
        connection filteredExcitationPath connect excitationFilter.opticalOut to sensingChamber.excitationInput;
        connection emissionPath connect sensingChamber.emissionOutput to emissionFilter.opticalIn;
        connection filteredEmissionPath connect emissionFilter.opticalOut to detector.opticalInput;
        connection detectorDataPath connect detector.electricalOutput to signalProcessor.analogInput;
        connection processedDataPath connect signalProcessor.digitalOutput to controller.dataInput;
        connection sampleFlowPath connect flowSystem.sampleOutlet to sensingChamber.fluidInput;

        exhibit state operatingState : SensorOperationalStates;
    }

    part def FluorescenceChlorideSensor;

    requirement <'REQ-001'> measurementRangeRequirement {
        doc /* The sensor shall measure chloride concentrations from 1 mM to 500 mM */
        subject sensor : FluorescenceChlorideSensor;
        require constraint {
            1.0 [SI::mol/SI::m3] <= sensor.sensingChamber.dyeConcentration and
            sensor.sensingChamber.dyeConcentration <= 500.0 [SI::mol/SI::m3]
        }
    }

    requirement <'REQ-002'> accuracyRequirement {
        doc /* The sensor shall provide concentration measurements with accuracy within ±3% of reading */
        subject fluorescenceChlorideSensor;
    }

    requirement <'REQ-003'> responseTimeRequirement {
        doc /* The sensor shall complete a measurement cycle within 10 seconds */
        subject fluorescenceChlorideSensor;
    }

    requirement <'REQ-004'> selectivityRequirement {
        doc /* The sensor shall exhibit selectivity for chloride over bromide and iodide with ratio > 10:1 */
        subject fluorescenceChlorideSensor;
    }

    requirement <'REQ-005'> stabilityRequirement {
        doc /* The sensor baseline shall remain stable within ±2% over 8 hours of continuous operation */
        subject fluorescenceChlorideSensor;
    }

    requirement <'REQ-006'> temperatureRangeRequirement {
        doc /* The sensor shall operate accurately in temperature range 15°C to 35°C */
        subject fluorescenceChlorideSensor;
    }

    requirement systemFunctionalRequirement {
        doc /* Primary function: Continuously monitor chloride ion concentration in aqueous samples
             using fluorescence quenching mechanism with real-time output */

        assume constraint aqueousSample {
            doc /* Sample must be aqueous solution with pH 5-9 */
        }

        assume constraint opticalClearance {
            doc /* Sample must be optically clear with turbidity < 10 NTU */
        }

        require measurementRangeRequirement;
        require accuracyRequirement;
        require responseTimeRequirement;
        require selectivityRequirement;
        require stabilityRequirement;
        require temperatureRangeRequirement;
    }
}
