package SafetyValveSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure;
    attribute def Temperature;
    attribute def FlowRate;
    attribute def Force;
    attribute def Area;
    attribute def Time;
    attribute def Percent;
    attribute def Boolean;

    value def bar : Pressure;
    value def degC : Temperature;
    value def kg_per_s : FlowRate;
    value def newton : Force;
    value def square_mm : Area;
    value def second : Time;
    value def percent : Percent;

    enum def ValveOperatingMode {
        enum closed;
        enum opening;
        enum relieving;
        enum reseating;
        enum manualTest;
        enum fault;
    }

    enum def FaultCode {
        enum none;
        enum sensorFailure;
        enum seatLeakage;
        enum actuatorJam;
        enum springFatigue;
        enum dischargeBlocked;
    }

    item def PressurizedFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute massFlow : FlowRate;
    }

    item def VentFluid :> PressurizedFluid {
        attribute dischargedSafely : Boolean;
    }

    item def ControlSignal {
        attribute commandedLift : Percent;
        attribute testCommand : Boolean;
        attribute resetCommand : Boolean;
    }

    item def DiagnosticSignal {
        attribute currentMode : ValveOperatingMode;
        attribute activeFault : FaultCode;
        attribute measuredPressure : Pressure;
        attribute valveLift : Percent;
    }

    port def ProcessFluidPort {
        in item fluidIn : PressurizedFluid;
        out item fluidOut : PressurizedFluid;
    }

    port def ReliefDischargePort {
        out item ventedFluid : VentFluid;
    }

    port def SignalInputPort {
        in item command : ControlSignal;
    }

    port def SignalOutputPort {
        out item diagnostic : DiagnosticSignal;
    }

    part def PressureVessel {
        attribute designPressure : Pressure = 16.0 [bar];
        attribute normalOperatingPressure : Pressure = 9.0 [bar];
        attribute maximumAllowableWorkingPressure : Pressure = 14.0 [bar];
        port processPort : ProcessFluidPort;
    }

    part def InletNozzle {
        attribute boreArea : Area = 490.0 [square_mm];
        port vesselSide : ProcessFluidPort;
        port valveSide : ProcessFluidPort;
    }

    part def ValveSeat {
        attribute seatDiameterArea : Area = 452.0 [square_mm];
        attribute leakageRateLimit : FlowRate = 0.002 [kg_per_s];
        port inlet : ProcessFluidPort;
        port outlet : ProcessFluidPort;
    }

    part def ValveDisc {
        attribute liftPosition : Percent = 0.0 [percent];
        attribute closingForce : Force;
        port lowerFace : ProcessFluidPort;
        port upperFace : ProcessFluidPort;
    }

    part def SpringAssembly {
        attribute springPreload : Force = 6200.0 [newton];
        attribute calibratedSetPressure : Pressure = 12.0 [bar];
        attribute blowdownMargin : Pressure = 1.0 [bar];
        attribute fatigueMargin : Percent = 25.0 [percent];
    }

    part def LiftActuator {
        attribute manualTestLift : Percent = 15.0 [percent];
        attribute maximumLift : Percent = 100.0 [percent];
        port commandPort : SignalInputPort;
    }

    part def PressureSensor {
        attribute measurementRangeMinimum : Pressure = 0.0 [bar];
        attribute measurementRangeMaximum : Pressure = 20.0 [bar];
        attribute accuracy : Percent = 0.5 [percent];
        port sensedFluid : ProcessFluidPort;
        port diagnosticOut : SignalOutputPort;
    }

    part def DischargeHeader {
        attribute backPressureLimit : Pressure = 1.5 [bar];
        attribute ratedReliefCapacity : FlowRate = 3.5 [kg_per_s];
        port inlet : ReliefDischargePort;
        port safeOutlet : ReliefDischargePort;
    }

    action def MonitorPressure {
        in item sensedFluid : PressurizedFluid;
        out item diagnostic : DiagnosticSignal;

        attribute setPressure : Pressure = 12.0 [bar];
        attribute reseatPressure : Pressure = 11.0 [bar];

        first start;
        then evaluatePressure;

        action evaluatePressure {
            if sensedFluid.pressure >= setPressure then
                diagnostic.currentMode = ValveOperatingMode::opening;
            else
                diagnostic.currentMode = ValveOperatingMode::closed;
            end;
        }

        then done;
    }

    action def RelieveOverpressure {
        in item inletFluid : PressurizedFluid;
        out item ventedFluid : VentFluid;
        out item diagnostic : DiagnosticSignal;

        attribute fullLiftPressure : Pressure = 13.2 [bar];
        attribute ratedCapacity : FlowRate = 3.5 [kg_per_s];

        first start;
        then modulateLift;

        action modulateLift {
            if inletFluid.pressure >= fullLiftPressure then
                diagnostic.valveLift = 100.0 [percent];
                ventedFluid.massFlow = ratedCapacity;
            else
                diagnostic.valveLift = 35.0 [percent];
                ventedFluid.massFlow = 1.2 [kg_per_s];
            end;
            ventedFluid.pressure = inletFluid.pressure;
            ventedFluid.temperature = inletFluid.temperature;
            ventedFluid.dischargedSafely = true;
            diagnostic.currentMode = ValveOperatingMode::relieving;
            diagnostic.activeFault = FaultCode::none;
        }

        then done;
    }

    action def ReseatValve {
        in item inletFluid : PressurizedFluid;
        out item diagnostic : DiagnosticSignal;

        attribute reseatPressure : Pressure = 11.0 [bar];

        first start;
        then checkReseat;

        action checkReseat {
            if inletFluid.pressure <= reseatPressure then
                diagnostic.valveLift = 0.0 [percent];
                diagnostic.currentMode = ValveOperatingMode::closed;
            else
                diagnostic.currentMode = ValveOperatingMode::reseating;
            end;
        }

        then done;
    }

    state def SafetyValveControllerStateMachine {
        attribute measuredPressure : Pressure;
        attribute setPressure : Pressure = 12.0 [bar];
        attribute reseatPressure : Pressure = 11.0 [bar];
        attribute fault : FaultCode = FaultCode::none;
        attribute mode : ValveOperatingMode = ValveOperatingMode::closed;

        state Closed;
        state Opening;
        state Relieving;
        state Reseating;
        state ManualTest;
        state Faulted;

        entry action Closed {
            mode = ValveOperatingMode::closed;
        }

        entry action Opening {
            mode = ValveOperatingMode::opening;
        }

        entry action Relieving {
            mode = ValveOperatingMode::relieving;
        }

        entry action Reseating {
            mode = ValveOperatingMode::reseating;
        }

        entry action ManualTest {
            mode = ValveOperatingMode::manualTest;
        }

        entry action Faulted {
            mode = ValveOperatingMode::fault;
        }

        transition first Closed;
        transition Closed to Opening
            if measuredPressure >= setPressure;
        transition Opening to Relieving
            if measuredPressure > setPressure;
        transition Relieving to Reseating
            if measuredPressure <= reseatPressure;
        transition Reseating to Closed
            if measuredPressure <= reseatPressure;
        transition Closed to ManualTest
            if mode == ValveOperatingMode::manualTest;
        transition ManualTest to Closed
            if measuredPressure < setPressure;
        transition Closed to Faulted
            if fault != FaultCode::none;
        transition Opening to Faulted
            if fault != FaultCode::none;
        transition Relieving to Faulted
            if fault != FaultCode::none;
        transition Reseating to Faulted
            if fault != FaultCode::none;
    }

    part def SpringLoadedSafetyValve {
        attribute setPressure : Pressure = 12.0 [bar];
        attribute reseatPressure : Pressure = 11.0 [bar];
        attribute overpressureLimit : Percent = 10.0 [percent];
        attribute responseTimeLimit : Time = 0.5 [second];
        attribute ratedReliefCapacity : FlowRate = 3.5 [kg_per_s];
        attribute currentMode : ValveOperatingMode = ValveOperatingMode::closed;
        attribute currentFault : FaultCode = FaultCode::none;

        port inlet : ProcessFluidPort;
        port outlet : ReliefDischargePort;
        port commandIn : SignalInputPort;
        port statusOut : SignalOutputPort;

        part seat : ValveSeat;
        part disc : ValveDisc;
        part spring : SpringAssembly;
        part actuator : LiftActuator;
        part pressureSensor : PressureSensor;

        perform action monitor : MonitorPressure;
        perform action relieve : RelieveOverpressure;
        perform action reseat : ReseatValve;
        exhibit state controller : SafetyValveControllerStateMachine;

        connect inlet to seat.inlet;
        connect seat.outlet to disc.lowerFace;
        connect disc.upperFace to outlet;
        connect commandIn to actuator.commandPort;
        connect inlet to pressureSensor.sensedFluid;
        connect pressureSensor.diagnosticOut to statusOut;
    }

    part def ProtectedProcessSystem {
        attribute systemDesignPressure : Pressure = 16.0 [bar];
        attribute normalPressure : Pressure = 9.0 [bar];

        part vessel : PressureVessel;
        part inletNozzle : InletNozzle;
        part safetyValve : SpringLoadedSafetyValve;
        part dischargeHeader : DischargeHeader;

        port processConnection : ProcessFluidPort;
        port ventConnection : ReliefDischargePort;
        port operatorCommand : SignalInputPort;
        port operatorStatus : SignalOutputPort;

        connect processConnection to vessel.processPort;
        connect vessel.processPort to inletNozzle.vesselSide;
        connect inletNozzle.valveSide to safetyValve.inlet;
        connect safetyValve.outlet to dischargeHeader.inlet;
        connect dischargeHeader.safeOutlet to ventConnection;
        connect operatorCommand to safetyValve.commandIn;
        connect safetyValve.statusOut to operatorStatus;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         * The safety valve system shall protect the pressure vessel by automatically opening
         * when process pressure reaches the calibrated set pressure, relieving fluid to a safe
         * discharge path, and reseating after pressure returns below the reseat threshold.
         */
        attribute setPressure : Pressure = 12.0 [bar];
        attribute reseatPressure : Pressure = 11.0 [bar];

        subject protectedSystem : ProtectedProcessSystem;

        require constraint {
            protectedSystem.safetyValve.setPressure == setPressure and
            protectedSystem.safetyValve.reseatPressure == reseatPressure
        }
    }

    requirement def OverpressureProtectionRequirement {
        doc
        /*
         * During an overpressure event, vessel pressure shall not exceed 110 percent of the
         * safety valve set pressure while the discharge path is available.
         */
        attribute allowedAccumulation : Percent = 10.0 [percent];
        attribute maximumProtectedPressure : Pressure = 13.2 [bar];

        subject protectedSystem : ProtectedProcessSystem;

        require constraint {
            protectedSystem.safetyValve.overpressureLimit <= allowedAccumulation
        }
    }

    requirement def ReliefCapacityRequirement {
        doc
        /*
         * The safety valve and discharge header shall pass the required relief mass flow
         * without exceeding the allowable back pressure.
         */
        attribute requiredReliefCapacity : FlowRate = 3.5 [kg_per_s];
        attribute maximumBackPressure : Pressure = 1.5 [bar];

        subject protectedSystem : ProtectedProcessSystem;

        require constraint {
            protectedSystem.safetyValve.ratedReliefCapacity >= requiredReliefCapacity and
            protectedSystem.dischargeHeader.ratedReliefCapacity >= requiredReliefCapacity and
            protectedSystem.dischargeHeader.backPressureLimit <= maximumBackPressure
        }
    }

    requirement def ResponseTimeRequirement {
        doc
        /*
         * The safety valve shall begin opening within the specified response time after
         * sensed pressure reaches the calibrated set pressure.
         */
        attribute maximumResponseTime : Time = 0.5 [second];

        subject valve : SpringLoadedSafetyValve;

        require constraint {
            valve.responseTimeLimit <= maximumResponseTime
        }
    }

    requirement def FailSafeRequirement {
        doc
        /*
         * Any detected sensor, actuator, seat leakage, spring, or discharge fault shall be
         * reported through the diagnostic output and shall place the valve controller in a
         * fault state for operator intervention.
         */
        subject valve : SpringLoadedSafetyValve;

        require constraint {
            valve.currentFault == FaultCode::none or
            valve.currentMode == ValveOperatingMode::fault
        }
    }

    satisfy PrimaryFunctionRequirement by ProtectedProcessSystem;
    satisfy OverpressureProtectionRequirement by ProtectedProcessSystem;
    satisfy ReliefCapacityRequirement by ProtectedProcessSystem;
    satisfy ResponseTimeRequirement by SpringLoadedSafetyValve;
    satisfy FailSafeRequirement by SpringLoadedSafetyValve;

    package OperationalScenario {

        action def NormalOperation {
            in item vesselFluid : PressurizedFluid;
            out item status : DiagnosticSignal;

            first start;
            then holdClosed;

            action holdClosed {
                status.currentMode = ValveOperatingMode::closed;
                status.measuredPressure = vesselFluid.pressure;
                status.valveLift = 0.0 [percent];
                status.activeFault = FaultCode::none;
            }

            then done;
        }

        action def OverpressureEvent {
            in item vesselFluid : PressurizedFluid;
            out item ventedFluid : VentFluid;
            out item status : DiagnosticSignal;

            first start;
            then detectOverpressure;
            then openValve;
            then dischargeFluid;
            then reseatAfterRecovery;
            then done;

            action detectOverpressure {
                status.measuredPressure = vesselFluid.pressure;
                status.currentMode = ValveOperatingMode::opening;
            }

            action openValve {
                status.valveLift = 100.0 [percent];
                status.currentMode = ValveOperatingMode::relieving;
            }

            action dischargeFluid {
                ventedFluid.pressure = vesselFluid.pressure;
                ventedFluid.temperature = vesselFluid.temperature;
                ventedFluid.massFlow = 3.5 [kg_per_s];
                ventedFluid.dischargedSafely = true;
            }

            action reseatAfterRecovery {
                status.valveLift = 0.0 [percent];
                status.currentMode = ValveOperatingMode::closed;
            }
        }
    }
}