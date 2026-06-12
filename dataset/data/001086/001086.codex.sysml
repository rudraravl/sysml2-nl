package HydrocarbonDewPointSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Temperature {
        :> scalar;
        unit = "degC";
    }

    attribute def Pressure {
        :> scalar;
        unit = "bar";
    }

    attribute def MolarFraction {
        :> scalar;
        unit = "mol/mol";
    }

    attribute def FlowRate {
        :> scalar;
        unit = "Sm3/h";
    }

    attribute def TimeDuration {
        :> scalar;
        unit = "s";
    }

    attribute def Power {
        :> scalar;
        unit = "W";
    }

    item def NaturalGasSample {
        attribute samplePressure : Pressure;
        attribute sampleTemperature : Temperature;
        attribute flowRate : FlowRate;
        attribute methane : MolarFraction;
        attribute ethane : MolarFraction;
        attribute propane : MolarFraction;
        attribute butanes : MolarFraction;
        attribute pentanesPlus : MolarFraction;
        attribute carbonDioxide : MolarFraction;
        attribute nitrogen : MolarFraction;
        attribute waterVapor : MolarFraction;
    }

    item def ConditionedGasSample :> NaturalGasSample {
        attribute filtrationRating : Real;
        attribute pressureRegulated : Boolean;
        attribute liquidFree : Boolean;
    }

    item def DewPointMeasurement {
        attribute measuredDewPoint : Temperature;
        attribute measurementPressure : Pressure;
        attribute confidence : Real;
        attribute timestamp : TimeDuration;
        attribute valid : Boolean;
    }

    item def ControlCommand {
        attribute targetMirrorTemperature : Temperature;
        attribute targetPressure : Pressure;
        attribute sampleValveOpen : Boolean;
        attribute purgeValveOpen : Boolean;
        attribute alarmReset : Boolean;
    }

    item def AlarmSignal {
        attribute active : Boolean;
        attribute severity : Integer;
        attribute messageCode : Integer;
    }

    port def GasInletPort {
        in item gasIn : NaturalGasSample;
    }

    port def GasOutletPort {
        out item gasOut : NaturalGasSample;
    }

    port def ConditionedGasPort {
        out item conditionedGas : ConditionedGasSample;
    }

    port def MeasurementPort {
        out item measurement : DewPointMeasurement;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def AlarmPort {
        out item alarm : AlarmSignal;
    }

    port def ElectricPowerPort {
        in attribute voltage : Real;
        in attribute current : Real;
    }

    part def HydrocarbonDewPointAnalyzer {
        attribute operatingPressureMin : Pressure = 1.0 [bar];
        attribute operatingPressureMax : Pressure = 100.0 [bar];
        attribute dewPointRangeLow : Temperature = -40.0 [degC];
        attribute dewPointRangeHigh : Temperature = 40.0 [degC];
        attribute sampleFlowNominal : FlowRate = 30.0 [Sm3/h];
        attribute measurementCycleTime : TimeDuration = 300.0 [s];
        attribute ratedPower : Power = 250.0 [W];

        port gasInlet : GasInletPort;
        port gasOutlet : GasOutletPort;
        port measurementOut : MeasurementPort;
        port commandIn : CommandPort;
        port alarmOut : AlarmPort;
        port powerIn : ElectricPowerPort;

        part samplingProbe : SamplingProbe;
        part pressureRegulator : PressureRegulator;
        part particulateFilter : ParticulateFilter;
        part flowController : SampleFlowController;
        part chilledMirrorCell : ChilledMirrorCell;
        part opticalDetector : OpticalCondensateDetector;
        part temperatureController : MirrorTemperatureController;
        part processor : DewPointProcessor;
        part purgeAssembly : PurgeAssembly;
        part operatorInterface : OperatorInterface;

        connect gasInlet.gasIn to samplingProbe.processGas;
        connect samplingProbe.sampleOut to pressureRegulator.sampleIn;
        connect pressureRegulator.regulatedSampleOut to particulateFilter.unfilteredSampleIn;
        connect particulateFilter.filteredSampleOut to flowController.sampleIn;
        connect flowController.controlledSampleOut to chilledMirrorCell.sampleIn;
        connect chilledMirrorCell.sampleOut to purgeAssembly.sampleIn;
        connect purgeAssembly.exhaustOut to gasOutlet.gasOut;

        connect chilledMirrorCell.mirrorTemperatureOut to temperatureController.measuredMirrorTemperature;
        connect temperatureController.coolingCommandOut to chilledMirrorCell.coolingCommandIn;
        connect opticalDetector.condensateSignalOut to processor.condensateSignalIn;
        connect chilledMirrorCell.mirrorTemperatureOut to processor.mirrorTemperatureIn;
        connect pressureRegulator.pressureOut to processor.samplePressureIn;
        connect processor.measurementOut to measurementOut.measurement;
        connect processor.alarmOut to alarmOut.alarm;
        connect commandIn.command to processor.externalCommandIn;
        connect processor.purgeCommandOut to purgeAssembly.purgeCommandIn;
        connect processor.temperatureCommandOut to temperatureController.targetTemperatureIn;
    }

    part def SamplingProbe {
        port processGas : GasInletPort;
        port sampleOut : ConditionedGasPort;

        attribute insertionDepth : Real = 0.33;
        attribute heated : Boolean = true;
        attribute probeTemperature : Temperature = 60.0 [degC];

        action drawRepresentativeSample {
            in item processGas : NaturalGasSample;
            out item sample : ConditionedGasSample;

            first start;
            then maintainProbeAboveExpectedDewPoint;
            then extractSlipstream;
            then deliverSample;
        }
    }

    part def PressureRegulator {
        port sampleIn : ConditionedGasPort;
        port regulatedSampleOut : ConditionedGasPort;
        out attribute pressureOut : Pressure;

        attribute setPressure : Pressure = 27.6 [bar];
        attribute stabilityBand : Pressure = 0.2 [bar];

        action regulatePressure {
            in item incoming : ConditionedGasSample;
            out item regulated : ConditionedGasSample;

            first senseIncomingPressure;
            then adjustRestriction;
            then stabilizeOutletPressure;
            then publishRegulatedSample;
        }
    }

    part def ParticulateFilter {
        port unfilteredSampleIn : ConditionedGasPort;
        port filteredSampleOut : ConditionedGasPort;

        attribute filtrationRatingMicron : Real = 2.0;
        attribute liquidTrapCapacity : Real = 25.0;

        action removeParticlesAndFreeLiquids {
            first receiveRegulatedSample;
            then separateEntrainedLiquid;
            then trapParticulates;
            then releaseFilteredSample;
        }
    }

    part def SampleFlowController {
        port sampleIn : ConditionedGasPort;
        port controlledSampleOut : ConditionedGasPort;

        attribute targetFlow : FlowRate = 30.0 [Sm3/h];
        attribute lowFlowAlarmThreshold : FlowRate = 10.0 [Sm3/h];
        attribute highFlowAlarmThreshold : FlowRate = 60.0 [Sm3/h];

        action controlSampleFlow {
            first measureFlow;
            then compareToTarget;
            then positionMeteringValve;
            then outputControlledFlow;
        }
    }

    part def ChilledMirrorCell {
        port sampleIn : ConditionedGasPort;
        port sampleOut : GasOutletPort;

        in attribute coolingCommandIn : Temperature;
        out attribute mirrorTemperatureOut : Temperature;

        attribute mirrorMaterial : String = "stainless steel with polished optical surface";
        attribute mirrorTemperature : Temperature = 20.0 [degC];
        attribute coolingRate : Real = 0.25;
        attribute heatingRate : Real = 0.50;

        state def MirrorCellState {
            state idle;
            state cooling;
            state condensateDetected;
            state warming;
            state stabilized;
            state fault;

            transition idle_to_cooling
                first idle
                then cooling
                accept ControlCommand;

            transition cooling_to_detected
                first cooling
                then condensateDetected
                accept AlarmSignal
                if opticalCondensateDetected == true;

            transition detected_to_warming
                first condensateDetected
                then warming;

            transition warming_to_stabilized
                first warming
                then stabilized
                if mirrorTemperature > lastDetectedDewPoint + 5.0 [degC];

            transition stabilized_to_cooling
                first stabilized
                then cooling;

            transition any_to_fault
                first idle
                then fault
                if mirrorTemperature < -45.0 [degC];
        }

        action exposeMirrorToSample {
            first admitConditionedGas;
            then sweepMirrorSurface;
            then maintainOpticalPath;
            then exhaustSample;
        }
    }

    part def OpticalCondensateDetector {
        out attribute condensateSignalOut : Boolean;

        attribute lightSourceWavelength : Real = 880.0;
        attribute cleanMirrorReflectance : Real = 1.0;
        attribute condensateReflectanceThreshold : Real = 0.82;

        action detectHydrocarbonFilm {
            first illuminateMirror;
            then measureReflectedIntensity;
            then compareAgainstCleanReference;
            then assertCondensateSignal;
        }
    }

    part def MirrorTemperatureController {
        in attribute targetTemperatureIn : Temperature;
        in attribute measuredMirrorTemperature : Temperature;
        out attribute coolingCommandOut : Temperature;

        attribute proportionalGain : Real = 1.8;
        attribute integralGain : Real = 0.04;
        attribute derivativeGain : Real = 0.10;

        action controlMirrorTemperature {
            first readTargetTemperature;
            then readMeasuredTemperature;
            then computeTemperatureError;
            then applyThermoelectricCoolingOrHeating;
            then publishCoolingCommand;
        }
    }

    part def DewPointProcessor {
        in attribute condensateSignalIn : Boolean;
        in attribute mirrorTemperatureIn : Temperature;
        in attribute samplePressureIn : Pressure;
        in item externalCommandIn : ControlCommand;

        out item measurementOut : DewPointMeasurement;
        out item alarmOut : AlarmSignal;
        out attribute purgeCommandOut : Boolean;
        out attribute temperatureCommandOut : Temperature;

        attribute hydrocarbonDewPoint : Temperature;
        attribute measurementPressure : Pressure;
        attribute lastValidMeasurementAge : TimeDuration;
        attribute alarmActive : Boolean = false;
        attribute dewPointAlarmLimit : Temperature = -5.0 [degC];
        attribute maximumAllowedUncertainty : Temperature = 1.0 [degC];

        action calculateHydrocarbonDewPoint {
            first initializeMeasurementCycle;
            then coolMirrorAtControlledRate;
            then monitorCondensateSignal;
            then captureMirrorTemperatureAtFirstCondensation;
            then verifyRepeatability;
            then compensateForSamplePressure;
            then publishDewPointMeasurement;
        }

        action evaluateAlarms {
            first compareDewPointToLimit;
            then checkSamplePressureRange;
            then checkSignalValidity;
            then publishAlarmSignal;
        }

        state def AnalyzerOperatingState {
            state poweredOff;
            state startup;
            state purge;
            state ready;
            state measuring;
            state validating;
            state reporting;
            state maintenanceRequired;
            state faulted;

            transition power_on
                first poweredOff
                then startup;

            transition startup_complete
                first startup
                then purge
                if selfDiagnosticsPassed == true;

            transition purge_complete
                first purge
                then ready
                if purgeDuration >= 60.0 [s];

            transition start_measurement
                first ready
                then measuring
                accept ControlCommand;

            transition condensation_found
                first measuring
                then validating
                if condensateSignalIn == true;

            transition validation_passed
                first validating
                then reporting
                if measurementRepeatability <= 0.5 [degC];

            transition report_complete
                first reporting
                then ready;

            transition validation_failed
                first validating
                then measuring
                if measurementRepeatability > 0.5 [degC];

            transition maintenance_alarm
                first ready
                then maintenanceRequired
                if lastValidMeasurementAge > 86400.0 [s];

            transition critical_fault
                first measuring
                then faulted
                if samplePressureIn > 100.0 [bar];
        }
    }

    part def PurgeAssembly {
        port sampleIn : GasOutletPort;
        port exhaustOut : GasOutletPort;

        in attribute purgeCommandIn : Boolean;

        attribute purgeGasType : String = "dry methane or nitrogen";
        attribute purgeDuration : TimeDuration = 60.0 [s];

        action purgeMeasurementCell {
            first closeSampleValve;
            then openPurgeValve;
            then sweepChilledMirrorCell;
            then closePurgeValve;
            then reopenSampleValve;
        }
    }

    part def OperatorInterface {
        port measurementDisplay : MeasurementPort;
        port commandPanel : CommandPort;
        port alarmDisplay : AlarmPort;

        attribute displayRefreshPeriod : TimeDuration = 1.0 [s];

        action showAnalyzerStatus {
            first readCurrentMeasurement;
            then displayDewPointPressureAndValidity;
            then displayAlarmState;
            then acceptOperatorCommand;
        }
    }

    requirement def HydrocarbonDewPointSystemRequirement {
        subject analyzer : HydrocarbonDewPointAnalyzer;

        require constraint {
            analyzer.dewPointRangeLow <= analyzer.processor.hydrocarbonDewPoint and
            analyzer.processor.hydrocarbonDewPoint <= analyzer.dewPointRangeHigh
        }

        doc /* The system shall determine the hydrocarbon dew point of a pressurized natural gas stream by conditioning a representative sample, cooling an exposed mirror surface, detecting first hydrocarbon condensation, and reporting the temperature at the specified measurement pressure. */
    }

    requirement def PrimaryFunctionRequirement {
        subject analyzer : HydrocarbonDewPointAnalyzer;

        require constraint {
            analyzer.processor.measurementOut.valid == true
        }

        doc /* The primary high-level function of the system is to provide a valid, pressure-referenced hydrocarbon dew point measurement that supports gas quality monitoring, custody transfer decisions, and protection of downstream pipeline equipment from liquid hydrocarbon dropout. */
    }

    requirement def SampleConditioningRequirement {
        subject analyzer : HydrocarbonDewPointAnalyzer;

        require constraint {
            analyzer.flowController.targetFlow >= 10.0 [Sm3/h] and
            analyzer.flowController.targetFlow <= 60.0 [Sm3/h] and
            analyzer.pressureRegulator.setPressure >= 1.0 [bar] and
            analyzer.pressureRegulator.setPressure <= 100.0 [bar]
        }

        doc /* The analyzer shall condition the incoming natural gas sample to a stable pressure, controlled flow rate, and liquid-free state before exposure to the chilled mirror measurement cell. */
    }

    requirement def DetectionAccuracyRequirement {
        subject analyzer : HydrocarbonDewPointAnalyzer;

        require constraint {
            analyzer.processor.maximumAllowedUncertainty <= 1.0 [degC]
        }

        doc /* The analyzer shall report hydrocarbon dew point with measurement uncertainty no greater than one degree Celsius under normal operating conditions. */
    }

    requirement def AlarmRequirement {
        subject analyzer : HydrocarbonDewPointAnalyzer;

        require constraint {
            analyzer.processor.alarmActive == true implies
            analyzer.processor.hydrocarbonDewPoint >= analyzer.processor.dewPointAlarmLimit
        }

        doc /* The analyzer shall generate an alarm when the measured hydrocarbon dew point approaches or exceeds the configured gas quality limit. */
    }

    action def DetermineHydrocarbonDewPoint {
        in item rawGas : NaturalGasSample;
        out item result : DewPointMeasurement;

        first receiveRepresentativeGasSample;
        then regulateSamplePressure;
        then filterAndControlSampleFlow;
        then coolMirrorUntilHydrocarbonCondensation;
        then detectFirstCondensateFilm;
        then recordMirrorTemperatureAndPressure;
        then validateMeasurementRepeatability;
        then reportHydrocarbonDewPoint;
    }

    part hydrocarbonDewPointSystem : HydrocarbonDewPointAnalyzer {
        attribute operatingPressureMin = 1.0 [bar];
        attribute operatingPressureMax = 100.0 [bar];
        attribute dewPointRangeLow = -40.0 [degC];
        attribute dewPointRangeHigh = 40.0 [degC];
        attribute sampleFlowNominal = 30.0 [Sm3/h];
        attribute measurementCycleTime = 300.0 [s];
        attribute ratedPower = 250.0 [W];
    }
}