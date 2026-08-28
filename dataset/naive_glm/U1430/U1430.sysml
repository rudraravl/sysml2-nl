package CentrifugalPumpSystem {

    // ===== Value Types with Units =====
    value type Pressure { unit 'Pa'; attribute min : Pressure = 0 [Pa]; }
    value type PressureBar { unit 'bar'; }
    value type FlowRate { unit 'm3/s'; attribute min : FlowRate = 0 [m3/s]; }
    value type RotationalSpeed { unit 'rev/min'; }
    value type Torque { unit 'N*m'; }
    value type Power { unit 'W'; }
    value type Temperature { unit 'K'; }
    value type Voltage { unit 'V'; }
    value type Current { unit 'A'; }
    value type Frequency { unit 'Hz'; }
    value type AngularVelocity { unit 'rad/s'; }
    value type VibrationLevel { unit 'm/s2'; }
    value type NPSH { unit 'm'; attribute min : NPSH = 0 [m]; }
    value type Dimension { unit 'm'; }
    value type Mass { unit 'kg'; }
    value type Duration { unit 's'; }
    value type Efficiency { unit '1'; }

    // ===== Items =====
    item def ProcessFluid {
        attribute density : Real [unit 'kg/m3'];
        attribute viscosity : Real [unit 'Pa*s'];
        attribute vaporPressure : Pressure;
    }

    item def ElectricalEnergy;
    item def ControlSignal;
    item def Telemetry;

    // ===== Enumerations =====
    enum PumpMode { Off, Manual, Auto }
    enum ValvePosition { Closed, Opening, Open, Closing }

    // ===== Port Definitions =====
    port def ElectricalInPort {
        in item ElectricalEnergy;
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
    }

    port def ElectricalOutPort {
        out item ElectricalEnergy;
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
    }

    port def ControlCmdPort {
        in item ControlSignal;
        attribute commandedSpeed : RotationalSpeed;
        attribute runCommand : Boolean;
    }

    port def ControlFbPort {
        out item Telemetry;
        attribute measuredSpeed : RotationalSpeed;
        attribute measuredVibration : VibrationLevel;
    }

    port def FluidInPort {
        in item ProcessFluid;
        attribute inletPressure : Pressure;
        attribute inletTemperature : Temperature;
        attribute availableNPSH : NPSH;
    }

    port def FluidOutPort {
        out item ProcessFluid;
        attribute outletPressure : Pressure;
        attribute outletFlow : FlowRate;
        attribute outletTemperature : Temperature;
    }

    port def RotationalMechanicalPort {
        attribute angularVelocity : AngularVelocity;
        attribute torque : Torque;
    }

    port def PressureSignalPort {
        out attribute pressure : Pressure;
        out attribute pressureValid : Boolean;
    }

    port def FlowSignalPort {
        out attribute flow : FlowRate;
        out attribute flowValid : Boolean;
    }

    // ===== Part Definitions =====

    part def ElectricMotor {
        port electricalIn : ElectricalInPort;
        port rotorOut : RotationalMechanicalPort;
        attribute ratedPower : Power = 75000 [W];
        attribute ratedSpeed : RotationalSpeed = 2950 [rev/min];
        attribute ratedVoltage : Voltage = 400 [V];
        attribute ratedCurrent : Current = 135 [A];
        attribute efficiency : Efficiency = 0.93;
        attribute powerFactor : Real = 0.88;
        attribute insulationClass : String = "F";
        attribute protectionClass : String = "IP55";

        action def ConvertEnergy {
            in electricalEnergy : ElectricalEnergy;
            out rotationalTorque : Torque;
            attribute inputPower : Power;
            attribute outputPower : Power;
            attribute losses : Power;
        }

        perform ConvertEnergy {
            bind electricalEnergy = electricalIn.electricalEnergy;
            bind rotationalTorque = rotorOut.torque;
        }
    }

    part def VariableFrequencyDrive {
        port lineIn : ElectricalInPort;
        port motorOut : ElectricalOutPort;
        port controlIn : ControlCmdPort;
        attribute ratedPower : Power = 90000 [W];
        attribute minFrequency : Frequency = 0 [Hz];
        attribute maxFrequency : Frequency = 60 [Hz];
        attribute outputFrequency : Frequency;
        attribute outputVoltage : Voltage;
        attribute outputCurrent : Current;
        attribute switchingFrequency : Frequency = 4000 [Hz];

        action def Modulate {
            in commandedSpeed : RotationalSpeed;
            in lineFrequency : Frequency;
            out driveFrequency : Frequency;
            out driveVoltage : Voltage;
        }
    }

    part def Shaft {
        port driveEnd : RotationalMechanicalPort;
        port drivenEnd : RotationalMechanicalPort;
        attribute material : String = "StainlessSteel410";
        attribute length : Dimension = 0.45 [m];
        attribute diameter : Dimension = 0.045 [m];
        attribute mass : Mass = 5.6 [kg];
        attribute torsionalStiffness : Real [unit 'N*m/rad'];
        attribute criticalSpeed : RotationalSpeed = 5800 [rev/min];
    }

    part def Bearing {
        attribute bearingType : String;
        attribute ratedLoad : Real [unit 'N'];
        attribute lifeHours : Duration = 50000 [s];
        attribute frictionCoefficient : Real = 0.002;
        port mechanicalInterface : RotationalMechanicalPort;
    }

    part def MechanicalSeal {
        port shaftInterface : RotationalMechanicalPort;
        attribute sealType : String = "SingleMechanical";
        attribute faceMaterial : String = "SiliconCarbide/Carbon";
        attribute elastomer : String = "Viton";
        attribute maxPressure : Pressure = 1600000 [Pa];
        attribute maxTemperature : Temperature = 423 [K];
        attribute leakageRate : FlowRate = 0.0 [m3/s];
    }

    part def Impeller {
        port shaftInterface : RotationalMechanicalPort;
        attribute impellerType : String = "ClosedCentrifugal";
        attribute diameter : Dimension = 0.2 [m];
        attribute vaneCount : Integer = 7;
        attribute eyeDiameter : Dimension = 0.08 [m];
        attribute material : String = "StainlessSteel316";
        attribute mass : Mass = 3.2 [kg];
        attribute balanceGrade : String = "G2.5";
    }

    part def Volute {
        attribute material : String = "DuctileIron";
        attribute inletDiameter : Dimension = 0.1 [m];
        attribute outletDiameter : Dimension = 0.08 [m];
        attribute spiralTurns : Real = 1.0;
        attribute cutwaterClearance : Dimension = 0.001 [m];
    }

    part def SuctionNozzle {
        port fluidIn : FluidInPort;
        attribute flangeRating : String = "ANSI150";
        attribute diameter : Dimension = 0.1 [m];
        attribute material : String = "DuctileIron";
    }

    part def DischargeNozzle {
        port fluidOut : FluidOutPort;
        attribute flangeRating : String = "ANSI150";
        attribute diameter : Dimension = 0.08 [m];
        attribute material : String = "DuctileIron";
    }

    part def PumpCasing {
        part volute : Volute;
        part suctionNozzle : SuctionNozzle;
        part dischargeNozzle : DischargeNozzle;
        attribute material : String = "DuctileIronASTM536";
        attribute designPressure : Pressure = 1600000 [Pa];
        attribute designTemperature : Temperature = 393 [K];
        attribute hydrostaticTestPressure : Pressure = 2400000 [Pa];
        attribute wallThickness : Dimension = 0.012 [m];
    }

    part def PressureTransmitter {
        port processPort : FluidInPort;
        port signalPort : PressureSignalPort;
        attribute rangeMin : Pressure = 0 [Pa];
        attribute rangeMax : Pressure = 2500000 [Pa];
        attribute accuracy : Real = 0.0075;
        attribute outputSignal : String = "4-20mA";
        attribute processConnection : String = "1/2NPT";
    }

    part def FlowTransmitter {
        port processPort : FluidInPort;
        port signalPort : FlowSignalPort;
        attribute rangeMin : FlowRate = 0 [m3/s];
        attribute rangeMax : FlowRate = 0.05 [m3/s];
        attribute accuracy : Real = 0.01;
        attribute technology : String = "Electromagnetic";
        attribute outputSignal : String = "4-20mA";
    }

    part def ProcessIsolationValve {
        port fluidPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        attribute position : ValvePosition;
        attribute actuatorType : String = "Manual";
        attribute diameter : Dimension = 0.1 [m];
        attribute strokeTime : Duration = 30 [s];

        action def MoveTo {
            in targetPosition : ValvePosition;
            attribute timeToReach : Duration;
        }
    }

    // ===== Behaviors =====

    state def PumpOperatingStates {
        state Off {
            entry action OffEntry;
            do action OffDo { attribute standby : Boolean = true; }
            exit action OffExit;
        }

        state Starting {
            entry action BeginStartSequence;
            state Priming {
                do action PrimePump {
                    attribute primingTime : Duration = 60 [s];
                }
            }
            state OpeningSuctionValve {
                do action OpenSuction;
            }
            state RampingVFD {
                do action RampVFD {
                    attribute rampDuration : Duration = 15 [s];
                    attribute targetSpeed : RotationalSpeed = 1500 [rev/min];
                }
            }
            state OpeningDischargeValve {
                do action OpenDischarge;
            }
        }

        state Normal {
            do action SteadyOperation;
        }

        state Cavitation {
            entry action DetectCavitation;
            do action ReduceSpeed {
                attribute speedReduction : RotationalSpeed = 200 [rev/min];
            }
        }

        state Runout {
            entry action DetectRunout;
            do action ThrottleFlow;
        }

        state Stopping {
            entry action BeginStopSequence;
            state ClosingDischargeValve {
                do action CloseDischarge;
            }
            state DeceleratingVFD {
                do action DecelerateVFD {
                    attribute rampDuration : Duration = 20 [s];
                }
            }
            state ClosingSuctionValve {
                do action CloseSuction;
            }
        }

        transition offToStarting first Off then Starting;
        transition startingToNormal first Starting then Normal
            when (dischargePressure > 100000 [Pa]) and (outletFlow > 0.005 [m3/s]);
        transition normalToCavitation first Normal then Cavitation
            when (availableNPSH < requiredNPSH);
        transition cavitationToNormal first Cavitation then Normal
            when (availableNPSH > requiredNPSH);
        transition normalToRunout first Normal then Runout
            when (outletFlow > maxFlow);
        transition runoutToNormal first Runout then Normal
            when (outletFlow <= maxFlow);
        transition normalToStopping first Normal then Stopping
            when (runCommand == false);
        transition cavitationToStopping first Cavitation then Stopping
            when (runCommand == false);
        transition runoutToStopping first Runout then Stopping
            when (runCommand == false);
        transition stoppingToOff first Stopping then Off
            when (motorStopped == true);
    }

    action def BeginStartSequence {
        attribute step : String = "StartSequenceInitiated";
    }
    action def PrimePump {
        attribute primingTime : Duration = 60 [s];
    }
    action def OpenSuction;
    action def RampVFD {
        attribute rampDuration : Duration = 15 [s];
        attribute targetSpeed : RotationalSpeed = 1500 [rev/min];
    }
    action def OpenDischarge;
    action def SteadyOperation;
    action def DetectCavitation {
        attribute cavitationDetected : Boolean;
    }
    action def ReduceSpeed {
        attribute speedReduction : RotationalSpeed = 200 [rev/min];
    }
    action def DetectRunout {
        attribute runoutDetected : Boolean;
    }
    action def ThrottleFlow;
    action def BeginStopSequence;
    action def CloseDischarge;
    action def DecelerateVFD {
        attribute rampDuration : Duration = 20 [s];
    }
    action def CloseSuction;
    action def OffEntry;
    action def OffDo {
        attribute standby : Boolean = true;
    }
    action def OffExit;

    // ===== Connection Definitions =====

    connection def ElectricalConnection {
        end supplier : ElectricalOutPort;
        end consumer : ElectricalInPort;
        attribute conductorSize : Dimension = 0.016 [m];
    }

    connection def ShaftConnection {
        end driver : RotationalMechanicalPort;
        end driven : RotationalMechanicalPort;
    }

    connection def FluidConnection {
        end upstream : FluidOutPort;
        end downstream : FluidInPort;
        attribute pipeDiameter : Dimension;
    }

    connection def ControlConnection {
        end source : ControlCmdPort;
        end sink : ControlCmdPort;
    }

    connection def TelemetryConnection {
        end source : ControlFbPort;
        end sink : ControlFbPort;
    }

    // ===== Top-Level System =====

    part def CentrifugalPumpSystem {
        attribute systemName : String = "IndustrialCentrifugalPump";
        attribute designFlowRate : FlowRate = 0.025 [m3/s];
        attribute designHead : Real [unit 'm'] = 60;
        attribute maxFlow : FlowRate = 0.045 [m3/s];
        attribute requiredNPSH : NPSH = 3.0 [m];
        attribute availableNPSH : NPSH;
        attribute dischargePressure : Pressure;
        attribute outletFlow : FlowRate;
        attribute runCommand : Boolean;
        attribute motorStopped : Boolean;

        part electricMotor : ElectricMotor {
            rebind ratedPower = 55000 [W];
            rebind ratedSpeed = 2950 [rev/min];
        }

        part vfd : VariableFrequencyDrive {
            rebind ratedPower = 75000 [W];
        }

        part shaft : Shaft {
            rebind length = 0.45 [m];
            rebind diameter = 0.045 [m];
        }

        part radialBearing : Bearing {
            rebind bearingType = "Radial";
            rebind ratedLoad = 12000;
        }

        part thrustBearing : Bearing {
            rebind bearingType = "Thrust";
            rebind ratedLoad = 8000;
        }

        part mechanicalSeal : MechanicalSeal;

        part impeller : Impeller {
            rebind diameter = 0.2 [m];
        }

        part pumpCasing : PumpCasing {
            part volute : Volute;
            part suctionNozzle : SuctionNozzle;
            part dischargeNozzle : DischargeNozzle;
        }

        part suctionValve : ProcessIsolationValve;
        part dischargeValve : ProcessIsolationValve;

        part suctionPressureTransmitter : PressureTransmitter {
            rebind rangeMax = 600000 [Pa];
        }

        part dischargePressureTransmitter : PressureTransmitter {
            rebind rangeMax = 2500000 [Pa];
        }

        part flowTransmitter : FlowTransmitter {
            rebind rangeMax = 0.05 [m3/s];
        }

        // Ports of the system
        port systemElectricalIn : ElectricalInPort;
        port systemControlIn : ControlCmdPort;
        port systemTelemetryOut : ControlFbPort;
        port suctionPort : FluidInPort;
        port dischargePort : FluidOutPort;

        // Internal connections
        connection vfdToMotor : ElectricalConnection {
            connect vfd.motorOut to electricMotor.electricalIn;
        }
        connection lineToVfd : ElectricalConnection {
            connect systemElectricalIn to vfd.lineIn;
        }
        connection motorToShaft : ShaftConnection {
            connect electricMotor.rotorOut to shaft.driveEnd;
        }
        connection shaftToImpeller : ShaftConnection {
            connect shaft.drivenEnd to impeller.shaftInterface;
        }
        connection shaftToSeal : ShaftConnection {
            connect shaft.drivenEnd to mechanicalSeal.shaftInterface;
        }
        connection radialBearingMount : ShaftConnection {
            connect shaft.driveEnd to radialBearing.mechanicalInterface;
        }
        connection thrustBearingMount : ShaftConnection {
            connect shaft.drivenEnd to thrustBearing.mechanicalInterface;
        }
        connection suctionFluid1 : FluidConnection {
            connect suctionPort to suctionValve.fluidPort;
            rebind pipeDiameter = 0.1 [m];
        }
        connection suctionFluid2 : FluidConnection {
            connect suctionValve.fluidOutPort to pumpCasing.suctionNozzle.fluidIn;
            rebind pipeDiameter = 0.1 [m];
        }
        connection dischargeFluid1 : FluidConnection {
            connect pumpCasing.dischargeNozzle.fluidOut to dischargeValve.fluidPort;
            rebind pipeDiameter = 0.08 [m];
        }
        connection dischargeFluid2 : FluidConnection {
            connect dischargeValve.fluidOutPort to dischargePort;
            rebind pipeDiameter = 0.08 [m];
        }
        connection suctionPressureTap : FluidConnection {
            connect pumpCasing.suctionNozzle.fluidIn to suctionPressureTransmitter.processPort;
            rebind pipeDiameter = 0.015 [m];
        }
        connection dischargePressureTap : FluidConnection {
            connect pumpCasing.dischargeNozzle.fluidOut to dischargePressureTransmitter.processPort;
            rebind pipeDiameter = 0.015 [m];
        }
        connection flowTap : FluidConnection {
            connect dischargeValve.fluidOutPort to flowTransmitter.processPort;
            rebind pipeDiameter = 0.08 [m];
        }
        connection cmdToVfd : ControlConnection {
            connect systemControlIn to vfd.controlIn;
        }

        // Behavioral state machine
        exhibit state operatingStates : PumpOperatingStates;

        // Assignments derived from sensors
        perform action UpdateSystemSignals {
            assign dischargePressure = dischargePressureTransmitter.signalPort.pressure;
            assign outletFlow = flowTransmitter.signalPort.flow;
            assign availableNPSH = suctionPort.availableNPSH;
        }
    }

    // ===== Requirements =====

    requirement def SystemFunctionalRequirements {
        subject pumpSystem : CentrifugalPumpSystem;

        requirement DeliverDesignFlow {
            requirement {
                doc /* The pump shall deliver the design flow rate at the design head. */
                assume pumpSystem.designFlowRate == 0.025 [m3/s]
            }
        }

        requirement OperateAcrossRange {
            requirement {
                doc /* The VFD shall allow speed adjustment across the operating range. */
                assume vfd.maxFrequency == 60 [Hz]
                assume vfd.minFrequency == 0 [Hz]
            }
        }

        requirement ContainPressure {
            requirement {
                doc /* The pump casing shall contain process pressure at design conditions. */
                assume pumpCasing.designPressure == 1600000 [Pa]
                assume pumpCasing.hydrostaticTestPressure >= 1.5 * pumpCasing.designPressure
            }
        }

        requirement PreventLeakage {
            requirement {
                doc /* The mechanical seal shall prevent leakage at the shaft exit. */
                assume mechanicalSeal.leakageRate <= 1e-9 [m3/s]
            }
        }

        requirement ProvideTelemetry {
            requirement {
                doc /* The system shall provide suction pressure, discharge pressure and flow telemetry. */
                assume suctionPressureTransmitter.signalPort.pressureValid == true
                assume dischargePressureTransmitter.signalPort.pressureValid == true
                assume flowTransmitter.signalPort.flowValid == true
            }
        }

        requirement DetectCavitation {
            requirement {
                doc /* The system shall detect cavitation and reduce speed as corrective action. */
                assume operatingStates.Cavitation.entry == DetectCavitation
            }
        }

        requirement DetectRunout {
            requirement {
                doc /* The system shall detect runout and throttle flow as corrective action. */
                assume operatingStates.Runout.entry == DetectRunout
            }
        }

        requirement SafeStartup {
            requirement {
                doc /* Startup shall follow priming, suction valve opening, VFD ramp, and discharge valve opening. */
                assume operatingStates.Starting.entry == BeginStartSequence
            }
        }

        requirement SafeShutdown {
            requirement {
                doc /* Shutdown shall close discharge, decelerate VFD, then close suction valve. */
                assume operatingStates.Stopping.entry == BeginStopSequence
            }
        }

        requirement NPSHMargin {
            requirement {
                doc /* Available NPSH shall exceed required NPSH during normal operation. */
                assume availableNPSH > requiredNPSH
            }
        }
    }

    // ===== Instantiation =====

    part pumpInstance : CentrifugalPumpSystem {
        rebind systemName = "PumpUnit-001";
        rebind designFlowRate = 0.025 [m3/s];
        rebind designHead = 60;
    }

    satisfy SystemFunctionalRequirements by pumpInstance;
}
</packageName>
