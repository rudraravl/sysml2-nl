package BiosensorSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Concentration {
        :> scalarValues::Real;
        unit : Unit = micromolePerLiter;
    }

    attribute def Voltage {
        :> scalarValues::Real;
        unit : Unit = volt;
    }

    attribute def Current {
        :> scalarValues::Real;
        unit : Unit = microampere;
    }

    attribute def Temperature {
        :> scalarValues::Real;
        unit : Unit = degreeCelsius;
    }

    attribute def TimeInterval {
        :> scalarValues::Real;
        unit : Unit = second;
    }

    attribute def BatteryCharge {
        :> scalarValues::Real;
        unit : Unit = percent;
    }

    attribute def SamplingRate {
        :> scalarValues::Real;
        unit : Unit = hertz;
    }

    attribute def SignalQuality {
        :> scalarValues::Real;
        unit : Unit = percent;
    }

    attribute def Confidence {
        :> scalarValues::Real;
        unit : Unit = percent;
    }

    attribute def Identifier {
        :> scalarValues::String;
    }

    item def BiologicalSample {
        attribute sampleId : Identifier;
        attribute sampleTemperature : Temperature;
        attribute collectionTime : TimeInterval;
    }

    item def Analyte {
        attribute name : Identifier;
        attribute concentration : Concentration;
    }

    item def RawElectrochemicalSignal {
        attribute workingElectrodeCurrent : Current;
        attribute referenceVoltage : Voltage;
        attribute signalTemperature : Temperature;
        attribute signalQuality : SignalQuality;
    }

    item def DigitizedSignal {
        attribute sampleRate : SamplingRate;
        attribute digitalValue : scalarValues::Integer;
        attribute signalQuality : SignalQuality;
    }

    item def BiosensorMeasurement {
        attribute analyteName : Identifier;
        attribute measuredConcentration : Concentration;
        attribute confidence : Confidence;
        attribute measurementTime : TimeInterval;
        attribute temperatureCompensated : scalarValues::Boolean;
    }

    item def UserAlert {
        attribute alertCode : Identifier;
        attribute alertMessage : Identifier;
        attribute severity : scalarValues::Integer;
    }

    port def SampleIntakePort {
        in item sample : BiologicalSample;
    }

    port def ReagentFlowPort {
        out item conditionedSample : BiologicalSample;
    }

    port def ElectrochemicalSignalPort {
        out item rawSignal : RawElectrochemicalSignal;
    }

    port def DigitalSignalPort {
        out item digitizedSignal : DigitizedSignal;
    }

    port def MeasurementPort {
        out item measurement : BiosensorMeasurement;
    }

    port def AlertPort {
        out item alert : UserAlert;
    }

    port def PowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute availableCharge : BatteryCharge;
    }

    port def DataPort {
        out item measurement : BiosensorMeasurement;
        out item alert : UserAlert;
    }

    action def PrepareSample {
        in item incomingSample : BiologicalSample;
        out item preparedSample : BiologicalSample;

        attribute mixingDuration : TimeInterval = 4.0 [second];
        attribute targetTemperature : Temperature = 37.0 [degreeCelsius];
    }

    action def DetectAnalyte {
        in item preparedSample : BiologicalSample;
        out item rawSignal : RawElectrochemicalSignal;

        attribute biasVoltage : Voltage = 0.65 [volt];
        attribute stabilizationTime : TimeInterval = 2.0 [second];
    }

    action def ConvertSignal {
        in item rawSignal : RawElectrochemicalSignal;
        out item digitizedSignal : DigitizedSignal;

        attribute conversionResolutionBits : scalarValues::Integer = 16;
        attribute sampleRate : SamplingRate = 20.0 [hertz];
    }

    action def EstimateConcentration {
        in item digitizedSignal : DigitizedSignal;
        out item measurement : BiosensorMeasurement;

        attribute calibrationSlope : scalarValues::Real = 0.018;
        attribute calibrationOffset : Concentration = 0.2 [micromolePerLiter];
        attribute minimumConfidence : Confidence = 90.0 [percent];
    }

    action def ReportMeasurement {
        in item measurement : BiosensorMeasurement;
        out item reportedMeasurement : BiosensorMeasurement;
    }

    action def GenerateAlert {
        in item measurement : BiosensorMeasurement;
        out item alert : UserAlert;

        attribute lowLimit : Concentration = 2.0 [micromolePerLiter];
        attribute highLimit : Concentration = 30.0 [micromolePerLiter];
    }

    part def MicrofluidicCartridge {
        port sampleIn : SampleIntakePort;
        port conditionedOut : ReagentFlowPort;

        attribute channelVolume : VolumeValue = 25.0 [microliter];
        attribute reagentVolume : VolumeValue = 10.0 [microliter];
        attribute nominalProcessingTime : TimeInterval = 4.0 [second];

        perform action prepareSample : PrepareSample;
    }

    part def BioreceptorLayer {
        attribute receptorMaterial : Identifier = "glucose oxidase hydrogel";
        attribute operatingTemperature : Temperature = 37.0 [degreeCelsius];
        attribute responseTime : TimeInterval = 3.0 [second];
        attribute lowerDetectionLimit : Concentration = 0.1 [micromolePerLiter];
        attribute upperDetectionLimit : Concentration = 50.0 [micromolePerLiter];
    }

    part def ElectrochemicalTransducer {
        port signalOut : ElectrochemicalSignalPort;

        part bioreceptor : BioreceptorLayer;

        attribute workingElectrodeArea : AreaValue = 3.0 [squareMillimeter];
        attribute biasVoltage : Voltage = 0.65 [volt];
        attribute nominalSensitivity : scalarValues::Real = 0.018;

        perform action detectAnalyte : DetectAnalyte;
    }

    part def AnalogFrontEnd {
        port rawIn : ElectrochemicalSignalPort;
        port digitalOut : DigitalSignalPort;

        attribute inputNoiseCurrent : Current = 0.02 [microampere];
        attribute gain : scalarValues::Real = 100000.0;
        attribute filterCutoffFrequency : FrequencyValue = 5.0 [hertz];

        perform action convertSignal : ConvertSignal;
    }

    part def ProcessingUnit {
        port digitalIn : DigitalSignalPort;
        port measurementOut : MeasurementPort;
        port alertOut : AlertPort;

        attribute processorClock : FrequencyValue = 48.0 [megahertz];
        attribute firmwareVersion : Identifier = "2.4.1";
        attribute measurementLatency : TimeInterval = 1.0 [second];

        perform action estimateConcentration : EstimateConcentration;
        perform action generateAlert : GenerateAlert;

        state machine MeasurementControl {
            state Idle;
            state SampleDetected;
            state Stabilizing;
            state Measuring;
            state Validating;
            state Reporting;
            state Fault;

            entry action initialize {
                send UserAlert {
                    alertCode = "READY";
                    alertMessage = "biosensor ready";
                    severity = 0;
                } via alertOut;
            }

            transition first Idle;

            transition Idle_to_SampleDetected
                first Idle
                accept BiologicalSample
                then SampleDetected;

            transition SampleDetected_to_Stabilizing
                first SampleDetected
                then Stabilizing;

            transition Stabilizing_to_Measuring
                first Stabilizing
                if stabilizationComplete
                then Measuring;

            transition Measuring_to_Validating
                first Measuring
                then Validating;

            transition Validating_to_Reporting
                first Validating
                if measurementConfidence >= 90.0 [percent]
                then Reporting;

            transition Validating_to_Fault
                first Validating
                if measurementConfidence < 90.0 [percent]
                then Fault;

            transition Reporting_to_Idle
                first Reporting
                then Idle;

            transition Fault_to_Idle
                first Fault
                accept resetCommand
                then Idle;

            attribute stabilizationComplete : scalarValues::Boolean;
            attribute measurementConfidence : Confidence;
            attribute resetCommand : scalarValues::Boolean;
        }
    }

    part def DisplayAndCommunicationModule {
        port measurementIn : MeasurementPort;
        port alertIn : AlertPort;
        port dataOut : DataPort;

        attribute displayRefreshRate : FrequencyValue = 30.0 [hertz];
        attribute wirelessProtocol : Identifier = "Bluetooth Low Energy";
        attribute packetInterval : TimeInterval = 1.0 [second];

        perform action reportMeasurement : ReportMeasurement;
    }

    part def PowerSubsystem {
        port powerOut : PowerPort;

        attribute nominalVoltage : Voltage = 3.7 [volt];
        attribute minimumOperatingVoltage : Voltage = 3.3 [volt];
        attribute batteryCharge : BatteryCharge = 100.0 [percent];
        attribute maximumContinuousCurrent : Current = 120000.0 [microampere];
    }

    part def BiosensorSystem {
        port sampleInput : SampleIntakePort;
        port externalData : DataPort;

        part cartridge : MicrofluidicCartridge;
        part transducer : ElectrochemicalTransducer;
        part analogFrontEnd : AnalogFrontEnd;
        part processor : ProcessingUnit;
        part userInterface : DisplayAndCommunicationModule;
        part power : PowerSubsystem;

        attribute targetAnalyte : Identifier = "glucose";
        attribute primaryFunction : Identifier = "detect a biological analyte in a sample and convert the biochemical interaction into a calibrated concentration measurement";
        attribute measurementRangeLow : Concentration = 0.1 [micromolePerLiter];
        attribute measurementRangeHigh : Concentration = 50.0 [micromolePerLiter];
        attribute requiredMeasurementTime : TimeInterval = 10.0 [second];
        attribute requiredConfidence : Confidence = 90.0 [percent];

        connect sampleInput.sample to cartridge.sampleIn.sample;
        connect cartridge.conditionedOut.conditionedSample to transducer.detectAnalyte.preparedSample;
        connect transducer.signalOut.rawSignal to analogFrontEnd.rawIn.rawSignal;
        connect analogFrontEnd.digitalOut.digitizedSignal to processor.digitalIn.digitizedSignal;
        connect processor.measurementOut.measurement to userInterface.measurementIn.measurement;
        connect processor.alertOut.alert to userInterface.alertIn.alert;
        connect userInterface.dataOut.measurement to externalData.measurement;
        connect userInterface.dataOut.alert to externalData.alert;
        connect power.powerOut.supplyVoltage to analogFrontEnd.rawIn;
        connect power.powerOut.supplyVoltage to processor.digitalIn;
    }

    requirement def PrimaryFunctionRequirement {
        subject biosensor : BiosensorSystem;

        require constraint {
            biosensor.primaryFunction == "detect a biological analyte in a sample and convert the biochemical interaction into a calibrated concentration measurement"
        }

        doc /* The biosensor system shall accept a biological sample, selectively detect the target analyte, convert the biochemical response into an electrical signal, process the signal, and report a high-level concentration measurement to the user or connected system. */
    }

    requirement def MeasurementRangeRequirement {
        subject biosensor : BiosensorSystem;

        require constraint {
            biosensor.measurementRangeLow <= 0.1 [micromolePerLiter] and
            biosensor.measurementRangeHigh >= 50.0 [micromolePerLiter]
        }

        doc /* The biosensor system shall measure the target analyte over the full specified concentration range. */
    }

    requirement def MeasurementTimeRequirement {
        subject biosensor : BiosensorSystem;

        require constraint {
            biosensor.requiredMeasurementTime <= 10.0 [second]
        }

        doc /* The biosensor system shall complete sample preparation, analyte detection, signal conversion, concentration estimation, and reporting within ten seconds. */
    }

    requirement def ConfidenceRequirement {
        subject biosensor : BiosensorSystem;

        require constraint {
            biosensor.requiredConfidence >= 90.0 [percent]
        }

        doc /* The biosensor system shall report measurements only when the computed confidence is at least ninety percent or shall generate a diagnostic alert. */
    }

    requirement def PowerRequirement {
        subject biosensor : BiosensorSystem;

        require constraint {
            biosensor.power.nominalVoltage >= biosensor.power.minimumOperatingVoltage and
            biosensor.power.batteryCharge >= 10.0 [percent]
        }

        doc /* The biosensor system shall remain operational while sufficient regulated power is available. */
    }

    satisfy PrimaryFunctionRequirement by BiosensorSystem;
    satisfy MeasurementRangeRequirement by BiosensorSystem;
    satisfy MeasurementTimeRequirement by BiosensorSystem;
    satisfy ConfidenceRequirement by BiosensorSystem;
    satisfy PowerRequirement by BiosensorSystem;

    part biosensorSystem : BiosensorSystem;

}