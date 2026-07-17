package 'Electrical Resistivity and Conductivity System' {
    attribute def StartCalibration;
    attribute def MeasurementComplete;
    attribute def ReportComplete;
    attribute def ErrorDetected;
    attribute def ErrorCleared;

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def ResistivityValue :> Real {
        doc /* Electrical resistivity in ohm-meters (Ω·m) */
    }

    attribute def ConductivityValue :> Real {
        doc /* Electrical conductivity in siemens per meter (S/m) */
    }

    attribute def TemperatureCoefficientValue :> Real {
        doc /* Temperature coefficient of resistivity in per Kelvin (1/K) */
    }

    item def MaterialSample {
        attribute materialType : String;
        attribute resistivity : ResistivityValue;
        attribute conductivity : ConductivityValue;
        attribute temperatureCoefficient : TemperatureCoefficientValue;
        attribute referenceTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute sampleLength : LengthValue;
        attribute crossSectionalArea : AreaValue;
        
        assert constraint resistivityConductivityInverse {
            doc /* Conductivity is the reciprocal of resistivity */
            conductivity == 1.0 / resistivity
        }
    }

    item def MeasurementData {
        attribute appliedVoltage : ElectricPotentialValue;
        attribute measuredCurrent : ElectricCurrentValue;
        attribute calculatedResistance : Real;
        attribute calculatedResistivity : ResistivityValue;
        attribute calculatedConductivity : ConductivityValue;
        attribute measurementTemperature : TemperatureValue;
        attribute timestamp : Real;
    }

    port def PowerPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    port def SamplePort {
        in item sample : MaterialSample;
    }

    port def DataPort {
        out item data : MeasurementData;
    }

    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }

    part def VoltageSource {
        attribute outputVoltage : ElectricPotentialValue;
        attribute maxCurrent : ElectricCurrentValue;
        out port powerOut : PowerPort;
    }

    part def FourPointProbe {
        doc /* Four-point probe for accurate resistivity measurement */
        attribute probeSpacing : LengthValue;
        attribute probeContactResistance : Real;
        in port currentIn : PowerPort;
        out port voltageOut : PowerPort;
        port sampleInterface : SamplePort;
    }

    part def CurrentMeter {
        attribute measurementRange : ElectricCurrentValue;
        attribute accuracy : Real;
        in port input : PowerPort;
        out port output : PowerPort;
        attribute measuredCurrent : ElectricCurrentValue;
    }

    part def Voltmeter {
        attribute measurementRange : ElectricPotentialValue;
        attribute inputImpedance : Real;
        attribute accuracy : Real;
        in port input : PowerPort;
        attribute measuredVoltage : ElectricPotentialValue;
    }

    part def TemperatureController {
        attribute targetTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute heatingPower : PowerValue;
        attribute coolingPower : PowerValue;
        in port controlIn : ControlPort;
        out port sensorOut : DataPort;
    }

    part def DataAcquisitionUnit {
        attribute samplingRate : FrequencyValue;
        attribute resolution : Real;
        in port voltageIn : PowerPort;
        in port currentIn : PowerPort;
        in port temperatureIn : DataPort;
        out port dataOut : DataPort;
    }

    action def CalculateResistance {
        in voltage : ElectricPotentialValue;
        in current : ElectricCurrentValue;
        out resistance : Real;
    }

    action def CalculateResistivity {
        in resistance : Real;
        in length : LengthValue;
        in area : AreaValue;
        out resistivity : ResistivityValue;
    }

    action def CalculateConductivity {
        in resistivity : ResistivityValue;
        out conductivity : ConductivityValue;
    }

    action def CompensateTemperature {
        in measuredResistivity : ResistivityValue;
        in currentTemp : TemperatureValue;
        in referenceTemp : TemperatureValue;
        in tempCoefficient : TemperatureCoefficientValue;
        out compensatedResistivity : ResistivityValue;
    }

    action def PerformMeasurementCycle {
        in sample : MaterialSample;
        in appliedVoltage : ElectricPotentialValue;
        out measurementResult : MeasurementData;

        first start;
        then action applyVoltage {
            attribute voltage : ElectricPotentialValue = appliedVoltage;
        }
        then action measureCurrent {
            out current : ElectricCurrentValue;
        }
        then action calcResistance : CalculateResistance {
            in voltage = applyVoltage.voltage;
            in current = measureCurrent.current;
            out resistance : Real;
        }
        then action calcResistivity : CalculateResistivity {
            in resistance = calcResistance.resistance;
            in length = sample.sampleLength;
            in area = sample.crossSectionalArea;
            out resistivity : ResistivityValue;
        }
        then action calcConductivity : CalculateConductivity {
            in resistivity = calcResistivity.resistivity;
            out conductivity : ConductivityValue;
        }
        then action compensate : CompensateTemperature {
            in measuredResistivity = calcResistivity.resistivity;
            in currentTemp = sample.currentTemperature;
            in referenceTemp = sample.referenceTemperature;
            in tempCoefficient = sample.temperatureCoefficient;
            out compensatedResistivity : ResistivityValue;
        }
        then action recordData {
            attribute result : MeasurementData {
                appliedVoltage = applyVoltage.voltage;
                measuredCurrent = measureCurrent.current;
                calculatedResistance = calcResistance.resistance;
                calculatedResistivity = compensate.compensatedResistivity;
                calculatedConductivity = calcConductivity.conductivity;
                measurementTemperature = sample.currentTemperature;
            }
        }
        then done;
    }

    state def MeasurementStateMachine {
        entry action initialize;

        state Idle;

        state Calibrating {
            entry action performCalibration;
            do action verifyProbeContact;
        }

        state TemperatureStabilizing {
            entry action setTargetTemperature;
            do action monitorTemperature;
        }

        state Measuring {
            entry action startMeasurement;
            do action acquireData;
            exit action stopMeasurement;
        }

        state Processing {
            entry action processData;
            do action calculateProperties;
        }

        state Reporting {
            entry action generateReport;
            do action transmitData;
        }

        state Error {
            entry action logError;
            do action diagnostics;
        }

        transition idle_to_calibrating
            first Idle
            accept StartCalibration
            then Calibrating;

        transition calibrating_to_stabilizing
            first Calibrating
            if calibrationComplete
            then TemperatureStabilizing;

        transition stabilizing_to_measuring
            first TemperatureStabilizing
            if temperatureStable
            then Measuring;

        transition measuring_to_processing
            first Measuring
            accept MeasurementComplete
            then Processing;

        transition processing_to_reporting
            first Processing
            if dataValid
            then Reporting;

        transition reporting_to_idle
            first Reporting
            accept ReportComplete
            then Idle;

        transition any_to_error
            first Idle
            accept ErrorDetected
            then Error;

        transition error_to_idle
            first Error
            accept ErrorCleared
            then Idle;
    }

    part def ResistivityConductivityMeasurementSystem {
        doc /* 
            Primary function: Measure and characterize the electrical resistivity 
            and conductivity of material samples across varying temperatures using 
            a four-point probe technique. The system applies a known voltage, measures 
            the resulting current, and calculates resistivity and conductivity with 
            temperature compensation to provide accurate material characterization 
            for research and quality control applications.
        */

        part voltageSource : VoltageSource {
            attribute outputVoltage = 1.0;
            attribute maxCurrent = 0.1;
        }

        part probe : FourPointProbe {
            attribute probeSpacing = 0.001;
            attribute probeContactResistance = 0.01;
        }

        part ammeter : CurrentMeter {
            attribute measurementRange = 0.1;
            attribute accuracy = 0.001;
        }

        part voltmeter : Voltmeter {
            attribute measurementRange = 10.0;
            attribute inputImpedance = 1000000.0;
            attribute accuracy = 0.0001;
        }

        part tempController : TemperatureController {
            attribute targetTemperature = 298.15;
            attribute heatingPower = 100.0;
            attribute coolingPower = 100.0;
        }

        part dataAcquisition : DataAcquisitionUnit {
            attribute samplingRate = 1000.0;
            attribute resolution = 16.0;
        }

        part controlUnit {
            attribute operatingMode : String;
            port controlPort : ControlPort;
            exhibit state operation : MeasurementStateMachine;
        }

        connection sourceToAmmeter connect voltageSource.powerOut to ammeter.input;
        connection ammeterToProbe connect ammeter.output to probe.currentIn;
        connection probeToVoltmeter connect probe.voltageOut to voltmeter.input;
        connection voltmeterToDAQ connect voltmeter.input to dataAcquisition.voltageIn;
        connection ammeterToDAQ connect ammeter.output to dataAcquisition.currentIn;
        connection tempToDAQ connect tempController.sensorOut to dataAcquisition.temperatureIn;
        connection controlToTemp connect controlUnit.controlPort to tempController.controlIn;

        perform action measurementCycle : PerformMeasurementCycle;
    }

    requirement def MeasurementAccuracyRequirement {
        doc /* The system shall measure resistivity with accuracy better than 1% */
        subject system : ResistivityConductivityMeasurementSystem;
        
        require constraint accuracySpec {
            doc /* Resistivity measurement accuracy <= 1% of true value */
        }
    }

    requirement def TemperatureStabilityRequirement {
        doc /* The system shall maintain temperature stability during measurement */
        subject system : ResistivityConductivityMeasurementSystem;
        
        require constraint temperatureStability {
            doc /* Temperature variation during measurement <= 0.1 K */
        }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The system shall measure across wide resistivity range */
        subject system : ResistivityConductivityMeasurementSystem;
        
        require constraint resistivityRange {
            doc /* Resistivity range: 10^-8 to 10^8 ohm-meters */
        }
        
        require constraint conductivityRange {
            doc /* Conductivity range: 10^-8 to 10^8 siemens per meter */
        }
    }

    requirement def TemperatureRangeRequirement {
        doc /* The system shall operate over specified temperature range */
        subject system : ResistivityConductivityMeasurementSystem;
        
        require constraint operatingTemperatureRange {
            doc /* Operating temperature: 77 K to 500 K */
        }
    }

    requirement systemRequirements {
        doc /* Top-level requirements for resistivity and conductivity measurement system */
        
        require measurementAccuracy : MeasurementAccuracyRequirement;
        require temperatureStability : TemperatureStabilityRequirement;
        require measurementRange : MeasurementRangeRequirement;
        require temperatureRange : TemperatureRangeRequirement;
    }

    part resistivitySystem : ResistivityConductivityMeasurementSystem {
        doc /* 
            Complete electrical resistivity and conductivity measurement system 
            for material characterization. Utilizes four-point probe methodology 
            to eliminate contact resistance effects and provides temperature-
            compensated measurements for accurate determination of intrinsic 
            material electrical properties.
        */
        
        satisfy systemRequirements;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Electrical Resistivity and Conductivity System'::*;

    part testSubject = controlUnit {
        exhibit state sm : MeasurementStateMachine;
    }

    action orchestrator {
        attribute testVoltage : ElectricPotentialValue;
        attribute testCurrent : ElectricCurrentValue;
        action actionProbe : CalculateResistance {
            in voltage = testVoltage;
            in current = testCurrent;
        }
        attribute testStartCalibration : StartCalibration;
        attribute testMeasurementComplete : MeasurementComplete;
        attribute testReportComplete : ReportComplete;
        action triggerStartCalibration send testStartCalibration to testSubject;
        action triggerMeasurementComplete send testMeasurementComplete to testSubject;
        action triggerReportComplete send testReportComplete to testSubject;
        first actionProbe;
        then triggerStartCalibration;
        then triggerMeasurementComplete;
        then triggerReportComplete;
    }
}
