package SlurryTransportSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value def Viscosity :> Real { unit 'mPa·s'; }
    value def FlowRate :> Real { unit 'L/s'; }
    value def Pressure :> Real { unit 'bar'; }
    value def RotationalSpeed :> Real { unit 'rpm'; }
    value def Volume :> Real { unit 'L'; }
    value def Mass :> Real { unit 'kg'; }
    value def Temperature :> Real { unit '°C'; }
    value def Power :> Real { unit 'kW'; }

    // ===== Item Types =====
    item def SolidMaterial {
        attribute particleSize : Real;
        attribute density : Mass;
    }
    item def LiquidMaterial {
        attribute density : Mass;
        attribute temperature : Temperature;
    }
    item def Slurry {
        attribute viscosity : Viscosity;
        attribute density : Mass;
        attribute solidFraction : Real;
    }

    // ===== Signal Definitions =====
    item def SensorReading {
        attribute value : Real;
        attribute timestamp : Time;
    }
    item def ViscosityReading :> SensorReading {
        redefines value : Viscosity;
    }
    item def FlowReading :> SensorReading {
        redefines value : FlowRate;
    }
    item def PressureReading :> SensorReading {
        redefines value : Pressure;
    }
    item def OperatorCommand {
        attribute commandType : String;
    }
    item def StartCommand :> OperatorCommand;
    item def ShutdownCommand :> OperatorCommand;
    item def EmergencyStopCommand :> OperatorCommand;

    // ===== Port Definitions =====
    port def SlurryPort {
        in item slurryIn : Slurry;
        out item slurryOut : Slurry;
    }
    port def SlurryInPort {
        in item slurryIn : Slurry;
    }
    port def SlurryOutPort {
        out item slurryOut : Slurry;
    }
    port def SolidInPort {
        in item solidIn : SolidMaterial;
    }
    port def LiquidInPort {
        in item liquidIn : LiquidMaterial;
    }
    port def DataOutPort {
        out item reading : SensorReading;
    }
    port def DataInPort {
        in item reading : SensorReading;
    }
    port def CommandInPort {
        in item command : OperatorCommand;
    }
    port def ControlOutPort {
        out attribute setpoint : Real;
    }
    port def ControlInPort {
        in attribute setpoint : Real;
    }

    // ===== Component Definitions =====

    part def MixingVessel {
        port solidIn : SolidInPort;
        port liquidIn : LiquidInPort;
        port slurryOut : SlurryOutPort;
        port speedControl : ControlInPort;

        attribute capacity : Volume = 5000 [L];
        attribute currentSpeed : RotationalSpeed;
        attribute targetViscosity : Viscosity = 200 [mPa·s];

        part agitator {
            attribute speed : RotationalSpeed;
        }

        action def MixMaterials {
            in solid : SolidMaterial;
            in liquid : LiquidMaterial;
            out slurry : Slurry;
        }

        state mixingControl {
            entry;
            do mix : MixMaterials;
        }
    }

    part def ViscosityMonitor {
        port slurryIn : SlurryInPort;
        port slurryOut : SlurryOutPort;
        port dataOut : DataOutPort;

        attribute measuredViscosity : Viscosity;
        attribute samplingInterval : Time = 1 [s];

        action def MeasureViscosity {
            in slurry : Slurry;
            out reading : ViscosityReading;
        }

        state monitoring {
            entry;
            do measure : MeasureViscosity;
        }
    }

    part def CentrifugalPump {
        port slurryIn : SlurryInPort;
        port slurryOut : SlurryOutPort;
        port speedControl : ControlInPort;

        attribute maxFlowRate : FlowRate = 500 [L/s];
        attribute currentOutput : FlowRate;
        attribute powerRating : Power = 75 [kW];
        attribute impellerSpeed : RotationalSpeed;

        action def PressurizeSlurry {
            in slurryIn : Slurry;
            out slurryOut : Slurry;
        }

        state pumping {
            entry;
            do pressurize : PressurizeSlurry;
        }
    }

    part def FlowMeter {
        port slurryIn : SlurryInPort;
        port slurryOut : SlurryOutPort;
        port dataOut : DataOutPort;

        attribute measuredFlowRate : FlowRate;
        attribute samplingInterval : Time = 1 [s];

        action def MeasureFlow {
            in slurry : Slurry;
            out reading : FlowReading;
        }

        state measuring {
            entry;
            do measure : MeasureFlow;
        }
    }

    part def Pipeline {
        port slurryIn : SlurryInPort;
        port slurryOut : SlurryOutPort;
        port pressureSensorData : DataOutPort;

        attribute length : Real = 1000 [m];
        attribute diameter : Real = 0.3 [m];
        attribute maxSafePressure : Pressure = 16 [bar];
        attribute currentPressure : Pressure;

        part pressureSensor {
            attribute measuredPressure : Pressure;
            attribute samplingInterval : Time = 1 [s];

            action def MeasurePressure {
                out reading : PressureReading;
            }

            state sensing {
                entry;
                do measure : MeasurePressure;
            }
        }

        action def TransportSlurry {
            in slurryIn : Slurry;
            out slurryOut : Slurry;
        }

        state transporting {
            entry;
            do transport : TransportSlurry;
        }
    }

    part def ValveAssembly {
        port slurryIn : SlurryInPort;
        port slurryOut : SlurryOutPort;
        port valveControl : ControlInPort;

        attribute isOpen : Boolean = true;

        action def CloseValve;
        action def OpenValve;

        state valveState {
            state open {
                entry;
                do openAction : OpenValve;
            }
            state closed {
                entry;
                do closeAction : CloseValve;
            }
        }
    }

    part def ControlSystem {
        port viscosityData : DataInPort;
        port flowData : DataInPort;
        port pressureData : DataInPort;
        port commandInput : CommandInPort;
        port mixingSpeedCmd : ControlOutPort;
        port pumpOutputCmd : ControlOutPort;
        port valveCmd : ControlOutPort;

        attribute targetViscosity : Viscosity = 200 [mPa·s];
        attribute targetFlowRate : FlowRate = 300 [L/s];
        attribute pressureHighThreshold : Pressure = 14 [bar];
        attribute pressureCriticalThreshold : Pressure = 16 [bar];
        attribute alarmFlowReduction : Real = 0.5;

        action def ProcessSensorData {
            in viscosity : ViscosityReading;
            in flow : FlowReading;
            in pressure : PressureReading;
        }

        action def AdjustMixingSpeed {
            in viscosity : Viscosity;
            out speedSetpoint : RotationalSpeed;
        }

        action def AdjustPumpOutput {
            in flow : FlowRate;
            in pressure : Pressure;
            out flowSetpoint : FlowRate;
        }

        action def EmergencyShutdown {
            out closeValves : Boolean;
            out haltPump : Boolean;
            out haltMixer : Boolean;
        }

        state controlStateMachine {
            state idle {
                entry;
                do wait : Action;
            }
            state startup {
                entry;
                do initialize : Action;
            }
            state normalOperation {
                entry;
                do regulate : ProcessSensorData;
            }
            state alarmState {
                entry;
                do reduceFlow : AdjustPumpOutput;
            }
            state shutdown {
                entry;
                do controlledStop : Action;
            }
            state emergencyStop {
                entry;
                do emergencyHalt : EmergencyShutdown;
            }

            transition idle_to_startup
                first idle
                accept StartCommand
                then startup;

            transition startup_to_normal
                first startup
                accept 'initialization complete'
                then normalOperation;

            transition normal_to_alarm
                first normalOperation
                accept 'pressure > pressureHighThreshold'
                then alarmState;

            transition alarm_to_normal
                first alarmState
                accept 'pressure <= pressureHighThreshold'
                then normalOperation;

            transition any_to_shutdown
                first {normalOperation, alarmState}
                accept ShutdownCommand
                then shutdown;

            transition any_to_emergency
                first {idle, startup, normalOperation, alarmState, shutdown}
                accept EmergencyStopCommand
                then emergencyStop;
        }
    }

    // ===== Requirements =====
    requirement def SlurryConsistencyRequirement {
        subject : Slurry;
        attribute requiredViscosity : Viscosity = 200 [mPa·s];
        attribute tolerance : Viscosity = 20 [mPa·s];
        require {
            subject.viscosity >= requiredViscosity - tolerance and
            subject.viscosity <= requiredViscosity + tolerance
        }
    }

    requirement def FlowRateRequirement {
        subject : FlowMeter;
        attribute requiredFlowRate : FlowRate = 300 [L/s];
        attribute tolerance : FlowRate = 30 [L/s];
        require {
            subject.measuredFlowRate >= requiredFlowRate - tolerance and
            subject.measuredFlowRate <= requiredFlowRate + tolerance
        }
    }

    requirement def PressureSafetyRequirement {
        subject : Pipeline;
        require {
            subject.currentPressure <= subject.maxSafePressure
        }
    }

    requirement def EmergencyStopRequirement {
        subject : ControlSystem;
        require {
            subject.controlStateMachine.emergencyStop.isActive implies
            (not subject.controlStateMachine.normalOperation.isActive and
             not subject.controlStateMachine.alarmState.isActive)
        }
    }

    requirement def ContinuousMonitoringRequirement {
        subject : ControlSystem;
        require {
            subject.viscosityData.reading.timestamp != null and
            subject.flowData.reading.timestamp != null and
            subject.pressureData.reading.timestamp != null
        }
    }

    // ===== System Assembly =====
    part def SlurryTransportPlant {
        part mixingVessel : MixingVessel;
        part viscosityMonitor : ViscosityMonitor;
        part centrifugalPump : CentrifugalPump;
        part flowMeter : FlowMeter;
        part pipeline : Pipeline;
        part valveAssembly : ValveAssembly;
        part controller : ControlSystem;

        // Material inputs
        // Solid and liquid feed into mixing vessel

        // Slurry flow connections
        connect mixingVessel.slurryOut to viscosityMonitor.slurryIn;
        connect viscosityMonitor.slurryOut to centrifugalPump.slurryIn;
        connect centrifugalPump.slurryOut to flowMeter.slurryIn;
        connect flowMeter.slurryOut to pipeline.slurryIn;
        connect pipeline.slurryOut to valveAssembly.slurryIn;

        // Sensor data connections to controller
        connect viscosityMonitor.dataOut to controller.viscosityData;
        connect flowMeter.dataOut to controller.flowData;
        connect pipeline.pressureSensorData to controller.pressureData;

        // Control signal connections
        connect controller.mixingSpeedCmd to mixingVessel.speedControl;
        connect controller.pumpOutputCmd to centrifugalPump.speedControl;
        connect controller.valveCmd to valveAssembly.valveControl;

        // Requirements satisfaction
        satisfy SlurryConsistencyRequirement by mixingVessel.targetViscosity;
        satisfy FlowRateRequirement by flowMeter;
        satisfy PressureSafetyRequirement by pipeline;
        satisfy EmergencyStopRequirement by controller;
        satisfy ContinuousMonitoringRequirement by controller;
    }
}
