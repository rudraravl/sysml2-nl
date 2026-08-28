package IndustrialFluidTransportSystem {

    import ScalarValues::*;
    import SI::*;

    // ===================== Units =====================
    unit cubicMetersPerSecond;
    unit pascals;
    unit kilopascals;
    unit revolutionsPerMinute;
    unit newtonMeters;
    unit cubicMeters;
    unit meters;
    unit millimeters;
    unit kelvins;
    unit volts;
    unit amperes;
    unit kilowatts;
    unit seconds;

    // ===================== Value Types =====================
    value def FlowRate :> Real;       // [cubicMetersPerSecond]
    value def Pressure :> Real;       // [pascals]
    value def RotationalSpeed :> Real; // [revolutionsPerMinute]
    value def Torque :> Real;         // [newtonMeters]
    value def VolumeValue :> Real;    // [cubicMeters]
    value def LengthValue :> Real;    // [meters]
    value def TemperatureValue :> Real; // [kelvins]
    value def VoltageValue :> Real;   // [volts]
    value def CurrentValue :> Real;   // [amperes]
    value def PowerValue :> Real;     // [kilowatts]
    value def DensityValue :> Real;   // [kg/m^3]
    value def ViscosityValue :> Real; // [Pa.s]
    value def FractionValue :> Real;  // [0..1]
    value def DurationValue :> Real;  // [seconds]

    // ===================== Enumerations =====================
    enum def CommandKind { start; stop; reset; }
    enum def FaultType { overPressure; underFlow; motorOverheat; sealLeak; none; }

    // ===================== Item Types =====================
    item def Liquid {
        attribute density : DensityValue;
        attribute viscosity : ViscosityValue;
        attribute temperature : TemperatureValue;
    }
    item def Water :> Liquid {
        attribute density = 1000.0;
        attribute viscosity = 0.001;
        attribute temperature = 293.15;
    }
    item def ProcessFluid :> Liquid {
        attribute density = 1050.0;
        attribute viscosity = 0.003;
        attribute temperature = 298.15;
    }
    item def Command {
        attribute kind : CommandKind;
        attribute timestamp : DurationValue;
    }

    // ===================== Port Definitions =====================
    port def FluidPort {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        ref item medium : Liquid;
    }
    port def MechanicalPort {
        out speed : RotationalSpeed;
        out torque : Torque;
    }
    port def ElectricalPort {
        in voltage : VoltageValue;
        out current : CurrentValue;
        attribute power : PowerValue;
    }
    port def MeasurementPort {
        out flowRate : FlowRate;
        out pressure : Pressure;
    }
    port def ControlSignalPort {
        in speedSetpoint : RotationalSpeed;
    }
    port def CommandPort {
        in command : Command;
    }
    port def ValveControlPort {
        in position : FractionValue;
    }
    port def PumpStatusPort {
        out speed : RotationalSpeed;
        out running : Boolean;
        out fault : FaultType;
    }

    // ===================== Pipe Parts =====================
    part def Pipe {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute roughness : LengthValue;
        attribute pressureDrop : Pressure;
    }
    part def SuctionPipe :> Pipe {
        attribute length = 2.5;
        attribute diameter = 0.10;
        attribute roughness = 0.000045;
    }
    part def DischargePipe :> Pipe {
        attribute length = 6.0;
        attribute diameter = 0.08;
        attribute roughness = 0.000045;
    }

    // ===================== Valve Parts =====================
    part def Valve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute open : Boolean;
        attribute position : FractionValue;
        attribute maxPressure : Pressure;
        action def openValve { position = 1.0; open = true; }
        action def closeValve { position = 0.0; open = false; }
    }
    part def IsolationValve :> Valve {
        attribute open = true;
        attribute position = 1.0;
        attribute maxPressure = 1600000;
    }
    part def RegulatingValve :> Valve {
        port control : ValveControlPort;
        attribute targetPosition : FractionValue = 0.7;
        attribute open = true;
        attribute position = 0.7;
        attribute maxPressure = 1600000;
        action def regulate {
            position = control.position;
            open = position > 0.0;
        }
    }

    // ===================== Sensor Parts =====================
    part def FlowMeter {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port measurement : MeasurementPort;
        attribute measuredFlow : FlowRate;
        attribute fullScale : FlowRate = 0.10;
        attribute accuracy : FractionValue = 0.01;
        action def measure {
            measuredFlow = inlet.flowRate;
            measurement.flowRate = measuredFlow;
            measurement.pressure = inlet.pressure;
        }
    }
    part def PressureSensor {
        port inlet : FluidPort;
        port measurement : MeasurementPort;
        attribute measuredPressure : Pressure;
        attribute range : Pressure = 1000000;
        attribute accuracy : FractionValue = 0.005;
        action def measure {
            measuredPressure = inlet.pressure;
            measurement.pressure = measuredPressure;
            measurement.flowRate = inlet.flowRate;
        }
    }

    // ===================== Tank Parts =====================
    part def Tank {
        port fluidPort : FluidPort;
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute level : FractionValue;
        ref item contained : Liquid;
        action def fill { in fluid : Liquid; }
        action def drain { out fluid : Liquid; }
    }
    part def SourceTank :> Tank {
        attribute capacity = 10.0;
        attribute currentVolume = 9.0;
        attribute level = 0.9;
        ref item contained : ProcessFluid;
    }
    part def DestinationTank :> Tank {
        attribute capacity = 8.0;
        attribute currentVolume = 0.0;
        attribute level = 0.0;
        ref item contained : ProcessFluid;
    }

    // ===================== Pump Sub-Components =====================
    part def ElectricMotor {
        port electrical : ElectricalPort;
        port mechanical : MechanicalPort;
        port control : ControlSignalPort;
        attribute nominalSpeed : RotationalSpeed = 1750;
        attribute maxSpeed : RotationalSpeed = 3500;
        attribute minSpeed : RotationalSpeed = 0;
        attribute currentSpeed : RotationalSpeed = 0;
        attribute outputTorque : Torque = 0;
        attribute ratedPower : PowerValue = 5.5;
        attribute supplyVoltage : VoltageValue = 480;
        attribute running : Boolean = false;

        action def spinUp {
            in targetSpeed : RotationalSpeed;
            currentSpeed = targetSpeed;
            mechanical.speed = currentSpeed;
            running = true;
        }
        action def spinDown {
            currentSpeed = 0;
            mechanical.speed = 0;
            running = false;
        }
        action def runAt {
            in speedSetpoint : RotationalSpeed;
            currentSpeed = speedSetpoint;
            mechanical.speed = currentSpeed;
        }
    }

    part def Shaft {
        port driveEnd : MechanicalPort;
        port drivenEnd : MechanicalPort;
        attribute material : String = "stainless steel";
        attribute length : LengthValue = 0.55;
        attribute diameter : LengthValue = 0.04;
        attribute rotationalSpeed : RotationalSpeed;
        attribute transmittedTorque : Torque;
        attribute tensileStrength : Pressure = 700000000;
    }

    part def Bearing {
        port shaftInterface : MechanicalPort;
        attribute loadCapacity : Real;
        attribute frictionCoefficient : FractionValue;
        attribute ratedLife : DurationValue;
    }
    part def RadialBearing :> Bearing {
        attribute radialLoadCapacity : Real = 5000;
        attribute loadCapacity = 5000;
        attribute frictionCoefficient = 0.002;
        attribute ratedLife = 20000000;
    }
    part def ThrustBearing :> Bearing {
        attribute axialLoadCapacity : Real = 8000;
        attribute loadCapacity = 8000;
        attribute frictionCoefficient = 0.003;
        attribute ratedLife = 18000000;
    }

    part def Impeller {
        port shaftInterface : MechanicalPort;
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute bladeCount : Integer = 6;
        attribute diameter : LengthValue = 0.16;
        attribute outletWidth : LengthValue = 0.02;
        attribute rotationalSpeed : RotationalSpeed;
        attribute headGenerated : Pressure;
        attribute material : String = "stainless steel";

        action def transferEnergy {
            in fluid : Liquid;
            attribute rpm : RotationalSpeed = shaftInterface.speed;
            headGenerated = 0.0000879 * rpm * rpm;
            outlet.pressure = inlet.pressure + headGenerated;
            outlet.flowRate = inlet.flowRate;
            outlet.medium = inlet.medium;
        }
    }

    part def PumpCasing {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port shaftPenetration : MechanicalPort;
        attribute material : String = "cast iron";
        attribute inletDiameter : LengthValue = 0.10;
        attribute outletDiameter : LengthValue = 0.06;
        attribute designPressure : Pressure = 1600000;
        attribute wallThickness : LengthValue = 0.012;
        action def directFluid {
            outlet.flowRate = inlet.flowRate;
        }
    }

    part def MechanicalSeal {
        port shaftInterface : MechanicalPort;
        attribute leakRate : FlowRate = 0.0;
        attribute ratedPressure : Pressure = 1600000;
        attribute material : String = "silicon carbide / carbon";
        action def seal {
            leakRate = 0.0;
        }
    }

    // ===================== Main Centrifugal Pump =====================
    part def CentrifugalPump {
        port suction : FluidPort;
        port discharge : FluidPort;
        port electrical : ElectricalPort;
        port control : ControlSignalPort;
        port status : PumpStatusPort;

        part motor : ElectricMotor;
        part shaft : Shaft;
        part radialBearing : RadialBearing;
        part thrustBearing : ThrustBearing;
        part impeller : Impeller;
        part casing : PumpCasing;
        part primarySeal : MechanicalSeal;
        part secondarySeal : MechanicalSeal;

        attribute ratedFlow : FlowRate = 0.05;
        attribute ratedHead : Pressure = 250000;
        attribute currentSpeed : RotationalSpeed = 0;
        attribute targetSpeed : RotationalSpeed = 0;
        attribute outletPressure : Pressure = 0;
        attribute flowRate : FlowRate = 0;
        attribute running : Boolean = false;
        attribute faultState : FaultType = FaultType::none;
        attribute lowFlowLimit : FlowRate = 0.005;

        // Internal mechanical power path
        connect motor.mechanical to shaft.driveEnd;
        connect shaft.drivenEnd to radialBearing.shaftInterface;
        connect radialBearing.shaftInterface to thrustBearing.shaftInterface;
        connect thrustBearing.shaftInterface to impeller.shaftInterface;
        connect impeller.shaftInterface to casing.shaftPenetration;
        connect impeller.shaftInterface to primarySeal.shaftInterface;
        connect impeller.shaftInterface to secondarySeal.shaftInterface;

        // Internal fluid path
        connect suction to casing.inlet;
        connect casing.inlet to impeller.inlet;
        connect impeller.outlet to casing.outlet;
        connect casing.outlet to discharge;

        // Control & power
        connect control to motor.control;
        connect electrical to motor.electrical;

        // Status reporting
        action def updateStatus {
            status.speed = motor.currentSpeed;
            status.running = motor.running;
            status.fault = faultState;
            discharge.flowRate = casing.outlet.flowRate;
            discharge.pressure = casing.outlet.pressure;
        }

        state machine PumpOperationStates {
            state idle;
            state accelerating;
            state running;
            state decelerating;
            transition idle to accelerating when control.speedSetpoint > 0;
            transition accelerating to running when motor.currentSpeed >= 0.98 * control.speedSetpoint;
            transition running to decelerating when control.speedSetpoint == 0;
            transition decelerating to idle when motor.currentSpeed == 0;
            entry accelerating { motor.spinUp(control.speedSetpoint); }
            entry decelerating { motor.spinDown(); }
            do running { impeller.transferEnergy(suction.medium); updateStatus(); }
        }
    }

    // ===================== Power Supply =====================
    part def PowerSupply {
        port electrical : ElectricalPort;
        attribute outputVoltage : VoltageValue = 480;
        attribute maxPower : PowerValue = 7.5;
        attribute enabled : Boolean = true;
        action def supply {
            electrical.voltage = outputVoltage;
            electrical.power = maxPower;
        }
    }

    // ===================== Operator Interface =====================
    part def OperatorInterface {
        port commands : CommandPort;
        attribute lastCommand : CommandKind;
        action def sendStart {
            commands.command.kind = CommandKind::start;
        }
        action def sendStop {
            commands.command.kind = CommandKind::stop;
        }
        action def sendReset {
            commands.command.kind = CommandKind::reset;
        }
    }

    // ===================== Controller =====================
    part def Controller {
        port commands : CommandPort;
        port flowMeasurement : MeasurementPort;
        port pressureMeasurement : MeasurementPort;
        port pumpStatus : PumpStatusPort;
        port pumpControl : ControlSignalPort;
        port valveControl : ValveControlPort;

        attribute targetFlowRate : FlowRate = 0.04;
        attribute targetPressure : Pressure = 220000;
        attribute measuredFlow : FlowRate;
        attribute measuredPressure : Pressure;
        attribute pumpSpeed : RotationalSpeed;
        attribute pumpRunning : Boolean;
        attribute pumpFault : FaultType;

        attribute lowFlowThreshold : FlowRate = 0.008;
        attribute highPressureLimit : Pressure = 800000;
        attribute lowPressureLimit : Pressure = 50000;
        attribute outputSpeedSetpoint : RotationalSpeed;
        attribute nominalSpeed : RotationalSpeed = 1750;
        attribute maxSpeed : RotationalSpeed = 3500;
        attribute minSpeed : RotationalSpeed = 200;

        attribute kP : Real = 12000;
        attribute kI : Real = 350;
        attribute integralError : Real = 0;
        attribute errorTolerance : FlowRate = 0.001;
        attribute faultActive : Boolean = false;
        attribute lastCommandKind : CommandKind = CommandKind::stop;
        attribute manualResetRequired : Boolean = false;

        action def readSensors {
            measuredFlow = flowMeasurement.flowRate;
            measuredPressure = pressureMeasurement.pressure;
            pumpSpeed = pumpStatus.speed;
            pumpRunning = pumpStatus.running;
            pumpFault = pumpStatus.fault;
        }

        action def computeControl {
            attribute error : Real = targetFlowRate - measuredFlow;
            integralError = integralError + error;
            outputSpeedSetpoint = nominalSpeed + kP * error + kI * integralError;
            if (outputSpeedSetpoint > maxSpeed) { outputSpeedSetpoint = maxSpeed; }
            if (outputSpeedSetpoint < minSpeed) { outputSpeedSetpoint = minSpeed; }
            pumpControl.speedSetpoint = outputSpeedSetpoint;
        }

        action def detectFault {
            if (measuredPressure > highPressureLimit) { faultActive = true; }
            if (measuredPressure < lowPressureLimit && pumpRunning) { faultActive = true; }
            if (pumpFault != FaultType::none) { faultActive = true; }
        }

        action def regulateValve {
            attribute valveTarget : FractionValue = targetPressure / 300000;
            if (valveTarget > 1.0) { valveTarget = 1.0; }
            if (valveTarget < 0.1) { valveTarget = 0.1; }
            valveControl.position = valveTarget;
        }

        action def safeShutdown {
            pumpControl.speedSetpoint = 0;
            valveControl.position = 0.0;
        }

        state machine ControllerStateMachine {
            state idle;
            state starting;
            state operating;
            state lowFlow;
            state stopping;
            state fault;

            // Initial state
            transition first to idle;

            // Normal command flow
            transition idle to starting
                when commands.command.kind == CommandKind::start;
            transition starting to operating
                when pumpStatus.speed >= 0.95 * nominalSpeed;
            transition operating to lowFlow
                when flowMeasurement.flowRate < lowFlowThreshold;
            transition lowFlow to operating
                when flowMeasurement.flowRate >= lowFlowThreshold && !faultActive;
            transition operating to stopping
                when commands.command.kind == CommandKind::stop;
            transition lowFlow to stopping
                when commands.command.kind == CommandKind::stop;
            transition stopping to idle
                when pumpStatus.speed == 0;

            // Fault transitions from any active state
            transition starting to fault when faultActive;
            transition operating to fault when faultActive;
            transition lowFlow to fault when faultActive;
            transition stopping to fault when faultActive;
            transition idle to fault when faultActive;

            // Fault recovery requires manual reset
            transition fault to idle
                when commands.command.kind == CommandKind::reset && !faultActive;

            // Entry / do / exit behaviors
            entry idle {
                pumpControl.speedSetpoint = 0;
                valveControl.position = 0.5;
            }
            entry starting {
                pumpControl.speedSetpoint = nominalSpeed;
                valveControl.position = 0.7;
            }
            do starting { readSensors(); computeControl(); detectFault(); }
            entry operating {
                valveControl.position = 0.8;
            }
            do operating { readSensors(); computeControl(); regulateValve(); detectFault(); }
            entry lowFlow {
                valveControl.position = 1.0;
                integralError = 0;
            }
            do lowFlow { readSensors(); computeControl(); detectFault(); }
            entry stopping {
                pumpControl.speedSetpoint = 0;
                valveControl.position = 0.3;
            }
            do stopping { readSensors(); detectFault(); }
            entry fault {
                safeShutdown();
                manualResetRequired = true;
            }
            do fault {
                // Await reset; hold safe state
            }
            exit fault {
                manualResetRequired = false;
                integralError = 0;
            }
        }
    }

    // ===================== Top-Level System =====================
    part def FluidTransportSystem {
        part sourceTank : SourceTank;
        part suctionPipe : SuctionPipe;
        part isolationValve : IsolationValve;
        part pump : CentrifugalPump;
        part dischargePipe : DischargePipe;
        part regulatingValve : RegulatingValve;
        part flowMeter : FlowMeter;
        part pressureSensor : PressureSensor;
        part destinationTank : DestinationTank;
        part controller : Controller;
        part powerSupply : PowerSupply;
        part operatorInterface : OperatorInterface;

        // Fluid circuit connections (source -> destination)
        connect sourceTank.fluidPort to suctionPipe.inlet;
        connect suctionPipe.outlet to isolationValve.inlet;
        connect isolationValve.outlet to pump.suction;
        connect pump.discharge to dischargePipe.inlet;
        connect dischargePipe.outlet to regulatingValve.inlet;
        connect regulatingValve.outlet to flowMeter.inlet;
        connect flowMeter.outlet to pressureSensor.inlet;
        connect pressureSensor.inlet to destinationTank.fluidPort;

        // Sensor measurements to controller
        connect flowMeter.measurement to controller.flowMeasurement;
        connect pressureSensor.measurement to controller.pressureMeasurement;

        // Control signals
        connect controller.pumpControl to pump.control;
        connect controller.valveControl to regulatingValve.control;
        connect controller.pumpStatus to pump.status;

        // Power
        connect powerSupply.electrical to pump.electrical;

        // Operator commands
        connect operatorInterface.commands to controller.commands;

        // System-level fluid initialization
        ref item processFluid : ProcessFluid;
        attribute systemFlowRate : FlowRate;
        attribute systemPressure : Pressure;
        attribute enabled : Boolean = false;

        action def initialize {
            sourceTank.contained = processFluid;
            destinationTank.contained = processFluid;
            isolationValve.openValve();
            regulatingValve.position = 0.7;
        }
        action def shutdown {
            isolationValve.closeValve();
            regulatingValve.closeValve();
        }
    }

    // ===================== Requirements =====================
    requirement def FluidDeliveryRequirement {
        subject system : FluidTransportSystem;
        attribute targetFlow : FlowRate;
        attribute targetPressure : Pressure;
        attribute tolerance : FlowRate;
        require {
            abs(system.systemFlowRate - targetFlow) <= tolerance;
            abs(system.systemPressure - targetPressure) <= 20000;
        }
    }

    requirement def FlowControlRequirement {
        subject controller : Controller;
        attribute setpoint : FlowRate;
        attribute tolerance : FlowRate;
        require {
            abs(controller.measuredFlow - setpoint) <= tolerance;
        }
    }

    requirement def PressureControlRequirement {
        subject controller : Controller;
        attribute setpoint : Pressure;
        attribute tolerance : Pressure;
        require {
            abs(controller.measuredPressure - setpoint) <= tolerance;
        }
    }

    requirement def StateBehaviorRequirement {
        subject controller : Controller;
        require {
            controller.ControllerStateMachine.idle.isInitial;
            controller.ControllerStateMachine.fault.requiresReset;
        }
        attribute requiresReset : Boolean = true;
    }

    requirement def LeakPreventionRequirement {
        subject pump : CentrifugalPump;
        attribute maxLeakRate : FlowRate;
        require {
            pump.primarySeal.leakRate <= maxLeakRate;
            pump.secondarySeal.leakRate <= maxLeakRate;
        }
    }

    requirement def BearingSupportRequirement {
        subject pump : CentrifugalPump;
        attribute requiredRadialLoad : Real;
        attribute requiredAxialLoad : Real;
        require {
            pump.radialBearing.radialLoadCapacity >= requiredRadialLoad;
            pump.thrustBearing.axialLoadCapacity >= requiredAxialLoad;
        }
    }

    requirement def ImpellerBladeRequirement {
        subject pump : CentrifugalPump;
        attribute requiredBladeCount : Integer;
        require { pump.impeller.bladeCount == requiredBladeCount; }
    }

    requirement def ShaftMaterialRequirement {
        subject pump : CentrifugalPump;
        attribute requiredMaterial : String;
        require { pump.shaft.material == requiredMaterial; }
    }

    requirement def SafetyFaultRequirement {
        subject controller : Controller;
        require {
            controller.faultActive implies controller.ControllerStateMachine.fault.active;
            controller.ControllerStateMachine.fault.to.idle.guard
                == (commands.command.kind == CommandKind::reset && !faultActive);
        }
    }

    requirement def AutonomousOperationRequirement {
        subject system : FluidTransportSystem;
        require {
            system.controller.commands.command.kind == CommandKind::start
                implies system.enabled;
        }
    }

    // ===================== Requirement Usages =====================
    requirement fluidDelivery : FluidDeliveryRequirement {
        subject :>> system = FluidTransportSystem;
        attribute targetFlow = 0.04;
        attribute targetPressure = 220000;
        attribute tolerance = 0.002;
    }

    requirement flowControl : FlowControlRequirement {
        subject :>> controller = FluidTransportSystem::controller;
        attribute setpoint = 0.04;
        attribute tolerance = 0.002;
    }

    requirement pressureControl : PressureControlRequirement {
        subject :>> controller = FluidTransportSystem::controller;
        attribute setpoint = 220000;
        attribute tolerance = 15000;
    }

    requirement stateBehavior : StateBehaviorRequirement {
        subject :>> controller = FluidTransportSystem::controller;
    }

    requirement leakPrevention : LeakPreventionRequirement {
        subject :>> pump = FluidTransportSystem::pump;
        attribute maxLeakRate = 0.00001;
    }

    requirement bearingSupport : BearingSupportRequirement {
        subject :>> pump = FluidTransportSystem::pump;
        attribute requiredRadialLoad = 3500;
        attribute requiredAxialLoad = 6000;
    }

    requirement impellerBladeCount : ImpellerBladeRequirement {
        subject :>> pump = FluidTransportSystem::pump;
        attribute requiredBladeCount = 6;
    }

    requirement shaftMaterial : ShaftMaterialRequirement {
        subject :>> pump = FluidTransportSystem::pump;
        attribute requiredMaterial = "stainless steel";
    }

    requirement safetyFault : SafetyFaultRequirement {
        subject :>> controller = FluidTransportSystem::controller;
    }

    requirement autonomousOperation : AutonomousOperationRequirement {
        subject :>> system = FluidTransportSystem;
    }

    // ===================== Satisfaction Bindings =====================
    satisfaction fluidDelivery satisfy FluidTransportSystem;
    satisfaction flowControl satisfy FluidTransportSystem::controller;
    satisfaction pressureControl satisfy FluidTransportSystem::controller;
    satisfaction leakPrevention satisfy FluidTransportSystem::pump;
    satisfaction bearingSupport satisfy FluidTransportSystem::pump;
    satisfaction impellerBladeCount satisfy FluidTransportSystem::pump;
    satisfaction shaftMaterial satisfy FluidTransportSystem::pump;
    satisfaction stateBehavior satisfy FluidTransportSystem::controller;
    satisfaction safetyFault satisfy FluidTransportSystem::controller;
    satisfaction autonomousOperation satisfy FluidTransportSystem;
}
