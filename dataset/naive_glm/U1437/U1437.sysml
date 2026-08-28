package JohnCraneSealSupportSystem_APIPlan53B {
    import ScalarValues::*;
    import ISQ::*;
    import ISQPressure::*;
    import ISQTemperature::*;
    import ISQVolume::*;
    import ISQMass::*;
    import ISQFlowRate::*;
    import ISQDuration::*;

    // ===== Value Types =====

    value type PressureValue :> Real { :>> unit = 'Pa'; }
    value type TemperatureValue :> Real { :>> unit = 'K'; }
    value type VolumeValue :> Real { :>> unit = 'm3'; }
    value type FlowRateValue :> Real { :>> unit = 'm3/s'; }
    value type LevelValue :> Real { :>> unit = '%'; min = 0; max = 100; }
    value type DifferentialPressureValue :> Real { :>> unit = 'Pa'; }
    value type MassValue :> Real { :>> unit = 'kg'; }
    value type DurationValue :> Real { :>> unit = 's'; }
    value type PowerValue :> Real { :>> unit = 'W'; }
    value type RotationalSpeedValue :> Real { :>> unit = 'rad/s'; }
    value type AreaValue :> Real { :>> unit = 'm2'; }
    value type LengthValue :> Real { :>> unit = 'm'; }
    value type DimensionlessValue :> Real;

    // ===== Item Types =====

    item def BarrierFluid {
        attribute density : MassValue = 850.0; // kg/m3 typical synthetic oil
        attribute specificHeat : Real = 2000.0; // J/(kg.K)
        attribute viscosity : Real = 0.015; // Pa.s
        attribute currentPressure : PressureValue;
        attribute currentTemperature : TemperatureValue;
        attribute contaminationLevel : DimensionlessValue = 0.0;
    }

    item def ProcessFluid {
        attribute processPressure : PressureValue;
        attribute processTemperature : TemperatureValue;
        attribute hazardLevel : String;
    }

    item def GasCharge {
        attribute preChargePressure : PressureValue;
        attribute gasType : String = "Nitrogen";
    }

    item def ContaminantParticle {
        attribute particleSize : LengthValue;
        attribute particleCount : Integer;
    }

    // ===== Port Definitions =====

    port def BarrierFluidPort {
        out barrierFluidOut : BarrierFluid;
        in barrierFluidIn : BarrierFluid;
        attribute portPressure : PressureValue;
        attribute portTemperature : TemperatureValue;
        attribute portFlowRate : FlowRateValue;
    }

    port def FluidInletPort {
        in fluidIn : BarrierFluid;
        attribute inletPressure : PressureValue;
        attribute inletTemperature : TemperatureValue;
        attribute inletFlowRate : FlowRateValue;
    }

    port def FluidOutletPort {
        out fluidOut : BarrierFluid;
        attribute outletPressure : PressureValue;
        attribute outletTemperature : TemperatureValue;
        attribute outletFlowRate : FlowRateValue;
    }

    port def SignalPort {
        out pressureReading : PressureValue;
        out temperatureReading : TemperatureValue;
        out levelReading : LevelValue;
        out flowRateReading : FlowRateValue;
        out alarmStatus : String;
        out shutdownCommand : Boolean;
    }

    port def ControlPort {
        in pressureSetpoint : PressureValue;
        in temperatureSetpoint : TemperatureValue;
        in levelSetpoint : LevelValue;
        in pumpCommand : Boolean;
        in shutdownCommand : Boolean;
    }

    port def ProcessInterfacePort {
        in barrierFluidSupply : BarrierFluid;
        out barrierFluidReturn : BarrierFluid;
        attribute sealCavityPressure : PressureValue;
        attribute processFluidPressure : PressureValue;
    }

    port def PowerPort {
        in electricalPower : PowerValue;
        attribute voltage : Real = 480.0;
        attribute frequency : Real = 60.0;
    }

    // ===== Interfaces =====

    interface def BarrierFluidFlowInterface {
        end supplier : FluidOutletPort;
        end consumer : FluidInletPort;
        flow barrierFluidFlow : BarrierFluid;
    }

    interface def ControlSignalInterface {
        end controller : ControlPort;
        end instrument : SignalPort;
    }

    // ===== Component Part Definitions =====

    part def PressurizedReservoir {
        port reservoirInlet : FluidInletPort;
        port reservoirOutlet : FluidOutletPort;
        port reservoirSignal : SignalPort;
        port reservoirControl : ControlPort;

        attribute totalVolume : VolumeValue = 0.060; // 60 liters
        attribute fluidVolume : VolumeValue = 0.045; // 45 liters initial fill
        attribute maxOperatingPressure : PressureValue = 2.0e6; // 20 bar
        attribute minOperatingPressure : PressureValue = 0.5e6; // 5 bar
        attribute designTemperature : TemperatureValue = 350.0; // K
        attribute material : String = "Stainless Steel 316L";

        part bladderAccumulator : BladderAccumulator {
            attribute bladderVolume : VolumeValue = 0.015;
            attribute preChargePressure : PressureValue = 1.2e6; // 12 bar
            attribute bladderMaterial : String = "Nitrile Rubber";
            attribute maxGasCompressionRatio : Real = 4.0;
            port gasChargePort : FluidInletPort;
        }

        part levelTransmitter : LevelTransmitter {
            attribute measurementRange : LevelValue = 100.0;
            attribute accuracy : Real = 0.5;
        }

        part pressureTransmitter : PressureTransmitter {
            attribute measurementRange : PressureValue = 3.0e6;
            attribute accuracy : Real = 0.25;
        }

        attribute currentLevel : LevelValue = 75.0;
        attribute currentPressure : PressureValue = 1.5e6;
        attribute currentTemperature : TemperatureValue = 310.0;

        action def maintainPressure {
            in fluidDemand : FlowRateValue;
            out suppliedFluid : BarrierFluid;
            // Bladder accumulator expands/contracts to maintain pressure
        }

        action def monitorLevel {
            out levelReading : LevelValue;
        }

        requirement reservoirPressureConstraint {
            doc { /* Reservoir pressure must remain above process pressure + margin */ }
            constraint { currentPressure > 1.2e6 }
        }
    }

    part def BladderAccumulator {
        attribute gasVolume : VolumeValue = 0.015;
        attribute fluidVolume : VolumeValue = 0.045;
        attribute preChargePressure : PressureValue = 1.2e6;
        attribute currentGasPressure : PressureValue;
        attribute bladderMaterial : String = "Nitrile Rubber";
        attribute maxOperatingPressure : PressureValue = 2.5e6;
        attribute burstPressure : PressureValue = 4.0e6;

        action def regulatePressure {
            in systemPressure : PressureValue;
            out regulatedPressure : PressureValue;
            // Uses Boyle's law: P1*V1 = P2*V2
        }

        requirement bladderIntegrity {
            constraint { currentGasPressure <= burstPressure }
        }
    }

    part def CirculationPump {
        port pumpInlet : FluidInletPort;
        port pumpOutlet : FluidOutletPort;
        port pumpPower : PowerPort;
        port pumpControl : ControlPort;
        port pumpSignal : SignalPort;

        attribute ratedFlowRate : FlowRateValue = 0.0005; // 0.5 L/s
        attribute ratedPressure : PressureValue = 2.5e6; // 25 bar
        attribute ratedPower : PowerValue = 750.0; // 0.75 kW
        attribute ratedSpeed : RotationalSpeedValue = 157.08; // 1500 RPM
        attribute pumpType : String = "Centrifugal";
        attribute motorType : String = "TEFC Induction Motor";
        attribute efficiency : Real = 0.65;

        attribute currentFlowRate : FlowRateValue;
        attribute currentPressure : PressureValue;
        attribute isRunning : Boolean = false;
        attribute runHours : DurationValue = 0.0;

        action def circulateFluid {
            in inletFluid : BarrierFluid;
            out outletFluid : BarrierFluid;
            // Increases pressure and drives flow through the loop
        }

        action def startPump {
            in startCommand : Boolean;
            // Soft start sequence
        }

        action def stopPump {
            in stopCommand : Boolean;
            // Controlled ramp-down
        }

        state def PumpOperatingState {
            entry; then Off;

            state Off {
                entry action { isRunning = false; }
            }

            state Starting {
                entry action { isRunning = true; }
                do circulateFluid;
            }

            state Running {
                entry action { isRunning = true; }
                do circulateFluid;
            }

            state Faulted {
                entry action { isRunning = false; }
            }

            transition Off -> Starting
                when pumpControl.pumpCommand == true;
            transition Starting -> Running
                when currentPressure >= 0.8 * ratedPressure;
            transition Running -> Off
                when pumpControl.pumpCommand == false;
            transition Running -> Faulted
                when currentPressure < 0.3e6 or currentFlowRate < 0.0001;
            transition Faulted -> Off
                when pumpControl.shutdownCommand == true;
        }
    }

    part def FilterAssembly {
        port filterInlet : FluidInletPort;
        port filterOutlet : FluidOutletPort;
        port filterSignal : SignalPort;

        attribute filterRating : LengthValue = 0.00001; // 10 micron
        attribute filterArea : AreaValue = 0.05;
        attribute maxDifferentialPressure : PressureValue = 50000.0; // 0.5 bar
        attribute currentDifferentialPressure : PressureValue;
        attribute elementType : String = "Glass Fiber";
        attribute bypassValveSetting : PressureValue = 60000.0; // 0.6 bar
        attribute isBypassOpen : Boolean = false;
        attribute serviceInterval : DurationValue = 432000.0; // 120 hours

        part filterElement : FilterElement {
            attribute micronRating : LengthValue = 0.00001;
            attribute dirtHoldingCapacity : MassValue = 0.05;
            attribute currentDirtLoad : MassValue = 0.0;
            attribute isClogged : Boolean = false;
        }

        part bypassValve : BypassValve {
            attribute crackPressure : PressureValue = 60000.0;
            attribute isOpen : Boolean = false;
        }

        part differentialPressureGauge : DifferentialPressureGauge {
            attribute range : PressureValue = 100000.0;
            attribute currentReading : PressureValue;
        }

        action def filterFluid {
            in dirtyFluid : BarrierFluid;
            out cleanFluid : BarrierFluid;
            out capturedContaminants : ContaminantParticle;
            // Removes particulates above micron rating
        }

        action def checkBypass {
            // Opens bypass valve if differential pressure exceeds threshold
        }

        requirement filterIntegrity {
            constraint { currentDifferentialPressure < maxDifferentialPressure }
        }
    }

    part def FilterElement {
        attribute micronRating : LengthValue;
        attribute dirtHoldingCapacity : MassValue;
        attribute currentDirtLoad : MassValue;
        attribute isClogged : Boolean;
    }

    part def BypassValve {
        attribute crackPressure : PressureValue;
        attribute isOpen : Boolean;
    }

    part def DifferentialPressureGauge {
        attribute range : PressureValue;
        attribute currentReading : PressureValue;
    }

    part def HeatExchanger {
        port hxFluidInlet : FluidInletPort;
        port hxFluidOutlet : FluidOutletPort;
        port hxCoolantInlet : FluidInletPort;
        port hxCoolantOutlet : FluidOutletPort;
        port hxSignal : SignalPort;

        attribute heatDuty : PowerValue = 3000.0; // 3 kW
        attribute heatTransferArea : AreaValue = 0.8;
        attribute overallU : Real = 250.0; // W/(m2.K)
        attribute designPressure : PressureValue = 3.0e6;
        attribute designTemperature : TemperatureValue = 400.0;
        attribute coolantType : String = "Cooling Water";
        attribute coolantInletTemperature : TemperatureValue = 293.15; // 20 C
        attribute coolantFlowRate : FlowRateValue = 0.002;
        attribute tubeMaterial : String = "316L Stainless Steel";
        attribute shellMaterial : String = "Carbon Steel";

        attribute currentInletTemp : TemperatureValue;
        attribute currentOutletTemp : TemperatureValue;
        attribute currentHeatRemoval : PowerValue;

        action def coolBarrierFluid {
            in hotFluid : BarrierFluid;
            in coolantIn : BarrierFluid;
            out cooledFluid : BarrierFluid;
            out coolantOut : BarrierFluid;
            // Counter-flow heat exchange
        }

        action def calculateHeatTransfer {
            // Q = U * A * LMTD
        }

        requirement coolingPerformance {
            doc { /* Outlet temperature must be below setpoint */ }
            constraint { currentOutletTemp <= 323.15 } // 50 C max
        }
    }

    part def MechanicalSealInterface {
        port sealSupplyPort : FluidInletPort;
        port sealReturnPort : FluidOutletPort;
        port processInterface : ProcessInterfacePort;
        port sealSignal : SignalPort;

        attribute sealType : String = "Dual Mechanical Seal";
        attribute sealFaceMaterial : String = "Silicon Carbide vs Carbon";
        attribute sealSize : LengthValue = 0.100; // 100 mm shaft
        attribute maxSealPressure : PressureValue = 3.0e6;
        attribute maxSealTemperature : TemperatureValue = 423.15; // 150 C
        attribute barrierPressureMargin : PressureValue = 0.15e6; // 1.5 bar above process

        attribute currentBarrierPressure : PressureValue;
        attribute currentProcessPressure : PressureValue;
        attribute currentSealTemperature : TemperatureValue;
        attribute leakageRate : FlowRateValue = 0.0;

        part primarySeal : SealFace {
            attribute faceWidth : LengthValue = 0.005;
            attribute faceFlatness : LengthValue = 0.0000003; // 0.3 micron
        }

        part secondarySeal : SealFace {
            attribute faceWidth : LengthValue = 0.005;
            attribute faceFlatness : LengthValue = 0.0000003;
        }

        part sealGland : SealGland {
            attribute glandMaterial : String = "316L SS";
            attribute connectionSize : LengthValue = 0.025; // 1 inch
        }

        action def lubricateSealFaces {
            in barrierFluid : BarrierFluid;
            // Forms hydrodynamic film between faces
        }

        action def coolSealFaces {
            in barrierFluid : BarrierFluid;
            out heatedFluid : BarrierFluid;
            // Absorbs frictional heat
        }

        action def maintainPressureBarrier {
            // Ensures barrier pressure > process pressure
        }

        requirement pressureDifferentialRequirement {
            doc { /* Barrier fluid pressure must exceed process pressure by at least 1.5 bar */ }
            constraint { currentBarrierPressure > currentProcessPressure + barrierPressureMargin }
        }
    }

    part def SealFace {
        attribute faceWidth : LengthValue;
        attribute faceFlatness : LengthValue;
        attribute material : String = "Silicon Carbide";
        attribute wearRate : LengthValue;
    }

    part def SealGland {
        attribute glandMaterial : String;
        attribute connectionSize : LengthValue;
    }

    part def InstrumentationPanel {
        port panelControl : ControlPort;
        port panelSignal : SignalPort;
        port panelPower : PowerPort;

        attribute systemPressureSetpoint : PressureValue = 1.8e6;
        attribute systemTemperatureSetpoint : TemperatureValue = 323.15; // 50 C
        attribute systemLevelSetpoint : LevelValue = 70.0;
        attribute lowLevelAlarm : LevelValue = 30.0;
        attribute highTempAlarm : TemperatureValue = 343.15; // 70 C
        attribute lowPressureAlarm : PressureValue = 0.8e6;
        attribute highPressureAlarm : PressureValue = 2.5e6;
        attribute criticalLowLevel : LevelValue = 15.0;
        attribute criticalHighTemp : TemperatureValue = 363.15; // 90 C
        attribute criticalLowPressure : PressureValue = 0.3e6;

        attribute currentSystemState : String = "Normal";
        attribute alarmActive : Boolean = false;
        attribute shutdownActive : Boolean = false;

        part pressureIndicator : PressureIndicator {
            attribute range : PressureValue = 4.0e6;
            attribute accuracy : Real = 0.25;
            attribute currentReading : PressureValue;
        }

        part temperatureIndicator : TemperatureIndicator {
            attribute range : TemperatureValue = 473.15;
            attribute sensorType : String = "RTD Pt100";
            attribute currentReading : TemperatureValue;
        }

        part levelIndicator : LevelIndicator {
            attribute range : LevelValue = 100.0;
            attribute sensorType : String = "Ultrasonic";
            attribute currentReading : LevelValue;
        }

        part flowIndicator : FlowIndicator {
            attribute range : FlowRateValue = 0.002;
            attribute sensorType : String = "Coriolis";
            attribute currentReading : FlowRateValue;
        }

        part differentialPressureSwitch : DifferentialPressureSwitch {
            attribute setpoint : DifferentialPressureValue = 0.15e6;
            attribute tripStatus : Boolean = false;
        }

        part controller : PLCController {
            attribute scanTime : DurationValue = 0.01;
            attribute programVersion : String = "API53B_v2.1";
            attribute inputCount : Integer = 16;
            attribute outputCount : Integer = 8;
        }

        part alarmPanel : AlarmPanel {
            attribute visualAlarms : Integer = 8;
            attribute audibleAlarm : Boolean = true;
            attribute alarmHistory : Integer = 1000;
        }

        action def monitorParameters {
            in pressure : PressureValue;
            in temperature : TemperatureValue;
            in level : LevelValue;
            in flowRate : FlowRateValue;
            out systemStatus : String;
            // Continuous monitoring of all parameters
        }

        action def evaluateAlarms {
            in pressure : PressureValue;
            in temperature : TemperatureValue;
            in level : LevelValue;
            out alarmFlags : String;
            // Compares readings against setpoints
        }

        action def triggerShutdown {
            out shutdownCommand : Boolean;
            // Emergency shutdown sequence
        }

        action def logEvent {
            in eventDescription : String;
            in timestamp : DurationValue;
            // Records events for diagnostics
        }

        state def SystemOperatingState {
            entry; then NormalOperation;

            state NormalOperation {
                entry action { currentSystemState = "Normal"; alarmActive = false; shutdownActive = false; }
                do monitorParameters;
            }

            state LowLevelAlarm {
                entry action { currentSystemState = "LowLevelAlarm"; alarmActive = true; }
                do monitorParameters;
            }

            state HighTemperatureAlarm {
                entry action { currentSystemState = "HighTempAlarm"; alarmActive = true; }
                do monitorParameters;
            }

            state LowPressureAlarm {
                entry action { currentSystemState = "LowPressureAlarm"; alarmActive = true; }
                do monitorParameters;
            }

            state HighPressureAlarm {
                entry action { currentSystemState = "HighPressureAlarm"; alarmActive = true; }
                do monitorParameters;
            }

            state FilterCloggedAlarm {
                entry action { currentSystemState = "FilterCloggedAlarm"; alarmActive = true; }
                do monitorParameters;
            }

            state EmergencyShutdown {
                entry action { currentSystemState = "EmergencyShutdown"; shutdownActive = true; }
                do triggerShutdown;
            }

            transition NormalOperation -> LowLevelAlarm
                when panelSignal.levelReading < lowLevelAlarm;
            transition NormalOperation -> HighTemperatureAlarm
                when panelSignal.temperatureReading > highTempAlarm;
            transition NormalOperation -> LowPressureAlarm
                when panelSignal.pressureReading < lowPressureAlarm;
            transition NormalOperation -> HighPressureAlarm
                when panelSignal.pressureReading > highPressureAlarm;

            transition LowLevelAlarm -> NormalOperation
                when panelSignal.levelReading >= systemLevelSetpoint;
            transition HighTemperatureAlarm -> NormalOperation
                when panelSignal.temperatureReading <= systemTemperatureSetpoint;
            transition LowPressureAlarm -> NormalOperation
                when panelSignal.pressureReading >= systemPressureSetpoint;
            transition HighPressureAlarm -> NormalOperation
                when panelSignal.pressureReading <= systemPressureSetpoint;

            transition LowLevelAlarm -> EmergencyShutdown
                when panelSignal.levelReading < criticalLowLevel;
            transition HighTemperatureAlarm -> EmergencyShutdown
                when panelSignal.temperatureReading > criticalHighTemp;
            transition LowPressureAlarm -> EmergencyShutdown
                when panelSignal.pressureReading < criticalLowPressure;

            transition EmergencyShutdown -> NormalOperation
                when panelControl.shutdownCommand == false
                and panelSignal.levelReading >= systemLevelSetpoint
                and panelSignal.temperatureReading <= systemTemperatureSetpoint
                and panelSignal.pressureReading >= systemPressureSetpoint;
        }
    }

    part def PressureIndicator {
        attribute range : PressureValue;
        attribute accuracy : Real;
        attribute currentReading : PressureValue;
    }

    part def TemperatureIndicator {
        attribute range : TemperatureValue;
        attribute sensorType : String;
        attribute currentReading : TemperatureValue;
    }

    part def LevelIndicator {
        attribute range : LevelValue;
        attribute sensorType : String;
        attribute currentReading : LevelValue;
    }

    part def FlowIndicator {
        attribute range : FlowRateValue;
        attribute sensorType : String;
        attribute currentReading : FlowRateValue;
    }

    part def DifferentialPressureSwitch {
        attribute setpoint : DifferentialPressureValue;
        attribute tripStatus : Boolean;
    }

    part def PLCController {
        attribute scanTime : DurationValue;
        attribute programVersion : String;
        attribute inputCount : Integer;
        attribute outputCount : Integer;
    }

    part def AlarmPanel {
        attribute visualAlarms : Integer;
        attribute audibleAlarm : Boolean;
        attribute alarmHistory : Integer;
    }

    part def LevelTransmitter {
        attribute measurementRange : LevelValue;
        attribute accuracy : Real;
    }

    part def PressureTransmitter {
        attribute measurementRange : PressureValue;
        attribute accuracy : Real;
    }

    // ===== Top-Level System =====

    part SealSupportSystem {
        doc { /* John Crane API Plan 53B Seal Support System - Self-contained barrier fluid circulation system for dual mechanical seals */ }

        port systemSupplyPort : FluidOutletPort;
        port systemReturnPort : FluidInletPort;
        port systemProcessInterface : ProcessInterfacePort;
        port systemPower : PowerPort;
        port systemControl : ControlPort;
        port systemSignal : SignalPort;

        attribute systemDesignPressure : PressureValue = 2.5e6;
        attribute systemDesignFlowRate : FlowRateValue = 0.0005;
        attribute systemDesignTemperature : TemperatureValue = 350.0;
        attribute barrierFluidType : String = "Synthetic ISO VG 32";
        attribute apiPlanType : String = "API Plan 53B";
        attribute manufacturer : String = "John Crane";

        part reservoir : PressurizedReservoir;
        part circulationPump : CirculationPump;
        part filterAssembly : FilterAssembly;
        part heatExchanger : HeatExchanger;
        part sealInterface : MechanicalSealInterface;
        part instrumentationPanel : InstrumentationPanel;

        // Piping and connections
        part piping : PipingSystem {
            attribute pipeMaterial : String = "316L Stainless Steel";
            attribute pipeSize : LengthValue = 0.025; // 1 inch
            attribute totalPipeLength : LengthValue = 5.0;
            attribute designPressure : PressureValue = 3.0e6;
        }

        part valves : ValveAssembly {
            part isolationValve1 : IsolationValve {
                attribute size : LengthValue = 0.025;
                attribute type : String = "Ball Valve";
            }
            part isolationValve2 : IsolationValve {
                attribute size : LengthValue = 0.025;
                attribute type : String = "Ball Valve";
            }
            part checkValve : CheckValve {
                attribute size : LengthValue = 0.025;
                attribute crackPressure : PressureValue = 10000.0;
            }
            part pressureReliefValve : PressureReliefValve {
                attribute setPressure : PressureValue = 3.0e6;
                attribute size : LengthValue = 0.015;
            }
            part regulatingValve : RegulatingValve {
                attribute size : LengthValue = 0.025;
                attribute setPressure : PressureValue = 1.8e6;
            }
        }

        part baseplate : Baseplate {
            attribute material : String = "Carbon Steel Painted";
            attribute dimensions : String = "1200mm x 800mm x 100mm";
        }

        // Connections - Barrier Fluid Loop
        connection reservoirToPump : BarrierFluidFlowInterface
            connect reservoir.reservoirOutlet to circulationPump.pumpInlet;

        connection pumpToFilter : BarrierFluidFlowInterface
            connect circulationPump.pumpOutlet to filterAssembly.filterInlet;

        connection filterToHeatExchanger : BarrierFluidFlowInterface
            connect filterAssembly.filterOutlet to heatExchanger.hxFluidInlet;

        connection heatExchangerToSeal : BarrierFluidFlowInterface
            connect heatExchanger.hxFluidOutlet to sealInterface.sealSupplyPort;

        connection sealToReservoir : BarrierFluidFlowInterface
            connect sealInterface.sealReturnPort to reservoir.reservoirInlet;

        // Coolant connections
        connection coolantSupply : BarrierFluidFlowInterface
            connect heatExchanger.hxCoolantInlet to heatExchanger.hxCoolantOutlet;

        // Control signal connections
        connection panelToPump : ControlSignalInterface
            connect instrumentationPanel.panelControl to circulationPump.pumpControl;

        connection panelToReservoir : ControlSignalInterface
            connect instrumentationPanel.panelControl to reservoir.reservoirControl;

        connection reservoirToPanel : ControlSignalInterface
            connect reservoir.reservoirSignal to instrumentationPanel.panelSignal;

        connection pumpToPanel : ControlSignalInterface
            connect circulationPump.pumpSignal to instrumentationPanel.panelSignal;

        connection filterToPanel : ControlSignalInterface
            connect filterAssembly.filterSignal to instrumentationPanel.panelSignal;

        connection heatExchangerToPanel : ControlSignalInterface
            connect heatExchanger.hxSignal to instrumentationPanel.panelSignal;

        connection sealToPanel : ControlSignalInterface
            connect sealInterface.sealSignal to instrumentationPanel.panelSignal;

        // Process interface connection
        connection sealToProcess : BarrierFluidFlowInterface
            connect sealInterface.processInterface to systemProcessInterface;

        // System-level action
        action def operateSystem {
            in startCommand : Boolean;
            // 1. Initialize instrumentation panel
            // 2. Start circulation pump
            // 3. Establish barrier fluid flow
            // 4. Verify pressure differential
            // 5. Enter normal operation
        }

        action def shutdownSystem {
            in shutdownCommand : Boolean;
            // 1. Stop circulation pump
            // 2. Close isolation valves
            // 3. Verify safe state
            // 4. Log shutdown event
        }

        action def performMaintenance {
            in maintenanceType : String;
            // Filter element replacement
            // Barrier fluid top-off
            // Bladder pre-charge verification
            // Heat exchanger inspection
        }
    }

    part def PipingSystem {
        attribute pipeMaterial : String;
        attribute pipeSize : LengthValue;
        attribute totalPipeLength : LengthValue;
        attribute designPressure : PressureValue;
    }

    part def ValveAssembly {
        part isolationValve1 : IsolationValve;
        part isolationValve2 : IsolationValve;
        part checkValve : CheckValve;
        part pressureReliefValve : PressureReliefValve;
        part regulatingValve : RegulatingValve;
    }

    part def IsolationValve {
        attribute size : LengthValue;
        attribute type : String;
    }

    part def CheckValve {
        attribute size : LengthValue;
        attribute crackPressure : PressureValue;
    }

    part def PressureReliefValve {
        attribute setPressure : PressureValue;
        attribute size : LengthValue;
    }

    part def RegulatingValve {
        attribute size : LengthValue;
        attribute setPressure : PressureValue;
    }

    part def Baseplate {
        attribute material : String;
        attribute dimensions : String;
    }

    // ===== Requirements =====

    requirement def PressureDifferentialRequirement {
        doc { /* The barrier fluid pressure must be maintained at a higher pressure than the process fluid to ensure any leakage is barrier fluid into the process, not process fluid to atmosphere */ }
        attribute requiredMargin : PressureValue = 0.15e6; // 1.5 bar minimum

        subject sealSupportSystem : SealSupportSystem;

        constraint { sealSupportSystem.sealInterface.currentBarrierPressure > sealSupportSystem.sealInterface.currentProcessPressure + requiredMargin }
    }

    requirement def BarrierFluidCleanlinessRequirement {
        doc { /* Barrier fluid must be filtered to 10 micron or better to protect precision-lapped seal faces */ }
        attribute maxParticleSize : LengthValue = 0.00001; // 10 micron

        subject filterAssembly : FilterAssembly;

        constraint { filterAssembly.filterRating <= maxParticleSize }
    }

    requirement def TemperatureControlRequirement {
        doc { /* Barrier fluid temperature must be maintained below 50C to preserve lubricating properties and prevent seal damage */ }
        attribute maxOutletTemperature : TemperatureValue = 323.15; // 50 C

        subject heatExchanger : HeatExchanger;

        constraint { heatExchanger.currentOutletTemp <= maxOutletTemperature }
    }

    requirement def ReservoirCapacityRequirement {
        doc { /* Reservoir must have sufficient capacity to maintain barrier pressure during pump stoppage via bladder accumulator */ }
        attribute minReserveVolume : VolumeValue = 0.010; // 10 liters reserve
        attribute minPreChargePressure : PressureValue = 1.0e6; // 10 bar

        subject reservoir : PressurizedReservoir;

        constraint { reservoir.totalVolume - reservoir.fluidVolume >= minReserveVolume }
        constraint { reservoir.bladderAccumulator.preChargePressure >= minPreChargePressure }
    }

    requirement def FlowRateRequirement {
        doc { /* Circulation pump must deliver sufficient flow to maintain seal face lubrication and cooling */ }
        attribute minFlowRate : FlowRateValue = 0.0002; // 0.2 L/s minimum

        subject circulationPump : CirculationPump;

        constraint { circulationPump.ratedFlowRate >= minFlowRate }
    }

    requirement def EmergencyShutdownRequirement {
        doc { /* System must trigger emergency shutdown when critical thresholds are exceeded to prevent catastrophic seal failure */ }
        attribute maxResponseTime : DurationValue = 2.0; // 2 seconds

        subject instrumentationPanel : InstrumentationPanel;

        constraint { instrumentationPanel.criticalLowLevel > 0 }
        constraint { instrumentationPanel.criticalHighTemp < 373.15 }
        constraint { instrumentationPanel.criticalLowPressure > 0 }
    }

    requirement def SystemReliabilityRequirement {
        doc { /* The API Plan 53B system shall provide continuous barrier fluid circulation and pressure maintenance to protect dual mechanical seals on critical rotating equipment */ }

        subject sealSupportSystem : SealSupportSystem;

        satisfy PressureDifferentialRequirement;
        satisfy BarrierFluidCleanlinessRequirement;
        satisfy TemperatureControlRequirement;
        satisfy ReservoirCapacityRequirement;
        satisfy FlowRateRequirement;
        satisfy EmergencyShutdownRequirement;
    }

    // ===== Verification =====

    verification def VerifyPressureDifferential {
        subject sealSupportSystem : SealSupportSystem;
        objective {
            doc { /* Verify barrier pressure exceeds process pressure by required margin during normal operation */ }
        }
    }

    verification def VerifyFlowRate {
        subject circulationPump : CirculationPump;
        objective {
            doc { /* Verify pump delivers rated flow rate at design pressure */ }
        }
    }

    verification def VerifyTemperatureControl {
        subject heatExchanger : HeatExchanger;
        objective {
            doc { /* Verify heat exchanger maintains outlet temperature below 50C at design heat load */ }
        }
    }

    verification def VerifyFiltration {
        subject filterAssembly : FilterAssembly;
        objective {
            doc { /* Verify filter removes particles above 10 micron rating */ }
        }
    }

    verification def VerifyEmergencyShutdown {
        subject instrumentationPanel : InstrumentationPanel;
        objective {
            doc { /* Verify emergency shutdown triggers within 2 seconds of critical threshold breach */ }
        }
    }
}
