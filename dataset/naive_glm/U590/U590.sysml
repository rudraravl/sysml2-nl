package MassAirFlowSensorSystem {
    import ScalarValues::*;

    // ---- Value Types with Units ----
    value type MassFlowRate > Real { unit 'g/s'; }
    value type TemperatureValue > Real { unit 'degC'; }
    value type PressureValue > Real { unit 'kPa'; }
    value type VoltageValue > Real { unit 'V'; }
    value type CurrentValue > Real { unit 'mA'; }
    value type MassValue > Real { unit 'g'; }
    value type TimeValue > Real { unit 'ms'; }
    value type FrequencyValue > Real { unit 'Hz'; }
    value type VolumeValue > Real { unit 'L'; }
    value type RatioValue > Real { unit 'ratio'; }

    // ---- Item Definitions ----
    item def Air {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute humidity : Real;
        attribute flowRate : MassFlowRate;
    }

    item def FilteredAir :> Air;

    item def RawHotWireData {
        attribute heatingCurrent : CurrentValue;
        attribute timestamp : TimeValue;
    }

    item def EnvironmentalData {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute timestamp : TimeValue;
    }

    item def ProcessedMassFlow {
        attribute massFlowRate : MassFlowRate;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute timestamp : TimeValue;
    }

    item def VoltageSignal {
        attribute voltage : VoltageValue;
        attribute massFlowRate : MassFlowRate;
        attribute timestamp : TimeValue;
    }

    item def FuelCommand {
        attribute fuelMass : MassValue;
        attribute afr : RatioValue;
        attribute timestamp : TimeValue;
    }

    item def CalibrationParameters {
        attribute wireResistance : Real;
        attribute temperatureCoefficient : Real;
        attribute pressureCoefficient : Real;
        attribute zeroOffset : Real;
        attribute gainFactor : Real;
    }

    // ---- Port Definitions ----
    port def AirInPort {
        in item air : Air;
    }

    port def AirOutPort {
        out item air : Air;
    }

    port def RawDataOutPort {
        out item data : RawHotWireData;
    }

    port def EnvDataOutPort {
        out item data : EnvironmentalData;
    }

    port def MassFlowOutPort {
        out item flow : ProcessedMassFlow;
    }

    port def SignalOutPort {
        out item signal : VoltageSignal;
    }

    port def SignalInPort {
        in item signal : VoltageSignal;
    }

    port def FuelCommandOutPort {
        out item command : FuelCommand;
    }

    port def FuelCommandInPort {
        in item command : FuelCommand;
    }

    // ---- Part Definitions ----
    part def AirFilter {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        attribute filtrationEfficiency : Real;
        attribute maxFlowRate : MassFlowRate;

        action def filterAir {
            in incoming : Air;
            out filtered : FilteredAir;
        }

        state def AirFilterStates {
            state Idle;
            state Filtering {
                entry / filterAir(airIn.air, airOut.air);
            }
            transition idle_to_filtering first Idle then Filtering
                when airIn.air.flowRate > 0;
            transition filtering_to_idle first Filtering then Idle
                when airIn.air.flowRate == 0;
        }
    }

    part def HotWireElement {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port dataOut : RawDataOutPort;
        attribute wireTemperature : TemperatureValue;
        attribute nominalCurrent : CurrentValue;
        attribute maxCurrent : CurrentValue;

        action def measureCoolingEffect {
            in air : Air;
            out current : CurrentValue;
        }

        action def maintainTemperature {
            in current : CurrentValue;
            out adjustedCurrent : CurrentValue;
        }
    }

    part def TemperatureSensor {
        port airIn : AirInPort;
        port dataOut : EnvDataOutPort;
        attribute measuredTemperature : TemperatureValue;
        attribute accuracy : TemperatureValue;

        action def measureTemperature {
            in air : Air;
            out temp : TemperatureValue;
        }
    }

    part def PressureSensor {
        port airIn : AirInPort;
        port dataOut : EnvDataOutPort;
        attribute measuredPressure : PressureValue;
        attribute accuracy : PressureValue;

        action def measurePressure {
            in air : Air;
            out pressure : PressureValue;
        }
    }

    part def Microcontroller {
        port hotWireIn : RawDataOutPort;
        port tempIn : EnvDataOutPort;
        port pressureIn : EnvDataOutPort;
        port flowOut : MassFlowOutPort;
        attribute calibration : CalibrationParameters;
        attribute samplingRate : FrequencyValue;
        attribute responseTime : TimeValue;

        action def compensateMeasurement {
            in raw : RawHotWireData;
            in env : EnvironmentalData;
            in cal : CalibrationParameters;
            out flow : ProcessedMassFlow;
        }

        action def applyCalibration {
            in current : CurrentValue;
            in temp : TemperatureValue;
            in pressure : PressureValue;
            in cal : CalibrationParameters;
            out massFlow : MassFlowRate;
        }

        state def MicrocontrollerStates {
            state Standby;
            state Sampling {
                entry / compensateMeasurement(hotWireIn.data, tempIn.data, calibration, flowOut.flow);
            }
            state Processing;
            transition standby_to_sampling first Standby then Sampling
                when hotWireIn.data.heatingCurrent changes;
            transition sampling_to_processing first Sampling then Processing
                when flowOut.flow.massFlowRate computed;
            transition processing_to_sampling first Processing then Sampling
                when samplingRate.elapsed;
        }
    }

    part def SignalConditioner {
        port flowIn : MassFlowOutPort;
        port signalOut : SignalOutPort;
        attribute outputMin : VoltageValue;
        attribute outputMax : VoltageValue;
        attribute linearityError : Real;

        action def linearize {
            in flow : ProcessedMassFlow;
            out signal : VoltageSignal;
        }

        action def filterNoise {
            in signal : VoltageSignal;
            out clean : VoltageSignal;
        }
    }

    part def MAFSensor {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port signalOut : SignalOutPort;
        attribute responseTime : TimeValue;
        attribute measurementRange : MassFlowRate;
        attribute accuracy : Real;

        part hotWire : HotWireElement;
        part tempSensor : TemperatureSensor;
        part pressureSensor : PressureSensor;
        part microcontroller : Microcontroller;
        part signalConditioner : SignalConditioner;

        connection: airIn connect hotWire.airIn;
        connection: airIn connect tempSensor.airIn;
        connection: airIn connect pressureSensor.airIn;
        connection: hotWire.airOut connect airOut;

        connection: hotWire.dataOut connect microcontroller.hotWireIn;
        connection: tempSensor.dataOut connect microcontroller.tempIn;
        connection: pressureSensor.dataOut connect microcontroller.pressureIn;
        connection: microcontroller.flowOut connect signalConditioner.flowIn;
        connection: signalConditioner.signalOut connect signalOut;

        state def MAFSensorStates {
            state Initializing;
            state Active {
                entry / hotWire.maintainTemperature(hotWire.nominalCurrent, hotWire.dataOut.data.heatingCurrent);
            }
            state Faulted;
            transition init_to_active first Initializing then Active
                when hotWire.wireTemperature >= 100;
            transition active_to_faulted first Active then Faulted
                when hotWire.dataOut.data.heatingCurrent > hotWire.maxCurrent;
            transition faulted_to_init first Faulted then Initializing
                when reset asserted;
        }
    }

    part def IntakeManifold {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        attribute cylinderCount : Integer;
        attribute plenumVolume : VolumeValue;

        action def distributeAir {
            in air : Air;
            out distributed : Air;
        }

        state def ManifoldStates {
            state Balanced;
            state Distributing {
                entry / distributeAir(airIn.air, airOut.air);
            }
            transition balanced_to_distributing first Balanced then Distributing
                when airIn.air.flowRate > 0;
            transition distributing_to_balanced first Distributing then Balanced
                when airIn.air.flowRate == 0;
        }
    }

    part def EngineControlUnit {
        port signalIn : SignalInPort;
        port fuelCommandOut : FuelCommandOutPort;
        attribute targetAFR : RatioValue;
        attribute afrTolerance : RatioValue;
        attribute processingLatency : TimeValue;

        action def calculateFuelInjection {
            in signal : VoltageSignal;
            in afr : RatioValue;
            out command : FuelCommand;
        }

        action def optimizeAFR {
            in massFlow : MassFlowRate;
            in target : RatioValue;
            out fuelMass : MassValue;
        }

        state def ECUStates {
            state Monitoring;
            state Computing {
                entry / calculateFuelInjection(signalIn.signal, targetAFR, fuelCommandOut.command);
            }
            state Commanding;
            transition mon_to_comp first Monitoring then Computing
                when signalIn.signal.voltage changes;
            transition comp_to_cmd first Computing then Commanding
                when fuelCommandOut.command.fuelMass computed;
            transition cmd_to_mon first Commanding then Monitoring
                when fuelCommandOut.command delivered;
        }
    }

    part def Engine {
        port airIn : AirInPort;
        port fuelIn : FuelCommandInPort;
        attribute cylinderCount : Integer;
        attribute displacement : VolumeValue;
        attribute operatingRPM : FrequencyValue;
    }

    // ---- Top-Level Assembly ----
    part def AirIntakeAssembly {
        part airFilter : AirFilter;
        part mafSensor : MAFSensor;
        part intakeManifold : IntakeManifold;
        part ecu : EngineControlUnit;
        part engine : Engine;

        connection: airFilter.airOut connect mafSensor.airIn;
        connection: mafSensor.airOut connect intakeManifold.airIn;
        connection: intakeManifold.airOut connect engine.airIn;
        connection: mafSensor.signalOut connect ecu.signalIn;
        connection: ecu.fuelCommandOut connect engine.fuelIn;
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracyRequirement {
        subject sensor : MAFSensor;
        attribute maxErrorPercent : Real;
        require sensor.accuracy <= maxErrorPercent;
    }

    requirement def ResponseTimeRequirement {
        subject sensor : MAFSensor;
        attribute maxResponseTime : TimeValue;
        require sensor.responseTime <= maxResponseTime;
    }

    requirement def SignalLinearityRequirement {
        subject conditioner : SignalConditioner;
        attribute maxLinearityError : Real;
        require conditioner.linearityError <= maxLinearityError;
    }

    requirement def FuelOptimizationRequirement {
        subject ecu : EngineControlUnit;
        attribute targetAFR : RatioValue;
        attribute tolerance : RatioValue;
        require abs(ecu.actualAFR - targetAFR) <= tolerance;
    }

    requirement def AirFiltrationRequirement {
        subject filter : AirFilter;
        attribute minEfficiency : Real;
        require filter.filtrationEfficiency >= minEfficiency;
    }

    requirement def CompensationRequirement {
        subject controller : Microcontroller;
        attribute tempRange : TemperatureValue;
        attribute pressureRange : PressureValue;
        require controller.compensationActive == true;
    }

    // ---- Instantiated System with Requirement Satisfactions ----
    part massAirFlowSystem : AirIntakeAssembly {
        attribute systemResponseTime : TimeValue;

        satisfy respReq : ResponseTimeRequirement {
            subject = mafSensor;
            attribute maxResponseTime = 15 'ms';
        }

        satisfy accReq : MeasurementAccuracyRequirement {
            subject = mafSensor;
            attribute maxErrorPercent = 2.0;
        }

        satisfy linReq : SignalLinearityRequirement {
            subject = mafSensor.signalConditioner;
            attribute maxLinearityError = 1.0;
        }

        satisfy fuelReq : FuelOptimizationRequirement {
            subject = ecu;
            attribute targetAFR = 14.7;
            attribute tolerance = 0.5;
        }

        satisfy filtReq : AirFiltrationRequirement {
            subject = airFilter;
            attribute minEfficiency = 99.0;
        }

        satisfy compReq : CompensationRequirement {
            subject = mafSensor.microcontroller;
            attribute tempRange = 40 'degC';
            attribute pressureRange = 100 'kPa';
        }
    }
}
