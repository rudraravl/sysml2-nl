package FlowInjectionAnalysisModel {
    public import ScalarValues::*;

    attribute def Volume_mL :> Real {
        doc /* Unit: milliliter. */
    }

    attribute def Volume_uL :> Real {
        doc /* Unit: microliter. */
    }

    attribute def FlowRate_mL_per_min :> Real {
        doc /* Unit: milliliter per minute. */
    }

    attribute def Time_s :> Real {
        doc /* Unit: second. */
    }

    attribute def Temperature_degC :> Real {
        doc /* Unit: degree Celsius. */
    }

    attribute def Pressure_kPa :> Real {
        doc /* Unit: kilopascal. */
    }

    attribute def Concentration_mg_per_L :> Real {
        doc /* Unit: milligram per liter. */
    }

    attribute def Absorbance_AU :> Real {
        doc /* Unit: absorbance unit. */
    }

    attribute def Wavelength_nm :> Real {
        doc /* Unit: nanometer. */
    }

    attribute def ElectricalPower_W :> Real {
        doc /* Unit: watt. */
    }

    attribute def Voltage_V :> Real {
        doc /* Unit: volt. */
    }

    attribute def Percent :> Real {
        doc /* Unit: percent. */
    }

    enum def FluidKind {
        enum carrier;
        enum sample;
        enum reagent;
        enum mixedReactionStream;
        enum waste;
        enum rinseSolution;
    }

    enum def CommandKind {
        enum startAssay;
        enum stopAssay;
        enum primeFluidics;
        enum loadSampleLoop;
        enum injectSamplePlug;
        enum rinsePath;
        enum calibrateDetector;
        enum acknowledgeFault;
    }

    enum def ValvePositionKind {
        enum load;
        enum inject;
        enum rinse;
        enum bypass;
    }

    enum def DetectorModeKind {
        enum off;
        enum warmup;
        enum baseline;
        enum measurePeak;
        enum standby;
        enum fault;
    }

    enum def AlarmKind {
        enum none;
        enum lowCarrier;
        enum lowReagent;
        enum highPressure;
        enum detectorSaturation;
        enum leakDetected;
        enum sampleNotLoaded;
    }

    item def Fluid {
        attribute kind: FluidKind;
        attribute volume_mL: Volume_mL;
        attribute temperature_degC: Temperature_degC;
    }

    item def CarrierFluid :> Fluid {
        attribute pH: Real;
        attribute ionicStrength_mmol_per_L: Real;
    }

    item def SampleFluid :> Fluid {
        attribute sampleIdentifier: String;
        attribute expectedAnalyteConcentration_mg_per_L: Concentration_mg_per_L;
    }

    item def ReagentFluid :> Fluid {
        attribute reagentName: String;
        attribute reagentConcentration_mg_per_L: Concentration_mg_per_L;
    }

    item def ReactionStream :> Fluid {
        attribute residenceTime_s: Time_s;
        attribute analyteConcentration_mg_per_L: Concentration_mg_per_L;
        attribute colorDevelopment_percent: Percent;
    }

    item def WasteFluid :> Fluid {
        attribute disposalVolume_mL: Volume_mL;
    }

    item def ControlCommand {
        attribute command: CommandKind;
        attribute requestedAt_s: Time_s;
    }

    item def ValveCommand :> ControlCommand {
        attribute targetPosition: ValvePositionKind;
    }

    item def PumpCommand :> ControlCommand {
        attribute targetFlowRate_mL_per_min: FlowRate_mL_per_min;
    }

    item def DetectorCommand :> ControlCommand {
        attribute targetMode: DetectorModeKind;
        attribute wavelength_nm: Wavelength_nm;
    }

    item def DetectorSignal {
        attribute absorbance_AU: Absorbance_AU;
        attribute wavelength_nm: Wavelength_nm;
        attribute timeFromInjection_s: Time_s;
        attribute saturated: Boolean;
    }

    item def AnalysisReport {
        attribute sampleIdentifier: String;
        attribute peakHeight_AU: Absorbance_AU;
        attribute calculatedAnalyteConcentration_mg_per_L: Concentration_mg_per_L;
        attribute analysisCycleTime_s: Time_s;
        attribute validResult: Boolean;
        attribute alarm: AlarmKind;
    }

    port def FluidInputPort {
        in item fluid: Fluid;
    }

    port def FluidOutputPort {
        out item fluid: Fluid;
    }

    port def CommandInputPort {
        in item command: ControlCommand;
    }

    port def CommandOutputPort {
        out item command: ControlCommand;
    }

    port def SignalInputPort {
        in item signal: DetectorSignal;
    }

    port def SignalOutputPort {
        out item signal: DetectorSignal;
    }

    port def ReportOutputPort {
        out item report: AnalysisReport;
    }

    part def Reservoir {
        attribute containedFluidKind: FluidKind;
        attribute capacity_mL: Volume_mL;
        attribute minimumUsableVolume_mL: Volume_mL;
        attribute currentVolume_mL: Volume_mL;
        port outlet: FluidOutputPort;
    }

    part def WasteContainer {
        attribute capacity_mL: Volume_mL;
        attribute currentWasteVolume_mL: Volume_mL;
        port inlet: FluidInputPort;
    }

    part def MeteringPump {
        attribute minimumFlowRate_mL_per_min: FlowRate_mL_per_min;
        attribute maximumFlowRate_mL_per_min: FlowRate_mL_per_min;
        attribute commandedFlowRate_mL_per_min: FlowRate_mL_per_min;
        attribute dischargePressure_kPa: Pressure_kPa;
        attribute flowStability_percent: Percent;
        port inlet: FluidInputPort;
        port outlet: FluidOutputPort;
        port commandIn: CommandInputPort;
    }

    part def InjectionValve {
        attribute sampleLoopVolume_uL: Volume_uL;
        attribute position: ValvePositionKind;
        attribute switchingTime_s: Time_s;
        port carrierInlet: FluidInputPort;
        port sampleInlet: FluidInputPort;
        port rinseInlet: FluidInputPort;
        port outlet: FluidOutputPort;
        port commandIn: CommandInputPort;
    }

    part def MixingTee {
        attribute internalVolume_uL: Volume_uL;
        port carrierSampleInlet: FluidInputPort;
        port reagentInlet: FluidInputPort;
        port outlet: FluidOutputPort;
    }

    part def ReactionCoil {
        attribute internalVolume_uL: Volume_uL;
        attribute coilLength_cm: Real;
        attribute residenceTime_s: Time_s;
        attribute controlledTemperature_degC: Temperature_degC;
        port inlet: FluidInputPort;
        port outlet: FluidOutputPort;
    }

    part def OpticalFlowCellDetector {
        attribute wavelength_nm: Wavelength_nm;
        attribute pathLength_mm: Real;
        attribute baselineAbsorbance_AU: Absorbance_AU;
        attribute maximumLinearAbsorbance_AU: Absorbance_AU;
        attribute mode: DetectorModeKind;
        port inlet: FluidInputPort;
        port outlet: FluidOutputPort;
        port commandIn: CommandInputPort;
        port signalOut: SignalOutputPort;
    }

    part def EmbeddedController {
        attribute supplyVoltage_V: Voltage_V;
        attribute maximumPower_W: ElectricalPower_W;
        attribute assaySequenceEnabled: Boolean;
        attribute activeAlarm: AlarmKind;
        port pumpCommandOut: CommandOutputPort;
        port valveCommandOut: CommandOutputPort;
        port detectorCommandOut: CommandOutputPort;
        port detectorSignalIn: SignalInputPort;
        port reportOut: ReportOutputPort;
    }

    action def PrimeFluidicPath {
        in item carrier: CarrierFluid;
        in item reagent: ReagentFluid;
        out item primedCarrier: CarrierFluid;
        out item primedReagent: ReagentFluid;
        attribute duration_s: Time_s = 60.0;
        attribute carrierPrimeFlow_mL_per_min: FlowRate_mL_per_min = 1.50;
        attribute reagentPrimeFlow_mL_per_min: FlowRate_mL_per_min = 0.30;
    }

    action def LoadInjectionLoop {
        in item sample: SampleFluid;
        out item loadedSamplePlug: SampleFluid;
        attribute loopVolume_uL: Volume_uL = 100.0;
        attribute loadingTime_s: Time_s = 8.0;
        attribute samplePumpFlow_mL_per_min: FlowRate_mL_per_min = 0.75;
    }

    action def InjectSamplePlug {
        in item loadedSamplePlug: SampleFluid;
        in item carrier: CarrierFluid;
        out item segmentedCarrierStream: ReactionStream;
        attribute injectionTime_s: Time_s = 1.0;
        attribute carrierFlow_mL_per_min: FlowRate_mL_per_min = 1.20;
    }

    action def MixWithReagent {
        in item segmentedCarrierStream: ReactionStream;
        in item reagent: ReagentFluid;
        out item mixedReactionStream: ReactionStream;
        attribute reagentFlow_mL_per_min: FlowRate_mL_per_min = 0.25;
        attribute mixingVolume_uL: Volume_uL = 35.0;
    }

    action def DevelopReaction {
        in item mixedReactionStream: ReactionStream;
        out item developedReactionStream: ReactionStream;
        attribute residenceTime_s: Time_s = 24.0;
        attribute reactionTemperature_degC: Temperature_degC = 37.0;
    }

    action def MeasureDetectorResponse {
        in item developedReactionStream: ReactionStream;
        out item detectorSignal: DetectorSignal;
        attribute wavelength_nm: Wavelength_nm = 540.0;
        attribute samplingInterval_s: Time_s = 0.20;
    }

    action def ComputeAnalyteConcentration {
        in item detectorSignal: DetectorSignal;
        out item report: AnalysisReport;
        attribute calibrationSlope_mg_per_L_per_AU: Real = 25.0;
        attribute calibrationIntercept_mg_per_L: Concentration_mg_per_L = 0.0;
    }

    action def RinseFluidicPath {
        in item rinseSolution: Fluid;
        out item waste: WasteFluid;
        attribute rinseDuration_s: Time_s = 30.0;
        attribute rinseFlowRate_mL_per_min: FlowRate_mL_per_min = 1.50;
    }

    action def RunFlowInjectionAssay {
        in item rawSample: SampleFluid;
        in item carrier: CarrierFluid;
        in item reagent: ReagentFluid;
        in item rinseSolution: Fluid;
        out item analysisReport: AnalysisReport;

        action prime: PrimeFluidicPath;
        action load: LoadInjectionLoop;
        action inject: InjectSamplePlug;
        action mix: MixWithReagent;
        action react: DevelopReaction;
        action measure: MeasureDetectorResponse;
        action compute: ComputeAnalyteConcentration;
        action rinse: RinseFluidicPath;

        succession s1 first prime then load;
        succession s2 first load then inject;
        succession s3 first inject then mix;
        succession s4 first mix then react;
        succession s5 first react then measure;
        succession s6 first measure then compute;
        succession s7 first compute then rinse;
    }

    state def AnalyzerOperatingStateMachine {
        state off;
        state standby;
        state priming;
        state loadingSample;
        state injecting;
        state reacting;
        state detecting;
        state computingResult;
        state rinsing;
        state fault;

        transition t0 first off then standby;
        transition t1 first standby then priming;
        transition t2 first priming then loadingSample;
        transition t3 first loadingSample then injecting;
        transition t4 first injecting then reacting;
        transition t5 first reacting then detecting;
        transition t6 first detecting then computingResult;
        transition t7 first computingResult then rinsing;
        transition t8 first rinsing then standby;
        transition f1 first priming then fault;
        transition f2 first loadingSample then fault;
        transition f3 first injecting then fault;
        transition f4 first detecting then fault;
        transition r1 first fault then standby;
    }

    part def FlowInjectionAnalysisSystem {
        doc /* Primary high-level function: automatically introduce a metered liquid sample plug into a continuous carrier stream, add reagent, allow a controlled reaction, measure the detector response, and report analyte concentration. */

        attribute canInjectSample: Boolean = true;
        attribute canMixWithReagent: Boolean = true;
        attribute canMeasureDetectorResponse: Boolean = true;
        attribute canReportAnalyteConcentration: Boolean = true;
        attribute nominalCarrierFlowRate_mL_per_min: FlowRate_mL_per_min = 1.20;
        attribute nominalReagentFlowRate_mL_per_min: FlowRate_mL_per_min = 0.25;
        attribute nominalSampleLoopVolume_uL: Volume_uL = 100.0;
        attribute nominalCycleTime_s: Time_s = 95.0;
        attribute maximumCycleTime_s: Time_s = 120.0;
        attribute maximumOperatingPressure_kPa: Pressure_kPa = 450.0;
        attribute detectorWavelength_nm: Wavelength_nm = 540.0;

        port reportOut: ReportOutputPort;

        part carrierReservoir: Reservoir {
            :>> containedFluidKind = FluidKind::carrier;
            :>> capacity_mL = 1000.0;
            :>> minimumUsableVolume_mL = 50.0;
            :>> currentVolume_mL = 800.0;
        }

        part sampleReservoir: Reservoir {
            :>> containedFluidKind = FluidKind::sample;
            :>> capacity_mL = 50.0;
            :>> minimumUsableVolume_mL = 1.0;
            :>> currentVolume_mL = 10.0;
        }

        part reagentReservoir: Reservoir {
            :>> containedFluidKind = FluidKind::reagent;
            :>> capacity_mL = 500.0;
            :>> minimumUsableVolume_mL = 25.0;
            :>> currentVolume_mL = 350.0;
        }

        part rinseReservoir: Reservoir {
            :>> containedFluidKind = FluidKind::rinseSolution;
            :>> capacity_mL = 500.0;
            :>> minimumUsableVolume_mL = 25.0;
            :>> currentVolume_mL = 400.0;
        }

        part wasteContainer: WasteContainer {
            :>> capacity_mL = 1500.0;
            :>> currentWasteVolume_mL = 0.0;
        }

        part carrierPump: MeteringPump {
            :>> minimumFlowRate_mL_per_min = 0.10;
            :>> maximumFlowRate_mL_per_min = 3.00;
            :>> commandedFlowRate_mL_per_min = 1.20;
            :>> dischargePressure_kPa = 180.0;
            :>> flowStability_percent = 1.0;
        }

        part samplePump: MeteringPump {
            :>> minimumFlowRate_mL_per_min = 0.05;
            :>> maximumFlowRate_mL_per_min = 2.00;
            :>> commandedFlowRate_mL_per_min = 0.75;
            :>> dischargePressure_kPa = 120.0;
            :>> flowStability_percent = 2.0;
        }

        part reagentPump: MeteringPump {
            :>> minimumFlowRate_mL_per_min = 0.05;
            :>> maximumFlowRate_mL_per_min = 1.00;
            :>> commandedFlowRate_mL_per_min = 0.25;
            :>> dischargePressure_kPa = 140.0;
            :>> flowStability_percent = 1.5;
        }

        part injectionValve: InjectionValve {
            :>> sampleLoopVolume_uL = 100.0;
            :>> position = ValvePositionKind::load;
            :>> switchingTime_s = 0.50;
        }

        part mixer: MixingTee {
            :>> internalVolume_uL = 35.0;
        }

        part reactionCoil: ReactionCoil {
            :>> internalVolume_uL = 580.0;
            :>> coilLength_cm = 250.0;
            :>> residenceTime_s = 24.0;
            :>> controlledTemperature_degC = 37.0;
        }

        part detector: OpticalFlowCellDetector {
            :>> wavelength_nm = 540.0;
            :>> pathLength_mm = 10.0;
            :>> baselineAbsorbance_AU = 0.000;
            :>> maximumLinearAbsorbance_AU = 1.500;
            :>> mode = DetectorModeKind::standby;
        }

        part controller: EmbeddedController {
            :>> supplyVoltage_V = 24.0;
            :>> maximumPower_W = 60.0;
            :>> assaySequenceEnabled = true;
            :>> activeAlarm = AlarmKind::none;
            perform action assayCycle: RunFlowInjectionAssay;
            exhibit state operatingState: AnalyzerOperatingStateMachine;
        }

        connection carrierToCarrierPump connect carrierReservoir.outlet to carrierPump.inlet;
        connection carrierPumpToValve connect carrierPump.outlet to injectionValve.carrierInlet;
        connection sampleToSamplePump connect sampleReservoir.outlet to samplePump.inlet;
        connection samplePumpToValve connect samplePump.outlet to injectionValve.sampleInlet;
        connection rinseToValve connect rinseReservoir.outlet to injectionValve.rinseInlet;
        connection valveToMixer connect injectionValve.outlet to mixer.carrierSampleInlet;
        connection reagentToReagentPump connect reagentReservoir.outlet to reagentPump.inlet;
        connection reagentPumpToMixer connect reagentPump.outlet to mixer.reagentInlet;
        connection mixerToReactionCoil connect mixer.outlet to reactionCoil.inlet;
        connection reactionCoilToDetector connect reactionCoil.outlet to detector.inlet;
        connection detectorToWaste connect detector.outlet to wasteContainer.inlet;

        connection controllerToCarrierPump connect controller.pumpCommandOut to carrierPump.commandIn;
        connection controllerToSamplePump connect controller.pumpCommandOut to samplePump.commandIn;
        connection controllerToReagentPump connect controller.pumpCommandOut to reagentPump.commandIn;
        connection controllerToValve connect controller.valveCommandOut to injectionValve.commandIn;
        connection controllerToDetector connect controller.detectorCommandOut to detector.commandIn;
        connection detectorSignalToController connect detector.signalOut to controller.detectorSignalIn;
        connection controllerReportToSystemReport connect controller.reportOut to reportOut;
    }

    constraint def CarrierFlowRangeConstraint {
        in flowRate_mL_per_min: FlowRate_mL_per_min;
        constraint validCarrierFlow {
            flowRate_mL_per_min >= 0.50 and flowRate_mL_per_min <= 2.00
        }
    }

    constraint def CycleTimeConstraint {
        in cycleTime_s: Time_s;
        in limit_s: Time_s;
        constraint withinLimit {
            cycleTime_s <= limit_s
        }
    }

    constraint def DetectorLinearRangeConstraint {
        in peakAbsorbance_AU: Absorbance_AU;
        constraint withinLinearRange {
            peakAbsorbance_AU >= 0.000 and peakAbsorbance_AU <= 1.500
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The analyzer shall perform flow injection analysis by injecting a metered sample into a flowing carrier, mixing with reagent, detecting the reaction product, and producing an analyte concentration report. */
        subject analyzer: FlowInjectionAnalysisSystem;

        require constraint supportsPrimaryFunction {
            analyzer.canInjectSample == true and
            analyzer.canMixWithReagent == true and
            analyzer.canMeasureDetectorResponse == true and
            analyzer.canReportAnalyteConcentration == true
        }
    }

    requirement def FlowControlRequirement {
        doc /* The carrier stream shall operate within the normal flow injection analysis range. */
        subject analyzer: FlowInjectionAnalysisSystem;

        require constraint carrierFlowIsInRange {
            analyzer.nominalCarrierFlowRate_mL_per_min >= 0.50 and
            analyzer.nominalCarrierFlowRate_mL_per_min <= 2.00
        }
    }

    requirement def SampleMeteringRequirement {
        doc /* The injected sample plug shall be metered by a defined injection loop volume. */
        subject analyzer: FlowInjectionAnalysisSystem;

        require constraint sampleLoopVolumeIsDefined {
            analyzer.nominalSampleLoopVolume_uL >= 50.0 and
            analyzer.nominalSampleLoopVolume_uL <= 250.0
        }
    }

    requirement def AssayCycleTimeRequirement {
        doc /* One automated analysis cycle shall complete within the allowed cycle time. */
        subject analyzer: FlowInjectionAnalysisSystem;

        require constraint cycleTimeWithinLimit {
            analyzer.nominalCycleTime_s <= analyzer.maximumCycleTime_s
        }
    }

    requirement def OperatingPressureRequirement {
        doc /* Fluidic components shall operate below the specified maximum pressure. */
        subject analyzer: FlowInjectionAnalysisSystem;

        require constraint pressureLimitDefined {
            analyzer.maximumOperatingPressure_kPa <= 500.0
        }
    }

    part fiaAnalyzer: FlowInjectionAnalysisSystem;

    requirement primaryFunction: PrimaryFunctionRequirement {
        subject analyzer = fiaAnalyzer;
    }

    requirement flowControl: FlowControlRequirement {
        subject analyzer = fiaAnalyzer;
    }

    requirement sampleMetering: SampleMeteringRequirement {
        subject analyzer = fiaAnalyzer;
    }

    requirement assayCycleTime: AssayCycleTimeRequirement {
        subject analyzer = fiaAnalyzer;
    }

    requirement operatingPressure: OperatingPressureRequirement {
        subject analyzer = fiaAnalyzer;
    }
}
