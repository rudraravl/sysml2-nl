package OrificePlateFlowMeasurementSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value type PressureValue :> Real { unit "Pa"; }
    value type PressureDifferenceValue :> Real { unit "Pa"; }
    value type VolumeFlowRateValue :> Real { unit "m3/s"; }
    value type MassFlowRateValue :> Real { unit "kg/s"; }
    value type DensityValue :> Real { unit "kg/m3"; }
    value type DynamicViscosityValue :> Real { unit "Pa.s"; }
    value type DiameterValue :> Real { unit "m"; }
    value type AreaValue :> Real { unit "m2"; }
    value type CurrentValue :> Real { unit "mA"; }
    value type TemperatureValue :> Real { unit "K"; }
    value type TimeValue :> Real { unit "s"; }
    value type VolumeValue :> Real { unit "m3"; }
    value type MassValue :> Real { unit "kg"; }
    value type DimensionlessValue :> Real { unit "1"; }

    // ===== Item Types =====
    item def ProcessFluid {
        attribute density : DensityValue;
        attribute viscosity : DynamicViscosityValue;
        attribute temperature : TemperatureValue;
        attribute name : String;
    }

    item def PressureSample {
        attribute value : PressureValue;
        attribute timestamp : TimeValue;
        attribute location : String;
    }

    item def DifferentialPressureReading {
        attribute value : PressureDifferenceValue;
        attribute timestamp : TimeValue;
    }

    item def FlowData {
        attribute volumetricFlowRate : VolumeFlowRateValue;
        attribute massFlowRate : MassFlowRateValue;
        attribute accumulatedVolume : VolumeValue;
        attribute accumulatedMass : MassValue;
        attribute timestamp : TimeValue;
        attribute valid : Boolean;
    }

    item def SystemCommand {
        attribute commandType : String;
        attribute parameter : String;
    }

    // ===== Port Definitions =====
    port def FluidFlowPort {
        out item fluid : ProcessFluid;
    }

    port def PressureTapPort {
        out item pressure : PressureSample;
    }

    port def ElectricalSignalPort {
        out item current : CurrentValue;
    }

    port def DataPort {
        out item data : FlowData;
        in item command : SystemCommand;
    }

    // ===== Part Definitions =====

    part def Pipeline {
        attribute innerDiameter : DiameterValue;
        attribute length : DiameterValue;
        attribute material : String;
        attribute roughness : DimensionlessValue;
        port inlet : FluidFlowPort;
        port outlet : FluidFlowPort;
    }

    part def FlowConditioner {
        attribute tubeCount : Integer;
        attribute tubeDiameter : DiameterValue;
        attribute length : DiameterValue;
        attribute material : String;
        port inflow : FluidFlowPort;
        port outflow : FluidFlowPort;

        action def ConditionFlow {
            in fluidIn : ProcessFluid;
            out fluidOut : ProcessFluid;
            doc "Smooths turbulence and creates a uniform flow profile upstream of the orifice plate.";
        }
    }

    part def OrificePlate {
        attribute plateThickness : DiameterValue;
        attribute orificeDiameter : DiameterValue;
        attribute pipeDiameter : DiameterValue;
        attribute betaRatio : DimensionlessValue;
        attribute dischargeCoefficient : DimensionlessValue;
        attribute material : String;
        attribute edgeSharpness : DimensionlessValue;

        port inflow : FluidFlowPort;
        port outflow : FluidFlowPort;
        port upstreamTapPoint : PressureTapPort;
        port downstreamTapPoint : PressureTapPort;

        action def GeneratePressureDrop {
            in fluidIn : ProcessFluid;
            out fluidOut : ProcessFluid;
            out upstreamPressure : PressureSample;
            out downstreamPressure : PressureSample;
            doc "Forces fluid through the smaller orifice opening, increasing velocity and producing a measurable pressure drop.";
        }
    }

    part def PressureTap {
        attribute location : String;
        attribute tapDiameter : DiameterValue;
        attribute tapType : String;
        port pressureInput : PressureTapPort;
        port pressureOutput : PressureTapPort;

        action def SensePressure {
            in pressureIn : PressureSample;
            out pressureOut : PressureSample;
            doc "Transmits fluid pressure from the pipe wall tap to the differential pressure transmitter.";
        }
    }

    part def DPTransmitter {
        attribute rangeMin : PressureDifferenceValue;
        attribute rangeMax : PressureDifferenceValue;
        attribute accuracy : DimensionlessValue;
        attribute outputSignalMin : CurrentValue;
        attribute outputSignalMax : CurrentValue;
        attribute supplyVoltage : Real;
        attribute calibrated : Boolean;

        port highPressureInput : PressureTapPort;
        port lowPressureInput : PressureTapPort;
        port electricalOutput : ElectricalSignalPort;

        action def ConvertPressureToCurrent {
            in highPressure : PressureSample;
            in lowPressure : PressureSample;
            out current : CurrentValue;
            doc "Senses the differential pressure across the orifice plate and converts it into a standardized 4-20 mA electrical signal.";
        }

        action def ZeroCalibrate {
            doc "Adjusts transmitter output at zero differential pressure.";
        }

        action def SpanCalibrate {
            doc "Adjusts transmitter output at full-scale differential pressure.";
        }
    }

    part def FlowComputer {
        attribute fluidDensity : DensityValue;
        attribute fluidViscosity : DynamicViscosityValue;
        attribute pipeDiameter : DiameterValue;
        attribute orificeDiameter : DiameterValue;
        attribute dischargeCoefficient : DimensionlessValue;
        attribute expansibilityFactor : DimensionlessValue;
        attribute calculationInterval : TimeValue;
        attribute accumulatedVolume : VolumeValue;
        attribute accumulatedMass : MassValue;
        attribute orificeArea : AreaValue;

        port signalInput : ElectricalSignalPort;
        port dataOutput : DataPort;

        action def CalculateFlowRates {
            in current : CurrentValue;
            in dpRangeMin : PressureDifferenceValue;
            in dpRangeMax : PressureDifferenceValue;
            out flowData : FlowData;
            doc "Uses the measured differential pressure, fluid properties, and orifice geometry to calculate volumetric and mass flow rates via the ISO 5167 orifice equation.";
        }

        action def AccumulateTotals {
            in flowData : FlowData;
            in deltaTime : TimeValue;
            out updatedVolume : VolumeValue;
            out updatedMass : MassValue;
            doc "Integrates instantaneous flow rates over time to compute total volume and mass passed through the pipe.";
        }

        action def ValidateMeasurement {
            in flowData : FlowData;
            out valid : Boolean;
            doc "Validates the measurement against configured range limits and plausibility checks.";
        }
    }

    part def FlowIndicator {
        attribute displayType : String;
        attribute displayResolution : DimensionlessValue;
        attribute backlightEnabled : Boolean;
        port dataInput : DataPort;

        action def DisplayFlow {
            in data : FlowData;
            doc "Provides local display of volumetric flow rate, mass flow rate, and accumulated totals.";
        }
    }

    // ===== Connection Definitions =====
    connection def FluidConnection {
        end : FluidFlowPort;
        end : FluidFlowPort;
    }

    connection def PressureConnection {
        end : PressureTapPort;
        end : PressureTapPort;
    }

    connection def ElectricalConnection {
        end : ElectricalSignalPort;
        end : ElectricalSignalPort;
    }

    connection def DataConnection {
        end : DataPort;
        end : DataPort;
    }

    // ===== State Machine Definition =====
    state def SystemOperationStates {
        attribute initialized : Boolean;
        attribute calibrated : Boolean;
        attribute measuring : Boolean;

        initial state Initialization {
            doc "Perform power-on self-test, load configuration parameters, and verify component communication.";
            entry action {
                // Run self-diagnostic on DP transmitter, flow computer, and indicator
            }
            transition to Calibration on initComplete;
        }

        state Calibration {
            doc "Perform zero and span calibration of the DP transmitter against known pressure references.";
            entry action {
                // Execute zero and span calibration routines
            }
            transition to Standby on calibrationComplete;
            transition to Initialization on calibrationFailed;
        }

        state Standby {
            doc "Hold the system in a ready state with no active measurement output.";
            entry action {
                // Maintain readiness; await measurement start command
            }
            transition to MeasurementCycle on startMeasurement;
            transition to Calibration on recalibrate;
        }

        state MeasurementCycle {
            doc "Continuously acquire, compute, validate, and output flow data.";
            entry action {
                // Enter continuous measurement loop
            }

            state Acquiring {
                doc "Acquire pressure samples from the upstream and downstream pressure taps via the DP transmitter.";
                entry action {
                    // Sample high and low pressure readings
                }
                transition to Computing on samplesAcquired;
            }

            state Computing {
                doc "Calculate volumetric and mass flow rates and accumulate totals using the orifice equation.";
                entry action {
                    // Execute flow rate and totalization calculations
                }
                transition to Validating on computationComplete;
            }

            state Validating {
                doc "Validate the computed flow data against range limits and plausibility checks.";
                entry action {
                    // Check measurement against configured bounds
                }
                transition to Outputting on validationPassed;
                transition to Standby on validationFailed;
            }

            state Outputting {
                doc "Transmit validated flow data to the local flow indicator and the central plant control system.";
                entry action {
                    // Send FlowData to indicator and plant interface
                }
                transition to Acquiring on outputComplete;
            }

            transition to Standby on stopMeasurement;
        }
    }

    // ===== Top-Level System =====
    part def OrificePlateFlowMeasurementSystem {
        attribute systemId : String;
        attribute installationDate : String;
        attribute manufacturer : String;
        attribute measurementError : DimensionlessValue;

        port processInlet : FluidFlowPort;
        port processOutlet : FluidFlowPort;
        port plantInterface : DataPort;

        part pipeline : Pipeline {
            :>> innerDiameter = 0.1;
            :>> length = 2.0;
            :>> material = "StainlessSteel";
            :>> roughness = 0.000045;
        }

        part flowConditioner : FlowConditioner {
            :>> tubeCount = 19;
            :>> tubeDiameter = 0.015;
            :>> length = 0.5;
            :>> material = "StainlessSteel";
        }

        part orificePlate : OrificePlate {
            :>> plateThickness = 0.003;
            :>> orificeDiameter = 0.05;
            :>> pipeDiameter = 0.1;
            :>> betaRatio = 0.5;
            :>> dischargeCoefficient = 0.61;
            :>> material = "StainlessSteel316";
            :>> edgeSharpness = 0.99;
        }

        part upstreamTap : PressureTap {
            :>> location = "Upstream";
            :>> tapDiameter = 0.006;
            :>> tapType = "CornerTap";
        }

        part downstreamTap : PressureTap {
            :>> location = "Downstream";
            :>> tapDiameter = 0.006;
            :>> tapType = "CornerTap";
        }

        part dpTransmitter : DPTransmitter {
            :>> rangeMin = 0.0;
            :>> rangeMax = 50000.0;
            :>> accuracy = 0.005;
            :>> outputSignalMin = 4.0;
            :>> outputSignalMax = 20.0;
            :>> supplyVoltage = 24.0;
            :>> calibrated = false;
        }

        part flowComputer : FlowComputer {
            :>> fluidDensity = 998.0;
            :>> fluidViscosity = 0.001;
            :>> pipeDiameter = 0.1;
            :>> orificeDiameter = 0.05;
            :>> dischargeCoefficient = 0.61;
            :>> expansibilityFactor = 1.0;
            :>> calculationInterval = 1.0;
            :>> accumulatedVolume = 0.0;
            :>> accumulatedMass = 0.0;
            :>> orificeArea = 0.0019635;
        }

        part flowIndicator : FlowIndicator {
            :>> displayType = "LCD";
            :>> displayResolution = 0.001;
            :>> backlightEnabled = true;
        }

        // Fluid flow connections through the measurement assembly
        connection fluidConn1 : FluidConnection connect processInlet to pipeline.inlet;
        connection fluidConn2 : FluidConnection connect pipeline.outlet to flowConditioner.inflow;
        connection fluidConn3 : FluidConnection connect flowConditioner.outflow to orificePlate.inflow;
        connection fluidConn4 : FluidConnection connect orificePlate.outflow to processOutlet;

        // Pressure tap connections from orifice plate tap points through taps to DP transmitter
        connection pressureConn1 : PressureConnection connect orificePlate.upstreamTapPoint to upstreamTap.pressureInput;
        connection pressureConn2 : PressureConnection connect orificePlate.downstreamTapPoint to downstreamTap.pressureInput;
        connection pressureConn3 : PressureConnection connect upstreamTap.pressureOutput to dpTransmitter.highPressureInput;
        connection pressureConn4 : PressureConnection connect downstreamTap.pressureOutput to dpTransmitter.lowPressureInput;

        // Electrical signal from DP transmitter to flow computer
        connection signalConn : ElectricalConnection connect dpTransmitter.electricalOutput to flowComputer.signalInput;

        // Data connections from flow computer to indicator and plant control
        connection dataConn1 : DataConnection connect flowComputer.dataOutput to flowIndicator.dataInput;
        connection dataConn2 : DataConnection connect flowComputer.dataOutput to plantInterface;

        // Exhibit system operational state machine
        exhibit state systemOperation : SystemOperationStates;
    }

    // ===== Requirements =====

    requirement def MeasurementAccuracyRequirement {
        doc "The system shall measure volumetric and mass flow rates within the specified maximum error.";
        attribute maxError : DimensionlessValue = 0.01;
        subject system : OrificePlateFlowMeasurementSystem;
        require { system.measurementError <= maxError; }
    }

    requirement def PressureDropRangeRequirement {
        doc "The DP transmitter shall support the full expected differential pressure range across the orifice plate.";
        attribute minDP : PressureDifferenceValue = 100.0;
        attribute maxDP : PressureDifferenceValue = 100000.0;
        subject transmitter : DPTransmitter;
        require { transmitter.rangeMin <= minDP and transmitter.rangeMax >= maxDP; }
    }

    requirement def SignalInterfaceRequirement {
        doc "The DP transmitter shall produce a standardized 4-20 mA current loop output signal.";
        attribute minCurrent : CurrentValue = 4.0;
        attribute maxCurrent : CurrentValue = 20.0;
        subject transmitter : DPTransmitter;
        require { transmitter.outputSignalMin == minCurrent and transmitter.outputSignalMax == maxCurrent; }
    }

    requirement def FlowConditionerRequirement {
        doc "A flow conditioner shall be installed upstream of the orifice plate to smooth turbulence and produce a uniform flow profile.";
        attribute minTubeCount : Integer = 1;
        subject conditioner : FlowConditioner;
        require { conditioner.tubeCount >= minTubeCount; }
    }

    requirement def OrificeGeometryRequirement {
        doc "The orifice plate beta ratio shall be within the standard range for accurate differential pressure measurement.";
        attribute minBeta : DimensionlessValue = 0.2;
        attribute maxBeta : DimensionlessValue = 0.7;
        subject plate : OrificePlate;
        require { plate.betaRatio >= minBeta and plate.betaRatio <= maxBeta; }
    }

    requirement def DischargeCoefficientRequirement {
        doc "The orifice plate discharge coefficient shall fall within the standard range for sharp-edged orifice plates.";
        attribute minCd : DimensionlessValue = 0.59;
        attribute maxCd : DimensionlessValue = 0.65;
        subject plate : OrificePlate;
        require { plate.dischargeCoefficient >= minCd and plate.dischargeCoefficient <= maxCd; }
    }

    requirement def TotalAccumulationRequirement {
        doc "The flow computer shall maintain non-negative accumulated volume and mass totals.";
        subject computer : FlowComputer;
        require { computer.accumulatedVolume >= 0.0 and computer.accumulatedMass >= 0.0; }
    }

    requirement def SystemStateRequirement {
        doc "The system shall support initialization, calibration, standby, and continuous measurement cycle states.";
        subject system : OrificePlateFlowMeasurementSystem;
        require { system.systemOperation.initialized == true; }
    }

    requirement def DualPressureTapRequirement {
        doc "Two pressure taps shall be installed, one upstream and one downstream of the orifice plate, feeding high and low pressures to the DP transmitter.";
        subject system : OrificePlateFlowMeasurementSystem;
        require { system.upstreamTap.location == "Upstream" and system.downstreamTap.location == "Downstream"; }
    }

    requirement def FlowDataOutputRequirement {
        doc "The flow computer shall output flow data containing both volumetric and mass flow rates plus accumulated totals to the flow indicator and plant control system.";
        subject system : OrificePlateFlowMeasurementSystem;
        require { system.flowComputer.dataOutput.data.volumetricFlowRate >= 0.0 and system.flowComputer.dataOutput.data.massFlowRate >= 0.0; }
    }
}
