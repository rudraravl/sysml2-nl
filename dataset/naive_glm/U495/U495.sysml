package CombinedCyclePowerPlant {

    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type MassFlowRate > Real { unit "kg/s"; }
    value type VolumeFlowRate > Real { unit "m3/s"; }
    value type Temperature > Real { unit "K"; }
    value type Pressure > Real { unit "Pa"; }
    value type AngularVelocity > Real { unit "rad/s"; }
    value type Torque > Real { unit "N*m"; }
    value type MechanicalPower > Real { unit "W"; }
    value type ElectricalPower > Real { unit "W"; }
    value type Voltage > Real { unit "V"; }
    value type Current > Real { unit "A"; }
    value type Frequency > Real { unit "Hz"; }
    value type Energy > Real { unit "J"; }
    value type PowerFactor > Real { }
    value type StateOfCharge > Real { min 0; max 1; }
    value type Efficiency > Real { min 0; max 1; }
    value type SignalLevel > Real { unit "V"; }

    // ===== Item Types =====
    item def NaturalGas;
    item def CombustionAir;
    item def ExhaustGas;
    item def Steam;
    item def Feedwater;
    item def Condensate;
    item def ElectricalEnergy;
    item def ControlSignal;
    item def TelemetrySignal;
    item def GridDemandSignal;

    // ===== Port Definitions =====
    port def FuelInPort {
        in item fuel : NaturalGas;
        in attribute flowRate : MassFlowRate;
    }
    port def AirInPort {
        in item air : CombustionAir;
        in attribute flowRate : MassFlowRate;
    }
    port def ExhaustOutPort {
        out item exhaust : ExhaustGas;
        out attribute temperature : Temperature;
        out attribute flowRate : MassFlowRate;
    }
    port def ExhaustInPort {
        in item exhaust : ExhaustGas;
        in attribute temperature : Temperature;
        in attribute flowRate : MassFlowRate;
    }
    port def SteamPort {
        out item steam : Steam;
        out attribute pressure : Pressure;
        out attribute temperature : Temperature;
        out attribute flowRate : MassFlowRate;
    }
    port def FeedwaterPort {
        in item water : Feedwater;
        in attribute flowRate : MassFlowRate;
        in attribute temperature : Temperature;
    }
    port def MechanicalShaftPort {
        out attribute torque : Torque;
        out attribute speed : AngularVelocity;
        out attribute power : MechanicalPower;
    }
    port def MechanicalShaftInPort {
        in attribute torque : Torque;
        in attribute speed : AngularVelocity;
        in attribute power : MechanicalPower;
    }
    port def ACPowerPort {
        out attribute voltage : Voltage;
        out attribute current : Current;
        out attribute frequency : Frequency;
        out attribute power : ElectricalPower;
        out attribute powerFactor : PowerFactor;
    }
    port def ACPowerInPort {
        in attribute voltage : Voltage;
        in attribute current : Current;
        in attribute frequency : Frequency;
        in attribute power : ElectricalPower;
        in attribute powerFactor : PowerFactor;
    }
    port def BidirectionalACPort {
        in out attribute voltage : Voltage;
        in out attribute current : Current;
        in out attribute frequency : Frequency;
        in out attribute power : ElectricalPower;
        in out attribute powerFactor : PowerFactor;
    }
    port def GridPort {
        in out attribute voltage : Voltage;
        in out attribute current : Current;
        in out attribute frequency : Frequency;
        in out attribute power : ElectricalPower;
        in out attribute powerFactor : PowerFactor;
    }
    port def ControlCmdPort {
        in attribute command : ControlSignal;
        in attribute setpoint : ElectricalPower;
    }
    port def TelemetryPort {
        out attribute telemetry : TelemetrySignal;
        out attribute measuredPower : ElectricalPower;
        out attribute status : String;
    }
    port def DemandPort {
        in attribute demand : GridDemandSignal;
        in attribute requestedPower : ElectricalPower;
    }

    // ===== Requirements =====
    requirement def ReliablePowerGeneration {
        doc { The plant shall generate and deliver reliable, high-quality electrical power to the regional grid. }
        attribute minOutputPower : ElectricalPower = 50e6;
        attribute maxOutputPower : ElectricalPower = 500e6;
        attribute nominalFrequency : Frequency = 60;
        attribute nominalVoltage : Voltage = 380e3;
        attribute frequencyTolerance : Frequency = 0.05;
        attribute voltageTolerance : Voltage = 5e3;
        require generatedPower >= minOutputPower;
        require generatedPower <= maxOutputPower;
    }

    requirement def CombinedCycleEfficiency {
        doc { The plant shall achieve high thermal efficiency by recovering exhaust heat. }
        attribute minOverallEfficiency : Efficiency = 0.58;
        require overallEfficiency >= minOverallEfficiency;
    }

    requirement def PowerQuality {
        doc { The power conditioning unit shall regulate voltage, stabilize frequency, and filter noise. }
        require abs(outputFrequency - 60.0) <= 0.05;
        require abs(outputVoltage - 380e3) <= 5e3;
        require harmonicDistortion <= 0.03;
    }

    requirement def GridStabilization {
        doc { The energy storage system shall provide rapid response for grid stabilization. }
        attribute maxResponseTime : Real = 0.1 { unit "s"; }
        attribute minStorageCapacity : Energy = 100e6;
        require responseTime <= maxResponseTime;
        require storageCapacity >= minStorageCapacity;
    }

    requirement def LoadFollowing {
        doc { The control system shall dynamically adjust output to follow real-time grid demand. }
        attribute maxRampRate : Real = 20e6 { unit "W/s"; }
        require rampRate <= maxRampRate;
    }

    // ===== Gas Turbine =====
    part def GasTurbine {
        attribute ratedPower : MechanicalPower = 250e6;
        attribute thermalEfficiency : Efficiency = 0.38;
        attribute currentPower : MechanicalPower;
        attribute currentSpeed : AngularVelocity;
        attribute exhaustTemp : Temperature = 870;
        attribute exhaustFlow : MassFlowRate = 600;

        port fuelInput : FuelInPort;
        port airInput : AirInPort;
        port shaftOutput : MechanicalShaftPort;
        port exhaustOutput : ExhaustOutPort;
        port controlIn : ControlCmdPort;
        port telemetryOut : TelemetryPort;

        action def Combust {
            in fuel : NaturalGas;
            in air : CombustionAir;
            out exhaust : ExhaustGas;
            out mechanicalPower : MechanicalPower;
        }

        perform action combust : Combust {
            in fuel = fuelInput.fuel;
            in air = airInput.air;
            out exhaust = exhaustOutput.exhaust;
            out mechanicalPower = shaftOutput.power;
        }

        state def TurbineStates {
            entry; then Off;
            state Off;
            transition from Off to Cranking when controlIn.command == "START";
            state Cranking;
            transition from Cranking to Firing after 30 { unit "s"; };
            state Firing;
            transition from Firing to Running when currentSpeed >= 3000;
            state Running;
            transition from Running to Cooldown when controlIn.command == "STOP";
            state Cooldown;
            transition from Cooldown to Off after 600 { unit "s"; };
        }

        exhibit state machine turbineSM : TurbineStates;
    }

    // ===== Electrical Generator =====
    part def ElectricalGenerator {
        attribute ratedPower : ElectricalPower = 240e6;
        attribute efficiency : Efficiency = 0.98;
        attribute outputVoltage : Voltage = 22e3;
        attribute outputFrequency : Frequency = 60;
        attribute outputPower : ElectricalPower;
        attribute powerFactor : PowerFactor = 0.9;

        port shaftInput : MechanicalShaftInPort;
        port powerOutput : ACPowerPort;
        port controlIn : ControlCmdPort;
        port telemetryOut : TelemetryPort;

        action def Generate {
            in mechanicalPower : MechanicalPower;
            out electricalPower : ElectricalPower;
        }

        perform action generate : Generate {
            in mechanicalPower = shaftInput.power;
            out electricalPower = powerOutput.power;
        }
    }

    // ===== Heat Recovery System =====
    part def HeatRecoverySystem {
        attribute ratedSteamPressure : Pressure = 16e6;
        attribute ratedSteamTemp : Temperature = 810;
        attribute steamFlow : MassFlowRate = 180;
        attribute recoveredPower : ElectricalPower = 130e6;
        attribute efficiency : Efficiency = 0.92;

        port exhaustInput : ExhaustInPort;
        port feedwaterInput : FeedwaterPort;
        port steamOutput : SteamPort;
        port controlIn : ControlCmdPort;
        port telemetryOut : TelemetryPort;

        part hrsg : HRSGBoiler;
        part steamTurbine : SteamTurbine;
        part condenser : Condenser;

        connect exhaustInput to hrsg.gasIn;
        connect feedwaterInput to hrsg.waterIn;
        connect hrsg.steamOut to steamTurbine.steamIn;
        connect steamTurbine.exhaustSteam to condenser.steamIn;
        connect condenser.condensateOut to hrsg.waterIn;
        connect steamOutput to steamTurbine.steamOut;

        state def HRSSStates {
            entry; then Idle;
            state Idle;
            transition from Idle to Preheating when controlIn.command == "START";
            state Preheating;
            transition from Preheating to Operating when hrsg.steamPressure >= 12e6;
            state Operating;
            transition from Operating to Shutdown when controlIn.command == "STOP";
            state Shutdown;
            transition from Shutdown to Idle after 1200 { unit "s"; };
        }

        exhibit state machine hrssSM : HRSSStates;
    }

    part def HRSGBoiler {
        attribute steamPressure : Pressure;
        attribute steamTemperature : Temperature;
        port gasIn : ExhaustInPort;
        port waterIn : FeedwaterPort;
        port steamOut : SteamPort;
    }

    part def SteamTurbine {
        attribute ratedPower : MechanicalPower = 130e6;
        port steamIn : SteamPort;
        port steamOut : SteamPort;
        port exhaustSteam : SteamPort;
        port shaftOut : MechanicalShaftPort;
    }

    part def Condenser {
        port steamIn : SteamPort;
        port condensateOut : FeedwaterPort;
    }

    // ===== Power Conditioning Unit =====
    part def PowerConditioningUnit {
        attribute ratedPower : ElectricalPower = 400e6;
        attribute outputVoltage : Voltage = 380e3;
        attribute outputFrequency : Frequency = 60;
        attribute harmonicDistortion : Real = 0.02;
        attribute efficiency : Efficiency = 0.99;

        port generatorInput : ACPowerInPort;
        port storagePort : BidirectionalACPort;
        port gridOutput : GridPort;
        port controlIn : ControlCmdPort;
        port telemetryOut : TelemetryPort;

        action def Condition {
            in inputPower : ElectricalPower;
            out outputPower : ElectricalPower;
        }

        perform action condition : Condition {
            in inputPower = generatorInput.power;
            out outputPower = gridOutput.power;
        }

        state def PCUStates {
            entry; then Standby;
            state Standby;
            transition from Standby to Synchronizing when controlIn.command == "CONNECT";
            state Synchronizing;
            transition from Synchronizing to Online when abs(outputFrequency - 60.0) <= 0.02;
            state Online;
            transition from Online to Standby when controlIn.command == "DISCONNECT";
        }

        exhibit state machine pcuSM : PCUStates;
    }

    // ===== Energy Storage System =====
    part def EnergyStorageSystem {
        attribute ratedCapacity : Energy = 200e6;
        attribute ratedPower : ElectricalPower = 50e6;
        attribute stateOfCharge : StateOfCharge = 0.5;
        attribute responseTime : Real = 0.05 { unit "s"; };
        attribute chargeRate : ElectricalPower;
        attribute dischargeRate : ElectricalPower;

        port gridPort : BidirectionalACPort;
        port controlIn : ControlCmdPort;
        port telemetryOut : TelemetryPort;

        action def Charge {
            in power : ElectricalPower;
            out energy : Energy;
        }
        action def Discharge {
            in energy : Energy;
            out power : ElectricalPower;
        }

        state def ESSStates {
            entry; then Idle;
            state Idle;
            transition from Idle to Charging when controlIn.command == "CHARGE" and stateOfCharge < 0.95;
            state Charging;
            transition from Charging to Idle when stateOfCharge >= 0.95 or controlIn.command == "HOLD";
            transition from Idle to Discharging when controlIn.command == "DISCHARGE" and stateOfCharge > 0.05;
            state Discharging;
            transition from Discharging to Idle when stateOfCharge <= 0.05 or controlIn.command == "HOLD";
        }

        exhibit state machine essSM : ESSStates;
    }

    // ===== Control System =====
    part def ControlSystem {
        attribute mode : String = "AUTO";
        attribute targetPower : ElectricalPower;
        attribute actualPower : ElectricalPower;
        attribute rampRate : Real = 15e6 { unit "W/s"; };

        port turbineCmd : ControlCmdPort;
        port generatorCmd : ControlCmdPort;
        port hrssCmd : ControlCmdPort;
        port pcuCmd : ControlCmdPort;
        port essCmd : ControlCmdPort;
        port demandInput : DemandPort;
        port turbineTelemetry : TelemetryPort;
        port generatorTelemetry : TelemetryPort;
        port hrssTelemetry : TelemetryPort;
        port pcuTelemetry : TelemetryPort;
        port essTelemetry : TelemetryPort;

        action def StartupSequence;
        action def ShutdownSequence;
        action def LoadFollow {
            in demand : ElectricalPower;
            out setpoint : ElectricalPower;
        }

        perform action loadFollow : LoadFollow {
            in demand = demandInput.requestedPower;
            out setpoint = targetPower;
        }

        state def ControlStates {
            entry; then ColdStandby;
            state ColdStandby;
            transition from ColdStandby to Starting when demandInput.command == "START";
            state Starting;
            transition from Starting to Online when pcuTelemetry.status == "ONLINE";
            state Online;
            transition from Online to ShuttingDown when demandInput.command == "STOP";
            state ShuttingDown;
            transition from ShuttingDown to ColdStandby when turbineTelemetry.status == "OFF";
        }

        exhibit state machine controlSM : ControlStates;
    }

    // ===== Combined Cycle Power Plant =====
    part def CombinedCyclePlant {
        attribute plantName : String = "Regional Combined Cycle Plant";
        attribute overallEfficiency : Efficiency = 0.60;
        attribute generatedPower : ElectricalPower;
        attribute outputFrequency : Frequency;
        attribute outputVoltage : Voltage;

        satisfy ReliablePowerGeneration;
        satisfy CombinedCycleEfficiency;
        satisfy PowerQuality;
        satisfy GridStabilization;
        satisfy LoadFollowing;

        part gasTurbine : GasTurbine;
        part generator : ElectricalGenerator;
        part heatRecovery : HeatRecoverySystem;
        part powerConditioning : PowerConditioningUnit;
        part energyStorage : EnergyStorageSystem;
        part controlSystem : ControlSystem;

        port gridConnection : GridPort;
        port fuelSupply : FuelInPort;
        port airIntake : AirInPort;
        port feedwaterSupply : FeedwaterPort;
        port operatorInterface : DemandPort;

        // Mechanical coupling
        connect gasTurbine.shaftOutput to generator.shaftInput;

        // Exhaust gas to heat recovery
        connect gasTurbine.exhaustOutput to heatRecovery.exhaustInput;

        // Feedwater supply
        connect feedwaterSupply to heatRecovery.feedwaterInput;

        // Generator output to power conditioning
        connect generator.powerOutput to powerConditioning.generatorInput;

        // Energy storage bidirectional connection to power conditioning
        connect energyStorage.gridPort to powerConditioning.storagePort;

        // Power conditioning to grid
        connect powerConditioning.gridOutput to gridConnection;

        // Control system connections
        connect controlSystem.turbineCmd to gasTurbine.controlIn;
        connect controlSystem.generatorCmd to generator.controlIn;
        connect controlSystem.hrssCmd to heatRecovery.controlIn;
        connect controlSystem.pcuCmd to powerConditioning.controlIn;
        connect controlSystem.essCmd to energyStorage.controlIn;

        connect gasTurbine.telemetryOut to controlSystem.turbineTelemetry;
        connect generator.telemetryOut to controlSystem.generatorTelemetry;
        connect heatRecovery.telemetryOut to controlSystem.hrssTelemetry;
        connect powerConditioning.telemetryOut to controlSystem.pcuTelemetry;
        connect energyStorage.telemetryOut to controlSystem.essTelemetry;

        connect operatorInterface to controlSystem.demandInput;

        // Fuel and air supply
        connect fuelSupply to gasTurbine.fuelInput;
        connect airIntake to gasTurbine.airInput;
    }

    part plantInstance : CombinedCyclePlant;
}
