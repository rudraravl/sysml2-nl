package PistonlessPumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def Fluid {
            attribute density : Real;
            attribute viscosity : Real;
            attribute temperature : Real;
        }

        attribute def PressureValue :> Real;
        attribute def VolumeFlowRateValue :> Real;
        attribute def VolumeValue :> Real;
        attribute def PowerValue :> Real;
        attribute def AngularVelocityValue :> Real;
        attribute def LengthValue :> Real;

        port def FluidPort {
            attribute pressure : PressureValue;
            attribute flowRate : VolumeFlowRateValue;
            out item fluidOut : Fluid;
        }

        port def FluidInletPort :> FluidPort {
            in item fluidIn : Fluid;
        }

        port def PowerPort {
            attribute voltage : Real;
            attribute current : Real;
            attribute power : PowerValue;
        }

        part def PistonlessPump {
            doc /* A pistonless pump uses continuous rotary motion (impeller/rotor) 
                   to transfer fluid without reciprocating pistons */

            attribute ratedFlowRate : VolumeFlowRateValue;
            attribute ratedPressureRise : PressureValue;
            attribute efficiency : Real;
            attribute operatingSpeed : AngularVelocityValue;

            port inlet : ~FluidPort;
            port outlet : FluidPort;
            port powerInput : ~PowerPort;

            part impeller {
                attribute diameter : LengthValue;
                attribute bladeCount : Integer;
                attribute rotationSpeed : AngularVelocityValue;
            }

            part volute {
                attribute inletDiameter : LengthValue;
                attribute outletDiameter : LengthValue;
            }

            part drivingMotor {
                attribute ratedPower : PowerValue;
                attribute nominalSpeed : AngularVelocityValue;
            }

            part shaft {
                attribute diameter : LengthValue;
                attribute length : LengthValue;
            }

            part bearings {
                attribute type : String;
                attribute count : Integer;
            }
        }

        part def SourceTank {
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            port outletPort : FluidPort;

            item storedFluid : Fluid {
                attribute volume : VolumeValue;
            }

            assert constraint levelConstraint {
                currentLevel <= capacity
            }
        }

        part def DestinationTank {
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            port inletPort : ~FluidPort;

            item receivedFluid : Fluid {
                attribute volume : VolumeValue;
            }

            assert constraint levelConstraint {
                currentLevel <= capacity
            }
        }

        part def PressureTransducer {
            attribute measuredPressure : PressureValue;
            attribute accuracy : Real;
            port sensingPort : ~FluidPort;
        }

        part def FlowTransducer {
            attribute measuredFlowRate : VolumeFlowRateValue;
            attribute accuracy : Real;
            port sensingPort : ~FluidPort;
        }

        part def ControlValve {
            attribute position : Real;
            attribute maxOpening : Real;
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
        }

        action def InitializePump {
            in pumpRef : PistonlessPump;
            out initialized : Boolean;
        }

        action def StartPumpMotor {
            in pumpRef : PistonlessPump;
            out motorRunning : Boolean;
        }

        action def StopPumpMotor {
            in pumpRef : PistonlessPump;
            out motorStopped : Boolean;
        }

        action def ReadPressure {
            in sensor : PressureTransducer;
            out pressure : PressureValue;
        }

        action def ReadFlowRate {
            in sensor : FlowTransducer;
            out flowRate : VolumeFlowRateValue;
        }

        action def ModulateValve {
            in valve : ControlValve;
            in targetPosition : Real;
            out actualPosition : Real;
        }

        action def PumpControlSequence {
            first start;
            then action initialize : InitializePump;
            then action startMotor : StartPumpMotor;
            then merge controlLoop;
            then action measurePressure : ReadPressure;
            then action measureFlow : ReadFlowRate;
            then decide;
                if measurePressure.pressure < minPressure then increaseValveOpening;
                if measurePressure.pressure > maxPressure then decreaseValveOpening;
                if measurePressure.pressure >= minPressure and 
                   measurePressure.pressure <= maxPressure then maintainValvePosition;
            action increaseValveOpening : ModulateValve {
                in targetPosition = currentValvePosition + 10.0;
            }
            then controlLoop;
            action decreaseValveOpening : ModulateValve {
                in targetPosition = currentValvePosition - 10.0;
            }
            then controlLoop;
            action maintainValvePosition : ModulateValve {
                in targetPosition = currentValvePosition;
            }
            then controlLoop;

            attribute minPressure : PressureValue;
            attribute maxPressure : PressureValue;
            attribute currentValvePosition : Real;
        }

        state def PumpOperationalStates {
            entry; then off;

            state off;
            
            transition off_to_startup
                first off
                accept StartSignal
                then startup;

            state startup {
                state priming;
                
                transition priming_to_accelerating
                    first priming
                    if inletPressure > minInletPressure
                    then accelerating;

                state accelerating;
                
                transition accelerating_to_operational
                    first accelerating
                    if motorSpeed >= targetSpeed * 0.95
                    then operational;
            }
            
            transition startup_to_operational
                first startup
                if motorSpeed >= targetSpeed * 0.95
                then operational;

            state operational {
                state normalFlow;
                
                transition normalFlow_to_reducedFlow
                    first normalFlow
                    if dischargePressure > maxDischargePressure
                    then reducedFlow;

                state reducedFlow;
                
                transition reducedFlow_to_normalFlow
                    first reducedFlow
                    if dischargePressure <= maxDischargePressure
                    then normalFlow;
            }
            
            transition operational_to_shutdown
                first operational
                accept StopSignal
                then shutdown;

            state shutdown;
            
            transition shutdown_to_off
                first shutdown
                if motorSpeed <= 0.1
                then off;

            attribute motorSpeed : AngularVelocityValue;
            attribute flowRate : VolumeFlowRateValue;
            attribute inletPressure : PressureValue;
            attribute dischargePressure : PressureValue;
            attribute targetSpeed : AngularVelocityValue;
            attribute nominalFlowRate : VolumeFlowRateValue;
            attribute minInletPressure : PressureValue;
            attribute maxDischargePressure : PressureValue;
        }

        requirement def PumpPerformanceRequirement {
            doc /* Performance requirements for the pistonless pump */

            subject pump : PistonlessPump;

            require minimumFlowRate {
                doc /* Pump shall deliver minimum volumetric flow rate */
                pump.ratedFlowRate >= 120.0
            }

            require minimumPressureRise {
                doc /* Pump shall achieve minimum pressure rise */
                pump.ratedPressureRise >= 400000.0
            }

            require minimumEfficiency {
                doc /* Pump shall maintain minimum hydraulic efficiency */
                pump.efficiency >= 0.70
            }
        }

        requirement def SubsystemReliabilityRequirement {
            doc /* Reliability and operational requirements */

            require continuousOperation {
                doc /* Subsystem shall operate continuously for minimum duration */
            }

            require cavitationPrevention {
                doc /* Subsystem shall prevent cavitation at pump inlet */
            }

            require leakagePrevention {
                doc /* Subsystem shall prevent external fluid leakage */
            }
        }

        interface def PumpingInterface {
            end port sourcePort : FluidPort;
            end port pumpInlet : FluidPort;
            end port pumpOutlet : FluidPort;
            end port destinationPort : FluidPort;

            connect sourcePort to pumpInlet;
            connect pumpOutlet to destinationPort;
        }
    }

    package Usages {
        import Definitions::*;

        part pistonlessPumpingSubsystem {
            doc /* Complete pistonless pumping subsystem transferring fluid from source to destination */

            part sourceTank : SourceTank {
                attribute :>> capacity = 5000.0;
                attribute :>> currentLevel = 3500.0;

                item :>> storedFluid : Fluid {
                    attribute :>> volume = 3500.0;
                    attribute :>> density = 998.0;
                    attribute :>> viscosity = 0.001002;
                    attribute :>> temperature = 293.15;
                }

                attribute outletPort.pressure = 101325.0;
                attribute outletPort.flowRate = 0.0;
            }

            flow sourceToInlet
                from sourceTank.outletPort.fluidOut
                to pistonlessPump.inlet.fluidIn;

            part pistonlessPump : PistonlessPump {
                attribute :>> ratedFlowRate = 150.0;
                attribute :>> ratedPressureRise = 500000.0;
                attribute :>> efficiency = 0.78;
                attribute :>> operatingSpeed = 1800.0;

                part :>> impeller {
                    attribute :>> diameter = 0.28;
                    attribute :>> bladeCount = 7;
                    attribute :>> rotationSpeed = 1800.0;
                }

                part :>> volute {
                    attribute :>> inletDiameter = 0.12;
                    attribute :>> outletDiameter = 0.10;
                }

                part :>> drivingMotor {
                    attribute :>> ratedPower = 18500.0;
                    attribute :>> nominalSpeed = 1800.0;
                }

                part :>> shaft {
                    attribute :>> diameter = 0.055;
                    attribute :>> length = 0.35;
                }

                part :>> bearings {
                    attribute :>> type = "Ball Bearing";
                    attribute :>> count = 2;
                }

                perform action operatingStateMachine : PumpOperationalStates {
                    attribute :>> targetSpeed = 1800.0;
                    attribute :>> nominalFlowRate = 150.0;
                    attribute :>> minInletPressure = 50000.0;
                    attribute :>> maxDischargePressure = 650000.0;
                }
            }

            part dischargePressureSensor : PressureTransducer {
                attribute :>> measuredPressure = 520000.0;
                attribute :>> accuracy = 0.5;
            }

            flow pumpToSensor
                from pistonlessPump.outlet.fluidOut
                to dischargePressureSensor.sensingPort.fluidIn;

            part dischargeFlowSensor : FlowTransducer {
                attribute :>> measuredFlowRate = 148.0;
                attribute :>> accuracy = 1.0;
            }

            flow sensorToFlowMeter
                from dischargePressureSensor.sensingPort.fluidOut
                to dischargeFlowSensor.sensingPort.fluidIn;

            part dischargeValve : ControlValve {
                attribute :>> position = 80.0;
                attribute :>> maxOpening = 100.0;
            }

            flow flowMeterToValve
                from dischargeFlowSensor.sensingPort.fluidOut
                to dischargeValve.inletPort.fluidIn;

            part destinationTank : DestinationTank {
                attribute :>> capacity = 8000.0;
                attribute :>> currentLevel = 1200.0;

                item :>> receivedFluid : Fluid {
                    attribute :>> volume = 1200.0;
                    attribute :>> density = 998.0;
                    attribute :>> viscosity = 0.001002;
                    attribute :>> temperature = 295.15;
                }

                attribute inletPort.pressure = 0.0;
                attribute inletPort.flowRate = 0.0;
            }

            flow valveToDestination
                from dischargeValve.outletPort.fluidOut
                to destinationTank.inletPort.fluidIn;

            perform action controlSequence : PumpControlSequence {
                attribute :>> minPressure = 450000.0;
                attribute :>> maxPressure = 600000.0;
                attribute :>> currentValvePosition = 80.0;
            }

            satisfy performanceReq : PumpPerformanceRequirement {
                subject pumpSubject = pistonlessPump;
            }

            satisfy reliabilityReq : SubsystemReliabilityRequirement;

            interface pumpingConnection : PumpingInterface connect
                sourcePort ::> sourceTank.outletPort to
                pumpInlet ::> pistonlessPump.inlet,
                pumpOutlet ::> pistonlessPump.outlet to
                destinationPort ::> destinationTank.inletPort;
        }

        part highCapacityConfiguration : PistonlessPump {
            doc /* High capacity pistonless pump variant for increased flow requirements */

            attribute :>> ratedFlowRate = 250.0;
            attribute :>> ratedPressureRise = 700000.0;
            attribute :>> efficiency = 0.82;
            attribute :>> operatingSpeed = 2400.0;

            part :>> impeller {
                attribute :>> diameter = 0.35;
                attribute :>> bladeCount = 9;
                attribute :>> rotationSpeed = 2400.0;
            }

            part :>> volute {
                attribute :>> inletDiameter = 0.15;
                attribute :>> outletDiameter = 0.12;
            }

            part :>> drivingMotor {
                attribute :>> ratedPower = 30000.0;
                attribute :>> nominalSpeed = 2400.0;
            }

            part :>> shaft {
                attribute :>> diameter = 0.070;
                attribute :>> length = 0.42;
            }

            part :>> bearings {
                attribute :>> type = "Roller Bearing";
                attribute :>> count = 2;
            }
        }
    }
}
