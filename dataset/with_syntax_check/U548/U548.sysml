package PumpingSubsystemModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package ValueTypes {
        attribute def FlowRate :> Real;
        attribute def Pressure :> Real;
        attribute def RotationalSpeed :> Real;
        attribute def Power :> Real;
        attribute def Efficiency :> Real;
    }

    package Definitions {
        private import ValueTypes::*;

        item def Fluid {
            attribute density : Real;
            attribute viscosity : Real;
            attribute temperature : Real;
            attribute volume : Real;
        }

        port def FluidInPort {
            attribute inletPressure : Pressure;
            in item fluidIn : Fluid;
        }

        port def FluidOutPort {
            attribute outletPressure : Pressure;
            out item fluidOut : Fluid;
        }

        port def PowerPort {
            attribute powerSupplied : Power;
        }

        part def Inducer {
            attribute bladeCount : Integer;
            attribute diameter : Real;
            attribute rotationalSpeed : RotationalSpeed;
            attribute efficiency : Efficiency;
            attribute pressureRise : Pressure;

            port inducerInlet : FluidInPort;
            port inducerOutlet : FluidOutPort;

            perform action induceFluid : InduceFluid {
                in fluidInput = inducerInlet.fluidIn;
                in speed = rotationalSpeed;
                out fluidOutput = inducerOutlet.fluidOut;
            }

            assert constraint PressureIncrease {
                inducerOutlet.outletPressure > inducerInlet.inletPressure
            }
        }

        part def Impeller {
            attribute diameter : Real;
            attribute rotationalSpeed : RotationalSpeed;
            attribute efficiency : Efficiency;

            port impellerInlet : FluidInPort;
            port impellerOutlet : FluidOutPort;

            perform action impelFluid : ImpelFluid {
                in fluidInput = impellerInlet.fluidIn;
                in speed = rotationalSpeed;
                out fluidOutput = impellerOutlet.fluidOut;
            }
        }

        part def Motor {
            attribute ratedPower : Power;
            attribute operatingSpeed : RotationalSpeed;
            attribute efficiency : Efficiency;
            attribute currentDraw : Real;

            port powerInput : ~PowerPort;

            perform action driveShaft : DriveShaft;
        }

        part def Shaft {
            attribute diameter : Real;
            attribute length : Real;
            attribute torque : Real;
            attribute rotationalSpeed : RotationalSpeed;
        }

        part def Casing {
            attribute material : String;
            attribute maxPressureRating : Pressure;
            attribute inletDiameter : Real;
            attribute outletDiameter : Real;

            port casingInlet : FluidInPort;
            port casingOutlet : FluidOutPort;
        }

        part def Seal {
            attribute sealType : String;
            attribute leakageRate : FlowRate;
        }

        part def Bearing {
            attribute bearingType : String;
            attribute loadCapacity : Real;
        }

        part def Pump {
            attribute designFlowRate : FlowRate;
            attribute designPressureRise : Pressure;
            attribute overallEfficiency : Efficiency;
            attribute npshRequired : Pressure;

            port pumpInlet : FluidInPort;
            port pumpOutlet : FluidOutPort;
            port electricalInput : ~PowerPort;

            part inducer : Inducer {
                attribute :>> bladeCount = 4;
                attribute :>> efficiency = 0.82;
            }

            part impeller : Impeller {
                attribute :>> efficiency = 0.86;
            }

            part motor : Motor {
                attribute :>> efficiency = 0.90;
            }

            part shaft : Shaft;

            part casing : Casing;

            part mechanicalSeal : Seal {
                attribute :>> sealType = "Mechanical Face Seal";
            }

            part radialBearing : Bearing {
                attribute :>> bearingType = "Radial Ball Bearing";
            }

            part thrustBearing : Bearing {
                attribute :>> bearingType = "Thrust Ball Bearing";
            }

            flow of fluid : Fluid from pumpInlet.fluidIn to casing.casingInlet.fluidIn;
            flow of fluid : Fluid from casing.casingInlet.fluidIn to inducer.inducerInlet.fluidIn;
            flow of fluid : Fluid from inducer.inducerOutlet.fluidOut to impeller.impellerInlet.fluidIn;
            flow of fluid : Fluid from impeller.impellerOutlet.fluidOut to casing.casingOutlet.fluidOut;
            flow of fluid : Fluid from casing.casingOutlet.fluidOut to pumpOutlet.fluidOut;

            bind shaft.rotationalSpeed = motor.operatingSpeed;
            bind inducer.rotationalSpeed = shaft.rotationalSpeed;
            bind impeller.rotationalSpeed = shaft.rotationalSpeed;

            connect electricalInput to motor.powerInput;

            exhibit state pumpState : PumpOperatingStates;
        }

        part def SupplyTank {
            attribute capacity : Real;
            attribute currentLevel : Real;

            port tankOutlet : FluidOutPort;

            item storedFluid : Fluid {
                attribute :>> volume : Real;
            }
        }

        part def DischargeTank {
            attribute capacity : Real;
            attribute operatingPressure : Pressure;

            port tankInlet : FluidInPort;

            item receivedFluid : Fluid {
                attribute :>> volume : Real;
            }
        }

        part def PressureSensor {
            attribute measurementRange : Pressure;
            attribute accuracy : Real;

            port sensingPort;
            out attribute pressureReading : Pressure;
        }

        part def FlowSensor {
            attribute measurementRange : FlowRate;
            attribute accuracy : Real;

            port sensorInlet : FluidInPort;
            port sensorOutlet : FluidOutPort;
            out attribute flowReading : FlowRate;
        }

        part def ControlValve {
            attribute position : Real;
            attribute flowCoefficient : Real;

            port valveInlet : FluidInPort;
            port valveOutlet : FluidOutPort;
            in attribute controlSignal : Real;

            perform action adjustValve : AdjustValve;
        }

        action def InduceFluid {
            in fluidInput : Fluid;
            in speed : RotationalSpeed;
            out fluidOutput : Fluid;
        }

        action def ImpelFluid {
            in fluidInput : Fluid;
            in speed : RotationalSpeed;
            out fluidOutput : Fluid;
        }

        action def DriveShaft;

        action def AdjustValve;

        action def MonitorPressure {
            in pressureValue : Pressure;
            out status : String;
        }

        action def MonitorFlow {
            in flowValue : FlowRate;
            out status : String;
        }

        action def ControlPumpSystem {
            in targetFlowRate : FlowRate;
            in actualFlowRate : FlowRate;
            in dischargePressure : Pressure;
            out valveCommand : Real;

            first start;
            then merge monitorLoop;

            then action checkFlow : MonitorFlow {
                in flowValue = actualFlowRate;
            }

            then action checkPressure : MonitorPressure {
                in pressureValue = dischargePressure;
            }

            then decide;
                if actualFlowRate < targetFlowRate then increaseFlow;
                if actualFlowRate >= targetFlowRate then maintainFlow;

            action increaseFlow {
                out command : Real = valveCommand + 0.1;
            }
            then monitorLoop;

            action maintainFlow {
                out command : Real = valveCommand;
            }
            then monitorLoop;
        }

        state def PumpOperatingStates {
            entry; then off;

            state off;
            accept StartSignal then startup;

            state startup;
            accept AccelerateSignal then operating;

            state operating;
            accept StopSignal then shutdown;
            accept FaultDetected then faulted;

            state shutdown;
            accept at when speed <= 0.0 then off;

            state faulted;
            accept ResetSignal then off;

            attribute speed : Real;
        }

        requirement def InducerPerformanceRequirement {
            subject inducer : Inducer;

            require cavitationSuppression {
                doc /* The inducer shall suppress cavitation and reduce NPSH required by at least 25%. */
            }

            require inducerEfficiency {
                doc /* The inducer efficiency shall be at least 80% at design flow rate. */
            }

            require pressureBoost {
                doc /* The inducer shall provide positive pressure rise at all operating conditions. */
            }
        }

        requirement def PumpSystemRequirement {
            subject pump : Pump;

            require flowCapability {
                doc /* The pump shall deliver design flow rate within +/- 3% tolerance. */
            }

            require pressureCapability {
                doc /* The pump shall achieve design pressure rise at rated flow. */
            }

            require overallEfficiency {
                doc /* The pump overall efficiency shall be at least 72% at design point. */
            }

            require npshMargin {
                doc /* The pump NPSH required shall not exceed available NPSH minus 2 meters. */
            }
        }

        requirement def SystemReliabilityRequirement {
            doc /* The pumping subsystem shall operate continuously for at least 10000 hours between maintenance intervals. */
        }
    }

    package Usages {
        private import Definitions::*;

        part pumpingSubsystem {
            part supplyTank : SupplyTank {
                attribute :>> capacity = 8000.0;
                attribute :>> currentLevel = 4.2;

                item :>> storedFluid : Fluid {
                    attribute :>> density = 998.0;
                    attribute :>> viscosity = 0.001;
                    attribute :>> temperature = 25.0;
                    attribute :>> volume = 6500.0;
                }
            }

            part inletPressureSensor : PressureSensor {
                attribute :>> measurementRange = 600.0;
                attribute :>> accuracy = 0.25;
            }

            part mainPump : Pump {
                attribute :>> designFlowRate = 120.0;
                attribute :>> designPressureRise = 350.0;
                attribute :>> overallEfficiency = 0.75;
                attribute :>> npshRequired = 45.0;

                part :>> inducer {
                    attribute :>> diameter = 0.18;
                    attribute :>> rotationalSpeed = 2900.0;
                    attribute :>> pressureRise = 80.0;
                }

                part :>> impeller {
                    attribute :>> diameter = 0.28;
                    attribute :>> rotationalSpeed = 2900.0;
                }

                part :>> motor {
                    attribute :>> ratedPower = 42.0;
                    attribute :>> operatingSpeed = 2900.0;
                    attribute :>> currentDraw = 78.0;
                }

                part :>> casing {
                    attribute :>> material = "Stainless Steel 316L";
                    attribute :>> maxPressureRating = 1200.0;
                    attribute :>> inletDiameter = 0.12;
                    attribute :>> outletDiameter = 0.10;
                }

                part :>> shaft {
                    attribute :>> diameter = 0.05;
                    attribute :>> length = 0.8;
                    attribute :>> torque = 138.0;
                }

                part :>> mechanicalSeal {
                    attribute :>> leakageRate = 0.001;
                }
            }

            part dischargePressureSensor : PressureSensor {
                attribute :>> measurementRange = 1500.0;
                attribute :>> accuracy = 0.25;
            }

            part flowSensor : FlowSensor {
                attribute :>> measurementRange = 180.0;
                attribute :>> accuracy = 0.5;
            }

            part dischargeValve : ControlValve {
                attribute :>> position = 0.80;
                attribute :>> flowCoefficient = 135.0;
            }

            part dischargeTank : DischargeTank {
                attribute :>> capacity = 5000.0;
                attribute :>> operatingPressure = 320.0;

                item :>> receivedFluid : Fluid {
                    attribute :>> density = 998.0;
                    attribute :>> viscosity = 0.001;
                    attribute :>> temperature = 27.0;
                    attribute :>> volume = 3200.0;
                }
            }

            flow of fluid : Fluid 
                from supplyTank.tankOutlet.fluidOut 
                to mainPump.pumpInlet.fluidIn;

            flow of fluid : Fluid 
                from mainPump.pumpOutlet.fluidOut 
                to flowSensor.sensorInlet.fluidIn;

            flow of fluid : Fluid 
                from flowSensor.sensorOutlet.fluidOut 
                to dischargeValve.valveInlet.fluidIn;

            flow of fluid : Fluid 
                from dischargeValve.valveOutlet.fluidOut 
                to dischargeTank.tankInlet.fluidIn;

            perform action systemControl : ControlPumpSystem {
                in targetFlowRate = 120.0;
                in actualFlowRate = flowSensor.flowReading;
                in dischargePressure = dischargePressureSensor.pressureReading;
                out valveCommand = dischargeValve.controlSignal;
            }

            satisfy inducerReq : InducerPerformanceRequirement {
                subject inducer = mainPump.inducer;
            }

            satisfy pumpReq : PumpSystemRequirement {
                subject pump = mainPump;
            }

            satisfy reliabilityReq : SystemReliabilityRequirement;
        }
    }
}
