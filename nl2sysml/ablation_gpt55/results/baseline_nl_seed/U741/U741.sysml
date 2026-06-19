package LabOnChipPrimaryFunctionModel {
    import ScalarValues::*;

    attribute def Volume_uL :> Real;
    attribute def FlowRate_uL_per_min :> Real;
    attribute def Temperature_degC :> Real;
    attribute def Time_s :> Real;
    attribute def Voltage_V :> Real;
    attribute def Current_mA :> Real;
    attribute def Power_mW :> Real;
    attribute def Pressure_kPa :> Real;
    attribute def Concentration_ng_per_mL :> Real;
    attribute def SampleRate_Hz :> Real;
    attribute def Count :> Integer;
    attribute def Fraction_0_to_1 :> Real;

    enum def AssayMode {
        enum rapid;
        enum standard;
        enum highSensitivity;
    }

    enum def AssayStatus {
        enum idle;
        enum acceptingSample;
        enum priming;
        enum metering;
        enum mixing;
        enum incubating;
        enum sensing;
        enum processing;
        enum reporting;
        enum cleaning;
        enum complete;
        enum faulted;
    }

    item def Liquid {
        attribute volume_uL : Volume_uL;
        attribute temperature_degC : Temperature_degC;
    }

    item def PatientSample :> Liquid {
        attribute sampleIdentifier : String;
        attribute nominalAnalyteName : String;
        attribute expectedConcentration_ng_per_mL : Concentration_ng_per_mL;
    }

    item def Reagent :> Liquid {
        attribute reagentName : String;
        attribute lotIdentifier : String;
        attribute storageTemperature_degC : Temperature_degC;
    }

    item def Buffer :> Reagent {
        attribute pH : Real;
    }

    item def MeteredSample :> Liquid {
        attribute meteredVolume_uL : Volume_uL;
        attribute meteringError_uL : Volume_uL;
    }

    item def MeteredReagent :> Liquid {
        attribute meteredVolume_uL : Volume_uL;
        attribute reagentRatioToSample : Real;
    }

    item def AssayMixture :> Liquid {
        attribute sampleVolume_uL : Volume_uL;
        attribute reagentVolume_uL : Volume_uL;
        attribute mixingCompleteness : Fraction_0_to_1;
    }

    item def PreparedAssayMixture :> AssayMixture {
        attribute incubationTime_s : Time_s;
        attribute incubationTemperature_degC : Temperature_degC;
    }

    item def WasteFluid :> Liquid {
        attribute biohazardLevel : String;
    }

    item def OpticalSignal {
        attribute wavelength_nm : Real;
        attribute intensity : Real;
        attribute samplingRate_Hz : SampleRate_Hz;
    }

    item def ElectricalPower {
        attribute voltage_V : Voltage_V;
        attribute current_mA : Current_mA;
        attribute availablePower_mW : Power_mW;
    }

    item def HeatFlow {
        attribute thermalPower_mW : Power_mW;
        attribute targetTemperature_degC : Temperature_degC;
    }

    item def AssayCommand {
        attribute commandIdentifier : String;
        attribute requestedMode : AssayMode;
        attribute requestedSampleVolume_uL : Volume_uL;
    }

    item def ControlMessage {
        attribute messageName : String;
        attribute status : AssayStatus;
    }

    item def CalibrationData {
        attribute calibrationIdentifier : String;
        attribute slope : Real;
        attribute intercept : Real;
        attribute validUntilEpoch_s : Time_s;
    }

    item def RawSensorData {
        attribute opticalIntensity : Real;
        attribute darkCurrent : Real;
        attribute temperature_degC : Temperature_degC;
        attribute samplingRate_Hz : SampleRate_Hz;
    }

    item def AssayResult {
        attribute sampleIdentifier : String;
        attribute analyteName : String;
        attribute concentration_ng_per_mL : Concentration_ng_per_mL;
        attribute confidence : Fraction_0_to_1;
        attribute resultTime_s : Time_s;
    }

    item def StartAssaySignal;
    item def SampleDetectedSignal;
    item def PrimingCompleteSignal;
    item def MeteringCompleteSignal;
    item def MixingCompleteSignal;
    item def IncubationCompleteSignal;
    item def SensingCompleteSignal;
    item def ProcessingCompleteSignal;
    item def ReportCompleteSignal;
    item def CleaningCompleteSignal;
    item def FaultDetectedSignal;
    item def ResetSignal;

    port def SampleLoadPort {
        in item sample : PatientSample;
    }

    port def SampleInPort {
        in item sample : PatientSample;
    }

    port def SampleOutPort {
        out item sample : PatientSample;
    }

    port def MeteredSampleInPort {
        in item sample : MeteredSample;
    }

    port def MeteredSampleOutPort {
        out item sample : MeteredSample;
    }

    port def ReagentLoadPort {
        in item reagent : Reagent;
    }

    port def ReagentInPort {
        in item reagent : Reagent;
    }

    port def ReagentOutPort {
        out item reagent : Reagent;
    }

    port def MeteredReagentInPort {
        in item reagent : MeteredReagent;
    }

    port def MeteredReagentOutPort {
        out item reagent : MeteredReagent;
    }

    port def MixtureInPort {
        in item mixture : AssayMixture;
    }

    port def MixtureOutPort {
        out item mixture : AssayMixture;
    }

    port def PreparedMixtureInPort {
        in item mixture : PreparedAssayMixture;
    }

    port def PreparedMixtureOutPort {
        out item mixture : PreparedAssayMixture;
    }

    port def WasteInPort {
        in item waste : WasteFluid;
    }

    port def WasteOutPort {
        out item waste : WasteFluid;
    }

    port def OpticalSignalOutPort {
        out item signal : OpticalSignal;
    }

    port def OpticalSignalInPort {
        in item signal : OpticalSignal;
    }

    port def RawDataOutPort {
        out item data : RawSensorData;
    }

    port def RawDataInPort {
        in item data : RawSensorData;
    }

    port def ResultOutPort {
        out item result : AssayResult;
    }

    port def ResultInPort {
        in item result : AssayResult;
    }

    port def CommandInPort {
        in item command : AssayCommand;
    }

    port def ControlBusPort {
        inout item message : ControlMessage;
    }

    port def PowerInPort {
        in item power : ElectricalPower;
    }

    port def PowerOutPort {
        out item power : ElectricalPower;
    }

    port def HeatInPort {
        in item heat : HeatFlow;
    }

    port def HeatOutPort {
        out item heat : HeatFlow;
    }

    interface def SampleTransfer {
        end source : SampleOutPort;
        end sink : SampleInPort;
        flow source.sample to sink.sample;
    }

    interface def MeteredSampleTransfer {
        end source : MeteredSampleOutPort;
        end sink : MeteredSampleInPort;
        flow source.sample to sink.sample;
    }

    interface def ReagentTransfer {
        end source : ReagentOutPort;
        end sink : ReagentInPort;
        flow source.reagent to sink.reagent;
    }

    interface def MeteredReagentTransfer {
        end source : MeteredReagentOutPort;
        end sink : MeteredReagentInPort;
        flow source.reagent to sink.reagent;
    }

    interface def MixtureTransfer {
        end source : MixtureOutPort;
        end sink : MixtureInPort;
        flow source.mixture to sink.mixture;
    }

    interface def PreparedMixtureTransfer {
        end source : PreparedMixtureOutPort;
        end sink : PreparedMixtureInPort;
        flow source.mixture to sink.mixture;
    }

    interface def WasteTransfer {
        end source : WasteOutPort;
        end sink : WasteInPort;
        flow source.waste to sink.waste;
    }

    interface def OpticalSignalTransfer {
        end source : OpticalSignalOutPort;
        end sink : OpticalSignalInPort;
        flow source.signal to sink.signal;
    }

    interface def RawDataTransfer {
        end source : RawDataOutPort;
        end sink : RawDataInPort;
        flow source.data to sink.data;
    }

    interface def ResultTransfer {
        end source : ResultOutPort;
        end sink : ResultInPort;
        flow source.result to sink.result;
    }

    interface def PowerTransfer {
        end source : PowerOutPort;
        end sink : PowerInPort;
        flow source.power to sink.power;
    }

    interface def HeatTransfer {
        end source : HeatOutPort;
        end sink : HeatInPort;
        flow source.heat to sink.heat;
    }

    action def LoadSampleAction {
        in sample : PatientSample;
        out loadedSample : PatientSample;
    }

    action def PrimeChannelsAction {
        in buffer : Buffer;
        out primedWaste : WasteFluid;
    }

    action def MeterSampleAction {
        in sample : PatientSample;
        out meteredSample : MeteredSample;
    }

    action def MeterReagentAction {
        in reagent : Reagent;
        out meteredReagent : MeteredReagent;
    }

    action def MixFluidsAction {
        in sample : MeteredSample;
        in reagent : MeteredReagent;
        out mixture : AssayMixture;
    }

    action def IncubateMixtureAction {
        in mixture : AssayMixture;
        out preparedMixture : PreparedAssayMixture;
    }

    action def SenseAnalyteAction {
        in preparedMixture : PreparedAssayMixture;
        out rawData : RawSensorData;
        out waste : WasteFluid;
    }

    action def ProcessResultAction {
        in rawData : RawSensorData;
        in calibration : CalibrationData;
        out result : AssayResult;
    }

    action def ReportResultAction {
        in result : AssayResult;
        out reportedResult : AssayResult;
    }

    action def CleanChannelsAction {
        in buffer : Buffer;
        out waste : WasteFluid;
    }

    action def ExecuteLabOnChipAssayAction {
        in command : AssayCommand;
        in sample : PatientSample;
        in reagent : Reagent;
        in buffer : Buffer;
        in calibration : CalibrationData;
        out result : AssayResult;
        out waste : WasteFluid;

        action loadSample : LoadSampleAction;
        action primeChannels : PrimeChannelsAction;
        action meterSample : MeterSampleAction;
        action meterReagent : MeterReagentAction;
        action mixFluids : MixFluidsAction;
        action incubateMixture : IncubateMixtureAction;
        action senseAnalyte : SenseAnalyteAction;
        action processResult : ProcessResultAction;
        action reportResult : ReportResultAction;
        action cleanChannels : CleanChannelsAction;

        first loadSample then primeChannels;
        then meterSample;
        then meterReagent;
        then mixFluids;
        then incubateMixture;
        then senseAnalyte;
        then processResult;
        then reportResult;
        then cleanChannels;

        flow sample to loadSample.sample;
        flow loadSample.loadedSample to meterSample.sample;
        flow reagent to meterReagent.reagent;
        flow buffer to primeChannels.buffer;
        flow meterSample.meteredSample to mixFluids.sample;
        flow meterReagent.meteredReagent to mixFluids.reagent;
        flow mixFluids.mixture to incubateMixture.mixture;
        flow incubateMixture.preparedMixture to senseAnalyte.preparedMixture;
        flow senseAnalyte.rawData to processResult.rawData;
        flow calibration to processResult.calibration;
        flow processResult.result to reportResult.result;
        flow reportResult.reportedResult to result;
        flow senseAnalyte.waste to waste;
    }

    state def AssayControllerStates {
        entry; then standby;

        state standby {
            accept StartAssaySignal then acceptingSample;
        }

        state acceptingSample {
            do action loadSample : LoadSampleAction;
            accept SampleDetectedSignal then priming;
            accept FaultDetectedSignal then faulted;
        }

        state priming {
            do action primeChannels : PrimeChannelsAction;
            accept PrimingCompleteSignal then metering;
            accept FaultDetectedSignal then faulted;
        }

        state metering {
            do action meterSample : MeterSampleAction;
            do action meterReagent : MeterReagentAction;
            accept MeteringCompleteSignal then mixing;
            accept FaultDetectedSignal then faulted;
        }

        state mixing {
            do action mixFluids : MixFluidsAction;
            accept MixingCompleteSignal then incubating;
            accept FaultDetectedSignal then faulted;
        }

        state incubating {
            do action incubateMixture : IncubateMixtureAction;
            accept IncubationCompleteSignal then sensing;
            accept FaultDetectedSignal then faulted;
        }

        state sensing {
            do action senseAnalyte : SenseAnalyteAction;
            accept SensingCompleteSignal then processing;
            accept FaultDetectedSignal then faulted;
        }

        state processing {
            do action processResult : ProcessResultAction;
            accept ProcessingCompleteSignal then reporting;
            accept FaultDetectedSignal then faulted;
        }

        state reporting {
            do action reportResult : ReportResultAction;
            accept ReportCompleteSignal then cleaning;
            accept FaultDetectedSignal then faulted;
        }

        state cleaning {
            do action cleanChannels : CleanChannelsAction;
            accept CleaningCompleteSignal then standby;
            accept FaultDetectedSignal then faulted;
        }

        state faulted {
            accept ResetSignal then standby;
        }
    }

    part def SampleReservoir {
        attribute capacity_uL : Volume_uL = 120.0;
        attribute minimumDetectableVolume_uL : Volume_uL = 2.0;
        port loadPort : SampleLoadPort;
        port outlet : SampleOutPort;
        port control : ControlBusPort;
        port power : PowerInPort;
    }

    part def ReagentReservoir {
        attribute capacity_uL : Volume_uL = 500.0;
        attribute storageTemperature_degC : Temperature_degC = 4.0;
        port loadPort : ReagentLoadPort;
        port outlet : ReagentOutPort;
        port control : ControlBusPort;
        port power : PowerInPort;
    }

    part def WasteReservoir {
        attribute capacity_uL : Volume_uL = 1000.0;
        attribute fillWarningThreshold_uL : Volume_uL = 850.0;
        port inlet : WasteInPort;
        port control : ControlBusPort;
    }

    part def MicroPump {
        attribute minimumFlowRate_uL_per_min : FlowRate_uL_per_min = 1.0;
        attribute maximumFlowRate_uL_per_min : FlowRate_uL_per_min = 80.0;
        attribute maximumBackPressure_kPa : Pressure_kPa = 120.0;
        port control : ControlBusPort;
        port power : PowerInPort;
    }

    part def SampleMeteringPump :> MicroPump {
        attribute targetSampleVolume_uL : Volume_uL = 20.0;
        attribute volumeAccuracy_uL : Volume_uL = 0.5;
        port sampleIn : SampleInPort;
        port sampleOut : MeteredSampleOutPort;
        perform action meterSample : MeterSampleAction;
    }

    part def ReagentMeteringPump :> MicroPump {
        attribute targetReagentVolume_uL : Volume_uL = 40.0;
        attribute volumeAccuracy_uL : Volume_uL = 1.0;
        port reagentIn : ReagentInPort;
        port reagentOut : MeteredReagentOutPort;
        perform action meterReagent : MeterReagentAction;
    }

    part def MicrofluidicNetwork {
        attribute nominalChannelWidth_um : Real = 80.0;
        attribute nominalChannelDepth_um : Real = 40.0;
        attribute deadVolume_uL : Volume_uL = 0.8;
        port sampleIn : MeteredSampleInPort;
        port reagentIn : MeteredReagentInPort;
        port mixtureOut : MixtureOutPort;
        port control : ControlBusPort;
        perform action mixFluids : MixFluidsAction;
    }

    part def IncubationChamber {
        attribute chamberVolume_uL : Volume_uL = 75.0;
        attribute targetTemperature_degC : Temperature_degC = 37.0;
        attribute temperatureTolerance_degC : Temperature_degC = 0.5;
        attribute nominalIncubationTime_s : Time_s = 300.0;
        port mixtureIn : MixtureInPort;
        port preparedOut : PreparedMixtureOutPort;
        port thermalIn : HeatInPort;
        port control : ControlBusPort;
        port power : PowerInPort;
        perform action incubateMixture : IncubateMixtureAction;
    }

    part def ThermalController {
        attribute minimumTemperature_degC : Temperature_degC = 20.0;
        attribute maximumTemperature_degC : Temperature_degC = 60.0;
        attribute controlPeriod_s : Time_s = 0.25;
        port thermalOut : HeatOutPort;
        port control : ControlBusPort;
        port power : PowerInPort;
    }

    part def OpticalEmitter {
        attribute excitationWavelength_nm : Real = 525.0;
        attribute opticalPower_mW : Power_mW = 8.0;
        port signalOut : OpticalSignalOutPort;
        port control : ControlBusPort;
        port power : PowerInPort;
    }

    part def PhotodetectorArray {
        attribute detectorCount : Count = 16;
        attribute samplingRate_Hz : SampleRate_Hz = 100.0;
        attribute darkCurrent : Real = 0.02;
        port opticalIn : OpticalSignalInPort;
        port rawDataOut : RawDataOutPort;
        port control : ControlBusPort;
        port power : PowerInPort;
    }

    part def SensingArray {
        attribute analyteName : String = "C-reactive protein";
        attribute limitOfDetection_ng_per_mL : Concentration_ng_per_mL = 0.5;
        attribute dynamicRangeUpper_ng_per_mL : Concentration_ng_per_mL = 200.0;
        part emitter : OpticalEmitter;
        part detectors : PhotodetectorArray;
        port assayIn : PreparedMixtureInPort;
        port wasteOut : WasteOutPort;
        port rawDataOut : RawDataOutPort;
        port control : ControlBusPort;
        port power : PowerInPort;
        connection opticalPath : OpticalSignalTransfer connect emitter.signalOut to detectors.opticalIn;
        connection detectorData connect detectors.rawDataOut to rawDataOut;
        perform action senseAnalyte : SenseAnalyteAction;
    }

    part def DataProcessor {
        attribute processorClock_MHz : Real = 80.0;
        attribute resultLatency_s : Time_s = 5.0;
        attribute storedCalibrationCount : Count = 8;
        port rawDataIn : RawDataInPort;
        port resultOut : ResultOutPort;
        port control : ControlBusPort;
        port power : PowerInPort;
        perform action processResult : ProcessResultAction;
    }

    part def AssayController {
        attribute controllerStatus : AssayStatus = AssayStatus::idle;
        attribute watchdogTimeout_s : Time_s = 30.0;
        port commandIn : CommandInPort;
        port controlBus : ControlBusPort;
        port power : PowerInPort;
        exhibit state operationalStates : AssayControllerStates;
        perform action executeAssay : ExecuteLabOnChipAssayAction;
    }

    part def PowerManagementUnit {
        attribute inputVoltage_V : Voltage_V = 5.0;
        attribute maximumPower_mW : Power_mW = 2500.0;
        attribute regulatedLogicVoltage_V : Voltage_V = 3.3;
        attribute regulatedActuatorVoltage_V : Voltage_V = 5.0;
        port powerIn : PowerInPort;
        port controllerPower : PowerOutPort;
        port pumpPower : PowerOutPort;
        port thermalPower : PowerOutPort;
        port sensingPower : PowerOutPort;
        port processorPower : PowerOutPort;
    }

    part def LabOnChipAnalyzer {
        doc /* Primary high-level function: automatically transform a microliter-scale biological sample into a quantified analyte concentration result by metering, mixing, incubating, sensing, processing, and reporting within an integrated microfluidic chip system. */

        attribute primaryFunction : String = "Automated microscale sample-to-answer biochemical assay";
        attribute nominalSampleVolume_uL : Volume_uL = 20.0;
        attribute nominalReagentVolume_uL : Volume_uL = 40.0;
        attribute nominalTotalAssayVolume_uL : Volume_uL = 60.0;
        attribute assayCycleTime_s : Time_s = 600.0;
        attribute nominalOperatingTemperature_degC : Temperature_degC = 37.0;
        attribute maximumInputPower_mW : Power_mW = 2500.0;
        attribute reportConfidenceThreshold : Fraction_0_to_1 = 0.95;

        port sampleLoadingPort : SampleLoadPort;
        port reagentLoadingPort : ReagentLoadPort;
        port commandInputPort : CommandInPort;
        port resultOutputPort : ResultOutPort;
        port wasteDrainPort : WasteOutPort;
        port powerInputPort : PowerInPort;

        part sampleReservoir : SampleReservoir;
        part reagentReservoir : ReagentReservoir;
        part wasteReservoir : WasteReservoir;
        part samplePump : SampleMeteringPump;
        part reagentPump : ReagentMeteringPump;
        part microfluidicNetwork : MicrofluidicNetwork;
        part incubationChamber : IncubationChamber;
        part thermalController : ThermalController;
        part sensingArray : SensingArray;
        part dataProcessor : DataProcessor;
        part assayController : AssayController;
        part powerManagement : PowerManagementUnit;

        connection externalSampleLoad connect sampleLoadingPort to sampleReservoir.loadPort;
        connection externalReagentLoad connect reagentLoadingPort to reagentReservoir.loadPort;
        connection commandLink connect commandInputPort to assayController.commandIn;
        connection externalPower connect powerInputPort to powerManagement.powerIn;

        connection sampleFeed : SampleTransfer connect sampleReservoir.outlet to samplePump.sampleIn;
        connection meteredSampleFeed : MeteredSampleTransfer connect samplePump.sampleOut to microfluidicNetwork.sampleIn;
        connection reagentFeed : ReagentTransfer connect reagentReservoir.outlet to reagentPump.reagentIn;
        connection meteredReagentFeed : MeteredReagentTransfer connect reagentPump.reagentOut to microfluidicNetwork.reagentIn;
        connection mixedFluidFeed : MixtureTransfer connect microfluidicNetwork.mixtureOut to incubationChamber.mixtureIn;
        connection preparedAssayFeed : PreparedMixtureTransfer connect incubationChamber.preparedOut to sensingArray.assayIn;
        connection wasteCollection : WasteTransfer connect sensingArray.wasteOut to wasteReservoir.inlet;
        connection externalWasteDrain connect sensingArray.wasteOut to wasteDrainPort;
        connection sensingData : RawDataTransfer connect sensingArray.rawDataOut to dataProcessor.rawDataIn;
        connection reportLink connect dataProcessor.resultOut to resultOutputPort;

        connection controllerToSampleReservoir connect assayController.controlBus to sampleReservoir.control;
        connection controllerToReagentReservoir connect assayController.controlBus to reagentReservoir.control;
        connection controllerToWasteReservoir connect assayController.controlBus to wasteReservoir.control;
        connection controllerToSamplePump connect assayController.controlBus to samplePump.control;
        connection controllerToReagentPump connect assayController.controlBus to reagentPump.control;
        connection controllerToNetwork connect assayController.controlBus to microfluidicNetwork.control;
        connection controllerToIncubator connect assayController.controlBus to incubationChamber.control;
        connection controllerToThermal connect assayController.controlBus to thermalController.control;
        connection controllerToSensor connect assayController.controlBus to sensingArray.control;
        connection controllerToProcessor connect assayController.controlBus to dataProcessor.control;

        connection thermalLink : HeatTransfer connect thermalController.thermalOut to incubationChamber.thermalIn;

        connection controllerPower : PowerTransfer connect powerManagement.controllerPower to assayController.power;
        connection samplePumpPower : PowerTransfer connect powerManagement.pumpPower to samplePump.power;
        connection reagentPumpPower : PowerTransfer connect powerManagement.pumpPower to reagentPump.power;
        connection incubatorPower : PowerTransfer connect powerManagement.thermalPower to incubationChamber.power;
        connection thermalControllerPower : PowerTransfer connect powerManagement.thermalPower to thermalController.power;
        connection sensorPower : PowerTransfer connect powerManagement.sensingPower to sensingArray.power;
        connection processorPower : PowerTransfer connect powerManagement.processorPower to dataProcessor.power;

        perform action primaryAssayBehavior : ExecuteLabOnChipAssayAction;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The lab-on-a-chip analyzer shall accept a microliter-scale patient sample and autonomously produce a quantified analyte concentration result through integrated sample handling, reagent mixing, incubation, sensing, data processing, and reporting. */
        subject analyzer : LabOnChipAnalyzer;
        require constraint nominalSampleVolumeLimit {
            analyzer.nominalSampleVolume_uL <= 50.0
        }
        require constraint assayTimeLimit {
            analyzer.assayCycleTime_s <= 900.0
        }
        require constraint confidenceThreshold {
            analyzer.reportConfidenceThreshold >= 0.95
        }
    }

    requirement def MicrofluidicMeteringRequirement {
        doc /* The fluidic subsystem shall meter sample and reagent volumes with microliter-scale control to support repeatable assays. */
        subject analyzer : LabOnChipAnalyzer;
        require constraint sampleMeterAccuracy {
            analyzer.samplePump.volumeAccuracy_uL <= 1.0
        }
        require constraint reagentMeterAccuracy {
            analyzer.reagentPump.volumeAccuracy_uL <= 2.0
        }
    }

    requirement def IncubationControlRequirement {
        doc /* The incubation chamber shall maintain biochemical reaction temperature near the required assay temperature. */
        subject analyzer : LabOnChipAnalyzer;
        require constraint incubationTemperature {
            analyzer.incubationChamber.targetTemperature_degC == 37.0
        }
        require constraint incubationTolerance {
            analyzer.incubationChamber.temperatureTolerance_degC <= 0.5
        }
    }

    requirement def ResultSensitivityRequirement {
        doc /* The sensing and processing subsystem shall support detection of the selected analyte at clinically relevant concentrations. */
        subject analyzer : LabOnChipAnalyzer;
        require constraint detectionLimit {
            analyzer.sensingArray.limitOfDetection_ng_per_mL <= 1.0
        }
        require constraint resultLatency {
            analyzer.dataProcessor.resultLatency_s <= 10.0
        }
    }

    part labOnChipAnalyzer : LabOnChipAnalyzer;

    requirement primaryFunctionSatisfied : PrimaryFunctionRequirement {
        subject analyzer = labOnChipAnalyzer;
    }

    requirement meteringSatisfied : MicrofluidicMeteringRequirement {
        subject analyzer = labOnChipAnalyzer;
    }

    requirement incubationSatisfied : IncubationControlRequirement {
        subject analyzer = labOnChipAnalyzer;
    }

    requirement sensitivitySatisfied : ResultSensitivityRequirement {
        subject analyzer = labOnChipAnalyzer;
    }
}
