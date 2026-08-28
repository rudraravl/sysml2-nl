package IndustrialFluidPumpingSystem {
    import ISQ::*;
    import ISQSpaceAndTime::*;
    import ISQMechanics::*;
    import ISQElectromagnetism::*;
    import ScalarValues::*;

    // ---- Value Types ----
    attribute def Pressure :> Real { unit 'Pa'; }
    attribute def FlowRate :> Real { unit 'm3/s'; }
    attribute def RotationalSpeed :> Real { unit 'rad/s'; }
    attribute def Torque :> Real { unit 'N.m'; }
    attribute def Power :> Real { unit 'W'; }
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Efficiency :> Real { unit '1'; }
    attribute def Volume :> Real { unit 'm3'; }
    attribute def Temperature :> Real { unit 'K'; }
    attribute def Dimensionless :> Real { unit '1'; }

    // ---- Item Definitions ----
    item def Fluid {
        attribute density : Real = 1000 [kg/m3];
        attribute viscosity : Real = 0.001 [Pa.s];
    }

    item def ElectricalEnergy;
    item def ControlSignal;

    // ---- Port Definitions ----
    port def FluidPort {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        item fluid : Fluid;
    }

    port def RotationalPort {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }

    port def ElectricalPort {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    port def PressureSignalPort {
        attribute measuredPressure : Pressure;
    }

    port def FlowSignalPort {
        attribute measuredFlowRate : FlowRate;
    }

    port def ControlSignalPort {
        attribute valvePosition : Real; // 0..1
        attribute pumpCommand : PumpCommandType;
    }

    enum def PumpCommandType { idle; start; run; stop; }

    // ---- Part Definitions ----

    part def Reservoir {
        port fluidPort : FluidPort;
        attribute capacity : Volume;
        attribute currentVolume : Volume;
        attribute fluid : Fluid;
    }

    part def SourceReservoir :> Reservoir {
        attribute capacity : Volume = 50 [m3];
        attribute currentVolume : Volume = 45 [m3];
    }

    part def DestinationReservoir :> Reservoir {
        attribute capacity : Volume = 50 [m3];
        attribute currentVolume : Volume = 5 [m3];
    }

    part def ElectricMotor {
        in port electricalIn : ElectricalPort;
        out port shaftOut : RotationalPort;
        attribute ratedPower : Power = 15000 [W];
        attribute ratedSpeed : RotationalSpeed = 314.16 [rad/s];
        attribute efficiency : Efficiency = 0.92;
        attribute currentSpeed : RotationalSpeed;
        attribute currentTorque : Torque;

        action def generateTorque {
            in voltage : Voltage;
            in current : Current;
            out speed : RotationalSpeed;
            out torque : Torque;
        }
    }

    part def CentrifugalPump {
        in port shaftIn : RotationalPort;
        in port suctionPort : FluidPort;
        out port dischargePort : FluidPort;
        in port commandIn : ControlSignalPort;

        attribute ratedFlowRate : FlowRate = 0.05 [m3/s];
        attribute ratedPressureRise : Pressure = 500000 [Pa];
        attribute ratedSpeed : RotationalSpeed = 314.16 [rad/s];
        attribute efficiency : Efficiency = 0.78;
        attribute currentFlowRate : FlowRate;
        attribute currentPressureRise : Pressure;
        attribute currentSpeed : RotationalSpeed;

        state machine def PumpStateMachine {
            state idle;
            state starting;
            state running;
            state stopping;

            transition idle_to_starting
                first idle
                if commandIn.pumpCommand == PumpCommandType::start
                then starting;

            transition starting_to_running
                first starting
                if currentSpeed >= ratedSpeed * 0.95
                then running;

            transition running_to_stopping
                first running
                if commandIn.pumpCommand == PumpCommandType::stop
                then stopping;

            transition stopping_to_idle
                first stopping
                if currentSpeed <= 1.0 [rad/s]
                then idle;

            entry idle { currentSpeed = 0 [rad/s]; }
            entry starting { currentSpeed = currentSpeed + 31.4 [rad/s]; }
            entry running { currentFlowRate = ratedFlowRate; currentPressureRise = ratedPressureRise; }
            entry stopping { currentSpeed = currentSpeed - 31.4 [rad/s]; }
        }

        action def pressurizeFluid {
            in fluidIn : Fluid;
            in speed : RotationalSpeed;
            out fluidOut : Fluid;
            out pressureRise : Pressure;
            out flowRate : FlowRate;
        }
    }

    part def PressureSensor {
        in port fluidIn : FluidPort;
        out port signalOut : PressureSignalPort;
        attribute measurementRange : Pressure = 1000000 [Pa];
        attribute accuracy : Dimensionless = 0.01;
        attribute measuredPressure : Pressure;

        action def measurePressure {
            in fluid : Fluid;
            in pressure : Pressure;
            out signal : Pressure;
        }
    }

    part def FlowMeter {
        in port fluidIn : FluidPort;
        out port signalOut : FlowSignalPort;
        attribute measurementRange : FlowRate = 0.2 [m3/s];
        attribute accuracy : Dimensionless = 0.02;
        attribute measuredFlowRate : FlowRate;

        action def measureFlow {
            in fluid : Fluid;
            in flowRate : FlowRate;
            out signal : FlowRate;
        }
    }

    part def ControlValve {
        in port fluidIn : FluidPort;
        out port fluidOut : FluidPort;
        in port controlIn : ControlSignalPort;
        attribute maxFlowRate : FlowRate = 0.05 [m3/s];
        attribute valvePosition : Real; // 0..1
        attribute currentFlowRate : FlowRate;

        action def regulateFlow {
            in fluid : Fluid;
            in position : Real;
            out fluidOut : Fluid;
            out flowRate : FlowRate;
        }
    }

    part def Pipeline {
        in port inlet : FluidPort;
        out port outlet : FluidPort;
        attribute length : Real = 50 [m];
        attribute diameter : Real = 0.1 [m];
        attribute pressureDrop : Pressure;
    }

    part def PumpController {
        in port pressureFeedback : PressureSignalPort;
        in port flowFeedback : FlowSignalPort;
        out port controlOut : ControlSignalPort;
        attribute targetFlowRate : FlowRate = 0.05 [m3/s];
        attribute targetPressure : Pressure = 500000 [Pa];
        attribute valvePosition : Real = 0.8;
        attribute pumpCommand : PumpCommandType = PumpCommandType::idle;

        action def controlLoop {
            in measuredPressure : Pressure;
            in measuredFlow : FlowRate;
            out valveCmd : Real;
            out pumpCmd : PumpCommandType;
        }
    }

    part def PumpingSystem {
        part sourceReservoir : SourceReservoir;
        part pump : CentrifugalPump;
        part motor : ElectricMotor;
        part dischargePipeline : Pipeline;
        part pressureSensor : PressureSensor;
        part flowMeter : FlowMeter;
        part controlValve : ControlValve;
        part destinationReservoir : DestinationReservoir;
        part controller : PumpController;

        // Electrical supply to motor
        port electricalSupply : ElectricalPort {
            voltage = 480 [V];
            current = 35 [A];
        }

        // Connections
        connection electricalToMotor connect electricalSupply to motor.electricalIn;
        connection motorToPump connect motor.shaftOut to pump.shaftIn;
        connection sourceToPump connect sourceReservoir.fluidPort to pump.suctionPort;
        connection pumpToPipeline connect pump.dischargePort to dischargePipeline.inlet;
        connection pipelineToPressureSensor connect dischargePipeline.outlet to pressureSensor.fluidIn;
        connection pressureSensorToValve connect pressureSensor.fluidIn to controlValve.fluidIn;
        connection valveToFlowMeter connect controlValve.fluidOut to flowMeter.fluidIn;
        connection flowMeterToDestination connect flowMeter.fluidIn to destinationReservoir.fluidPort;

        connection pressureFeedback connect pressureSensor.signalOut to controller.pressureFeedback;
        connection flowFeedback connect flowMeter.signalOut to controller.flowFeedback;
        connection controllerToPump connect controller.controlOut to pump.commandIn;
        connection controllerToValve connect controller.controlOut to controlValve.controlIn;

        // System-level attributes
        attribute systemFlowRate : FlowRate;
        attribute systemPressure : Pressure;
        attribute systemEfficiency : Efficiency;
        attribute totalPowerConsumption : Power;
    }

    // ---- Requirements ----
    requirement def FlowRateRequirement {
        attribute requiredFlowRate : FlowRate = 0.05 [m3/s];
        subject system : PumpingSystem;
        require system.systemFlowRate >= requiredFlowRate;
        doc "The system shall deliver a flow rate of at least 0.05 m3/s to the destination reservoir."
    }

    requirement def PressureRequirement {
        attribute requiredPressure : Pressure = 500000 [Pa];
        subject system : PumpingSystem;
        require system.systemPressure >= requiredPressure;
        doc "The system shall provide a pressure increase of at least 500 kPa at the pump discharge."
    }

    requirement def PowerConsumptionRequirement {
        attribute maxPower : Power = 20000 [W];
        subject system : PumpingSystem;
        require system.totalPowerConsumption <= maxPower;
        doc "The system total power consumption shall not exceed 20 kW during normal operation."
    }

    requirement def EfficiencyRequirement {
        attribute minEfficiency : Efficiency = 0.70;
        subject system : PumpingSystem;
        require system.systemEfficiency >= minEfficiency;
        doc "The system shall operate at an overall efficiency of at least 70%."
    }

    requirement def PumpStateRequirement {
        subject pump : CentrifugalPump;
        require pump.PumpStateMachine.isStateRunning() == true
            when pump.commandIn.pumpCommand == PumpCommandType::run;
        doc "The pump shall enter the running state when commanded to run."
    }

    requirement def MonitoringRequirement {
        subject system : PumpingSystem;
        require system.pressureSensor.measuredPressure == system.systemPressure;
        require system.flowMeter.measuredFlowRate == system.systemFlowRate;
        doc "The pressure sensor and flow meter shall continuously monitor discharge pressure and flow rate."
    }

    requirement def ControlValveRequirement {
        subject valve : ControlValve;
        require valve.valvePosition >= 0.0 and valve.valvePosition <= 1.0;
        doc "The control valve position shall be regulated between 0 (closed) and 1 (fully open)."
    }

    requirement package PumpingSystemRequirements {
        requirement flowRateReq : FlowRateRequirement;
        requirement pressureReq : PressureRequirement;
        requirement powerReq : PowerConsumptionRequirement;
        requirement efficiencyReq : EfficiencyRequirement;
        requirement pumpStateReq : PumpStateRequirement;
        requirement monitoringReq : MonitoringRequirement;
        requirement controlValveReq : ControlValveRequirement;
    }

    // ---- Verification ----
    verification def VerifyFlowRate {
        subject system : PumpingSystem;
        objective {
            doc "Verify the system delivers the required flow rate."
        }
        require system.systemFlowRate >= 0.05 [m3/s];
    }

    verification def VerifyPressure {
        subject system : PumpingSystem;
        objective {
            doc "Verify the system provides the required pressure increase."
        }
        require system.systemPressure >= 500000 [Pa];
    }

    verification def VerifyPowerConsumption {
        subject system : PumpingSystem;
        objective {
            doc "Verify the system does not exceed the maximum power consumption."
        }
        require system.totalPowerConsumption <= 20000 [W];
    }
}
