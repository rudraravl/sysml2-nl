package CryogenicStorageAndGasSupplySystem {

    import ScalarValues::*;

    // ============ Units ============
    unit Pa;
    unit K;
    unit m3;
    unit kg;
    unit kgps;
    unit m3ps;
    unit W;
    unit s;

    // ============ Value Types ============
    value type Pressure :> Real {
        min 0.0;
        unit Pa;
    }
    value type Temperature :> Real {
        min 0.0;
        unit K;
    }
    value type Volume :> Real {
        min 0.0;
        unit m3;
    }
    value type Mass :> Real {
        min 0.0;
        unit kg;
    }
    value type MassFlowRate :> Real {
        min 0.0;
        unit kgps;
    }
    value type VolumetricFlowRate :> Real {
        min 0.0;
        unit m3ps;
    }
    value type Power :> Real {
        min 0.0;
        unit W;
    }
    value type Duration :> Real {
        min 0.0;
        unit s;
    }
    value type Fraction :> Real {
        min 0.0;
        max 1.0;
    }

    // ============ Item Definitions ============
    item def CryogenicLiquid {
        attribute boilingPoint : Temperature;
        attribute density : Real;
    }
    item def LiquidNitrogen :> CryogenicLiquid {
        redefines boilingPoint = 77.36;
        redefines density = 808.0;
    }
    item def LiquidOxygen :> CryogenicLiquid {
        redefines boilingPoint = 90.19;
        redefines density = 1141.0;
    }
    item def GaseousProduct {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }
    item def NitrogenGas :> GaseousProduct;
    item def OxygenGas :> GaseousProduct;

    // ============ Enumerations ============
    enum def SystemMode {
        off;
        standby;
        supplying;
        safetyVenting;
        fault;
    }
    enum def ValveMode {
        closed;
        regulating;
        open;
    }
    enum def PumpMode {
        stopped;
        running;
        standby;
    }

    // ============ Port Definitions ============
    port def LiquidFlowPort {
        attribute flowRate : MassFlowRate;
        ref item medium : CryogenicLiquid;
    }
    port def GasFlowPort {
        attribute flowRate : MassFlowRate;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        ref item medium : GaseousProduct;
    }
    port def ThermalInterfacePort {
        attribute heatInflow : Power;
        attribute ambientTemperature : Temperature;
    }
    port def VacuumSensingPort {
        attribute vacuumLevel : Pressure;
    }
    port def PhysicalSensingPort {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute liquidLevel : Fraction;
    }
    port def SensorOutputPort {
        attribute measuredValue : Real;
        attribute unitLabel : String;
        attribute valid : Boolean;
    }
    port def ControlPort {
        attribute command : String;
        attribute setpointValue : Real;
    }

    // ============ Part Definitions ============

    part def InnerVessel {
        doc /* Inner vessel that holds cryogenic liquid at extremely low temperature. */;
        attribute capacity : Volume = 0.25;
        attribute designPressure : Pressure = 8.0e5;
        attribute currentPressure : Pressure;
        attribute contentsTemperature : Temperature;
        attribute liquidLevel : Fraction;
        attribute contentsMass : Mass;

        port liquidOutlet : LiquidFlowPort;
        port pressureReliefPort : GasFlowPort;
        port sensingInterface : PhysicalSensingPort;

        action def updateStatus() {
            // Update internal state from physical measurements
        }
    }

    part def OuterShell {
        doc /* Protective outer wall exposed to ambient environment. */;
        attribute material : String = "stainless steel";
        attribute wallThickness : Real = 0.003;
        attribute ambientTemperature : Temperature;

        port ambientInterface : ThermalInterfacePort;
    }

    part def VacuumJacket {
        doc /* Insulating vacuum space between inner and outer walls. */;
        attribute targetVacuum : Pressure = 1.0e-3;
        attribute currentVacuum : Pressure;
        attribute jacketVolume : Volume = 0.05;

        port vacuumPort : VacuumSensingPort;
    }

    part def VacuumPumpSystem {
        doc /* Actively monitors and maintains vacuum level in the jacket. */;
        attribute pumpCapacity : VolumetricFlowRate = 0.001;
        attribute isRunning : Boolean = false;
        attribute currentMode : PumpMode = PumpMode::stopped;

        port vacuumPort : VacuumSensingPort;
        port controlPort : ControlPort;

        action def maintainVacuum() {
            // Pump down vacuum jacket to maintain target vacuum
        }

        state machine pumpStateMachine {
            state Stopped {
                entry { isRunning = false; currentMode = PumpMode::stopped; }
            }
            state Running {
                entry { isRunning = true; currentMode = PumpMode::running; }
                do { maintainVacuum(); }
            }
            state Standby {
                entry { isRunning = false; currentMode = PumpMode::standby; }
            }

            transition Stopped -> Running when controlPort.command == "start";
            transition Running -> Standby when vacuumPort.vacuumLevel <= 1.0e-3;
            transition Standby -> Running when vacuumPort.vacuumLevel > 2.0e-3;
            transition Running -> Stopped when controlPort.command == "stop";
            transition Standby -> Stopped when controlPort.command == "stop";
        }
    }

    part def EvaporatorCoil {
        doc /* Heat exchanger using ambient heat to vaporize cryogenic liquid. */;
        attribute heatTransferArea : Real = 2.0;
        attribute heatTransferCoefficient : Real = 50.0;
        attribute coilVolume : Volume = 0.002;
        attribute outletGasTemperature : Temperature = 288.0;
        attribute vaporizationRate : MassFlowRate;

        port liquidInlet : LiquidFlowPort;
        port gasOutlet : GasFlowPort;
        port ambientHeatPort : ThermalInterfacePort;

        action def vaporize() {
            // Convert incoming liquid to gas using ambient heat
        }
    }

    part def PressureRegulationValve {
        doc /* Regulates flow and pressure of output gas. */;
        attribute setpointPressure : Pressure = 3.0e5;
        attribute maxFlowRate : MassFlowRate = 0.05;
        attribute valvePosition : Fraction = 0.0;
        attribute currentMode : ValveMode = ValveMode::closed;

        port gasInlet : GasFlowPort;
        port gasOutlet : GasFlowPort;
        port controlPort : ControlPort;

        action def regulatePressure() {
            // Adjust valve position to maintain setpoint
        }

        state machine regulationStateMachine {
            state Closed {
                entry { valvePosition = 0.0; currentMode = ValveMode::closed; }
            }
            state Regulating {
                entry { currentMode = ValveMode::regulating; }
                do { regulatePressure(); }
            }
            state FullyOpen {
                entry { valvePosition = 1.0; currentMode = ValveMode::open; }
            }

            transition Closed -> Regulating when controlPort.command == "supply";
            transition Regulating -> Closed when controlPort.command == "stop";
            transition Regulating -> FullyOpen when gasInlet.pressure > setpointPressure * 1.5;
            transition FullyOpen -> Regulating when gasInlet.pressure <= setpointPressure;
        }
    }

    part def SafetyReliefValve {
        doc /* Automatically vents excess pressure at dangerous levels. */;
        attribute reliefPressure : Pressure = 7.0e5;
        attribute isVenting : Boolean = false;
        attribute ventingRate : MassFlowRate;

        port gasInlet : GasFlowPort;
        port ventPort : GasFlowPort;
        port controlPort : ControlPort;

        action def ventExcessPressure() {
            // Vent excess gas to atmosphere
        }

        state machine safetyStateMachine {
            state Sealed {
                entry { isVenting = false; }
            }
            state Venting {
                entry { isVenting = true; }
                do { ventExcessPressure(); }
            }

            transition Sealed -> Venting when gasInlet.pressure >= reliefPressure;
            transition Venting -> Sealed when gasInlet.pressure < reliefPressure * 0.9;
        }
    }

    part def LiquidLevelSensor {
        doc /* Measures the level of cryogenic liquid in the inner vessel. */;
        attribute minRange : Fraction = 0.0;
        attribute maxRange : Fraction = 1.0;
        attribute accuracy : Fraction = 0.01;
        attribute currentValue : Fraction;

        port physicalInput : PhysicalSensingPort;
        port readout : SensorOutputPort;

        action def measure() {
            // Measure liquid level and output via readout
        }
    }

    part def VesselPressureSensor {
        doc /* Measures internal pressure of the cryogenic system. */;
        attribute minRange : Pressure = 0.0;
        attribute maxRange : Pressure = 1.0e6;
        attribute accuracy : Pressure = 5.0e3;
        attribute currentValue : Pressure;

        port physicalInput : PhysicalSensingPort;
        port readout : SensorOutputPort;

        action def measure() {
            // Measure pressure and output via readout
        }
    }

    part def VesselTemperatureSensor {
        doc /* Measures temperature of the cryogenic liquid and gas. */;
        attribute minRange : Temperature = 50.0;
        attribute maxRange : Temperature = 350.0;
        attribute accuracy : Temperature = 1.0;
        attribute currentValue : Temperature;

        port physicalInput : PhysicalSensingPort;
        port readout : SensorOutputPort;

        action def measure() {
            // Measure temperature and output via readout
        }
    }

    part def VacuumGauge {
        doc /* Monitors vacuum level to ensure insulation integrity. */;
        attribute minRange : Pressure = 1.0e-5;
        attribute maxRange : Pressure = 1.0e5;
        attribute accuracy : Pressure = 1.0e-4;
        attribute currentValue : Pressure;

        port sensingPort : VacuumSensingPort;
        port readout : SensorOutputPort;

        action def measure() {
            // Measure vacuum level and output via readout
        }
    }

    part def SystemController {
        doc /* Manages overall system operation, safety, and efficiency. */;
        attribute currentMode : SystemMode = SystemMode::off;
        attribute targetSupplyPressure : Pressure = 3.0e5;
        attribute maxSafePressure : Pressure = 6.0e5;
        attribute minVacuumLevel : Pressure = 1.0e-3;
        attribute minLiquidLevel : Fraction = 0.05;
        attribute gasDemand : Boolean = false;
        attribute powerOn : Boolean = false;
        attribute faultAcknowledged : Boolean = false;

        port liquidLevelInput : SensorOutputPort;
        port pressureInput : SensorOutputPort;
        port temperatureInput : SensorOutputPort;
        port vacuumInput : SensorOutputPort;

        port pumpCommand : ControlPort;
        port valveCommand : ControlPort;
        port safetyValveCommand : ControlPort;

        action def monitorSystem() {
            // Continuously monitor sensors and maintain vacuum
        }
        action def regulateSupply() {
            // Regulate gas supply based on demand
        }
        action def emergencyVent() {
            // Command safety valve to vent excess pressure
        }
        action def alertOperator() {
            // Send fault alert to operator
        }

        state machine controllerStateMachine {
            state Off {
                entry { currentMode = SystemMode::off; }
            }
            state Standby {
                entry { currentMode = SystemMode::standby; }
                do { monitorSystem(); }
            }
            state Supplying {
                entry { currentMode = SystemMode::supplying; }
                do { regulateSupply(); }
            }
            state SafetyVenting {
                entry { currentMode = SystemMode::safetyVenting; }
                do { emergencyVent(); }
            }
            state Fault {
                entry { currentMode = SystemMode::fault; }
                do { alertOperator(); }
            }

            transition Off -> Standby when powerOn;
            transition Standby -> Supplying when gasDemand;
            transition Supplying -> Standby when !gasDemand;
            transition Standby -> SafetyVenting when pressureInput.measuredValue >= 6.0e5;
            transition Supplying -> SafetyVenting when pressureInput.measuredValue >= 6.0e5;
            transition SafetyVenting -> Standby when pressureInput.measuredValue < 5.4e5;
            transition Standby -> Fault when vacuumInput.measuredValue > 1.0e-1;
            transition Standby -> Fault when liquidLevelInput.measuredValue < 0.05;
            transition Supplying -> Fault when vacuumInput.measuredValue > 1.0e-1;
            transition Fault -> Standby when faultAcknowledged;
        }
    }

    // ============ Top-Level System ============
    part def CryogenicStorageAndGasSupplySystem {
        doc /* Industrial-grade cryogenic liquid storage and on-demand gas supply system. */;

        attribute systemName : String = "CryoGas-250L";
        attribute ratedCapacity : Volume = 0.25;
        attribute ratedPressure : Pressure = 8.0e5;
        attribute designLife : Duration = 4.734e8;

        part innerVessel : InnerVessel;
        part outerShell : OuterShell;
        part vacuumJacket : VacuumJacket;
        part vacuumPumpSystem : VacuumPumpSystem;
        part evaporatorCoil : EvaporatorCoil;
        part pressureRegulationValve : PressureRegulationValve;
        part safetyReliefValve : SafetyReliefValve;
        part liquidLevelSensor : LiquidLevelSensor;
        part vesselPressureSensor : VesselPressureSensor;
        part vesselTemperatureSensor : VesselTemperatureSensor;
        part vacuumGauge : VacuumGauge;
        part controller : SystemController;

        port gasOutput : GasFlowPort;
        port ambientConnection : ThermalInterfacePort;
        port ventOutput : GasFlowPort;

        // Liquid flow: vessel to evaporator
        connection liquidToEvaporator
            connect innerVessel.liquidOutlet to evaporatorCoil.liquidInlet;

        // Gas flow: evaporator to regulator to output
        connection evaporatorToRegulator
            connect evaporatorCoil.gasOutlet to pressureRegulationValve.gasInlet;
        connection regulatorToOutput
            connect pressureRegulationValve.gasOutlet to gasOutput;

        // Vacuum monitoring and pumping
        connection vacuumSensing
            connect vacuumJacket.vacuumPort to vacuumGauge.sensingPort;
        connection vacuumPumping
            connect vacuumJacket.vacuumPort to vacuumPumpSystem.vacuumPort;

        // Safety relief
        connection safetyVenting
            connect innerVessel.pressureReliefPort to safetyReliefValve.gasInlet;
        connection safetyVentOutput
            connect safetyReliefValve.ventPort to ventOutput;

        // Ambient thermal interface
        connection ambientThermal
            connect outerShell.ambientInterface to ambientConnection;
        connection evaporatorAmbientHeat
            connect evaporatorCoil.ambientHeatPort to ambientConnection;

        // Sensor physical connections
        connection liquidLevelSensing
            connect innerVessel.sensingInterface to liquidLevelSensor.physicalInput;
        connection pressureSensing
            connect innerVessel.sensingInterface to vesselPressureSensor.physicalInput;
        connection temperatureSensing
            connect innerVessel.sensingInterface to vesselTemperatureSensor.physicalInput;

        // Sensor feedback to controller
        connection liquidLevelFeedback
            connect liquidLevelSensor.readout to controller.liquidLevelInput;
        connection pressureFeedback
            connect vesselPressureSensor.readout to controller.pressureInput;
        connection temperatureFeedback
            connect vesselTemperatureSensor.readout to controller.temperatureInput;
        connection vacuumFeedback
            connect vacuumGauge.readout to controller.vacuumInput;

        // Controller commands
        connection pumpControl
            connect controller.pumpCommand to vacuumPumpSystem.controlPort;
        connection valveControl
            connect controller.valveCommand to pressureRegulationValve.controlPort;
        connection safetyControl
            connect controller.safetyValveCommand to safetyReliefValve.controlPort;

        satisfy CryoStorageRequirement;
        satisfy OnDemandGasSupplyRequirement;
        satisfy SafetyReliefRequirement;
        satisfy VacuumIntegrityRequirement;
        satisfy MonitoringRequirement;
        satisfy EvaporatorPerformanceRequirement;
        satisfy VacuumPumpRequirement;
    }

    // ============ Requirements ============

    requirement def CryoStorageRequirement {
        doc /* The system shall safely store cryogenic liquid at extremely low temperatures with minimal boil-off. */;
        subject theSystem : CryogenicStorageAndGasSupplySystem;
        attribute maxStorageTemp : Temperature = 120.0;
        require theSystem.innerVessel.contentsTemperature <= maxStorageTemp;
    }

    requirement def OnDemandGasSupplyRequirement {
        doc /* The system shall provide regulated gas on demand at a steady pressure and suitable temperature. */;
        subject theSystem : CryogenicStorageAndGasSupplySystem;
        attribute minOutputPressure : Pressure = 2.9e5;
        attribute maxOutputPressure : Pressure = 3.1e5;
        attribute minOutputTemperature : Temperature = 288.0;
        require theSystem.gasOutput.pressure >= minOutputPressure;
        require theSystem.gasOutput.pressure <= maxOutputPressure;
        require theSystem.gasOutput.temperature >= minOutputTemperature;
    }

    requirement def SafetyReliefRequirement {
        doc /* The system shall automatically vent excess pressure before it reaches a dangerous level. */;
        subject theSystem : CryogenicStorageAndGasSupplySystem;
        attribute maxAllowablePressure : Pressure = 8.0e5;
        require theSystem.safetyReliefValve.reliefPressure < maxAllowablePressure;
    }

    requirement def VacuumIntegrityRequirement {
        doc /* The vacuum jacket shall maintain a high-quality vacuum to minimize heat transfer and boil-off. */;
        subject theSystem : CryogenicStorageAndGasSupplySystem;
        attribute targetVacuum : Pressure = 1.0e-3;
        require theSystem.vacuumJacket.currentVacuum <= targetVacuum;
    }

    requirement def MonitoringRequirement {
        doc /* The system shall include comprehensive sensors for safe and efficient operation. */;
        subject theSystem : CryogenicStorageAndGasSupplySystem;
        require theSystem.liquidLevelSensor.readout.valid;
        require theSystem.vesselPressureSensor.readout.valid;
        require theSystem.vesselTemperatureSensor.readout.valid;
        require theSystem.vacuumGauge.readout.valid;
    }

    requirement def EvaporatorPerformanceRequirement {
        doc /* The evaporator coil shall fully vaporize cryogenic liquid using ambient heat. */;
        subject theSystem : CryogenicStorageAndGasSupplySystem;
        attribute minOutletGasTemp : Temperature = 283.0;
        require theSystem.evaporatorCoil.outletGasTemperature >= minOutletGasTemp;
    }

    requirement def VacuumPumpRequirement {
        doc /* The vacuum pump system shall maintain vacuum integrity over the design life. */;
        subject theSystem : CryogenicStorageAndGasSupplySystem;
        attribute targetVacuum : Pressure = 1.0e-3;
        require theSystem.vacuumPumpSystem.vacuumPort.vacuumLevel <= targetVacuum;
    }
}
