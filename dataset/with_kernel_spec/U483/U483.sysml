package 'Concentric Reducer Piping System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Quantities::*;
    private import MeasurementReferences::*;

    package 'Piping Quantities' {
        private import Quantities::*;
        private import MeasurementReferences::*;
        private import ISQ::*;

        attribute def VolumeFlowRateUnit :> DerivedUnit {
            private attribute volPF : QuantityPowerFactor[1] { :>> quantity = Volume; :>> exponent = 1; }
            private attribute timePF : QuantityPowerFactor[1] { :>> quantity = Time; :>> exponent = -1; }
            attribute :>> quantityDimension { :>> quantityPowerFactors = (volPF, timePF); }
        }
        attribute def VolumeFlowRateValue :> ScalarQuantityValue {
            :>> num : Real;
            :>> mRef : VolumeFlowRateUnit;
        }
        attribute cubicMeterPerSecond : VolumeFlowRateUnit = m**3 / s;
    }

    package 'Fluid Domain' {
        item def Fluid {
            attribute density : MassDensityValue;
            attribute dynamicViscosity : Real;
            attribute temperature : TemperatureValue;
        }
        item def Liquid :> Fluid;
        item def Gas :> Fluid;
        item def Water :> Liquid {
            :>> density = 1000 [kg/m**3];
            :>> dynamicViscosity = 0.001;
            :>> temperature = 293.15 [K];
        }
    }

    package 'Piping Interface' {
        private import 'Piping Quantities'::*;
        private import 'Fluid Domain'::*;
        private import ISQ::*;

        port def FluidPort {
            attribute pressure : PressureValue;
            attribute volumetricFlowRate : VolumeFlowRateValue;
            attribute crossSectionalArea : AreaValue;
            attribute meanVelocity : SpeedValue;
            in item fluidFlow : Fluid;
        }
    }

    package 'Fluid Dynamics Calculations' {
        private import 'Piping Quantities'::*;
        private import 'Fluid Domain'::*;
        private import 'Piping Interface'::*;
        private import ISQ::*;

        calc def PipeCrossSectionArea {
            in diameter : LengthValue;
            return area : AreaValue = 3.14159265359 * (diameter / 2) ** 2;
        }

        calc def MeanFluidVelocity {
            in flowRate : VolumeFlowRateValue;
            in area : AreaValue;
            return velocity : SpeedValue = flowRate / area;
        }

        calc def MassFlowRateCalc {
            in density : MassDensityValue;
            in flowRate : VolumeFlowRateValue;
            return massFlowRate : MassFlowRateValue = density * flowRate;
        }

        calc def ReducerOutletVelocity {
            in inletArea : AreaValue;
            in inletVelocity : SpeedValue;
            in outletArea : AreaValue;
            return outletVelocity : SpeedValue = (inletArea * inletVelocity) / outletArea;
        }

        calc def BernoulliOutletPressure {
            in fluidDensity : MassDensityValue;
            in inletVelocity : SpeedValue;
            in outletVelocity : SpeedValue;
            in inletPressure : PressureValue;
            return outletPressure : PressureValue = inletPressure - (fluidDensity / 2) * (outletVelocity ** 2 - inletVelocity ** 2);
        }

        action def MonitorFlow {
            in sensorFlowPort : FluidPort;
            attribute measuredFlowRate : VolumeFlowRateValue;
        }

        action def MonitorPressure {
            in sensorPressurePort : FluidPort;
            attribute measuredPressure : PressureValue;
        }
    }

    package 'Piping Components' {
        private import 'Piping Quantities'::*;
        private import 'Piping Interface'::*;
        private import 'Fluid Domain'::*;
        private import 'Fluid Dynamics Calculations'::*;
        private import ISQ::*;

        part def PipingComponent {
            attribute nominalDiameter : LengthValue;
            attribute length : LengthValue;
            attribute material : String;
            attribute roughness : LengthValue;
            port fluidInPort : FluidPort;
            port fluidOutPort : ~FluidPort;
        }

        part def UpstreamPipe :> PipingComponent {
            :>> nominalDiameter = 0.3048 [m];
            :>> length = 5.0 [m];
            :>> material = "Carbon Steel";
            :>> roughness = 0.000045 [m];
        }

        part def DownstreamPipe :> PipingComponent {
            :>> nominalDiameter = 0.1524 [m];
            :>> length = 5.0 [m];
            :>> material = "Carbon Steel";
            :>> roughness = 0.000045 [m];
        }

        part def ConcentricReducer :> PipingComponent {
            attribute inletDiameter : LengthValue = 0.3048 [m];
            attribute outletDiameter : LengthValue = 0.1524 [m];
            attribute taperAngle : PlaneAngleValue = 15 [deg];
            attribute areaRatio : Real = (outletDiameter / inletDiameter) ** 2;
            :>> nominalDiameter = inletDiameter;
            :>> material = "Stainless Steel 316";
            :>> roughness = 0.000045 [m];

            calc inletCrossArea : PipeCrossSectionArea {
                in diameter = inletDiameter;
            }
            calc outletCrossArea : PipeCrossSectionArea {
                in diameter = outletDiameter;
            }
            calc computedOutletVelocity : ReducerOutletVelocity {
                in inletArea = inletCrossArea.area;
                in inletVelocity = fluidInPort.meanVelocity;
                in outletArea = outletCrossArea.area;
            }
            calc computedOutletPressure : BernoulliOutletPressure {
                in fluidDensity = fluidInPort.fluidFlow.density;
                in inletVelocity = fluidInPort.meanVelocity;
                in outletVelocity = computedOutletVelocity.outletVelocity;
                in inletPressure = fluidInPort.pressure;
            }
        }

        part def FlowMeter {
            attribute measurementRange : VolumeFlowRateValue;
            attribute accuracyPercent : Real;
            port fluidFlowPort : FluidPort;
            action monitorFlow : MonitorFlow;
        }

        part def PressureSensor {
            attribute measurementRange : PressureValue;
            attribute accuracyPercent : Real;
            port fluidFlowPort : FluidPort;
            action monitorPressure : MonitorPressure;
        }
    }

    package 'Monitoring' {
        private import 'Piping Interface'::*;
        private import 'Piping Quantities'::*;
        private import ISQ::*;

        state def ReducerOperatingState {
            attribute inletFlowRate : VolumeFlowRateValue;
            attribute outletFlowRate : VolumeFlowRateValue;
            attribute inletPressure : PressureValue;
            attribute outletPressure : PressureValue;
            attribute pressureDrop : PressureValue;
            attribute alarmThreshold : PressureValue = 50000 [Pa];

            state Idle;
            state Starting;
            state Steady;
            state Transient;
            state Alarm;

            transition idle_to_starting
                first Idle
                then Starting
                guard { inletFlowRate > 0 [cubicMeterPerSecond] }

            transition starting_to_steady
                first Starting
                then Steady
                guard { outletFlowRate == inletFlowRate }

            transition steady_to_transient
                first Steady
                then Transient
                guard { outletFlowRate != inletFlowRate }

            transition steady_to_alarm
                first Steady
                then Alarm
                guard { pressureDrop > alarmThreshold }

            transition transient_to_steady
                first Transient
                then Steady
                guard { outletFlowRate == inletFlowRate }

            transition steady_to_idle
                first Steady
                then Idle
                guard { inletFlowRate == 0 [cubicMeterPerSecond] }

            transition transient_to_idle
                first Transient
                then Idle
                guard { inletFlowRate == 0 [cubicMeterPerSecond] }

            transition alarm_to_idle
                first Alarm
                then Idle
                guard { inletFlowRate == 0 [cubicMeterPerSecond] }
        }
    }

    package 'Reducer Requirements' {
        private import 'Piping Quantities'::*;
        private import ISQ::*;

        requirement def MassConservationRequirement {
            attribute inletMassFlowRate : MassFlowRateValue;
            attribute outletMassFlowRate : MassFlowRateValue;
            require constraint { inletMassFlowRate == outletMassFlowRate }
        }

        requirement def PressureDropLimitRequirement {
            attribute actualPressureDrop : PressureValue;
            attribute maxPressureDrop : PressureValue;
            require constraint { actualPressureDrop <= maxPressureDrop }
        }

        requirement def VelocityIncreaseRequirement {
            attribute inletVelocity : SpeedValue;
            attribute outletVelocity : SpeedValue;
            require constraint { outletVelocity > inletVelocity }
        }

        requirement def TaperAngleDesignRequirement {
            attribute taperAngle : PlaneAngleValue;
            attribute minTaperAngle : PlaneAngleValue;
            attribute maxTaperAngle : PlaneAngleValue;
            require constraint { taperAngle >= minTaperAngle and taperAngle <= maxTaperAngle }
        }

        requirement massConservation : MassConservationRequirement;
        requirement pressureDropLimit : PressureDropLimitRequirement {
            :>> maxPressureDrop = 50000 [Pa];
        }
        requirement velocityIncrease : VelocityIncreaseRequirement;
        requirement taperAngleDesign : TaperAngleDesignRequirement {
            :>> minTaperAngle = 5 [deg];
            :>> maxTaperAngle = 30 [deg];
        }
    }

    package 'Piping System Composition' {
        private import 'Piping Components'::*;
        private import 'Piping Interface'::*;
        private import 'Fluid Domain'::*;
        private import 'Piping Quantities'::*;
        private import 'Reducer Requirements'::*;
        private import 'Monitoring'::*;
        private import ISQ::*;

        part pipingSystem : PipingComponent {
            :>> nominalDiameter = 0.3048 [m];
            :>> material = "Stainless Steel 316";

            part upstreamPipe : UpstreamPipe {
                port :>> fluidInPort {
                    :>> pressure = 200000 [Pa];
                    :>> volumetricFlowRate = 0.05 [cubicMeterPerSecond];
                    :>> crossSectionalArea = 0.073 [m**2];
                    :>> meanVelocity = 0.685 [m/s];
                }
                port :>> fluidOutPort {
                    :>> pressure = 200000 [Pa];
                    :>> volumetricFlowRate = 0.05 [cubicMeterPerSecond];
                    :>> crossSectionalArea = 0.073 [m**2];
                    :>> meanVelocity = 0.685 [m/s];
                }
            }
            part reducer : ConcentricReducer {
                :>> inletDiameter = 0.3048 [m];
                :>> outletDiameter = 0.1524 [m];
                :>> taperAngle = 15 [deg];
                port :>> fluidInPort {
                    :>> pressure = 200000 [Pa];
                    :>> volumetricFlowRate = 0.05 [cubicMeterPerSecond];
                    :>> crossSectionalArea = 0.073 [m**2];
                    :>> meanVelocity = 0.685 [m/s];
                }
                port :>> fluidOutPort {
                    :>> pressure = 196462 [Pa];
                    :>> volumetricFlowRate = 0.05 [cubicMeterPerSecond];
                    :>> crossSectionalArea = 0.0182 [m**2];
                    :>> meanVelocity = 2.747 [m/s];
                }
            }
            part downstreamPipe : DownstreamPipe {
                port :>> fluidInPort {
                    :>> pressure = 196462 [Pa];
                    :>> volumetricFlowRate = 0.05 [cubicMeterPerSecond];
                    :>> crossSectionalArea = 0.0182 [m**2];
                    :>> meanVelocity = 2.747 [m/s];
                }
                port :>> fluidOutPort {
                    :>> pressure = 196462 [Pa];
                    :>> volumetricFlowRate = 0.05 [cubicMeterPerSecond];
                    :>> crossSectionalArea = 0.0182 [m**2];
                    :>> meanVelocity = 2.747 [m/s];
                }
            }
            part inletFlowMeter : FlowMeter {
                :>> measurementRange = 1.0 [cubicMeterPerSecond];
                :>> accuracyPercent = 0.5;
            }
            part inletPressureSensor : PressureSensor {
                :>> measurementRange = 500000 [Pa];
                :>> accuracyPercent = 0.25;
            }
            part outletFlowMeter : FlowMeter {
                :>> measurementRange = 1.0 [cubicMeterPerSecond];
                :>> accuracyPercent = 0.5;
            }
            part outletPressureSensor : PressureSensor {
                :>> measurementRange = 500000 [Pa];
                :>> accuracyPercent = 0.25;
            }

            connect upstreamPipe.fluidOutPort to reducer.fluidInPort;
            connect reducer.fluidOutPort to downstreamPipe.fluidInPort;
            connect upstreamPipe.fluidOutPort to inletFlowMeter.fluidFlowPort;
            connect upstreamPipe.fluidOutPort to inletPressureSensor.fluidFlowPort;
            connect downstreamPipe.fluidInPort to outletFlowMeter.fluidFlowPort;
            connect downstreamPipe.fluidInPort to outletPressureSensor.fluidFlowPort;

            exhibit operatingState : ReducerOperatingState {
                in inletFlowRate = inletFlowMeter.fluidFlowPort.volumetricFlowRate;
                in outletFlowRate = outletFlowMeter.fluidFlowPort.volumetricFlowRate;
                in inletPressure = inletPressureSensor.fluidFlowPort.pressure;
                in outletPressure = outletPressureSensor.fluidFlowPort.pressure;
                in pressureDrop = inletPressure - outletPressure;
            }

            satisfy massConservation by reducer;
            satisfy pressureDropLimit by reducer;
            satisfy velocityIncrease by reducer;
            satisfy taperAngleDesign by reducer;
        }
    }
}
