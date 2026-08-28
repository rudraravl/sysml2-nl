package PumpingSubsystem {
    import ScalarValues::*;

    // ---- Value Types with Units ----
    value type Length { unit 'm'; }
    value type RPM { unit 'rpm'; }
    value type Pressure { unit 'Pa'; }
    value type FlowRate { unit 'm3/s'; }
    value type Temperature { unit 'K'; }
    value type Voltage { unit 'V'; }
    value type Current { unit 'A'; }
    value type Power { unit 'W'; }
    value type Torque { unit 'N*m'; }
    value type Volume { unit 'm3'; }
    value type MassFlowRate { unit 'kg/s'; }

    // ---- Item Types ----
    item def WorkingFluid {
        attribute density: Real = 1000.0; // kg/m3
        attribute viscosity: Real = 0.001; // Pa*s
    }
    item def PressurizedFluid :> WorkingFluid {
        attribute pressure: Pressure;
    }
    item def SupplyFluid :> WorkingFluid {
        attribute pressure: Pressure = 101325 [Pa];
    }
    item def ElectricalEnergy {
        attribute voltage: Voltage;
        attribute current: Current;
    }
    item def OilMist {
        attribute oilGrade: String = "ISO VG 32";
    }

    // ---- Signal / Message Types ----
    item def SpeedCommand {
        attribute targetSpeed: RPM;
    }
    item def StartSignal;
    item def ShutdownSignal;
    item def PumpTelemetry {
        attribute currentSpeed: RPM;
        attribute dischargePressure: Pressure;
        attribute flowRate: FlowRate;
        attribute motorTemperature: Temperature;
    }

    // ---- Port Definitions ----
    port def FluidInPort {
        in item SupplyFluid;
    }
    port def FluidOutPort {
        out item PressurizedFluid;
    }
    port def ElectricalPowerPort {
        out item ElectricalEnergy;
    }
    port def ElectricalSinkPort {
        in item ElectricalEnergy;
    }
    port def CommandOutPort {
        out item SpeedCommand;
    }
    port def CommandInPort {
        in item SpeedCommand;
    }
    port def TelemetryOutPort {
        out item PumpTelemetry;
    }
    port def TelemetryInPort {
        in item PumpTelemetry;
    }
    port def OilMistPort {
        out item OilMist;
    }
    port def OilMistSinkPort {
        in item OilMist;
    }

    // ---- Mechanical Component Definitions ----
    part def ElectricMotor {
        attribute ratedPower: Power = 75000 [W];
        attribute ratedVoltage: Voltage = 480 [V];
        attribute ratedCurrent: Current = 156.25 [A];
        attribute maxSpeed: RPM = 5000 [rpm];
        attribute currentSpeed: RPM;
        attribute temperature: Temperature;
        attribute efficiency: Real = 0.95;
        port powerIn: ElectricalSinkPort;
        port mechanicalOut;
    }

    part def DriveShaft {
        attribute material: String = "Titanium Alloy Ti-6Al-4V";
        attribute maxTorque: Torque = 500 [N*m];
        attribute length: Length = 0.35 [m];
        attribute diameter: Length = 0.025 [m];
        port shaftInput;
        port shaftOutput;
    }

    part def Impeller {
        attribute bladeCount: Integer = 6;
        attribute nominalSpeed: RPM = 3600 [rpm];
        attribute maxSpeed: RPM = 4500 [rpm];
        attribute diameter: Length = 0.15 [m];
        attribute impellerInput;
        attribute impellerOutput;
    }

    part def CeramicBallBearing {
        attribute material: String = "Silicon Nitride Si3N4";
        attribute maxSpeed: RPM = 5000 [rpm];
        attribute dynamicLoadRating: Real = 50000; // N
        attribute innerDiameter: Length = 0.025 [m];
        attribute outerDiameter: Length = 0.062 [m];
        port lubricationIn: OilMistSinkPort;
    }

    part def OilMistLubricationSystem {
        attribute oilType: String = "ISO VG 32 Turbine Oil";
        attribute mistFlowRate: MassFlowRate = 0.001 [kg/s];
        attribute reservoirCapacity: Volume = 0.002 [m3];
        port oilMistOut1: OilMistPort;
        port oilMistOut2: OilMistPort;
    }

    part def MechanicalFaceSeal {
        attribute material: String = "Silicon Carbide";
        attribute maxPressure: Pressure = 50000000 [Pa];
        attribute maxSpeed: RPM = 5000 [rpm];
        attribute shaftDiameter: Length = 0.025 [m];
    }

    part def StainlessSteelHousing {
        attribute material: String = "316L Stainless Steel";
        attribute wallThickness: Length = 0.012 [m];
        attribute maxWorkingPressure: Pressure = 100000000 [Pa];
        attribute designPressure: Pressure = 70000000 [Pa];
        attribute inletDiameter: Length = 0.08 [m];
        attribute outletDiameter: Length = 0.06 [m];
    }

    // ---- Turbopump Assembly ----
    part def Turbopump {
        port fluidIn: FluidInPort;
        port fluidOut: FluidOutPort;
        port electricalIn: ElectricalSinkPort;
        port commandIn: CommandInPort;
        port telemetryOut: TelemetryOutPort;

        part motor: ElectricMotor;
        part shaft: DriveShaft;
        part impeller: Impeller;
        part bearing1: CeramicBallBearing;
        part bearing2: CeramicBallBearing;
        part lubrication: OilMistLubricationSystem;
        part seal: MechanicalFaceSeal;
        part housing: StainlessSteelHousing;

        attribute nominalSpeed: RPM = 3600 [rpm];
        attribute currentSpeed: RPM;
        attribute dischargePressure: Pressure;
        attribute flowRate: FlowRate;
        attribute motorTemperature: Temperature;
        attribute targetSpeed: RPM;

        connection motorToShaft connect motor.mechanicalOut to shaft.shaftInput;
        connection shaftToImpeller connect shaft.shaftOutput to impeller.impellerInput;
        connection lubeToBearing1 connect lubrication.oilMistOut1 to bearing1.lubricationIn;
        connection lubeToBearing2 connect lubrication.oilMistOut2 to bearing2.lubricationIn;

        // Internal action to generate telemetry
        action def generateTelemetry :> PumpTelemetry {
            in currentSpeed: RPM;
            in dischargePressure: Pressure;
            in flowRate: FlowRate;
            in motorTemperature: Temperature;
        }

        // State machine for pump operation
        state def PumpOperation {
            entry; then Off;

            state Off {
                entry { currentSpeed = 0 [rpm]; }
            }

            transition startPump
                first Off
                accept StartSignal
                then Starting;

            state Starting {
                entry { motor.powerIn.in.electricalEnergy.voltage = 480 [V]; }
            }

            transition motorStarted
                first Starting
                accept 'motor_energized'
                then Accelerating;

            state Accelerating {
                // Ramp speed toward target
            }

            transition targetReached
                first Accelerating
                when currentSpeed >= targetSpeed
                then SteadyFlow;

            state SteadyFlow {
                // Sustain nominal operation
            }

            transition adjustSpeed
                first SteadyFlow
                accept SpeedCommand
                then Adjusting;

            state Adjusting {
                // Modify speed to match new target
            }

            transition adjustComplete
                first Adjusting
                when currentSpeed >= targetSpeed
                then SteadyFlow;

            transition shutdown
                first SteadyFlow
                accept ShutdownSignal
                then Decelerating;

            transition shutdownFromAdjust
                first Adjusting
                accept ShutdownSignal
                then Decelerating;

            state Decelerating {
                // Ramp down speed
            }

            transition motorStopped
                first Decelerating
                when currentSpeed == 0 [rpm]
                then Off;
        }

        exhibit PumpOperation;
    }

    // ---- External System Components ----
    part def FluidSupplyTank {
        attribute capacity: Volume = 5.0 [m3];
        attribute currentLevel: Volume = 4.0 [m3];
        attribute fluidType: String = "Deionized Water";
        port fluidOut: FluidInPort;
    }

    part def ReceiverTank {
        attribute capacity: Volume = 3.0 [m3];
        attribute currentPressure: Pressure = 101325 [Pa];
        attribute maxPressure: Pressure = 70000000 [Pa];
        port fluidIn: FluidOutPort;
    }

    part def PowerSupply {
        attribute outputVoltage: Voltage = 480 [V];
        attribute maxPower: Power = 100000 [W];
        attribute efficiency: Real = 0.92;
        port electricalOut: ElectricalPowerPort;
    }

    part def ElectronicController {
        attribute targetSpeed: RPM = 3600 [rpm];
        attribute sampleRate: Real = 100.0; // Hz
        attribute maxSpeed: RPM = 4500 [rpm];
        attribute minSpeed: RPM = 0 [rpm];
        port commandOut: CommandOutPort;
        port telemetryIn: TelemetryInPort;

        action def processTelemetry {
            in telemetry: PumpTelemetry;
            out adjustedTarget: RPM;
        }

        state def ControllerOperation {
            entry; then Idle;

            state Idle;

            transition activate
                first Idle
                accept 'start_command'
                then Active;

            state Active {
                entry; then Monitoring;

                state Monitoring {
                    // Receive and evaluate telemetry
                }

                transition evaluate
                    first Monitoring
                    accept PumpTelemetry
                    then Adjusting;

                state Adjusting {
                    // Compute new target speed
                }

                transition commandDispatched
                    first Adjusting
                    accept 'command_sent'
                    then Monitoring;
            }

            transition deactivate
                first Active
                accept 'stop_command'
                then Idle;
        }

        exhibit ControllerOperation;
    }

    // ---- Top-level Pumping System ----
    part def PumpingSystem {
        part supplyTank: FluidSupplyTank;
        part turbopump: Turbopump;
        part receiverTank: ReceiverTank;
        part powerSupply: PowerSupply;
        part controller: ElectronicController;

        connection supplyToPump connect supplyTank.fluidOut to turbopump.fluidIn;
        connection pumpToReceiver connect turbopump.fluidOut to receiverTank.fluidIn;
        connection powerToPump connect powerSupply.electricalOut to turbopump.electricalIn;
        connection controllerToPump connect controller.commandOut to turbopump.commandIn;
        connection pumpToController connect turbopump.telemetryOut to controller.telemetryIn;
    }

    // ---- Requirements ----
    requirement def NominalSpeedRequirement {
        subject pump: Turbopump;
        require pump.nominalSpeed == 3600 [rpm];
    }

    requirement def PressureContainmentRequirement {
        subject housing: StainlessSteelHousing;
        require housing.maxWorkingPressure >= 100000000 [Pa];
    }

    requirement def FlowRateRequirement {
        subject pump: Turbopump;
        require pump.flowRate >= 0.05 [m3/s];
    }

    requirement def DischargePressureRequirement {
        subject pump: Turbopump;
        require pump.dischargePressure >= 5000000 [Pa];
    }

    requirement def TelemetryReportingRequirement {
        subject pump: Turbopump;
        require pump.telemetryOut.out.PumpTelemetry.currentSpeed != null;
        require pump.telemetryOut.out.PumpTelemetry.dischargePressure != null;
        require pump.telemetryOut.out.PumpTelemetry.flowRate != null;
        require pump.telemetryOut.out.PumpTelemetry.motorTemperature != null;
    }

    requirement def BearingSpeedRequirement {
        subject bearing: CeramicBallBearing;
        require bearing.maxSpeed >= 5000 [rpm];
    }

    requirement def ShaftStrengthRequirement {
        subject shaft: DriveShaft;
        require shaft.maxTorque >= 500 [N*m];
    }

    requirement def SealPressureRequirement {
        subject seal: MechanicalFaceSeal;
        require seal.maxPressure >= 50000000 [Pa];
    }

    requirement def PowerSupplyRequirement {
        subject psu: PowerSupply;
        require psu.maxPower >= 75000 [W];
        require psu.outputVoltage == 480 [V];
    }

    requirement def ControlResponsivenessRequirement {
        subject ctrl: ElectronicController;
        require ctrl.sampleRate >= 50.0;
    }

    // ---- Verification ----
    verification PumpPerformanceVerification {
        subject pump: Turbopump;
        objective {
            verify PumpPerformanceRequirement {
                require pump.currentSpeed >= 3600 [rpm];
                require pump.dischargePressure >= 5000000 [Pa];
                require pump.flowRate >= 0.05 [m3/s];
            }
        }
    }

    verification HousingIntegrityVerification {
        subject housing: StainlessSteelHousing;
        objective {
            verify PressureContainmentRequirement;
        }
    }

    verification TelemetryVerification {
        subject pump: Turbopump;
        objective {
            verify TelemetryReportingRequirement;
        }
    }
}
