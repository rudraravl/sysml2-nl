package PipingSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQ::MassDensityValue;
    import SI::Meter;
    import SI::Pascal;
    import SI::CubicMeterPerSecond;
    import SI::MeterPerSecond;
    import SI::Degree;
    import SI::Kilogram;
    import SI::Second;

    // ---- Value Types ----
    value def Diameter :> Real { unit = "m"; }
    value def PipeLength :> Real { unit = "m"; }
    value def TaperAngle :> Real { unit = "deg"; }
    value def PressureValue :> Real { unit = "Pa"; }
    value def VolumeFlowRateValue :> Real { unit = "m3/s"; }
    value def VelocityValue :> Real { unit = "m/s"; }
    value def MassFlowRateValue :> Real { unit = "kg/s"; }
    value def DensityValue :> Real { unit = "kg/m3"; }
    value def AreaValue :> Real { unit = "m2"; }

    // ---- Item Types ----
    item def Fluid {
        attribute density : DensityValue;
        attribute dynamicViscosity : Real;
    }

    // ---- Port Definitions ----
    port def FluidPort {
        out item flow : Fluid;
        attribute pressure : PressureValue;
        attribute volumeFlowRate : VolumeFlowRateValue;
        attribute velocity : VelocityValue;
    }

    // ---- Part Definitions ----
    part def PipeSegment {
        attribute diameter : Diameter;
        attribute length : PipeLength;
        port inlet : FluidPort;
        port outlet : FluidPort;
    }

    part def ConcentricReducer {
        attribute inletDiameter : Diameter;
        attribute outletDiameter : Diameter;
        attribute taperAngle : TaperAngle;
        attribute reducerLength : PipeLength;
        port inlet : FluidPort;
        port outlet : FluidPort;

        action def ComputeOutletVelocity {
            in inletArea : AreaValue;
            in outletArea : AreaValue;
            in inletVelocity : VelocityValue;
            out outletVelocity : VelocityValue;
        }

        action def ComputePressureDrop {
            in inletVelocity : VelocityValue;
            in outletVelocity : VelocityValue;
            in fluidDensity : DensityValue;
            out pressureDrop : PressureValue;
        }

        perform action transitionBehavior {
            // Continuity: A1*v1 = A2*v2
            in inletArea : AreaValue = 3.14159 * (inletDiameter/2)^2;
            in outletArea : AreaValue = 3.14159 * (outletDiameter/2)^2;
            out computedOutletVelocity : VelocityValue = (inletArea * inlet.velocity) / outletArea;
            // Bernoulli approximation: dp = 0.5 * rho * (v2^2 - v1^2)
            out computedPressureDrop : PressureValue = 0.5 * inlet.flow.density * (computedOutletVelocity^2 - inlet.velocity^2);
        }
    }

    part def FlowMeter {
        attribute measuredFlowRate : VolumeFlowRateValue;
        port sensorPort : FluidPort;
        action def MeasureFlow {
            in flow : Fluid;
            out reading : VolumeFlowRateValue;
        }
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        port sensorPort : FluidPort;
        action def MeasurePressure {
            in flow : Fluid;
            out reading : PressureValue;
        }
    }

    // ---- Requirements ----
    requirement def ReducerPerformanceReq {
        subject : PipingSubsystem;
        requirement {
            doc "The concentric reducer shall smoothly transition fluid from a larger diameter to a smaller diameter while maintaining flow continuity."
        }
    }

    requirement def MassConservationReq {
        subject : ConcentricReducer;
        attribute inletMassFlow : MassFlowRateValue;
        attribute outletMassFlow : MassFlowRateValue;
        requirement {
            doc "The mass flow rate entering the reducer shall equal the mass flow rate exiting the reducer."
            constraint { inletMassFlow == outletMassFlow }
        }
    }

    requirement def VelocityIncreaseReq {
        subject : ConcentricReducer;
        attribute inletVelocity : VelocityValue;
        attribute outletVelocity : VelocityValue;
        requirement {
            doc "The fluid velocity at the reducer outlet shall be greater than the velocity at the inlet."
            constraint { outletVelocity > inletVelocity }
        }
    }

    requirement def PressureLossReq {
        subject : ConcentricReducer;
        attribute inletPressure : PressureValue;
        attribute outletPressure : PressureValue;
        attribute maxAllowablePressureDrop : PressureValue = 50000.0;
        requirement {
            doc "The pressure drop across the reducer shall not exceed the maximum allowable pressure drop."
            constraint { (inletPressure - outletPressure) <= maxAllowablePressureDrop }
        }
    }

    requirement def TaperAngleReq {
        subject : ConcentricReducer;
        attribute taperAngle : TaperAngle;
        attribute minAngle : TaperAngle = 5.0;
        attribute maxAngle : TaperAngle = 30.0;
        requirement {
            doc "The reducer taper angle shall be within the range that prevents excessive turbulence."
            constraint { taperAngle >= minAngle and taperAngle <= maxAngle }
        }
    }

    // ---- Composite System ----
    part def PipingSubsystem {
        attribute systemFluid : Fluid;

        part upstreamPipe : PipeSegment {
            attribute diameter : Diameter = 0.5;
            attribute length : PipeLength = 2.0;
        }

        part reducer : ConcentricReducer {
            attribute inletDiameter : Diameter = 0.5;
            attribute outletDiameter : Diameter = 0.25;
            attribute taperAngle : TaperAngle = 15.0;
            attribute reducerLength : PipeLength = 0.6;
        }

        part downstreamPipe : PipeSegment {
            attribute diameter : Diameter = 0.25;
            attribute length : PipeLength = 2.0;
        }

        part inletFlowMeter : FlowMeter;
        part outletFlowMeter : FlowMeter;
        part inletPressureSensor : PressureSensor;
        part outletPressureSensor : PressureSensor;

        // Connections
        connection upstreamToReducer : FluidPort connect upstreamPipe.outlet to reducer.inlet;
        connection reducerToDownstream : FluidPort connect reducer.outlet to downstreamPipe.inlet;

        connection inletFlowMeterConnection : FluidPort connect reducer.inlet to inletFlowMeter.sensorPort;
        connection outletFlowMeterConnection : FluidPort connect reducer.outlet to outletFlowMeter.sensorPort;
        connection inletPressureConnection : FluidPort connect reducer.inlet to inletPressureSensor.sensorPort;
        connection outletPressureConnection : FluidPort connect reducer.outlet to outletPressureSensor.sensorPort;

        // Requirements satisfaction
        satisfy ReducerPerformanceReq {
            subject = PipingSubsystem::this;
        }

        satisfy MassConservationReq {
            subject = reducer;
            attribute inletMassFlow = reducer.inlet.flow.density * reducer.inlet.volumeFlowRate;
            attribute outletMassFlow = reducer.outlet.flow.density * reducer.outlet.volumeFlowRate;
        }

        satisfy VelocityIncreaseReq {
            subject = reducer;
            attribute inletVelocity = reducer.inlet.velocity;
            attribute outletVelocity = reducer.outlet.velocity;
        }

        satisfy PressureLossReq {
            subject = reducer;
            attribute inletPressure = reducer.inlet.pressure;
            attribute outletPressure = reducer.outlet.pressure;
        }

        satisfy TaperAngleReq {
            subject = reducer;
            attribute taperAngle = reducer.taperAngle;
        }

        // Monitoring State Machine
        state def MonitoringStates {
            entry action initialEntry {
                PipingSubsystem::this.inletFlowMeter.measuredFlowRate = 0.0;
                PipingSubsystem::this.outletFlowMeter.measuredFlowRate = 0.0;
                PipingSubsystem::this.inletPressureSensor.measuredPressure = 0.0;
                PipingSubsystem::this.outletPressureSensor.measuredPressure = 0.0;
            }

            state Idle {
                entry action {
                    PipingSubsystem::this.inletFlowMeter.measuredFlowRate = 0.0;
                    PipingSubsystem::this.outletFlowMeter.measuredFlowRate = 0.0;
                }
                transition to Monitoring when PipingSubsystem::this.upstreamPipe.inlet.flow != null;
            }

            state Monitoring {
                entry action {
                    PipingSubsystem::this.inletFlowMeter.MeasureFlow(PipingSubsystem::this.reducer.inlet.flow);
                    PipingSubsystem::this.outletFlowMeter.MeasureFlow(PipingSubsystem::this.reducer.outlet.flow);
                    PipingSubsystem::this.inletPressureSensor.MeasurePressure(PipingSubsystem::this.reducer.inlet.flow);
                    PipingSubsystem::this.outletPressureSensor.MeasurePressure(PipingSubsystem::this.reducer.outlet.flow);
                }
                do action verifyOperation {
                    if (PipingSubsystem::this.outletFlowMeter.measuredFlowRate > PipingSubsystem::this.inletFlowMeter.measuredFlowRate) {
                        // Velocity increase confirmed via continuity
                    }
                    if ((PipingSubsystem::this.inletPressureSensor.measuredPressure - PipingSubsystem::this.outletPressureSensor.measuredPressure) > 50000.0) {
                        // Pressure loss exceeds allowable limit
                    }
                }
                transition to FaultDetected when (PipingSubsystem::this.inletPressureSensor.measuredPressure - PipingSubsystem::this.outletPressureSensor.measuredPressure) > 50000.0;
                transition to Idle when PipingSubsystem::this.upstreamPipe.inlet.flow == null;
            }

            state FaultDetected {
                entry action {
                    // Alert operators of excessive pressure drop or anomaly
                }
                transition to Idle when PipingSubsystem::this.upstreamPipe.inlet.flow == null;
            }
        }

        perform monitoringBehavior : MonitoringStates;
    }
}
