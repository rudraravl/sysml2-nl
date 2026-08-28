package IntelligentPumpingSubsystem {

    import ScalarValues::*;

    // ===== Units =====
    unit Pa;
    unit m3_per_s;
    unit rad_per_s;
    unit m3;
    unit s;

    // ===== Value Types =====
    value def PressureValue :> Real {
        unit Pa;
    }

    value def FlowRateValue :> Real {
        unit m3_per_s;
    }

    value def RotationalSpeedValue :> Real {
        unit rad_per_s;
    }

    value def VolumeValue :> Real {
        unit m3;
    }

    value def DurationValue :> Real {
        unit s;
    }

    value def DimensionlessGain :> Real;

    // ===== Items =====
    item def Fluid;

    // ===== Ports =====
    port def FluidFlowPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        inout item fluid : Fluid;
    }

    port def FlowSignalPort {
        attribute flowRate : FlowRateValue;
    }

    port def PressureSignalPort {
        attribute pressure : PressureValue;
    }

    port def SpeedCommandPort {
        attribute speedCommand : RotationalSpeedValue;
    }

    // ===== Sensors =====
    part def FlowSensor {
        attribute measuredFlowRate : FlowRateValue;
        out port flowSignal : FlowSignalPort;

        action sense {
            in fluid : Fluid;
            in portPressure : PressureValue;
            out flowRate : FlowRateValue;

            attribute rawSignal : Real;
            attribute calibrated : FlowRateValue = rawSignal * 0.001;
            bind flowRate = calibrated;
        }
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        out port pressureSignal : PressureSignalPort;

        action sense {
            in fluid : Fluid;
            out pressure : PressureValue;

            attribute rawSignal : Real;
            attribute calibrated : PressureValue = rawSignal * 1000.0;
            bind pressure = calibrated;
        }
    }

    // ===== Pump Controller =====
    part def PumpController {
        attribute targetFlowRate : FlowRateValue = 0.001 [m3_per_s];
        attribute minSpeed : RotationalSpeedValue = 0.0 [rad_per_s];
        attribute maxSpeed : RotationalSpeedValue = 314.0 [rad_per_s];
        attribute proportionalGain : DimensionlessGain = 1000.0;
        attribute integralGain : DimensionlessGain = 10.0;
        attribute samplingPeriod : DurationValue = 0.1 [s];
        attribute maxFlowRate : FlowRateValue = 0.01 [m3_per_s];
        attribute minInletPressure : PressureValue = 50000.0 [Pa];
        attribute maxOutletPressure : PressureValue = 500000.0 [Pa];

        in port inletFlow : FlowSignalPort;
        in port inletPressure : PressureSignalPort;
        in port outletFlow : FlowSignalPort;
        in port outletPressure : PressureSignalPort;
        out port speedCommand : SpeedCommandPort;

        attribute currentSpeed : RotationalSpeedValue = 0.0 [rad_per_s];
        attribute flowError : FlowRateValue = 0.0 [m3_per_s];
        attribute accumulatedError : FlowRateValue = 0.0 [m3_per_s];
        attribute faultDetected : Boolean = false;
        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute faultReset : Boolean = false;

        // Closed-loop proportional-integral control: compare actual outlet flow
        // to target and adjust pump speed accordingly
        action regulateFlow {
            in actualFlow : FlowRateValue;
            in targetFlow : FlowRateValue;
            in currentSpeed : RotationalSpeedValue;
            in gain : DimensionlessGain;
            in integral : DimensionlessGain;
            in maxSpeed : RotationalSpeedValue;
            in minSpeed : RotationalSpeedValue;
            out newSpeed : RotationalSpeedValue;

            // Positive error means flow is too low; pump should speed up
            attribute error : FlowRateValue = targetFlow - actualFlow;
            attribute proportionalTerm : RotationalSpeedValue = gain * error;
            attribute integralTerm : RotationalSpeedValue = integral * error;
            attribute adjustment : RotationalSpeedValue = proportionalTerm + integralTerm;
            attribute candidate : RotationalSpeedValue = currentSpeed + adjustment;

            // Saturate to safe speed limits
            decide
                if candidate > maxSpeed
                then action clampHigh {
                    out clamped : RotationalSpeedValue = maxSpeed;
                }
                else if candidate < minSpeed
                then action clampLow {
                    out clamped : RotationalSpeedValue = minSpeed;
                }
                else action passThrough {
                    out clamped : RotationalSpeedValue = candidate;
                };

            bind newSpeed = clampHigh.clamped;
            bind newSpeed = clampLow.clamped;
            bind newSpeed = passThrough.clamped;
        }

        // Safety monitoring: detect over-speed, cavitation, over-pressure, or reverse flow
        action checkFaults {
            in inletPress : PressureValue;
            in outletPress : PressureValue;
            in outletFlowRate : FlowRateValue;
            in maxFlow : FlowRateValue;
            in minPress : PressureValue;
            in maxPress : PressureValue;
            out fault : Boolean;

            decide
                if outletFlowRate > maxFlow
                then action overFlowFault {
                    out result : Boolean = true;
                }
                else if inletPress < minPress
                then action cavitationFault {
                    out result : Boolean = true;
                }
                else if outletPress > maxPress
                then action overPressureFault {
                    out result : Boolean = true;
                }
                else if outletPress < inletPress
                then action reverseFlowFault {
                    out result : Boolean = true;
                }
                else action noFault {
                    out result : Boolean = false;
                };

            bind fault = overFlowFault.result;
            bind fault = cavitationFault.result;
            bind fault = overPressureFault.result;
            bind fault = reverseFlowFault.result;
            bind fault = noFault.result;
        }

        // Controller internal state behavior
        state controllerState {
            entry;
            state idle;
            state regulating;
            state faulted;

            transition first entry then idle;
            transition first idle then regulating when startCommand;
            transition first regulating then faulted when faultDetected;
            transition first regulating then idle when stopCommand;
            transition first faulted then idle when faultReset;
        }
    }

    // ===== Pump Motor =====
    part def PumpMotor {
        in port speedCommand : SpeedCommandPort;
        attribute currentSpeed : RotationalSpeedValue = 0.0 [rad_per_s];
        attribute maxSpeed : RotationalSpeedValue = 314.0 [rad_per_s];
        attribute accelerationRate : RotationalSpeedValue = 50.0 [rad_per_s];
        attribute decelerationRate : RotationalSpeedValue = 80.0 [rad_per_s];
        attribute targetSpeed : RotationalSpeedValue = 0.0 [rad_per_s];
        attribute power : Real = 0.0;
        attribute motorStopped : Boolean = true;

        // Ramp motor speed toward commanded value with acceleration/deceleration limits
        action spin {
            in command : RotationalSpeedValue;
            in currentSpeed : RotationalSpeedValue;
            in accelRate : RotationalSpeedValue;
            in decelRate : RotationalSpeedValue;
            out speed : RotationalSpeedValue;

            attribute speedDifference : RotationalSpeedValue = command - currentSpeed;

            decide
                if speedDifference > accelRate
                then action rampUp {
                    out result : RotationalSpeedValue = currentSpeed + accelRate;
                }
                else if speedDifference < -decelRate
                then action rampDown {
                    out result : RotationalSpeedValue = currentSpeed - decelRate;
                }
                else action reachTarget {
                    out result : RotationalSpeedValue = command;
                };

            bind speed = rampUp.result;
            bind speed = rampDown.result;
            bind speed = reachTarget.result;
        }

        action stop {
            out speed : RotationalSpeedValue = 0.0 [rad_per_s];
        }
    }

    // ===== Intelligent Pump =====
    part def IntelligentPump {
        attribute targetPressureIncrease : PressureValue = 200000.0 [Pa];
        attribute minOperatingSpeed : RotationalSpeedValue = 10.0 [rad_per_s];
        attribute maxOperatingSpeed : RotationalSpeedValue = 314.0 [rad_per_s];
        attribute minFlowRate : FlowRateValue = 0.0001 [m3_per_s];
        attribute maxFlowRate : FlowRateValue = 0.01 [m3_per_s];
        attribute startupDuration : DurationValue = 5.0 [s];
        attribute shutdownDuration : DurationValue = 3.0 [s];
        attribute nominalPower : Real = 750.0;

        // Control and status signals
        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute faultReset : Boolean = false;
        attribute operatingSpeedReached : Boolean = false;
        attribute motorStopped : Boolean = true;

        // Fluid interface ports
        in port inlet : FluidFlowPort;
        out port outlet : FluidFlowPort;

        // Sensor suite at inlet and outlet
        part inletFlowSensor : FlowSensor;
        part inletPressureSensor : PressureSensor;
        part outletFlowSensor : FlowSensor;
        part outletPressureSensor : PressureSensor;

        // Integrated controller and motor
        part controller : PumpController;
        part motor : PumpMotor;

        // Bind sensor measurements to port fluid properties
        bind inletFlowSensor.measuredFlowRate = inlet.flowRate;
        bind inletPressureSensor.measuredPressure = inlet.pressure;
        bind outletFlowSensor.measuredFlowRate = outlet.flowRate;
        bind outletPressureSensor.measuredPressure = outlet.pressure;

        // Connect sensor signal outputs to controller inputs
        connect inletFlowSensor.flowSignal to controller.inletFlow;
        connect inletPressureSensor.pressureSignal to controller.inletPressure;
        connect outletFlowSensor.flowSignal to controller.outletFlow;
        connect outletPressureSensor.pressureSignal to controller.outletPressure;

        // Connect controller speed command to motor
        connect controller.speedCommand to motor.speedCommand;

        // Bind pump-level control signals to controller
        bind controller.startCommand = startCommand;
        bind controller.stopCommand = stopCommand;
        bind controller.faultDetected = faultDetected;
        bind controller.faultReset = faultReset;

        // Bind motor status to pump status
        bind motor.motorStopped = motorStopped;

        // Pump operational state machine: off, starting, running, stopping, faulted
        state pumpStateMachine {
            entry;
            state off;
            state starting;
            state running;
            state stopping;
            state faulted;

            transition first entry then off;
            transition first off then starting when startCommand;
            transition first starting then running when operatingSpeedReached;
            transition first running then stopping when stopCommand;
            transition first stopping then off when motorStopped;
            transition first off, starting, running, stopping then faulted when faultDetected;
            transition first faulted then off when faultReset;
        }
    }

    // ===== Storage Tank =====
    part def StorageTank {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute fluidPressure : PressureValue;
        attribute minVolume : VolumeValue = 0.0 [m3];
        attribute maxVolume : VolumeValue = 1.0 [m3];

        inout port fluidPort : FluidFlowPort;

        action fill {
            in flowRate : FlowRateValue;
            in duration : DurationValue;
            out newVolume : VolumeValue;

            attribute addedVolume : VolumeValue = flowRate * duration;
            attribute result : VolumeValue = currentVolume + addedVolume;
            bind newVolume = result;
        }

        action drain {
            in flowRate : FlowRateValue;
            in duration : DurationValue;
            out newVolume : VolumeValue;

            attribute removedVolume : VolumeValue = flowRate * duration;
            attribute result : VolumeValue = currentVolume - removedVolume;
            bind newVolume = result;
        }

        state tankState {
            entry;
            state empty;
            state partiallyFilled;
            state full;

            attribute volume : VolumeValue = currentVolume;

            transition first entry then partiallyFilled;
            transition first empty then partiallyFilled when volume > 0.0 [m3];
            transition first partiallyFilled then full when volume >= capacity;
            transition first full then partiallyFilled when volume < capacity;
            transition first partiallyFilled then empty when volume <= 0.0 [m3];
        }
    }

    // ===== Subsystem Assembly =====
    part pumpingSubsystem {
        part sourceTank : StorageTank {
            :>> capacity = 1.0 [m3];
            :>> currentVolume = 0.8 [m3];
            :>> fluidPressure = 101325.0 [Pa];
        }

        part destinationTank : StorageTank {
            :>> capacity = 1.0 [m3];
            :>> currentVolume = 0.2 [m3];
            :>> fluidPressure = 101325.0 [Pa];
        }

        part pump : IntelligentPump {
            :>> targetPressureIncrease = 200000.0 [Pa];
            :>> maxOperatingSpeed = 314.0 [rad_per_s];
            :>> minOperatingSpeed = 10.0 [rad_per_s];
            :>> maxFlowRate = 0.01 [m3_per_s];
            :>> minFlowRate = 0.0001 [m3_per_s];
            :>> nominalPower = 750.0;
        }

        // Fluid transfer from source tank to pump inlet
        connect sourceTank.fluidPort to pump.inlet {
            flow of Fluid;
        }

        // Fluid transfer from pump outlet to destination tank
        connect pump.outlet to destinationTank.fluidPort {
            flow of Fluid;
        }
    }

    // ===== Requirements =====
    requirement def PressureIncreaseRequirement {
        subject pump : IntelligentPump;
        attribute requiredIncrease : PressureValue = 200000.0 [Pa];
        require {
            pump.outlet.pressure - pump.inlet.pressure >= requiredIncrease
        }
    }

    requirement def FlowRateControlRequirement {
        subject pump : IntelligentPump;
        attribute targetFlow : FlowRateValue = 0.001 [m3_per_s];
        attribute tolerance : FlowRateValue = 0.0001 [m3_per_s];
        require {
            pump.outlet.flowRate >= targetFlow - tolerance and
            pump.outlet.flowRate <= targetFlow + tolerance
        }
    }

    requirement def SpeedLimitRequirement {
        subject pump : IntelligentPump;
        attribute maxSpeed : RotationalSpeedValue = 314.0 [rad_per_s];
        require {
            pump.motor.currentSpeed <= maxSpeed
        }
    }

    requirement def FlowRateLimitRequirement {
        subject pump : IntelligentPump;
        attribute maxFlow : FlowRateValue = 0.01 [m3_per_s];
        attribute minFlow : FlowRateValue = 0.0001 [m3_per_s];
        require {
            pump.outlet.flowRate <= maxFlow and
            pump.outlet.flowRate >= minFlow
        }
    }

    requirement def SafetyShutdownRequirement {
        subject pump : IntelligentPump;
        require {
            pump.faultDetected implies pump.motor.currentSpeed == 0.0 [rad_per_s]
        }
    }

    requirement def AutonomousOperationRequirement {
        subject pump : IntelligentPump;
        attribute targetFlow : FlowRateValue = 0.001 [m3_per_s];
        require {
            pump.controller.targetFlowRate == targetFlow
        }
    }

    requirement def ClosedLoopControlRequirement {
        subject pump : IntelligentPump;
        require {
            pump.controller.regulateFlow.actualFlow == pump.outletFlow.flowRate and
            pump.controller.regulateFlow.targetFlow == pump.controller.targetFlowRate
        }
    }

    requirement def FaultDetectionRequirement {
        subject pump : IntelligentPump;
        require {
            pump.controller.checkFaults.inletPress == pump.inletPressure.pressure and
            pump.controller.checkFaults.outletPress == pump.outletPressure.pressure and
            pump.controller.checkFaults.outletFlowRate == pump.outletFlow.flowRate
        }
    }

    // ===== Requirement Satisfaction =====
    part def PumpingSubsystemVerification {
        subject subsystem : pumpingSubsystem;

        satisfy PressureIncreaseRequirement by subsystem.pump;
        satisfy FlowRateControlRequirement by subsystem.pump;
        satisfy SpeedLimitRequirement by subsystem.pump;
        satisfy FlowRateLimitRequirement by subsystem.pump;
        satisfy SafetyShutdownRequirement by subsystem.pump;
        satisfy AutonomousOperationRequirement by subsystem.pump;
        satisfy ClosedLoopControlRequirement by subsystem.pump;
        satisfy FaultDetectionRequirement by subsystem.pump;
    }
}
