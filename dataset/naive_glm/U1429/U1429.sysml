package HydraulicAccumulatorPowerSystem {
    import ScalarValues::*;

    // ===== Value Types with Units =====

    value type Pressure :> Real {
        attribute unit : String = "Pa";
    }

    value type Volume :> Real {
        attribute unit : String = "m^3";
    }

    value type FlowRate :> Real {
        attribute unit : String = "m^3/s";
    }

    value type Temperature :> Real {
        attribute unit : String = "K";
    }

    value type Mass :> Real {
        attribute unit : String = "kg";
    }

    value type Force :> Real {
        attribute unit : String = "N";
    }

    value type Length :> Real {
        attribute unit : String = "m";
    }

    value type Area :> Real {
        attribute unit : String = "m^2";
    }

    value type Energy :> Real {
        attribute unit : String = "J";
    }

    value type RotationalSpeed :> Real {
        attribute unit : String = "rad/s";
    }

    // ===== Item Definitions =====

    item def HydraulicFluid {
        attribute density : Mass = 850.0;
        attribute viscosity : Real = 0.04;
        attribute bulkModulus : Pressure = 1600000000.0;
        attribute temperature : Temperature = 313.15;
    }

    item def NitrogenGas {
        attribute preChargePressure : Pressure;
        attribute gasConstant : Real = 296.8;
        attribute temperature : Temperature = 293.15;
        attribute volume : Volume;
        attribute mass : Mass;
    }

    // ===== Port Definitions =====

    port def HydraulicPort {
        out item fluidOut : HydraulicFluid;
        in item fluidIn : HydraulicFluid;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def ElectricalPort {
        attribute voltage : Real;
        attribute current : Real;
    }

    port def SignalPort {
        out attribute pressureReading : Pressure;
        out attribute flowReading : FlowRate;
        out attribute temperatureReading : Temperature;
    }

    port def ControlSignalPort {
        in attribute commandPressure : Pressure;
        in attribute commandFlow : FlowRate;
        attribute valvePosition : Real;
    }

    // ===== Component Part Definitions =====

    part def Reservoir {
        port hydraulicSupply : HydraulicPort;
        port hydraulicReturn : HydraulicPort;

        attribute maxCapacity : Volume = 0.05;
        attribute currentVolume : Volume = 0.04;
        attribute fluidLevel : Length;
        attribute minFluidLevel : Length = 0.05;
        attribute ventedToAtmosphere : Boolean = true;
        attribute filterMeshSize : Real = 0.00001;

        action def supplyFluid {
            in requestFlow : FlowRate;
            out suppliedFluid : HydraulicFluid;
            attribute outputPressure : Pressure = 100000.0;
        }

        action def receiveReturnFluid {
            in returnedFluid : HydraulicFluid;
            attribute returnPressure : Pressure;
        }

        action def filterFluid {
            in rawFluid : HydraulicFluid;
            out filteredFluid : HydraulicFluid;
        }

        state reservoirStates {
            state Normal {
                do action { filterFluid; }
                transition to LowFluid when currentVolume < 0.01;
            }
            state LowFluid {
                entry action { send LowFluidWarning; }
                transition to Normal when currentVolume >= 0.02;
            }
        }
    }

    part def HydraulicPump {
        port hydraulicIn : HydraulicPort;
        port hydraulicOut : HydraulicPort;
        port electricalIn : ElectricalPort;

        attribute ratedFlow : FlowRate = 0.0005;
        attribute ratedPressure : Pressure = 20000000.0;
        attribute displacement : Volume = 0.000025;
        attribute efficiency : Real = 0.92;
        attribute shaftSpeed : RotationalSpeed;
        attribute currentFlow : FlowRate;
        attribute currentPressure : Pressure;
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;

        action def pressurizeFluid {
            in lowPressureFluid : HydraulicFluid;
            out highPressureFluid : HydraulicFluid;
            attribute inputPressure : Pressure;
            attribute outputPressure : Pressure;
            attribute flowProduced : FlowRate;
        }

        action def regulateOutput {
            in targetPressure : Pressure;
            out regulatedFlow : FlowRate;
        }

        state pumpStates {
            state Off {
                entry action { currentFlow = 0.0; }
                transition to Starting when electricalIn.voltage > 0.0;
            }
            state Starting {
                do action { shaftSpeed = shaftSpeed + 10.0; }
                transition to Running when shaftSpeed >= 150.0;
                transition to Fault when electricalIn.current > 50.0;
            }
            state Running {
                do action { pressurizeFluid; }
                transition to Off when electricalIn.voltage == 0.0;
                transition to Fault when currentPressure > ratedPressure * 1.1;
            }
            state Fault {
                entry action { send PumpFault; }
                transition to Off when electricalIn.voltage == 0.0;
            }
        }
    }

    part def BladderAccumulator {
        port hydraulicPort : HydraulicPort;

        attribute vesselVolume : Volume = 0.01;
        attribute gasVolume : Volume;
        attribute fluidVolume : Volume;
        attribute preChargePressure : Pressure = 8000000.0;
        attribute maxPressure : Pressure = 21000000.0;
        attribute minPressure : Pressure = 7000000.0;
        attribute currentGasPressure : Pressure;
        attribute currentFluidPressure : Pressure;
        attribute storedEnergy : Energy;
        attribute shellMaterial : String = "High-strength steel";
        attribute shellWallThickness : Length = 0.005;
        attribute bladderMaterial : String = "Nitrile rubber";
        attribute bladderMaxExpansion : Volume = 0.008;
        attribute polytropicExponent : Real = 1.2;

        item nitrogenGas : NitrogenGas {
            attribute preChargePressure : Pressure = 8000000.0;
            attribute volume : Volume = 0.01;
            attribute temperature : Temperature = 293.15;
        }

        action def chargeAccumulator {
            in incomingFluid : HydraulicFluid;
            in chargeFlow : FlowRate;
            action compressGas {
                in gas : NitrogenGas;
                in fluidVolumeAdded : Volume;
                attribute newGasVolume : Volume;
                attribute newGasPressure : Pressure;
            }
            attribute energyStored : Energy;
        }

        action def dischargeAccumulator {
            in demandFlow : FlowRate;
            out outgoingFluid : HydraulicFluid;
            action expandGas {
                in gas : NitrogenGas;
                out fluidVolumeReleased : Volume;
                attribute newGasVolume : Volume;
                attribute newGasPressure : Pressure;
            }
            attribute energyReleased : Energy;
        }

        action def maintainPressure {
            in systemPressure : Pressure;
            attribute pressureStabilized : Boolean;
        }

        state accumulatorStates {
            state PreCharged {
                entry action { currentGasPressure = preChargePressure; gasVolume = vesselVolume; fluidVolume = 0.0; }
                transition to Charging when hydraulicPort.pressure > preChargePressure;
            }
            state Charging {
                do action { chargeAccumulator; }
                transition to FullyCharged when currentGasPressure >= maxPressure;
                transition to Discharging when hydraulicPort.pressure < currentGasPressure;
            }
            state FullyCharged {
                entry action { send AccumulatorFull; }
                do action { maintainPressure; }
                transition to Discharging when hydraulicPort.pressure < currentGasPressure;
            }
            state Discharging {
                do action { dischargeAccumulator; }
                transition to PreCharged when currentGasPressure <= preChargePressure;
                transition to Charging when hydraulicPort.pressure > currentGasPressure;
            }
        }
    }

    part def HydraulicActuator {
        port hydraulicIn : HydraulicPort;
        port hydraulicReturn : HydraulicPort;

        attribute boreDiameter : Length = 0.1;
        attribute rodDiameter : Length = 0.04;
        attribute strokeLength : Length = 0.5;
        attribute pistonArea : Area;
        attribute rodSideArea : Area;
        attribute maxForce : Force = 150000.0;
        attribute currentForce : Force;
        attribute currentPosition : Length;
        attribute currentVelocity : Real;
        attribute loadMass : Mass = 500.0;

        action def extend {
            in pressurizedFluid : HydraulicFluid;
            out returnFluid : HydraulicFluid;
            attribute extendingForce : Force;
            attribute extendingVelocity : Real;
        }

        action def retract {
            in pressurizedFluid : HydraulicFluid;
            out returnFluid : HydraulicFluid;
            attribute retractingForce : Force;
            attribute retractingVelocity : Real;
        }

        action def holdPosition {
            in pressurizedFluid : HydraulicFluid;
            attribute holdingForce : Force;
        }

        state actuatorStates {
            state Idle {
                entry action { currentVelocity = 0.0; }
                transition to Extending when hydraulicIn.pressure > 5000000.0;
            }
            state Extending {
                do action { extend; }
                transition to Holding when currentPosition >= strokeLength;
                transition to Idle when hydraulicIn.pressure < 1000000.0;
            }
            state Holding {
                do action { holdPosition; }
                transition to Retracting when hydraulicReturn.pressure > hydraulicIn.pressure;
                transition to Extending when hydraulicIn.pressure > hydraulicReturn.pressure;
            }
            state Retracting {
                do action { retract; }
                transition to Idle when currentPosition <= 0.0;
            }
        }
    }

    part def PressureSensor {
        port hydraulicPort : HydraulicPort;
        port signalOut : SignalPort;

        attribute measuringRange : Pressure = 30000000.0;
        attribute accuracy : Real = 0.005;
        attribute sampleRate : Real = 1000.0;
        attribute currentReading : Pressure;
        attribute temperatureCompensation : Boolean = true;

        action def measurePressure {
            in fluid : HydraulicFluid;
            out reading : Pressure;
            attribute rawValue : Pressure;
            attribute calibratedValue : Pressure;
        }

        action def transmitSignal {
            in pressureValue : Pressure;
            out signalOutput : Pressure;
        }

        action def selfDiagnostics {
            attribute sensorOK : Boolean;
        }

        state sensorStates {
            state Initializing {
                do action { selfDiagnostics; }
                transition to Active when sensorOK == true;
                transition to Fault when sensorOK == false;
            }
            state Active {
                do action { measurePressure; transmitSignal; }
                transition to Fault when currentReading > measuringRange * 1.1;
            }
            state Fault {
                entry action { send SensorFault; }
                transition to Initializing when sensorOK == true;
            }
        }
    }

    part def ControlValve {
        port portP : HydraulicPort;
        port portA : HydraulicPort;
        port portB : HydraulicPort;
        port portT : HydraulicPort;
        port controlIn : ControlSignalPort;

        attribute valvePosition : Real;
        attribute maxFlow : FlowRate;
        attribute responseTime : Real;
        attribute valveType : String;
        attribute actuatorType : String = "Solenoid";

        action def directFlow {
            in controlSignal : Pressure;
            in incomingFluid : HydraulicFluid;
            out directedFluid : HydraulicFluid;
            out returnFluid : HydraulicFluid;
            attribute flowDirected : FlowRate;
        }

        action def shiftValve {
            in targetPosition : Real;
            attribute currentPosition : Real;
            attribute shiftTime : Real;
        }

        state valveStates {
            state Closed {
                entry action { valvePosition = 0.0; }
                transition to Opening when controlIn.commandPressure > 0.0;
            }
            state Opening {
                do action { shiftValve; }
                transition to Open when valvePosition >= 1.0;
                transition to Closed when controlIn.commandPressure == 0.0;
            }
            state Open {
                do action { directFlow; }
                transition to Closing when controlIn.commandPressure == 0.0;
            }
            state Closing {
                do action { shiftValve; }
                transition to Closed when valvePosition <= 0.0;
                transition to Open when controlIn.commandPressure > 0.0;
            }
        }
    }

    part def PressureReliefValve {
        port hydraulicIn : HydraulicPort;
        port hydraulicOut : HydraulicPort;

        attribute setPressure : Pressure = 25000000.0;
        attribute crackingPressure : Pressure = 24500000.0;
        attribute fullOpenPressure : Pressure = 26000000.0;
        attribute maxFlow : FlowRate = 0.0015;
        attribute currentPressure : Pressure;
        attribute valveOpening : Real;
        attribute springPreload : Force;
        attribute poppetDiameter : Length = 0.015;

        action def ventExcessFluid {
            in excessFluid : HydraulicFluid;
            out ventedFluid : HydraulicFluid;
            attribute ventedFlow : FlowRate;
        }

        action def reseatValve {
            attribute valveReseated : Boolean;
        }

        state reliefValveStates {
            state Closed {
                entry action { valveOpening = 0.0; }
                transition to Cracking when currentPressure >= crackingPressure;
            }
            state Cracking {
                do action { valveOpening = valveOpening + 0.1; }
                action ventExcessFluid;
                transition to FullyOpen when currentPressure >= fullOpenPressure;
                transition to Closed when currentPressure < setPressure;
            }
            state FullyOpen {
                entry action { valveOpening = 1.0; }
                do action { ventExcessFluid; }
                transition to Cracking when currentPressure < fullOpenPressure;
                transition to Closed when currentPressure < setPressure;
            }
        }
    }

    part def CheckValve {
        port hydraulicIn : HydraulicPort;
        port hydraulicOut : HydraulicPort;

        attribute crackingPressure : Pressure = 50000.0;
        attribute maxFlow : FlowRate = 0.002;
        attribute isOpen : Boolean;
        attribute currentPressure : Pressure;

        action def allowForwardFlow {
            in incomingFluid : HydraulicFluid;
            out outgoingFluid : HydraulicFluid;
        }

        action def preventBackflow {
            attribute backflowPrevented : Boolean = true;
        }

        state checkValveStates {
            state Closed {
                transition to Open when currentPressure > crackingPressure;
            }
            state Open {
                do action { allowForwardFlow; }
                transition to Closed when currentPressure <= 0.0;
            }
        }
    }

    part def Controller {
        port sensorInput : SignalPort;
        port chargeValveControl : ControlSignalPort;
        port dischargeValveControl : ControlSignalPort;
        port pumpControl : ElectricalPort;

        attribute targetPressure : Pressure = 18000000.0;
        attribute lowPressureThreshold : Pressure = 9000000.0;
        attribute highPressureThreshold : Pressure = 20000000.0;
        attribute lowDemandThreshold : FlowRate = 0.0001;
        attribute highDemandThreshold : FlowRate = 0.0008;
        attribute controlGain : Real = 0.8;

        action def evaluateDemand {
            in pressureReading : Pressure;
            in flowReading : FlowRate;
            out chargeCommand : Pressure;
            out dischargeCommand : Pressure;
            out pumpCommand : Real;
            attribute demandLevel : Real;
        }

        action def regulatePressure {
            in currentPressure : Pressure;
            out valvePosition : Real;
            attribute error : Pressure;
            attribute correction : Real;
        }

        state controllerStates {
            state Monitoring {
                do action { evaluateDemand; }
                transition to ChargingMode when sensorInput.pressureReading < lowPressureThreshold;
                transition to DischargingMode when sensorInput.pressureReading > highPressureThreshold;
            }
            state ChargingMode {
                do action { regulatePressure; }
                action { chargeValveControl.commandPressure = targetPressure; }
                transition to Monitoring when sensorInput.pressureReading >= targetPressure;
            }
            state DischargingMode {
                do action { regulatePressure; }
                action { dischargeValveControl.commandPressure = targetPressure; }
                transition to Monitoring when sensorInput.pressureReading <= targetPressure;
            }
            state EmergencyShutdown {
                entry action { send EmergencyStop; pumpControl.voltage = 0.0; }
                transition to Monitoring when sensorInput.pressureReading < 5000000.0;
            }
        }
    }

    // ===== System-Level Part Definition =====

    part def HydraulicAccumulatorSystem {
        port systemPressurePort : HydraulicPort;
        port electricalInput : ElectricalPort;
        port systemSignalOutput : SignalPort;

        attribute systemPressure : Pressure;
        attribute safeOperatingLimit : Pressure = 25000000.0;
        attribute normalOperatingPressure : Pressure = 18000000.0;
        attribute lowDemandThreshold : FlowRate = 0.0001;
        attribute highDemandThreshold : FlowRate = 0.0008;
        attribute totalStoredEnergy : Energy;
        attribute systemEfficiency : Real = 0.88;

        part reservoir : Reservoir {
            attribute maxCapacity : Volume = 0.05;
            attribute currentVolume : Volume = 0.04;
        }

        part pump : HydraulicPump {
            attribute ratedFlow : FlowRate = 0.0005;
            attribute ratedPressure : Pressure = 20000000.0;
            attribute efficiency : Real = 0.92;
        }

        part accumulator : BladderAccumulator {
            attribute vesselVolume : Volume = 0.01;
            attribute preChargePressure : Pressure = 8000000.0;
            attribute maxPressure : Pressure = 21000000.0;
            attribute minPressure : Pressure = 7000000.0;
        }

        part actuator : HydraulicActuator {
            attribute boreDiameter : Length = 0.1;
            attribute strokeLength : Length = 0.5;
            attribute maxForce : Force = 150000.0;
            attribute loadMass : Mass = 500.0;
        }

        part pressureSensor : PressureSensor {
            attribute measuringRange : Pressure = 30000000.0;
            attribute accuracy : Real = 0.005;
            attribute sampleRate : Real = 1000.0;
        }

        part chargeValve : ControlValve {
            attribute maxFlow : FlowRate = 0.001;
            attribute responseTime : Real = 0.01;
            attribute valveType : String = "3-position 4-way";
        }

        part dischargeValve : ControlValve {
            attribute maxFlow : FlowRate = 0.002;
            attribute responseTime : Real = 0.005;
            attribute valveType : String = "2-position 2-way";
        }

        part reliefValve : PressureReliefValve {
            attribute setPressure : Pressure = 25000000.0;
            attribute crackingPressure : Pressure = 24500000.0;
            attribute maxFlow : FlowRate = 0.0015;
        }

        part pumpCheckValve : CheckValve {
            attribute crackingPressure : Pressure = 50000.0;
            attribute maxFlow : FlowRate = 0.001;
        }

        part accumulatorCheckValve : CheckValve {
            attribute crackingPressure : Pressure = 100000.0;
            attribute maxFlow : FlowRate = 0.002;
        }

        part controller : Controller {
            attribute targetPressure : Pressure = 18000000.0;
            attribute lowPressureThreshold : Pressure = 9000000.0;
            attribute highPressureThreshold : Pressure = 20000000.0;
        }

        // ===== Connections =====

        connection reservoir.hydraulicSupply to pump.hydraulicIn;
        connection pump.hydraulicOut to pumpCheckValve.hydraulicIn;
        connection pumpCheckValve.hydraulicOut to chargeValve.portP;
        connection chargeValve.portA to accumulator.hydraulicPort;
        connection accumulator.hydraulicPort to accumulatorCheckValve.hydraulicIn;
        connection accumulatorCheckValve.hydraulicOut to chargeValve.portP;
        connection chargeValve.portB to actuator.hydraulicIn;
        connection actuator.hydraulicReturn to dischargeValve.portA;
        connection dischargeValve.portB to reservoir.hydraulicReturn;
        connection chargeValve.portT to reservoir.hydraulicReturn;
        connection pump.hydraulicOut to reliefValve.hydraulicIn;
        connection reliefValve.hydraulicOut to reservoir.hydraulicReturn;
        connection pump.hydraulicOut to pressureSensor.hydraulicPort;
        connection pressureSensor.signalOut to controller.sensorInput;
        connection controller.chargeValveControl to chargeValve.controlIn;
        connection controller.dischargeValveControl to dischargeValve.controlIn;
        connection controller.pumpControl to pump.electricalIn;
        connection electricalInput to controller.pumpControl;
        connection pressureSensor.signalOut to systemSignalOutput;
        connection pump.hydraulicOut to systemPressurePort;

        // ===== System State Machine =====

        state systemOperation {
            attribute currentDemand : FlowRate;
            attribute pumpOutput : FlowRate;
            attribute accumulatorState : String;

            state SystemIdle {
                entry action { systemPressure = 0.0; }
                transition to SystemStartup when electricalInput.voltage > 0.0;
            }

            state SystemStartup {
                do action { pump.shaftSpeed = pump.shaftSpeed + 10.0; }
                transition to PumpRunning when pump.shaftSpeed >= 150.0;
                transition to SystemFault when pump.electricalIn.current > 50.0;
            }

            state PumpRunning {
                do action { pump.pressurizeFluid; }
                transition to LowDemandMode when currentDemand < lowDemandThreshold;
                transition to HighDemandMode when currentDemand > highDemandThreshold;
                transition to OverPressureProtection when systemPressure > safeOperatingLimit;
                transition to SystemIdle when electricalInput.voltage == 0.0;
            }

            state LowDemandMode {
                entry action { accumulatorState = "Charging"; }
                do action { accumulator.chargeAccumulator; }
                transition to PumpRunning when currentDemand >= lowDemandThreshold;
                transition to HighDemandMode when currentDemand > highDemandThreshold;
                transition to OverPressureProtection when systemPressure > safeOperatingLimit;
            }

            state HighDemandMode {
                entry action { accumulatorState = "Discharging"; }
                do action { accumulator.dischargeAccumulator; }
                transition to PumpRunning when currentDemand <= highDemandThreshold;
                transition to LowDemandMode when currentDemand < lowDemandThreshold;
                transition to OverPressureProtection when systemPressure > safeOperatingLimit;
            }

            state OverPressureProtection {
                entry action { send OverPressureAlarm; }
                do action { reliefValve.ventExcessFluid; }
                transition to PumpRunning when systemPressure < safeOperatingLimit * 0.95;
                transition to SystemFault when systemPressure > safeOperatingLimit * 1.1;
            }

            state SystemFault {
                entry action { send SystemFaultAlarm; pump.electricalIn.voltage = 0.0; }
                transition to SystemIdle when electricalInput.voltage == 0.0;
            }
        }

        // ===== System-Level Action =====

        action def manageHydraulicPower {
            in electricalEnergy : ElectricalPort;
            out hydraulicPower : Pressure;
            out systemStatus : SignalPort;

            action drawFluidFromReservoir {
                in reservoirFluid : HydraulicFluid;
                out supplyFluid : HydraulicFluid;
            }

            action pressurizeFluid {
                in supplyFluid : HydraulicFluid;
                out highPressureFluid : HydraulicFluid;
            }

            action distributeFluid {
                in highPressureFluid : HydraulicFluid;
                out fluidToAccumulator : HydraulicFluid;
                out fluidToActuator : HydraulicFluid;
                attribute splitRatio : Real;
            }

            action chargeOrDischargeAccumulator {
                in fluidToAccumulator : HydraulicFluid;
                out storedOrReleasedFluid : HydraulicFluid;
                attribute energyChange : Energy;
            }

            action performWork {
                in fluidToActuator : HydraulicFluid;
                out returnFluid : HydraulicFluid;
                attribute workDone : Energy;
            }

            action monitorSystemPressure {
                in fluid : HydraulicFluid;
                out pressureReading : Pressure;
            }

            action protectFromOverpressure {
                in excessFluid : HydraulicFluid;
                out ventedFluid : HydraulicFluid;
            }

            action returnFluidToReservoir {
                in returnFluid : HydraulicFluid;
                in ventedFluid : HydraulicFluid;
                out reservoirFluid : HydraulicFluid;
            }

            flow drawFluidFromReservoir.supplyFluid to pressurizeFluid.supplyFluid;
            flow pressurizeFluid.highPressureFluid to distributeFluid.highPressureFluid;
            flow distributeFluid.fluidToAccumulator to chargeOrDischargeAccumulator.fluidToAccumulator;
            flow distributeFluid.fluidToActuator to performWork.fluidToActuator;
            flow performWork.returnFluid to returnFluidToReservoir.returnFluid;
            flow chargeOrDischargeAccumulator.storedOrReleasedFluid to returnFluidToReservoir.ventedFluid;
            flow returnFluidToReservoir.reservoirFluid to drawFluidFromReservoir.reservoirFluid;
        }
    }

    // ===== Requirements =====

    requirement def SystemPressureRequirement {
        doc << The system shall maintain hydraulic pressure within safe operating limits at all times. >>;
        attribute maxOperatingPressure : Pressure = 21000000.0;
        attribute safePressureLimit : Pressure = 25000000.0;
        subject systemPressure : Pressure;
        require constraint { systemPressure <= safePressureLimit }
    }

    requirement def AccumulatorStorageRequirement {
        doc << The accumulator shall store sufficient hydraulic energy to supplement pump output during peak demand periods. >>;
        attribute minAccumulatorVolume : Volume = 0.005;
        attribute preChargePressure : Pressure = 8000000.0;
        attribute maxOperatingPressure : Pressure = 21000000.0;
        subject accumulatorVolume : Volume;
        subject storedEnergy : Energy;
        require constraint { accumulatorVolume >= minAccumulatorVolume }
        require constraint { storedEnergy > 0.0 }
    }

    requirement def PumpSizingRequirement {
        doc << The pump shall be sized to meet average demand, not peak demand, to optimize energy efficiency. >>;
        attribute ratedFlow : FlowRate = 0.0005;
        attribute ratedPressure : Pressure = 20000000.0;
        attribute minEfficiency : Real = 0.85;
        subject pumpFlow : FlowRate;
        subject pumpEfficiency : Real;
        require constraint { pumpFlow >= ratedFlow }
        require constraint { pumpEfficiency >= minEfficiency }
    }

    requirement def PressureReliefRequirement {
        doc << The pressure relief valve shall automatically vent excess fluid to the reservoir when system pressure exceeds the safe operating limit. >>;
        attribute reliefValveSetPressure : Pressure = 25000000.0;
        attribute crackingPressure : Pressure = 24500000.0;
        attribute maxVentFlow : FlowRate = 0.0015;
        subject reliefValvePressure : Pressure;
        subject ventFlow : FlowRate;
        require constraint { reliefValvePressure <= reliefValveSetPressure }
        require constraint { ventFlow <= maxVentFlow }
    }

    requirement def PressureMonitoringRequirement {
        doc << The pressure sensor shall continuously monitor system hydraulic pressure and provide real-time readings to the controller. >>;
        attribute minSampleRate : Real = 500.0;
        attribute requiredAccuracy : Real = 0.01;
        attribute measuringRange : Pressure = 30000000.0;
        subject sensorSampleRate : Real;
        subject sensorAccuracy : Real;
        require constraint { sensorSampleRate >= minSampleRate }
        require constraint { sensorAccuracy <= requiredAccuracy }
    }

    requirement def ActuatorPerformanceRequirement {
        doc << The hydraulic actuator shall perform work using pressurized fluid supplied from both the pump and the accumulator. >>;
        attribute maxForce : Force = 150000.0;
        attribute strokeLength : Length = 0.5;
        attribute responseTime : Real = 0.5;
        subject actuatorForce : Force;
        subject actuatorStroke : Length;
        require constraint { actuatorForce <= maxForce }
        require constraint { actuatorStroke <= strokeLength }
    }

    requirement def EnergyEfficiencyRequirement {
        doc << The system shall allow use of a smaller pump while still meeting peak power demands through accumulator discharge. >>;
        attribute pumpRatedFlow : FlowRate = 0.0005;
        attribute peakDemandFlow : FlowRate = 0.002;
        attribute minSystemEfficiency : Real = 0.80;
        subject systemPeakFlow : FlowRate;
        subject systemEfficiency : Real;
        require constraint { systemPeakFlow >= peakDemandFlow }
        require constraint { systemEfficiency >= minSystemEfficiency }
    }

    requirement def PulsationAbsorptionRequirement {
        doc << The accumulator shall absorb pressure pulsations to smooth system operation and reduce mechanical stress. >>;
        attribute maxPulsationAmplitude : Pressure = 500000.0;
        attribute targetPulsationAmplitude : Pressure = 200000.0;
        subject pulsationAmplitude : Pressure;
        require constraint { pulsationAmplitude <= maxPulsationAmplitude }
    }

    requirement def BladderIntegrityRequirement {
        doc << The accumulator bladder shall maintain nitrogen gas separation from hydraulic fluid under all operating conditions. >>;
        attribute bladderMaterial : String = "Nitrile rubber";
        attribute maxCycles : Integer = 1000000;
        attribute maxTemperature : Temperature = 393.15;
        subject bladderTemperature : Temperature;
        subject cycleCount : Integer;
        require constraint { bladderTemperature <= maxTemperature }
        require constraint { cycleCount <= maxCycles }
    }

    requirement def ControlResponseRequirement {
        doc << The controller shall respond to pressure changes within 50 milliseconds to maintain stable system operation. >>;
        attribute maxResponseTime : Real = 0.05;
        attribute controlGain : Real = 0.8;
        subject controllerResponseTime : Real;
        require constraint { controllerResponseTime <= maxResponseTime }
    }

    requirement def CheckValveRequirement {
        doc << Check valves shall prevent backflow from the accumulator to the pump and from the actuator to the accumulator. >>;
        attribute crackingPressure : Pressure = 50000.0;
        attribute maxFlow : FlowRate = 0.002;
        subject backflowPrevented : Boolean;
        subject forwardFlow : FlowRate;
        require constraint { backflowPrevented == true }
        require constraint { forwardFlow <= maxFlow }
    }

    // ===== Requirement Satisfaction =====

    part def SystemVerification {
        part systemUnderTest : HydraulicAccumulatorSystem;

        action def verifyPressureSafety {
            in system : HydraulicAccumulatorSystem;
            attribute measuredPressure : Pressure;
            attribute passCriteria : Pressure = 25000000.0;
            require constraint { measuredPressure <= passCriteria }
        }

        action def verifyAccumulatorCapacity {
            in accumulator : BladderAccumulator;
            attribute measuredVolume : Volume;
            attribute measuredEnergy : Energy;
            attribute minVolume : Volume = 0.005;
            require constraint { measuredVolume >= minVolume }
            require constraint { measuredEnergy > 0.0 }
        }

        action def verifyReliefValveActivation {
            in reliefValve : PressureReliefValve;
            attribute activationPressure : Pressure;
            attribute maxAllowed : Pressure = 25000000.0;
            require constraint { activationPressure <= maxAllowed }
        }

        action def verifyPumpEfficiency {
            in pump : HydraulicPump;
            attribute measuredEfficiency : Real;
            attribute minRequired : Real = 0.85;
            require constraint { measuredEfficiency >= minRequired }
        }

        action def verifySensorAccuracy {
            in sensor : PressureSensor;
            attribute measuredAccuracy : Real;
            attribute maxError : Real = 0.01;
            require constraint { measuredAccuracy <= maxError }
        }

        action def verifyActuatorForce {
            in actuator : HydraulicActuator;
            attribute measuredForce : Force;
            attribute maxForce : Force = 150000.0;
            require constraint { measuredForce <= maxForce }
        }

        action def verifySystemPeakFlow {
            in system : HydraulicAccumulatorSystem;
            attribute measuredPeakFlow : FlowRate;
            attribute minRequired : FlowRate = 0.002;
            require constraint { measuredPeakFlow >= minRequired }
        }

        action def verifyPulsationDamping {
            in accumulator : BladderAccumulator;
            attribute measuredPulsation : Pressure;
            attribute maxAllowed : Pressure = 500000.0;
            require constraint { measuredPulsation <= maxAllowed }
        }

        action def verifyControllerResponse {
            in controller : Controller;
            attribute measuredResponseTime : Real;
            attribute maxAllowed : Real = 0.05;
            require constraint { measuredResponseTime <= maxAllowed }
        }

        action def verifyBladderIntegrity {
            in accumulator : BladderAccumulator;
            attribute gasLeakDetected : Boolean;
            attribute maxTemperature : Temperature = 393.15;
            attribute measuredTemperature : Temperature;
            require constraint { gasLeakDetected == false }
            require constraint { measuredTemperature <= maxTemperature }
        }

        action def runFullSystemTest {
            in system : HydraulicAccumulatorSystem;
            action verifyPressureSafety;
            action verifyAccumulatorCapacity;
            action verifyReliefValveActivation;
            action verifyPumpEfficiency;
            action verifySensorAccuracy;
            action verifyActuatorForce;
            action verifySystemPeakFlow;
            action verifyPulsationDamping;
            action verifyControllerResponse;
            action verifyBladderIntegrity;
        }
    }

    // ===== Requirement Allocation =====

    part def SystemAllocation {
        part system : HydraulicAccumulatorSystem;

        satisfy SystemPressureRequirement by system;
        satisfy AccumulatorStorageRequirement by system.accumulator;
        satisfy PumpSizingRequirement by system.pump;
        satisfy PressureReliefRequirement by system.reliefValve;
        satisfy PressureMonitoringRequirement by system.pressureSensor;
        satisfy ActuatorPerformanceRequirement by system.actuator;
        satisfy EnergyEfficiencyRequirement by system;
        satisfy PulsationAbsorptionRequirement by system.accumulator;
        satisfy BladderIntegrityRequirement by system.accumulator;
        satisfy ControlResponseRequirement by system.controller;
        satisfy CheckValveRequirement by system.pumpCheckValve;
        satisfy CheckValveRequirement by system.accumulatorCheckValve;
    }
}
