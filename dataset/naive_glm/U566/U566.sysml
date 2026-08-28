package EfficientPumpSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // ---------- Value Types ----------
    value def RotationalSpeed :> Real { unit "rpm"; }
    value def FlowRateQ :> Real { unit "m3/s"; }
    value def PressureP :> Real { unit "Pa"; }
    value def HeadH :> Length { unit "m"; }
    value def FrequencyF :> Real { unit "Hz"; }
    value def VoltageV :> Real { unit "V"; }
    value def CurrentA :> Real { unit "A"; }
    value def PowerW :> Real { unit "W"; }
    value def DimensionlessN :> Real { unit "1"; }
    value def EfficiencyPct :> Real { unit "%"; }

    // ---------- Items ----------
    item def Fluid;
    item def ElectricalPower;
    item def ControlCommand {
        attribute targetSpeed : RotationalSpeed;
    }
    item def SensorReading {
        attribute value : Real;
        attribute timestamp : Real;
    }

    // ---------- Port Definitions ----------
    port def FluidPort {
        out item fluid : Fluid;
        attribute pressure : PressureP;
        attribute flowRate : FlowRateQ;
    }
    port def InletFluidPort :> FluidPort;
    port def OutletFluidPort :> FluidPort;

    port def ElectricalPort {
        out item power : ElectricalPower;
        attribute voltage : VoltageV;
        attribute frequency : FrequencyF;
        attribute current : CurrentA;
    }

    port def CommandPort {
        out item command : ControlCommand;
    }

    port def ReadingPort {
        out item reading : SensorReading;
    }

    // ---------- Requirements ----------
    requirement def EfficientPumpRequirement {
        subject pumpSystem : EfficientPumpSystem;
        objective {
            doc "The pump system shall transport fluid while maintaining peak energy efficiency under varying demand.";
        }
    }

    requirement def SpecificSpeedControlRequirement :> EfficientPumpRequirement {
        doc "The controller shall maintain specific speed within +/- 2% of the ideal value.";
        attribute idealSpecificSpeed : DimensionlessN = 0.85;
        attribute tolerance : DimensionlessN = 0.02;
        constraint { abs(controller.specificSpeed - idealSpecificSpeed) <= tolerance }
    }

    requirement def ClosedLoopResponseRequirement :> EfficientPumpRequirement {
        doc "The system shall adjust motor speed in response to demand changes within 5 seconds.";
        attribute maxResponseTime : Real = 5.0;
    }

    requirement def SafeShutdownRequirement :> EfficientPumpRequirement {
        doc "The system shall support an immediate emergency shutdown from any operating state.";
    }

    // ---------- Pump Mechanical Components ----------
    part def Impeller {
        attribute bladeCount : Integer = 7;
        attribute diameter : Length = 0.25 [m];
        port in shaftDrive;
        attribute rotationalSpeed : RotationalSpeed;
    }

    part def Volute {
        attribute casingProfile : String = "snail";
        port in inletFluid : InletFluidPort;
        port out outletFluid : OutletFluidPort;
    }

    part def PumpHousing {
        attribute material : String = "stainless steel";
        attribute maxPressure : PressureP = 2.0e6 [Pa];
    }

    part def PumpAssembly {
        part impeller : Impeller;
        part volute : Volute;
        part housing : PumpHousing;
        port in fluidIn : InletFluidPort;
        port out fluidOut : OutletFluidPort;
        port in mechanicalDrive;

        connection impellerDrive connect mechanicalDrive to impeller.shaftDrive;
        connection fluidPathIn connect fluidIn to volute.inletFluid;
        connection fluidPathOut connect volute.outletFluid to fluidOut;
        connection encloseImpeller connect impeller to housing;
        connection encloseVolute connect volute to housing;
    }

    // ---------- Electric Motor ----------
    part def ElectricMotor {
        attribute ratedPower : PowerW = 15000 [W];
        attribute ratedSpeed : RotationalSpeed = 2900 [rpm];
        port in electricalIn : ElectricalPort;
        port out mechanicalOut;
        attribute currentSpeed : RotationalSpeed;

        action def Accelerate {
            in target : RotationalSpeed;
            then deliverTorque;
        }
        action deliverTorque;
    }
    port def MechanicalDrivePort {
        out attribute speed : RotationalSpeed;
    }

    // ---------- Variable Frequency Drive ----------
    part def VariableFrequencyDrive {
        attribute inputFrequency : FrequencyF = 50 [Hz];
        attribute inputVoltage : VoltageV = 400 [V];
        attribute outputFrequency : FrequencyF;
        attribute outputVoltage : VoltageV;
        port in supplyIn : ElectricalPort;
        port in commandIn : CommandPort;
        port out motorOut : ElectricalPort;

        action def ModulateOutput {
            in cmd : ControlCommand;
            then setFrequency;
        }
        action setFrequency {
            assign outputFrequency : FrequencyF = cmd.targetSpeed / 60.0 [rpm/Hz];
        }
    }

    // ---------- Sensors ----------
    part def FlowSensor {
        attribute measuredFlow : FlowRateQ;
        port in fluidSense : InletFluidPort;
        port out flowReading : ReadingPort;
        action def MeasureFlow {
            assign measuredFlow : FlowRateQ = fluidSense.flowRate;
            then emit flowReading.reading;
        }
    }

    part def PressureSensor {
        attribute measuredPressure : PressureP;
        port in pressureSense : FluidPort;
        port out pressureReading : ReadingPort;
        action def MeasurePressure {
            assign measuredPressure : PressureP = pressureSense.pressure;
            then emit pressureReading.reading;
        }
    }

    part def SpeedSensor {
        attribute measuredSpeed : RotationalSpeed;
        port in shaftSense : MechanicalDrivePort;
        port out speedReading : ReadingPort;
        action def MeasureSpeed {
            assign measuredSpeed : RotationalSpeed = shaftSense.speed;
            then emit speedReading.reading;
        }
    }

    // ---------- Specific Speed Controller ----------
    part def SpecificSpeedController {
        attribute idealSpecificSpeed : DimensionlessN = 0.85;
        attribute specificSpeed : DimensionlessN;
        attribute currentFlow : FlowRateQ;
        attribute currentHead : HeadH;
        attribute currentSpeed : RotationalSpeed;
        attribute currentEfficiency : EfficiencyPct;

        port in flowIn : ReadingPort;
        port in inletPressureIn : ReadingPort;
        port in outletPressureIn : ReadingPort;
        port in speedIn : ReadingPort;
        port out vfdCommand : CommandPort;

        action def ComputeHead {
            in pIn : PressureP;
            in pOut : PressureP;
            out head : HeadH;
            assign head : HeadH = (pOut - pIn) / 9810.0 [Pa/m];
        }

        action def ComputeSpecificSpeed {
            in n : RotationalSpeed;
            in q : FlowRateQ;
            in h : HeadH;
            out ns : DimensionlessN;
            assign ns : DimensionlessN = (n / 60.0 [rpm/Hz]) * sqrt(q) / pow(h, 0.75);
        }

        action def Optimize {
            in measuredFlow : FlowRateQ;
            in measuredHead : HeadH;
            in measuredSpeed : RotationalSpeed;
            out command : ControlCommand;
            attribute targetSpeed : RotationalSpeed;
            assign targetSpeed : RotationalSpeed = idealSpecificSpeed * pow(measuredHead, 0.75) / sqrt(measuredFlow) * 60.0 [Hz/rpm];
            assign command.targetSpeed : RotationalSpeed = targetSpeed;
        }

        state def ControllerStateMachine {
            entry; then stopped;

            state stopped {
                entry { assign currentSpeed : RotationalSpeed = 0 [rpm]; }
                transition init to initializing
                    when (startSignal == true);
            }

            state initializing {
                entry { perform selfCalibration; }
                action selfCalibration;
                transition to accelerating
                    when (calibrationComplete == true);
            }

            state accelerating {
                entry { perform rampUp; }
                action rampUp;
                transition to normalOperation
                    when (currentSpeed >= targetSpeed);
            }

            state normalOperation {
                entry { perform continuousOptimization; }
                do { perform Optimize; }
                transition to decelerating
                    when (stopSignal == true);
                transition to emergency
                    when (faultDetected == true);
            }

            state decelerating {
                entry { perform rampDown; }
                action rampDown;
                transition to stopped
                    when (currentSpeed <= 0 [rpm]);
            }

            state emergency {
                entry { perform immediateShutdown; }
                action immediateShutdown;
                transition to stopped
                    when (currentSpeed <= 0 [rpm]);
            }

            attribute startSignal : Boolean = false;
            attribute stopSignal : Boolean = false;
            attribute faultDetected : Boolean = false;
            attribute calibrationComplete : Boolean = false;
            attribute targetSpeed : RotationalSpeed = 2900 [rpm];
        }

        exhibit state machine ControllerStateMachine;
    }

    // ---------- Top-Level System ----------
    part def EfficientPumpSystem {
        part pump : PumpAssembly;
        part motor : ElectricMotor;
        part vfd : VariableFrequencyDrive;
        part controller : SpecificSpeedController;
        part flowSensor : FlowSensor;
        part inletPressureSensor : PressureSensor;
        part outletPressureSensor : PressureSensor;
        part speedSensor : SpeedSensor;

        port in systemFluidIn : InletFluidPort;
        port out systemFluidOut : OutletFluidPort;
        port in mainsSupply : ElectricalPort;

        // Mechanical coupling
        connection motorToPump connect motor.mechanicalOut to pump.mechanicalDrive;
        connection pumpToSpeedSensor connect motor.mechanicalOut to speedSensor.shaftSense;

        // Fluid connections
        connection systemInToPump connect systemFluidIn to pump.fluidIn;
        connection pumpOutToSystem connect pump.fluidOut to systemFluidOut;

        // Sensor fluid taps
        connection inletToFlowSensor connect systemFluidIn to flowSensor.fluidSense;
        connection inletToPressureSensor connect systemFluidIn to inletPressureSensor.pressureSense;
        connection outletToPressureSensor connect systemFluidOut to outletPressureSensor.pressureSense;

        // Sensor readings to controller
        connection flowToController connect flowSensor.flowReading to controller.flowIn;
        connection inletPressureToController connect inletPressureSensor.pressureReading to controller.inletPressureIn;
        connection outletPressureToController connect outletPressureSensor.pressureReading to controller.outletPressureIn;
        connection speedToController connect speedSensor.speedReading to controller.speedIn;

        // Controller command to VFD
        connection commandToVFD connect controller.vfdCommand to vfd.commandIn;

        // Electrical supply chain
        connection mainsToVFD connect mainsSupply to vfd.supplyIn;
        connection vfdToMotor connect vfd.motorOut to motor.electricalIn;

        satisfy EfficientPumpRequirement by self;
        satisfy SpecificSpeedControlRequirement by controller;
        satisfy ClosedLoopResponseRequirement by self;
        satisfy SafeShutdownRequirement by self;
    }
}
