package CalorimeterSystem {
    import ScalarValues::*;

    // ===== Units =====

    unit K;
    unit W;
    unit J;
    unit kg;
    unit s;
    unit Hz;
    unit JPerK;
    unit JPerKgK;
    unit KPerS;
    unit KPerW;

    // ===== Value Types =====

    value type TemperatureValue :> Real {
        unit K;
    }

    value type PowerValue :> Real {
        unit W;
    }

    value type EnergyValue :> Real {
        unit J;
    }

    value type MassValue :> Real {
        unit kg;
    }

    value type TimeValue :> Real {
        unit s;
    }

    value type HeatCapacityValue :> Real {
        unit JPerK;
    }

    value type SpecificHeatValue :> Real {
        unit JPerKgK;
    }

    value type TemperatureRateValue :> Real {
        unit KPerS;
    }

    value type FrequencyValue :> Real {
        unit Hz;
    }

    value type ThermalResistanceValue :> Real {
        unit KPerW;
    }

    // ===== Enumerations =====

    enum def OperatingMode {
        enum isothermal;
        enum adiabatic;
        enum scanning;
    }

    enum def ExperimentPhase {
        enum initialization;
        enum equilibration;
        enum measurement;
        enum completion;
    }

    // ===== Item Types =====

    item def Sample {
        attribute mass : MassValue;
        attribute initialTemperature : TemperatureValue;
        attribute materialType : String;
        attribute density : Real;
    }

    item def SensorReading {
        attribute timestamp : TimeValue;
        attribute temperature : TemperatureValue;
        attribute confidence : Real;
    }

    item def HeaterCommand {
        attribute timestamp : TimeValue;
        attribute powerLevel : PowerValue;
        attribute duration : TimeValue;
    }

    item def DataRecord {
        attribute timestamp : TimeValue;
        attribute temperature : TemperatureValue;
        attribute heaterPower : PowerValue;
        attribute phase : ExperimentPhase;
    }

    item def ExperimentResult {
        attribute sampleMass : MassValue;
        attribute specificHeatCapacity : SpecificHeatValue;
        attribute initialTemperature : TemperatureValue;
        attribute finalTemperature : TemperatureValue;
        attribute totalEnergySupplied : EnergyValue;
        attribute experimentDuration : TimeValue;
        attribute averageTemperature : TemperatureValue;
        attribute temperatureChange : TemperatureValue;
    }

    item def CalibrationData {
        attribute chamberHeatCapacity : HeatCapacityValue;
        attribute sensorOffset : TemperatureValue;
        attribute calibrationDate : String;
    }

    // ===== Port Definitions =====

    port def ThermalInterfacePort {
        attribute temperature : TemperatureValue;
        out heatFlow : PowerValue;
    }

    port def TemperatureOutputPort {
        out reading : SensorReading;
    }

    port def HeaterControlPort {
        in command : HeaterCommand;
    }

    port def DataStreamPort {
        out record : DataRecord;
    }

    port def ResultOutputPort {
        out result : ExperimentResult;
    }

    port def OperatorCommandPort {
        in command : String;
        in mode : OperatingMode;
        in targetTemperature : TemperatureValue;
        in scanRate : TemperatureRateValue;
        in sampleMass : MassValue;
        in sampleMaterial : String;
        out status : String;
        out currentPhase : ExperimentPhase;
        out result : ExperimentResult;
    }

    // ===== Part Definitions =====

    part def SampleChamber {
        port thermalInterface : ThermalInterfacePort;

        attribute currentTemperature : TemperatureValue;
        attribute chamberHeatCapacity : HeatCapacityValue;
        attribute sample : Sample;
        attribute thermalTimeConstant : TimeValue;
        attribute maxOperatingTemperature : TemperatureValue;

        action def Equilibrate {
            in heatInput : PowerValue;
            in duration : TimeValue;
            in chamberHeatCapacity : HeatCapacityValue;
            out newTemperature : TemperatureValue;
        }

        action def LoadSample {
            in sampleToLoad : Sample;
            out loadedSample : Sample;
        }
    }

    part def TemperatureSensor {
        port temperatureOutput : TemperatureOutputPort;

        attribute responseTime : TimeValue;
        attribute accuracy : TemperatureValue;
        attribute measurementRangeMin : TemperatureValue;
        attribute measurementRangeMax : TemperatureValue;
        attribute resolution : TemperatureValue;
        attribute calibrationOffset : TemperatureValue;

        action def Measure {
            in chamberTemperature : TemperatureValue;
            in timestamp : TimeValue;
            out reading : SensorReading;
        }

        action def Calibrate {
            in referenceTemperature : TemperatureValue;
            out newOffset : TemperatureValue;
        }
    }

    part def HeatingElement {
        port controlInput : HeaterControlPort;
        port thermalOutput : ThermalInterfacePort;

        attribute maxPower : PowerValue;
        attribute currentPower : PowerValue;
        attribute efficiency : Real;
        attribute rampRate : PowerValue;
        attribute thermalMass : HeatCapacityValue;

        action def ApplyHeat {
            in powerCommand : PowerValue;
            in efficiency : Real;
            out heatFlow : PowerValue;
        }

        action def RampPower {
            in targetPower : PowerValue;
            in rampRate : PowerValue;
            out currentPower : PowerValue;
        }
    }

    part def ThermalInsulation {
        attribute thermalResistance : ThermalResistanceValue;
        attribute ambientTemperature : TemperatureValue;
        attribute heatLossRate : PowerValue;
        attribute insulationThickness : Real;
        attribute conductivity : Real;

        action def CalculateHeatLoss {
            in internalTemperature : TemperatureValue;
            in ambientTemp : TemperatureValue;
            in thermalResistance : ThermalResistanceValue;
            out heatLoss : PowerValue;
        }

        action def EvaluateInsulationEffectiveness {
            in heatLoss : PowerValue;
            in appliedPower : PowerValue;
            out effectiveness : Real;
        }
    }

    part def ControlUnit {
        port operatorInterface : OperatorCommandPort;
        port sensorInput : TemperatureOutputPort;
        port heaterOutput : HeaterControlPort;
        port dataOutput : DataStreamPort;
        port resultOutput : ResultOutputPort;

        attribute operatingMode : OperatingMode;
        attribute targetTemperature : TemperatureValue;
        attribute scanRate : TemperatureRateValue;
        attribute isRunning : Boolean;
        attribute proportionalGain : Real;
        attribute integralGain : Real;
        attribute derivativeGain : Real;
        attribute sampleMass : MassValue;
        attribute experimentStartTime : TimeValue;
        attribute currentPhase : ExperimentPhase;
        attribute accumulatedError : Real;
        attribute previousError : TemperatureValue;

        state def ControlStateMachine {
            entry; then Idle;

            state Idle {
                entry { operatorInterface.status = "Idle"; }
            }

            state Running {
                entry; then Initialization;

                state Initialization {
                    entry { operatorInterface.currentPhase = ExperimentPhase::initialization; }
                }

                state Equilibration {
                    entry { operatorInterface.currentPhase = ExperimentPhase::equilibration; }
                }

                state Measurement {
                    entry { operatorInterface.currentPhase = ExperimentPhase::measurement; }
                }

                transition Initialization to Equilibration
                    when operatorInterface.command == "equilibrate";

                transition Equilibration to Measurement
                    when sensorInput.reading.temperature == targetTemperature;

                transition Measurement to Equilibration
                    when operatingMode == OperatingMode::isothermal
                        and sensorInput.reading.temperature != targetTemperature;
            }

            state Stopped {
                entry { operatorInterface.status = "Stopped"; }
            }

            transition Idle to Running
                when operatorInterface.command == "start";

            transition Running to Stopped
                when operatorInterface.command == "stop";

            transition Stopped to Idle
                when operatorInterface.command == "reset";
        }

        action def RegulateTemperature {
            in currentTemperature : TemperatureValue;
            in target : TemperatureValue;
            in mode : OperatingMode;
            in proportionalGain : Real;
            in integralGain : Real;
            in derivativeGain : Real;
            in accumulatedError : Real;
            in previousError : TemperatureValue;
            out powerCommand : PowerValue;
            out newAccumulatedError : Real;
            out newPreviousError : TemperatureValue;
        }

        action def ComputeSpecificHeat {
            in dataRecords : DataRecord[0..*];
            in sampleMass : MassValue;
            in chamberHeatCapacity : HeatCapacityValue;
            out specificHeat : SpecificHeatValue;
            out totalEnergy : EnergyValue;
            out temperatureChange : TemperatureValue;
        }

        action def GenerateResult {
            in specificHeat : SpecificHeatValue;
            in totalEnergy : EnergyValue;
            in temperatureChange : TemperatureValue;
            in sampleMass : MassValue;
            in initialTemp : TemperatureValue;
            in finalTemp : TemperatureValue;
            in duration : TimeValue;
            out result : ExperimentResult;
        }
    }

    part def DataAcquisitionSystem {
        port dataInput : DataStreamPort;
        port sensorInput : TemperatureOutputPort;
        port heaterInput : HeaterControlPort;
        port resultOutput : ResultOutputPort;

        attribute samplingRate : FrequencyValue;
        attribute dataLog : DataRecord[0..*];
        attribute bufferSize : Integer;
        attribute recordCount : Integer;
        attribute isLogging : Boolean;

        action def LogData {
            in timestamp : TimeValue;
            in temperature : TemperatureValue;
            in heaterPower : PowerValue;
            in phase : ExperimentPhase;
            out record : DataRecord;
        }

        action def CompileResults {
            in log : DataRecord[0..*];
            in sampleMass : MassValue;
            in chamberHeatCapacity : HeatCapacityValue;
            out result : ExperimentResult;
        }

        action def ExportData {
            in log : DataRecord[0..*];
            in result : ExperimentResult;
            out exportPath : String;
        }

        action def ClearLog {
            out clearedLog : DataRecord[0..*];
        }
    }

    // ===== Calculation Definitions =====

    calc def SpecificHeatCalculation {
        in totalEnergy : EnergyValue;
        in sampleMass : MassValue;
        in temperatureChange : TemperatureValue;
        in chamberHeatCapacity : HeatCapacityValue;
        out specificHeat : SpecificHeatValue;
    }

    calc def HeatLossCalculation {
        in internalTemp : TemperatureValue;
        in ambientTemp : TemperatureValue;
        in thermalResistance : ThermalResistanceValue;
        out heatLoss : PowerValue;
    }

    calc def PIDControllerCalculation {
        in currentTemp : TemperatureValue;
        in targetTemp : TemperatureValue;
        in kp : Real;
        in ki : Real;
        in kd : Real;
        in integralError : Real;
        in previousError : TemperatureValue;
        out powerCommand : PowerValue;
        out newIntegralError : Real;
        out newPreviousError : TemperatureValue;
    }

    // ===== Top-Level Assembly =====

    part def Calorimeter {
        part sampleChamber : SampleChamber {
            attribute chamberHeatCapacity : HeatCapacityValue = 50.0;
            attribute maxOperatingTemperature : TemperatureValue = 1273.0;
            attribute thermalTimeConstant : TimeValue = 2.5;
        }

        part temperatureSensor : TemperatureSensor {
            attribute responseTime : TimeValue = 0.001;
            attribute accuracy : TemperatureValue = 0.01;
            attribute measurementRangeMin : TemperatureValue = 73.0;
            attribute measurementRangeMax : TemperatureValue = 1273.0;
            attribute resolution : TemperatureValue = 0.001;
            attribute calibrationOffset : TemperatureValue = 0.0;
        }

        part heatingElement : HeatingElement {
            attribute maxPower : PowerValue = 100.0;
            attribute efficiency : Real = 0.95;
            attribute rampRate : PowerValue = 10.0;
            attribute thermalMass : HeatCapacityValue = 5.0;
        }

        part thermalInsulation : ThermalInsulation {
            attribute thermalResistance : ThermalResistanceValue = 1000.0;
            attribute ambientTemperature : TemperatureValue = 293.15;
            attribute insulationThickness : Real = 0.05;
            attribute conductivity : Real = 0.04;
        }

        part controlUnit : ControlUnit {
            attribute proportionalGain : Real = 10.0;
            attribute integralGain : Real = 0.1;
            attribute derivativeGain : Real = 1.0;
        }

        part dataAcquisition : DataAcquisitionSystem {
            attribute samplingRate : FrequencyValue = 1000.0;
            attribute bufferSize : Integer = 1000000;
        }

        // Connections
        connection temperatureSensor.temperatureOutput to controlUnit.sensorInput;
        connection controlUnit.heaterOutput to heatingElement.controlInput;
        connection heatingElement.thermalOutput to sampleChamber.thermalInterface;
        connection temperatureSensor.temperatureOutput to dataAcquisition.sensorInput;
        connection controlUnit.heaterOutput to dataAcquisition.heaterInput;
        connection controlUnit.dataOutput to dataAcquisition.dataInput;
        connection controlUnit.resultOutput to dataAcquisition.resultOutput;
    }

    // ===== Requirements =====

    requirement def TemperatureAccuracyRequirement {
        doc "The temperature sensor shall measure temperature with accuracy better than 0.1 K across the full operating range.";
        attribute maxError : TemperatureValue = 0.1;
        subject temperatureSensor : TemperatureSensor;
        constraint { temperatureSensor.accuracy <= maxError }
    }

    requirement def ThermalInsulationRequirement {
        doc "The thermal insulation shall limit heat loss to less than 0.01 W under nominal operating conditions.";
        attribute maxHeatLoss : PowerValue = 0.01;
        subject thermalInsulation : ThermalInsulation;
        constraint { thermalInsulation.heatLossRate <= maxHeatLoss }
    }

    requirement def SamplingRateRequirement {
        doc "The data acquisition system shall sample at a rate of at least 1000 Hz to capture rapid thermal transients.";
        attribute minSamplingRate : FrequencyValue = 1000.0;
        subject dataAcquisition : DataAcquisitionSystem;
        constraint { dataAcquisition.samplingRate >= minSamplingRate }
    }

    requirement def SensorResponseTimeRequirement {
        doc "The temperature sensor shall have a response time less than 1 millisecond to ensure accurate tracking of temperature changes.";
        attribute maxResponseTime : TimeValue = 0.001;
        subject temperatureSensor : TemperatureSensor;
        constraint { temperatureSensor.responseTime <= maxResponseTime }
    }

    requirement def SpecificHeatCalculationRequirement {
        doc "The system shall automatically calculate specific heat capacity from collected experimental data and known sample mass, accounting for chamber heat capacity.";
        subject controlUnit : ControlUnit;
        subject dataAcquisition : DataAcquisitionSystem;
    }

    requirement def HeaterPowerRequirement {
        doc "The heating element shall be capable of supplying up to 100 W of power with at least 95% efficiency.";
        attribute requiredMaxPower : PowerValue = 100.0;
        attribute minEfficiency : Real = 0.95;
        subject heatingElement : HeatingElement;
        constraint { heatingElement.maxPower >= requiredMaxPower }
        constraint { heatingElement.efficiency >= minEfficiency }
    }

    requirement def OperatingModeRequirement {
        doc "The control unit shall support isothermal and adiabatic operating modes, maintaining or preventing heat exchange as specified.";
        subject controlUnit : ControlUnit;
    }

    requirement def DataIntegrityRequirement {
        doc "The data acquisition system shall log continuous data records including timestamps, temperature readings, and heater power levels throughout the experiment.";
        subject dataAcquisition : DataAcquisitionSystem;
    }

    requirement def MeasurementRangeRequirement {
        doc "The calorimeter shall operate over a temperature range of 73 K to 1273 K.";
        attribute minTemp : TemperatureValue = 73.0;
        attribute maxTemp : TemperatureValue = 1273.0;
        subject temperatureSensor : TemperatureSensor;
        constraint { temperatureSensor.measurementRangeMin <= minTemp }
        constraint { temperatureSensor.measurementRangeMax >= maxTemp }
    }

    // ===== Requirement Satisfaction =====

    satisfaction of TemperatureAccuracyRequirement by calorimeter.temperatureSensor;
    satisfaction of ThermalInsulationRequirement by calorimeter.thermalInsulation;
    satisfaction of SamplingRateRequirement by calorimeter.dataAcquisition;
    satisfaction of SensorResponseTimeRequirement by calorimeter.temperatureSensor;
    satisfaction of SpecificHeatCalculationRequirement by calorimeter.controlUnit;
    satisfaction of HeaterPowerRequirement by calorimeter.heatingElement;
    satisfaction of OperatingModeRequirement by calorimeter.controlUnit;
    satisfaction of DataIntegrityRequirement by calorimeter.dataAcquisition;
    satisfaction of MeasurementRangeRequirement by calorimeter.temperatureSensor;
}
