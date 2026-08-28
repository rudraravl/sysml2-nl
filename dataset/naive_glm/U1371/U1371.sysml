package AutomatedFluidFlowControlSystem {
    import ScalarValues::*;

    // =====================================================================
    // Value types (with units declared via doc / semantic naming)
    // =====================================================================
    value type PressureValue :> Real {
        doc "Absolute or gauge pressure [Pa].";
    }
    value type PressureDiffValue :> Real {
        doc "Differential pressure [Pa].";
    }
    value type FlowRateValue :> Real {
        doc "Volumetric flow rate [m3/s].";
    }
    value type VelocityValue :> Real {
        doc "Fluid velocity [m/s].";
    }
    value type AreaValue :> Real {
        doc "Cross-sectional area [m2].";
    }
    value type DensityValue :> Real {
        doc "Mass density [kg/m3].";
    }
    value type DiameterValue :> Real {
        doc "Diameter [m].";
    }
    value type FractionValue :> Real {
        doc "Dimensionless fraction in range [0,1].";
        :>> min = 0.0;
        :>> max = 1.0;
    }
    value type FrequencyValue :> Real {
        doc "Sampling frequency [1/s].";
    }
    value type LengthValue :> Real {
        doc "Length [m].";
    }
    value type TimeValue :> Real {
        doc "Time [s].";
    }
    value type GainValue :> Real {
        doc "Dimensionless controller gain.";
    }

    // =====================================================================
    // Items
    // =====================================================================
    item def Liquid {
        attribute density : DensityValue;
        attribute dynamicViscosity : Real;
    }

    item def Water :> Liquid {
        :>> density = 1000.0;
        :>> dynamicViscosity = 0.001;
    }

    // =====================================================================
    // Ports
    // =====================================================================
    port def FluidFlowPort {
        in liquid : Liquid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute temperature : Real;
    }

    port def PressureSignalPort {
        out pressure : PressureValue;
    }

    port def VelocitySignalPort {
        out velocity : VelocityValue;
    }

    port def FlowRateSignalPort {
        out flowRate : FlowRateValue;
    }

    port def ValveCommandPort {
        in openingCommand : FractionValue;
    }

    port def PumpCommandPort {
        in pumpEnable : Boolean;
        in pumpThrottle : FractionValue;
    }

    port def AlarmPort {
        out alarmActive : Boolean;
        out alarmCode : Integer;
    }

    // =====================================================================
    // Component part definitions
    // =====================================================================
    part def Reservoir {
        attribute capacity : Real;
        attribute fillLevel : Real;
        attribute minLevel : Real;
        attribute maxLevel : Real;
        port outlet : FluidFlowPort;

        action def supplyLiquid {
            in level : Real;
            out outletFlow : FluidFlowPort;
            if level > minLevel {
                outletFlow.flowRate := 0.0;
            } else {
                outletFlow.flowRate := 0.0;
            }
        }
    }

    part def Pump {
        attribute nominalFlowRate : FlowRateValue;
        attribute pressureBoost : PressureValue;
        attribute pumpEnabled : Boolean;
        attribute throttle : FractionValue;
        port inlet : FluidFlowPort;
        port outlet : FluidFlowPort;
        port command : PumpCommandPort;

        action def pumpLiquid {
            in inletFlow : FluidFlowPort;
            out outletFlow : FluidFlowPort;
            if pumpEnabled {
                outletFlow.pressure := inletFlow.pressure + pressureBoost * throttle;
                outletFlow.flowRate := nominalFlowRate * throttle;
            } else {
                outletFlow.pressure := inletFlow.pressure;
                outletFlow.flowRate := 0.0;
            }
        }
    }

    part def VenturiTube {
        attribute inletDiameter : DiameterValue;
        attribute throatDiameter : DiameterValue;
        attribute inletArea : AreaValue;
        attribute throatArea : AreaValue;
        attribute dischargeCoefficient : Real;
        attribute tubeLength : LengthValue;

        port inlet : FluidFlowPort;
        port outlet : FluidFlowPort;
        port inletTap : FluidFlowPort;
        port throatTap : FluidFlowPort;

        computation computeAreas {
            :>> inletArea = 3.141592653589793 * (inletDiameter / 2.0) * (inletDiameter / 2.0);
            :>> throatArea = 3.141592653589793 * (throatDiameter / 2.0) * (throatDiameter / 2.0);
        }
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        attribute fullScaleRange : PressureValue;
        attribute accuracyPercent : Real;
        attribute samplingRate : FrequencyValue;
        port fluidTap : FluidFlowPort;
        port signalOut : PressureSignalPort;

        action def measurePressure {
            in tap : FluidFlowPort;
            out signal : PressureSignalPort;
            signal.pressure := tap.pressure;
            measuredPressure := tap.pressure;
        }
    }

    part def VelocitySensor {
        attribute measuredVelocity : VelocityValue;
        attribute fullScaleRange : VelocityValue;
        attribute accuracyPercent : Real;
        port fluidTap : FluidFlowPort;
        port signalOut : VelocitySignalPort;

        action def measureVelocity {
            in tap : FluidFlowPort;
            out signal : VelocitySignalPort;
            signal.velocity := tap.flowRate / 0.001;
            measuredVelocity := signal.velocity;
        }
    }

    part def ControlValve {
        attribute opening : FractionValue;
        attribute maxOpening : FractionValue;
        attribute minOpening : FractionValue;
        attribute valveCoefficient : Real;
        attribute commandedOpening : FractionValue;
        port inlet : FluidFlowPort;
        port outlet : FluidFlowPort;
        port commandIn : ValveCommandPort;
        port feedbackOut : FlowRateSignalPort;

        action def adjustOpening {
            in cmd : FractionValue;
            if cmd > maxOpening {
                opening := maxOpening;
            } else if cmd < minOpening {
                opening := minOpening;
            } else {
                opening := cmd;
            }
            commandedOpening := cmd;
        }

        action def passFlow {
            in inletFlow : FluidFlowPort;
            out outletFlow : FluidFlowPort;
            outletFlow.pressure := inletFlow.pressure * (1.0 - 0.5 * opening);
            outletFlow.flowRate := inletFlow.flowRate * opening;
            feedbackOut.flowRate := outletFlow.flowRate;
        }
    }

    // =====================================================================
    // Controller
    // =====================================================================
    part def Controller {
        attribute targetFlowRate : FlowRateValue;
        attribute measuredFlowRate : FlowRateValue;
        attribute flowError : FlowRateValue;
        attribute previousError : FlowRateValue;
        attribute integralTerm : FlowRateValue;
        attribute derivativeTerm : FlowRateValue;
        attribute proportionalGain : GainValue;
        attribute integralGain : GainValue;
        attribute derivativeGain : GainValue;
        attribute density : DensityValue;
        attribute inletArea : AreaValue;
        attribute throatArea : AreaValue;
        attribute dischargeCoefficient : Real;
        attribute alarmPressureThreshold : PressureDiffValue;
        attribute alarmActive : Boolean;
        attribute alarmCode : Integer;
        attribute valveOpening : FractionValue;
        attribute controlLoopActive : Boolean;
        attribute startCommand : Boolean;
        attribute stopCommand : Boolean;
        attribute resetCommand : Boolean;
        attribute systemReady : Boolean;

        port pressureInletIn : PressureSignalPort;
        port pressureThroatIn : PressureSignalPort;
        port velocityInletIn : VelocitySignalPort;
        port velocityThroatIn : VelocitySignalPort;
        port pumpCommandOut : PumpCommandPort;
        port valveCommandOut : ValveCommandPort;
        port alarmOut : AlarmPort;

        // Bernoulli-based flow rate computation:
        // Q = Cd * At * sqrt( 2 * (p_inlet - p_throat) /
        //                     ( rho * (1 - (At/Ai)^2) ) )
        action def computeFlowRate {
            in pInlet : PressureValue;
            in pThroat : PressureValue;
            in rho : DensityValue;
            in Cd : Real;
            in At : AreaValue;
            in Ai : AreaValue;
            out Q : FlowRateValue;
            attribute dp : PressureDiffValue;
            attribute areaRatio : Real;
            attribute denom : Real;
            dp := pInlet - pThroat;
            areaRatio := At / Ai;
            denom := rho * (1.0 - areaRatio * areaRatio);
            if denom <= 0.0 {
                Q := 0.0;
            } else if dp < 0.0 {
                Q := 0.0;
            } else {
                Q := Cd * At * sqrt(2.0 * dp / denom);
            }
        }

        action def computeControl {
            in Qmeasured : FlowRateValue;
            in Qtarget : FlowRateValue;
            out opening : FractionValue;
            flowError := Qtarget - Qmeasured;
            integralTerm := integralTerm + flowError;
            derivativeTerm := flowError - previousError;
            previousError := flowError;
            opening := valveOpening
                + proportionalGain * flowError
                + integralGain * integralTerm
                + derivativeGain * derivativeTerm;
            if opening > 1.0 {
                opening := 1.0;
            }
            if opening < 0.0 {
                opening := 0.0;
            }
        }

        action def checkSafety {
            in pInlet : PressureValue;
            in pThroat : PressureValue;
            attribute dp : PressureDiffValue;
            dp := pInlet - pThroat;
            if dp > alarmPressureThreshold {
                alarmActive := true;
                alarmCode := 1;
            } else {
                alarmActive := false;
                alarmCode := 0;
            }
        }

        state machine operationStates {
            state standby {
                entry {
                    alarmActive := false;
                    alarmCode := 0;
                    controlLoopActive := false;
                    valveOpening := 0.0;
                    pumpCommandOut.pumpEnable := false;
                    pumpCommandOut.pumpThrottle := 0.0;
                    valveCommandOut.openingCommand := 0.0;
                    systemReady := false;
                }
                do {
                    if startCommand {
                        systemReady := true;
                    }
                }
            }

            state startup {
                entry {
                    controlLoopActive := false;
                    pumpCommandOut.pumpEnable := true;
                    pumpCommandOut.pumpThrottle := 0.3;
                    valveCommandOut.openingCommand := 0.2;
                    valveOpening := 0.2;
                }
                do {
                    computeFlowRate(pressureInletIn.pressure,
                                    pressureThroatIn.pressure,
                                    density,
                                    dischargeCoefficient,
                                    throatArea,
                                    inletArea,
                                    measuredFlowRate);
                    checkSafety(pressureInletIn.pressure,
                                pressureThroatIn.pressure);
                    if measuredFlowRate > 0.0 {
                        systemReady := true;
                    }
                }
            }

            state normal {
                entry {
                    controlLoopActive := true;
                    pumpCommandOut.pumpEnable := true;
                    pumpCommandOut.pumpThrottle := 1.0;
                }
                do {
                    computeFlowRate(pressureInletIn.pressure,
                                    pressureThroatIn.pressure,
                                    density,
                                    dischargeCoefficient,
                                    throatArea,
                                    inletArea,
                                    measuredFlowRate);
                    computeControl(measuredFlowRate,
                                   targetFlowRate,
                                   valveOpening);
                    valveCommandOut.openingCommand := valveOpening;
                    checkSafety(pressureInletIn.pressure,
                                pressureThroatIn.pressure);
                }
            }

            state shutdown {
                entry {
                    controlLoopActive := false;
                    valveCommandOut.openingCommand := 0.0;
                    valveOpening := 0.0;
                    pumpCommandOut.pumpEnable := false;
                    pumpCommandOut.pumpThrottle := 0.0;
                }
                do {
                    if !startCommand {
                        // remain in shutdown until external reset
                    }
                }
            }

            state alarm {
                entry {
                    controlLoopActive := false;
                    pumpCommandOut.pumpEnable := false;
                    pumpCommandOut.pumpThrottle := 0.0;
                    valveCommandOut.openingCommand := 0.0;
                    valveOpening := 0.0;
                    alarmActive := true;
                    alarmCode := 1;
                    alarmOut.alarmActive := true;
                    alarmOut.alarmCode := 1;
                }
                do {
                    checkSafety(pressureInletIn.pressure,
                                pressureThroatIn.pressure);
                    if resetCommand & !alarmActive {
                        // ready to leave alarm
                    }
                }
            }

            transition standby_to_startup first standby then startup
                when startCommand & systemReady;

            transition startup_to_normal first startup then normal
                when systemReady & !alarmActive;

            transition startup_to_alarm first startup then alarm
                when alarmActive;

            transition normal_to_shutdown first normal then shutdown
                when stopCommand;

            transition normal_to_alarm first normal then alarm
                when (pressureInletIn.pressure - pressureThroatIn.pressure) > alarmPressureThreshold;

            transition shutdown_to_standby first shutdown then standby
                when resetCommand & !startCommand;

            transition alarm_to_shutdown first alarm then shutdown
                when resetCommand & !alarmActive;

            transition alarm_to_standby first alarm then standby
                when resetCommand & !alarmActive & !stopCommand;
        }
    }

    // =====================================================================
    // System under consideration
    // =====================================================================
    part def FlowControlSystem {
        attribute systemName : String = "AutomatedVenturiFlowController";
        attribute operationalMode : String = "standby";
        attribute designTargetFlowRate : FlowRateValue = 0.005;

        part reservoir : Reservoir {
            :>> capacity = 1.0;
            :>> fillLevel = 0.8;
            :>> minLevel = 0.05;
            :>> maxLevel = 0.95;
        }

        part pump : Pump {
            :>> nominalFlowRate = 0.01;
            :>> pressureBoost = 200000.0;
            :>> pumpEnabled = false;
            :>> throttle = 0.0;
        }

        part venturi : VenturiTube {
            :>> inletDiameter = 0.05;
            :>> throatDiameter = 0.025;
            :>> inletArea = 0.0019635;
            :>> throatArea = 0.00049087;
            :>> dischargeCoefficient = 0.98;
            :>> tubeLength = 0.30;
        }

        part pressureInletSensor : PressureSensor {
            :>> fullScaleRange = 500000.0;
            :>> accuracyPercent = 0.1;
            :>> samplingRate = 100.0;
        }

        part pressureThroatSensor : PressureSensor {
            :>> fullScaleRange = 500000.0;
            :>> accuracyPercent = 0.1;
            :>> samplingRate = 100.0;
        }

        part velocityInletSensor : VelocitySensor {
            :>> fullScaleRange = 10.0;
            :>> accuracyPercent = 0.5;
        }

        part velocityThroatSensor : VelocitySensor {
            :>> fullScaleRange = 40.0;
            :>> accuracyPercent = 0.5;
        }

        part controlValve : ControlValve {
            :>> maxOpening = 1.0;
            :>> minOpening = 0.0;
            :>> opening = 0.5;
            :>> valveCoefficient = 0.85;
        }

        part controller : Controller {
            :>> targetFlowRate = 0.005;
            :>> proportionalGain = 2.0;
            :>> integralGain = 0.1;
            :>> derivativeGain = 0.05;
            :>> density = 1000.0;
            :>> inletArea = 0.0019635;
            :>> throatArea = 0.00049087;
            :>> dischargeCoefficient = 0.98;
            :>> alarmPressureThreshold = 300000.0;
            :>> alarmActive = false;
            :>> alarmCode = 0;
            :>> valveOpening = 0.0;
            :>> controlLoopActive = false;
            :>> startCommand = false;
            :>> stopCommand = false;
            :>> resetCommand = false;
            :>> systemReady = false;
        }

        // Fluid connections
        connection reservoirToPump connect reservoir.outlet to pump.inlet;
        connection pumpToVenturi connect pump.outlet to venturi.inlet;
        connection venturiToValve connect venturi.outlet to controlValve.inlet;

        // Sensor tap connections (sense pressures/velocities at taps)
        connection inletTapPressure connect venturi.inletTap to pressureInletSensor.fluidTap;
        connection inletTapVelocity connect venturi.inletTap to velocityInletSensor.fluidTap;
        connection throatTapPressure connect venturi.throatTap to pressureThroatSensor.fluidTap;
        connection throatTapVelocity connect venturi.throatTap to velocityThroatSensor.fluidTap;

        // Signal connections
        connection pressureInletSignal connect pressureInletSensor.signalOut to controller.pressureInletIn;
        connection pressureThroatSignal connect pressureThroatSensor.signalOut to controller.pressureThroatIn;
        connection velocityInletSignal connect velocityInletSensor.signalOut to controller.velocityInletIn;
        connection velocityThroatSignal connect velocityThroatSensor.signalOut to controller.velocityThroatIn;

        // Command connections
        connection pumpCommandConnection connect controller.pumpCommandOut to pump.command;
        connection valveCommandConnection connect controller.valveCommandOut to controlValve.commandIn;

        // Alarm connection
        connection alarmIndicatorConnection connect controller.alarmOut to ... // external alarm indicator
    }

    // =====================================================================
    // Requirements
    // =====================================================================
    requirement def FlowControlSystemRequirement {
        doc "Top-level requirement for the automated fluid flow measurement and control system.";
        subject system : FlowControlSystem;
        objective {
            doc "The system shall precisely manage liquid flow through a pipeline by measuring a Venturi-induced pressure drop and adjusting a control valve in a closed feedback loop to maintain a pre-set target flow rate.";
        }
    }

    requirement def VenturiMeasurementRequirement {
        doc "Flow measurement based on Bernoulli's principle.";
        subject venturi : VenturiTube;
        subject pInlet : PressureSensor;
        subject pThroat : PressureSensor;
        objective {
            doc "The system shall measure the differential pressure between the Venturi inlet and throat and shall compute the volumetric flow rate using Bernoulli's principle and continuity: Q = Cd * At * sqrt(2*(p1-p2)/(rho*(1-(At/Ai)^2))).";
        }
        assume {
            doc "The liquid is incompressible and the flow is steady-state single-phase.";
        }
    }

    requirement def SensorCoverageRequirement {
        doc "Sensors at inlet and throat.";
        subject pInlet : PressureSensor;
        subject pThroat : PressureSensor;
        subject vInlet : VelocitySensor;
        subject vThroat : VelocitySensor;
        objective {
            doc "Pressure and velocity sensors shall be installed at both the Venturi inlet and the Venturi throat and shall provide real-time measurements to the controller.";
        }
    }

    requirement def FeedbackControlRequirement {
        doc "Closed-loop valve control.";
        subject controller : Controller;
        subject valve : ControlValve;
        objective {
            doc "During normal operation, the controller shall continuously compare the measured flow rate to the target flow rate and shall command the control valve opening to reduce the difference, closing the valve when flow is too high and opening it when flow is too low.";
        }
        perform {
            doc "Steady-state flow rate error shall be within +/-2 percent of the target flow rate.";
        }
    }

    requirement def OperationalStatesRequirement {
        doc "Operational state machine.";
        subject controller : Controller;
        objective {
            doc "The system shall operate through the states standby, startup, normal operation, and shutdown, with an additional alarm state for safety.";
        }
    }

    requirement def SafetyAlarmRequirement {
        doc "Abnormal pressure-drop alarm.";
        subject controller : Controller;
        objective {
            doc "If an abnormal pressure drop is detected across the Venturi section exceeding the alarm threshold, the system shall transition to the alarm state, deactivate the pump, close the control valve, and raise an alarm indication.";
        }
    }

    requirement def PumpDriveRequirement {
        doc "Pump drives flow from reservoir.";
        subject pump : Pump;
        subject reservoir : Reservoir;
        objective {
            doc "The pump shall draw liquid from the reservoir and provide the necessary pressure head to drive flow through the Venturi tube and downstream control valve.";
        }
    }

    // Requirement instances
    requirement flowControlSystemRequirement : FlowControlSystemRequirement {
        subject system = FlowControlSystem::system;
    }

    requirement venturiMeasurementRequirement : VenturiMeasurementRequirement {
        subject venturi = FlowControlSystem::venturi;
        subject pInlet = FlowControlSystem::pressureInletSensor;
        subject pThroat = FlowControlSystem::pressureThroatSensor;
    }

    requirement sensorCoverageRequirement : SensorCoverageRequirement {
        subject pInlet = FlowControlSystem::pressureInletSensor;
        subject pThroat = FlowControlSystem::pressureThroatSensor;
        subject vInlet = FlowControlSystem::velocityInletSensor;
        subject vThroat = FlowControlSystem::velocityThroatSensor;
    }

    requirement feedbackControlRequirement : FeedbackControlRequirement {
        subject controller = FlowControlSystem::controller;
        subject valve = FlowControlSystem::controlValve;
    }

    requirement operationalStatesRequirement : OperationalStatesRequirement {
        subject controller = FlowControlSystem::controller;
    }

    requirement safetyAlarmRequirement : SafetyAlarmRequirement {
        subject controller = FlowControlSystem::controller;
    }

    requirement pumpDriveRequirement : PumpDriveRequirement {
        subject pump = FlowControlSystem::pump;
        subject reservoir = FlowControlSystem::reservoir;
    }

    // Satisfaction links
    satisfaction satisfy venturiMeasurementRequirement by venturi;
    satisfaction satisfy sensorCoverageRequirement by pressureInletSensor;
    satisfaction satisfy sensorCoverageRequirement by pressureThroatSensor;
    satisfaction satisfy sensorCoverageRequirement by velocityInletSensor;
    satisfaction satisfy sensorCoverageRequirement by velocityThroatSensor;
    satisfaction satisfy feedbackControlRequirement by controller;
    satisfaction satisfy operationalStatesRequirement by controller;
    satisfaction satisfy safetyAlarmRequirement by controller;
    satisfaction satisfy pumpDriveRequirement by pump;
    satisfaction satisfy flowControlSystemRequirement by FlowControlSystem;
}
