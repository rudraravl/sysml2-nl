package pHGlassElectrodeSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def pHValue :> ScalarValues::Real {
        doc /* Dimensionless hydrogen ion activity index. */
    }

    attribute def TemperatureC :> ScalarValues::Real {
        unit = "degC";
    }

    attribute def ElectricPotential_mV :> ScalarValues::Real {
        unit = "mV";
    }

    attribute def Resistance_MOhm :> ScalarValues::Real {
        unit = "Mohm";
    }

    attribute def Conductivity_uScm :> ScalarValues::Real {
        unit = "uS/cm";
    }

    attribute def Time_s :> ScalarValues::Real {
        unit = "s";
    }

    attribute def Voltage_V :> ScalarValues::Real {
        unit = "V";
    }

    attribute def Current_mA :> ScalarValues::Real {
        unit = "mA";
    }

    attribute def Confidence :> ScalarValues::Real {
        doc /* Normalized confidence from 0.0 to 1.0. */
    }

    item def SampleSolution {
        attribute hydrogenIonActivity : ScalarValues::Real;
        attribute pH : pHValue;
        attribute temperature : TemperatureC;
        attribute conductivity : Conductivity_uScm;
    }

    item def InternalElectrolyte {
        attribute chlorideActivity : ScalarValues::Real;
        attribute pH : pHValue;
        attribute fillLevelPercent : ScalarValues::Real;
    }

    item def ReferenceJunctionIonFlow {
        attribute flowStable : Boolean;
        attribute junctionPotential : ElectricPotential_mV;
    }

    item def ElectrodePotentialSignal {
        attribute potential : ElectricPotential_mV;
        attribute temperature : TemperatureC;
        attribute sourceImpedance : Resistance_MOhm;
        attribute timestamp : Time_s;
    }

    item def ConditionedVoltageSignal {
        attribute voltage : Voltage_V;
        attribute noiseRms : ElectricPotential_mV;
        attribute timestamp : Time_s;
    }

    item def DigitalPHMeasurement {
        attribute pH : pHValue;
        attribute temperature : TemperatureC;
        attribute slope_mVPerPH : ScalarValues::Real;
        attribute offset_mV : ElectricPotential_mV;
        attribute confidence : Confidence;
        attribute stable : Boolean;
        attribute timestamp : Time_s;
    }

    item def CalibrationBuffer {
        attribute certifiedPH : pHValue;
        attribute temperature : TemperatureC;
        attribute tolerance : pHValue;
    }

    item def UserCommand {
        attribute commandId : String;
        attribute requestedMode : String;
    }

    item def DisplayMessage {
        attribute line1 : String;
        attribute line2 : String;
        attribute alarmActive : Boolean;
    }

    port def SolutionContactPort {
        inout solution : SampleSolution;
    }

    port def IonExchangePort {
        inout solution : SampleSolution;
        out potential : ElectrodePotentialSignal;
    }

    port def ElectrolytePort {
        inout electrolyte : InternalElectrolyte;
    }

    port def ReferenceJunctionPort {
        inout solution : SampleSolution;
        out ionFlow : ReferenceJunctionIonFlow;
        out referencePotential : ElectrodePotentialSignal;
    }

    port def AnalogSignalPort {
        out signal : ElectrodePotentialSignal;
    }

    port def ConditionedSignalPort {
        in rawSignal : ElectrodePotentialSignal;
        out conditionedSignal : ConditionedVoltageSignal;
    }

    port def DigitalMeasurementPort {
        in conditionedSignal : ConditionedVoltageSignal;
        out measurement : DigitalPHMeasurement;
    }

    port def TemperaturePort {
        out temperature : TemperatureC;
    }

    port def PowerPort {
        in supplyVoltage : Voltage_V;
        in supplyCurrent : Current_mA;
    }

    port def UserInterfacePort {
        in command : UserCommand;
        out message : DisplayMessage;
        out measurement : DigitalPHMeasurement;
    }

    part def GlassMembrane {
        attribute hydratedLayerThickness_um : ScalarValues::Real = 0.5;
        attribute membraneResistance : Resistance_MOhm = 250.0;
        attribute alkaliErrorLimitPH : pHValue = 12.0;
        attribute acidErrorLimitPH : pHValue = 1.0;

        port sampleSide : IonExchangePort;
        port internalSide : ElectrolytePort;

        action generateBoundaryPotential {
            in sample : SampleSolution;
            in electrolyte : InternalElectrolyte;
            out potential : ElectrodePotentialSignal;

            doc /* Produces a membrane potential proportional to the difference between sample hydrogen ion activity and fixed internal electrolyte activity. */
        }
    }

    part def InternalReferenceElement {
        attribute material : String = "Ag/AgCl";
        attribute nominalPotential : ElectricPotential_mV = 205.0;
        attribute driftPerDay : ElectricPotential_mV = 0.2;

        port electrolyteInterface : ElectrolytePort;
        port signalOut : AnalogSignalPort;

        action produceStableInternalPotential {
            in electrolyte : InternalElectrolyte;
            out signal : ElectrodePotentialSignal;
        }
    }

    part def ReferenceElectrode {
        attribute referenceMaterial : String = "Ag/AgCl";
        attribute junctionType : String = "porous ceramic";
        attribute junctionResistance : Resistance_MOhm = 5.0;
        attribute maximumJunctionPotential : ElectricPotential_mV = 3.0;

        port sampleJunction : ReferenceJunctionPort;
        port electrolytePort : ElectrolytePort;
        port referenceSignalOut : AnalogSignalPort;

        action maintainReferencePotential {
            in electrolyte : InternalElectrolyte;
            in sample : SampleSolution;
            out referenceSignal : ElectrodePotentialSignal;
            out ionFlow : ReferenceJunctionIonFlow;
        }
    }

    part def ElectrodeBody {
        attribute bodyMaterial : String = "chemically resistant glass";
        attribute maximumImmersionDepth_mm : ScalarValues::Real = 120.0;
        attribute minimumImmersionDepth_mm : ScalarValues::Real = 20.0;

        port sampleContact : SolutionContactPort;

        part membrane : GlassMembrane;
        part internalReference : InternalReferenceElement;
        part referenceElectrode : ReferenceElectrode;

        item internalFill : InternalElectrolyte {
            attribute chlorideActivity = 3.0;
            attribute pH = 7.0;
            attribute fillLevelPercent = 95.0;
        }

        connect sampleContact.solution to membrane.sampleSide.solution;
        connect sampleContact.solution to referenceElectrode.sampleJunction.solution;
        connect internalFill to membrane.internalSide.electrolyte;
        connect internalFill to internalReference.electrolyteInterface.electrolyte;
        connect internalFill to referenceElectrode.electrolytePort.electrolyte;
    }

    part def HighImpedanceAmplifier {
        attribute inputResistance : Resistance_MOhm = 1000000.0;
        attribute inputBiasCurrent_pA : ScalarValues::Real = 0.5;
        attribute gain : ScalarValues::Real = 1.0;
        attribute noiseRms : ElectricPotential_mV = 0.05;

        port rawInput : ConditionedSignalPort;
        port power : PowerPort;

        action bufferElectrodeSignal {
            in raw : ElectrodePotentialSignal;
            out conditioned : ConditionedVoltageSignal;
        }
    }

    part def TemperatureSensor {
        attribute sensorType : String = "Pt1000 RTD";
        attribute accuracy : TemperatureC = 0.2;
        attribute responseTime : Time_s = 8.0;

        port sampleContact : SolutionContactPort;
        port temperatureOut : TemperaturePort;

        action measureTemperature {
            in sample : SampleSolution;
            out temperature : TemperatureC;
        }
    }

    part def SignalProcessor {
        attribute idealSlopeAt25C_mVPerPH : ScalarValues::Real = -59.16;
        attribute calibratedSlope_mVPerPH : ScalarValues::Real = -58.8;
        attribute zeroOffset : ElectricPotential_mV = 0.7;
        attribute stabilityWindow : ElectricPotential_mV = 0.2;
        attribute stabilityDuration : Time_s = 10.0;

        port analogInput : DigitalMeasurementPort;
        port temperatureInput : TemperaturePort;

        action compensateTemperature {
            in voltage : ConditionedVoltageSignal;
            in temperature : TemperatureC;
            out compensatedPotential : ElectricPotential_mV;
        }

        action computePH {
            in compensatedPotential : ElectricPotential_mV;
            in temperature : TemperatureC;
            out measurement : DigitalPHMeasurement;
        }

        action assessStability {
            in measurement : DigitalPHMeasurement;
            out stable : Boolean;
            out confidence : Confidence;
        }
    }

    part def CalibrationManager {
        attribute lowBufferPH : pHValue = 4.01;
        attribute neutralBufferPH : pHValue = 7.00;
        attribute highBufferPH : pHValue = 10.01;
        attribute minimumAcceptableSlope_mVPerPH : ScalarValues::Real = -62.0;
        attribute maximumAcceptableSlope_mVPerPH : ScalarValues::Real = -54.0;
        attribute maximumOffsetMagnitude : ElectricPotential_mV = 30.0;

        port measurementIn : DigitalMeasurementPort;
        port userInterface : UserInterfacePort;

        action performTwoPointCalibration {
            in firstBuffer : CalibrationBuffer;
            in secondBuffer : CalibrationBuffer;
            out slope_mVPerPH : ScalarValues::Real;
            out offset : ElectricPotential_mV;
            out accepted : Boolean;
        }

        action performThreePointCalibration {
            in acidicBuffer : CalibrationBuffer;
            in neutralBuffer : CalibrationBuffer;
            in alkalineBuffer : CalibrationBuffer;
            out slope_mVPerPH : ScalarValues::Real;
            out offset : ElectricPotential_mV;
            out accepted : Boolean;
        }
    }

    part def UserInterface {
        attribute displayType : String = "LCD";
        attribute resolutionPH : pHValue = 0.01;
        attribute alarmEnabled : Boolean = true;

        port ui : UserInterfacePort;

        action showMeasurement {
            in measurement : DigitalPHMeasurement;
            out message : DisplayMessage;
        }

        action showCalibrationResult {
            in accepted : Boolean;
            in slope_mVPerPH : ScalarValues::Real;
            in offset : ElectricPotential_mV;
            out message : DisplayMessage;
        }
    }

    part def PowerSupply {
        attribute nominalVoltage : Voltage_V = 5.0;
        attribute maximumCurrent : Current_mA = 120.0;
        attribute isolationRating_V : Voltage_V = 500.0;

        port powerOut : PowerPort;
    }

    part def PHGlassElectrodeSystem {
        doc /* Primary function: determine the hydrogen ion activity of an aqueous sample by converting the glass membrane electrochemical potential, measured against a stable reference electrode and compensated for temperature, into a calibrated pH value for display or external use. */

        attribute measurementRangeLow : pHValue = 0.0;
        attribute measurementRangeHigh : pHValue = 14.0;
        attribute normalAccuracy : pHValue = 0.02;
        attribute operatingTemperatureLow : TemperatureC = 0.0;
        attribute operatingTemperatureHigh : TemperatureC = 80.0;
        attribute responseTimeToStableReading : Time_s = 30.0;

        port samplePort : SolutionContactPort;
        port userPort : UserInterfacePort;
        port powerInput : PowerPort;

        part electrode : ElectrodeBody;
        part amplifier : HighImpedanceAmplifier;
        part temperatureSensor : TemperatureSensor;
        part processor : SignalProcessor;
        part calibration : CalibrationManager;
        part interface : UserInterface;
        part supply : PowerSupply;

        connect samplePort.solution to electrode.sampleContact.solution;
        connect samplePort.solution to temperatureSensor.sampleContact.solution;

        connect electrode.membrane.sampleSide.potential to amplifier.rawInput.rawSignal;
        connect amplifier.rawInput.conditionedSignal to processor.analogInput.conditionedSignal;
        connect temperatureSensor.temperatureOut.temperature to processor.temperatureInput.temperature;

        connect processor.analogInput.measurement to interface.ui.measurement;
        connect processor.analogInput.measurement to calibration.measurementIn.measurement;
        connect interface.ui.message to userPort.message;
        connect userPort.command to interface.ui.command;
        connect userPort.command to calibration.userInterface.command;

        connect powerInput.supplyVoltage to amplifier.power.supplyVoltage;
        connect powerInput.supplyCurrent to amplifier.power.supplyCurrent;
        connect powerInput.supplyVoltage to supply.powerOut.supplyVoltage;
        connect powerInput.supplyCurrent to supply.powerOut.supplyCurrent;

        action measureSamplePH {
            in sample : SampleSolution;
            out measurement : DigitalPHMeasurement;

            first startIonExchange;
            then acquirePotential;
            then bufferSignal;
            then measureTemperature;
            then compensateForTemperature;
            then calculatePH;
            then verifyStability;
            then publishMeasurement;

            action startIonExchange {
                in sample : SampleSolution;
                out membranePotential : ElectrodePotentialSignal;
            }

            action acquirePotential {
                in membranePotential : ElectrodePotentialSignal;
                out rawPotential : ElectrodePotentialSignal;
            }

            action bufferSignal {
                in rawPotential : ElectrodePotentialSignal;
                out conditioned : ConditionedVoltageSignal;
            }

            action measureTemperature {
                in sample : SampleSolution;
                out temperature : TemperatureC;
            }

            action compensateForTemperature {
                in conditioned : ConditionedVoltageSignal;
                in temperature : TemperatureC;
                out compensatedPotential : ElectricPotential_mV;
            }

            action calculatePH {
                in compensatedPotential : ElectricPotential_mV;
                in temperature : TemperatureC;
                out calculatedMeasurement : DigitalPHMeasurement;
            }

            action verifyStability {
                in calculatedMeasurement : DigitalPHMeasurement;
                out stableMeasurement : DigitalPHMeasurement;
            }

            action publishMeasurement {
                in stableMeasurement : DigitalPHMeasurement;
                out measurement : DigitalPHMeasurement;
            }
        }

        state measurementStateMachine {
            entry action initializeElectronics;

            state Idle;
            state ConditioningElectrode;
            state MeasuringPotential;
            state TemperatureCompensating;
            state CalculatingPH;
            state StableReading;
            state CalibrationMode;
            state Fault;

            transition initial then Idle;

            transition Idle_to_Conditioning
                first Idle
                accept UserCommand
                if command.requestedMode == "measure"
                then ConditioningElectrode;

            transition Conditioning_to_Measuring
                first ConditioningElectrode
                after 5.0
                then MeasuringPotential;

            transition Measuring_to_Compensating
                first MeasuringPotential
                if electrode.membrane.membraneResistance < 1000.0
                then TemperatureCompensating;

            transition Compensating_to_Calculating
                first TemperatureCompensating
                then CalculatingPH;

            transition Calculating_to_Stable
                first CalculatingPH
                if processor.analogInput.measurement.stable == true
                then StableReading;

            transition Stable_to_Measuring
                first StableReading
                after 2.0
                then MeasuringPotential;

            transition Idle_to_Calibration
                first Idle
                accept UserCommand
                if command.requestedMode == "calibrate"
                then CalibrationMode;

            transition Calibration_to_Idle
                first CalibrationMode
                accept UserCommand
                if command.requestedMode == "measure"
                then Idle;

            transition Any_to_Fault
                first Idle
                if electrode.internalFill.fillLevelPercent < 20.0
                then Fault;

            transition Fault_to_Idle
                first Fault
                accept UserCommand
                if command.requestedMode == "reset"
                then Idle;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide a calibrated pH measurement of an aqueous sample using a glass membrane electrode and reference electrode pair. */

        subject system : PHGlassElectrodeSystem;

        require constraint {
            system.measurementRangeLow <= 0.0 and
            system.measurementRangeHigh >= 14.0 and
            system.normalAccuracy <= 0.02
        }
    }

    requirement def HighImpedanceInputRequirement {
        doc /* The measurement electronics shall not significantly load the glass membrane signal source. */

        subject amplifier : HighImpedanceAmplifier;

        require constraint {
            amplifier.inputResistance >= 100000.0
        }
    }

    requirement def TemperatureCompensationRequirement {
        doc /* The system shall compensate measured electrode potential using sample temperature before reporting pH. */

        subject system : PHGlassElectrodeSystem;

        require constraint {
            system.operatingTemperatureLow <= 0.0 and
            system.operatingTemperatureHigh >= 80.0
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The system shall produce a stable pH reading within the specified response time under normal sample conditions. */

        subject system : PHGlassElectrodeSystem;

        require constraint {
            system.responseTimeToStableReading <= 30.0
        }
    }

    requirement def CalibrationRequirement {
        doc /* The system shall support at least two-point calibration using certified buffer solutions. */

        subject calibration : CalibrationManager;

        require constraint {
            calibration.lowBufferPH == 4.01 and
            calibration.neutralBufferPH == 7.00
        }
    }

    requirement def ReferenceStabilityRequirement {
        doc /* The reference electrode junction potential shall remain small compared with the pH-sensitive membrane potential. */

        subject reference : ReferenceElectrode;

        require constraint {
            reference.maximumJunctionPotential <= 3.0
        }
    }

    part phGlassElectrodeSystem : PHGlassElectrodeSystem;

    item nominalSample : SampleSolution {
        attribute hydrogenIonActivity = 0.0000001;
        attribute pH = 7.00;
        attribute temperature = 25.0;
        attribute conductivity = 1000.0;
    }

    item acidicCalibrationBuffer : CalibrationBuffer {
        attribute certifiedPH = 4.01;
        attribute temperature = 25.0;
        attribute tolerance = 0.01;
    }

    item neutralCalibrationBuffer : CalibrationBuffer {
        attribute certifiedPH = 7.00;
        attribute temperature = 25.0;
        attribute tolerance = 0.01;
    }

    item alkalineCalibrationBuffer : CalibrationBuffer {
        attribute certifiedPH = 10.01;
        attribute temperature = 25.0;
        attribute tolerance = 0.01;
    }

    satisfy PrimaryFunctionRequirement by phGlassElectrodeSystem;
    satisfy TemperatureCompensationRequirement by phGlassElectrodeSystem;
    satisfy ResponseTimeRequirement by phGlassElectrodeSystem;
    satisfy HighImpedanceInputRequirement by phGlassElectrodeSystem.amplifier;
    satisfy CalibrationRequirement by phGlassElectrodeSystem.calibration;
    satisfy ReferenceStabilityRequirement by phGlassElectrodeSystem.electrode.referenceElectrode;
}