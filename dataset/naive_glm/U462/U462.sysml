package IndustrialPumpingSystem {

    import ScalarValues::*;

    // ================================================================
    // VALUE TYPES
    // ================================================================

    value type FlowRateValue :> Real {
        doc 'Volumetric flow rate [m^3/s].';
    }

    value type PressureValue :> Real {
        doc 'Fluid pressure [Pa].';
    }

    value type HeadValue :> Real {
        doc 'Pump head as equivalent fluid column height [m].';
    }

    value type SpeedValue :> Real {
        doc 'Rotational speed [rad/s].';
    }

    value type FrequencyValue :> Real {
        doc 'AC electrical frequency [Hz].';
    }

    value type VoltageValue :> Real {
        doc 'Electrical voltage [V].';
    }

    value type CurrentValue :> Real {
        doc 'Electrical current [A].';
    }

    value type PowerValue :> Real {
        doc 'Power [W].';
    }

    value type TemperatureValue :> Real {
        doc 'Temperature [degC].';
    }

    value type EfficiencyValue :> Real {
        doc 'Dimensionless efficiency (0 to 1).';
    }

    // ================================================================
    // ITEM DEFINITIONS
    // ================================================================

    item def ProcessFluid {
        doc 'Process fluid pumped through the industrial system.';
        attribute density : Real = 1000 {
            doc 'Density [kg/m^3].';
        }
        attribute dynamicViscosity : Real = 0.001 {
            doc 'Dynamic viscosity [Pa*s].';
        }
        attribute temperature : TemperatureValue = 20;
    }

    // ================================================================
    // PORT DEFINITIONS
    // ================================================================

    port def FluidPort {
        doc 'Port carrying process fluid with flow rate and pressure.';
        flow ProcessFluid;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }

    port def FlowSignalOutPort {
        doc 'Output port providing measured flow rate signal.';
        out measuredFlowRate : FlowRateValue;
    }

    port def FlowSignalInPort {
        doc 'Input port receiving measured flow rate signal.';
        in measuredFlowRate : FlowRateValue;
    }

    port def PressureSignalOutPort {
        doc 'Output port providing measured pressure signal.';
        out measuredPressure : PressureValue;
    }

    port def PressureSignalInPort {
        doc 'Input port receiving measured pressure signal.';
        in measuredPressure : PressureValue;
    }

    port def SpeedCommandOutPort {
        doc 'Output port providing speed command signal.';
        out speedCommand : SpeedValue;
    }

    port def SpeedCommandInPort {
        doc 'Input port receiving speed command signal.';
        in speedCommand : SpeedValue;
    }

    port def ElectricalPowerOutPort {
        doc 'Output port providing electrical power to a load.';
        out lineVoltage : VoltageValue;
        out lineFrequency : FrequencyValue;
        out lineCurrent : CurrentValue;
    }

    port def ElectricalPowerInPort {
        doc 'Input port receiving electrical power from a source.';
        in lineVoltage : VoltageValue;
        in lineFrequency : FrequencyValue;
        in lineCurrent : CurrentValue;
    }

    // ================================================================
    // CONNECTION DEFINITIONS
    // ================================================================

    connection def FluidConnection {
        doc 'Connection carrying process fluid between fluid ports.';
        end source : FluidPort;
        end sink : FluidPort;
    }

    connection def FlowSignalLink {
        doc 'Connection carrying flow measurement signal.';
        end source : FlowSignalOutPort;
        end sink : FlowSignalInPort;
    }

    connection def PressureSignalLink {
        doc 'Connection carrying pressure measurement signal.';
        end source : PressureSignalOutPort;
        end sink : PressureSignalInPort;
    }

    connection def SpeedCommandLink {
        doc 'Connection carrying speed command signal.';
        end source : SpeedCommandOutPort;
        end sink : SpeedCommandInPort;
    }

    connection def ElectricalPowerLink {
        doc 'Connection carrying electrical power between VFD and motor.';
        end source : ElectricalPowerOutPort;
        end sink : ElectricalPowerInPort;
    }

    // ================================================================
    // ACTION DEFINITIONS
    // ================================================================

    action def ApplyAffinityLaws {
        doc
        /*
         * Computes the required pump speed and expected power
         * consumption based on the centrifugal pump affinity laws:
         *   Q1 / Q0 = N1 / N0            (flow ~ speed)
         *   H1 / H0 = (N1 / N0)^2        (head ~ speed squared)
         *   P1 / P0 = (N1 / N0)^3        (power ~ speed cubed)
         * Given a desired flow and head target, this action determines
         * the appropriate shaft speed and the resulting power draw.
         */;

        in nominalFlow : FlowRateValue;
        in nominalHead : HeadValue;
        in nominalSpeed : SpeedValue;
        in nominalPower : PowerValue;
        in targetFlow : FlowRateValue;
        in targetHead : HeadValue;
        out requiredSpeed : SpeedValue;
        out expectedPower : PowerValue;

        attribute flowSpeedRatio : Real =
            if nominalFlow > 0 then targetFlow / nominalFlow else 0;

        attribute headSpeedRatio : Real =
            if nominalHead > 0 then (targetHead / nominalHead) ** 0.5 else 0;

        attribute effectiveSpeedRatio : Real = (flowSpeedRatio + headSpeedRatio) / 2;

        attribute clampedSpeedRatio : Real =
            if effectiveSpeedRatio < 0 then 0
            else if effectiveSpeedRatio > 1.2 then 1.2
            else effectiveSpeedRatio;

        out requiredSpeed =
            if nominalSpeed > 0 then nominalSpeed * clampedSpeedRatio else 0;
        out expectedPower =
            if nominalPower > 0 then nominalPower * clampedSpeedRatio ** 3 else 0;
    }

    action def ComputeFeedbackCorrection {
        doc
        /*
         * Computes a proportional-integral (PI) feedback correction
         * on top of the feed-forward affinity-law speed estimate.
         * Compensates for process disturbances and modeling errors
         * that the affinity laws alone cannot capture.
         */;

        in flowSetpoint : FlowRateValue;
        in headSetpoint : HeadValue;
        in measuredFlow : FlowRateValue;
        in measuredHead : HeadValue;
        in feedForwardSpeed : SpeedValue;
        in proportionalGain : Real;
        in integralGain : Real;
        in maxSpeed : SpeedValue;
        in minSpeed : SpeedValue;
        out correctedSpeed : SpeedValue;

        attribute flowError : Real = flowSetpoint - measuredFlow;
        attribute headError : Real = headSetpoint - measuredHead;

        attribute proportionalCorrection : SpeedValue =
            proportionalGain * (flowError * 10 + headError * 0.5);
        attribute integralCorrection : SpeedValue =
            integralGain * (flowError + headError * 0.5);

        attribute rawSpeed : SpeedValue =
            feedForwardSpeed + proportionalCorrection + integralCorrection;

        out correctedSpeed =
            if rawSpeed < minSpeed then minSpeed
            else if rawSpeed > maxSpeed then maxSpeed
            else rawSpeed;
    }

    // ================================================================
    // STATE MACHINE DEFINITIONS
    // ================================================================

    state machine def PumpStateMachine {
        doc 'Operational states for the centrifugal pump.';

        initial state Off {
            doc 'Pump is stopped, no fluid is being moved.';
        }
        state Starting {
            doc 'Pump is ramping up to operating speed.';
        }
        state Running {
            doc 'Pump is operating normally at controlled speed.';
        }
        state Stopping {
            doc 'Pump is ramping down to a stop.';
        }
        final state Faulted {
            doc 'Pump has encountered a fault condition.';
        }

        transition from Off to Starting when startCommand;
        transition from Starting to Running when speedReachedNominal;
        transition from Starting to Faulted when startFailure;
        transition from Running to Stopping when stopCommand;
        transition from Running to Faulted when faultDetected;
        transition from Stopping to Off when fullyStopped;
        transition from Faulted to Off when faultReset;
    }

    state machine def MotorStateMachine {
        doc 'Operational states for the electric motor.';

        initial state Off {
            doc 'Motor is de-energized.';
        }
        state Accelerating {
            doc 'Motor is ramping up to commanded speed.';
        }
        state Running {
            doc 'Motor is running at operating speed.';
        }
        state Decelerating {
            doc 'Motor is ramping down.';
        }
        final state Faulted {
            doc 'Motor fault detected (overload, overtemp, etc.).';
        }

        transition from Off to Accelerating when energized;
        transition from Accelerating to Running when atRatedSpeed;
        transition from Accelerating to Faulted when overloadDetected;
        transition from Running to Decelerating when deEnergized;
        transition from Decelerating to Off when stopped;
        transition from Faulted to Off when faultReset;
    }

    state machine def VFDStateMachine {
        doc 'Operational states for the Variable Frequency Drive.';

        initial state Powered {
            doc 'VFD is powered on but not driving the motor.';
        }
        state Accelerating {
            doc 'VFD is ramping output frequency to target.';
        }
        state AtSpeed {
            doc 'VFD is maintaining output at commanded frequency.';
        }
        state Decelerating {
            doc 'VFD is ramping output frequency down to zero.';
        }
        final state Faulted {
            doc 'VFD has detected a fault condition.';
        }

        transition from Powered to Accelerating when runCommand;
        transition from Accelerating to AtSpeed when targetFrequencyReached;
        transition from AtSpeed to Decelerating when stopCommand;
        transition from Decelerating to Powered when zeroOutput;
        transition from AtSpeed to Faulted when overloadDetected;
        transition from Faulted to Powered when faultReset;
    }

    state machine def ControllerStateMachine {
        doc 'Operational states for the process controller.';

        initial state Boot {
            doc 'Controller initializing after power-up.';
        }
        state Idle {
            doc 'Controller is powered but the control loop is inactive.';
        }
        state Active {
            doc 'Controller is actively running the feedback control loop.';

            initial state Measure {
                doc 'Acquiring latest flow and pressure measurements from transmitters.';
            }
            state Compute {
                doc 'Computing required speed using affinity laws and PI correction.';
            }
            state Actuate {
                doc 'Sending updated speed command to the VFD.';
            }

            transition from Measure to Compute when sensorsValid;
            transition from Compute to Actuate when computationReady;
            transition from Actuate to Measure when commandDispatched;
        }
        final state Faulted {
            doc 'Controller has detected a fault.';
        }

        transition from Boot to Idle when initComplete;
        transition from Idle to Active when enableControl;
        transition from Active to Idle when disableControl;
        transition from Active to Faulted when controllerFault;
        transition from Faulted to Idle when faultCleared;
    }

    state machine def TransmitterStateMachine {
        doc 'Operational states for measurement transmitters.';

        initial state Powered {
            doc 'Transmitter is powered but not actively measuring.';
        }
        state Measuring {
            doc 'Transmitter is acquiring a measurement from the fluid.';
        }
        state Reporting {
            doc 'Transmitter is sending the measurement signal to the controller.';
        }
        final state Faulted {
            doc 'Transmitter has detected a sensor fault.';
        }

        transition from Powered to Measuring when sensingEnabled;
        transition from Measuring to Reporting when sampleReady;
        transition from Reporting to Measuring when reportSent;
        transition from Measuring to Faulted when sensorFault;
        transition from Faulted to Powered when faultReset;
    }

    // ================================================================
    // PART DEFINITIONS
    // ================================================================

    part def CentrifugalPump {
        doc
        /*
         * Main centrifugal pump driven by an electric motor through
         * a VFD. Performance is governed by the affinity laws that
         * relate flow, head, and power to rotational speed.
         */;

        port inlet : FluidPort;
        port outlet : FluidPort;
        port drive : SpeedCommandInPort;

        // Nominal performance parameters at rated speed
        attribute nominalFlow : FlowRateValue = 0.05 {
            doc 'Nominal flow rate at rated speed [m^3/s].';
        }
        attribute nominalHead : HeadValue = 30 {
            doc 'Nominal head at rated speed [m].';
        }
        attribute nominalSpeed : SpeedValue = 314.16 {
            doc 'Nominal rotational speed, approximately 3000 rpm [rad/s].';
        }
        attribute nominalPower : PowerValue = 18000 {
            doc 'Nominal shaft power at rated speed [W].';
        }

        // Safe operating limits
        attribute maxSpeed : SpeedValue = 400 {
            doc 'Maximum safe speed [rad/s].';
        }
        attribute minSpeed : SpeedValue = 50 {
            doc 'Minimum operating speed [rad/s].';
        }
        attribute efficiency : EfficiencyValue = 0.75 {
            doc 'Pump hydraulic efficiency.';
        }

        // Current operating point derived from drive speed input
        attribute currentSpeed : SpeedValue = drive.speedCommand;
        attribute speedRatio : Real =
            if nominalSpeed > 0 then currentSpeed / nominalSpeed else 0;

        // Affinity-law-derived operating performance
        attribute currentFlow : FlowRateValue = nominalFlow * speedRatio;
        attribute currentHead : HeadValue = nominalHead * speedRatio ** 2;
        attribute currentPower : PowerValue = nominalPower * speedRatio ** 3;

        // Outlet port carries computed flow and pressure
        attribute outlet.flowRate = currentFlow;
        attribute outlet.pressure = currentHead * 9810;

        // Inlet port receives upstream fluid conditions
        attribute inlet.pressure = 101325;

        constraint safeSpeed {
            doc 'Pump speed must remain within safe operating limits.';
            currentSpeed >= 0 and currentSpeed <= maxSpeed;
        }

        exhibit state machine PumpStateMachine;
    }

    part def ElectricMotor {
        doc
        /*
         * Three-phase AC induction motor driving the centrifugal
         * pump. The motor speed is determined by the VFD output
         * frequency according to the synchronous speed relation.
         */;

        port electrical : ElectricalPowerInPort;
        port mechanicalOut : SpeedCommandOutPort;

        attribute poles : Integer = 2 {
            doc 'Number of motor poles.';
        }
        attribute ratedSpeed : SpeedValue = 314.16;
        attribute ratedPower : PowerValue = 22000;
        attribute ratedVoltage : VoltageValue = 400;
        attribute ratedFrequency : FrequencyValue = 50;
        attribute efficiency : EfficiencyValue = 0.92;
        attribute slip : Real = 0.03 {
            doc 'Rated slip fraction for induction motor.';
        }
        attribute powerFactor : Real = 0.85;

        // Synchronous speed: omega_sync = 2 * pi * f * 2 / poles
        attribute synchronousSpeed : SpeedValue =
            2 * 3.14159 * electrical.lineFrequency * 2 / poles;

        // Actual speed accounting for slip
        attribute actualSpeed : SpeedValue =
            synchronousSpeed * (1 - slip);

        // Electrical input power (three-phase): P = sqrt(3) * V * I * pf
        attribute electricalInputPower : PowerValue =
            1.732 * electrical.lineVoltage * electrical.lineCurrent * powerFactor;

        // Mechanical output power after motor losses
        attribute mechanicalOutputPower : PowerValue =
            electricalInputPower * efficiency;

        // Output speed to pump drive
        attribute mechanicalOut.speedCommand = actualSpeed;

        constraint safeElectricalInput {
            doc 'Motor electrical input must stay within rated limits.';
            electrical.lineVoltage <= ratedVoltage * 1.1 and
            electrical.lineFrequency <= 60;
        }

        exhibit state machine MotorStateMachine;
    }

    part def VariableFrequencyDrive {
        doc
        /*
         * Variable Frequency Drive (VFD) that converts fixed-frequency
         * AC input power to variable-frequency AC output, enabling
         * precise speed control of the electric motor. Employs
         * voltage-to-frequency (V/f) control strategy.
         */;

        port lineInput : ElectricalPowerInPort;
        port motorOutput : ElectricalPowerOutPort;
        port commandInput : SpeedCommandInPort;

        attribute ratedPower : PowerValue = 25000;
        attribute inputFrequency : FrequencyValue = 50;
        attribute inputVoltage : VoltageValue = 400;
        attribute minOutputFreq : FrequencyValue = 0;
        attribute maxOutputFreq : FrequencyValue = 60;
        attribute efficiency : EfficiencyValue = 0.96;

        // Convert commanded speed to required output frequency
        // For a 2-pole motor: f = omega / (2 * pi)
        attribute commandedSpeed : SpeedValue = commandInput.speedCommand;
        attribute rawOutputFreq : FrequencyValue =
            if commandedSpeed > 0 then commandedSpeed / (2 * 3.14159) else 0;

        // Clamp output frequency to allowed range
        attribute outputFreq : FrequencyValue =
            if rawOutputFreq > maxOutputFreq then maxOutputFreq
            else if rawOutputFreq < minOutputFreq then minOutputFreq
            else rawOutputFreq;

        // V/f control: output voltage proportional to frequency
        attribute outputVoltage : VoltageValue =
            if inputFrequency > 0 then inputVoltage * (outputFreq / inputFrequency) else 0;

        // Output current derived from rated power and voltage
        attribute outputCurrent : CurrentValue =
            if outputVoltage > 0 then ratedPower / outputVoltage else 0;

        // Propagate computed values to motor output port
        attribute motorOutput.lineFrequency = outputFreq;
        attribute motorOutput.lineVoltage = outputVoltage;
        attribute motorOutput.lineCurrent = outputCurrent;

        constraint safeOutput {
            doc 'VFD output frequency and voltage must stay within rated limits.';
            outputFreq <= maxOutputFreq and outputVoltage <= 600;
        }

        exhibit state machine VFDStateMachine;
    }

    part def ProcessController {
        doc
        /*
         * Central process controller implementing energy-efficient
         * affinity-law-based speed control with PI feedback correction.
         * Receives flow and pressure measurements, compares to
         * setpoints, computes the required speed using affinity laws,
         * and commands the VFD accordingly.
         */;

        port flowFeedback : FlowSignalInPort;
        port pressureFeedback : PressureSignalInPort;
        port vfdCommand : SpeedCommandOutPort;

        // Setpoints
        attribute flowSetpoint : FlowRateValue = 0.04 {
            doc 'Desired process flow rate [m^3/s].';
        }
        attribute headSetpoint : HeadValue = 28 {
            doc 'Desired pump head [m].';
        }

        // Pump nominal parameters for affinity law calculations
        attribute pumpNominalFlow : FlowRateValue = 0.05;
        attribute pumpNominalHead : HeadValue = 30;
        attribute pumpNominalSpeed : SpeedValue = 314.16;
        attribute pumpNominalPower : PowerValue = 18000;

        // PI control gains
        attribute proportionalGain : Real = 0.5;
        attribute integralGain : Real = 0.1;

        // Operating limits for command output
        attribute maxCommandSpeed : SpeedValue = 400;
        attribute minCommandSpeed : SpeedValue = 50;

        // Measured values from transmitters
        attribute measuredFlow : FlowRateValue = flowFeedback.measuredFlowRate;
        attribute measuredPressure : PressureValue = pressureFeedback.measuredPressure;

        // Convert measured pressure to head: H = P / (rho * g)
        // For water: rho * g = 1000 * 9.81 = 9810
        attribute measuredHead : HeadValue =
            if measuredPressure > 0 then measuredPressure / 9810 else 0;

        // Error signals
        attribute flowError : FlowRateValue = flowSetpoint - measuredFlow;
        attribute headError : HeadValue = headSetpoint - measuredHead;

        // Feed-forward: affinity-law speed calculation
        // Speed ratio from flow: N1/N0 = Q1/Q0
        attribute flowSpeedRatio : Real =
            if pumpNominalFlow > 0 then flowSetpoint / pumpNominalFlow else 0;
        // Speed ratio from head: N1/N0 = sqrt(H1/H0)
        attribute headSpeedRatio : Real =
            if pumpNominalHead > 0 then (headSetpoint / pumpNominalHead) ** 0.5 else 0;
        // Average the two ratios to satisfy both flow and head targets
        attribute effectiveSpeedRatio : Real = (flowSpeedRatio + headSpeedRatio) / 2;
        // Clamp to physically meaningful range
        attribute clampedSpeedRatio : Real =
            if effectiveSpeedRatio < 0 then 0
            else if effectiveSpeedRatio > 1.2 then 1.2
            else effectiveSpeedRatio;

        attribute feedForwardSpeed : SpeedValue =
            if pumpNominalSpeed > 0 then pumpNominalSpeed * clampedSpeedRatio else 0;
        attribute predictedPower : PowerValue =
            if pumpNominalPower > 0 then pumpNominalPower * clampedSpeedRatio ** 3 else 0;

        // Feedback correction (PI control)
        attribute pCorrection : SpeedValue =
            proportionalGain * (flowError * 10 + headError * 0.5);
        attribute iCorrection : SpeedValue =
            integralGain * (flowError + headError * 0.5);
        attribute correctedSpeed : SpeedValue =
            feedForwardSpeed + pCorrection + iCorrection;

        // Final command clamped to safe operating range
        attribute finalCommand : SpeedValue =
            if correctedSpeed < minCommandSpeed then minCommandSpeed
            else if correctedSpeed > maxCommandSpeed then maxCommandSpeed
            else correctedSpeed;

        // Output speed command to VFD
        attribute vfdCommand.speedCommand = finalCommand;

        // Energy efficiency metric
        attribute energyEfficiency : EfficiencyValue =
            if predictedPower > 0 then
                (measuredFlow * measuredPressure) / predictedPower
            else 0;

        constraint commandWithinLimits {
            doc 'Controller output must stay within pump safe operating limits.';
            finalCommand >= minCommandSpeed and finalCommand <= maxCommandSpeed;
        }

        exhibit state machine ControllerStateMachine;
    }

    part def FlowTransmitter {
        doc
        /*
         * Flow transmitter installed on the pump outlet piping.
         * Continuously measures the actual flow rate and transmits
         * a signal to the process controller for feedback control.
         */;

        port fluidConnection : FluidPort;
        port signalOut : FlowSignalOutPort;

        attribute rangeMin : FlowRateValue = 0 {
            doc 'Minimum measurable flow [m^3/s].';
        }
        attribute rangeMax : FlowRateValue = 0.1 {
            doc 'Maximum measurable flow [m^3/s].';
        }
        attribute accuracy : EfficiencyValue = 0.005 {
            doc 'Measurement accuracy as fraction of full scale.';
        }
        attribute responseTime : Real = 0.1 {
            doc 'Response time [s].';
        }

        // Measured flow with range clamping
        attribute measuredFlow : FlowRateValue =
            if fluidConnection.flowRate < rangeMin then rangeMin
            else if fluidConnection.flowRate > rangeMax then rangeMax
            else fluidConnection.flowRate;

        // Propagate measured value to output port
        attribute signalOut.measuredFlowRate = measuredFlow;

        exhibit state machine TransmitterStateMachine;
    }

    part def PressureTransmitter {
        doc
        /*
         * Pressure transmitter installed on the pump outlet piping.
         * Continuously measures the discharge pressure and transmits
         * a signal to the process controller for feedback control.
         */;

        port fluidConnection : FluidPort;
        port signalOut : PressureSignalOutPort;

        attribute rangeMin : PressureValue = 0 {
            doc 'Minimum measurable pressure [Pa].';
        }
        attribute rangeMax : PressureValue = 500000 {
            doc 'Maximum measurable pressure [Pa].';
        }
        attribute accuracy : EfficiencyValue = 0.005 {
            doc 'Measurement accuracy as fraction of full scale.';
        }
        attribute responseTime : Real = 0.1 {
            doc 'Response time [s].';
        }

        // Measured pressure with range clamping
        attribute measuredPressure : PressureValue =
            if fluidConnection.pressure < rangeMin then rangeMin
            else if fluidConnection.pressure > rangeMax then rangeMax
            else fluidConnection.pressure;

        // Propagate measured value to output port
        attribute signalOut.measuredPressure = measuredPressure;

        exhibit state machine TransmitterStateMachine;
    }

    // ================================================================
    // SYSTEM INTEGRATION
    // ================================================================

    part def PumpingSystem {
        doc
        /*
         * Complete automated industrial pumping system integrating
         * all components. Implements energy-efficient, affinity-law-
         * based variable speed control of a centrifugal pump through
         * a continuous feedback loop.
         */;

        // External fluid interface ports
        port processInlet : FluidPort {
            doc 'Process fluid inlet from upstream supply.';
        }
        port processOutlet : FluidPort {
            doc 'Process fluid outlet to downstream process.';
        }

        // Internal components
        part pump : CentrifugalPump;
        part motor : ElectricMotor;
        part vfd : VariableFrequencyDrive;
        part controller : ProcessController;
        part flowSensor : FlowTransmitter;
        part pressureSensor : PressureTransmitter;

        // --- Fluid connections ---
        connection inletToPump : FluidConnection {
            connect processInlet to pump.inlet;
        }
        connection pumpToFlowSensor : FluidConnection {
            connect pump.outlet to flowSensor.fluidConnection;
        }
        connection pumpToPressureSensor : FluidConnection {
            connect pump.outlet to pressureSensor.fluidConnection;
        }
        connection pumpToOutlet : FluidConnection {
            connect pump.outlet to processOutlet;
        }

        // --- Electrical power connection ---
        connection vfdToMotor : ElectricalPowerLink {
            connect vfd.motorOutput to motor.electrical;
        }

        // --- Mechanical speed command connection ---
        connection motorToPump : SpeedCommandLink {
            connect motor.mechanicalOut to pump.drive;
        }

        // --- Measurement signal connections ---
        connection flowToController : FlowSignalLink {
            connect flowSensor.signalOut to controller.flowFeedback;
        }
        connection pressureToController : PressureSignalLink {
            connect pressureSensor.signalOut to controller.pressureFeedback;
        }

        // --- Control command connection ---
        connection controllerToVfd : SpeedCommandLink {
            connect controller.vfdCommand to vfd.commandInput;
        }

        // System-level operating parameters
        attribute systemFlowSetpoint : FlowRateValue = 0.04;
        attribute systemHeadSetpoint : HeadValue = 28;
        attribute maxSystemPower : PowerValue = 25000;

        // Performance metrics
        attribute estimatedPower : PowerValue = controller.predictedPower;
        attribute throttleEquivalentPower : PowerValue = pump.nominalPower;
        attribute energySavings : PowerValue =
            if throttleEquivalentPower > estimatedPower then
                throttleEquivalentPower - estimatedPower
            else 0;
        attribute energySavingsRatio : EfficiencyValue =
            if throttleEquivalentPower > 0 then
                energySavings / throttleEquivalentPower
            else 0;

        constraint safeSystemPower {
            doc 'System power consumption must not exceed rated maximum.';
            estimatedPower <= maxSystemPower;
        }

        // Requirement satisfaction
        satisfy FlowControlRequirement;
        satisfy PressureControlRequirement;
        satisfy EnergyEfficiencyRequirement;
        satisfy AffinityLawAccuracyRequirement;
        satisfy SafeSpeedLimitRequirement;
        satisfy VFDControlRangeRequirement;
        satisfy ContinuousFeedbackRequirement;
    }

    // ================================================================
    // REQUIREMENTS
    // ================================================================

    requirement def FlowControlRequirement {
        doc
        /*
         * The system shall maintain the process fluid flow rate at
         * the desired setpoint within the specified tolerance using
         * affinity-law-based variable speed control.
         */;

        subject system : PumpingSystem;
        attribute tolerance : FlowRateValue = 0.002 {
            doc 'Allowable deviation from flow setpoint [m^3/s].';
        }

        assert flowControl {
            doc 'Measured flow shall remain within tolerance of the controller setpoint.';
            system.controller.measuredFlow >=
                system.controller.flowSetpoint - tolerance and
            system.controller.measuredFlow <=
                system.controller.flowSetpoint + tolerance;
        }
    }

    requirement def PressureControlRequirement {
        doc
        /*
         * The system shall maintain the pump discharge pressure at
         * the desired setpoint within the specified tolerance.
         */;

        subject system : PumpingSystem;
        attribute tolerance : PressureValue = 20000 {
            doc 'Allowable deviation from pressure setpoint [Pa].';
        }

        assert pressureControl {
            doc 'Measured pressure shall remain within tolerance of the head-derived setpoint.';
            system.controller.measuredPressure >=
                system.controller.headSetpoint * 9810 - tolerance and
            system.controller.measuredPressure <=
                system.controller.headSetpoint * 9810 + tolerance;
        }
    }

    requirement def EnergyEfficiencyRequirement {
        doc
        /*
         * The system shall achieve energy savings of at least 20%
         * compared to constant-speed throttling-based operation
         * when operating below 80% of maximum flow capacity,
         * by leveraging the cubic relationship between power and
         * speed inherent in the pump affinity laws.
         */;

        subject system : PumpingSystem;

        assert energySavings {
            doc 'Energy savings ratio shall exceed 20% at partial load.';
            system.energySavingsRatio >= 0.20;
        }
    }

    requirement def AffinityLawAccuracyRequirement {
        doc
        /*
         * The controller's affinity-law-based speed calculation
         * shall predict pump power consumption within 10% of the
         * actual value under steady-state operating conditions.
         */;

        subject system : PumpingSystem;

        assert affinityAccuracy {
            doc 'Predicted power shall be within 10% of actual pump power.';
            system.controller.predictedPower >=
                system.pump.currentPower * 0.9 and
            system.controller.predictedPower <=
                system.pump.currentPower * 1.1;
        }
    }

    requirement def SafeSpeedLimitRequirement {
        doc
        /*
         * The pump rotational speed shall never exceed the maximum
         * safe operating speed to prevent mechanical damage and
         * ensure system integrity under all operating conditions.
         */;

        subject system : PumpingSystem;

        assert safeSpeed {
            doc 'Pump speed shall remain at or below the maximum safe limit.';
            system.pump.currentSpeed <= system.pump.maxSpeed;
        }
    }

    requirement def VFDControlRangeRequirement {
        doc
        /*
         * The Variable Frequency Drive shall provide continuous
         * speed control across the full operating range from
         * minimum to maximum frequency, enabling precise matching
         * of pump output to process demand.
         */;

        subject system : PumpingSystem;

        assert vfdRange {
            doc 'VFD shall support output frequencies from 0 to at least 50 Hz.';
            system.vfd.maxOutputFreq >= 50 and
            system.vfd.minOutputFreq <= 10;
        }
    }

    requirement def ContinuousFeedbackRequirement {
        doc
        /*
         * The system shall continuously monitor flow and pressure
         * through transmitters and adjust pump speed in a closed
         * feedback loop to maintain the desired operating conditions.
         */;

        subject system : PumpingSystem;

        assert continuousLoop {
            doc 'Transmitter measurements shall be continuously fed to the controller.';
            system.controller.flowFeedback.measuredFlowRate ==
                system.flowSensor.signalOut.measuredFlowRate and
            system.controller.pressureFeedback.measuredPressure ==
                system.pressureSensor.signalOut.measuredPressure;
        }
    }
}
