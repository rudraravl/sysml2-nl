package ElectrochemicalFatigueCrackSensingUnit {

    import ScalarValues::*;
    import SI::*;

    attribute def ElectricPotential {
        :> ScalarValues::Real;
        unit = V;
    }

    attribute def ElectricCurrent {
        :> ScalarValues::Real;
        unit = A;
    }

    attribute def ElectricCharge {
        :> ScalarValues::Real;
        unit = C;
    }

    attribute def ElectricalResistance {
        :> ScalarValues::Real;
        unit = Ohm;
    }

    attribute def Temperature {
        :> ScalarValues::Real;
        unit = K;
    }

    attribute def Length {
        :> ScalarValues::Real;
        unit = m;
    }

    attribute def CrackLength {
        :> Length;
    }

    attribute def CrackGrowthRate {
        :> ScalarValues::Real;
        unit = m / s;
    }

    attribute def TimeDuration {
        :> ScalarValues::Real;
        unit = s;
    }

    attribute def SamplingRate {
        :> ScalarValues::Real;
        unit = Hz;
    }

    attribute def DimensionlessRatio {
        :> ScalarValues::Real;
    }

    item def ElectrolyteIonFlow {
        attribute ionicCurrent : ElectricCurrent;
        attribute temperature : Temperature;
    }

    item def ExcitationSignal {
        attribute potential : ElectricPotential;
        attribute frequency : SamplingRate;
    }

    item def SensorResponse {
        attribute measuredCurrent : ElectricCurrent;
        attribute measuredPotential : ElectricPotential;
        attribute inferredImpedance : ElectricalResistance;
        attribute temperature : Temperature;
    }

    item def CrackMeasurement {
        attribute crackLength : CrackLength;
        attribute crackGrowthRate : CrackGrowthRate;
        attribute confidence : DimensionlessRatio;
        attribute timestamp : TimeDuration;
    }

    item def DiagnosticStatus {
        attribute electrolyteValid : Boolean;
        attribute electrodeContinuityValid : Boolean;
        attribute calibrationValid : Boolean;
        attribute faultPresent : Boolean;
    }

    port def ExcitationPort {
        out item signal : ExcitationSignal;
    }

    port def ElectrochemicalResponsePort {
        in item response : SensorResponse;
    }

    port def ElectrolytePort {
        inout item ionFlow : ElectrolyteIonFlow;
    }

    port def MeasurementOutputPort {
        out item measurement : CrackMeasurement;
    }

    port def DiagnosticPort {
        out item status : DiagnosticStatus;
    }

    port def PowerPort {
        in attribute supplyVoltage : ElectricPotential;
        in attribute supplyCurrent : ElectricCurrent;
    }

    part def ElectrochemicalFatigueCrackSensor {
        attribute workingElectrodePotential : ElectricPotential;
        attribute counterElectrodePotential : ElectricPotential;
        attribute referenceElectrodePotential : ElectricPotential;
        attribute baselineImpedance : ElectricalResistance;
        attribute activeImpedance : ElectricalResistance;
        attribute electrolyteTemperature : Temperature;
        attribute minimumDetectableCrackLength : CrackLength = 0.0002 [m];
        attribute maximumMeasurableCrackLength : CrackLength = 0.025 [m];

        port excitation : ExcitationPort;
        port response : ElectrochemicalResponsePort;
        port electrolyte : ElectrolytePort;

        part workingElectrode {
            attribute exposedLength : Length;
            attribute continuityResistance : ElectricalResistance;
        }

        part referenceElectrode {
            attribute stabilityPotential : ElectricPotential;
        }

        part counterElectrode {
            attribute surfaceArea : ScalarValues::Real;
        }

        part electrolyteLayer {
            attribute conductivity : ScalarValues::Real;
            attribute thickness : Length;
            attribute temperature : Temperature;
        }
    }

    part def PotentiostatFrontEnd {
        attribute excitationAmplitude : ElectricPotential = 0.010 [V];
        attribute dcBiasPotential : ElectricPotential = 0.250 [V];
        attribute currentResolution : ElectricCurrent = 0.000000001 [A];
        attribute inputImpedance : ElectricalResistance;

        port power : PowerPort;
        port excitation : ExcitationPort;
        port response : ElectrochemicalResponsePort;

        action generateExcitation {
            out item signal : ExcitationSignal;
        }

        action acquireResponse {
            in item response : SensorResponse;
            out attribute current : ElectricCurrent;
            out attribute potential : ElectricPotential;
        }
    }

    part def TemperatureCompensator {
        attribute referenceTemperature : Temperature = 298.15 [K];
        attribute measuredTemperature : Temperature;
        attribute compensationFactor : DimensionlessRatio;

        action compensateImpedance {
            in attribute rawImpedance : ElectricalResistance;
            in attribute temperature : Temperature;
            out attribute compensatedImpedance : ElectricalResistance;
        }
    }

    part def CrackEstimator {
        attribute calibrationSlope : ScalarValues::Real;
        attribute calibrationOffset : CrackLength;
        attribute previousCrackLength : CrackLength;
        attribute currentCrackLength : CrackLength;
        attribute samplePeriod : TimeDuration = 1.0 [s];

        action estimateCrackLength {
            in attribute compensatedImpedance : ElectricalResistance;
            out item measurement : CrackMeasurement;
        }

        action estimateGrowthRate {
            in attribute previousLength : CrackLength;
            in attribute currentLength : CrackLength;
            in attribute elapsedTime : TimeDuration;
            out attribute rate : CrackGrowthRate;
        }
    }

    part def HealthMonitor {
        attribute minimumElectrolyteConductivity : ScalarValues::Real;
        attribute maximumElectrodeResistance : ElectricalResistance = 100.0 [Ohm];
        attribute maximumTemperature : Temperature = 333.15 [K];
        attribute minimumTemperature : Temperature = 273.15 [K];

        port diagnostic : DiagnosticPort;

        action evaluateHealth {
            in attribute electrodeResistance : ElectricalResistance;
            in attribute temperature : Temperature;
            out item status : DiagnosticStatus;
        }
    }

    part def EmbeddedController {
        attribute samplingRate : SamplingRate = 1.0 [Hz];
        attribute startupDelay : TimeDuration = 5.0 [s];
        attribute faultLatch : Boolean;

        port measurementOutput : MeasurementOutputPort;
        port diagnosticOutput : DiagnosticPort;

        part estimator : CrackEstimator;
        part compensator : TemperatureCompensator;
        part healthMonitor : HealthMonitor;

        state controllerState {
            entry; then Initializing;

            state Initializing;
            state Calibrating;
            state Measuring;
            state Faulted;
            state Standby;

            transition Initializing_to_Calibrating
                first Initializing
                then Calibrating
                accept after startupDelay;

            transition Calibrating_to_Measuring
                first Calibrating
                then Measuring
                guard calibrationComplete;

            transition Measuring_to_Faulted
                first Measuring
                then Faulted
                guard faultLatch == true;

            transition Faulted_to_Standby
                first Faulted
                then Standby
                accept resetCommand;

            transition Standby_to_Measuring
                first Standby
                then Measuring
                accept enableCommand;
        }

        action processMeasurementCycle {
            in item response : SensorResponse;
            out item measurement : CrackMeasurement;
            out item status : DiagnosticStatus;

            first start;
            then compensate;
            then estimate;
            then diagnose;
            then publish;

            action start;
            action compensate;
            action estimate;
            action diagnose;
            action publish;
        }
    }

    part def SensingUnit {
        attribute supplyVoltageNominal : ElectricPotential = 5.0 [V];
        attribute totalCurrentNominal : ElectricCurrent = 0.080 [A];
        attribute measurementRangeMin : CrackLength = 0.0002 [m];
        attribute measurementRangeMax : CrackLength = 0.025 [m];
        attribute requiredAccuracy : Length = 0.00005 [m];
        attribute requiredResponseTime : TimeDuration = 2.0 [s];

        port powerInput : PowerPort;
        port crackMeasurementOutput : MeasurementOutputPort;
        port diagnosticOutput : DiagnosticPort;
        port electrolyteInterface : ElectrolytePort;

        part sensor : ElectrochemicalFatigueCrackSensor;
        part potentiostat : PotentiostatFrontEnd;
        part controller : EmbeddedController;

        connect powerInput to potentiostat.power;
        connect potentiostat.excitation to sensor.excitation;
        connect sensor.response to potentiostat.response;
        connect electrolyteInterface to sensor.electrolyte;
        connect controller.measurementOutput to crackMeasurementOutput;
        connect controller.diagnosticOutput to diagnosticOutput;

        perform action senseFatigueCrack {
            in attribute suppliedVoltage : ElectricPotential;
            out item crackMeasurement : CrackMeasurement;
            out item diagnosticStatus : DiagnosticStatus;

            first energize;
            then exciteSensor;
            then acquireElectrochemicalResponse;
            then compensateTemperature;
            then estimateCrack;
            then reportResults;

            action energize {
                in attribute voltage : ElectricPotential;
            }

            action exciteSensor {
                out item excitation : ExcitationSignal;
            }

            action acquireElectrochemicalResponse {
                in item response : SensorResponse;
            }

            action compensateTemperature {
                in item rawResponse : SensorResponse;
                out attribute compensatedImpedance : ElectricalResistance;
            }

            action estimateCrack {
                in attribute compensatedImpedance : ElectricalResistance;
                out item measurement : CrackMeasurement;
            }

            action reportResults {
                in item measurement : CrackMeasurement;
                in item status : DiagnosticStatus;
            }
        }
    }

    requirement def CrackMeasurementRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.measurementRangeMin <= 0.0002 [m] and
            sensingUnit.measurementRangeMax >= 0.025 [m]
        }

        doc /* The sensing unit shall measure fatigue crack length from 0.2 mm to 25 mm using an electrochemical fatigue crack sensor. */
    }

    requirement def AccuracyRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.requiredAccuracy <= 0.00005 [m]
        }

        doc /* The sensing unit shall estimate crack length with error no greater than 50 micrometers after calibration. */
    }

    requirement def ResponseTimeRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.requiredResponseTime <= 2.0 [s]
        }

        doc /* The sensing unit shall publish a compensated crack measurement within 2 seconds of each acquisition cycle. */
    }

    requirement def DiagnosticRequirement {
        subject monitor : HealthMonitor;

        require constraint {
            monitor.maximumElectrodeResistance <= 100.0 [Ohm] and
            monitor.maximumTemperature <= 333.15 [K] and
            monitor.minimumTemperature >= 273.15 [K]
        }

        doc /* The sensing unit shall detect electrode continuity faults and electrolyte temperature faults. */
    }

    requirement def ElectrochemicalExcitationRequirement {
        subject frontEnd : PotentiostatFrontEnd;

        require constraint {
            frontEnd.excitationAmplitude <= 0.020 [V] and
            frontEnd.currentResolution <= 0.000000001 [A]
        }

        doc /* The potentiostat shall excite the electrochemical crack sensor with small-signal potential perturbation and resolve nanoampere current response. */
    }

    part sensingUnitInstance : SensingUnit {
        attribute supplyVoltageNominal = 5.0 [V];
        attribute totalCurrentNominal = 0.080 [A];
        attribute measurementRangeMin = 0.0002 [m];
        attribute measurementRangeMax = 0.025 [m];
        attribute requiredAccuracy = 0.00005 [m];
        attribute requiredResponseTime = 2.0 [s];

        part sensor {
            attribute workingElectrodePotential = 0.250 [V];
            attribute counterElectrodePotential = 0.0 [V];
            attribute referenceElectrodePotential = 0.0 [V];
            attribute baselineImpedance = 5000.0 [Ohm];
            attribute activeImpedance = 5000.0 [Ohm];
            attribute electrolyteTemperature = 298.15 [K];

            part workingElectrode {
                attribute exposedLength = 0.030 [m];
                attribute continuityResistance = 10.0 [Ohm];
            }

            part referenceElectrode {
                attribute stabilityPotential = 0.0 [V];
            }

            part electrolyteLayer {
                attribute thickness = 0.0001 [m];
                attribute temperature = 298.15 [K];
            }
        }

        part potentiostat {
            attribute excitationAmplitude = 0.010 [V];
            attribute dcBiasPotential = 0.250 [V];
            attribute currentResolution = 0.000000001 [A];
            attribute inputImpedance = 1000000000.0 [Ohm];
        }

        part controller {
            attribute samplingRate = 1.0 [Hz];
            attribute startupDelay = 5.0 [s];
            attribute faultLatch = false;

            part estimator {
                attribute calibrationSlope = 0.000001;
                attribute calibrationOffset = 0.0 [m];
                attribute previousCrackLength = 0.0 [m];
                attribute currentCrackLength = 0.0 [m];
                attribute samplePeriod = 1.0 [s];
            }

            part compensator {
                attribute referenceTemperature = 298.15 [K];
                attribute measuredTemperature = 298.15 [K];
                attribute compensationFactor = 1.0;
            }

            part healthMonitor {
                attribute maximumElectrodeResistance = 100.0 [Ohm];
                attribute maximumTemperature = 333.15 [K];
                attribute minimumTemperature = 273.15 [K];
            }
        }
    }

    satisfy CrackMeasurementRequirement by sensingUnitInstance;
    satisfy AccuracyRequirement by sensingUnitInstance;
    satisfy ResponseTimeRequirement by sensingUnitInstance;
    satisfy ElectrochemicalExcitationRequirement by sensingUnitInstance.potentiostat;
    satisfy DiagnosticRequirement by sensingUnitInstance.controller.healthMonitor;
}