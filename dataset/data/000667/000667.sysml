package 'Liquid Nitrogen Cryogenic Cooling System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def CryogenicTemperature :> TemperatureValue;
    attribute def FlowRate :> VolumeFlowRateValue;
    attribute def PressureLevel :> PressureValue;
    attribute def LiquidLevel :> Real;
    attribute def HeatTransferRate :> PowerValue;
    attribute def ValvePosition :> Real;

    item def LiquidNitrogen {
        attribute boilingPoint : CryogenicTemperature = 77.36 [K];
        attribute density : DensityValue = 808.0 [kg/m^3];
        attribute latentHeat : ISQ::SpecificEnergyValue = 199.0 [kJ/kg];
        attribute currentTemperature : CryogenicTemperature;
        attribute currentPressure : PressureLevel;
    }

    port def CryogenicFluidPort {
        out attribute temperature : CryogenicTemperature;
        out attribute flowRate : FlowRate;
        out attribute pressure : PressureLevel;
    }

    port def ThermalLoadPort {
        in attribute heatLoad : PowerValue;
        out attribute surfaceTemperature : TemperatureValue;
    }

    port def ControlPort {
        in attribute setpoint : CryogenicTemperature;
        out attribute measured : CryogenicTemperature;
        out attribute status : String;
    }

    part def StorageDewar {
        doc /* Vacuum-insulated vessel for storing liquid nitrogen at cryogenic temperatures */
        
        attribute capacity : VolumeValue;
        attribute currentLevel : LiquidLevel;
        attribute insulationVacuumPressure : PressureLevel;
        attribute boilOffRate : FlowRate;

        port liquidOutlet : CryogenicFluidPort;
        port pressureVent;

        part vacuumJacket {
            attribute vacuumQuality : PressureLevel;
            attribute thermalConductivity : Real;
        }

        part innerVessel {
            item ln2Reservoir : LiquidNitrogen;
            attribute wallTemperature : CryogenicTemperature;
        }

        part levelIndicator {
            attribute currentReading : LiquidLevel;
        }
    }

    part def CryogenicValve {
        doc /* Precision flow control valve for cryogenic service */
        
        attribute position : ValvePosition;
        attribute maxFlowCapacity : FlowRate;
        attribute actuationSpeed : Real;

        port inlet : CryogenicFluidPort;
        port outlet : CryogenicFluidPort;

        action modulateFlow {
            in commandedPosition : ValvePosition;
            in upstreamPressure : PressureLevel;
            out resultingFlowRate : FlowRate;
            out actualPosition : ValvePosition;
        }
    }

    part def CryogenicHeatExchanger {
        doc /* Heat exchanger for transferring cooling capacity from LN2 to thermal load */
        
        attribute effectiveArea : AreaValue;
        attribute overallHeatTransferCoefficient : Real;
        attribute thermalEfficiency : Real;

        port cryogenicInput : CryogenicFluidPort;
        port cryogenicOutput : CryogenicFluidPort;
        port loadInterface : ThermalLoadPort;

        action exchangeHeat {
            in ln2Temperature : CryogenicTemperature;
            in ln2FlowRate : FlowRate;
            in loadTemperature : TemperatureValue;
            in loadHeatGeneration : PowerValue;
            out coolingPowerDelivered : HeatTransferRate;
            out ln2ExitTemperature : TemperatureValue;
            out loadCooledTemperature : TemperatureValue;
        }
    }

    part def CryogenicTemperatureSensor {
        doc /* Precision temperature sensor for cryogenic range */
        
        attribute measurementAccuracy : TemperatureValue;
        attribute responseTime : TimeValue;
        attribute operatingRange : CryogenicTemperature[2];

        action sense {
            in actualTemperature : CryogenicTemperature;
            out measuredValue : CryogenicTemperature;
            out sensorHealth : Boolean;
        }
    }

    part def CryogenicPressureSensor {
        attribute measurementRange : PressureLevel[2];
        attribute accuracy : PressureLevel;

        action measure {
            in actualPressure : PressureLevel;
            out reading : PressureLevel;
        }
    }

    part def LevelSensor {
        attribute minDetectable : LiquidLevel;
        attribute maxDetectable : LiquidLevel;

        action detectLevel {
            in actualLevel : LiquidLevel;
            out levelReading : LiquidLevel;
            out lowLevelAlarm : Boolean;
        }
    }

    part def TemperatureController {
        doc /* PID controller for maintaining target cryogenic temperature */
        
        attribute targetTemperature : CryogenicTemperature;
        attribute proportionalGain : Real;
        attribute integralGain : Real;
        attribute derivativeGain : Real;
        attribute integralAccumulator : Real;
        attribute previousError : Real;

        port controlInterface : ControlPort;

        action computeControl {
            in setpoint : CryogenicTemperature;
            in processVariable : CryogenicTemperature;
            in deltaTime : TimeValue;
            out controlOutput : ValvePosition;
            out errorValue : Real;
        }

        action checkSafety {
            in systemPressure : PressureLevel;
            in dewarLevel : LiquidLevel;
            in loadTemperature : TemperatureValue;
            out safeToOperate : Boolean;
            out alarmCondition : String;
        }
    }

    part def SafetyReliefValve {
        attribute reliefSetPressure : PressureLevel;
        attribute ventCapacity : FlowRate;

        action relievePressure {
            in currentPressure : PressureLevel;
            out valveOpen : Boolean;
            out ventFlowRate : FlowRate;
        }
    }

    part def GasVentSystem {
        attribute ventLineSize : LengthValue;
        attribute maxVentRate : FlowRate;

        action ventBoilOff {
            in gasFlowRate : FlowRate;
            out exhaustTemperature : TemperatureValue;
        }
    }

    action def InitializeSystem {
        out systemReady : Boolean;
        out initialDewarLevel : LiquidLevel;
    }

    action def MonitorOperatingConditions {
        in dewarLevel : LiquidLevel;
        in systemPressure : PressureLevel;
        in loadTemperature : TemperatureValue;
        in targetTemperature : CryogenicTemperature;
        out operationalStatus : String;
        out requiresIntervention : Boolean;
    }

    action def AdjustCoolingRate {
        in temperatureError : Real;
        in currentFlowRate : FlowRate;
        out newValvePosition : ValvePosition;
    }

    action def ExecuteCoolingCycle {
        in heatLoadDemand : PowerValue;
        in availableLN2 : LiquidLevel;
        out achievedTemperature : CryogenicTemperature;
        out ln2Consumed : VolumeValue;
    }

    state def SystemOperatingStates {
        entry; then standby;

        state standby {
            doc /* System powered but not actively cooling */
        }
        accept StartupCommand;
        then initialization;

        state initialization {
            do action performStartup : InitializeSystem {
                out systemReady;
                out initialDewarLevel;
            }
        }
        if performStartup.systemReady and performStartup.initialDewarLevel > 0.2 then precooling;
        if not performStartup.systemReady then fault;

        state precooling {
            doc /* Initial cooldown phase to bring load to cryogenic range */
            do action rapidCooldown {
                out cooldownProgress : Real;
            }
        }
        if rapidCooldown.cooldownProgress >= 0.95 then steadyStateOperation;

        state steadyStateOperation {
            doc /* Normal operation maintaining target temperature */
            do action maintainTemperature {
                in targetSetpoint : CryogenicTemperature;
                out temperatureDeviation : Real;
            }
        }
        if maintainTemperature.temperatureDeviation > 5.0 then precooling;
        accept LowLevelDetected;
        then lowLevelAlarm;
        accept OverpressureDetected;
        then pressureRelief;
        accept ShutdownCommand;
        then shutdown;

        state lowLevelAlarm {
            do action alertOperator;
        }
        accept DewarRefilled;
        then steadyStateOperation;
        accept CriticalLowLevel;
        then shutdown;

        state pressureRelief {
            do action activateReliefValve;
        }
        accept PressureNormalized;
        then steadyStateOperation;

        state fault {
            do action logFaultCondition;
        }
        accept FaultCleared;
        then standby;

        state shutdown {
            do action closeAllValves;
            do action isolateSystem;
        }
        then done;
    }

    part cryogenicCoolingSystem {
        doc /* 
         * A liquid nitrogen cryogenic cooling system designed to maintain ultra-low 
         * temperatures for scientific instruments, superconducting equipment, or 
         * industrial processes. The system continuously circulates liquid nitrogen 
         * through a heat exchanger to extract heat from the target load, maintaining 
         * precise temperature control in the cryogenic range (typically 77-150 K).
         * 
         * Primary Function: Provide continuous, stable cryogenic cooling by delivering
         * controlled liquid nitrogen flow to remove heat from a thermal load, maintaining
         * target temperatures with high precision while ensuring safe operation through
         * automated monitoring and pressure relief systems.
         */

        part storageDewar : StorageDewar {
            attribute :>> capacity = 150.0 [L];
            attribute :>> currentLevel = 0.80;
            attribute :>> insulationVacuumPressure = 0.001 [Pa];
            attribute :>> boilOffRate = 0.05 [L/h];
        }

        part supplyValve : CryogenicValve {
            attribute :>> maxFlowCapacity = 8.0 [L/min];
            attribute :>> actuationSpeed = 0.1;
        }

        part heatExchanger : CryogenicHeatExchanger {
            attribute :>> effectiveArea = 0.75 [m^2];
            attribute :>> thermalEfficiency = 0.85;
        }

        part returnValve : CryogenicValve {
            attribute :>> maxFlowCapacity = 10.0 [L/min];
        }

        part loadTempSensor : CryogenicTemperatureSensor {
            attribute :>> measurementAccuracy = 0.05 [K];
            attribute :>> responseTime = 0.3 [s];
        }

        part dewarTempSensor : CryogenicTemperatureSensor {
            attribute :>> measurementAccuracy = 0.1 [K];
            attribute :>> responseTime = 0.5 [s];
        }

        part pressureSensor : CryogenicPressureSensor {
            attribute :>> accuracy = 100.0 [Pa];
        }

        part levelSensor : LevelSensor {
            attribute :>> minDetectable = 0.05;
            attribute :>> maxDetectable = 0.98;
        }

        part controller : TemperatureController {
            attribute :>> targetTemperature = 90.0 [K];
            attribute :>> proportionalGain = 2.5;
            attribute :>> integralGain = 0.8;
            attribute :>> derivativeGain = 0.3;
        }

        part safetyRelief : SafetyReliefValve {
            attribute :>> reliefSetPressure = 400000.0 [Pa];
            attribute :>> ventCapacity = 15.0 [L/min];
        }

        part ventSystem : GasVentSystem {
            attribute :>> maxVentRate = 20.0 [L/min];
        }

        connect storageDewar.liquidOutlet to supplyValve.inlet;
        connect supplyValve.outlet to heatExchanger.cryogenicInput;
        connect heatExchanger.cryogenicOutput to returnValve.inlet;
        connect returnValve.outlet to ventSystem;

        perform action coolingOperation {
            first start;
            then merge controlLoop;

            action monitorConditions : MonitorOperatingConditions {
                in dewarLevel = storageDewar.currentLevel;
                in systemPressure = storageDewar.innerVessel.ln2Reservoir.currentPressure;
                in loadTemperature = heatExchanger.loadInterface.surfaceTemperature;
                in targetTemperature = controller.targetTemperature;
                out operationalStatus;
                out requiresIntervention;
            }

            then decide;
                if monitorConditions.operationalStatus == "normal" then controlTemperature;
                if monitorConditions.operationalStatus == "lowLevel" then issueAlarm;
                if monitorConditions.operationalStatus == "overpressure" then activateRelief;
                if monitorConditions.requiresIntervention then emergencyShutdown;

            action controlTemperature {
                action computePID : TemperatureController::computeControl {
                    in setpoint = controller.targetTemperature;
                    in processVariable = loadTempSensor.sense.measuredValue;
                    in deltaTime = 0.1 [s];
                    out controlOutput;
                    out errorValue;
                }
                then action adjustValve : AdjustCoolingRate {
                    in temperatureError = computePID.errorValue;
                    in currentFlowRate = supplyValve.modulateFlow.resultingFlowRate;
                    out newValvePosition;
                }
                then action setValve {
                    action updateValvePosition {
                        in position = adjustValve.newValvePosition;
                    }
                }
            }
            then action performCooling : ExecuteCoolingCycle {
                in heatLoadDemand = heatExchanger.loadInterface.heatLoad;
                in availableLN2 = storageDewar.currentLevel;
                out achievedTemperature;
                out ln2Consumed;
            }
            then controlLoop;

            action issueAlarm {
                action sendLowLevelWarning;
                action reduceFlowRate;
            }
            then controlLoop;

            action activateRelief {
                action openReliefValve : SafetyReliefValve::relievePressure {
                    in currentPressure = storageDewar.innerVessel.ln2Reservoir.currentPressure;
                    out valveOpen;
                    out ventFlowRate;
                }
            }
            then controlLoop;

            action emergencyShutdown {
                action closeSupplyValve;
                action isolateDewar;
                action notifyOperator;
            }
            then done;
        }

        exhibit state operatingBehavior : SystemOperatingStates;
    }

    requirement <'REQ-001'> maintainCryogenicTemperature {
        doc /* 
         * The system shall maintain the thermal load at the specified cryogenic 
         * temperature setpoint within ±1.5 K during steady-state operation.
         */

        subject cryogenicCoolingSystem;

        require constraint temperatureControl {
            abs(cryogenicCoolingSystem.heatExchanger.loadInterface.surfaceTemperature - 
                cryogenicCoolingSystem.controller.targetTemperature) <= 1.5 [K]
        }
    }

    requirement <'REQ-002'> ensureSafeOperation {
        doc /* 
         * The system shall maintain safe operating conditions by keeping pressure 
         * below relief threshold and ensuring adequate liquid nitrogen supply.
         */

        subject cryogenicCoolingSystem;

        require constraint pressureSafety {
            cryogenicCoolingSystem.storageDewar.innerVessel.ln2Reservoir.currentPressure < 
            cryogenicCoolingSystem.safetyRelief.reliefSetPressure
        }

        require constraint minimumSupply {
            cryogenicCoolingSystem.storageDewar.currentLevel >= 
            cryogenicCoolingSystem.levelSensor.minDetectable
        }
    }

    requirement <'REQ-003'> deliverCoolingCapacity {
        doc /* 
         * The system shall provide continuous cooling capacity of at least 750 W
         * to remove heat from the thermal load.
         */

        subject cryogenicCoolingSystem;

        require constraint minimumCoolingPower {
            cryogenicCoolingSystem.heatExchanger.exchangeHeat.coolingPowerDelivered >= 750.0 [W]
        }
    }

    requirement <'REQ-004'> controlFlowPrecision {
        doc /* 
         * The system shall modulate liquid nitrogen flow rate with precision 
         * sufficient to maintain temperature stability.
         */

        subject cryogenicCoolingSystem;

        require constraint flowModulation {
            cryogenicCoolingSystem.supplyValve.position >= 0.0 and
            cryogenicCoolingSystem.supplyValve.position <= 1.0
        }
    }

    requirement <'REQ-005'> automaticSafetyResponse {
        doc /* 
         * The system shall automatically activate pressure relief and issue alarms
         * when operating limits are approached or exceeded.
         */

        subject cryogenicCoolingSystem;

        require constraint reliefActivation {
            cryogenicCoolingSystem.storageDewar.innerVessel.ln2Reservoir.currentPressure >= 
            cryogenicCoolingSystem.safetyRelief.reliefSetPressure implies
            cryogenicCoolingSystem.safetyRelief.relievePressure.valveOpen
        }
    }

    requirement systemRequirements {
        doc /* Top-level requirements for cryogenic cooling system */
        
        require maintainCryogenicTemperature;
        require ensureSafeOperation;
        require deliverCoolingCapacity;
        require controlFlowPrecision;
        require automaticSafetyResponse;
    }
}
