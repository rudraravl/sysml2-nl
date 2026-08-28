package ElectromagneticInductivePumpingSystem {
    import ScalarValues::*;
    import ISQ::*;

    value type FlowRate :> Real { unit "m^3/s"; }
    value type Pressure :> Real { unit "Pa"; }
    value type Temperature :> Real { unit "K"; }
    value type Frequency :> Real { unit "Hz"; }
    value type Current :> Real { unit "A"; }
    value type Voltage :> Real { unit "V"; }
    value type Power :> Real { unit "W"; }
    value type Volume :> Real { unit "m^3"; }
    value type Force :> Real { unit "N"; }
    value type MagneticFluxDensity :> Real { unit "T"; }

    item def ConductiveFluid {
        attribute conductivity : Real;
        attribute density : Real;
        attribute viscosity : Real;
    }

    port def FluidPort {
        out item fluid : ConductiveFluid;
        ref attribute flowRate : FlowRate;
        ref attribute pressure : Pressure;
    }

    port def FluidInPort :> FluidPort {
        in item fluid : ConductiveFluid;
    }

    port def FluidOutPort :> FluidPort {
        out item fluid : ConductiveFluid;
    }

    port def ThreePhasePowerPort {
        attribute phaseA : Voltage;
        attribute phaseB : Voltage;
        attribute phaseC : Voltage;
        attribute frequency : Frequency;
        attribute lineCurrent : Current;
    }

    port def ControlSignalPort {
        attribute commandedFrequency : Frequency;
        attribute enable : Boolean;
        attribute emergencyStop : Boolean;
    }

    port def SensorDataPort {
        attribute measuredFlowRate : FlowRate;
        attribute measuredPressure : Pressure;
    }

    port def TempSensorPort {
        attribute measuredTemperature : Temperature;
    }

    requirement def TransferFluidRequirement {
        doc "The system shall transfer electrically conductive fluid from a source reservoir to a destination tank without moving mechanical parts."
        attribute minFlowRate : FlowRate = 0.0001 [m^3/s];
        subject pump : InductivePump;
        require {
            pump.outlet.flowRate >= minFlowRate
        }
    }

    requirement def FlowRegulationRequirement {
        doc "The controller shall regulate flow rate within tolerance of the commanded flow rate using a PID feedback loop."
        attribute commandedFlowRate : FlowRate;
        attribute tolerance : FlowRate = 0.0005 [m^3/s];
        subject controller : PumpController;
        require {
            abs(controller.commandedFlowRate - controller.outletSensor.measuredFlowRate) <= tolerance
        }
    }

    requirement def ThermalProtectionRequirement {
        doc "The controller shall shut down and enter the faulted state if coil temperature exceeds the safe limit, and only restart when cooled below the restart threshold."
        attribute maxSafeTemp : Temperature = 350 [K];
        attribute restartSafeTemp : Temperature = 320 [K];
        subject controller : PumpController;
        require {
            (controller.tempSensor.measuredTemperature > maxSafeTemp) implies (controller.state == PumpControllerState::faulted)
        }
    }

    part def SourceReservoir {
        port fluidOut : FluidOutPort;
        attribute capacity : Volume = 100 [m^3];
        attribute currentVolume : Volume;
        attribute fluid : ConductiveFluid;

        action supplyFluid {
            out item fluid : ConductiveFluid;
        }
    }

    part def DestinationTank {
        port fluidIn : FluidInPort;
        attribute capacity : Volume = 100 [m^3];
        attribute currentVolume : Volume;

        action receiveFluid {
            in item fluid : ConductiveFluid;
        }
    }

    part def LaminatedSteelCore {
        attribute relativePermeability : Real = 1000;
        attribute length : Real = 0.5;
        attribute stackThickness : Real = 0.0005;
    }

    part def ElectromagneticCoil {
        attribute phaseNumber : Integer;
        attribute turns : Integer = 200;
        attribute resistance : Real = 0.5;
        attribute inductance : Real = 0.01;
        port electrical : ThreePhasePowerPort;
    }

    part def StainlessSteelDuct {
        attribute length : Real = 0.6;
        attribute innerDiameter : Real = 0.05;
        attribute wallThickness : Real = 0.003;
        attribute crossSectionArea : Real;
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
    }

    part def InductivePump {
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        port powerIn : ThreePhasePowerPort;
        port tempSensorOut : TempSensorPort;

        part core : LaminatedSteelCore;
        part coils : ElectromagneticCoil[3];
        part duct : StainlessSteelDuct {
            port inlet redefines InductivePump::inlet;
            port outlet redefines InductivePump::outlet;
        }

        attribute travelingFieldFrequency : Frequency;
        attribute magneticFluxDensity : MagneticFluxDensity;
        attribute lorentzForce : Force;
        attribute coilTemperature : Temperature;

        action generateTravelingMagneticField {
            in power : ThreePhasePowerPort;
            out fieldStrength : MagneticFluxDensity;
        }

        action induceEddyCurrents {
            in fieldStrength : MagneticFluxDensity;
            in fluid : ConductiveFluid;
            out eddyCurrent : Current;
        }

        action applyLorentzForce {
            in eddyCurrent : Current;
            in fieldStrength : MagneticFluxDensity;
            out force : Force;
        }

        composite action pumpOperation {
            action generateTravelingMagneticField;
            action induceEddyCurrents;
            action applyLorentzForce;
            flow generateTravelingMagneticField.fieldStrength to induceEddyCurrents.fieldStrength;
            flow induceEddyCurrents.eddyCurrent to applyLorentzForce.eddyCurrent;
            flow generateTravelingMagneticField.fieldStrength to applyLorentzForce.fieldStrength;
        }
    }

    part def PowerSupply {
        port powerOut : ThreePhasePowerPort;
        port controlIn : ControlSignalPort;
        attribute outputFrequency : Frequency;
        attribute outputPower : Power;
        attribute maxPower : Power = 50000 [W];
        attribute enabled : Boolean;

        action adjustOutputFrequency {
            in command : Frequency;
            in enable : Boolean;
            out adjustedFrequency : Frequency;
        }

        action generateThreePhasePower {
            in frequency : Frequency;
            out power : ThreePhasePowerPort;
        }
    }

    part def FlowSensor {
        port fluidPort : FluidPort;
        port dataOut : SensorDataPort;
        attribute measuredFlowRate : FlowRate;
        attribute measuredPressure : Pressure;
        attribute samplingRate : Frequency = 1000 [Hz];

        action measureFlow {
            in item fluid : ConductiveFluid;
            out flowRate : FlowRate;
            out pressure : Pressure;
        }
    }

    part def TemperatureSensor {
        port tempOut : TempSensorPort;
        attribute measuredTemperature : Temperature;
        attribute samplingRate : Frequency = 10 [Hz];

        action measureTemperature {
            out temperature : Temperature;
        }
    }

    part def CoolingSystem {
        port thermalInterface : TempSensorPort;
        attribute coolantFlowRate : FlowRate;
        attribute active : Boolean;
        attribute maxCoolantFlow : FlowRate = 0.002 [m^3/s];

        action circulateCoolant {
            in activation : Boolean;
            out coolantFlow : FlowRate;
        }

        action regulateTemperature {
            in temperature : Temperature;
            out coolingActive : Boolean;
        }
    }

    enum PumpControllerState {
        idle;
        starting;
        running;
        stopping;
        faulted;
    }

    part def PumpController {
        port inletSensor : SensorDataPort;
        port outletSensor : SensorDataPort;
        port tempSensor : TempSensorPort;
        port powerControl : ControlSignalPort;

        attribute commandedFlowRate : FlowRate;
        attribute currentFrequency : Frequency;
        attribute kp : Real = 2.0;
        attribute ki : Real = 0.5;
        attribute kd : Real = 0.05;
        attribute integralError : Real = 0.0;
        attribute previousError : Real = 0.0;
        attribute maxSafeTemp : Temperature = 350 [K];
        attribute restartSafeTemp : Temperature = 320 [K];
        attribute state : PumpControllerState = PumpControllerState::idle;

        state def ControllerStateMachine {
            state idle {
                entry action {
                    powerControl.enable = false;
                    powerControl.commandedFrequency = 0 [Hz];
                }
            }

            state starting {
                entry action {
                    powerControl.enable = true;
                    powerControl.commandedFrequency = 5 [Hz];
                }
            }

            state running {
                entry action {
                    powerControl.enable = true;
                }
                do action computePID {
                    in setpoint : FlowRate = commandedFlowRate;
                    in measured : FlowRate = outletSensor.measuredFlowRate;
                    out controlFrequency : Frequency;
                }
            }

            state stopping {
                entry action {
                    powerControl.commandedFrequency = 0 [Hz];
                }
            }

            state faulted {
                entry action {
                    powerControl.enable = false;
                    powerControl.emergencyStop = true;
                    powerControl.commandedFrequency = 0 [Hz];
                }
            }

            transition t_idle_to_starting
                from idle to starting
                when commandedFlowRate > 0 [m^3/s];

            transition t_starting_to_running
                from starting to running
                when outletSensor.measuredFlowRate > 0 [m^3/s];

            transition t_running_to_stopping
                from running to stopping
                when commandedFlowRate == 0 [m^3/s];

            transition t_stopping_to_idle
                from stopping to idle
                when outletSensor.measuredFlowRate == 0 [m^3/s];

            transition t_running_to_faulted
                from running to faulted
                when tempSensor.measuredTemperature > maxSafeTemp;

            transition t_starting_to_faulted
                from starting to faulted
                when tempSensor.measuredTemperature > maxSafeTemp;

            transition t_faulted_to_idle
                from faulted to idle
                when tempSensor.measuredTemperature < restartSafeTemp;
        }

        exhibit state : ControllerStateMachine;

        action computePID {
            in setpoint : FlowRate;
            in measured : FlowRate;
            out controlFrequency : Frequency;

            attribute error : Real;
            attribute derivative : Real;
            attribute output : Real;

            do action {
                error = setpoint - measured;
                integralError = integralError + error;
                derivative = error - previousError;
                output = kp * error + ki * integralError + kd * derivative;
                previousError = error;
                controlFrequency = output [Hz];
                if (controlFrequency < 0 [Hz]) {
                    controlFrequency = 0 [Hz];
                }
                if (controlFrequency > 200 [Hz]) {
                    controlFrequency = 200 [Hz];
                }
            }
        }

        action evaluateThermalProtection {
            in temperature : Temperature;
            out shutdown : Boolean;
            do action {
                shutdown = (temperature > maxSafeTemp);
            }
        }
    }

    part def InductivePumpingSystem {
        requirement transferFluidReq : TransferFluidRequirement;
        requirement flowRegulationReq : FlowRegulationRequirement;
        requirement thermalProtectionReq : ThermalProtectionRequirement;

        part source : SourceReservoir {
            attribute currentVolume : Volume = 100 [m^3];
        }

        part destination : DestinationTank {
            attribute currentVolume : Volume = 0 [m^3];
        }

        part pump : InductivePump;

        part powerSupply : PowerSupply;

        part controller : PumpController {
            attribute commandedFlowRate : FlowRate = 0.01 [m^3/s];
        }

        part inletFlowSensor : FlowSensor;
        part outletFlowSensor : FlowSensor;
        part tempSensor : TemperatureSensor;
        part coolingSystem : CoolingSystem;

        connection sourceToPump connect source.fluidOut to pump.inlet;
        connection pumpToDestination connect pump.outlet to destination.fluidIn;
        connection sourceToInletSensor connect source.fluidOut to inletFlowSensor.fluidPort;
        connection pumpToOutletSensor connect pump.outlet to outletFlowSensor.fluidPort;
        connection powerToPump connect powerSupply.powerOut to pump.powerIn;
        connection controllerToPower connect controller.powerControl to powerSupply.controlIn;
        connection inletSensorToController connect inletFlowSensor.dataOut to controller.inletSensor;
        connection outletSensorToController connect outletFlowSensor.dataOut to controller.outletSensor;
        connection tempSensorToPump connect tempSensor.tempOut to pump.tempSensorOut;
        connection tempSensorToController connect tempSensor.tempOut to controller.tempSensor;
        connection tempSensorToCooling connect tempSensor.tempOut to coolingSystem.thermalInterface;
    }
}
