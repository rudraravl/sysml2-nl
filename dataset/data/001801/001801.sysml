package 'John Crane Seal Support System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;
    private import ModelingMetadata::*;

    attribute def PressureDifferential :> ISQ::PressureValue;
    attribute def FlowRate :> ISQ::VolumeFlowRateValue;
    attribute def FluidLevel :> Real;
    attribute def SealHealth :> Real;

    enum def OperatingMode {
        standby;
        normal;
        alarm;
        shutdown;
    }

    enum def FluidCondition {
        clean;
        contaminated;
        degraded;
    }

    item def BarrierFluid {
        attribute pressure : ISQ::PressureValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute flowRate : FlowRate;
        attribute condition : FluidCondition;
    }

    item def ProcessFluid {
        attribute pressure : ISQ::PressureValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute viscosity : Real;
    }

    port def FluidPort {
        in item fluid : BarrierFluid;
    }

    port def ProcessPort {
        in item process : ProcessFluid;
    }

    port def SealPort {
        in item barrier : BarrierFluid;
        out item returnFluid : BarrierFluid;
    }

    port def MonitoringPort {
        out attribute pressure : ISQ::PressureValue;
        out attribute temperature : ISQ::ThermodynamicTemperatureValue;
        out attribute level : FluidLevel;
    }

    part def PressurizedReservoir {
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : FluidLevel;
        attribute operatingPressure : ISQ::PressureValue;
        attribute minLevel : FluidLevel;

        port fluidSupply : FluidPort;
        port fluidReturn : FluidPort;
        port monitoring : MonitoringPort;

        part bladderAccumulator {
            attribute precharge : ISQ::PressureValue;
            attribute volume : ISQ::VolumeValue;
        }

        part levelSensor {
            out attribute reading : FluidLevel;
        }

        part pressureSensor {
            out attribute reading : ISQ::PressureValue;
        }
    }

    part def HeatExchanger {
        attribute coolingCapacity : ISQ::PowerValue;
        attribute maxFlowRate : FlowRate;
        attribute inletTemp : ISQ::ThermodynamicTemperatureValue;
        attribute outletTemp : ISQ::ThermodynamicTemperatureValue;

        port hotFluidIn : FluidPort;
        port coolFluidOut : FluidPort;
        port coolingWaterIn;
        port coolingWaterOut;

        part tubeBundle {
            attribute surfaceArea : ISQ::AreaValue;
            attribute material : String;
        }

        part shellSide {
            attribute flowPattern : String;
        }
    }

    part def CirculationPump {
        attribute ratedFlow : FlowRate;
        attribute ratedHead : ISQ::LengthValue;
        attribute power : ISQ::PowerValue;
        attribute efficiency : Real;

        port suction : FluidPort;
        port discharge : FluidPort;

        part impeller {
            attribute diameter : ISQ::LengthValue;
            attribute speed : ISQ::AngularVelocityValue;
        }

        part motor {
            attribute voltage : ISQ::ElectricPotentialValue;
            attribute current : ISQ::ElectricCurrentValue;
        }
    }

    part def FilterAssembly {
        attribute filterRating : ISQ::LengthValue;
        attribute maxDifferentialPressure : ISQ::PressureValue;
        attribute currentDP : ISQ::PressureValue;

        port inlet : FluidPort;
        port outlet : FluidPort;

        part filterElement {
            attribute material : String;
            attribute replacementInterval : ISQ::TimeValue;
        }

        part bypassValve {
            attribute setPoint : ISQ::PressureValue;
        }
    }

    part def InstrumentationPanel {
        attribute alarmSetpoints : Real[*];

        port pressureInput : MonitoringPort;
        port temperatureInput : MonitoringPort;
        port levelInput : MonitoringPort;
        port alarmOutput;

        part pressureTransmitter {
            attribute range : ISQ::PressureValue;
            attribute accuracy : Real;
        }

        part temperatureTransmitter {
            attribute range : ISQ::ThermodynamicTemperatureValue;
            attribute accuracy : Real;
        }

        part levelTransmitter {
            attribute range : FluidLevel;
            attribute accuracy : Real;
        }

        part alarmRelay {
            attribute contacts : Integer;
        }
    }

    part def MechanicalSealInterface {
        attribute sealType : String;
        attribute sealSize : ISQ::LengthValue;
        attribute maxPressure : ISQ::PressureValue;
        attribute maxTemperature : ISQ::ThermodynamicTemperatureValue;

        port barrierFluidIn : SealPort;
        port processFluidInterface : ProcessPort;

        part stationaryFace {
            attribute material : String;
        }

        part rotatingFace {
            attribute material : String;
        }

        part secondarySeal {
            attribute type : String;
        }
    }

    action def MonitorSystemConditions {
        in attribute currentPressure : ISQ::PressureValue;
        in attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
        in attribute currentLevel : FluidLevel;
        in attribute processPressure : ISQ::PressureValue;
        in attribute pressureMargin : ISQ::PressureValue;
        in attribute maxTemperature : ISQ::ThermodynamicTemperatureValue;
        in attribute minLevel : FluidLevel;
        out attribute systemHealth : SealHealth;
        out attribute alarmCondition : Boolean;
    }

    action def CirculateBarrierFluid {
        in attribute pumpFlow : FlowRate;
        in attribute sealDemand : FlowRate;
        in attribute coolingRequired : Boolean;
        out attribute circulationRate : FlowRate;
        out attribute coolingActive : Boolean;
    }

    action def MaintainPressure {
        in attribute targetPressure : ISQ::PressureValue;
        in attribute currentPressure : ISQ::PressureValue;
        in attribute processPressure : ISQ::PressureValue;
        out attribute pressureAdjustment : ISQ::PressureValue;
    }

    action def ControlTemperature {
        in attribute currentTemp : ISQ::ThermodynamicTemperatureValue;
        in attribute maxTemp : ISQ::ThermodynamicTemperatureValue;
        in attribute coolingCapacity : ISQ::PowerValue;
        out attribute coolingDemand : ISQ::PowerValue;
    }

    state def SealSupportSystemLifecycle {
        in attribute currentMode : OperatingMode;
        
        entry; then startup;

        state startup;
        then normalOperation;

        state normalOperation;
        accept at pressureLow;
        then pressureAlarm;
        accept at temperatureHigh;
        then temperatureAlarm;
        accept at levelLow;
        then levelAlarm;

        state pressureAlarm;
        accept at pressureRestored;
        then normalOperation;
        accept at criticalPressureLoss;
        then emergencyShutdown;

        state temperatureAlarm;
        accept at temperatureNormal;
        then normalOperation;
        accept at criticalTemperature;
        then emergencyShutdown;

        state levelAlarm;
        accept at levelRestored;
        then normalOperation;
        accept at criticalLevelLow;
        then emergencyShutdown;

        state emergencyShutdown;
        then maintenance;

        state maintenance;
        then startup;
    }

    action def ProvideBarrierFluidSupport {
        in attribute processPressure : ISQ::PressureValue;
        in attribute processTemperature : ISQ::ThermodynamicTemperatureValue;
        in attribute requiredMargin : ISQ::PressureValue;
        in attribute maxAllowableTemp : ISQ::ThermodynamicTemperatureValue;
        out attribute sealProtection : SealHealth;

        first start;
        then merge continuousOperation;

        then action monitor : MonitorSystemConditions {
            in currentPressure;
            in currentTemperature;
            in currentLevel;
            in processPressure = processPressure;
            in pressureMargin = requiredMargin;
            in maxTemperature = maxAllowableTemp;
            in minLevel = 0.25;
            out systemHealth;
            out alarmCondition;
        }

        then decide;
            if monitor.systemHealth > 0.8 then maintainNormalOperation;
            if monitor.systemHealth <= 0.8 and monitor.systemHealth > 0.5 then adjustOperation;
            if monitor.systemHealth <= 0.5 then initiateShutdown;

        action maintainNormalOperation {
            action circulate : CirculateBarrierFluid {
                in pumpFlow;
                in sealDemand;
                in coolingRequired;
                out circulationRate;
                out coolingActive;
            }
            then action maintainPress : MaintainPressure {
                in targetPressure = processPressure + requiredMargin;
                in currentPressure;
                in processPressure = processPressure;
                out pressureAdjustment;
            }
            then action controlTemp : ControlTemperature {
                in currentTemp = currentTemperature;
                in maxTemp = maxAllowableTemp;
                in coolingCapacity;
                out coolingDemand;
            }
        }
        then continuousOperation;

        action adjustOperation;
        then continuousOperation;

        action initiateShutdown;
        then done;
    }

    requirement def <'REQ-SS-001'> PressureMarginRequirement {
        doc /* The seal support system shall maintain barrier fluid pressure 
               at minimum 1.7 bar above process fluid pressure to ensure 
               positive sealing and prevent process fluid ingress. */

        subject sealSupportSystem : SealSupportSystem;

        require constraint {
            sealSupportSystem.reservoir.operatingPressure >= 
            sealSupportSystem.sealInterface.processFluidInterface.process.pressure + 1.7 [SI::bar]
        }

        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = high;
                technicalRisk = medium;
                scheduleRisk = low;
                costRisk = medium;
            }
            originator = "Seal Engineering";
            owner = "System Design Lead";
        }
    }

    requirement def <'REQ-SS-002'> TemperatureControlRequirement {
        doc /* The seal support system shall maintain barrier fluid temperature 
               at or below 65°C at seal interface to preserve fluid properties 
               and seal face integrity. */

        subject sealSupportSystem : SealSupportSystem;

        require constraint {
            sealSupportSystem.cooler.outletTemp <= 338.15 [SI::K]
        }

        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = medium;
                technicalRisk = medium;
                scheduleRisk = low;
                costRisk = low;
            }
            originator = "Thermal Engineering";
            owner = "Cooling System Specialist";
        }
    }

    requirement def <'REQ-SS-003'> FluidLevelAlarmRequirement {
        doc /* The seal support system shall generate high-priority alarm 
               when reservoir fluid level drops below 25% capacity to prevent 
               pump cavitation and loss of seal protection. */

        subject sealSupportSystem : SealSupportSystem;

        require constraint {
            sealSupportSystem.reservoir.currentLevel < 0.25 implies 
            sealSupportSystem.instrumentation.alarmOutput
        }

        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = high;
                technicalRisk = low;
                scheduleRisk = low;
                costRisk = low;
            }
            originator = "Safety Engineering";
            owner = "Instrumentation Lead";
        }
    }

    requirement def <'REQ-SS-004'> CirculationFlowRequirement {
        doc /* The seal support system shall maintain minimum circulation flow 
               rate of 5 liters per minute to ensure adequate heat removal 
               and seal face lubrication. */

        subject sealSupportSystem : SealSupportSystem;

        require constraint {
            sealSupportSystem.pump.ratedFlow >= 5.0 [SI::L/SI::min]
        }

        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = medium;
                technicalRisk = low;
                scheduleRisk = low;
                costRisk = low;
            }
            originator = "Hydraulic Engineering";
            owner = "Pump Specialist";
        }
    }

    requirement <'SYS-REQ-SS-001'> sealSupportSystemRequirement {
        doc /* The John Crane Seal Support System shall provide continuous, 
               pressurized barrier fluid circulation to mechanical seals in 
               rotating equipment, maintaining seal integrity, controlling 
               temperature, and preventing process fluid leakage through 
               automated monitoring and protection. */

        assume constraint operatingEnvironment {
            doc /* System operates in industrial process environments with 
                   varying process pressures (0-25 bar), temperatures (0-200°C), 
                   and fluid types including hydrocarbons, water, and chemicals. */
        }

        require pressureMargin : PressureMarginRequirement;
        require temperatureControl : TemperatureControlRequirement;
        require fluidLevelAlarm : FluidLevelAlarmRequirement;
        require circulationFlow : CirculationFlowRequirement;
    }

    part sealSupportSystem : SealSupportSystem {
        satisfy sealSupportSystemRequirement;

        part reservoir : PressurizedReservoir {
            attribute capacity = 20.0 [SI::L];
            attribute currentLevel = 0.85;
            attribute operatingPressure = 8.0 [SI::bar];
            attribute minLevel = 0.25;
        }

        part cooler : HeatExchanger {
            attribute coolingCapacity = 5000.0 [SI::W];
            attribute maxFlowRate = 10.0 [SI::L/SI::min];
            attribute inletTemp = 338.15 [SI::K];
            attribute outletTemp = 318.15 [SI::K];
        }

        part pump : CirculationPump {
            attribute ratedFlow = 8.0 [SI::L/SI::min];
            attribute ratedHead = 15.0 [SI::m];
            attribute power = 750.0 [SI::W];
            attribute efficiency = 0.65;
        }

        part filter : FilterAssembly {
            attribute filterRating = 10.0e-6 [SI::m];
            attribute maxDifferentialPressure = 2.0 [SI::bar];
            attribute currentDP = 0.3 [SI::bar];
        }

        part instrumentation : InstrumentationPanel {
            attribute alarmSetpoints = (0.25, 338.15, 6.0);
        }

        part sealInterface : MechanicalSealInterface {
            attribute sealType = "Type 53B Dual Pressurized";
            attribute sealSize = 50.0 [SI::mm];
            attribute maxPressure = 25.0 [SI::bar];
            attribute maxTemperature = 473.15 [SI::K];
        }

        perform action provideSupport : ProvideBarrierFluidSupport {
            in processPressure = 5.0 [SI::bar];
            in processTemperature = 353.15 [SI::K];
            in requiredMargin = 1.7 [SI::bar];
            in maxAllowableTemp = 338.15 [SI::K];
            out sealProtection;
        }

        connection reservoirToPump connect 
            reservoir.fluidSupply to pump.suction;

        connection pumpToFilter connect 
            pump.discharge to filter.inlet;

        connection filterToCooler connect 
            filter.outlet to cooler.hotFluidIn;

        connection coolerToSeal connect 
            cooler.coolFluidOut to sealInterface.barrierFluidIn;

        connection sealToReservoir connect 
            sealInterface.barrierFluidIn to reservoir.fluidReturn;

        connection reservoirMonitoring connect 
            reservoir.monitoring to instrumentation.pressureInput;

        port processInterface : ProcessPort;
        port coolingWaterSupply;
        port powerSupply;
        port alarmSignal;
    }

    part def SealSupportSystem {
        doc /* John Crane Seal Support System (API Plan 53B) provides critical 
               sealing protection for rotating equipment in industrial applications.
               
               Primary Function: Continuously circulate clean, pressurized barrier 
               fluid to dual mechanical seals, maintaining pressure above process 
               fluid to prevent leakage, controlling temperature through heat 
               exchange, filtering contaminants, and monitoring system health to 
               ensure reliable seal operation and environmental compliance while 
               maximizing equipment uptime and seal life. */

        part reservoir : PressurizedReservoir;
        part cooler : HeatExchanger;
        part pump : CirculationPump;
        part filter : FilterAssembly;
        part instrumentation : InstrumentationPanel;
        part sealInterface : MechanicalSealInterface;

        port processInterface : ProcessPort;
        port coolingWaterSupply;
        port powerSupply;
        port alarmSignal;
    }
}
